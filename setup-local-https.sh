#!/bin/bash

# Local HTTPS Development Setup for Vite + Supabase
# This script sets up a secure local development environment using Caddy and mkcert
# Enables getUserMedia() and prevents mixed content issues

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LOCAL_DOMAIN_APP="app.local"
LOCAL_DOMAIN_API="api.local"
VITE_PORT=5173
SUPABASE_PORT=54321
CADDY_HTTP_PORT=8080
CADDY_HTTPS_PORT=8443

echo -e "${BLUE}🚀 Setting up Local HTTPS Development Environment${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""
echo -e "This will configure:"
echo -e "  • ${GREEN}Frontend (Vite):${NC} https://${LOCAL_DOMAIN_APP}:${CADDY_HTTPS_PORT}"
echo -e "  • ${GREEN}Backend (Supabase):${NC} https://${LOCAL_DOMAIN_API}:${CADDY_HTTPS_PORT}"
echo -e "  • ${GREEN}Certificate Authority:${NC} mkcert (trusted locally)"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get the local IP address
get_local_ip() {
    # Try different methods to get local IP
    if command_exists ip; then
        ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || echo "192.168.1.100"
    elif command_exists hostname; then
        hostname -I 2>/dev/null | awk '{print $1}' || echo "192.168.1.100"
    else
        echo "192.168.1.100"
    fi
}

LOCAL_IP=$(get_local_ip)
echo -e "${YELLOW}📍 Detected Local IP: ${LOCAL_IP}${NC}"
echo ""

# Detect OS and set package manager
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command_exists apt; then
            echo "ubuntu"
        elif command_exists yum; then
            echo "centos"
        elif command_exists pacman; then
            echo "arch"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
echo -e "${BLUE}🖥️  Detected OS: ${OS}${NC}"

# Install mkcert
install_mkcert() {
    echo -e "\n${YELLOW}📦 Installing mkcert...${NC}"
    
    case $OS in
        "ubuntu")
            if ! command_exists mkcert; then
                echo "Installing mkcert via apt..."
                sudo apt update
                sudo apt install -y libnss3-tools
                # Download latest mkcert binary
                curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
                chmod +x mkcert-v*-linux-amd64
                sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert
            fi
            ;;
        "macos")
            if ! command_exists mkcert; then
                if command_exists brew; then
                    brew install mkcert
                    brew install nss # for Firefox
                else
                    echo -e "${RED}❌ Homebrew not found. Please install Homebrew first.${NC}"
                    exit 1
                fi
            fi
            ;;
        "windows")
            if ! command_exists mkcert; then
                echo "Please install mkcert manually on Windows:"
                echo "1. Download from: https://github.com/FiloSottile/mkcert/releases"
                echo "2. Add to PATH"
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}❌ Unsupported OS for automatic mkcert installation${NC}"
            echo "Please install mkcert manually: https://github.com/FiloSottile/mkcert"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✅ mkcert installed successfully${NC}"
}

# Install Caddy
install_caddy() {
    echo -e "\n${YELLOW}📦 Installing Caddy...${NC}"
    
    case $OS in
        "ubuntu")
            if ! command_exists caddy; then
                echo "Installing Caddy via official script..."
                sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
                curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
                curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
                sudo apt update
                sudo apt install -y caddy
            fi
            ;;
        "macos")
            if ! command_exists caddy; then
                if command_exists brew; then
                    brew install caddy
                else
                    echo -e "${RED}❌ Homebrew not found. Please install Homebrew first.${NC}"
                    exit 1
                fi
            fi
            ;;
        "windows")
            if ! command_exists caddy; then
                echo "Please install Caddy manually on Windows:"
                echo "1. Download from: https://caddyserver.com/download"
                echo "2. Add to PATH"
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}❌ Unsupported OS for automatic Caddy installation${NC}"
            echo "Please install Caddy manually: https://caddyserver.com/docs/install"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✅ Caddy installed successfully${NC}"
}

# Setup mkcert CA and certificates
setup_certificates() {
    echo -e "\n${YELLOW}🔐 Setting up certificates...${NC}"
    
    # Create mkcert CA
    echo "Creating local Certificate Authority..."
    mkcert -install
    
    # Create certificates directory
    mkdir -p ./certs
    
    # Generate certificates for local domains and IP
    echo "Generating certificates for local domains..."
    mkcert -cert-file ./certs/local.crt -key-file ./certs/local.key \
        "${LOCAL_DOMAIN_APP}" \
        "${LOCAL_DOMAIN_API}" \
        "localhost" \
        "127.0.0.1" \
        "${LOCAL_IP}" \
        "*.local"
    
    echo -e "${GREEN}✅ Certificates generated successfully${NC}"
    echo -e "📁 Certificates saved to: ./certs/"
}

