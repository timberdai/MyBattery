# AGENTS.md — MyBattery 智能体接手指南与上下文知识库

> 欢迎来到 **MyBattery** 项目。本文档专为 AI 编码助手（Antigravity、Claude Code、Cursor、Codex 等）及协作者编写。
> 请在接手任何开发任务前完整阅读本文档，以确保理解项目背景、用户核心诉求、设计决策与开发工作流。

---

## 1. 项目定位与背景 (Identity & Context)

* **项目名称**：MyBattery
* **仓库地址**：`https://github.com/timberdai/MyBattery`
* **主分支**：`main`
* **当前版本**：`v0.1.0`
* **作者**：timberdai (`timberdai@outlook.com`)
* **致敬与灵感**：
  * 底层架构灵感源自：[nicholaspsmith/battery-time-menubar](https://github.com/nicholaspsmith/battery-time-menubar)
  * 现代美学与交互参考：[BetterBattery](https://github.com/michaelmax98/BetterBattery) 与 [CodexBar](https://github.com/steipete/CodexBar)

---

## 2. 用户核心画像与产品哲学 (User Persona & Product Principles)

在为此项目编写代码或提出方案时，**必须严格遵守以下用户准则**：

1. **核心使用场景**：
   * 用户为 Apple Silicon (M系列) 笔记本重度用户；
   * **常年外接供电使用，并在系统设置中常年开启“80% 充电上限”**；
   * 极度关注：外接线是否插好、当前是充电还是旁路供电、真实输入瓦数是多少、当前是否为 USB-PD 高功率握手。
2. **审美与品味准则（遵循 Emil Kowalski 与 Apple 原生设计哲学）**：
   * **拒绝低质粗糙**：必须像素级对齐，拒绝发灰、截断、白边或文字重叠；
   * **拒绝花哨无用功能**：用户**坚决不喜欢表情功能（Emoji / Memoji）**等花哨冗余特性；
   * **信息层次分明**：遵循《Refactoring UI》规则，主数值加粗饱和、次级键淡灰雅致，善用微型胶囊轨道与徽章；
   * **纯信息展示与辅助控制**：定位为纯粹、高质感的电能信息面板，不强行做侵入式系统改写。

---

## 3. 极速开发与热重载工作流 (Workflow & Tooling)

* **严禁全量重构或冗余操作**：本项目已内置极速增量热重载脚本：
  ```bash
  ./scripts/dev-reload.sh
  ```
  该脚本会在 `<2s` 内完成：
  1. `swift build -c release`（增量编译）
  2. 拷贝二进制到 `~/Applications/MyBattery.app` 并进行 ad-hoc 签名
  3. 平滑重启后台进程 `MyBattery`
* **开发调试流程**：修改代码 ➔ 执行 `./scripts/dev-reload.sh` ➔ 用户点击状态栏立即看到真实效果。

---

## 4. 关键架构与核心技术决策 (Architecture & ADRs)

### 4.1 80% 旁路供电硬件级识别 (Bypass Power Detection)
* **技术难点**：插着外接供电且停在 80% 时，macOS 会激活旁路供电，此时电池既不充电也不放电（电流为 0）。普通工具常误判为“未插电”或“充满电”。
* **解决方案**：
  * 读取 `AppleSmartBattery` 的 `NotChargingReason == 16777216` 且 `ExternalConnected == Yes`；
  * 或判定 `reading.plugged && !isCharging && percent == 80`；
  * 状态栏图标与详情面板统一标注：`外接电源 · 旁路供电 (80%上限保护)`。

### 4.2 功率测量：整机输入功率 vs 放电功耗 (Active Power)
* **决策原因**：标称电压（如 `12.37 V`）对用户无实际意义，电池端电流在旁路时显示 `0.0 W` 容易引起误解。
* **数据来源**：
  * **插电时**：读取 `PowerTelemetryData.SystemPowerIn`（毫瓦转换得到瓦特），展示适配器输入给 Mac 整机的真实功率（例如 `16.4 W`）；
  * **拔电时**：计算 `instantAmperageRaw * voltageMV`，展示电池整机放电功耗（例如 `8.5 W`）。

### 4.3 状态栏图标黄金比例与镂空渲染 (BatteryGlyph)
* **尺寸规范**：外壳 `21.0 × 11.5 pt`，右侧带微型小三角极耳；
* **内部图标**：饱满圆头大插头（`6.6 × 4.9 pt`）或高能闪电；
* **物理镂空**：采用 `CGBlendMode.clear` 物理打孔（1.2pt 呼吸间距），无论在浅色、深色还是动态壁纸下均可完美透出桌面背景，具备极致通透感。

### 4.4 CodexBar 风格 Header 卡片 (BatteryMenuCardView)
* **实现机制**：纯 AppKit 自绘制 `NSView` 嵌入 `NSMenuItem`，重写 `allowsVibrancy = true`，完美融入系统毛玻璃菜单；
* **内容包含**：大号电量粗体数字、状态胶囊徽章、**微型电量胶囊进度条（在 80% 处刻画了物理刻度标记线）**与实时功率副标。

---

## 5. 项目模块代码结构地图 (Code Map)

```text
MyBattery/
├── Package.swift                             # Swift Package 清单，产物为 MyBattery
├── Sources/
│   ├── MyBattery/
│   │   ├── main.swift                        # 应用入口、菜单构建逻辑与轮询状态管理
│   │   ├── BatteryMenuCardView.swift         # 顶部 CodexBar 风格微型卡片与胶囊进度条
│   │   ├── BatteryGlyph.swift                # 状态栏图标 CoreGraphics 高清渲染器
│   │   ├── DisplayPrefs.swift                # 显示偏好设置 (图标/百分比/时间)
│   │   └── PowerSourceWatcher.swift          # 电源插拔与硬件状态变更监听
│   └── BatteryTimeCore/
│       ├── IORegBattery.swift                # IOKit 硬件遥测解析器 (含 SystemPowerIn)
│       ├── BatteryMath.swift                 # 电池安培、电压、健康度数学计算
│       └── Usage24h.swift                    # 24小时电池与供电使用时长统计
├── scripts/
│   └── dev-reload.sh                         # <2s 极速增量热重载脚本
├── docs/
│   ├── ARCHITECTURE.md                       # 系统架构图与数据流
│   └── DECISIONS.md                          # 历史讨论与决策备忘录
├── legacy/                                   # 原作者旧版独立脚本归档
└── README.md                                 # 面向用户的项目主页说明文档
```

---

## 6. 待推进路线图 (Next Roadmap)

根据对 [BetterBattery](https://github.com/michaelmax98/BetterBattery) 与 [BatteryBar](https://github.com/isolson/BatteryBar) 的竞品研究，后续建议迭代优先级如下：

1. **三端电能流向示意图 (Power Flow Diagram)**：
   * 在卡片中展示 `[⚡️ 适配器 16.4W] ➔ [🔋 0.0W 旁路闲置] ➔ [💻 主机 16.4W]`；
2. **电池温度微型冷暖胶囊 (Temperature Gauge)**：
   * 展示实时电池温度（如 `32.5 °C`）并附带蓝-绿-橙-红冷暖指示轨；
3. **容量衰减对比条 (Capacity Degradation Bar)**：
   * 将当前容量（4831 mAh）、全负荷容量（6294 mAh）与出厂设计容量（6249 mAh）用条形图对比展示；
4. **显著耗电应用侦测 (Using Significant Energy)**：
   * 仅在拔掉电源放电时激活：后台轻量采样耗电最大的 2~3 个应用（如 `Chrome`、`Claude` 等）。
