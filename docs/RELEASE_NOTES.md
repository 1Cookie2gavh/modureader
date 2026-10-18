# Modu 1.2.11

Build / 构建：**10149** · Stable / 正式版

### English

- PDF and scanned books: 1–4× pinch zoom, desktop rectangle zoom, panning and per-page zoom/position memory. Crop, fit and rotation work together; the draggable zoom bar uses 80% transparency and hides after five idle seconds.
- Organize PDF controls as Contents, Notes, Text, Page and Brightness. Group crop, panels, zoom, fit, rotation and image enhancement under Page; pin the crop preview above independently scrolling options and use illustrated panel choices.
- Automatically use embedded text when available and OCR otherwise. Reflow shares ebook styles and menus, with horizontal alignment, balanced margins and larger original-page navigation buttons.
- Save OCR results and corrections by original page in one book cache. Reopening reuses saved text; missing pages are recognized automatically. Edit in reflow/extraction tools and export saved pages directly from Text as UTF-8 TXT with original page numbers and separators ([#42](https://github.com/sobranie2406/modureader/issues/42)). Thanks [@seightday](https://github.com/seightday) for the suggestion.
- Optional serial background prefetch covers the current original page and up to four following pages in original and reflow reading. Reuse existing OCR and corrections, let the in-flight page finish across page turns, then update the queue from the latest page. Cache progress counts saved pages and corrections.
- Sync saved OCR, corrections and retained annotation revisions with downloaded original books. Books not downloaded locally do not fetch OCR caches; downloading the original also retrieves saved text.
- Confirm before re-recognizing a page. Replace recognition and corrections only after success; retain earlier notes and their original-image positions.
- Improve long-press word selection, round draggable handles and selection highlight height. Refine the draggable, transparent narration toolbar and its icon controls.
- Drag-only settings sliders retain tap-to-seek for reading progress ([#40](https://github.com/sobranie2406/modureader/issues/40)). Thanks [@ndd200](https://github.com/ndd200). Crop scope, model download sources and update sources use direct choices.
- Start bookshelf sync directly and restore global settings export with the legacy system-theme value. Feedback can preview and include sanitized current-session Advanced Logs, reset on restart.
- HarmonyOS: preserve reader URL parameters for imports ([#33](https://github.com/sobranie2406/modureader/issues/33)) and use native database snapshots before sync merges ([#41](https://github.com/sobranie2406/modureader/issues/41)). Thanks [@xuezeyang123-hub](https://github.com/xuezeyang123-hub) for reporting and testing.
- iOS: add optional volume-change paging through the existing reader controls.

Nine packages: Android ARM64, iOS ARM64, HarmonyOS ARM64, macOS x64/ARM64, Windows x64/ARM64 and Linux x64/ARM64, each with a SHA-256 file. iOS IPA and HarmonyOS HAP are unsigned and require signing before installation.

### 简体中文

- PDF／扫描书新增 1–4 倍双指缩放、桌面框选放大、拖动及逐页倍数和位置记忆；裁边、适配、旋屏联动。缩放浮动条可拖动，80% 透明，闲置 5 秒自动隐藏。
- PDF 底栏整合为目录、笔记、文字、页面和亮度。页面内归拢裁边分格、缩放、适配、旋屏和图像增强；裁边预览固定在顶部，下方选项独立滚动，分格数量使用示意图点选。
- 自动优先读取文字层，无文字层时执行 OCR；重排沿用电子书样式和菜单，改进左右对齐、对称边距，加大原书页码翻页按钮。
- OCR 结果和校对稿按原书页码保存在每本书一个缓存文件中。再次打开优先读取已保存文字，无缓存时自动识别；在重排／提取工具中编辑，文字一级菜单可直接导出按“原页码＋分隔线＋内容”排列的 UTF-8 TXT（[#42](https://github.com/sobranie2406/modureader/issues/42)）。感谢 [@seightday](https://github.com/seightday) 提出建议。
- 可选后台预缓存当前原书页及后续页面，共 1–5 页，原页及重排界面均持续工作。已有 OCR 和校对稿直接复用，翻页时先完成正在处理的页面，再按最新页码更新队列；进度将已有缓存与校对稿计入已处理。
- OCR 缓存、校对稿及笔记引用版本随已下载原书同步；未下载原书不拉取缓存，下载原书时一并获取已保存文字。
- 重新识别本页前明确确认，成功后才替换识别和校对结果；保留旧笔记及原图位置。
- 优化长按扩词、圆点拖动手柄及选区高亮高度；完善可拖动、透明的朗读浮动栏和纯图标控制。
- 设置滑块仅拖动调节，阅读进度保留点击跳转（[#40](https://github.com/sobranie2406/modureader/issues/40)）。感谢 [@ndd200](https://github.com/ndd200)。裁边应用范围、模型下载源及更新源改为直接点选。
- 点击书架同步按钮直接开始同步，修复旧版跟随系统主题值导致的全局设置导出失败。问题反馈可预览并附带脱敏的本次启动高级日志，重启后清空。
- 鸿蒙：导入保留阅读器网址参数（[#33](https://github.com/sobranie2406/modureader/issues/33)），同步合并前采用原生数据库备份接口（[#41](https://github.com/sobranie2406/modureader/issues/41)）。感谢 [@xuezeyang123-hub](https://github.com/xuezeyang123-hub) 反馈与测试。
- iOS：通过现有阅读控制接入可选音量变化翻页。

提供安卓 ARM64、iOS ARM64、鸿蒙 ARM64、macOS x64/ARM64、Windows x64/ARM64、Linux x64/ARM64 九个平台包及 SHA-256 校验文件。iOS IPA、鸿蒙 HAP 为未签名包，安装前需要签名。
