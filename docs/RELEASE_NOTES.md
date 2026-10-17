# Modu 1.2.11 Beta3

Build / 构建：**10139** · Pre-release / 测试版

### English

- Save OCR results and corrections in one local book cache indexed by original PDF page. Reopening reuses saved text; missing pages are recognized automatically. Edit page text and export saved pages as UTF-8 TXT with original page numbers and separators ([#42](https://github.com/sobranie2406/modureader/issues/42)). Thanks [@seightday](https://github.com/seightday) for the suggestion.
- Confirm before re-recognizing a page. Replace saved recognition and edits only after success; retain earlier notes and their source-page positions.
- OCR reflow uses ebook layout settings, with unsupported controls disabled. Improve horizontal alignment, symmetric margins, PDF style controls and nested reading menus.
- Cache paragraph word boundaries for long-press word selection. Retain round draggable handles without expanding manually adjusted ranges; suppress duplicate Android selection menus and excess highlight height.
- Match the narration stop icon to the other toolbar buttons, without a separate background. Retain the draggable, 80% transparent toolbar.
- Start manual bookshelf sync directly without the status dialog.
- Export settings saved with the legacy `auto` system theme value.
- Drag-only settings sliders; reading progress retains tap-to-seek ([#40](https://github.com/sobranie2406/modureader/issues/40)). Thanks [@ndd200](https://github.com/ndd200).
- Reader layout optimizations, anonymous chapter timings, renderer recovery, and native blue selection handles.
- Preserve HarmonyOS loopback reader URL parameters for imports ([#33](https://github.com/sobranie2406/modureader/issues/33)). Thanks [@xuezeyang123-hub](https://github.com/xuezeyang123-hub).

Packages: Android ARM64, iOS ARM64, HarmonyOS ARM64, macOS x64/ARM64, Windows x64/ARM64 and Linux x64/ARM64, with SHA-256 files. iOS IPA and HarmonyOS HAP are unsigned and require signing before installation. This beta does not replace the latest stable release.

### 简体中文

- OCR 结果及校对稿按 PDF 原始页码保存在每本书一个本地缓存文件中。再次打开优先读取已保存文字，无缓存时自动识别；支持编辑本页文字，并按“原页码＋分隔线＋内容”导出 UTF-8 TXT（[#42](https://github.com/sobranie2406/modureader/issues/42)）。感谢 [@seightday](https://github.com/seightday) 提出建议。
- 重新识别本页前明确确认，成功后才替换识别及编辑结果；失败保留旧稿，旧笔记及原图位置保留。
- OCR 重排复用普通电子书排版设置，不适用项置灰；调整左右对齐、对称边距、PDF 样式及二三级阅读菜单。
- 提前缓存段落词边界，长按文字直接选中完整词；保留圆点拖动手柄，手动调整不再自动扩词，抑制安卓重复选字浮窗和过高的选区高亮。
- 朗读停止图标与其他按钮保持一致，不单独添加背景；保留浮动栏拖动和80%透明背景。
- 点击书架同步按钮直接开始同步，不再弹出同步面板。
- 修复旧版“跟随系统”主题值导致全局设置导出失败。
- 设置滑块仅拖动调节，阅读进度条保留点击跳转（[#40](https://github.com/sobranie2406/modureader/issues/40)）。感谢 [@ndd200](https://github.com/ndd200)。
- 阅读排版计算优化，补充匿名章节耗时、渲染器重载恢复及原生蓝色选字手柄。
- 鸿蒙阅读器本地加载保留网址参数，修复相关导入失败（[#33](https://github.com/sobranie2406/modureader/issues/33)）。感谢 [@xuezeyang123-hub](https://github.com/xuezeyang123-hub)。

提供安卓 ARM64、iOS ARM64、鸿蒙 ARM64、macOS x64/ARM64、Windows x64/ARM64、Linux x64/ARM64 九个平台包及 SHA-256 校验文件。iOS IPA、鸿蒙 HAP 为未签名包，安装前需要签名。本次为测试版，不替代最新正式版。
