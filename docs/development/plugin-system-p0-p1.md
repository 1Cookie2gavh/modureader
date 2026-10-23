# 插件系统执行文档（P0 规范冻结 + P1 声明式插件）

Status: P1a/P1b/P1c implemented, pending review · 2026-10-24 · 基线 `main` @ `0feceeb9` (Modu 1.3.1+10152) · 本轮实施范围：**P1b + P1c**

本文档覆盖 **P0（设计冻结）** 与 **P1（声明式插件）**，其中 P1 拆为 P1a（安装 + AI Prompt 注册 + 示例插件）、P1b（划词动作 + 插件设置）、P1c（配置导出）。P2–P5（注册表化、声明式网络插件、WebView JS 脚本宿主、生态加固）见 §0 路线图与 §14 衔接章节，不在本期实现范围。

---

## 0. 交接摘要（先读这一节）

### 0.1 目标形态与交付路线

产品目标是 **C：插件可在沙箱内执行脚本**。但依赖顺序决定了不能先做运行时：

| 阶段 | 内容 | 交付物 | 预估 | 门禁 |
|---|---|---|---|---|
| **P0** | 规范冻结：包格式、能力模型、Host API、`ScriptRuntime` 接口、威胁模型、商店合规 | 本文件 §2–§4（规范即文档，不再拆 `PLUGIN_SPEC.md`） | 2–3 人日 | 规范评审通过；manifest 能表达脚本贡献而无需改 schema |
| **P1** | 声明式最小闭环：安装/启停/卸载/升级 + **AI Prompt 注册（`aiSkill`）** + **划词动作（`selectionAction`）** + 设置迁移 | 本文件 §5–§13 | 11–14 人日（分 P1a/b/c） | 6 平台装/卸/停用；示例插件可用；恶意包全拒 |
| **P2** | 注册表化：TTS、翻译、词典、AI 工具/技能、工具栏分发改 ID 注册表 | 注册表 API + 迁移垫片 | 8–12 人日 | 存量配置零丢失；全量回归 |
| **P3** | 声明式网络插件：词典 HTTP 源、endpoint 模板、域名白名单与限额 | 安全评审 + 限额测试 | 8–10 人日 | 越权请求被拒；备份往返一致 |
| **P4** | 脚本运行时 v1：`ScriptRuntime` + WebView 实现、Host API 桥、看门狗 | 脚本样例 2–3 个 | 10–15 人日 | 沙箱逃逸评审；iOS/Android 真机；OHOS 明确降级 |
| **P5** | 生态与加固：签名/撤销、打包 CLI、开发者面板、模板仓库 | 开发者文档 + CLI | 8–10 人日 | 外部开发者 1 小时跑通样例 |

总计约 47–64 人日（单人 9–13 周），关键路径 P0 → P1 → P2 → P4。

**P1 内部再拆三个 PR**（本阶段不引入 JS）：

| PR | 内容 |
|---|---|
| **P1a（已实现）** | 插件包安装/启停/卸载/升级 + `aiSkill` 提示词注册 + 示例插件 + 设置页 + 单测 |
| **P1b** | `selectionAction` 划词动作（复用 prompt 机制，涉及工具栏名额与哈希守卫）+ 插件设置表单与 `pluginConfig_` |
| **P1c** | 插件状态/配置加入设置导出与校验（`settings_modules`、`_types`、`value_validation`） |

这样首个 PR 端到端可演示，且不触碰划词工具栏与配置导出两条高风险路径。

**为什么不是先做 C**：脚本宿主一旦先落地，会倒逼 manifest、能力模型、配置迁移返工；且 iOS 只豁免“由 WebKit/WKWebView 解释执行”的代码，内嵌 QuickJS 或动态库在 iOS/Android/HarmonyOS 三处都有政策或工具链风险。因此脚本路线锁定 **WebView JS**，并把它作为第五种贡献类型挂到已稳定的注册表上。

### 0.2 当前仓库状态（2026-10-23）

- 基线：`main` = `origin/main` = `upstream/main` = `0feceeb9`（Modu 1.3.1+10152），工作区此前干净；本轮已快进合并 19 个上游提交并推送。
- 本轮改动：新增 `docs/development/plugin-system-p0-p1.md`，并在 `docs/README.md` 增加索引项。
- 2026-10-23 后续：P1a 已实现（见 §16.6 v0.3）：新增 `lib/models/plugin_manifest.dart`、`plugin_state.dart`、`lib/service/plugins/`、`lib/page/settings_page/plugins/`、`scripts/dev/pack_plugin.dart`、`docs/examples/plugins/prompt-pack/` 与对应测试；修改 `main.dart`、`Prefs`、`get_base_path.dart`、设置入口与 `pubspec.yaml`（显式 `pub_semver`）。未改动数据库、同步、TTS/翻译/词典、划词工具栏与设置导出。
- 2026-10-23 P1b/P1c（见 §16.6 v0.4）：开放 `ui:selection-action`，新增 `SelectionActionContribution` 与 `SelectionActionContributionHandler`（24 名额、名称/图标校验、哈希守卫、用户编辑保留为 `custom-*`）；启用 `pluginConfig_<id>` 与详情页插件设置表单；`pluginState`/`pluginConfig_*` 接入设置导出、导入与严格校验，并补充中英文设置文档。数据库仍为 v11，未改 `SelectionToolbarConfig.validate()`。
- 2026-10-24 示例插件升级到 1.1.0（见 §16.6 v0.5）：增加一个 `selectionAction` 与四种 `settings`，README 与样例测试同步；用于手工验收 P1b 的安装、停用、卸载与设置备份。

### 0.3 决策状态

已确认：

- 目标形态 C，分阶段推进；本期只写并实现 P0–P1。
- **首个 PR 范围**：插件安装 + `aiSkill`（AI Prompt）注册 + 示例插件；不含 JS、划词动作、配置导出。
- P1 按能力拆分：P1a 安装 + AI Prompt 注册 + 示例插件；P1b 划词动作 + 插件设置；P1c 配置导出。三者可独立回滚。
- 脚本宿主方向：**WebView JS 唯一宿主**（不在 P4 引入 QuickJS/原生动态库）。
- 平台：全平台，尽量遵循应用商店规范，不按平台写死能力。

待确认（默认值，见 §15）：

1. 插件提示词默认启用。
2. 设置导出中「插件」模块默认包含（P1c 已实现，`all` 与 `plugins` 作用域均包含）。
3. 「插件」入口不做开发者选项门控。
4. 样例插件使用 CC0。

### 0.4 下一步

P1a/P1b/P1c 已实现并通过本地自动化测试。下一步：

1. 评审 P1b/P1c 的代码与本文档；按 §10 做 6 平台手工验收。
2. 重点回归：24 个自定义划词名额边界、用户编辑条目在卸载后的保留、设置备份往返与缺失插件提示。
3. 进入 P2 前补一次真实插件包的跨设备验收（安装 → 停用 → 备份 → 另一设备恢复 → 重新安装）。

### 0.5 实现守卫（P1 全程）

- 不修改 `SelectionToolbarConfig.validate()`；插件动作按现有 `custom-` 规则物化。
- 不新增数据库表、不 bump `currentDbVersion`（P1 保持 11）。
- 不引入脚本运行时/新原生依赖（P1 纯数据）。
- 不把插件 prompt 全文、用户书籍内容或凭据写入日志。
- 不让插件设置出现 `password` 类型（明文凭据会进设置导出，见 §5.2）。
- 插件包文件不进入设置备份；备份只带 `pluginState` 与 `pluginConfig_*`。

---

## 1. 目标与非目标

### 1.1 本期目标

