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

# Path to the JSON configuration file

# Get the last part of the current directory
dir_name="${PWD##*/}"

# Check the directory name and execute the corresponding command.
case "${dir_name}" in
    scripts)
        NETWORK_CONFIG_FILE="../config/network/network.json"
        ;;
    qemu-kvm-scripts)
        NETWORK_CONFIG_FILE="./config/network/network.json"
        ;;
    *)
        echo -e "${ERROR_MSG}Unrecognised directory '${WHITE}${dir_name}'${ENDCOLOR}" >&2
        exit 1
        ;;
esac

# Extract values from the JSON file and assign them to variables
BRIDGE_NAME=$(jq -r '.BRIDGE_NAME' "$NETWORK_CONFIG_FILE")
NUMBER_OF_TAP_INTERFACES=$(jq -r '.NUMBER_OF_TAP_INTERFACES' "$NETWORK_CONFIG_FILE")
DHCP_RANGE_START=$(jq -r '.DHCP_RANGE_START' "$NETWORK_CONFIG_FILE")
DHCP_RANGE_END=$(jq -r '.DHCP_RANGE_END' "$NETWORK_CONFIG_FILE")

# Function to check if dnsmasq and bridge-utils are installed
check_dependencies() {
    local exit_code=0

    # Check if dnsmasq is installed
    if ! sudo which dnsmasq &> /dev/null; then
        echo -e "${ERROR_MSG}${WHITE}dnsmasq${ENDCOLOR} is not installed. Please install it using '${WHITE}sudo apt install dnsmasq${ENDCOLOR}' or your package manager."
        exit_code=1
    else
        echo -e "${SUCCESS_MSG}${WHITE}dnsmasq${ENDCOLOR} is installed."
    fi

    # Check if bridge-utils (brctl) is installed
    if ! sudo which brctl &> /dev/null; then
        echo -e "${ERROR_MSG}bridge-utils (brctl) is not installed. Please install it using '${WHITE}sudo apt install bridge-utils${ENDCOLOR}' or your package manager."
        exit_code=1
    else
        echo -e "${SUCCESS_MSG}${WHITE}bridge-utils${ENDCOLOR} (brctl) is installed."
    fi

    return ${exit_code}
}

# Function to create an isolated network
create_isolated_network() {
    # Check if bridge name and number of TAP interfaces are provided
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo -e "${ERROR_MSG}Usage: create_isolated_network ${WHITE}<bridge_name> <number_of_tap_interfaces>${ENDCOLOR}"
        return 1
    fi

    local bridge_name="$1"
    local num_tap_interfaces="$2"

    # Create the virtual bridge
    sudo brctl addbr "${bridge_name}"
    if [ $? -ne 0 ]; then
        echo -e "${ERROR_MSG}Failed to create bridge ${WHITE}${bridge_name}${ENDCOLOR}."
        return 1
    fi

    sudo ip link set "${bridge_name}" up
    if [ $? -ne 0 ]; then
        echo -e "${ERROR_MSG}Failed to bring up bridge ${WHITE}${bridge_name}${ENDCOLOR}."
        return 1
    fi

    echo -e "${SUCCESS_MSG}Bridge ${WHITE}${bridge_name}${ENDCOLOR} created and brought up."

    # Create and attach TAP interfaces
    for i in $(seq 0 $((num_tap_interfaces - 1))); do
        local tap_name="tap${i}"

        sudo ip tuntap add dev "${tap_name}" mode tap
        if [ $? -ne 0 ]; then
            echo -e "${ERROR_MSG}Failed to create TAP interface ${WHITE}${tap_name}${ENDCOLOR}."
            return 1
        fi

        sudo ip link set "${tap_name}" up
        if [ $? -ne 0 ]; then
            echo -e "${ERROR_MSG}Failed to bring up TAP interface ${WHITE}${tap_name}${ENDCOLOR}."
            return 1
        fi

        sudo brctl addif "${bridge_name}" "${tap_name}"
        if [ $? -ne 0 ]; then
            echo -e "${ERROR_MSG}Failed to attach TAP interface ${WHITE}${tap_name}${ENDCOLOR} to bridge ${WHITE}${bridge_name}${ENDCOLOR}."
            return 1
        fi

        echo -e "${SUCCESS_MSG}Tap interface ${WHITE}${tap_name}${ENDCOLOR} created and attached to ${WHITE}${bridge_name}${ENDCOLOR}."
    done
}

