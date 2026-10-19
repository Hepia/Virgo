#!/bin/bash

HOST="cnc.changeme.com"
PORT=23

# Vérifier si telnet est installé
if ! command -v telnet &> /dev/null; then
    echo "telnet non trouvé. Installation en cours..."
    sudo apt-get update
    sudo apt-get install -y telnet
    if [ $? -ne 0 ]; then
        echo "Échec de l'installation de telnet. Veuillez l'installer manuellement."
        exit 1
    fi
fi

echo "Test de connexion TCP vers $HOST:$PORT ..."

# Utilisation de telnet avec timeout (5 secondes)
timeout 5 telnet "$HOST" "$PORT" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "Connexion réussie vers $HOST:$PORT"
else
    echo "Échec de connexion vers $HOST:$PORT"
fi
