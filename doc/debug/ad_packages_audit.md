# debug/ad_packages_audit.md
# Android TV (Hisense VIDDA_TV) 广告、遥测与冗余组件清查审计报告

> 采集时间: 2026-11-08  
> 采集工具: /collector (Context Collector Mode)  
> 设备标识: `192.168.120.12:5555`

---

## 1. 宿主设备运行基准 (Device Baseline)

| 参数项 | 采集值 | 备注 |
| :--- | :--- | :--- |
| **设备制造商 (Manufacturer)** | `Hisense` | 海信 |
| **品牌 (Brand) / 机型 (Model)** | `Hisense` / `VIDDA_TV` | VIDAA 智能电视平台 |
| **Android 版本 / SDK 级别** | `Android 9 (Pie)` / `API 28` | 支持 `pm disable-user --user 0` |
| **总物理内存 (MemTotal)** | `1,484,056 kB (~1.42 GB)` | 硬件属于受限小内存 TV 机型 |
| **空闲可用内存 (MemAvailable)** | `~575,968 kB (~562 MB)` | 内存压力较高，后台极易遭遇 OOM 杀进程 |
| **当前激活桌面 (Home Launcher)** | `com.oversea.aslauncher` (Emotn Launcher) | 已完成第三方桌面接管 |
| **当前已安装包总数** | 78 个 | 包含系统组件、预装组件与用户应用 |
| **历史已注销/卸载组件数** | 20 个 (`pm list packages -u` 对账) | 历史曾执行过部分模块卸载 |

---

## 2. 存量可消杀广告、遥测与冗余组件清单 (Targeted Debloat Candidates)

### 2.1 第一优先级：核心广告与商业化投放组件 (Direct Commercial Ads)

本分类组件属于纯粹的商业广告推流、阿里百川电商 SDK 与弹窗广告来源，停用后对基础电视播放与系统功能零负面影响。

| 包名 (Package Name) | APK 路径 | 当前运行状态 | 内存消耗 (RSS) | 功能定位与消杀理由 |
| :--- | :--- | :--- | :--- | :--- |
| `com.hisense.business.ad` | `/data/app/com.hisense.business.ad-.../base.apk` | STOPPED | 0 MB (未启动) | **阿里百川商业化广告 SDK**。内置电视淘宝、AliBC 智能导购、直播与弹窗广告组件。曾由 `com.hisense.service.ad` 安装，残留在 `/data/app` 中。 |

### 2.2 第二优先级：数据采集、遥测与云端长连接服务 (Telemetry & Push)

本分类组件持续驻留后台，轮询收集用户收视习惯、按键事件、应用切换日志并上传至海信云端，同时维持 MQTT 长连接监听营销通知。**是吞噬 1.5G 电视内存的核心元凶**。

| 包名 (Package Name) | APK 路径 | 当前运行状态 | 内存消耗 (RSS) | 功能定位与消杀理由 |
| :--- | :--- | :--- | :--- | :--- |
| `com.hisense.hitv.das` | `/system/priv-app/DasApp/DasApp.apk` | **RUNNING (PID 4572)** | **82.6 MB** | **海信数据采集服务 (DAS - Data Acquisition Service)**。常驻后台记录用户交互行为、收视埋点并定期上报。**建议立即冻结**。 |
| `com.hisense.tv.infer` | `/system/app/inference/inference.apk` | **RUNNING (PID 9554)** | **64.2 MB** | **端侧 AI 推荐推理引擎**。用于个性化视频瀑布流推荐与广告定向推送。在已使用第三方桌面的环境下属于纯内存浪费。**建议立即冻结**。 |
| `com.hisense.hiservice` | `/system/app/MsHiservice_Mqtt/MsHiservice_Mqtt.apk` | **RUNNING (PID 9645)** | **53.5 MB** | **海信 MQTT 长连接推送服务**。监听云端运营通知、弹窗与营销活动推送。**建议立即冻结**。 |
| `com.hisense.logupload` | `/system/app/LogUpload/LogUpload.apk` | STOPPED | 0 MB (休眠) | **海信错误与诊断日志上传服务**。定期将系统日志打包回传。 |

### 2.3 第三优先级：出厂演示、工厂测试与已失效的初次引导 (Factory & Setup Bloat)

出厂阶段留存的测试工具与初次开机引导，日常使用完全无用。

