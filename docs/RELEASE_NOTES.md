# Modu 1.3.0

Build / 构建：**10151** · Stable / 正式版

### English

- Feat(settings): Consolidate selection search and custom dictionaries into Selection toolbar, AI reading skills into AI settings, vector/OCR models into Model settings, global settings backup into Sync and backup, storage into Advanced, and feedback into About.

- Feat(translation): Translate only the current original page in text/OCR reflow, preferring saved corrections over recognized text. Support translation-only and bilingual display with the shared selection toolbar, lookup, copying, AI and page-local selected-text speech.

- Feat(weread): Add an optional official WeRead API connection under Appearance. Search by title/author and confirm the edition before linking; show WeRead ratings, reviews, popular highlights, cover, description and publication information separately from personal ratings/reviews.

- Feat(sync): Sync WeRead links and loaded public metadata alongside downloaded books. Include its API Key only in explicitly enabled credential exports or encrypted sensitive-settings sync; keep the query switch device-local and never upload book contents to WeRead.

- Feat(weread): Load reviews and highlights when expanded, cache results with source/update information, and retain Open in WeRead. Replacing a local cover or description requires individual confirmation; external highlights are not mapped to local page positions.

- Feat(ocr): Export saved book text as TXT or Markdown in original page order, preferring corrected text.

- Feat(appearance): Unify menus and settings with softly shadowed rounded groups; brighten the light theme with paper-white backgrounds and jade accents. Preserve the dark palette and E-Ink's monochrome, unfilled, shadow-free styling, with distinct book-format and indexing-status colours.

- Feat(appearance): Add confirmation before restoring the default app accent, reader text colour or reader background colour. Label and outline both reader colour controls so they remain visible against matching backgrounds.

- Fix(reader): Apply top-margin changes immediately. Thanks [@RuizeSun](https://github.com/RuizeSun) for [#51](https://github.com/sobranie2406/modureader/pull/51).

- Fix(tts): Preserve playback speed across synthesized sentences and restore selected-text narration in reflow without turning pages. Thanks [@1Cookie2gavh](https://github.com/1Cookie2gavh) for the playback-rate fix in [#52](https://github.com/sobranie2406/modureader/pull/52).

- Fix(appearance): Refresh home navigation tabs immediately when settings change. Thanks [@RuizeSun](https://github.com/RuizeSun) for [#53](https://github.com/sobranie2406/modureader/pull/53).

- Fix(reader): Match ebook, PDF/scanned and reflow menus, including submenus, to the grouped layout; preserve heading fonts and existing controls, clip backgrounds to rounded corners and remove doubled shadow rims.

- Fix(reader): Make the brightness panel's moon button switch both reader night mode and the app theme across ebooks, PDF/scanned books and reflow; keep E-Ink behavior unchanged.

- Fix(fonts): Replace the broken Atkinson preview with real Latin/digit glyphs, keep previews compact and preserve download controls and font licenses.

- Fix(settings): Align group widths while sizing heights to content; standardize headings and spacing, left-align QQ information, shorten slider handles and use tags for CSS choices. Fresh installations open the bookshelf without welcome/setup screens.

- Fix(macos): Avoid Flutter 3.47 settings-transition flicker and rendering corruption with the tested Skia backend, retaining navigation animations. Android and iOS renderer settings are unchanged.

### 简体中文

- Feat(settings): 选词搜索、自定义字典并入划词工具栏，AI 阅读技能并入 AI 设置，向量／OCR 合并到模型设置，全局设置备份并入同步与备份，存储并入高级，反馈并入关于默读。

- Feat(translation): 文字／OCR 重排仅翻译当前原书页，优先使用已校对文字，其次使用识别结果；支持仅译文与原译对照，复用划词工具栏的查询、复制、AI 及本页选词朗读。

- Feat(weread): 外观中新增可选的微信读书官方 API 关联，按书名／作者搜索并核对版本后确认绑定；独立展示微信读书评分、书评、热门划线、封面、简介及出版资料，不覆盖个人评分／书评。

- Feat(sync): 微信读书关联及已加载公开资料随已下载原书同步；API Key 仅纳入明确开启的凭据导出或加密敏感设置同步，查询开关按设备保留，不向微信读书上传书籍正文。

- Feat(weread): 展开书评／热门划线即自动加载，缓存结果并显示来源与更新时间，保留“在微信读书打开”；替换本地封面和简介分别确认，外部划线不映射到本地页码。

- Feat(ocr): 已保存书籍文字支持导出 TXT 或 Markdown，按原页码排列并优先采用校对稿。

- Feat(appearance): 菜单及设置统一柔和阴影圆角分组，浅色采用更明亮的清纸白底与青玉绿强调色；保持深色和 E-Ink 黑白、无填色、无阴影样式，保留书籍格式与索引状态的区分色。

- Feat(appearance): 软件主题色、阅读文字色和背景色均可经二次确认恢复默认；两个阅读颜色入口增加边框和标签，避免与页面同色时无法辨认。

- Fix(reader): 阅读上边距调整即时生效。感谢 [@RuizeSun](https://github.com/RuizeSun) 贡献 [#51](https://github.com/sobranie2406/modureader/pull/51)。

- Fix(tts): 修复合成语句切换后语速重置，恢复重排划词朗读且不触发翻页。感谢 [@1Cookie2gavh](https://github.com/1Cookie2gavh) 在 [#52](https://github.com/sobranie2406/modureader/pull/52) 中贡献语速修复。

- Fix(appearance): 首页导航标签随设置修改即时刷新。感谢 [@RuizeSun](https://github.com/RuizeSun) 贡献 [#53](https://github.com/sobranie2406/modureader/pull/53)。

- Fix(reader): 普通书籍、PDF／扫描书与重排菜单及子菜单统一分组布局，保留原有标题字体和功能；修正圆角外露出直角背景及阴影重叠轮廓。

- Fix(reader): 普通书籍、PDF／扫描书及重排页的月亮按钮同时切换阅读夜间模式与软件主题，E-Ink 行为不变。

- Fix(fonts): Atkinson 预览改用真实英文字母／数字字形，去除缺字方框；预览区域保持紧凑，保留下载操作与字体许可。

- Fix(settings): 分组框统一宽度、高度随内容变化，统一标题和间距，QQ群信息左对齐，缩短滑块竖条，CSS 选项改用标签；新安装直接进入书架，不再显示欢迎及设置引导。

- Fix(macos): 使用对照复测通过的 Skia 后端修正 Flutter 3.47 设置转场频闪和画面异常，保留过渡动画，不改安卓及 iOS 渲染配置。

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

[Source / 源码](https://github.com/sobranie2406/modureader/tree/v1.3.0) · [Changes / 变更](https://github.com/sobranie2406/modureader/compare/v1.2.12...v1.3.0) · [Licenses / 许可](https://github.com/sobranie2406/modureader/blob/v1.3.0/NOTICE)
