@echo off
:: scripts/update-apps.bat
chcp 65001 >nul
title Android TV 核心应用更新与安装工具

echo ========================================================
echo        Android TV 核心应用更新与一键安装工具
echo ========================================================
echo.
echo 纳管应用:
echo   1. BT (Bilibili TV 开源版)
echo   2. TizenTube Cobalt (YouTube TV 开源版)
echo   3. TVBox (开源聚合播放器)
echo   4. mytv-android (极简电视直播)
echo   5. Emotn Launcher (纯净长辈桌面)
echo.
echo ========================================================
echo 请选择执行模式:
echo.
echo [1] 一键下载/更新并推送到电视安装 (推荐)
echo [2] 仅下载/更新最新 APK 到本地 (apk/ 目录)
echo [3] 检查版本状态 (不下载、不安装)
echo [4] 强制重新拉取并推送到电视安装 (Force)
echo [5] 退出
echo ========================================================
echo.

set /p UCHOICE="请输入选择 [1-5]: "

if "%UCHOICE%"=="1" goto MODE_INSTALL
if "%UCHOICE%"=="2" goto MODE_DOWNLOAD
if "%UCHOICE%"=="3" goto MODE_CHECK
if "%UCHOICE%"=="4" goto MODE_FORCE_INSTALL
if "%UCHOICE%"=="5" exit /b 0

echo [!] 无效输入，默认执行一键更新与推送安装...
goto MODE_INSTALL

:MODE_INSTALL
echo.
echo [*] 正在启动更新并推送到电视...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-apps.ps1" -Mode Install
goto FINISH

:MODE_DOWNLOAD
echo.
echo [*] 正在仅下载更新到本地 apk/ 目录...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-apps.ps1" -Mode Download
goto FINISH

:MODE_CHECK
echo.
echo [*] 正在检查远程与本地版本状态...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-apps.ps1" -Mode Check
goto FINISH

:MODE_FORCE_INSTALL
echo.
echo [*] 正在强制重新下载并推送到电视...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-apps.ps1" -Mode Install -Force
goto FINISH

:FINISH
echo.
echo ========================================================
echo 执行结束。
echo ========================================================
pause
exit /b 0

