# Local HTTPS Development Setup Guide

This guide helps you set up a complete offline HTTPS development environment for your Vite + Supabase POS application. This setup solves the following critical issues:

- ✅ **getUserMedia() camera access** - Browsers require HTTPS for camera APIs
- ✅ **Mixed content security** - No more HTTPS frontend to HTTP backend blocks  
- ✅ **Local network access** - Mobile devices and laptops can access the app
- ✅ **Offline capability** - Works completely without internet
- ✅ **Trusted certificates** - No browser security warnings

## 🎯 Solution Overview

We use **Caddy** as a reverse proxy with **mkcert** for trusted local certificates:

```
📱 Mobile Device (HTTPS) ──┐
💻 Laptop (HTTPS) ─────────┼─► Caddy Proxy ─┬─► Vite (HTTP:5173)
🖥️ Desktop (HTTPS) ───────┘    (HTTPS:8443)  └─► Supabase (HTTP:54321)
```

## 🚀 Quick Setup

### Option 1: Automated Setup (Recommended)

**For Linux/Mac (including WSL):**
```bash
chmod +x setup-local-https.sh
./setup-local-https.sh
```

**For Windows PowerShell:**
```powershell
# Run as Administrator
.\setup-local-https.ps1
```

### Option 2: Manual Setup

If the automated scripts don't work for your system, follow the manual steps below.

## 📋 Manual Setup Instructions

### Step 1: Install Prerequisites

**Ubuntu/Debian:**
```bash
# Install mkcert
sudo apt update
sudo apt install -y libnss3-tools
curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
chmod +x mkcert-v*-linux-amd64
sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert

# Install Caddy
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install -y caddy
```

**macOS:**
```bash
# Install via Homebrew
brew install mkcert caddy
brew install nss # for Firefox support
```

**Windows:**
```powershell
# Install via Chocolatey
choco install mkcert caddy -y
```

### Step 2: Setup Certificates

```bash
# Create local Certificate Authority
mkcert -install

# Create certificates directory
mkdir -p ./certs

# Generate certificates (replace YOUR_LOCAL_IP with your actual IP)
mkcert -cert-file ./certs/local.crt -key-file ./certs/local.key \
    app.local \
    api.local \
    localhost \
    127.0.0.1 \
    YOUR_LOCAL_IP \
    "*.local"
```

### Step 3: Create Caddyfile

Create a `Caddyfile` in your project root:

```caddyfile
# Local HTTPS Development Configuration
{
    auto_https off
    http_port 8080
    https_port 8443
    admin localhost:2019
}

# Frontend (Vite) - HTTPS
https://app.local:8443 {
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
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "1; mode=block"
    }
    @cors_preflight method OPTIONS
    respond @cors_preflight 200
}

# Backend (Supabase) - HTTPS
https://api.local:8443 {
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
        Access-Control-Expose-Headers "Content-Length, Content-Range"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
    }
    @cors_preflight method OPTIONS
    respond @cors_preflight 200
}

# HTTP to HTTPS redirects
http://app.local:8080 {
    redir https://app.local:8443{uri} permanent
}

http://api.local:8080 {
    redir https://api.local:8443{uri} permanent
}
```

### Step 4: Update Hosts File

**Linux/Mac:**
```bash
sudo tee -a /etc/hosts << EOF
127.0.0.1 app.local
127.0.0.1 api.local
EOF
```

**Windows (as Administrator):**
```powershell
Add-Content C:\Windows\System32\drivers\etc\hosts "127.0.0.1 app.local"
Add-Content C:\Windows\System32\drivers\etc\hosts "127.0.0.1 api.local"
```

### Step 5: Create Environment Files

Create `.env.local`:
```env
# Local HTTPS Development Configuration
PUBLIC_SUPABASE_URL=https://api.local:8443
PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0

VITE_APP_TITLE=POS System (Local HTTPS)
VITE_LOCAL_DEVELOPMENT=true
```

Create `.env.local.network` (replace YOUR_LOCAL_IP):
```env
# Network HTTPS Development Configuration
PUBLIC_SUPABASE_URL=https://YOUR_LOCAL_IP:8443
PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0

VITE_APP_TITLE=POS System (Network HTTPS)
VITE_LOCAL_DEVELOPMENT=true
VITE_NETWORK_ACCESS=true
```

## 🎮 Usage

### Start Development Environment

1. **Start Supabase:**
   ```bash
   supabase start
   ```

2. **Start Caddy Proxy:**
   ```bash
   caddy start --config Caddyfile
   ```

3. **Start Vite:**
   ```bash
   npm run dev
   ```

