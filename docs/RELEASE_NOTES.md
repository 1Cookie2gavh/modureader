# Modu 1.2.6 · Stable

## English

**Modu 1.2.6 (build 10108)** — changes since stable **1.2.5**.

- Fix(reader): Handle unavailable chapter documents and reload failed resources on retry while preserving the outgoing page and reading position. Keep slow loads cancellable and add privacy-safe chapter failure diagnostics.
- Fix(ai): Remember edit-before-send independently for each AI screen and selection action on this device; exclude these preferences from sync and settings transfer.
- Fix(ai): Keep AI Knowledge on model/web knowledge for follow-ups, history restore and retries; never use local book tools. Keep Book AI follow-ups grounded in their original book or skill source.
- Feat(ai): Add independent settings, new-chat, history and display menus to AI Knowledge, AI translation, Classical Chinese translation and other AI panels. Separate history by built-in/custom skill and home task; clearing one history does not remove another. Retain legacy conversations.
- Fix(reader): Unify Android reader touch-selection handles in blue and remove the native drag magnifier, retaining range adjustment, copy and annotation actions.
- Ci(lint): Update custom_lint to 0.7.6 to fix its startup failure on the current Dart SDK; keep custom checks enabled.

- Fix(pdf): Restore highlight, underline and annotation actions for PDF/OCR selections; align marks with cropped, zoomed and rotated pages.
- Fix(appearance): Use the full 0–100 manual brightness range instead of a 20% floor; preserve follow-system mode and keep software dimming controls accessible.
- Feat(appearance): Add a default-enabled book-format badge switch in Appearance; keep scanned-book and indexed indicators independent.
- Fix(bookshelf): Hide cover overflow buttons until selection mode is entered by long press or desktop right-click, in both the shelf and folders; keep batch actions and lower-right menu placement.
- Fix(android): Refresh release plugin registration through the shared APK build entry, preventing stale integration-test plugin references after tests.
- Ci(android): Update Gradle, Android Gradle Plugin and Kotlin to 9.2.1, 9.0.1 and 2.3.20; migrate the app and 14 plugins to built-in Kotlin, enable JVM target validation, align library compile SDKs and migrate native-library packaging. Keep the Android 8.0 minimum.
- Ci(android): Pin the SDK command-line parser used by builds and emulator tests, migrate deprecated Gradle property assignments and disable unused Jetifier. Update the Android database plugin to 2.4.2+2 for Android 16 API guards, with sqflite_common pinned to 2.5.6 to preserve transaction semantics.
- Fix(pdf): Restore touch-scroll momentum in PDF continuous-scroll mode, respecting disabled-animation and E-Ink settings ([#31](https://github.com/sobranie2406/modureader/issues/31)). Thanks [@RuizeSun](https://github.com/RuizeSun)
- Feat(pdf): Use the existing brightness-panel moon button to invert PDF pages and darken the surrounding background in night mode. Keep OCR text selection and annotation colours unchanged; turn it off to restore original page colours. Images within PDF pages are also inverted.

**Packages:** Nine installers and nine SHA-256 files: Android ARM64, iOS ARM64, macOS/Windows/Linux ARM64 and x64, and HarmonyOS ARM64. No Android x64 release.

**Installation:** Back up before upgrading; do not uninstall or clear the library. Android retains the project signing key and Android 8.0 minimum. iOS still requires iOS 16+ and your own signing for the app and Share Extension; this release does not add iOS 15 support. macOS uses ad-hoc signing without notarization. Windows requires WebView2; Linux targets Debian 13. HarmonyOS HAP is unsigned and needs a valid certificate/profile; HarmonyOS device validation remains outstanding. Models are downloaded on demand.

**Validation and limits:** Automated checks cover PDF selection/annotation alignment, scroll momentum, night inversion, brightness, badges, selection menus and packaging. Package generation is not full device acceptance. Flutter still requires the deprecated `android.newDsl=false` compatibility flag; its warning is not suppressed. Dictionary images require the corresponding MDD/local resources; this release does not reconstruct missing resources.

The custom lint startup failure is fixed, but separately running the legacy Riverpod rules still exposes a newer-Dart syntax incompatibility. Standard analysis and automated tests are distinct from complete custom-rule validation; the runtime framework was not upgraded to address this development-tool limitation.

Chapter recovery passed controlled null-document and cache-reload regressions as part of 585 JavaScript tests; the reported intermittent Xiaomi-device scenario still needs device revalidation. The reader script build retains three legacy-target top-level-await compatibility warnings.

[Source](https://github.com/sobranie2406/modureader/tree/v1.2.6) · [Changes since 1.2.5](https://github.com/sobranie2406/modureader/compare/v1.2.5...v1.2.6) · [Installation guide](https://github.com/sobranie2406/modureader/blob/v1.2.6/docs/RELEASING.md)

---

## 简体中文

**Modu 1.2.6（构建 10108）**，以下为 **1.2.5 正式版以来**的变化。

- Fix(reader): 处理切章空文档，重试时重新加载失败资源，保留原页与阅读位置；慢加载仍可取消，并补充不含正文和资源地址的失败诊断。
- Fix(ai): 各 AI 界面与划词 AI 入口独立记忆「编辑后发送」开关，仅保存在本机，不参与同步和设置导入导出。
- Fix(ai): AI 知识的追问、历史恢复和重试始终使用大模型／联网知识，不调用本地或本书检索工具；本书 AI 继续围绕原书籍或原技能的原文范围回答。
- Feat(ai): 为 AI 知识、AI 翻译、文言文翻译等 AI 界面补齐独立的设置、新建对话、历史和显示菜单；内置技能、自定义技能与首页任务分别保存历史，清空互不影响，保留旧记录。
- Fix(reader): 安卓阅读选区统一蓝色触控手柄，去除原生拖动放大浮框，保留选区调整、复制与批注操作。
- Ci(lint): 将 custom_lint 更新至 0.7.6，修复当前 Dart SDK 下检查插件无法启动的问题，保留自定义检查。

- Fix(pdf): 恢复 PDF／OCR 选词的高亮、下划线与批注操作，使标记随裁边、缩放和旋转正确对齐。
- Fix(appearance): 手动亮度使用完整的 0–100 范围，取消原有 20% 下限；保留跟随系统模式，软件调暗时保持控件可见。
- Feat(appearance): 在界面外观中增加默认开启的书籍格式标签开关，不影响扫描版和已索引标记。
- Fix(bookshelf): 书架与文件夹内默认隐藏封面三个点，长按或桌面右键进入多选后再显示；保留批量操作及右下角菜单位置。
- Fix(android): 通过统一 APK 打包入口刷新生产插件注册表，避免测试后残留的 integration_test 引用导致编译失败。
- Ci(android): 将 Gradle、Android Gradle Plugin 和 Kotlin 分别升级到 9.2.1、9.0.1 和 2.3.20；将应用和 14 个插件迁移至内置 Kotlin，启用 JVM 目标版本校验，对齐插件编译 SDK 并迁移原生库打包配置。最低仍支持 Android 8.0。
- Ci(android): 固定构建与模拟器测试使用的 SDK 命令行解析器，迁移 Gradle 弃用属性赋值并关闭不再需要的 Jetifier。Android 数据库插件升级至 2.4.2+2，使用 Android 16 API 兼容分支；锁定 sqflite_common 2.5.6，保留原有事务语义。
- Fix(pdf): 修复 PDF「连续卷轴」触控滑动缺少惯性的问题，遵循关闭动画和 E-Ink 设置 ([#31](https://github.com/sobranie2406/modureader/issues/31)) 感谢 [@RuizeSun](https://github.com/RuizeSun)
- Feat(pdf): 复用亮度面板的月亮按钮，夜间模式下 PDF 页面反色、四周背景变黑，保留 OCR 选词与批注颜色；关闭后恢复原色。PDF 页面内的插图也会一同反色。

**安装包：**9 个程序包及 9 个 SHA-256 校验文件：Android ARM64、iOS ARM64、macOS／Windows／Linux 的 ARM64 与 x64，以及 HarmonyOS ARM64。不发布 Android x64。

**安装：**建议先备份再覆盖升级，不要先卸载或清空书库。Android 沿用项目签名，最低仍为 Android 8.0。iOS 仍要求 iOS 16+，需自行签名应用和分享扩展；本版不增加 iOS 15 支持。macOS 为临时签名，未公证；Windows 需要 WebView2，Linux 面向 Debian 13。HarmonyOS HAP 未签名，需有效证书／Profile 后签名安装，尚未完成鸿蒙实机验证。模型仍按需下载。

**验证与限制：**自动回归覆盖 PDF 选词及批注对齐、滑动惯性、夜间反色、亮度、标签、选择菜单和打包检查；包构建成功不代表所有设备均已验收。Flutter 仍需要已弃用的 `android.newDsl=false` 兼容开关，保留其警告。词典图片需要配套 MDD／本地资源，本版不补造缺失图片。

自定义 lint 的启动异常已修复，但单独运行旧 Riverpod 规则仍有新版 Dart 语法兼容问题。标准分析与自动测试不等同于全部自定义规则验证；本版不因此升级应用运行框架。

章节恢复已通过空文档、缓存重载等受控回归，共 585 项 JavaScript 测试通过；用户报告的小米设备偶发场景仍待实机复验。阅读器脚本构建保留三条旧目标环境的 top-level-await 兼容性警告。

[对应源码](https://github.com/sobranie2406/modureader/tree/v1.2.6) · [1.2.5 至 1.2.6 源码差异](https://github.com/sobranie2406/modureader/compare/v1.2.5...v1.2.6) · [安装说明](https://github.com/sobranie2406/modureader/blob/v1.2.6/docs/RELEASING.md)
