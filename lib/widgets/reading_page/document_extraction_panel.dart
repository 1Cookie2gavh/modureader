import 'package:anx_reader/utils/app_motion.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:anx_reader/l10n/modu_strings.dart';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/service/ocr/local_ocr_service.dart';
import 'package:anx_reader/service/ocr/ocr_model_store.dart';
import 'package:anx_reader/service/ocr/ocr_models.dart';
import 'package:anx_reader/service/ocr/document_page_range.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'document_reader_surface.dart';
import 'package:anx_reader/service/ocr/document_text_style.dart';
import 'document_text_style_dialog.dart';

typedef DocumentRequest = Future<Map<String, dynamic>> Function(
    Map<String, dynamic>);
typedef DocumentOcr = Future<String> Function(
    Uint8List, OcrCancellation, void Function(int, int));

/// A transient, explicitly requested page operation. Nothing is queued on disk.
/// The returned text is a draft, never an instruction to send an AI request.
class DocumentExtractionPanel extends StatefulWidget {
  const DocumentExtractionPanel(
      {super.key,
      required this.info,
      required this.render,
      required this.extractText,
      required this.cancelRender,
      this.modelStore,
      this.recognize,
      this.initialTextStyle = const DocumentTextStyle(),
      this.saveTextStyle,
      this.brightness,
      this.narrationBuilder,
      this.stopNarration,
      this.forceOcr = false});
  final Widget? brightness;
  final Widget Function(String text)? narrationBuilder;
  final Future<void> Function()? stopNarration;
  final Future<Map<String, dynamic>> Function(int?) info;
  final DocumentRequest render, extractText;
  final VoidCallback cancelRender;
  final OcrModelStore? modelStore;
  final DocumentOcr? recognize;
  final bool forceOcr;
  final DocumentTextStyle initialTextStyle;
  final Future<void> Function(DocumentTextStyle)? saveTextStyle;

  @override
  State<DocumentExtractionPanel> createState() =>
      _DocumentExtractionPanelState();
}

class _DocumentExtractionPanelState extends State<DocumentExtractionPanel> {
  late final OcrModelStore _store = widget.modelStore ??
      OcrModelStore(model: OcrModels.byId(Prefs().ocrModelId));
  final _surfaceKey = GlobalKey<DocumentReaderSurfaceState>();
  bool _narrationOpened = false;
  final _textScroll = ScrollController();
  final _pageRange = TextEditingController();
  final _results = <int, String>{};
  List<int> _batchPages = [];
  bool _multiple = false;
  int? _activePage;
  Uint8List? _preview;
  MemoryImage? _image;
  int _page = 0, _total = 0, _generation = 0;
  double _aspect = 1;
  late DocumentTextStyle _textStyle = widget.initialTextStyle;

  void _editTextStyle() => _surfaceKey.currentState?.openMenu('style');

  Rect _region = const Rect.fromLTWH(.1, .1, .8, .8);
  bool _wholePage = false, _forceOcr = false, _busy = false;
  bool _needsModel = false, _reflow = false;
  bool _stopped = false;
  String? _result, _error;
  double? _progress;
  OcrCancellation? _ocr;
  CancelToken? _download;

  String t(String zh, String en) => ModuStrings.text(context, zh, en);
  @override
  void initState() {
    super.initState();
    _forceOcr = widget.forceOcr;
    _load(null);
  }

  @override
  void dispose() {
    if (_narrationOpened) widget.stopNarration?.call();
    _generation++;
    _ocr?.cancel();
    _download?.cancel();
    if (widget.modelStore == null) _store.close();
    widget.cancelRender();
    _image?.evict();
    _textScroll.dispose();
    _pageRange.dispose();
    super.dispose();
  }

  static Uint8List _png(Map<String, dynamic> reply) {
    const prefix = 'data:image/png;base64,';
    final value = reply['dataUrl'];
    if (value is! String ||
        !value.startsWith(prefix) ||
        value.length > 16000000) {
      throw const FormatException('Invalid page image');
    }
    return base64Decode(value.substring(prefix.length));
  }

