#!/bin/bash

# VPN Proxy Deployment Script
# This script sets up the environment and deploys the HAProxy VPN proxy

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root for security reasons"
        print_status "Please run as a regular user with sudo privileges"
        exit 1
    fi
}

# Function to clone repository
clone_repository() {
    local repo_url="https://github.com/ikuriiruki/vpn-proxy"
    local folder_name=${1:-"vpn-proxy"}
    
    if [ -d "$folder_name" ]; then
        print_warning "Directory '$folder_name' already exists"
        print_status "Updating existing repository..."
        cd "$folder_name"
        git pull origin main
        cd - > /dev/null
    else
        print_status "Cloning repository to '$folder_name'..."
        if git clone "$repo_url" "$folder_name"; then
            print_success "Repository cloned successfully"
        else
            print_error "Failed to clone repository"
            print_status "Make sure git is installed and you have internet access"
            exit 1
        fi
    fi
    
    # Change to the project directory
    cd "$folder_name"
    print_status "Changed to project directory: $(pwd)"
}

# Function to check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command_exists docker; then
        missing_deps+=("docker")
    fi
    
    if ! command_exists docker-compose; then
        missing_deps+=("docker-compose")
    fi
    
    if ! command_exists envsubst; then
        missing_deps+=("gettext-base")
    fi
    
    if ! command_exists git; then
        missing_deps+=("git")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_status "Please install them using your package manager:"
        print_status "  Ubuntu/Debian: sudo apt update && sudo apt install docker.io docker-compose gettext-base git"
        print_status "  CentOS/RHEL: sudo yum install docker docker-compose gettext git"
        print_status "  Arch Linux: sudo pacman -S docker docker-compose gettext git"
        exit 1
    fi
    
    print_success "All dependencies are installed"
}

# Function to setup environment file
setup_environment() {
    print_status "Setting up environment configuration..."
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            print_status "Creating .env file from example..."
            cp .env.example .env
        else
            print_status "Creating .env file with default values..."
            cat > .env << EOF
# VPN Proxy Configuration
# Foreign server IP address (the server you're proxying to)
FOREIGN_IP=your.foreign.server.ip

# Inbound ports (ports this proxy listens on)
VMESS_TCP_INBOUND_PORT=8080
VMESS_WS_INBOUND_PORT=8081
VLESS_TCP_REALITY_INBOUND_PORT=8443
VLESS_GRPC_REALITY_INBOUND_PORT=2053
TROJAN_WS_INBOUND_PORT=2083
SHADOWSOCKS_TCP_INBOUND_PORT=1080

# Outbound ports (ports on the foreign server)
VMESS_TCP_OUTBOUND_PORT=8081
VMESS_WS_OUTBOUND_PORT=8000
VLESS_TCP_REALITY_OUTBOUND_PORT=8443
VLESS_GRPC_REALITY_OUTBOUND_PORT=2053
TROJAN_WS_OUTBOUND_PORT=2083
SHADOWSOCKS_TCP_OUTBOUND_PORT=1080
EOF
        fi
        
        print_warning "Please edit .env file with your actual configuration values"
        print_status "Opening .env file for editing..."
        
        # Try to open with common editors
        if command_exists nano; then
            nano .env
        elif command_exists vim; then
            vim .env
        elif command_exists vi; then
            vi .env
        else
            print_status "Please edit .env file manually with your preferred editor"
        fi
    else
        print_success ".env file already exists"
    fi
}

