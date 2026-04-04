@echo off
setlocal

set "SOURCE_ROOT=%~dp0"
set "SOURCE_SUPPORT=%SOURCE_ROOT%windows_support"
set "INSTALL_ROOT=%LOCALAPPDATA%\AuraGamblingSuite"
set "INSTALL_BIN=%INSTALL_ROOT%\bin"
set "INSTALL_GAMES=%INSTALL_ROOT%\games"
set "SOURCE_BIN=%SOURCE_SUPPORT%\bin"
set "SOURCE_GAMES=%SOURCE_SUPPORT%\games"

echo Installing Aura Gambling Suite CLI...

mkdir "%INSTALL_ROOT%" >nul 2>&1
mkdir "%INSTALL_BIN%" >nul 2>&1
mkdir "%INSTALL_GAMES%" >nul 2>&1

copy /Y "%SOURCE_BIN%\*.cmd" "%INSTALL_BIN%\" >nul
copy /Y "%SOURCE_GAMES%\*.bat" "%INSTALL_GAMES%\" >nul
copy /Y "%SOURCE_GAMES%\*.ps1" "%INSTALL_GAMES%\" >nul

if exist "%INSTALL_BIN%\sl.cmd" del /Q "%INSTALL_BIN%\sl.cmd"
if exist "%INSTALL_BIN%\sc.cmd" del /Q "%INSTALL_BIN%\sc.cmd"

echo Adding to PATH (user-level)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SOURCE_SUPPORT%\update_user_path.ps1" add "%INSTALL_BIN%"
echo Updating PowerShell profile commands...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SOURCE_SUPPORT%\update_powershell_profile.ps1" add "%INSTALL_BIN%"

echo ;%PATH%; | findstr /I /C:";%INSTALL_BIN%;" >nul
if errorlevel 1 set "PATH=%PATH%;%INSTALL_BIN%"

echo Installed files to:
echo   %INSTALL_ROOT%
echo Done. New terminals should pick up the commands immediately.
echo Restart any terminal windows that were already open before install.

pause
