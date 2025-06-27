# Database Switching Guide

This guide explains how to switch between local and online databases for your POS system, including handling dynamic IP addresses.

## 🎯 Quick Switch Methods

### Method 1: Use the Batch Files (Recommended)

**Simple one-click switching:**
- **`switch-to-localhost.bat`** - For single computer development
- **`switch-to-network.bat`** - For local network access (multiple devices)
- **`switch-to-online.bat`** - For internet-based database
- **`update-ip.bat`** - Check current IP addresses

### Method 2: Manual Environment File Switching

#### **For Local Development (Single Computer)**
Edit `.env.local`:
```bash
# LOCAL DATABASE (localhost only)
PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
```

#### **For Network Access (Multiple Devices)**
Edit `.env.local`:
```bash
# NETWORK DATABASE (accessible from other devices)
PUBLIC_SUPABASE_URL=http://192.168.0.202:54321
PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
```

#### **For Online Database**
Edit `.env.local`:
```bash
# ONLINE DATABASE (internet required)
PUBLIC_SUPABASE_URL=https://wglybohfygczpapjxwwz.supabase.co
PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndnbHlib2hmeWdjenBhcGp4d3d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYyMDI2OTYsImV4cCI6MjA2MTc3ODY5Nn0.F9Ja7Npo2aj-1EzgmG275aF_nkm6BvY7MprqQKhpFp0
```

---

## 🔄 Dynamic IP Address Solutions

### Problem: IP Address Changes
When your IP address changes, other devices on the network can't access your local database.

### Solution 1: Use the Batch Files (Simplest)

1. **Run `update-ip.bat`** to see your current IP addresses
2. **Edit `.env.local.network`** and update the IP address
3. **Run `switch-to-network.bat`** to activate the new configuration

### Solution 2: Manual Update

#### **Quick Commands for Switching**
```powershell
# Switch to localhost
copy .env.local.localhost .env.local

# Switch to network (after updating IP)
copy .env.local.network .env.local

# Switch to online
copy .env.local.online .env.local
```

#### **Check Current IP**
```powershell
ipconfig | Select-String "IPv4"
```

---

## 📋 Complete Setup Procedures

### For Offline Network Setup (No Internet)

1. **Start Supabase locally:**
   ```powershell
   npx supabase start
   ```

2. **Check your current IP:**
   ```powershell
   .\update-ip.bat
   ```

3. **Update network configuration (if IP changed):**
   - Edit `.env.local.network`
   - Replace IP in: `PUBLIC_SUPABASE_URL=http://YOUR_NEW_IP:54321`

4. **Switch to network mode:**
   ```powershell
   .\switch-to-network.bat
   ```

5. **Start development server:**
   ```powershell
   npm run dev
   ```

6. **Access from other devices:**
   - Host: `http://localhost:5175` or `http://YOUR_IP:5175`
   - Other devices: `http://YOUR_IP:5175`

### For Online Setup (Internet Required)

1. **Switch to online config:**
   ```powershell
   .\switch-to-online.bat
   ```

2. **Stop local Supabase (optional):**
   ```powershell
   npx supabase stop
   ```

3. **Start development server:**
   ```powershell
   npm run dev
   ```

4. **Access from anywhere:**
   - Any device with internet: `http://YOUR_IP:5175`

---

## 🔧 Troubleshooting

### Issue: "ERR_CONNECTION_REFUSED realtime/v1/websocket"
**Cause:** Using localhost URL when accessing from network device.
**Solution:** Run `switch-to-network.bat` or manually switch to network IP configuration.

### Issue: "No such container: supabase_db_xxx"
**Cause:** Container name mismatch.
**Solution:**
```powershell
npx supabase stop
npx supabase start
```

### Issue: Can't access from other devices
**Causes & Solutions:**
1. **Wrong IP in config** → Run `update-ip.bat` and update `.env.local.network`
2. **Wrong configuration active** → Run `switch-to-network.bat`
3. **Firewall blocking** → Allow port 5175 and 54321 through Windows Firewall
4. **Different network** → Ensure all devices on same WiFi/network

### Issue: IP Address Changed
**Quick Fix:**
```powershell
# Method 1: Use the batch files
.\update-ip.bat
# Edit .env.local.network with new IP
.\switch-to-network.bat

# Method 2: Manual update
ipconfig | Select-String "IPv4"
# Copy your IP and update .env.local.network
copy .env.local.network .env.local
```

---

## 🚀 Advanced: Production-Like Setup

### Using Static IP (Router Configuration)
1. Access your router admin panel (usually `192.168.1.1` or `192.168.0.1`)
2. Find "DHCP Reservation" or "Static IP" settings
3. Assign a static IP to your computer's MAC address
4. Update `.env.local.network` with the static IP
5. No more IP changes!

### Using Domain Names (Advanced)
1. Set up local DNS or use hosts file
2. Add entry: `192.168.0.202 pos-server.local`
3. Use `http://pos-server.local:54321` in config
4. Update hosts file when IP changes instead of config

---

## 📝 Quick Reference

| Scenario | Configuration | Access URLs | Batch File |
|----------|---------------|-------------|------------|
| **Single Computer** | `127.0.0.1:54321` | `localhost:5175` | `switch-to-localhost.bat` |
| **Local Network** | `YOUR_IP:54321` | `YOUR_IP:5175` | `switch-to-network.bat` |
| **Online Database** | `supabase.co` | Any IP with internet | `switch-to-online.bat` |

### Essential Commands
```powershell
# Check current IP
ipconfig | Select-String "IPv4"

# Check Supabase status
npx supabase status

# Restart Supabase
npx supabase stop && npx supabase start

# Start development server
npm run dev
```

### Port Reference
- **App**: `5175` (or 5173, 5174 if ports busy)
- **Supabase API**: `54321`
- **Database**: `54322`
- **Studio**: `54323`

### Configuration Files
- **`.env.local`** - Active configuration
- **`.env.local.localhost`** - Localhost configuration
- **`.env.local.network`** - Network configuration  
- **`.env.local.online`** - Online configuration

---

## 💡 Best Practices

1. **Use the batch files** for easy switching
2. **Keep multiple config files** for different scenarios
3. **Test network access** before deploying to other devices
4. **Document your current IP** for team members
5. **Consider static IP assignment** for permanent setups
6. **Always restart dev server** after config changes

---

## 🆘 Emergency Fixes

### Can't connect to anything:
```powershell
# Nuclear option - restart everything
npx supabase stop
docker system prune -f
npx supabase start
.\switch-to-localhost.bat
npm run dev
```

### Database out of sync:
```powershell
# Reset to clean state
npx supabase db reset
```

### Network completely broken:
```powershell
# Fall back to online database
.\switch-to-online.bat
npm run dev
```

### All batch files broken:
```powershell
# Manual fallback
copy .env.local.localhost .env.local
npm run dev
```

---

## 🎉 Current Setup Status

✅ **All configuration files created**
✅ **Batch files for easy switching available**  
✅ **Network configuration set to: `192.168.0.202:54321`**
✅ **App currently accessible at: `http://192.168.0.202:5175`**
✅ **Realtime WebSocket working over network**

**Ready for multi-device offline operation!** 