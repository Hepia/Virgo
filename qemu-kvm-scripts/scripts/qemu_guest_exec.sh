#!/bin/bash

RED="\e[91m"
GREEN="\e[92m"
YELLOW="\e[93m"
BLUE="\e[94m"
WHITE="\e[97m"
ENDCOLOR="\e[0m"

INFO_MSG="${WHITE}[INFO]:    ${ENDCOLOR}"
SUCCESS_MSG="${GREEN}[SUCCESS]: ${ENDCOLOR}"
WARNING_MSG="${YELLOW}[WARNING]: ${ENDCOLOR}"
ERROR_MSG="${RED}[ERROR]:   ${ENDCOLOR}"

# Get the last part of the current directory
dir_name="${PWD##*/}"

# Check the directory name and execute the corresponding command.
case "${dir_name}" in
    scripts)
        CONFIG_FILE="../config/vms/config.json"
        DRIVER_FILE=$(jq -r '.DRIVER_FILE' "${CONFIG_FILE}")
        DRIVER_FILE="../${DRIVER_FILE}"
        ;;
    qemu-kvm-scripts)
        CONFIG_FILE="./config/vms/config.json"
        DRIVER_FILE=$(jq -r '.DRIVER_FILE' "${CONFIG_FILE}")
        DRIVER_FILE="./${DRIVER_FILE}"
        ;;
    *)
        echo -e "${ERROR_MSG}Unrecognised directory '${WHITE}${dir_name}'${ENDCOLOR}" >&2
        exit 1
        ;;
esac

# Extract values from the JSON file and assign them to variables
VM_NAME=$(jq -r '.VM_NAME' "${CONFIG_FILE}")
QGA_SOCKET=$(jq -r '.QGA_SOCKET' "${DRIVER_FILE}")

### CONFIGURATION ###
#QEMU_GA_CMD="virsh qemu-agent-command ${VM_NAME}"
SCRIPT_PATH=""
LOG_FILE=""
PID_FILE="/tmp/vm_script_pid"

# Function to send a command to QEMU Guest Agent via QGA socket
qga_send() {
    echo -e "$1" | socat - UNIX-CONNECT:"${QGA_SOCKET}"
}

# Function to check if QEMU Guest Agent is running
check_qemu_guest_agent() {
    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Checking if QEMU Guest Agent is running in VM '${WHITE}${VM_NAME}${ENDCOLOR}'..."

    CMD="{\"execute\": \"guest-ping\"}"
    STATUS=$(qga_send "${CMD}")

    if [[ "$STATUS" == *"return"* ]]; then
        echo -e "${SUCCESS_MSG}[${WHITE}✔${ENDCOLOR}] QEMU Guest Agent is running."
        return 0
    else
        echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] QEMU Guest Agent is NOT running. Use ${WHITE}--install-qga${ENDCOLOR} to install it inside the VM."
        exit 1
    fi
}

# Function to install QEMU Guest Agent inside the VM
install_qemu_guest_agent() {
    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Installing QEMU Guest Agent inside the VM..."

    CMD_INSTALL="{\"execute\": \"guest-exec\", \"arguments\": {\"path\": \"/usr/bin/apt\", \"arg\": [\"update\"], \"capture-output\": true}}"
    CMD_INSTALL_QGA="{\"execute\": \"guest-exec\", \"arguments\": {\"path\": \"/usr/bin/apt\", \"arg\": [\"install\", \"-y\", \"qemu-guest-agent\"], \"capture-output\": true}}"
    CMD_START_QGA="{\"execute\": \"guest-exec\", \"arguments\": {\"path\": \"/usr/bin/systemctl\", \"arg\": [\"start\", \"qemu-guest-agent\"], \"capture-output\": true}}"

    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Updating package list inside VM..."
    qga_send "${CMD_INSTALL}"

    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Installing QEMU Guest Agent..."
    qga_send "${CMD_INSTALL_QGA}"

    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Starting QEMU Guest Agent service..."
    qga_send "${CMD_START_QGA}"

    echo -e "${SUCCESS_MSG}[${WHITE}✔${ENDCOLOR}] QEMU Guest Agent installed and started inside the VM."
}

