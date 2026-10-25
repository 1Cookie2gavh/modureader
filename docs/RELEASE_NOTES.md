# Modu 1.3.3

Build / 构建：**10163** · Stable / 正式版

### English

- Feat(plugins): Add reviewed prompt packs and selection actions under Experimental features. Plugins are off by default, require confirmation on each device, and accept only integrity-checked packages from the project catalog. Thanks [@RuizeSun](https://github.com/RuizeSun) for [#62](https://github.com/sobranie2406/modureader/pull/62).

- Feat(logs): Include device model, OS, installed Modu version/build and Android WebView provider/version in startup and exported logs, without device identifiers.

- Feat(fonts): Add Manage installed fonts below Download fonts in Reading settings. Remove downloaded/imported app copies after confirmation and reset only affected font selections; preserve system fonts, bundled fonts and original import files.

- Feat(translation): Add independent output colours for language and Classical Chinese translation, with presets, a custom picker and confirmed reset. Both reader translation panels use consistent settings rows and expose output-appearance controls; source text keeps its existing Style settings.

- Feat(translation): Use a 12–48 px slider for translation size and allow restoring the original size. Preview the same Analects passage in the selected target language; keep the two translation appearance settings independent.

- Fix(plugins): Preserve edited contributions during upgrades and retain the installed package on failure. Serialize lifecycle operations, bound decompression output, and prevent settings restore from granting plugin consent.

- Fix(selection): Fix page-edge dwell not turning pages on touch devices, backward selection expanding after a turn, and landing-page handles becoming unavailable to drag. Preserve one turn per drag and require release and a fresh handle drag before extending again.

- Fix(webview): Make the reader bootstrap parseable by older WebViews, transpile the legacy PDF scripts and load required polyfills. Report unsupported WebViews and script failures promptly; recognize both ModuUA and legacy AnxUA logs.

- Fix(selection): Restrict selection-menu pointer interception to visible controls so transparent menu space no longer blocks cross-page selection handles.

- Fix(harmony): Keep the reading toolbar clear of notches and camera cutouts with system bars hidden, including rotation, without adding duplicate safe-area spacing or changing pagination.

- Fix(reader): Recover an invalid saved EPUB text position at the same chapter’s start so shelf entry can finish loading the TOC and annotations. Preserve valid note-entry positions and annotation anchors.

- Fix(windows): Reject unsupported /S silent-install arguments before opening the installer wizard and report the supported Inno Setup command, preventing unattended installations from waiting indefinitely.

- Ci(release): Include the legacy bootstrap regression in clean-checkout checks and verify rejection of unsupported Windows installer arguments alongside the supported install/uninstall path.

### 简体中文

- Feat(plugins): 实验性功能新增提示词包与划词动作插件，默认关闭，警示并确认后仅在本设备开启；仅接受项目审核清单内且通过完整性校验的插件。感谢 [@RuizeSun](https://github.com/RuizeSun) 贡献 [#62](https://github.com/sobranie2406/modureader/pull/62)。

- Feat(logs): 启动及导出日志增加设备型号、系统版本、Modu 版本与构建号、Android WebView 提供程序和版本，不采集设备唯一标识。

- Feat(fonts): 在“设置 → 阅读 → 下载字体”下方新增“管理已安装字体”，确认后可移除下载或导入的应用内字体，仅回退相关字体选择，保留系统字体、内置字体及原始导入文件。

- Feat(translation): 语种翻译与文言文翻译分别支持独立译文颜色，提供预设、自定义取色及确认恢复默认；阅读中的两个翻译面板统一设置行样式并提供译文外观入口，原文继续使用原有“样式”设置。

- Feat(translation): 译文字号改用 12–48 px 滑动条，并可恢复跟随原文；语种翻译预览按目标语言展示“学而时习之，不亦乐乎？”的译文，两类翻译外观仍独立保存。

- Fix(plugins): 插件升级保留已编辑的贡献项，失败时保留旧包；串行化生命周期操作、限制实际解压量，设置恢复不能绕过插件开启确认。

- Fix(selection): 修复触摸选区在页边停留不翻页、向前翻页后多选以及新页面手柄无法继续拖动的问题；保持每次拖动只翻一页，松手并重新拖动后才继续扩选。

- Fix(webview): 阅读入口脚本兼容旧 WebView 解析，旧版 PDF 脚本一并转译并补齐运行时支持；不支持的 WebView 或脚本失败及时提示，识别 ModuUA 与旧 AnxUA 日志。

- Fix(selection): 划词菜单仅在可见控件区域拦截触摸，透明布局不再挡住跨页选区手柄。

- Fix(harmony): 修复鸿蒙隐藏状态栏后阅读工具栏被刘海或挖孔遮挡，适配旋转并避免重复安全区留白，不改变正文分页。

- Fix(reader): 修复从书架打开 EPUB 时，上次文字位置失效导致反复加载失败、目录空白及批注未显示的问题；失效落点回退至同章开头，有效笔记跳转及批注锚点保持不变。

- Fix(windows): Windows 安装器遇到不支持的 /S 静默参数时提前退出并提示正确的 Inno Setup 命令，避免无人值守安装停在向导中。

- Ci(release): 将旧 WebView 入口脚本回归加入干净环境检查，并在 Windows 安装／卸载验证中检查错误静默参数的退出行为。