  Future<bool> _load(int? requested, {bool keepResults = false}) async {
    _stopped = false;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _reflow = keepResults;
      _progress = null;
      _preview = null;
      _activePage = null;
    });
    try {
      final info = await widget.info(requested);
      if (!mounted || generation != _generation || _stopped) return false;
      final page = (info['page'] as num).toInt();
      final total = (info['total'] as num).toInt();
      final aspect = (info['width'] as num) / (info['height'] as num);
      if (page < 0 ||
          page >= total ||
          !aspect.isFinite ||
          aspect <= 0 ||
          info['imageOnly'] == false) {
        throw const FormatException('Page unavailable');
      }
      final png = _png(await widget.render(
          {'page': page, 'width': 1000, 'height': 1000, 'rotation': 0}));
      if (!mounted || generation != _generation || _stopped) return false;
      _image?.evict();
      setState(() {
        _page = page;
        _total = total;
        _aspect = aspect;
        _preview = png;
        _image = MemoryImage(png);
        _result = _results[page];
        if (_pageRange.text.isEmpty) _pageRange.text = '${page + 1}';
      });
      return true;
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error =
            t('页面加载失败，请重试', 'Could not load this page. Please retry.'));
        _surfaceKey.currentState?.openMenu('tools', toggle: false);
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
    return false;
  }

  void _clearResults() {
    _results.clear();
    _batchPages = [];
    _result = null;
    _error = null;
    _reflow = false;
    _activePage = null;
  }

  int? _adjacentPage(int direction) {
    if (_multiple && _batchPages.isNotEmpty) {
      final index = _batchPages.indexOf(_page) + direction;
      return index >= 0 && index < _batchPages.length
          ? _batchPages[index]
          : null;
    }
    final page = _page + direction;
    return page >= 0 && page < _total ? page : null;
  }

  Future<void> _navigate(int direction) async {
    final page = _adjacentPage(direction);
    if (_busy || page == null) return;
    if (_narrationOpened) {
      _surfaceKey.currentState?.closeMenu();
      await widget.stopNarration?.call();
      if (!mounted) return;
      _narrationOpened = false;
    }
    final previewText = _reflow;
    if (await _load(page, keepResults: previewText)) {
      if (previewText && _result == null) {
        await _extract(toAi: false, pages: [page]);
      }
      if (_textScroll.hasClients) _textScroll.jumpTo(0);
    }
  }

  Future<void> _toggleResult() async {
    if (_narrationOpened) {
      await widget.stopNarration?.call();
      if (!mounted) return;
      _narrationOpened = false;
    }
    _surfaceKey.currentState?.closeMenu();
    setState(() => _reflow = !_reflow);
  }

  String get _draft => _multiple
      ? _batchPages
          .where((page) => _results[page]!.trim().isNotEmpty)
          .map((page) =>
              '${t('第 ${page + 1} 页', 'Page ${page + 1}')}\n${_results[page]!}')
          .join('\n\n')
      : _result!;

  bool get _complete => _multiple
      ? _batchPages.isNotEmpty && _batchPages.every(_results.containsKey)
      : _result != null;

  Future<void> _startExtraction({required bool toAi}) async {
    if (_busy) return;
    if (_multiple) {
      try {
        _batchPages = parseDocumentPageRange(_pageRange.text, _total);
      } on FormatException {
        setState(() => _error = t('请输入有效页码，如 1-5,8,10-12（共 $_total 页）',
            'Enter valid pages, e.g. 1-5,8,10-12 ($_total pages).'));
        return;
      }
      if (_page != _batchPages.first && !await _load(_batchPages.first)) return;
    }
    await _extract(toAi: toAi, pages: _multiple ? _batchPages : [_page]);
  }

  void _stop() {
    _stopped = true;
    _ocr?.cancel();
    _download?.cancel();
    widget.cancelRender();
    // Do not start another job until the worker has released its model sessions.
  }

  Future<void> _downloadModel() async {
    _store.downloadSource = Prefs().ocrModelDownloadSource == 'gitee'
        ? OcrDownloadSource.gitee
        : OcrDownloadSource.upstream;
    final token = CancelToken();
    _download = token;
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      await _store.download(token, (n, total) {
        if (mounted && !token.isCancelled) {
          setState(() => _progress = n / total);
        }
      });
      if (mounted && !token.isCancelled) setState(() => _needsModel = false);
    } catch (_) {
      if (mounted && !token.isCancelled) {
        setState(() => _error = t('模型下载或校验失败。请检查网络后重试，已完成的模型文件会保留。',
            'Model download or verification failed. Check your connection and retry; verified files are retained.'));
      }
    } finally {
      _download = null;
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _extract({required bool toAi, required List<int> pages}) async {
    if (!mounted || _busy || _preview == null) return;
    final cancel = OcrCancellation();
    _ocr = cancel;
    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
    });
    final r =
        _wholePage || _multiple ? const Rect.fromLTWH(0, 0, 1, 1) : _region;
    try {
      // One page at a time: the OCR worker and image memory are never multiplied.
      for (var index = 0; index < pages.length; index++) {
        final page = pages[index];
        cancel.check();
        if (_results.containsKey(page)) continue;
        setState(() {
          _activePage = page;
          _progress = index / pages.length;
        });
        final request = <String, dynamic>{
          'page': page,
          'region': {
            'x': r.left,
            'y': r.top,
            'width': r.width,
            'height': r.height
          }
        };
        var text = '';
        if (!_forceOcr) {
          final reply = await widget.extractText(request);
          text = (reply['text'] as String? ?? '').trim();
        }
        cancel.check();
        if (text.isEmpty) {
          if (!await _store.available()) {
            if (mounted && !cancel.cancelled) {
              setState(() => _needsModel = true);
              _surfaceKey.currentState?.openMenu('tools', toggle: false);
            }
            return;
          }
          cancel.check();
          final png = _png(await widget.render(
              {...request, 'width': 2048, 'height': 2048, 'rotation': 0}));
          cancel.check();
          void progress(int n, int total) {
            if (mounted && !cancel.cancelled) {
              setState(() => _progress = (index + n / total) / pages.length);
            }
          }

          text = await (widget.recognize?.call(png, cancel, progress) ??
              LocalOcrService()
                  .recognize(png, _store, cancel, progress: progress));
        }
        cancel.check();
        if (!mounted) return;
        if (text.trim().isEmpty && !_multiple) {
          setState(() => _error = t('未找到可识别文字。请框选单栏、放正页面后重试。',
              'No text found. Select a single upright column and retry.'));
          return;
        }
        setState(() {
          _results[page] = text;
          _result = _results[_page];
        });
      }
      if (toAi && _complete && _draft.trim().isNotEmpty) {
        Navigator.of(context).pop(_draft);
      } else {
        setState(() => _reflow = true);
        _surfaceKey.currentState?.closeMenu();
        if (_textScroll.hasClients) _textScroll.jumpTo(0);
      }
    } catch (_) {
      if (mounted && !cancel.cancelled) {
        setState(() => _error = t('提取失败，请缩小区域重试；如模型损坏，可重新下载。',
            'Extraction failed. Try a smaller region or download the model again.'));
        _surfaceKey.currentState?.openMenu('tools', toggle: false);
      }
    } finally {
      _ocr = null;
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
          if (cancel.cancelled) {
            _error = t('已停止，已完成的页面保留，可重试继续。',
                'Stopped. Completed pages are retained; retry to continue.');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => DocumentReaderSurface(
        key: _surfaceKey,
        brightness: widget.brightness,
        narration: _reflow &&
                _result?.trim().isNotEmpty == true &&
                widget.narrationBuilder != null
            ? Builder(builder: (_) {
                _narrationOpened = true;
                return widget.narrationBuilder!(_result!);
              })
            : null,
        header: Row(children: [
          IconButton(
              tooltip: t('关闭', 'Close'),
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context)),
          Expanded(
              child: Text(t('提取文字', 'Extract text'),
                  style: const TextStyle(fontSize: 22))),
          IconButton(
              tooltip: t('OCR 文字样式', 'OCR text style'),
              onPressed: _editTextStyle,
              icon: const Icon(Icons.settings)),
        ]),
        style: DocumentTextStyleDialog(
            initial: _textStyle,
            embedded: true,
            save: (style) async {
              await widget.saveTextStyle?.call(style);
              if (mounted) setState(() => _textStyle = style);
            }),
        body: Column(children: [
          Expanded(
              child: _reflow && _result != null
                  ? SingleChildScrollView(
                      controller: _textScroll,
                      padding: EdgeInsets.symmetric(
                          vertical: 20, horizontal: _textStyle.margin),
                      child: SelectableText(
                          _result!.trim().isEmpty
                              ? t('此页未识别到文字', 'No text found on this page')
                              : _result!,
                          textAlign: _textStyle.alignment,
                          style: _textStyle.textStyle))
                  : _preview == null
                      ? Center(
                          child: _busy
                              ? const EinkStaticIndicator(
                                  child: CircularProgressIndicator())
                              : TextButton(
                                  onPressed: () => _load(null),
                                  child: Text(t('重新加载', 'Reload'))))
                      : LayoutBuilder(builder: (context, c) {
                          final width =
                              math.min(c.maxWidth, c.maxHeight * _aspect);
                          return Center(
                              child: SizedBox(
                                  width: width,
                                  height: width / _aspect,
                                  child: DocumentRegionSelector(
                                      image: _image!,
                                      region: _region,
                                      enabled:
                                          !_busy && !_wholePage && !_multiple,
                                      showRegion: !_wholePage && !_multiple,
                                      onChanged: (r) => setState(() {
                                            _region = r;
                                            _clearResults();
                                          }))));
                        })),
          if (_busy)
            EinkStaticIndicator(
                child: LinearProgressIndicator(value: _progress)),
        ]),
        navigation: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                  tooltip: t('上一页', 'Previous page'),
                  onPressed: !_busy && _adjacentPage(-1) != null
                      ? () => _navigate(-1)
                      : null,
                  icon: const Icon(Icons.chevron_left)),
              Text('${_page + 1} / $_total'),
              IconButton(
                  tooltip: t('下一页', 'Next page'),
                  onPressed: !_busy && _adjacentPage(1) != null
                      ? () => _navigate(1)
                      : null,
                  icon: const Icon(Icons.chevron_right)),
              if (_result != null)
                TextButton(
                    onPressed: _busy ? null : _toggleResult,
                    child: Text(_reflow
                        ? t('原版', 'Original')
                        : t('提取结果', 'Extracted text'))),
            ]),
        tools: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t('文字识别', 'Text recognition'),
              style: Theme.of(context).textTheme.titleLarge),
          if (_multiple && _batchPages.isNotEmpty)
            Text(t('已完成 ${_results.length} / ${_batchPages.length} 页',
                '${_results.length} / ${_batchPages.length} pages completed')),
          if (_busy && _activePage != null)
            Text(t('正在提取第 ${_activePage! + 1} 页',
                'Extracting page ${_activePage! + 1}')),
          if (_reflow) ...[
            Text(t('核对提取结果后填入 AI 输入框，不会自动发送。',
                'Review the extracted text before filling the AI draft. It is not sent automatically.')),
          ] else ...[
            Wrap(spacing: 8, children: [
              ChoiceChip(
                  label: Text(t('区域识别', 'Selected area')),
                  selected: !_wholePage && !_multiple,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() {
                            _wholePage = false;
                            _multiple = false;
                            _clearResults();
                          })),
              ChoiceChip(
                  label: Text(t('整页识别', 'Whole page')),
                  selected: _wholePage && !_multiple,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() {
                            _wholePage = true;
                            _multiple = false;
                            _clearResults();
                          })),
              ChoiceChip(
                  label: Text(t('连续识别', 'Multiple pages')),
                  selected: _multiple,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() {
                            _multiple = true;
                            _clearResults();
                          })),
            ]),
            if (_multiple)
              TextField(
                key: const ValueKey('extraction-page-range'),
                controller: _pageRange,
                enabled: !_busy,
                maxLength: 512,
                decoration: InputDecoration(
                  labelText: t('页码范围', 'Page range'),
                  hintText: '1-5,8,10-12',
                  helperText: t('使用文档页码（共 $_total 页），逗号分隔',
                      'Document page numbers ($_total total), separated by commas'),
                  counterText: '',
                ),
                onChanged: (_) => setState(_clearResults),
              ),
            if (!_wholePage && !_multiple)
              Text(t('拖动框内移动区域，拖动四角调整大小',
                  'Drag inside to move; drag a corner to resize.')),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t('强制 OCR', 'Force OCR')),
                subtitle: Text(t('默认优先使用文字层；识别在本机进行',
                    'Prefer embedded text by default; OCR runs on this device.')),
                value: _forceOcr,
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                          _forceOcr = v;
                          _clearResults();
                        })),
          ],
          if (_needsModel)
            Padding(
                padding: const EdgeInsets.all(8),
                child: Text(t(
                    '此区域需要 OCR。请先下载已选模型，再点击提取。可在设置 → OCR 模型中选择模型及下载源；识别在本机进行，不上传书页。',
                    'OCR is needed. Download the selected model, then extract again. Choose a model and source in Settings → OCR model. Recognition stays on this device; book pages are not uploaded.'))),
          if (_error != null)
            Text(
                _activePage == null
                    ? _error!
                    : '${t('第 ${_activePage! + 1} 页', 'Page ${_activePage! + 1}')} · $_error',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                if (_busy)
                  OutlinedButton(onPressed: _stop, child: Text(t('停止', 'Stop')))
                else ...[
                  if (_needsModel || _error != null)
                    OutlinedButton(
                        onPressed: _downloadModel,
                        child: Text(t(
                            '下载 / 修复 OCR 模型', 'Download / repair OCR model'))),
                  if (!_reflow || !_complete)
                    OutlinedButton(
                        onPressed: _preview == null
                            ? null
                            : () => _startExtraction(toAi: false),
                        child: Text(t('预览提取结果', 'Preview extracted text'))),
                  FilledButton.icon(
                      onPressed: _preview == null ||
                              (_complete && _draft.trim().isEmpty)
                          ? null
                          : () {
                              if (_complete) {
                                Navigator.pop(context, _draft);
                              } else {
                                _startExtraction(toAi: true);
                              }
                            },
                      icon: const Icon(Icons.edit_note),
                      label: Text(t('提取至 AI 输入框', 'Extract to AI draft'))),
                ],
              ]),
          Text(
              t('填入后由你确认发送。OCR：PP-OCRv4 / RapidOCR · Apache-2.0',
                  'Review before sending. OCR: PP-OCRv4 / RapidOCR · Apache-2.0'),
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

/// Coordinates are normalized to the original page, not the cropped reader view.
class DocumentRegionSelector extends StatelessWidget {
  const DocumentRegionSelector(
      {super.key,
      required this.image,
      required this.region,
      required this.enabled,
      required this.showRegion,
      required this.onChanged});
  final ImageProvider image;
  final Rect region;
  final bool enabled, showRegion;
  final ValueChanged<Rect> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        return Stack(clipBehavior: Clip.hardEdge, children: [
          Positioned.fill(
              child:
                  Image(image: image, fit: BoxFit.fill, gaplessPlayback: true)),
          if (showRegion) ...[
            Positioned(
                left: region.left * w,
                top: region.top * h,
                width: region.width * w,
                height: region.height * h,
                child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: !enabled
                        ? null
                        : (d) {
                            onChanged(Rect.fromLTWH(
                                (region.left + d.delta.dx / w)
                                    .clamp(0, 1 - region.width),
                                (region.top + d.delta.dy / h)
                                    .clamp(0, 1 - region.height),
                                region.width,
                                region.height));
                          },
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.black, width: 2),
                            color: Colors.white.withValues(alpha: .12))))),
            for (var i = 0; i < 4; i++)
              Positioned(
                  left: ((i % 2 == 0 ? region.left : region.right) * w - 22)
                      .clamp(0, math.max(0, w - 44)),
                  top: ((i < 2 ? region.top : region.bottom) * h - 22)
                      .clamp(0, math.max(0, h - 44)),
                  child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: !enabled
                          ? null
                          : (d) {
                              final dx = d.delta.dx / w, dy = d.delta.dy / h;
                              onChanged(Rect.fromLTRB(
                                  i % 2 == 0
                                      ? (region.left + dx)
                                          .clamp(0, region.right - .04)
                                      : region.left,
                                  i < 2
                                      ? (region.top + dy)
                                          .clamp(0, region.bottom - .04)
                                      : region.top,
                                  i % 2 == 1
                                      ? (region.right + dx)
                                          .clamp(region.left + .04, 1)
                                      : region.right,
                                  i >= 2
                                      ? (region.bottom + dy)
                                          .clamp(region.top + .04, 1)
                                      : region.bottom));
                            },
                      child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                              child: DecoratedBox(
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.fromBorderSide(BorderSide(
                                          color: Colors.black, width: 2))),
                                  child: SizedBox(width: 14, height: 14)))))),
          ],
        ]);
      });
}
