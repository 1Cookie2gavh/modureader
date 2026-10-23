# 插件系统 P2–P3 设计与执行文档（注册表化 + 声明式网络插件）

Status: 设计稿，待评审 · 2026-10-24 · 基线 `3cdf7365`（P1 已实现；工作区含未提交的 P1b/P1c 改动） · 本文只定义 P2/P3，不含实现

本文承接 [插件系统 P0–P1 执行文档](plugin-system-p0-p1.md)。P2 的目标是把翻译、朗读（TTS）、词典、AI 工具/技能与划词工具栏的分发改成稳定 ID 注册表；P3 的目标是在这套注册表上开放**声明式网络插件**，首个落地类型是词典 HTTP 源。P4 的 WebView 脚本宿主、P5 的签名与生态不在本文范围。

---

## 0. 交接摘要（先读这一节）

### 0.1 一句话结论

P2 是**内部架构改造**，不新增用户可见的插件能力；P3 是**第一个新的插件能力**，只允许插件通过宿主代理发起受域名白名单、请求模板和限额约束的 HTTP 请求。P2 必须先合入，P3 才能安全复用同一套注册表、生命周期和设置迁移。

### 0.2 阶段边界

| 阶段 | 内容 | 交付物 | 预估 | 门禁 |
|---|---|---|---|---|
| **P2a** | 注册表内核 + AI 工具/阅读技能注册表化 | `HostRegistry`、`RegistryCatalog`、AI 工具与技能描述符、兼容验证与单测 | 3–4 人日 | 存量 `enabledAiTools` / `readAnySkill*` 零丢失；无行为变化 |
| **P2b** | 翻译 + TTS 注册表化 | 翻译/TTS 描述符、工厂、配置键白名单、备份迁移 | 3–4 人日 | 旧枚举名与旧配置可读；导出/导入往返一致 |
| **P2c** | 词典 + 划词工具栏注册表化，接入 P1 插件贡献生命周期 | 词典源描述符、工具栏动作描述符、`isApplied` 生命周期 | 3–4 人日 | 旧工具栏 JSON、旧词典选择、P1 插件动作均不回归 |
| **P3** | 声明式网络插件 v1：词典 HTTP 源 | `net:http`、`dictionarySource`、宿主 HTTP 代理、域名/限额/密钥 | 8–10 人日 | 越权请求全拒；密钥不进入备份；6 平台文本查询可用 |

P2 合计约 **9–12 人日**，P3 约 **8–10 人日**。P2 内部三个 PR 各自可独立回滚；P3 在 P2 全部合入后开始。

### 0.3 与 P0 路线图的两处调整

P0 文档 §14 写过“P2 新增 `ttsProvider` 等 kind”。本文明确调整：

1. **P2 不开放 `ttsProvider` / `translatorProvider` 贡献**。没有网络传输或脚本运行时，这类贡献只有元数据，无法真正工作；提前开放会制造“装得上但选不了/选了不工作”的死 UI，并逼着 manifest 在 P3 再改一次。P2 只完成内置引擎的注册表化和插件贡献生命周期，P3 再用同一套声明式 HTTP 适配器开放 provider 类贡献。
2. **P3 v1 只开放 `dictionarySource`**。翻译和 TTS 的请求/响应差异更大（流式、音频、鉴权头），放到 P3.1 复用同一 HTTP 适配器评估；P3 v1 不承诺插件 TTS/翻译。

这两处调整不改变“目标形态 C、脚本宿主 P4、WebView 唯一宿主”的结论。

### 0.4 当前代码事实（P1 基线）

- 插件宿主：`lib/service/plugins/plugin_host.dart`，已有安装/启停/卸载/升级、`PluginStatus`、启动对账和 `AppliedContribution` 哈希守卫。
- 贡献注册：`lib/service/plugins/plugin_contribution_handler.dart` + `plugin_contributions.dart`，按 `kind` 查 handler；P1 注册了 `aiSkill` 与 `selectionAction`。
- 插件状态：`pluginState` 单键 + `pluginConfig_<id>`；P1 已接入设置导出与严格校验。
- 内置分发仍是枚举/静态表：
  - 翻译：`TranslateService.provider` 的 `switch`（`lib/service/translate/index.dart:29-50`）。
  - TTS：`TtsService.provider` 的 `switch`（`lib/service/tts/tts_service.dart:19-32`）。
  - 词典：`enum OnlineDictionary` 与 `OnlineDictionaryService.lookup` 内按枚举拼 host（`lib/service/dictionary/online_dictionary.dart:8-40`）。
  - AI 工具：`AiToolRegistry` 的静态 `_definitions`（`lib/service/ai/tools/ai_tool_registry.dart:69-127`）。
  - 阅读技能：`const readAnySkills` 静态列表（`lib/service/ai/readany_skills.dart:44-181`）。
  - 划词工具栏：`SelectionToolbarConfig` 的静态 `defaultItems` / `templateItems` / `iconIds` / `skillIds` 与 `validate()`（`lib/models/selection_toolbar.dart:133-310`）。
- 网络：现有词典用 `Dio` 直连（`online_dictionary.dart:42-80`），无统一插件网络出口、无域名白名单、无限额、无密钥隔离。

### 0.5 下一步

1. 评审本文档，重点确认 §3 的 D10–D22 与 §5.3 的 manifest 形状。
2. P2a 先做一个 1 人日 spike：证明 `HostRegistry` 能在不改变现有设置键的前提下替换 AI 工具与技能静态表，并让测试可注入。
3. 进入 P2 前补一次真实插件包跨设备验收（安装 → 停用 → 备份 → 另一设备恢复 → 重装），作为 P2/P3 的回归基线。
4. P2 合入后再写 P3 的安全评审记录；P3 不先写代码再补评审。

---

## 1. 目标与非目标

### 1.1 P2 目标

1. 为六类内置扩展点建立**稳定字符串 ID + 描述符**的注册表：翻译、TTS、词典源、AI 工具、阅读技能、划词工具栏动作。
2. 移除分发处的 `switch` 与静态 `const` 列表依赖；UI、预置数据、导入校验都从注册表读取。
3. 保持所有**既有持久化键和值不变**：旧版写下的枚举名/工具 ID/技能 ID/工具栏 ID 继续可读；P2 不要求用户重新配置。
4. 让 P1 插件贡献生命周期能感知“运行时注册表是否真的注册了该贡献”，修复重启后 `_isMaterialised` 只检查提示词/工具栏、无法覆盖未来 provider 类型的问题。
5. 为 P3 的 `dictionarySource` 预先留出注册、注销、冲突检测和 UI 展示接口，但 P2 不开放网络能力。

### 1.2 P3 目标

1. 新增能力令牌 `net:http`，只允许插件通过**宿主 HTTP 代理**访问 manifest 声明的精确域名。
2. 新增 `dictionarySource` 贡献：声明式请求模板 + 声明式 JSON 响应映射，不执行任何插件代码。
3. 实现域名白名单、HTTPS、禁重定向、私网/回环地址拦截、超时、响应大小、并发/频率/每日限额、取消与内存缓存。
4. 插件密钥与普通设置分离：`pluginSecret_<id>` 设备本地保存，**不进入设置导出、WebDAV 同步或数据库备份**，日志与错误信息脱敏。
5. 在词典查询 UI 中把插件源与内置在线源并列展示，显示来源、许可与归属；插件停用/卸载后源消失，配置和用户选择保留。
6. 6 平台（Android / iOS / macOS / Windows / Linux / HarmonyOS）行为一致；不新增原生依赖、不改数据库版本。

### 1.3 明确不做

- P2 不新增插件贡献 kind，不改变 manifest 的已开放能力集合（仍为 `ai:prompt-pack`、`ui:selection-action`）。
- P2/P3 不执行插件 JS/Dart/原生代码；不引入 QuickJS、动态库、WebView 脚本宿主。
- P3 v1 不支持 POST、请求体、Cookie、任意请求头、HTML 解析、分页、OAuth、文件上传、WebSocket。
- P3 v1 不开放 `translatorProvider` / `ttsProvider` 插件贡献；它们留到 P3.1 或 P4，视 P3 适配器评审结果决定。
- 不做插件市场、远程安装、签名/撤销列表；P3 仍只有 SHA-256 完整性校验。
- 不把插件包、插件私有文件、词典数据纳入设置备份；不新增数据库表，`currentDbVersion` 保持 11。
- 不允许插件覆盖内置 ID，也不允许两个插件注册同一 ID。

### 1.4 完成定义（DoD）

**P2**

- `flutter analyze` 无新增告警，`flutter test` 全绿。
- 同一份旧设置（含 `translateService`、`ttsService`、`enabledAiTools`、`readAnySkill*`、`selectionToolbar`、`dictionaryLookupSources`）在新版本启动后，选择、顺序、启停状态与升级前一致。
- 设置导出/导入往返后，上述键的语义不变；未知 provider 配置不被丢弃。
- P1 的 `aiSkill` / `selectionAction` 在重启、停用、卸载、升级后行为不变；新增的 `isApplied` 对未知 kind 保持“无法判断则保留”的保守策略。
- 新增测试覆盖 §7 标记 P2 的条目。

**P3**

