# Modu 1.2.8 · Stable

## English

**Modu 1.2.8 (build 10124)** — changes since stable **1.2.7**.

- Perf(pdf): Prepare adjacent cropped/enhanced PDF pages before they enter the scroll viewport, reuse bounded full-panel backing images and refine zoomed details separately. Adapt one/two-panel lookahead to measured processing time and available device hints; cancel obsolete work, recycle bitmap URLs and preserve text/annotation coordinates.
- Fix(windows): Do not refocus the Flutter child window on deactivation or minimized activation messages; retain focus restoration on normal activation. Defensive correction for the reported selection-menu/Show Desktop scenario; the native crash is not yet reproduced or confirmed fixed.
- Fix(sync): Start automatic sync promptly on startup, foreground/unlock, network restoration and book exit after reading/narration writes finish. Persist unfinished requests for retry, preserve Jianguoyun interval/budget/cooldown and Wi-Fi-only rules, and do not acknowledge newer requests with an older upload.

- Feat(models): Add offline file import to embedding and OCR model settings. Accept only the existing catalogue's pinned size and SHA-256, validate the complete set before installation, and preserve model selection and books.
- Feat(tts): Remember and sync each book's exact narration range and playback state. Reopening restores its highlight in a paused state, without automatic speech. Older clients continue to sync reading positions but cannot restore narration state.
- Fix(tts): Follow long passages across page boundaries using system word offsets or an online audio-duration estimate. Retain the existing audio cache and page layout; same-page progress does not repeatedly scroll the reader.
- Fix(tts): Allow configured playback shortcuts in the narration panel and handle Xiaomi hardware keyboards reporting a visible, zero-height IME. Preserve text-editor guards and suppress held-key repeats for play/pause.
- Fix(reader): Follow Legado's pre-display page-finalization approach for horizontal prose: distribute spare height across actual lines, including two/three-line pages, while preserving chapter endings and explicit page breaks. Apply the new viewport width/height before measuring after rotation or resizing; page turns reuse the completed layout without post-display repositioning.
- Fix(harmony): Add a native reader keep-screen-on bridge and contain plugin failures; align export snapshot validation with path_provider's application cache instead of the ability cache, preserving original logs and path restrictions. Investigation of the bookshelf blank screen and chapter-load failure remains open ([#33](https://github.com/sobranie2406/modureader/issues/33)). Thanks [@xuezeyang123-hub](https://github.com/xuezeyang123-hub) for the report.
- Feat(ios): Add opt-in file/folder reading in place for EPUB, PDF, MOBI, AZW3 and FB2, retaining device-local access bookmarks without copying or automatically uploading originals. Keep ordinary import for formats requiring conversion; bookshelf deletion/replacement preserves originals ([#35](https://github.com/sobranie2406/modureader/issues/35)). Thanks [@wangxxisme](https://github.com/wangxxisme) for the suggestion.
- Fix(reader): Include reclaimed leading paragraph space when fitting full pages, and keep DIV paragraph spacing rules active after preparing page-alignment runs. Extend browser checks to production reader CSS and the slider's actual 3em/5em paragraph settings.
- Fix(reader): Keep individual scroll-line boundaries at small line spacing and zero paragraph spacing. Measure loaded font geometry and the available viewport before display, adjust scroll spacing without changing saved settings, and scale paginated edge alignment with text size. Page turns reuse prepared layout.
- Fix(settings): Restore Keyboard shortcuts under Settings → Reading, between page-turning controls and scroll settings. Keep the reader popup compact and preserve existing bindings, immediate saving and reset defaults.

**Packages:** Nine installers and nine SHA-256 files: Android ARM64, iOS ARM64, macOS/Windows/Linux ARM64 and x64, and HarmonyOS ARM64. Android x64 is not distributed.

**Installation:** Back up before upgrading; do not uninstall or clear the library. Android retains the project signing key and Android 8.0 minimum. iOS requires iOS 16+ and your own signing for the app and Share Extension. macOS uses ad-hoc signing without notarization; Windows requires WebView2; Linux targets Debian 13. HarmonyOS HAP is unsigned and requires a valid certificate/profile. Models are downloaded on demand or imported from verified catalogue-matching files.

**Known limits:** Windows crash prevention is a defensive correction, not a confirmed resolution of the reported native crash. HarmonyOS bookshelf/chapter failures remain under investigation. Online narration estimates progress from audio duration where word timings are unavailable. Fast PDF jumps can outpace prefetch.

[Source](https://github.com/sobranie2406/modureader/tree/v1.2.8) · [Changes since 1.2.7](https://github.com/sobranie2406/modureader/compare/v1.2.7...v1.2.8) · [Installation guide](https://github.com/sobranie2406/modureader/blob/v1.2.8/docs/RELEASING.md)

---

## 简体中文

**Modu 1.2.8（构建 10124）**，以下为 **1.2.7 正式版以来**的变化。

- Perf(pdf): PDF 相邻页提前完成裁边与图像增强，进入滚动区域即可显示，复用有尺寸上限的整页／分格底图，放大后再补充局部高清细节。结合实际处理耗时及设备信息自动调整提前一至两个阅读区域，取消失效任务并回收图片缓存，保留文字层和批注坐标。
- Fix(windows): 窗口失去激活或处于最小化状态时，不再主动把焦点设回 Flutter 子窗口；正常激活时保留焦点恢复。针对划词菜单打开后“显示桌面”场景进行防护修正，原生崩溃尚未复现或确认修复。
- Fix(sync): 启动、回到前台／解锁、恢复网络及退出书籍时尽快自动同步；退出先等待阅读与朗读位置写入完成，未完成请求持久化后自动补同步，保留坚果云间隔／预算／冷却及仅 Wi-Fi 限制，旧上传完成不清除新请求。

- Feat(models): 向量模型和 OCR 模型设置增加离线文件导入，仅接受现有型号及固定版本，完整文件组通过大小与 SHA-256 校验后才安装，保留当前模型选择与书籍数据。
- Feat(tts): 按书籍独立记忆并同步精确朗读位置、高亮范围和播放状态，重新打开时恢复高亮并保持暂停，不自动出声。旧客户端仍可同步阅读进度，但不能恢复朗读状态。
- Fix(tts): 长段落跨页时按系统字词进度或在线音频时长比例估算跟随翻页，保留已有缓存和页面排版，页内播放进度不反复滚动页面。
- Fix(tts): 朗读面板内支持已配置的播放快捷键，修复小米外接键盘将零高度输入法报告为可见、导致空格键被拦截的问题；保留文本输入保护，长按播放／暂停键不重复切换。
- Fix(reader): 参考 Legado 在显示前完成分页对齐的思路，左右翻页按实际行位置分配剩余高度，补齐两三行正文页的对齐，保留章节末页及显式分页留白；旋转屏幕或改变窗口时先应用新的可用宽高再测量，翻页复用已完成的排版，不在显示后补调位置。
- Fix(harmony): 补齐鸿蒙阅读常亮原生通道并处理插件失败；导出文件快照按 path_provider 使用的应用级缓存目录校验，避免与 Ability 级缓存目录不一致，保留原日志与路径安全限制。书架空白及章节加载失败仍在排查（[#33](https://github.com/sobranie2406/modureader/issues/33)）。感谢 [@xuezeyang123-hub](https://github.com/xuezeyang123-hub) 反馈。
- Feat(ios): 新增文件／文件夹“原位添加”，EPUB、PDF、MOBI、AZW3、FB2 可不复制原书直接阅读，并保存本机访问授权；原书不自动上传或纳入备份，需转换格式的书籍仍用普通导入，书架删除／替换保留外部原书（[#35](https://github.com/sobranie2406/modureader/issues/35)）。感谢 [@wangxxisme](https://github.com/wangxxisme) 提出建议。
- Fix(reader): 顶底对齐计算纳入页首段距释放的空间，避免大行距、大段距正文页被误判跳过；修复 DIV 正文加入排版节点后丢失段落样式的问题，补测实际阅读 CSS 及段距滑块对应的 3em／5em 设置。
- Fix(reader): 修复小行距、零段间距时只能在部分段尾停靠的问题。显示前根据已加载字体和实际可用阅读区域计算滚动行距，保留保存的设置；左右翻页的顶底对齐按实际字号调整，翻页时复用已完成的排版。
- Fix(settings): 恢复“设置 → 阅读”中的自定义按键入口，位于翻页方式下方、滚动设置上方；阅读弹窗保持精简，保留已有按键配置、即时保存和恢复默认。

**安装包：**9 个程序包及 9 个 SHA-256 校验文件：Android ARM64、iOS ARM64、macOS／Windows／Linux ARM64 与 x64，以及 HarmonyOS ARM64。不发布 Android x64。

**安装：**建议备份后覆盖升级，不要先卸载或清空书库。Android 沿用项目签名，最低支持 Android 8.0；iOS 要求 iOS 16+，需自行签名应用及分享扩展；macOS 为临时签名，未公证；Windows 需要 WebView2；Linux 面向 Debian 13。HarmonyOS HAP 未签名，需有效证书／Profile。模型按需下载或导入与型号固定版本一致、经校验的文件。

**已知限制：**Windows 为防护修正，不能视为已确认解决所报告的原生崩溃。鸿蒙书架空白／章节加载失败仍在排查。在线朗读无字词时间戳时按音频时长估算跟随；快速跳转 PDF 时仍可能超出预缓存。

[源码](https://github.com/sobranie2406/modureader/tree/v1.2.8) · [1.2.7 以来的变化](https://github.com/sobranie2406/modureader/compare/v1.2.7...v1.2.8) · [安装说明](https://github.com/sobranie2406/modureader/blob/v1.2.8/docs/RELEASING.md)
