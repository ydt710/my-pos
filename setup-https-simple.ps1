# Simple Local HTTPS Development Setup for Windows
# This script sets up Caddy + mkcert for HTTPS development

param([switch]$Help)

if ($Help) {
    Write-Host "Local HTTPS Development Setup" -ForegroundColor Cyan
    Write-Host "Usage: .\setup-https-simple.ps1" -ForegroundColor White
    Write-Host "This script installs mkcert and Caddy, then sets up HTTPS development environment" -ForegroundColor White
    exit 0
}

# Configuration
$LOCAL_IP = "192.168.1.100"  # Will be detected automatically
$DOMAIN_APP = "app.local"
$DOMAIN_API = "api.local"

Write-Host "🚀 Setting up Local HTTPS Development Environment" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Function to check if command exists
function Test-CommandExists {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Get local IP
try {
    $LOCAL_IP = (Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -ErrorAction SilentlyContinue).SourceAddress.IPAddress
    if (-not $LOCAL_IP) {
        $LOCAL_IP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -match "^192\.168\.|^10\.|^172\." } | Select-Object -First 1).IPAddress
    }
} catch {
    $LOCAL_IP = "192.168.1.100"
}

Write-Host "📍 Local IP: $LOCAL_IP" -ForegroundColor Yellow

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "⚠️  This script needs administrator privileges for hosts file modification" -ForegroundColor Yellow
    Write-Host "   Please run as Administrator or manually update hosts file later" -ForegroundColor Yellow
}

# Install Chocolatey if needed
if (-not (Test-CommandExists "choco")) {
    Write-Host "📦 Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-Host "✅ Chocolatey installed" -ForegroundColor Green
} else {
    Write-Host "✅ Chocolatey already installed" -ForegroundColor Green
}

# Install mkcert
if (-not (Test-CommandExists "mkcert")) {
    Write-Host "📦 Installing mkcert..." -ForegroundColor Yellow
    choco install mkcert -y
    Write-Host "✅ mkcert installed" -ForegroundColor Green
} else {
    Write-Host "✅ mkcert already installed" -ForegroundColor Green
}

# Install Caddy
if (-not (Test-CommandExists "caddy")) {
    Write-Host "📦 Installing Caddy..." -ForegroundColor Yellow
    choco install caddy -y
    Write-Host "✅ Caddy installed" -ForegroundColor Green
} else {
    Write-Host "✅ Caddy already installed" -ForegroundColor Green
}

# Setup mkcert CA
Write-Host "🔐 Setting up certificates..." -ForegroundColor Yellow
mkcert -install

# Create certificates directory
if (-not (Test-Path ".\certs")) {
    New-Item -ItemType Directory -Path ".\certs" | Out-Null
}

# Generate certificates
mkcert -cert-file ".\certs\local.crt" -key-file ".\certs\local.key" $DOMAIN_APP $DOMAIN_API "localhost" "127.0.0.1" $LOCAL_IP "*.local"
Write-Host "✅ Certificates generated" -ForegroundColor Green

# Create Caddyfile
Write-Host "⚙️  Creating Caddyfile..." -ForegroundColor Yellow

# Build Caddyfile content
$caddyContent = @"
# Local HTTPS Development Configuration

# Global options
{
    auto_https off
    http_port 8080
    https_port 8443
    admin localhost:2019
}

# Frontend (Vite) - HTTPS
https://$DOMAIN_APP`:8443 {
    tls ./certs/local.crt ./certs/local.key
    reverse_proxy localhost:5173 {
        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
    header {
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Origin, Content-Type, Accept, Authorization"
    }
    @cors_preflight method OPTIONS
    respond @cors_preflight 200
}

# Backend (Supabase) - HTTPS
https://$DOMAIN_API`:8443 {
    tls ./certs/local.crt ./certs/local.key
    reverse_proxy localhost:54321 {
        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
        header_up Authorization {header.Authorization}
        header_up apikey {header.apikey}
    }
    header {
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, PATCH, OPTIONS"
        Access-Control-Allow-Headers "Origin, Content-Type, Accept, Authorization, apikey, X-Client-Info"
    }
    @cors_preflight method OPTIONS
    respond @cors_preflight 200
}

# HTTP redirects
http://$DOMAIN_APP`:8080 {
    redir https://$DOMAIN_APP`:8443{uri} permanent
}

http://$DOMAIN_API`:8080 {
    redir https://$DOMAIN_API`:8443{uri} permanent
}

# Status page
:8080 {
    respond "Local HTTPS Server Running! Frontend: https://$DOMAIN_APP`:8443 Backend: https://$DOMAIN_API`:8443" 200
}
"@

$caddyContent | Out-File -FilePath "Caddyfile" -Encoding UTF8
Write-Host "✅ Caddyfile created" -ForegroundColor Green

