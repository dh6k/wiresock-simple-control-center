@echo off
setlocal EnableExtensions EnableDelayedExpansion
title WireSock Installation Check

set "CONFIG=C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config"
set "PACKAGE_ID=NTKERNEL.WireSockVPNClient"
set "CLI="
set "ACTIVE_PROFILE="
set "SPLIT=UNKNOWN"
set "KILLSWITCH=UNKNOWN"
set "WSSTATUS=UNKNOWN"

call :find_cli
if exist "%CONFIG%" call :read_config
if defined CLI call :get_status

cls
echo ============================================================
echo WireSock Installation Status
echo ============================================================
where winget.exe >nul 2>&1 && (echo WinGet               : OK) || (echo WinGet               : NOT FOUND)

where winget.exe >nul 2>&1
if not errorlevel 1 (
  set "WF=%TEMP%\wiresock-winget-%RANDOM%.txt"
  winget list --id "%PACKAGE_ID%" -e >"!WF!" 2>&1
  findstr /i /c:"%PACKAGE_ID%" "!WF!" >nul && (echo WireSock package     : INSTALLED) || (echo WireSock package     : NOT DETECTED)
  del "!WF!" >nul 2>&1
) else (
  echo WireSock package     : CANNOT CHECK
)

if defined CLI (echo CLI executable       : OK&echo CLI path             : !CLI!) else (echo CLI executable       : NOT FOUND)
where wiresock-connect-cli.exe >nul 2>&1 && (echo CLI in PATH          : YES) || (echo CLI in PATH          : NO)
if exist "%CONFIG%" (echo Config file          : OK&echo Config path          : %CONFIG%) else (echo Config file          : NOT FOUND)
echo Active profile       : !ACTIVE_PROFILE!
if /i "!SPLIT!"=="True" (echo Split Tunneling     : ON) else if /i "!SPLIT!"=="False" (echo Split Tunneling     : OFF) else (echo Split Tunneling     : UNKNOWN)
if /i "!KILLSWITCH!"=="True" (echo Kill Switch         : ON) else if /i "!KILLSWITCH!"=="False" (echo Kill Switch         : OFF) else (echo Kill Switch         : UNKNOWN)
echo CLI VPN status      : !WSSTATUS!
echo.
pause
exit /b 0

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
set "SF=%TEMP%\wiresock-status-%RANDOM%.txt"
"%CLI%" status >"!SF!" 2>&1
findstr /i /c:"NotConnected" /c:"Not Connected" "!SF!" >nul && set "WSSTATUS=NotConnected"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Disconnected" "!SF!" >nul && set "WSSTATUS=Disconnected"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Disconnecting" "!SF!" >nul && set "WSSTATUS=Disconnecting"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Connecting" "!SF!" >nul && set "WSSTATUS=Connecting"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Connected" "!SF!" >nul && set "WSSTATUS=Connected"
del "!SF!" >nul 2>&1
exit /b 0
