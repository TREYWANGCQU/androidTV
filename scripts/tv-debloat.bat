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