# Function to run a script inside the VM
run_script_in_vm() {
    if [[ -z "$SCRIPT_PATH" ]]; then
        echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] No script specified! Use ${WHITE}-f <script_path>${ENDCOLOR}."
        exit 1
    fi

    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Running script '${WHITE}${SCRIPT_PATH}${ENDCOLOR}' inside VM..."

    CMD="{\"execute\": \"guest-exec\", \"arguments\": {\"path\": \"${SCRIPT_PATH}\", \"capture-output\": true}}"
    RESPONSE=$(qga_send "${CMD}")

    PID=$(echo "$RESPONSE" | grep -o '"pid":[0-9]*' | cut -d: -f2)

    if [[ -n "${PID}" ]]; then
        echo -e "${SUCCESS_MSG}[${WHITE}✔${ENDCOLOR}] Script started successfully. Process ID: ${WHITE}${PID}${ENDCOLOR}."
        echo "${PID}" > "{$PID_FILE}"
    else
        echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] Failed to start the script inside the VM."
        exit 1
    fi
}

# Function to check the execution status of the script
check_script_status() {
    if [[ ! -f "${PID_FILE}" ]]; then
        echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] No script execution found. Run the script first."
        exit 1
    fi

    PID=$(cat "${PID_FILE}")

    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Checking execution status of script (PID: ${WHITE}${PID}${ENDCOLOR})..."

    STATUS_CMD="{\"execute\": \"guest-exec-status\", \"arguments\": {\"pid\": ${PID}}}"
    STATUS=$(qga_send "${STATUS_CMD}")

    if [[ "${STATUS}" == *"exited\":true"* ]]; then
        EXIT_CODE=$(echo "${STATUS}" | grep -o '"exitcode":[0-9]*' | cut -d: -f2)
        echo -e "${SUCCESS_MSG}[${WHITE}✔${ENDCOLOR}] Script execution completed. Exit code: ${WHITE}${EXIT_CODE}${ENDCOLOR}."
        rm -f "${PID_FILE}"
    else
        echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Script is still running inside the VM..."
    fi
}

# Function to fetch logs from the VM
fetch_script_logs() {
     if [[ -z "${LOG_FILE}" ]]; then
         echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] No log file specified! Use ${WHITE}-l <log_file_path>${ENDCOLOR}."
         exit 1
     fi

     echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Fetching logs from VM (${WHITE}${LOG_FILE}${ENDCOLOR})..."

     LOG_CMD="{\"execute\": \"guest-file-open\", \"arguments\": {\"path\": \"${LOG_FILE}\", \"mode\": \"r\"}}"
     RESPONSE=$(qga_send "${LOG_CMD}")
     FD=$(echo "${RESPONSE}" | grep -o '"return":[0-9]*' | cut -d: -f2)

     if [[ -n "${FD}" ]]; then
        READ_CMD="{\"execute\": \"guest-file-read\", \"arguments\": {\"handle\": ${FD}}}"
        LOGS=$(qga_send "${READ_CMD}")
        echo -e  "${INFO_MSG}[${WHITE}+${ENDCOLOR}] [ ${WHITE}Script Logs${ENDCOLOR} ]"
        echo -e -n "${INFO_MSG}[${WHITE}+${ENDCOLOR}] "
        echo "${LOGS}" | grep -o '"buf":".*"' | sed 's/"buf":"//g' | sed 's/"//g'

        CLOSE_CMD="{\"execute\": \"guest-file-close\", \"arguments\": {\"handle\": $FD}}"
        qga_send "${CLOSE_CMD}"
     else
         echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] Could not open log file in VM."
     fi
}

# Function to display help
show_help() {
    echo -e "Usage: $0 ${WHITE}[OPTIONS]"
    echo ""
    echo -e "Available options:"
    echo -e "  ${WHITE}-f, --file <script_path>${ENDCOLOR}   Run a script inside the VM"
    echo -e "  ${WHITE}-s, --status${ENDCOLOR}               Check the execution status of the script"
    echo -e "  ${WHITE}-l, --logs <log_file>${ENDCOLOR}      Fetch logs from the VM"
    echo -e "  ${WHITE}-i, --install-qga${ENDCOLOR}          Install QEMU Guest Agent inside the VM"
    echo -e "  ${WHITE}-h, --help${ENDCOLOR}                 Display this help message"
    echo ""
    exit 0
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file)
            SCRIPT_PATH="$2"
            shift 2
            check_qemu_guest_agent
            run_script_in_vm
            ;;
        -s|--status)
            check_qemu_guest_agent
            check_script_status
            shift
            ;;
        -l|--logs)
            LOG_FILE="$2"
            shift 2
            check_qemu_guest_agent
            fetch_script_logs
            ;;
        -i|--install-qga)
            install_qemu_guest_agent
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] Invalid option: ${WHITE}$1${ENDCOLOR}. Use ${WHITE}-h${ENDCOLOR} for help."
            exit 1
            ;;
    esac
done

# Show help if no arguments are provided
if [[ $# -eq 0 ]]; then
    show_help
fi
