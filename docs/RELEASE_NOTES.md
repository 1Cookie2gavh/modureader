# Modu 1.3.4

Build / 构建：**10165** · Stable / 正式版

### English

- Feat(tts): Use compact minus/value/plus controls for pitch (0.5–2.0×) and speed (0.1–4.0×), with direct input and 0.1 steps. Give each half the row, centering labels above their controls on narrow screens and beside them when space allows.

- Fix(tts): Apply Xiaomi MiMo pitch through Android playback so individual levels affect buffered speech without resynthesis; retain pitch and speed across pause, resume and segment changes. Other platforms send distinct pitch instructions where supported.

- Perf(reader): Batch adjacent generated text-run measurements, remove duplicate position refreshes after layout and skip unchanged continuous-reading styles; preserve text, selection and navigation behavior.

- Perf(harmony): Coalesce continuous-scroll position measurements while keeping chapter preloading responsive and flushing the final position.

- Fix(sync): Restore newer synchronized reading and narration positions when resuming a paused reader; preserve active narration and retry deferred background jumps.

- Feat(bookshelf): Support opening supported books from system file associations and import dropped books without repeated confirmation dialogs, preserving originals and isolating per-file failures.

- Fix(ocr): Remember forced OCR per book and replace embedded-text cache results when OCR is requested, preserving saved revisions and note anchors.

- Fix(pdf): Improve continuous-reading backing-image clarity while bounding decoded pixels and retaining visible or selected pages.

- Feat(reader): Add an optional move-and-resize switch for selection-tool popups, visible only in popup display mode and off by default. Drag the top to move, or the sides, bottom and corners to resize; every opening restores the default position and size.

- Feat(translation): Add Baidu Translation API and Microsoft Translator to ordinary language translation, sharing service credentials with Classical Chinese translation. Translate visible paragraphs progressively and support cancellation while keeping each translation mode’s language and appearance preferences independent.

- Feat(translation): Show separate character-use estimates and editable reference-allowance progress for Baidu and Microsoft only. Aggregate updated devices through encrypted settings sync without double-counting repeated syncs; AI and Google usage are excluded. Estimates count successful Modu requests in UTC calendar months and are not official balances; Microsoft Key 1 and Key 2 are counted separately.

- Fix(bookshelf): Size folder dialogs around the configured cover width and available screen space, avoiding oversized covers in partially filled rows.

- Fix(sync): Refresh shelf and open-folder ordering after reading-position synchronization when sorting by last read, using the synchronized reading timestamp and preserving pinning.

- Fix(translation): Fix translation startup failing when an expired chapter document remains in the reader, including the macOS “Translation is not available for this book” error. Discard detached paragraph work and prevent late results from changing removed documents.

- Fix(sync): Synchronize translation service configuration and credentials through the existing encrypted settings channel while keeping language, translation direction and output appearance local, including when importing older snapshots.

- Ci(tests): Align folder-menu fixtures with synchronized group membership so full regression covers folder selection and reader-return transitions.

### 简体中文

- Feat(tts): 音调与语速改为紧凑的减号／数值／加号控件，分别支持 0.5～2.0 和 0.1～4.0 倍、每次 0.1 及手动输入；两组各占一半，窄屏时名称居中置于对应控件上方，宽屏时名称与控件同行。

- Fix(tts): 安卓端通过本地播放调整小米 MiMo 音调，使不同档位作用于已缓冲语音，无需重新合成；暂停、继续与切段保留音调和语速。其他平台在服务支持时发送不同档位的音高指令。

- Perf(reader): 合并相邻生成文字片段的测量，减少排版后的重复位置刷新，跳过连续阅读中未变化的样式；保留正文、选择及导航功能。

- Perf(harmony): 合并连续滚动中的位置测量，保持章节预加载响应并及时保存最终位置。

- Fix(sync): 暂停的阅读器返回前台时恢复较新的同步阅读及朗读位置；保留正在播放的朗读，重试后台延迟的跳转。

- Feat(bookshelf): 支持从系统文件关联打开可导入的书籍，拖入书籍时减少重复确认，保留原文件并隔离单文件导入失败。

- Fix(ocr): 按书保存强制 OCR 设置，要求 OCR 时替换原文字层缓存，同时保留历史修订及笔记锚点。

- Fix(pdf): 提高连续阅读底图清晰度，同时限制解码总像素，保留可见或已选中的页面。

- Feat(reader): 划词功能弹窗新增可选的移动与缩放开关，仅在选择弹出显示时出现，默认关闭；拖动顶部移动，拖动两侧、底边或四角调整大小，每次打开恢复预设位置和大小。

- Feat(translation): 语种翻译接入百度翻译 API 和 Microsoft Translator，与文言文翻译共用服务凭据；仅翻译可见段落、逐段呈现并可随时停止，两类翻译的语言和外观设置仍各自独立。

- Feat(translation): 仅为百度和微软分别显示字符用量估算与可调整的参考额度进度，通过加密设置同步汇总已更新设备，重复同步不重复累计，AI 和 Google 不计入。按 UTC 自然月统计 Modu 成功请求，不代表官方剩余额度；微软 Key 1 与 Key 2 分别计数。

- Fix(bookshelf): 文件夹弹窗根据封面宽度设置和屏幕空间确定布局，避免未填满一行时封面被过度放大。

- Fix(sync): 按最后阅读排序时，阅读进度同步后使用同步的阅读时间刷新书架及已打开文件夹的顺序，保留置顶规则。

- Fix(translation): 修复阅读器残留已失效章节文档导致翻译无法启动的问题，包括 macOS 提示“此书无法翻译”；清理失效段落任务，避免迟到结果写入已移除页面。

- Fix(sync): 翻译服务配置及凭据通过现有加密设置通道同步，语言、翻译方向和译文外观保留本机设置，旧快照导入也不覆盖这些选项。

- Ci(tests): 统一文件夹菜单测试中的分组数据，使完整回归覆盖同步后的文件夹选择和阅读返回动画。

### Downloads / 下载

Android ARM64 · iOS ARM64 · macOS / Windows / Linux ARM64 & x64 · HarmonyOS ARM64. Every package includes a SHA-256 sidecar. / 每个安装包均提供 SHA-256 校验文件。

iOS IPA and HarmonyOS HAP require your own signing. macOS uses ad-hoc signing without notarization; Windows has no commercial Authenticode signature. / iOS IPA 与鸿蒙 HAP 需自行签名；macOS 为临时签名、未公证，Windows 无商业 Authenticode 签名。

[Source / 源码](https://github.com/sobranie2406/modureader/tree/v1.3.4) · [Installation / 安装说明](https://github.com/sobranie2406/modureader/blob/v1.3.4/docs/RELEASING.md) · [License](https://github.com/sobranie2406/modureader/blob/v1.3.4/LICENSE) · [Notice](https://github.com/sobranie2406/modureader/blob/v1.3.4/NOTICE)
