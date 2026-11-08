# 电视核心应用一键更新与离线包归档方案设计规范

> **文档标识**：`doc/feat/01_app_auto_update_scheme.md`  
> **编制角色**：System Analyst (`/analyzer`)  
> **状态**：方案设计归档 (Pending Builder Implementation)  
> **面向宿主**：Windows 10/11 (PowerShell 5.1+ / Batch) + Android TV (ADB)

---

## 1. 方案背景与目标 (Background & Objectives)

### 1.1 现状与痛点
1. **多源维护繁琐**：电视端常用开源增强与轻量应用（如哔哩哔哩 TV 端开源客户端 **BT (bilibili TV)**、YouTube 去广告/Cobalt 核心客户端 **TizenTube Cobalt / SmartTube**、影视聚合播放器 **TVBox / FongMi**、电视极速直播 **mytv-android** 以及长辈友好型纯净桌面 **Emotn Launcher**）迭代频繁且分发源分散。
2. **国内网络受阻**：直接从原生 `github.com/.../releases/download/` 拉取 APK 经常遭遇 DNS 污染、TCP 连接重置或握手超时，导致下载失败或产生 0KB 损坏包。
3. **版本滞后与装机割裂**：每次更新需要用户在 PC 端网页翻找 Release、逐个点击下载、插拔 U 盘或手动输入 `adb install`，缺乏端到端的一键更新与版本基准追溯。

### 1.2 建设目标
- **单一真相源**：在本地 `apk/` 目录下建立结构化的应用归档库，保持各重要 TV 应用始终为最新稳定版。
- **双模开箱即用**：提供 Windows 下双击即跑的批处理入口（`.bat`）与高健壮性的后台解析引擎（`.ps1`），无需用户配置复杂 Python 环境。
- **智能镜像降级**：内置 GitHub API 直连 + 多节点反代镜像加速（如 `ghproxy.net` / `mirror.ghproxy.com`）自适应切换，彻底解决网络抖动。
- **无缝衔接 ADB 运维链**：与工作区现有的 `scripts/tv-connect.bat` 深度联动，支持“仅下载更新到本地”与“下载并一键推送到电视覆盖安装”两种操作模式。

---

## 2. 事实基准与应用清单矩阵 (Fact Grounding Matrix)

通过对开源电视生态与 GitHub Release 规范的检索查证，确定首批纳管的核心应用元数据基准如下：

| 应用简称 | 完整项目定位 | 权威分发渠道 / 仓库 | 发布资产 (Asset) 匹配规则 | 架构说明 | 依赖门禁 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **BT (bilibili TV)** | 哔哩哔哩 TV 原生遥控开源客户端 | `chinasoul/BT` *(备用: `swyefun/BBLLV5` / `cat3399/blbl`)* | `.*universal\.apk$` (排除 api19 兼容包) | 推荐 universal 通用架构 (ExoPlayer + Leanback，体积 ~3.3MB) | Android 5.1+ |
| **TizenTube** | YouTube TV Cobalt 核心去广告版 (或 SmartTube) | `reisxd/TizenTubeCobalt` *(备用: `yuliskov/SmartTube`)* | `.*(Cobalt\|universal).*\.apk$` | 适配 Android TV Cobalt 27 渲染 | Android 7.0+ |
| **TVBox** | 开源空壳点播/直播聚合播放器 (FongMi 内核) | `FongMi/Release` *(备用: `q215613905/TVBoxOSCRelease`)* | `.*(leanback\|java).*\.apk$` | 专为遥控器 D-Pad 交互定制 | Android 5.0+ |
| **mytv-android** | 极简电视直播 (IPTV) 客户端 | `mytv-android/mytv-android` | `.*mytv-android-tv.*(all\|arm64-v8a).*original.*\.apk$` | 专为遥控器切台优化，内置 Media3/IJK/VLC | Android 6.0+ |
| **Emotn Launcher** | 经典大图标长辈友好型纯净桌面 | 当贝分发源 *(主: `zmautoapp.dangsfly.com` / 原厂备用: `app.emotn.com`)* | `.*\.apk$` 或固定归档包 | 极简大图标、支持国内天气插件、老幼皆宜 | Android 4.4+ |

