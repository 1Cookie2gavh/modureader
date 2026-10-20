import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'weread_api.dart';

/// A binding is a generation: changing/unlinking a book invalidates all old
/// sections, including responses arriving later and old snapshots on other devices.
class WereadData {
  static const maxBytes = 2 * 1024 * 1024;
  static final _stampPattern = RegExp(r'^\d{20}:[a-f0-9]{32}$');
  static bool _validStamp(Object? value) {
    if (value is! String || !_stampPattern.hasMatch(value)) return false;
    final time = int.tryParse(value.split(':').first);
    return time != null && time > 0 && time < 8640000000000000;
  }

  static const sections = {'info', 'reviews', 'highlights'};
  static Map<String, dynamic> empty() =>
      {'version': 1, 'binding': null, 'sections': <String, dynamic>{}};

  static String stamp(Iterable<String> previous) {
    var time = DateTime.now().toUtc().microsecondsSinceEpoch;
    for (final value in previous) {
      time = max(time, int.parse(value.split(':').first) + 1);
    }
    final random = Random.secure();
    final salt = List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    return '${time.toString().padLeft(20, '0')}:$salt';
  }

  static String? bookId(Map<String, dynamic> data) =>
      wereadMap(data['binding'])['bookId'] as String?;
  static String? revision(Map<String, dynamic> data) =>
      wereadMap(data['binding'])['stamp'] as String?;
  static Map<String, dynamic> section(Map<String, dynamic> data, String name) =>
      wereadMap(wereadMap(data['sections'])[name]);
  static Map<String, dynamic> content(Map<String, dynamic> data, String name) =>
      wereadMap(section(data, name)['data']);
  static DateTime updated(Map<String, dynamic> section) =>
      DateTime.fromMicrosecondsSinceEpoch(
          int.parse((section['stamp'] as String).split(':').first),
          isUtc: true);

  static Map<String, dynamic> normalize(Object? raw) {
    if (raw is! Map<String, dynamic> ||
        raw['version'] != 1 ||
        utf8.encode(jsonEncode(raw)).length > maxBytes) {
      throw const FormatException('Invalid WeRead snapshot');
    }
    final binding = raw['binding'];
    if (binding == null) return empty();
    if (binding is! Map<String, dynamic> || !_validStamp(binding['stamp'])) {
      throw const FormatException('Invalid WeRead binding');
    }
    final id = binding['bookId'];
    if (id != null && (id is! String || id.isEmpty || id.length > 200)) {
      throw const FormatException('Invalid WeRead book');
    }
    final result = <String, dynamic>{
      'version': 1,
      'binding': {'bookId': id, 'stamp': binding['stamp']},
      'sections': <String, dynamic>{},
    };
    if (id == null) return result;
    final items = wereadMap(raw['sections']);
    for (final name in sections) {
      if (items[name] == null) continue;
      final item = wereadMap(items[name]);
      if (!_validStamp(item['stamp'])) {
        throw const FormatException('Invalid WeRead section');
      }
      final data = wereadMap(item['data']);
      Map<String, dynamic> normalized;
      if (name == 'info') {
        normalized = wereadInfo(data);
        if (normalized['bookId'] != id) {
          throw const FormatException('WeRead source mismatch');
        }
      } else {
        if (data['items'] is! List || (data['items'] as List).length > 200) {
          throw const FormatException('Invalid WeRead entries');
        }
        normalized = {
          'items': [
            for (final rawItem in data['items'] as List)
              if (name == 'highlights')
                {
                  'text': wereadText(wereadMap(rawItem)['text']),
                  'count': wereadInt(wereadMap(rawItem)['count']),
                }
              else
                {
                  for (final key in ['id', 'content', 'author'])
                    key: wereadText(wereadMap(rawItem)[key]),
                  for (final key in ['idx', 'star', 'createTime'])
                    key: wereadInt(wereadMap(rawItem)[key]),
                },
          ],
          if (name == 'reviews') ...{
            'total': wereadInt(data['total']),
            'hasMore': data['hasMore'] == true,
            'synckey': wereadInt(data['synckey']),
            'maxIdx': wereadInt(data['maxIdx']),
          },
        };
      }
      (result['sections'] as Map)[name] = {
        'stamp': item['stamp'],
        'data': normalized,
      };
    }
    return result;
  }

