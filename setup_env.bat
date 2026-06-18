@echo off

REM ============================================================
REM  HeadTracker 编译环境设置脚本
REM  自动检测盘符，设置 PATH，支持便携使用
REM  在命令行中运行: setup_env.bat
REM  然后就可以直接使用 gcc, qmake, python 等命令
REM ============================================================

REM 获取脚本所在盘符和目录
set "DRIVE=%~d0"
set "PROJECT_ROOT=%DRIVE%\HeadTracker"

echo.
echo   HeadTracker Build Environment Setup
echo   ===================================
echo   Project Root: %PROJECT_ROOT%
echo   Drive: %DRIVE%
echo.

REM 设置工具路径
set "QT_PATH=%PROJECT_ROOT%\tools\Qt\6.4.1\mingw_64"
set "MINGW_PATH=%PROJECT_ROOT%\tools\Qt\Tools\mingw1310_64"
set "PYTHON_PATH=%PROJECT_ROOT%\tools\python-embed"

REM 检查工具是否存在
if not exist "%QT_PATH%\bin\qmake.exe" (
    echo   [ERROR] Qt 6.4.1 not found: %QT_PATH%
    echo   Please run tools\python-embed\python.exe -m aqt install-qt ...
    goto :end
)

if not exist "%MINGW_PATH%\bin\gcc.exe" (
    echo   [ERROR] MinGW toolchain not found: %MINGW_PATH%
    echo   Please run tools\python-embed\python.exe -m aqt install-tool ...
    goto :end
)

if not exist "%PYTHON_PATH%\python.exe" (
    echo   [ERROR] Python not found: %PYTHON_PATH%
    goto :end
)

REM 设置 PATH（放在最前面，优先使用便携工具链）
set "PATH=%MINGW_PATH%\bin;%QT_PATH%\bin;%PYTHON_PATH%;%PYTHON_PATH%\Scripts;%PATH%"

REM 设置 Qt 相关环境变量
set "QTDIR=%QT_PATH%"
set "QMAKESPEC=win32-g++"

echo   [OK] Qt 6.4.1:      %QT_PATH%
echo   [OK] MinGW GCC:     %MINGW_PATH%
echo   [OK] Python:        %PYTHON_PATH%
echo.

REM 显示版本信息
echo   Tool Versions:
echo   --------------
gcc --version 2>nul | findstr /C:"gcc" 2>nul || echo   [WARN] gcc not found in PATH
g++ --version 2>nul | findstr /C:"g++" 2>nul || echo   [WARN] g++ not found in PATH
mingw32-make --version 2>nul | findstr /C:"GNU Make" 2>nul || echo   [WARN] mingw32-make not found
qmake --version 2>nul | findstr /C:"Qt" 2>nul || echo   [WARN] qmake not found
python --version 2>nul || echo   [WARN] python not found
echo.

echo   Environment is ready!
echo   Run build_gui.bat to compile the GUI.
echo   Run build_firmware.bat to compile the firmware.

:end
