import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/l10n/modu_strings.dart';
import 'package:anx_reader/page/settings_page/css_settings.dart';
import 'package:anx_reader/page/settings_page/settings_page.dart';
import 'package:anx_reader/widgets/settings/settings_tile.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/other_settings.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/reading_settings.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/style_settings.dart';
import 'package:anx_reader/widgets/settings/settings_section.dart';
import 'package:anx_reader/widgets/settings/settings_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReadingSettings extends ConsumerStatefulWidget {
  const ReadingSettings({super.key});

  @override
  ConsumerState<ReadingSettings> createState() => _ReadingSettingsState();
}

class _ReadingSettingsState extends ConsumerState<ReadingSettings> {
  @override
  Widget build(BuildContext context) {
    CustomSettingsSection section(String title, Widget child) =>
        CustomSettingsSection(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SettingsSectionTitle(child: Text(title)),
            child,
          ]),
        );
    return settingsSections(sections: [
      SettingsSection(
        title: Text(ModuStrings.text(context, 'CSS 设置', 'CSS settings')),
        tiles: [
          SettingsTile.navigation(
            key: const ValueKey('reading-css-settings'),
            leading: const Icon(Icons.tune),
            title: Text(ModuStrings.text(context, 'CSS 设置', 'CSS settings')),
            description: Text(ModuStrings.text(context, '预设模板 · 图形调节 · 自定义代码',
                'Templates · Visual controls · Custom code')),
            onPressed: (context) =>
                Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SettingsPageBody(
                title: ModuStrings.text(context, 'CSS 设置', 'CSS settings'),
                isMobile: true,
                sections: const CssSettings(),
              ),
            )),
          ),
        ],
      ),
      section(L10n.of(context).readingPageReading,
          const ReadingMoreSettings(readerMenu: true)),
      section(L10n.of(context).readingPageStyle,
          const StyleSettings(readerMenu: true)),
      section(L10n.of(context).readingPageOther,
          const OtherSettings(readerMenu: true, showKeyboardShortcuts: true)),
    ]);
  }
}
