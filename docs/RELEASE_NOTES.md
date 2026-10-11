# Modu 1.2.6 · Stable

## English

**Modu 1.2.6 (build 10104)** — changes since stable **1.2.5**.

- Fix(pdf): Restore highlight, underline and annotation actions for PDF/OCR selections; align marks with cropped, zoomed and rotated pages.
- Fix(appearance): Use the full 0–100 manual brightness range instead of a 20% floor; preserve follow-system mode and keep software dimming controls accessible.
- Feat(appearance): Add a default-enabled book-format badge switch in Appearance; keep scanned-book and indexed indicators independent.
- Fix(bookshelf): Hide cover overflow buttons until selection mode is entered by long press or desktop right-click, in both the shelf and folders; keep batch actions and lower-right menu placement.
- Fix(android): Refresh release plugin registration through the shared APK build entry, preventing stale integration-test plugin references after tests.
- Ci(android): Update Gradle, Android Gradle Plugin and Kotlin to 9.2.1, 9.0.1 and 2.3.20; migrate the app and 14 plugins to built-in Kotlin, enable JVM target validation, align library compile SDKs and migrate native-library packaging. Keep the Android 8.0 minimum and existing plugin versions.
- Fix(pdf): Restore touch-scroll momentum in PDF continuous-scroll mode, respecting disabled-animation and E-Ink settings ([#31](https://github.com/sobranie2406/modureader/issues/31)). Thanks [@RuizeSun](https://github.com/RuizeSun)
- Feat(pdf): Use the existing brightness-panel moon button to invert PDF pages and darken the surrounding background in night mode. Keep OCR text selection and annotation colours unchanged; turn it off to restore original page colours. Images within PDF pages are also inverted.

**Packages:** Nine installers and nine SHA-256 files: Android ARM64, iOS ARM64, macOS/Windows/Linux ARM64 and x64, and HarmonyOS ARM64. No Android x64 release.

**Installation:** Back up before upgrading; do not uninstall or clear the library. Android retains the project signing key and Android 8.0 minimum. iOS still requires iOS 16+ and your own signing for the app and Share Extension; this release does not add iOS 15 support. macOS uses ad-hoc signing without notarization. Windows requires WebView2; Linux targets Debian 13. HarmonyOS HAP is unsigned and needs a valid certificate/profile; HarmonyOS device validation remains outstanding. Models are downloaded on demand.

**Validation and limits:** Automated checks cover PDF selection/annotation alignment, scroll momentum, night inversion, brightness, badges, selection menus and packaging. Package generation is not full device acceptance. Remaining Android SDK XML, database-plugin API and Gradle deprecation warnings are not suppressed. Dictionary images require the corresponding MDD/local resources; this release does not reconstruct missing resources.

[Source](https://github.com/sobranie2406/modureader/tree/v1.2.6) · [Changes since 1.2.5](https://github.com/sobranie2406/modureader/compare/v1.2.5...v1.2.6) · [Installation guide](https://github.com/sobranie2406/modureader/blob/v1.2.6/docs/RELEASING.md)

---

## 简体中文

**Modu 1.2.6（构建 10104）**，以下为 **1.2.5 正式版以来**的变化。

- Fix(pdf): 恢复 PDF／OCR 选词的高亮、下划线与批注操作，使标记随裁边、缩放和旋转正确对齐。
- Fix(appearance): 手动亮度使用完整的 0–100 范围，取消原有 20% 下限；保留跟随系统模式，软件调暗时保持控件可见。
- Feat(appearance): 在界面外观中增加默认开启的书籍格式标签开关，不影响扫描版和已索引标记。
- Fix(bookshelf): 书架与文件夹内默认隐藏封面三个点，长按或桌面右键进入多选后再显示；保留批量操作及右下角菜单位置。
- Fix(android): 通过统一 APK 打包入口刷新生产插件注册表，避免测试后残留的 integration_test 引用导致编译失败。
- Ci(android): 将 Gradle、Android Gradle Plugin 和 Kotlin 分别升级到 9.2.1、9.0.1 和 2.3.20；将应用和 14 个插件迁移至内置 Kotlin，启用 JVM 目标版本校验，对齐插件编译 SDK 并迁移原生库打包配置。保留现有插件版本，最低仍支持 Android 8.0。
- Fix(pdf): 修复 PDF「连续卷轴」触控滑动缺少惯性的问题，遵循关闭动画和 E-Ink 设置 ([#31](https://github.com/sobranie2406/modureader/issues/31)) 感谢 [@RuizeSun](https://github.com/RuizeSun)
- Feat(pdf): 复用亮度面板的月亮按钮，夜间模式下 PDF 页面反色、四周背景变黑，保留 OCR 选词与批注颜色；关闭后恢复原色。PDF 页面内的插图也会一同反色。

**安装包：**9 个程序包及 9 个 SHA-256 校验文件：Android ARM64、iOS ARM64、macOS／Windows／Linux 的 ARM64 与 x64，以及 HarmonyOS ARM64。不发布 Android x64。

**安装：**建议先备份再覆盖升级，不要先卸载或清空书库。Android 沿用项目签名，最低仍为 Android 8.0。iOS 仍要求 iOS 16+，需自行签名应用和分享扩展；本版不增加 iOS 15 支持。macOS 为临时签名，未公证；Windows 需要 WebView2，Linux 面向 Debian 13。HarmonyOS HAP 未签名，需有效证书／Profile 后签名安装，尚未完成鸿蒙实机验证。模型仍按需下载。

**验证与限制：**自动回归覆盖 PDF 选词及批注对齐、滑动惯性、夜间反色、亮度、标签、选择菜单和打包检查；包构建成功不代表所有设备均已验收。Android 尚有 SDK XML、数据库插件旧 API 和 Gradle 弃用提示，未屏蔽警告。词典图片需要配套 MDD／本地资源，本版不补造缺失图片。

[对应源码](https://github.com/sobranie2406/modureader/tree/v1.2.6) · [1.2.5 至 1.2.6 源码差异](https://github.com/sobranie2406/modureader/compare/v1.2.5...v1.2.6) · [安装说明](https://github.com/sobranie2406/modureader/blob/v1.2.6/docs/RELEASING.md)
