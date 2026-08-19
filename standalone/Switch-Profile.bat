@echo off
setlocal EnableExtensions EnableDelayedExpansion
title WireSock Switch Profile

set "CONFIG=C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config"
set "CONNECT_TIMEOUT=15"
set "CLI="
set "ACTIVE_PROFILE="
set "KILLSWITCH=False"
set "WSSTATUS=UNKNOWN"
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

cls
echo Current profile: !ACTIVE_PROFILE!
echo.
set "COUNT=0"
set "LIST_FILE=!WS_TEMP!\wiresock-list-!RANDOM!-!RANDOM!.txt"
"!CLI!" list >"!LIST_FILE!" 2>nul
if exist "!LIST_FILE!" (
  for /f "usebackq delims=" %%L in ("!LIST_FILE!") do (
    set "LINE=%%L"
    for /f "tokens=* delims= " %%T in ("!LINE!") do set "LINE=%%T"
    if "!LINE:~0,2!"=="- " (
      set /a COUNT+=1
      set "PROFILE_!COUNT!=!LINE:~2!"
      if /i "!LINE:~2!"=="!ACTIVE_PROFILE!" (echo [!COUNT!] !LINE:~2! [ACTIVE]) else (echo [!COUNT!] !LINE:~2!)
    )
  )
  del /q "!LIST_FILE!" >nul 2>&1
)

if !COUNT! LEQ 0 (
  echo [ERROR] No WireSock profiles found.
  pause
  goto exit_error
)

echo [0] Cancel
echo.
set "SEL="
set /p "SEL=Select profile: "
if "!SEL!"=="0" goto exit_ok
echo(!SEL!| findstr /r "^[0-9][0-9]*$" >nul || (echo [ERROR] Invalid selection.&pause&goto exit_error)
if !SEL! LSS 1 (echo [ERROR] Invalid selection.&pause&goto exit_error)
if !SEL! GTR !COUNT! (echo [ERROR] Invalid selection.&pause&goto exit_error)
for %%N in (!SEL!) do set "TARGET=!PROFILE_%%N!"
if not defined TARGET (echo [ERROR] Invalid selection.&pause&goto exit_error)

set "OLD_PROFILE=!ACTIVE_PROFILE!"
call :get_status
if /i "!WSSTATUS!"=="Connected" (
  call :disconnect_wait 15
  if errorlevel 1 call :force_disconnect
)
if /i "!WSSTATUS!"=="Connecting" call :force_disconnect
if /i "!WSSTATUS!"=="Disconnecting" call :wait_disconnected 10

copy /y "%CONFIG%" "%CONFIG%.profile-switch-backup" >nul
if errorlevel 1 (
  echo [ERROR] Could not create config backup.
  pause
  goto exit_error
)

set "WS_TARGET=!TARGET!"
set "WS_CONFIG=%CONFIG%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:WS_CONFIG; $v=$env:WS_TARGET; $t=[IO.File]::ReadAllText($p); $pat='(?is)<ActiveConfig>.*?</ActiveConfig>'; if(([regex]::Matches($t,$pat)).Count -ne 1){exit 10}; $e=[Security.SecurityElement]::Escape($v); $n=[regex]::Replace($t,$pat,'<ActiveConfig>'+$e+'</ActiveConfig>',1); [IO.File]::WriteAllText($p,$n,(New-Object Text.UTF8Encoding($false)))" >nul 2>&1
if errorlevel 1 goto rollback

call :read_config
if /i not "!ACTIVE_PROFILE!"=="!TARGET!" goto rollback

call :connect_wait "!TARGET!" !CONNECT_TIMEOUT!
if errorlevel 1 goto rollback

echo Connected: !TARGET!
timeout /t 2 /nobreak >nul
goto exit_ok

:rollback
call :force_disconnect
if /i "!KILLSWITCH!"=="False" "!CLI!" reset-network-lock >nul 2>&1
copy /y "%CONFIG%.profile-switch-backup" "%CONFIG%" >nul
call :read_config
if defined OLD_PROFILE call :connect_wait "!OLD_PROFILE!" !CONNECT_TIMEOUT!
echo [ERROR] Profile switch failed; previous config restored.
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
set "KILLSWITCH=False"
set "WS_CONFIG=%CONFIG%"
set "OUT=!WS_TEMP!\wiresock-config-!RANDOM!-!RANDOM!.txt"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [xml]$x=Get-Content -LiteralPath $env:WS_CONFIG -Raw; $a=$x.SelectSingleNode('//ActiveConfig'); $k=$x.SelectSingleNode('//EnableKillSwitch'); if($a){'ACTIVE='+$a.InnerText}; if($k){'KILL='+$k.InnerText}" >"!OUT!" 2>nul
if exist "!OUT!" (
  for /f "usebackq tokens=1,* delims==" %%A in ("!OUT!") do (
    if /i "%%A"=="ACTIVE" set "ACTIVE_PROFILE=%%B"
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