- 含 `net:http` 的包在安装页展示域名、用途与限额；未声明 `net:http` 的包不能注册 `dictionarySource`。
- 插件只能请求白名单内的精确域名；重定向、私网地址、IP 字面量、userinfo、非 443 端口、非 HTTPS 全部被拒。
- 单次查询的请求数、响应大小、超时、并发和频率均在限额内；超限返回可读错误，不影响本地词典与其他在线源。
- 插件密钥不出现在设置导出、数据库备份、日志、错误页和诊断文本中。
- 卸载/停用插件后词典源立即消失；重装后配置与源选择恢复；缺失插件不崩溃。
- 6 平台手工验收通过；恶意包测试全拒。

---

## 2. 现状、缺口与约束

### 2.1 可复用的 P1 资产

| 资产 | 位置 | P2/P3 用法 |
|---|---|---|
| `PluginHost` 单例与状态机 | `plugin_host.dart` | 继续作为唯一安装/启停入口；新增注册表对账 |
| `PluginContributionHandler` | `plugin_contribution_handler.dart` | P3 新增 `DictionarySourceHandler`；P2 增加 `isApplied` |
| `AppliedContribution` | `plugin_state.dart` | 不扩展 JSON 字段；provider 类型只用 `kind/id/contentSha256` |
| `PluginConfig` | `plugin_config.dart` | P3 增加 secret 类型与独立存储 |
| 设置导出/导入 | `settings_modules.dart`、`global_settings_transfer.dart`、`settings_value_validation.dart` | P2 改为注册表驱动的白名单；P3 增加 secret 排除 |
| 备份脱敏 | `backup_safety.dart` | P3 必须把 `pluginSecret_` 纳入凭据判断 |

### 2.2 具体缺口

1. **枚举是分发中心**：`TranslateService` / `TtsService` 同时承担“UI 选项、持久化值、工厂、配置键”四种职责，新增 provider 必须改枚举和多个 switch。
2. **静态表是隐式 schema**：AI 工具、技能、工具栏预置、图标 ID、skill ID 都是 `const` 列表；插件无法注册，测试也无法注入替身。
3. **配置键与 provider 名耦合**：`translateServiceConfig_<enum.name>`、`onlineTtsConfig_<serviceId>`、`ttsVoiceModel_<serviceId>` 直接拼名字；迁移必须保留旧键。
4. **导入校验硬编码服务清单**：`TtsConfigTransfer.services` 固定 5 个；`settings_value_validation.dart` 用 `TtsConfigTransfer.services.contains(id)` 判断，未知 provider 会被降级为“只校验对象形状”。P2 要显式保留未知键，而不是靠分支碰巧不丢。
5. **插件贡献对账不完整**：`PluginHost._isMaterialised` 只认识 `aiSkill` 和 `selectionAction`，其他 kind 一律返回 `true`；注册表型贡献在重启后内存为空，会被误判为“仍已物化”。
6. **没有统一网络出口**：现有在线词典直接 `Dio()`，无法集中做域名、限额、密钥、日志脱敏。P3 必须先建宿主代理，再允许插件源。
7. **没有 secret 设置类型**：P1 明确禁止 `password`，因为 `pluginConfig_*` 会进入设置导出。P3 需要密钥时必须新增隔离存储，不能复用 `pluginConfig_*`。

### 2.3 设计约束

- 不改变数据库 schema；插件配置和密钥都走 SharedPreferences。
- 不改变 P1 已写入的 `pluginState` JSON 形状；新增行为放在运行时和设置键上。
- 所有新增 ID 必须可安全用于 SharedPreferences 键、JSON 值和 UI 的 `ValueKey`；不允许空格、冒号以外的控制字符。
- 所有网络错误只记录结构化 code、插件 ID、域名、状态码；**不记录查询词、完整 URL、请求头、响应体**。
- 所有用户可见文案用 `ModuStrings.text(context, zh, en)`；日志与异常用英文。

---

## 3. 已冻结决策（P2/P3）

| 编号 | 决策 | 理由 |
|---|---|---|
| D10 | 内置扩展点 ID **沿用现有持久化 token**（如 `googleApi`、`edge`、`wiktionaryZh`、`calculator`、`smart_summary`、`query`） | 零迁移、零备份破坏；旧值就是新 ID |
| D11 | 插件 ID 统一命名空间 `plugin:<pluginId>:<contributionId>`；划词动作因 `validate()` 限制使用 `custom-plugin:<pluginId>:<actionId>` | 与 P1 提示词/动作 ID 一致；避免与内置 ID 冲突 |
| D12 | 注册表按域拆分（translate / tts / dictionary / aiTool / readingSkill / toolbar），每个条目有唯一 `id`、`owner`、`aliases` | 一个全局大表会制造跨域耦合；按域注册便于测试和权限 |
| D13 | 插件不能覆盖内置 ID；同域重复注册直接抛错并回滚安装 | 防止恶意包劫持“翻译”“朗读”等默认入口 |
| D14 | P2 不开放 provider 类插件贡献；P3 先开放 `dictionarySource` | 没有传输层的 provider 是死 UI；一次只引入一种真实能力 |
| D15 | P3 的网络请求只能经宿主代理；插件不能拿到 `Dio` / `HttpClient` / socket | 统一做白名单、限额、脱敏；也是未来脚本宿主的最小权限边界 |
| D16 | 白名单是**精确主机名**，HTTPS，端口 443，禁重定向；不接受通配符、IP、userinfo、片段 | 降低 SSRF、DNS rebinding、开放重定向风险；通配符留到有明确需求再评审 |
| D17 | P3 响应只支持 JSON + 声明式路径映射，不支持 HTML/CSS 选择器 | 避免在 P3 引入一个小型解析引擎；HTML 留给 P3.1/P4 |
| D18 | 密钥存 `pluginSecret_<id>`，**永不导出**（即使 `includeSecrets=true`），不进日志 | 插件密钥不应随设置/备份跨设备；与现有 `isCredentialPreference` 边界一致 |
| D19 | 每插件独立限额：1 并发、20 次/分钟、300 次/日、1 次/查询；全局 4 并发、60 次/分钟 | 防止一个坏源拖垮全部词典查询或耗尽网络 |
| D20 | 只允许 GET、无请求体、固定 header 白名单（`Accept`、`Accept-Language`、secret 的 `Authorization`） | 消除 CSRF、任意 header 注入、cookie 泄露；满足只读词典需求 |
| D21 | 查询结果只进内存缓存（每插件 64 条、TTL 10 分钟），不落盘；用户查询词不进日志 | 词典内容有许可限制；查询词可能包含敏感阅读内容 |
| D22 | 只读旧 token、写回也保持旧 token；新增插件 token 才使用 `plugin:`；不 bump DB、不改 `pluginState` schema | 可降级、可回滚；P2 是重构而非数据迁移 |

补充说明：

- D10 的直接结果是 P2 **不需要写迁移脚本**。唯一需要映射的旧别名是 `translateService` 的 `microsoft`（旧值）→ `microsoftApi`，以及 TTS 已废弃的 `aliyun`/`azure` → `system`；这两条在 P1 的 `getTranslateService` / `Prefs.ttsService` 已有处理，P2 把它们收进注册表 alias。
- D11 的 `plugin:` 前缀不参与 manifest 的 `id` 正则；manifest 的贡献 `id` 仍是 `^[a-z0-9][a-z0-9._-]{0,62}$`。宿主负责拼接，避免 manifest 自带命名空间。
- D16 的“精确主机名”指 DNS 名称，不是 IP。安装时和请求时都要校验；请求时解析出的所有 A/AAAA 记录都必须通过私网检查。

---

## 4. P2：注册表化

### 4.1 目标架构

```
                    ┌─────────────────────────────┐
                    │        RegistryCatalog      │
                    │  translate / tts / dict /   │
                    │  aiTool / skill / toolbar   │
                    └──────────────┬──────────────┘
                                   │ resolve(id)
   UI / Prefs / backup  ───────────┤
                                   │
   PluginContributions ── handler ─┘
          │
          ├─ AiPromptHandler          (P1)
          ├─ SelectionActionHandler   (P1)
          └─ DictionarySourceHandler  (P3)
```

- **内置条目**在 `RegistryCatalog.standard()` 中一次性注册，owner 为 `RegistryOwner.builtIn`。
- **插件条目**由 handler 在 `apply` 中注册，owner 为 `RegistryOwner.plugin(pluginId)`；`remove` 只注销 owner 匹配的条目。
- **UI 和导入校验**只通过 `resolve(id)` 读取；不再直接读 enum 或 const 列表。
- 注册表是内存状态，启动时由 `PluginHost.initialize()` 重建；持久化的 `pluginState.applied` 只用于对账和清理。

### 4.2 注册表内核

建议新增 `lib/service/registry/host_registry.dart`：

