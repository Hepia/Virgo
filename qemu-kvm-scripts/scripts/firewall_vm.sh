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

### CONFIGURATION ###
SSH_PORT=4022
SSH_CONFIG="/etc/ssh/sshd_config"

# Function to check and install packages
check_and_install_packages() {
    for package in "$@"; do
        if ! dpkg -l | grep -q "^ii  ${package} "; then
            echo -e "${WARNING_MSG}Package '${WHITE}${package}${ENDCOLOR}' is not installed. Installing..."
            sudo apt update && sudo apt install -y "${package}"
        else
            echo -e "${INFO_MSG}Package '${WHITE}${package}${ENDCOLOR}' is already installed."
        fi
    done
}

# Function to change the SSH port in the configuration file
change_ssh_port() {
    local ssh_port="$1"
    local ssh_config="$2"

    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Checking if SSH port is already set to ${WHITE}${ssh_port}${ENDCOLOR}..."

    # Check if the current SSH port is already ${ssh_port}
    if grep -q "^Port ${ssh_port}" "${ssh_config}"; then
        echo -e "${SUCCESS_MSG}[${WHITE}✔${ENDCOLOR}] SSH is already configured to listen on port ${WHITE}${ssh_port}${ENDCOLOR}."
        return 0
    fi

    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] SSH port not configured to ${WHITE}${ssh_port}${ENDCOLOR}. Proceeding with changes..."

    # Check if a backup already exists
    local backup_file="${ssh_config}.bak"
    if [ -f "${backup_file}" ]; then
        # Find the highest numbered backup file and increment it
        i=1
        while [ -f "${ssh_config}.bak.${i}" ]; do
            ((i++))
        done
        backup_file="${ssh_config}.bak.${i}"
    fi

    # Make a backup of the original SSH config file
    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Creating backup of SSH config as ${WHITE}${backup_file}${ENDCOLOR}..."
    sudo cp "${ssh_config}" "${backup_file}"

    # Update the Port directive in sshd_config to listen on port ${ssh_port}
    sudo sed -i "s/^#Port 22/Port ${ssh_port}/" "${ssh_config}"
    sudo sed -i "s/^Port 22/Port ${ssh_port}/" "${ssh_config}"

    echo -e "${SUCCESS_MSG}[${WHITE}✔${ENDCOLOR}] SSH port changed to ${WHITE}${ssh_port}${ENDCOLOR} and backup created as ${WHITE}${backup_file}${ENDCOLOR}."
}

# Function to restart the SSH service
restart_ssh_service() {
    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Restarting SSH service..."

    sudo systemctl restart ssh

    echo -e "${SUCCESS_MSG}[${WHITE}✔${ENDCOLOR}] SSH service restarted."
}

# Function to verify that SSH is listening on the specific port
verify_ssh_port() {
    local ssh_port="$1"

    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Verifying SSH is listening on port ${WHITE}${ssh_port}${ENDCOLOR}..."

    sudo ss -tuln | grep ":${ssh_port}"

    if [ $? -eq 0 ]; then
        echo -e "${SUCCESS_MSG}[${WHITE}✔${ENDCOLOR}] SSH is now listening on port ${WHITE}${ssh_port}${ENDCOLOR}."
    else
        echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] SSH is not listening on port ${WHITE}${ssh_port}${ENDCOLOR}. Please check the configuration."
    fi
}

# Function to change the SSH port, and restart the SSH service
configure_ssh_port() {
    local json_file="$1"

    if [[ ! -f "${json_file}" ]]; then
        echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] JSON config file not found: ${WHITE}${json_file}${ENDCOLOR}."
        return 1
    fi

    local ssh_port ssh_config
    ssh_port=$(jq -r '.SSH_PORT' "${json_file}")
    ssh_config=$(jq -r '.SSH_CONFIG' "${json_file}")

    change_ssh_port
    restart_ssh_service "${ssh_port}" "${ssh_config}"
    verify_ssh_port "${ssh_port}"
}

# Function to reset firewall rules
reset_firewall() {
    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Resetting firewall rules..."

    sudo iptables -F
    sudo iptables -X
    sudo iptables -Z
    sudo iptables -t nat -F
    sudo iptables -t mangle -F

    echo -e "${SUCCESS_MSG}[${WHITE}✔${ENDCOLOR}] Firewall rules reset."
}

echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}]  ${WHITE}${}${ENDCOLOR}."
echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}]  ${WHITE}${}${ENDCOLOR}."
echo -e "${SUCCESS_MSG}[${WHITE}✔${ENDCOLOR}]  ${WHITE}${}${ENDCOLOR}."