tap_exists() {
    local tap_name="$1"

    # Check if the interface name is provided
    if [ -z "${tap_name}" ]; then
        echo -e "${ERROR_MSG}Usage: tap_exists ${WHITE}<tap_interface_name>${ENDCOLOR}"
        return 1
    fi

    # Check if the TAP interface exists
    if ip link show "${tap_name}" &>/dev/null; then
        echo -e "${INFO_MSG}TAP interface ${WHITE}${tap_name}${ENDCOLOR} exists."
        return 0
    else
        echo -e "${ERROR_MSH}TAP interface ${WHITE}${tap_name}${ENDCOLOR} does not exist."
        return 1
    fi
}

# Function to remove an isolated network
remove_isolated_network() {
    # Check if bridge name is provided
    if [ -z "$1" ]; then
        echo -e "${ERROR_MSG}Usage: remove_isolated_network ${WHITE}<bridge_name>${ENDCOLOR}"
        return 1
    fi

    local bridge_name="$1"

    # Check if the bridge exists
    if ! ip link show "${bridge_name}" &>/dev/null; then
        echo -e "${ERROR_MSG}Bridge ${bridge_name} does not exist. Aborting."
        return 1
    fi

    echo -e "${INFO_MSG}Removing all TAP interfaces from ${WHITE}${bridge_name}${ENDCOLOR}..."

    # Get all TAP interfaces associated with the bridge
    local tap_interfaces
    tap_interfaces=$(sudo brctl show br0 | tr -s '[:space:]' ' ' | grep -o '\btap[[:alnum:]]*')
    #tap_interfaces=$(sudo brctl show "${bridge_name}" | awk 'NR>1 {print $4; print $1; print $2}' | grep -E '^tap[0-9]+$')

    # Remove and delete each TAP interface
    for tap in ${tap_interfaces}; do
        echo -e "${INFO_MSG}Removing TAP interface: ${WHITE}${tap}${ENDCOLOR}"
        tap_exists ${tap}

        if [ $? -eq 1 ]; then
            return 1
        fi

        sudo ip link set "${tap}" down
        sudo ip tuntap del mode tap dev "${tap}"
        if [ $? -eq 0 ]; then
            echo -e "${SUCCESS_MSG}TAP interface ${WHITE}${tap}${ENDCOLOR} removed."
        else
            echo -e "${ERROR_MSG}Failed to remove TAP interface ${WHITE}${tap}${ENDCOLOR}."
            return 1
        fi
    done

    # Bring down and delete the bridge
    echo -e "${INFO_MSG}Removing bridge: ${WHITE}${bridge_name}${ENDCOLOR}"
    sudo ip link set "${bridge_name}" down
    sudo brctl delbr "${bridge_name}"

    if [ $? -eq 0 ]; then
        echo -e "${SUCCESS_MSG}Bridge ${WHITE}${bridge_name}${ENDCOLOR} removed."
    else
        echo -e "${ERROR_MSG}Failed to remove bridge ${WHITE}${bridge_name}${ENDCOLOR}."
        return 1
    fi

    return 0
}

