# Modu 1.2.10 Beta1

Build / 构建：**10128** · GitHub prerelease / 预发行版

### English

- Feat(reader): Give PDF reflow and OCR results an ebook-style reading surface and compact bottom menus for text style, brightness and narration. Preserve source-page navigation, selection/annotations, region/full-page/batch recognition and AI drafts; opening menus does not resize the text viewport.
- Feat(feedback): Remove contact links from feedback; include independently optional crash and safe current-session runtime diagnostics by default in bug reports, with full preview before confirmation. Record content-free reader, narration, sync, lifecycle, timing and memory events; runtime history clears on every restart while crash diagnostics remain separate.
- Feat(reader): Add an immediately saved option to scroll one chapter at a time instead of joining adjacent chapters; continuous scrolling remains the default ([#36](https://github.com/sobranie2406/modureader/issues/36)). Thanks [@Wisso2278](https://github.com/Wisso2278) for the suggestion.
- Fix(reader): Preserve numbered headings and decorated publisher blocks during automatic page alignment and line-spacing fitting; leave affected columns at native spacing while ordinary prose pages still align ([#34](https://github.com/sobranie2406/modureader/issues/34)). Thanks [@Claire9518](https://github.com/Claire9518) for the report and sample EPUB.
- Fix(backup): Resolve library and cache paths before starting the ZIP worker, avoiding uninitialized Windows preferences during database export.
- Fix(storage): Schedule Windows storage relocation before database startup, verify copied files and retain the original library; only switch paths after successful copying.
- Fix(android): Stage settings exports in app-owned cache before opening the system save dialog; distinguish file, system-service and settings-format failures instead of reporting all failures as permissions.

### 简体中文

- Feat(reader): PDF 重排和 OCR 结果统一为电子书式阅读界面，使用自适应底部样式、亮度和朗读菜单；保留原页导航、划词标注、区域／整页／连续识别及 AI 草稿功能，展开菜单不改变正文视口。
- Feat(feedback): 问题与反馈页面移除联系方式；Bug 报告默认附带可分别取消的崩溃日志和安全运行日志，提交前预览完整内容并确认。补充不含私人内容的阅读、朗读、同步、生命周期、耗时与内存记录；运行记录每次重启清空，崩溃诊断独立保留。
- Feat(reader): 新增“跨章节连续滚动”开关，关闭后每章独立滚动，章末通过翻页或目录进入下一章；即时保存，默认保留连续滚动（[#36](https://github.com/sobranie2406/modureader/issues/36)）。感谢 [@Wisso2278](https://github.com/Wisso2278) 提出建议。
- Fix(reader): 自动上下对齐和行距微调时保护带编号、边框等特殊排版的小标题，避免编号、竖线与标题文字错位；相关页面保留原排版，纯正文页继续对齐（[#34](https://github.com/sobranie2406/modureader/issues/34)）。感谢 [@Claire9518](https://github.com/Claire9518) 提供反馈和复现书籍。
- Fix(backup): 在主线程确定书库和缓存路径，再启动 ZIP 压缩，修复 Windows 数据库导出时设置未初始化的问题。
- Fix(storage): Windows 存储迁移改在重启后、数据库打开前执行，逐文件校验并保留原书库，复制成功后才切换路径。
- Fix(android): 设置导出先写入应用缓存，再调用系统保存窗口；区分文件读写、系统服务和设置格式错误，不再统一提示权限问题。


## Downloads / 下载

Four packages, each with a SHA-256 checksum / 发布以下四个安装包及 SHA-256 校验文件：

- Android ARM64 — APK
- macOS Apple Silicon (ARM64) — DMG
- Windows 64-bit (x64) — EXE installer / 安装程序
- iOS ARM64 — unsigned IPA, requires your own signing / 未签名 IPA，需自行签名安装

Upgrade without uninstalling or clearing the library; back up first. Android retains the project signing key. macOS is ad-hoc signed, not notarized. Windows requires WebView2. iOS requires your own signing; this is not a TestFlight build. This Beta does not replace 1.2.9 as the latest stable release.

建议先备份，再覆盖升级，不要卸载或清空书库。安卓沿用项目签名；macOS 为临时签名、未公证；Windows 需要 WebView2；iOS 需自行签名，不是 TestFlight 版本。本次 Beta 不替代 1.2.9 最新正式版，不发布其他平台或 Gitee 镜像。

[Source / 源码](https://github.com/sobranie2406/modureader/tree/v1.2.10-beta.1) · [Changes / 变更](https://github.com/sobranie2406/modureader/compare/v1.2.9...v1.2.10-beta.1)
