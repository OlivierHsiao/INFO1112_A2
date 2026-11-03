#!/bin/bash

# AI Acknowledgment: Debugging help and code structure developed with assistance 
#                    from Claude (Anthropic); plotting code AI-generated as permitted.

handle_assignemnt(){
    local url="https://www.sydney.edu.au/units/INFO1112/2026-S2C-ND-CC" #only in function

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

handle_population(){

    # download population stat csv
    local url="https://dbr.abs.gov.au/processedData/csv/STE_1.csv"
    curl -fsSL "$url" -o /tmp/pop.csv

    # error message if fail
    if [[ $? -ne 0 ]]; then 
            echo "Error: could not download the population stats page" >&2     # server screen
            echo "Error: could not download the population stats page"         # client
        return; fi


    # extract population data and print latest
    header=$(head -n 1 /tmp/pop.csv | tr -d '\r')
    row=$(grep "^ERP_P_20," /tmp/pop.csv | head -n 1 | tr -d '\r')
    printf '%s\n%s\n' "$header" "$row" | awk -F, '
    NR==1 { for (i=4; i<=NF; i++) year[i]=$i; next }
    {for (i=4; i<=NF; i++) if ($i !="") print year[i] "," $i}' > /tmp/pop_data.csv
    latest=$(tail -n 1 /tmp/pop_data.csv)
    echo "$latest" | awk -F, '{print "latest ("$1") NSW population is "$2}' >&2

    # file emptiness check
    if [[ ! -s /tmp/pop_data.csv ]]; then
        echo "file is empty"
        return; fi
    
    # plot and output population.png
    cat > /tmp/plot.py << 'EOF'
# AI acknowledgment: this plotting code was generated with Claude (Anthropic),
# as permitted by the brief. Data is extracted with Bash in server.sh.
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

years, pops = [], []
with open(sys.argv[1]) as f:
    for line in f:
        y, p = line.strip().split(",")
        years.append(int(y))
        pops.append(int(p))

plt.plot(years, pops, marker="o")
plt.xlabel("Year")
plt.ylabel("Population")
plt.title("NSW Estimated Resident Population")
plt.xticks(years)
plt.tight_layout()
plt.savefig(sys.argv[2])
EOF

    if ! python3 /tmp/plot.py /tmp/pop_data.csv /tmp/population.png; then
        echo "Error: could not create population plot" >&2
        echo "Error: could not create population plot"
        return
    fi

    cat /tmp/population.png

}


handle_poi(){
    POI_API="https://maps1.six.nsw.gov.au/arcgis/rest/services/public/NSW_POI/MapServer/0/query"
    POI_RADIUS=500
    local query="$1"
    local lat lon name

    if [[ "$query" =~ ^-?[0-9]+(\.[0-9]+)?,-?[0-9]+(\.[0-9]+)?$ ]]; then
        # request is coordinates: "lat,lon"
        lat=${query%,*}
        lon=${query#*,}
        name="$query"
    else
        # request is a name: look it up
        name=$(echo "$query" | tr 'a-z' 'A-Z')     # dataset names are in capitals
        local safe=${name//\'/\'\'}                 # escape ' for the SQL query (e.g. ST MARY'S)

        # exact match first, then "contains"
        for where in "poiname = '$safe'" "poiname LIKE '%$safe%'"; do  # 1. exact match 2. contain match
            curl -fsS -G "$POI_API" \
                --data-urlencode "where=$where" \
                --data-urlencode "outFields=poiname,poitype" \
                --data-urlencode "returnGeometry=true" \
                --data-urlencode "outSR=4326" \
                --data-urlencode "f=json" -o /tmp/poi_lookup.json || break
            [[ $(jq '.features | length' /tmp/poi_lookup.json 2>/dev/null) -gt 0 ]] && break # if find something, break
        done

        # there is no match, return and print not found message
        if [[ $(jq '.features | length' /tmp/poi_lookup.json 2>/dev/null) -eq 0 ]] 2>/dev/null; then
            echo "Error: POI '$query' not found" >&2
            echo "Error: POI '$query' not found"
            return
        fi

        # extract name and position from the first match
        name=$(jq -r '.features[0].attributes.poiname' /tmp/poi_lookup.json)
        lat=$(jq -r '.features[0].geometry.y' /tmp/poi_lookup.json)
        lon=$(jq -r '.features[0].geometry.x' /tmp/poi_lookup.json)
    fi

    echo "POI: $name at ($lat, $lon), searching within ${POI_RADIUS} m" >&2

    # find neighbours
    if ! curl -fsS -G "$POI_API" \
        --data-urlencode "geometry=$lon,$lat" \
        --data-urlencode "geometryType=esriGeometryPoint" \
        --data-urlencode "inSR=4326" \
        --data-urlencode "distance=$POI_RADIUS" \
        --data-urlencode "units=esriSRUnit_Meter" \
        --data-urlencode "outFields=poiname,poitype" \
        --data-urlencode "returnGeometry=true" \
        --data-urlencode "outSR=4326" \
        --data-urlencode "f=json" -o /tmp/poi_near.json; then
        echo "Error: could not reach the NSW POI service" >&2
        echo "Error: could not reach the NSW POI service"
        return
    fi

    # build the result JSON (leave out the POI itself)
    if ! jq --arg q "$name" --argjson r "$POI_RADIUS" '
        {query: $q, radius_m: $r,
         neighbours: [.features[]
                      | select(.attributes.poiname != $q)
                      | {name: .attributes.poiname,
                         type: .attributes.poitype,
                         latitude: .geometry.y,
                         longitude: .geometry.x}]
                    | unique_by(.name)}
        | .count = (.neighbours | length)' /tmp/poi_near.json > /tmp/poi.json; then
        echo "Error: unexpected reply from the NSW POI service" >&2
        echo "Error: unexpected reply from the NSW POI service"
        return
    fi

    echo "Found $(jq '.count' /tmp/poi.json) neighbouring POIs" >&2
    cat /tmp/poi.json
}

# package installation handling
declare -a packages
packages=(netcat-openbsd iproute2 curl html2text python3 py3-matplotlib jq)
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
            handle_assignemnt
        ;;
            population)
            handle_population
        ;;
            *)
            handle_poi "$request"
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