  static Map<String, dynamic> merge(
      Map<String, dynamic> a, Map<String, dynamic> b) {
    a = normalize(a);
    b = normalize(b);
    final ar = revision(a) ?? '', br = revision(b) ?? '';
    if (ar != br) return ar.compareTo(br) > 0 ? a : b;
    // Same generation with differing identities is invalid, not a remapping.
    if (bookId(a) != bookId(b)) {
      throw const FormatException('Conflicting WeRead binding');
    }
    for (final name in sections) {
      final left = section(a, name), right = section(b, name);
      final comparison =
          '${left['stamp'] ?? ''}'.compareTo('${right['stamp'] ?? ''}');
      if (comparison < 0 ||
          (comparison == 0 &&
              jsonEncode(left).compareTo(jsonEncode(right)) < 0)) {
        (a['sections'] as Map)[name] = right;
      }
    }
    return normalize(a);
  }
}

class WereadStore {
  WereadStore(this.localBookKey, {this.directory});
  final String localBookKey;
  final Directory? directory;
  static final _locks = <String, Future<void>>{};

  Future<File> _file() async {
    final root = directory ??
        Directory(
            '${(await getApplicationSupportDirectory()).path}/weread-metadata');
    return File(
        '${root.path}/${sha256.convert(utf8.encode(localBookKey))}.json');
  }

  Future<Map<String, dynamic>> _read(File file) async {
    if (!await file.exists()) return WereadData.empty();
    if (await file.length() > WereadData.maxBytes) {
      throw const FormatException('WeRead cache too large');
    }
    return WereadData.normalize(jsonDecode(await file.readAsString()));
  }

  Future<Map<String, dynamic>> read() async {
    final file = await _file();
    await _locks[file.path];
    return _read(file);
  }

  Future<Map<String, dynamic>> _change(
      Map<String, dynamic> Function(Map<String, dynamic>) change) async {
    final file = await _file();
    final previous = _locks[file.path];
    final done = Completer<void>();
    _locks[file.path] = done.future;
    await previous;
    try {
      final data = WereadData.normalize(change(await _read(file)));
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.part');
      await temp.writeAsString(jsonEncode(data), flush: true);
      await temp.rename(file.path);
      return data;
    } finally {
      done.complete();
      if (identical(_locks[file.path], done.future)) _locks.remove(file.path);
    }
  }

  Future<Map<String, dynamic>> bind(Map<String, dynamic>? info) =>
      _change((old) {
        final stamp = WereadData.stamp([
          if (WereadData.revision(old) case final String s) s,
        ]);
        return {
          'version': 1,
          'binding': {'bookId': info?['bookId'], 'stamp': stamp},
          'sections': {
            if (info != null)
              'info': {'stamp': stamp, 'data': wereadInfo(info)},
          },
        };
      });

  Future<Map<String, dynamic>> saveSection(
          String expectedRevision, String name, Map<String, dynamic> content) =>
      _change((data) {
        if (!WereadData.sections.contains(name)) {
          throw ArgumentError.value(name);
        }
        if (WereadData.revision(data) != expectedRevision) return data;
        final old = WereadData.section(data, name);
        (data['sections'] as Map)[name] = {
          'stamp': WereadData.stamp([
            expectedRevision,
            if (old['stamp'] case final String s) s,
          ]),
          'data': content,
        };
        return data;
      });

  Future<Map<String, dynamic>> merge(Map<String, dynamic> incoming) =>
      _change((local) => WereadData.merge(local, incoming));
}
