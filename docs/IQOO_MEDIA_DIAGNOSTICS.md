# iQOO 媒体通知诊断测试

本地兼容测试版：`1.2.11-beta.3-iqoo.4+10144`，Android ARM64，不发布。
本次修复：仅在定向兼容模式下，将通知栏播放使用的模拟静音键在本应用接收器中转换为当前 MediaSession 的 `TransportControls.play()`；不改暂停、前后句、停止及耳机按键。保留上一版通知图标防裁剪修复。
仅当测试构建开启 `MODU_IQOO_MEDIA_COMPAT` 且品牌/制造商为 vivo 或 iQOO 时，启用通知布局、播放命令转发及停止清理兼容。普通构建及其他品牌手机保持原有行为，不改变朗读引擎逻辑。

## 发给测试用户

1. 安装测试 APK，保留原有数据，不要卸载或清除数据。
2. 打开书籍朗读，返回桌面展开通知栏，点击暂停，再点三角播放按钮；确认实际恢复出声，重复三次。锁屏后重复测试。
3. 测试上一段/下一段、停止，并对照应用内暂停/继续。停止后确认通知消失，再次朗读确认通知恢复。
4. **不要退出或重启应用**。到「设置 → 高级 → 日志」，点击右上角菜单导出日志。
5. 发送导出的 `Modu-iQOO-Log-*.txt` 和通知截图，并说明手机型号、Android / OriginOS 版本、使用的朗读引擎及复现操作。截图中的书名等信息可以遮挡。

诊断专版导出的是本次启动的脱敏日志，不是旧的原始日志文件。新增字段不包含书名、章节正文、文件路径、网址、账号、密钥或媒体会话 token。其他原始日志仍可在应用内查看，但不包含在此专版导出文件中。

## 诊断字段与限制

- `source=dart`：应用提交的 playing / processing 状态、controls、systemActions、compact。动作数字是当前 audio_service 的 MediaAction 枚举索引。
- `source=android`：从本应用已发布通知的 token 连接 MediaController，观察实际 PlaybackState 状态和 actions 位掩码、canPlay/canPause/canToggle，以及控制器回调。
- 同时记录本应用通知是否存在、token 是否存在、动作数量/图标资源 ID、待执行操作是否存在、媒体样式、前台/持续标记、通知通道与权限、后台限制、省电模式、音频属性及元数据是否存在。
- `sessionPresent` 仅表示观察器已取得控制器，**不代表是否注册过 MediaSession**。通知或 token 缺失时不能由此断定应用没注册会话。通知消失后可暂时保留已连接的控制器，继续观察其状态。
- Android 13+ 可依据 PlaybackState 生成系统按钮，`notificationActions=0` 本身并不能证明按钮缺失。
- `compatActive=true` 表示本次确实开启了定向兼容；`actionIconPresent` / `actionIconTypes` / `actionIconResources` 记录现代 Icon 对象是否存在、类型和资源编号，不读取或导出图片/URI。
- `notificationPlayRequests` 为本进程收到并尝试直接转发的通知播放次数；`sessionPlayCallbacks` 为媒体会话实际进入播放回调的次数（也可能包含其他播放来源），不能等同于已经出声。二者均只在定向兼容开启时累加，供定位命令传递使用。
- 每 2 秒读取一次本应用通知，变化才记录；控制器存在时每 30 秒保留一次快照。会话状态通过回调记录并去重。不绑定/启动媒体服务，不请求通知读取权限，不读取其他应用通知，不发送播放命令。
- 采集最多 2000 条；分享日志保留最近 1000 条/256 KiB 详细记录。请在复现后及时导出，不适合长时间持续监测。
- 系统 UI 的最终渲染无法仅靠应用日志确定，需要配合截图和 iQOO 实机复测；当前未在 iQOO 实机验证。

## 构建

```sh
node scripts/build_android.mjs --build-name=1.2.11-beta.3-iqoo.4 --build-number=10144 --dart-define=MODU_MEDIA_DIAGNOSTICS=true --dart-define=MODU_IQOO_MEDIA_COMPAT=true
```

默认构建不启用该诊断；无需增加依赖或权限。测试包沿用应用签名和应用 ID，覆盖安装，不是独立应用。
