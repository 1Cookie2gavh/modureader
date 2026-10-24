import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/modu_strings.dart';
import 'package:anx_reader/page/settings_page/plugins/plugins_page.dart';
import 'package:anx_reader/service/plugins/plugin_host.dart';
import 'package:anx_reader/utils/app_motion.dart';
import 'package:anx_reader/widgets/settings/settings_section.dart';
import 'package:anx_reader/widgets/settings/settings_tile.dart';
import 'package:anx_reader/widgets/settings/settings_title.dart';
import 'package:flutter/material.dart';

class ExperimentalSettings extends StatefulWidget {
  const ExperimentalSettings({super.key, this.host});
  final PluginHost? host;

  @override
  State<ExperimentalSettings> createState() => _ExperimentalSettingsState();
}

class _ExperimentalSettingsState extends State<ExperimentalSettings> {
  bool _busy = false;
  PluginHost get _host => widget.host ?? PluginHost.instance;

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (value) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(ModuStrings.text(
                context, '开启实验性插件？', 'Enable experimental plugins?')),
            content: Text(ModuStrings.text(
                context,
                '插件仍在实验阶段，可能存在兼容性问题，请先备份设置。仅允许项目内置审核清单中的插件，安装和启用时校验文件指纹，不支持第三方插件。当前仅支持声明式提示词和划词动作，不执行插件代码；使用 AI 动作时，相关阅读内容会发送给你选择的 AI 服务。关闭此功能将停用插件，保留插件文件、配置及你编辑过的普通条目。是否确认开启？',
                'Plugins are experimental; back up settings first. Only plugins in the project-reviewed built-in catalog are accepted, with file verification on install and enable. Third-party plugins are not supported. Only declarative prompts and selection actions are supported; no plugin code runs. Using AI actions sends relevant reading content to your selected AI service. Turning this off disables plugins but keeps packages, configuration and edited ordinary entries. Enable anyway?')),
            scrollable: true,
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(ModuStrings.text(context, '取消', 'Cancel'))),
              FilledButton(
                  key: const ValueKey('confirm-experimental-plugins'),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(ModuStrings.text(
                      context, '了解风险，确认开启', 'Understand risks and enable'))),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      await _host.setExperimentalEnabled(value);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(pluginErrorText(context, error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([Prefs(), _host]),
        builder: (context, _) {
          final enabled = Prefs().experimentalPluginsEnabled;
          return settingsSections(sections: [
            SettingsSection(
              title: Text(
                  ModuStrings.text(context, '实验性功能', 'Experimental features')),
              tiles: [
                SettingsTile.switchTile(
                  key: const ValueKey('experimental-plugins-switch'),
                  leading: const Icon(Icons.extension_outlined),
                  title: Text(ModuStrings.text(context, '插件', 'Plugins')),
                  description: Text(ModuStrings.text(
                      context,
                      '默认关闭。只在本设备确认开启，不随设置备份自动启用。',
                      'Off by default. Requires consent on this device; backups cannot enable it.')),
                  initialValue: enabled,
                  enabled: !_busy && PluginHost.isEnabled,
                  onToggle: _toggle,
                ),
                if (enabled)
                  SettingsTile.navigation(
                    title: Text(
                        ModuStrings.text(context, '管理插件', 'Manage plugins')),
                    leading: const Icon(Icons.settings_outlined),
                    enabled: !_busy,
                    onPressed: (_) => Navigator.push(
                        context,
                        MotionCupertinoPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                                title: Text(ModuStrings.text(
                                    context, '插件', 'Plugins'))),
                            body: PluginSettings(host: _host),
                          ),
                        )),
                  ),
              ],
            ),
          ]);
        },
      );
}
