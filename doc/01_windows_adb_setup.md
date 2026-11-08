# 01. Windows ADB 调试环境搭建手册

本篇详细介绍如何在 Windows 10/11 上快速配置 Android 调试桥（ADB, Android Debug Bridge），并与局域网内的智能电视建立可靠的无线调试连接。

---

## 1. Windows 端 ADB 工具链部署

在 Windows 上配置 ADB 推荐采用以下两种途径之一：

### 途径 A：使用 Windows 自带包管理器 Winget（最快捷）

Windows 10 (1809+) 及 Windows 11 已内置 `winget`。在 Windows Terminal、PowerShell 或 CMD 中执行：

```powershell
# 安装 Google 官方 Platform-Tools
winget install Google.PlatformTools --source winget
```

安装完成后，关闭当前终端并重新打开，执行下述命令验证：

```powershell
adb version
```
*正常输出示例：`Android Debug Bridge version 1.0.41 ... Installed as ...\platform-tools\adb.exe`*

### 途径 B：官方离线绿色包手动配置

1. **下载官方工具包**：
   访问 Google Android 官方下载页获取最新 Platform-Tools：
   - 官方直链：`https://dl.google.com/android/repository/platform-tools-latest-windows.zip`
2. **解压至固定路径**：
   例如解压至 `C:\platform-tools`（确保解压后存在 `C:\platform-tools\adb.exe`）。
3. **配置系统环境变量 PATH**：
   - 按快捷键 `Win + R`，输入 `sysdm.cpl`，回车打开“系统属性”。
   - 切换至 **“高级”** 选项卡 -> 点击 **“环境变量”**。
   - 在“系统变量”或“用户变量”中找到 `Path`，选中并点击 **“编辑”**。
   - 点击 **“新建”**，填入 `C:\platform-tools`，点击确定保存所有窗口。
4. **验证可用性**：
   打开全新的 CMD 或 PowerShell 窗口，执行：
   ```cmd
   adb version
   ```

---

## 2. Android TV 端激活网络调试

为了通过局域网连接电视，必须先在电视上激活开发者选项与调试开关。

### 步骤 1：激活开发者选项（Developer Options）
1. 打开电视的系统 **“设置”** (Settings)。
2. 进入 **“关于”** (About) 或 **“系统信息”**。
3. 找到 **“软件版本号”** / **“内部版本号”** (Build Number)。
4. 连续按遥控器 **确定键（OK）5 ~ 7 次**，直到屏幕底部弹出提示：*“您现在处于开发者模式！”*。

### 步骤 2：开启调试开关
1. 返回设置主界面，进入新出现的 **“开发者选项”**（部分系统位于“系统设置” -> “更多设置”中）。
2. 将 **“USB 调试”** (USB Debugging) 设置为 **开启**。
3. 若系统具备 **“网络调试”** (Network Debugging) 或 **“无线调试”** 选项，一并设为 **开启**。

> [!NOTE]
> **部分品牌特殊路径**：
> - **小米/红米 (MIUI TV / PatchWall)**：设置 -> 关于 -> 产品型号 连续按确定键，随后进入“账号与安全” -> “ADB调试”选择开启。
> - **TCL / 雷鸟**：系统设置 -> 系统信息 -> 快速连续按遥控器红绿蓝黄或按“上下左右确定”，可调出工厂菜单开启 ADB。
> - **海信 (VIDAA)**：设置 -> 系统 -> 通用设置 -> 商场模式开启后可能开放端口，或在声音平衡处连按调出工厂设置开启调试。

### 步骤 3：获取电视局域网 IP
- 在电视“网络设置”中查看当前连接的 Wi-Fi 或有线网详情。
- 记录电视的 IP 地址，例如 `192.168.1.105`。
- **推荐策略**：在家庭路由器后台将电视的 MAC 地址绑定为静态 IP（DHCP 静态保留），避免每次电视开机 IP 发生变化。

---

## 3. 局域网建立 ADB 连接与授权

确保 Windows 电脑与 Android TV 连接在**同一路由器**（同一局域网网段）下。

### 步骤 1：发起连接请求
在 Windows 终端中运行：

```cmd
# 默认端口一般为 5555
adb connect 192.168.1.105:5555
```

### 步骤 2：在电视上确认 RSA 密钥授权
首次连接时，电视屏幕中央会弹出授权请求弹窗：
> **允许网络调试吗？**
> 该计算机的 RSA 密钥指纹是：`XX:XX:XX:XX...`
> **[√] 始终允许来自此计算机的调试**
> [ 取消 ]   [ **允许** ]

**务必使用遥控器勾选“始终允许来自此计算机”，然后点击“允许”**。

### 步骤 3：验证设备状态
在电脑端终端中执行：

```cmd
adb devices
```

**健康状态输出**：
```text
List of devices attached
192.168.1.105:5555    device
```
*状态显示为 `device` 即代表握手成功，可以执行管理命令。*

---

## 4. 常见连接故障排错字典 (Troubleshooting)

| 异常现象 | 核心根因分析 | 针对性解决对策 |
| :--- | :--- | :--- |
| **`device offline`** | ADB Server 握手协议卡死，或电视网络休眠 | 1. 执行 `adb kill-server && adb start-server`<br>2. 电视端关闭再重新开启“USB调试”<br>3. 唤醒电视屏幕后重新执行 `adb connect` |
| **`device unauthorized`** | 电视端尚未弹出或未点击“允许调试”弹窗 | 1. 检查电视屏幕是否被其他全屏视频层遮挡<br>2. 在电脑执行 `adb kill-server`<br>3. 删除电脑端 `%USERPROFILE%\.android\adbkey*` 重新触发电视弹窗 |
| **`connection refused` / `cannot connect`** | 1. 电视端 5555 调试端口未开放<br>2. 路由器开启了 AP 隔离 (Client Isolation) | 1. 确认电视与电脑是否连接在同一 Wi-Fi，关闭路由器的“访客网络/AP隔离”<br>2. 若支持 USB 双公头线，先使用 USB 连接电视执行 `adb tcpip 5555`，再拔线使用网络连接 |
| **Android 11+ 配对失败** | 现代 Android TV 强制启用动态配对码机制 | 1. 电视进入“无线调试” -> “使用配对码配对设备”<br>2. 电脑执行 `adb pair <tv-ip>:<配对端口>` 并输入6位数字<br>3. 配对成功后执行 `adb connect <tv-ip>:<连接端口>` |

