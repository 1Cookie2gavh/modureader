import 'dart:io';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/models/plugin_manifest.dart';
import 'package:anx_reader/models/plugin_state.dart';
import 'package:anx_reader/models/user_prompt.dart';
import 'package:anx_reader/service/plugins/plugin_host.dart';
import 'package:anx_reader/service/plugins/plugin_paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'plugin_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late PluginPaths paths;
  late PluginHost host;

  PluginHost createHost() => PluginHost(
        paths: paths,
        appVersionResolver: () async => '1.3.1+10152',
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    Prefs().userPrompts = [];
    await Prefs().savePluginState(PluginState.empty);
    temp = await Directory.systemTemp.createTemp('modu_plugin_host_');
    paths = PluginPaths(rootPath: p.join(temp.path, 'plugins'));
    host = createHost();
    await host.initialize();
  });

  tearDown(() async {
    host.dispose();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<File> package({
    String version = '1.0.0',
    String? manifest,
  }) {
    return writePluginZip(
      temp,
      samplePackageFiles(manifest: manifest ?? manifestJson(version: version)),
      name: 'package-$version.moduplugin',
    );
  }

  test('initialize is idempotent and tolerates empty state', () async {
    await host.initialize();
    await host.initialize();
    expect(host.plugins, isEmpty);
    expect(Prefs().userPrompts, isEmpty);
  });

  test('installs a package, materialises prompts and persists state', () async {
    final result = await host.install(await package());
    expect(result.record.status, PluginStatus.enabled);
    expect(host.plugins, hasLength(1));
    expect(await paths.pluginDir('com.example.prompt-pack').exists(), isTrue);

    final prompts = Prefs().userPrompts;
    expect(prompts, hasLength(2));
    expect(prompts.first.id, 'plugin:com.example.prompt-pack:deep-summary');
    expect(prompts.first.enabled, isTrue);
    expect(prompts.first.order, 1);
    expect(prompts.last.order, 2);

    final stored = Prefs().pluginState.byId('com.example.prompt-pack');
    expect(stored, isNotNull);
    expect(stored!.applied, hasLength(2));
    expect(stored.sha256, result.record.sha256);
  });

  test('rejects the same version until it is explicitly reinstalled', () async {
    final file = await package();
    await host.install(file);
    await expectLater(
      () => host.install(file),
      throwsA(isA<PluginInstallError>().having(
          (error) => error.code, 'code', PluginErrorCode.alreadyInstalled)),
    );

    await host.install(file, allowSameVersion: true);
    expect(host.plugins, hasLength(1));
    expect(Prefs().userPrompts, hasLength(2));
  });

  test('upgrade replaces prompts and rejects downgrade', () async {
    await host.install(await package(version: '1.0.0'));
    await host.install(await package(
        version: '1.1.0',
        manifest: manifestJson(
          version: '1.1.0',
          contributes: [aiSkill(id: 'deep-summary', prompt: '新的提示词')],
        )));

    expect(host.byId('com.example.prompt-pack')!.version, '1.1.0');
    final prompts = Prefs().userPrompts;
    expect(prompts, hasLength(1));
    expect(prompts.single.content, '新的提示词');

    await expectLater(
      () async => host.install(await package(version: '1.0.0')),
      throwsA(isA<PluginInstallError>().having(
          (error) => error.code, 'code', PluginErrorCode.downgradeNotAllowed)),
    );
  });

  test('disable removes contributions and enable restores them', () async {
    await host.install(await package());
    await host.disable('com.example.prompt-pack');

    expect(host.byId('com.example.prompt-pack')!.status, PluginStatus.disabled);
    expect(Prefs().userPrompts, isEmpty);

    await host.enable('com.example.prompt-pack');
    expect(host.byId('com.example.prompt-pack')!.status, PluginStatus.enabled);
    expect(Prefs().userPrompts, hasLength(2));
  });

  test('uninstall removes files, prompts and the registry entry', () async {
    await host.install(await package());
    await host.uninstall('com.example.prompt-pack');

    expect(host.plugins, isEmpty);
    expect(Prefs().userPrompts, isEmpty);
    expect(Prefs().pluginState.plugins, isEmpty);
    expect(await paths.pluginDir('com.example.prompt-pack').exists(), isFalse);
  });

  test('disable keeps plugin settings but uninstall deletes them', () async {
    await host.install(await package());
    await Prefs()
        .savePluginConfig('com.example.prompt-pack', {'tone': 'brief'});

    await host.disable('com.example.prompt-pack');
    expect(Prefs().pluginConfig('com.example.prompt-pack'), {'tone': 'brief'});

    await host.uninstall('com.example.prompt-pack');
    expect(Prefs().pluginConfig('com.example.prompt-pack'), isEmpty);
  });

  test('uninstall keeps a prompt the user edited as a custom prompt', () async {
    await host.install(await package());
    final prompts = Prefs().userPrompts;
    Prefs().userPrompts = [
      prompts.first.copyWith(content: '我改过的提示词'),
      prompts.last,
    ];

    await host.uninstall('com.example.prompt-pack');

    final remaining = Prefs().userPrompts;
    expect(remaining, hasLength(1));
    expect(remaining.single.id, startsWith('custom-'));
    expect(remaining.single.content, '我改过的提示词');
  });

  test('missing package directory becomes missing without crashing', () async {
    await host.install(await package());
    await paths.deletePlugin('com.example.prompt-pack');

    final restarted = createHost();
    addTearDown(restarted.dispose);
    await restarted.initialize();

    final record = restarted.byId('com.example.prompt-pack');
    expect(record, isNotNull);
    expect(record!.status, PluginStatus.missing);
    expect(record.applied, isEmpty);
    expect(Prefs().userPrompts, isEmpty);

    await restarted.uninstall('com.example.prompt-pack');
    expect(Prefs().pluginState.plugins, isEmpty);
  });

  test('damaged manifest becomes broken and keeps a diagnostic', () async {
    await host.install(await package());
    final manifestFile = paths.manifestFile('com.example.prompt-pack');
    await manifestFile.writeAsString('{broken', flush: true);

    final restarted = createHost();
    addTearDown(restarted.dispose);
    await restarted.initialize();

    final record = restarted.byId('com.example.prompt-pack');
    expect(record!.status, PluginStatus.broken);
    expect(record.lastError, isNotNull);
    expect(Prefs().userPrompts, isEmpty);
  });

  test('restart keeps enabled plugins without duplicating prompts', () async {
    await host.install(await package());

    final restarted = createHost();
    addTearDown(restarted.dispose);
    await restarted.initialize();

    expect(restarted.byId('com.example.prompt-pack')!.status,
        PluginStatus.enabled);
    expect(Prefs().userPrompts, hasLength(2));
  });

  test('a single user-deleted prompt is not resurrected on restart', () async {
    await host.install(await package());
    Prefs().userPrompts = [Prefs().userPrompts.first];

    final restarted = createHost();
    addTearDown(restarted.dispose);
    await restarted.initialize();

    expect(Prefs().userPrompts, hasLength(1));
  });

  test('rejects minAppVersion above the running app', () async {
    final file = await writePluginZip(temp,
        samplePackageFiles(manifest: manifestJson(minAppVersion: '9.0.0')));
    await expectLater(
      () => host.install(file),
      throwsA(isA<PluginInstallError>()
          .having((error) => error.code, 'code', PluginErrorCode.appTooOld)),
    );
  });

  test('returns a warning for skipped contribution kinds', () async {
    final file = await writePluginZip(
        temp,
        samplePackageFiles(
            manifest: manifestJson(contributes: [
          aiSkill(id: 'known'),
          {
            'kind': 'futureKind',
            'schema': 1,
            'id': 'future',
          },
        ])));
    final result = await host.install(file);
    expect(result.warnings, hasLength(1));
    expect(Prefs().userPrompts, hasLength(1));
  });

  test('refuses to overwrite a prompt the plugin does not own', () async {
    final now = DateTime.now();
    Prefs().userPrompts = [
      UserPrompt(
        id: 'plugin:com.example.prompt-pack:deep-summary',
        name: '用户自己的',
        content: '用户内容',
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    await expectLater(
      () async => host.install(await package()),
      throwsA(isA<PluginInstallError>().having(
          (error) => error.code, 'code', PluginErrorCode.promptConflict)),
    );
    expect(Prefs().userPrompts.single.content, '用户内容');
    expect(host.plugins, isEmpty);
  });
}
