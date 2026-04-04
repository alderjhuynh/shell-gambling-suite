@echo off
setlocal

set "INSTALL_ROOT=%LOCALAPPDATA%\AuraGamblingSuite"
set "INSTALL_BIN=%INSTALL_ROOT%\bin"

echo Uninstalling Aura Gambling Suite CLI...

echo Removing PATH entry (user-level)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows_support\update_user_path.ps1" remove "%INSTALL_BIN%"

if exist "%INSTALL_ROOT%" (
    rmdir /S /Q "%INSTALL_ROOT%"
    echo Removed %INSTALL_ROOT%
) else (
    echo Nothing to remove at %INSTALL_ROOT%
)

echo Done. New terminals should drop the commands immediately.
echo Restart any terminal windows that were already open before uninstall.
pause