1. 冻结插件包规范 v1：包结构、`manifest.json`、能力令牌、版本与限额、拒绝理由，且**预留脚本贡献位而无需改 schema**。
2. 落地一个可安装、可启停、可卸载、可升级的插件宿主，插件包为**纯数据**，不含任何可执行代码。
3. 首批贡献类型：`aiSkill`（AI Prompt 注册）与 `selectionAction`（划词工具栏动作），分别物化为用户提示词与自定义 AI 命令，并通过 `ContributionHandler` 注册表挂载，为后续类型留位。
4. 插件状态与插件设置持久化，并接入设置导出/导入；插件包文件不进入备份。
5. 6 平台（Android / iOS / macOS / Windows / Linux / HarmonyOS）行为一致：**安装、启停、卸载、插件设置与设置迁移全部可用**。

### 1.2 非目标（本期明确不做）

- 不执行任何插件代码（JS/Dart/原生）。
- 不允许插件自带 Flutter UI、不允许插件访问书库、笔记、AI Key、同步凭据。
- 不做插件市场、不做远程安装、不做签名校验（只做 SHA-256 完整性校验）。
- 不新增数据库表，不修改 DB 版本（保持 `currentDbVersion = 11`）。
- 不把插件包纳入设置备份（备份只带状态与配置，见 §5.4）。
- 不修改 `AiToolRegistry` / 阅读技能策略 / TTS / 翻译 / 词典分发（这些属于 P2）。

### 1.3 完成定义（DoD，P1）

- `flutter analyze` 无新增告警；`flutter test` 全绿；新增测试覆盖 §10 中标记 P1a/P1b/P1c 的条目。
- 用样例插件在 6 平台完成「安装 → 启用 → AI 提示词选择器出现模板 → 停用消失 → 卸载清理」。
- 含 `selectionAction` 的包在 6 平台完成「安装 → 划词工具栏出现动作 → 停用/卸载移除 → 用户编辑后保留」。
- 设置备份在另一设备恢复后插件显示 `missing`，重新安装后设置仍在；非法 `pluginState`/`pluginConfig_*` 被整体拒绝。
- 恶意包（路径穿越、zip bomb、重复 id、超大 manifest、未知能力）全部被拒绝并给出可读原因。
- 插件状态重启后保持；包缺失时显示 `missing` 且不崩溃。

---

## 2. 已冻结的设计决策

| 编号 | 决策 | 理由 |
|---|---|---|
| D1 | `contributes[]` 用字符串 `kind` + 整数 `schema`，未知 kind **忽略并告警** | 前向兼容：P4 的 `script` 贡献不需要老客户端改 schema |
| D2 | 未知 **能力**（capability）拒绝安装，未知 **贡献 kind** 忽略 | 安全默认拒绝；展示默认宽容 |
| D3 | 能力令牌而非布尔开关，安装时逐项展示授权 | 为 P3/P4 的网络、脚本、书库读取预留同一模型 |
| D4 | 脚本运行时抽象为 `ScriptRuntime`（`none` / `webview` / 未来适配器），由「能力 + 运行时可用性」选择 | 不在本期写死平台分支，OHOS 以后可接入 overlay 宿主 |
| D5 | 插件状态存 SharedPreferences 单键 `pluginState`，插件配置存 `pluginConfig_<id>` | 复用现有导出/迁移管线；P1 不引 DB 迁移风险 |
| D6 | `minAppVersion` 用 `pub_semver` 比较，只比较 `x.y.z`（忽略 `+build`） | 与现有 `getAppVersion()` 输出兼容 |
| D7 | 贡献物化采用**快照 + 哈希守卫**，不做实时引用 | 卸载/升级不误删用户编辑；实例化成本低 |
| D8 | 宿主初始化幂等，允许 Android 延迟启动与 macOS 迁移后二次初始化 | 见 `lib/main.dart` 的两条启动路径 |
| D9 | 贡献类型由 `ContributionHandler` 注册表按 `kind` 分发，宿主不写 `switch` | 首个 PR 只注册 `aiSkill`，P1b/后续引擎按同一接口追加 |

### 2.1 决策记录（ADR）说明

P0 不单独产出 ADR 文件：上表的「决策 / 理由」两列就是 ADR 的 Decision / Context 摘要，冲突时以本表为准。后续如需正式 ADR，可直接从本表拆出 `docs/development/adr/`，不改变本文档的约束力。

---

## 3. 插件包规范 v1

### 3.1 包结构

```
my-pack-1.0.0.moduplugin        # 实际是 zip，扩展名仅用于区分
├── manifest.json               # 必需，UTF-8，≤ 64 KB
├── LICENSE                     # 可选；license 字段为 SPDX 标识
├── README.md                   # 可选；详情页只显示纯文本前 8 KB
└── assets/…                    # 可选；本期不加载，保留给 P3/P4
```

- 扩展名接受 `.moduplugin` 与 `.zip`；文件选择器过滤两者。
- 包内路径必须是相对路径，禁止 `..`、绝对路径、盘符与符号链接。反斜杠在 `archive` 解码阶段会被归一化为 `/`，安装器按归一化后的路径处理并再做包含性检查（见 §9.1）；不要依赖反斜杠表达目录层级。
- 包上限：压缩后 5 MB、解压后累计 20 MB、条目 ≤ 200、单文件 ≤ 1 MB、压缩比 > 200:1 时拒绝（zip bomb 防护）。

### 3.2 `manifest.json`

```json
{
  "schemaVersion": 1,
  "id": "com.example.prompt-pack",
  "version": "1.1.0",
  "name": { "zh-CN": "示例提示词包", "en": "Example prompt pack" },
  "description": { "zh-CN": "两个 AI 提示词模板、一个划词动作和一组插件设置。", "en": "Two AI prompts, one selection action and plugin settings." },
  "author": { "name": "Example", "url": "https://example.com" },
  "license": "CC0-1.0",
  "minAppVersion": "1.3.1",
  "capabilities": ["ai:prompt-pack", "ui:selection-action"],
  "contributes": [
    {
      "kind": "aiSkill",
      "schema": 1,
      "id": "deep-summary",
      "name": { "zh-CN": "深度摘要", "en": "Deep summary" },
      "description": { "zh-CN": "按论点—证据—结论归纳。", "en": "Claim–evidence–conclusion." },
      "prompt": "阅读当前内容，按“核心结论 / 论证链 / 证据 / 隐含假设”输出。",
      "enabled": true
    },
    {
      "kind": "aiSkill",
      "schema": 1,
      "id": "socratic-questions",
      "name": { "zh-CN": "苏格拉底提问", "en": "Socratic questions" },
      "description": { "zh-CN": "针对当前内容提出 3 个追问。", "en": "Three follow-up questions." },
      "prompt": "针对当前内容提出 3 个由浅入深的追问，并说明每个问题想检验什么。",
      "enabled": true
    },
    {
      "kind": "selectionAction",
      "schema": 1,
      "id": "explain-selection",
      "name": { "zh-CN": "简明解释", "en": "Explain simply" },
      "icon": "lightbulb",
      "prompt": "解释 {selection} 的含义与关键概念，简明直接，不编造。",
      "scope": "context",
      "enabled": true
    }
  ],
  "settings": [
    {
      "key": "tone",
      "type": "select",
      "label": { "zh-CN": "回答语气", "en": "Answer tone" },
      "options": ["concise", "detailed"],
      "defaultValue": "concise"
    },
    {
      "key": "quote_original",
      "type": "toggle",
      "label": { "zh-CN": "引用原文", "en": "Quote the original" },
      "defaultValue": false
    },
    {
      "key": "max_words",
      "type": "number",
      "label": { "zh-CN": "最大字数", "en": "Maximum words" },
      "defaultValue": 300
    },
    {
      "key": "hint",
      "type": "tip",
      "description": { "zh-CN": "设置会被保存和导出；当前版本不执行插件代码。", "en": "Settings are stored and exported; this version runs no plugin code." }
    }
  ],
  "hostApi": 1
}
```

