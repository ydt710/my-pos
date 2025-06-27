@echo off
echo.
echo 🔍 Current IP Addresses:
echo.
ipconfig | findstr "IPv4"
echo.
echo 📝 To update network configuration:
echo.
echo 1. Note your current IP address from above
echo 2. Edit .env.local.network file
echo 3. Replace the IP in: PUBLIC_SUPABASE_URL=http://YOUR_NEW_IP:54321
echo 4. Run switch-to-network.bat
echo.
echo 💡 Your main network IP is likely: 192.168.0.xxx or 192.168.1.xxx
echo.
pause 