> [!NOTE]
> **技术事实说明**：  
> 1. **BT 与历史版本替代及轻量包特征**：原 `xiaye13579/BBLL` 已于 2025 年初停更且受 B 站官方 API 风控（返回 `-352`）严重影响；`cat3399/blbl` 虽发布至 v0.1.29 但已被作者设置为只读归档；当前生态首选用原生 Kotlin 开发的 `chinasoul/BT`，专为电视遥控器打造。需要特别注意：**BT 的 universal.apk 经过极致精简，物理体积约为 3.29 MB (3,370 KB)**，系统门禁设计不可机械设置 5MB 硬门槛，否则会诱发假阳性误删。  
> 2. **TizenTube Cobalt / SmartTube**：原生 TizenTube 运行于三星 Tizen 操作系统（`.wgt` 格式）。在 Android TV 生态中，由 `reisxd/TizenTubeCobalt` 承担 Cobalt 核心主选，`yuliskov/SmartTube` 作为稳定性备选。  
> 3. **TVBox 发布仓纠偏**：俊版原仓库 `q215613905/TVBoxOS` 仅维护源码无编译 Release，其实际 GitHub Actions 自动化编译发布仓库为 `q215613905/TVBoxOSCRelease`。  
> 4. **mytv-android 资产规则**：其实际 Release 资产命名前缀为 `mytv-android-tv-*-original.apk`，通过 `(all|arm64-v8a)` 模式精准匹配，严格排除 `disguised`（伪装包）与 `x5offline`（过大离线包）。  
> 5. **Emotn Launcher 官方源失效与镜像替代**：属于闭源免费桌面软件（无开放 GitHub Releases API），其原厂门户 `app.emotn.com/download/app` 现已返回 404，且 `cdn.emotn.com` 域名已下线。为确保无人值守自动化闭环，必须在配置中将分发源重定向至高可用静态 CDN 镜像（如当贝分发节点 `zmautoapp.dangsfly.com/...`），由下载引擎自适应支持直接 URL 流式下载与体积校验，与 GitHub Releases 应用统一纳管。

---

## 3. 总体架构与数据流模型 (System Architecture & Data Flow)

### 3.1 模块分层架构

```mermaid
flowchart TD
    subgraph UI ["用户交互与调度层 (Orchestration)"]
        BAT["update-apps.bat\n(双击入口 / 终端交互菜单)"]
    end

    subgraph Core ["PowerShell 核心处理引擎 (scripts/update-apps.ps1)"]
        Config["应用元数据契约\n(manifest.json / 内存 HashTable)"]
        API["GitHub Release 探测器\n(REST API v3 / Redirect Sniffer)"]
        Mirror["镜像自适应路由\n(Direct / GHProxy Fallback)"]
        Downloader["分块断点下载器\n(SHA/Size 校验 & 0KB 拦截)"]
        Storage["本地包管理器\n(存储至 apk/ 规范命名)"]
    end

    subgraph Host ["本地物理存储 (Local File System)"]
        APK_DIR["apk/\n- BT-latest.apk\n- TizenTube-latest.apk\n- TVBox-latest.apk\n- mytv-latest.apk\n- EmotnLauncher-latest.apk\n- manifest.cache.json"]
    end

    subgraph ADB ["下发执行层 (Deployment Integration)"]
        TV["Android TV 目标设备\n(adb install -r -d)"]
    end

    BAT -->|参数透传 / 绕过策略| Core
    Config --> API
    API --> Mirror
    Mirror --> Downloader
    Downloader --> Storage
    Storage --> APK_DIR
    Storage -.->|可选: 一键推送到电视| ADB
    ADB --> TV
```

### 3.2 核心更新控制流程

```mermaid
sequenceDiagram
    autonumber
    participant U as 用户 (User)
    participant B as update-apps.bat
    participant P as update-apps.ps1
    participant G as GitHub API / 镜像节点
    participant F as 本地 apk/ 目录
    participant T as 电视 (ADB Device)

    U->>B: 双击运行或命令行调用
    B->>P: 调用 powershell -ExecutionPolicy Bypass
    P->>F: 读取本地缓存元数据 (manifest.cache.json)
    loop 遍历目标应用 (BT, TizenTube, TVBox, mytv, Emotn)
        P->>G: 请求 repos/{owner}/{repo}/releases/latest
        alt API 请求成功
            G-->>P: 返回最新 Release JSON (Tag, Assets)
        else 遭遇限流或超时
            P->>G: 切换至备选镜像反代/重定向探测
            G-->>P: 获取最新资产直链
        end
        P->>P: 比较本地已有版本 Tag
        alt 本地已是最新且文件完整
            P-->>B: 跳过下载，报告已最新
        else 发现新版本或文件缺失
            P->>G: 流式下载 APK (带进度条)
            P->>F: 写入 apk/<App>-<Version>.apk 并建立/更新 <App>-latest.apk
            P->>F: 更新 manifest.cache.json
        end
    end
    alt 用户选择“更新后推送到电视”
        P->>T: 执行 adb install -r -d apk/<App>-latest.apk
        T-->>P: 返回 Success
    end
    P-->>B: 打印更新汇报看板
    B-->>U: 执行完毕，按任意键退出
```

---

## 4. 脚本编制方案与核心技术设计 (Script Engineering Specification)