# Function to configure dnsmasq DHCP server
configure_dnsmasq() {
    # Check if required parameters are provided
    if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        echo -e "${ERROR_MSG}Usage: configure_dnsmasq ${WHITE}<bridge_interface> <dhcp_range_start> <dhcp_range_end>${ENDCOLOR}"
        return 1
    fi

    local bridge_interface="$1"
    local dhcp_range_start="$2"
    local dhcp_range_end="$3"
    local dhcp_lease_time="12h"
    local dnsmasq_conf="/etc/dnsmasq.conf"
    local backup_file="${dnsmasq_conf}.bak"

    # Check if a backup already exists; if not, create one
    if [ ! -e "${backup_file}" ]; then
        sudo cp "${dnsmasq_conf}" "${backup_file}"
        echo -e "${INFO_MSG}Backup created: ${WHITE}${backup_file}${ENDCOLOR}"
    else
        echo -e "${WARNING_MSG}Backup already exists: ${WHITE}${backup_file}${ENDCOLOR}. Skipping backup creation."
    fi

   # Check if the dnsmasq.conf already contains the interface and dhcp-range
    if grep -q "interface=$bridge_interface" "$dnsmasq_conf"; then
        echo -e "${WARNING_MSG}Configuration for ${WHITE}${bridge_interface}${ENDCOLOR} already exists in ${WHITE}dnsmasq.conf${ENDCOLOR}. Skipping interface configuration."
    else
        # Add configuration for the bridge interface if not already present
        echo "interface=$bridge_interface" | sudo tee -a "$dnsmasq_conf" > /dev/null
        echo -e "${INFO_MSG}Configured dnsmasq for interface ${WHITE}${bridge_interface}${ENDCOLOR}."
    fi

    if grep -q "dhcp-range=$dhcp_range_start,$dhcp_range_end" "$dnsmasq_conf"; then
        echo -e "${WARNING_MSG}DHCP range ${WHITE}${dhcp_range_start}${ENDCOLOR} to ${WHITE}${dhcp_range_end}${ENDCOLOR} already exists in ${WHITE}dnsmasq.conf${ENDCOLOR}. Skipping DHCP range configuration."
    else
        # Add DHCP range configuration if not already present
        echo "dhcp-range=$dhcp_range_start,$dhcp_range_end,$dhcp_lease_time" | sudo tee -a "$dnsmasq_conf" > /dev/null
        echo -e "${INFO_MSG}Configured dnsmasq for interface ${WHITE}${bridge_interface}${ENDCOLOR} with DHCP range ${WHITE}${dhcp_range_start}${ENDCOLOR} to ${WHITE}${dhcp_range_end}${ENDCOLOR}."
    fi

    # Restart dnsmasq service
    sudo systemctl restart dnsmasq && echo -e "${SUCCESS_MSG}dnsmasq service restarted." || echo -e "${ERROR_MSG}Failed to restart dnsmasq."
}

# Function to stop dnsmasq and restore the backup configuration
restore_dnsmasq_backup() {
    local dnsmasq_conf="/etc/dnsmasq.conf"
    local backup_file="${dnsmasq_conf}.bak"

    # Stop the dnsmasq service
    echo -e "${INFO_MSG}Stopping dnsmasq service..."
    sudo systemctl stop dnsmasq && echo -e "${SUCCESS_MSG}dnsmasq service stopped." || { echo -e "${ERROR_MSG}Failed to stop dnsmasq."; return 1; }

    # Check if the backup file exists
    if [ -e "${backup_file}" ]; then
        # Restore the backup configuration
        sudo cp "${backup_file}" "${dnsmasq_conf}"
        sudo rm -rf "${backup_file}"
        echo -e "${SUCCESS_MSG}Restored backup configuration from ${WHITE}${backup_file}${ENDCOLOR}."
    else
        echo -e "${ERROR_MSG}No backup configuration found. Restoration aborted."
        return 1
    fi

    # Restart the dnsmasq service
    echo -e "${INFO_MSG}Restarting dnsmasq service..."
    sudo systemctl restart dnsmasq && echo -e "${SUCCESS_MSG}dnsmasq service restarted with restored configuration." || echo -e "${SUCCESS_MSG}Failed to restart dnsmasq."

    return 0
}

# Check if root is needed for dmesg
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${INFO_MSG}This script requires sudo access. Please provide your password to continue."
    sudo -v
fi

check_dependencies
status=$?

# Check the status
if [ ${status} -eq 0 ]; then
    echo -e "${SUCCESS_MSG}All required dependencies are installed."
else
    echo -e "${ERROR_MSG}Some dependencies are missing. Please install them."
    exit 1
fi

# Check if the bridge exists
if ! ip link show "${BRIDGE_NAME}" &>/dev/null; then
    create_isolated_network "${BRIDGE_NAME}" "${NUMBER_OF_TAP_INTERFACES}"
    configure_dnsmasq "${BRIDGE_NAME}" "${DHCP_RANGE_START}" "${DHCP_RANGE_END}"
else
    restore_dnsmasq_backup
    remove_isolated_network "${BRIDGE_NAME}"
fi
