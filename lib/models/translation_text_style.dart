import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:anx_reader/service/ocr/document_text_style.dart';
import 'package:anx_reader/service/book_player/reader_font_response.dart';

/// Presentation of translated output only, independent of API/cache identity.
class TranslationTextStyle {
  const TranslationTextStyle(
      {this.font = '', this.size = 0, this.bold = false, this.italic = false});
  final String font;
  final double size;
  final bool bold, italic;
  static bool validFont(Object? value) =>
      value is String &&
      (['', 'system', 'serif', 'sans-serif', 'monospace'].contains(value) ||
          RegExp(r'^[^/\\\x00]+\.(ttf|otf)$', caseSensitive: false)
              .hasMatch(value));
  factory TranslationTextStyle.decode(String value) {
    try {
      final v = jsonDecode(value) as Map;
      final size = v['size'];
      return TranslationTextStyle(
          font: validFont(v['font']) ? v['font'] as String : '',
          size: size is num && size.isFinite && size != 0
              ? size.toDouble().clamp(12, 48)
              : 0,
          bold: v['bold'] == true,
          italic: v['italic'] == true);
    } catch (_) {
      return const TranslationTextStyle();
    }
  }
  bool get imported =>
      font.isNotEmpty &&
      !['system', 'serif', 'sans-serif', 'monospace'].contains(font);
  String encode() =>
      jsonEncode({'font': font, 'size': size, 'bold': bold, 'italic': italic});
  TranslationTextStyle withValue(String key, Object value) =>
      TranslationTextStyle.decode(
          jsonEncode({...jsonDecode(encode()) as Map, key: value}));
  Future<void> loadFont() =>
      DocumentTextStyle(font: imported ? font : '').loadFont();
  TextStyle get textStyle => TextStyle(
      fontFamily: switch (font) {
        '' => null,
        'system' => '',
        'serif' => 'SourceHanSerif',
        _ => font
      },
      fontSize: size == 0 ? null : size,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal);
  Map<String, Object> webStyle(int port) => {
        'font': imported
            ? 'ModuTranslationOutput'
            : font == 'system'
                ? 'system-ui'
                : font,
        'fontUrl': imported ? readerFontUrl(font, port) : '',
        'size': size,
        'bold': bold,
        'italic': italic,
      };
}
