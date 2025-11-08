#!/bin/bash

# Create a new VPN client
# Usage: sudo ./scripts/create-client.sh client-name [server-ip]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
EASY_RSA_DIR="/etc/openvpn/easy-rsa"
OPENVPN_DIR="/etc/openvpn"
CLIENTS_DIR="$OPENVPN_DIR/clients"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Usage: $0 client-name [server-ip]${NC}"
    exit 1
fi

CLIENT_NAME="$1"
# Auto-detect server IP if not provided
SERVER_IP="${2:-$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')}"

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Check CA exists
if [ ! -f "$EASY_RSA_DIR/pki/ca.crt" ]; then
    echo -e "${RED}Error: Certificate Authority does not exist.${NC}"
    echo -e "${YELLOW}Run first: sudo ./scripts/generate-ca.sh${NC}"
    exit 1
fi

# Generate server certificate if needed
if [ ! -f "$OPENVPN_DIR/server.crt" ]; then
    echo -e "${YELLOW}Server certificate does not exist. Generating...${NC}"
    "$SCRIPT_DIR/generate-ca.sh" server
fi

echo -e "${GREEN}=== Creating VPN client: $CLIENT_NAME ===${NC}\n"

# Step 1/4: Generate client certificate
if [ ! -f "$EASY_RSA_DIR/pki/issued/${CLIENT_NAME}.crt" ]; then
    echo -e "${GREEN}[1/4] Generating client certificate...${NC}"
    cd "$EASY_RSA_DIR"
    ./easyrsa --batch build-client-full "$CLIENT_NAME" nopass
else
    echo -e "${YELLOW}Client certificate already exists${NC}"
fi

mkdir -p "$CLIENTS_DIR"

# Step 2/4: Create .ovpn configuration file
echo -e "${GREEN}[2/4] Creating client configuration...${NC}"

CLIENT_CONFIG="$CLIENTS_DIR/${CLIENT_NAME}.ovpn"

# Use template if exists, otherwise create default config
if [ -f "$PROJECT_ROOT/config/client-template.conf" ]; then
    sed -e "s|{{SERVER_IP}}|$SERVER_IP|g" \
        -e "s|{{CLIENT_NAME}}|$CLIENT_NAME|g" \
        "$PROJECT_ROOT/config/client-template.conf" > "$CLIENT_CONFIG.tmp"
else
    cat > "$CLIENT_CONFIG.tmp" <<EOF
# OpenVPN configuration for $CLIENT_NAME
# Generated on $(date)

client
dev tun
proto udp
remote $SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
verb 3

# Network optimization
comp-lzo adaptive

# Encryption (must match server)
cipher AES-256-GCM
auth SHA256

# TLS
key-direction 1
tls-version-min 1.2

# Performance optimization
sndbuf 393216
rcvbuf 393216
EOF
fi

# Add certificates to file
echo "" >> "$CLIENT_CONFIG.tmp"
echo "# CA Certificate" >> "$CLIENT_CONFIG.tmp"
echo "<ca>" >> "$CLIENT_CONFIG.tmp"
cat "$OPENVPN_DIR/ca.crt" >> "$CLIENT_CONFIG.tmp"
echo "</ca>" >> "$CLIENT_CONFIG.tmp"
echo "" >> "$CLIENT_CONFIG.tmp"

echo "# Client Certificate" >> "$CLIENT_CONFIG.tmp"
echo "<cert>" >> "$CLIENT_CONFIG.tmp"
cat "$EASY_RSA_DIR/pki/issued/${CLIENT_NAME}.crt" >> "$CLIENT_CONFIG.tmp"
echo "</cert>" >> "$CLIENT_CONFIG.tmp"
echo "" >> "$CLIENT_CONFIG.tmp"

echo "# Client Private Key" >> "$CLIENT_CONFIG.tmp"
echo "<key>" >> "$CLIENT_CONFIG.tmp"
cat "$EASY_RSA_DIR/pki/private/${CLIENT_NAME}.key" >> "$CLIENT_CONFIG.tmp"
echo "</key>" >> "$CLIENT_CONFIG.tmp"
echo "" >> "$CLIENT_CONFIG.tmp"

echo "# TLS-Auth Key" >> "$CLIENT_CONFIG.tmp"
echo "<tls-auth>" >> "$CLIENT_CONFIG.tmp"
cat "$OPENVPN_DIR/tls-auth.key" >> "$CLIENT_CONFIG.tmp"
echo "</tls-auth>" >> "$CLIENT_CONFIG.tmp"

mv "$CLIENT_CONFIG.tmp" "$CLIENT_CONFIG"
chmod 600 "$CLIENT_CONFIG"

echo -e "${GREEN}[3/4] Client configuration created: $CLIENT_CONFIG${NC}"

# Step 4/4: Display summary
echo -e "${GREEN}[4/4] Summary${NC}"
echo -e "\n${YELLOW}Client created successfully!${NC}"
echo -e "Name: ${GREEN}$CLIENT_NAME${NC}"
echo -e "Configuration file: ${GREEN}$CLIENT_CONFIG${NC}"
echo -e "Server: ${GREEN}$SERVER_IP:1194${NC}"
echo -e "\n${YELLOW}To transfer file to client:${NC}"
echo -e "  scp $CLIENT_CONFIG user@client:/path/to/"
echo -e "\n${YELLOW}To install on client (Linux):${NC}"
echo -e "  sudo cp $CLIENT_CONFIG /etc/openvpn/client/"
echo -e "  sudo systemctl start openvpn@${CLIENT_NAME}"
echo -e "\n${GREEN}=== Client created successfully! ===${NC}\n"