# Create Caddyfile
create_caddyfile() {
    echo -e "\n${YELLOW}⚙️  Creating Caddyfile...${NC}"
    
    cat > Caddyfile << EOF
# Local HTTPS Development Configuration
# Serves Vite frontend and Supabase backend over HTTPS

# Global options
{
    # Disable automatic HTTPS (we're using our own certs)
    auto_https off
    # Use custom ports to avoid conflicts
    http_port ${CADDY_HTTP_PORT}
    https_port ${CADDY_HTTPS_PORT}
    # Enable admin API for management
    admin localhost:2019
}

# Frontend (Vite) - HTTPS
https://${LOCAL_DOMAIN_APP}:${CADDY_HTTPS_PORT} {
    # Use our local certificates
    tls ./certs/local.crt ./certs/local.key
    
    # Proxy to Vite dev server
    reverse_proxy localhost:${VITE_PORT} {
        # Enable WebSocket support for Vite HMR
        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # Enable CORS for development
    header {
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Origin, Content-Type, Accept, Authorization"
        # Security headers for HTTPS
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "1; mode=block"
    }
    
    # Handle preflight requests
    @cors_preflight method OPTIONS
    respond @cors_preflight 200
    
    # Logging
    log {
        output file ./logs/frontend.log
        format single_field common_log
        level INFO
    }
}

# Backend (Supabase) - HTTPS
https://${LOCAL_DOMAIN_API}:${CADDY_HTTPS_PORT} {
    # Use our local certificates  
    tls ./certs/local.crt ./certs/local.key
    
    # Proxy to Supabase local instance
    reverse_proxy localhost:${SUPABASE_PORT} {
        # Preserve headers for Supabase
        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
        # Handle Supabase auth headers
        header_up Authorization {header.Authorization}
        header_up apikey {header.apikey}
    }
    
    # Enable CORS for API
    header {
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, PATCH, OPTIONS"
        Access-Control-Allow-Headers "Origin, Content-Type, Accept, Authorization, apikey, X-Client-Info"
        Access-Control-Expose-Headers "Content-Length, Content-Range"
        # Security headers
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
    }
    
    # Handle preflight requests
    @cors_preflight method OPTIONS
    respond @cors_preflight 200
    
    # Logging
    log {
        output file ./logs/backend.log
        format single_field common_log
        level INFO
    }
}

# HTTP to HTTPS redirect for frontend
http://${LOCAL_DOMAIN_APP}:${CADDY_HTTP_PORT} {
    redir https://${LOCAL_DOMAIN_APP}:${CADDY_HTTPS_PORT}{uri} permanent
}

# HTTP to HTTPS redirect for backend
http://${LOCAL_DOMAIN_API}:${CADDY_HTTP_PORT} {
    redir https://${LOCAL_DOMAIN_API}:${CADDY_HTTPS_PORT}{uri} permanent
}

# Serve a simple status page on default HTTP
:${CADDY_HTTP_PORT} {
    respond "Local HTTPS Development Server Running 🚀\n\nFrontend: https://${LOCAL_DOMAIN_APP}:${CADDY_HTTPS_PORT}\nBackend: https://${LOCAL_DOMAIN_API}:${CADDY_HTTPS_PORT}\n\nAccess from network: https://${LOCAL_IP}:${CADDY_HTTPS_PORT}" 200
}
EOF

    echo -e "${GREEN}✅ Caddyfile created successfully${NC}"
}

# Update hosts file
update_hosts() {
    echo -e "\n${YELLOW}🌐 Updating hosts file...${NC}"
    
    # Backup hosts file
    sudo cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)
    
    # Remove existing entries
    sudo sed -i "/${LOCAL_DOMAIN_APP}/d" /etc/hosts
    sudo sed -i "/${LOCAL_DOMAIN_API}/d" /etc/hosts
    
    # Add new entries
    echo "127.0.0.1 ${LOCAL_DOMAIN_APP}" | sudo tee -a /etc/hosts
    echo "127.0.0.1 ${LOCAL_DOMAIN_API}" | sudo tee -a /etc/hosts
    
    echo -e "${GREEN}✅ Hosts file updated${NC}"
    echo -e "📝 Added entries:"
    echo -e "   127.0.0.1 ${LOCAL_DOMAIN_APP}"
    echo -e "   127.0.0.1 ${LOCAL_DOMAIN_API}"
}

