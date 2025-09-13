# VPN Proxy

A HAProxy-based VPN proxy that forwards traffic to a foreign server supporting multiple protocols including VMess, VLESS, Trojan, and Shadowsocks.

## 🚀 Quick Install

```bash
# One-line installation and deployment
bash <(curl -s https://raw.githubusercontent.com/ikuriiruki/vpn-proxy/main/deploy.sh) clone && \
cd vpn-proxy && \
./deploy.sh deploy
```

[![GitHub](https://img.shields.io/badge/GitHub-ikuriiruki%2Fvpn--proxy-blue?style=flat&logo=github)](https://github.com/ikuriiruki/vpn-proxy)

## Features

-   **Multi-protocol support**: VMess (TCP/WebSocket), VLESS (TCP/gRPC Reality), Trojan WebSocket, Shadowsocks TCP
-   **HAProxy load balancing**: High-performance TCP proxy with health checks
-   **Docker deployment**: Easy containerized deployment
-   **Environment-based configuration**: Flexible port and server configuration
-   **Automated setup**: Easy deployment with dependency checking

## Prerequisites

-   Docker and Docker Compose
-   `gettext-base` package (for `envsubst` command)
-   Linux system with root privileges for Docker

### Installation on different systems:

**Ubuntu/Debian:**

```bash
sudo apt update
sudo apt install docker.io docker-compose-plugin gettext-base
sudo systemctl start docker
sudo systemctl enable docker
```

**CentOS/RHEL:**

```bash
sudo yum install docker docker-compose-plugin gettext
sudo systemctl start docker
sudo systemctl enable docker
```

**Arch Linux:**

```bash
sudo pacman -S docker docker-compose-plugin gettext
sudo systemctl start docker
sudo systemctl enable docker
```

## Quick Start

### Option 1: Direct Installation (Recommended)

**One-line installation and deployment:**

```bash
# Clone repository and deploy
bash <(curl -s https://raw.githubusercontent.com/ikuriiruki/vpn-proxy/main/deploy.sh) clone && \
cd vpn-proxy && \
./deploy.sh deploy

# If you want to install with a custom folder name
bash <(curl -s https://raw.githubusercontent.com/ikuriiruki/vpn-proxy/main/deploy.sh) clone my-proxy && \
cd my-proxy && \
./deploy.sh deploy
```

### Option 2: Manual Installation

1. **Clone this repository**

    ```bash
    git clone https://github.com/ikuriiruki/vpn-proxy
    cd vpn-proxy
    ```

2. **Run the deployment script**

    ```bash
    ./deploy.sh
    ```

3. **Configure your environment**

    - The script will create a `.env` file from the template
    - Edit the `.env` file with your foreign server IP and desired ports
    - The script will automatically open the file for editing

4. **Deploy the proxy**
    - The script will validate your configuration
    - Generate the HAProxy configuration
    - Deploy the proxy using Docker Compose

## Configuration

### Environment Variables

The `.env` file contains the following configuration options:

| Variable                           | Description                                   | Default                  |
| ---------------------------------- | --------------------------------------------- | ------------------------ |
| `FOREIGN_IP`                       | IP address of the foreign server to proxy to  | `your.foreign.server.ip` |
| `VMESS_TCP_INBOUND_PORT`           | Inbound port for VMess TCP protocol           | `8081`                   |
| `VMESS_TCP_OUTBOUND_PORT`          | Outbound port for VMess TCP protocol          | `8081`                   |
| `VMESS_WS_INBOUND_PORT`            | Inbound port for VMess WebSocket protocol     | `8000`                   |
| `VMESS_WS_OUTBOUND_PORT`           | Outbound port for VMess WebSocket protocol    | `8000`                   |
| `VLESS_TCP_REALITY_INBOUND_PORT`   | Inbound port for VLESS TCP Reality protocol   | `8443`                   |
| `VLESS_TCP_REALITY_OUTBOUND_PORT`  | Outbound port for VLESS TCP Reality protocol  | `8443`                   |
| `VLESS_GRPC_REALITY_INBOUND_PORT`  | Inbound port for VLESS gRPC Reality protocol  | `2053`                   |
| `VLESS_GRPC_REALITY_OUTBOUND_PORT` | Outbound port for VLESS gRPC Reality protocol | `2053`                   |
| `TROJAN_WS_INBOUND_PORT`           | Inbound port for Trojan WebSocket protocol    | `2083`                   |
| `TROJAN_WS_OUTBOUND_PORT`          | Outbound port for Trojan WebSocket protocol   | `2083`                   |
| `SHADOWSOCKS_TCP_INBOUND_PORT`     | Inbound port for Shadowsocks TCP protocol     | `1080`                   |
| `SHADOWSOCKS_TCP_OUTBOUND_PORT`    | Outbound port for Shadowsocks TCP protocol    | `1080`                   |

### HAProxy Configuration

The HAProxy configuration is automatically generated from the template (`haproxy.cfg.template`) using environment variables. The configuration includes:

-   Global settings with logging
-   Default TCP mode with appropriate timeouts
-   Frontend/backend pairs for each protocol
-   Health checks for backend servers
-   Host network mode for direct port binding

## Usage

### Installation Commands

```bash
# Clone repository with custom folder name
bash <(curl -s https://raw.githubusercontent.com/ikuriiruki/vpn-proxy/main/deploy.sh) clone my-proxy

# Quick install using dedicated installer
bash <(curl -s https://raw.githubusercontent.com/ikuriiruki/vpn-proxy/main/install.sh)
```

### Deployment Commands

```bash
# Deploy the proxy (default command)
./deploy.sh
./deploy.sh deploy

# Check proxy status
./deploy.sh status

# View proxy logs
./deploy.sh logs

# Stop the proxy
./deploy.sh stop

# Restart the proxy
./deploy.sh restart

# Show help
./deploy.sh help
```

### Manual Operations

If you prefer to run commands manually:

```bash
# Generate configuration
export $(cat .env | xargs)
envsubst < haproxy.cfg.template > haproxy.cfg

# Start the proxy
docker compose up -d

# Stop the proxy
docker compose down

# View logs
docker logs haproxy-proxy
```

## Architecture

```
Client → HAProxy (Local Server) → Foreign Server
        (Inbound Ports)         (Outbound Ports)
```

The proxy acts as a TCP load balancer that:

1. Listens on configured inbound ports for different protocols
2. Forwards traffic to the foreign server on corresponding outbound ports
3. Performs health checks on the backend server
4. Provides logging and monitoring capabilities

### Port Mapping Example

For VMess TCP protocol:

-   Client connects to: `your-proxy-server:8080` (inbound)
-   Proxy forwards to: `foreign-server:8081` (outbound)

This allows you to:

-   Use different ports locally vs remotely
-   Avoid port conflicts
-   Provide a clean interface to clients

## Troubleshooting

### Common Issues

1. **Permission denied when running deploy.sh**

    ```bash
    chmod +x deploy.sh
    ```

2. **Docker daemon not running**

    ```bash
    sudo systemctl start docker
    ```

3. **Port already in use**

    - Check if ports are already in use: `netstat -tulpn | grep :PORT`
    - Change ports in `.env` file and redeploy

4. **Foreign server unreachable**

    - Verify the `FOREIGN_IP` is correct
    - Check network connectivity: `ping FOREIGN_IP`
    - Ensure the foreign server is running the corresponding services

5. **Configuration not updating**
    - Regenerate config: `./deploy.sh deploy`
    - Check logs: `./deploy.sh logs`

### Logs and Monitoring

```bash
# View real-time logs
docker logs -f haproxy-proxy

# Check container status
docker ps -f name=haproxy-proxy

# Check port bindings
netstat -tulpn | grep haproxy
```

## Security Considerations

-   The proxy runs in host network mode for direct port access
-   Ensure your firewall is properly configured
-   Consider using fail2ban for additional protection
-   Regularly update Docker images for security patches

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source. Please check the license file for details.
