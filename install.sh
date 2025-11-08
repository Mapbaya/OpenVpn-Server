#!/bin/bash

# Automatic OpenVPN server installation script
# Usage: sudo ./install.sh

set -e  # Exit on error

# Colors for messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== OpenVPN Server Installation ===${NC}\n"

# Check root privileges
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Use sudo${NC}"
    exit 1
fi

# Step 1: Install required software
echo -e "${GREEN}[1/4] Installing software...${NC}"

# Detect distribution and install packages
if command -v apt-get &> /dev/null; then
    # Debian/Ubuntu
    apt-get update -qq
    apt-get install -y openvpn easy-rsa iptables-persistent curl
elif command -v yum &> /dev/null; then
    # CentOS/RHEL
    yum install -y epel-release
    yum install -y openvpn easy-rsa iptables-services curl
elif command -v pacman &> /dev/null; then
    # Arch Linux
    pacman -S --noconfirm openvpn easy-rsa iptables curl
fi

# Step 2: Configure server
echo -e "${GREEN}[2/4] Configuring server...${NC}"

chmod +x scripts/*.sh
./scripts/setup-server.sh

# Step 3: Generate certificates
echo -e "${GREEN}[3/4] Generating certificates...${NC}"

# Generate CA (Certificate Authority)
./scripts/generate-ca.sh

# Generate server certificate
./scripts/generate-ca.sh server

# Step 4: Start server
echo -e "${GREEN}[4/4] Starting server...${NC}"

# Create log directory with proper permissions
mkdir -p /var/log/openvpn
chown openvpn:network /var/log/openvpn 2>/dev/null || chmod 755 /var/log/openvpn

# Start server (depending on distribution)
if systemctl list-unit-files | grep -q "openvpn-server@"; then
    # Arch Linux
    systemctl start openvpn-server@server || echo -e "${YELLOW}systemd failed, manual start required${NC}"
    systemctl enable openvpn-server@server 2>/dev/null || true
else
    # Debian/Ubuntu
    systemctl start openvpn@server || echo -e "${YELLOW}systemd failed, manual start required${NC}"
    systemctl enable openvpn@server 2>/dev/null || true
fi

echo -e "\n${GREEN}✅ Installation complete!${NC}\n"
echo -e "${YELLOW}Create a client: sudo ./scripts/create-client.sh client-name${NC}"
echo -e "${YELLOW}If server didn't start: sudo openvpn --config /etc/openvpn/server.conf --daemon${NC}\n"
