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
    
tmpfile="$outfile.tmp"
(echo "$request"; sleep 5) | nc -w 20 "$ip_add" "$port_add" > "$tmpfile"

# nothing came back: server not running or unreachable
if [[ ! -s "$tmpfile" ]]; then
    echo "Error: no reply from server (is it running at $ip_add:$port_add?)"
    rm -f "$tmpfile"
    exit 1
fi

# server sent an error message instead of a file
if head -c 6 "$tmpfile" | grep -q "^Error"; then
    cat "$tmpfile"
    rm -f "$tmpfile"
    exit 1
fi

mv "$tmpfile" "$outfile"
echo "Saved reply to $outfile"