4. **Access Application:**
   - Frontend: https://app.local:8443
   - Backend: https://api.local:8443

### Stop Development Environment

```bash
caddy stop
# Stop Vite and Supabase as normal
```

### Switch Between Local and Network Access

**For localhost only:**
```bash
# Use .env.local (domain-based)
cp .env.local .env.local
```

**For network access:**
```bash
# Use .env.local.network (IP-based)
cp .env.local.network .env.local
```

## 📱 Mobile Device Setup

To access the app from mobile devices on your local network:

### Step 1: Install Certificate Authority

1. **Find CA location:**
   ```bash
   mkcert -CAROOT
   ```

2. **Copy `rootCA.pem` to your mobile device** (via AirDrop, email, etc.)

3. **Install certificate on mobile:**
   - **iOS:** Settings → General → VPN & Device Management → Install Profile
   - **Android:** Settings → Security → Install from storage

### Step 2: Configure DNS Resolution

**Option A: Router DNS (Recommended)**
1. Access your router's admin panel (usually http://192.168.1.1)
2. Add DNS entries:
   - `app.local` → `YOUR_LOCAL_IP`
   - `api.local` → `YOUR_LOCAL_IP`

**Option B: Mobile Hosts File (Advanced)**
1. Use apps like "Hosts Editor" (Android) or "DNS Override" (iOS)
2. Add entries:
   - `YOUR_LOCAL_IP app.local`
   - `YOUR_LOCAL_IP api.local`

### Step 3: Access Application

1. Switch to network mode: `cp .env.local.network .env.local`
2. Restart Vite if running
3. Access via: https://app.local:8443 or https://YOUR_LOCAL_IP:8443

## 🔧 Troubleshooting

### Certificate Issues

**Problem:** Browser shows "Not Secure" warning
**Solution:** 
1. Verify mkcert CA is installed: `mkcert -install`
2. Regenerate certificates with correct domains/IPs
3. Clear browser cache and restart

**Problem:** Mobile devices don't trust certificates
**Solution:**
1. Ensure rootCA.pem is properly installed on device
2. Enable "Full Trust" for the CA in iOS Settings
3. Restart browser after installing certificate

### Network Access Issues

**Problem:** Can't access from other devices
**Solution:**
1. Check firewall allows ports 8443 and 5173
2. Verify you're using `.env.local.network` configuration
3. Ensure mobile devices can resolve domains (router DNS or hosts file)

**Problem:** Router doesn't support custom DNS
**Solution:**
1. Use IP-based access: https://YOUR_LOCAL_IP:8443
2. Or set up a local DNS server like dnsmasq

### Performance Issues

**Problem:** Slow loading or connection timeouts
**Solution:**
1. Check Caddy logs: `caddy list` and look in `./logs/`
2. Verify Vite and Supabase are running on correct ports
3. Test direct access to ensure services are working

### Port Conflicts

**Problem:** Port 8443 already in use
**Solution:**
1. Change `https_port` in Caddyfile to another port (e.g., 9443)
2. Update environment files accordingly
3. Update firewall rules for new port

## 🔍 Verification Checklist

After setup, verify everything works:

- [ ] ✅ Caddy starts without errors: `caddy list`
- [ ] ✅ Can access https://app.local:8443 without security warnings
- [ ] ✅ Can access https://api.local:8443 without security warnings
- [ ] ✅ Vite HMR (hot reload) works through proxy
- [ ] ✅ Supabase API calls work through proxy
- [ ] ✅ Camera access works (test getUserMedia())
- [ ] ✅ Mobile devices can access after certificate install
- [ ] ✅ No mixed content errors in browser console

## 📚 Technical Details

### Why This Setup Works

1. **Trusted Certificates:** mkcert creates a local CA that browsers trust
2. **No Mixed Content:** Everything runs over HTTPS
3. **Network Isolation:** Completely offline-capable once set up
4. **Mobile Support:** Certificates work on mobile with proper CA install
5. **Development Friendly:** Maintains Vite HMR and development features

### Security Considerations

- Certificates are only valid for local development
- CA private key stays on development machine
- No external certificate authorities or internet required
- Firewall should still protect development environment

### Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Browser       │    │   Caddy Proxy    │    │  Development    │
│  (HTTPS Client) │───▶│   (HTTPS Server) │───▶│    Services     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │                         │
                              │                    ┌────────────┐
                              │                    │ Vite       │
                              └────────────────────│ :5173      │
                                                   └────────────┘
                                                   ┌────────────┐
                                                   │ Supabase   │
                                                   │ :54321     │
                                                   └────────────┘
```

This setup provides a production-like HTTPS environment for local development while maintaining the convenience and performance of local development tools. 