# Function to apply new firewall rules based on a JSON file
apply_firewall_rules() {
    local json_file="$1"

    if [[ ! -f "${json_file}" ]]; then
        echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] JSON config file not found: ${WHITE}${json_file}${ENDCOLOR}."
        return 1
    fi

    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Applying new firewall rules..."

    # Parse values from JSON
    local bridge_name ssh_enabled tap_count dhcp_start dhcp_end
    bridge_name=$(jq -r '.BRIDGE_NAME' "${json_file}")
    ssh_enabled=$(jq -r '.SSH' "${json_file}")
    tap_count=$(jq -r '.NUMBER_OF_TAP_INTERFACES' "${json_file}")
    dhcp_start=$(jq -r '.DHCP_RANGE_START' "${json_file}" | xargs)
    dhcp_end=$(jq -r '.DHCP_RANGE_END' "${json_file}" | xargs)
    ssh_port=$(jq -r '.SSH_PORT' "${json_file}")

    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Configuring firewall for bridge: ${WHITE}${bridge_name}${ENDCOLOR}."
    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] SSH access: ${WHITE}${ssh_enabled}${ENDCOLOR}."
    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] TAP interfaces: ${WHITE}${tap_count}${ENDCOLOR}."
    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] DHCP range: ${WHITE}${dhcp_start} - ${dhcp_end}${ENDCOLOR}."

    # Configuration of the ssh port if necessary
    if [[ "${ssh_enabled}" == "true" ]]; then
        configure_ssh_port "${json_file}"
    fi

    # Set default policies
    sudo iptables -P INPUT DROP
    sudo iptables -P OUTPUT DROP
    sudo iptables -P FORWARD DROP

    # Allow loopback
    sudo iptables -A INPUT -i lo -j ACCEPT
    sudo iptables -A OUTPUT -o lo -j ACCEPT

    # Detect and count NAT interfaces based on their IP range (10.0.2.x)
    local nat_ifaces
    nat_ifaces=$(ip -o -4 addr show | awk '{print $2, $4}' | grep -E "eth[0-9]+" | grep "10\.0\.2\." | cut -d' ' -f1)

    local nat_count=$(echo "${nat_ifaces}" | wc -l)
    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Found ${WHITE}${nat_count}${ENDCOLOR} NAT interfaces in the ${WHITE}10.0.2.0/24${ENDCOLOR} range."

    # Calculate the starting index for TAP interfaces
    local start_tap_index=${nat_count}

    # Allow traffic on TAP interfaces in the DHCP range
    for i in $(seq 0 $((tap_count - 1))); do
        # TAP interfaces start after NAT interfaces
        local tap_iface="eth$((start_tap_index + i))"
        sudo iptables -A INPUT -i "${tap_iface}" -s "${dhcp_start}"/24 -j ACCEPT
        sudo iptables -A OUTPUT -o "${tap_iface}" -d "${dhcp_start}"/24 -j ACCEPT
    done

    # Configure NAT interfaces (eth0, eth1, ...)
    for iface in ${nat_ifaces}; do
        echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Configuring NAT interface: ${WHITE}${iface}${ENDCOLOR}"

        if [[ "${ssh_enabled}" == "true" ]]; then
            # Allow incoming SSH only on NAT interfaces
            sudo iptables -A INPUT -i "${iface}" -p tcp --dport "${ssh_port}" -j ACCEPT
        fi

        # Block everything else on NAT interfaces
        sudo iptables -A INPUT -i "${iface}" -j DROP
        sudo iptables -A OUTPUT -o "${iface}" -j DROP
    done

    echo -e "${SUCCESS_MSG}[${WHITE}✔${ENDCOLOR}] Firewall rules successfully applied."
}

# Function to save firewall rules
save_firewall_rules() {
    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Saving firewall rules for persistence..."

    check_and_install_packages iptables-persistent jq
    sudo netfilter-persistent save
    sudo netfilter-persistent reload

    echo -e "${SUCCESS_MSG}[${WHITE}✔${ENDCOLOR}] Firewall rules saved and persistent."
}

# Function to display current firewall rules
show_firewall_rules() {
    echo -e "${INFO_MSG}[${WHITE}+${ENDCOLOR}] Displaying current firewall rules..."
    sudo iptables -L -v -n
}

