# AGENTS.md — MyBattery 智能体接手指南与核心知识库

> 欢迎来到 **MyBattery** 项目。本文档专为接手本项目的 AI 编码助手（Codex、Claude Code、Antigravity 等）及协作者编写。
> **在执行任何代码修改、重构或功能演进前，必须完整阅读并严格遵守本文档所列出的核心红线与设计准则。**

---

## 1. 项目定位与背景 (Identity & Context)

* **项目名称**：MyBattery
* **仓库地址**：`https://github.com/timberdai/MyBattery`
* **主分支**：`main`
* **当前版本**：`0.1.0`（MyBattery 独立版本）
* **作者**：timberdai (`timberdai@outlook.com`)
* **技术栈**：Swift 5.9+ / macOS 13.0+ / AppKit / IOKit / CoreGraphics / SMC (随附 `Vendor/StatusItemKit`，无外部网络 SPM 包)

---

## 2. 用户绝对红线与产品设计铁律 (Strict Red Lines)

在为此项目编写或审查代码时，**必须无条件遵循以下不可触碰的红线**：

1. 🛑 **严禁撑宽面板（面板宽度严格保持在 ~176 pt 左右）**：
   * 用户极其喜爱当前精致紧凑的超窄面板；
   * 所有文本、标签、行视图的宽度必须在 176 pt 限制内完美布局，严禁出现由于文本过长导致的横向被撑宽、换行错位或右侧截断。
2. 🛑 **纯展示数据行绝不允许鼠标 Hover 蓝色高亮**：
   * 所有电池数据行（电量、供电状态、功率、时间、健康、循环、容量、温度、风扇等，包括冷启动占位行）必须使用 `ReadOnlyRowView` 纯自绘；
   * 严禁直接使用原生 `NSMenuItem(title: ...)` 承载数据行，鼠标滑过绝不能变成可点击选中的蓝色长条。
3. 🛑 **彻底杜绝电压（`V`）参数展示**：
   * 严禁在 UI 界面出现 `12.4 V`、`20.0 V / 4.5 A` 等电压相关字段，用户只关心瓦数（`W`）、电量（`%` / `mAh`）与温度（`°C`）。
4. 🛑 **严禁加入大卡片、拓扑图、折叠栏或表情**：
   * 用户坚决反对臃肿的花哨功能（如大圆环进度条、三端电能拓扑图、Emoji 表情卡片、折叠二级菜单等）；
   * 保持纯粹、扁平、一目了然的原生 macOS 菜单设计。
5. 🛑 **其他未提及部分严禁擅自改动**：
   * 状态栏微型电池图标绘制、登录启动逻辑、系统设置跳转、退出等既有功能保持原有逻辑，改动需最小化与高内聚。

---

## 3. 关键架构与核心技术决策 (Architecture & ADRs)

### 3.1 官方权威电池健康度校准 (Official Battery Health Alignment)
* **原理**：此前通过瞬时物理容量计算 `rawMax * 100 / design` 时，因电芯物理读数微小波动会导致 `99%` 的显示偏差；
* **决策**：优先读取 `IORegBattery.officialMaxCapacity`（来自底层 BMS 权威校验键值 `"MaxCapacity"`，限制在 1...100% 合理区间），采用系统提供的健康百分比；获取不到或异常时降级回退到容量除法，不预测剩余寿命。

### 3.2 80% 充电保护与旁路供电识别 (Bypass Power Detection)
* **原理**：在常年插电且保持 80% 限制时，macOS 启用硬件旁路供电（电池电流归零）；
* **识别依据**：`NotChargingReason == 16777216` 或 `plugged && !isCharging && percent == 80`；
* **展示**：明确显示为 `外接供电 (旁路)`，实时功率展示真实整机输入功率（`SystemPowerIn`），杜绝硬编码 0.0 W。

### 3.3 免 root 硬件温度与散热风扇 (SMCFansReader)
* **实现**：`SMCFansReader.swift` 通过 IOKit 与 `AppleSMC` 建立用户态连接；
* **风扇**：只使用查询键信息 `9` 与读取字节 `5`，拒绝写命令；校验 `FNum` 的 `ui8 ` 类型/长度与 0...10 个十进制键边界，通过 `fpe2` 大端定点 / `flt ` 小端浮点准确解码；读取在后台轮询，菜单使用缓存。转速小于 50 RPM 时展示为 `停转 (静音)`；若机型无风扇（如 MacBook Air）则整行自适应隐藏；
* **温度**：优先从 ioreg 的 BatteryData/顶层 Temperature 读取，缺数时只读 SMC 电池传感器 TB0T（flt 小端或 sp78 大端），显示 `电池温度: XX.X °C`；缺传感器隐藏，不用其他硬件温度冒充。

