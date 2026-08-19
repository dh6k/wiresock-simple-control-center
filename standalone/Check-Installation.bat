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
  set "WF=!WS_TEMP!\wiresock-winget-!RANDOM!-!RANDOM!.txt"
  winget list --id "%PACKAGE_ID%" -e >"!WF!" 2>&1
  findstr /i /c:"%PACKAGE_ID%" "!WF!" >nul && (echo WireSock package     : INSTALLED) || (echo WireSock package     : NOT DETECTED)
  del /q "!WF!" >nul 2>&1
) else (
  echo WireSock package     : CANNOT CHECK
)

if defined CLI (echo CLI executable       : OK&echo CLI path             : !CLI!) else (echo CLI executable       : NOT FOUND)
call :cli_in_path
if "!CLI_IN_PATH!"=="1" (echo CLI in PATH          : YES) else (echo CLI in PATH          : NO)
if exist "%CONFIG%" (echo Config file          : OK&echo Config path          : %CONFIG%) else (echo Config file          : NOT FOUND)
echo Active profile       : !ACTIVE_PROFILE!
if /i "!SPLIT!"=="True" (echo Split Tunneling     : ON) else if /i "!SPLIT!"=="False" (echo Split Tunneling     : OFF) else (echo Split Tunneling     : UNKNOWN)
if /i "!KILLSWITCH!"=="True" (echo Kill Switch         : ON) else if /i "!KILLSWITCH!"=="False" (echo Kill Switch         : OFF) else (echo Kill Switch         : UNKNOWN)
echo CLI VPN status      : !WSSTATUS!
echo Temp directory      : !WS_TEMP!
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

:cli_in_path
set "CLI_IN_PATH=0"
set "OUT=!WS_TEMP!\wiresock-path-!RANDOM!-!RANDOM!.txt"
where wiresock-connect-cli.exe >"!OUT!" 2>nul
for %%Z in ("!OUT!") do if %%~zZ GTR 0 set "CLI_IN_PATH=1"
del /q "!OUT!" >nul 2>&1
exit /b 0

:read_config
set "ACTIVE_PROFILE="
set "SPLIT=UNKNOWN"
set "KILLSWITCH=UNKNOWN"
if not exist "%CONFIG%" exit /b 0
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

:get_status
set "WSSTATUS=UNKNOWN"
if not defined CLI exit /b 0
set "SF=!WS_TEMP!\wiresock-status-!RANDOM!-!RANDOM!.txt"
"!CLI!" status >"!SF!" 2>&1
findstr /i /c:"NotConnected" /c:"Not Connected" "!SF!" >nul && set "WSSTATUS=NotConnected"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Disconnecting" "!SF!" >nul && set "WSSTATUS=Disconnecting"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Disconnected" "!SF!" >nul && set "WSSTATUS=Disconnected"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Connecting" "!SF!" >nul && set "WSSTATUS=Connecting"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Connected" "!SF!" >nul && set "WSSTATUS=Connected"
del /q "!SF!" >nul 2>&1
exit /b 0

:exit_script
popd >nul 2>&1
exit /b 0
