@echo off
setlocal EnableExtensions EnableDelayedExpansion
title WireSock GUI Toggle

set "GUI_EXE="
set "GUI_IMAGE="
set "GUI_STATUS=UNKNOWN"
set "WS_TEMP="

rem ============================================================
rem Standalone GUI toggle must run elevated, just like the main
rem Control Center. Pass both the script path and working directory
rem directly through environment variables. Do NOT use Split-Path:
rem Windows PowerShell 5.1 can reject -LiteralPath + -Parent here.
rem ============================================================
net session >nul 2>&1
if errorlevel 1 (
  set "WS_SELF=%~f0"
  set "WS_DIR=%~dp0"
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

call :find_gui
if not defined GUI_EXE (
  cls
  echo ============================================================
  echo   WireSock GUI Toggle
  echo ============================================================
  echo.
  echo [ERROR] WireSock Secure Connect GUI executable was not found.
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
echo GUI process    : !GUI_IMAGE!
echo GUI status     : !GUI_STATUS!
echo.

if /i "!GUI_STATUS!"=="ON" goto gui_off

echo Opening WireSock GUI...
explorer.exe "!GUI_EXE!" >nul 2>&1
call :wait_gui_on 8
if not errorlevel 1 (
  echo WireSock GUI: ON
  timeout /t 2 /nobreak >nul
  goto exit_ok
)

echo [ERROR] WireSock GUI did not start within 8 seconds.
echo.
echo Executable: !GUI_EXE!
echo Process   : !GUI_IMAGE!
pause
goto exit_error

:gui_off
echo Closing WireSock GUI only...
if not defined GUI_IMAGE call :derive_gui_image
if not defined GUI_IMAGE (
  echo [ERROR] Cannot determine WireSock GUI process name.
  pause
  goto exit_error
)

rem ============================================================
rem Method 1: same idea as the main Control Center.
rem Stop only processes whose full executable path matches GUI_EXE.
rem This script is elevated, so Process.Path should now be readable.
rem ============================================================
set "WS_GUI_EXE=!GUI_EXE!"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$target=$env:WS_GUI_EXE; foreach($p in @(Get-Process -ErrorAction SilentlyContinue)){ try { if($p.Path -and ([IO.Path]::GetFullPath($p.Path) -ieq [IO.Path]::GetFullPath($target))){ Stop-Process -Id $p.Id -Force -ErrorAction Stop } } catch {} }" >nul 2>&1
call :wait_gui_off 3
if not errorlevel 1 goto gui_off_ok

rem ============================================================
rem Method 2: elevated taskkill by exact image name + process tree.
rem ============================================================
taskkill /f /t /im "!GUI_IMAGE!" >nul 2>&1
call :wait_gui_off 3
if not errorlevel 1 goto gui_off_ok

rem ============================================================
rem Method 3: WMI/CIM termination. This avoids Get-Process.Path and
rem is useful if taskkill behaves strangely on a particular system.
rem ============================================================
set "WS_GUI_IMAGE=!GUI_IMAGE!"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$name=$env:WS_GUI_IMAGE; Get-CimInstance Win32_Process -Filter ('Name='''+$name+'''') -ErrorAction SilentlyContinue | ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName Terminate -ErrorAction SilentlyContinue | Out-Null }" >nul 2>&1
call :wait_gui_off 3
if not errorlevel 1 goto gui_off_ok

rem ============================================================
rem Still alive: show useful diagnostics instead of hiding errors.
rem ============================================================
echo [ERROR] WireSock GUI is still running after 3 close methods.
echo.
echo Executable: !GUI_EXE!
echo Process   : !GUI_IMAGE!
echo.
echo Matching processes:
tasklist /fi "IMAGENAME eq !GUI_IMAGE!"
echo.
echo If the PID changes immediately after each kill, another WireSock
echo component is relaunching the GUI automatically.
echo.
pause
goto exit_error

:gui_off_ok
echo WireSock GUI: OFF
timeout /t 2 /nobreak >nul
goto exit_ok

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
set "GUI_IMAGE="
set "GUI_FILE=!WS_TEMP!\wiresock-gui-!RANDOM!-!RANDOM!.txt"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $target=$null; $roots=@([IO.Path]::Combine($env:ProgramData,'Microsoft\Windows\Start Menu\Programs'),[IO.Path]::Combine($env:APPDATA,'Microsoft\Windows\Start Menu\Programs')); $shell=New-Object -ComObject WScript.Shell; foreach($r in $roots){ if($r -and (Test-Path -LiteralPath $r)){ foreach($lnk in @(Get-ChildItem -LiteralPath $r -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue)){ if($lnk.BaseName -match 'WireSock.*Secure.*Connect'){ $t=$shell.CreateShortcut($lnk.FullName).TargetPath; if($t -and (Test-Path -LiteralPath $t)){ $target=$t; break } } }; if($target){break} } }; if(-not $target){ foreach($d in @('C:\Program Files\Wiresock Secure Connect','C:\Program Files\WireSock Secure Connect')){ if(Test-Path -LiteralPath $d){ foreach($c in @(Get-ChildItem -LiteralPath $d -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue)){ if($c.FullName -match '\\command-line\\'){continue}; if($c.Name -match 'wiresock-connect-cli|wiresock-client|unins|uninstall|updater|update'){continue}; if($c.VersionInfo.ProductName -match 'WireSock.*Secure.*Connect' -or $c.VersionInfo.FileDescription -match 'WireSock.*Secure.*Connect'){ $target=$c.FullName; break } }; if($target){break} } } }; if($target){$target}" >"!GUI_FILE!" 2>nul

if exist "!GUI_FILE!" set /p "GUI_EXE="<"!GUI_FILE!"
del /q "!GUI_FILE!" >nul 2>&1
if defined GUI_EXE if not exist "!GUI_EXE!" set "GUI_EXE="
if defined GUI_EXE call :derive_gui_image
exit /b 0

:derive_gui_image
set "GUI_IMAGE="
if not defined GUI_EXE exit /b 1
for %%F in ("!GUI_EXE!") do set "GUI_IMAGE=%%~nxF"
if not defined GUI_IMAGE exit /b 1
exit /b 0

:get_gui_status
set "GUI_STATUS=NOT FOUND"
if not defined GUI_EXE call :find_gui
if not defined GUI_EXE exit /b 0
if not defined GUI_IMAGE call :derive_gui_image
if not defined GUI_IMAGE exit /b 0

set "GUI_STATUS=OFF"
set "TASK_FILE=!WS_TEMP!\wiresock-tasklist-!RANDOM!-!RANDOM!.txt"
tasklist /fi "IMAGENAME eq !GUI_IMAGE!" /fo csv /nh >"!TASK_FILE!" 2>nul
if exist "!TASK_FILE!" (
  findstr /i /c:"!GUI_IMAGE!" "!TASK_FILE!" >nul 2>&1
  if not errorlevel 1 set "GUI_STATUS=ON"
  del /q "!TASK_FILE!" >nul 2>&1
)
exit /b 0

:wait_gui_on
set "GUI_WAIT=%~1"
for /l %%I in (1,1,!GUI_WAIT!) do (
  call :get_gui_status
  if /i "!GUI_STATUS!"=="ON" exit /b 0
  timeout /t 1 /nobreak >nul
)
exit /b 1

:wait_gui_off
set "GUI_WAIT=%~1"
for /l %%I in (1,1,!GUI_WAIT!) do (
  call :get_gui_status
  if /i "!GUI_STATUS!"=="OFF" exit /b 0
  timeout /t 1 /nobreak >nul
)
exit /b 1

:exit_ok
popd >nul 2>&1
exit /b 0

:exit_error
popd >nul 2>&1
exit /b 1
