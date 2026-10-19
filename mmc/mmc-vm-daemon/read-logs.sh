#!/bin/bash

LOG_FILE="/var/log/mmc-vm.log"

if [ ! -f "$LOG_FILE" ]; then
    echo "Log file $LOG_FILE does not exist"
    exit 1
fi

tail -f "$LOG_FILE" 