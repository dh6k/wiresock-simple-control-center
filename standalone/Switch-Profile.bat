@echo off
setlocal EnableExtensions EnableDelayedExpansion
title WireSock Switch Profile

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
call :read_config

cls
echo Current profile: !ACTIVE_PROFILE!
echo.
set "COUNT=0"
for /f "usebackq delims=" %%L in (`"!CLI!" list 2^>nul`) do (
  set "LINE=%%L"
  for /f "tokens=* delims= " %%T in ("!LINE!") do set "LINE=%%T"
  if "!LINE:~0,2!"=="- " (
    set /a COUNT+=1
    set "PROFILE_!COUNT!=!LINE:~2!"
    if /i "!LINE:~2!"=="!ACTIVE_PROFILE!" (echo [!COUNT!] !LINE:~2! [ACTIVE]) else (echo [!COUNT!] !LINE:~2!)
  )
)
echo [0] Cancel
echo.
set "SEL="
set /p "SEL=Select profile: "
if "!SEL!"=="0" exit /b 0
for %%N in (!SEL!) do set "TARGET=!PROFILE_%%N!"
if not defined TARGET (echo [ERROR] Invalid selection.&pause&exit /b 2)

set "OLD_PROFILE=!ACTIVE_PROFILE!"
call :get_status
if /i "!WSSTATUS!"=="Connected" (
  start "" /b "%CLI%" disconnect >nul 2>&1
  call :wait_disconnected 15
)
if /i "!WSSTATUS!"=="Connecting" taskkill /f /im wiresock-connect-cli.exe >nul 2>&1

copy /y "%CONFIG%" "%CONFIG%.profile-switch-backup" >nul
set "WS_TARGET=!TARGET!"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%CONFIG%';$v=$env:WS_TARGET;$t=[IO.File]::ReadAllText($p);$e=[Security.SecurityElement]::Escape($v);$n=[regex]::Replace($t,'(?is)<ActiveConfig>.*?</ActiveConfig>','<ActiveConfig>'+$e+'</ActiveConfig>',1);[IO.File]::WriteAllText($p,$n,(New-Object Text.UTF8Encoding($false)))"
if errorlevel 1 goto rollback
call :read_config

call :connect_wait "!TARGET!" !CONNECT_TIMEOUT!
if errorlevel 1 goto rollback

echo Connected: !TARGET!
timeout /t 2 /nobreak >nul
exit /b 0

:rollback
start "" /b "%CLI%" disconnect >nul 2>&1
taskkill /f /im wiresock-connect-cli.exe >nul 2>&1
if /i "!KILLSWITCH!"=="False" "%CLI%" reset-network-lock >nul 2>&1
copy /y "%CONFIG%.profile-switch-backup" "%CONFIG%" >nul
call :read_config
if defined OLD_PROFILE call :connect_wait "!OLD_PROFILE!" !CONNECT_TIMEOUT!
echo [ERROR] Profile switch failed; previous config restored.
pause
exit /b 3

:find_cli
for /f "delims=" %%F in ('where wiresock-connect-cli.exe 2^>nul') do if not defined CLI set "CLI=%%F"
if not defined CLI if exist "C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe" set "CLI=C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe"
if not defined CLI if exist "C:\Program Files\WireSock Secure Connect\command-line\wiresock-connect-cli.exe" set "CLI=C:\Program Files\WireSock Secure Connect\command-line\wiresock-connect-cli.exe"
exit /b 0

:read_config
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "[xml]$x=Get-Content -LiteralPath '%CONFIG%' -Raw;$x.SelectSingleNode('//ActiveConfig').InnerText"`) do set "ACTIVE_PROFILE=%%V"
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
