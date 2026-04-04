@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0aura_games.ps1" video_poker %*
exit /b %ERRORLEVEL%
