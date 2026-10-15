import 'document_text_geometry.dart';

/// Keep source blocks/indents when line geometry is available. Never reorder or
/// discard uncertain headers, footers or columns. AI drafts retain raw text.
String reflowDocumentText(String text,
    {List<DocumentTextRegion> regions = const [],
    int layoutVersion = 4,
    void Function(int rawStart, int rawEnd, int start, int end)? mapLine}) {
  final structure = _sourceLines(text, regions, legacy: layoutVersion < 4);
  final paragraphs = <String>[];
  var current = '';
  var rawOffset = 0, outputLength = 0;
  final lines = <(int, int, int, int)>[];
  void flush() {
    if (current.isNotEmpty) {
      if (paragraphs.isNotEmpty) outputLength += 2;
      for (final line in lines) {
        mapLine?.call(line.$1, line.$2, outputLength + line.$3,
            outputLength + line.$4.clamp(0, current.length));
      }
      paragraphs.add(current);
      outputLength += current.length;
    }
    current = '';
    lines.clear();
  }

  for (final raw in text.split('\n')) {
    final line = raw.trim();
    final rawStart = rawOffset + raw.length - raw.trimLeft().length;
    rawOffset += raw.length + 1;
    if (line.isEmpty) {
      flush();
      continue;
    }
    final layout = structure[rawStart];
    if (current.isNotEmpty &&
        (layout?.$1 ??
            ((layoutVersion < 4 && RegExp(r'[。！？.!?：:]$').hasMatch(current)) ||
                RegExp(r'^\s{2,}').hasMatch(raw)))) {
      flush();
    }
    if (current.isEmpty &&
        (layout?.$2 == true ||
            (layout == null &&
                layoutVersion >= 4 &&
                RegExp(r'^\s{2,}').hasMatch(raw)))) {
      current = '\u3000\u3000';
    }
    if (current.isNotEmpty) {
      if (RegExp(r'[A-Za-z]-$').hasMatch(current) &&
          RegExp(r'^[a-z]').hasMatch(line)) {
        current = current.substring(0, current.length - 1);
        final previous = lines.last;
        lines[lines.length - 1] =
            (previous.$1, previous.$2, previous.$3, previous.$4 - 1);
      } else if ((RegExp(r'[A-Za-z0-9,;]$').hasMatch(current) ||
              (layoutVersion >= 4 &&
                  RegExp(r'''[A-Za-z0-9][.!?:]["')\]]?$''')
                      .hasMatch(current))) &&
          RegExp(r'^[A-Za-z0-9]').hasMatch(line)) {
        current += ' ';
      }
    }
    lines.add((
      rawStart,
      rawStart + line.length,
      current.length,
      current.length + line.length
    ));
    current += line;
  }
  flush();
  return paragraphs.join('\n\n');
}

Map<int, (bool, bool)> _sourceLines(
    String text, List<DocumentTextRegion> regions,
    {required bool legacy}) {
  if (regions.isEmpty) return {};
  final lines = <(int, String, DocumentImageRect)>[];
  var offset = 0;
  final ordered = [...regions]..sort((a, b) => a.start.compareTo(b.start));
  var cursor = 0;
  for (final raw in text.split('\n')) {
    final start = offset + raw.length - raw.trimLeft().length;
    final end = offset + raw.trimRight().length;
    offset += raw.length + 1;
    while (cursor < ordered.length && ordered[cursor].end <= start) {
      cursor++;
    }
    final boxes = <DocumentImageRect>[];
    for (var i = cursor; i < ordered.length && ordered[i].start < end; i++) {
      boxes.add(ordered[i].rect);
    }
    if (end <= start || boxes.isEmpty) continue;
    final left = boxes.map((r) => r.x).reduce((a, b) => a < b ? a : b);
    final top = boxes.map((r) => r.y).reduce((a, b) => a < b ? a : b);
    final right =
        boxes.map((r) => r.x + r.width).reduce((a, b) => a > b ? a : b);
    final bottom =
        boxes.map((r) => r.y + r.height).reduce((a, b) => a > b ? a : b);
    lines.add((
      start,
      raw.trim(),
      DocumentImageRect(left, top, right - left, bottom - top)
    ));
  }
  if (lines.length < 2) return {};
  if (!legacy) return _paragraphLines(lines);
  // Keep v1-v3 text/offsets byte-for-byte stable for existing annotations.
  double median(List<double> values) {
    values.sort();
    return values[values.length ~/ 2];
  }

  final left = lines.map((l) => l.$3.x).reduce((a, b) => a < b ? a : b);
  final right =
      lines.map((l) => l.$3.x + l.$3.width).reduce((a, b) => a > b ? a : b);
  final height = median(lines.map((l) => l.$3.height).toList());
  final character =
      median(lines.map((l) => l.$3.width / l.$2.runes.length).toList());
  final result = <int, (bool, bool)>{};
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i], box = line.$3;
    final indent =
        box.x - left > character * .8 && box.x - left < character * 4.5;
    var boundary = i == 0 || indent;
    if (i > 0) {
      final previous = lines[i - 1], p = previous.$3;
      final hardWrap = p.x + p.width < right - character * 2.5 &&
          !RegExp(r'[A-Za-z]-$').hasMatch(previous.$2);
      // shortcut: geometry infers printed blocks, not table/poetry semantics;
      // ambiguous short lines stay separate instead of guessing away content.
      boundary = boundary ||
          hardWrap ||
          box.y - p.y > height * 2 ||
          box.y <= p.y ||
          (box.height - p.height).abs() > height * .35 ||
          text
              .substring(previous.$1 + previous.$2.length, line.$1)
              .contains('\n\n');
    }
    result[line.$1] = (boundary, indent);
  }
  return result;
}