| 包名 (Package Name) | APK 路径 | 当前运行状态 | 内存消耗 (RSS) | 功能定位与消杀理由 |
| :--- | :--- | :--- | :--- | :--- |
| `com.hisense.demonstrate` | `/system/app/DemonstrateDemo/DemonstrateDemo.apk` | STOPPED | 0 MB | **卖场演示应用 (Demo Mode)**。线下展厅用的促销视频轮播与展示模式。 |
| `com.hisense.autotest` | `/system/app/AutoTest/AutoTest.apk` | STOPPED | 0 MB | **硬件自动化测试工具**。产线测试组件。 |
| `com.hisense.uifac` | `/system/app/HisFac/HisFac.apk` | STOPPED | 0 MB | **工厂模式 UI (Factory Mode)**。出厂调试校准界面。 |
| `com.jamdeo.tv.fte` | `/system/app/FTE_V6/FTE_V6.apk` | STOPPED | 0 MB | **First Time Experience (首次开机向导)**。仅新机初次通电时需要，后续常驻监听开机广播。 |

### 2.4 第四优先级：聚好看增值营销、日历与虚拟形象组件 (Value-Added Bloat)

包含聚好看附属的虚拟形象素材、营销日历及语音互动聊天室组件。

| 包名 (Package Name) | APK 路径 | 当前运行状态 | 内存消耗 (RSS) | 功能定位与消杀理由 |
| :--- | :--- | :--- | :--- | :--- |
| `com.jamdeo.android.jamdeoavatartrafficcontrol` | `/system/priv-app/AvataTrafficControl/AvataTrafficControl.apk` | STOPPED | 0 MB | **Avatar 虚拟形象流量管控**。用于聚好看虚拟人素材流量统计。 |
| `com.jamdeo.android.avatarresources` | `/system/app/Avatarresources/Avatarresources.apk` | STOPPED | 0 MB | **虚拟形象动效资源包**。占用磁盘且无独立功能。 |
| `com.jamdeo.calendar` | `/system/app/CinesenseCalendar_A5H/CinesenseCalendar_A5H.apk` | STOPPED | 0 MB | **聚好看日历**。集成节日排期与影视商业推荐。 |
| `com.speech.chatroom` | `/system/app/speechChatRoom/speechChatRoom.apk` | STOPPED | 0 MB | **语音聊天室推流服务**。电视端社交互动推流组件。 |

### 2.5 条件性建议（按需评估项）

| 包名 (Package Name) | APK 路径 | 当前运行状态 | 内存消耗 (RSS) | 评估说明 |
| :--- | :--- | :--- | :--- | :--- |
| `com.hisense.tv.aivirtualassistant` | `/system/app/HisenseVirtualAssistant_A5H/...` | **RUNNING (PID 4234)** | **77.5 MB** | **海信虚拟形象 AI 助手**。若不需要屏幕上浮现“小聚”虚拟卡通形象动效，冻结可直接净省 77.5 MB RAM。基础语音遥控主要依赖 `com.aispeech.dui.dds.tvassistant`。 |
| `com.hisense.singlelisten` | `/system/app/SingleListen_V6/SingleListen_V6.apk` | STOPPED | 0 MB | **单独听 (息屏听歌)**。若不需要关闭屏幕纯听音乐的功能，可一并冻结。 |

---

## 3. 内存释放预估收益 (Memory Recovery Forecast)

当前 5 个活跃的目标组件合计占用内存：
$$\text{Total Recoverable RAM} = 82.6\text{ MB (DAS)} + 64.2\text{ MB (Infer)} + 53.5\text{ MB (MQTT)} + 77.5\text{ MB (Virtual Assistant)} \approx 277.8\text{ MB}$$

> [!TIP]
> 电视总可用物理内存仅约 1.42 GB（当前剩余 562 MB）。执行上述消杀后，**预计将为电视释放约 200 MB ~ 278 MB 的活跃物理内存**，系统空闲内存将从 562 MB 显著提升至 760 MB ~ 840 MB（提升约 35% ~ 50%），极大减轻后台应用切换时的掉帧与被杀概率。

---

## 4. 历史已卸载组件对账表 (Historically Uninstalled in User 0)

经 `pm list packages -u` 与当前安装包比对，以下 20 个组件在之前已被卸载/停用，记录在案避免重复操作：

