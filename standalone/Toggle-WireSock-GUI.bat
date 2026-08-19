@echo off
setlocal EnableExtensions EnableDelayedExpansion
title WireSock GUI Toggle

set "GUI_EXE="
set "GUI_STATUS=UNKNOWN"
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
  goto exit_error
)

call :find_gui
if not defined GUI_EXE (
  cls
  echo ============================================================
  echo   WireSock GUI Toggle
  echo ============================================================
  echo.
  echo [ERROR] WireSock Secure Connect GUI executable was not found.
  echo.
  echo Detection checks Start Menu shortcuts and common install paths.
  echo VPN/tunnel state was not changed.
  echo.
  pause
  goto exit_error
)

call :get_gui_status
cls
echo ============================================================
echo   WireSock GUI Toggle
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
  goto exit_ok
)

echo [ERROR] WireSock GUI did not start.
pause
goto exit_error

:gui_off
echo Closing WireSock GUI only...
set "WS_GUI_EXE=!GUI_EXE!"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$target=$env:WS_GUI_EXE; foreach($p in @(Get-Process -ErrorAction SilentlyContinue)){ try { if($p.Path -and ([IO.Path]::GetFullPath($p.Path) -ieq [IO.Path]::GetFullPath($target))){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } } catch {} }" >nul 2>&1
timeout /t 1 /nobreak >nul
call :get_gui_status
if /i "!GUI_STATUS!"=="OFF" (
  echo WireSock GUI: OFF
  timeout /t 2 /nobreak >nul
  goto exit_ok
)

echo [ERROR] WireSock GUI is still running.
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

:find_gui
set "GUI_EXE="
set "GUI_FILE=!WS_TEMP!\wiresock-gui-!RANDOM!-!RANDOM!.txt"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $target=$null; $roots=@([IO.Path]::Combine($env:ProgramData,'Microsoft\Windows\Start Menu\Programs'),[IO.Path]::Combine($env:APPDATA,'Microsoft\Windows\Start Menu\Programs')); $shell=New-Object -ComObject WScript.Shell; foreach($r in $roots){ if($r -and (Test-Path -LiteralPath $r)){ foreach($lnk in @(Get-ChildItem -LiteralPath $r -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue)){ if($lnk.BaseName -match 'WireSock.*Secure.*Connect'){ $t=$shell.CreateShortcut($lnk.FullName).TargetPath; if($t -and (Test-Path -LiteralPath $t)){ $target=$t; break } } }; if($target){break} } }; if(-not $target){ foreach($d in @('C:\Program Files\Wiresock Secure Connect','C:\Program Files\WireSock Secure Connect')){ if(Test-Path -LiteralPath $d){ foreach($c in @(Get-ChildItem -LiteralPath $d -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue)){ if($c.FullName -match '\\command-line\\'){continue}; if($c.Name -match 'wiresock-connect-cli|wiresock-client|unins|uninstall|updater|update'){continue}; if($c.VersionInfo.ProductName -match 'WireSock.*Secure.*Connect' -or $c.VersionInfo.FileDescription -match 'WireSock.*Secure.*Connect'){ $target=$c.FullName; break } }; if($target){break} } } }; if($target){$target}" >"!GUI_FILE!" 2>nul
if exist "!GUI_FILE!" set /p "GUI_EXE="<"!GUI_FILE!"
del /q "!GUI_FILE!" >nul 2>&1
if defined GUI_EXE if not exist "!GUI_EXE!" set "GUI_EXE="
exit /b 0

:get_gui_status
set "GUI_STATUS=NOT FOUND"
if not defined GUI_EXE call :find_gui
if not defined GUI_EXE exit /b 0
set "WS_GUI_EXE=!GUI_EXE!"
set "GUI_STATE_FILE=!WS_TEMP!\wiresock-gui-state-!RANDOM!-!RANDOM!.txt"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$target=$env:WS_GUI_EXE; $found=$false; foreach($p in @(Get-Process -ErrorAction SilentlyContinue)){ try { if($p.Path -and ([IO.Path]::GetFullPath($p.Path) -ieq [IO.Path]::GetFullPath($target))){$found=$true;break} } catch {} }; if($found){'ON'}else{'OFF'}" >"!GUI_STATE_FILE!" 2>nul
if exist "!GUI_STATE_FILE!" set /p "GUI_STATUS="<"!GUI_STATE_FILE!"
del /q "!GUI_STATE_FILE!" >nul 2>&1
exit /b 0

:exit_ok
popd >nul 2>&1
exit /b 0

:exit_error
popd >nul 2>&1
exit /b 1
