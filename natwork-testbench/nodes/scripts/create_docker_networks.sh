#!/bin/bash

# Nom et subnet des réseaux
NET="ddos-test-net"
SUBNET="10.10.10.0/24"

#NET_B="ddos-test_netB"
#SUBNET_B="10.20.20.0/24"

# Fonction pour créer un réseau si il n'existe pas déjà
create_network() {
  local net_name=$1
  local subnet=$2
  if docker network ls --format '{{.Name}}' | grep -wq "$net_name"; then
    echo "Le réseau $net_name existe déjà."
  else
    echo "Création du réseau $net_name avec subnet $subnet..."
    docker network create --subnet=$subnet $net_name
    echo "Réseau $net_name créé."
  fi
}

# Création des réseaux
create_network $NET $SUBNET
#create_network $NET_B $SUBNET_B

echo "Tous les réseaux sont prêts."
