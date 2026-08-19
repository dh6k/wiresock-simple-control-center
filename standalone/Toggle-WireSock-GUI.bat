@echo off
setlocal EnableExtensions EnableDelayedExpansion
title WireSock GUI Toggle

set "GUI_EXE="
set "GUI_STATUS=UNKNOWN"

call :find_gui
if not defined GUI_EXE (
  cls
  echo ============================================================
  echo   WireSock GUI Toggle
  echo ============================================================
  echo.
  echo [ERROR] WireSock Secure Connect GUI executable was not found.
  echo.
  echo The script checks the Start Menu shortcut first, then common
  echo WireSock installation directories.
  echo.
  pause
  exit /b 1
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
rem Use Explorer so the GUI starts with the normal desktop user token
rem even when this script is launched from an elevated parent window.
explorer.exe "!GUI_EXE!" >nul 2>&1
timeout /t 2 /nobreak >nul
call :get_gui_status
if /i "!GUI_STATUS!"=="ON" (
  echo WireSock GUI: ON
  timeout /t 2 /nobreak >nul
  exit /b 0
)

echo [ERROR] WireSock GUI did not start.
pause
exit /b 2

:gui_off
echo Closing WireSock GUI...
set "WS_GUI_EXE=!GUI_EXE!"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$target=$env:WS_GUI_EXE; Get-Process -ErrorAction SilentlyContinue | Where-Object { try { $_.Path -and ([IO.Path]::GetFullPath($_.Path) -ieq [IO.Path]::GetFullPath($target)) } catch { $false } } | Stop-Process -Force -ErrorAction SilentlyContinue"
timeout /t 1 /nobreak >nul
call :get_gui_status
if /i "!GUI_STATUS!"=="OFF" (
  echo WireSock GUI: OFF
  timeout /t 2 /nobreak >nul
  exit /b 0
)

echo [ERROR] WireSock GUI is still running.
pause
exit /b 3

:find_gui
set "GUI_EXE="
for /f "usebackq delims=" %%G in (`powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='SilentlyContinue';" ^
  "$roots=@($env:ProgramData+'\Microsoft\Windows\Start Menu\Programs',$env:APPDATA+'\Microsoft\Windows\Start Menu\Programs');" ^
  "$shell=New-Object -ComObject WScript.Shell; $target=$null;" ^
  "foreach($r in $roots){if(Test-Path -LiteralPath $r){foreach($lnk in Get-ChildItem -LiteralPath $r -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue){if($lnk.BaseName -match 'WireSock.*Secure.*Connect'){ $t=$shell.CreateShortcut($lnk.FullName).TargetPath; if($t -and (Test-Path -LiteralPath $t)){ $target=$t; break }}}}; if($target){break}};" ^
  "if(-not $target){$dirs=@('C:\Program Files\Wiresock Secure Connect','C:\Program Files\WireSock Secure Connect'); foreach($d in $dirs){if(Test-Path -LiteralPath $d){$c=Get-ChildItem -LiteralPath $d -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue ^| Where-Object { $_.FullName -notmatch '\\command-line\\' -and $_.Name -notmatch 'wiresock-connect-cli|wiresock-client|unins|uninstall|updater|update' } ^| Where-Object { $_.VersionInfo.ProductName -match 'WireSock.*Secure.*Connect' -or $_.VersionInfo.FileDescription -match 'WireSock.*Secure.*Connect' } ^| Select-Object -First 1; if($c){$target=$c.FullName;break}}}};" ^
  "if($target){$target}"`) do set "GUI_EXE=%%G"
exit /b 0

:get_gui_status
set "GUI_STATUS=NOT FOUND"
if not defined GUI_EXE exit /b 0
set "WS_GUI_EXE=!GUI_EXE!"
for /f "usebackq delims=" %%S in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$target=$env:WS_GUI_EXE; $p=Get-Process -ErrorAction SilentlyContinue ^| Where-Object { try { $_.Path -and ([IO.Path]::GetFullPath($_.Path) -ieq [IO.Path]::GetFullPath($target)) } catch { $false } } ^| Select-Object -First 1; if($p){'ON'}else{'OFF'}"`) do set "GUI_STATUS=%%S"
exit /b 0
