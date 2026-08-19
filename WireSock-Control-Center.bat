@echo off
setlocal EnableExtensions EnableDelayedExpansion
title WireSock Control Center

set "CONFIG=C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config"
set "SETTINGS=%~dp0WireSock-Control-Center.ini"
set "CONNECT_TIMEOUT=15"
set "CLI="
set "GUI_EXE="
set "GUI_STATUS=UNKNOWN"
set "ACTIVE_PROFILE="
set "SPLIT=False"
set "KILLSWITCH=False"
set "WSSTATUS=UNKNOWN"

rem ============================================================
rem Elevate and force a valid working directory.
rem This matters when the BAT is launched from a freshly cloned repo,
rem Explorer, a shortcut, another drive, or after UAC changes context.
rem ============================================================
net session >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -WorkingDirectory '%~dp0' -Verb RunAs"
  exit /b
)

pushd "%~dp0" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Cannot access script directory:
  echo %~dp0
  pause
  exit /b 1
)

call :load_settings
call :find_cli

goto menu

:menu
call :read_config
call :get_status
call :get_gui_status
cls
echo ============================================================
echo                 WireSock Control Center
echo ============================================================
echo.
echo VPN Status       : !WSSTATUS!
echo WireSock GUI     : !GUI_STATUS!
echo Active Profile   : !ACTIVE_PROFILE!
if /i "!SPLIT!"=="True" (echo Split Tunneling  : ON) else (echo Split Tunneling  : OFF)
if /i "!KILLSWITCH!"=="True" (echo Kill Switch      : ON) else (echo Kill Switch      : OFF)
echo Connect Timeout  : !CONNECT_TIMEOUT! seconds
echo.
echo [1] Toggle VPN
echo [2] Toggle Split Tunneling
echo [3] Switch Profile
echo [4] Check Installation Status
echo [5] Set Connection Timeout
echo [6] Toggle WireSock GUI
echo [0] Exit
echo.
set "CHOICE="
set /p "CHOICE=Select: "
if "!CHOICE!"=="1" goto toggle_vpn
if "!CHOICE!"=="2" goto toggle_split
if "!CHOICE!"=="3" goto switch_profile
if "!CHOICE!"=="4" goto check_install
if "!CHOICE!"=="5" goto set_timeout
if "!CHOICE!"=="6" goto toggle_gui
if "!CHOICE!"=="0" goto exit_script
goto menu

rem ============================================================
rem Toggle WireSock GUI only. Does not touch the VPN tunnel/service.
rem ============================================================
:toggle_gui
call :find_gui
if not defined GUI_EXE (
  cls
  echo ============================================================
  echo   Toggle WireSock GUI
  echo ============================================================
  echo.
  echo [ERROR] WireSock GUI executable was not found.
  echo.
  echo Detection checks Start Menu shortcuts and common install paths.
  echo VPN/tunnel state was not changed.
  echo.
  pause
  goto menu
)

call :get_gui_status
cls
echo ============================================================
echo   Toggle WireSock GUI
 echo ============================================================
echo.
echo GUI executable : !GUI_EXE!
echo GUI status     : !GUI_STATUS!
echo.

if /i "!GUI_STATUS!"=="ON" goto gui_off

echo Opening WireSock GUI...
rem Explorer starts the GUI in the interactive desktop session.
explorer.exe "!GUI_EXE!" >nul 2>&1
timeout /t 2 /nobreak >nul
call :get_gui_status
if /i "!GUI_STATUS!"=="ON" (
  echo WireSock GUI: ON
  timeout /t 2 /nobreak >nul
) else (
  echo [ERROR] WireSock GUI did not start.
  pause
)
goto menu

:gui_off
echo Closing WireSock GUI only...
set "WS_GUI_EXE=!GUI_EXE!"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$target=$env:WS_GUI_EXE; foreach($p in @(Get-Process -ErrorAction SilentlyContinue)){ try { if($p.Path -and ([IO.Path]::GetFullPath($p.Path) -ieq [IO.Path]::GetFullPath($target))){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } } catch {} }" >nul 2>&1
timeout /t 1 /nobreak >nul
call :get_gui_status
if /i "!GUI_STATUS!"=="OFF" (
  echo WireSock GUI: OFF
  timeout /t 2 /nobreak >nul
) else (
  echo [ERROR] WireSock GUI is still running.
  pause
)
goto menu

