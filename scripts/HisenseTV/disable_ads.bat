@echo off
:: scripts/HisenseTV/disable_ads.bat
chcp 65001 >nul
setlocal enabledelayedexpansion
title 海信智能电视 (VIDAA) 广告与遥测一键安全禁用脚本

:: ==============================================================================
:: Android TV (Hisense VIDDA_TV) 一键广告、遥测与冗余组件消杀工具
:: 基准凭据: doc/debug/ad_packages_audit.md
:: 设备基准: Hisense VIDDA_TV (Android 9 / API 28)
:: ==============================================================================

set "DEFAULT_DEVICE_IP=192.168.120.12:5555"
set "TARGET_DEVICE="

echo ==============================================================================
echo       海信智能电视 (VIDDA_TV) 免 Root 广告/遥测/冗余组件一键消杀工具
echo ==============================================================================
echo 基准报告: doc/debug/ad_packages_audit.md
echo 执行模式: 用户级安全冻结 (pm disable-user --user 0) [安全无损/完全可逆]
echo ==============================================================================
echo.

:: 1. ADB 基础环境巡检
where adb >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未在系统 PATH 中检测到 adb.exe！
    echo 请先配置 Android Platform Tools 环境后再执行。
    pause
    exit /b 1
)

:: 2. 设备目标确定与连接探测
if not "%~1"=="" (
    if /i "%~1"=="--restore" (
        goto RESTORE_MODE
    )
    if /i "%~1"=="--all" (
        set "AUTO_ALL=1"
        goto DETECT_DEVICE
    )
    set "TARGET_DEVICE=%~1"
)

:DETECT_DEVICE
if "%TARGET_DEVICE%"=="" (
    :: 探测是否有当前已连接的 target
    adb devices | findstr /i "%DEFAULT_DEVICE_IP%.*device" >nul 2>nul
    if %errorlevel% equ 0 (
        set "TARGET_DEVICE=%DEFAULT_DEVICE_IP%"
    ) else (
        adb get-state >nul 2>nul
        if %errorlevel% equ 0 (
            for /f "tokens=1" %%d in ('adb devices ^| findstr /r /v "^$" ^| findstr /v "List"') do (
                if not "%%d"=="" (
                    set "TARGET_DEVICE=%%d"
                    goto DEVICE_FOUND
                )
            )
        )
        :: 未就绪则尝试连接默认 IP
        echo [*] 正在尝试连线默认海信电视端点: %DEFAULT_DEVICE_IP% ...
        adb connect %DEFAULT_DEVICE_IP% >nul 2>nul
        adb devices | findstr /i "%DEFAULT_DEVICE_IP%.*device" >nul 2>nul
        if !errorlevel! equ 0 (
            set "TARGET_DEVICE=%DEFAULT_DEVICE_IP%"
        ) else (
            echo.
            echo [提示] 未能自动连接至 %DEFAULT_DEVICE_IP%。
            set /p "TARGET_DEVICE=请输入电视 IP:端口 (直接回车默认: %DEFAULT_DEVICE_IP%): "
            if "!TARGET_DEVICE!"=="" set "TARGET_DEVICE=%DEFAULT_DEVICE_IP%"
            adb connect !TARGET_DEVICE!
        )
    )
)

:DEVICE_FOUND
echo [*] 正在校验电视连接状态与 ADB 授权 [%TARGET_DEVICE%] ...
adb -s %TARGET_DEVICE% get-state >nul 2>nul
if %errorlevel% neq 0 (
    echo [致命错误] 设备 %TARGET_DEVICE% 未就绪或未授权！
    echo 1. 请检查电视与电脑是否处于同一 Wi-Fi / 局域网。
    echo 2. 请留意电视屏幕是否有"允许 USB/网络调试"弹窗，并用遥控器点击"允许"。
    pause
    exit /b 1
)
echo [成功] 电视连接就绪: %TARGET_DEVICE%
echo.

:: 3. 模式选择菜单 (若非命令行静默参数)
if "%AUTO_ALL%"=="1" goto RUN_ALL_DEBLOAT

echo ------------------------------------------------------------------------------
echo 请选择执行动作：
echo [1] 执行标准一键消杀 (P1核心广告 + P2遥测长连接 + P3出厂冗余 + P4聚好看营销)
echo [2] 执行全量深度消杀 (标准消杀 + 额外冻结虚拟人助手小聚 ~77MB + 息屏听歌)
echo [3] 查看当前已冻结组件及可用物理内存
echo [4] 灾备自愈：一键解冻恢复海信所有被禁组件
echo [0] 退出
echo ------------------------------------------------------------------------------
set /p "ACT_CHOICE=请输入选项 [1-4, 默认1]: "
if "%ACT_CHOICE%"=="" set "ACT_CHOICE=1"

