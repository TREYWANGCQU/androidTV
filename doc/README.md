# Android TV 自定义与净化工程指南

> 本指南专为国内主流 Android TV 及智能机顶盒（小米/红米、海信、TCL、创维等）定制，提供免 Root 环境下的 ADB 调试配置、开机与内置广告冻结、第三方优质桌面评测及防踢接管方案。

---

## 目录索引

- [01. Windows ADB 调试环境搭建](file:///d:/offices/Github/AI-automation/See/androidTV/doc/01_windows_adb_setup.md)
  - 了解 ADB 工具链安装（Winget 与官方免安装包）
  - TV 开发者选项与网络调试激活
  - 局域网无线配对与常见连接状态排错（offline/unauthorized）
- [02. 免 Root 广告应用消杀与系统瘦身](file:///d:/offices/Github/AI-automation/See/androidTV/doc/02_ad_debloat_guide.md)
  - 冻结机制对比（`pm disable-user` vs `pm uninstall -k`）
  - 系统防砖白名单（严禁触碰的核心组件）
  - 小米、海信、TCL、创维靶向包名清单
  - 单应用与灾备恢复命令
- [03. 第三方桌面全景选型与防踢接管](file:///d:/offices/Github/AI-automation/See/androidTV/doc/03_third_party_launchers.md)
  - 2026 主流 TV 桌面深度横评（Projectivy Launcher、Emotn UI、FLauncher、ATV Launcher）
  - 国产 ROM 防篡改机制解析（锁死默认桌面、按 Home 键反弹）
  - 三级接管方案：原生设置 -> 冻结默认 -> 无障碍服务（Accessibility）劫持
- [04. 自动化批处理与工具化运维](file:///d:/offices/Github/AI-automation/See/androidTV/doc/04_automation_scripts.md)
  - Windows 一键连接脚本 (`tv-connect.bat`)
  - 分品牌一键消杀脚本 (`tv-debloat.bat`)
  - 一键灾备恢复脚本 (`tv-restore.bat`)

---

## 核心设计原则与安全红线

> [!CAUTION]
> **安全防砖红线（绝对不可修改的系统基准）**
> 1. **严禁冻结/卸载输入法**：一旦移除且未安装备用输入法，涉及文字输入或 Wi-Fi 密码变更时将引发界面崩溃死锁。
> 2. **严禁触碰蓝牙/遥控守护服务**：蓝牙语音遥控器依赖 `com.android.bluetooth` 与专用外设配对进程，误删将导致红外/蓝牙遥控器失联。
> 3. **严禁冻结核心系统框架与包管理**：`android` (framework-res)、`com.android.systemui`、`com.android.settings`、`com.android.packageinstaller` 一旦损坏，将导致开机循环卡 Logo。

### 操作策略倡议

```
[原则 1: 用户级冻结优先]
优先使用 `pm disable-user --user 0 <pkg>`，该命令仅停用组件，保留 apk 文件与系统签名完整性。
不破坏系统分区只读哈希，支持 OTA 升级前一键恢复。

[原则 2: 渐进式验证]
每次执行 1~2 个包名停用后，重启电视或按遥控器测试核心功能（网络、音频、遥控、信号源切换），
确认无异常后再执行后续包名。

[原则 3: 桌面防踢保底]
对于深度绑定默认桌面的机型，优先采用 Projectivy Launcher 的“无障碍服务劫持”策略，
不硬删原厂桌面，以零风险实现通电即入第三方桌面。
```