字段规则：

| 字段 | 规则 |
|---|---|
| `schemaVersion` | 必须为 `1`；更高版本拒绝安装（提示升级应用） |
| `id` | `^[a-z0-9]([a-z0-9._-]{1,62}[a-z0-9])?$`，全局唯一，安装目录名 |
| `version` | 严格 semver `x.y.z`；升级必须大于已装版本，降级需先卸载 |
| `name`/`description`/`label` | 字符串或 `{locale: string}`；locale 键接受 `zh-CN`/`en` 等，回退链：精确 → 语言前缀 → `en` → 首个值 |
| `license` | SPDX 标识，必填；UI 展示并要求用户确认 |
| `minAppVersion` | 可选；`pub_semver` 解析，高于当前版本则拒绝 |
| `capabilities` | 见 §3.4；P1 开放 `ai:prompt-pack` 与 `ui:selection-action` |
| `contributes` | ≤ 40 项；`kind` 见 §3.3 |
| `settings` | 可选；P1b 起在详情页渲染，类型限 `text`/`number`/`toggle`/`select`/`tip`，不支持 `password`（明文凭据风险，见 §5.2） |
| `hostApi` | 可选，默认 1；本期只接受 1 |

### 3.3 贡献类型（按阶段开放）

| `kind` | 阶段 | 语义 | 关键字段 |
|---|---|---|---|
| `aiSkill` | **P1a 实现** | 用户提示词模板，出现在 AI 提示词选择器 | `id` `name` `description` `prompt` `enabled` |
| `selectionAction` | **P1b 实现** | 划词工具栏动作，执行时发送 prompt 到 AI 面板 | `id` `name` `icon` `prompt` `scope` `enabled` |
| `translatorProvider` | P2 | 翻译引擎声明 | — |
| `ttsProvider` | P2 | TTS 引擎声明 | — |
| `dictionarySource` | P3 | 词典 HTTP 源映射 | — |
| `script` | P4 | `{entry, runtime:"webview", api:1}`，本期解析但不执行 | `entry` |

未识别的 `kind`：记录一条 warning 日志，跳过该项，安装继续。这是 D1 的前向兼容保证；因此 P1a 客户端安装含 `selectionAction` 的包时不会失败，只是该动作不生效（用户会看到「已跳过 N 项」提示）。

### 3.4 能力令牌

| 令牌 | 含义 | P1 |
|---|---|---|
| `ai:prompt-pack` | 添加提示词模板 | 允许 |
| `ui:selection-action` | 向划词工具栏添加动作 | 允许（P1b 起） |
| `net:http` | 由宿主代理发起 HTTP（域名白名单） | 拒绝安装 |
| `script:run` | 执行包内 JS | 拒绝安装 |
| `library:read` | 读取书库/笔记 | 拒绝安装 |
| `storage:plugin` | 读写插件私有目录（恒允许，不需要声明） | 隐式 |

拒绝信息必须列出「缺失能力」清单，便于用户判断是否为版本过旧。注意与贡献 kind 的差异：**未知 kind 忽略、已知但未开放的能力拒绝**，这是 D2 的边界。

### 3.5 校验顺序与拒绝理由

1. 文件存在、大小 ≤ 5 MB、可解压。
2. 条目数与解压总量限额、路径安全检查。
3. `manifest.json` 存在、≤ 64 KB、合法 JSON。
4. `schemaVersion` → `id` → `version` → `license` → `hostApi` → `minAppVersion`。
5. 能力集合 ⊆ **当前开放集合**（P1 为 `ai:prompt-pack`、`ui:selection-action`）。已知但未开放的能力报「需要更高版本」，未知能力报「未知能力」，两者都拒绝安装。
6. 贡献项逐个校验（数量、id 唯一、字段类型、prompt ≤ 8000 字符、显示名 ≤ 40 字符；`selectionAction.name` ≤ 30 字符、`icon` ∈ 现有 `iconIds`、自定义动作总数 ≤ 24）。
7. 设置项校验（key 唯一、类型受支持、`select` 有 options、`defaultValue` 类型匹配）——P1b 起写入 `pluginConfig_<id>`。
8. 与已装插件冲突检查（同 id 的版本关系）。

每个失败分支返回结构化 `PluginInstallError { code, message, offendingEntry? }`，UI 直接展示 message，日志只记 code 与 entry，不记 prompt 全文。

### 3.6 示例插件（P1b 后更新）

位置：`docs/examples/plugins/prompt-pack/`

```
prompt-pack/
├── manifest.json          # 即 §3.2 的示例：两个 aiSkill、一个 selectionAction、四个 settings
├── LICENSE                # CC0-1.0
└── README.md              # 安装步骤、贡献说明、如何改 prompt
```

打包：`dart run scripts/dev/pack_plugin.dart docs/examples/plugins/prompt-pack`，输出 `prompt-pack-1.1.0.moduplugin`，再在设置 → 插件 → 安装中选中。样例必须能被自动化测试直接构造（不依赖手工 zip），因此 `PluginPackageReader` 的测试用同一份目录打成内存 zip。`sample_plugin_test.dart` 会安装仓库内的样例并断言两条提示词、一个划词动作与设置声明。

---

## 4. 运行时架构（P1）

### 4.1 组件

| 组件 | 位置 | 职责 |
|---|---|---|
| `PluginManifest` / `PluginContribution` / `PluginSettingSpec` | `lib/models/plugin_manifest.dart` | 纯数据 + 严格 `fromJson`，手写解析（不用 freezed，避免宽松的未知字段行为） |
| `PluginRecord` / `PluginState` | `lib/models/plugin_state.dart` | 安装记录：id、version、enabled、sha256、installedAt、applied 贡献 id、lastError |
| `PluginPackageReader` | `lib/service/plugins/plugin_package.dart` | 解压到 staging、限额与路径安全、manifest 解析 |
| `PluginPaths` | `lib/service/plugins/plugin_paths.dart` | `plugins/`、`plugins/.staging/`、`plugins/.trash/` 的路径与创建 |
| `PluginHost` | `lib/service/plugins/plugin_host.dart` | 单例 + `ChangeNotifier`；initialize/install/enable/disable/uninstall/upgrade；状态持久化；错误隔离 |
| `PluginContributionHandler` | `lib/service/plugins/plugin_contribution_handler.dart` | 贡献类型接口 + 按 `kind` 的注册表（D9） |
| `SelectionActionHandler` | `lib/service/plugins/handlers/selection_action_handler.dart` | P1b：把 `selectionAction` 物化为工具栏 `aiCommand`，含 24 名额与哈希守卫 |
| `PluginConfig` | `lib/service/plugins/plugin_config.dart` | `pluginConfig_<id>` 的编解码、导入校验与默认值合并 |
| `PluginContributions` | `lib/service/plugins/plugin_contributions.dart` | 编排 apply/remove：逐个 handler 调用、快照回滚、哈希守卫 |
| `ScriptRuntime` | `lib/service/plugins/script_runtime.dart` | 仅接口与 `NoopScriptRuntime`；P4 实现 `WebViewScriptRuntime` |
| 设置页 | `lib/page/settings_page/plugins/` | 列表、详情、权限、安装/卸载交互 |

`PluginHost` 对外 API（形状冻结，供 P2–P4 扩展）：

```dart
Future<void> initialize();                 // 幂等
List<PluginRecord> get plugins;
PluginRecord? byId(String id);
Future<PluginInstallResult> install(File package);
Future<void> enable(String id);
Future<void> disable(String id);
Future<void> uninstall(String id);
void dispose();                             // P1 仅释放监听
```

### 4.2 状态机