if "%ACT_CHOICE%"=="1" goto RUN_STANDARD_DEBLOAT
if "%ACT_CHOICE%"=="2" goto RUN_ALL_DEBLOAT
if "%ACT_CHOICE%"=="3" goto INSPECT_STATE
if "%ACT_CHOICE%"=="4" goto RESTORE_MODE
if "%ACT_CHOICE%"=="0" exit /b 0

echo [提示] 无效输入，默认进入标准一键消杀。
goto RUN_STANDARD_DEBLOAT

:: ==============================================================================
:: 执行消杀逻辑
:: ==============================================================================
:RUN_STANDARD_DEBLOAT
set "INCLUDE_OPTIONAL=0"
goto DO_DEBLOAT

:RUN_ALL_DEBLOAT
set "INCLUDE_OPTIONAL=1"
goto DO_DEBLOAT

:DO_DEBLOAT
echo.
echo ==============================================================================
echo [*] 开始执行海信电视组件靶向消杀...
echo ==============================================================================

:: --- 第一优先级：核心广告与商业化投放组件 ---
echo.
echo [--- 1/4 第一优先级：核心广告与商业化投放组件 ---]
call :DISABLE_PKG "com.hisense.business.ad" "阿里百川商业化广告 SDK (电视淘宝/导购/弹窗)"

:: --- 第二优先级：数据采集、遥测与云端长连接服务 ---
echo.
echo [--- 2/4 第二优先级：数据采集、遥测与云端长连接服务 (核心降载) ---]
call :DISABLE_PKG "com.hisense.hitv.das" "海信数据采集服务 (DAS 交互行为/收视埋点)"
call :DISABLE_PKG "com.hisense.tv.infer" "端侧 AI 推荐推理引擎 (推荐流与定向广告计算)"
call :DISABLE_PKG "com.hisense.hiservice" "海信 MQTT 长连接推送服务 (常驻通知/营销监听)"
call :DISABLE_PKG "com.hisense.logupload" "海信错误与诊断日志上传服务 (后台打包回传)"

:: --- 第三优先级：出厂演示、工厂测试与初次引导 ---
echo.
echo [--- 3/4 第三优先级：出厂演示、工厂测试与初次引导 ---]
call :DISABLE_PKG "com.hisense.demonstrate" "卖场演示应用 (线下展厅视频轮播 Demo)"
call :DISABLE_PKG "com.hisense.autotest" "硬件自动化测试工具 (产线测试组件)"
call :DISABLE_PKG "com.hisense.uifac" "工厂模式 UI (出厂调试校准界面)"
call :DISABLE_PKG "com.jamdeo.tv.fte" "首次开机向导 (初次通电设置，后续冗余)"

:: --- 第四优先级：聚好看增值营销、日历与虚拟形象素材 ---
echo.
echo [--- 4/4 第四优先级：聚好看增值营销、日历与虚拟形象素材 ---]
call :DISABLE_PKG "com.jamdeo.android.jamdeoavatartrafficcontrol" "Avatar 虚拟形象流量管控组件"
call :DISABLE_PKG "com.jamdeo.android.avatarresources" "虚拟形象动效资源包"
call :DISABLE_PKG "com.jamdeo.calendar" "聚好看日历 (营销日历与商业推荐)"
call :DISABLE_PKG "com.speech.chatroom" "语音聊天室推流服务 (社交互动推流)"

:: --- 条件评估项：深度内存优化 ---
if "%INCLUDE_OPTIONAL%"=="1" (
    echo.
    echo [--- 额外项：深度优化组件 (释放 ~77MB 活跃物理内存) ---]
    call :DISABLE_PKG "com.hisense.tv.aivirtualassistant" "海信虚拟人 AI 助手 (小聚卡通形象，保留基础遥控语音)"
    call :DISABLE_PKG "com.hisense.singlelisten" "单独听服务 (息屏听歌功能)"
)

echo.
echo ==============================================================================
echo [完成] 选定组件已完成处理！
echo ==============================================================================
goto INSPECT_STATE

:: ==============================================================================
:: 子例程: 安全禁用组件 (含绝对白名单防护)
:: ==============================================================================
:DISABLE_PKG
set "PKG_NAME=%~1"
set "PKG_DESC=%~2"

