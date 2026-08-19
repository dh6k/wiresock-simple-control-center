@echo off
setlocal EnableExtensions EnableDelayedExpansion
title WireSock Control Center

set "CONFIG=C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config"
set "PROFILES_DIR=C:\ProgramData\WireSock Foundation\WireSock Secure Connect\Profiles"
set "SETTINGS=%~dp0WireSock-Control-Center.ini"
set "LOG_DIR=%~dp0logs"
set "CONNECT_TIMEOUT=15"
set "CLI="
set "GUI_EXE="
set "GUI_STATUS=UNKNOWN"
set "ACTIVE_PROFILE="
set "SPLIT=False"
set "KILLSWITCH=False"
set "WSSTATUS=UNKNOWN"
set "PROFILE_COUNT=0"
set "LAST_STARTUP_LOG="

rem ============================================================
rem Elevate and force a valid working directory.
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
call :startup_monitor

goto menu

rem ============================================================
rem MAIN MENU
rem ============================================================
:menu
call :find_cli
call :read_config
call :get_status
call :get_gui_status
call :load_profiles
cls
echo ============================================================
echo                 WireSock Control Center
echo ============================================================
echo.
echo VPN Status       : !WSSTATUS!
echo WireSock GUI     : !GUI_STATUS!
echo Active Profile   : !ACTIVE_PROFILE!
echo Profiles         : !PROFILE_COUNT!
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
echo [7] Profile Manager
echo [8] Run Startup Monitor
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
if "!CHOICE!"=="7" goto profile_manager
if "!CHOICE!"=="8" goto run_startup_monitor
if "!CHOICE!"=="0" goto exit_script
goto menu

rem ============================================================
rem STARTUP MONITOR / PREFLIGHT
rem Runs automatically before the first menu and can be rerun.
rem It is read-only: no VPN/profile/settings changes are made.
rem ============================================================
:run_startup_monitor
call :startup_monitor

goto menu

:startup_monitor
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1

set "STAMP_FILE=%TEMP%\wiresock-stamp-%RANDOM%-%RANDOM%.txt"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-Date -Format yyyyMMdd-HHmmss" >"!STAMP_FILE!" 2>nul
set "STARTUP_STAMP=%RANDOM%-%RANDOM%"
if exist "!STAMP_FILE!" set /p "STARTUP_STAMP="<"!STAMP_FILE!"
del "!STAMP_FILE!" >nul 2>&1

set "LAST_STARTUP_LOG=%LOG_DIR%\startup-!STARTUP_STAMP!.log"
>"!LAST_STARTUP_LOG!" echo WireSock Control Center startup monitor
>>"!LAST_STARTUP_LOG!" echo Timestamp: !STARTUP_STAMP!
>>"!LAST_STARTUP_LOG!" echo Script: %~f0
>>"!LAST_STARTUP_LOG!" echo.

cls
echo ============================================================
echo            WireSock Control Center - Preflight
echo ============================================================
echo.

echo [OK]   Script directory : %~dp0
>>"!LAST_STARTUP_LOG!" echo [OK] Script directory: %~dp0

call :find_cli
if defined CLI (
  echo [OK]   WireSock CLI    : !CLI!
  >>"!LAST_STARTUP_LOG!" echo [OK] WireSock CLI: !CLI!
) else (
  echo [WARN] WireSock CLI    : NOT FOUND
  >>"!LAST_STARTUP_LOG!" echo [WARN] WireSock CLI: NOT FOUND
)

if exist "%CONFIG%" (
  echo [OK]   Config file     : FOUND
  >>"!LAST_STARTUP_LOG!" echo [OK] Config file: %CONFIG%
) else (
  echo [WARN] Config file     : NOT FOUND
  >>"!LAST_STARTUP_LOG!" echo [WARN] Config file: NOT FOUND - %CONFIG%
)

call :read_config
if defined ACTIVE_PROFILE (
  echo [OK]   Active profile  : !ACTIVE_PROFILE!
  >>"!LAST_STARTUP_LOG!" echo [OK] Active profile: !ACTIVE_PROFILE!
) else (
  echo [WARN] Active profile  : UNKNOWN
  >>"!LAST_STARTUP_LOG!" echo [WARN] Active profile: UNKNOWN
)

