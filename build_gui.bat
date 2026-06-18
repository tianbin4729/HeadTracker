@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM  HeadTracker GUI 编译脚本 (Qt 6.4.1 + MinGW)
REM ============================================================

REM 获取脚本所在盘符
set "DRIVE=%~d0"
set "PROJECT_ROOT=%DRIVE%\HeadTracker"

echo.
echo   ============================================
echo   Building HeadTracker GUI
echo   ============================================
echo.

REM 设置工具路径
set "QT_PATH=%PROJECT_ROOT%\tools\Qt\6.4.1\mingw_64"
set "MINGW_PATH=%PROJECT_ROOT%\tools\Qt\Tools\mingw1310_64"
set "PYTHON_PATH=%PROJECT_ROOT%\tools\python-embed"

REM 检查工具
if not exist "%QT_PATH%\bin\qmake.exe" (
    echo   [ERROR] Qt not found. Run setup first.
    goto :error
)
if not exist "%MINGW_PATH%\bin\gcc.exe" (
    echo   [ERROR] MinGW not found. Run setup first.
    goto :error
)
if not exist "%PYTHON_PATH%\python.exe" (
    echo   [ERROR] Python not found. Run setup first.
    goto :error
)

REM 设置 PATH
set "PATH=%MINGW_PATH%\bin;%QT_PATH%\bin;%PYTHON_PATH%;%PYTHON_PATH%\Scripts;%PATH%"

REM 处理外接硬盘 git ownership 问题 (每个电脑的 SID 不同)
git config --global --add safe.directory "%PROJECT_ROOT%" >nul 2>&1
git config --global --add safe.directory '*' >nul 2>&1

echo   [1/4] Generating settings headers...
cd /d "%PROJECT_ROOT%\settings"
set "PYTHONPATH=%PROJECT_ROOT%\settings"
"%PYTHON_PATH%\python.exe" buildsettings.py 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo   [WARN] Settings generation had issues, continuing...
)

echo.
echo   [2/4] Running qmake...
cd /d "%PROJECT_ROOT%\gui\src"
qmake HeadTracker.pro 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo   [ERROR] qmake failed!
    goto :error
)
echo   [OK] qmake completed.

echo.
echo   [3/4] Compiling...
REM 使用完整路径确保便携性 (覆盖 Makefile 中的 CC/CXX)
mingw32-make -j%NUMBER_OF_PROCESSORS% CC="%MINGW_PATH%\bin\gcc.exe" CXX="%MINGW_PATH%\bin\g++.exe" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo   [ERROR] Compilation failed!
    goto :error
)
echo   [OK] Compilation completed.

echo.
echo   [4/4] Build finished!
echo.
echo   Output files:
dir /b "%PROJECT_ROOT%\gui\src\release\HeadTracker.exe" 2>nul && echo     release\HeadTracker.exe  [OK]
echo.

echo   ============================================
echo   Build Successful!
echo   ============================================
goto :end

:error
echo.
echo   ============================================
echo   Build FAILED!
echo   ============================================
endlocal
exit /b 1

:end
endlocal
exit /b 0
