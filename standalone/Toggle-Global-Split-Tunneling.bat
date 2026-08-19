@echo off
setlocal EnableExtensions EnableDelayedExpansion
title WireSock Toggle Global Split Tunneling

set "CONFIG=C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config"
set "CONNECT_TIMEOUT=15"
set "CLI="
set "ACTIVE_PROFILE="
set "SPLIT=False"
set "KILLSWITCH=False"
set "WAS_CONNECTED=0"

net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

call :find_cli
if not defined CLI (echo [ERROR] WireSock CLI not found.&pause&exit /b 1)
if not exist "%CONFIG%" (echo [ERROR] wiresock.config not found.&pause&exit /b 1)
call :read_config
call :get_status
if /i "!WSSTATUS!"=="Connected" set "WAS_CONNECTED=1"
if /i "!WSSTATUS!"=="Connecting" set "WAS_CONNECTED=1"

if "!WAS_CONNECTED!"=="1" (
  start "" /b "%CLI%" disconnect >nul 2>&1
  call :wait_disconnected 15
)

copy /y "%CONFIG%" "%CONFIG%.toggle-backup" >nul
if /i "!SPLIT!"=="True" (set "NEW_SPLIT=False") else (set "NEW_SPLIT=True")

powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%CONFIG%';$t=[IO.File]::ReadAllText($p);$r='<EnableSplitTunnelingGlobally>'+('%NEW_SPLIT%')+'</EnableSplitTunnelingGlobally>';$n=[regex]::Replace($t,'(?i)<EnableSplitTunnelingGlobally>\s*(True|False)\s*</EnableSplitTunnelingGlobally>',$r,1);[IO.File]::WriteAllText($p,$n,(New-Object Text.UTF8Encoding($false)))"
if errorlevel 1 goto rollback
call :read_config
if /i not "!SPLIT!"=="!NEW_SPLIT!" goto rollback

if "!WAS_CONNECTED!"=="1" (
  call :connect_wait "!ACTIVE_PROFILE!" !CONNECT_TIMEOUT!
  if errorlevel 1 goto rollback
)

echo Split Tunneling: !NEW_SPLIT!
timeout /t 2 /nobreak >nul
exit /b 0

:rollback
copy /y "%CONFIG%.toggle-backup" "%CONFIG%" >nul
call :read_config
if "!WAS_CONNECTED!"=="1" call :connect_wait "!ACTIVE_PROFILE!" !CONNECT_TIMEOUT!
if /i "!KILLSWITCH!"=="False" "%CLI%" reset-network-lock >nul 2>&1
echo [ERROR] Change failed; previous config restored.
pause
exit /b 4

:find_cli
for /f "delims=" %%F in ('where wiresock-connect-cli.exe 2^>nul') do if not defined CLI set "CLI=%%F"
if not defined CLI if exist "C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe" set "CLI=C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe"
if not defined CLI if exist "C:\Program Files\WireSock Secure Connect\command-line\wiresock-connect-cli.exe" set "CLI=C:\Program Files\WireSock Secure Connect\command-line\wiresock-connect-cli.exe"
exit /b 0

:read_config
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "[xml]$x=Get-Content -LiteralPath '%CONFIG%' -Raw;$x.SelectSingleNode('//ActiveConfig').InnerText"`) do set "ACTIVE_PROFILE=%%V"
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "[xml]$x=Get-Content -LiteralPath '%CONFIG%' -Raw;$x.SelectSingleNode('//EnableSplitTunnelingGlobally').InnerText"`) do set "SPLIT=%%V"
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "[xml]$x=Get-Content -LiteralPath '%CONFIG%' -Raw;$x.SelectSingleNode('//EnableKillSwitch').InnerText"`) do set "KILLSWITCH=%%V"
exit /b 0

:get_status
set "WSSTATUS=UNKNOWN"
set "SF=%TEMP%\wiresock-status-%RANDOM%.txt"
"%CLI%" status >"!SF!" 2>&1
findstr /i /c:"NotConnected" /c:"Not Connected" "!SF!" >nul && set "WSSTATUS=NotConnected"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Disconnected" "!SF!" >nul && set "WSSTATUS=Disconnected"
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

:connect_wait
set "CP=%~1"
set "WAIT=%~2"
if /i "!KILLSWITCH!"=="True" (set "LOCK=on") else (set "LOCK=off")
start "" /b "%CLI%" connect "!CP!" -log-level error -network-lock !LOCK! -exit >nul 2>&1
for /l %%I in (1,1,!WAIT!) do (
  call :get_status
  if /i "!WSSTATUS!"=="Connected" exit /b 0
  timeout /t 1 /nobreak >nul
)
exit /b 1
