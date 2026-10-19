import 'dart:ui' show TextRange;

import 'models/tts_sentence.dart';
import 'tts_pipeline.dart';

/// A page-local speech cursor. Prefetch can inspect it but cannot advance it.
class TtsPageSource {
  TtsPageSource(String text,
      {required this.chapter, this.onPosition, this.onHighlight}) {
    var offset = 0;
    for (final sentence in TtsPipeline(text).sentences) {
      // Bound unpunctuated OCR text for system engines and online providers.
      final runes = sentence.runes.toList();
      for (var start = 0; start < runes.length; start += 500) {
        final part = String.fromCharCodes(runes.skip(start).take(500));
        final position = text.indexOf(part, offset);
        _offsets.add(position);
        offset = position + part.length;
        _sentences.add(TtsSentence(
            text: part,
            endsParagraph: RegExp(r'^(?:[ \t]*\n|\s*$)')
                .hasMatch(text.substring(offset))));
      }
    }
  }

  final String chapter;
  final void Function(int offset)? onPosition;
  final void Function(TextRange? range)? onHighlight;
  final _sentences = <TtsSentence>[];
  final _offsets = <int>[];
  int _index = 0;
  bool _valid = true;
  bool get valid => _valid && _sentences.isNotEmpty;
  bool get atEnd => _index >= _sentences.length;

  void invalidate() {
    _valid = false;
    clearHighlight();
  }

  void clearHighlight() => onHighlight?.call(null);
  void rewind() => _index = 0;

  String currentText() {
    if (!valid) return '';
    if (_index >= _sentences.length) rewind();
    return _current();
  }

  String nextText() {
    if (!valid) return '';
    if (_index < _sentences.length) _index++;
    return _current();
  }

  String previousText() {
    if (!valid) return '';
    if (_index > 0) _index--;
    return _current();
  }

  String _current() {
    if (_index >= _sentences.length) {
      clearHighlight();
      return '';
    }
    showCurrent();
    return _sentences[_index].text;
  }

  void showCurrent() {
    if (valid && _index < _offsets.length) {
      final start = _offsets[_index];
      onHighlight?.call(
          TextRange(start: start, end: start + _sentences[_index].text.length));
      onPosition?.call(start);
    }
  }

  List<TtsSentence> collect(int count) => valid
      ? _sentences.skip(_index).take(count).toList(growable: false)
      : const [];
}