```
                 install                 enable
  (无) ───────────────▶ installed ───────────────▶ enabled
                          │  ▲                      │
              disable ◀───┘  └────── enable ◀───────┘
                          │
       包缺失/清单损坏 ──▶ broken / missing（不可启用，可卸载）
```

- `enabled` 的唯一副作用是「贡献已物化」；P1 不执行任何插件逻辑。
- `broken`：manifest 解析失败或哈希不符；保留配置，UI 提供「重新安装」与「卸载」。
- `missing`：`pluginState` 有记录但目录不存在（典型：只恢复了设置备份）。

### 4.3 启动时序

```
main()
 └─ Prefs().initPrefs()                       # 已有，main.dart:103
 └─ _startConfiguredApp()
     ├─ initBasePath()                        # 已有，main.dart:170
     ├─ AnxLog.init(); AnxError.init()
     ├─ DBHelper().initDB()                   # 已有，main.dart:173
     ├─ PluginHost.instance.initialize()      # 新增：try/catch，失败不阻断启动
     ├─ Server().start()                      # 已有
     └─ runApp(...)                           # 已有
```

- `initialize()` 内部 `_initialized` 守卫；macOS 迁移完成后再次调用只做「重新扫描 + 重新应用贡献」，不重复注册监听（`main.dart:462-475`）。
- 关闭：`onWindowClose()` 中 `PluginHost.instance.dispose()`，位置在 `DBHelper.close()` 之前（`main.dart:291`）。
- 紧急开关：`--dart-define=MODU_PLUGINS=false` 时 `initialize()` 直接返回，用于插件导致启动异常时的构建级回滚。

### 4.4 存储布局

```
<basePath>/plugins/
├── com.example.prompt-pack/
│   ├── manifest.json
│   └── README.md
├── .staging/<uuid>/            # 安装临时目录，启动时清空
└── .trash/<uuid>/              # 卸载/升级临时目录，启动时清空
```

`initBasePath()` 增加 `plugins/` 创建（`lib/utils/get_path/get_base_path.dart:67-87`）。Android 的 `prepareAndroidStorage()` 只负责把旧数据迁到应用私有外部目录，之后仍走 `_startConfiguredApp() → initBasePath()`（`lib/utils/get_path/android_storage.dart:19-32`、`lib/main.dart:155-173`），因此插件目录不需要 Android 专属分支。

### 4.5 错误隔离

- 任何单个插件的异常只影响该插件：捕获 → `lastError`（≤ 500 字符，脱敏）→ 状态置 `broken` 或保持 `disabled`。
- `initialize()` 整体异常：记录 `AnxLog.severe`，注册表置空，应用继续启动。
- 贡献物化失败：回滚到安装前的 `userPrompts` 与 `selectionToolbar` 快照，安装失败并清理 staging。

### 4.6 贡献类型注册表（D9）

宿主不写 `switch (kind)`，而是维护 `Map<String, PluginContributionHandler>`：

```dart
abstract class PluginContributionHandler {
  String get kind;                       // 'aiSkill'
  Set<String> get requiredCapabilities;  // {'ai:prompt-pack'}
  void validate(PluginContribution c, PluginManifest m);   // 抛 PluginInstallError
  Future<AppliedContribution> apply(PluginManifest m);      // 写入宿主数据结构
  Future<void> remove(AppliedContribution applied);         // 哈希守卫后清理
}
```

P1 注册 `AiPromptContributionHandler` 与 `SelectionActionContributionHandler`；P2/P4 的引擎与脚本沿用同一接口。新增类型 = 新增一个 handler 文件 + 一行注册，不需要改 `plugin_host.dart`。

---

## 5. 配置、导出与迁移

### 5.1 新增 Prefs 键

| 键 | 阶段 | 内容 |
|---|---|---|
| `pluginState` | **P1a** | `{"schemaVersion":1,"plugins":[PluginRecord…]}` |
| `pluginConfig_<id>` | **P1b** | 插件设置值对象，仅保存用户改过的键；缺失键使用 manifest `settings[].defaultValue` |

`Prefs` 已实现：

```dart
PluginState get pluginState;
Future<void> savePluginState(PluginState state);   // 写后 notifyListeners()
Future<void> removePluginData(String id);          // 卸载：删状态记录与 pluginConfig_<id>

Map<String, dynamic> pluginConfig(String id);
Future<void> savePluginConfig(String id, Map<String, dynamic> values);
```

### 5.2 接入设置导出/导入（P1c，已实现）

三处同时接通：

1. `lib/service/config_transfer/settings_modules.dart`
   - `settingsModuleKeys['plugins'] = 'pluginState'`
   - `settingsModuleForKey()` 增加 `if (key.startsWith('pluginConfig_')) return 'plugins';`
2. `lib/service/config_transfer/global_settings_transfer.dart`
   - `_types` 增加 `'pluginState': 'string'`
   - `_type()` 前缀白名单增加 `'pluginConfig_'`
3. `lib/service/config_transfer/settings_value_validation.dart`
   - `pluginState`：`PluginState.parseStrict()` 校验 `schemaVersion`、id 格式与唯一性、字段类型、记录数上限（100）。
   - `pluginConfig_*`：必须是 JSON 对象；插件已安装时按 manifest `settings` 逐项校验类型与 `select` 选项，缺失时只校验对象形状；未知键保留，便于新版本设置向后兼容。

导出后插件包**不随设置走**：导入端会出现 `missing`，UI 文案说明「插件文件需重新安装，配置已保留」。

凭据边界：插件设置不支持 `password` 类型，因此 `pluginConfig_*` 中不会出现密钥；P3 引入需要密钥的插件（词典/TTS）时，必须同步扩展 `isCredentialPreference()`（`lib/service/local_data/backup_safety.dart`）把 `pluginConfig_*` 纳入敏感键判断，并按 manifest 声明的字段做脱敏，否则 `includeSecrets=false` 的导出会泄露插件密钥。

### 5.3 数据库备份

`Prefs.buildPrefsBackupMap()` 会打包 SharedPreferences，因此插件状态会随数据库备份一起走，无需改动；`test/service/config_transfer/plugin_settings_transfer_test.dart` 验证恢复后 `pluginState` 可解析、`missing` 状态正确。

### 5.4 卸载语义

- 卸载删除：插件目录、`pluginState` 中的记录、由该插件物化的提示词（哈希守卫见 §6.2）。
- 不删除：被用户编辑过的提示词——改为普通提示词保留（见 §6.2）。
- 升级：先装到 staging → 校验 → 旧目录移入 `.trash` → 新目录就位 → 先移除旧贡献再应用新贡献 → 清理 `.trash`。

---

## 6. 贡献物化规则

### 6.1 `aiSkill` → 用户提示词（P1a）

- 物化为 `UserPrompt`：
  - `id`: `plugin:<pluginId>:<skillId>`
  - `name` / `content`: manifest 本地化后的值，`content` ≤ 8000 字符，`name` ≤ 40 字符
  - `enabled`: manifest 值（默认 `true`）
  - `order`: 当前最大值之后按 manifest 顺序递增
  - `createdAt` / `updatedAt`: 安装时刻
- 写入：`Prefs().userPrompts = [...]`；AI 提示词选择器按「插件是否仍安装」分组显示「来自插件」，不依赖 id 前缀做展示判断。
- 上限：单插件 ≤ 30 条提示词；`id` 全局唯一。
- 说明：这是**提示词模板**，不是阅读技能策略（`readingSkillPolicies` 属于 P2），因此不触碰 `readany_skills.dart` 与 `reading_skill_execution.dart`。
- 同 id 冲突：升级时替换本插件旧条目；若同 id 已存在且不属于该插件（异常情况），拒绝安装并提示。

### 6.2 卸载/升级清理与哈希守卫（P1a）

安装成功时记录：

```json
"applied": {
  "prompts": [{ "id": "plugin:com.example.prompt-pack:deep-summary", "contentSha256": "…" }]
}
```

