@echo off
chcp 65001 >nul
cd /d "%~dp0"
py "%~dp0generate_character_services.py" %*
echo.
pause