```dart
enum RegistryDomain { translate, tts, dictionary, aiTool, readingSkill, toolbar }

sealed class RegistryOwner {
  const RegistryOwner();
  const factory RegistryOwner.builtIn() = BuiltInOwner;
  const factory RegistryOwner.plugin(String pluginId) = PluginOwner;
}

class BuiltInOwner extends RegistryOwner {
  const BuiltInOwner();
  @override
  bool operator ==(Object other) => other is BuiltInOwner;
  @override
  int get hashCode => 0;
}

class PluginOwner extends RegistryOwner {
  const PluginOwner(this.pluginId);
  final String pluginId;
  @override
  bool operator ==(Object other) =>
      other is PluginOwner && other.pluginId == pluginId;
  @override
  int get hashCode => pluginId.hashCode;
}

abstract interface class RegistryEntry {
  String get id;
  RegistryDomain get domain;
  RegistryOwner get owner;
  List<String> get aliases; // 旧 token，可为空
}

class HostRegistry<T extends RegistryEntry> {
  HostRegistry(this.domain);

  final RegistryDomain domain;
  final Map<String, T> _byId = {};
  final Map<String, String> _aliases = {};
  final List<void Function()> _listeners = [];

  List<T> get all => List.unmodifiable(_byId.values);

  T? byId(String id) => _byId[id];

  /// 先精确 ID，再 alias；找不到返回 null（调用方决定降级策略）。
  T? resolve(String id) {
    final direct = _byId[id];
    if (direct != null) return direct;
    final canonical = _aliases[id];
    return canonical == null ? null : _byId[canonical];
  }

  void register(T entry) {
    if (entry.domain != domain) {
      throw ArgumentError('Entry ' + entry.id + ' belongs to ' + entry.domain.name);
    }
    if (_byId.containsKey(entry.id)) {
      throw StateError('Duplicate ' + domain.name + ' id: ' + entry.id);
    }
    final seenAliases = <String>{};
    for (final alias in entry.aliases) {
      if (alias == entry.id || !seenAliases.add(alias)) {
        throw StateError('Invalid ' + domain.name + ' alias: ' + alias);
      }
      final existing = _byId[alias] ?? _aliases[alias];
      if (existing != null) {
        throw StateError('Duplicate ' + domain.name + ' alias: ' + alias);
      }
    }
    _byId[entry.id] = entry;
    for (final alias in entry.aliases) {
      _aliases[alias] = entry.id;
    }
    _notify();
  }

  /// 只允许 owner 自己注销；内置条目永远不能由插件删除。
  bool unregister(String id, {required RegistryOwner owner}) {
    final entry = _byId[id];
    if (entry == null || entry.owner != owner) return false;
    _byId.remove(id);
    _aliases.removeWhere((_, canonical) => canonical == id);
    _notify();
    return true;
  }

  void removeAllOwnedBy(RegistryOwner owner) {
    for (final id in _byId.entries
        .where((entry) => entry.value.owner == owner)
        .map((entry) => entry.key)
        .toList()) {
      unregister(id, owner: owner);
    }
  }

  void addListener(void Function() listener) => _listeners.add(listener);
  void _notify() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }
}
```

实现注意：

- 不要用泛型 `Map<String, dynamic>` 全局表；每域一个实例，类型安全且错误信息清晰。
- `RegistryCatalog` 持有六个 `HostRegistry`，并在构造时注册内置条目。测试用 `RegistryCatalog.forTesting()` 注入空表或替身。
- `RegistryEntry` 的 `aliases` 只用于旧值；不允许 alias 与另一个条目的 ID 相同。
- 注册失败要把 `StateError` 转成 `PluginInstallError(duplicateContribution)`，并触发已应用贡献回滚。
- 注册表变更通过 listener 通知 UI；不要直接调用 `Prefs.notifyListeners()` 造成无关重建。

### 4.3 生命周期：给 handler 增加 `isApplied`

P1 的 `PluginHost._isMaterialised` 是硬编码 `switch (kind)`。P2 改为 handler 自己判断：

```dart
abstract class PluginContributionHandler {
  String get kind;
  Set<String> get requiredCapabilities;

  void validate(PluginManifest manifest, List<PluginContribution> contributions);

  Future<List<AppliedContribution>> apply(
      PluginManifest manifest, List<PluginContribution> contributions);

  Future<void> remove(List<AppliedContribution> applied);

  /// 运行时是否仍存在该贡献。默认 true（未知/无状态类型保持保守）。
  bool isApplied(AppliedContribution applied) => true;

  /// true 表示该类型的贡献只存在于内存注册表，重启后必须重建。
  /// P1 的提示词/工具栏为 false；P3 的词典源为 true。
  bool get runtimeOnly => false;
}
```

`PluginHost._reconcile` 改为：

```dart
final lost = record.applied.isEmpty ||
    record.applied.every((entry) => !_isMaterialised(entry));

bool _isMaterialised(AppliedContribution entry) {
  final handler = _contributions.registry.forKind(entry.kind);
  return handler?.isApplied(entry) ?? true;
}
```

- `AiPromptHandler.isApplied`：检查 `userPrompts` 是否存在该 ID（沿用 P1 逻辑）。
- `SelectionActionHandler.isApplied`：检查 `selectionToolbar.items` 是否存在该 ID（沿用 P1 逻辑）。
- 未来的 `DictionarySourceHandler.isApplied`：检查词典注册表是否含有该 ID 且 owner 匹配。
- 未知 kind 仍返回 `true`，避免新版本写入的贡献被旧版本误删。

> 这一改动是 P2 的关键：没有它，P3 的 provider 源在重启后会被误判为“已物化”，但实际注册表为空，用户会看到源消失且无法自动恢复。

P3 的 `DictionarySourceHandler` 必须声明 `runtimeOnly = true`，并且 `apply` 必须幂等（先注销同 owner 的旧源，再注册当前 manifest 的源）。P2 引入该标志时**不改变** P1 两个 handler 的 `every` 语义；`PluginHost` 对 `runtimeOnly` 的 kind 在每次启动无条件重建，避免“部分源丢失但 other 仍存在”时被漏掉。该重建逻辑可以放在 P3 的 handler/协调层，但接口必须在 P2 冻结。

### 4.4 各域注册表

#### 4.4.1 翻译

现状：`TranslateService` 枚举 + `provider` switch；配置存 `translateServiceConfig_<enum.name>`。

目标描述符：

```dart
class TranslateProviderEntry implements RegistryEntry {
  const TranslateProviderEntry({
    required this.id,
    required this.factory,
    required this.label,
    required this.configPrefix,
    this.aliases = const [],
    this.supportsFullText = true,
    this.isWebView = false,
    this.description,
    this.owner = const RegistryOwner.builtIn(),
  });

  @override final String id;
  @override final List<String> aliases;
  @override final RegistryOwner owner;
  @override RegistryDomain get domain => RegistryDomain.translate;

  final TranslateServiceProvider Function() factory;
  final String Function(BuildContext) label;
  final String configPrefix; // 'translateServiceConfig_'
  final bool supportsFullText;
  final bool isWebView;
  final String? description;

  TranslateServiceProvider create() => factory();
}
```

内置 ID 与迁移（注册顺序与现有 `enum` 顺序一致，避免 UI 顺序变化）：

| ID（= 旧 `enum.name`） | 别名 | 配置键 | 全文翻译 | WebView |
|---|---|---|---|---|
| `microsoftFree` | — | `translateServiceConfig_microsoftFree` | 是 | 否 |
| `bingWeb` | — | — | 否 | 是 |
| `googleWeb` | — | — | 否 | 是 |
| `microsoftApi` | `microsoft` | `translateServiceConfig_microsoftApi` | 是 | 否 |
| `googleApi` | — | `translateServiceConfig_googleApi` | 是 | 否 |
| `deepl` | — | `translateServiceConfig_deepl` | 是 | 否 |
| `ai` | — | — | 是 | 否 |
| `baiduWeb` | — | — | 否 | 是 |
| `youdaoWeb` | — | — | 否 | 是 |

改造点：

- `TranslateService.provider` 不再 `switch`，改为 `TranslateProviderRegistry.instance.resolve(name)!.create()`；枚举保留一个版本作为 UI 类型，P4 再删除。
- `getTranslateService(name)` 先走注册表，找不到时回退 `microsoftFree` 并记一次 warning（不抛异常，保持旧行为）。
- `TranslateService.values` 的 UI 列表改为注册表顺序；`readAnyValues` / `selectionValues` / `webValues` 改为基于条目的 `supportsFullText`、`isWebView` 过滤，避免硬编码枚举集合。
- 配置文件继续按 `<id>` 拼键；P2 不重命名任何键。
- 导入校验中 `translateServiceConfig_*` 仍只校验对象形状；P2 可按注册表配置项做类型校验（可选，不阻塞）。

#### 4.4.2 TTS

现状：`TtsService` 枚举 + `provider` switch；`TtsConfigTransfer.services` 固定 5 个；`Prefs.ttsService` 已有 `aliyun/azure → system` 的兼容逻辑。

目标描述符：

```dart
class TtsProviderEntry implements RegistryEntry {
  const TtsProviderEntry({
    required this.id,
    required this.factory,
    required this.label,
    required this.isOnline,
    this.aliases = const [],
    this.configurable = true,
    this.owner = const RegistryOwner.builtIn(),
  });

  @override final String id;
  @override final List<String> aliases;
  @override final RegistryOwner owner;
  @override RegistryDomain get domain => RegistryDomain.tts;

  final TtsServiceProvider Function() factory;
  final String Function(BuildContext) label;
  final bool isOnline;
  final bool configurable; // system 不计入 onlineTtsConfig_
}
```

内置 ID：`system`、`edge`、`dashscope`、`xiaomi`、`openai`。别名：`aliyun` → `system`、`azure` → `system`（保留旧行为）。

