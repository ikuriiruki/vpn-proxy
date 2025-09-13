#!/bin/bash

# VPN Proxy Quick Install Script
# This script can be run directly from GitHub using curl

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Main installation function
main() {
    local folder_name=${1:-"vpn-proxy"}
    
    print_status "VPN Proxy Quick Installer"
    print_status "Repository: https://github.com/ikuriiruki/vpn-proxy"
    echo
    
    check_dependencies
    clone_repository "$folder_name"
    
    print_success "Installation complete!"
    echo
    print_status "Next steps:"
    echo "  1. Configure your environment:"
    echo "     nano .env"
    echo
    echo "  2. Deploy the proxy:"
    echo "     ./deploy.sh deploy"
    echo
    print_status "For more information, run: ./deploy.sh help"
}

# Run main function with all arguments
main "$@"