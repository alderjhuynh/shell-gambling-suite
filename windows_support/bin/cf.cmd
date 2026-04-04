@echo off
setlocal
call "%~dp0\..\games\coinflip.bat" %*
exit /b %ERRORLEVEL%
