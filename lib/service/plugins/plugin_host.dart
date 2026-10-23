import 'dart:convert';
import 'dart:io';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/models/plugin_manifest.dart';
import 'package:anx_reader/models/plugin_state.dart';
import 'package:anx_reader/service/plugins/plugin_contributions.dart';
import 'package:anx_reader/service/plugins/plugin_package.dart';
import 'package:anx_reader/service/plugins/plugin_paths.dart';
import 'package:anx_reader/utils/app_version.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

class PluginInstallResult {
  const PluginInstallResult({required this.record, this.warnings = const []});

  final PluginRecord record;
  final List<String> warnings;
}

/// Single source of truth for installed plugins.
///
/// P1a only materialises declarative contributions; no package code runs.
/// All public mutation methods are transactional around the prompt snapshot:
/// a failure restores the snapshot and the filesystem, and never leaves a
/// registry entry behind.
class PluginHost extends ChangeNotifier {
  PluginHost({
    PluginPaths? paths,
    PluginPackageReader? reader,
    PluginContributions? contributions,
    Future<String> Function()? appVersionResolver,
  })  : _paths = paths ?? PluginPaths(),
        _appVersionResolver = appVersionResolver ?? getAppVersion {
    _reader = reader ?? PluginPackageReader(paths: _paths);
    _contributions = contributions ?? PluginContributions.standard();
  }

  static PluginHost? _instance;

  static PluginHost get instance => _instance ??= PluginHost();

  final PluginPaths _paths;
  late final PluginPackageReader _reader;
  late final PluginContributions _contributions;
  final Future<String> Function() _appVersionResolver;

  static const bool _compiledIn =
      bool.fromEnvironment('MODU_PLUGINS', defaultValue: true);

  /// Build-level kill switch (`--dart-define=MODU_PLUGINS=false`).
  static bool get isEnabled => _compiledIn;

  List<PluginRecord> _plugins = const [];
  final Map<String, PluginManifest> _manifests = {};
  final Map<String, String> _manifestTexts = {};
  String _appVersion = '';
  bool _initialized = false;
  bool _disposed = false;
  Future<void>? _initializing;

  List<PluginRecord> get plugins => List.unmodifiable(_plugins);

  PluginPaths get paths => _paths;

  String get appVersion => _appVersion;

  bool get isInitialized => _initialized;

  PluginRecord? byId(String id) {
    for (final plugin in _plugins) {
      if (plugin.id == id) return plugin;
    }
    return null;
  }

  /// Parsed manifest kept in memory so enable/disable and the detail page do
  /// not need file-system access (and keep working with a fake clock in tests).
  PluginManifest? manifestFor(String id) => _manifests[id];

  String? manifestTextFor(String id) => _manifestTexts[id];

