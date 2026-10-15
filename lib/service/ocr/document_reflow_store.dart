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
      List<DocumentTextRegion> rawRegions = const []})
      : rawRegions = DocumentTextResult(rawText, rawRegions).regions {
    final mapped = <DocumentTextRegion>[];
    final ordered = [...this.rawRegions]
      ..sort((a, b) => a.start.compareTo(b.start));
    var cursor = 0;
    text = reflowDocumentText(rawText,
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
          rawRegions: geometry);
      return value.revision == data['revision'] && value.text == data['text']
          ? value
          : null;
    } catch (_) {
      return null;
    }
  }
}

/// Page text, not preferences. Book identity and OCR model revision are part of
/// the cache key. Immutable text revisions keep older notes anchored safely.
class DocumentReflowStore {
  DocumentReflowStore(this.bookKey, {this.directory});
  final String bookKey;
  final Directory? directory;
  Future<Directory> _root() async => Directory(
      '${(directory ?? await getApplicationSupportDirectory()).path}/document-reflow-v1/${sha256.convert(utf8.encode(bookKey))}');
  String _index(int page, String profile) =>
      '$page-${sha256.convert(utf8.encode(profile))}.json';
  Future<DocumentReflowPage?> _read(String name) async {
    try {
      final file = File('${(await _root()).path}/$name');
      if (!await file.exists() || await file.length() > 12000000) return null;
      return DocumentReflowPage.decode(jsonDecode(await file.readAsString()));
    } catch (_) {
      return null;
    }
  }

  Future<DocumentReflowPage?> read(int page, String profile) async {
    final result = await _read(_index(page, profile));
    if (result?.page != page) return null;
    if (result!.layoutVersion < 4) {
      // Save both revisions before replacing the current index; old notes keep
      // their exact text and source-image coordinates without another OCR run.
      final updated = DocumentReflowPage(
          page: page,
          ocr: result.ocr,
          rawText: result.rawText,
          rawRegions: result.rawRegions);
      await save(result, profile);
      await save(updated, profile);
      return updated;
    }
    return result;
  }

  Future<DocumentReflowPage?> readAnchor(DocumentReflowAnchor anchor) async {
    final result = await _read('${anchor.page}-${anchor.revision}.json');
    return result != null && anchor.matches(result) ? result : null;
  }

  Future<void> save(DocumentReflowPage value, String profile) async {
    if (bookKey.isEmpty ||
        value.text.isEmpty ||
        value.rawText.length > 1000000) {
      throw const FormatException('Invalid reflow page');
    }
    final root = await _root();
    await root.create(recursive: true);
    for (final name in [
      '${value.page}-${value.revision}.json',
      _index(value.page, profile)
    ]) {
      final file = File('${root.path}/$name');
      // Flush then rename; an interrupted OCR/cache write must not replace a
      // valid text revision with a partial JSON document.
      final temporary =
          File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.part');
      try {
        await temporary.writeAsString(jsonEncode(value.toJson()), flush: true);
        await temporary.rename(file.path);
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    }
  }
}
