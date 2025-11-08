#!/bin/bash

# Automatic OpenVPN server configuration
# Usage: sudo ./scripts/setup-server.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
OPENVPN_DIR="/etc/openvpn"
EASY_RSA_DIR="/etc/openvpn/easy-rsa"
SERVER_NAME="server"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}=== OpenVPN Server Configuration ===${NC}\n"

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Install OpenVPN if needed
if ! command -v openvpn &> /dev/null; then
    echo -e "${YELLOW}OpenVPN is not installed. Installing...${NC}"
    apt-get update
    apt-get install -y openvpn easy-rsa iptables-persistent
fi

# Step 1/6: Create necessary directories
echo -e "${GREEN}[1/6] Creating directories...${NC}"
mkdir -p "$OPENVPN_DIR"
mkdir -p "$EASY_RSA_DIR"
mkdir -p "$OPENVPN_DIR/clients"
mkdir -p /var/log/openvpn
chown openvpn:network /var/log/openvpn 2>/dev/null || chmod 755 /var/log/openvpn

# Step 2/6: Configure Easy-RSA
if [ ! -d "$EASY_RSA_DIR/pki" ]; then
    echo -e "${GREEN}[2/6] Configuring Easy-RSA...${NC}"
    if [ -d "/usr/share/easy-rsa" ]; then
        cp -r /usr/share/easy-rsa/* "$EASY_RSA_DIR/"
    elif [ -d "/usr/local/share/easy-rsa" ]; then
        cp -r /usr/local/share/easy-rsa/* "$EASY_RSA_DIR/"
    elif [ -f "/usr/bin/easyrsa" ]; then
        # Arch Linux: create symlink to easyrsa
        mkdir -p "$EASY_RSA_DIR"
        ln -sf /usr/bin/easyrsa "$EASY_RSA_DIR/easyrsa"
        if [ -d "/etc/easy-rsa" ]; then
            cp -r /etc/easy-rsa/* "$EASY_RSA_DIR/" 2>/dev/null || true
        fi
    else
        echo -e "${YELLOW}Easy-RSA not found in standard locations${NC}"
        echo -e "${YELLOW}Please install easy-rsa or configure it manually${NC}"
    fi
fi

# Step 3/6: Generate Diffie-Hellman parameters (may take 5-10 min)
if [ ! -f "$OPENVPN_DIR/dh.pem" ]; then
    echo -e "${GREEN}[3/6] Generating Diffie-Hellman parameters (this may take a while)...${NC}"
    openssl dhparam -out "$OPENVPN_DIR/dh.pem" 2048
else
    echo -e "${YELLOW}Diffie-Hellman parameters already exist${NC}"
fi

# Step 4/6: Generate TLS key
if [ ! -f "$OPENVPN_DIR/tls-auth.key" ]; then
    echo -e "${GREEN}[4/6] Generating TLS key...${NC}"
    openvpn --genkey --secret "$OPENVPN_DIR/tls-auth.key"
else
    echo -e "${YELLOW}TLS key already exists${NC}"
fi

# Step 5/6: Copy server configuration
echo -e "${GREEN}[5/6] Configuring OpenVPN server...${NC}"
if [ -f "$PROJECT_ROOT/config/server.conf" ]; then
    cp "$PROJECT_ROOT/config/server.conf" "$OPENVPN_DIR/$SERVER_NAME.conf"
    echo -e "${GREEN}Server configuration copied${NC}"
else
    echo -e "${RED}Error: Server configuration file not found${NC}"
    exit 1
fi

# Step 6/6: Configure firewall
echo -e "${GREEN}[6/6] Configuring firewall...${NC}"

# Detect main network interface
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ -z "$INTERFACE" ]; then
    INTERFACE="eth0"
fi

# Enable IP forwarding (required for VPN)
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# iptables rules for OpenVPN
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$INTERFACE" -j MASQUERADE
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A OUTPUT -o tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -o "$INTERFACE" -j ACCEPT
iptables -A FORWARD -i "$INTERFACE" -o tun+ -j ACCEPT
iptables -A INPUT -p udp --dport 1194 -j ACCEPT

# Save rules
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save
elif command -v iptables-save &> /dev/null; then
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
fi

echo -e "\n${GREEN}=== Configuration complete! ===${NC}\n"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Generate CA: ${GREEN}sudo ./scripts/generate-ca.sh${NC}"
echo -e "2. Generate server certificate: ${GREEN}sudo ./scripts/generate-ca.sh server${NC}"
echo -e "3. Create clients: ${GREEN}sudo ./scripts/create-client.sh client-name${NC}"
echo -e "4. Start server: ${GREEN}sudo systemctl start openvpn@server${NC}"
echo -e "5. Enable auto-start: ${GREEN}sudo systemctl enable openvpn@server${NC}\n"
