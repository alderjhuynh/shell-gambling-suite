@echo off
setlocal
call "%~dp0\..\games\video_poker.bat" %*
exit /b %ERRORLEVEL%
