@echo off
chcp 65001 >nul
REM Autorise les connexions de l'iPhone (réseau local uniquement) :
REM   TCP 8765 = commandes, UDP 5353 = détection automatique (Bonjour).
net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
    exit /b
)
netsh advfirewall firewall delete rule name="PadRemote" >nul 2>&1
netsh advfirewall firewall delete rule name="PadRemote Bonjour" >nul 2>&1
netsh advfirewall firewall add rule name="PadRemote" dir=in action=allow protocol=TCP localport=8765 remoteip=localsubnet profile=any
netsh advfirewall firewall add rule name="PadRemote Bonjour" dir=in action=allow protocol=UDP localport=5353 remoteip=localsubnet profile=any
echo.
echo Règles de pare-feu "PadRemote" ajoutées (réseau local uniquement).
pause
