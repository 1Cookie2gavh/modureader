/// Placeholder for the P4 WebView script host.
///
/// P1a never executes package code. Keeping the interface here means the host
/// and manifest model do not need to change when a real runtime is plugged in.
enum ScriptRuntimeKind { none, webview }

abstract class ScriptRuntime {
  ScriptRuntimeKind get kind;

  /// False when the current platform cannot provide the runtime (for example
  /// HarmonyOS without the overlay host). The UI degrades the feature instead
  /// of disabling it by platform name.
  bool get isAvailable;

  Future<void> initialize();

  Future<void> dispose();
}

class NoopScriptRuntime implements ScriptRuntime {
  const NoopScriptRuntime();

  @override
  ScriptRuntimeKind get kind => ScriptRuntimeKind.none;

  @override
  bool get isAvailable => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}
}
