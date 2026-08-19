@echo off
setlocal EnableExtensions EnableDelayedExpansion
title WireSock Profile Manager

set "CONFIG=C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config"
set "PROFILES_DIR=C:\ProgramData\WireSock Foundation\WireSock Secure Connect\Profiles"
set "CLI="
set "ACTIVE_PROFILE="
set "PROFILE_COUNT=0"

net session >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -WorkingDirectory '%~dp0' -Verb RunAs"
  exit /b
)

pushd "%~dp0" >nul 2>&1
call :find_cli
if not defined CLI (
  echo [ERROR] WireSock CLI not found.
  pause
  goto exit_script
)

goto menu

:menu
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
echo [0] Exit
echo.
set "CHOICE="
set /p "CHOICE=Select: "
if "!CHOICE!"=="1" goto list_profiles
if "!CHOICE!"=="2" goto import_profile
if "!CHOICE!"=="3" goto export_profile
if "!CHOICE!"=="4" goto view_profile
if "!CHOICE!"=="5" goto duplicate_profile
if "!CHOICE!"=="6" goto rename_profile
if "!CHOICE!"=="7" goto delete_profile
if "!CHOICE!"=="8" goto open_folder
if "!CHOICE!"=="0" goto exit_script
goto menu

:list_profiles
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
    if /i "!PROFILE_%%I!"=="!ACTIVE_PROFILE!" (echo [%%I] !PROFILE_%%I! [ACTIVE]) else (echo [%%I] !PROFILE_%%I!)
  )
)
echo.
pause
goto menu

:import_profile
set "PICK=%TEMP%\wiresock-import-%RANDOM%-%RANDOM%.txt"
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.OpenFileDialog; $d.Title='Import WireSock profile'; $d.Filter='WireGuard configuration (*.conf)|*.conf|All files (*.*)|*.*'; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){$d.FileName}" >"!PICK!" 2>nul
set "IMPORT_PATH="
if exist "!PICK!" set /p "IMPORT_PATH="<"!PICK!"
del "!PICK!" >nul 2>&1
if not defined IMPORT_PATH goto menu
"!CLI!" import "!IMPORT_PATH!"
echo.
if errorlevel 1 (echo [ERROR] Import failed.) else (echo [OK] Profile imported.)
pause
goto menu

:export_profile
call :choose_profile
if errorlevel 1 goto menu
set "EXPORT_PROFILE=!SELECTED_PROFILE!"
set "PICK=%TEMP%\wiresock-export-%RANDOM%-%RANDOM%.txt"
set "WS_EXPORT_NAME=!EXPORT_PROFILE!"
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.SaveFileDialog; $d.Title='Export WireSock profile'; $d.Filter='WireGuard configuration (*.conf)|*.conf|All files (*.*)|*.*'; $d.FileName=$env:WS_EXPORT_NAME+'.conf'; $d.OverwritePrompt=$true; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){$d.FileName}" >"!PICK!" 2>nul
set "EXPORT_PATH="
if exist "!PICK!" set /p "EXPORT_PATH="<"!PICK!"
del "!PICK!" >nul 2>&1
if not defined EXPORT_PATH goto menu
if exist "!EXPORT_PATH!" del /q "!EXPORT_PATH!" >nul 2>&1
"!CLI!" export "!EXPORT_PROFILE!" "!EXPORT_PATH!"
echo.
if errorlevel 1 (echo [ERROR] Export failed.) else (echo [OK] Exported to: !EXPORT_PATH!)
pause
goto menu

:view_profile
call :choose_profile
if errorlevel 1 goto menu
set "VIEW_PROFILE=!SELECTED_PROFILE!"
set "VIEW_DIR=%TEMP%\wiresock-view-%RANDOM%-%RANDOM%"
mkdir "!VIEW_DIR!" >nul 2>&1
set "VIEW_FILE=!VIEW_DIR!\!VIEW_PROFILE!.conf"
"!CLI!" export "!VIEW_PROFILE!" "!VIEW_FILE!" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Could not export profile for viewing.
  rd /s /q "!VIEW_DIR!" >nul 2>&1
  pause
  goto menu
)
notepad.exe "!VIEW_FILE!"
rd /s /q "!VIEW_DIR!" >nul 2>&1
goto menu

:duplicate_profile
call :choose_profile
if errorlevel 1 goto menu
set "SOURCE_PROFILE=!SELECTED_PROFILE!"
call :prompt_new_name "Duplicate profile as"
if errorlevel 1 goto menu
set "NEW_PROFILE=!NEW_PROFILE_NAME!"
call :profile_exists "!NEW_PROFILE!"
if not errorlevel 1 (
  echo [ERROR] Profile already exists: !NEW_PROFILE!
  pause
  goto menu
)
call :copy_profile_as "!SOURCE_PROFILE!" "!NEW_PROFILE!"
if errorlevel 1 (echo [ERROR] Duplicate failed.) else (echo [OK] Created: !NEW_PROFILE!)
pause
goto menu

