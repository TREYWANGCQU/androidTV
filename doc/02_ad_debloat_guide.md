# 02. 免 Root 广告应用消杀与系统瘦身指南

智能电视普遍内置开机广告、屏保广告、视频缓冲广告以及常驻推送服务，这些后台进程大量侵占本就有限的 TV 硬件内存（多数电视仅 1.5G~3G RAM），导致系统日常操作卡顿。

本篇介绍如何通过 ADB 免 Root 机制安全冻结广告服务，并提供针对国产品牌的精细化包名对照清单。

---

## 1. ADB 消杀命令核心机制

Android 系统提供了两套面向当前用户（`--user 0`）的应用隔离指令，理解其本质差异可保障操作可逆与系统稳定。

### 推荐：用户级冻结（`pm disable-user`）
```cmd
adb shell pm disable-user --user 0 <应用包名>
```
- **工作机制**：在用户 0 空间将该应用状态置为“已停用（Disabled）”。组件不会随开机启动，不会接收广播，桌面图标完全消失，但保留系统镜像里的 apk 文件。
- **优点**：**完全可逆、极其安全**。一旦误操作或需要使用该功能，一条命令即可满血复活，不破坏系统分区 Hash，绝不影响 OTA 固件升级。

### 备选：用户级卸载（`pm uninstall -k`）
```cmd
adb shell pm uninstall -k --user 0 <应用包名>
```
- **工作机制**：从用户空间注销该应用，保留应用数据（`-k` 参数）。系统在开机解析已安装列表时将完全跳过此应用。
- **恢复方式**：需通过 `adb shell cmd package install-existing <应用包名>` 重新挂载。

---

## 2. 系统安全防砖白名单（绝对禁止冻结）

> [!CAUTION]
> **以下组件属于 Android TV 运行时底层关键支撑，冻结任何一项都可能直接引发开机卡死、遥控器失灵或黑屏！**

| 组件分类 | 关键包名（严禁操作） | 风险描述 |
| :--- | :--- | :--- |
| **系统渲染与框架** | `android` (framework-res)<br>`com.android.systemui` | 状态栏、按键焦点监听、音量悬浮条与全局窗口渲染崩溃 |
| **系统核心设置** | `com.android.settings`<br>`com.android.providers.settings` | 全局参数存储异常，导致系统死锁开机无限重启 |
| **输入法服务 (IME)** | 当前电视唯一生效的输入法组件<br>*(若想换输入法，必须先装好并激活新输入法后，方可停用旧输入法)* | 无法输入文字，遇到 Wi-Fi 密码变更或登录时崩溃 |
| **蓝牙与遥控守护** | `com.android.bluetooth`<br>`com.android.server.telecom` | 蓝牙语音遥控器无法对码、断连、按键无响应 |
| **包安装与权限解析** | `com.android.packageinstaller`<br>`com.google.android.packageinstaller` | 无法再安装任何新 APK 应用 |

---

## 3. 国内主流品牌广告靶向包名清单

在操作前，可先通过命令检索电视中是否存在对应包名：
```cmd
adb shell pm list packages | findstr /i xiaomi
```

### 3.1 小米 / 红米电视 (MIUI TV / PatchWall)

小米电视广告大多集中在 `mitv` 命名空间下，冻结以下服务后可根治开机广告和开屏推荐：

```cmd
:: 1. 开机与系统弹窗广告组件（核心）
adb shell pm disable-user --user 0 com.xiaomi.mitv.advertise
adb shell pm disable-user --user 0 com.xiaomi.mitv.adplayer

:: 2. 升级自愈守护（防止联网后悄悄下载新广告策略）
adb shell pm disable-user --user 0 com.xiaomi.mitv.upgrade

:: 3. 广告型视频播放器与推流层
adb shell pm disable-user --user 0 com.mitv.videoplayer

:: 4. 电视商城与常驻推送通知
adb shell pm disable-user --user 0 com.xiaomi.mitv.shop
adb shell pm disable-user --user 0 com.xiaomi.mitv.tvpush.tvpushservice

:: 5. 垃圾流媒体与多看预装推荐（按需）
adb shell pm disable-user --user 0 com.duokan.videoplayer.tv
adb shell pm disable-user --user 0 com.xiaomi.mitv.smartshare
```

> [!TIP]
> **关于小米默认桌面 `com.mitv.tvhome`**：
> **请勿盲目执行 `disable`！** 在部分老款 MIUI TV 上直接停用原生桌面会导致按遥控器 Home 键黑屏死锁。请按照 [03 篇桌面防踢指南](file:///d:/offices/Github/AI-automation/See/androidTV/doc/03_third_party_launchers.md) 采用无障碍服务接管。

---

### 3.2 海信电视 (Hisense VIDAA / 聚好看)

海信系统的内置推荐与商业化广告主要分布在 `hitv` 与 `jamdeo` 模块：

```cmd
:: 1. 核心开机与视频广告服务
adb shell pm disable-user --user 0 com.hisense.hitv.hicloud.adapp
adb shell pm disable-user --user 0 com.hisense.tv.videoad

:: 2. 聚好看后台流媒体推送与推荐广告
adb shell pm disable-user --user 0 com.jamdeo.tv.vod

:: 3. 商业化服务与日志回传
adb shell pm disable-user --user 0 com.hisense.service.smarthome
adb shell pm disable-user --user 0 com.hisense.juconnect.connectservice
```

---

### 3.3 TCL / 雷鸟电视 (雷鸟系统 / 瀑布流)

TCL 与雷鸟电视开屏广告主要由商业广告服务拉起：

```cmd
:: 1. 核心广告推送与商业服务
adb shell pm disable-user --user 0 com.tcl.adservice
adb shell pm disable-user --user 0 com.tcl.commercial.ad
adb shell pm disable-user --user 0 com.tcl.bootad

:: 2. 瀑布流视频推荐流（显著降低内存占用）
adb shell pm disable-user --user 0 com.tcl.waterfall
```

---

### 3.4 创维 / 酷开电视 (Skyworth Coocaa OS)

创维酷开系统的广告与推广组件如下：

```cmd
:: 1. 核心广告服务与天赐系统推送
adb shell pm disable-user --user 0 com.coocaa.ad
adb shell pm disable-user --user 0 com.tianci.ad

:: 2. 电视购物与外围推广
adb shell pm disable-user --user 0 com.coocaa.mall
adb shell pm disable-user --user 0 com.coocaa.game
```

---

## 4. 状态核验与灾备恢复

### 4.1 检查已冻结列表
确认上述包名是否已成功变为停用状态：
```cmd
adb shell pm list packages -d
```
*输出列表中包含被冻结的包名，即表明其已被禁用，开机将不再加载。*

### 4.2 快速单项恢复（解冻）
若发现误伤了某个必要功能（如小爱同学联动或投屏），执行以下命令立刻解冻：
```cmd
adb shell pm enable <被冻结的包名>
```
*例如解冻小米升级服务：`adb shell pm enable com.xiaomi.mitv.upgrade`*

### 4.3 彻底卸载后的重新安装（灾备）
若此前误用了 `pm uninstall -k --user 0`，可通过下列命令重新装载系统内置 APK：
```cmd
adb shell cmd package install-existing <被卸载的包名>
```

### 4.4 硬件级终极自愈（兜底保证）
即使用户在操作中失误导致黑屏，由于 `--user 0` 仅作用于数据区，**只要在关机状态下长按遥控器的 `主页键 + 菜单键`（或电源键组合）进入 Recovery 模式，执行“恢复出厂设置（Wipe Data / Factory Reset）”，电视即可 100% 恢复初始状态**。

