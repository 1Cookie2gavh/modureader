import 'package:anx_reader/utils/app_motion.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/main.dart';
import 'package:anx_reader/page/reading_page.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/other_settings.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/reading_settings.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/style_settings.dart';
import 'package:anx_reader/widgets/reading_page/reader_popup.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/custom_css_editor.dart';
import 'package:flutter/material.dart';
import '../reader_settings_scroll_view.dart';

enum ReadingSettings { theme, style }

void showMoreSettings(ReadingSettings settings) {
  final context = navigatorKey.currentContext!;
  readingPageKey.currentState!.showOrHideAppBarAndBottomBar(false);
  showReaderPopup(context,
      enableDrag: false,
      builder: (_) => ReaderMoreSettings(settings: settings));
}

class ReaderMoreSettings extends StatelessWidget {
  const ReaderMoreSettings({super.key, required this.settings});
  final ReadingSettings settings;

  @override
  Widget build(BuildContext context) {
    final bookKey = epubPlayerKey.currentState?.cssBookKey;
    return DefaultTabController(
      length: 4,
      initialIndex: settings == ReadingSettings.theme ? 0 : 1,
      animationDuration: AppMotion.duration(const Duration(milliseconds: 300)),
      child: Column(children: [
        Row(children: [
          Expanded(
              child: TabBar(tabs: [
            Tab(text: L10n.of(context).readingPageReading),
            Tab(text: L10n.of(context).readingPageStyle),
            const Tab(text: 'CSS'),
            Tab(text: L10n.of(context).readingPageOther),
          ])),
          const CloseButton(),
        ]),
        const Divider(height: 0),
        Expanded(
            child: TabBarView(children: [
          const ReaderSettingsScrollView(child: ReadingMoreSettings()),
          const ReaderSettingsScrollView(child: StyleSettings()),
          ReaderSettingsScrollView(
              child: Padding(
            padding: const EdgeInsets.all(8),
            child: CustomCSSEditor(key: ValueKey(bookKey), bookKey: bookKey),
          )),
          const ReaderSettingsScrollView(child: OtherSettings()),
        ])),
      ]),
    );
  }
}
