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

echo Adding to PATH (user-level)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$target = [System.IO.Path]::GetFullPath('%INSTALL_BIN%');" ^
    "$current = [Environment]::GetEnvironmentVariable('Path', 'User');" ^
    "$parts = @();" ^
    "if ($current) { $parts = $current -split ';' | Where-Object { $_ } }" ^
    "if ($parts -notcontains $target) {" ^
    "  $updated = (($parts + $target) | Select-Object -Unique) -join ';';" ^
    "  [Environment]::SetEnvironmentVariable('Path', $updated, 'User')" ^
    "}"

echo Installed files to:
echo   %INSTALL_ROOT%
echo Done. Restart your terminal before using the commands.

pause