### 4.1 技术栈选型决策

| 维度 | 方案 A: 纯批处理 (`.bat` + `curl.exe`) | 方案 B: `PowerShell` 引擎 + `.bat` 门面 (推荐) | 方案 C: `Python` 脚本 (`requests`) |
| :--- | :--- | :--- | :--- |
| **运行时依赖** | 依赖 Win10+ 自带 curl，解析复杂 JSON 极其脆弱 | **零外部依赖**，Windows 7+ 均预装 PowerShell 5.1+ | 需用户额外安装 Python 及三方库，门槛高 |
| **JSON 处理** | 必须借助复杂 `findstr` 或临时 VBScript | 原生 `ConvertFrom-Json`，强类型字典操作 | 极佳 |
| **网络鲁棒性** | 缺乏细粒度 TLS 与 Header 控制 | 原生支持 TLS 1.2/1.3、自定义 User-Agent 与超时熔断 | 极佳 |
| **用户体验** | 纯命令行黑框，进度显示原始 | 原生 `Write-Progress` 友好进度条，色彩分级明确 | 依赖终端库 |

**决策结论**：采用 **方案 B**。对外提供统一的 `scripts/update-apps.bat`，内部通过 `PowerShell.exe -ExecutionPolicy Bypass -File update-apps.ps1` 调度主逻辑，兼顾免安装便利性与生产级脚本健壮性。

### 4.2 模块架构与文件布局规划

拟在工程中落地的文件清单与职责划分：

```text
androidTV/
├── apk/                             # APK 归档目标目录
│   ├── BT-latest.apk                # 符号链接或标准化重命名副本
│   ├── TizenTube-latest.apk
│   ├── TVBox-latest.apk
│   ├── mytv-latest.apk
│   ├── EmotnLauncher-latest.apk
│   └── .manifest.cache.json         # 记录各组件当前已下载版本与哈希
├── doc/
│   └── feat/
│       └── 01_app_auto_update_scheme.md   # 本设计方案规范
└── scripts/
    ├── update-apps.bat              # [新增] 双击运行的入口批处理
    ├── update-apps.ps1              # [新增] 核心下载与版本比对引擎
    └── modules/
        └── AppRegistry.psd1         # [新增/内嵌] 应用元数据源定义
```

### 4.3 核心逻辑关键算法设计

#### 1. 网络镜像与反代降级策略
为了防御 GitHub API 频率限制（未认证 IP 每小时仅 60 次）以及国内下载阻断，下载引擎采用三级容灾矩阵：
- **Primary**：`https://api.github.com/repos/{owner}/{repo}/releases/latest`（官方标准）
- **Mirror List**：
  - `https://ghproxy.net/https://github.com/{owner}/{repo}/releases/download/...`
  - `https://mirror.ghproxy.com/https://github.com/{owner}/{repo}/releases/download/...`
  - `https://kkgithub.com/...`
- **Fallback 机制**：下载采用 HTTP 探针，若返回码非 200 或握手超时（>8s），自动顺延至下一镜像重试，最多重试 3 次。

#### 2. 包完整性与轻量包兼容门禁
在下载完成进入 `apk/` 目录前，必须通过以下硬门禁：
1. **HTTP Status Code** 严格等于 200。
2. **物理文件体积门禁**：全局基础门禁设为 $\ge 2\,\text{MB}$（默认 2,097,152 字节），拦截反代劫持 HTML 报错页（通常 $< 100\,\text{KB}$）或 0KB 断流坏包；同时支持单应用在清单中配置个性化阈值，杜绝 3.29MB 极简包被误判。
3. **原子性写入**：先下载至 `apk/.tmp_<name>.apk`，全量校验通过后原子重命名至目标路径。

#### 3. 与现有 ADB 工具链协同 (Optional Pipeline)
下载完成后，脚本探测当前是否存在已连接的 ADB 电视设备：
- 若存在已授权的设备（`adb get-state` 返回 `device`），提供一键覆写安装选项：
  ```cmd
  adb install -r -d -g apk/BT-latest.apk
  ```
  （`-r` 保留数据替换，`-d` 允许降级覆盖，`-g` 授予运行时所有默认权限）

### 4.4 异常源自愈与细粒度门禁适配规范 (方案 A: 全自动修复机制)

在实机演练排障中，部分应用可能出现下载阻断现象。通过白盒证伪与根因追溯，系统确立**方案 A（配置级全自动自愈）**作为核心演化标准，彻底替代繁琐的手动下载与人工文件搬运：

