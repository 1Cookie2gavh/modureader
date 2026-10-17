import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'document_text_reflow.dart';
import 'document_text_geometry.dart';

/// Not an EPUB CFI: never pass these positions to the original PDF renderer.
class DocumentReflowAnchor {
  const DocumentReflowAnchor(
      this.page, this.ocr, this.revision, this.start, this.end,
      {this.rects = const [], this.original = false});
  static const prefix = 'modu-reflow:';
  final int page, start, end;
  final bool ocr;
  final String revision;
  final List<DocumentImageRect> rects;
  final bool original;
  String encode() {
    final base = '$page:${ocr ? 1 : 0}:$revision:$start:$end';
    return rects.isEmpty
        ? '${prefix}v1:$base'
        : '${prefix}v2:$base:${base64Url.encode(utf8.encode(jsonEncode(rects.map((r) => r.toJson()).toList())))}';
  }

  String get originalReference =>
      '${prefix}source:${encode().substring(prefix.length)}';
  static DocumentReflowAnchor? parse(String value) {
    if (value.length > 1000000) return null;
    final original = value.startsWith('${prefix}source:');
    if (original) value = prefix + value.substring('${prefix}source:'.length);
    final match = RegExp(
            r'^modu-reflow:v([12]):(\d+):([01]):([a-f0-9]{64}):(\d+):(\d+)(?::([A-Za-z0-9_=-]+))?$')
        .firstMatch(value);
    if (match == null) return null;
    final page = int.tryParse(match[2]!),
        start = int.tryParse(match[5]!),
        end = int.tryParse(match[6]!);
    if (page == null ||
        start == null ||
        end == null ||
        page > 1000000 ||
        start < 0 ||
        end <= start ||
        end > 1000000) {
      return null;
    }
    final rects = <DocumentImageRect>[];
    if (match[1] == '1' && match[7] != null) return null;
    if (match[1] == '2') {
      try {
        final raw = jsonDecode(utf8.decode(base64Url.decode(match[7]!)));
        if (raw is! List || raw.isEmpty || raw.length > 4096) return null;
        for (final value in raw) {
          final rect = DocumentImageRect.decode(value);
          if (rect == null) return null;
          rects.add(rect);
        }
      } catch (_) {
        return null;
      }
    }
    return DocumentReflowAnchor(page, match[3] == '1', match[4]!, start, end,
        rects: List.unmodifiable(rects), original: original);
  }

  bool matches(DocumentReflowPage value) =>
      page == value.page &&
      revision == value.revision &&
      end <= value.text.length;
}

