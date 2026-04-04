@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0aura_games.ps1" scratchers %*
exit /b %ERRORLEVEL%