改造点：

- `TtsService.provider` 改为注册表解析；枚举保留给 `ttsVoiceModel_` 的 `serviceId` 兼容。
- `TtsConfigTransfer.services` 改为 `TtsProviderRegistry.instance.configurableIds`，但**导出时仍按固定顺序写出已知 5 个 provider 的键**，保证旧版本能读；导入时：
  - 已知 provider：按现有规则校验；
  - 未知 provider：保留原始 `config`/`voice` 键，不参与当前运行，也不丢弃；只在诊断中记录数量。
- `settings_value_validation.dart` 的 `onlineTtsConfig_` 分支改为“注册表能解析 → 严格校验；不能解析 → 保留对象形状”；不能因为未知就静默删除。
- `ttsService` 的持久化值仍是字符串 ID，不改键。

#### 4.4.3 AI 工具

现状：`AiToolRegistry` 静态 `_definitions`，`sanitizeIds` 会丢弃未知 ID。

目标：

- `AiToolEntry` 包装现有 `AiToolDefinition`，`id` 不变（`calculator`、`currentTime`、`mindmap` 等）。
- `definitions` / `byId` / `defaultEnabledToolIds` / `sanitizeIds` / `buildTools` 改为实例方法；`AiToolRegistry.instance` 供生产使用，测试可注入。
- `sanitizeIds` 的新语义：**保留未知 ID 在存储中，构建工具时过滤**。这样插件/未来版本删除工具后，重新启用旧工具不会丢配置；当前运行只构建已知工具。
- `enabledAiTools` 的导入校验不变（字符串列表）；P2 不新增工具贡献 kind，插件不能向此注册表注册可执行工具。P4 脚本工具通过新的 `scriptTool` 类型接入，走独立权限。
- 兼容：`AiToolRegistry.displayNameForId` 对未知 ID 仍返回 ID 本身，历史消息展示不崩。

#### 4.4.4 阅读技能

现状：`const readAnySkills` + `legacyAiKnowledgeSkill`；用户自定义技能已经是 `UserPrompt`，通过 `ReadingSkillEntry.custom` 合并。

目标：

- 新增 `ReadingSkillRegistry`，内置条目 ID 不变（`smart_summary`、`book_summary`、`concept_explainer`、`argument_analyzer`、`character_tracker`、`quote_collector`、`reading_guide`、`smart_translator`、`vocabulary_helper`、`mindmap`）。
- `legacyAiKnowledgeSkill` 只用于旧 prompt/history 兼容，不注册为可见技能；`readingSkillPromptDefinitions` 保留“可见技能 + 退役定义”的并集语义。
- `orderedReadingSkills` 从注册表读取内置技能；自定义技能仍来自 `UserPrompt`。
- `isReadingSkillOrderId` 已接受 `builtin:` / `custom:`；P2 不改变顺序 ID 格式。
- 插件 `aiSkill` 已经通过 `UserPrompt` 进入自定义技能列表，P2 不新增 `readingSkill` 贡献 kind，避免两套提示词语义。

#### 4.4.5 划词工具栏

这是 P2 风险最高的部分，因为 `SelectionToolbarConfig.validate()` 同时约束内置项、24 个自定义名额、字段长度和序列化。

目标：

- `ToolbarActionEntry` 描述内置动作：`id`、`action`、默认 `name/icon/prompt`、分组（default/annotation/template）、是否 AI、默认启用。
- `defaultItems` / `defaultAnnotations` / `templateItems` 由注册表生成；ID 仍是 `query`、`narrate`、`custom-preset-*` 等，**不改任何序列化 ID**。
- `iconIds` / `skillIds` 改为注册表导出的集合；插件动作仍使用 `custom-plugin:` 前缀，并继续走 `SelectionActionHandler` 的 24 名额检查。
- `validate()` 改为查询只读 catalog：
  - 内置动作必须在 catalog 中存在且 `action` 匹配；
  - 自定义动作仍需 `custom-` 前缀、非空名称/prompt、合法图标；
  - 不再引用 `defaultItems` / `templateItems` 的静态身份比较（`identical(defaults, defaultItems)` 这类写法要删掉，改为 `entry.isBuiltIn`）。
- **分层约束**：`lib/models/selection_toolbar.dart` 不能反向 import `lib/service/registry`（否则形成 model ↔ service 循环）。内置动作的纯数据定义放在 `lib/models/toolbar_action_definition.dart`，注册表包装它；`SelectionToolbarConfig` 通过启动时注入的 `ToolbarCatalog` 或静态默认 catalog 访问，测试可注入替身。
- 序列化保持 v1 形状：`items`、`annotations`、`colors`、`version`、`templateRevision` 不变。P2 必须为旧配置做 golden test：默认配置、用户删除了某个预置、用户重命名/改 prompt、含插件动作、24 名额边界。
- `SelectionActionHandler` 的 `isApplied` 改为读工具栏配置（与 P1 相同），但内置/插件 ID 的合法性判断走注册表。

> 不要在 P2 把工具栏 ID 改成新命名空间；那会破坏设置备份、同步和旧版本读取，收益为零。

#### 4.4.6 词典源

现状：`OnlineDictionary` 枚举只有两个值；`DictionaryPreferences` 存 `local:<uuid>` / `online:<enum.name>`。

目标：

- `DictionarySourceEntry`：`id`、显示名（本地化）、`kind`（local/online/plugin）、`lookup` 回调、`license`、`attribution`、`isAvailable`。
- 内置在线源 ID 仍是 `wiktionaryZh` / `wiktionaryEn`；`DictionaryPreferences` 的 token 仍是 `online:wiktionaryZh`，零迁移。
- P3 插件源 token 设计为 `online:plugin:<pluginId>:<sourceId>`；解析时先尝试内置源，再查插件注册表。
- 未知 token **保留**在 SharedPreferences 中但不出现在 UI；插件重装后自动恢复选择。P2 先实现解析与保留逻辑，P3 再填充插件源。
- `DictionaryLookup` 的 `OnlineDictionary` 类型改为 `DictionarySourceEntry`；UI 的“查询中/失败/无条目”状态键从枚举改为字符串 ID。P2 必须保持两个内置源的行为和排序。

### 4.5 Prefs、导出与导入

P2 不改键名，但要改**校验和枚举来源**：

| 键/前缀 | P2 改动 | 兼容要求 |
|---|---|---|
| `translateService` | 读时 alias 解析，写时仍是 ID | `microsoft` 旧值可读 |
| `fullTextTranslateService` | 同上；WebView 仍回退 `microsoftFree` | 不允许全文翻译选 WebView |
| `translateServiceConfig_*` | 配置项来自注册表；未知 id 保留对象 | 旧配置不丢 |
| `ttsService` | 注册表解析；`aliyun/azure` → `system` | 旧值不崩 |
| `onlineTtsConfig_*` | 已知严格校验、未知保留 | 导入不丢未知 provider |
| `ttsVoiceModel_*` | 键不变；未知 provider 的 voice 保留 | 同上 |
| `enabledAiTools` | 保留未知 ID，运行时过滤 | 重装/升级不丢 |
| `readAnySkillStates` / `readAnySkillPrompts` / `readAnySkillOrder` | 注册表提供内置 ID；未知顺序 ID 保留 | 旧顺序不丢 |
| `selectionToolbar` | 注册表提供内置动作；序列化不变 | 旧 JSON 可读 |
| `dictionaryLookupSources` | 解析 token；未知 token 保留 | 本地/在线选择不丢 |

`settings_modules.dart` 的 `settingsModuleForKey` 目前用前缀判断 `onlineTtsConfig_`、`translateServiceConfig_`、`pluginConfig_`。P2 保留这些分支；如果注册表新增配置前缀，必须同时更新这里，并加一个“所有注册表配置前缀都有 owner”的单测，避免导出时静默漏项。

`isCredentialPreference` 在 P2 保持现状；P3 增加 `pluginSecret_`。

### 4.6 UI 改动

- 翻译设置页：引擎列表从注册表读取；保留现有分组（选择翻译 / 全文翻译）和 `readAnyValues` 的顺序语义。
- 朗读设置页：服务选择从注册表读取；配置表单仍由 `TtsServiceProvider.getConfigItems` 生成。
- 词典设置：内置在线源从注册表读取；P3 再增加“插件源”分组与网络徽标。
- AI 设置：工具列表从注册表读取；未知已保存 ID 不显示，但不删除。
- 插件详情：P2 增加“已注册运行时项”区块，显示该插件注册的 provider/词典源/工具（P2 实际只有 P1 的提示词/动作），无条目时隐藏。
- 不新增 ARB 键；新增文案用 `ModuStrings.text`。

### 4.7 P2 测试

