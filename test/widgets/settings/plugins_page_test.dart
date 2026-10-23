import 'dart:io';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/models/plugin_state.dart';
import 'package:anx_reader/page/settings_page/plugins/plugins_page.dart';
import 'package:anx_reader/service/plugins/plugin_host.dart';
import 'package:anx_reader/service/plugins/plugin_paths.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../service/plugins/plugin_test_utils.dart';

void main() {
  late Directory temp;
  late PluginHost host;
  File? nextPackage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    Prefs().userPrompts = [];
    await Prefs().savePluginState(PluginState.empty);
    await Prefs().saveLocaleToPrefs('en');
    temp = await Directory.systemTemp.createTemp('modu_plugin_ui_');
    host = PluginHost(
      paths: PluginPaths(rootPath: p.join(temp.path, 'plugins')),
      appVersionResolver: () async => '1.3.1+10152',
    );
    await host.initialize();
    nextPackage = await writePluginZip(
        temp,
        samplePackageFiles(
            manifest: manifestJson(contributes: [
          aiSkill(
              id: 'deep-summary',
              name: const {'zh-CN': '深度摘要', 'en': 'Deep summary'}),
          aiSkill(
              id: 'socratic-questions',
              name: const {'zh-CN': '苏格拉底提问', 'en': 'Socratic questions'}),
        ])));
  });

  tearDown(() async {
    host.dispose();
    try {
      if (await temp.exists()) await temp.delete(recursive: true);
    } catch (_) {
      // Windows may still hold the temp directory briefly; leaking it in a
      // failing test run is harmless.
    }
  });

  Future<void> pumpSettings(WidgetTester tester,
      {VoidCallback? onPick, bool pickNothing = false}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      home: Scaffold(
        body: PluginSettings(
          host: host,
          pickPackage: () async {
            onPick?.call();
            return pickNothing ? null : nextPackage;
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> installSample(WidgetTester tester) async {
    await tester.runAsync(() => host.install(nextPackage!));
  }

  /// Lets real file-system futures started by a tap handler finish, which
  /// `pumpAndSettle` cannot observe because they schedule no frames.
  Future<void> settleAsync(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
  }

  testWidgets('empty state explains packages and offers install',
      (tester) async {
    await pumpSettings(tester);
    expect(find.text('Install plugin…'), findsOneWidget);
    expect(find.textContaining('No plugins installed yet'), findsOneWidget);
  });

  testWidgets('the install button opens the package picker', (tester) async {
    var picked = false;
    await pumpSettings(tester, onPick: () => picked = true, pickNothing: true);
    await tester.tap(find.byKey(const ValueKey('plugin-install')));
    await tester.pumpAndSettle();
    expect(picked, isTrue);
  });

  testWidgets('an installed plugin renders its name, version and status',
      (tester) async {
    await installSample(tester);
    await pumpSettings(tester);

    expect(find.text('Example prompt pack'), findsOneWidget);
    expect(find.textContaining('v1.0.0 · Enabled'), findsOneWidget);
    expect(Prefs().userPrompts, hasLength(2));
  });

  testWidgets('the switch disables and re-enables contributions',
      (tester) async {
    await installSample(tester);
    await pumpSettings(tester);

    await tester.tap(find.byType(Switch).first);
    await settleAsync(tester);
    expect(Prefs().userPrompts, isEmpty);
    expect(find.textContaining('v1.0.0 · Disabled'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await settleAsync(tester);
    expect(Prefs().userPrompts, hasLength(2));
  });

  testWidgets('uninstall asks for confirmation and cleans up', (tester) async {
    await installSample(tester);
    await pumpSettings(tester);

    await tester
        .tap(find.byKey(const ValueKey('plugin-menu-com.example.prompt-pack')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uninstall'));
    await tester.pumpAndSettle();

    expect(find.text('Uninstall plugin?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Uninstall'));
    await settleAsync(tester);

    expect(find.text('Example prompt pack'), findsNothing);
    expect(Prefs().userPrompts, isEmpty);
    expect(host.plugins, isEmpty);
  });

  testWidgets('details list permissions and contributed prompts',
      (tester) async {
    await installSample(tester);
    await pumpSettings(tester);

    await tester.tap(find.text('Example prompt pack'));
    await settleAsync(tester);

    expect(find.text('Permissions'), findsOneWidget);
    expect(find.text('Add AI prompt templates'), findsOneWidget);
    expect(find.text('Contributions'), findsOneWidget);
    expect(find.text('Deep summary'), findsWidgets);
    expect(find.text('Socratic questions'), findsWidgets);
    expect(find.text('Socratic questions'), findsWidgets);
  });
}
