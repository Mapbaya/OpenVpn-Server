#!/bin/bash

# Revoke a VPN client (disable access)
# Usage: sudo ./scripts/revoke-client.sh client-name

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

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Usage: $0 client-name${NC}"
    exit 1
fi

CLIENT_NAME="$1"

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

echo -e "${YELLOW}=== Revoking client: $CLIENT_NAME ===${NC}\n"

# Check certificate exists
if [ ! -f "$EASY_RSA_DIR/pki/issued/${CLIENT_NAME}.crt" ]; then
    echo -e "${RED}Error: Client certificate $CLIENT_NAME does not exist${NC}"
    exit 1
fi

# Revoke certificate
cd "$EASY_RSA_DIR"
./easyrsa --batch revoke "$CLIENT_NAME"

# Update CRL (Certificate Revocation List)
echo -e "${GREEN}Updating Certificate Revocation List (CRL)...${NC}"
./easyrsa gen-crl
cp "pki/crl.pem" "$OPENVPN_DIR/"
chmod 644 "$OPENVPN_DIR/crl.pem"

# Restart server to apply changes
if systemctl is-active --quiet openvpn@server || systemctl is-active --quiet openvpn-server@server; then
    echo -e "${GREEN}Restarting OpenVPN server...${NC}"
    systemctl restart openvpn@server 2>/dev/null || systemctl restart openvpn-server@server 2>/dev/null
fi

# Option: delete client configuration file
if [ -f "$CLIENTS_DIR/${CLIENT_NAME}.ovpn" ]; then
    read -p "Delete client configuration file? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$CLIENTS_DIR/${CLIENT_NAME}.ovpn"
        echo -e "${GREEN}Configuration file deleted${NC}"
    fi
fi

echo -e "\n${GREEN}=== Client $CLIENT_NAME revoked successfully! ===${NC}\n"
echo -e "${YELLOW}The client will no longer be able to connect to the VPN${NC}\n"
