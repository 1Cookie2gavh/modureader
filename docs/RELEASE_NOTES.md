# Modu 1.2.10

Build / 构建：**10129** · Stable / 正式版

### English

- Fix(reflow): Remove narration from PDF/OCR reflow menus, selection actions and playback shortcuts; prevent speech from falling through to the hidden original page. Ordinary ebook narration remains available.

- Fix(ocr): Reduce excessive reflow paragraph breaks by measuring printed line spacing per column and requiring clear paragraph gaps, first-line indents or trailing whitespace. Join ordinary sentence wraps and nearby same-row OCR fragments; upgrade cached layouts without rerunning OCR while preserving historical note revisions and source coordinates.

- Fix(eink): Lock E-Ink to pure white backgrounds and pure black text across the app, ebook reader and OCR reflow, regardless of dark/night mode. Preserve saved reading palettes and background images when E-Ink is disabled.

- Fix(reflow): Reuse the actual ebook quick-style component for OCR/reflow font size, thickness, line/paragraph spacing, fonts, palettes and backgrounds. Keep typography book-local and additional reflow settings behind the gear button.

- Fix(reflow): Use the ordinary ebook menu host and button order for PDF/OCR reflow. Keep the original-page/mode header and PDF page arrows; both compact and menu arrows automatically reflow the adjacent source page and reuse cached recognition. Preserve PDF preprocessing budgets and caches.

