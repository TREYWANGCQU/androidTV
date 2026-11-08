@echo off
:: scripts/tv-connect.bat
chcp 65001 >nul
title Android TV 无线 ADB 连接工具

echo ========================================================
echo           Android TV 局域网 ADB 无线连接工具
echo ========================================================
echo.

:: 1. 检查本地 ADB 环境
where adb >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未在系统 PATH 中找到 adb.exe！
    echo 请先参考 doc/01_windows_adb_setup.md 配置 ADB 工具链。
    pause
    exit /b 1
)

:: 2. 读取或输入电视 IP
set /p TV_IP="请输入电视的局域网 IP 地址 (例如 192.168.1.105): "
if "%TV_IP%"=="" (
    echo [提示] 输入不能为空！
    pause
    exit /b 1
)

echo.
echo [*] 正在尝试连接至 %TV_IP%:5555 ...
adb connect %TV_IP%:5555

echo.
echo [*] 正在校验设备在线状态与授权指纹...
adb devices | findstr /i "%TV_IP%:5555.*device" >nul
if %errorlevel% equ 0 (
    echo ========================================================
    echo [成功] 电视连接就绪！当前状态: 已授权 (device)
    echo ========================================================
) else (
    echo ========================================================
    echo [警告] 尚未成功就绪，请核对：
    echo 1. 电视屏幕是否弹出"允许网络调试"弹窗？请用遥控器点击"允许"。
    echo 2. 电视 IP 是否输入正确？
    echo 3. 运行 "adb devices" 查看当前具体状态。
    echo ========================================================
)

echo.
pause