if /i "!SPLIT!"=="True" (
  echo [OK]   Split tunneling : ON
  >>"!LAST_STARTUP_LOG!" echo [OK] Split tunneling: ON
) else if /i "!SPLIT!"=="False" (
  echo [OK]   Split tunneling : OFF
  >>"!LAST_STARTUP_LOG!" echo [OK] Split tunneling: OFF
) else (
  echo [WARN] Split tunneling : UNKNOWN
  >>"!LAST_STARTUP_LOG!" echo [WARN] Split tunneling: UNKNOWN
)

call :load_profiles
if !PROFILE_COUNT! GTR 0 (
  echo [OK]   Profiles        : !PROFILE_COUNT!
  >>"!LAST_STARTUP_LOG!" echo [OK] Profiles: !PROFILE_COUNT!
) else (
  echo [WARN] Profiles        : NONE / UNAVAILABLE
  >>"!LAST_STARTUP_LOG!" echo [WARN] Profiles: NONE / UNAVAILABLE
)

call :get_status
if /i "!WSSTATUS!"=="UNKNOWN" (
  echo [WARN] VPN status      : UNKNOWN
  >>"!LAST_STARTUP_LOG!" echo [WARN] VPN status: UNKNOWN
) else (
  echo [OK]   VPN status      : !WSSTATUS!
  >>"!LAST_STARTUP_LOG!" echo [OK] VPN status: !WSSTATUS!
)

call :get_gui_status
if /i "!GUI_STATUS!"=="NOT FOUND" (
  echo [WARN] WireSock GUI    : NOT FOUND
  >>"!LAST_STARTUP_LOG!" echo [WARN] WireSock GUI: NOT FOUND
) else (
  echo [OK]   WireSock GUI    : !GUI_STATUS!
  >>"!LAST_STARTUP_LOG!" echo [OK] WireSock GUI: !GUI_STATUS!
)

echo [OK]   Connect timeout  : !CONNECT_TIMEOUT! seconds
>>"!LAST_STARTUP_LOG!" echo [OK] Connect timeout: !CONNECT_TIMEOUT! seconds

echo.
echo Log: !LAST_STARTUP_LOG!
echo.
echo Starting Control Center...
timeout /t 2 /nobreak >nul
exit /b 0

rem ============================================================
rem Toggle WireSock GUI only. Does not touch VPN tunnel/service.
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
rem Switch profile and connect it
rem ============================================================
:switch_profile
call :require_runtime
if errorlevel 1 goto menu
call :read_config
call :choose_profile
if errorlevel 1 goto menu
set "TARGET=!SELECTED_PROFILE!"

if /i "!TARGET!"=="!ACTIVE_PROFILE!" (
  call :get_status
  if /i "!WSSTATUS!"=="Connected" (
    echo Already connected to !TARGET!.
    timeout /t 2 /nobreak >nul
    goto menu
  )
)

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
rem PROFILE MANAGER
rem CLI-supported primitives: list/import/export/delete.
rem Duplicate/Rename are composed safely from export + import.
rem ============================================================
:profile_manager
call :require_runtime
if errorlevel 1 goto menu
call :read_config
call :load_profiles
cls
echo ============================================================
echo                  WireSock Profile Manager
echo ============================================================
echo.
echo Active Profile : !ACTIVE_PROFILE!
echo Profiles       : !PROFILE_COUNT!
echo.
echo [1] List Profiles
echo [2] Import Profile (.conf)
echo [3] Export Profile
echo [4] View Profile
echo [5] Duplicate Profile
echo [6] Rename Profile
echo [7] Delete Profile
echo [8] Open Profiles Folder
echo [0] Back
echo.
set "PM_CHOICE="
set /p "PM_CHOICE=Select: "
if "!PM_CHOICE!"=="1" goto pm_list
if "!PM_CHOICE!"=="2" goto pm_import
if "!PM_CHOICE!"=="3" goto pm_export
if "!PM_CHOICE!"=="4" goto pm_view
if "!PM_CHOICE!"=="5" goto pm_duplicate
if "!PM_CHOICE!"=="6" goto pm_rename
if "!PM_CHOICE!"=="7" goto pm_delete
if "!PM_CHOICE!"=="8" goto pm_open_folder
if "!PM_CHOICE!"=="0" goto menu
goto profile_manager