- Fix(tts): Update Edge Read Aloud authentication to the v2 token protocol, resolving synthesis rejection caused by the obsolete token. Preserve clock correction, bounded retries, audio caching and narration positions ([#39](https://github.com/sobranie2406/modureader/issues/39)). Thanks [@115MicroRGB](https://github.com/115MicroRGB) for the iOS report.

- Feat(reflow): Infer paragraphs and first-line indents from source line geometry while retaining uncertain headers, footers and short lines. Reuse ebook color/background editors, imported fonts and spacing controls; add reflow-aware page navigation, search, copy, query/translation, AI drafts and bookmarks. Keep historical text-layout revisions intact for existing annotations.

- Fix(reader): Switch ordinary ebook night colors without repagination or waiting for fonts; apply reader colors to nested publisher text and headings when original-book styles are disabled. Keep OCR reflow and original-page toolbars mutually exclusive, with immediate opaque night colors on reflow text and no hidden source-page repaint.

- Feat(notes): Preserve original page numbers and uncropped image line/text-block coordinates with new PDF/OCR reflow notes. “View original” shows the saved source regions without rerunning OCR; re-recognition never rewrites existing notes or their text revisions. Older notes remain available without guessed image positions or forced text matching.

- Feat(feedback): Remove contact links from feedback; include independently optional crash and safe current-session runtime diagnostics by default in bug reports, with full preview before confirmation. Record content-free reader, narration, sync, lifecycle, timing and memory events; runtime history clears on every restart while crash diagnostics remain separate.
- Feat(reader): Add an immediately saved option to scroll one chapter at a time instead of joining adjacent chapters; continuous scrolling remains the default ([#36](https://github.com/sobranie2406/modureader/issues/36)). Thanks [@Wisso2278](https://github.com/Wisso2278) for the suggestion.
- Fix(reader): Preserve numbered headings and decorated publisher blocks during automatic page alignment and line-spacing fitting; leave affected columns at native spacing while ordinary prose pages still align ([#34](https://github.com/sobranie2406/modureader/issues/34)). Thanks [@Claire9518](https://github.com/Claire9518) for the report and sample EPUB.
- Fix(backup): Resolve library and cache paths before starting the ZIP worker, avoiding uninitialized Windows preferences during database export.
- Fix(storage): Schedule Windows storage relocation before database startup, verify copied files and retain the original library; only switch paths after successful copying.
- Fix(android): Stage settings exports in app-owned cache before opening the system save dialog; distinguish file, system-service and settings-format failures instead of reporting all failures as permissions.

### 简体中文

- Fix(reflow): 移除 PDF／OCR 重排的朗读菜单、划词朗读和播放快捷键入口，避免误读隐藏原页；普通电子书朗读保持不变。

- Fix(ocr): 减少重排过度断段，按栏测算实际行距，仅在明确段距、首行缩进或段尾留白时分段；合并普通句内换行及同一行 OCR 碎片。旧缓存无需重新识别即可更新排版，历史笔记版本和原图坐标保持不变。

- Fix(eink): E-Ink 强制锁定浅色，应用界面、电子书与 OCR 重排统一为纯白底纯黑字，不随深色／夜间模式切换；关闭后恢复保存的阅读配色和背景图。

- Fix(reflow): OCR／重排样式面板直接复用普通电子书组件，统一字号、粗细、行距／段距、字体、配色与背景布局；排版仅保存到当前书籍，重排附加参数收进齿轮设置。

- Fix(reflow): PDF／OCR 重排直接共用普通电子书菜单及按钮排列，保留顶部原页／重排模式和底部 PDF 页码箭头；底部与菜单翻页均自动重排相邻原页并复用识别缓存，保留 PDF 预处理提前量和缓存逻辑。

- Fix(tts): 适配 Edge 朗读新版 v2 鉴权，修复旧版令牌导致的语音生成被拒绝；保留时钟校正、有限重试、音频缓存和朗读位置（[#39](https://github.com/sobranie2406/modureader/issues/39)）。感谢 [@115MicroRGB](https://github.com/115MicroRGB) 提供 iOS 问题反馈。

- Feat(reflow): 根据原页行坐标恢复分段和首行缩进，保留无法确认的页眉、页脚及短行；复用电子书配色、背景图、导入字体与间距设置，补充适配重排文字的跳页、查找、复制、查询／翻译、AI 草稿及书签。保留历史文字排版版本，避免旧划线与笔记错位。

- Fix(reader): 普通电子书切换夜间配色不再重新分页或等待字体；关闭原书样式时，内嵌文字与标题一并跟随阅读配色，避免夜间仍显示黑字。OCR 重排与原页工具栏互斥，避免两套菜单叠加，识别／重排文字立即切换不透明夜间配色，不再同时重绘隐藏原页。

- Feat(notes): 新增 PDF／OCR 重排笔记保留原始页码及未裁切原图的行／文字块坐标；“查看原图”按保存时位置框选核对，不依赖重新 OCR。重新识别不改写既有笔记及文字版本；旧笔记保留，不猜测坐标、不强行匹配。

- Feat(feedback): 问题与反馈页面移除联系方式；Bug 报告默认附带可分别取消的崩溃日志和安全运行日志，提交前预览完整内容并确认。补充不含私人内容的阅读、朗读、同步、生命周期、耗时与内存记录；运行记录每次重启清空，崩溃诊断独立保留。
- Feat(reader): 新增“跨章节连续滚动”开关，关闭后每章独立滚动，章末通过翻页或目录进入下一章；即时保存，默认保留连续滚动（[#36](https://github.com/sobranie2406/modureader/issues/36)）。感谢 [@Wisso2278](https://github.com/Wisso2278) 提出建议。
- Fix(reader): 自动上下对齐和行距微调时保护带编号、边框等特殊排版的小标题，避免编号、竖线与标题文字错位；相关页面保留原排版，纯正文页继续对齐（[#34](https://github.com/sobranie2406/modureader/issues/34)）。感谢 [@Claire9518](https://github.com/Claire9518) 提供反馈和复现书籍。
- Fix(backup): 在主线程确定书库和缓存路径，再启动 ZIP 压缩，修复 Windows 数据库导出时设置未初始化的问题。
- Fix(storage): Windows 存储迁移改在重启后、数据库打开前执行，逐文件校验并保留原书库，复制成功后才切换路径。
- Fix(android): 设置导出先写入应用缓存，再调用系统保存窗口；区分文件读写、系统服务和设置格式错误，不再统一提示权限问题。

## Downloads / 下载

Nine packages, each with a SHA-256 checksum / 九个平台安装包及各自 SHA-256 校验文件：

- Android ARM64 — APK
- macOS ARM64 / x64 — DMG
- Windows ARM64 / x64 — EXE installer / 安装程序
- Linux ARM64 / x64 — DEB (Debian 13)
- iOS ARM64 — unsigned IPA / 未签名 IPA
- HarmonyOS ARM64 — unsigned native HAP / 未签名原生 HAP

Back up first, then upgrade without uninstalling or clearing your library. Android retains the project signing key. macOS is ad-hoc signed and not notarized. Windows requires WebView2. Linux targets Debian 13. iOS requires your own signing for the app and Share Extension; HarmonyOS requires a valid local certificate/profile. Models are downloaded or imported separately, not bundled.

建议先备份，再覆盖升级，不要卸载或清空书库。安卓沿用项目签名；macOS 为临时签名、未公证；Windows 需要 WebView2；Linux 面向 Debian 13；iOS 应用及分享扩展需自行签名，鸿蒙 HAP 需使用有效证书和配置签名安装。模型按需下载或离线导入，不内嵌安装包。

[Source / 源码](https://github.com/sobranie2406/modureader/tree/v1.2.10) · [Changes / 变更](https://github.com/sobranie2406/modureader/compare/v1.2.9...v1.2.10) · [Licenses / 许可](https://github.com/sobranie2406/modureader/blob/v1.2.10/NOTICE)
