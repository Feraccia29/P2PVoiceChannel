@echo off
echo Starting P2P VoIP Infrastructure...
echo.
echo Launching Podman Compose and NPM Server in separate terminals...
echo.

REM Launch Podman Compose in new terminal
start "Podman - P2P VoIP" cmd /k "cd /d %~dp0server && podman compose up"

REM Wait a moment for Podman to start
timeout /t 2 /nobreak >nul

REM Launch NPM Server in new terminal
start "NPM Server - P2P VoIP" cmd /k "cd /d %~dp0server && npm start"

echo.
echo Two terminals opened:
echo   - Podman Compose (TURN/STUN server)
echo   - NPM Server (Signaling server on port 3000)
echo.
