import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:anx_reader/utils/get_path/get_base_path.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OCR/reflow appearance only; never writes BookStyle or original-page state.
class DocumentTextStyle {
  const DocumentTextStyle(
      {this.size = 20,
      this.height = 1.6,
      this.weight = 1,
      this.spacing = 0,
      this.margin = 20,
      this.verticalMargin = 16,
      this.paragraphSpacing = 1,
      this.font = '',
      this.serif = false,
      this.justify = false});
  final double size,
      height,
      weight,
      spacing,
      margin,
      verticalMargin,
      paragraphSpacing;
  final String font;
  static final _fonts = <String, Future<void>>{};
  Future<void> loadFont() async {
    if (font.isEmpty) return;
    await (_fonts[font] ??= (() async {
      try {
        final data = await File('${getFontDir().path}/$font').readAsBytes();
        final loader = FontLoader(font)
          ..addFont(Future.value(ByteData.sublistView(data)));
        await loader.load();
      } catch (_) {
        _fonts.remove(font);
        rethrow;
      }
    })());
  }

  final bool serif, justify;
  TextStyle get textStyle => TextStyle(
      fontSize: size,
      height: height,
      letterSpacing: spacing,
      fontFamily: font.isNotEmpty ? font : (serif ? 'SourceHanSerif' : null),
      fontWeight:
          FontWeight.values[((weight * 400 / 100).round() - 1).clamp(0, 8)]);
  TextAlign get alignment => justify ? TextAlign.justify : TextAlign.start;
  TextSpan buildTextSpan(String text) {
    final children = <InlineSpan>[];
    var start = 0;
    for (final gap in RegExp(r'\n\n').allMatches(text)) {
      children.add(TextSpan(text: text.substring(start, gap.start + 1)));
      children.add(TextSpan(
          text: '\n',
          style: TextStyle(
              height: paragraphSpacing == 0 ? .01 : paragraphSpacing)));
      start = gap.end;
    }
    children.add(TextSpan(text: text.substring(start)));
    return TextSpan(style: textStyle, children: children);
  }

  Map<String, dynamic> toJson() => {
        'size': size,
        'height': height,
        'weight': weight,
        'spacing': spacing,
        'margin': margin,
        'verticalMargin': verticalMargin,
        'paragraphSpacing': paragraphSpacing,
        'font': font,
        'serif': serif,
        'justify': justify
      };
  factory DocumentTextStyle.fromJson(dynamic value) {
    final v = value is Map ? value : const {};
    double number(String key, double fallback, double min, double max) {
      final n = v[key];
      return n is num && n.isFinite ? n.toDouble().clamp(min, max) : fallback;
    }

    return DocumentTextStyle(
        size: number('size', 20, 14, 40),
        height: number('height', 1.6, 1.2, 2.4),
        weight: number('weight', 1, .5, 2),
        spacing: number('spacing', 0, 0, 6),
        margin: number('margin', 20, 0, 60),
        verticalMargin: number('verticalMargin', 16, 0, 80),
        paragraphSpacing: number('paragraphSpacing', 1, 0, 3),
        font: v['font'] is String &&
                RegExp(r'^[^/\\]+\.(ttf|otf)$', caseSensitive: false)
                    .hasMatch(v['font'])
            ? v['font']
            : '',
        serif: v['serif'] == true,
        justify: v['justify'] == true);
  }
  DocumentTextStyle withValue(String key, Object value) =>
      DocumentTextStyle.fromJson({...toJson(), key: value});
}

class DocumentTextStyleStore {
  DocumentTextStyleStore(this.prefs);
  final SharedPreferences prefs;
  static const key = 'documentTextStyles';
  static Future<void> _writes = Future.value();
  Map<String, dynamic> _read() {
    try {
      final v = jsonDecode(prefs.getString(key) ?? '{}');
      return v is Map ? Map<String, dynamic>.from(v) : {};
    } catch (_) {
      return {};
    }
  }

  DocumentTextStyle read(String book) =>
      DocumentTextStyle.fromJson(_read()[book]);
  Future<void> save(String book, DocumentTextStyle style) {
    if (book.isEmpty) throw ArgumentError('Missing book identity');
    final operation = _writes.then((_) async {
      final previous = prefs.getString(key);
      try {
        if (!await prefs.setString(
            key, jsonEncode({..._read(), book: style.toJson()}))) {
          throw StateError('Could not save OCR style');
        }
      } catch (_) {
        // SharedPreferences updates its in-memory cache before platform I/O.
        try {
          if (previous == null) {
            await prefs.remove(key);
          } else {
            await prefs.setString(key, previous);
          }
        } catch (_) {}
        rethrow;
      }
    });
    _writes = operation.catchError((_) {});
    return operation;
  }
}
