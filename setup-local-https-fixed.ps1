# Local HTTPS Development Setup for Vite + Supabase (Windows PowerShell)
# This script sets up a secure local development environment using Caddy and mkcert
# Enables getUserMedia() and prevents mixed content issues

param(
    [switch]$SkipElevation,
    [switch]$Help
)

# Configuration
$LOCAL_DOMAIN_APP = "app.local"
$LOCAL_DOMAIN_API = "api.local" 
$VITE_PORT = 5173
$SUPABASE_PORT = 54321
$CADDY_HTTP_PORT = 8080
$CADDY_HTTPS_PORT = 8443

if ($Help) {
    Write-Host @"
Local HTTPS Development Setup for Windows

This script sets up a secure local development environment using Caddy and mkcert.
It enables getUserMedia() and prevents mixed content issues for offline POS systems.

USAGE:
    .\setup-local-https-fixed.ps1                 # Normal setup
    .\setup-local-https-fixed.ps1 -SkipElevation  # Skip admin elevation check

WHAT IT DOES:
    • Installs mkcert and Caddy via Chocolatey/Scoop
    • Generates trusted local SSL certificates  
    • Creates Caddy reverse proxy configuration
    • Updates Windows hosts file
    • Creates environment files and startup scripts
    • Configures HTTPS access for Vite and Supabase

ACCESS URLS:
    • Frontend: https://app.local:8443
    • Backend: https://api.local:8443
    • Network: https://[YOUR_IP]:8443

"@
    exit 0
}

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to restart as administrator
function Restart-AsAdministrator {
    if (-not $SkipElevation -and -not (Test-Administrator)) {
        Write-Host "🔒 This script requires administrator privileges to modify the hosts file." -ForegroundColor Yellow
        Write-Host "   Restarting as administrator..." -ForegroundColor Yellow
        
        $arguments = "-File `"$($MyInvocation.MyCommand.Path)`""
        if ($SkipElevation) { $arguments += " -SkipElevation" }
        
        Start-Process PowerShell -Verb RunAs -ArgumentList $arguments
        exit 0
    }
}

# Function to check if command exists
function Test-Command {
    param([string]$Command)
    try {
        if (Get-Command $Command -ErrorAction Stop) { return $true }
    } catch {
        return $false
    }
}

# Function to get local IP address
function Get-LocalIP {
    try {
        $ip = (Test-NetConnection -ComputerName "8.8.8.8" -Port 53).SourceAddress.IPAddress
        if ($ip) { return $ip }
    } catch {}
    
    try {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -match "^192\.168\.|^10\.|^172\." } | Select-Object -First 1).IPAddress
        if ($ip) { return $ip }
    } catch {}
    
    return "192.168.1.100"
}

# Colors for output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "🚀 Setting up Local HTTPS Development Environment" "Cyan"
Write-ColorOutput "=================================================" "Cyan"
Write-ColorOutput ""

$LOCAL_IP = Get-LocalIP
Write-ColorOutput "📍 Detected Local IP: $LOCAL_IP" "Yellow"
Write-ColorOutput ""

Write-ColorOutput "This will configure:" "White"
Write-ColorOutput "  • Frontend (Vite): https://$LOCAL_DOMAIN_APP`:$CADDY_HTTPS_PORT" "Green"
Write-ColorOutput "  • Backend (Supabase): https://$LOCAL_DOMAIN_API`:$CADDY_HTTPS_PORT" "Green"
Write-ColorOutput "  • Certificate Authority: mkcert (trusted locally)" "Green"
Write-ColorOutput ""

# Check for administrator privileges
Restart-AsAdministrator

# Install Chocolatey if not present
function Install-Chocolatey {
    if (-not (Test-Command "choco")) {
        Write-ColorOutput "📦 Installing Chocolatey..." "Yellow"
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-ColorOutput "✅ Chocolatey installed successfully" "Green"
    } else {
        Write-ColorOutput "✅ Chocolatey already installed" "Green"
    }
}

# Install mkcert
function Install-Mkcert {
    Write-ColorOutput "📦 Installing mkcert..." "Yellow"
    
    if (-not (Test-Command "mkcert")) {
        try {
            choco install mkcert -y
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-ColorOutput "✅ mkcert installed successfully" "Green"
        } catch {
            Write-ColorOutput "❌ Failed to install mkcert via Chocolatey" "Red"
            Write-ColorOutput "Please install manually from: https://github.com/FiloSottile/mkcert/releases" "Yellow"
            exit 1
        }
    } else {
        Write-ColorOutput "✅ mkcert already installed" "Green"
    }
}

# Install Caddy
function Install-Caddy {
    Write-ColorOutput "📦 Installing Caddy..." "Yellow"
    
    if (-not (Test-Command "caddy")) {
        try {
            choco install caddy -y
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-ColorOutput "✅ Caddy installed successfully" "Green"
        } catch {
            Write-ColorOutput "❌ Failed to install Caddy via Chocolatey" "Red"
            Write-ColorOutput "Please install manually from: https://caddyserver.com/download" "Yellow"
            exit 1
        }
    } else {
        Write-ColorOutput "✅ Caddy already installed" "Green"
    }
}

# Setup certificates
function Setup-Certificates {
    Write-ColorOutput "🔐 Setting up certificates..." "Yellow"
    
    # Create mkcert CA
    Write-ColorOutput "Creating local Certificate Authority..." "White"
    mkcert -install
    
    # Create certificates directory
    if (-not (Test-Path ".\certs")) {
        New-Item -ItemType Directory -Path ".\certs" | Out-Null
    }
    
    # Generate certificates
    Write-ColorOutput "Generating certificates for local domains..." "White"
    mkcert -cert-file ".\certs\local.crt" -key-file ".\certs\local.key" `
        $LOCAL_DOMAIN_APP $LOCAL_DOMAIN_API "localhost" "127.0.0.1" $LOCAL_IP "*.local"
    
    Write-ColorOutput "✅ Certificates generated successfully" "Green"
    Write-ColorOutput "📁 Certificates saved to: .\certs\" "White"
}

# Create Caddyfile
function Create-Caddyfile {
    Write-ColorOutput "⚙️  Creating Caddyfile..." "Yellow"
    
    # Create Caddyfile content as an array of strings
    $caddyfileLines = @(
        "# Local HTTPS Development Configuration",
        "# Serves Vite frontend and Supabase backend over HTTPS",
        "",
        "# Global options",
        "{",
        "    # Disable automatic HTTPS (we're using our own certs)",
        "    auto_https off",
        "    # Use custom ports to avoid conflicts", 
        "    http_port $CADDY_HTTP_PORT",
        "    https_port $CADDY_HTTPS_PORT",
        "    # Enable admin API for management",
        "    admin localhost:2019",
        "}",
        "",
        "# Frontend (Vite) - HTTPS",
        "https://$LOCAL_DOMAIN_APP`:$CADDY_HTTPS_PORT {",
        "    # Use our local certificates",
        "    tls ./certs/local.crt ./certs/local.key",
        "    ",
        "    # Proxy to Vite dev server",
        "    reverse_proxy localhost:$VITE_PORT {",
        "        # Enable WebSocket support for Vite HMR",
        "        header_up Host {upstream_hostport}",
        "        header_up X-Real-IP {remote_host}",
        "        header_up X-Forwarded-For {remote_host}",
        "        header_up X-Forwarded-Proto {scheme}",
        "    }",
        "    ",
        "    # Enable CORS for development",
        "    header {",
        "        Access-Control-Allow-Origin `"*`"",
        "        Access-Control-Allow-Methods `"GET, POST, PUT, DELETE, OPTIONS`"",
        "        Access-Control-Allow-Headers `"Origin, Content-Type, Accept, Authorization`"",
        "        # Security headers for HTTPS",
        "        Strict-Transport-Security `"max-age=31536000; includeSubDomains`"",
        "        X-Content-Type-Options `"nosniff`"",
        "        X-Frame-Options `"SAMEORIGIN`"",
        "        X-XSS-Protection `"1; mode=block`"",
        "    }",
        "    ",
        "    # Handle preflight requests", 
        "    `@cors_preflight method OPTIONS",
        "    respond `@cors_preflight 200",
        "    ",
        "    # Logging",
        "    log {",
        "        output file ./logs/frontend.log",
        "        format single_field common_log",
        "        level INFO",
        "    }",
        "}",
        "",
        "# Backend (Supabase) - HTTPS",
        "https://$LOCAL_DOMAIN_API`:$CADDY_HTTPS_PORT {",
        "    # Use our local certificates",
        "    tls ./certs/local.crt ./certs/local.key",
        "    ",
        "    # Proxy to Supabase local instance",
        "    reverse_proxy localhost:$SUPABASE_PORT {",
        "        # Preserve headers for Supabase",
        "        header_up Host {upstream_hostport}",
        "        header_up X-Real-IP {remote_host}",
        "        header_up X-Forwarded-For {remote_host}",
        "        header_up X-Forwarded-Proto {scheme}",
        "        # Handle Supabase auth headers",
        "        header_up Authorization {header.Authorization}",
        "        header_up apikey {header.apikey}",
        "    }",
        "    ",
        "    # Enable CORS for API",
        "    header {",
        "        Access-Control-Allow-Origin `"*`"",
        "        Access-Control-Allow-Methods `"GET, POST, PUT, DELETE, PATCH, OPTIONS`"",
        "        Access-Control-Allow-Headers `"Origin, Content-Type, Accept, Authorization, apikey, X-Client-Info`"",
        "        Access-Control-Expose-Headers `"Content-Length, Content-Range`"",
        "        # Security headers",
        "        X-Content-Type-Options `"nosniff`"",
        "        X-Frame-Options `"SAMEORIGIN`"",
        "    }",
        "    ",
        "    # Handle preflight requests",
        "    `@cors_preflight method OPTIONS",
        "    respond `@cors_preflight 200",
        "    ",
        "    # Logging",
        "    log {",
        "        output file ./logs/backend.log",
        "        format single_field common_log",
        "        level INFO",
        "    }",
        "}",
        "",
        "# HTTP to HTTPS redirect for frontend",
        "http://$LOCAL_DOMAIN_APP`:$CADDY_HTTP_PORT {",
        "    redir https://$LOCAL_DOMAIN_APP`:$CADDY_HTTPS_PORT{uri} permanent",
        "}",
        "",
        "# HTTP to HTTPS redirect for backend", 
        "http://$LOCAL_DOMAIN_API`:$CADDY_HTTP_PORT {",
        "    redir https://$LOCAL_DOMAIN_API`:$CADDY_HTTPS_PORT{uri} permanent",
        "}",
        "",
        "# Serve a simple status page on default HTTP",
        ":$CADDY_HTTP_PORT {",
        "    respond `"Local HTTPS Development Server Running 🚀\n\nFrontend: https://$LOCAL_DOMAIN_APP`:$CADDY_HTTPS_PORT\nBackend: https://$LOCAL_DOMAIN_API`:$CADDY_HTTPS_PORT\n\nAccess from network: https://$LOCAL_IP`:$CADDY_HTTPS_PORT`" 200",
        "}"
    )

    # Write Caddyfile
    $caddyfileLines | Out-File -FilePath "Caddyfile" -Encoding UTF8
    Write-ColorOutput "✅ Caddyfile created successfully" "Green"
}

# Update hosts file
function Update-HostsFile {
    Write-ColorOutput "🌐 Updating hosts file..." "Yellow"
    
    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    
    # Backup hosts file
    $backupPath = "$hostsPath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $hostsPath $backupPath
    
    # Read current hosts file
    $hostsContent = Get-Content $hostsPath
    
    # Remove existing entries
    $hostsContent = $hostsContent | Where-Object { $_ -notmatch $LOCAL_DOMAIN_APP -and $_ -notmatch $LOCAL_DOMAIN_API }
    
    # Add new entries
    $hostsContent += "127.0.0.1 $LOCAL_DOMAIN_APP"
    $hostsContent += "127.0.0.1 $LOCAL_DOMAIN_API"
    
    # Write back to hosts file
    $hostsContent | Out-File -FilePath $hostsPath -Encoding ASCII
    
    Write-ColorOutput "✅ Hosts file updated" "Green"
    Write-ColorOutput "📝 Added entries:" "White"
    Write-ColorOutput "   127.0.0.1 $LOCAL_DOMAIN_APP" "White"
    Write-ColorOutput "   127.0.0.1 $LOCAL_DOMAIN_API" "White"
}

# Create environment files
function Create-EnvironmentFiles {
    Write-ColorOutput "📄 Creating environment files..." "Yellow"
    
    # Create HTTPS environment file
    $envLines = @(
        "# Local HTTPS Development Configuration",
        "# Generated by setup-local-https-fixed.ps1",
        "",
        "# HTTPS Supabase Configuration (via Caddy proxy)",
        "PUBLIC_SUPABASE_URL=https://$LOCAL_DOMAIN_API`:$CADDY_HTTPS_PORT",
        "PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0",
        "",
        "# Local development settings",
        "VITE_APP_TITLE=POS System (Local HTTPS)",
        "VITE_LOCAL_DEVELOPMENT=true"
    )

    $envLines | Out-File -FilePath ".env.local" -Encoding UTF8
    
    # Create network environment file
    $envNetworkLines = @(
        "# Network HTTPS Development Configuration",
        "# For access from other devices on the local network",
        "",
        "# HTTPS Supabase Configuration (via Caddy proxy)",
        "PUBLIC_SUPABASE_URL=https://$LOCAL_IP`:$CADDY_HTTPS_PORT",
        "PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0",
        "",
        "# Network development settings",
        "VITE_APP_TITLE=POS System (Network HTTPS)",
        "VITE_LOCAL_DEVELOPMENT=true",
        "VITE_NETWORK_ACCESS=true"
    )

    $envNetworkLines | Out-File -FilePath ".env.local.network" -Encoding UTF8
    
    Write-ColorOutput "✅ Environment files created" "Green"
    Write-ColorOutput "📁 Files created:" "White"
    Write-ColorOutput "   .env.local (localhost access)" "White"
    Write-ColorOutput "   .env.local.network (network access)" "White"
}

# Create startup scripts
function Create-StartupScripts {
    Write-ColorOutput "📝 Creating startup scripts..." "Yellow"
    
    # Create logs directory
    if (-not (Test-Path ".\logs")) {
        New-Item -ItemType Directory -Path ".\logs" | Out-Null
    }
    
    # Create start script
    $startScriptLines = @(
        "# Start Local HTTPS Development Environment",
        "# This script starts Caddy proxy and development servers",
        "",
        "Write-Host `"🚀 Starting Local HTTPS Development Environment`" -ForegroundColor Cyan",
        "Write-Host `"`"",
        "",
        "# Check if required files exist",
        "if (-not (Test-Path `"Caddyfile`")) {",
        "    Write-Host `"❌ Caddyfile not found. Run setup-local-https-fixed.ps1 first.`" -ForegroundColor Red",
        "    exit 1",
        "}",
        "",
        "if (-not (Test-Path `".env.local`")) {",
        "    Write-Host `"❌ .env.local not found. Run setup-local-https-fixed.ps1 first.`" -ForegroundColor Red",
        "    exit 1",
        "}",
        "",
        "# Start Caddy in background",
        "Write-Host `"📡 Starting Caddy reverse proxy...`" -ForegroundColor Yellow",
        "caddy start --config Caddyfile",
        "",
        "# Wait a moment for Caddy to start",
        "Start-Sleep -Seconds 2",
        "",
        "# Check Caddy status",
        "try {",
        "    `$caddyStatus = caddy list 2>`$null",
        "    if (`$LASTEXITCODE -eq 0 -and `$caddyStatus -match `"caddy`") {",
        "        Write-Host `"✅ Caddy started successfully`" -ForegroundColor Green",
        "    } else {",
        "        Write-Host `"❌ Failed to start Caddy`" -ForegroundColor Red",
        "        exit 1",
        "    }",
        "} catch {",
        "    Write-Host `"❌ Failed to start Caddy`" -ForegroundColor Red",
        "    exit 1",
        "}",
        "",
        "Write-Host `"`"",
        "Write-Host `"🎉 HTTPS Development Environment Ready!`" -ForegroundColor Green",
        "Write-Host `"`"",
        "Write-Host `"📍 Access URLs:`" -ForegroundColor White",
        "Write-Host `"   Frontend: https://app.local:8443`" -ForegroundColor White",
        "Write-Host `"   Backend:  https://api.local:8443`" -ForegroundColor White",
        "`$localIp = (Test-NetConnection -ComputerName `"8.8.8.8`" -Port 53 -ErrorAction SilentlyContinue).SourceAddress.IPAddress",
        "if (`$localIp) {",
        "    Write-Host `"   Network:  https://`$localIp:8443`" -ForegroundColor White",
        "}",
        "Write-Host `"`"",
        "Write-Host `"🛠️  Development Commands:`" -ForegroundColor White",
        "Write-Host `"   Start Vite: npm run dev`" -ForegroundColor White", 
        "Write-Host `"   Start Supabase: supabase start`" -ForegroundColor White",
        "Write-Host `"   Stop Caddy: caddy stop`" -ForegroundColor White",
        "Write-Host `"`"",
        "Write-Host `"💡 Make sure Vite and Supabase are running on their default ports`" -ForegroundColor Yellow",
        "Write-Host `"   Vite: localhost:5173`" -ForegroundColor Yellow",
        "Write-Host `"   Supabase: localhost:54321`" -ForegroundColor Yellow"
    )

    $startScriptLines | Out-File -FilePath "start-https-dev.ps1" -Encoding UTF8
    
    # Create stop script
    $stopScriptLines = @(
        "# Stop Local HTTPS Development Environment",
        "",
        "Write-Host `"🛑 Stopping Caddy reverse proxy...`" -ForegroundColor Yellow",
        "caddy stop",
        "",
        "Write-Host `"✅ HTTPS development environment stopped`" -ForegroundColor Green"
    )

    $stopScriptLines | Out-File -FilePath "stop-https-dev.ps1" -Encoding UTF8
    
    # Create network switch script
    $networkScriptLines = @(
        "# Switch to network HTTPS configuration",
        "",
        "Write-Host `"🌐 Switching to network HTTPS configuration...`" -ForegroundColor Yellow",
        "",
        "if (Test-Path `".env.local.network`") {",
        "    Copy-Item `".env.local.network`" `".env.local`"",
        "    Write-Host `"✅ Switched to network HTTPS configuration`" -ForegroundColor Green",
        "    `$localIp = (Test-NetConnection -ComputerName `"8.8.8.8`" -Port 53 -ErrorAction SilentlyContinue).SourceAddress.IPAddress",
        "    if (`$localIp) {",
        "        Write-Host `"📍 Other devices can now access: https://`$localIp:8443`" -ForegroundColor White",
        "    }",
        "} else {",
        "    Write-Host `"❌ .env.local.network not found`" -ForegroundColor Red",
        "    exit 1",
        "}"
    )

    $networkScriptLines | Out-File -FilePath "switch-to-network-https.ps1" -Encoding UTF8
    
    # Create localhost switch script
    $localhostScriptLines = @(
        "# Switch to localhost HTTPS configuration",
        "",
        "Write-Host `"🏠 Switching to localhost HTTPS configuration...`" -ForegroundColor Yellow",
        "",
        "if (Test-Path `".env.local`") {",
        "    # Restore localhost configuration",
        "    (Get-Content `".env.local`") | ForEach-Object { `$_ -replace `"PUBLIC_SUPABASE_URL=https://.*:8443`", `"PUBLIC_SUPABASE_URL=https://api.local:8443`" } | Set-Content `".env.local`"",
        "    Write-Host `"✅ Switched to localhost HTTPS configuration`" -ForegroundColor Green",
        "    Write-Host `"📍 Access via: https://app.local:8443`" -ForegroundColor White",
        "} else {",
        "    Write-Host `"❌ .env.local not found`" -ForegroundColor Red",
        "    exit 1",
        "}"
    )

    $localhostScriptLines | Out-File -FilePath "switch-to-localhost-https.ps1" -Encoding UTF8
    
    Write-ColorOutput "✅ Startup scripts created" "Green"
    Write-ColorOutput "📁 PowerShell scripts created:" "White"
    Write-ColorOutput "   start-https-dev.ps1" "White"
    Write-ColorOutput "   stop-https-dev.ps1" "White"
    Write-ColorOutput "   switch-to-network-https.ps1" "White"
    Write-ColorOutput "   switch-to-localhost-https.ps1" "White"
}

# Print mobile setup instructions
function Show-MobileInstructions {
    Write-ColorOutput ""
    Write-ColorOutput "📱 Mobile Device Setup Instructions" "Cyan"
    Write-ColorOutput "====================================" "Cyan"
    Write-ColorOutput ""
    Write-ColorOutput "To access the app from mobile devices and trust the certificates:" "Yellow"
    Write-ColorOutput ""
    Write-ColorOutput "📋 Step 1: Install mkcert CA on mobile devices" "Green"
    Write-ColorOutput "1. Run: mkcert -CAROOT to find CA location" "White"
    Write-ColorOutput "2. Copy rootCA.pem to your mobile device" "White"
    Write-ColorOutput "3. Install the certificate:" "White"
    Write-ColorOutput "   📱 iOS: Settings > General > VPN & Device Management > Install Profile" "White"
    Write-ColorOutput "   🤖 Android: Settings > Security > Install from storage" "White"
    Write-ColorOutput ""
    Write-ColorOutput "📋 Step 2: Update mobile device hosts" "Green"
    Write-ColorOutput "Option A - Router DNS (Recommended):" "White"
    Write-ColorOutput "1. Access your router admin panel" "White"
    Write-ColorOutput "2. Add DNS entries:" "White"
    Write-ColorOutput "   $LOCAL_DOMAIN_APP → $LOCAL_IP" "White"
    Write-ColorOutput "   $LOCAL_DOMAIN_API → $LOCAL_IP" "White"
    Write-ColorOutput ""
    Write-ColorOutput "Option B - Device hosts file (Advanced):" "White"
    Write-ColorOutput "1. Use apps like 'Hosts Editor' (Android) or 'DNS Override' (iOS)" "White"
    Write-ColorOutput "2. Add entries:" "White"
    Write-ColorOutput "   $LOCAL_IP $LOCAL_DOMAIN_APP" "White"
    Write-ColorOutput "   $LOCAL_IP $LOCAL_DOMAIN_API" "White"
    Write-ColorOutput ""
    Write-ColorOutput "📋 Step 3: Access the application" "Green"
    Write-ColorOutput "1. Use network configuration: .\switch-to-network-https.ps1" "White"
    Write-ColorOutput "2. Access via: https://$LOCAL_DOMAIN_APP`:$CADDY_HTTPS_PORT" "White"
    Write-ColorOutput "3. Or directly via IP: https://$LOCAL_IP`:$CADDY_HTTPS_PORT" "White"
}

# Main execution
function Main {
    try {
        Write-ColorOutput "🔍 Checking system requirements..." "Yellow"
        
        # Install required tools
        Install-Chocolatey
        Install-Mkcert
        Install-Caddy
        
        # Setup certificates and configuration
        Setup-Certificates
        Create-Caddyfile
        Update-HostsFile
        Create-EnvironmentFiles
        Create-StartupScripts
        
        Write-ColorOutput ""
        Write-ColorOutput "🎉 Setup Complete!" "Green"
        Write-ColorOutput "=================" "Green"
        Write-ColorOutput ""
        Write-ColorOutput "📍 Quick Start:" "Yellow"
        Write-ColorOutput "1. Start Supabase: supabase start" "White"
        Write-ColorOutput "2. Start HTTPS proxy: .\start-https-dev.ps1" "White"
        Write-ColorOutput "3. Start Vite: npm run dev" "White"
        Write-ColorOutput "4. Open: https://$LOCAL_DOMAIN_APP`:$CADDY_HTTPS_PORT" "White"
        Write-ColorOutput ""
        Write-ColorOutput "🌐 Network Access:" "Yellow"
        Write-ColorOutput "• Run: .\switch-to-network-https.ps1" "White"
        Write-ColorOutput "• Access from other devices: https://$LOCAL_IP`:$CADDY_HTTPS_PORT" "White"
        
        Show-MobileInstructions
        
        Write-ColorOutput ""
        Write-ColorOutput "✅ Your offline HTTPS development environment is ready!" "Green"
        Write-ColorOutput "   getUserMedia() will now work on all devices." "Green"
        
    } catch {
        Write-ColorOutput "❌ Setup failed: $($_.Exception.Message)" "Red"
        exit 1
    }
}

# Run main function
Main 