declare -a packages
packages=(netcat-openbsd iproute2 curl html2text python3 py3-matplotlib)
for package in "${packages[@]}"; do
    apk info -e $package > /dev/null || echo "downloading $package"; apk add $package
    done

clientIP=$(ifconfig eth0 | grep "inet addr" | awk '{print $2}' | awk -F: '{print $2}')
echo $clientIP
# ifconfig eth