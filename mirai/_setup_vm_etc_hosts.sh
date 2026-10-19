#!/bin/bash

HOSTS_LINE="127.0.0.1 cnc.changeme.com"

if grep -qF "$HOSTS_LINE" /etc/hosts; then
    echo "La ligne est déjà présente dans /etc/hosts."
else
    echo "$HOSTS_LINE" | sudo tee -a /etc/hosts > /dev/null
    echo "Ligne ajoutée dans /etc/hosts : $HOSTS_LINE"
fi
