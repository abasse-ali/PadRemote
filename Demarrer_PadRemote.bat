@echo off
chcp 65001 >nul
title PadRemote - serveur PC
cd /d "%~dp0"

set "PY="
where py >nul 2>nul && set "PY=py -3"
if not defined PY (
    where python >nul 2>nul && set "PY=python"
)
if not defined PY (
    echo Python est introuvable. Installez-le depuis https://www.python.org/downloads/
    pause
    exit /b 1
)

%PY% "%~dp0server\padremote.py" %*
if errorlevel 1 pause
