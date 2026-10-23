import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/modu_strings.dart';
import 'package:anx_reader/models/plugin_manifest.dart';
import 'package:anx_reader/models/plugin_state.dart';
import 'package:anx_reader/models/user_prompt.dart';
import 'package:anx_reader/page/settings_page/plugins/plugins_page.dart';
import 'package:anx_reader/service/plugins/plugin_host.dart';
import 'package:anx_reader/widgets/settings/settings_section.dart';
import 'package:anx_reader/widgets/settings/settings_tile.dart';
import 'package:flutter/material.dart';

class PluginDetailPage extends StatelessWidget {
  const PluginDetailPage({
    super.key,
    required this.pluginId,
    required this.host,
  });

  final String pluginId;
  final PluginHost host;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: host,
      builder: (context, _) {
        final record = host.byId(pluginId);
        return Scaffold(
          appBar: AppBar(
            title: Text(record == null
                ? ModuStrings.text(context, '插件详情', 'Plugin details')
                : record.name
                    .resolve(Localizations.localeOf(context).toLanguageTag())),
          ),
          body: record == null
              ? Center(
                  child: Text(ModuStrings.text(context, '插件已被卸载。',
                      'This plugin is no longer installed.')),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    _basicSection(context, record),
                    _permissionSection(context),
                    _contributionSection(context, record),
                    _diagnosticSection(context, record),
                  ],
                ),
        );
      },
    );
  }

  Widget _basicSection(BuildContext context, PluginRecord record) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return SettingsSection(
      title: Text(ModuStrings.text(context, '基本信息', 'Information')),
      tiles: [
        _valueTile(context, 'ID', record.id),
        _valueTile(context, ModuStrings.text(context, '版本', 'Version'),
            'v${record.version}'),
        _valueTile(context, ModuStrings.text(context, '许可证', 'License'),
            record.license),
        if (record.author != null)
          _valueTile(context, ModuStrings.text(context, '作者', 'Author'),
              record.author!),
        _valueTile(context, ModuStrings.text(context, '安装时间', 'Installed'),
            record.installedAt.toLocal().toString().split('.').first),
        _valueTile(context, 'SHA-256', record.sha256),
        _valueTile(context, ModuStrings.text(context, '包内名称', 'Package name'),
            record.name.resolve(locale)),
        _valueTile(context, ModuStrings.text(context, '状态', 'Status'),
            pluginStatusLabel(context, record.status)),
      ],
    );
  }

  Widget _permissionSection(BuildContext context) {
    final capabilities =
        host.manifestFor(pluginId)?.capabilities ?? const <String>{};
    return SettingsSection(
      title: Text(ModuStrings.text(context, '权限', 'Permissions')),
      tiles: [
        if (capabilities.isEmpty)
          CustomSettingsTile(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(ModuStrings.text(context, '没有声明额外权限，或插件包已不可用。',
                  'No additional permissions declared, or the package is unavailable.')),
            ),
          )
        else
          for (final capability in capabilities)
            _valueTile(
                context, _capabilityLabel(context, capability), capability),
      ],
    );
  }

  Widget _contributionSection(BuildContext context, PluginRecord record) {
    final prompts = Prefs().userPrompts;
    return SettingsSection(
      title: Text(ModuStrings.text(context, '贡献内容', 'Contributions')),
      tiles: [
        if (record.applied.isEmpty)
          CustomSettingsTile(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(ModuStrings.text(
                  context,
                  '当前没有已生效的贡献。启用插件后，它添加的提示词会出现在 AI 提示词列表中。',
                  'No active contributions. Enable the plugin to add its prompts to the AI prompt list.')),
            ),
          )
        else
          for (final applied in record.applied)
            CustomSettingsTile(
              child: ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(_appliedName(applied, prompts)),
                subtitle: Text('${applied.kind} · ${applied.id}'),
              ),
            ),
      ],
    );
  }

  String _appliedName(AppliedContribution applied, List<UserPrompt> prompts) {
    for (final prompt in prompts) {
      if (prompt.id == applied.id) return prompt.name;
    }
    return applied.id;
  }

  Widget _diagnosticSection(BuildContext context, PluginRecord record) {
    final raw = host.manifestTextFor(pluginId);
    return SettingsSection(
      title: Text(ModuStrings.text(context, '诊断', 'Diagnostics')),
      tiles: [
        if (record.lastError != null)
          _valueTile(context, ModuStrings.text(context, '最近错误', 'Last error'),
              record.lastError!),
        if (raw != null)
          CustomSettingsTile(
            child: ExpansionTile(
              title: Text(ModuStrings.text(
                  context, 'manifest.json 原文', 'manifest.json')),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    raw.length > 8192 ? '${raw.substring(0, 8192)}…' : raw,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  AbstractSettingsTile _valueTile(
      BuildContext context, String label, String value) {
    return CustomSettingsTile(
      child: ListTile(
        title: Text(label),
        subtitle: SelectableText(value),
      ),
    );
  }

  String _capabilityLabel(BuildContext context, String capability) {
    switch (capability) {
      case kAiPromptPackCapability:
        return ModuStrings.text(
            context, '添加 AI 提示词模板', 'Add AI prompt templates');
      case 'storage:plugin':
        return ModuStrings.text(context, '使用插件私有目录', 'Use plugin storage');
      default:
        return capability;
    }
  }
}
