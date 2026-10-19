import 'dart:io';

import 'package:anx_reader/service/ocr/document_reflow_loader.dart';
import 'package:anx_reader/service/ocr/document_reflow_store.dart';
import 'package:anx_reader/service/ocr/document_text_geometry.dart';
import 'package:anx_reader/service/ocr/local_ocr_service.dart';
import 'package:anx_reader/service/ocr/ocr_model_store.dart';
import 'package:flutter_test/flutter_test.dart';

class ReadyModel extends OcrModelStore {
  @override
  Future<bool> available() async => true;
}

void main() {
  late Directory directory;
  late DocumentReflowStore store;
  late ReadyModel model;
  late List<String> stages;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('modu-reflow-loader-');
    store = DocumentReflowStore('book', directory: directory);
    model = ReadyModel();
    stages = [];
  });
  tearDown(() async {
    model.close();
    await directory.delete(recursive: true);
  });

  Future<DocumentReflowPage> load(Map<String, dynamic> info,
          {bool scanned = false}) =>
      loadDocumentReflowPage(
        info: info,
        store: store,
        model: model,
        cancel: OcrCancellation(),
        extract: (request) async {
          expect(request['page'], isA<int>());
          stages.add('extract');
          return {'text': scanned ? '' : 'Text layer'};
        },
        render: (request) async {
          expect(request['page'], isA<int>());
          stages.add('render');
          return {'dataUrl': 'data:image/png;base64,AQ=='};
        },
        recognize: (_, __, ___) async {
          stages.add('recognize');
          return DocumentTextResult('Recognized text');
        },
      );

  for (final page in <num>[2, 2.0]) {
    test('accepts ${page.runtimeType} bridge pages and reuses corrected cache',
        () async {
      final info = {'page': page, 'total': page is int ? 5 : 5.0};
      final result = await load(info);
      expect(result.page, 2);
      expect(result.ocr, isFalse);
      expect(stages, ['extract']);
      await store.save(
          DocumentReflowPage(
              page: 2,
              ocr: false,
              rawText: result.rawText,
              editedText: 'Corrected text'),
          '');
      stages.clear();
      expect((await load(info)).text, 'Corrected text');
      expect(stages, isEmpty);
    });
  }

  test('Mac double page numbers reach OCR and persist by original page',
      () async {
    final result = await load({'page': 73.0, 'total': 357.0}, scanned: true);
    expect(result.page, 73);
    expect(result.ocr, isTrue);
    expect(stages, ['extract', 'render', 'recognize']);
    expect((await store.read(73, ''))!.text, 'Recognized text');
  });

  for (final invalid in <Object?>[
    null,
    '2',
    true,
    -1,
    2.5,
    double.nan,
    double.infinity,
    double.negativeInfinity,
    1e100,
  ]) {
    test('rejects invalid page/total $invalid without doing work', () async {
      await expectLater(
          load({'page': invalid, 'total': 5}), throwsFormatException);
      await expectLater(
          load({'page': 0, 'total': invalid}), throwsFormatException);
      expect(stages, isEmpty);
    });
  }
  test('rejects out of bounds and non-image pages', () async {
    for (final info in [
      {'page': 5.0, 'total': 5.0},
      {'page': 0.0, 'total': 0.0},
      {'page': 2.0, 'total': 5.0, 'imageOnly': false},
    ]) {
      await expectLater(load(info), throwsFormatException);
    }
    expect(stages, isEmpty);
  });
}
