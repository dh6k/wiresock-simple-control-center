@echo off
setlocal EnableExtensions EnableDelayedExpansion
title WireSock Toggle Global Split Tunneling

set "CONFIG=C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config"
set "CONNECT_TIMEOUT=15"
set "CLI="
set "ACTIVE_PROFILE="
set "SPLIT=False"
set "KILLSWITCH=False"
set "WSSTATUS=UNKNOWN"
set "WAS_CONNECTED=0"
set "WS_TEMP="
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

call :init_temp
if errorlevel 1 (
  echo [ERROR] No writable temporary directory is available.
  pause
  goto exit_error
)

call :find_cli
if not defined CLI (echo [ERROR] WireSock CLI not found.&pause&goto exit_error)
if not exist "%CONFIG%" (echo [ERROR] wiresock.config not found.&pause&goto exit_error)
call :read_config
call :get_status
if /i "!WSSTATUS!"=="Connected" set "WAS_CONNECTED=1"
if /i "!WSSTATUS!"=="Connecting" set "WAS_CONNECTED=1"

if "!WAS_CONNECTED!"=="1" (
  call :disconnect_wait 15
  if errorlevel 1 call :force_disconnect
)

copy /y "%CONFIG%" "%CONFIG%.toggle-backup" >nul
if errorlevel 1 (
  echo [ERROR] Could not create config backup.
  pause
  goto exit_error
)

if /i "!SPLIT!"=="True" (set "NEW_SPLIT=False") else (set "NEW_SPLIT=True")
set "WS_NEW_SPLIT=!NEW_SPLIT!"
set "WS_CONFIG=%CONFIG%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:WS_CONFIG; $v=$env:WS_NEW_SPLIT; $t=[IO.File]::ReadAllText($p); $pat='(?i)<EnableSplitTunnelingGlobally>\s*(True|False)\s*</EnableSplitTunnelingGlobally>'; if(([regex]::Matches($t,$pat)).Count -ne 1){exit 10}; $n=[regex]::Replace($t,$pat,'<EnableSplitTunnelingGlobally>'+$v+'</EnableSplitTunnelingGlobally>',1); [IO.File]::WriteAllText($p,$n,(New-Object Text.UTF8Encoding($false)))" >nul 2>&1
if errorlevel 1 goto rollback

call :read_config
if /i not "!SPLIT!"=="!NEW_SPLIT!" goto rollback

if "!WAS_CONNECTED!"=="1" (
  if not defined ACTIVE_PROFILE goto rollback
  call :connect_wait "!ACTIVE_PROFILE!" !CONNECT_TIMEOUT!
  if errorlevel 1 goto rollback
)

echo Split Tunneling: !NEW_SPLIT!
timeout /t 2 /nobreak >nul
goto exit_ok

:rollback
call :force_disconnect
copy /y "%CONFIG%.toggle-backup" "%CONFIG%" >nul
call :read_config
if "!WAS_CONNECTED!"=="1" if defined ACTIVE_PROFILE call :connect_wait "!ACTIVE_PROFILE!" !CONNECT_TIMEOUT!
if /i "!KILLSWITCH!"=="False" "!CLI!" reset-network-lock >nul 2>&1
echo [ERROR] Change failed; previous config restored.
pause
goto exit_error

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
set "SPLIT=False"
set "KILLSWITCH=False"
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

:get_status
set "WSSTATUS=UNKNOWN"
set "SF=!WS_TEMP!\wiresock-status-!RANDOM!-!RANDOM!.txt"
"!CLI!" status >"!SF!" 2>&1
findstr /i /c:"NotConnected" /c:"Not Connected" "!SF!" >nul && set "WSSTATUS=NotConnected"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Disconnecting" "!SF!" >nul && set "WSSTATUS=Disconnecting"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Disconnected" "!SF!" >nul && set "WSSTATUS=Disconnected"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Connecting" "!SF!" >nul && set "WSSTATUS=Connecting"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Connected" "!SF!" >nul && set "WSSTATUS=Connected"
del /q "!SF!" >nul 2>&1
exit /b 0

:wait_disconnected
set "WAIT_SECONDS=%~1"
for /l %%I in (1,1,!WAIT_SECONDS!) do (
  call :get_status
  if /i "!WSSTATUS!"=="NotConnected" exit /b 0
  if /i "!WSSTATUS!"=="Disconnected" exit /b 0
  timeout /t 1 /nobreak >nul
)
exit /b 1

:disconnect_wait
start "" /b "!CLI!" disconnect >nul 2>&1
call :wait_disconnected %~1
exit /b !errorlevel!

:force_disconnect
start "" /b "!CLI!" disconnect >nul 2>&1
call :wait_disconnected 8
taskkill /f /im wiresock-connect-cli.exe >nul 2>&1
exit /b 0

:connect_wait
set "CP=%~1"
set "WAIT=%~2"
if /i "!KILLSWITCH!"=="True" (set "LOCK=on") else (set "LOCK=off")
start "" /b "!CLI!" connect "!CP!" -log-level error -network-lock !LOCK! -exit >nul 2>&1
for /l %%I in (1,1,!WAIT!) do (
  call :get_status
  if /i "!WSSTATUS!"=="Connected" exit /b 0
  if %%I GTR 3 if /i "!WSSTATUS!"=="NotConnected" exit /b 1
  if %%I GTR 3 if /i "!WSSTATUS!"=="Disconnected" exit /b 1
  timeout /t 1 /nobreak >nul
)
exit /b 1

:exit_ok
popd >nul 2>&1
exit /b 0

:exit_error
popd >nul 2>&1
exit /b 1