### 3.4 纯原生插电呼吸光晕特效 (PlugInGlowController)
* **动效机制**：电源从断开变为连接瞬间，在所有屏幕四周边缘弹出无边框、无阴影、穿透鼠标事件的浮动全屏窗口（`level = .screenSaver`）；
* **纯原生渲染**：采用 CoreGraphics 绘制多重半透明发光圆角矩形，CoreAnimation 淡入淡出，零外部宏依赖，动效完成后彻底销毁窗口；
* **勾选开关与主线程隔离**：在菜单面板设置区域提供与“登录时启动”一致的原生勾选项 `插电特效`（英文 Plug-in Glow），勾选代表启用，取消勾选立即取消正在播放的光效，启用时预览一次，访问 shared、初始化、开关与触发必须在主线程，关闭同步清理；析构若发生在后台，则把保留的窗口交给主线程关闭。监听屏幕参数变化、应用退出及 NSWorkspace 休眠通知，清理当前窗口。

---

## 4. 模块文件代码地图 (Codebase Map)

```text
MyBattery/
├── Package.swift                             # SPM 清单 (依赖 Vendor/StatusItemKit, 模块 BatteryTimeCore)
├── Vendor/StatusItemKit/                    # 随附只读库源码、来源与 MPL-2.0
├── Sources/
│   ├── MyBattery/
│   │   ├── main.swift                        # 应用入口、NSMenu 组装、轮询与 UI 控件
│   │   ├── PlugInGlowController.swift        # 插电全屏边缘呼吸霓虹光效控制器
│   │   ├── SMCFansReader.swift               # 免 root AppleSMC 风扇转速读取器
│   │   ├── BatteryGlyph.swift                # 状态栏胶囊图标 CoreGraphics 渲染
│   │   ├── DisplayPrefs.swift                # UserDefaults 显示偏好配置
│   │   └── PowerSourceWatcher.swift          # IOKit 电源插拔事件监听
│   └── BatteryTimeCore/
│       ├── IORegBattery.swift                # ioreg 属性解析器 (MaxCapacity / SystemPowerIn)
│       ├── BatteryMath.swift                 # 电池时间、百分比与单位换算
│       └── Usage24h.swift                    # 24小时使用统计日志解析
├── scripts/
│   ├── build-app.sh                          # 生产包打包脚本
│   └── dev-reload.sh                         # 本地增量编译、签名与热重载脚本
├── Resources/
│   ├── Info.plist                            # 应用属性清单
│   └── bundle/AppIcon.icns                   # 应用图标
├── docs/
│   └── DECISIONS.md                          # 架构决策备忘录 (含已替代废弃记录)
├── README.md                                 # 用户主页说明文档
├── AGENTS.md                                 # 智能体开发规范与红线 (本文档)
└── HANDOFF.md                                # 详细交接与安全审查清单
```

---

## 5. 开发调试与构建验证命令 (Workflow & Verification)

```bash
# 1. 增量热重载部署测试（推荐）
./scripts/dev-reload.sh

# 2. 纯编译检查
swift build -c release

# 3. 运行中进程检查
pgrep -l MyBattery
```

## 6. 产品与发布约定（2026-10-07）

用户定位：自己每天用、其他人能在 GitHub 下载或编译来玩的电池小工具。重点是日常状态、功率、协议准确和易安装；不扩展成充电管理器，不改 Apple 原生优化充电或上限。保留必要错误保护和验证，如实记录工具链/真实界面的未测项；这些环境限制不自动成为个人使用版的发布阻塞。

版本以 VERSION 为单一来源。MyBattery 首个公开版本=0.1.0，独立标签 mybattery-v0.1.0；保留上游 v1.0.0/v1.1.1 等历史标签。已用本项目 workflow 取代原来的每次 main 推送自动发布规则：main/PR 做检查，产品标签且版本匹配才发布。scripts/build-app.sh 自行打包和签名，正式发布模式要求干净且处在精确产品标签；同级 StatusItemKit 不作修改。

2026-10-07 用户已明确授权本轮提交、推送到 timberdai/MyBattery 并发布 v0.1.0（DMG 与 GitHub 自动源码归档）。后续发布仍按各次授权处理。README面向用户，审计过程只放交接/验收文件，不塞进产品功能介绍。

## 7. 自动语言规则（2026-10-07）

系统 Locale.preferredLanguages 第一项为 zh/zh-Hans/zh-Hant/zh-CN 等中文标识时显示简体中文；英文、其他语言、无值均显示英语。只判断第一项，不因次选中文把其他语言用户切成中文。启动时确定语言，不添加语言切换菜单或保存语言偏好。所有可见菜单、动态 formatter、版本与登录失败提示都遵守同一规则；英文继续满足176pt，不缩小字体或裁切。随附库的语言提示允许在本仓库内适配，不改同级库。
