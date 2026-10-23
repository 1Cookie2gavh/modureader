import 'dart:io';
import 'package:flutter/material.dart';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/modu_strings.dart';
import 'package:anx_reader/models/translation_text_style.dart';
import 'package:anx_reader/utils/get_path/get_base_path.dart';
import 'package:anx_reader/widgets/settings/settings_section.dart';
import 'package:anx_reader/widgets/settings/settings_tile.dart';

class TranslationTextStyleSettings extends StatefulWidget {
  const TranslationTextStyleSettings({super.key, this.classical = true});
  final bool classical;
  @override
  State<TranslationTextStyleSettings> createState() =>
      _TranslationTextStyleSettingsState();
}

class _TranslationTextStyleSettingsState
    extends State<TranslationTextStyleSettings> {
  late var style = TranslationTextStyle.decode(widget.classical
      ? Prefs().classicalTranslationTextStyle
      : Prefs().languageTranslationTextStyle);
  String get prefix => widget.classical ? 'classical' : 'language';
  final fonts = <String>[];
  @override
  void initState() {
    super.initState();
    try {
      fonts.addAll(getFontDir()
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((name) =>
              RegExp(r'\.(ttf|otf)$', caseSensitive: false).hasMatch(name)));
      fonts.sort();
    } catch (_) {/* Font directory can be empty on a new installation. */}
    loadFont();
  }

  Future<void> loadFont() async {
    try {
      await style.loadFont();
    } catch (_) {/* Use platform fallback for unavailable fonts. */}
    if (mounted) setState(() {});
  }

  void change(String key, Object value) {
    setState(() => style = style.withValue(key, value));
    if (widget.classical) {
      Prefs().classicalTranslationTextStyle = style.encode();
    } else {
      Prefs().languageTranslationTextStyle = style.encode();
    }
    if (key == 'font') loadFont();
  }

  String t(String zh, String en) => ModuStrings.text(context, zh, en);
  Future<void> pick<T>(
      String title, T current, Map<T, String> options, String key) async {
    final value = await showDialog<T>(
        context: context,
        builder: (context) => SimpleDialog(title: Text(title), children: [
              for (final entry in options.entries)
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, entry.key),
                    child: Row(children: [
                      Expanded(child: Text(entry.value)),
                      if (entry.key == current) const Icon(Icons.check)
                    ]))
            ]));
    if (value != null && mounted) change(key, value as Object);
  }

  @override
  Widget build(BuildContext context) {
    final choices = {
      '': t('跟随原文', 'Follow original'),
      'system': t('系统字体', 'System font'),
      'serif': t('衬线字体', 'Serif'),
      'sans-serif': t('无衬线字体', 'Sans serif'),
      'monospace': t('等宽字体', 'Monospace'),
      for (final font in fonts) font: font,
      if (style.imported && !fonts.contains(style.font))
        style.font: '${style.font} (${t('未安装', 'not installed')})'
    };
    return SettingsSection(
        title: Text(t('译文外观', 'Translation appearance')),
        tiles: [
          SettingsTile.navigation(
              key: ValueKey('$prefix-style-font'),
              leading: const Icon(Icons.font_download_outlined),
              title: Text(t('字体', 'Font')),
              value: Text(choices[style.font]!),
              onPressed: (_) => pick(
                  t('译文字体', 'Translation font'), style.font, choices, 'font')),
          SettingsTile.navigation(
              key: ValueKey('$prefix-style-size'),
              leading: const Icon(Icons.format_size),
              title: Text(t('字号', 'Font size')),
              value: Text(style.size == 0
                  ? t('跟随原文', 'Follow original')
                  : '${style.size.toStringAsFixed(0)} px'),
              onPressed: (_) => pick(
                  t('译文字号', 'Translation font size'),
                  style.size,
                  {
                    0.0: t('跟随原文', 'Follow original'),
                    for (var n = 12; n <= 48; n++) n.toDouble(): '$n px'
                  },
                  'size')),
          SettingsTile.switchTile(
              key: ValueKey('$prefix-style-bold'),
              leading: const Icon(Icons.format_bold),
              title: Text(t('粗体', 'Bold')),
              initialValue: style.bold,
              onToggle: (value) => change('bold', value)),
          SettingsTile.switchTile(
              key: ValueKey('$prefix-style-italic'),
              leading: const Icon(Icons.format_italic),
              title: Text(t('斜体', 'Italic')),
              initialValue: style.italic,
              onToggle: (value) => change('italic', value)),
          CustomSettingsTile(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            widget.classical
                                ? t('只调整文言文译文，不改变原文或语种翻译。已生成译文同步更新，不重新请求翻译。',
                                    'Applies only to Classical Chinese output, not the original or language translation. Existing output updates without another request.')
                                : t('只调整语种译文，不改变原文或文言文翻译。已生成译文同步更新，不重新请求翻译。',
                                    'Applies only to language translation output, not the original or Classical Chinese translation. Existing output updates without another request.'),
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 12),
                        Text(
                            t('译文预览：学习并时常温习，不也是一件愉快的事吗？',
                                'Translation preview: Is it not a pleasure to learn and practise?'),
                            key: ValueKey('$prefix-style-preview'),
                            style: style.textStyle),
                      ]))),
        ]);
  }
}
