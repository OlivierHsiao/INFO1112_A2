#!/bin/bash

handle_assignemnt(){
    local url=$1  #only in function
    echo "assignment branch"

        # download unit page and checke error
        curl -fsSL "$url" -o /tmp/unit.html
        if [[ $? -ne 0 ]]; then 
            echo "Error: could not download the unit page" >&2     # server screen
            echo "Error: could not download the unit page"         # client
        return; fi

        # convert to text
        html2text /tmp/unit.html > /tmp/unit.txt
        if [[ $? -ne 0 ]]; then 
            echo "Error: html2text failed" >&2
            echo "Error: html2text failed"
            return; fi

        # server display the rows
        block=$(grep -A 2 "Assignment 2" /tmp/unit.txt)
        echo "$block" >&2

        # extract
        line1=$(echo "$block" | sed -n 1p)
        line2=$(echo "$block" | sed -n 2p)
        line3=$(echo "$block" | sed -n 3p)
        title=$(echo "$line1" | awk -F '  +' '{print $2}')
        topic=$(echo "$line3" | awk -F '  +' '{print $2}')
        due_date="$(echo "$line1" | awk -F '  +' '{print $NF}' | awk -F': ' '{print $NF}') $(echo "$line2" | awk -F '  +' '{print $3}' | awk -F: '{print $1}') $(echo "$line3" | awk -F '  +' '{print $3}')"
        point=$(echo "$line2" | awk -F'  +' '{print $2}' | awk '{print $NF}' | awk -F '%' '{print $1}')

        # check emptiness
        if [[ -z "$title" || -z "$topic" || -z "$due_date" || -z "$point" ]]; then
            echo "Error: could not extract assignment details" >&2
            echo "Error: could not extract assignment details"
            return
        fi

        printf '{\n    "title" : "%s",\n    "topic" : "%s",\n    "due_date" : "%s",\n    "points" : %s\n}\n' \
            "$title" "$topic" "$due_date" "$point" > /tmp/assignment.json
        cat /tmp/assignment.json
}

# package installation handling
declare -a packages
packages=(netcat-openbsd iproute2 curl html2text python3 py3-matplotlib)
for package in "${packages[@]}"; do
    apk info -e $package > /dev/null || { echo "downloading $package"; apk add $package; }
    done

serverIP=$(ifconfig eth0 | grep "inet" | awk '{print $2}' | awk -F: '{print $2}')
# echo "ip: $serverIP"
# ifconfig eth

cleanup() {
    pkill -P $$ 2>/dev/null #kill every subprocess
    rm -f /tmp/reply
    exit
}
trap cleanup INT TERM

first="true"
PORT=1234

rm -f /tmp/reply
mkfifo /tmp/reply

while true; do
    nc -lvnN "$PORT" < /tmp/reply 2> /tmp/nc_log | {
        read -r request
        request=${request//$'\r'/}
        [[ -z "$request" ]] && exit  #skip empty request
        clientIP=$(grep "Connection received" /tmp/nc_log | awk '{print $4}')   # FIX: client IP
        echo "Connection received on $clientIP" >&2                     # FIX: >&2 → server screen
        echo "Request: $request" >&2

        case "$request" in
            assignment)
            handle_assignemnt "https://www.sydney.edu.au/units/INFO1112/2026-S2C-ND-CC"
        ;;
            population)
        echo "population branch (todo)"
        ;;
            *)
        echo "Error: unknown request '$request'"
        ;;
        esac
    } > /tmp/reply &
    nc_pid=$!

    sleep 1
    if [[ "$first" == "true" ]]; then
        serverPort=$(ss -ltn | grep "LISTEN" | awk '{print $4}' | awk -F: '{print $NF}')
        # echo "port: $serverPort"
        echo "The server is running at Link addr:${serverIP}, port=${serverPort}"
        first="false"; fi
    wait $nc_pid

done