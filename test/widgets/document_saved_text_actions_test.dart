import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/service/ocr/document_reflow_store.dart';
import 'package:anx_reader/widgets/reading_page/document_saved_text_actions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'document_reflow_reader_test.dart' as fixture;

class _ExportStore extends fixture.MemoryStore {
  String output = '第4页\n────────────────────\n校对𠀀\n────────────────────';
  @override
  Future<String> exportTxt() async => output;
}

class _Picker extends FilePicker {
  String? path, suggestedName;
  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    suggestedName = fileName;
    return path;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });
  testWidgets(
      'TXT export writes UTF-8; cancelling does not alter saved content',
      (tester) async {
    final store = _ExportStore();
    final picker = _Picker();
    FilePicker.platform = picker;
    final directory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('modu-ocr-export-test-'));
    addTearDown(() => directory!.delete(recursive: true));
    picker.path = '${directory!.path}/saved.txt';
    Future<void>? pending;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () =>
                        pending = exportSavedDocumentText(context, store),
                    child: const Text('Export'))))));
    await tester.runAsync(() async {
      await tester.tap(find.text('Export'));
      await pending;
      expect(utf8.decode(await File(picker.path!).readAsBytes()), store.output);
    });
    await tester.pumpAndSettle();
    expect(picker.suggestedName, endsWith('.txt'));
    expect(find.text('TXT exported'), findsOneWidget);
    picker.path = null;
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(store.output, contains('校对𠀀'));
    expect(tester.takeException(), isNull);
  }, skip: !(Platform.isMacOS || Platform.isLinux));

  for (final size in [const Size(360, 640), const Size(740, 360)]) {
    testWidgets('page editor fits $size with large text', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = fixture.MemoryStore();
      final page = DocumentReflowPage(page: 0, ocr: true, rawText: '原文');
      await store.save(page, '');
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!),
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () =>
                          editSavedDocumentPage(context, store, page),
                      child: const Text('Edit'))))));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(
          find.byKey(const ValueKey('saved-page-editor')), '校对');
      await tester.ensureVisible(find.byKey(const ValueKey('save-page-edit')));
      await tester.tap(find.byKey(const ValueKey('save-page-edit')));
      await tester.pumpAndSettle();
      expect(store.latest['0']!.text, '校对');
      expect(tester.takeException(), isNull);
    });
  }
}
