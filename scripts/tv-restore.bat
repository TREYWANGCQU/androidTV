@echo off
:: scripts/tv-restore.bat
chcp 65001 >nul
title Android TV 应用解冻与恢复工具

echo ========================================================
echo           Android TV 应用解冻与恢复工具
echo ========================================================
echo.

adb get-state >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未检测到在线电视设备，请先确保已连接。
    pause
    exit /b 1
)

echo [1] 恢复指定包名 (手动输入包名解冻)
echo [2] 一键恢复小米/红米常见广告与系统组件
echo [3] 退出
echo.
set /p RCHOICE="请选择操作 [1-3]: "

if "%RCHOICE%"=="1" goto MANUAL_ENABLE
if "%RCHOICE%"=="2" goto ENABLE_XIAOMI
if "%RCHOICE%"=="3" exit /b 0
goto :eof

:MANUAL_ENABLE
set /p TARGET_PKG="请输入待解冻的完整包名: "
if "%TARGET_PKG%"=="" goto :eof
echo 正在解冻 %TARGET_PKG% ...
adb shell pm enable %TARGET_PKG%
echo 解冻完成。
pause
exit /b 0

:ENABLE_XIAOMI
echo 正在解冻小米核心与基础组件...
adb shell pm enable com.xiaomi.mitv.advertise
adb shell pm enable com.xiaomi.mitv.adplayer
adb shell pm enable com.xiaomi.mitv.upgrade
adb shell pm enable com.mitv.videoplayer
adb shell pm enable com.xiaomi.mitv.shop
adb shell pm enable com.xiaomi.mitv.tvpush.tvpushservice
adb shell pm enable com.mitv.tvhome
echo 恢复完成！
pause
exit /b 0