#### 1. BT 应用 3.29MB 假阳性误杀治理
- **根因分析**：GitHub Release 的 `BT-v0.9.42-universal.apk` 物理体积为 3,370.91 KB（约 3.29 MB）。若引擎硬编码 5MB 门禁，将触发防御性删除逻辑，陷入“重复下载成功却判定失败”的假阳性死循环；且若用户手动放入文件，亦会因本地大小校验不通过而反复触发联网覆盖。
- **治理标准**：将全局 `MinApkSizeBytes` 阈值调谐至 `2097152`（2MB），既能可靠阻断文本型 404/反代报错页（几 KB 至几十 KB），又能无损放行轻量级极简 TV 客户端。

#### 2. Emotn Launcher 官方源失效与镜像重定向
- **根因分析**：Emotn 原厂直链 `https://app.emotn.com/download/app` 报 404，备选源 `cdn.emotn.com` 域名已下线。
- **治理标准**：将 `AppRegistry.psd1` 的分发源平滑替换为经过验证的当贝 CDN 分发节点（`https://zmautoapp.dangsfly.com/20260711/6a51fff5b0db3.apke8f2.apk`），保留原厂域名为备选，确保无人值守更新流水线全绿通畅。

#### 3. `AppRegistry.psd1` 契约配置更新示例
```powershell
# scripts/modules/AppRegistry.psd1
@{
    Apps = @(
        # 1. 哔哩哔哩 TV 端 (放宽门禁后原生全自动拉取)
        @{
            Id          = 'BT'
            Name        = 'Bilibili TV (BT)'
            Type        = 'github'
            Repo        = 'chinasoul/BT'
            FallbackRepo= 'swyefun/BBLLV5'
            AssetFilter = '.*universal\.apk$'
            Exclude     = '.*api19.*'
            TargetFile  = 'BT-latest.apk'
            Description = '哔哩哔哩 TV 原生遥控开源客户端'
        },
        # ... 省略 TizenTube / TVBox / mytv ...
        # 5. Emotn 桌面 (切入高可用 CDN 镜像源)
        @{
            Id          = 'EmotnLauncher'
            Name        = 'Emotn Launcher'
            Type        = 'direct'
            Url         = 'https://zmautoapp.dangsfly.com/20260711/6a51fff5b0db3.apke8f2.apk'
            FallbackUrls= @(
                'https://app.emotn.com/download/app'
            )
            TargetFile  = 'EmotnLauncher-latest.apk'
            Description = '长辈友好型纯净电视桌面'
        }
    )
    Mirrors = @(
        'https://ghproxy.net/',
        'https://mirror.ghproxy.com/',
        'https://kkgithub.com/'
    )
    MinApkSizeBytes = 2097152 # 统一放宽至 2MB，完美兼容 BT 3.29MB 安装包
}
```

---

## 5. 实施路线图与 WBS (Work Breakdown Structure)

本方案经评审批准后，将分阶段移交 `/builder` 开展代码实施：

- [ ] **Phase 1: 基础设施与应用清单契约配置**
  - 在 `scripts/` 中规范化配置应用元数据（包含 GitHub Repo、Asset 正则表达式、架构要求）。
  - 创建并确保 `apk/` 目录权限及 `.gitignore` 规则（忽略大型 `.apk`，保留 `.gitkeep`）。
- [ ] **Phase 2: 核心下载与版本调度引擎 (`scripts/update-apps.ps1`)**
  - 实现 TLS 1.2 强制协商与 GitHub API 资产解析逻辑。
  - 实现镜像加速链轮询器与断点重试下载逻辑。
  - 实现体积门禁与 `apk/` 归档版本持久化（`.manifest.cache.json`）。
- [ ] **Phase 3: 双击交互批处理外壳 (`scripts/update-apps.bat`)**
  - 编写编码与环境初始化脚本（`chcp 65001`）。
  - 实现参数转发与模式选择（1. 仅下载最新 APK；2. 下载并一键安装到电视；3. 检查更新状态）。
- [ ] **Phase 4: 全流程联调与白盒验收**
  - 在真实 Windows 终端下运行测试，验证国内网络下的镜像下载成功率。
  - 接入 ADB 电视环境，验证应用静默覆盖升级能力。

---

## 6. 质量门禁与验收标准 (Acceptance Criteria)

1. **执行零报错门禁**：在无第三方环境污染的裸机 Windows 10/11 环境下，双击 `scripts/update-apps.bat` 能够无障碍启动并正确捕获各应用最新 Release。
2. **下载准确性门禁**：`apk/` 目录下成功生成各应用的最新安装包，无 0KB 坏包，APK 解包签名结构有效。
3. **网络自愈容错率**：人为模拟原生 GitHub API 超时时，脚本能够自动切入加速镜像节点并顺利拉取安装包。
4. **架构合规**：不篡改 `scripts/` 已有脚本功能，严格遵循项目现有命令规范与 UTF-8 编码约束。