:pm_list
call :read_config
call :load_profiles
cls
echo ============================================================
echo   WireSock Profiles
echo ============================================================
echo.
if !PROFILE_COUNT! LEQ 0 (
  echo No profiles found or WireSock service is unavailable.
) else (
  for /l %%I in (1,1,!PROFILE_COUNT!) do (
    if /i "!PROFILE_%%I!"=="!ACTIVE_PROFILE!" (
      echo [%%I] !PROFILE_%%I! [ACTIVE]
    ) else (
      echo [%%I] !PROFILE_%%I!
    )
  )
)
echo.
pause
goto profile_manager

:pm_import
set "IMPORT_PICK=%TEMP%\wiresock-import-pick-%RANDOM%-%RANDOM%.txt"
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.OpenFileDialog; $d.Title='Import WireSock profile'; $d.Filter='WireGuard configuration (*.conf)|*.conf|All files (*.*)|*.*'; $d.Multiselect=$false; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){$d.FileName}" >"!IMPORT_PICK!" 2>nul
set "IMPORT_PATH="
if exist "!IMPORT_PICK!" set /p "IMPORT_PATH="<"!IMPORT_PICK!"
del "!IMPORT_PICK!" >nul 2>&1
if not defined IMPORT_PATH goto profile_manager

cls
echo Importing:
echo !IMPORT_PATH!
echo.
"!CLI!" import "!IMPORT_PATH!"
if errorlevel 1 (
  echo.
  echo [ERROR] Import failed.
) else (
  echo.
  echo [OK] Profile imported.
)
echo.
pause
goto profile_manager

:pm_export
call :choose_profile
if errorlevel 1 goto profile_manager
set "EXPORT_PROFILE=!SELECTED_PROFILE!"
set "EXPORT_PICK=%TEMP%\wiresock-export-pick-%RANDOM%-%RANDOM%.txt"
set "WS_EXPORT_NAME=!EXPORT_PROFILE!"
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.SaveFileDialog; $d.Title='Export WireSock profile'; $d.Filter='WireGuard configuration (*.conf)|*.conf|All files (*.*)|*.*'; $d.FileName=$env:WS_EXPORT_NAME+'.conf'; $d.OverwritePrompt=$true; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){$d.FileName}" >"!EXPORT_PICK!" 2>nul
set "EXPORT_PATH="
if exist "!EXPORT_PICK!" set /p "EXPORT_PATH="<"!EXPORT_PICK!"
del "!EXPORT_PICK!" >nul 2>&1
if not defined EXPORT_PATH goto profile_manager

if exist "!EXPORT_PATH!" del /q "!EXPORT_PATH!" >nul 2>&1
"!CLI!" export "!EXPORT_PROFILE!" "!EXPORT_PATH!"
if errorlevel 1 (
  echo.
  echo [ERROR] Export failed.
) else (
  echo.
  echo [OK] Exported to:
  echo !EXPORT_PATH!
)
echo.
pause
goto profile_manager

:pm_view
call :choose_profile
if errorlevel 1 goto profile_manager
set "VIEW_PROFILE=!SELECTED_PROFILE!"
set "VIEW_DIR=%TEMP%\wiresock-view-%RANDOM%-%RANDOM%"
mkdir "!VIEW_DIR!" >nul 2>&1
set "VIEW_FILE=!VIEW_DIR!\!VIEW_PROFILE!.conf"
"!CLI!" export "!VIEW_PROFILE!" "!VIEW_FILE!" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Could not export profile for viewing.
  rd /s /q "!VIEW_DIR!" >nul 2>&1
  pause
  goto profile_manager
)
notepad.exe "!VIEW_FILE!"
rd /s /q "!VIEW_DIR!" >nul 2>&1
goto profile_manager

