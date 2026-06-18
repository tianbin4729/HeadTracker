@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM  HeadTracker 固件编译脚本 (Docker + Zephyr RTOS)
REM  需要在电脑上安装 Docker Desktop 并运行
REM ============================================================

set "DRIVE=%~d0"
set "PROJECT_ROOT=%DRIVE%\HeadTracker"
set "DOCKER_IMAGE=headtracker-build"

REM 默认构建所有板子，也可指定单个板子
REM 用法: build_firmware.bat [board_name]
REM 例如: build_firmware.bat dtqsys_ht

echo.
echo   ============================================
echo   Building HeadTracker Firmware
echo   ============================================
echo.

REM 检查 Docker 是否可用
where docker >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo   [ERROR] Docker not found! Please install Docker Desktop.
    echo   Download: https://www.docker.com/products/docker-desktop/
    goto :error
)

REM 检查 Docker 是否在运行
docker info >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo   [ERROR] Docker is not running. Please start Docker Desktop first.
    goto :error
)

echo   [OK] Docker is running.
echo.

REM 检查 Docker 镜像是否存在
docker image inspect %DOCKER_IMAGE% >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo   [INFO] Docker image '%DOCKER_IMAGE%' not found. Building...
    echo   [INFO] This will take a long time (downloads Zephyr SDK + toolchains).
    echo.
    cd /d "%PROJECT_ROOT%"
    docker build -t %DOCKER_IMAGE% .
    if %ERRORLEVEL% NEQ 0 (
        echo   [ERROR] Docker image build failed!
        goto :error
    )
    echo   [OK] Docker image built successfully.
    echo.
)

REM 确定要构建的板子
if not "%~1"=="" (
    set "BOARDS=%~1"
) else (
    echo   Building ALL supported boards...
    echo.
    set "BOARDS=arduino_nano_33_ble xiao_ble/nrf52840/sense xiao_ble/nrf52840 dtqsys_ht licardo_ht esp32c3_devkitm m5stickc_plus/esp32/procpu rpi_pico/rp2040/w"
)

REM 创建输出目录
if not exist "%PROJECT_ROOT%\firmware\build_bins" (
    mkdir "%PROJECT_ROOT%\firmware\build_bins"
)

REM 构建每个板子
set "BUILD_COUNT=0"
set "FAIL_COUNT=0"

for %%b in (!BOARDS!) do (
    set /a BUILD_COUNT+=1
    echo   ----------------------------------------
    echo   [!BUILD_COUNT!] Building for: %%b
    echo   ----------------------------------------

    REM 清理之前构建
    if exist "%PROJECT_ROOT%\firmware\src\build" (
        rmdir /s /q "%PROJECT_ROOT%\firmware\src\build"
    )

    REM 在 Docker 容器中构建
    REM arduino_nano_33_ble Rev2 需要额外 cmake 参数
    set "EXTRA_CMAKE="
    if /i "%%b"=="arduino_nano_33_ble" set "EXTRA_CMAKE=-- -DBOARD_REV2=1"

    docker run --rm ^
        -v "%PROJECT_ROOT%:/workspace" ^
        %DOCKER_IMAGE% ^
        bash -c "source /root/zephyr_py_env/.venv/bin/activate && source /root/zephyr/zephyr/zephyr-env.sh && cd /workspace/firmware/src && west build -p -b %%b !EXTRA_CMAKE!"

    if %ERRORLEVEL% NEQ 0 (
        echo   [FAILED] %%b build failed!
        set /a FAIL_COUNT+=1
    ) else (
        echo   [OK] %%b built successfully.
        REM 复制产物
        if exist "%PROJECT_ROOT%\firmware\src\build\zephyr\*.bin" (
            copy /y "%PROJECT_ROOT%\firmware\src\build\zephyr\*.bin" "%PROJECT_ROOT%\firmware\build_bins\" >nul 2>&1
            echo         .bin copied to firmware\build_bins\
        )
        if exist "%PROJECT_ROOT%\firmware\src\build\zephyr\*.uf2" (
            copy /y "%PROJECT_ROOT%\firmware\src\build\zephyr\*.uf2" "%PROJECT_ROOT%\firmware\build_bins\" >nul 2>&1
            echo         .uf2 copied to firmware\build_bins\
        )
        if exist "%PROJECT_ROOT%\firmware\src\build\zephyr\*.hex" (
            copy /y "%PROJECT_ROOT%\firmware\src\build\zephyr\*.hex" "%PROJECT_ROOT%\firmware\build_bins\" >nul 2>&1
            echo         .hex copied to firmware\build_bins\
        )
    )
    echo.
)

echo   ============================================
echo   Firmware Build Summary:
echo     Total:  !BUILD_COUNT!
echo     Passed: !BUILD_COUNT! - !FAIL_COUNT!
echo     Failed: !FAIL_COUNT!
echo   ============================================

if !FAIL_COUNT! GTR 0 (
    echo   Output: %PROJECT_ROOT%\firmware\build_bins\
    endlocal
    exit /b 1
) else (
    echo   All boards built successfully!
    echo   Output: %PROJECT_ROOT%\firmware\build_bins\
    endlocal
    exit /b 0
)

:error
echo.
echo   ============================================
echo   Build FAILED!
echo   ============================================
endlocal
exit /b 1
