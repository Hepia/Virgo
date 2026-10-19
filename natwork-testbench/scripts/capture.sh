#!/bin/bash
set -eu

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  -d <seconds>   Capture duration (default: unlimited)
  -s <snaplen>   Snap length, max bytes per packet (default: 0 = full packet)
  -o <file>      Output pcap file (default: capture_TIMESTAMP.pcap)
  -h, --help     Show this help message

Examples:
  $0 -d 60              # Capture for 60 seconds
  $0 -s 96              # Capture only first 96 bytes of each packet
  $0 -o mytrace.pcap    # Save capture to mytrace.pcap
EOF
}

# Default values
OUTFILE="capture_$(date +%Y%m%d_%H%M%S).pcap"
SNAPLEN=0
DURATION=0
IFACES=("eno2" "enx00e04c6801f0")

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -d) DURATION=$2; shift 2 ;;
    -s) SNAPLEN=$2; shift 2 ;;
    -o) OUTFILE=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

echo "Capturing on interfaces: ${IFACES[*]}"
echo "Output pcap file: $OUTFILE"
echo "Duration: $([[ $DURATION -eq 0 ]] && echo unlimited || echo ${DURATION}s)"
echo "Snaplen: $([[ $SNAPLEN -eq 0 ]] && echo full || echo $SNAPLEN bytes)"
echo "Format: legacy pcap (default in tcpdump 4.99.3)"

# Build tcpdump command
CMD="tcpdump -nn -s $SNAPLEN -w $OUTFILE"
for iface in "${IFACES[@]}"; do
    CMD="$CMD -i $iface"
done

# Run capture
if [ "$DURATION" -gt 0 ]; then
    echo "[*] Capturing for $DURATION seconds..."
    timeout "$DURATION" bash -c "$CMD"
else
    echo "[*] Capturing until interrupted..."
    bash -c "$CMD"
fi

echo "[+] Capture finished."
echo "Pcap saved to: $OUTFILE"
