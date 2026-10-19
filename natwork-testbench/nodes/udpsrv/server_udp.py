import socket
import json
import sys

# Load configuration from JSON
with open("/app/config.json") as f:
    config = json.load(f)

UDP_IP = config["udp_ip"]
UDP_PORT = config["udp_port"]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((UDP_IP, UDP_PORT))
print(f"UDP server listening on {UDP_IP}:{UDP_PORT}", flush=True)

try:
    while True:
        data, addr = sock.recvfrom(1024)
        print(f"Received from {addr}: {data.decode()}", flush=True)
except KeyboardInterrupt:
    print("Server stopped", flush=True)
    sys.exit(0)