:pm_duplicate
call :choose_profile
if errorlevel 1 goto profile_manager
set "SOURCE_PROFILE=!SELECTED_PROFILE!"
call :prompt_new_profile_name "Duplicate profile as"
if errorlevel 1 goto profile_manager
set "NEW_PROFILE=!NEW_PROFILE_NAME!"
call :profile_exists "!NEW_PROFILE!"
if not errorlevel 1 (
  echo [ERROR] A profile named !NEW_PROFILE! already exists.
  pause
  goto profile_manager
)
call :copy_profile_as "!SOURCE_PROFILE!" "!NEW_PROFILE!"
if errorlevel 1 (
  echo [ERROR] Duplicate failed.
) else (
  echo [OK] Created profile: !NEW_PROFILE!
)
echo.
pause
goto profile_manager

:pm_rename
call :read_config
call :choose_profile
if errorlevel 1 goto profile_manager
set "SOURCE_PROFILE=!SELECTED_PROFILE!"
if /i "!SOURCE_PROFILE!"=="!ACTIVE_PROFILE!" (
  echo.
  echo [BLOCKED] Rename the active profile only after switching away from it.
  echo This avoids leaving ActiveConfig pointing at a deleted name.
  echo.
  pause
  goto profile_manager
)
call :prompt_new_profile_name "Rename profile to"
if errorlevel 1 goto profile_manager
set "NEW_PROFILE=!NEW_PROFILE_NAME!"
call :profile_exists "!NEW_PROFILE!"
if not errorlevel 1 (
  echo [ERROR] A profile named !NEW_PROFILE! already exists.
  pause
  goto profile_manager
)

call :copy_profile_as "!SOURCE_PROFILE!" "!NEW_PROFILE!"
if errorlevel 1 (
  echo [ERROR] Could not create the new profile. Original was not changed.
  pause
  goto profile_manager
)

"!CLI!" delete "!SOURCE_PROFILE!" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] New profile was created but old profile could not be deleted.
  echo Rolling back the new profile...
  "!CLI!" delete "!NEW_PROFILE!" >nul 2>&1
  pause
  goto profile_manager
)

echo [OK] Renamed !SOURCE_PROFILE! to !NEW_PROFILE!.
pause
goto profile_manager

:pm_delete
call :read_config
call :choose_profile
if errorlevel 1 goto profile_manager
set "DELETE_PROFILE=!SELECTED_PROFILE!"
if /i "!DELETE_PROFILE!"=="!ACTIVE_PROFILE!" (
  echo.
  echo [BLOCKED] Cannot delete the active profile.
  echo Switch to another profile first.
  echo.
  pause
  goto profile_manager
)

cls
echo ============================================================
echo   Delete WireSock Profile
echo ============================================================
echo.
echo Profile: !DELETE_PROFILE!
echo.
set "CONFIRM="
set /p "CONFIRM=Type DELETE to confirm: "
if /i not "!CONFIRM!"=="DELETE" goto profile_manager

"!CLI!" delete "!DELETE_PROFILE!"
if errorlevel 1 (
  echo.
  echo [ERROR] Delete failed.
) else (
  echo.
  echo [OK] Profile deleted.
)
echo.
pause
goto profile_manager

:pm_open_folder
if exist "%PROFILES_DIR%" (
  explorer.exe "%PROFILES_DIR%"
) else (
  echo [ERROR] Profiles directory not found:
  echo %PROFILES_DIR%
  pause
)
goto profile_manager

rem ============================================================
rem Installation check
rem ============================================================
:check_install
call :find_cli
call :read_config
call :get_status
call :get_gui_status
call :load_profiles
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
if exist "%PROFILES_DIR%" (echo Profiles folder : OK) else (echo Profiles folder : NOT FOUND)
echo Profile count   : !PROFILE_COUNT!
echo Active profile  : !ACTIVE_PROFILE!
if /i "!SPLIT!"=="True" (echo Split tunneling: ON) else (echo Split tunneling: OFF)
if /i "!KILLSWITCH!"=="True" (echo Kill Switch     : ON) else (echo Kill Switch     : OFF)
echo VPN status      : !WSSTATUS!
echo Timeout         : !CONNECT_TIMEOUT! seconds
if defined LAST_STARTUP_LOG echo Startup log     : !LAST_STARTUP_LOG!
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
rem Profile helper routines
rem ============================================================
:load_profiles
for /l %%I in (1,1,200) do set "PROFILE_%%I="
set "PROFILE_COUNT=0"
if not defined CLI exit /b 0
set "LIST_FILE=%TEMP%\wiresock-list-%RANDOM%-%RANDOM%.txt"
"!CLI!" list >"!LIST_FILE!" 2>nul
if exist "!LIST_FILE!" (
  for /f "usebackq delims=" %%L in ("!LIST_FILE!") do (
    set "LINE=%%L"
    for /f "tokens=* delims= " %%T in ("!LINE!") do set "LINE=%%T"
    if "!LINE:~0,2!"=="- " (
      set /a PROFILE_COUNT+=1
      set "PROFILE_!PROFILE_COUNT!=!LINE:~2!"
    )
  )
  del "!LIST_FILE!" >nul 2>&1
)
exit /b 0

