@echo off
setlocal EnableExtensions
title Install WireSock and add CLI to PATH

net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

where winget.exe >nul 2>&1
if errorlevel 1 (
  echo [ERROR] winget.exe not found.
  pause
  exit /b 1
)

echo Installing/updating WireSock Secure Connect...
winget install NTKERNEL.WireSockVPNClient --accept-package-agreements --accept-source-agreements

set "CLI_DIR=C:\Program Files\Wiresock Secure Connect\command-line"
if not exist "%CLI_DIR%\wiresock-connect-cli.exe" set "CLI_DIR=C:\Program Files\WireSock Secure Connect\command-line"

if not exist "%CLI_DIR%\wiresock-connect-cli.exe" (
  echo [ERROR] WireSock CLI was not found after installation.
  pause
  exit /b 2
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=[Environment]::GetEnvironmentVariable('Path','Machine');$d='%CLI_DIR%';if(($p -split ';') -notcontains $d){[Environment]::SetEnvironmentVariable('Path',($p.TrimEnd(';')+';'+$d),'Machine')}"
set "PATH=%PATH%;%CLI_DIR%"

echo.
echo WireSock CLI: %CLI_DIR%\wiresock-connect-cli.exe
echo System PATH updated.
echo Open a new terminal/app if an existing process does not see the new PATH yet.
echo.
pause