- 卸载/升级时，仅当当前 `content` 哈希与记录一致才删除。
- 哈希不一致 = 用户编辑过：**改 id 为 `custom-<timestamp>` 并保留内容**，从插件条目中移除；这样重装同一插件不会与旧条目冲突，用户编辑也不会丢。
- 物化前保存 `userPrompts` 原始 JSON 快照；任一步失败按快照写回，清理 staging，状态回滚。
- 写入顺序：先写 `userPrompts`，成功后再写 `pluginState`，避免崩溃留下「状态已记、贡献未落」。

### 6.3 `selectionAction`（P1b，已实现）

同一套 prompt 机制，但目标换成 `SelectionToolbarItem`（`action: aiCommand`）：

- 物化 id：`custom-plugin:<pluginId>:<actionId>`。前缀必须是 `custom-`，以复用现有 `validate()` 的自定义动作规则；组合后 id 超过 100 字符时拒绝安装。
- 自定义动作名额 ≤ 24（安装前检查，不改 `validate()`）；升级时已属于该插件的动作不重复占名额。
- `name` ≤ 30、`icon` ∈ `SelectionToolbarConfig.iconIds`、`skillId` 固定 `selection_toolbar`、`scope` 为 `context` 或 `selection`。
- 哈希覆盖名称、图标、prompt 与 scope；卸载时一致才删除，不一致则改 id 为 `custom-<timestamp>` 并保留为普通自定义命令。
- 快照与回滚同时覆盖 `userPrompts` 与 `selectionToolbar`。

---

## 7. UI

### 7.1 入口

`SubMoreSettings` 的 `settings` 列表（`lib/page/settings_page/more_settings_page.dart:97-207`）新增一项：

- 标题：`ModuStrings.text(context, '插件', 'Plugins')`
- 图标：`Icons.extension_outlined`
- 副标题：`已安装 N 个 · 启用 M 个`
- 位置：`高级` 之前（始终显示，不依赖开发者选项）

移动端复用同一 `SubMoreSettings`，无需额外入口。

### 7.2 插件列表页

- 顶部「安装插件…」按钮 → `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['moduplugin','zip'])`。
- 列表项：名称、版本、作者、状态徽标（已启用/已停用/缺失/损坏）、开关。
- 菜单：详情、重新安装、卸载（二次确认，说明会删除哪些内容）。
- 空态：说明包格式并链接到样例插件文档。

### 7.3 详情页（P1）

- 基本信息：id、版本、许可证、作者、安装时间、包 SHA-256。
- 权限：由宿主维护的能力说明（`ai:prompt-pack` → 「添加 AI 提示词模板」），不直接展示插件自述。
- 贡献列表：提示词名称与启用状态。
- 设置：P1b 起在详情页复用 `ServiceConfigForm` 渲染；修改后短暂防抖自动保存到 `pluginConfig_<id>`。
- 划词动作：详情页显示动作名称与已用/剩余 24 个自定义名额。
- 诊断：最近一次错误（脱敏）、manifest 原始文本（折叠）。

### 7.4 文案

新增 UI 文案统一用 `ModuStrings.text(context, zh, en)`，不新增 ARB 键（插件文案本身来自 manifest，走 §3.2 的回退链）。日志与异常信息使用英文，便于检索。

---

## 8. 文件级改动清单

### 8.1 新增

| 文件 | 内容 |
|---|---|
| `lib/models/plugin_manifest.dart` | `PluginManifest`、`PluginContribution`（`AiSkillContribution`、`SelectionActionContribution` + `UnknownContribution` 保底）、`PluginSettingSpec`；手写严格 `fromJson` 与限额常量 |
| `lib/models/plugin_state.dart` | `PluginRecord`、`PluginState`（普通解析 + 导入用 `parseStrict`）、`PluginStatus` 枚举；JSON 编解码 |
| `lib/service/plugins/plugin_package.dart` | `PluginPackageReader.read(File)`：限额、路径安全、解压 staging、manifest 解析、`PluginInstallError` |
| `lib/service/plugins/plugin_paths.dart` | 目录常量与 `ensureCreated()`、`cleanStale()` |
| `lib/service/plugins/plugin_host.dart` | 单例、`ChangeNotifier`、安装/启停/卸载/升级、启动扫描、错误隔离 |
| `lib/service/plugins/plugin_contribution_handler.dart` | D9 的 handler 接口与注册表 |
| `lib/service/plugins/handlers/ai_prompt_handler.dart` | P1a：`aiSkill` → `UserPrompt` 的 apply/remove、哈希守卫 |
| `lib/service/plugins/handlers/selection_action_handler.dart` | P1b：`selectionAction` → 工具栏自定义命令的 apply/remove、24 名额与哈希守卫 |
| `lib/service/plugins/handlers/plugin_locale.dart` | 贡献物化时统一解析当前 locale |
| `lib/service/plugins/plugin_config.dart` | `pluginConfig_<id>` 编解码、导入校验与默认值合并 |
| `lib/service/plugins/plugin_contributions.dart` | 编排：按 kind 找 handler、快照回滚 |
| `lib/service/plugins/script_runtime.dart` | `ScriptRuntime` 接口 + `NoopScriptRuntime`（P4 扩展点） |
| `lib/page/settings_page/plugins/plugins_page.dart` | 列表页 |
| `lib/page/settings_page/plugins/plugin_detail_page.dart` | 详情页（权限/贡献/插件设置/诊断/名额） |
| `scripts/dev/pack_plugin.dart` | 把目录打成确定性 zip（条目排序、固定时间戳），供测试与样例发布 |
| `docs/examples/plugins/prompt-pack/` | 样例插件：`manifest.json` + `LICENSE`(CC0) + `README.md`，两个 `aiSkill` |

### 8.2 修改

| 文件 | 改动 | 锚点 |
|---|---|---|
| `lib/main.dart` | `DBHelper().initDB()` 后调用 `PluginHost.initialize()`；`onWindowClose()` 中 `dispose()` | `:173`、`:287` |
| `lib/utils/get_path/get_base_path.dart` | 新增 `getPluginDir()` 并在 `initBasePath()` 创建 | `:67-87`、`:95-113` 邻接 |
| `lib/models/selection_toolbar.dart` | `SelectionToolbarItem.copyWith` 增加 `id`（卸载时把用户编辑过的插件动作改名为 `custom-*`）；`validate()` 未改 | `:31` |
| `lib/widgets/settings/service_config_form.dart` | 数字输入接受小数；文本项支持 `maxLength`（插件文本设置上限 8000） | `:147` |
| `lib/service/config/config_item.dart` | 增加可选 `maxLength`，供插件文本设置限制输入长度 | `:20` |
| `lib/config/shared_preference_provider.dart` | `pluginState` 读写、`pluginConfig_<id>` 读写、`removePluginData`（状态 + 设置） | `:1461` 附近 |
| `docs/SETTINGS.md` / `docs/SETTINGS_zh.md` | 增加「插件」设置说明与备份边界 | 设置入口与备份章节 |
| `lib/page/settings_page/more_settings_page.dart` | 设置列表新增「插件」项 | `:97-207` |
| `pubspec.yaml` | 显式声明 `pub_semver`（当前经 `pubspec_parse` 传递可用） | `dependencies` 段 |
| `docs/SETTINGS.md` / `docs/SETTINGS_zh.md` | 增加「插件」设置说明与备份边界 | 设置分类章节 |

P1b 修改 `lib/models/selection_toolbar.dart` 的 `copyWith`（不修改 `validate()`）；P1c 修改 `settings_modules.dart`、`global_settings_transfer.dart`、`settings_value_validation.dart`。

不改动：数据库、同步、TTS、翻译、词典、AI 工具注册表、`SelectionToolbarConfig.validate()`。

---