class DocumentReflowPage {
  DocumentReflowPage(
      {required this.page,
      required this.ocr,
      required this.rawText,
      this.layoutVersion = 4,
      this.editedText,
      List<DocumentTextRegion> rawRegions = const []})
      : rawRegions = DocumentTextResult(rawText, rawRegions).regions {
    final mapped = <DocumentTextRegion>[];
    final ordered = [...this.rawRegions]
      ..sort((a, b) => a.start.compareTo(b.start));
    var cursor = 0;
    final originalText = reflowDocumentText(rawText,
        layoutVersion: layoutVersion,
        regions: layoutVersion >= 3 ? this.rawRegions : const [],
        mapLine: (rawStart, rawEnd, start, end) {
      while (cursor < ordered.length && ordered[cursor].end <= rawStart) {
        cursor++;
      }
      for (var i = cursor;
          i < ordered.length && ordered[i].start < rawEnd;
          i++) {
        final region = ordered[i];
        final a = region.start.clamp(rawStart, rawEnd);
        final b = region.end.clamp(rawStart, rawEnd);
        final mappedStart = (start + a - rawStart).clamp(start, end);
        final mappedEnd = (start + b - rawStart).clamp(start, end);
        if (mappedEnd > mappedStart) {
          mapped.add(DocumentTextRegion(mappedStart, mappedEnd, region.rect));
        }
      }
    });
    if (editedText != null) {
      if (editedText!.length > 1000000) {
        throw const FormatException('Edited page is too large');
      }
      // Only unchanged text keeps its image mapping; never guess coordinates for a correction.
      var prefix = 0, suffix = 0;
      while (prefix < originalText.length &&
          prefix < editedText!.length &&
          originalText.codeUnitAt(prefix) == editedText!.codeUnitAt(prefix)) {
        prefix++;
      }
      while (suffix < originalText.length - prefix &&
          suffix < editedText!.length - prefix &&
          originalText.codeUnitAt(originalText.length - suffix - 1) ==
              editedText!.codeUnitAt(editedText!.length - suffix - 1)) {
        suffix++;
      }
      final delta = editedText!.length - originalText.length;
      final unchanged = <DocumentTextRegion>[];
      for (final region in mapped) {
        if (region.end <= prefix) {
          unchanged.add(region);
        } else if (region.start >= originalText.length - suffix) {
          unchanged.add(DocumentTextRegion(
              region.start + delta, region.end + delta, region.rect));
        }
      }
      mapped
        ..clear()
        ..addAll(unchanged);
    }
    text = editedText ?? originalText;
    regions = List.unmodifiable(mapped);
    // Geometry is part of the immutable revision: identical OCR words can move.
    revision = sha256
        .convert(utf8.encode(rawRegions.isEmpty
            ? text
            : jsonEncode([text, rawRegions.map((r) => r.toJson()).toList()])))
        .toString();
  }
  final int page;
  final bool ocr;
  final int layoutVersion;
  final String rawText;
  final String? editedText;
  late final String text, revision;
  final List<DocumentTextRegion> rawRegions;
  late final List<DocumentTextRegion> regions;
  DocumentReflowAnchor anchor(int start, int end) =>
      DocumentReflowAnchor(page, ocr, revision, start, end,
          rects: List.unmodifiable(regions
              .where((r) => r.start < end && r.end > start)
              .map((r) => r.rect)));
  Map<String, Object> toJson() => {
        'version':
            layoutVersion >= 3 ? layoutVersion : (rawRegions.isEmpty ? 1 : 2),
        'page': page,
        'ocr': ocr,
        'rawText': rawText,
        'text': text,
        'revision': revision,
        if (editedText != null) 'editedText': editedText!,
        if (rawRegions.isNotEmpty)
          'regions': rawRegions.map((r) => r.toJson()).toList(),
      };
  static DocumentReflowPage? decode(dynamic data) {
    if (data is! Map ||
        ![1, 2, 3, 4].contains(data['version']) ||
        data['page'] is! int ||
        data['ocr'] is! bool ||
        data['rawText'] is! String) {
      return null;
    }
    final raw = data['rawText'] as String;
    if (raw.length > 1000000 || (data['page'] as int) < 0) return null;
    try {
      if (data['editedText'] != null && data['editedText'] is! String) {
        return null;
      }
      if (data['version'] == 2 && data['regions'] is! List) return null;
      final geometry = data['version'] != 1
          ? DocumentTextResult.decode({'text': raw, 'regions': data['regions']})
              .regions
          : const <DocumentTextRegion>[];
      final value = DocumentReflowPage(
          page: data['page'],
          ocr: data['ocr'],
          rawText: raw,
          layoutVersion: data['version'],
          editedText: data['editedText'],
          rawRegions: geometry);
      return value.revision == data['revision'] && value.text == data['text']
          ? value
          : null;
    } catch (_) {
      return null;
    }
  }
}

/// One durable book file, indexed by original page, including immutable note revisions.
class DocumentReflowStore {
  DocumentReflowStore(this.bookKey, {this.directory});
  final String bookKey;
  final Directory? directory;
  Future<Directory> _root() async => Directory(
      '${(directory ?? await getApplicationSupportDirectory()).path}/document-reflow-v1/${sha256.convert(utf8.encode(bookKey))}');
  static final _pending = <String, Future<void>>{};
  Future<T> _locked<T>(Future<T> Function(Directory) action) async {
    final root = await _root();
    final previous = _pending[root.path] ?? Future<void>.value();
    final done = Completer<void>();
    _pending[root.path] = done.future;
    await previous;
    try {
      return await action(root);
    } finally {
      done.complete();
      if (identical(_pending[root.path], done.future)) {
        _pending.remove(root.path);
      }
    }
  }

