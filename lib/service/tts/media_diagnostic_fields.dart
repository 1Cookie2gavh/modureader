/// Strict allowlist shared by the collector and shareable feedback log.
/// Never serialize notification extras, metadata values, tokens or errors.
Map<String, Object> safeMediaDiagnosticFields(Object? input) {
  if (input is! Map) return {};
  const numbers = {
    'sdk',
    'targetSdk',
    'elapsedMs',
    'state',
    'actions',
    'errorCode',
    'notificationCount',
    'notificationActions',
    'importance',
    'flags',
    'audioUsage',
    'audioContentType',
    'notificationFlags',
    'notificationPlayRequests',
    'sessionPlayCallbacks',
  };
  const booleans = {
    'playing',
    'notificationsEnabled',
    'notificationPermission',
    'powerSave',
    'backgroundRestricted',
    'notificationPresent',
    'tokenPresent',
    'ownSession',
    'mediaCategory',
    'mediaStyle',
    'channelPresent',
    'channelBlocked',
    'groupBlocked',
    'foreground',
    'ongoing',
    'statePresent',
    'canPlay',
    'canPause',
    'canToggle',
    'titlePresent',
    'subtitlePresent',
    'artPresent',
    'sessionPresent',
    'errorPresent',
    'compatActive',
  };
  const enums = {
    'source': {'dart', 'android'},
    'event': {
      'start',
      'snapshot',
      'state',
      'metadata',
      'destroyed',
      'error',
      'limit'
    },
    'processing': {
      'idle',
      'loading',
      'buffering',
      'ready',
      'completed',
      'error'
    },
  };
  final output = <String, Object>{};
  for (final entry in input.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String) continue;
    if (numbers.contains(key) && value is int && value.abs() <= (1 << 53)) {
      output[key] = value;
    } else if (booleans.contains(key) && value is bool) {
      output[key] = value;
    } else if (enums[key]?.contains(value) ?? false) {
      output[key] = value as String;
    } else if ({
          'controls',
          'systemActions',
          'compact',
          'semanticActions',
          'actionIcons',
          'actionIconTypes',
          'actionIconResources',
        }.contains(key) &&
        value is List) {
      output[key] = value
          .whereType<int>()
          .where((v) => v >= 0 && v <= 0x7fffffff)
          .take(32)
          .toList();
    } else if ({'actionIntents', 'actionIconPresent'}.contains(key) &&
        value is List) {
      output[key] = value.whereType<bool>().take(32).toList();
    }
  }
  return output;
}