:choose_profile
call :read_config
call :load_profiles
set "SELECTED_PROFILE="
if !PROFILE_COUNT! LEQ 0 (
  echo [ERROR] No profiles found.
  pause
  exit /b 1
)

cls
echo ============================================================
echo   Select WireSock Profile
echo ============================================================
echo.
for /l %%I in (1,1,!PROFILE_COUNT!) do (
  if /i "!PROFILE_%%I!"=="!ACTIVE_PROFILE!" (
    echo [%%I] !PROFILE_%%I! [ACTIVE]
  ) else (
    echo [%%I] !PROFILE_%%I!
  )
)
echo [0] Cancel
echo.
set "PROFILE_SEL="
set /p "PROFILE_SEL=Select profile: "
if "!PROFILE_SEL!"=="0" exit /b 1
echo(!PROFILE_SEL!| findstr /r "^[0-9][0-9]*$" >nul || exit /b 1
if !PROFILE_SEL! LSS 1 exit /b 1
if !PROFILE_SEL! GTR !PROFILE_COUNT! exit /b 1
for %%N in (!PROFILE_SEL!) do set "SELECTED_PROFILE=!PROFILE_%%N!"
if not defined SELECTED_PROFILE exit /b 1
exit /b 0

:profile_exists
set "LOOKUP_PROFILE=%~1"
call :load_profiles
for /l %%I in (1,1,!PROFILE_COUNT!) do (
  if /i "!PROFILE_%%I!"=="!LOOKUP_PROFILE!" exit /b 0
)
exit /b 1

:prompt_new_profile_name
set "NEW_PROFILE_NAME="
cls
echo ============================================================
echo   WireSock Profile Manager
echo ============================================================
echo.
echo %~1
echo Use a Windows-safe file/profile name. Empty input cancels.
echo.
set /p "NEW_PROFILE_NAME=Name: "
if not defined NEW_PROFILE_NAME exit /b 1
set "WS_NEW_PROFILE_NAME=!NEW_PROFILE_NAME!"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$n=$env:WS_NEW_PROFILE_NAME; if([string]::IsNullOrWhiteSpace($n)){exit 1}; if($n.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0){exit 2}; if($n.EndsWith('.') -or $n.EndsWith(' ')){exit 3}" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Invalid profile name.
  pause
  exit /b 1
)
exit /b 0

:copy_profile_as
set "COPY_SOURCE=%~1"
set "COPY_TARGET=%~2"
set "OP_DIR=%TEMP%\wiresock-profile-op-%RANDOM%-%RANDOM%"
mkdir "!OP_DIR!" >nul 2>&1
if errorlevel 1 exit /b 1
set "OP_FILE=!OP_DIR!\!COPY_TARGET!.conf"

"!CLI!" export "!COPY_SOURCE!" "!OP_FILE!" >nul 2>&1
if errorlevel 1 (
  rd /s /q "!OP_DIR!" >nul 2>&1
  exit /b 1
)

"!CLI!" import "!OP_FILE!" >nul 2>&1
set "COPY_RC=!errorlevel!"
rd /s /q "!OP_DIR!" >nul 2>&1
if not "!COPY_RC!"=="0" exit /b 1

call :profile_exists "!COPY_TARGET!"
if errorlevel 1 exit /b 1
exit /b 0

rem ============================================================
rem Find CLI without relying on current directory.
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
rem ============================================================
:read_config
set "ACTIVE_PROFILE="
set "SPLIT=Unknown"
set "KILLSWITCH=Unknown"
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
