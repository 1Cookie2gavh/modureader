# Modu 1.3.2

Build / 构建：**10157** · Stable / 正式版

### English

- Feat(appearance): Add Auto / Wide / Narrow interface layout choices, preserving the existing automatic width threshold and reader column settings.

- Feat(selection): Extend selections within an ebook chapter by dwelling at the page edge. Freeze the endpoint at the next/previous page boundary until release and a fresh handle drag; in scrolling mode, extend with capped, edge-sensitive auto-scroll that stops on release. Keep the opposite endpoint fixed and publish the selection toolbar after dragging; fixed-layout PDF selection remains unchanged.

- Feat(reader): Add an Auto-align scrolling switch, enabled by default. Preserve the existing directional alignment when enabled; when disabled, stop freely without forced line snapping. Apply changes immediately and include the preference in settings backup.

- Feat(bookshelf): Long-press and drag books to create a named folder, move into an existing folder, or drop outside an open folder to return to the shelf. Dragging a checked book carries all checked books with a count badge. Preserve normal taps, batch menus and book data; failed moves retain the selection.

- Feat(reader): Customize top-toolbar visibility and order in Reading settings. Fit enabled actions and More within 40% of the reading area's usable width, adapting to rotation and window resizing without shrinking touch targets; place remaining actions in More, with Back separate. Add Classical Chinese ↔ Modern Chinese translation using AI, Baidu's official API or Microsoft Translator, configured under Translation. Ordinary and PDF/OCR reflow reading support translation-only/bilingual output, visible-paragraph loading and immediate cancellation; reflow translations never overwrite OCR edits or notes.

- Feat(translation): Split Translation settings into Language translation and Classical Chinese translation entries using the shared settings-card style. Add independent Classical Chinese output font (including imported fonts), size, bold and italic controls with a preview and settings backup support. Update existing and future output in ordinary and PDF/OCR reflow reading without changing source styling or making another translation request.

- Feat(translation): Add separate font, size, bold, italic and preview controls for ordinary language translation. Keep language and Classical Chinese appearance preferences independent, applying them only to their own output in ordinary and PDF/OCR reflow reading; preserve original text and update cached output without another translation request.

- Fix(harmony): Raise the native loopback HTTP response limit from 5 MiB to 100 MiB for local book loading; keep remote requests and other platforms unchanged.

- Fix(harmony): Connect file sharing to the HarmonyOS system share sheet, retaining temporary file snapshots for receiving apps instead of using the unsupported plugin path.

- Fix(harmony): Keep database reads and writes on the same native transaction so saved reading progress does not return a stale revision and pull the reader back after a page turn. Preserve conflict protection and other platforms.