:: 绝对安全防砖白名单校验 (防呆熔断)
if /i "%PKG_NAME%"=="android" goto WHITELIST_ALARM
if /i "%PKG_NAME%"=="com.android.systemui" goto WHITELIST_ALARM
if /i "%PKG_NAME%"=="com.android.tv.settings" goto WHITELIST_ALARM
if /i "%PKG_NAME%"=="com.android.settings" goto WHITELIST_ALARM
if /i "%PKG_NAME%"=="com.sohu.inputmethod.sogou.tv" goto WHITELIST_ALARM
if /i "%PKG_NAME%"=="com.android.bluetooth" goto WHITELIST_ALARM
if /i "%PKG_NAME%"=="com.hisense.tv.inputs" goto WHITELIST_ALARM
if /i "%PKG_NAME%"=="com.hisense.tv.baseservice" goto WHITELIST_ALARM
if /i "%PKG_NAME%"=="com.jamdeo.tv.service" goto WHITELIST_ALARM
if /i "%PKG_NAME%"=="com.multiscreen.airplay" goto WHITELIST_ALARM
if /i "%PKG_NAME%"=="com.hisense.wifidisplay" goto WHITELIST_ALARM
if /i "%PKG_NAME%"=="com.oversea.aslauncher" goto WHITELIST_ALARM

echo [*] 正在处理: %PKG_DESC% ...
adb -s %TARGET_DEVICE% shell pm disable-user --user 0 %PKG_NAME% 2>nul | findstr /i "disabled-user disabled" >nul 2>nul
if %errorlevel% equ 0 (
    echo     [成功] 已冻结: %PKG_NAME%
) else (
    :: 检查是否本来就未安装或属于历史注销组件
    adb -s %TARGET_DEVICE% shell pm list packages | findstr /x "package:%PKG_NAME%" >nul 2>nul
    if %errorlevel% neq 0 (
        echo     [跳过] 该组件当前未处于安装状态或已注销 (%PKG_NAME%)
    ) else (
        echo     [状态] 已执行冻结指令: %PKG_NAME%
    )
)
goto :eof

:WHITELIST_ALARM
echo [严重警报] 触发绝对防砖白名单拦截！拒绝冻结关键底层系统组件: %PKG_NAME%
goto :eof

:: ==============================================================================
:: 状态与内存巡检
:: ==============================================================================
:INSPECT_STATE
echo.
echo ==============================================================================
echo                       电视当前已冻结组件清单 (pm list packages -d)
echo ==============================================================================
adb -s %TARGET_DEVICE% shell pm list packages -d
echo ==============================================================================
echo.
echo [*] 当前系统内存状态快照 (MemFree / MemAvailable):
adb -s %TARGET_DEVICE% shell cat /proc/meminfo | findstr /i "MemTotal MemFree MemAvailable"
echo.
echo 建议使用遥控器重启电视观察系统流畅度与开机状态。
pause
exit /b 0

:: ==============================================================================
:: 灾备自愈：一键解冻恢复模式
:: ==============================================================================
:RESTORE_MODE
if "%TARGET_DEVICE%"=="" goto DETECT_DEVICE

echo.
echo ==============================================================================
echo [*] 正在执行海信电视组件一键解冻恢复 (pm enable)...
echo ==============================================================================

call :ENABLE_PKG "com.hisense.business.ad" "阿里百川商业化广告 SDK"
call :ENABLE_PKG "com.hisense.hitv.das" "海信数据采集服务 (DAS)"
call :ENABLE_PKG "com.hisense.tv.infer" "端侧 AI 推荐推理引擎"
call :ENABLE_PKG "com.hisense.hiservice" "海信 MQTT 长连接推送服务"
call :ENABLE_PKG "com.hisense.logupload" "海信错误与诊断日志上传服务"
call :ENABLE_PKG "com.hisense.demonstrate" "卖场演示应用"
call :ENABLE_PKG "com.hisense.autotest" "硬件自动化测试工具"
call :ENABLE_PKG "com.hisense.uifac" "工厂模式 UI"
call :ENABLE_PKG "com.jamdeo.tv.fte" "首次开机向导"
call :ENABLE_PKG "com.jamdeo.android.jamdeoavatartrafficcontrol" "Avatar 虚拟形象流量管控组件"
call :ENABLE_PKG "com.jamdeo.android.avatarresources" "虚拟形象动效资源包"
call :ENABLE_PKG "com.jamdeo.calendar" "聚好看日历"
call :ENABLE_PKG "com.speech.chatroom" "语音聊天室推流服务"
call :ENABLE_PKG "com.hisense.tv.aivirtualassistant" "海信虚拟人 AI 助手"
call :ENABLE_PKG "com.hisense.singlelisten" "单独听服务"

echo.
echo ==============================================================================
echo [完成] 所有海信消杀目标组件已发送恢复解冻指令！
echo ==============================================================================
pause
exit /b 0

:ENABLE_PKG
set "PKG_NAME=%~1"
set "PKG_DESC=%~2"
echo [*] 正在解冻: %PKG_DESC% (%PKG_NAME%)...
adb -s %TARGET_DEVICE% shell pm enable %PKG_NAME% >nul 2>nul
goto :eof

