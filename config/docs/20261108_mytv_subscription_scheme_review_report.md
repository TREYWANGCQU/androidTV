# mytv-android 专属自选订阅源方案架构评审报告

> **报告标识**：`config/docs/20261108_mytv_subscription_scheme_review_report.md`  
> **评审对象**：`doc/feat/02_mytv_subscription_scheme.md`  
> **评审角色**：Quality Gate Reviewer (`/reviewer`)  
> **评审时间**：2026-11-08  
> **前置约束变更**：网络环境因 DNS 及透明代理考量**仅开通 IPv4**，并在家庭透明网关实施 **IPv4 级透明分流**。

---

## 1. 评审执行摘要 (Executive Summary)

针对系统分析师提交的《mytv-android 专属自选订阅源与透明分流架构方案设计规范》（`doc/feat/02_mytv_subscription_scheme.md`），本门禁聚焦于用户最新明确的底层网络约束——**“仅开通 IPv4，并实施 IPv4 网关级分流”**。

经多维度审查发现，当前方案在需求对齐与底层架构网络契约上存在 **L2 级架构/逻辑层偏差（严重阻塞性缺陷）**：原方案深度依赖并硬编码了国内运营商“IPv6 直连单播专线”假设，在拓扑图、分流判定矩阵、编译过滤规范以及 M3U/TXT 示例产物中均包含 IPv6 字面量地址。在仅启用 IPv4 的局域网环境下，该方案将直接导致电视端播放大面积死链、超时及黑屏。根据 Reviewer 契约，L2 级缺陷严禁 Reviewer 原地越权擅改，必须判定为 **FAIL** 并阻断合并，下发整改工单交由 `/builder` 进行重构。

---

## 2. 门禁终审结论 (FINAL_STATUS)

**`FAIL`** (阻断合并，需针对 IPv4 纯净网络契约进行重构)

---

## 3. 持久化元数据 (PERSISTENCE_METADATA)

- **Report File**: `d:/offices/Github/AI-automation/See/androidTV/config/docs/20261108_mytv_subscription_scheme_review_report.md`
- **Reviewed Document**: `d:/offices/Github/AI-automation/See/androidTV/doc/feat/02_mytv_subscription_scheme.md`
- **Defect Level Distribution**: L0: 2 项, L1: 1 项, L2: 3 项, L3: 0 项

---

## 4. 关键缺陷与事实偏离发现 (FINDINGS)

### 4.1 [L2 架构/网络协议层] IPv6 核心依赖与 IPv4-Only 物理网络约束严重冲突
- **归因标签**：`[N/A]`（核心架构输入与业务场景约束变更）
- **事实证据**：
  - 方案第 1.1 节（第 17 行）声称：“国内频道依赖 IPv6 高带宽，必须物理直连”；
  - 方案第 2.2 节（第 61、74 行）分流判定矩阵将“所有原生 IPv6 流量强制直连”作为核心规则；
  - 方案第 4.3 节（第 251、261 行）给出的央视主力源产物示例直接硬编码了 IPv6 字面量地址：`http://[2409:8087:...]/live/cctv1.m3u8`。
- **影响评估**：在电视端与透明网关不分配/禁用 IPv6 的环境下，Android TV 无法解析或路由该段地址，会导致 `ENETUNREACH`（网络不可达）与长期重试卡死，核心国内基本盘直接失效。

### 4.2 [L2 逻辑/编译流水线层] 编译探活引擎缺少 IPv4 强制约束与 AAAA/IPv6 过滤门禁
- **归因标签**：`[Requires /researcher]`（需验证上游纯 IPv4 源池与 aiohttp 强制 IPv4 探测机制）
- **事实证据**：方案第 4.2 节定义的 `iptv_compiler.py` 探活流程仅校验 HTTP 200 与 TTFB，未对 URL 的 Host 协议族进行过滤。若 GitHub Actions 执行机具备双栈网络，拉取并探活通过的 IPv6 优质流被排在前列，推送到电视端将全部变为死链。
- **整改要求**：编译流水线必须在清洗阶段剔除所有正则匹配为 IPv6 字面量（如 `\[[0-9a-fA-F:]+\]`）的链接，并在 `aiohttp.TCPConnector` 中强制声明 `family=socket.AF_INET`，确保探活环境与电视端 IPv4 单栈物理环境 100% 同构。

