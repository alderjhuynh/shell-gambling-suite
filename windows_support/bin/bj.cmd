@echo off
setlocal
call "%~dp0\..\games\blackjack.bat" %*
exit /b %ERRORLEVEL%