## 9. 关键实现细节

### 9.1 路径安全解压

`archive` 包的 `extractArchiveToDiskSync` 不做目标路径约束，现有用法只针对受信归档（`lib/page/settings_page/sync.dart:827-835`）。插件包必须手工逐条写出：

```dart
var total = 0;
for (final entry in archive.files) {
  if (!entry.isFile) continue;                 // 拒绝目录与符号链接
  final name = entry.name.replaceAll('\\', '/');
  if (name.startsWith('/') || name.contains('..') || name.contains(':')) {
    throw PluginInstallError.invalidPath(name);
  }
  final target = File(p.join(staging.path, name));
  if (!p.isWithin(staging.path, target.path)) throw PluginInstallError.invalidPath(name);
  // 先按头部声明的大小做限额，再解压，避免 bomb 在解压后才被拒绝。
  if (entry.size > maxFileBytes || total + entry.size > maxTotalBytes) {
    throw PluginInstallError.tooLarge(name);
  }
  total += entry.size;
  final bytes = entry.content as List<int>;    // ZipFile.content 同步返回解压字节
  await target.parent.create(recursive: true);
  await target.writeAsBytes(bytes, flush: true);
}
```

实现说明：`archive` 3.x 在解码 zip 时已把条目名中的 `\` 归一化为 `/`，因此上面的反斜杠检查是纵深防御，实际测试看到的是 `assets\evil.txt` 被安全落盘为 `assets/evil.txt`。真正拦截越界的是 `..` 段、绝对路径、盘符、空段与 `p.isWithin` 检查；`test/service/plugins/plugin_package_test.dart` 覆盖这些分支。

### 9.2 版本比较

```dart
bool meetsMinAppVersion(String current /* 1.3.1+10152 */, String min) {
  Version.parse(current.split('+').first)
      .compareTo(Version.parse(min)) >= 0;
}
```

### 9.3 数量检查

P1a：单插件 `aiSkill` ≤ 30 条，`UserPrompt` 总数不设新上限（现有行为是无限追加），但 prompt 内容 ≤ 8000 字符、名称 ≤ 40 字符。

P1b（划词动作）另需工具栏名额检查：

```dart
final config = Prefs().selectionToolbar;
final custom = config.items.where((i) => i.isCustom).length;
if (custom + actions.length > 24) throw PluginInstallError.noToolbarSlots(24 - custom);
```

### 9.4 安装伪代码（P1）

```
install(file):
  pkg = PluginPackageReader.read(file)          # 校验 + staging + manifest
  check minAppVersion / capabilities / conflicts
  snapshot = userPrompts.raw
  try:
    applied = PluginContributions.apply(pkg)    # 只经 aiSkill handler
    Prefs().userPrompts = merge(applied.prompts) # 先落贡献
    move staging -> plugins/<id> (旧目录 -> .trash)
    state.upsert(record(applied))
    savePluginState                              # 再落状态
    notifyListeners()
  catch:
    restore snapshot; clean staging; rethrow