### 4.3 [L2 架构/DNS分流层] 缺失 IPv4 单栈透明网关下的 DNS 策略与防污染闭环
- **归因标签**：`[Requires /researcher]`（需明确 Clash Meta / Sing-box 在 Fake-IP 模式下的 IPv4 分流拓扑）
- **事实证据**：用户之所以“因 DNS 之类考量仅开通 IPv4”，核心痛点在于双栈环境下 IPv6 AAAA 查询往往绕过透明网关 DNS 防火墙，导致 CDN 调度混乱、DNS 污染或泄露。原文档第 2.2 节未对纯 IPv4 网关级 DNS 调度机制（如 Fake-IP 池、Domestic DNS 分流解析、海外域名远端解析）做出清晰的技术约束。

### 4.4 [L1 浅层一致性] 上游源池（Upstream Pool）未区隔 IPv4 专属资源
- **归因标签**：`[Requires /collector]`（需盘点并锁定稳定可用的 IPv4 央视/卫视 CDN 列表）
- **事实证据**：第 3.1 节引用了 `FanMingMing IPv6/IPv4`。在公网环境中，FanMingMing 主仓库以 IPv6 运营商内网切片为主，IPv4 资源多为 CDN 源。若未明确声明指定 IPv4 分支或备用源，会导致候选可用源匮乏。

### 4.5 [L0 规范层] 代码示例块文件路径注释与语法微瑕
- **事实证据**：
  - 第 4.1 节 JSON 代码块包含 `//` 注释，部分非宽松 JSON 解析器会报错；
  - 第 4.3 节产物示例未严格遵循 `File Path Rule` 规范（缺少文件相对路径顶行注释）。

---

## 5. 自动修复记录 (AUTO_REMEDIATION_LOG)

> 依据 Reviewer 准则，因本案存在 **L2 级架构与网络协议层阻塞缺陷**，严禁 Reviewer 越权原地篡改架构逻辑。本次审查无就地修复操作，全部整改项交由工单分流闭环。

---

## 6. 整改工单与执行清单 (REQUIRED_ACTIONS)

请调度工程实施中枢 `/builder` 按照以下清单对 `doc/feat/02_mytv_subscription_scheme.md` 进行针对性重构：

- [ ] **Action 1 (架构与拓扑重构 - IPv4 单栈对齐)**：
  - 全面剔除文档中所有“IPv6 单播专线”、“IPv6 高码率”以及 `[2409:...]` 的描述与示例；
  - 重绘第 2.2 节网络拓扑图与分流矩阵，以 **IPv4 Transparent Gateway (Clash Meta / Sing-box)** 为基准：
    - **国内直连 (DIRECT)**：`GEOSITE:CN`、`GEOIP:CN` (IPv4 chnroute)、国内 CDN 域名（央视频/咪咕/各省广电）；
    - **国际代理 (PROXY)**：非 CN 域名及境外 IPv4 流量（TVB/凤凰/海外流媒体）；
    - **DNS 规避污染设计**：明确在网关层采用 Fake-IP (IPv4) 或分流 DNS，关闭 AAAA 解析，避免双栈 DNS 泄露与解析延迟。
- [ ] **Action 2 (编译引擎契约适配 - 纯 IPv4 探活与过滤)** `[Requires /researcher]`:
  - 在第 4.2 节编译引擎逻辑中，明确增加 **IPv4 过滤门禁**：
    1. 正则丢弃包含 IPv6 格式的主机地址；
    2. Socket 强制使用 `AF_INET` 进行探活与测速；
    3. 异常降级时严禁回退包含 IPv6 的历史缓存。
- [ ] **Action 3 (上游源池调优与事实校准)** `[Requires /collector]`:
  - 更新第 3.1 节上游源清单，将引用源调整为可靠的纯 IPv4 源库（例如 FanMingMing 的 IPv4 CDN 分支、咪咕官方 CDN IPv4 直链池、YanG 纯 IPv4 聚合库）。
- [ ] **Action 4 (输出产物与规范修复)**:
  - 修正第 4.3 节 M3U 与 TXT 的示例产物，全部替换为标准 IPv4 FQDN 或 IPv4 地址；
  - 补齐符合规范的文件头相对路径注释。

---

## 7. 合并决策 (MERGE_DECISION)

- **决策结果**：**BLOCKED (阻断)**
- **后续指引**：
  方案在未对齐 IPv4 物理约束前不得进入编码阶段。建议用户指令 `/builder` 执行上述 `REQUIRED_ACTIONS` 进行方案修订，修订完成后重新触发 `/reviewer` 执行门禁复核。

