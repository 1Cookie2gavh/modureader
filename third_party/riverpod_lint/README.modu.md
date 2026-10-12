# Riverpod lint compatibility

Upstream: `riverpod_lint` 3.1.9 and `riverpod_analyzer_utils` 1.0.0-dev.12
(https://github.com/rrousselGit/riverpod). Original MIT licenses are retained.

These are development-only analyzer plugins, loaded by `analysis_options.yaml`
in the analysis server's isolated dependency context. They do not upgrade the
application's Riverpod 2 runtime, generator or annotations.

The only behavior patch makes the optional Riverpod annotation `name` field
nullable when absent. Riverpod 2 has no such field; treating its absence as an
invalid annotation incorrectly reports every generated provider as unsupported.
Keep all lint rules active, including provider dependencies and context safety.

The old custom_lint/analyzer 7 combination cannot serialize dot-shorthand nodes
used by the Dart 3.13 / Flutter SDK. Use `flutter analyze --no-pub` or
`dart analyze`, not `dart run custom_lint`. Development requires Dart 3.13+.