rem ============================================================
rem Toggle VPN
rem ============================================================
:toggle_vpn
call :require_runtime
if errorlevel 1 goto menu
call :read_config
call :get_status
if /i "!WSSTATUS!"=="Connected" goto vpn_off
if /i "!WSSTATUS!"=="Connecting" goto vpn_off
if /i "!WSSTATUS!"=="Disconnecting" call :wait_disconnected 10
goto vpn_on

:vpn_off
echo Disconnecting WireSock...
call :disconnect_wait 15
if errorlevel 1 call :force_disconnect
if /i "!KILLSWITCH!"=="False" "%CLI%" reset-network-lock >nul 2>&1
goto menu

:vpn_on
if not defined ACTIVE_PROFILE (
  echo [ERROR] ActiveConfig is empty.
  pause
  goto menu
)
echo Connecting !ACTIVE_PROFILE!...
call :connect_wait "!ACTIVE_PROFILE!" !CONNECT_TIMEOUT!
if errorlevel 1 (
  echo [ERROR] Connect timed out after !CONNECT_TIMEOUT! seconds.
  call :force_disconnect
  if /i "!KILLSWITCH!"=="False" "%CLI%" reset-network-lock >nul 2>&1
  pause
)
goto menu

rem ============================================================
rem Toggle global split tunneling
rem ============================================================
:toggle_split
call :require_runtime
if errorlevel 1 goto menu
call :read_config
call :get_status
set "WAS_CONNECTED=0"
if /i "!WSSTATUS!"=="Connected" set "WAS_CONNECTED=1"
if /i "!WSSTATUS!"=="Connecting" set "WAS_CONNECTED=1"

if "!WAS_CONNECTED!"=="1" (
  call :disconnect_wait 15
  if errorlevel 1 call :force_disconnect
)

copy /y "%CONFIG%" "%CONFIG%.control-center-backup" >nul
if errorlevel 1 (
  echo [ERROR] Could not create config backup.
  pause
  goto menu
)

if /i "!SPLIT!"=="True" (set "NEW_SPLIT=False") else (set "NEW_SPLIT=True")
set "WS_NEW_SPLIT=!NEW_SPLIT!"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p='%CONFIG%'; $v=$env:WS_NEW_SPLIT; $t=[IO.File]::ReadAllText($p); $pat='(?i)<EnableSplitTunnelingGlobally>\s*(True|False)\s*</EnableSplitTunnelingGlobally>'; if(([regex]::Matches($t,$pat)).Count -ne 1){exit 10}; $n=[regex]::Replace($t,$pat,'<EnableSplitTunnelingGlobally>'+$v+'</EnableSplitTunnelingGlobally>',1); [IO.File]::WriteAllText($p,$n,(New-Object Text.UTF8Encoding($false)))" >nul 2>&1
if errorlevel 1 goto split_rollback

call :read_config
if /i not "!SPLIT!"=="!NEW_SPLIT!" goto split_rollback

if "!WAS_CONNECTED!"=="1" (
  call :connect_wait "!ACTIVE_PROFILE!" !CONNECT_TIMEOUT!
  if errorlevel 1 goto split_rollback
)
goto menu

:split_rollback
call :force_disconnect
copy /y "%CONFIG%.control-center-backup" "%CONFIG%" >nul
call :read_config
if "!WAS_CONNECTED!"=="1" call :connect_wait "!ACTIVE_PROFILE!" !CONNECT_TIMEOUT!
if /i "!KILLSWITCH!"=="False" "%CLI%" reset-network-lock >nul 2>&1
echo [ERROR] Split tunneling change failed; previous config restored.
pause
goto menu

rem ============================================================
rem Switch profile
rem ============================================================
:switch_profile
call :require_runtime
if errorlevel 1 goto menu
call :read_config
cls
echo ============================================================
echo   Switch WireSock Profile
echo ============================================================
echo.
echo Current profile: !ACTIVE_PROFILE!
echo.
set "COUNT=0"
set "LIST_FILE=%TEMP%\wiresock-list-%RANDOM%-%RANDOM%.txt"
"!CLI!" list >"!LIST_FILE!" 2>nul
for /f "usebackq delims=" %%L in ("!LIST_FILE!") do (
  set "LINE=%%L"
  for /f "tokens=* delims= " %%T in ("!LINE!") do set "LINE=%%T"
  if "!LINE:~0,2!"=="- " (
    set /a COUNT+=1
    set "PROFILE_!COUNT!=!LINE:~2!"
    if /i "!LINE:~2!"=="!ACTIVE_PROFILE!" (echo [!COUNT!] !LINE:~2! [ACTIVE]) else (echo [!COUNT!] !LINE:~2!)
  )
)
del "!LIST_FILE!" >nul 2>&1