# Create environment files
create_env_files() {
    echo -e "\n${YELLOW}📄 Creating environment files...${NC}"
    
    # Create HTTPS environment file
    cat > .env.local << EOF
# Local HTTPS Development Configuration
# Generated by setup-local-https.sh

# HTTPS Supabase Configuration (via Caddy proxy)
PUBLIC_SUPABASE_URL=https://${LOCAL_DOMAIN_API}:${CADDY_HTTPS_PORT}
PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0

# Local development settings
VITE_APP_TITLE=POS System (Local HTTPS)
VITE_LOCAL_DEVELOPMENT=true
EOF

    # Create network access environment file
    cat > .env.local.network << EOF
# Network HTTPS Development Configuration
# For access from other devices on the local network

# HTTPS Supabase Configuration (via Caddy proxy)
PUBLIC_SUPABASE_URL=https://${LOCAL_IP}:${CADDY_HTTPS_PORT}
PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0

# Network development settings
VITE_APP_TITLE=POS System (Network HTTPS)
VITE_LOCAL_DEVELOPMENT=true
VITE_NETWORK_ACCESS=true
EOF

    echo -e "${GREEN}✅ Environment files created${NC}"
    echo -e "📁 Files created:"
    echo -e "   .env.local (localhost access)"
    echo -e "   .env.local.network (network access)"
}

# Create startup scripts
create_scripts() {
    echo -e "\n${YELLOW}📝 Creating startup scripts...${NC}"
    
    # Create logs directory
    mkdir -p logs
    
    # Create start script
    cat > start-https-dev.sh << 'EOF'
#!/bin/bash

# Start Local HTTPS Development Environment
# This script starts Caddy proxy and development servers

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Starting Local HTTPS Development Environment${NC}"
echo ""

# Check if required files exist
if [ ! -f "Caddyfile" ]; then
    echo -e "${RED}❌ Caddyfile not found. Run setup-local-https.sh first.${NC}"
    exit 1
fi

if [ ! -f ".env.local" ]; then
    echo -e "${RED}❌ .env.local not found. Run setup-local-https.sh first.${NC}"
    exit 1
fi

# Start Caddy in background
echo -e "${YELLOW}📡 Starting Caddy reverse proxy...${NC}"
caddy start --config Caddyfile

# Wait a moment for Caddy to start
sleep 2

# Check Caddy status
if caddy list | grep -q "caddy"; then
    echo -e "${GREEN}✅ Caddy started successfully${NC}"
else
    echo -e "${RED}❌ Failed to start Caddy${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 HTTPS Development Environment Ready!${NC}"
echo ""
echo -e "📍 Access URLs:"
echo -e "   Frontend: https://app.local:8443"
echo -e "   Backend:  https://api.local:8443"
echo -e "   Network:  https://$(hostname -I | awk '{print $1}'):8443"
echo ""
echo -e "🛠️  Development Commands:"
echo -e "   Start Vite: npm run dev"
echo -e "   Start Supabase: supabase start"
echo -e "   Stop Caddy: caddy stop"
echo ""
echo -e "${YELLOW}💡 Make sure Vite and Supabase are running on their default ports${NC}"
echo -e "   Vite: localhost:5173"
echo -e "   Supabase: localhost:54321"
EOF

    # Create stop script
    cat > stop-https-dev.sh << 'EOF'
#!/bin/bash

# Stop Local HTTPS Development Environment

echo "🛑 Stopping Caddy reverse proxy..."
caddy stop

echo "✅ HTTPS development environment stopped"
EOF

    # Create network switch script
    cat > switch-to-network-https.sh << 'EOF'
#!/bin/bash

# Switch to network HTTPS configuration

echo "🌐 Switching to network HTTPS configuration..."

if [ -f ".env.local.network" ]; then
    cp .env.local.network .env.local
    echo "✅ Switched to network HTTPS configuration"
    echo "📍 Other devices can now access: https://$(hostname -I | awk '{print $1}'):8443"
else
    echo "❌ .env.local.network not found"
    exit 1
fi
EOF

    # Create localhost switch script  
    cat > switch-to-localhost-https.sh << 'EOF'
#!/bin/bash

# Switch to localhost HTTPS configuration

echo "🏠 Switching to localhost HTTPS configuration..."

if [ -f ".env.local" ]; then
    # Restore localhost configuration
    sed -i 's|PUBLIC_SUPABASE_URL=https://.*:8443|PUBLIC_SUPABASE_URL=https://api.local:8443|g' .env.local
    echo "✅ Switched to localhost HTTPS configuration"
    echo "📍 Access via: https://app.local:8443"
else
    echo "❌ .env.local not found"
    exit 1
fi
EOF

    # Make scripts executable
    chmod +x start-https-dev.sh
    chmod +x stop-https-dev.sh
    chmod +x switch-to-network-https.sh
    chmod +x switch-to-localhost-https.sh
    
    echo -e "${GREEN}✅ Startup scripts created${NC}"
}

