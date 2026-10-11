# MyBattery 维护入口

更新：2026-10-12。当前产品版本0.1.0，作者timberdai，主分支main。

本轮用户授权替换已选定的应用图标、安装本地应用并提交推送GitHub；未要求新的Release或版本标签。GitHub没有隐藏Contributors的选项；用户随后明确要求移除Nick和Claude，并增加Codex及Gemini，覆盖此前保留账号关联的选择。用户确认Gemini是项目初期主力，要求采用已有Gemini用户使用的署名方式。

本轮main历史改写仅取消Nick的GitHub账号邮箱关联（保留作者姓名）、移除Claude共同作者字段；在原0ed5a5e的初期MyBattery提交补充Gemini官方机器人署名，在原d29414e的图标提交补充OpenAI官方Codex署名。78条原有提交的每个文件树、作者姓名、日期与合并关系已逐项比对一致；原HEAD d29414e6f13dd26e10e74765c2358b599afa7562，改写后对应HEAD 7d3426606cbeda9d5f14f59c4b90a3a9464f4f27，树均为57dfbd139b856faf4cc89d1ce407b055a677e266。完整原历史备份build/verification/contributors/before-rewrite.bundle已验证；逐提交映射与检查结果在同目录。推送仅更新main，使用精确旧HEAD的force-with-lease；版本标签、Release、上游版权及来源声明保留。GitHub贡献者缓存须通过实际页面核实，不能仅凭本地署名宣称列表已刷新。

应用保留176pt只读菜单、自动中英双语、功率/协议/温度/健康/风扇信息、勾选式插电特效以及原生登录启动。只读，不控制充电或风扇。应用图标替换不改变菜单栏实时电池绘制。同级StatusItemKit未修改，依赖源码与许可随附在Vendor/。

图标源文件Resources/artwork/AppIcon.png，生成入口scripts/build-icon.sh；AppIcon.icns包含16–1024px十种尺寸，README使用docs/app-icon.png。2026-10-12本机验证：图标重生成、脚本语法、Info.plist、git diff检查通过；350条辅助回归、release构建与签名检查通过。源码、构建包、已安装包的ICNS SHA256一致：15f9b263b48950d119c9f43c4262fe35dcbe5e3d6f79fe291f196bd6c0d076fb。Finder实测已显示新图标，应用重启运行正常。验证日志与旧安装备份在忽略的build/verification/中；完整swift test本机因缺XCTest未能运行，以本轮main提交对应GitHub Actions结果为准。

公开版本标题v0.1.0，使用mybattery-v0.1.0标签；保留旧v0.1.0及v1.x历史标签。VERSION是版本来源。Release提供arm64 DMG，GitHub自动提供ZIP和TAR.GZ源码。README/README.en.md包含用户安装和开发说明，About指向最新Release。下载的源码归档无需Git历史也能构建；本机已用不含.git的完整源码副本验证。公开发行入口：https://github.com/timberdai/MyBattery/releases/tag/mybattery-v0.1.0 。

发布流程：主分支/PR执行完整XCTest和构建；通过后推送产品标签，由workflow生成DMG、检验并发布；同一产品标签的补发会替换DMG和发行说明。正式打包要求干净工作区、标签版本一致。本机CLT仍缺XCTest；GitHub完整Xcode环境已执行全部非桌面XCTest并通过，补齐了此前完整测试未运行的证据。检查见 https://github.com/timberdai/MyBattery/actions/runs/37577564996 。不能把辅助入口当全套测试。桌面光效测试需显式启用，不在无桌面CI中强制播放。

此前本机350条辅助回归（含153个中英文宽度样例）和19条两屏光效生命周期断言通过；真实菜单鼠标交互未自动完整验收。用户已反馈真实菜单截图，并要求特效改为勾选项，现已应用。菜单功率与档位不是同一类实时数据，详细说明见README。

旧审计与冻结记录保留在本机共用工作区；本文件只维护项目状态与恢复入口，不随源码发布机器路径或完整审计日志。
