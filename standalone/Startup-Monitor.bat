@echo off
setlocal EnableExtensions EnableDelayedExpansion
title WireSock Startup Monitor

set "CONFIG=C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config"
set "PROFILES_DIR=C:\ProgramData\WireSock Foundation\WireSock Secure Connect\Profiles"
set "CLI="
set "ACTIVE_PROFILE="
set "SPLIT=UNKNOWN"
set "KILLSWITCH=UNKNOWN"
set "WSSTATUS=UNKNOWN"
set "PROFILE_COUNT=0"

pushd "%~dp0" >nul 2>&1
cls
echo ============================================================
echo                  WireSock Startup Monitor
echo ============================================================
echo.
echo [OK]   Script directory : %~dp0

call :find_cli
if defined CLI (echo [OK]   WireSock CLI    : !CLI!) else (echo [WARN] WireSock CLI    : NOT FOUND)
if exist "%CONFIG%" (echo [OK]   Config file     : FOUND) else (echo [WARN] Config file     : NOT FOUND)
if exist "%PROFILES_DIR%" (echo [OK]   Profiles folder : FOUND) else (echo [WARN] Profiles folder : NOT FOUND)

call :read_config
if defined ACTIVE_PROFILE (echo [OK]   Active profile  : !ACTIVE_PROFILE!) else (echo [WARN] Active profile  : UNKNOWN)
if /i "!SPLIT!"=="True" (echo [OK]   Split tunneling : ON) else if /i "!SPLIT!"=="False" (echo [OK]   Split tunneling : OFF) else (echo [WARN] Split tunneling : UNKNOWN)
if /i "!KILLSWITCH!"=="True" (echo [OK]   Kill Switch     : ON) else if /i "!KILLSWITCH!"=="False" (echo [OK]   Kill Switch     : OFF) else (echo [WARN] Kill Switch     : UNKNOWN)

call :load_profiles
if !PROFILE_COUNT! GTR 0 (echo [OK]   Profiles        : !PROFILE_COUNT!) else (echo [WARN] Profiles        : NONE / UNAVAILABLE)

call :get_status
if /i "!WSSTATUS!"=="UNKNOWN" (echo [WARN] VPN status      : UNKNOWN) else (echo [OK]   VPN status      : !WSSTATUS!)

echo.
pause
popd >nul 2>&1
exit /b 0

:find_cli
set "OUT=%TEMP%\wiresock-where-%RANDOM%-%RANDOM%.txt"
where wiresock-connect-cli.exe >"!OUT!" 2>nul
if exist "!OUT!" set /p "CLI="<"!OUT!"
del "!OUT!" >nul 2>&1
if defined CLI exit /b 0
if exist "C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe" set "CLI=C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe"
if not defined CLI if exist "C:\Program Files\WireSock Secure Connect\command-line\wiresock-connect-cli.exe" set "CLI=C:\Program Files\WireSock Secure Connect\command-line\wiresock-connect-cli.exe"
exit /b 0

:read_config
if not exist "%CONFIG%" exit /b 0
set "OUT=%TEMP%\wiresock-config-%RANDOM%-%RANDOM%.txt"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[xml]$x=Get-Content -LiteralPath '%CONFIG%' -Raw; $a=$x.SelectSingleNode('//ActiveConfig'); $s=$x.SelectSingleNode('//EnableSplitTunnelingGlobally'); $k=$x.SelectSingleNode('//EnableKillSwitch'); if($a){'ACTIVE='+$a.InnerText}; if($s){'SPLIT='+$s.InnerText}; if($k){'KILL='+$k.InnerText}" >"!OUT!" 2>nul
if exist "!OUT!" (
  for /f "usebackq tokens=1,* delims==" %%A in ("!OUT!") do (
    if /i "%%A"=="ACTIVE" set "ACTIVE_PROFILE=%%B"
    if /i "%%A"=="SPLIT" set "SPLIT=%%B"
    if /i "%%A"=="KILL" set "KILLSWITCH=%%B"
  )
  del "!OUT!" >nul 2>&1
)
exit /b 0

:load_profiles
if not defined CLI exit /b 0
set "OUT=%TEMP%\wiresock-list-%RANDOM%-%RANDOM%.txt"
"!CLI!" list >"!OUT!" 2>nul
if exist "!OUT!" (
  for /f "usebackq delims=" %%L in ("!OUT!") do (
    set "LINE=%%L"
    for /f "tokens=* delims= " %%T in ("!LINE!") do set "LINE=%%T"
    if "!LINE:~0,2!"=="- " set /a PROFILE_COUNT+=1
  )
  del "!OUT!" >nul 2>&1
)
exit /b 0

:get_status
if not defined CLI exit /b 0
set "OUT=%TEMP%\wiresock-status-%RANDOM%-%RANDOM%.txt"
"!CLI!" status >"!OUT!" 2>&1
findstr /i /c:"NotConnected" /c:"Not Connected" "!OUT!" >nul && set "WSSTATUS=NotConnected"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Disconnecting" "!OUT!" >nul && set "WSSTATUS=Disconnecting"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Disconnected" "!OUT!" >nul && set "WSSTATUS=Disconnected"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Connecting" "!OUT!" >nul && set "WSSTATUS=Connecting"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Connected" "!OUT!" >nul && set "WSSTATUS=Connected"
del "!OUT!" >nul 2>&1
exit /b 0
