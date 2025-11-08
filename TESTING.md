# Testing

How to test and verify the OpenVPN server works.

## Quick Check

After installation, verify it's running:

```bash
# Check if port 1194 is listening
sudo ss -uln | grep 1194

# Check service status
sudo systemctl status openvpn@server
# or for Arch:
sudo systemctl status openvpn-server@server

# Run diagnostics
sudo ./scripts/troubleshoot.sh
```

## Performance Testing

### Check Optimizations

```bash
# Verify compression is enabled
grep "comp-lzo" /etc/openvpn/server.conf

# Check buffer sizes
grep "sndbuf\|rcvbuf" /etc/openvpn/server.conf

# Test connection speed (if you have iperf3)
iperf3 -c <server-ip> -p 5201
```

## Validation Checklist

- [ ] Server starts
- [ ] Port 1194 listening (UDP)
- [ ] Certificates valid
- [ ] Client can connect
- [ ] Internet works through VPN
- [ ] Compression active
- [ ] Firewall rules OK
- [ ] IP forwarding enabled

## If Something Doesn't Work

1. Run diagnostics: `sudo ./scripts/troubleshoot.sh`
2. Check logs: `sudo journalctl -u openvpn@server -n 50`
3. Verify certs: `sudo openssl verify -CAfile /etc/openvpn/ca.crt /etc/openvpn/server.crt`
4. Check firewall: `sudo iptables -L -n -v`

## Success = When You See

✅ Server listening on 1194  
✅ Client connects  
✅ Internet traffic goes through VPN  
✅ Compression working (check logs)  
✅ Stable connection  