| 层级 | 文件（新建/修改） | 覆盖 |
|---|---|---|
| 注册表内核 | `test/service/registry/host_registry_test.dart` | 注册、重复 ID、alias 冲突、owner 注销、内置不可删、监听通知 |
| AI 工具 | `test/service/ai/tools/ai_tool_registry_test.dart` | 内置 ID 不变、未知 ID 保留、构建过滤、顺序 |
| 阅读技能 | `test/service/ai/reading_skill_registry_test.dart` | 内置列表、退役定义、顺序合并、未知 ID 保留 |
| 翻译 | `test/service/translate/translate_registry_test.dart` | 9 个 ID、`microsoft` alias、WebView/全文过滤、旧配置读取 |
| TTS | `test/service/tts/tts_registry_test.dart`、`test/service/config_transfer/tts_config_transfer_test.dart` | 5 个 ID、`aliyun/azure`、未知 provider 保留、备份往返 |
| 词典 | `test/service/dictionary/dictionary_preferences_test.dart` | 旧 token、未知 token 保留、local:* 兼容 |
| 工具栏 | `test/models/selection_toolbar_test.dart`、`test/widgets/selection_toolbar_test.dart` | 旧 JSON golden、默认/删除/编辑/插件动作、24 名额 |
| 插件生命周期 | `test/service/plugins/plugin_host_test.dart` | `isApplied` 重启对账、P1 行为不变、未知 kind 保守 |
| 导入 | `test/service/config_transfer/settings_transfer_registry_test.dart` | 注册表前缀都有 owner、未知 provider 不丢、非法 ID 拒绝 |

P2 手工验收：

1. 用 P1 版本生成一份设置备份（含插件、翻译、TTS、AI 工具、技能顺序、工具栏），在 P2 版本导入，逐项对比选择与顺序。
2. 安装 P1 样例插件，确认提示词/划词动作在重启、停用、卸载、升级后行为不变。
3. 把 `translateService` 改成 `microsoft`、`ttsService` 改成 `aliyun`，重启后分别落到 `microsoftApi` / `system`，不崩溃。
4. 在注册表测试中注入一个假 provider，确认 UI 能显示、配置能保存、导出不丢；测试结束不污染全局。
5. 6 平台各跑一次安装/启停/卸载与设置页打开。

### 4.8 P2 PR 拆分与回滚

| PR | 内容 | 独立回滚 |
|---|---|---|
| **P2a** | `HostRegistry` / `RegistryCatalog`、AI 工具、阅读技能、`isApplied` 接口（先只改 P1 两个 handler） | 删除注册表并恢复静态表；数据无变化 |
| **P2b** | 翻译、TTS、配置导入/导出改造 | 恢复枚举 switch 和固定 services 列表；设置键未变 |
| **P2c** | 词典、工具栏、插件详情运行时区块、完整回归 | 恢复枚举与静态工具栏列表；插件数据无变化 |

回滚原则：P2 不写新键、不改旧键、不 bump DB，因此回滚只需回退代码；用户设置不需要恢复脚本。唯一需要清理的是测试中注入的全局注册表，生产代码不得把测试条目写入 prefs。

---

## 5. P3：声明式网络插件

### 5.1 范围与威胁模型

P3 v1 只允许**词典查询**这一种网络用途。一次查询的生命周期：

```
用户选中词 → DictionaryLookup
  → 读取 DictionaryPreferences（本地 + 内置在线 + 插件源）
  → 对每个插件源调用 PluginDictionarySource.lookup(word)
      → NetworkGuard 校验 URL/主机/端口/解析地址
      → HostHttpClient 发 GET（预算、超时、取消）
      → 读取并限制响应体
      → JsonMapping 解析为 DictionaryEntry
  → 与本地/内置结果并列渲染（纯文本）
```

威胁模型：

| 资产 | 威胁 | 缓解 |
|---|---|---|
| 用户查询词 | 被插件发往任意主机、写入日志 | 域名白名单；日志不记词；只 GET 声明模板 |
| 本地网络 | SSRF 访问 `127.0.0.1`、LAN、云元数据 | 禁 IP/本地名；解析后私网检查；禁重定向 |
| 插件密钥 | 随设置导出/备份泄露 | `pluginSecret_` 永不导出；错误/日志脱敏 |
| 应用稳定性 | 无限响应、慢请求、并发打满 | 1 MiB、8s、并发/频率/日限额、取消 |
| 内容许可 | 抓取受版权保护内容、丢失归属 | 必填 license/attribution/sourceUrl；UI 展示；不落盘 |
| 生态信任 | 插件冒充内置源/覆盖内置 | ID 命名空间；内置不可覆盖；安装页展示域名 |

### 5.2 能力与安装授权

新增能力常量：

```dart
const String kNetHttpCapability = 'net:http';
const String kDictionarySourceContributionKind = 'dictionarySource';
```

- P3 的 `kSupportedCapabilities = {..., 'net:http'}`；`script:run`、`library:read` 仍拒绝。
- 只有声明 `net:http` 的包才能包含 `dictionarySource`；反之，含 `dictionarySource` 但未声明 `net:http` 的包在 manifest 校验阶段拒绝（`capabilityUnavailable` 或 `invalidContribution`，实现时选一个并写进测试）。
- 安装页必须展示：
  - 将要访问的精确域名列表；
  - “查询词会发送到这些域名”；
  - 限额与“仅 HTTPS”；
  - 插件提供的许可与归属。
- 用户确认后才写入 `pluginState`；P1 的安装流程已有确认步骤，P3 只扩展展示内容，不新增第二套授权状态。
- 重新安装同 ID 插件时，若域名列表变化，必须重新展示并确认；域名列表不变可沿用已装记录，但仍展示。

### 5.3 manifest v1 形状（P3）

在 P1 manifest 上新增顶层 `network`，新增 `dictionarySource` 贡献，新增 `secret` 设置类型。

```json
{
  "schemaVersion": 1,
  "id": "com.example.dictionary",
  "version": "1.0.0",
  "name": { "zh-CN": "示例词典", "en": "Example dictionary" },
  "description": { "zh-CN": "通过公开 JSON API 查询示例词条。", "en": "Looks up entries from a public JSON API." },
  "author": { "name": "Example", "url": "https://example.com" },
  "license": "MIT",
  "minAppVersion": "1.4.0",
  "capabilities": ["net:http"],
  "network": {
    "domains": ["api.example.com"],
    "timeoutMs": 8000,
    "maxResponseBytes": 1048576,
    "requestsPerLookup": 1
  },
  "settings": [
    {
      "key": "lang",
      "type": "select",
      "label": { "zh-CN": "词典语言", "en": "Dictionary language" },
      "options": ["en", "zh"],
      "defaultValue": "en"
    },
    {
      "key": "api_key",
      "type": "secret",
      "label": { "zh-CN": "API 密钥（可选）", "en": "API key (optional)" },
      "required": false
    }
  ],
  "contributes": [
    {
      "kind": "dictionarySource",
      "schema": 1,
      "id": "example-en",
      "name": { "zh-CN": "示例词典 · 英文", "en": "Example Dictionary · English" },
      "request": {
        "method": "GET",
        "url": "https://api.example.com/v1/lookup",
        "query": {
          "q": "{word}",
          "lang": "{setting.lang}"
        },
        "headers": {
          "Accept": "application/json",
          "Authorization": "Bearer {secret.api_key}"
        }
      },
      "response": {
        "format": "json",
        "root": "data.entries[*]",
        "fields": {
          "word": "headword",
          "definition": "senses[*].definition",
          "partOfSpeech": "senses[*].partOfSpeech",
          "sourceUrl": "source.url",
          "license": "source.license",
          "attribution": "source.attribution"
        },
        "maxEntries": 5,
        "maxDefinitionChars": 4000
      },
      "license": "CC-BY-4.0",
      "licenseUri": "https://creativecommons.org/licenses/by/4.0/",
      "attribution": "Example Dictionary contributors",
      "sourceUrl": "https://example.com/dictionary"
    }
  ],
  "hostApi": 1
}
```

字段规则：

| 字段 | 规则 |
|---|---|
| `network.domains` | 1–8 个；精确 DNS 名，小写，最长 253；不得是 IP、localhost、`.local`、`.internal`；不接受通配符 |
| `network.timeoutMs` | 1000–15000，默认 8000 |
| `network.maxResponseBytes` | 4096–1048576，默认 1048576；不得超过全局上限 |
| `network.requestsPerLookup` | 固定 1（P3 v1）；其他值拒绝 |
| `request.method` | 仅 `GET` |
| `request.url` | HTTPS、无 userinfo、无 fragment、端口 443；host 必须在 `network.domains` |
| `request.query` | 键 1–16 个，值 1–256 字符；只允许 `{word}`、`{setting.<key>}` 占位；不允许 secret |
| `request.headers` | 仅 `Accept`、`Accept-Language`、`Authorization`；`Authorization` 只能引用 secret |
| `settings[].type = secret` | 仅 `net:http` 包允许；key 仍匹配 `settingKeyPattern`；可选 `required`（bool，默认 false）；不设 `defaultValue` |
| `response.format` | 仅 `json` |
| `response.root` | 可选；JSON path 子集；缺省为根 |
| `response.fields` | 必须含 `definition`；允许 `word`、`partOfSpeech`、`sourceUrl`、`license`、`attribution`、`licenseUri` |
| `response.maxEntries` | 1–20，默认 5 |
| `response.maxDefinitionChars` | 100–20000，默认 4000 |
| 贡献 `license`/`attribution` | 必填；`licenseUri`/`sourceUrl` 可选但必须是 https |

结构限额沿用 P1：贡献 ≤ 40、设置 ≤ 40、manifest ≤ 64 KB、包 ≤ 5 MB / 20 MB。P3 新增 `dictionarySource` 单插件 ≤ 8 个。

