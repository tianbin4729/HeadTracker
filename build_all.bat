@echo off

REM ============================================================
REM  HeadTracker 全量编译脚本
REM  按顺序编译: 设置文件 -> GUI -> 固件
REM  build_all.bat [board]   (可选: 指定固件板子)
REM ============================================================

set "DRIVE=%~d0"
set "PROJECT_ROOT=%DRIVE%\HeadTracker"

echo.
echo   ============================================
echo   HeadTracker - Full Build
echo   ============================================
echo.

echo   [1/3] Generating settings from CSV...
echo   --------------------------------------
cd /d "%PROJECT_ROOT%\settings"
set "PYTHONPATH=%PROJECT_ROOT%\settings"
"%PROJECT_ROOT%\tools\python-embed\python.exe" buildsettings.py
if %ERRORLEVEL% NEQ 0 (
    echo   [ERROR] Settings generation failed!
    pause
    exit /b 1
)
echo   [OK] Settings generated.
echo.

echo   [2/3] Building GUI...
echo   ---------------------
call "%PROJECT_ROOT%\build_gui.bat"
if %ERRORLEVEL% NEQ 0 (
    echo   [ERROR] GUI build failed!
    pause
    exit /b 1
)

echo.
echo   [3/3] Building Firmware (Docker)...
echo   ------------------------------------
call "%PROJECT_ROOT%\build_firmware.bat" %1
REM 固件编译可能有部分板子失败，不一定是致命错误

echo.
echo   ============================================
echo   Build Complete!
echo   ============================================
echo.
echo   GUI:      gui\src\release\HeadTracker.exe
echo   Firmware: firmware\build_bins\
echo.
pause
