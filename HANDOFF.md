# MyBattery 维护入口

更新：2026-10-12。当前产品版本0.1.0，作者timberdai，主分支main。

本轮用户授权替换已选定的应用图标、安装本地应用并提交推送GitHub；未要求新的Release或版本标签。用户确认保留提交历史，在README展示timberdai、Codex（GPT）、Google Antigravity（Gemini）协作说明。实查GitHub首页元数据编辑与General设置，没有隐藏Contributors的选项；自动贡献者列表仍保留，不能宣称已隐藏。上游版权、来源与历史记录保留。

应用保留176pt只读菜单、自动中英双语、功率/协议/温度/健康/风扇信息、勾选式插电特效以及原生登录启动。只读，不控制充电或风扇。应用图标替换不改变菜单栏实时电池绘制。同级StatusItemKit未修改，依赖源码与许可随附在Vendor/。

图标源文件Resources/artwork/AppIcon.png，生成入口scripts/build-icon.sh；AppIcon.icns包含16–1024px十种尺寸，README使用docs/app-icon.png。2026-10-12本机验证：图标重生成、脚本语法、Info.plist、git diff检查通过；350条辅助回归、release构建与签名检查通过。源码、构建包、已安装包的ICNS SHA256一致：15f9b263b48950d119c9f43c4262fe35dcbe5e3d6f79fe291f196bd6c0d076fb。Finder实测已显示新图标，应用重启运行正常。验证日志与旧安装备份在忽略的build/verification/中；完整swift test本机因缺XCTest未能运行，以本轮main提交对应GitHub Actions结果为准。

公开版本标题v0.1.0，使用mybattery-v0.1.0标签；保留旧v0.1.0及v1.x历史标签。VERSION是版本来源。Release提供arm64 DMG，GitHub自动提供ZIP和TAR.GZ源码。README/README.en.md包含用户安装和开发说明，About指向最新Release。下载的源码归档无需Git历史也能构建；本机已用不含.git的完整源码副本验证。公开发行入口：https://github.com/timberdai/MyBattery/releases/tag/mybattery-v0.1.0 。

发布流程：主分支/PR执行完整XCTest和构建；通过后推送产品标签，由workflow生成DMG、检验并发布；同一产品标签的补发会替换DMG和发行说明。正式打包要求干净工作区、标签版本一致。本机CLT仍缺XCTest；GitHub完整Xcode环境已执行全部非桌面XCTest并通过，补齐了此前完整测试未运行的证据。检查见 https://github.com/timberdai/MyBattery/actions/runs/37577564996 。不能把辅助入口当全套测试。桌面光效测试需显式启用，不在无桌面CI中强制播放。

此前本机350条辅助回归（含153个中英文宽度样例）和19条两屏光效生命周期断言通过；真实菜单鼠标交互未自动完整验收。用户已反馈真实菜单截图，并要求特效改为勾选项，现已应用。菜单功率与档位不是同一类实时数据，详细说明见README。

旧审计与冻结记录保留在本机共用工作区；本文件只维护项目状态与恢复入口，不随源码发布机器路径或完整审计日志。