```

顺序上先应用贡献再落盘，失败时状态从未写入；`savePluginState` 写后 `notifyListeners()`，UI 立即刷新。P1b 起 snapshot 同时包含 `userPrompts` 与 `selectionToolbar`，回滚两者都恢复。

---

## 10. 测试矩阵

| 阶段 | 层级 | 文件 | 覆盖 |
|---|---|---|---|
| P1a | 模型 | `test/models/plugin_manifest_test.dart` | 合法/缺字段/类型错误/超长/未知 kind 忽略/未开放能力拒绝/i18n 回退/`settings` 解析 |
| P1a | 包读取 | `test/service/plugins/plugin_package_test.dart` | 正常包、缺 manifest、超大、条目超限、zip bomb 比、`..`、绝对路径、空段路径、反斜杠归一化、非 zip、未开放能力 |
| P1a | 宿主 | `test/service/plugins/plugin_host_test.dart` | 安装、重复安装、升级、降级拒绝、启停、卸载、missing、broken、`initialize` 幂等 |
| P1a | 贡献 | `test/service/plugins/plugin_contributions_test.dart` | `aiSkill` 物化字段、顺序、30 条上限、用户编辑后卸载改名保留、失败回滚、升级替换 |
| P1a | 组件 | `test/widgets/settings/plugins_page_test.dart` | 空态、状态徽标、开关、卸载确认、详情页权限与贡献列表、插件设置渲染与落盘 |
| P1a/P1b | 样例 | `test/service/plugins/sample_plugin_test.dart` | 直接读取 `docs/examples/plugins/prompt-pack/`，打包后安装到 mock Prefs，断言两条提示词、一个划词动作与设置声明 |
| P1b | 工具栏 | `test/service/plugins/selection_action_test.dart` | 24 名额边界、name/icon/scope 校验、哈希守卫、用户编辑保留、升级不重复占名额 |
| P1b | 设置 | `test/widgets/settings/plugins_page_test.dart` | 详情页动作与插件设置渲染、设置修改落盘 |
| P1b | 回归 | 现有 `test/models/selection_toolbar_test.dart`、`test/widgets/selection_toolbar_test.dart` | 工具栏编解码与上限未被破坏（46 项通过） |
| P1c | 配置 | `test/service/config_transfer/plugin_settings_transfer_test.dart` | 导出含 `pluginState`/`pluginConfig_*`、往返一致、非法形状与类型拒绝、卸载清理 |

P1a 手工验收（记录到 PR）：

1. 6 平台安装同一 `.moduplugin`。
2. AI 面板提示词选择器出现两条模板；执行后 AI 收到完整 prompt。
3. 停用插件 → 模板消失；重新启用 → 恢复。
4. 手动编辑插件模板 → 卸载 → 该模板以普通提示词保留（id 已改为 `custom-*`）。
5. 删除插件目录后重启 → 显示 `missing`，应用不崩，可卸载。
6. 恶意包由 `test/service/plugins/plugin_package_test.dart` 构造（路径穿越、zip bomb、超大条目、未知能力），逐项被拒并给出可读原因。
7. 导出/导入设置在 P1c 验收；P1a 只需确认导出不会破坏应用（插件键被忽略）。

P1b/P1c 手工验收（记录到 PR）：

1. 安装含 `selectionAction` 的包 → 划词工具栏出现动作，执行后 AI 收到完整 prompt；停用/卸载后消失。
2. 手工修改插件动作的名称/图标/prompt → 卸载 → 动作保留为普通自定义命令（id 已改为 `custom-*`）。
3. 工具栏已有 24 个自定义动作时安装新动作被拒绝，提示剩余名额；删除一个后可安装。
4. 修改插件设置 → 重启后保持；导出设置到另一设备 → 插件显示 `missing`、设置仍在，重新安装包后可继续使用。
5. 导入被篡改的 `pluginState` 或 `pluginConfig_*` → 整体拒绝，未修改任何本地设置。

---

## 11. PR 拆分与验收

P1 拆三个 PR；三个 PR 均已实现：

| PR | 内容 | 预估 | 验收 |
|---|---|---|---|
| **P1a（已实现）** | manifest/state 模型、包读取、宿主、`aiSkill` handler、设置页（列表/详情/权限）、`main.dart` 接线、样例插件、`pack_plugin.dart`、全部 P1a 测试 | 6–7 人日 | 6 平台装/卸/停用；样例插件安装后 AI 面板出现模板；恶意包全拒；`flutter analyze` 干净 |
| **P1b（已实现）** | `selectionAction` handler + 工具栏名额/哈希守卫 + 详情页动作列表 + `pluginConfig_` 设置表单 | 3–4 人日 | 24 名额边界；用户编辑保留；现有工具栏回归通过 |
| **P1c（已实现）** | 设置导出/导入接线 + 校验 + `docs/SETTINGS.md` / `SETTINGS_zh.md` | 2–3 人日 | 备份往返一致；缺失插件显示 `missing` |

P1 内部提交顺序（P1a 已完成；P1b/P1c 各一个提交，每个提交都能编译、测试通过）：

1. `plugin_manifest.dart` + `plugin_state.dart` + 单测（含限额、i18n、未知 kind/能力）。
2. `plugin_package.dart` + `plugin_paths.dart` + 路径安全/限额单测。
3. `plugin_contribution_handler.dart` + `plugin_contributions.dart` + `handlers/ai_prompt_handler.dart` + 单测。
4. `plugin_host.dart` + `Prefs` 的 `pluginState` 读写 + 单测。
5. 设置页 + 入口 + 组件测试。
6. `main.dart` 接线 + 样例插件 + `pack_plugin.dart` + 文档。

总计 P1 约 **11–14 人日**（含联调与返工缓冲）。P1a 不触及数据库、设置导出、同步、TTS/翻译/词典与划词工具栏；P1b 只改工具栏物化与设置表单；P1c 只改设置迁移，三者各自独立可回滚。

---

## 12. 合规与许可证检查表

- [ ] 插件必须声明 SPDX `license`；安装页展示，未声明拒绝安装。
- [ ] 文档明确：插件为独立作品；Modu 以 GPL-3.0-or-later 分发，插件需 GPL 兼容（允许更宽松但不允许专有再分发限制）。
- [ ] 不把插件代码链接进应用二进制（P1 纯数据，天然满足）。
- [ ] 商店合规：P1 无任何可执行内容；P4 的 JS 仅由 WebKit/WKWebView 解释执行，符合 iOS 2.5.2 的解释代码例外；不下载 dex/so/dylib。
- [ ] 安装页不展示未经验证的「官方」标识；样例插件注明「示例，不含官方支持」。
- [ ] 隐私：插件包不含用户数据；宿主日志不记录 prompt 全文与凭据。

---

## 13. 风险与回滚

| 风险 | 阶段 | 缓解 |
|---|---|---|
| 提示词列表被插件条目淹没 | P1a | 单插件 ≤ 30 条；UI 分组显示；卸载即清理 |
| 用户编辑与卸载清理冲突 | P1a | 哈希守卫；编辑过的改为 `custom-*` 保留 |
| 插件包缺失但状态存在 | P1a | `missing` 状态 + 可卸载；启动不崩 |
| 启动路径多样（Android 延迟、macOS 迁移） | P1a | `initialize()` 幂等；两条路径都调用；异常不阻断启动 |
| 包解析崩溃 | P1a | 全部解析包在 try/catch 内，`lastError` 落库；损坏包可卸载 |
| 工具栏名额被打满 | P1b | 安装前显式检查并拒绝；详情页展示已用/剩余名额 |
| 配置导出后插件缺失导致困惑 | P1c | `missing` 状态 + 明确文案 + 「配置已保留」提示 |
| 未来脚本贡献与 P1 数据冲突 | P1a 起 | manifest 预留 `script` kind 与 `hostApi`；未知 kind 只忽略不误解 |

回滚方案：移除 `main.dart` 的 `initialize()` 调用即可让所有插件失效（数据保留）；或 `--dart-define=MODU_PLUGINS=false`。

---

## 14. 与后续阶段的衔接

| 阶段 | 本文档需要保证的接口 | 后续改动 |
|---|---|---|
| P1b | `PluginContributionHandler` 注册表、`AppliedContribution` 通用结构 | 已新增 `selectionAction` handler；快照与回滚扩展到 `selectionToolbar` |
| P1c | `pluginState` 结构稳定、`PluginStatus.missing` 已实现 | 已接入导出/导入、严格校验与模块作用域 |
| P2 注册表化 | `PluginContribution.kind` 字符串、能力令牌、`PluginRecord.applied` 通用结构 | TTS/翻译/词典/工具改为 ID 注册表；P2 不开放 provider 贡献，详见 P2–P3 文档 |
| P3 网络插件 | 能力模型已含 `net:http`；`PluginSettingSpec` 可承载域名/密钥 | 首个开放 `dictionarySource`；增加域名白名单、限额、请求代理；翻译/TTS 留到 P3.1 |
| P4 脚本宿主 | `ScriptRuntime` 接口、`script` kind、`hostApi` 版本 | 实现 `WebViewScriptRuntime`，能力 `script:run`，OHOS 用 overlay 适配器 |
| P5 生态 | 包 SHA-256 已存在；状态机已有 `broken/missing` | 增加签名/撤销列表、市场元数据、开发者工具 |

P2/P3 的 manifest 形状、注册表接口、网络守卫、密钥边界、测试计划与 PR 拆分见 [插件系统 P2–P3 设计与执行文档](plugin-system-p2-p3.md)。

### 关于 HarmonyOS

OHOS 有 ArkWeb 版 `flutter_inappwebview`，但只在云构建的依赖覆盖层中启用（`scripts/harmony/audio_webview_overrides.json:79-113`、`scripts/harmony/prepare.py:15-28`），且：

1. `HeadlessInAppWebView` 在 OHOS 上不可用，`AnxHeadlessWebView` 强制退回 Overlay（`lib/utils/webView/anx_headless_webview.dart:60-80`）。
2. 该适配器带一个创建期 `javaScriptBridgeEnabled` 安全策略，关闭时会禁用 `callAsyncJavaScript`、WebMessage 与非 page-world 脚本（`scripts/harmony/WEBVIEW_PATCH.md:43-58`）。
3. 目前是未签名 HAP、云端构建、未做真机验收（`docs/development/harmonyos-support.md:3-7`、`:104-108`）。

因此 P4 的脚本宿主要在 OHOS 可用，需要**独立的 overlay 宿主实现 + 真机验证**，而不是复用隐藏 WebView。P1 的声明式插件与平台无关，6 平台一致；脚本能力按「能力 + 运行时可用性」在 UI 上显示为不可用，而不是按平台写死禁用。

---

## 15. 已确认问题（P1 实现依据）

1. 插件提示词默认启用 — 已按规范实现（manifest `enabled` 缺省 `true`）。
2. 设置导出中的「插件」模块 — 已实现为默认包含（`all` 与 `plugins` 作用域），仅有小型 JSON。
3. 「插件」入口不加开发者选项门控 — 已实现，普通用户可见。
4. 样例插件许可证 — 已使用 CC0-1.0。

---

## 16. 交接运行手册

### 16.1 环境与命令

工具链（`docs/development/local-toolchain.md`）：**Flutter 3.47.2 / Dart 3.13.2**（FVM，`.fvmrc`）、JDK 17、Android SDK 36 / Build Tools 36.0.0、Gradle 9.2.1、AGP 9.0.1、Kotlin 2.3.20。

CI 同序命令（`pr-check.yml:57-67`）：

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```

单文件调试：

```bash
flutter test test/models/plugin_manifest_test.dart
flutter test test/service/plugins/
```

注意：

- 中文工作区路径下 Flutter 3.47.2 的 LSP `Content-Length` 有已知缺陷，本机 SDK 已打补丁；**不要随意重装 SDK**（`local-toolchain.md` 的「Flutter analysis with Chinese workspace paths」）。
- P1 新增模型是手写解析，不产生 `.g.dart`；但 CI 仍会跑 `build_runner`，提交前本地跑一次，确认没有意外生成物（`git status`）。
- 不提交 `build/`、`.dart_tool/`、日志文件。

### 16.2 建议阅读顺序（接手的工程师/Agent）

