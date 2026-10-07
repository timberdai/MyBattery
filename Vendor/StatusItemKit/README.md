# StatusItemKit（随附源码）

来源：[nicholaspsmith/StatusItemKit](https://github.com/nicholaspsmith/StatusItemKit)，MPL-2.0，保留各文件版权与本目录 LICENSE。

本副本取自本地干净提交 `c40a1fbe39ee61ac296bf9e135834f70d05eb30e`（2026-10-04），基于上游公开提交 `29565c5`。该本地提交将 AppVersion.swift、LoginItem.swift、LoginRequest.swift 的提示汉化；它没有发布到上游，不作为可下载的远程依赖。

最初随附的 Sources/StatusItemKit 24 个文件与该本地提交逐文件一致。MyBattery 的后续适配仅修改 AppVersion.swift、LoginItem.swift、LoginRequest.swift，并新增 StatusItemLanguage.swift，让这几个提示也按系统首选语言显示中文或英文；其余 21 个原始文件保持一致。Package.swift 仅保留应用需要的库 target，不附带上游演示应用、脚本与测试。MyBattery 随仓库携带这份源码，安装时无需准备同级目录，也不会改动已有同级 StatusItemKit。

LICENSE 保留原始完整条款，仅清理行末空格以通过仓库格式检查。