1. `com.hisense.service.ad` (海信基础广告服务)
2. `com.jamdeo.tv.vod` (聚好看点播推流)
3. `com.jamdeo.screensaver` (屏保推荐广告)
4. `com.hisense.service.message` (消息推送)
5. `com.hisense.hitv.payment` (收银台与支付中心)
6. `com.jamdeo.updateservice` (强制更新服务)
7. `com.hisense.hotelmenu` (酒店工程菜单)
8. `com.hisense.childlock` (少儿锁)
9. `com.hisense.tv.weather` (天气推荐)
10. `com.hisense.tv.foodmanage` (生鲜食材管理)
11. `com.hisense.tv.familyalbum` (家庭云相册)
12. `com.hisense.smartimages` (智能画报推流)
13. `com.hisense.electronictutorial` (电子说明书)
14. `com.hisense.tv.videochat.social` (社交视频通话)
15. `com.hisense.tv.mirror` (魔镜)
16. `com.hisense.aiot` (AIoT 智能家居)
17. `com.hisense.vidaaassistant` (语音助手旧模块)
18. `com.android.wechathci` (微信互联)
19. `com.hisense.hitv.hicloud.account` (海信云账号)
20. `com.keylab.speech.core.vidaa` (旧语音核心)

---

## 5. 绝对防砖白名单（严禁冻结）

以下组件属于电视基础输入、网络、多屏通信与图形渲染关键层，**严禁执行 disable 或 uninstall**：

| 包名 (Package Name) | 职责说明 | 风险后果 |
| :--- | :--- | :--- |
| `android` / `com.android.systemui` | Android 核心框架与 SystemUI | 开机黑屏、遥控无法渲染焦点、按键无响应 |
| `com.android.tv.settings` / `com.android.settings` | TV 设置与系统参数存储 | 设置崩溃、网络与蓝牙无法配置 |
| `com.sohu.inputmethod.sogou.tv` | 当前系统唯一的已启用输入法 | 无法键入 Wi-Fi 密码或搜索内容 |
| `com.android.bluetooth` | 蓝牙协议栈与遥控通信 | 蓝牙遥控器断连失灵 |
| `com.hisense.tv.inputs` | HDMI 与信号源管理 | 无法切换机顶盒、游戏机 HDMI 输入 |
| `com.hisense.tv.baseservice` / `com.jamdeo.tv.service` | 海信/聚好看底层硬件能力支撑 | 音效、画质调节与硬件控制异常 |
| `com.multiscreen.airplay` / `com.hisense.wifidisplay` | 投屏与多屏互动服务 | 手机无法投屏至电视 |
| `com.oversea.aslauncher` | 当前主桌面 (Emotn Launcher) | 桌面崩溃黑屏 |

---

## 6. 建议消杀批处理脚本 (Safe ADB Freeze Commands)

建议采用 `pm disable-user --user 0` 机制（完全可逆、保留系统分区 integrity、绝不破坏 OTA 兼容性）：

```cmd
:: ==========================================
:: 1. 核心广告与数据上报/遥测消杀 (高收益)
:: ==========================================
adb -s 192.168.120.12:5555 shell pm disable-user --user 0 com.hisense.business.ad
adb -s 192.168.120.12:5555 shell pm disable-user --user 0 com.hisense.hitv.das
adb -s 192.168.120.12:5555 shell pm disable-user --user 0 com.hisense.tv.infer
adb -s 192.168.120.12:5555 shell pm disable-user --user 0 com.hisense.hiservice
adb -s 192.168.120.12:5555 shell pm disable-user --user 0 com.hisense.logupload

:: ==========================================
:: 2. 出厂演示与测试冗余消杀
:: ==========================================
adb -s 192.168.120.12:5555 shell pm disable-user --user 0 com.hisense.demonstrate
adb -s 192.168.120.12:5555 shell pm disable-user --user 0 com.hisense.autotest
adb -s 192.168.120.12:5555 shell pm disable-user --user 0 com.hisense.uifac
adb -s 192.168.120.12:5555 shell pm disable-user --user 0 com.jamdeo.tv.fte

:: ==========================================
:: 3. 增值营销与附属组件消杀
:: ==========================================
adb -s 192.168.120.12:5555 shell pm disable-user --user 0 com.jamdeo.android.jamdeoavatartrafficcontrol
adb -s 192.168.120.12:5555 shell pm disable-user --user 0 com.jamdeo.android.avatarresources
adb -s 192.168.120.12:5555 shell pm disable-user --user 0 com.jamdeo.calendar
adb -s 192.168.120.12:5555 shell pm disable-user --user 0 com.speech.chatroom

:: ==========================================
:: 4. (可选) 停用虚拟人助手 (可释放 ~77MB 内存)
:: ==========================================
:: adb -s 192.168.120.12:5555 shell pm disable-user --user 0 com.hisense.tv.aivirtualassistant
```

恢复命令模板：
```cmd
adb -s 192.168.120.12:5555 shell pm enable <应用包名>
```

