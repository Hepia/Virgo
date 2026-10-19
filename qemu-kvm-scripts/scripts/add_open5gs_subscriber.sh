#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

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

# Global config
# URL of Open5GS WebUI API endpoint
API_PORT="3000"
API_URL="http://localhost:${API_PORT}/api/subscriber"
# Authentication Management Field - used in 3GPP AKA authentication
AMF="8000"

# Function to add a subscriber via Open5GS WebUI API
add_open5gs_subscriber() {
    # International Mobile Subscriber Identity - unique ID of the SIM
    local IMSI="$1"
    # Mobile Station ISDN Number - the phone number associated with the SIM
    local MSISDN="$2"
    # Subscriber's secret key for authentication (hex)
    local KEY="$3"
    # Operator code (derived or actual), used in the AKA algorithm
    local OPC="$4"

    echo -e "${INFO_MSG}Adding subscriber: IMSI=${WHITE}${IMSI}${ENDCOLOR}, MSISDN=${WHITE}${MSISDN}${ENDCOLOR}"

    # Sent POST request and capture HTTP status code
    HTTP_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" -X POST "${API_URL}" \
    -H "Content-Type: application/json" \
    -d '{
      "imsi": "'"${IMSI}"'",
      "msisdn": "'"${MSISDN}"'",
      "security": {
        "k": "'"${KEY}"'",
        "opc": "'"${OPC}"'",
        "amf": "'"${AMF}"'"
      },
      "network": {
        "slice": [
          {
            "sst": 1,
            "sd": "010203"
          }
        ],
        "dnn": [
          {
            "dnn": "internet"
          }
        ]
      }
    }')

    # Extract body and HTTP status
    HTTP_BODY=$(echo "${HTTP_RESPONSE}" | sed -e 's/HTTPSTATUS\:.*//g')
    HTTP_STATUS=$(echo "${HTTP_RESPONSE}" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

    if [[ "${HTTP_STATUS}" -ge 200 && "${HTTP_STATUS}" -lt 300 ]]; then
        echo -e "${SUCCESS_MSG}Successfully added subscriber: ${WHITE}${IMSI}${ENDCOLOR}"
    else
        echo -e "${ERROR_MSG}Failed to add subscriber: ${WHITE}${IMSI}${ENDCOLOR}"
        echo -e "${ERROR_MSG}HTTP Status: ${WHITE}${HTTP_STATUS}${ENDCOLOR}"
        echo -e "${ERROR_MSG}Response   : ${WHITE}${HTTP_BODY}${ENDCOLOR}"
  fi
}

# Function to check if a new subscriber exists
subscriber_exists() {
    local IMSI="$1"

    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${API_URL}/${IMSI}")

    if [[ "${HTTP_STATUS}" == "200" ]]; then
        return 0  # Exists
    else
        return 1  # Does not exist
    fi
}

# Function to parse command-line options
parse_args() {
    local FORCE=0
    local DRY_RUN=0
    local HELP=0
    local JSON_FILE=""

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --force)
                FORCE=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --help)
                HELP=1
                shift
                ;;
            *)
                JSON_FILE="$1"
                shift
                ;;
        esac
    done

    if [[ "${HELP}" -eq 1 ]]; then
        show_help
        exit 0
    fi
}

# Show help message
show_help() {
    echo -e "Usage: $0 ${WHITE}[OPTIONS] subscribers.json${ENDCOLOR}"
    echo ""
    echo "OPTIONS:"
    echo -e "  ${WHITE}--force${ENDCOLOR}         Force adding a subscriber, even if it already exists"
    echo -e "  ${WHITE}--dry-run${ENDCOLOR}       Only display what would happen without making any changes"
    echo -e "  ${WHITE}--help${ENDCOLOR}          Show this help message"
    echo ""
    echo "Example usage:"
    echo -e "  $0 ${WHITE}subscribers.json${ENDCOLOR}           # Add subscribers (skip existing ones)"
    echo -e "  $0 ${WHITE}--force subscribers.json${ENDCOLOR}   # Add subscribers (overwrite existing ones)"
    echo -e "  $0 ${WHITE}--dry-run subscribers.json${ENDCOLOR} # Preview subscriber addition without changes"
}

# Check for jq
if ! command -v jq &> /dev/null; then
  echo -e "${ERROR_MSG}'${WHITE}jq${ENDCOLOR}' is required but not installed. Install it and try again."
  exit 1
fi

# Parse command-line arguments
parse_args "$@"

# Check input file
if [[ ! -f "${JSON_FILE}" ]]; then
    echo -e "${ERROR_MSG}JSON file not found: ${WHITE}${JSON_FILE}${ENDCOLOR}"
    echo ""
    show_help
    exit 1
fi

if ! jq empty "${JSON_FILE}" 2>/dev/null; then
    echo -e "${ERROR_MSG}Invalid JSON in file: ${WHITE}${JSON_FILE}${ENDCOLOR}"
    exit 1
fi

# Loop through JSON and add each subscriber
jq -c '.[]' "${JSON_FILE}" | while read -r entry; do
    IMSI=$(echo "${entry}" | jq -r '.imsi')
    MSISDN=$(echo "${entry}" | jq -r '.msisdn')
    KEY=$(echo "${entry}" | jq -r '.key')
    OPC=$(echo "${entry}" | jq -r '.opc')

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        echo -e "${INFO_MSG}[${YELLOW}DRY-RUN${ENDCOLOR}] Would check if subscriber exists: IMSI=${WHITE}${IMSI}${ENDCOLOR}"
    elif [[ "${FORCE}" -eq 1 || ! subscriber_exists "${IMSI}" ]]; then
        add_open5gs_subscriber "${IMSI}" "${MSISDN}" "${KEY}" "${OPC}"
    else
        echo -e "${WARNING_MSG}Subscriber already exists: ${WHITE}${IMSI}${ENDCOLOR} - skipping."
    fi
done