echo [0] Back
echo.
set "SEL="
set /p "SEL=Select profile: "
if "!SEL!"=="0" goto menu
echo(!SEL!| findstr /r "^[0-9][0-9]*$" >nul || goto menu
if !SEL! LSS 1 goto menu
if !SEL! GTR !COUNT! goto menu
for %%N in (!SEL!) do set "TARGET=!PROFILE_%%N!"
if not defined TARGET goto menu

set "OLD_PROFILE=!ACTIVE_PROFILE!"
call :get_status
if /i "!WSSTATUS!"=="Connected" call :disconnect_wait 15
if /i "!WSSTATUS!"=="Connecting" call :force_disconnect

copy /y "%CONFIG%" "%CONFIG%.control-center-backup" >nul
if errorlevel 1 (
  echo [ERROR] Could not create config backup.
  pause
  goto menu
)

set "WS_TARGET=!TARGET!"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p='%CONFIG%'; $v=$env:WS_TARGET; $t=[IO.File]::ReadAllText($p); $pat='(?is)<ActiveConfig>.*?</ActiveConfig>'; if(([regex]::Matches($t,$pat)).Count -ne 1){exit 10}; $e=[Security.SecurityElement]::Escape($v); $n=[regex]::Replace($t,$pat,'<ActiveConfig>'+$e+'</ActiveConfig>',1); [IO.File]::WriteAllText($p,$n,(New-Object Text.UTF8Encoding($false)))" >nul 2>&1
if errorlevel 1 goto profile_rollback

call :read_config
if /i not "!ACTIVE_PROFILE!"=="!TARGET!" goto profile_rollback
call :connect_wait "!TARGET!" !CONNECT_TIMEOUT!
if errorlevel 1 goto profile_rollback
goto menu

:profile_rollback
call :force_disconnect
if /i "!KILLSWITCH!"=="False" "%CLI%" reset-network-lock >nul 2>&1
copy /y "%CONFIG%.control-center-backup" "%CONFIG%" >nul
call :read_config
if defined OLD_PROFILE call :connect_wait "!OLD_PROFILE!" !CONNECT_TIMEOUT!
echo [ERROR] Profile switch failed; previous config restored.
pause
goto menu

rem ============================================================
rem Installation check
rem ============================================================
:check_install
call :find_cli
call :read_config
call :get_status
call :get_gui_status
cls
echo ============================================================
echo WireSock Installation Status
echo ============================================================
where winget.exe >nul 2>&1 && (echo WinGet          : OK) || (echo WinGet          : NOT FOUND)
if defined CLI (echo CLI executable  : OK&echo CLI path        : !CLI!) else (echo CLI executable  : NOT FOUND)
where wiresock-connect-cli.exe >nul 2>&1 && (echo CLI in PATH     : YES) || (echo CLI in PATH     : NO)
if defined GUI_EXE (echo GUI executable  : OK&echo GUI path        : !GUI_EXE!) else (echo GUI executable  : NOT FOUND)
echo GUI status      : !GUI_STATUS!
if exist "%CONFIG%" (echo Config file     : OK) else (echo Config file     : NOT FOUND)
echo Active profile  : !ACTIVE_PROFILE!
if /i "!SPLIT!"=="True" (echo Split tunneling: ON) else (echo Split tunneling: OFF)
if /i "!KILLSWITCH!"=="True" (echo Kill Switch     : ON) else (echo Kill Switch     : OFF)
echo VPN status      : !WSSTATUS!
echo Timeout         : !CONNECT_TIMEOUT! seconds
echo.
pause
goto menu

rem ============================================================
rem Timeout settings
rem ============================================================
:set_timeout
cls
echo Current timeout: !CONNECT_TIMEOUT! seconds
echo Enter 5-120, or 0 to cancel.
set "NEW_TIMEOUT="
set /p "NEW_TIMEOUT=New timeout: "
if "!NEW_TIMEOUT!"=="0" goto menu
echo(!NEW_TIMEOUT!| findstr /r "^[0-9][0-9]*$" >nul || goto set_timeout
if !NEW_TIMEOUT! LSS 5 goto set_timeout
if !NEW_TIMEOUT! GTR 120 goto set_timeout
set "CONNECT_TIMEOUT=!NEW_TIMEOUT!"
>"%SETTINGS%" echo CONNECT_TIMEOUT=!CONNECT_TIMEOUT!
goto menu

:load_settings
if not exist "%SETTINGS%" exit /b 0
for /f "usebackq tokens=1,* delims==" %%A in ("%SETTINGS%") do if /i "%%A"=="CONNECT_TIMEOUT" set "CONNECT_TIMEOUT=%%B"
echo(!CONNECT_TIMEOUT!| findstr /r "^[0-9][0-9]*$" >nul || set "CONNECT_TIMEOUT=15"
if !CONNECT_TIMEOUT! LSS 5 set "CONNECT_TIMEOUT=15"
if !CONNECT_TIMEOUT! GTR 120 set "CONNECT_TIMEOUT=15"
exit /b 0

rem ============================================================
rem Find CLI without relying on the current directory.
rem ============================================================
:find_cli
set "CLI="
set "WHERE_FILE=%TEMP%\wiresock-where-%RANDOM%-%RANDOM%.txt"
where wiresock-connect-cli.exe >"!WHERE_FILE!" 2>nul
if exist "!WHERE_FILE!" set /p "CLI="<"!WHERE_FILE!"
del "!WHERE_FILE!" >nul 2>&1
if defined CLI exit /b 0
if exist "C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe" set "CLI=C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe"
if not defined CLI if exist "C:\Program Files\WireSock Secure Connect\command-line\wiresock-connect-cli.exe" set "CLI=C:\Program Files\WireSock Secure Connect\command-line\wiresock-connect-cli.exe"
exit /b 0

:require_runtime
call :find_cli
if not defined CLI (
  echo [ERROR] WireSock CLI not found.
  pause
  exit /b 1
)
if not exist "%CONFIG%" (
  echo [ERROR] wiresock.config not found.
  pause
  exit /b 1
)
exit /b 0

rem ============================================================
rem Read config in ONE PowerShell process.
rem No FOR /F command substitution, which was the source of the
rem cloned-folder/UAC path failure in the previous revision.
rem ============================================================
:read_config
set "ACTIVE_PROFILE="
set "SPLIT=False"
set "KILLSWITCH=False"
if not exist "%CONFIG%" exit /b 0

set "CFG_FILE=%TEMP%\wiresock-config-%RANDOM%-%RANDOM%.txt"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [xml]$x=Get-Content -LiteralPath '%CONFIG%' -Raw; $a=$x.SelectSingleNode('//ActiveConfig'); $s=$x.SelectSingleNode('//EnableSplitTunnelingGlobally'); $k=$x.SelectSingleNode('//EnableKillSwitch'); if($a){'ACTIVE='+$a.InnerText}; if($s){'SPLIT='+$s.InnerText}; if($k){'KILL='+$k.InnerText}" >"!CFG_FILE!" 2>nul
if exist "!CFG_FILE!" (
  for /f "usebackq tokens=1,* delims==" %%A in ("!CFG_FILE!") do (
    if /i "%%A"=="ACTIVE" set "ACTIVE_PROFILE=%%B"
    if /i "%%A"=="SPLIT" set "SPLIT=%%B"
    if /i "%%A"=="KILL" set "KILLSWITCH=%%B"
  )
  del "!CFG_FILE!" >nul 2>&1
)
exit /b 0

rem ============================================================
rem GUI detection.
rem Important: PowerShell output is redirected to a normal temp file.
rem We intentionally do NOT run the complex PowerShell inside FOR /F.
rem ============================================================
:find_gui
set "GUI_EXE="
set "GUI_FILE=%TEMP%\wiresock-gui-%RANDOM%-%RANDOM%.txt"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $target=$null; $roots=@([IO.Path]::Combine($env:ProgramData,'Microsoft\Windows\Start Menu\Programs'),[IO.Path]::Combine($env:APPDATA,'Microsoft\Windows\Start Menu\Programs')); $shell=New-Object -ComObject WScript.Shell; foreach($r in $roots){ if($r -and (Test-Path -LiteralPath $r)){ foreach($lnk in @(Get-ChildItem -LiteralPath $r -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue)){ if($lnk.BaseName -match 'WireSock.*Secure.*Connect'){ $t=$shell.CreateShortcut($lnk.FullName).TargetPath; if($t -and (Test-Path -LiteralPath $t)){ $target=$t; break } } }; if($target){break} } }; if(-not $target){ foreach($d in @('C:\Program Files\Wiresock Secure Connect','C:\Program Files\WireSock Secure Connect')){ if(Test-Path -LiteralPath $d){ foreach($c in @(Get-ChildItem -LiteralPath $d -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue)){ if($c.FullName -match '\\command-line\\'){continue}; if($c.Name -match 'wiresock-connect-cli|wiresock-client|unins|uninstall|updater|update'){continue}; if($c.VersionInfo.ProductName -match 'WireSock.*Secure.*Connect' -or $c.VersionInfo.FileDescription -match 'WireSock.*Secure.*Connect'){ $target=$c.FullName; break } }; if($target){break} } } }; if($target){$target}" >"!GUI_FILE!" 2>nul

if exist "!GUI_FILE!" set /p "GUI_EXE="<"!GUI_FILE!"
del "!GUI_FILE!" >nul 2>&1
exit /b 0

:get_gui_status
call :find_gui
set "GUI_STATUS=NOT FOUND"
if not defined GUI_EXE exit /b 0
set "WS_GUI_EXE=!GUI_EXE!"
set "GUI_STATE_FILE=%TEMP%\wiresock-gui-state-%RANDOM%-%RANDOM%.txt"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$target=$env:WS_GUI_EXE; $found=$false; foreach($p in @(Get-Process -ErrorAction SilentlyContinue)){ try { if($p.Path -and ([IO.Path]::GetFullPath($p.Path) -ieq [IO.Path]::GetFullPath($target))){$found=$true;break} } catch {} }; if($found){'ON'}else{'OFF'}" >"!GUI_STATE_FILE!" 2>nul
if exist "!GUI_STATE_FILE!" set /p "GUI_STATUS="<"!GUI_STATE_FILE!"
del "!GUI_STATE_FILE!" >nul 2>&1
exit /b 0

rem ============================================================
rem WireSock status helpers
rem ============================================================
:get_status
set "WSSTATUS=UNKNOWN"
if not defined CLI exit /b 0
set "SF=%TEMP%\wiresock-status-%RANDOM%-%RANDOM%.txt"
"%CLI%" status >"!SF!" 2>&1
findstr /i /c:"NotConnected" /c:"Not Connected" "!SF!" >nul && set "WSSTATUS=NotConnected"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Disconnecting" "!SF!" >nul && set "WSSTATUS=Disconnecting"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Disconnected" "!SF!" >nul && set "WSSTATUS=Disconnected"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Connecting" "!SF!" >nul && set "WSSTATUS=Connecting"
if /i "!WSSTATUS!"=="UNKNOWN" findstr /i /c:"Connected" "!SF!" >nul && set "WSSTATUS=Connected"
del "!SF!" >nul 2>&1
exit /b 0

:wait_disconnected
set "WAIT=%~1"
for /l %%I in (1,1,!WAIT!) do (
  call :get_status
  if /i "!WSSTATUS!"=="NotConnected" exit /b 0
  if /i "!WSSTATUS!"=="Disconnected" exit /b 0
  timeout /t 1 /nobreak >nul
)
exit /b 1

:disconnect_wait
start "" /b "%CLI%" disconnect >nul 2>&1
call :wait_disconnected %~1
exit /b !errorlevel!

:force_disconnect
start "" /b "%CLI%" disconnect >nul 2>&1
call :wait_disconnected 8
taskkill /f /im wiresock-connect-cli.exe >nul 2>&1
exit /b 0

:connect_wait
set "CP=%~1"
set "WAIT=%~2"
if /i "!KILLSWITCH!"=="True" (set "LOCK=on") else (set "LOCK=off")
start "" /b "%CLI%" connect "!CP!" -log-level error -network-lock !LOCK! -exit >nul 2>&1
for /l %%I in (1,1,!WAIT!) do (
  call :get_status
  if /i "!WSSTATUS!"=="Connected" exit /b 0
  if %%I GTR 3 if /i "!WSSTATUS!"=="NotConnected" exit /b 1
  if %%I GTR 3 if /i "!WSSTATUS!"=="Disconnected" exit /b 1
  timeout /t 1 /nobreak >nul
)
exit /b 1

:exit_script
popd >nul 2>&1
exit /b 0