Map<int, (bool, bool)> _paragraphLines(
    List<(int, String, DocumentImageRect)> lines) {
  bool sameRow(
      (int, String, DocumentImageRect) a, (int, String, DocumentImageRect) b) {
    final p = a.$3, box = b.$3;
    final height = p.height < box.height ? p.height : box.height;
    final space = box.x - p.x - p.width;
    return (box.y + box.height / 2 - p.y - p.height / 2).abs() < height * .5 &&
        space >= -p.width / a.$2.runes.length &&
        space < p.width / a.$2.runes.length * 3;
  }

  double quantile(List<double> values, double q) {
    values.sort();
    return values[((values.length - 1) * q).round()];
  }

  // Measure each contiguous column separately; never reorder source text.
  final groups = <List<(int, String, DocumentImageRect)>>[];
  for (final line in lines) {
    if (groups.isEmpty) {
      groups.add([line]);
      continue;
    }
    final previous = groups.last.last.$3, box = line.$3;
    final disjoint =
        box.x >= previous.x + previous.width || previous.x >= box.x + box.width;
    if (box.y < previous.y - previous.height * .5 ||
        (disjoint && !sameRow(groups.last.last, line))) {
      groups.add([line]);
    } else {
      groups.last.add(line);
    }
  }

  final result = <int, (bool, bool)>{};
  for (final group in groups) {
    final widest = group.map((l) => l.$3.width).reduce((a, b) => a > b ? a : b);
    final body = group.where((l) => l.$3.width >= widest * .65).toList();
    final left = quantile(body.map((l) => l.$3.x).toList(), .2);
    final right = quantile(body.map((l) => l.$3.x + l.$3.width).toList(), .8);
    final height = quantile(body.map((l) => l.$3.height).toList(), .5);
    final character =
        quantile(body.map((l) => l.$3.width / l.$2.runes.length).toList(), .5);
    final advances = <double>[];
    for (var i = 1; i < group.length; i++) {
      final delta = group[i].$3.y - group[i - 1].$3.y;
      if (delta > height * .5) advances.add(delta);
    }
    final pitch = advances.isEmpty ? height * 1.5 : quantile(advances, .25);
    for (var i = 0; i < group.length; i++) {
      final line = group[i], box = line.$3;
      final previous = i == 0 ? null : group[i - 1];
      final p = previous?.$3;
      final continuation = previous != null && sameRow(previous, line);
      final gap = p != null &&
          box.y - p.y > pitch * 1.45 &&
          box.y - p.y - pitch > height * .45;
      final indent =
          box.x - left > character * 1.3 && box.x - left < character * 4.5;
      final newIndent = indent && (p == null || gap || box.x - p.x > character);
      final cjk =
          previous != null && RegExp(r'[\u3400-\u9fff]').hasMatch(previous.$2);
      final tailSpace = character * (cjk ? 2.5 : 6);
      final shortLine = p != null &&
          right - p.x - p.width > tailSpace &&
          right - p.x - p.width > (right - left) * (cjk ? .12 : .18) &&
          !RegExp(r'[A-Za-z]-$').hasMatch(previous!.$2);
      result[line.$1] = (
        i == 0 || (!continuation && (gap || newIndent || shortLine)),
        indent
      );
    }
  }
  return result;
}
