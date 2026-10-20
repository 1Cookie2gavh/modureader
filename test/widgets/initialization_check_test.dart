import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/main.dart';
import 'package:anx_reader/page/changelog_screen.dart';
import 'package:anx_reader/service/initialization_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    PackageInfo.setMockInitialValues(
        appName: 'Modu',
        packageName: 'com.modu.reader',
        version: '1.2.12',
        buildNumber: '10150',
        buildSignature: '');
  });

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      locale: const Locale('en'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: const Scaffold(body: Text('Bookshelf')),
    ));
    await tester.pumpAndSettle();
    expect(navigatorKey.currentContext, isNotNull);
  }

  testWidgets('fresh install and subsequent startup stay on bookshelf',
      (tester) async {
    await show(tester);
    for (var i = 0; i < 2; i++) {
      await tester.runAsync(InitializationCheck.check);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(Prefs().lastAppVersion, '1.2.12+10150');
      expect(find.text('Bookshelf'), findsOneWidget);
      expect(navigatorKey.currentState!.canPop(), isFalse);
      expect(find.byType(ChangelogScreen), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('upgrading still opens release notes', (tester) async {
    Prefs().lastAppVersion = '1.2.11+10149';
    await show(tester);
    await InitializationCheck.check();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ChangelogScreen), findsOneWidget);
    tester.widget<ChangelogScreen>(find.byType(ChangelogScreen)).onComplete();
    await tester.pump(const Duration(milliseconds: 400));
    expect(Prefs().lastAppVersion, '1.2.12+10150');
    expect(tester.takeException(), isNull);
  });
}
