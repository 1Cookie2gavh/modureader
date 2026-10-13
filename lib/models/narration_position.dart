import 'dart:convert';

/// Exact speech range, independent of device page size. No book text or audio.
class NarrationPosition {
  const NarrationPosition(this.cfi, this.state);
  final String cfi;
  final String state;
  bool get canResume => state == 'playing' || state == 'paused';
  String encode() => jsonEncode({'cfi': cfi, 'state': state});

  static NarrationPosition? decode(Object? source) {
    if (source == null) return null;
    if (source is! String || source.length > 32768) {
      throw const FormatException('Invalid narration position');
    }
    final value = jsonDecode(source);
    if (value is! Map ||
        value['cfi'] is! String ||
        !(value['cfi'] as String).startsWith('epubcfi(') ||
        !(value['cfi'] as String).endsWith(')') ||
        !const ['playing', 'paused', 'stopped'].contains(value['state'])) {
      throw const FormatException('Invalid narration position');
    }
    return NarrationPosition(value['cfi'], value['state']);
  }
}