# Print mobile setup instructions
print_mobile_instructions() {
    echo -e "\n${BLUE}📱 Mobile Device Setup Instructions${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo ""
    echo -e "${YELLOW}To access the app from mobile devices and trust the certificates:${NC}"
    echo ""
    echo -e "${GREEN}📋 Step 1: Install mkcert CA on mobile devices${NC}"
    echo -e "1. Run: ${BLUE}mkcert -CAROOT${NC} to find CA location"
    echo -e "2. Copy rootCA.pem to your mobile device"
    echo -e "3. Install the certificate:"
    echo -e "   📱 iOS: Settings > General > VPN & Device Management > Install Profile"
    echo -e "   🤖 Android: Settings > Security > Install from storage"
    echo ""
    echo -e "${GREEN}📋 Step 2: Update mobile device hosts${NC}"
    echo -e "Option A - Router DNS (Recommended):"
    echo -e "1. Access your router admin panel"
    echo -e "2. Add DNS entries:"
    echo -e "   ${LOCAL_DOMAIN_APP} → ${LOCAL_IP}"
    echo -e "   ${LOCAL_DOMAIN_API} → ${LOCAL_IP}"
    echo ""
    echo -e "Option B - Device hosts file (Advanced):"
    echo -e "1. Use apps like 'Hosts Editor' (Android) or 'DNS Override' (iOS)"
    echo -e "2. Add entries:"
    echo -e "   ${LOCAL_IP} ${LOCAL_DOMAIN_APP}"
    echo -e "   ${LOCAL_IP} ${LOCAL_DOMAIN_API}"
    echo ""
    echo -e "${GREEN}📋 Step 3: Access the application${NC}"
    echo -e "1. Use network configuration: ${BLUE}./switch-to-network-https.sh${NC}"
    echo -e "2. Access via: ${BLUE}https://${LOCAL_DOMAIN_APP}:${CADDY_HTTPS_PORT}${NC}"
    echo -e "3. Or directly via IP: ${BLUE}https://${LOCAL_IP}:${CADDY_HTTPS_PORT}${NC}"
}

# Main execution
main() {
    echo -e "${YELLOW}🔍 Checking system requirements...${NC}"
    
    # Install required tools
    install_mkcert
    install_caddy
    
    # Setup certificates and configuration
    setup_certificates
    create_caddyfile
    update_hosts
    create_env_files
    create_scripts
    
    echo -e "\n${GREEN}🎉 Setup Complete!${NC}"
    echo -e "${GREEN}=================${NC}"
    echo ""
    echo -e "${YELLOW}📍 Quick Start:${NC}"
    echo -e "1. Start Supabase: ${BLUE}supabase start${NC}"
    echo -e "2. Start HTTPS proxy: ${BLUE}./start-https-dev.sh${NC}"
    echo -e "3. Start Vite: ${BLUE}npm run dev${NC}"
    echo -e "4. Open: ${BLUE}https://${LOCAL_DOMAIN_APP}:${CADDY_HTTPS_PORT}${NC}"
    echo ""
    echo -e "${YELLOW}🌐 Network Access:${NC}"
    echo -e "• Run: ${BLUE}./switch-to-network-https.sh${NC}"
    echo -e "• Access from other devices: ${BLUE}https://${LOCAL_IP}:${CADDY_HTTPS_PORT}${NC}"
    echo ""
    
    print_mobile_instructions
    
    echo -e "\n${GREEN}✅ Your offline HTTPS development environment is ready!${NC}"
    echo -e "${GREEN}   getUserMedia() will now work on all devices.${NC}"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 