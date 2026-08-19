@echo off
setlocal EnableExtensions EnableDelayedExpansion
title WireSock Toggle VPN

set "CONFIG=C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config"
set "CONNECT_TIMEOUT=15"
set "CLI="
set "ACTIVE_PROFILE="
set "KILLSWITCH=False"

net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

call :find_cli
if not defined CLI (echo [ERROR] WireSock CLI not found.&pause&exit /b 1)
if not exist "%CONFIG%" (echo [ERROR] wiresock.config not found.&pause&exit /b 1)

for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "[xml]$x=Get-Content -LiteralPath '%CONFIG%' -Raw;$x.SelectSingleNode('//ActiveConfig').InnerText"`) do set "ACTIVE_PROFILE=%%V"
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "[xml]$x=Get-Content -LiteralPath '%CONFIG%' -Raw;$x.SelectSingleNode('//EnableKillSwitch').InnerText"`) do set "KILLSWITCH=%%V"
call :get_status

if /i "!WSSTATUS!"=="Connected" goto off
if /i "!WSSTATUS!"=="Connecting" goto off
if /i "!WSSTATUS!"=="Disconnecting" call :wait_disconnected 10
goto on

:off
echo Turning VPN OFF...
start "" /b "%CLI%" disconnect >nul 2>&1
call :wait_disconnected 15
if errorlevel 1 taskkill /f /im wiresock-connect-cli.exe >nul 2>&1
if /i "!KILLSWITCH!"=="False" "%CLI%" reset-network-lock >nul 2>&1
echo VPN: OFF
timeout /t 2 /nobreak >nul
exit /b 0

:on
if not defined ACTIVE_PROFILE (echo [ERROR] ActiveConfig is empty.&pause&exit /b 2)
if /i "!KILLSWITCH!"=="True" (set "LOCK=on") else (set "LOCK=off")
echo Connecting !ACTIVE_PROFILE!...
start "" /b "%CLI%" connect "!ACTIVE_PROFILE!" -log-level error -network-lock !LOCK! -exit >nul 2>&1
for /l %%I in (1,1,!CONNECT_TIMEOUT!) do (
  call :get_status
  if /i "!WSSTATUS!"=="Connected" goto connected
  timeout /t 1 /nobreak >nul
)
start "" /b "%CLI%" disconnect >nul 2>&1
taskkill /f /im wiresock-connect-cli.exe >nul 2>&1
if /i "!KILLSWITCH!"=="False" "%CLI%" reset-network-lock >nul 2>&1
echo [ERROR] Connection timed out.
pause
exit /b 3

:connected
echo VPN: ON - !ACTIVE_PROFILE!
timeout /t 2 /nobreak >nul
exit /b 0

:find_cli
for /f "delims=" %%F in ('where wiresock-connect-cli.exe 2^>nul') do if not defined CLI set "CLI=%%F"
if not defined CLI if exist "C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe" set "CLI=C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe"
if not defined CLI if exist "C:\Program Files\WireSock Secure Connect\command-line\wiresock-connect-cli.exe" set "CLI=C:\Program Files\WireSock Secure Connect\command-line\wiresock-connect-cli.exe"
exit /b 0

:get_status
set "WSSTATUS=UNKNOWN"
set "SF=%TEMP%\wiresock-status-%RANDOM%.txt"
"%CLI%" status >"!SF!" 2>&1
findstr /i /c:"NotConnected" /c:"Not Connected" "!SF!" >nul && set "WSSTATUS=NotConnected"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Disconnected" "!SF!" >nul && set "WSSTATUS=Disconnected"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Disconnecting" "!SF!" >nul && set "WSSTATUS=Disconnecting"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Connecting" "!SF!" >nul && set "WSSTATUS=Connecting"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Connected" "!SF!" >nul && set "WSSTATUS=Connected"
del "!SF!" >nul 2>&1
exit /b 0

:wait_disconnected
for /l %%I in (1,1,%~1) do (
  call :get_status
  if /i "!WSSTATUS!"=="NotConnected" exit /b 0
  if /i "!WSSTATUS!"=="Disconnected" exit /b 0
  timeout /t 1 /nobreak >nul
)
exit /b 1
