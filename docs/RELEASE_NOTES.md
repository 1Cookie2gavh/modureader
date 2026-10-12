# Modu 1.2.7 · Stable

## English

**Modu 1.2.7 (build 10116)** — changes since stable **1.2.6**.

- Feat(history): Add an edit-only Reset button to restore the default reading-history cards and their order, saving immediately without deleting reading records ([#32](https://github.com/sobranie2406/modureader/issues/32)). Thanks [@ndd200](https://github.com/ndd200) for the suggestion.
- Fix(pdf): Fix next/previous source-page navigation in text/OCR reflow: pass the page number through the reader navigation API so successful extraction is not incorrectly reported as a reflow failure.
- Feat(pdf): Add multi-page text extraction with printer-style page ranges, sequential local OCR, completed-page reuse and cancellable retry. Navigate directly between extracted-page previews without returning to the image view; keep extraction into AI as a draft.
- Fix(reader): Align ordinary horizontal text pages to the configured top and bottom margins before display, with bounded spacing adjustments and natural chapter endings. Scroll steps and settled gestures prefer complete lines: prioritize the bottom edge going down and the top edge going up when both cannot fit. Do not hide edge text or reflow after page turns. Verified on an Android test device; other native platforms remain unverified.
- Perf(reader): Prepare and cache scroll-line geometry during layout instead of scanning chapter text on every scroll step. Invalidate it after layout/content changes and reuse document-local positions across adjacent chapters. Find only the visible boundary nodes when updating reading position, avoiding per-glyph measurements across the whole page.
- Perf(reader): Animate horizontal pages using a compositor transform, committing the scroll position once at completion. Retain immediate E-Ink/disabled-motion behaviour and the existing fallback for unsupported engines and vertical/continuous reading.
- Fix(harmony): Repair the log export menu and use the native document-save picker for file exports. Report success only after writing completes, handle cancellation and errors, and preserve original files. HarmonyOS physical-device verification remains pending.
- Fix(harmony): Use the current MODU artwork for the launcher and start window. Stage sync archives in the database directory required by the OHOS SQLite adapter, with unique names and disposable copies; retain integrity checks and merge protections. Add sanitized database failure diagnostics. Physical-device sync verification is pending.
- Fix(reader): Fit quick style panels to their content with an 80% height limit, keeping long settings scrollable and the bottom toolbar reachable. Hide the top toolbar while an expanded bottom tool panel is open.
- Feat(ui): Shorten the Chinese home navigation labels for Remote Library and Reading History to two characters, preserving typography, full page titles and other language labels.
- Feat(settings): Save lookup switches/order, dictionary selections, existing selection-tool options, AI model parameters and skill toggles, per-book indexing models, CSS edits and PDF/OCR text styles without a separate Save step. Keep validation, retry feedback and explicit confirmation for connection drafts, new templates and destructive actions.
- Feat(ui): Add translucent, draggable scrollbars across lists, settings, Lookup and scrollable dialogs; show during scrolling and hide after 1.2 seconds idle. Isolate nested and side-by-side scroll positions, reserve a drag lane beside controls, and leave horizontal scrolling without a scrollbar. Web panels and continuous reading also gain transient scrollbars; pagination stays unchanged and E-Ink skips fading.
- Feat(reader): Match reading-style and PDF settings panel sizes to Lookup; move CSS to its own tab between Style and Other, and remove duplicate selection-toolbar, automatic-summary and keyboard-shortcut entries from the reader panel.
- Chore(dev): Clean up static analysis and migrate legacy custom_lint to an isolated Riverpod native plugin compatible with the current Flutter/Dart toolchain, preserving Riverpod 2 runtime behavior and context-safety checks.
- Fix(pdf): Keep original-page navigation available after text/OCR reflow fails. Left/right arrows start reflow for the adjacent source page instead of repeatedly requesting the same failed page; retry and mode switching target the attempted page while reading progress changes only on success.
- Feat(appearance): Control book-format and indexed labels independently in Appearance; both default to on. Match indexed-label typography and padding to format labels without hiding indexing progress or failure notices.
- Feat(bookshelf): Switch between thumbnails and a cover-free list from the bookshelf toolbar; remember the layout and retain book metadata, folder counts, long-press selection and batch actions.
- Feat(lookup): Customize the overview order of Dictionary, Encyclopedia, Translation and AI Knowledge by dragging in Lookup settings. Remember the order locally, retain positions for disabled sources, and keep optional query-text ordering.
- Feat(appearance): Add an E-Ink-only "Disable all animations" switch, disabled outside E-Ink mode. Keep animation suppression enabled by default; turning it off restores saved animation preferences without changing the monochrome palette or hardware refresh settings.


**Packages:** Nine installers with nine SHA-256 files: Android ARM64, iOS ARM64, macOS/Windows/Linux ARM64 and x64, and HarmonyOS ARM64. Android x64 is not distributed.

**Installation:** Back up before upgrading; do not uninstall or clear the library. Android retains the project signing key and Android 8.0 minimum. iOS requires iOS 16+ and your own signing for the app and Share Extension. macOS uses ad-hoc signing without notarization; Windows requires WebView2; Linux targets Debian 13. HarmonyOS HAP is unsigned and requires a valid certificate/profile. Models are downloaded on demand.

**Validation and limits:** Android paging/scrolling and OCR reflow navigation were tested on a physical device. History reset has automated regression coverage. Package generation does not replace device acceptance; HarmonyOS file export/sync and other native platforms still need device validation. Flutter retains the required deprecated `android.newDsl=false` compatibility flag; the reader bundle retains three legacy-target top-level-await warnings. Continuous extraction keeps results in its local window; extraction into AI retains the existing draft behavior.

[Source](https://github.com/sobranie2406/modureader/tree/v1.2.7) · [Changes since 1.2.6](https://github.com/sobranie2406/modureader/compare/v1.2.6...v1.2.7) · [Installation guide](https://github.com/sobranie2406/modureader/blob/v1.2.7/docs/RELEASING.md)

---

## 简体中文

**Modu 1.2.7（构建 10116）**，以下为 **1.2.6 正式版以来**的变化。

- Feat(history): 阅读历史卡片编辑状态新增“恢复默认”按钮，还原默认卡片组合与排列顺序并立即保存，不删除阅读记录（[#32](https://github.com/sobranie2406/modureader/issues/32)）。感谢 [@ndd200](https://github.com/ndd200) 提出建议。
- Fix(pdf): 修复文字／OCR 重排结果切换上一页、下一页失败；按阅读器导航接口传递原版页码，避免提取成功后因原页定位失败而误报重排失败。
- Feat(pdf): 提取文字新增「连续识别」，支持打印机式页码范围、逐页本地 OCR、已完成结果复用和停止后重试；文字预览可直接切换上一页／下一页，无需返回原图。提取至 AI 仍沿用填入草稿的行为。
- Fix(reader): 普通横排正文在显示前小幅调整间距，对齐设置的上下边距，章节末页保留自然留白；滚动翻屏及手势停稳时优先停在完整行，两端无法兼顾时向下以下端为主、向上以上端为主。不隐藏边缘文字，也不在翻页后重排正文。已在安卓测试机验证，其他原生平台仍待实测。
- Perf(reader): 排版时提前计算并缓存滚动行位置，避免每次翻屏扫描整章；排版或正文变化时使缓存失效，相邻章节移动时复用章内坐标。更新阅读位置只查找可见首尾节点，避免逐字测量整页。
- Perf(reader): 左右翻页使用合成层平移动画，结束时一次性提交滚动位置；保留 E-Ink／禁用动画时立即翻页，以及旧引擎、竖排和连续滚动的原有处理。
- Fix(harmony): 修正日志导出菜单，文件导出改用鸿蒙原生保存窗口；写入完成后才提示成功，处理取消和失败并保留原文件。仍待鸿蒙实机验证。
- Fix(harmony): 鸿蒙桌面与启动窗口使用现有 MODU 图标；同步数据库改在鸿蒙 SQLite 插件要求的数据库目录内通过独立副本读写，使用唯一文件名，保留完整性校验与合并保护，并补充脱敏数据库错误诊断。同步仍待鸿蒙实机复测。
- Fix(reader): 阅读快捷样式面板按内容收缩，最高占屏幕 80%，长内容可滚动且底部工具栏保持可操作；展开下方工具面板时隐藏上方工具栏。
- Feat(ui): 首页中文导航将“远程书库”和“阅读历史”缩短为“远程”和“历史”，保留原字体字号、页面完整标题及其他语言名称。
- Feat(settings): 综合查询开关与排序、词典选择、已有划词工具选项、AI 模型参数与技能开关、单书索引模型、CSS 编辑及 PDF/OCR 文字样式无需另点保存；保留校验、失败重试以及连接草稿、新建模板和破坏性操作的确认。
- Feat(ui): 列表、设置、综合查询和可滚动弹窗统一增加半透明、可拖动滚动条，滚动时显示，停止操作 1.2 秒后隐藏；嵌套及并排列表独立控制，控件旁预留拖动区域，横向滑动不显示滚动条。内嵌网页与正文连续滚动模式同样支持，分页保持不变，E-Ink 下不播放淡入淡出动画。
- Feat(reader): 阅读样式与 PDF 设置面板尺寸对齐综合查询；CSS 独立为“样式”和“其他”之间的标签，移除阅读面板中的划词工具栏、自动总结前文及键盘快捷翻页入口。
- Chore(dev): 清理静态分析提示，将旧 custom_lint 迁移为兼容当前 Flutter/Dart 的隔离式 Riverpod 原生分析插件，保留 Riverpod 2 运行逻辑及上下文安全检查。
- Fix(pdf): 修复文字／OCR 重排失败后无法继续翻页的问题；左右箭头按原版页码启动相邻页重排，不再反复卡在同一失败页。重试和切换重排模式针对待处理页，仅成功后更新阅读进度。
- Feat(appearance): 外观设置支持独立开关书籍格式与已索引标签，均默认开启；已索引标签的字号和内边距与格式标签一致，不隐藏索引进度或失败提示。
- Feat(bookshelf): 书架首页新增缩略图／无封面列表切换，记忆布局选择，保留书籍信息、文件夹数量、长按多选和批量操作。
- Feat(lookup): 综合查询设置支持拖动调整字典、百科、翻译、AI 知识的汇总顺序，本机记忆设置；关闭来源仍保留位置，保留可选的查询文本智能排序。
- Feat(appearance): 在 E-Ink 模式下增加「关闭所有动画」总开关，未开启 E-Ink 时置灰。默认仍关闭动画；关闭此开关后恢复原有动画设置，不改变黑白显示与硬件刷新设置。

**安装包：**9 个程序包及 9 个 SHA-256 校验文件：Android ARM64、iOS ARM64、macOS／Windows／Linux ARM64 与 x64，以及 HarmonyOS ARM64。不发布 Android x64。

**安装：**建议备份后覆盖升级，不要先卸载或清空书库。Android 沿用项目签名，最低支持 Android 8.0；iOS 要求 iOS 16+，需自行签名应用及分享扩展；macOS 为临时签名，未公证；Windows 需要 WebView2；Linux 面向 Debian 13。HarmonyOS HAP 未签名，需有效证书／Profile。模型按需下载。

**验证与限制：**分页、滚动及 OCR 重排翻页已在安卓实机验证；历史恢复默认有自动回归覆盖。包构建不替代设备验收，鸿蒙日志导出／同步及其他原生平台仍待实测。Flutter 保留必需的 `android.newDsl=false` 弃用兼容开关；阅读器打包仍有三条旧目标 top-level-await 提示。连续提取结果保留在当前本地窗口，提取至 AI 沿用填入草稿的行为。

[源码](https://github.com/sobranie2406/modureader/tree/v1.2.7) · [1.2.6 以来的变化](https://github.com/sobranie2406/modureader/compare/v1.2.6...v1.2.7) · [安装说明](https://github.com/sobranie2406/modureader/blob/v1.2.7/docs/RELEASING.md)
