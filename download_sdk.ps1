# HeadTracker - Zephyr SDK & Source Download Script
# 在 Windows 上下载所需文件（可以用 VPN/下载工具加速）
# 用法: powershell -File download_sdk.ps1

$ErrorActionPreference = "Stop"
$SDK_VERSION = "0.17.0"
$ZEPHYR_VERSION = "3.7.1"
$DOWNLOADS = "$PSScriptRoot\downloads"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " HeadTracker SDK Downloader" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target: $DOWNLOADS"
Write-Host ""

# Choose download method
$USE_PROXY = $true
$PROXY_URL = "https://ghproxy.net/"

# You can set $USE_PROXY = $false if VPN is enabled
Write-Host "Proxy mode: $USE_PROXY" -ForegroundColor Yellow
Write-Host ""

$SDK_BASE = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${SDK_VERSION}"
$ZEPHYR_URL = "https://github.com/zephyrproject-rtos/zephyr/archive/refs/tags/v${ZEPHYR_VERSION}.tar.gz"

function Get-File {
    param($Url, $OutputPath)
    $displayUrl = if ($USE_PROXY) { "${PROXY_URL}${Url}" } else { $Url }
    Write-Host "Downloading: $displayUrl" -ForegroundColor Green
    Write-Host "  -> $OutputPath"

    try {
        if ($USE_PROXY) {
            Invoke-WebRequest -Uri "${PROXY_URL}${Url}" -OutFile $OutputPath -UseBasicParsing
        } else {
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        }
        $size = (Get-Item $OutputPath).Length
        Write-Host "  OK: $([math]::Round($size/1MB, 1)) MB" -ForegroundColor Green
    } catch {
        Write-Host "  FAILED: $_" -ForegroundColor Red
        # Retry once
        Write-Host "  Retrying..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        if ($USE_PROXY) {
            Invoke-WebRequest -Uri "${PROXY_URL}${Url}" -OutFile $OutputPath -UseBasicParsing
        } else {
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        }
        Write-Host "  OK (after retry)" -ForegroundColor Green
    }
}

# Step 1: Zephyr SDK minimal tarball
Write-Host "`n[1/6] Zephyr SDK minimal..." -ForegroundColor Yellow
Get-File `
    -Url "${SDK_BASE}/zephyr-sdk-${SDK_VERSION}_linux-x86_64_minimal.tar.xz" `
    -OutputPath "$DOWNLOADS\sdk\sdk-minimal.tar.xz"

# Step 2-5: Toolchains
$toolchains = @(
    "toolchain_linux-x86_64_arm-zephyr-eabi.tar.xz",
    "toolchain_linux-x86_64_xtensa-espressif_esp32_zephyr-elf.tar.xz",
    "toolchain_linux-x86_64_riscv64-zephyr-elf.tar.xz",
    "hosttools_linux-x86_64.tar.xz"
)

$idx = 2
foreach ($tc in $toolchains) {
    Write-Host "`n[$idx/6] Toolchain: $tc ..." -ForegroundColor Yellow
    Get-File `
        -Url "${SDK_BASE}/${tc}" `
        -OutputPath "$DOWNLOADS\sdk\$tc"
    $idx++
}

# Step 6: Zephyr source
Write-Host "`n[6/6] Zephyr source v${ZEPHYR_VERSION}..." -ForegroundColor Yellow
Get-File `
    -Url $ZEPHYR_URL `
    -OutputPath "$DOWNLOADS\zephyr\zephyr-${ZEPHYR_VERSION}.tar.gz"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Download complete!" -ForegroundColor Green
Write-Host " Files in: $DOWNLOADS" -ForegroundColor Cyan
Write-Host " Next: docker build -t headtracker-build F:\HeadTracker" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