### 5.4 请求模型

**只允许 GET**。请求由宿主构造，插件不能提供完整 header 或 body。

模板语法：

- `{word}`：用户在词典查询框输入的词，先 `trim`，长度 1–256；放入 query 时使用 `Uri.encodeQueryComponent`，放入 path 时使用 `Uri.encodeComponent`。
- `{setting.<key>}`：读取 `PluginConfig` 合并默认值后的标量；只允许 text/number/toggle/select，不允许 secret；值按字符串编码。
- `{secret.<key>}`：只在 header 值中允许；读取 `pluginSecret_<id>`；未配置时：
  - 若该设置 `required=true`，本次查询失败，提示“需要配置密钥”；
  - 若可选，整个 header 省略（不能发送空 `Bearer `）。
- 其他 `{...}` 一律拒绝；不做递归展开；模板最多 1024 字符。
- query 键和值都做 URL 编码；禁止在模板里写死 `?`、`#`；`request.url` 只允许 path，不允许带 query（query 必须走 `request.query`）。

Header 规则：

- `Accept` 默认 `application/json`，可被 manifest 覆盖为 `application/json` 或 `application/*+json`。
- `Accept-Language` 只能由 manifest 固定，不支持用户输入。
- `Authorization` 值只允许 `Bearer {secret.<key>}` 或 `{secret.<key>}`；不允许拼接其他文本，避免 header 注入。
- 宿主强制覆盖 `User-Agent`、`Host`、`Content-Length`、`Connection`；manifest 指定这些直接拒绝。
- 不允许 `Cookie`、`Referer`、`Origin`、`X-Forwarded-*`。

### 5.5 响应模型（JSON path 子集）

语法：

```
path      := segment (('.' segment) | ('[' (index | '*') ']'))*
segment   := [A-Za-z_][A-Za-z0-9_-]{0,63}
index     := 0..999
```

示例：`data.entries[*].senses[*].definition`。

求值规则：

- 从 `response.root` 开始；`root` 缺省为整个 JSON。
- `segment` 只读对象键；缺失返回空。
- `[n]` 只读数组第 n 项；越界返回空。
- `[*]` 展开数组；后续路径对每个元素求值并扁平化。
- 最终值可以是字符串、数字、布尔、字符串数组、数字数组；其他类型转字符串或丢弃。
- `definition` 多值用 `\n` 连接；丢弃空串；总长度超过 `maxDefinitionChars` 截断并加省略号。
- `sourceUrl` / `licenseUri` 必须是 https URL，否则丢弃该字段（不阻断整个结果）。
- 每个条目必须有非空 `definition`；没有则跳过；全部为空返回“未找到词条”。
- 不执行任何表达式、函数、过滤、递归下降；解析器是纯数据遍历，不允许 `eval`。

安全限制：

- 响应体先按字节上限读取，再 UTF-8 解码；非法 UTF-8 拒绝。
- JSON 解析后限制深度 ≤ 32、节点数 ≤ 100000、字符串总长 ≤ 2 MB；超过拒绝。
- `response.maxEntries` 截断；每条 definition 截断；不把远程 HTML 当 HTML 渲染，UI 只用 `SelectableText`。
- 内容中的控制字符（除 `\n`、`\t`）剔除。

### 5.6 网络守卫

新增 `lib/service/network/plugin_network_guard.dart`：

1. **URL 校验**：`Uri.tryParse`；scheme 必须 `https`；无 userinfo、无 fragment；端口为空或 443；host 非空。
2. **主机规范化**：小写、去掉末尾点（但拒绝用户输入带末尾点的写法）、IDN 转 punycode；与 `network.domains` 精确比较。拒绝：
   - IP 字面量（IPv4/IPv6/十进制/八进制/十六进制）；
   - `localhost`、`*.localhost`、`.local`、`.internal`、`.home.arpa`；
   - 含 `@`、`%`、空格、反斜杠、控制字符；
   - 非 443 端口。
3. **DNS 解析**：解析所有 A/AAAA；任一地址属于 loopback、private、link-local、multicast、unspecified、broadcast、IPv4-mapped IPv6 私网段，拒绝整个请求。使用与连接相同的解析结果，防止 DNS rebinding；连接后再次校验 remote address。
4. **重定向**：`followRedirects = false`；3xx 一律失败，不读取 `Location`。
5. **代理**：尊重应用现有 `httpProxyEnabled` 设置；域名白名单仍在 URL 层强制。代理服务器被视为用户信任的出口，文档中明确这一点。若未来要禁止插件走代理，需单独评审。
6. **TLS**：不允许关闭证书校验；不允许自定义 `badCertificateCallback`；不导入插件证书。
7. **连接**：连接超时 5s、总超时 `network.timeoutMs`；使用独立 `Dio` 实例或 `HttpClient`，不复用 AI/同步的客户端；响应流读取上限 `maxResponseBytes + 1`，超过立即取消。

实现建议：不要用 `Dio().get` 的默认重定向和 JSON 自动解码；使用 `ResponseType.stream`，手动计数、解码和解析。Dio 拦截器只做日志脱敏和预算计数，不做安全判断。

### 5.7 限额、缓存与取消

| 维度 | 限制 | 超限行为 |
|---|---|---|
| 每插件并发 | 1 | 新请求排队，队列超时 2s 后失败 |
| 每插件频率 | 20 次/分钟（滑动窗口） | 返回 `rateLimited`，不自动重试 |
| 每插件每日 | 300 次 | 返回 `dailyLimit`，次日本地时间 0 点重置 |
| 全局并发 | 4 | 排队；队列满则失败 |
| 全局频率 | 60 次/分钟 | 返回 `rateLimited` |
| 单次查询请求数 | 1 | manifest 校验阶段拒绝其他值 |
| 超时 | `network.timeoutMs`（≤15s） | 取消请求，返回 `timeout` |
| 响应体 | `maxResponseBytes`（≤1 MiB） | 取消并返回 `responseTooLarge` |
| 缓存 | 每插件 64 条，TTL 10 分钟，仅内存 | 不落盘、不跨设备 |
| 取消 | 页面关闭/换词 | `CancelToken.cancel()`，不记为失败 |

- 计数器按插件 ID 存在内存；应用重启清零。P3 不写 prefs，避免频繁 I/O 和备份污染。
- 失败分类：`configuration`、`network`、`timeout`、`rateLimited`、`dailyLimit`、`invalidResponse`、`license`、`disabled`。UI 只显示可读文案，不显示完整 URL/响应。
- 不自动重试 4xx/5xx；429/503 可返回 `Retry-After` 给 UI 作为提示，但不自动重试。

### 5.8 密钥与隐私

新增 `PluginSettingType.secret` 与 `pluginSecret_<id>`：

```dart
const String pluginSecretPrefix = 'pluginSecret_';

Future<void> savePluginSecret(String id, String key, String value);
Future<void> removePluginSecret(String id, String key);
Map<String, String> pluginSecrets(String id); // 仅宿主网络层可读
```

规则：

- 密钥值只存 SharedPreferences，**不写日志、不进 `pluginConfig_`、不进设置导出、不进数据库备份、不进 WebDAV 同步**。
- 详情页只显示“已配置 / 未配置”，不提供回显；用户可以清除或替换。
- `PluginConfig.validate` 对 secret 键一律拒绝（secret 不属于普通配置对象）。
- `backup_safety.isCredentialPreference` 增加 `pluginSecret_`；即使 `includeSecrets=true` 也不导出（这是有意的强约束，和“插件密钥设备本地”一致）。
- 错误信息、诊断、`lastError` 不能包含 header 值、查询词、完整 URL；只允许插件 ID、错误码、域名、状态码。
- 导出确认页增加说明：“插件密钥不会随设置或备份导出，需要在每台设备重新配置。”
- 安全边界要写清楚：P3 不引入平台 Keychain/Keystore，密钥在 SharedPreferences 中仍是明文存储。本阶段保证的是“不随导出/备份/日志泄露”，**不能**防御已 root/越狱或被物理控制的设备；如果后续需要更强保护，P4/P5 再评估 secure storage 抽象，不能在本阶段假装已加密。

### 5.9 词典物化与 UI

`DictionarySourceHandler` 的职责：

- `validate`：manifest 的 `network`、`request`、`response`、license/attribution、域名与设置引用全部校验；任何一项失败在写入前拒绝整个安装。
- `apply`：为每个 `dictionarySource` 创建 `PluginDictionarySource` 并注册到 `DictionarySourceRegistry`；注册 ID 为 `plugin:<pluginId>:<sourceId>`。返回 `AppliedContribution(kind: 'dictionarySource', id: ...)`。
- `remove`：按 ID 注销；如果用户曾编辑过源名称（P3 不允许编辑插件源，避免哈希复杂度），直接注销；配置与密钥保留到卸载。
- `isApplied`：注册表存在且 owner 匹配。
- 失败隔离：单个源注册失败不影响同插件其他源；安装阶段任一源失败则整体回滚（与 P1 一致）。

UI：

