import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

/// Grow-only counters: one writer per installation, merged by maximum.
/// No text or credentials are stored in usage records.
class TranslationUsage {
  TranslationUsage(this.preferences);
  final SharedPreferences preferences;
  static const deviceKey = 'translationUsageDevice';
  static const countersKey = 'translationUsageCounters';
  static const quotaKey = 'translationUsageQuotas';
  static final changes = ValueNotifier<int>(0);

  static String account(String engine, Map<String, String> config) => sha256
      .convert(utf8.encode(
          '$engine:${(engine == 'baidu' ? config['baidu_appid'] ?? '' : config['microsoft_key'] ?? '').trim()}'))
      .toString();

  static String month([DateTime? now]) {
    final date = (now ?? DateTime.now()).toUtc();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String get device {
    final existing = preferences.getString(deviceKey);
    if (existing != null) return existing;
    final id = const Uuid().v4();
    preferences.setString(deviceKey, id);
    return id;
  }

  Map<String, dynamic> get counters => Map<String, dynamic>.from(
      jsonDecode(preferences.getString(countersKey) ?? '{}') as Map);

  Map<String, int> localCounters() =>
      Map<String, int>.from(counters[device] as Map? ?? {});

  Future<void> record(String account, int characters, {DateTime? now}) async {
    if (characters <= 0) return;
    final all = counters;
    final id = device;
    final local = Map<String, int>.from(all[id] as Map? ?? {});
    final key = '${month(now)}/$account';
    local[key] = (local[key] ?? 0) + characters;
    all[id] = local;
    await preferences.setString(countersKey, jsonEncode(all));
    changes.value++;
  }

  int used(String account, {DateTime? now}) {
    final key = '${month(now)}/$account';
    return counters.values.fold<int>(
        0, (sum, device) => sum + ((device as Map)[key] as int? ?? 0));
  }

  Future<void> merge(String deviceId, Map<String, Object?> incoming) async {
    if (!RegExp(r'^[a-zA-Z0-9-]{1,64}$').hasMatch(deviceId) ||
        incoming.length > 10000 ||
        incoming.entries.any((e) =>
            !RegExp(r'^\d{4}-(0[1-9]|1[0-2])/[a-f0-9]{64}$').hasMatch(e.key) ||
            e.value is! int ||
            (e.value as int) < 0 ||
            (e.value as int) > 9007199254740991)) {
      throw const FormatException('Invalid translation usage counters');
    }
    final all = counters;
    final local = Map<String, int>.from(all[deviceId] as Map? ?? {});
    for (final entry in incoming.entries) {
      local[entry.key] = max(local[entry.key] ?? 0, entry.value as int);
    }
    all[deviceId] = local;
    await preferences.setString(countersKey, jsonEncode(all));
    changes.value++;
  }

  int quota(String account, String engine) {
    try {
      final values = jsonDecode(preferences.getString(quotaKey) ?? '{}') as Map;
      final value = values[account];
      if (value is int && value > 0 && value <= 1000000000000) return value;
    } catch (_) {/* An invalid imported allowance must not break settings. */}
    return engine == 'baidu' ? 1000000 : 2000000;
  }

  Future<void> setQuota(String account, int value) async {
    if (value <= 0 || value > 1000000000000) throw ArgumentError.value(value);
    final values = jsonDecode(preferences.getString(quotaKey) ?? '{}') as Map;
    values[account] = value;
    await preferences.setString(quotaKey, jsonEncode(values));
  }
}
