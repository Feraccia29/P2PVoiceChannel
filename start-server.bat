REM Launch Podman Compose in new terminal
start "Podman - P2P VoIP" cmd /k "cd /d %~dp0server && podman compose up"
