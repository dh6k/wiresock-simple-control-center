@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Install WireSock and add CLI to PATH

set "WS_SELF=%~f0"
set "WS_DIR=%~dp0"

net session >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:WS_SELF -WorkingDirectory $env:WS_DIR -Verb RunAs"
  exit /b
)

pushd "%~dp0" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Cannot access script directory:
  echo %~dp0
  pause
  exit /b 1
)

where winget.exe >nul 2>&1
if errorlevel 1 (
  echo [ERROR] winget.exe not found.
  pause
  goto exit_error
)

echo Installing/updating WireSock Secure Connect...
winget install NTKERNEL.WireSockVPNClient --accept-package-agreements --accept-source-agreements

set "CLI_DIR=C:\Program Files\Wiresock Secure Connect\command-line"
if not exist "!CLI_DIR!\wiresock-connect-cli.exe" set "CLI_DIR=C:\Program Files\WireSock Secure Connect\command-line"

if not exist "!CLI_DIR!\wiresock-connect-cli.exe" (
  echo.
  echo [ERROR] WireSock CLI was not found after installation.
  echo Checked:
  echo   C:\Program Files\Wiresock Secure Connect\command-line
  echo   C:\Program Files\WireSock Secure Connect\command-line
  echo.
  pause
  goto exit_error
)

set "WS_CLI_DIR=!CLI_DIR!"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=[Environment]::GetEnvironmentVariable('Path','Machine'); $d=$env:WS_CLI_DIR; if([string]::IsNullOrEmpty($p)){$p=''}; if(($p -split ';') -notcontains $d){$n=($p.TrimEnd(';')+';'+$d).TrimStart(';'); [Environment]::SetEnvironmentVariable('Path',$n,'Machine')}" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Could not update System PATH.
  pause
  goto exit_error
)

set "PATH=%PATH%;!CLI_DIR!"
echo.
echo WireSock CLI: !CLI_DIR!\wiresock-connect-cli.exe
echo System PATH updated.
echo Open a new terminal/app if an existing process does not see the new PATH yet.
echo.
pause
popd >nul 2>&1
exit /b 0

:exit_error
popd >nul 2>&1
exit /b 1
