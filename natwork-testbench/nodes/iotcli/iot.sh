#!/bin/bash
while true; do
  mosquitto_pub -h 192.168.20.102 -t test/topic -m "hello from IoT"
  sleep 5
done
