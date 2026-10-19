#!/bin/bash

URL="rtsp://192.168.20.101:8554/mystream"

while true; do
  # Random playtime between 5 and 30 seconds
  playtime=$((5 + RANDOM % 26))

  echo "[CLIENT] Trying to play for ${playtime}s..."
  timeout $playtime ffplay -nodisp -autoexit "$URL" > /dev/null 2>&1

  # If ffplay fails (stream unavailable), wait a while before retrying.
  if [ $? -ne 0 ]; then
    echo "[CLIENT] Stream not available, retrying in 5s..."
    sleep 5
    continue
  fi

  # Random pause between 5 and 30 seconds
  sleeptime=$((5 + RANDOM % 26))
  echo "[CLIENT] Pausing for ${sleeptime}s..."
  sleep $sleeptime
done
