@echo off
echo.
echo 🔄 Switching to ONLINE configuration...
echo.

copy .env.local.online .env.local >nul

echo ✅ Switched to online configuration
echo.
echo 📱 Access URLs:
echo    • Any device with internet: http://YOUR_IP:5175
echo    • Database: https://wglybohfygczpapjxwwz.supabase.co
echo    • Studio: https://supabase.com/dashboard/project/wglybohfygczpapjxwwz
echo.
echo ℹ️  Using remote Supabase database (internet required)
echo.
echo 🚀 Next steps:
echo    1. Stop local Supabase (optional): npx supabase stop
echo    2. Restart your development server: npm run dev
echo    3. Access from any device with internet
echo.
pause 