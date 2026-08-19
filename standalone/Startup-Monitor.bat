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
set "WS_TEMP="

pushd "%~dp0" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Cannot access script directory:
  echo %~dp0
  pause
  exit /b 1
)

call :init_temp
if errorlevel 1 (
  echo [ERROR] No writable temporary directory is available.
  pause
  goto exit_script
)

cls
echo ============================================================
echo                  WireSock Startup Monitor
echo ============================================================
echo.
echo [OK]   Script directory : %~dp0
echo [OK]   Temp directory   : !WS_TEMP!

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

goto exit_script

:init_temp
set "WS_TEMP=%TEMP%"
if not defined WS_TEMP set "WS_TEMP=%SystemRoot%\Temp"
if not exist "!WS_TEMP!\" mkdir "!WS_TEMP!" >nul 2>&1
if exist "!WS_TEMP!\" exit /b 0
set "WS_TEMP=%~dp0.tmp"
if not exist "!WS_TEMP!\" mkdir "!WS_TEMP!" >nul 2>&1
if exist "!WS_TEMP!\" exit /b 0
exit /b 1

:find_cli
set "CLI="
set "OUT=!WS_TEMP!\wiresock-where-!RANDOM!-!RANDOM!.txt"
where wiresock-connect-cli.exe >"!OUT!" 2>nul
if exist "!OUT!" set /p "CLI="<"!OUT!"
del /q "!OUT!" >nul 2>&1
if defined CLI exit /b 0
if exist "C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe" set "CLI=C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe"
if not defined CLI if exist "C:\Program Files\WireSock Secure Connect\command-line\wiresock-connect-cli.exe" set "CLI=C:\Program Files\WireSock Secure Connect\command-line\wiresock-connect-cli.exe"
exit /b 0

:read_config
set "ACTIVE_PROFILE="
set "SPLIT=UNKNOWN"
set "KILLSWITCH=UNKNOWN"
if not exist "%CONFIG%" exit /b 0
set "WS_CONFIG=%CONFIG%"
set "OUT=!WS_TEMP!\wiresock-config-!RANDOM!-!RANDOM!.txt"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [xml]$x=Get-Content -LiteralPath $env:WS_CONFIG -Raw; $a=$x.SelectSingleNode('//ActiveConfig'); $s=$x.SelectSingleNode('//EnableSplitTunnelingGlobally'); $k=$x.SelectSingleNode('//EnableKillSwitch'); if($a){'ACTIVE='+$a.InnerText}; if($s){'SPLIT='+$s.InnerText}; if($k){'KILL='+$k.InnerText}" >"!OUT!" 2>nul
if exist "!OUT!" (
  for /f "usebackq tokens=1,* delims==" %%A in ("!OUT!") do (
    if /i "%%A"=="ACTIVE" set "ACTIVE_PROFILE=%%B"
    if /i "%%A"=="SPLIT" set "SPLIT=%%B"
    if /i "%%A"=="KILL" set "KILLSWITCH=%%B"
  )
  del /q "!OUT!" >nul 2>&1
)
exit /b 0

:load_profiles
set "PROFILE_COUNT=0"
if not defined CLI exit /b 0
set "OUT=!WS_TEMP!\wiresock-list-!RANDOM!-!RANDOM!.txt"
"!CLI!" list >"!OUT!" 2>nul
if exist "!OUT!" (
  for /f "usebackq delims=" %%L in ("!OUT!") do (
    set "LINE=%%L"
    for /f "tokens=* delims= " %%T in ("!LINE!") do set "LINE=%%T"
    if "!LINE:~0,2!"=="- " set /a PROFILE_COUNT+=1
  )
  del /q "!OUT!" >nul 2>&1
)
exit /b 0

:get_status
set "WSSTATUS=UNKNOWN"
if not defined CLI exit /b 0
set "OUT=!WS_TEMP!\wiresock-status-!RANDOM!-!RANDOM!.txt"
"!CLI!" status >"!OUT!" 2>&1
findstr /i /c:"NotConnected" /c:"Not Connected" "!OUT!" >nul && set "WSSTATUS=NotConnected"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Disconnecting" "!OUT!" >nul && set "WSSTATUS=Disconnecting"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Disconnected" "!OUT!" >nul && set "WSSTATUS=Disconnected"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Connecting" "!OUT!" >nul && set "WSSTATUS=Connecting"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Connected" "!OUT!" >nul && set "WSSTATUS=Connected"
del /q "!OUT!" >nul 2>&1
exit /b 0

:exit_script
popd >nul 2>&1
exit /b 0
