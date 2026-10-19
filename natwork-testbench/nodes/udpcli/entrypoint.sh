#!/bin/sh
echo "Starting UDP client to ${HOST_IP}:${HOST_PORT}..."
exec python3 /app/client_udp.py
