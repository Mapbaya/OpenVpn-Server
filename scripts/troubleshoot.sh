#!/bin/bash

# Complete OpenVPN server diagnostics
# Usage: sudo ./scripts/troubleshoot.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
OPENVPN_DIR="/etc/openvpn"
EASY_RSA_DIR="/etc/openvpn/easy-rsa"
SERVER_NAME="server"

echo -e "${BLUE}=== OpenVPN Diagnostics ===${NC}\n"

# Function to display status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
    fi
}

# 1. Check service status
echo -e "${YELLOW}[1] OpenVPN Service Status${NC}"
if systemctl is-active --quiet openvpn@server || systemctl is-active --quiet openvpn-server@server; then
    echo -e "${GREEN}✓ Service active${NC}"
    systemctl status openvpn@server --no-pager -l 2>/dev/null | head -n 5 || systemctl status openvpn-server@server --no-pager -l | head -n 5
else
    echo -e "${RED}✗ Service inactive${NC}"
    echo -e "${YELLOW}  To start: sudo systemctl start openvpn@server${NC}"
fi
echo ""

# 2. Check configuration files
echo -e "${YELLOW}[2] Configuration Files${NC}"
[ -f "$OPENVPN_DIR/$SERVER_NAME.conf" ] && check_status "Server configuration exists" || echo -e "${RED}✗ Server configuration missing${NC}"
[ -f "$OPENVPN_DIR/ca.crt" ] && check_status "CA certificate exists" || echo -e "${RED}✗ CA certificate missing${NC}"
[ -f "$OPENVPN_DIR/server.crt" ] && check_status "Server certificate exists" || echo -e "${RED}✗ Server certificate missing${NC}"
[ -f "$OPENVPN_DIR/server.key" ] && check_status "Server key exists" || echo -e "${RED}✗ Server key missing${NC}"
[ -f "$OPENVPN_DIR/dh.pem" ] && check_status "DH parameters exist" || echo -e "${RED}✗ DH parameters missing${NC}"
[ -f "$OPENVPN_DIR/tls-auth.key" ] && check_status "TLS key exists" || echo -e "${RED}✗ TLS key missing${NC}"
[ -f "$OPENVPN_DIR/crl.pem" ] && check_status "CRL exists" || echo -e "${YELLOW}⚠ CRL missing (optional)${NC}"
echo ""

# 3. Validate certificates
echo -e "${YELLOW}[3] Certificate Validation${NC}"
if [ -f "$OPENVPN_DIR/server.crt" ] && [ -f "$OPENVPN_DIR/ca.crt" ]; then
    if openssl verify -CAfile "$OPENVPN_DIR/ca.crt" "$OPENVPN_DIR/server.crt" &> /dev/null; then
        echo -e "${GREEN}✓ Server certificate valid${NC}"
        CERT_EXPIRY=$(openssl x509 -in "$OPENVPN_DIR/server.crt" -noout -enddate | cut -d= -f2)
        echo -e "  Expiration: $CERT_EXPIRY"
    else
        echo -e "${RED}✗ Server certificate invalid${NC}"
    fi
else
    echo -e "${RED}✗ Cannot verify certificates${NC}"
fi
echo ""

# 4. Check listening port (1194/UDP)
echo -e "${YELLOW}[4] Listening Port (1194/UDP)${NC}"
if netstat -uln 2>/dev/null | grep -q ":1194 " || ss -uln 2>/dev/null | grep -q ":1194 "; then
    echo -e "${GREEN}✓ Port 1194 listening${NC}"
    (netstat -uln 2>/dev/null || ss -uln) | grep ":1194 "
else
    echo -e "${RED}✗ Port 1194 not listening${NC}"
fi
echo ""

# 5. Check IP forwarding
echo -e "${YELLOW}[5] IP Forwarding${NC}"
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ]; then
    echo -e "${GREEN}✓ IP forwarding enabled${NC}"
else
    echo -e "${RED}✗ IP forwarding disabled${NC}"
    echo -e "${YELLOW}  To enable: echo 1 > /proc/sys/net/ipv4/ip_forward${NC}"
fi
echo ""

# 6. Check firewall rules
echo -e "${YELLOW}[6] Firewall Rules${NC}"
if iptables -t nat -L POSTROUTING -n 2>/dev/null | grep -q "10.8.0.0/24"; then
    echo -e "${GREEN}✓ NAT rule for OpenVPN present${NC}"
else
    echo -e "${RED}✗ NAT rule missing${NC}"
fi

if iptables -L INPUT -n 2>/dev/null | grep -q "1194"; then
    echo -e "${GREEN}✓ INPUT rule for port 1194 present${NC}"
else
    echo -e "${YELLOW}⚠ INPUT rule for port 1194 missing${NC}"
fi
echo ""

# 7. Active connections
echo -e "${YELLOW}[7] Active Connections${NC}"
if [ -f "/var/log/openvpn/openvpn-status.log" ]; then
    echo -e "${GREEN}Connection status:${NC}"
    cat /var/log/openvpn/openvpn-status.log | head -n 20
else
    echo -e "${YELLOW}⚠ Status file not found${NC}"
    echo -e "  Check that server is configured to log status"
fi
echo ""

# 8. Recent logs
echo -e "${YELLOW}[8] Recent Logs (last 10 lines)${NC}"
if systemctl is-active --quiet openvpn@server || systemctl is-active --quiet openvpn-server@server; then
    journalctl -u openvpn@server -n 10 --no-pager 2>/dev/null || journalctl -u openvpn-server@server -n 10 --no-pager 2>/dev/null || echo -e "${YELLOW}Cannot read logs${NC}"
else
    echo -e "${YELLOW}Service inactive, no recent logs${NC}"
fi
echo ""

# 9. Test Internet connectivity
echo -e "${YELLOW}[9] Network Connectivity Test${NC}"
if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
    echo -e "${GREEN}✓ Internet connectivity OK${NC}"
else
    echo -e "${RED}✗ Internet connectivity problem${NC}"
fi
echo ""

# 10. Check TUN interface
echo -e "${YELLOW}[10] TUN Interface${NC}"
if ip link show tun0 &> /dev/null; then
    echo -e "${GREEN}✓ Interface tun0 active${NC}"
    ip addr show tun0 | grep inet
else
    echo -e "${YELLOW}⚠ Interface tun0 not active (normal if no clients connected)${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}=== Diagnostics Complete ===${NC}\n"
echo -e "${YELLOW}To see logs in real-time:${NC}"
echo -e "  sudo journalctl -u openvpn@server -f"
echo -e "\n${YELLOW}To restart service:${NC}"
echo -e "  sudo systemctl restart openvpn@server"