1. 本文件 §2–§4：约束、包规范、宿主架构。
2. `lib/models/user_prompt.dart`、`lib/providers/user_prompts.dart`：P1a 的物化目标与写入方式。
3. `lib/models/selection_toolbar.dart`：P1b 的物化目标，重点看 `validate()` 的 24 个自定义名额与 `custom-` 前缀规则。
4. `lib/config/shared_preference_provider.dart:1438` 附近：JSON 设置的既有写法。
5. `lib/main.dart:103-207`、`:257-296`、`:462-475`：启动与关闭路径。
6. P1c 的配置迁移：`lib/service/config_transfer/{settings_modules,global_settings_transfer,settings_value_validation}.dart`。
7. P1b 的插件设置表单：`lib/widgets/settings/service_config_form.dart`。

### 16.3 术语

| 术语 | 含义 |
|---|---|
| 插件包 / package | `.moduplugin`（zip），纯数据 |
| 贡献 / contribution | manifest `contributes[]` 中的一项，按 `kind` 分发 |
| 能力 / capability | 插件可执行的操作类别，安装时授权 |
| staging / trash | 安装与卸载的临时目录 |
| applied | 已物化的贡献记录（含内容哈希） |
| `broken` / `missing` | 包损坏 / 状态存在但包不在 |
| `PluginHost` | 宿主单例，唯一状态入口 |
| `ScriptRuntime` | 脚本运行时接口（P1 仅 `NoopScriptRuntime`） |

### 16.4 已知坑

- `Prefs` 是 `ChangeNotifier` 单例，写后 `notifyListeners()`；不要在构造期读未初始化的 `prefs`（`shared_preference_provider.dart:195-230`）。
- macOS 迁移会二次执行 `initBasePath` / `initDB`，`PluginHost.initialize()` 必须幂等。
- 插件动作走 `SelectionToolbarConfig.encode()` 的 `validate()`（总数、24 个名额、字段长度），因此插件 id 必须保持 `custom-` 前缀；不要修改 `validate()`。
- P1a 写提示词用 `Prefs().userPrompts = list`（内部 `jsonEncode` + `setString`），没有异步保存问题；但仍要「先写贡献、后写 pluginState」。
- 插件设置仅保存用户改过的键；读取时用 manifest 默认值补齐，导出时保持原样，避免默认值污染备份。
- 用户提示词 id 是字符串，不要假设为时间戳数字；插件条目用 `plugin:<pluginId>:<skillId>`。
- 用户编辑过的插件提示词在卸载时要改成 `custom-<timestamp>` 再保留，否则重装会 id 冲突。
- `ZipFile.size` 是解压后大小：**先按 `size` 限额，再取 `content`**，否则 zip bomb 在解压阶段就吃满内存。
- 设置导出会为 `_types` 中每个键补 `reset` 项；P1c 新增键时要明确“未设置”在另一台设备上的语义。

### 16.5 文档语言约定（待定）

`CONTRIBUTING.md:12` 规定单篇指南使用英文；本文档目前是中文工作稿。合并前二选一：维护者同意保留中文，或补充英文版。索引已加入 `docs/README.md` 的 Building and maintenance 列表。

### 16.6 变更记录

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-10-23 | v0.1 | 初稿：P0 规范 + P1 执行计划；补交接摘要（§0）、ADR 说明（§2.1）、运行手册（§16）；上游同步至 `0feceeb9` |
| 2026-10-23 | v0.2 | 按评审收窄首个 PR：P1 拆为 P1a（安装 + `aiSkill` + 示例插件）/ P1b（划词动作）/ P1c（配置导出）；新增 `ContributionHandler` 注册表（D9）；`settings` 推迟到 P1b；同步更新测试与 PR 拆分 |
| 2026-10-23 | v0.3 | 实现 P1a：manifest/state 模型、包读取与路径安全、宿主（安装/启停/卸载/升级/幂等扫描）、`aiSkill` handler、Prefs `pluginState`、设置页与入口、`main.dart` 接线、示例插件与 `pack_plugin.dart`；45 项测试通过。记录 `archive` 对反斜杠的归一化行为；标注 `flutter analyze` 仅剩基线既有的 `avoid_print` 信息 |
| 2026-10-23 | v0.4 | 实现 P1b/P1c：开放 `ui:selection-action`；新增 `SelectionActionContribution`/handler（24 名额、名称/图标/scope 校验、哈希守卫、编辑保留为 `custom-*`）；启用 `pluginConfig_` 与详情页 `ServiceConfigForm`；`pluginState`/`pluginConfig_*` 接入设置导出、严格校验与模块作用域；补中英文 `SETTINGS` 插件说明。工具栏 46 项回归、插件与配置新增测试全部通过 |
| 2026-10-24 | v0.5 | 示例插件升级到 1.1.0：新增 `selectionAction`（`explain-selection`）与 `settings`（select/toggle/number/tip），同步更新 README、执行文档与 `sample_plugin_test` |

### 16.7 给接手 Agent 的启动提示词（P1a/P1b/P1c 已完成，以下保留为复现/重做指令）

```text
仓库：D:\Code\modureader（Flutter 3.47.2，FVM）。基线：main @ 0feceeb9，工作区除
docs/development/plugin-system-p0-p1.md 与 docs/README.md 外应保持干净。

先完整阅读 docs/development/plugin-system-p0-p1.md，特别是 §0（交接摘要）、§2（冻结决策）、
§3（包规范）、§4（宿主架构与 handler 注册表）、§8（文件级改动）、§10（测试）、§11（PR 拆分）、
§16（运行手册）。

任务：实现 P1a（一个 PR，内部按 §11 的 6 个提交顺序）：
- 插件包模型与严格校验：lib/models/plugin_manifest.dart、lib/models/plugin_state.dart
- 包读取与路径安全：lib/service/plugins/plugin_package.dart、plugin_paths.dart
- 宿主：plugin_host.dart（安装/启停/卸载/升级/启动扫描/幂等初始化）
- 贡献注册表：plugin_contribution_handler.dart + handlers/ai_prompt_handler.dart + plugin_contributions.dart
- Prefs：pluginState 读写 + removePluginData
- 设置页：lib/page/settings_page/plugins/（列表、详情、安装/卸载、权限与贡献列表）
- 接线：lib/main.dart（DB init 后 initialize、关闭时 dispose）、more_settings_page.dart 入口
- 示例插件：docs/examples/plugins/prompt-pack/（manifest + LICENSE(CC0) + README）
- 打包脚本：scripts/dev/pack_plugin.dart
- 测试：按 §10 的 P1a 行

不要做：selectionAction（P1b）、settings 表单与 pluginConfig_（P1b）、设置导出（P1c）、
JS/脚本运行时、任何数据库迁移、任何 SelectionToolbarConfig 修改。

硬性约束：
- capabilities 只开放 ai:prompt-pack；未知 capability 拒绝安装，未知 contribution kind 忽略并告警。
- 限额、路径安全、zip bomb 防护按 §3.5 与 §9.1。
- 提示词 id 用 plugin:<pluginId>:<skillId>；卸载时哈希一致才删，不一致改 id 为 custom-* 保留。
- 不引入新原生依赖；不提交 .g.dart 生成物。
- 提交前运行：flutter pub get、flutter gen-l10n、
  dart run build_runner build --delete-conflicting-outputs、
  flutter analyze --no-fatal-infos --no-fatal-warnings、
  flutter test test/models/plugin_manifest_test.dart、flutter test test/service/plugins/。

验收：§10 的 P1a 行全绿；§1.3 的 DoD 满足；输出改动清单、测试结果与 6 平台手工验收状态。
```

### 16.8 相关文档

- [本地工具链](local-toolchain.md)：Flutter/Dart/Android 版本与中文路径分析补丁。
- [HarmonyOS 支持](harmonyos-support.md)：云端覆盖层、未签名 HAP、ArkWeb 适配现状。
- [测试策略](../TESTING.md)：编译、自动检查、真机验收必须分开报告。
- [贡献指南](../../CONTRIBUTING.md)：GPL 许可、回归测试、文档语言约定。
