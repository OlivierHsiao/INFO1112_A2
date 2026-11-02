#!/bin/bash

if [[ -z "$1" ]]; then
    echo "Usage: bash client.sh <request> [server_ip] [port]"
    exit 1; fi
    
request="$1"
ip_add="${2:-172.17.0.2}"
port_add="${3:-1234}"

case $request in 
    assignment) outfile="assignment.json";;
    population) outfile="population.png";;
    *) outfile=poi.json ;;
esac
    
(echo "$request"; sleep 1) | nc -w 5 "$ip_add" "$port_add" > "$outfile"
