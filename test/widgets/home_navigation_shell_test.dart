import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/widgets/home_navigation_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' as provider;
import 'package:shared_preferences/shared_preferences.dart';

Widget _page(String identifier, ScrollController? controller) =>
    Text('page-$identifier');

Widget host({bool productionTopology = false}) {
  final app = MaterialApp(
    locale: const Locale('en'),
    supportedLocales: L10n.supportedLocales,
    localizationsDelegates: L10n.localizationsDelegates,
    home: const HomeNavigationShell(pageBuilder: _page),
  );
  if (!productionTopology) return app;
  // The real app exposes this shell as a const home route. That route is not
  // rebuilt when Prefs notifies, so the shell must refresh itself.
  return provider.ChangeNotifierProvider(
    create: (_) => Prefs(),
    child: provider.Consumer<Prefs>(
      builder: (context, prefs, child) => app,
    ),
  );
}

Future<void> pumpHome(
  WidgetTester tester,
  Size size, {
  bool productionTopology = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(productionTopology: productionTopology));
  await tester.pumpAndSettle();
}

NavigationRail rail(WidgetTester tester) =>
    tester.widget<NavigationRail>(find.byType(NavigationRail));

BottomNavigationBar bottomBar(WidgetTester tester) =>
    tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    Prefs().bottomNavigatorShowAI = true;
    Prefs().bottomNavigatorShowStatistics = true;
    Prefs().bottomNavigatorShowNote = true;
  });

  testWidgets(
      'wide rail shows a newly separated tab immediately after its switch '
      'changes', (tester) async {
    await pumpHome(tester, const Size(1200, 800));
    expect(rail(tester).destinations.length, 6);

    Prefs().bottomNavigatorShowNote = false;
    await tester.pump();
    expect(rail(tester).destinations.length, 5);
    expect(find.byIcon(Icons.note), findsNothing);

    Prefs().bottomNavigatorShowNote = true;
    await tester.pump();
    expect(rail(tester).destinations.length, 6);
    expect(find.byIcon(Icons.note), findsOneWidget);
  });

  testWidgets('wide rail keeps the other tab switches in sync too',
      (tester) async {
    await pumpHome(tester, const Size(1200, 800));

    Prefs().bottomNavigatorShowStatistics = false;
    await tester.pump();
    expect(rail(tester).destinations.length, 5);
    expect(find.byIcon(Icons.history), findsNothing);

    Prefs().bottomNavigatorShowAI = false;
    await tester.pump();
    expect(rail(tester).destinations.length, 4);

    Prefs().bottomNavigatorShowStatistics = true;
    Prefs().bottomNavigatorShowAI = true;
    await tester.pump();
    expect(rail(tester).destinations.length, 6);
  });

  testWidgets('wide rail falls back when the selected tab is switched off',
      (tester) async {
    await pumpHome(tester, const Size(1200, 800));
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(rail(tester).selectedIndex, 2);
    expect(find.text('page-statistics'), findsOneWidget);

    Prefs().bottomNavigatorShowStatistics = false;
    await tester.pump();
    expect(rail(tester).selectedIndex, 0);
    expect(find.text('page-bookshelf'), findsOneWidget);
  });

  testWidgets('compact bar shows a newly separated tab immediately',
      (tester) async {
    await pumpHome(tester, const Size(500, 800));
    expect(bottomBar(tester).items.length, 6);

    Prefs().bottomNavigatorShowAI = false;
    await tester.pump();
    expect(bottomBar(tester).items.length, 5);

    Prefs().bottomNavigatorShowAI = true;
    await tester.pump();
    expect(bottomBar(tester).items.length, 6);
  });

  testWidgets('rail refreshes under the const home route used by the app',
      (tester) async {
    await pumpHome(tester, const Size(1200, 800), productionTopology: true);
    expect(rail(tester).destinations.length, 6);

    Prefs().bottomNavigatorShowNote = false;
    await tester.pump();
    expect(rail(tester).destinations.length, 5);

    Prefs().bottomNavigatorShowNote = true;
    await tester.pump();
    expect(rail(tester).destinations.length, 6);
  });
}
