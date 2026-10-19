#!/bin/bash

# Define network interfaces
IF0="eno2"
IF1="enx00e04c6801f0"
NETA="192.168.10."
NETB="192.168.20."

# Run as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

echo "Updating and installing required packages..."
apt update
apt install -y isc-dhcp-server openssh-server tcpdump iproute2 net-tools

echo "Configuring network interfaces..."

cat <<EOF > /etc/network/interfaces.d/${IF0}.cfg
auto ${IF0}
iface ${IF0} inet static
    address "${NETA}1"
    netmask 255.255.255.0
EOF

cat <<EOF > /etc/network/interfaces.d/${IF1}.cfg
auto ${IF1}
iface ${IF1} inet static
    address "${NETB}1"
    netmask 255.255.255.0
EOF

echo "Configuring DHCP server..."

# Backup DHCP file if present
if [ -f /etc/dhcp/dhcpd.conf ]; then
  cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak.$(date +%s)
fi

cat <<EOF > /etc/dhcp/dhcpd.conf
default-lease-time 600;
max-lease-time 7200;
authoritative;

subnet "${NETA}0" netmask 255.255.255.0 {
    range "${NETA}100" "${NETA}200";
    option routers "${NETA}1";
    option domain-name-servers "${NETA}1";
}

subnet ${NETB}0 netmask 255.255.255.0 {
    range "${NETB}100" "${NETB}200";
    option routers "${NETB}1";
    option domain-name-servers "${NETB}1";
}
EOF

# Correct DHCP interfaces configuration
echo "INTERFACESv4=\"$IF0 $IF1\"" > /etc/default/isc-dhcp-server

echo "Enabling IP routing and proxy ARP..."

# IP routing
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-router.conf
sysctl -w net.ipv4.ip_forward=1

echo "Creating enable-proxyarp.sh script..."

# Create script to enable proxy ARP
cat <<EOF > /usr/local/sbin/enable-proxyarp.sh
#!/bin/bash
echo 1 > /proc/sys/net/ipv4/conf/${IF0}/proxy_arp
echo 1 > /proc/sys/net/ipv4/conf/${IF1}/proxy_arp
EOF

chmod +x /usr/local/sbin/enable-proxyarp.sh

echo "Creating systemd service for Proxy ARP..."

# Create systemd service
cat <<EOF > /etc/systemd/system/proxyarp.service
[Unit]
Description=Enable Proxy ARP on ${IF0} and ${IF1}
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/enable-proxyarp.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "Configuring SSH..."
systemctl enable ssh
systemctl start ssh

echo "Configuring packet capture permissions for user yoda..."

# Grant tcpdump capabilities
setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump

# Wireshark setup
dpkg-reconfigure -f noninteractive wireshark-common
usermod -aG wireshark yoda
setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap

echo "Packet capture configuration complete. User yoda can now run tcpdump and Wireshark without sudo."

echo "Enabling and restarting services..."

# Restart services and enable proxy ARP
systemctl daemon-reload
systemctl enable proxyarp.service
systemctl start proxyarp.service
systemctl restart networking
systemctl restart isc-dhcp-server

echo ""
echo "Configuration complete. Performing checks..."
echo "---------------------------------------------"

# Check 1: IP routing
ipfwd=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$ipfwd" -eq 1 ]; then
  echo "IP routing enabled (/proc/sys/net/ipv4/ip_forward = 1)"
else
  echo "IP routing not enabled!"
fi

# Check 2: Proxy ARP
parp_if0=$(cat /proc/sys/net/ipv4/conf/${IF0}/proxy_arp)
parp_if1=$(cat /proc/sys/net/ipv4/conf/${IF1}/proxy_arp)

if [ "$parp_if0" -eq 1 ] && [ "$parp_if1" -eq 1 ]; then
  echo "Proxy ARP enabled on ${IF0} and ${IF1}"
else
  echo "Proxy ARP disabled on one of the interfaces"
fi

# Check 3: Interface IPs
ip_if0=$(ip addr show ${IF0} | grep "inet " | awk '{print $2}')
ip_if1=$(ip addr show ${IF1} | grep "inet " | awk '{print $2}')

echo "${IF0} IP : $ip_if0"
echo "${IF1} IP : $ip_if1"

# Check 4: DHCP active
dhcp_status=$(systemctl is-active isc-dhcp-server)
if [ "$dhcp_status" = "active" ]; then
  echo "DHCP server is active"
else
  echo "DHCP server is inactive!"
fi

# Check 5: SSH active
ssh_status=$(systemctl is-active ssh)
if [ "$ssh_status" = "active" ]; then
  echo "SSH server is active"
else
  echo "SSH server is inactive!"
fi

echo "---------------------------------------------"
echo "Network configuration complete and verified."

exit 0
