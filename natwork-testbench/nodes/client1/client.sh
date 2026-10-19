#!/bin/bash
# Neutraliser toute config proxy héritée
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY

URL="http://192.168.10.101:8080/index.html"

while true; do
  echo "[$(date)] Sending request to $URL ..."
  curl --http1.1 --no-keepalive --noproxy "*" \
       -H 'Cache-Control: no-cache' \
       -o /dev/null -s -w "HTTP %{http_code} in %{time_total}s\n" \
       "$URL"

  # Attente aléatoire 2–15 s
  delay=$((RANDOM % 14 + 2))
  echo "Sleeping for ${delay}s..."
  sleep "$delay"
done
