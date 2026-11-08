# 04. 自动化批处理与工具化运维指南

为了免去每次手动逐行敲入长包名命令的繁琐过程，本篇提供可在 Windows 环境下一键执行的批处理（Batch）脚本。

脚本集涵盖：
1. **`tv-connect.bat`**：自动检测环境、局域网连接与设备鉴权状态探针。
2. **`tv-debloat.bat`**：分品牌交互式菜单，安全批量冻结广告组件。
3. **`tv-restore.bat`**：一键解冻与灾备自愈脚本。

---

## 1. 脚本 1：设备无线连接与状态巡检 (`tv-connect.bat`)

此脚本自动检测 Windows 系统是否已安装 `adb`，支持记录上次输入的电视 IP，并在连接后验证是否具备 `device` 权限。

```bat
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
```

---

## 2. 脚本 2：分品牌广告安全冻结器 (`tv-debloat.bat`)

采用 `pm disable-user --user 0` 机制，带有操作日志与品牌针对性消杀逻辑。

```bat
@echo off
:: scripts/tv-debloat.bat
chcp 65001 >nul
title Android TV 免Root广告安全消杀工具

echo ========================================================
echo           Android TV 广告组件安全冻结器 (免 Root)
echo ========================================================
echo.

:: 确保有在线设备
adb get-state >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未检测到在线已授权的 Android TV 设备！
    echo 请先运行 tv-connect.bat 建立连接。
    pause
    exit /b 1
)

:MENU
echo 请选择您的电视品牌：
echo [1] 小米 / 红米电视 (PatchWall / MIUI TV)
echo [2] 海信电视 (VIDAA / 聚好看)
echo [3] TCL / 雷鸟电视 (雷鸟瀑布流)
echo [4] 创维 / 酷开电视 (Coocaa OS)
echo [5] 仅查看当前已被冻结的应用列表
echo [0] 退出脚本
echo.
set /p CHOICE="请输入数字选项 [0-5]: "

if "%CHOICE%"=="1" goto XIAOMI
if "%CHOICE%"=="2" goto HISENSE
if "%CHOICE%"=="3" goto TCL
if "%CHOICE%"=="4" goto SKYWORTH
if "%CHOICE%"=="5" goto LIST_DISABLED
if "%CHOICE%"=="0" exit /b 0

echo [提示] 输入无效，请重新选择。
goto MENU

:XIAOMI
echo.
echo [*] 正在为 小米/红米 电视执行广告冻结...
call :DISABLE com.xiaomi.mitv.advertise "开机与弹窗广告"
call :DISABLE com.xiaomi.mitv.adplayer "广告视频播放器"
call :DISABLE com.xiaomi.mitv.upgrade "强制广告版本升级服务"
call :DISABLE com.mitv.videoplayer "广告开屏播放器"
call :DISABLE com.xiaomi.mitv.shop "电视商城"
call :DISABLE com.xiaomi.mitv.tvpush.tvpushservice "常驻推送广告"
call :DISABLE com.duokan.videoplayer.tv "多看预装推流"
goto DONE

:HISENSE
echo.
echo [*] 正在为 海信 电视执行广告冻结...
call :DISABLE com.hisense.hitv.hicloud.adapp "海信开机与云广告"
call :DISABLE com.hisense.tv.videoad "海信视频广告"
call :DISABLE com.jamdeo.tv.vod "聚好看流媒体推送"
goto DONE

:TCL
echo.
echo [*] 正在为 TCL/雷鸟 电视执行广告冻结...
call :DISABLE com.tcl.adservice "TCL 广告核心服务"
call :DISABLE com.tcl.commercial.ad "TCL 商业化广告"
call :DISABLE com.tcl.bootad "TCL 开机广告"
call :DISABLE com.tcl.waterfall "瀑布流视频推荐流"
goto DONE

:SKYWORTH
echo.
echo [*] 正在为 创维/酷开 电视执行广告冻结...
call :DISABLE com.coocaa.ad "酷开广告服务"
call :DISABLE com.tianci.ad "天赐推送广告"
call :DISABLE com.coocaa.mall "电视商城推广"
call :DISABLE com.coocaa.game "电视游戏推广"
goto DONE

:LIST_DISABLED
echo.
echo ===================== 当前已冻结应用 =====================
adb shell pm list packages -d
echo ========================================================
pause
goto MENU

:DISABLE
set PKG=%1
set DESC=%2
echo 正在停用 %DESC% (%PKG%)...
adb shell pm disable-user --user 0 %PKG%
goto :eof

:DONE
echo.
echo ========================================================
echo [完成] 选定品牌的广告组件已成功冻结！
echo 建议使用遥控器重启电视观察效果。
echo ========================================================
pause
goto MENU
```

---

## 3. 脚本 3：全量解冻与自愈恢复器 (`tv-restore.bat`)

若出现误伤功能或需要恢复系统原厂配置，此脚本可一键恢复所有被停用的应用。

```bat
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
```

