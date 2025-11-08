# OpenVPN Server

Personal project: Secure OpenVPN server with SSL/TLS certificate management, client configuration, and troubleshooting tools.

## Installation

```bash
sudo ./install.sh
```

That's it! The script installs and configures everything automatically.

## Usage

### Create a client

```bash
sudo ./scripts/create-client.sh client-name
```

The `.ovpn` file is created in `/etc/openvpn/clients/client-name.ovpn`

### Revoke a client

```bash
sudo ./scripts/revoke-client.sh client-name
```

### Troubleshooting

```bash
sudo ./scripts/troubleshoot.sh
```

## What I optimized

I added several network optimizations to improve performance:

- **UDP protocol**: Faster than TCP, less latency
- **Adaptive compression**: Saves 20-40% bandwidth on compressible data
- **Larger buffers**: 393KB instead of default 64KB for better throughput
- **Optimized keepalive**: Keeps connections stable
- **Modern encryption**: AES-256-GCM with TLS 1.2+

These optimizations work well in practice - I've tested and used this server myself.

## Project Structure

```
openvpn-server/
├── install.sh              # Main installation script
├── scripts/
│   ├── setup-server.sh     # Server setup
│   ├── generate-ca.sh     # Certificate generation
│   ├── create-client.sh   # Create clients
│   ├── revoke-client.sh   # Revoke clients
│   └── troubleshoot.sh     # Diagnostics
└── config/
    ├── server.conf         # Server config
    └── client-template.conf # Client template
```

## Requirements

- Linux (Debian/Ubuntu, CentOS/RHEL, or Arch Linux)
- Root/sudo access
- Internet connection

## Notes

Certificates are generated automatically. Server listens on port 1194 (UDP) by default.

---

Personal learning project in system administration and networking.
