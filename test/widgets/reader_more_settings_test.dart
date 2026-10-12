import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/widgets/common/app_scroll_behavior.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/custom_css_editor.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/more_settings.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/other_settings.dart';
import 'package:anx_reader/widgets/reading_page/reader_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });

  for (final size in [
    const Size(390, 844),
    const Size(1200, 900),
    const Size(844, 390)
  ]) {
    testWidgets(
        'reader settings match query and CSS remains accessible at $size',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        locale: const Locale('zh'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
            body: Builder(
                builder: (context) => Column(children: [
                      TextButton(
                          onPressed: () => showReaderPopup(context,
                              builder: (_) => const Text('query body')),
                          child: const Text('query')),
                      TextButton(
                          onPressed: () => showReaderPopup(context,
                              enableDrag: false,
                              builder: (_) => const ReaderMoreSettings(
                                  settings: ReadingSettings.style)),
                          child: const Text('settings')),
                    ]))),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('query'));
      await tester.pumpAndSettle();
      final querySize =
          tester.getSize(find.byKey(const ValueKey('reader-popup-body')));
      Navigator.of(tester.element(find.text('query body'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('settings'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const ValueKey('reader-popup-body'))),
          querySize);
      expect(find.byType(CustomCSSEditor), findsNothing);
      expect(tester.widgetList<Tab>(find.byType(Tab)).map((t) => t.text),
          ['阅读', '样式', 'CSS', '其他']);
      await tester.tap(find.text('CSS'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomCSSEditor), findsOneWidget);
      expect(find.byKey(const ValueKey('apply-css-8')), findsOneWidget);
      await tester.tap(find.text('其他'));
      await tester.pumpAndSettle();
      expect(find.byType(OtherSettings), findsOneWidget);
      expect(find.text('划词工具栏'), findsNothing);
      expect(find.text('自动总结前文内容'), findsNothing);
      expect(find.text('键盘快捷键翻页'), findsNothing);
      expect(find.text('自定义按键'), findsNothing);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderMoreSettings), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
