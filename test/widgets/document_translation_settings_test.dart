import 'dart:async';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/enums/translation_mode.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/page/book_player/epub_player.dart';
import 'package:anx_reader/widgets/reading_page/translation_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });

  testWidgets(
      'shared reader settings translate this page and reuse display changes',
      (tester) async {
    final mode = ValueNotifier(TranslationModeEnum.off);
    final calls = <(TranslationModeEnum, bool)>[];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
          body: SingleChildScrollView(
              child: TranslationWidget(
        bookId: 1,
        epubPlayerKey: GlobalKey<EpubPlayerState>(),
        pageTranslationMode: mode,
        onTranslatePage: (display, force) async {
          calls.add((display, force));
          mode.value = display;
        },
        onStopPageTranslation: () => mode.value = TranslationModeEnum.off,
      ))),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('preferring saved edits'), findsOneWidget);
    await tester.tap(find.text('Translate visible content'));
    await tester.pumpAndSettle();
    expect(calls, [(TranslationModeEnum.bilingual, false)]);
    await tester.tap(find.text('Translation only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply display mode'));
    await tester.pumpAndSettle();
    expect(calls.last, (TranslationModeEnum.translationOnly, false));
    await tester.tap(find.text('Retranslate current content'));
    await tester.pumpAndSettle();
    expect(calls.last, (TranslationModeEnum.translationOnly, true));
    await tester.tap(find.byKey(const ValueKey('reader-stop-translation')));
    await tester.pumpAndSettle();
    expect(mode.value, TranslationModeEnum.off);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    mode.dispose();
  });

  testWidgets('stop during page translation ignores late completion',
      (tester) async {
    final mode = ValueNotifier(TranslationModeEnum.off);
    final pending = Completer<void>();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Scaffold(
          body: SingleChildScrollView(
              child: TranslationWidget(
        bookId: 1,
        epubPlayerKey: GlobalKey<EpubPlayerState>(),
        pageTranslationMode: mode,
        onTranslatePage: (display, _) {
          mode.value = display;
          return pending.future;
        },
        onStopPageTranslation: () => mode.value = TranslationModeEnum.off,
      ))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Translate visible content'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reader-stop-translation')));
    await tester.pumpAndSettle();
    pending.complete();
    await tester.pumpAndSettle();
    expect(mode.value, TranslationModeEnum.off);
    expect(find.text('Translate visible content'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    mode.dispose();
  });
}