  /// Loads the registry and reconciles it with the package directory.
  ///
  /// Safe to call more than once (Android deferred start, macOS migration).
  Future<void> initialize() async {
    if (_disposed || !_compiledIn) return;
    final running = _initializing;
    if (running != null) return running;
    final future = _initializeOnce();
    _initializing = future;
    try {
      await future;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initializeOnce() async {
    await _paths.ensureCreated();
    await _paths.cleanStale();
    try {
      _appVersion = await _appVersionResolver();
    } catch (_) {
      _appVersion = '';
    }

    final loaded = Prefs().pluginState;
    final next = <PluginRecord>[];
    var changed = false;
    _manifests.clear();
    _manifestTexts.clear();
    for (final record in loaded.plugins) {
      final result = await _reconcile(record);
      next.add(result.record);
      changed = changed || result.changed;
    }
    _plugins = next;
    _initialized = true;
    if (changed) {
      try {
        await Prefs()
            .savePluginState(PluginState(plugins: List.unmodifiable(next)));
      } catch (error) {
        AnxLog.warning('Could not persist reconciled plugin state: $error');
      }
    }
    notifyListeners();
  }

  Future<_Reconciled> _reconcile(PluginRecord record) async {
    final directory = _paths.pluginDir(record.id);
    if (!await directory.exists()) {
      _manifests.remove(record.id);
      _manifestTexts.remove(record.id);
      await _removeContributions(record);
      return _Reconciled(
        record: record.copyWith(
            status: PluginStatus.missing,
            applied: const [],
            clearLastError: true),
        changed: true,
      );
    }

    _LoadedManifest? loadedManifest;
    try {
      loadedManifest = await _readManifest(record.id);
    } catch (error) {
      _manifests.remove(record.id);
      _manifestTexts.remove(record.id);
      await _removeContributions(record);
      return _Reconciled(
        record: record.copyWith(
            status: PluginStatus.broken,
            applied: const [],
            lastError: describeError(error)),
        changed: true,
      );
    }
    if (loadedManifest == null ||
        loadedManifest.manifest.id != record.id ||
        loadedManifest.manifest.version != record.version) {
      await _removeContributions(record);
      return _Reconciled(
        record: record.copyWith(
            status: PluginStatus.broken,
            applied: const [],
            lastError: 'Installed files no longer match the registry entry.'),
        changed: true,
      );
    }
    final manifest = loadedManifest.manifest;
    _manifests[record.id] = manifest;
    _manifestTexts[record.id] = loadedManifest.text;

    if (record.status == PluginStatus.missing ||
        record.status == PluginStatus.broken) {
      // The package came back (for example the storage was remounted). Keep it
      // disabled until the user enables it again.
      return _Reconciled(
          record: record.copyWith(
              status: PluginStatus.disabled, clearLastError: true),
          changed: true);
    }

    if (record.status == PluginStatus.enabled) {
      final promptIds = Prefs().userPrompts.map((prompt) => prompt.id).toSet();
      final lost = record.applied.isEmpty ||
          record.applied.every((entry) => !promptIds.contains(entry.id));
      if (lost) {
        try {
          final applied = await _contributions.apply(manifest);
          return _Reconciled(
              record: record.copyWith(applied: applied), changed: true);
        } catch (error) {
          return _Reconciled(
              record: record.copyWith(
                  status: PluginStatus.broken,
                  lastError: describeError(error),
                  applied: const []),
              changed: true);
        }
      }
    }

    return _Reconciled(record: record, changed: false);
  }

  Future<_LoadedManifest?> _readManifest(String id) async {
    final file = _paths.manifestFile(id);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > PluginLimits.maxManifestBytes) {
      throw const PluginInstallError(
          PluginErrorCode.manifestTooLarge, 'manifest.json is too large.');
    }
    final text = _decodeUtf8(bytes);
    return _LoadedManifest(PluginManifest.parse(text), text);
  }

  Future<PluginInstallResult> install(File package,
      {bool allowSameVersion = false}) async {
    _ensureUsable();
    if (!_initialized) await initialize();
    final pkg = await _reader.read(package);
    try {
      final manifest = pkg.manifest;
      if (_appVersion.isNotEmpty) manifest.ensureCompatibleWith(_appVersion);

      final existing = byId(manifest.id);
      if (existing != null) {
        final comparison = Version.parse(manifest.version)
            .compareTo(Version.parse(existing.version));
        final repairable = existing.status == PluginStatus.broken ||
            existing.status == PluginStatus.missing;
        if (comparison < 0) {
          throw PluginInstallError(PluginErrorCode.downgradeNotAllowed,
              'A newer version (${existing.version}) is already installed. Uninstall it first.');
        }
        if (comparison == 0 && !repairable && !allowSameVersion) {
          throw PluginInstallError(PluginErrorCode.alreadyInstalled,
              'Version ${manifest.version} is already installed.');
        }
      }

      final snapshot = Prefs().userPrompts;
      List<AppliedContribution> applied = const [];
      Directory? previousFiles;
      try {
        applied = await _contributions.apply(manifest);
        if (existing != null) {
          final newIds = applied.map((entry) => entry.id).toSet();
          final stale = existing.applied
              .where((entry) => !newIds.contains(entry.id))
              .toList();
          await _contributions.remove(stale);
        }
        previousFiles = await _placeFiles(pkg);

        final record = PluginRecord(
          id: manifest.id,
          version: manifest.version,
          name: manifest.name,
          license: manifest.license,
          author: manifest.author?.name,
          installedAt: DateTime.now(),
          sha256: pkg.sha256,
          status: PluginStatus.enabled,
          applied: List.unmodifiable(applied),
        );
        await Prefs().savePluginState(Prefs().pluginState.upsert(record));
        _manifests[manifest.id] = manifest;
        _manifestTexts[manifest.id] = pkg.manifestText;
        _upsertMemory(record);
        notifyListeners();
        if (previousFiles != null) await _deleteQuietly(previousFiles);
        return PluginInstallResult(
            record: record, warnings: List.unmodifiable(pkg.warnings));
      } catch (error) {
        Prefs().userPrompts = snapshot;
        await _rollbackFiles(manifest.id, previousFiles);
        rethrow;
      }
    } finally {
      await pkg.dispose();
    }
  }

  Future<void> enable(String id) async {
    _ensureUsable();
    final record = _require(id);
    if (!record.isUsable) {
      throw PluginInstallError(PluginErrorCode.pluginUnavailable,
          'This plugin is ${record.status.name}; reinstall it first.');
    }
    if (record.status == PluginStatus.enabled) return;

    final manifest = _manifests[id];
    if (manifest == null) {
      throw PluginInstallError(
          PluginErrorCode.pluginUnavailable, 'Plugin manifest is unavailable.');
    }
    manifest.ensureCompatibleWith(_appVersion);
    final snapshot = Prefs().userPrompts;
    try {
      final applied = await _contributions.apply(manifest);
      final newIds = applied.map((entry) => entry.id).toSet();
      final stale =
          record.applied.where((entry) => !newIds.contains(entry.id)).toList();
      await _contributions.remove(stale);
      final updated = record.copyWith(
        status: PluginStatus.enabled,
        applied: List.unmodifiable(applied),
        clearLastError: true,
      );
      await Prefs().savePluginState(Prefs().pluginState.upsert(updated));
      _upsertMemory(updated);
      notifyListeners();
    } catch (_) {
      Prefs().userPrompts = snapshot;
      rethrow;
    }
  }

  Future<void> disable(String id) async {
    _ensureUsable();
    final record = _require(id);
    if (!record.isUsable) {
      throw PluginInstallError(PluginErrorCode.pluginUnavailable,
          'This plugin is ${record.status.name}; uninstall it instead.');
    }
    if (record.status == PluginStatus.disabled) return;
    await _contributions.remove(record.applied);
    final updated =
        record.copyWith(status: PluginStatus.disabled, applied: const []);
    await Prefs().savePluginState(Prefs().pluginState.upsert(updated));
    _upsertMemory(updated);
    notifyListeners();
  }

  Future<void> uninstall(String id) async {
    _ensureUsable();
    final record = _require(id);
    await _contributions.remove(record.applied);
    await Prefs().removePluginData(id);
    _plugins = _plugins.where((plugin) => plugin.id != id).toList();
    _manifests.remove(id);
    _manifestTexts.remove(id);
    notifyListeners();

    // File deletion is best-effort: the registry entry is already gone, so a
    // locked directory cannot leave the plugin half-installed.
    try {
      final directory = _paths.pluginDir(id);
      if (await directory.exists()) {
        final trashed = await _moveToTrash(directory, id);
        await _deleteQuietly(trashed);
      }
    } catch (error) {
      AnxLog.warning('Could not delete files of $id: ${describeError(error)}');
    }
  }

  PluginRecord _require(String id) {
    final record = byId(id);
    if (record == null) {
      throw PluginInstallError(
          PluginErrorCode.notInstalled, 'Plugin $id is not installed.');
    }
    return record;
  }

  void _ensureUsable() {
    if (!_compiledIn) {
      throw PluginInstallError(
          PluginErrorCode.internal, 'Plugins are disabled in this build.');
    }
    if (_disposed) {
      throw PluginInstallError(
          PluginErrorCode.internal, 'Plugin host is disposed.');
    }
  }

  void _upsertMemory(PluginRecord record) {
    final next = <PluginRecord>[];
    var replaced = false;
    for (final plugin in _plugins) {
      if (plugin.id == record.id) {
        next.add(record);
        replaced = true;
      } else {
        next.add(plugin);
      }
    }
    if (!replaced) next.add(record);
    _plugins = next;
  }

  Future<void> _removeContributions(PluginRecord record) async {
    try {
      await _contributions.remove(record.applied);
    } catch (error) {
      AnxLog.warning(
          'Could not remove contributions of ${record.id}: ${describeError(error)}');
    }
  }

  /// Moves the staged package into place, returning the previous directory if
  /// this was a replacement (it is deleted after the state is committed).
  Future<Directory?> _placeFiles(PluginPackage pkg) async {
    final id = pkg.manifest.id;
    final target = _paths.pluginDir(id);
    Directory? previous;
    if (await target.exists()) {
      previous = await _moveToTrash(target, id);
    }
    try {
      await pkg.staging.rename(target.path);
      return previous;
    } catch (_) {
      if (previous != null) {
        try {
          await previous.rename(target.path);
        } catch (_) {
          // Best effort; the package stays in trash and the record is rolled back.
        }
      }
      rethrow;
    }
  }

  Future<void> _rollbackFiles(String id, Directory? previousFiles) async {
    final target = _paths.pluginDir(id);
    await _deleteQuietly(target);
    if (previousFiles != null) {
      try {
        await previousFiles.rename(target.path);
      } catch (_) {
        // Nothing else can be done here; uninstall still works on the record.
      }
    }
  }

  Future<Directory> _moveToTrash(Directory directory, String id) async {
    final destination = Directory(p.join(
        _paths.trash.path, '$id-${DateTime.now().microsecondsSinceEpoch}'));
    await _paths.trash.create(recursive: true);
    await directory.rename(destination.path);
    return destination;
  }

  Future<void> _deleteQuietly(Directory? directory) async {
    if (directory == null) return;
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (_) {
      // The startup sweep removes stale trash entries.
    }
  }

  static String _decodeUtf8(List<int> bytes) {
    try {
      return const Utf8Decoder(allowMalformed: false).convert(bytes);
    } on FormatException {
      throw const PluginInstallError(
          PluginErrorCode.invalidManifest, 'manifest.json must be UTF-8.');
    }
  }

  /// Truncated, prompt-free error text suitable for the diagnostics UI.
  static String describeError(Object error) {
    final message = error is PluginInstallError
        ? '${error.code.name}: ${error.message}'
        : error.toString();
    return message.length <= 500 ? message : '${message.substring(0, 500)}…';
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}

class _Reconciled {
  const _Reconciled({required this.record, required this.changed});

  final PluginRecord record;
  final bool changed;
}

class _LoadedManifest {
  const _LoadedManifest(this.manifest, this.text);

  final PluginManifest manifest;
  final String text;
}