# Function to validate environment
validate_environment() {
    print_status "Validating environment configuration..."
    
    # Source the .env file
    set -a
    source .env
    set +a
    
    # Check if FOREIGN_IP is set and not the default
    if [ -z "$FOREIGN_IP" ] || [ "$FOREIGN_IP" = "your.foreign.server.ip" ]; then
        print_error "FOREIGN_IP is not properly configured in .env file"
        print_status "Please set FOREIGN_IP to your actual foreign server IP address"
        exit 1
    fi
    
    # Validate IP format (basic check)
    if ! [[ $FOREIGN_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        print_warning "FOREIGN_IP format might be invalid: $FOREIGN_IP"
        print_status "Please ensure it's a valid IPv4 address"
    fi
    
    # Check if all required ports are set
    local required_inbound_ports=("VMESS_TCP_INBOUND_PORT" "VMESS_WS_INBOUND_PORT" "VLESS_TCP_REALITY_INBOUND_PORT" "VLESS_GRPC_REALITY_INBOUND_PORT" "TROJAN_WS_INBOUND_PORT" "SHADOWSOCKS_TCP_INBOUND_PORT")
    local required_outbound_ports=("VMESS_TCP_OUTBOUND_PORT" "VMESS_WS_OUTBOUND_PORT" "VLESS_TCP_REALITY_OUTBOUND_PORT" "VLESS_GRPC_REALITY_OUTBOUND_PORT" "TROJAN_WS_OUTBOUND_PORT" "SHADOWSOCKS_TCP_OUTBOUND_PORT")
    
    for port_var in "${required_inbound_ports[@]}"; do
        if [ -z "${!port_var}" ]; then
            print_error "$port_var is not set in .env file"
            exit 1
        fi
    done
    
    for port_var in "${required_outbound_ports[@]}"; do
        if [ -z "${!port_var}" ]; then
            print_error "$port_var is not set in .env file"
            exit 1
        fi
    done
    
    print_success "Environment configuration is valid"
}

# Function to generate HAProxy configuration
generate_config() {
    print_status "Generating HAProxy configuration..."
    
    if [ ! -f "haproxy.cfg.template" ]; then
        print_error "haproxy.cfg.template not found"
        exit 1
    fi
    
    # Source environment variables
    set -a
    source .env
    set +a
    
    # Generate configuration using envsubst
    envsubst < haproxy.cfg.template > haproxy.cfg
    
    if [ $? -eq 0 ]; then
        print_success "HAProxy configuration generated successfully"
        print_status "Configuration summary:"
        echo "  Foreign server: $FOREIGN_IP"
        echo "  VMess TCP: $VMESS_TCP_INBOUND_PORT -> $VMESS_TCP_OUTBOUND_PORT"
        echo "  VMess WS: $VMESS_WS_INBOUND_PORT -> $VMESS_WS_OUTBOUND_PORT"
        echo "  VLESS TCP Reality: $VLESS_TCP_REALITY_INBOUND_PORT -> $VLESS_TCP_REALITY_OUTBOUND_PORT"
        echo "  VLESS gRPC Reality: $VLESS_GRPC_REALITY_INBOUND_PORT -> $VLESS_GRPC_REALITY_OUTBOUND_PORT"
        echo "  Trojan WS: $TROJAN_WS_INBOUND_PORT -> $TROJAN_WS_OUTBOUND_PORT"
        echo "  Shadowsocks TCP: $SHADOWSOCKS_TCP_INBOUND_PORT -> $SHADOWSOCKS_TCP_OUTBOUND_PORT"
    else
        print_error "Failed to generate HAProxy configuration"
        exit 1
    fi
}

# Function to check if Docker daemon is running
check_docker() {
    print_status "Checking Docker daemon..."
    
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running"
        print_status "Please start Docker daemon:"
        print_status "  sudo systemctl start docker"
        print_status "  sudo systemctl enable docker"
        exit 1
    fi
    
    print_success "Docker daemon is running"
}

# Function to deploy the proxy
deploy_proxy() {
    print_status "Deploying VPN proxy..."
    
    # Stop existing container if running
    if docker ps -q -f name=haproxy-proxy | grep -q .; then
        print_status "Stopping existing proxy container..."
        docker stop haproxy-proxy
    fi
    
    # Remove existing container if it exists
    if docker ps -aq -f name=haproxy-proxy | grep -q .; then
        print_status "Removing existing proxy container..."
        docker rm haproxy-proxy
    fi
    
    # Start the proxy using docker-compose
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        print_success "VPN proxy deployed successfully"
    else
        print_error "Failed to deploy VPN proxy"
        exit 1
    fi
}

# Function to show status
show_status() {
    print_status "Checking proxy status..."
    
    if docker ps -q -f name=haproxy-proxy | grep -q .; then
        print_success "Proxy is running"
        echo
        print_status "Container details:"
        docker ps -f name=haproxy-proxy --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo
        print_status "Proxy is listening on the following ports:"
        source .env
        echo "  VMess TCP: $VMESS_TCP_INBOUND_PORT -> $FOREIGN_IP:$VMESS_TCP_OUTBOUND_PORT"
        echo "  VMess WebSocket: $VMESS_WS_INBOUND_PORT -> $FOREIGN_IP:$VMESS_WS_OUTBOUND_PORT"
        echo "  VLESS TCP Reality: $VLESS_TCP_REALITY_INBOUND_PORT -> $FOREIGN_IP:$VLESS_TCP_REALITY_OUTBOUND_PORT"
        echo "  VLESS gRPC Reality: $VLESS_GRPC_REALITY_INBOUND_PORT -> $FOREIGN_IP:$VLESS_GRPC_REALITY_OUTBOUND_PORT"
        echo "  Trojan WebSocket: $TROJAN_WS_INBOUND_PORT -> $FOREIGN_IP:$TROJAN_WS_OUTBOUND_PORT"
        echo "  Shadowsocks TCP: $SHADOWSOCKS_TCP_INBOUND_PORT -> $FOREIGN_IP:$SHADOWSOCKS_TCP_OUTBOUND_PORT"
    else
        print_warning "Proxy is not running"
    fi
}

# Function to show logs
show_logs() {
    print_status "Showing proxy logs..."
    docker logs haproxy-proxy
}

# Function to stop the proxy
stop_proxy() {
    print_status "Stopping VPN proxy..."
    docker-compose down
    print_success "VPN proxy stopped"
}

# Function to restart the proxy
restart_proxy() {
    print_status "Restarting VPN proxy..."
    docker-compose restart
    print_success "VPN proxy restarted"
}

# Function to show help
show_help() {
    echo "VPN Proxy Deployment Script"
    echo
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  clone [folder]  Clone the repository (optional folder name)"
    echo "  deploy          Deploy the VPN proxy (default)"
    echo "  stop            Stop the VPN proxy"
    echo "  restart         Restart the VPN proxy"
    echo "  status          Show proxy status"
    echo "  logs            Show proxy logs"
    echo "  help            Show this help message"
    echo
    echo "Examples:"
    echo "  $0 clone                    # Clone to 'vpn-proxy' folder"
    echo "  $0 clone my-proxy           # Clone to 'my-proxy' folder"
    echo "  $0 deploy                   # Deploy the proxy"
    echo "  $0 status                   # Check status"
    echo "  $0 logs                     # View logs"
    echo
    echo "Quick start from GitHub:"
    echo "  bash <(curl -s https://raw.githubusercontent.com/ikuriiruki/vpn-proxy/main/deploy.sh) clone"
    echo "  bash <(curl -s https://raw.githubusercontent.com/ikuriiruki/vpn-proxy/main/deploy.sh) deploy"
}

# Main function
main() {
    local command=${1:-deploy}
    local folder_name=${2:-"vpn-proxy"}
    
    case $command in
        clone)
            check_dependencies
            clone_repository "$folder_name"
            print_success "Repository ready! Run './deploy.sh deploy' to start deployment"
            ;;
        deploy)
            check_root
            check_dependencies
            setup_environment
            validate_environment
            generate_config
            check_docker
            deploy_proxy
            show_status
            ;;
        stop)
            stop_proxy
            ;;
        restart)
            restart_proxy
            show_status
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"