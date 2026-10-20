import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/main.dart';
import 'package:anx_reader/page/home_page/settings_page.dart';
import 'package:anx_reader/page/settings_page/bug_report.dart';
import 'package:anx_reader/widgets/home_navigation_metrics.dart';
import 'package:anx_reader/widgets/settings/about.dart';
import 'package:anx_reader/widgets/common/container/filled_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Modu',
      packageName: 'com.modu.reader',
      version: '1.1.6-test.1',
      buildNumber: '10048',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    // Do not reuse a cached Future from a previous test's FakeAsync zone.
    rootBundle.evict('pubspec.yaml');
  });

  for (final width in [390.0, 1200.0]) {
    for (final bottom in [0.0, 24.0, 48.0]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets(
            'About clears floating bar and opens: width=$width inset=$bottom scale=$scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          late ScrollController controller;
          await tester.pumpWidget(ProviderScope(
              child: MaterialApp(
            navigatorKey: navigatorKey,
            locale: const Locale('zh'),
            supportedLocales: L10n.supportedLocales,
            localizationsDelegates: const [
              L10n.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: EdgeInsets.only(bottom: bottom),
                viewPadding: EdgeInsets.only(bottom: bottom),
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: Builder(
                builder: (context) => Scaffold(
                      extendBody: true,
                      body: BottomBar(
                        width: 330,
                        offset: HomeNavigationMetrics.barOffset,
                        hideOnScroll: false,
                        body: (_, suppliedController) {
                          controller = suppliedController;
                          return HomeNavigationBody(
                            hasBottomBar: true,
                            scrollBehindBar: true,
                            child: SettingsPage(controller: suppliedController),
                          );
                        },
                        child: SizedBox(
                          key: const ValueKey('floating-bar'),
                          height: HomeNavigationMetrics.barHeightFor(context),
                          child: const ColoredBox(color: Colors.blue),
                        ),
                      ),
                    )),
          )));
          await tester.pumpAndSettle();
          expect(controller.hasClients, isTrue);
          // Lazy variable-height tiles refine maxScrollExtent after layout.
          // Reach the actual bottom, not the initial estimate (large text can
          // change it after the first jump). Keep the clearance assertion exact.
          for (var attempt = 0; attempt < 5; attempt++) {
            controller.jumpTo(controller.position.maxScrollExtent);
            await tester.pumpAndSettle();
            if (controller.position.extentAfter < 0.01) break;
          }
          expect(controller.position.extentAfter, lessThan(0.01));
          final about = find.byType(About);
          final aboutFrame = tester.widget<FilledContainer>(find
              .ancestor(of: about, matching: find.byType(FilledContainer))
              .first);
          expect(aboutFrame.radius, 12);
          expect(aboutFrame.margin,
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6));
          final aboutRect = tester.getRect(about);
          final barRect =
              tester.getRect(find.byKey(const ValueKey('floating-bar')));
          expect(
              aboutRect.bottom,
              lessThanOrEqualTo(
                  barRect.top - HomeNavigationMetrics.contentGap));
          expect(aboutRect.top, greaterThan(0));
          await tester.tap(about);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.byKey(const ValueKey('about-app-frame')), findsOneWidget);
          expect(find.byKey(const ValueKey('about-credits-frame')),
              findsOneWidget);
          expect(find.textContaining('1.1.6-test.1+10048'), findsOneWidget);
          final dialogFrames = find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(FilledContainer));
          expect(dialogFrames, findsNWidgets(4));
          final rects = [
            for (var i = 0; i < 4; i++) tester.getRect(dialogFrames.at(i))
          ];
          for (final rect in rects) {
            expect(rect.left, closeTo(rects.first.left, 0.01));
            expect(rect.right, closeTo(rects.first.right, 0.01));
            expect(rect.height, greaterThan(0));
          }
          // All groups align horizontally, but their content sets the height.
          expect(rects.map((rect) => rect.height.round()).toSet().length,
              greaterThan(1));
          final feedback = find.byKey(const ValueKey('about-feedback'));
          await tester.ensureVisible(feedback);
          await tester.pumpAndSettle();
          await tester.tap(feedback);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byType(BugReportSettings), findsOneWidget);
          Navigator.of(tester.element(find.byType(BugReportSettings))).pop();
          await tester.pumpAndSettle();
          expect(find.byType(SettingsPage), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
