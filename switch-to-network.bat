@echo off
echo.
echo 🔄 Switching to NETWORK configuration...
echo.

copy .env.local.network .env.local >nul

echo ✅ Switched to network configuration
echo.
echo 📱 Access URLs:
echo    • Host computer: http://localhost:5175 OR http://192.168.0.202:5175
echo    • Other devices: http://192.168.0.202:5175
echo    • Database: http://192.168.0.202:54321
echo    • Studio: http://192.168.0.202:54323
echo.
echo ⚠️  Note: If your IP changed, update .env.local.network file first
echo.
echo 🚀 Next steps:
echo    1. Restart your development server: npm run dev
echo    2. Ensure Supabase is running: npx supabase status
echo    3. Test access from another device
echo.
pause 