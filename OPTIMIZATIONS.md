# Network Optimizations

Here's what I optimized in the OpenVPN server configuration.

## What I Changed

### 1. Buffer Sizes
**Default**: 64KB buffers  
**My config**: 393216 bytes (384KB)  
**Why**: Larger buffers = better throughput, especially on high-speed connections. I noticed less packet loss with this.

```conf
sndbuf 393216
rcvbuf 393216
```

### 2. Compression
**Default**: No compression  
**My config**: Adaptive LZO compression  
**Why**: Saves bandwidth (20-40% on text/web traffic). Only compresses when it helps, so no CPU waste on already-compressed data.

```conf
comp-lzo adaptive
```

### 3. UDP Protocol
**Why**: UDP is faster than TCP for VPN. No handshake overhead, lower latency. Better for real-time stuff.

```conf
proto udp
```

### 4. Keepalive Settings
**My config**: 10s interval, 120s timeout  
**Why**: Keeps connections alive without being too aggressive. Prevents random disconnects.

```conf
keepalive 10 120
```

## Security Stuff

- **AES-256-GCM**: Modern encryption, hardware-accelerated
- **TLS 1.2+**: Secure handshake
- **TLS-Auth**: Extra protection against attacks
- **Certificate revocation**: Can revoke compromised certs

## Results

In practice, this gives:
- Better performance (compression saves bandwidth)
- Lower latency (UDP is faster)
- More stable connections (better keepalive)
- Higher throughput (bigger buffers)

I tested this and it works well for my use case.