# Update hosts file (if admin)
if ($isAdmin) {
    Write-Host "🌐 Updating hosts file..." -ForegroundColor Yellow
    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    
    # Backup
    Copy-Item $hostsPath "$hostsPath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    # Read, filter, and add entries
    $hostsContent = Get-Content $hostsPath | Where-Object { $_ -notmatch $DOMAIN_APP -and $_ -notmatch $DOMAIN_API }
    $hostsContent += "127.0.0.1 $DOMAIN_APP"
    $hostsContent += "127.0.0.1 $DOMAIN_API"
    
    $hostsContent | Out-File -FilePath $hostsPath -Encoding ASCII
    Write-Host "✅ Hosts file updated" -ForegroundColor Green
} else {
    Write-Host "⚠️  Skipping hosts file update (not admin)" -ForegroundColor Yellow
    Write-Host "   Manually add these entries to C:\Windows\System32\drivers\etc\hosts:" -ForegroundColor Yellow
    Write-Host "   127.0.0.1 $DOMAIN_APP" -ForegroundColor White
    Write-Host "   127.0.0.1 $DOMAIN_API" -ForegroundColor White
}

# Create environment files
Write-Host "📄 Creating environment files..." -ForegroundColor Yellow

# Local environment
$envLocal = @"
# Local HTTPS Development Configuration
PUBLIC_SUPABASE_URL=https://$DOMAIN_API`:8443
PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
VITE_APP_TITLE=POS System (Local HTTPS)
VITE_LOCAL_DEVELOPMENT=true
"@

$envLocal | Out-File -FilePath ".env.local" -Encoding UTF8

# Network environment
$envNetwork = @"
# Network HTTPS Development Configuration
PUBLIC_SUPABASE_URL=https://$LOCAL_IP`:8443
PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
VITE_APP_TITLE=POS System (Network HTTPS)
VITE_LOCAL_DEVELOPMENT=true
VITE_NETWORK_ACCESS=true
"@

$envNetwork | Out-File -FilePath ".env.local.network" -Encoding UTF8
Write-Host "✅ Environment files created" -ForegroundColor Green

# Create startup scripts
Write-Host "📝 Creating startup scripts..." -ForegroundColor Yellow

# Create logs directory
if (-not (Test-Path ".\logs")) {
    New-Item -ItemType Directory -Path ".\logs" | Out-Null
}

# Start script
$startScript = @'
Write-Host "🚀 Starting HTTPS Development Environment" -ForegroundColor Cyan

if (-not (Test-Path "Caddyfile")) {
    Write-Host "❌ Caddyfile not found" -ForegroundColor Red
    exit 1
}

Write-Host "📡 Starting Caddy..." -ForegroundColor Yellow
caddy start --config Caddyfile

Start-Sleep -Seconds 2

try {
    $status = caddy list 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Caddy started successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Caddy failed to start" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Error checking Caddy status" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎉 HTTPS Environment Ready!" -ForegroundColor Green
Write-Host "Frontend: https://app.local:8443" -ForegroundColor White
Write-Host "Backend:  https://api.local:8443" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Start Supabase: supabase start" -ForegroundColor White
Write-Host "2. Start Vite: npm run dev" -ForegroundColor White
Write-Host "3. Open: https://app.local:8443" -ForegroundColor White
'@

$startScript | Out-File -FilePath "start-https.ps1" -Encoding UTF8

# Stop script
$stopScript = @'
Write-Host "🛑 Stopping Caddy..." -ForegroundColor Yellow
caddy stop
Write-Host "✅ Stopped" -ForegroundColor Green
'@

$stopScript | Out-File -FilePath "stop-https.ps1" -Encoding UTF8

# Network switch script
$networkScript = @'
Write-Host "🌐 Switching to network mode..." -ForegroundColor Yellow
if (Test-Path ".env.local.network") {
    Copy-Item ".env.local.network" ".env.local"
    Write-Host "✅ Switched to network configuration" -ForegroundColor Green
    Write-Host "Other devices can access via your IP address" -ForegroundColor White
} else {
    Write-Host "❌ .env.local.network not found" -ForegroundColor Red
}
'@

$networkScript | Out-File -FilePath "switch-to-network.ps1" -Encoding UTF8

Write-Host "✅ Scripts created" -ForegroundColor Green

Write-Host ""
Write-Host "🎉 Setup Complete!" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green
Write-Host ""
Write-Host "Quick Start:" -ForegroundColor Yellow
Write-Host "1. Start HTTPS proxy: .\start-https.ps1" -ForegroundColor White
Write-Host "2. Start Supabase: supabase start" -ForegroundColor White
Write-Host "3. Start Vite: npm run dev" -ForegroundColor White
Write-Host "4. Open: https://app.local:8443" -ForegroundColor White
Write-Host ""
Write-Host "For network access:" -ForegroundColor Yellow
Write-Host "1. Run: .\switch-to-network.ps1" -ForegroundColor White
Write-Host "2. Access from other devices: https://$LOCAL_IP`:8443" -ForegroundColor White
Write-Host ""
Write-Host "📱 Mobile Setup:" -ForegroundColor Yellow
Write-Host "1. Run: mkcert -CAROOT" -ForegroundColor White
Write-Host "2. Copy rootCA.pem to mobile device" -ForegroundColor White
Write-Host "3. Install certificate on mobile" -ForegroundColor White
Write-Host "4. Update mobile hosts file or router DNS" -ForegroundColor White
Write-Host ""
Write-Host "✅ getUserMedia() will now work on all devices!" -ForegroundColor Green 