- 词典查询的来源对话框分三组：“本地字典”“内置在线字典”“插件词典”。
- 插件源显示名称、网络徽标、许可/归属链接；首次勾选时提示“查询词会发送到 `api.example.com`”。
- 查询中/失败/无条目状态按源 ID 展示；单个插件源失败不影响其他源。
- 插件详情增加“网络”区块：域名、限额、最近一次错误码；不显示查询词或响应。
- 插件停用/卸载后，源从 UI 消失；`dictionaryLookupSources` 中的 token 保留，重装后恢复选中。
- 插件缺失（只恢复设置）时，源不显示，不报错；设置页提示“插件文件需重新安装”。

### 5.10 备份、导出与迁移

- `pluginState`、`pluginConfig_<id>` 照常进入设置导出；`pluginSecret_<id>` 永不进入。
- 插件包不进入备份；另一台设备恢复后插件为 `missing`，源不可用；重装后源恢复。
- `dictionaryLookupSources` 是设备本地设置，P3 不改变其“不随设置导出”的现状。若未来要导出源选择，必须单独评审 token 兼容和缺失插件语义。
- 导入时：
  - `pluginState` 严格解析；
  - `pluginConfig_*` 按 manifest 校验；未知键保留；
  - `pluginSecret_*` 即使出现在备份中也被忽略/剥离（防旧版本或手工构造的备份注入）。
- P3 不新增数据库迁移；`currentDbVersion` 保持 11。

### 5.11 许可与归属

- `dictionarySource` 必须声明 SPDX `license`、`attribution`；建议提供 `licenseUri`、`sourceUrl`。
- UI 展示来源与许可；`DictionaryEntry` 已有 `license`、`licenseUri`、`attribution`、`sourceUri` 字段，直接复用。
- 不缓存到磁盘、不批量抓取、不做全文索引；只响应用户主动查询。
- 插件作者需在 README 说明数据来源和许可；样例插件使用公开测试 API 或仓库内静态 JSON 服务（仅测试）。

### 5.12 实现结构

新增/修改文件：

| 文件 | 内容 |
|---|---|
| `lib/models/plugin_network.dart` | `PluginNetworkPolicy`、`PluginHttpRequestSpec`、`PluginJsonResponseSpec`，严格 `fromJson` |
| `lib/models/plugin_manifest.dart` | 解析 `network`；新增 `DictionarySourceContribution`；secret 设置类型；P3 能力集合 |
| `lib/service/network/plugin_network_guard.dart` | URL/主机/端口/私网/重定向校验 |
| `lib/service/network/plugin_http_client.dart` | 预算、超时、响应上限、取消、脱敏日志 |
| `lib/service/network/plugin_json_path.dart` | JSON path 子集解析与限额 |
| `lib/service/plugins/handlers/dictionary_source_handler.dart` | validate/apply/remove/isApplied |
| `lib/service/dictionary/plugin_dictionary_source.dart` | `DictionarySourceEntry` 的插件实现，调用网络与映射 |
| `lib/service/dictionary/dictionary_source_registry.dart` | 内置 + 插件源注册表 |
| `lib/service/plugins/plugin_secrets.dart` | `pluginSecret_<id>` 读写与清除 |
| `lib/config/shared_preference_provider.dart` | secret 方法；不暴露给普通设置 UI |
| `lib/service/local_data/backup_safety.dart` | 将 `pluginSecret_` 纳入凭据判断 |
| `lib/service/config_transfer/settings_value_validation.dart` | 拒绝 secret 出现在 `pluginConfig_`；导入剥离 `pluginSecret_` |
| `lib/widgets/dictionary/dictionary_sources.dart` | 插件源分组、网络提示 |
| `lib/widgets/dictionary/dictionary_lookup.dart` | 源 ID 化、插件源状态 |
| `lib/page/settings_page/plugins/plugin_detail_page.dart` | 网络权限、域名、限额、诊断 |

实现顺序（每步可编译、可测试）：

1. `plugin_network.dart` + manifest 解析 + 拒绝用例。
2. `plugin_json_path.dart` + 单测（不触网）。
3. `plugin_network_guard.dart` + 单测（注入 DNS 解析器）。
4. `plugin_http_client.dart` + 预算/超时/大小/取消测试（本地 HTTP server 或 mock adapter）。
5. `plugin_secrets.dart` + 导出/备份排除测试。
6. `dictionary_source_handler.dart` + 注册表 + 词典 UI。
7. 样例插件与端到端测试。

### 5.13 P3 测试矩阵

| 层级 | 覆盖 |
|---|---|
| manifest | 合法源、缺 license/attribution、缺 network、域名超限、通配符、IP、userinfo、非 443、http、POST、body、非法 header、非法模板、非法 JSON path、secret 未声明、source 未声明 net:http |
| URL/主机 | 大小写、末尾点、IDN、unicode 同形、`api.example.com.evil.com`、`evil.com@api.example.com`、`%40`、反斜杠、IPv4/十进制/IPv6、localhost、`.local`、私网段 |
| DNS | 解析到 127.0.0.1、10.x、192.168.x、169.254.x、::1、fc00::/7、fe80::/10、DNS rebinding（第一次公网、第二次私网） |
| HTTP | 200 JSON、404、500、429、重定向 301/302/307、无 Content-Type、`text/html`、gzip bomb、超 1 MiB、非法 UTF-8、慢响应、连接重置 |
| 解析 | 对象/数组根、`[*]`、多值 definition、缺字段、数字/布尔、非法 URL 字段、超深/超节点、控制字符 |
| 限额 | 每插件 1 并发、20/min、300/day、全局 4 并发、队列超时、取消不计费 |
| 密钥 | 未配置必填失败、可选省略 header、不进入导出/备份/日志/错误、清除后失效 |
| 生命周期 | 安装、停用、启用、卸载、升级、重启、missing、broken、源选择保留、域名变化重新确认 |
| UI | 三组来源、网络提示、单源失败隔离、许可/归属、无插件源空态 |
| 导出 | `pluginState`/`pluginConfig_` 往返；`pluginSecret_` 被剥离；`dictionaryLookupSources` 不导出；恶意备份拒绝 |

P3 手工验收：

1. 6 平台安装样例词典插件，查询一个词，确认结果只含纯文本、来源/许可可见。
2. 关闭网络，确认本地词典仍可用，插件源显示可读失败，不崩溃。
3. 把域名改成不在白名单的地址，确认安装/请求被拒；把重定向目标设为外域，确认不跟随。
4. 连续快速查询触发频率限制，停止后恢复；关闭页面取消请求。
5. 导出设置（含/不含密钥），确认密钥不在文件中；另一设备恢复后插件 missing，重装后配置恢复。
6. 卸载插件，确认源消失、配置清除、词典选择 token 不影响其他源。

### 5.14 P3 PR 拆分与回滚

| PR | 内容 | 验收 |
|---|---|---|
| **P3a** | manifest/`network`/`dictionarySource` 模型 + 严格校验 + 恶意包测试 | 不含网络实现也能全拒非法包 |
| **P3b** | 网络守卫 + HTTP 客户端 + JSON path + 限额/缓存/取消 | 本地 mock server 全绿；无真实外网依赖 |
| **P3c** | 密钥存储 + 导出/备份排除 + 处理器 + 词典注册表/UI | 端到端查询；密钥不泄露 |
| **P3d** | 样例插件、文档、6 平台验收、性能与错误文案 | DoD 全项 |

回滚：

- 移除 `net:http` 支持集合即可让所有网络插件安装失败；已安装插件的贡献在启动对账时被移除，配置/密钥保留。
- 更细的回滚：只移除 `DictionarySourceHandler` 注册，P2 注册表和其他插件不受影响。
- 不建议通过隐藏 UI 回滚；必须在能力/安装层拒绝，避免“装得上但不工作”。

---

## 6. 文件级改动清单

### 6.1 P2 新增

| 文件 | 内容 |
|---|---|
| `lib/service/registry/host_registry.dart` | `HostRegistry`、`RegistryEntry`、`RegistryOwner`、`RegistryDomain` |
| `lib/service/registry/registry_catalog.dart` | 六个域的实例与内置注册入口 |
| `lib/service/translate/translate_provider_registry.dart` | 翻译描述符与内置注册 |
| `lib/service/tts/tts_provider_registry.dart` | TTS 描述符与内置注册 |
| `lib/service/ai/reading_skill_registry.dart` | 阅读技能描述符与内置注册 |
| `lib/service/dictionary/dictionary_source_registry.dart` | 词典源描述符（P2 仅内置，P3 扩展插件源） |
| `lib/models/toolbar_action_definition.dart` | 工具栏内置动作描述符 |
| 对应测试 | 见 §4.7 |

### 6.2 P2 修改

