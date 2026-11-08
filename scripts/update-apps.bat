:: scripts/update-apps.bat
@echo off
chcp 65001 >nul
title Android TV 核心应用自动更新与归档工具

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%update-apps.ps1"

where powershell >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 系统中未找到 powershell.exe，无法启动核心引擎！
    pause
    exit /b 1
)

if not exist "%PS_SCRIPT%" (
    echo [错误] 找不到核心解析脚本: "%PS_SCRIPT%"
    pause
    exit /b 1
)

if "%~1"=="1" goto run_download
if /i "%~1"=="download" goto run_download
if "%~1"=="2" goto run_install
if /i "%~1"=="install" goto run_install
if "%~1"=="3" goto run_check
if /i "%~1"=="check" goto run_check
if "%~1"=="4" goto run_force
if /i "%~1"=="force" goto run_force
if not "%~1"=="" goto run_custom

:menu
cls
echo ========================================================
echo         Android TV 核心应用自动更新与归档工具
echo ========================================================
echo.
echo  [1] 一键检查并下载所有最新 APK 到本地 (apk/)
echo  [2] 一键下载并推送到电视覆盖安装 (ADB)
echo  [3] 仅检查应用最新版本状态 (不执行下载)
echo  [4] 强制重新下载所有应用最新版本 (忽略缓存)
echo  [0] 退出
echo.
echo ========================================================
set /p CHOICE="请选择操作序号 [0-4]: "

if "%CHOICE%"=="1" goto run_download
if "%CHOICE%"=="2" goto run_install
if "%CHOICE%"=="3" goto run_check
if "%CHOICE%"=="4" goto run_force
if "%CHOICE%"=="0" exit /b 0

echo [提示] 输入无效，请重新选择。
timeout /t 2 >nul
goto menu

:run_download
echo.
echo [*] 正在启动应用下载与本地归档流程...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Mode Download
goto finish

:run_install
echo.
echo [*] 正在启动应用下载与电视覆盖安装流程...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Mode Install
goto finish

:run_check
echo.
echo [*] 正在检查各应用远程最新版本状态...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Mode Check
goto finish

:run_force
echo.
echo [*] 正在强制重新下载所有应用最新版本...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Mode Download -Force
goto finish

:run_custom
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
goto finish

:finish
echo.
echo ========================================================
echo 操作执行完毕。
echo ========================================================
pause

