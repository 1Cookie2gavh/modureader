# Modu 1.3.1

Build / 构建：**10152** · Stable / 正式版

### English

- Feat(appearance): Make the Remote library navigation tab optional and reorder navigation visibility switches. Thanks [@1Cookie2gavh](https://github.com/1Cookie2gavh) for [#57](https://github.com/sobranie2406/modureader/pull/57).

- Feat(settings): Move CSS settings into Reading and rename Model settings to Offline local model settings; make built-in CSS template labels follow the app language without changing user-created names or CSS.

- Feat(history): Add a book-tap preference while editing History: open book details or read directly. Hide the option after editing, preserve save/discard behavior and restore the blurred long-press preview for details mode.

- Fix(ocr): Accept finite, integral text offsets returned as doubles by Apple's web bridge, restoring PDF text-layer reflow, split-view loading and prefetch while retaining geometry validation and saved corrections.

- Fix(storage): Include downloaded OCR models in storage usage and model cleanup. Thanks [@RuizeSun](https://github.com/RuizeSun) for [#56](https://github.com/sobranie2406/modureader/pull/56).

- Fix(windows): Synchronize embedded WebView2 visibility with window hiding, minimization and restoration, including retained readers and background-created views; preserve explicit page suspension. Thanks [@ndd200](https://github.com/ndd200) for reporting [#54](https://github.com/sobranie2406/modureader/issues/54).

- Fix(tts): Exclude invisible chapter notes from visible-page calculations so narration can turn from the first page within the current paragraph instead of waiting for the next highlight.

- Fix(reader): Align chapter-opening prose to the normal bottom margin while preserving heading styling and spacing; keep natural spacing on short endings, title-only pages and complex layouts.

- Fix(history): Keep short history lists stable during elastic overscroll instead of jumping back to the top. Thanks [@ndd200](https://github.com/ndd200) for reporting [#58](https://github.com/sobranie2406/modureader/issues/58).

- Fix(ai): Reduce repeated passage scans for long retrieval prompts, bound local query preprocessing and limit optional reader retrieval to eight seconds before continuing with existing context. Preserve full chat prompts and existing indexes.

- Fix(ai): Copy only the AI answer, excluding reasoning and tool output; disable copying while generating or when no answer is available, without changing saved conversations.

- Fix(bookshelf): Keep search-entry press feedback inside its rounded surface, removing the rectangular grey overlay while preserving the soft outer shadow.

- Ci(release): Accept verified release-branch QQ notifications; refresh regression checks for bounded retrieval and the localized homepage gallery.

### 简体中文

- Feat(appearance): 远程书库导航标签支持独立隐藏，并调整导航显示开关的排列顺序。感谢 [@1Cookie2gavh](https://github.com/1Cookie2gavh) 贡献 [#57](https://github.com/sobranie2406/modureader/pull/57)。

- Feat(settings): CSS 设置并入阅读，模型设置更名为离线本地模型设置；内置 CSS 模板名称随应用语言切换，保留用户自定义名称与 CSS 内容。

- Feat(history): 历史页编辑模式新增书籍点击行为选择：进入书籍详情或直接阅读；退出编辑后隐藏选项，保留保存／放弃修改，并在详情模式恢复长按虚化预览。

- Fix(ocr): 兼容 Apple 网页桥接返回的小数类型整数字符位置，恢复 PDF 文字层重排、分屏加载与预缓存；继续校验几何位置并保留已保存的校对稿。

- Fix(storage): 存储统计与模型清理纳入已下载的 OCR 模型。感谢 [@RuizeSun](https://github.com/RuizeSun) 贡献 [#56](https://github.com/sobranie2406/modureader/pull/56)。

- Fix(windows): 内嵌 WebView2 随窗口隐藏、最小化与恢复同步显示状态，覆盖保留的阅读页及后台创建的页面，保留页面主动暂停状态。感谢 [@ndd200](https://github.com/ndd200) 报告 [#54](https://github.com/sobranie2406/modureader/issues/54)。

- Fix(tts): 分页可见范围不再计入隐藏的章末脚注，修复章节首页朗读跨页时必须等到下一段高亮才翻页的问题。

- Fix(reader): 章节首页正文对齐正常下边距，保留标题样式及标题下方间距；短尾页、纯标题页和复杂图文页保持自然留白。

- Fix(history): 修复历史页短列表触底后继续弹性滑动突然回到顶部的问题。感谢 [@ndd200](https://github.com/ndd200) 报告 [#58](https://github.com/sobranie2406/modureader/issues/58)。

- Fix(ai): 优化长提示词检索的重复原文扫描与本地查询预处理；可选检索等待超过八秒后使用已有上下文继续，保留完整 AI 提示词和现有索引文件。

- Fix(ai): 复制仅包含 AI 正文，不附带思考和工具输出；生成中或没有正文时禁用复制，不改变已保存的对话。

- Fix(bookshelf): 搜索入口点击反馈限制在圆角内部，消除矩形灰影，保留外部柔和阴影。

- Ci(release): 支持已验证发布分支的 QQ 通知，同步更新限时检索及中英文首页图片的回归检查。

## Downloads / 下载

Nine packages, each with a SHA-256 checksum / 九个平台安装包及各自 SHA-256 校验文件：

- Android ARM64 — APK
- macOS ARM64 / x64 — DMG
- Windows ARM64 / x64 — EXE installer / 安装程序
- Linux ARM64 / x64 — DEB (Debian 13)
- iOS ARM64 — unsigned IPA / 未签名 IPA
- HarmonyOS ARM64 — unsigned native HAP / 未签名原生 HAP

Back up first, then upgrade without uninstalling or clearing your library. Sync remains on protocol v9; upgrade participating devices together to use the new WeRead fields. Android retains the project signing key. macOS is ad-hoc signed and not notarized. Windows requires WebView2. Linux targets Debian 13. iOS requires your own signing for the app and Share Extension; HarmonyOS requires a valid local certificate/profile. Models are downloaded or imported separately, not bundled.

建议先备份，再覆盖升级，不要卸载或清空书库。同步协议仍为 v9；使用新增微信读书字段时，请一起升级参与同步的设备。安卓沿用项目签名；macOS 为临时签名、未公证；Windows 需要 WebView2；Linux 面向 Debian 13；iOS 应用及分享扩展需自行签名，鸿蒙 HAP 需使用有效证书和配置签名安装。模型按需下载或离线导入，不内嵌安装包。

[Source / 源码](https://github.com/sobranie2406/modureader/tree/v1.3.1) · [Changes / 变更](https://github.com/sobranie2406/modureader/compare/v1.3.1...v1.3.1) · [Licenses / 许可](https://github.com/sobranie2406/modureader/blob/v1.3.1/NOTICE)
