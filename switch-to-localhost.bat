@echo off
echo.
echo 🔄 Switching to LOCALHOST configuration...
echo.

copy .env.local.localhost .env.local >nul

echo ✅ Switched to localhost configuration
echo.
echo 📱 Access URLs:
echo    • Host computer: http://localhost:5175
echo    • Database: http://127.0.0.1:54321
echo    • Studio: http://127.0.0.1:54323
echo.
echo 🚀 Next steps:
echo    1. Restart your development server: npm run dev
echo    2. Ensure Supabase is running: npx supabase status
echo.
pause 