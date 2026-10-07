# MyBattery

[![Release](https://img.shields.io/github/v/release/timberdai/MyBattery)](https://github.com/timberdai/MyBattery/releases/latest)
[![Build](https://github.com/timberdai/MyBattery/actions/workflows/release.yml/badge.svg)](https://github.com/timberdai/MyBattery/actions/workflows/release.yml)
[![License: MPL-2.0](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](LICENSE)

**一个小巧的 macOS 菜单栏电池工具：看电量、充电状态，也看你最关心的瓦数。**

[下载最新版](https://github.com/timberdai/MyBattery/releases/latest) · [English](README.en.md) · [反馈问题](https://github.com/timberdai/MyBattery/issues)

MyBattery 从一个日常需求开始：电脑长期插着电，使用 Apple 原生优化充电与 80% 上限时，也想随时知道它是接着电源、正在充电，还是在消耗电池，以及当前到底用了多少功率。顶部快速看状态，点开查看详细信息，保持紧凑的原生菜单。

## 能看到什么

- **电量与状态**：电池图标、百分比、插电和充电标识；支持图标、电量、剩余时间三种显示方式。
- **实时功率**：区分电池充入、放出、整机输入和负载，缺少读数时明确显示缺数。
- **适配器与 PD 档位**：查看系统报告的 PD、USB、MagSafe 类型、适配器瓦数及供电档位。
- **电池状态**：温度、健康度、循环次数、当前容量、全充容量和设计容量。
- **风扇与统计**：当前风扇转速，以及近 24 小时的电池/外接供电时长。
- **插电特效**：接通电源时显示绿色边缘光晕，通过菜单勾选开启或关闭。
- **日常操作**：登录时启动、打开系统电池设置和退出。

MyBattery 只读取信息，不控制充电上限或风扇。优化充电和 80% 上限继续在 Apple 的电池设置中管理。健康度表示当前容量状态，不预测还可以使用多少年。

## 安装

**系统：macOS 13 或更新版本。下载包：Apple Silicon（M 系列）。**

1. 在 [Releases](https://github.com/timberdai/MyBattery/releases/latest) 下载 `MyBattery-0.1.0-arm64.dmg`。
2. 打开 DMG，将 `MyBattery.app` 拖进旁边的 `Applications`（应用程序）。
3. 从“应用程序”打开 MyBattery；它会出现在菜单栏，不显示 Dock 图标。
4. 按需勾选“登录时启动”。

当前没有 Apple 开发者公证。首次打开若被系统拦截，在“系统设置 → 隐私与安全性”按系统提示选择“仍要打开”。读取电池和风扇不需要管理员权限。也可以采用下面的源码安装方式，在本机编译使用。

Release 中的 **Source code (zip)** 和 **Source code (tar.gz)** 是源码，供开发者编译；普通用户下载 DMG 即可。DMG 的 SHA256 校验值写在发布说明中。

## 这几个功率有什么区别

| 参数 | 表示什么 |
| --- | --- |
| 充电功率 | 当前实际充入电池的功率。 |
| 放电功率 | 当前电池向电脑供电的功率。 |
| 输入功率 | 电源给整台电脑的输入，包含系统用电与可能的电池充电。 |
| 负载功率 | 系统报告的负载；不能当作电池充电功率。 |
| 电源适配器 | 系统识别到的协议和适配器瓦数。 |
| 握手档位 | 用系统报告的供电参数换算出的 PD 档位功率；不是直接抓取握手报文。 |

例如，“PD 100 W”和“握手档位 100 W”可以同时出现，但实际输入可能只有十几瓦，电池也可能因 80% 上限而没有充电。看此刻用了多少，关注“输入功率”；看充进电池多少，关注“充电功率”。

传感器和系统字段因机型而异：没有风扇或读不到温度时，对应项目会隐藏；不会用固定数值冒充读数，也不会把未知协议猜成 PD 3.0/3.1。24 小时统计来自系统电源日志，是供电时长，包含睡眠期间的相应区间。

## 语言

自动读取系统的**首选语言**：中文（包括简体、繁体的系统语言设置）显示简体中文；英语及其他语言显示英语。没有语言切换开关，改系统语言后重新打开应用即可。

## 从源码安装

需要 Swift 5.9 或更新版本及 macOS 开发工具。所需的 StatusItemKit 已随仓库附带，无需下载同级依赖。

```bash
git clone https://github.com/timberdai/MyBattery.git
cd MyBattery
./scripts/install.sh
```

也可以解压 Release 的源码归档，进入解压目录运行 `./scripts/install.sh`，不需要 Git 历史。

脚本会编译、在本机签名、安装到 `~/Applications/MyBattery.app` 并启动。修改后运行 `./scripts/dev-reload.sh` 即可重新构建安装。

## 开发与贡献

```bash
swift build -c release
swift test
./scripts/run-round2-tests.sh
```

完整 XCTest 需要含测试框架的 Xcode。仅安装 Command Line Tools 时可使用第三个辅助入口，它直接测试生产解析、功率、边界和只读 SMC 路径，也检查中英文行宽；它不替代完整 XCTest。桌面光效生命周期可用 `./scripts/run-round2-tests.sh --glow` 检查。

欢迎通过 [Issues](https://github.com/timberdai/MyBattery/issues) 提交问题或通过 Pull Request 改进。报告时附 macOS 版本、Mac 型号、MyBattery 版本、复现步骤及相关截图；不要上传包含设备序列号的完整系统报告。

## 版本与构建

`VERSION` 是版本来源，当前为 **0.1.0**。运行 `./scripts/package-release.sh` 会在 `build/` 生成当前架构的 DMG 和校验文件。

主分支和 PR 执行测试与构建；推送匹配的 `mybattery-vX.Y.Z` 标签才发布。首个公开版本使用 `mybattery-v0.1.0`，Release 标题为 `v0.1.0`。原仓库已有的 `v0.1.0` 及 `v1.x` 历史标签保留。

## 灵感与致谢

- [BetterBattery](https://github.com/michaelmax98/BetterBattery)：轻巧的菜单栏电池与实时功率展示，是这个小工具的灵感之一。
- [battery-time-menubar](https://github.com/nicholaspsmith/battery-time-menubar)：MyBattery 的代码基础，保留原始版权与历史记录，并在其上完善日常信息展示。
- [StatusItemKit](https://github.com/nicholaspsmith/StatusItemKit)：提供菜单栏、版本与登录启动支持。随附版本及适配说明见 [Vendor/StatusItemKit](Vendor/StatusItemKit/README.md)。

作者：[timberdai](https://github.com/timberdai)。遵循 [Mozilla Public License 2.0](LICENSE)。