| 文件 | 改动 |
|---|---|
| `lib/service/translate/index.dart` | 删除 `provider` switch；枚举保留为 UI 适配；列表由注册表过滤 |
| `lib/service/tts/tts_service.dart` | 删除 `provider` switch；`getTtsService` 走注册表 |
| `lib/service/tts/tts_service_provider.dart` | 描述符适配所需的最小接口（必要时） |
| `lib/service/dictionary/online_dictionary.dart` | 枚举改为描述符；host/URI 由条目提供 |
| `lib/service/dictionary/dictionary_preferences.dart` | token 解析、未知 token 保留 |
| `lib/service/ai/tools/ai_tool_registry.dart` | 实例化；未知 ID 保留、构建过滤 |
| `lib/service/ai/readany_skills.dart` | 列表来自注册表；保留退役定义 |
| `lib/service/ai/reading_skill_layout.dart` | 从注册表取内置技能 |
| `lib/models/selection_toolbar.dart` | 静态表由注册表生成；`validate()` 查注册表；序列化不变 |
| `lib/service/plugins/plugin_contribution_handler.dart` | 增加 `isApplied` |
| `lib/service/plugins/plugin_host.dart` | `_isMaterialised` 改为 handler 查询 |
| `lib/service/plugins/handlers/ai_prompt_handler.dart` / `selection_action_handler.dart` | 实现 `isApplied` |
| `lib/service/config_transfer/tts_config_transfer.dart` | services 来自注册表；未知 provider 保留 |
| `lib/service/config_transfer/settings_modules.dart` | 配置前缀 owner 覆盖测试 |
| `lib/service/config_transfer/settings_value_validation.dart` | 注册表驱动的 provider 校验 |
| 设置页 | 翻译/朗读/词典/AI/插件详情从注册表读取 |

### 6.3 P3 新增/修改

见 §5.12。P3 不应改动数据库、同步协议、TTS 播放管线、AI 供应商配置或 P1 的包格式（除新增可选字段）。

---

## 7. 测试矩阵汇总

| 阶段 | 必测 |
|---|---|
| P2 | 旧设置零丢失；六个注册表；旧工具栏 JSON；P1 插件生命周期；导入未知 provider；6 平台手工 |
| P3 | 恶意 manifest；SSRF/重定向/DNS；限额/取消；密钥不泄露；词典 UI；备份剥离；6 平台手工 |

CI 同序命令沿用 P1 §16.1：

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```

新增测试优先纯 Dart，不依赖真实外网；网络测试用本地 `HttpServer` 或注入的 `DioAdapter`，DNS 用注入解析器。

---

## 8. 时间表与验收

| 周 | 内容 | 产出 |
|---|---|---|
| W1 | P2a 注册表内核 + AI 工具/技能 | PR P2a + 单测 |
| W2 | P2b 翻译/TTS + 迁移 | PR P2b + 设置往返测试 |
| W3 | P2c 词典/工具栏 + 回归 | PR P2c + 6 平台基线 |
| W4–W5 | P3a/P3b 模型与网络守卫 | PR P3a/P3b + 安全测试 |
| W6 | P3c 处理器/密钥/UI | PR P3c + 端到端 |
| W7 | P3d 样例/文档/验收 | PR P3d + DoD 记录 |

P2 结束条件：旧设置零丢失、P1 行为不变、注册表可注入、6 平台打开设置页无异常。
P3 结束条件：恶意包全拒、白名单/限额/密钥测试全绿、6 平台真实查询、文档与样例可复现。

---

## 9. 风险登记

| 风险 | 阶段 | 影响 | 缓解 |
|---|---|---|---|
| 工具栏 `validate()` 改动导致旧配置被判非法 | P2c | 用户工具栏丢失 | golden test + 先读后写；保留旧 ID；不改序列化 |
| 注册表全局单例污染测试 | P2a | 测试串扰 | 实例注入；`forTesting` 空表；测试 tearDown 清理 |
| 未知 provider 被导入逻辑丢弃 | P2b | 跨设备配置丢失 | 显式保留未知键；测试覆盖 |
| `isApplied` 默认值误删新贡献 | P2 | 升级后贡献消失 | 未知 kind 返回 true；只对已知 handler 判断 |
| 域名校验被 userinfo/IDN/末尾点绕过 | P3 | SSRF | 规范化 + 精确比较 + 测试字典 |
| DNS rebinding | P3 | 访问私网 | 解析结果校验 + 连接后再校验 |
| 响应过大/压缩炸弹 | P3 | OOM | 流式计数、解压后上限、JSON 节点限制 |
| 密钥进备份/日志 | P3 | 凭据泄露 | 独立键、导出剥离、日志白名单、测试 |
| 插件源拖慢查询 | P3 | UI 卡顿 | 并发 1/源、超时、取消、失败隔离 |
| 许可/归属缺失 | P3 | 合规风险 | manifest 必填、UI 展示、安装拒绝 |

回滚总原则：P2 只回退代码；P3 先移除能力/处理器注册，再回退 UI；已装插件的数据保留，不执行破坏性迁移。

---

## 10. 交接运行手册

### 10.1 建议阅读顺序

1. 本文 §3（决策）与 §0.3（与 P0 的差异）。
2. P1 文档 §3–§6（包规范、贡献物化、哈希守卫）。
3. `lib/service/plugins/plugin_host.dart`、`plugin_contribution_handler.dart`、`plugin_contributions.dart`。
4. P2 域代码：`translate/index.dart`、`tts/tts_service.dart`、`dictionary/online_dictionary.dart`、`ai/tools/ai_tool_registry.dart`、`models/selection_toolbar.dart`。
5. P3 前置：`network/http_proxy_overrides.dart`、`backup_safety.dart`、`settings_value_validation.dart`。

### 10.2 术语

| 术语 | 含义 |
|---|---|
| 注册表 / registry | 按域维护的 ID → 描述符表，替代枚举 switch 与静态 const |
| 描述符 / entry | 一个 provider/工具/技能/动作的元数据与工厂 |
| owner | 条目归属：内置或某个插件 |
| alias | 旧持久化 token 到新 ID 的映射；P2 只用于兼容 |
| `plugin:` | 插件贡献 ID 命名空间；工具栏用 `custom-plugin:` |
| `net:http` | P3 能力令牌，允许宿主代理 HTTP |
| `dictionarySource` | P3 声明式词典源贡献 |
| `pluginSecret_` | 设备本地插件密钥，永不导出 |
| 网络守卫 / NetworkGuard | URL、主机、DNS、端口、重定向的集中校验 |

### 10.3 已知坑

- 不要给 P2 加“迁移脚本”：D10 的设计就是旧 token 即新 ID；加迁移反而制造双写和回滚风险。
- 不要改 `SelectionToolbarConfig` 的序列化字段或 `custom-` 前缀规则；P1 插件动作依赖它。
- 不要在 `PluginHost` 里重新写 `switch (kind)`；P2 的对账必须走 handler。
- 不要复用 `pluginConfig_` 存密钥；P3 的 secret 必须独立键。
- 不要用 `Dio` 默认重定向/自动 JSON 解析处理插件响应；必须流式限量、手动解析。
- 不要把查询词写进日志或错误文案；词典查询可能包含用户正在阅读的敏感内容。
- 不要允许插件覆盖内置 ID；注册表冲突必须在安装阶段失败，而不是运行时覆盖。
- 不要假设 OHOS 的网络行为与 Android 完全一致；P3 需要在 OHOS 真机验证代理、TLS 和超时。

### 10.4 待确认问题

1. P3 的 `dictionarySource` 是否只允许 JSON，还是要在 v1 就支持一个极简 HTML 文本提取？本文默认 JSON-only。
2. 插件密钥是否允许 `includeSecrets=true` 时导出？本文默认**永远不导出**；如维护者要求可导出，需要单独的安全评审和 UI 二次确认。
3. P3 是否允许插件声明多个域名用于同一 API 的主备？本文允许 1–8 个，但每次请求只能命中一个；不允许运行时切换。
4. P2 的注册表是否需要在插件详情页展示“运行时注册项”？本文建议展示，但可作为 P2c 的可选 UI。
5. P3.1 的翻译/TTS 插件是否复用同一 `PluginHttpClient`？本文建议复用，但 TTS 的音频响应和流式播放需要单独评审。

---

## 11. 与 P0/P1、P4 的接口约定

| 接口 | P2/P3 保证 | P4 使用 |
|---|---|---|
| `PluginContributionHandler` | 增加 `isApplied`；validate/apply/remove 不变 | 脚本贡献沿用同一生命周期 |
| `AppliedContribution` | 形状不变；kind/id/hash | 脚本贡献记录 entry/hash |
| `HostRegistry` | 插件条目 owner 可注销；内置不可覆盖 | 脚本注册的工具/翻译器走同一注册表 |
| `PluginConfig` | 普通配置可导出；secret 独立 | 脚本设置沿用 |
| `net:http` | P3 只给声明式词典 | P4 脚本网络仍走宿主代理，不直接暴露 socket |
| `dictionarySource` | P3 的声明式源 | P4 可由脚本源补充，但不替代白名单 |

P4 的脚本运行时不应绕过 P3 的网络守卫；如果脚本需要网络，能力仍是 `net:http`，请求仍由宿主代理构造/审计。P3 的限额和日志脱敏是 P4 的基础设施，不是一次性代码。

---

## 12. 文档维护

- 本文是设计稿；实现落地后，把每节的“建议/默认”改成“已实现”，并补充实际测试数量与 6 平台验收记录。
- P2/P3 的实现若偏离 D10–D22，必须在本文件新增“决策变更”小节，说明原因、影响和回滚，不允许静默改变。
- 与用户可见行为相关的变更，同步更新 `docs/SETTINGS.md` / `docs/SETTINGS_zh.md`、`docs/LOCAL_DICTIONARIES.md` 与 `docs/README.md` 索引。
- 文档语言：P1 文档目前是中文工作稿；本文同为中文。合并前由维护者决定是否补英文版，索引先按现有 P1 条目风格加入。
