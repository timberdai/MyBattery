# MyBattery 🔋

**精美、轻量、现代的 macOS 菜单栏电池工具**  
针对 Apple Silicon (M1/M2/M3/M4) 与 macOS **80% 充电保护 / 旁路供电**深度定制优化。

---

## 💡 灵感与致谢 (Inspiration & Credits)

本项目的设计灵感源自优秀的开源项目 **[nicholaspsmith/battery-time-menubar](https://github.com/nicholaspsmith/battery-time-menubar)**。在其轻量稳定架构的基础上，我们针对常年外接供电、80% 电池养护上限以及现代 macOS 菜单视觉美学进行了深度重构与功能演进，同时吸收了 [BetterBattery](https://github.com/michaelmax98/BetterBattery) 与 [CodexBar](https://github.com/steipete/CodexBar) 的界面设计哲学。

感谢所有为开源社区贡献力量的开发者！

---

## ✨ 核心特性 (Features)

* **🔌 80% 充电保护与旁路供电深度识别**
  * 专为常年插电使用的 Mac 用户量身打造。
  * 准确区分**正在充电**与**外接电源·旁路供电 (80% 上限保护)**，状态栏图标与详情面板同步高对比度显示，绝无歧义。

* **⚡️ 实时整机输入功率与电池功耗 (Active Power Tracking)**
  * **插电时**：读取 Apple Silicon 真实遥测数据（`SystemPowerIn`），显示适配器输入给 Mac 整机的真实总功率（如 `16.4 W`），清楚感知是整机运行还是正在快充。
  * **拔电时**：毫秒级采样瞬时放电电流与电压，显示整机实时消耗功耗（如 `8.5 W`）。
  * 告别晦涩冷门的标称电压（`12.37 V`），只看对用户最有感知意义的真实瓦数。

* **🎨 CodexBar 风格微型卡片与胶囊进度条 (Modern Header Card)**
  * 菜单顶部集成轻量级毛玻璃 Header 卡片：
    * **大号粗体电量数值**（`80%`，插电翡翠绿高亮）；
    * **自适应状态药丸徽章**（`外接供电 · 旁路保护` / `⚡️ 充电中` / `🔋 电池供电`）；
    * **Retina 微型胶囊进度条**：全圆角自绘轨道，**在 80% 阈值处精致雕琢了物理刻度标记线（Tick Marker）**；
    * **实时摘要副标**：一目了然当前功率与电源适配器档位。

* **📊 完整的电池硬件与健康档案 (Hardware Telemetry)**
  * 电池健康度（出厂容量衰减比）与循环次数；
  * 当前实时容量、全负荷容量与出厂设计容量（mAh）；
  * 电源适配器真实握手协议（USB-PD 档位，如 `20.0 V / 4.5 A (90 W)`）；
  * 24 小时电池 vs 供电使用时间统计。

* **📐 像素级对齐的状态栏图标 (Pixel-Perfect Menu Bar Glyph)**
  * 21.0 × 11.5 pt 黄金比例胶囊外壳，搭配向右微型极耳；
  * 饱满圆头的醒目插头与高能闪电标记；
  * `CGBlendMode.clear` 物理镂空呼吸间距，无论在浅色、深色还是动态壁纸下均有绝佳的对比度。

---

## 🚀 安装与使用 (Getting Started)

### 系统要求
* macOS 13.0 (Ventura) 及更高版本
* Apple Silicon Mac (M1 / M2 / M3 / M4 系列)

### 从源码构建与运行
```bash
# 1. 克隆本仓库
git clone https://github.com/timberdai/MyBattery.git
cd MyBattery

# 2. 编译并启动
swift run -c release
```

### 极速热重载开发脚本
本项目内置增量热重载脚本，修改代码后执行以下命令可在 2 秒内完成构建、签名并重启应用：
```bash
./scripts/dev-reload.sh
```

---

## ⚙️ 快捷控制 (Preferences)

在菜单面板的“设置”分区中，您可以自由定制：
- [x] 显示电池图标
- [x] 显示电量百分比
- [ ] 显示预估剩余时间 / 充满时间
- [ ] 开机登录时自动启动
- ⚙️ 一键直达 macOS 系统“电池”设置

---

## 📄 开源协议 (License)

本项目遵循 [MPL-2.0 License](LICENSE) 开源协议。
欢迎提交 Issue 和 Pull Request 共同改进！
