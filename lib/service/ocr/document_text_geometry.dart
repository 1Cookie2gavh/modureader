/// Coordinates are fractions of the uncropped source page, not screen pixels.
class DocumentImageRect {
  const DocumentImageRect(this.x, this.y, this.width, this.height);
  final double x, y, width, height;
  bool get valid =>
      [x, y, width, height].every((v) => v.isFinite) &&
      x >= 0 &&
      y >= 0 &&
      width > 0 &&
      height > 0 &&
      x + width <= 1.000001 &&
      y + height <= 1.000001;
  List<double> toJson() => [x, y, width, height];
  static DocumentImageRect? decode(dynamic value) {
    if (value is! List || value.length != 4 || value.any((v) => v is! num)) {
      return null;
    }
    final r = DocumentImageRect(
        (value[0] as num).toDouble(),
        (value[1] as num).toDouble(),
        (value[2] as num).toDouble(),
        (value[3] as num).toDouble());
    return r.valid ? r : null;
  }

  DocumentImageRect within(DocumentImageRect crop) => DocumentImageRect(
      crop.x + x * crop.width,
      crop.y + y * crop.height,
      width * crop.width,
      height * crop.height);
}

class DocumentTextRegion {
  const DocumentTextRegion(this.start, this.end, this.rect);
  final int start, end;
  final DocumentImageRect rect;
  Map<String, Object> toJson() =>
      {'start': start, 'end': end, 'rect': rect.toJson()};
  static DocumentTextRegion? decode(dynamic value, int length) {
    if (value is! Map || value['start'] is! int || value['end'] is! int) {
      return null;
    }
    final start = value['start'] as int, end = value['end'] as int;
    final rect = DocumentImageRect.decode(value['rect']);
    if (rect == null || start < 0 || end <= start || end > length) return null;
    return DocumentTextRegion(start, end, rect);
  }
}

class DocumentTextResult {
  DocumentTextResult(this.text, [List<DocumentTextRegion> regions = const []])
      : regions = List.unmodifiable(regions) {
    if (text.length > 1000000 ||
        regions.length > 4096 ||
        regions.any((r) =>
            r.start < 0 ||
            r.end <= r.start ||
            r.end > text.length ||
            !r.rect.valid)) {
      throw const FormatException('Invalid document text geometry');
    }
  }
  final String text;
  final List<DocumentTextRegion> regions;
  Map<String, Object> toJson() =>
      {'text': text, 'regions': regions.map((r) => r.toJson()).toList()};
  factory DocumentTextResult.decode(Map value) {
    final text = value['text'];
    final regions = value['regions'] ?? const [];
    if (text is! String || regions is! List || regions.length > 4096) {
      throw const FormatException('Invalid document text result');
    }
    return DocumentTextResult(
        text,
        regions.map((r) {
          final region = DocumentTextRegion.decode(r, text.length);
          if (region == null) {
            throw const FormatException('Invalid source region');
          }
          return region;
        }).toList());
  }
  DocumentTextResult within(DocumentImageRect crop) => DocumentTextResult(
      text,
      regions
          .map((r) => DocumentTextRegion(r.start, r.end, r.rect.within(crop)))
          .toList());
}
