import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/page/settings_page/selection_toolbar.dart';
import 'package:anx_reader/page/settings_page/remote_library.dart';
import 'package:anx_reader/page/settings_page/settings_page.dart';
import 'package:anx_reader/page/settings_page/appearance.dart';
import 'package:anx_reader/utils/color_scheme.dart';
import 'package:anx_reader/widgets/common/container/filled_container.dart';
import 'package:anx_reader/widgets/settings/settings_section.dart';
import 'package:anx_reader/widgets/settings/settings_tile.dart';
import 'package:anx_reader/widgets/settings/community_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });

  test('default uses jade without overwriting explicitly chosen colours',
      () async {
    expect(Prefs().themeColor, const Color(0xFF197D74));
    await Prefs().saveThemeToPrefs(Colors.blue.toARGB32());
    expect(Prefs().themeColor.toARGB32(), Colors.blue.toARGB32());
    expect(Prefs().prefs.getInt('themeColor'), Colors.blue.toARGB32());
    await Prefs().saveThemeToPrefs(Colors.red.toARGB32());
    expect(Prefs().themeColor.toARGB32(), Colors.red.toARGB32());
  });

  testWidgets('true black remains black and the custom accent stays usable',
      (tester) async {
    await Prefs().saveThemeModeToPrefs('dark');
    Prefs().trueDarkMode = true;
    await Prefs().saveThemeToPrefs(Colors.red.toARGB32());
    late ThemeData theme;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      theme = colorSchema(Prefs(), context, Brightness.dark);
      return const SizedBox();
    })));
    expect(theme.scaffoldBackgroundColor, Colors.black);
    expect(theme.cardTheme.color, Colors.black);
    expect(theme.dialogTheme.backgroundColor, Colors.black);
    expect(theme.colorScheme.primary, isNot(const Color(0xFFB5C4A7)));
    expect(Prefs().themeColor.toARGB32(), Colors.red.toARGB32());
  });

  testWidgets('colour picker restores default without resetting other settings',
      (tester) async {
    await Prefs().saveThemeToPrefs(Colors.red.toARGB32());
    await Prefs().saveThemeModeToPrefs('dark');
    Prefs().trueDarkMode = true;
    Prefs().eInkMode = true;
    var notifications = 0;
    void listener() => notifications++;
    Prefs().addListener(listener);
    addTearDown(() => Prefs().removeListener(listener));
    await tester.pumpWidget(ChangeNotifierProvider<Prefs>.value(
        value: Prefs(),
        child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            home: Builder(
                builder: (context) => TextButton(
                      onPressed: () => showColorPickerDialog(context),
                      child: const Text('Pick colour'),
                    )))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick colour'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reset-theme-color')));
    await tester.pumpAndSettle();
    expect(Prefs().themeColor.toARGB32(), Colors.red.toARGB32());
    await tester.tap(find.byKey(const ValueKey('cancel-color-reset')));
    await tester.pumpAndSettle();
    expect(Prefs().themeColor.toARGB32(), Colors.red.toARGB32());
    expect(notifications, 0);
    await tester.tap(find.byKey(const ValueKey('reset-theme-color')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-color-reset')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(Prefs().prefs.containsKey('themeColor'), isFalse);
    expect(Prefs().themeColor, const Color(0xFF197D74));
    expect(Prefs().themeMode, ThemeMode.dark);
    expect(Prefs().trueDarkMode, isTrue);
    expect(Prefs().eInkMode, isTrue);
    expect(notifications, 1);
    await Prefs().initPrefs();
    expect(Prefs().themeColor, const Color(0xFF197D74));
  });

  testWidgets('old default upgrades visually without changing saved colours',
      (tester) async {
    for (final dark in [false, true]) {
      await Prefs().saveThemeModeToPrefs(dark ? 'dark' : 'light');
      ColorScheme? previous;
      for (final seed in [0xFF56674F, 0xFF197D74]) {
        await Prefs().saveThemeToPrefs(seed);
        late ThemeData theme;
        await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
          theme = colorSchema(Prefs(), context, Brightness.light);
          return const SizedBox();
        })));
        if (previous != null) expect(theme.colorScheme, previous);
        previous = theme.colorScheme;
        expect(Prefs().prefs.getInt('themeColor'), seed);
        expect(theme.colorScheme.secondaryContainer,
            Color(dark ? 0xFF303A2B : 0xFFE5F3EE));
        expect(theme.colorScheme.onSurfaceVariant,
            Color(dark ? 0xFFA2A79B : 0xFF65716D));
      }
    }
  });

  for (final eink in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets('menus inherit page background dark=$dark eink=$eink',
          (tester) async {
        Prefs().eInkMode = eink;
        await Prefs().saveThemeModeToPrefs(dark ? 'dark' : 'light');
        late ThemeData theme;
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Builder(builder: (context) {
            theme = colorSchema(Prefs(), context, Brightness.light);
            return Theme(
              data: theme,
              child: SettingsPageBody(
                title: 'Settings',
                isMobile: true,
                sections: SingleChildScrollView(
                  child: SettingsSection(
                    title: const Text('Global backup'),
                    tiles: [
                      SettingsTile.navigation(
                          title: const Text('Export'), onPressed: (_) {}),
                    ],
                  ),
                ),
              ),
            );
          }),
        ));
        await tester.pumpAndSettle();
        final background = eink
            ? Colors.white
            : dark
                ? const Color(0xFF1C1E1B)
                : const Color(0xFFFCFCFA);
        expect(theme.scaffoldBackgroundColor, background);
        expect(theme.colorScheme.surface, background);
        expect(theme.colorScheme.surfaceContainer, background);
        expect(theme.sliderTheme.thumbSize?.resolve({}),
            eink ? isNull : const Size(4, 28));
        final heading = tester.element(find.text('Global backup'));
        final headingStyle = DefaultTextStyle.of(heading).style;
        final resolvedBody = Theme.of(heading).textTheme.bodyMedium!;
        expect(headingStyle.fontSize, resolvedBody.fontSize);
        expect(headingStyle.fontFamily, resolvedBody.fontFamily);
        expect(headingStyle.color, theme.colorScheme.primary);
        expect(
          tester.getBottomLeft(find.text('Global backup')).dy,
          lessThan(tester.getTopLeft(find.byType(FilledContainer).first).dy),
        );
        expect(
            tester
                .widget<CupertinoPageScaffold>(
                    find.byType(CupertinoPageScaffold))
                .backgroundColor,
            background);
        final container = find
            .descendant(
                of: find.byType(FilledContainer),
                matching: find.byType(AnimatedContainer))
            .first;
        final decoration = tester
            .widget<AnimatedContainer>(container)
            .decoration! as ShapeDecoration;
        expect(decoration.color, eink ? Colors.transparent : background);
        if (eink) {
          expect(decoration.shadows, isEmpty);
        } else {
          final shadow = decoration.shadows!.single;
          expect(shadow.offset, const Offset(0, 2));
          expect(shadow.blurRadius, 8);
          expect(shadow.blurStyle, BlurStyle.normal);
          expect(shadow.color.a, closeTo(0.20, 0.01));
        }
        expect((decoration.shape as OutlinedBorder).side.color,
            theme.colorScheme.outlineVariant);
        expect(
            theme.colorScheme.outlineVariant,
            eink
                ? Colors.black
                : dark
                    ? const Color(0xFF383D35)
                    : const Color(0xFFE4EAE6));
        expect(
            theme.colorScheme.primary,
            eink
                ? Colors.black
                : dark
                    ? const Color(0xFFB5C4A7)
                    : const Color(0xFF197D74));
        expect(
            theme.colorScheme.onSurface,
            eink
                ? Colors.black
                : dark
                    ? const Color(0xFFE5E7DF)
                    : const Color(0xFF283633));
        for (final surface in [
          theme.canvasColor,
          theme.colorScheme.surfaceContainerLow,
          theme.colorScheme.surfaceContainerHigh,
          theme.colorScheme.surfaceContainerHighest,
          theme.navigationRailTheme.backgroundColor,
          theme.navigationBarTheme.backgroundColor,
        ]) {
          expect(surface, background);
        }
        expect(theme.popupMenuTheme.color, background);
        expect(theme.dialogTheme.backgroundColor, background);
        expect(theme.bottomSheetTheme.backgroundColor, background);
        for (final elevation in [
          theme.popupMenuTheme.elevation,
          theme.dialogTheme.elevation,
          theme.bottomSheetTheme.elevation,
          theme.menuTheme.style!.elevation!.resolve({}),
        ]) {
          expect(elevation, eink ? 0 : 4);
        }
        for (final shadow in [
          theme.popupMenuTheme.shadowColor,
          theme.dialogTheme.shadowColor,
          theme.bottomSheetTheme.shadowColor,
          theme.menuTheme.style!.shadowColor!.resolve({}),
        ]) {
          expect(shadow, theme.cardTheme.shadowColor);
        }
        if (eink) {
          for (final states in [
            <WidgetState>{},
            {WidgetState.selected},
            {WidgetState.disabled},
          ]) {
            expect(theme.chipTheme.color!.resolve(states), Colors.transparent);
            expect(
                theme.segmentedButtonTheme.style!.backgroundColor!
                    .resolve(states),
                Colors.transparent);
            expect(
                theme.filledButtonTheme.style!.backgroundColor!.resolve(states),
                Colors.transparent);
            expect(theme.switchTheme.trackColor!.resolve(states),
                Colors.transparent);
          }
        }

        await tester.pumpWidget(MaterialApp(
          theme: theme,
          locale: const Locale('en'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: const Scaffold(body: SelectionToolbarSettings()),
        ));
        await tester.pumpAndSettle();
        final cards = find.byType(Card);
        expect(cards, findsWidgets);
        for (final card in cards.evaluate()) {
          final material = tester.widget<Material>(find
              .descendant(
                  of: find.byWidget(card.widget),
                  matching: find.byType(Material))
              .first);
          expect(material.color, eink ? Colors.transparent : background);
          expect(material.elevation, eink ? 0 : 4);
          expect(material.shadowColor, theme.cardTheme.shadowColor);
        }
        expect(tester.takeException(), isNull);
        for (final panel in [
          const RemoteLibrarySettings(),
          const SingleChildScrollView(child: CommunityLinks()),
        ]) {
          await tester.pumpWidget(MaterialApp(
            theme: theme,
            home: Scaffold(body: panel),
          ));
          await tester.pumpAndSettle();
          final frames = find.descendant(
              of: find.byType(FilledContainer),
              matching: find.byType(AnimatedContainer));
          expect(frames, findsWidgets);
          for (final frame in tester.widgetList<AnimatedContainer>(frames)) {
            final decoration = frame.decoration! as ShapeDecoration;
            expect(decoration.color, eink ? Colors.transparent : background);
            expect(decoration.shadows, eink ? isEmpty : isNotEmpty);
            if (!eink) {
              expect(decoration.shadows!.single.color,
                  theme.cardTheme.shadowColor);
            }
          }
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
