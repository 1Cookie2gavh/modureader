import 'package:flutter/foundation.dart';
import 'package:anx_reader/enums/translation_mode.dart';
import 'package:anx_reader/service/ocr/document_reflow_store.dart';
import 'reader_translation_session.dart';

/// Ephemeral translation of one saved source page, never an OCR cache revision.
class DocumentPageTranslation extends ChangeNotifier {
  final mode = ValueNotifier(TranslationModeEnum.off);
  final _session = ReaderTranslationSession();
  List<String> _original = [], _translated = [];
  String? _revision, _settings;
  int? _page;
  bool busy = false;

  String get text => List.generate(
      _translated.length,
      (i) => mode.value == TranslationModeEnum.bilingual
          ? '${_original[i]}\n\n${_translated[i]}'
          : _translated[i]).join('\n\n');

  Future<void> translate(DocumentReflowPage page, TranslationModeEnum display,
      {required String settings,
      required Future<String> Function(ReaderTranslationSession, int, String)
          request,
      bool force = false}) async {
    if (display == TranslationModeEnum.off ||
        display == TranslationModeEnum.originalOnly) {
      stop();
      return;
    }
    if (!force &&
        _revision == page.revision &&
        _page == page.page &&
        _settings == settings &&
        _translated.length == _original.length &&
        _translated.isNotEmpty) {
      mode.value = display;
      notifyListeners();
      return;
    }
    final generation = _session.start();
    _revision = page.revision;
    _page = page.page;
    _settings = settings;
    // DocumentReflowPage.text already prefers the saved edited text.
    _original = page.text
        .split(RegExp(r'\n\s*\n'))
        .where((text) => text.trim().isNotEmpty)
        .toList();
    _translated = [];
    busy = true;
    mode.value = display;
    notifyListeners();
    try {
      for (final paragraph in _original) {
        final result = await request(_session, generation, paragraph);
        if (!_session.enabled || generation != _session.generation) return;
        _translated.add(result);
        notifyListeners();
      }
    } on TranslationCancelled {
      // Page changes, closing the reader and Stop cancel both transport and UI.
    } catch (_) {
      if (_session.enabled && generation == _session.generation) {
        stop();
        rethrow;
      }
    } finally {
      if (_session.enabled && generation == _session.generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void stop() {
    _session.stop();
    busy = false;
    _original = [];
    _translated = [];
    _revision = null;
    _page = null;
    _settings = null;
    mode.value = TranslationModeEnum.off;
    notifyListeners();
  }

  @override
  void dispose() {
    _session.stop();
    mode.dispose();
    super.dispose();
  }
}