- Fix(sync): Record file replacements received through sync and clean up verified, unreferenced local old versions only after the current book is available and checksum-valid. Preserve failed downloads, trash references, active reading files and unknown files; reuse verified replacement history for older leftovers ([#61](https://github.com/sobranie2406/modureader/issues/61)). Thanks [@ndd200](https://github.com/ndd200) for the report.

- Fix(reader): Keep the home screen's safe-area geometry stable while the reader hides system bars and during return, avoiding the late bookshelf jump when bars reappear. Preserve cover transitions, reader fullscreen behavior, keyboard insets and window resizing.

- Fix(ai): Keep the chat composer's rounded border inside the screen safe area, with outer side and bottom spacing even in fullscreen reading. Preserve keyboard avoidance and input controls.

- Fix(translation): Keep Classical Chinese and language translation controls and running indicators separate, including reflow reading. Accept integral numeric session IDs from Apple's web bridge instead of silently dropping paragraph requests; preserve cancellation and reject malformed IDs. Keep cached translations when AI keys rotate and retain the active display mode when reopening translation settings.

- Fix(translation): Reflow text when paragraph translations appear, switch display mode or stop. Clear stale page-alignment offsets and keep translated pages in natural flow so original and translated lines do not overlap; preserve alignment on untranslated pages.

- Fix(selection): Use one pair of touch-selection handles on Android and iOS. Keep cross-page endpoints re-grabbable outside system edge gestures, preserve the opposite anchor and leave desktop mouse selection and fixed-layout PDF interaction unchanged.

- Perf(reader): Scope page-progress and bookmark refreshes to reader controls, reuse the reader during menu updates, skip duplicate menu visibility rebuilds, cache reading themes with edit/restore invalidation, and share battery polling across metadata slots with background suspension. Preserve navigation animations, pagination, narration and progress persistence.

- Ci(tooling): Include the vendored analyzer's required generated visitor in clean checkouts so lint checks do not depend on local build leftovers.

### 简体中文

- Feat(appearance): 外观新增「自动／宽屏版／窄屏版」界面布局选项，保留原有自动适配阈值，不改变阅读正文的单双列设置。

- Feat(selection): 普通电子书同章节内拖动选区至页边停留可向前／向后翻页，翻页后端点停在新页交界处，松手并重新拖动手柄后继续扩选；滚动模式按靠近边缘的程度限速滚动，松手即停。固定另一端点，拖动结束后显示划词工具栏；PDF 原页选词保持不变。

- Feat(reader): 新增「滚动翻页自动对齐」开关，默认开启并保留原有方向对齐逻辑；关闭后可自由停留，不再强制对齐文字行。修改即时生效，并随设置备份保存。

- Feat(bookshelf): 长按拖动书籍可合并新建命名文件夹、移入已有文件夹，或从打开的文件夹拖到框外移回书架；拖动已勾选书籍时携带全部勾选书籍并显示数量。保留普通点击、批量菜单与书籍数据，移动失败保留勾选状态。

- Feat(reader): 阅读设置新增顶部按钮显隐与排序，功能区（含「更多」）最多占阅读区域可用宽度的 40%，随旋转及窗口大小变化自动调整数量，不缩小点击区域；其余功能放入「更多」，返回按钮独立保留。翻译设置新增文言文与现代汉语双向互译，支持 AI、百度官方接口及微软 Translator；普通书籍和 PDF/OCR 重排均支持仅译文／原文对照、可见段落逐段加载及实时停止，重排译文不覆盖 OCR 编辑稿和笔记。

- Feat(translation): 翻译设置拆分为「语种翻译」「文言文翻译」两个入口，统一设置行与圆角阴影卡片样式；文言文译文支持独立字体（含已导入字体）、字号、粗体与斜体，提供预览并纳入设置备份。普通阅读和 PDF/OCR 重排中的已有及后续译文均应用样式，不改动原文样式，不重新请求翻译。

- Feat(translation): 语种翻译增加独立字体、字号、粗体、斜体及预览，与文言文译文外观分别保存、互不联动；覆盖普通阅读及 PDF/OCR 重排，只调整对应译文，保留原文，已有译文更新样式无需重新请求。

- Fix(harmony): 鸿蒙本机书籍加载请求的响应上限由 5 MiB 调整为 100 MiB，远程请求及其他平台保持不变。

- Fix(harmony): 文件分享接入鸿蒙系统分享面板，保留供接收应用读取的临时文件副本，不再调用缺少鸿蒙实现的插件路径。

- Fix(harmony): 数据库读写统一使用同一个原生事务，修复保存阅读进度时读回旧版本、导致翻页后被拉回上一页的问题；保留同步冲突保护，其他平台不变。

- Fix(sync): 记录同步接收的书籍文件替换，仅在当前版本已下载且校验通过后，清理校验一致、无任何引用的本地旧版本；保留下载失败、回收站引用、正在阅读及来源不明的文件，并复用已验证的替换历史处理旧残留（[#61](https://github.com/sobranie2406/modureader/issues/61)）。感谢 [@ndd200](https://github.com/ndd200) 报告问题。

- Fix(reader): 阅读隐藏系统栏期间及返回时保持首页安全区布局稳定，避免状态栏稍后恢复导致书架整体抖动；保留封面过渡、阅读全屏、键盘避让和窗口尺寸适配。

- Fix(ai): AI 对话输入框的安全区留白移至圆角框外侧，全屏阅读时也保留两侧与底部间距，避免边框被屏幕边缘裁切；保留键盘避让及输入操作。

- Fix(translation): 分开文言文翻译与语种翻译的操作入口及运行状态，覆盖重排阅读；兼容 Apple 网页桥接返回的小数形式整数会话编号，避免逐段翻译请求被静默丢弃，同时保留取消机制并拒绝异常编号。AI 密钥轮换不再清空译文缓存，重新打开翻译设置时保持当前显示方式。

- Fix(translation): 逐段译文插入、显示方式切换及停止时重新排版，清除旧的页内对齐偏移；含译文的页面保持正常行流，避免原文与译文重叠，未翻译页面保留原有对齐。

- Fix(selection): Android 与 iOS 统一为一套触摸选区手柄，跨页后手柄避开系统边缘手势区，可松手重新拖动；保留另一端起点，桌面鼠标选择和 PDF 原页交互保持不变。

- Perf(reader): 翻页进度与书签改为局部刷新，菜单更新时复用阅读组件、跳过重复显隐刷新；阅读主题缓存随编辑和数据库恢复失效，页眉页脚共享电量查询并在后台暂停。保留原有过渡动画、排版、朗读和进度保存逻辑。

- Ci(tooling): 补齐内置分析器必需的生成访问器文件，确保干净检出可执行 lint 检查，不依赖本机构建残留。

## Downloads / 下载

Nine packages, each with a SHA-256 checksum / 九个平台安装包及各自 SHA-256 校验文件：

- Android ARM64 — APK
- macOS ARM64 / x64 — DMG
- Windows ARM64 / x64 — EXE installer / 安装程序
- Linux ARM64 / x64 — DEB (Debian 13)
- iOS ARM64 — unsigned IPA / 未签名 IPA
- HarmonyOS ARM64 — unsigned native HAP / 未签名原生 HAP

Back up first, then upgrade without uninstalling or clearing your library. Sync remains on protocol v9. Android retains the project signing key. macOS is ad-hoc signed and not notarized. Windows requires WebView2. Linux targets Debian 13. iOS requires your own signing for the app and Share Extension; HarmonyOS requires a valid local certificate/profile. Models are downloaded or imported separately, not bundled.

建议先备份，再覆盖升级，不要卸载或清空书库。同步协议仍为 v9。安卓沿用项目签名；macOS 为临时签名、未公证；Windows 需要 WebView2；Linux 面向 Debian 13；iOS 应用及分享扩展需自行签名，鸿蒙 HAP 需使用有效证书和配置签名安装。模型按需下载或离线导入，不内嵌安装包。

[Source / 源码](https://github.com/sobranie2406/modureader/tree/v1.3.2) · [Changes / 变更](https://github.com/sobranie2406/modureader/compare/v1.3.1...v1.3.2) · [Licenses / 许可](https://github.com/sobranie2406/modureader/blob/v1.3.2/NOTICE)
