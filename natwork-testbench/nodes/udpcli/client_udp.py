import socket
import time
import json
import os

# Load configuration from JSON
with open("/app/config.json") as f:
    config = json.load(f)

HOST_IP = config["host_ip"]
HOST_PORT = config["host_port"]

# Get hostname
HOSTNAME = os.uname().nodename  # alternative: open("/etc/hostname").read().strip()

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

i = 0
while True:
    message = f"[{HOSTNAME}] Message {i}"
    sock.sendto(message.encode(), (HOST_IP, HOST_PORT))
    print(f"Sent: {message}", flush=True)  # flush=True for live display
    i += 1
    time.sleep(1)
