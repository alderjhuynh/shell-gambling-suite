@echo off
setlocal
call "%~dp0\..\games\rock_paper_scissors.bat" %*
exit /b %ERRORLEVEL%
