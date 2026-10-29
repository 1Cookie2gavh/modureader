# Modu 1.3.5

Build / 构建：**10167** · Stable / 正式版

### English

- Feat(reader): Add device-local popup height limits (40–80%, default 80%) and reading popup opacity (20–100%, default 100%); E-Ink mode keeps popups opaque.

- Fix(reader): Prevent clipping in narration controls and nested reading menus; keep narration and zoom floating bars at their original opacity.

- Fix(sync): Refresh retained readers after unlocking and apply newer synchronized page and paused narration positions.

- Fix(sync): Save the visible page anchor when leaving ordinary reading; preserve resumable narration anchors and highlights without starting playback or initializing an unconfigured engine.

- Feat(tts): Continue PDF reflow narration onto the next original page, preferring cached and corrected text and waiting for extraction or OCR when needed; PDF narration remains session-only.

- Fix(tts): Restore playback from paused vivo/iQOO media notifications.

- Fix(windows): Remove the permission plugin’s unnecessary startup location subscription.

- Chore(android): Remove the obsolete all-files access request and block its inclusion by transitive dependencies; retain system document-picker exports.

- Fix(appearance): Use fixed 50% opacity for transient messages, independently of reading popup settings.

### 简体中文

- Feat(reader): 新增本机阅读弹窗高度上限（40～80%，默认 80%）和阅读弹出界面不透明度（20～100%，默认 100%）；电子墨水模式保持完全不透明。

- Fix(reader): 修复朗读调节控件与下级阅读菜单遮挡、裁切，朗读浮动条和缩放浮动条保留原有不透明度。

- Fix(sync): 锁屏恢复到未退出的阅读界面后触发同步，跳转到较新的页面及暂停朗读位置。

- Fix(sync): 普通阅读退出时保存当前页位置，有朗读记录时保留朗读起点与高亮；恢复同步状态不自动播放，也不初始化未配置的朗读引擎。

- Feat(tts): PDF 重排朗读到页末自动翻到下一原始页继续，优先使用缓存及校对文字，缺失时等待提取或 OCR；PDF 不保存跨会话朗读断点。

- Fix(tts): 修复 vivo／iQOO 通知栏暂停后点击三角播放按钮无法继续的问题。

- Fix(windows): 移除 Windows 权限插件在启动时自动订阅位置变化的多余行为。

- Chore(android): 删除遗留的所有文件访问权限申请并阻止依赖引入该权限，保留系统文件选择器导出。

- Fix(appearance): 短时提示统一使用固定 50% 不透明度，不随阅读弹窗设置变化。

### Downloads / 下载

Android ARM64 · iOS ARM64 · macOS / Windows / Linux ARM64 & x64 · HarmonyOS ARM64. Every package includes a SHA-256 sidecar. / 每个安装包均提供 SHA-256 校验文件。

iOS IPA and HarmonyOS HAP require your own signing. macOS uses ad-hoc signing without notarization; Windows has no commercial Authenticode signature. / iOS IPA 与鸿蒙 HAP 需自行签名；macOS 为临时签名、未公证，Windows 无商业 Authenticode 签名。

[Source / 源码](https://github.com/sobranie2406/modureader/tree/v1.3.5) · [Installation / 安装说明](https://github.com/sobranie2406/modureader/blob/v1.3.5/docs/RELEASING.md) · [License](https://github.com/sobranie2406/modureader/blob/v1.3.5/LICENSE) · [Notice](https://github.com/sobranie2406/modureader/blob/v1.3.5/NOTICE)
