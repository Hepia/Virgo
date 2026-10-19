#!/usr/bin/env bash
set -euo pipefail

MTX_BIN="/usr/local/bin/mediamtx"
CFG="/etc/mediamtx.json"

cleanup() { kill $(jobs -p) 2>/dev/null || true; }
trap cleanup INT TERM EXIT

echo "Starting MediaMTX..."
"$MTX_BIN" "$CFG" &

echo "Waiting for port 8554..."
i=0
until nc -z 127.0.0.1 8554 2>/dev/null; do
  i=$((i+1)); [[ "$i" -gt 120 ]] && { echo "Timeout waiting for MediaMTX"; exit 1; }
  sleep 0.5
done
echo "MediaMTX ready."

# Playtime
play_min=15
play_max=30

# Sleeptime
sleep_min=30
sleep_max=60

while true; do
    playtime=$((play_min + RANDOM % (play_max - play_min + 1)))  # 15–30 sec
    sleeptime=$((sleep_min + RANDOM % (sleep_max - sleep_min + 1)))  # 30–60 sec

    echo "Starting stream for ${playtime}s..."
    ffmpeg -re -stream_loop -1 \
           -t "$playtime" \
           -i /videos/big_buck_bunny_1080p_stereo.avi \
           -vf format=yuv420p \
           -c:v libx264 -preset veryfast -tune zerolatency -g 50 \
           -c:a aac -ar 44100 -b:a 128k \
           -f rtsp rtsp://127.0.0.1:8554/mystream

    echo "Stream stopped, sleeping ${sleeptime}s..."
    sleep "$sleeptime"
done
