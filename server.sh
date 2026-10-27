#!/bin/bash

# package installation handling
declare -a packages
packages=(netcat-openbsd iproute2 curl html2text python3 py3-matplotlib)
for package in "${packages[@]}"; do
    apk info -e $package > /dev/null || { echo "downloading $package"; apk add $package; }
    done

serverIP=$(ifconfig eth0 | grep "inet" | awk '{print $2}' | awk -F: '{print $2}')
# echo "ip: $serverIP"
# ifconfig eth

pkill nc
first="true"

while true; do
    nc -lvn 1234 &
    nc_pid=$!

    if [[ "$first" == "true" ]]; then
        serverPort=$(ss -ltn | grep "LISTEN" | awk '{print $4}' | awk -F: '{print $NF}')
        # echo "port: $serverPort"
        echo "The server is running at Link addr:${serverIP}, port=${serverPort}"
        first="false"; fi
    sleep 1
    wait

done