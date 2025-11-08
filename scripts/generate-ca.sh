#!/bin/bash

# Certificate generation (CA, server, clients)
# Usage: sudo ./scripts/generate-ca.sh [server|client-name]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
EASY_RSA_DIR="/etc/openvpn/easy-rsa"
OPENVPN_DIR="/etc/openvpn"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Check Easy-RSA is installed
if [ ! -f "$EASY_RSA_DIR/easyrsa" ]; then
    echo -e "${RED}Error: Easy-RSA is not configured. Run setup-server.sh first${NC}"
    exit 1
fi

cd "$EASY_RSA_DIR"

# Initialize PKI if needed
if [ ! -d "pki" ]; then
    echo -e "${GREEN}Initializing PKI (Public Key Infrastructure)...${NC}"
    ./easyrsa init-pki
    
    # Configure Easy-RSA variables
    if [ -f "$PROJECT_ROOT/easy-rsa/vars" ]; then
        cp "$PROJECT_ROOT/easy-rsa/vars" "$EASY_RSA_DIR/vars"
    else
        # Create default vars file
        cat > "$EASY_RSA_DIR/vars" <<EOF
set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "CA"
set_var EASYRSA_REQ_CITY       "San Francisco"
set_var EASYRSA_REQ_ORG        "OpenVPN-CA"
set_var EASYRSA_REQ_EMAIL      "admin@vpn.local"
set_var EASYRSA_REQ_OU         "IT"
set_var EASYRSA_KEY_SIZE       2048
set_var EASYRSA_ALGO           rsa
set_var EASYRSA_CURVE          secp384r1
set_var EASYRSA_DIGEST         "sha256"
EOF
    fi
    
    # Generate CA
    echo -e "${GREEN}Generating Certificate Authority (CA)...${NC}"
    ./easyrsa --batch build-ca nopass
    
    echo -e "${GREEN}CA generated successfully!${NC}"
fi

# Generate server or client certificate if requested
if [ -n "$1" ]; then
    CERT_NAME="$1"
    
    if [ "$CERT_NAME" = "server" ]; then
        echo -e "${GREEN}Generating server certificate...${NC}"
        
        if [ ! -f "pki/issued/server.crt" ]; then
            ./easyrsa --batch build-server-full server nopass
            
            # Copy certificates
            cp "pki/ca.crt" "$OPENVPN_DIR/"
            cp "pki/issued/server.crt" "$OPENVPN_DIR/"
            cp "pki/private/server.key" "$OPENVPN_DIR/"
            
            # Permissions
            chmod 600 "$OPENVPN_DIR/server.key"
            chmod 644 "$OPENVPN_DIR/server.crt"
            chmod 644 "$OPENVPN_DIR/ca.crt"
            
            echo -e "${GREEN}Server certificate generated and copied to $OPENVPN_DIR${NC}"
        else
            echo -e "${YELLOW}Server certificate already exists${NC}"
        fi
    else
        echo -e "${GREEN}Generating client certificate: $CERT_NAME...${NC}"
        
        if [ ! -f "pki/issued/${CERT_NAME}.crt" ]; then
            ./easyrsa --batch build-client-full "$CERT_NAME" nopass
            echo -e "${GREEN}Client certificate $CERT_NAME generated successfully!${NC}"
        else
            echo -e "${YELLOW}Client certificate $CERT_NAME already exists${NC}"
        fi
    fi
else
    echo -e "${GREEN}CA initialized. To generate server certificate:${NC}"
    echo -e "${YELLOW}sudo $0 server${NC}"
fi

# Update CRL (Certificate Revocation List)
echo -e "${GREEN}Updating Certificate Revocation List (CRL)...${NC}"
./easyrsa gen-crl
cp "pki/crl.pem" "$OPENVPN_DIR/"
chmod 644 "$OPENVPN_DIR/crl.pem"

echo -e "\n${GREEN}=== Operation complete! ===${NC}\n"
