# Modu 1.2.9 · Stable

## English

**Modu 1.2.9 (build 10127)** — fixes since stable **1.2.8**.

- Fix(reader): Stop footnote popups repeatedly resizing; keep screen-height line spacing adjustments confined to the main reading view and balance footnote margins.
- Fix(selection): Correct oversized blue Android selection highlights on aligned pages, preserving automatic word selection and draggable handles.
- Fix(tts): Keep narration playing at its live position when automatic sync refreshes the reader. Reopening a book still restores its highlight paused.
- Fix(sync): Do not report continuous narration progress as a sync failure. Queue and retry changes made during uploads without interrupting playback, while retaining conflict protection and Jianguoyun rate limits.

**Packages:** Nine installers with SHA-256 files: Android ARM64, iOS ARM64, macOS/Windows/Linux ARM64 and x64, and HarmonyOS ARM64.

**Installation:** Back up and upgrade without uninstalling or clearing the library. Android requires Android 8.0+ and retains the project signing key. iOS requires iOS 16+ and your own signing for the app and Share Extension. macOS is ad-hoc signed and not notarized; Windows requires WebView2; Linux targets Debian 13. The unsigned HarmonyOS HAP requires a valid certificate/profile.

[Source](https://github.com/sobranie2406/modureader/tree/v1.2.9) · [Changes since 1.2.8](https://github.com/sobranie2406/modureader/compare/v1.2.8...v1.2.9) · [Installation guide](https://github.com/sobranie2406/modureader/blob/v1.2.9/docs/RELEASING.md)

---

## 简体中文

**Modu 1.2.9（构建 10127）**，修复 **1.2.8 正式版以来**的问题。

- Fix(reader): 修复注释弹窗反复调整高度，按屏幕高度微调行距仅作用于阅读正文，并统一注释框左右留白。
- Fix(selection): 修正 Android 分页对齐后蓝色划词高亮过高，保留自动选词和拖动手柄。
- Fix(tts): 自动同步刷新阅读界面时，保持当前朗读及实时位置，不再打断播放；重新打开书籍仍恢复高亮并保持暂停。
- Fix(sync): 修复持续朗读、进度不断变化时误报同步失败；上传期间产生的新进度自动排队补传，不中断朗读，保留冲突保护和坚果云限频。

**安装包：**9 个程序包及对应 SHA-256 校验文件：Android ARM64、iOS ARM64、macOS／Windows／Linux ARM64 与 x64、HarmonyOS ARM64。

**安装：**建议备份后覆盖升级，不要先卸载或清空书库。Android 最低支持 Android 8.0，沿用项目签名；iOS 要求 iOS 16+，需自行签名应用及分享扩展；macOS 为临时签名、未公证；Windows 需要 WebView2；Linux 面向 Debian 13；鸿蒙 HAP 未签名，需有效证书／Profile。

[源码](https://github.com/sobranie2406/modureader/tree/v1.2.9) · [1.2.8 以来的变化](https://github.com/sobranie2406/modureader/compare/v1.2.8...v1.2.9) · [安装说明](https://github.com/sobranie2406/modureader/blob/v1.2.9/docs/RELEASING.md)