# Function to display help
show_help() {
    echo -e "Usage: $0 ${WHITE}[OPTIONS]${ENDCOLOR}"
    echo ""
    echo -e "Available options:"
    echo -e "  ${WHITE}-j, --json <file>${ENDCOLOR}   Defines the JSON configuration file. Required with ${WHITE}--configure${ENDCOLOR}, ${WHITE}--apply${ENDCOLOR}, and ${WHITE}--full${ENDCOLOR} parameters"
    echo -e "  ${WHITE}-c, --configure${ENDCOLOR}     Configure SSH to listen on a specific port"
    echo -e "  ${WHITE}-r, --reset${ENDCOLOR}         Reset all firewall rules"
    echo -e "  ${WHITE}-a, --apply${ENDCOLOR}         Apply the new firewall rules"
    echo -e "  ${WHITE}-s, --save${ENDCOLOR}          Save firewall rules"
    echo -e "  ${WHITE}-v, --view${ENDCOLOR}          Show the current firewall rules"
    echo -e "  ${WHITE}-f, --full${ENDCOLOR}          Perform a full setup (reset, apply, save, view)"
    echo -e "  ${WHITE}-h, --help${ENDCOLOR}          Display this help message"
    echo ""
    exit 0
}

# Check if root is needed
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${INFO_MSG}This script requires sudo access. Please provide your password to continue."
    sudo -v
fi

# JSON file path
json_file=""

# Execute the requested option if provided as an argument
while [[ $# -gt 0 ]]; do
    case "$1" in
        -j|--json)
            shift
            if [[ -z "$1" ]]; then
                echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] Missing path after --json"; exit 1
            fi
            json_file="$1"
            shift
        ;;
        -c|--configure)
            if [[ -z "${json_file}" ]]; then
                echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] ${WHITE}--json <file>${ENDCOLOR} is required with --apply"
                exit 1
            fi
            configure_ssh_port "${json_file}"
            exit 0 ;;
        -r|--reset) reset_firewall; exit 0 ;;
        -s|--save) save_firewall_rules; exit 0 ;;
        -v|--view) show_firewall_rules; exit 0 ;;
        -a|--apply)
            if [[ -z "${json_file}" ]]; then
                echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] ${WHITE}--json <file>${ENDCOLOR} is required with --apply"
                exit 1
            fi
            apply_firewall_rules "${json_file}"
            exit 0
        ;;
        -f|--full)
            if [[ -z "${json_file}" ]]; then
                echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] ${WHITE}--json <file>${ENDCOLOR} is required with --full"
                exit 1
            fi
            reset_firewall
            apply_firewall_rules "${json_file}"
            save_firewall_rules
            show_firewall_rules
            exit 0
        ;;
        -h|--help)
        ;;
        *) echo -e "${ERROR_MSG}Invalid option! Use -h for help."; exit 1 ;;
    esac
done

# Main menu (only displayed if no option is provided)
echo -e "${INFO_MSG}----------------------------"
echo -e "${INFO_MSG}  🔥 Firewall VM - IPTables  "
echo -e "${INFO_MSG}----------------------------"
echo -e "${INFO_MSG}${YELLOW}1${ENDCOLOR}) Configure SSH"
echo -e "${INFO_MSG}${YELLOW}2${ENDCOLOR}) Reset the firewall"
echo -e "${INFO_MSG}${YELLOW}3${ENDCOLOR}) Apply rules"
echo -e "${INFO_MSG}${YELLOW}4${ENDCOLOR}) Save rules"
echo -e "${INFO_MSG}${YELLOW}5${ENDCOLOR}) View rules"
echo -e "${INFO_MSG}${YELLOW}6${ENDCOLOR}) Run full setup (reset, apply, save, view)"
echo -e "${INFO_MSG}${YELLOW}7${ENDCOLOR}) Exit"
echo -e -n "${INFO_MSG}"
read -p "Choose an option: " choice
echo ""

case ${choice} in
    1)
        echo -e -n "${INFO_MSG}"
        read -p "Enter the path to the JSON config file: " json_file
        if [[ -z "${json_file}" || ! -f "${json_file}" ]]; then
            echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] Invalid or missing JSON file!"
            exit 1
        fi
        configure_ssh_port "${json_file}"
        ;;
    2) reset_firewall ;;
    3)
        echo -e -n "${INFO_MSG}"
        read -p "Enter the path to the JSON config file: " json_file
        if [[ -z "${json_file}" || ! -f "${json_file}" ]]; then
            echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] Invalid or missing JSON file!"
            exit 1
        fi
        apply_firewall_rules "${json_file}"
        ;;
    4) save_firewall_rules ;;
    5) show_firewall_rules ;;
    6)
        reset_firewall
        echo -e -n "${INFO_MSG}"
        read -p "Enter the path to the JSON config file: " json_file
        if [[ -z "${json_file}" || ! -f "${json_file}" ]]; then
            echo -e "${ERROR_MSG}[${WHITE}x${ENDCOLOR}] Invalid or missing JSON file!"
            exit 1
        fi
        apply_firewall_rules "${json_file}"
        save_firewall_rules
        show_firewall_rules
        ;;
    7) echo -e "${INFO_MSG}Exiting."; exit 0 ;;
    *) echo -e "${ERROR_MSG}Invalid option! Use -h for help."; exit 1 ;;
esac
