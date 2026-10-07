# Changelog

MyBattery 的版本以 `VERSION` 为准，使用 `mybattery-vX.Y.Z` 标签发布。继承的 `v1.x` 标签与下方原项目记录保留，不复用或覆盖。

## [0.1.0] - 2026-10-07

- 自动读取系统首选语言，提供简体中文与英语；其他语言默认英语，无手动切换开关。
- 首个 MyBattery 公开版本：顶部显示电量及插电/充电图标，展开查看功率、协议、健康度、循环、容量和风扇。
- 保留紧凑的 176 pt 只读面板和原生插电边缘光效；加入版本显示，默认图标与电量，保留已有显示选择。
- 区分电池充放电、整机输入与负载功率；修复负电流、缺数和矛盾采样被误标充电的问题。
- 正确识别系统的“pd charger”协议字段，显示 PD 握手功率档位；读取 ChargerData 的充电状态。
- ioreg 缺少电池温度时，通过只读 TB0T 电池传感器回退，支持 Apple Silicon 浮点和 sp78 格式。
- 修复 SMC 只读命令、浮点字节序、连接退避、整数溢出与嵌套字段越界；避免失败采样触发虚假插电光效。
- 插电特效采用原生勾选菜单，关闭立即生效，清理结束、屏幕变化、休眠与退出时的窗口；电源监听增加重复启动和资源释放保护。
- 随仓库附带 StatusItemKit 源码及许可，解决本地汉化依赖无法从上游获取的问题；克隆单个仓库或解压源码归档即可构建安装。
- 首次读数失败或没有电池时显示明确状态，保留设置、版本和退出入口。
- 增加源码安装、可复跑回归、DMG 安装包与 SHA256，采用独立版本文件和标签触发的 GitHub 构建/发布流程；GitHub 自动附带 ZIP/TAR.GZ 源码归档。
- 灵感来自 BetterBattery 与 battery-time-menubar，保留原始代码及许可的来源说明。

## 原项目历史

以下为 Battery Time 的原始变更记录，不是 MyBattery 的发布顺序。

## [1.1.1] - 2026-09-28

- `install.sh` now installs the app: it builds Battery Time.app, links it into ~/Applications, asks whether to turn on Start at Login (skipped when it is already on, or when there is no terminal to ask in), and relaunches it. It also removes the retired SwiftBar plugin link and its power-watch launchd agent, which the app replaces. `./install.sh --swiftbar` still installs the plugin instead

## [1.1.0] - 2026-09-27

- With the face on, the battery is taller (17pt instead of 13pt) to make more of the menu bar's height and give the face room
- The battery face's mood follows the charge: a smile from 60%, a flat "meh" line from 35%, a slight frown below that, and a full frown when low
- The battery face stays visible across the empty part of the battery: where it crosses past the charge it is drawn in the menu-bar ink instead of cut out; over a Low Power Mode yellow fill it is drawn in black
- While charging, the face stays (instead of being replaced by the bolt): the fill turns green and it grins with happy ^ ^ eyes
- Plugged in but not charging (full, or macOS holding the charge at a limit), the battery becomes a smiling plug

## [1.0.1] - 2026-09-23

- chore: regenerate the menu-bar icon image

## [1.0.0] - 2026-09-23

- feat: the menu shows the version it was built from
- LICENSE: name the copyright holder above the MPL text
- License: Mozilla Public License 2.0
- docs: document the --login flag
- feat: --login on|off|status from the command line
- docs: Curtain is now Barn
- docs: Apollo Monitor described without the vendor name
- feat: the battery frowns when low, drawn in ink over the empty body
- docs: drop instructions that assume other software the reader may not use
- docs: the character menu-bar icon, rendered from code, and what its states mean
- fix: smaller battery face that stays inside the outline
- feat: a face on the battery glyph (Menu bar shows ▸ Battery face)
- feat: app icon from the Menubarn mascot
- docs: why a standalone app beats a SwiftBar plugin
- docs: README leads with the standalone app; SwiftBar plugin is the fallback
- docs: add the Menubarn mascot to the README
- Advertise the menu-bar suite
- feat: yield the status item during a curtain peek
- Run the pmset/ioreg poll off the main thread so it can't freeze the menu
- docs: document Start at Login options in the README
- fix: battery glyph uses opaque adaptive ink (not translucent labelColor)
- fix: battery glyph adapts to the menu-bar appearance
- docs: note the standalone Swift app
- feat: instant plug/unplug via IOKit power-source notifications
- feat: BatteryTime app (status glyph, full dropdown, polling)
- feat: battery glyph image (ported from render-title.swift)
- feat: 24h usage parse + battery tips triggers
- feat: battery math (health, humanize, temp, ETA stopgap)
- feat: ioreg AppleSmartBattery parsing
- feat: package skeleton + pmset -g batt parsing
- docs: add Swift app implementation plan
- docs: add menu-bar glyph states (charging/high-power/low-power/low/normal) to README
- feat: High Power = blue fill (incl. while charging), drop 💪
- feat: native-style battery glyph with %-left, 💪 High Power, fixed charging bolt
- feat: show 95% of macOS's remaining estimate
- change: cap only our stop-gap estimate, show macOS's estimate as-is
- feat: cap on-battery estimate at nominal; render whole hours as "Nh"
- feat: nominal time estimate on unplug when discharge draw is 0
- fix: battery glyph by default, bolt only while charging
- revert: menu bar back to bolt + time (drop the battery glyph)
- feat: show an instant time estimate on unplug before macOS computes one
- feat: visible charging bolt (outline halo) + circular Energy Mode icons
- feat: icon/%/time display toggles + native "Energy Mode" dropdown header
- feat: native-style battery icon in the menu bar
- feat: collapse battery tips to a "Battery Life Tips" item with a popup
- feat: behavior-based battery-longevity tips in the dropdown
- feat: 24-hour on-battery vs plugged usage in the dropdown
- feat: °C/°F temperature unit toggle in the dropdown
- feat: battery health, power draw, adapter & temp/voltage/charge in dropdown
- feat: 3-mode energy selector, hidden defaults, tight image-rendered title
- feat: bolt/ETA menu bar, details dropdown, instant plug/unplug updates
- feat: battery time-remaining menu-bar SwiftBar plugin
