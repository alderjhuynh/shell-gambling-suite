@echo off
setlocal
call "%~dp0\..\games\scratchers.bat" %*
exit /b %ERRORLEVEL%