  Future<Map<String, dynamic>> _book(Directory root) async {
    final file = File('${root.path}/book.json');
    if (await file.exists()) {
      if (await file.length() > 256 * 1024 * 1024) {
        throw const FormatException('Saved OCR book is too large');
      }
      final data = jsonDecode(await file.readAsString());
      if (data is! Map<String, dynamic> ||
          data['version'] != 1 ||
          data['pages'] is! Map<String, dynamic> ||
          data['revisions'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid saved OCR book');
      }
      return data;
    }
    final data = <String, dynamic>{
      'version': 1,
      'pages': <String, dynamic>{},
      'revisions': <String, dynamic>{}
    };
    if (!await root.exists()) return data;
    // Import legacy profile caches once, retaining their files as recovery copies.
    final files = <(File, DateTime)>[];
    await for (final entry in root.list()) {
      if (entry is File &&
          RegExp(r'[/\\]\d+-[a-f0-9]{64}\.json$').hasMatch(entry.path)) {
        files.add((entry, await entry.lastModified()));
      }
    }
    files.sort((a, b) => a.$2.compareTo(b.$2));
    for (final entry in files) {
      try {
        if (await entry.$1.length() > 12000000) continue;
        final page = DocumentReflowPage.decode(
            jsonDecode(await entry.$1.readAsString()));
        if (page != null) _put(data, page);
      } on FormatException {
        continue;
      }
    }
    if ((data['pages'] as Map).isNotEmpty) await _write(root, data);
    return data;
  }

  void _put(Map<String, dynamic> data, DocumentReflowPage page) {
    final key = '${page.page}-${page.revision}';
    (data['revisions'] as Map)[key] = page.toJson();
    (data['pages'] as Map)['${page.page}'] = key;
  }

  DocumentReflowPage? _page(Map<String, dynamic> data, int number) {
    final key = (data['pages'] as Map)['$number'];
    if (key == null) return null;
    final page = DocumentReflowPage.decode((data['revisions'] as Map)[key]);
    if (page == null ||
        page.page != number ||
        key != '$number-${page.revision}') {
      throw const FormatException('Invalid saved OCR page');
    }
    return page;
  }

  Future<void> _write(Directory root, Map<String, dynamic> data) async {
    await root.create(recursive: true);
    final bytes = utf8.encode(jsonEncode(data));
    if (bytes.length > 256 * 1024 * 1024) {
      throw const FormatException('Saved OCR book is too large');
    }
    final file = File('${root.path}/book.json');
    final temporary =
        File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.part');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  // Profiles are deliberately ignored: mode/model/crop changes never discard a user's saved page.
  Future<DocumentReflowPage?> read(int page, String profile) =>
      _locked((root) async {
        final data = await _book(root);
        final result = _page(data, page);
        if (result != null &&
            result.layoutVersion < 4 &&
            result.editedText == null) {
          final updated = DocumentReflowPage(
              page: page,
              ocr: result.ocr,
              rawText: result.rawText,
              rawRegions: result.rawRegions);
          _put(data, updated);
          await _write(root, data);
          return updated;
        }
        return result;
      });

  Future<DocumentReflowPage?> readAnchor(DocumentReflowAnchor anchor) =>
      _locked((root) async {
        final data = await _book(root);
        final result = DocumentReflowPage.decode(
            (data['revisions'] as Map)['${anchor.page}-${anchor.revision}']);
        return result != null && anchor.matches(result) ? result : null;
      });

  Future<void> save(DocumentReflowPage value, String profile) =>
      _locked((root) async {
        if (bookKey.isEmpty ||
            value.text.trim().isEmpty ||
            value.text.length > 1000000 ||
            value.rawText.length > 1000000 ||
            value.page < 0 ||
            value.page > 1000000) {
          throw const FormatException('Invalid reflow page');
        }
        final data = await _book(root);
        _put(data, value);
        await _write(root, data);
      });

  Future<DocumentReflowPage> saveEdit(
          DocumentReflowPage original, String text) =>
      _locked((root) async {
        if (text.trim().isEmpty || text.length > 1000000) {
          throw const FormatException('Invalid edited page');
        }
        final data = await _book(root);
        if (_page(data, original.page)?.revision != original.revision) {
          throw StateError('Page changed; reopen before editing');
        }
        final edited = DocumentReflowPage(
            page: original.page,
            ocr: original.ocr,
            rawText: original.rawText,
            rawRegions: original.rawRegions,
            layoutVersion: original.layoutVersion,
            editedText: text);
        _put(data, edited);
        await _write(root, data);
        return edited;
      });

  Future<String> exportTxt() => _locked((root) async {
        final data = await _book(root);
        final numbers = (data['pages'] as Map)
            .keys
            .map((key) => int.parse(key as String))
            .toList()
          ..sort();
        const separator = '────────────────────';
        return numbers
            .map((number) =>
                '第${number + 1}页\n$separator\n${_page(data, number)!.text}\n$separator')
            .join('\n\n');
      });
}
