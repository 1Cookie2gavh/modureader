# Plugin trust / 插件信任策略

Current scope: declarative AI prompt packs and selection actions only. No plugin
JavaScript, native code, network bridge or automatic update execution.

当前仅开放声明式 AI 提示词与划词动作，不执行插件脚本或原生代码，不开放网络桥接或自动更新执行。

## Project-controlled catalog / 项目控制的可信清单

The only accepted source is the project-maintained catalog in
`lib/service/plugins/plugin_trust.dart`, shipped with the app. The initial entry
is the repository's `com.example.prompt-pack` 1.1.0 sample. Local file selection
is transport only, not approval: matching the entire reviewed file inventory is
mandatory, including documentation and license. ZIP timestamps/compression may
differ; extracted bytes may not. No manifest field, preference, imported backup,
URL or user confirmation can add trust.

唯一可用来源为随应用发布的项目可信清单；初始条目为仓库示例包 1.1.0。
本地选包只是传输方式，不授予信任。包括文档和许可证在内的完整文件清单必须匹配，
ZIP 时间戳和压缩方式可不同，解压后的内容不可不同。声明、设置、备份、网址和用户确认均不能扩充清单。

## Admission / 审核与放行

1. Review every source file, license, declared capability and prompt. Reject
   executable content, instructions to disclose secrets, unexpected external
   destinations, and privileges beyond the current declarative host.
2. Keep a versioned source directory in the project, with review attribution.
   Run manifest, package-boundary, installation, removal and upgrade tests.
3. Calculate each source file's SHA-256 (`shasum -a 256 <file>`). Add the exact
   `id@version` file map to the built-in catalog in the same reviewed change.
   Never generate approvals from an arbitrary downloaded package at runtime.
4. Ship through a reviewed app release. Distribute reproducibly packed packages
   from the project's release assets. Removing a catalog entry revokes it in
   that app version; already installed entries are rechecked at startup.

新增版本依次完成：逐文件与提示词审核、版本化源码与测试、指纹清单代码审查、应用发布。
禁止运行时从任意下载包自动生成信任。撤销需要更新应用清单；不声称具备即时远程撤销。

## Boundaries / 安全边界

Identity and integrity checks do not prove AI output safe. Invoking a reviewed
prompt may send reading context to the user's chosen AI provider. Explicit local
opt-in is still required. Edited prompts retained as ordinary user entries are
user-owned content, no longer verified plugin contributions. An attacker who can
replace the application binary or all user preferences is outside this catalog's
integrity boundary. No real AI/network request is required to test this feature.
