import 'package:anx_reader/models/plugin_manifest.dart';
import 'package:anx_reader/models/plugin_state.dart';

/// One contribution type. The host never switches on `kind`; it looks the
/// handler up in [PluginContributionRegistry] (decision D9), so new types are
/// added by writing a handler and registering it.
abstract class PluginContributionHandler {
  String get kind;

  /// Capabilities the manifest must declare before this handler runs.
  Set<String> get requiredCapabilities;

  /// Validates every contribution of this kind before anything is written.
  /// Throws [PluginInstallError].
  void validate(
      PluginManifest manifest, List<PluginContribution> contributions);

  /// Materialises the contributions and returns the records used by the
  /// uninstall hash guard.
  Future<List<AppliedContribution>> apply(
      PluginManifest manifest, List<PluginContribution> contributions);

  /// Removes previously materialised contributions. Implementations keep
  /// user-edited values (renaming them instead of deleting).
  Future<void> remove(List<AppliedContribution> applied);
}

class PluginContributionRegistry {
  PluginContributionRegistry(Iterable<PluginContributionHandler> handlers)
      : _handlers = {
          for (final handler in handlers) handler.kind: handler,
        } {
    final duplicates = handlers
        .map((handler) => handler.kind)
        .where((kind) => handlers.where((h) => h.kind == kind).length > 1)
        .toSet();
    if (duplicates.isNotEmpty) {
      throw ArgumentError(
          'Duplicate plugin contribution handlers: ${duplicates.join(', ')}');
    }
  }

  final Map<String, PluginContributionHandler> _handlers;

  Iterable<String> get kinds => _handlers.keys;

  PluginContributionHandler? forKind(String kind) => _handlers[kind];
}