:rename_profile
call :read_config
call :choose_profile
if errorlevel 1 goto menu
set "SOURCE_PROFILE=!SELECTED_PROFILE!"
if /i "!SOURCE_PROFILE!"=="!ACTIVE_PROFILE!" (
  echo [BLOCKED] Switch away from the active profile before renaming it.
  pause
  goto menu
)
call :prompt_new_name "Rename profile to"
if errorlevel 1 goto menu
set "NEW_PROFILE=!NEW_PROFILE_NAME!"
call :profile_exists "!NEW_PROFILE!"
if not errorlevel 1 (
  echo [ERROR] Profile already exists: !NEW_PROFILE!
  pause
  goto menu
)
call :copy_profile_as "!SOURCE_PROFILE!" "!NEW_PROFILE!"
if errorlevel 1 (
  echo [ERROR] Could not create the renamed copy. Original is unchanged.
  pause
  goto menu
)
"!CLI!" delete "!SOURCE_PROFILE!" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Old profile could not be deleted. Rolling back new profile...
  "!CLI!" delete "!NEW_PROFILE!" >nul 2>&1
  pause
  goto menu
)
echo [OK] Renamed !SOURCE_PROFILE! to !NEW_PROFILE!.
pause
goto menu

:delete_profile
call :read_config
call :choose_profile
if errorlevel 1 goto menu
set "DELETE_PROFILE=!SELECTED_PROFILE!"
if /i "!DELETE_PROFILE!"=="!ACTIVE_PROFILE!" (
  echo [BLOCKED] Cannot delete the active profile. Switch away first.
  pause
  goto menu
)
set "CONFIRM="
set /p "CONFIRM=Type DELETE to remove !DELETE_PROFILE!: "
if /i not "!CONFIRM!"=="DELETE" goto menu
"!CLI!" delete "!DELETE_PROFILE!"
echo.
if errorlevel 1 (echo [ERROR] Delete failed.) else (echo [OK] Profile deleted.)
pause
goto menu

:open_folder
if exist "%PROFILES_DIR%" (explorer.exe "%PROFILES_DIR%") else (echo [ERROR] Profiles folder not found.&pause)
goto menu

:load_profiles
for /l %%I in (1,1,200) do set "PROFILE_%%I="
set "PROFILE_COUNT=0"
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
if !PROFILE_COUNT! LEQ 0 exit /b 1
cls
for /l %%I in (1,1,!PROFILE_COUNT!) do (
  if /i "!PROFILE_%%I!"=="!ACTIVE_PROFILE!" (echo [%%I] !PROFILE_%%I! [ACTIVE]) else (echo [%%I] !PROFILE_%%I!)
)
echo [0] Cancel
echo.
set "SEL="
set /p "SEL=Select profile: "
if "!SEL!"=="0" exit /b 1
echo(!SEL!| findstr /r "^[0-9][0-9]*$" >nul || exit /b 1
if !SEL! LSS 1 exit /b 1
if !SEL! GTR !PROFILE_COUNT! exit /b 1
for %%N in (!SEL!) do set "SELECTED_PROFILE=!PROFILE_%%N!"
if not defined SELECTED_PROFILE exit /b 1
exit /b 0

:profile_exists
set "LOOKUP=%~1"
call :load_profiles
for /l %%I in (1,1,!PROFILE_COUNT!) do if /i "!PROFILE_%%I!"=="!LOOKUP!" exit /b 0
exit /b 1

:prompt_new_name
set "NEW_PROFILE_NAME="
cls
echo %~1
set /p "NEW_PROFILE_NAME=Name: "
if not defined NEW_PROFILE_NAME exit /b 1
set "WS_NEW_PROFILE_NAME=!NEW_PROFILE_NAME!"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$n=$env:WS_NEW_PROFILE_NAME; if([string]::IsNullOrWhiteSpace($n)){exit 1}; if($n.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0){exit 2}; if($n.EndsWith('.') -or $n.EndsWith(' ')){exit 3}" >nul 2>&1
if errorlevel 1 (echo [ERROR] Invalid profile name.&pause&exit /b 1)
exit /b 0

:copy_profile_as
set "SRC=%~1"
set "DST=%~2"
set "OP_DIR=%TEMP%\wiresock-profile-op-%RANDOM%-%RANDOM%"
mkdir "!OP_DIR!" >nul 2>&1
if errorlevel 1 exit /b 1
set "OP_FILE=!OP_DIR!\!DST!.conf"
"!CLI!" export "!SRC!" "!OP_FILE!" >nul 2>&1
if errorlevel 1 (rd /s /q "!OP_DIR!" >nul 2>&1&exit /b 1)
"!CLI!" import "!OP_FILE!" >nul 2>&1
set "RC=!errorlevel!"
rd /s /q "!OP_DIR!" >nul 2>&1
if not "!RC!"=="0" exit /b 1
call :profile_exists "!DST!"
exit /b !errorlevel!

:read_config
set "ACTIVE_PROFILE="
if not exist "%CONFIG%" exit /b 0
set "OUT=%TEMP%\wiresock-active-%RANDOM%-%RANDOM%.txt"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[xml]$x=Get-Content -LiteralPath '%CONFIG%' -Raw; $n=$x.SelectSingleNode('//ActiveConfig'); if($n){$n.InnerText}" >"!OUT!" 2>nul
if exist "!OUT!" set /p "ACTIVE_PROFILE="<"!OUT!"
del "!OUT!" >nul 2>&1
exit /b 0

:find_cli
set "CLI="
set "OUT=%TEMP%\wiresock-where-%RANDOM%-%RANDOM%.txt"
where wiresock-connect-cli.exe >"!OUT!" 2>nul
if exist "!OUT!" set /p "CLI="<"!OUT!"
del "!OUT!" >nul 2>&1
if defined CLI exit /b 0
if exist "C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe" set "CLI=C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe"
if not defined CLI if exist "C:\Program Files\WireSock Secure Connect\command-line\wiresock-connect-cli.exe" set "CLI=C:\Program Files\WireSock Secure Connect\command-line\wiresock-connect-cli.exe"
exit /b 0

:exit_script
popd >nul 2>&1
exit /b 0
