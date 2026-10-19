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

# Function to list JSON files with numbering
list_json_files() {
    local folder="$1"
    local type="$2"

    echo -e "Listing ${type} JSON files in ${WHITE}${folder}${ENDCOLOR}:"
    echo ""
    files=()
    i=1

    # Loop through all .json files in the directory
    for file in "${folder}"/*.json; do
        # Check if the file is a symbolic link, and skip it if it is
        if [ ! -L "${file}" ]; then
            # Add the file to the list and display with numbering
            echo -e "${YELLOW}${i}${ENDCOLOR}. ${GREEN}$(basename "${file}")${ENDCOLOR}"
            files+=("${file}")
            ((i++))
        fi
    done

    echo
}

# Function to show current symbolic link targets
show_current_links() {
    local config_link_path="$1"
    local config_link_name="$2"
    local drivers_link_path="$3"
    local drivers_link_name="$4"
    local network_config_link_path="$5"
    local network_config_link_name="$6"

    echo "Current symbolic links:"
    echo ""

    # Show current target of config.json
    if [ -L "./${config_link_path}/${config_link_name}.json" ]; then
        config_link_target=$(readlink "./${config_link_path}/${config_link_name}.json")
        echo -e "${GREEN}${config_link_name}.json${ENDCOLOR} -> ${GREEN}${config_link_target}${ENDCOLOR}"
    else
        echo -e "${GREEN}${config_link_name}.json${ENDCOLOR} -> ${RED}No symbolic link exists${ENDCOLOR}"
    fi

    # Show current target of drivers.json
    if [ -L "./${drivers_link_path}/${drivers_link_name}.json" ]; then
        drivers_link_target=$(readlink "./${drivers_link_path}/${drivers_link_name}.json")
        echo -e "${GREEN}${drivers_link_name}.json${ENDCOLOR} -> ${GREEN}${drivers_link_target}${ENDCOLOR}"
    else
        echo -e "${GREEN}${drivers_link_name}.json${ENDCOLOR} -> ${RED}No symbolic link exists${ENDCOLOR}"
    fi

    # Show current target of network.json
    if [ -L "./${network_config_link_path}/${network_config_link_name}.json" ]; then
        network_config_link_target=$(readlink "./${network_config_link_path}/${network_config_link_name}.json")
        echo -e "${GREEN}${network_config_link_name}.json${ENDCOLOR} -> ${GREEN}${network_config_link_target}${ENDCOLOR}"
    else
        echo -e "${GREEN}${network_config_link_name}.json${ENDCOLOR} -> ${RED}No symbolic link exists${ENDCOLOR}"
    fi
}

# Modify the symbolic link interactively
modify_symlink() {
    local folder="$1"
    local type="$2"

    # List files for selection
    list_json_files "${folder}" "${type}"

    # Prompt user to select a new target for the symlink
    echo -e "Enter the number of the new ${WHITE}${type}.json${ENDCOLOR} file to link to (or 'q' to quit):"
    read choice
    echo

    # Validate the input and update the symlink if valid
    if [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#files[@]} )); then
        new_target=$(basename "${files[$((choice-1))]}")
        echo -e "Updating symbolic link to point to: ${GREEN}${new_target}${ENDCOLOR}"
        cd ./${folder}
        ln -snf "${new_target}" "${type}.json"
        cd -
    elif [[ "$choice" == "q" ]]; then
        echo "Quitting without changes."
    else
        echo -e "${RED}Invalid choice${ENDCOLOR}. Please try again."
    fi
}

# Main menu to modify the symlink in the config and driver folder
while true; do
    echo ""
    echo "Select an option:"
    echo ""
    echo -e "${YELLOW}1${ENDCOLOR}. Show current symbolic links"
    echo -e "${YELLOW}2${ENDCOLOR}. Modify ${WHITE}config.json${ENDCOLOR} link"
    echo -e "${YELLOW}3${ENDCOLOR}. Modify ${WHITE}drivers.json${ENDCOLOR} link"
    echo -e "${YELLOW}4${ENDCOLOR}. Modify ${WHITE}network.json${ENDCOLOR} link"
    echo -e "${YELLOW}5${ENDCOLOR}. Exit"
    echo ""
    echo -e -n "${INFO_MSG}"
    read -p "Enter your choice: " choice
    echo ""

    # Get the last part of the current directory
    dir_name="${PWD##*/}"

    case $choice in
        1)
            # Check the directory name and execute the corresponding command.
            case "${dir_name}" in
                scripts)
                    show_current_links "../config/vms" "config" "../config/drivers" "drivers" "../config/network" "network"
                    ;;
                qemu-kvm-scripts)
                    show_current_links "./config/vms" "config" "./config/drivers" "drivers" "./config/network" "network"
                    ;;
                *)
                    echo -e "${ERROR_MSG}Unrecognised directory '${WHITE}${dir_name}'${ENDCOLOR}" >&2
                    exit 1
                    ;;
            esac
            ;;
        2)
            # Check the directory name and execute the corresponding command.
            case "${dir_name}" in
                scripts)
                    modify_symlink "../config/vms" "config"
                    ;;
                qemu-kvm-scripts)
                    modify_symlink "./config/vms" "config"
                    ;;
                *)
                    echo -e "${ERROR_MSG}Unrecognised directory '${WHITE}${dir_name}'${ENDCOLOR}" >&2
                    exit 1
                    ;;
            esac
            ;;
        3)
            # Check the directory name and execute the corresponding command.
            case "${dir_name}" in
                scripts)
                    modify_symlink "../config/drivers" "drivers"
                    ;;
                qemu-kvm-scripts)
                    modify_symlink "./config/drivers" "drivers"
                    ;;
                *)
                    echo -e "${ERROR_MSG}Unrecognised directory '${WHITE}${dir_name}'${ENDCOLOR}" >&2
                    exit 1
                    ;;
            esac
            ;;
        4)
            # Check the directory name and execute the corresponding command.
            case "${dir_name}" in
                scripts)
                    modify_symlink "../config/network" "network"
                    ;;
                qemu-kvm-scripts)
                    modify_symlink "./config/network" "network"
                    ;;
                *)
                    echo -e "${ERROR_MSG}Unrecognised directory '${WHITE}${dir_name}'${ENDCOLOR}" >&2
                    exit 1
                    ;;
            esac
            ;;
        5)
            echo "Exiting."
            break
            ;;
        *)
            echo -e "${RED}Invalid choice${ENDCOLOR}. Please try again."
            ;;
    esac
done
