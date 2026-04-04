@echo off
setlocal

set "INSTALL_ROOT=%LOCALAPPDATA%\AuraGamblingSuite"
set "INSTALL_BIN=%INSTALL_ROOT%\bin"

echo Uninstalling Aura Gambling Suite CLI...

echo Removing PATH entry (user-level)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$target = [System.IO.Path]::GetFullPath('%INSTALL_BIN%');" ^
    "$current = [Environment]::GetEnvironmentVariable('Path', 'User');" ^
    "$parts = @();" ^
    "if ($current) { $parts = $current -split ';' | Where-Object { $_ } }" ^
    "$updated = ($parts | Where-Object { [System.StringComparer]::OrdinalIgnoreCase.Compare($_, $target) -ne 0 }) -join ';';" ^
    "[Environment]::SetEnvironmentVariable('Path', $updated, 'User')"

if exist "%INSTALL_ROOT%" (
    rmdir /S /Q "%INSTALL_ROOT%"
    echo Removed %INSTALL_ROOT%
) else (
    echo Nothing to remove at %INSTALL_ROOT%
)

echo Done. Restart your terminal to flush PATH changes.
pause
