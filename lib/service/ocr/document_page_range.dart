/// Printer-style, one-based page numbers; returns unique zero-based pages.
List<int> parseDocumentPageRange(String value, int total) {
  final pages = <int>{};
  final normalized =
      value.replaceAll('，', ',').replaceAll(RegExp('[–—－]'), '-');
  for (final part in normalized.split(',')) {
    final match = RegExp(r'^\s*(\d+)\s*(?:-\s*(\d+)\s*)?$').firstMatch(part);
    if (match == null) throw const FormatException('Invalid page range');
    final start = int.tryParse(match[1]!);
    final end = int.tryParse(match[2] ?? match[1]!);
    if (start == null ||
        end == null ||
        start < 1 ||
        end < start ||
        end > total) {
      throw const FormatException('Page range outside document');
    }
    for (var page = start; page <= end; page++) {
      pages.add(page - 1);
    }
  }
  return pages.toList()..sort();
}
