import 'package:anx_reader/utils/app_motion.dart';
import 'dart:async';
import 'dart:convert';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/modu_strings.dart';
import 'package:anx_reader/models/book_note.dart';
import 'package:anx_reader/service/book_player/reader_word_selection.dart';
import 'package:anx_reader/page/settings_page/ocr_model.dart';
import 'package:anx_reader/service/ocr/document_reflow_store.dart';
import 'package:anx_reader/service/ocr/document_text_style.dart';
import 'package:anx_reader/service/ocr/document_text_geometry.dart';
import 'package:anx_reader/service/book_player/reading_appearance.dart';
import 'package:anx_reader/service/ocr/local_ocr_service.dart';
import 'package:anx_reader/service/ocr/ocr_model_store.dart';
import 'package:anx_reader/service/ocr/ocr_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'document_text_style_dialog.dart';
import 'document_reader_surface.dart';
import 'progress_widget.dart';
import 'reader_settings_scroll_view.dart';
import 'package:anx_reader/models/reader_progress.dart';

typedef ReflowSelection = Future<void> Function(DocumentReflowAnchor anchor,
    String text, String contextText, Rect globalRect, List<int> annotationIds);

/// A reading surface in the reader's body, not a dialog or another book.
/// The source WebView stays mounted underneath to retain original-page state.
class DocumentReflowReader extends StatefulWidget {
  const DocumentReflowReader(
      {super.key,
      required this.store,
      required this.info,
      required this.extractText,
      required this.render,
      required this.cancelRender,
      required this.onClose,
      required this.onPageChanged,
      required this.onSelection,
      required this.clearMenu,
      this.selectionInvalidated,
      required this.loadNotes,
      required this.initialStyle,
      required this.saveStyle,
      this.forceOcr = false,
      this.anchor,
      this.modelStore,
      this.recognize,
      this.recognizeWithRegions,
      this.brightness,
      this.onQuery,
      this.onAiDraft,
      this.onBookmark,
      this.onExtract,
      this.onOpenReaderMenu,
      this.onOpenReaderPanel,
      this.onCloseReaderMenu,
      this.readerMenuVisible = false,
      this.readerActions = const []});
  final VoidCallback? onOpenReaderMenu, onCloseReaderMenu;
  final ValueChanged<Widget>? onOpenReaderPanel;
  final bool readerMenuVisible;
  final Future<void> Function(String, String, bool)? onQuery;
  final Future<void> Function(String)? onAiDraft;
  final Future<void> Function(DocumentReflowAnchor, String)? onBookmark;
  final VoidCallback? onExtract;
  final Widget? brightness;
  final List<Widget> readerActions;
  final DocumentReflowStore store;
  final Future<Map<String, dynamic>> Function(int?) info;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) extractText,
      render;
  final VoidCallback cancelRender, onClose, clearMenu;
  final VoidCallback? selectionInvalidated;
  final Future<void> Function(int) onPageChanged;
  final ReflowSelection onSelection;
  final Future<List<BookNote>> Function() loadNotes;
  final DocumentTextStyle initialStyle;
  final Future<void> Function(DocumentTextStyle) saveStyle;
  final bool forceOcr;
  final DocumentReflowAnchor? anchor;
  final OcrModelStore? modelStore;
  final Future<String> Function(
      Uint8List, OcrCancellation, void Function(int, int))? recognize;
  final Future<DocumentTextResult> Function(
          Uint8List, OcrCancellation, void Function(int, int))?
      recognizeWithRegions;
  @override
  State<DocumentReflowReader> createState() => DocumentReflowReaderState();
}

class DocumentReflowReaderState extends State<DocumentReflowReader> {
  final _surfaceKey = GlobalKey<DocumentReaderSurfaceState>();
  final _panels = ValueNotifier<int>(0);
  void closeMenu() {
    if (widget.onCloseReaderMenu != null) {
      widget.onCloseReaderMenu!();
    } else {
      _surfaceKey.currentState?.closeMenu();
    }
  }

  void _openMenu(String menu) {
    if (widget.onOpenReaderPanel != null) {
      widget.clearMenu();
      clearSelection();
      widget.onOpenReaderPanel!(ListenableBuilder(
          listenable: _panels,
          builder: (context, _) => Padding(
              padding:
                  menu == 'style' ? EdgeInsets.zero : const EdgeInsets.all(16),
              child: menu == 'style'
                  ? _readerPanel(menu)
                  : ReaderSettingsScrollView(child: _readerPanel(menu)))));
    } else {
      _surfaceKey.currentState?.openMenu(menu);
    }
  }

  void openStyleMenu() => _openMenu('style');
  void openToolsMenu() => _openMenu('tools');
  Future<void> readerAction(String action) => _action(action);
  Widget progressPanel() => ListenableBuilder(
      listenable: _panels,
      builder: (context, _) => ReadingProgressControls(
          progress: ReaderProgress(
              chapterTitle: chapter,
              currentChapter: 1,
              totalChapters: !_busy && _total > 0 ? 1 : 0,
              currentPage: (_navigationPage ?? 0) + 1,
              totalPages: _total,
              percentage:
                  _total > 1 ? (_navigationPage ?? 0) / (_total - 1) : 0),
          onSeek: (value) => goToPage((value * (_total - 1)).round()),
          onPreviousChapter: () => turnOriginalPage(-1),
          onPreviousPage: () => turnOriginalPage(-1),
          onNextPage: () => turnOriginalPage(1),
          onNextChapter: () => turnOriginalPage(1)));
  final _controller = _ReflowTextController();
  final _search = TextEditingController();
  String? _searchStatus;
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'document_reflow_text');
  final _textFieldKey = GlobalKey();
  EditableTextState? _editable;
  EditableTextState? get _textState {
    EditableTextState? result;
    void visit(Element element) {
      if (element is StatefulElement && element.state is EditableTextState) {
        result = element.state as EditableTextState;
      } else {
        element.visitChildren(visit);
      }
    }

    _textFieldKey.currentContext?.visitChildElements(visit);
    return result;
  }

  late DocumentTextStyle _style = widget.initialStyle;
  late bool _forceOcr = widget.anchor?.ocr ?? widget.forceOcr;
  DocumentReflowPage? _page;
  int _total = 0, _generation = 0;
  int? _requestedPage;
  int? get _navigationPage => _requestedPage ?? _page?.page;
  Future<void>? _pendingLoad;
  bool _busy = false, _needsModel = false;
  String? _error, _shownSelection;
  TextSelection _observedSelection = const TextSelection.collapsed(offset: -1);
  Timer? _selectionTimer;
  Timer? _mouseLongPressTimer;
  Timer? _menuTapTimer;
  Duration? _pointerDownTime;
  int _selectionEpoch = 0;
  int? _expandingEpoch;
  bool _selectionSession = false, _expandInitialSelection = false;
  PointerDeviceKind? _pointerKind;
  Offset? _pointerOrigin;
  double? _progress;
  OcrCancellation? _cancel;
  List<BookNote> _notes = [];
  String t(String zh, String en) => ModuStrings.text(context, zh, en);
  String get chapter =>
      '${t('原书第', 'Original page')} ${(_page?.page ?? 0) + 1} ${t('页 · 重排', '· reflow')}';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_selectionChanged);
    unawaited(_style.loadFont().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {}));
    unawaited(_load(widget.anchor?.page, anchor: widget.anchor));
  }

  @override
  void dispose() {
    _generation++;
    _selectionTimer?.cancel();
    _mouseLongPressTimer?.cancel();
    _menuTapTimer?.cancel();
    _cancel?.cancel();
    widget.cancelRender();
    _controller.dispose();
    _search.dispose();
    _scroll.dispose();
    _focus.dispose();
    _panels.dispose();
    super.dispose();
  }

  Future<void> refreshNotes() async {
    final version = _generation;
    final notes = await widget.loadNotes();
    if (!mounted || version != _generation) return;
    _notes = notes;
    _controller.setMarks(_page, notes);
  }

  void _selectionChanged() {
    final selection = _controller.selection;
    if (selection == _observedSelection) return;
    _observedSelection = selection;
    _selectionEpoch++;
    _shownSelection = null;
    if (_selectionSession &&
        !(_pointerOrigin != null && _pointerKind == PointerDeviceKind.mouse)) {
      _queueSelection();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          selection != _controller.selection ||
          _shownSelection != null) {
        return;
      }
      (widget.selectionInvalidated ?? widget.clearMenu)();
    });
  }

  void clearSelection() {
    _resetSelectionGesture();
    _editable?.hideToolbar();
    _shownSelection = null;
    _controller.selection = TextSelection.collapsed(
        offset: _controller.selection.extentOffset
            .clamp(0, _controller.text.length));
  }

  Future<void> navigate(DocumentReflowAnchor anchor) async {
    if (_busy) {
      _cancel?.cancel();
      widget.cancelRender();
    }
    _forceOcr = anchor.ocr;
    await _load(anchor.page, anchor: anchor);
  }

  Future<void> setMode(bool ocr) async {
    if (_busy) return;
    setState(() => _forceOcr = ocr);
    await _load(_navigationPage);
  }

  Future<void> turn(int direction) async {
    if (_busy) return;
    if (_page == null || _navigationPage != _page!.page) {
      await turnOriginalPage(direction);
      return;
    }
    clearSelection();
    widget.clearMenu();
    if (_scroll.hasClients) {
      final next =
          _scroll.offset + direction * _scroll.position.viewportDimension * .9;
      if ((direction > 0 &&
              _scroll.offset < _scroll.position.maxScrollExtent - 1) ||
          (direction < 0 && _scroll.offset > 1)) {
        final target =
            next.clamp(0, _scroll.position.maxScrollExtent).toDouble();
        if (AppMotion.disabled) {
          _scroll.jumpTo(target);
        } else {
          await _scroll.animateTo(target,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut);
        }
        return;
      }
    }
    await turnOriginalPage(direction);
  }

  void cancelLoading() {
    _cancel?.cancel();
    widget.cancelRender();
  }

  Future<void> turnOriginalPage(int direction) async {
    final page = _navigationPage;
    if (_busy || page == null) return;
    final target = page + direction;
    if (target >= 0 && target < _total) await _load(target);
  }

  Future<void> goToPage(int page) async {
    if (page >= 0 && page < _total) await _load(page);
  }

  String get actionText {
    final selection = _controller.selection;
    return selection.isValid && !selection.isCollapsed
        ? selection.textInside(_controller.text)
        : _controller.text;
  }

  Future<void> _jumpToPage() async {
    final input = TextEditingController(text: '${(_navigationPage ?? 0) + 1}');
    final target = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(t('跳转原书页码', 'Go to original page')),
              content: TextField(
                  controller: input,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(helperText: '1–$_total'),
                  onSubmitted: (value) {
                    final number = int.tryParse(value);
                    if (number != null && number > 0 && number <= _total) {
                      Navigator.pop(context, number - 1);
                    }
                  }),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t('取消', 'Cancel'))),
                TextButton(
                    onPressed: () {
                      final number = int.tryParse(input.text);
                      if (number != null && number > 0 && number <= _total) {
                        Navigator.pop(context, number - 1);
                      }
                    },
                    child: Text(t('跳转', 'Go')))
              ],
            ));
    // Dialog route transitions can still reference its controller this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => input.dispose());
    if (mounted && target != null) await goToPage(target);
  }

  void _findNext() {
    final query = _search.text;
    if (query.isEmpty) return;
    final text = _controller.text;
    final pattern = RegExp(RegExp.escape(query), caseSensitive: false);
    final match = pattern
            .allMatches(text,
                _controller.selection.isValid ? _controller.selection.end : 0)
            .firstOrNull ??
        pattern.firstMatch(text);
    final index = match?.start ?? -1;
    setState(() => _searchStatus =
        index < 0 ? t('本页未找到', 'Not found on this page') : null);
    _panels.value++;
    if (index < 0) return;
    final state = _textState;
    state?.userUpdateTextEditingValue(
        _controller.value.copyWith(
            selection:
                TextSelection(baseOffset: index, extentOffset: match!.end)),
        SelectionChangedCause.keyboard);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) state?.bringIntoView(TextPosition(offset: index));
    });
  }

  Future<void> _action(String action) async {
    final text = actionText, page = _page;
    if (text.isEmpty || page == null) return;
    if (action == 'search') {
      _openMenu('search');
      return;
    }
    closeMenu();
    try {
      switch (action) {
        case 'copy':
          await Clipboard.setData(ClipboardData(text: text));
        case 'query':
          await widget.onQuery?.call(text, page.text, false);
        case 'translate':
          await widget.onQuery?.call(text, page.text, true);
        case 'ai':
          await widget.onAiDraft?.call(text);
        case 'bookmark':
          final selection = _controller.selection;
          final start = selection.isValid
              ? selection.start.clamp(0, page.text.length - 1)
              : 0;
          final end = selection.isValid && !selection.isCollapsed
              ? selection.end
              : (start + 120).clamp(0, page.text.length);
          await widget.onBookmark
              ?.call(page.anchor(start, end), page.text.substring(start, end));
          await refreshNotes();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t(
                '操作失败，请重试', 'Could not complete the action. Please retry.'))));
      }
    }
  }

  Future<void> _load(int? target,
      {DocumentReflowAnchor? anchor, bool refresh = false}) async {
    while (_pendingLoad != null) {
      cancelLoading();
      await _pendingLoad;
    }
    if (!mounted) return;
    final pending = _performLoad(target, anchor: anchor, refresh: refresh);
    _pendingLoad = pending;
    try {
      await pending;
    } finally {
      if (identical(_pendingLoad, pending)) _pendingLoad = null;
    }
  }

  Future<void> _performLoad(int? target,
      {DocumentReflowAnchor? anchor, bool refresh = false}) async {
    _resetSelectionGesture();
    final generation = ++_generation, cancel = OcrCancellation();
    _cancel?.cancel();
    _cancel = cancel;
    widget.clearMenu();
    setState(() {
      _busy = true;
      // Navigation follows the attempted source page, not stale reflow text.
      _requestedPage = target ?? _navigationPage;
      _error = null;
      _needsModel = false;
      _progress = null;
    });
    _panels.value++;
    final model = widget.modelStore ??
        OcrModelStore(model: OcrModels.byId(Prefs().ocrModelId));
    bool active() => mounted && generation == _generation && !cancel.cancelled;
    void check() {
      cancel.check();
      if (!active()) throw StateError('Reader changed');
    }

    try {
      final info = await widget.info(target);
      check();
      final page = (info['page'] as num).toInt(),
          total = (info['total'] as num).toInt();
      if (page < 0 ||
          page >= total ||
          (target != null && page != target) ||
          info['imageOnly'] == false) {
        throw const FormatException('Invalid image page');
      }
      _requestedPage = page;
      _total = total;
      // Bounds are original-page coordinates resolved by the same crop logic
      // as the PDF/image reader. No region picker for either reflow command.
      final sourceRegion = info['region'] as Map? ??
          const {'x': 0, 'y': 0, 'width': 1, 'height': 1};
      final region = <String, double>{};
      for (final name in ['x', 'y', 'width', 'height']) {
        final value = sourceRegion[name];
        if (value is! num || !value.isFinite) {
          throw const FormatException('Invalid reflow bounds');
        }
        region[name] = value.toDouble();
      }
      if (region['x']! < 0 ||
          region['y']! < 0 ||
          region['width']! <= 0 ||
          region['height']! <= 0 ||
          region['x']! + region['width']! > 1 + 1e-9 ||
          region['y']! + region['height']! > 1 + 1e-9) {
        throw const FormatException('Invalid reflow bounds');
      }
      final hideWatermarks = info['hideWatermarks'] == true;
      final profile =
          'reflow-v4:${_forceOcr ? 'ocr' : 'text'}:${model.model.id}:${model.model.revision}:${jsonEncode(region)}:$hideWatermarks';
      var result = refresh
          ? null
          : anchor == null
              ? await widget.store.read(page, profile)
              : await widget.store.readAnchor(anchor);
      check();
      if (result == null) {
        var text = '', usedOcr = false;
        var geometry = <DocumentTextRegion>[];
        final request = <String, dynamic>{
          'page': page,
          'region': region,
          'hideWatermarks': hideWatermarks,
        };
        if (!_forceOcr) {
          final result =
              DocumentTextResult.decode(await widget.extractText(request));
          text = result.text;
          geometry = result.regions;
          check();
        }
        if (text.trim().isEmpty) {
          if (!await model.available()) {
            check();
            setState(() => _needsModel = true);
            return;
          }
          check();
          usedOcr = true;
          final image = await widget.render(
              {...request, 'width': 2048, 'height': 2048, 'rotation': 0});
          check();
          const prefix = 'data:image/png;base64,';
          final data = image['dataUrl'];
          if (data is! String ||
              !data.startsWith(prefix) ||
              data.length > 16000000) {
            throw const FormatException('Invalid page image');
          }
          void progress(int n, int total) {
            if (active()) {
              setState(() => _progress = total > 0 ? n / total : null);
            }
          }

          final bytes = base64Decode(data.substring(prefix.length));
          final recognized = await (widget.recognizeWithRegions
                  ?.call(bytes, cancel, progress) ??
              (widget.recognize != null
                  ? widget.recognize!(bytes, cancel, progress)
                      .then(DocumentTextResult.new)
                  : LocalOcrService().recognizeWithRegions(bytes, model, cancel,
                      progress: progress)));
          final result = recognized.within(DocumentImageRect(
              region['x']!, region['y']!, region['width']!, region['height']!));
          text = result.text;
          geometry = result.regions;
          check();
        }
        if (text.trim().isEmpty || text.length > 1000000) {
          throw const FormatException('No usable text');
        }
        result = DocumentReflowPage(
            page: page, ocr: usedOcr, rawText: text, rawRegions: geometry);
        await widget.store.save(result, profile);
        check();
      }
      final notes = await widget.loadNotes();
      check();
      // Commit page and reader progress together only after successful loading.
      await widget.onPageChanged(page);
      check();
      _page = result;
      _notes = notes;
      _controller.text = result.text;
      _controller.setMarks(result, notes);
      _controller.paragraphSpacing = _style.paragraphSpacing;
      _shownSelection = null;
      setState(() {
        if (anchor != null && !anchor.matches(result!)) {
          _error = t('已返回原书页码，但重排文字版本不同，未强行定位标注。',
              'Returned to the source page. Text has changed; the annotation was not applied to a different passage.');
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!active()) return;
        if (_scroll.hasClients) _scroll.jumpTo(0);
        if (anchor != null && anchor.matches(result!)) {
          _controller.selection =
              TextSelection(baseOffset: anchor.start, extentOffset: anchor.end);
          _textState?.bringIntoView(TextPosition(offset: anchor.start));
        }
      });
    } catch (_) {
      if (active()) {
        setState(() => _error = t('本页重排失败，已保留原阅读位置。请重试、用左右箭头切换页面或返回原页。',
            'Could not reflow this page. Your position is unchanged. Retry, use the arrows to switch pages, or return to the original.'));
      }
    } finally {
      if (widget.modelStore == null) model.close();
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _progress = null;
        });
        _panels.value++;
      }
    }
  }

  Future<void> _settings() async {
    await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const OcrModelSettings()));
    if (mounted) {
      await _load(_requestedPage ?? _page?.page ?? widget.anchor?.page);
    }
  }

  Widget _readerPanel(String menu) => switch (menu) {
        'style' => stylePanel(),
        'search' => Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                key: const ValueKey('reflow-search'),
                controller: _search,
                decoration:
                    InputDecoration(labelText: t('本页搜索', 'Search this page')),
                onSubmitted: (_) => _findNext()),
            TextButton(
                key: const ValueKey('reflow-find-next'),
                onPressed: _findNext,
                child: Text(t('下一个', 'Find next'))),
            if (_searchStatus != null) Text(_searchStatus!),
          ]),
        _ => Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t('PDF / OCR', 'PDF / OCR'),
                style: Theme.of(context).textTheme.titleLarge),
            SwitchListTile(
                title: Text(t('强制 OCR', 'Force OCR')),
                value: _forceOcr,
                onChanged: _busy ? null : (v) => setMode(v)),
            ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(t('重新识别本页', 'Recognize this page again')),
                subtitle: Text(t('保留旧版本及其划线笔记',
                    'Keep older versions and their annotations')),
                onTap:
                    _busy ? null : () => _load(_navigationPage, refresh: true)),
            if (widget.onExtract != null)
              ListTile(
                  leading: const Icon(Icons.crop),
                  title: Text(
                      t('区域 / 连续多页识别', 'Area / multiple-page recognition')),
                  onTap: widget.onExtract),
            ListTile(
                leading: const Icon(Icons.arrow_back),
                title: Text(t('返回原页', 'Return to original page')),
                onTap: widget.onClose),
            ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: Text(t('OCR 模型设置', 'OCR model settings')),
                onTap: _busy ? null : _settings),
          ]),
      };

  Widget stylePanel() => DocumentTextStyleDialog(
      initial: _style,
      embedded: true,
      onOpenPanel: widget.onOpenReaderPanel,
      save: (style) async {
        await widget.saveStyle(style);
        if (mounted) {
          setState(() {
            _style = style;
            _controller.paragraphSpacing = style.paragraphSpacing;
          });
        }
      });

  void _resetSelectionGesture() {
    _menuTapTimer?.cancel();
    _selectionTimer?.cancel();
    _mouseLongPressTimer?.cancel();
    _selectionEpoch++;
    _expandingEpoch = null;
    _selectionSession = false;
    _expandInitialSelection = false;
    _pointerOrigin = null;
  }

  void _selectionPointerDown(PointerDownEvent event) {
    _menuTapTimer?.cancel();
    _pointerDownTime = event.timeStamp;
    _selectionTimer?.cancel();
    _mouseLongPressTimer?.cancel();
    _selectionEpoch++;
    _selectionSession = true;
    _expandInitialSelection = event.buttons == kPrimaryButton;
    _pointerKind = event.kind;
    _pointerOrigin = event.position;
    if (event.kind == PointerDeviceKind.mouse && _expandInitialSelection) {
      // Desktop TextField supports double-click/drag but not press-and-hold.
      // Match the ordinary reader without competing with touch gestures.
      _mouseLongPressTimer = Timer(kLongPressTimeout, () {
        if (!mounted || !_expandInitialSelection || _pointerOrigin == null) {
          return;
        }
        final state = _textState;
        if (state == null) return;
        final position =
            state.renderEditable.getPositionForPoint(event.position);
        final word = state.renderEditable.getWordBoundary(position);
        if (!word.isValid || word.isCollapsed) return;
        state.userUpdateTextEditingValue(
            _controller.value.copyWith(
                selection: TextSelection(
                    baseOffset: word.start, extentOffset: word.end)),
            SelectionChangedCause.longPress);
        _queueSelection();
      });
    }
  }

  void _selectionPointerMove(PointerMoveEvent event) {
    // A deliberate drag owns its exact range. Handle overlays live outside
    // this Listener, so dragging a handle never arms expansion again.
    if (_pointerOrigin != null &&
        (event.position - _pointerOrigin!).distance >
            (_pointerKind == PointerDeviceKind.mouse ? 2 : kTouchSlop)) {
      _expandInitialSelection = false;
      _mouseLongPressTimer?.cancel();
    }
  }

  void _selectionPointerUp(PointerUpEvent event) {
    _mouseLongPressTimer?.cancel();
    final shortTap = _expandInitialSelection &&
        _pointerOrigin != null &&
        (event.position - _pointerOrigin!).distance < kTouchSlop &&
        _pointerDownTime != null &&
        event.timeStamp - _pointerDownTime! < kLongPressTimeout;
    if (shortTap && widget.onOpenReaderMenu != null) {
      _menuTapTimer = Timer(kDoubleTapTimeout, () {
        if (mounted && _controller.selection.isCollapsed) {
          widget.onOpenReaderMenu!();
        }
      });
    }
    _pointerOrigin = null;
    _queueSelection();
  }

  void _queueSelection() {
    _selectionTimer?.cancel();
    _selectionTimer = Timer(const Duration(milliseconds: 80), () {
      unawaited(_settleSelection());
    });
  }

  Future<void> _settleSelection() async {
    final selection = _controller.selection, page = _page;
    final state = _textState;
    if (!mounted ||
        state == null ||
        page == null ||
        !selection.isValid ||
        selection.isCollapsed) {
      _expandInitialSelection = false;
      return;
    }
    final epoch = _selectionEpoch, generation = _generation;
    if (_expandingEpoch == epoch) return;
    if (_expandInitialSelection) {
      // Consume before awaiting: late native results must not undo a user's
      // next gesture, a moved handle, or a restored annotation range.
      _expandInitialSelection = false;
      _expandingEpoch = epoch;
      final text = _controller.text;
      final start = selection.start == 0
          ? 0
          : text.lastIndexOf('\n', selection.start - 1) + 1;
      final newline = text.indexOf('\n', selection.start);
      final end = newline < 0 ? text.length : newline;
      List<int>? bounds;
      if (Prefs().longPressSelectParagraph) {
        final paragraph = text.substring(start, end);
        final leading = paragraph.length - paragraph.trimLeft().length;
        bounds = [start + leading, start + paragraph.trimRight().length];
      } else {
        final word = await ReaderWordSelection.bounds({
          'text': text.substring(start, end),
          'offset': selection.start - start,
          'locale': Localizations.localeOf(context).toLanguageTag(),
        });
        if (word != null) bounds = [start + word[0], start + word[1]];
      }
      if (_expandingEpoch == epoch) _expandingEpoch = null;
      if (!mounted ||
          epoch != _selectionEpoch ||
          generation != _generation ||
          selection != _controller.selection) {
        return;
      }
      // Never shrink a native word/drag range into a smaller token.
      if (bounds != null &&
          bounds[0] <= selection.start &&
          bounds[1] >= selection.end &&
          bounds[0] < bounds[1]) {
        final expanded = selection.baseOffset <= selection.extentOffset
            ? TextSelection(baseOffset: bounds[0], extentOffset: bounds[1])
            : TextSelection(baseOffset: bounds[1], extentOffset: bounds[0]);
        state.userUpdateTextEditingValue(
            _controller.value.copyWith(selection: expanded),
            _pointerKind == PointerDeviceKind.mouse
                ? SelectionChangedCause.tap
                : SelectionChangedCause.longPress);
        _selectionTimer?.cancel();
      }
    }
    // Wait for the expanded range's layout before reading global anchors.
    final settled = _controller.selection;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _generation ||
          settled != _controller.selection) {
        return;
      }
      _publishSelection(state);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Widget _selectionMenu(BuildContext context, EditableTextState state) {
    if (_expandingEpoch == _selectionEpoch) return const SizedBox.shrink();
    if (_expandInitialSelection) {
      _queueSelection();
    } else {
      _publishSelection(state);
    }
    return const SizedBox.shrink();
  }

  void _publishSelection(EditableTextState state) {
    _editable = state;
    final selection = _controller.selection, page = _page;
    if (page == null || !selection.isValid || selection.isCollapsed) {
      return;
    }
    final anchor = page.anchor(selection.start, selection.end);
    final id = anchor.encode();
    final primary = state.contextMenuAnchors.primaryAnchor;
    final secondary = state.contextMenuAnchors.secondaryAnchor ?? primary;
    if (_shownSelection != id) {
      _shownSelection = id;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted ||
            _controller.selection != selection ||
            _page != page ||
            _shownSelection != id) {
          return;
        }
        final ids = _notes
            .where((note) {
              final saved = DocumentReflowAnchor.parse(note.cfi);
              return saved != null &&
                  saved.matches(page) &&
                  saved.start < selection.end &&
                  saved.end > selection.start;
            })
            .map((note) => note.id)
            .whereType<int>()
            .toList();
        final contextText = page.text.substring(
            (selection.start - 800).clamp(0, page.text.length),
            (selection.end + 800).clamp(0, page.text.length));
        await widget.onSelection(anchor, selection.textInside(page.text),
            contextText, Rect.fromPoints(primary, secondary).inflate(4), ids);
      });
    }
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: Prefs(), builder: (context, _) => _buildReader(context));
  }

  Widget _buildReader(BuildContext context) {
    Color parse(String value, Color fallback) =>
        Color(int.tryParse(value.replaceFirst('#', ''), radix: 16) ??
            fallback.toARGB32());
    final theme = readingThemeForDisplay(Prefs(),
        isDarkMode: Theme.of(context).brightness == Brightness.dark);
    final foreground =
        parse(theme.textColor, Theme.of(context).colorScheme.onSurface);
    return DocumentReaderSurface(
      readerContentOnly: widget.onOpenReaderMenu != null,
      hideHeader: widget.readerMenuVisible,
      onBack: widget.readerMenuVisible ? closeMenu : widget.onClose,
      key: _surfaceKey,
      brightness: widget.brightness,
      style: stylePanel(),
      actions: widget.readerActions,
      extraMenus: {'search': _readerPanel('search')},
      onMenuOpened: () {
        widget.clearMenu();
        clearSelection();
      },
      header: Row(children: [
        TextButton.icon(
            key: const ValueKey('reflow-original'),
            onPressed: widget.onClose,
            icon: const Icon(Icons.arrow_back),
            label: Text(t('原页', 'Original'))),
        Expanded(
            child: DropdownButtonHideUnderline(
                child: DropdownButton<bool>(
                    key: const ValueKey('reflow-mode'),
                    value: _forceOcr,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                          value: false,
                          child: Text(t('文字重排', 'Reflow text'),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(
                          value: true,
                          child: Text(t('OCR 重排', 'OCR reflow'),
                              maxLines: 1, overflow: TextOverflow.ellipsis))
                    ],
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value != null && value != _forceOcr) {
                              unawaited(setMode(value));
                            }
                          }))),
        if (widget.onOpenReaderMenu == null)
          PopupMenuButton<String>(
            key: const ValueKey('reflow-more'),
            tooltip: t('更多阅读功能', 'More reading tools'),
            icon: const Icon(Icons.more_vert),
            enabled: !_busy && _page != null,
            onSelected: _action,
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'search', child: Text(t('本页搜索', 'Search this page'))),
              PopupMenuItem(
                  value: 'copy',
                  child: Text(t('复制选中内容 / 本页', 'Copy selection / page'))),
              if (widget.onQuery != null) ...[
                PopupMenuItem(
                    value: 'query', child: Text(t('综合查询', 'Look up'))),
                PopupMenuItem(
                    value: 'translate', child: Text(t('翻译', 'Translate'))),
              ],
              if (widget.onAiDraft != null)
                PopupMenuItem(value: 'ai', child: Text(t('AI 对话', 'AI chat'))),
              if (widget.onBookmark != null)
                PopupMenuItem(
                    value: 'bookmark', child: Text(t('添加书签', 'Add bookmark'))),
            ],
          ),
      ]),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpenReaderMenu,
        child: Column(children: [
          if (_busy)
            EinkStaticIndicator(
                child: LinearProgressIndicator(value: _progress)),
          Expanded(
              child: _page == null
                  ? Center(
                      child: _busy
                          ? const EinkStaticIndicator(
                              child: CircularProgressIndicator())
                          : Text(t('等待本页文字', 'Waiting for page text'),
                              style: TextStyle(color: foreground)))
                  : SingleChildScrollView(
                      controller: _scroll,
                      padding: EdgeInsets.symmetric(
                          horizontal: _style.margin,
                          vertical: _style.verticalMargin),
                      child: Listener(
                          onPointerDown: _selectionPointerDown,
                          onPointerMove: _selectionPointerMove,
                          onPointerUp: _selectionPointerUp,
                          onPointerCancel: (_) => _resetSelectionGesture(),
                          child: KeyedSubtree(
                              key: _textFieldKey,
                              child: TextField(
                                key: const ValueKey('reflow-text'),
                                controller: _controller,
                                focusNode: _focus,
                                readOnly: true,
                                maxLines: null,
                                showCursor: false,
                                enableSuggestions: false,
                                style: _style.textStyle
                                    .copyWith(color: foreground),
                                textAlign: _style.alignment,
                                decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isCollapsed: true,
                                    contentPadding: EdgeInsets.zero),
                                contextMenuBuilder: _selectionMenu,
                                onTapOutside: (_) {},
                              ))))),
          if (_needsModel || _error != null)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                    _error ??
                        t('本页需要 OCR，请先在模型设置中下载模型。识别在本机完成。',
                            'This page needs OCR. Download a model in settings; recognition runs locally.'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: foreground))),
        ]),
      ),
      tools: _readerPanel('tools'),
      navigation: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            IconButton(
                key: const ValueKey('reflow-previous'),
                tooltip: t('上一原页', 'Previous original page'),
                onPressed: !_busy && (_navigationPage ?? 0) > 0
                    ? () => turnOriginalPage(-1)
                    : null,
                icon: const Icon(Icons.chevron_left)),
            Tooltip(
                message: t('跳转原书页码', 'Go to original page'),
                child: TextButton(
                    onPressed: _busy || _total == 0 ? null : _jumpToPage,
                    child: Text('${(_navigationPage ?? 0) + 1} / $_total'))),
            IconButton(
                key: const ValueKey('reflow-next'),
                tooltip: t('下一原页', 'Next original page'),
                onPressed: !_busy &&
                        _navigationPage != null &&
                        _navigationPage! + 1 < _total
                    ? () => turnOriginalPage(1)
                    : null,
                icon: const Icon(Icons.chevron_right)),
            if (_busy)
              TextButton(
                  onPressed: () {
                    _cancel?.cancel();
                    widget.cancelRender();
                  },
                  child: Text(t('停止', 'Stop'))),
            if (_needsModel && !_busy)
              TextButton(
                  onPressed: _settings,
                  child: Text(t('OCR 模型设置', 'OCR model settings'))),
            if (!_busy && (_error != null || _page == null))
              TextButton(
                  onPressed: () => _load(
                      _requestedPage ?? _page?.page ?? widget.anchor?.page),
                  child: Text(t('重试', 'Retry'))),
          ]),
    );
  }
}

class _ReflowTextController extends TextEditingController {
  double paragraphSpacing = 1;
  DocumentReflowPage? page;
  List<BookNote> notes = [];
  void setMarks(DocumentReflowPage? value, List<BookNote> marks) {
    page = value;
    notes = marks;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final marks = <(DocumentReflowAnchor, BookNote)>[];
    if (page != null && page!.text == text) {
      for (final note in notes) {
        final anchor = DocumentReflowAnchor.parse(note.cfi);
        if (anchor != null &&
            anchor.matches(page!) &&
            (note.type == 'highlight' || note.type == 'underline')) {
          marks.add((anchor, note));
        }
      }
    }
    final edges = {
      0,
      text.length,
      for (final mark in marks) ...[mark.$1.start, mark.$1.end],
      for (final match in RegExp(r'\n\n').allMatches(text)) ...[
        match.start + 1,
        match.end
      ]
    }.toList()
      ..sort();
    return TextSpan(style: style, children: [
      for (var i = 0; i < edges.length - 1; i++)
        TextSpan(
            text: text.substring(edges[i], edges[i + 1]),
            style: _styleAt(edges[i], marks).merge(edges[i] > 0 &&
                    text[edges[i] - 1] == '\n' &&
                    text[edges[i]] == '\n'
                ? TextStyle(
                    height: paragraphSpacing == 0 ? .01 : paragraphSpacing)
                : null))
    ]);
  }

  TextStyle _styleAt(int offset, List<(DocumentReflowAnchor, BookNote)> marks) {
    Color? background, underline;
    for (final (anchor, note) in marks) {
      if (offset < anchor.start || offset >= anchor.end) continue;
      final color = Color(
          int.tryParse('ff${note.color.replaceFirst('#', '')}', radix: 16) ??
              0xffffff00);
      if (note.type == 'highlight') background = color.withValues(alpha: .35);
      if (note.type == 'underline') underline = color;
    }
    return TextStyle(
        backgroundColor: background,
        decoration: underline == null ? null : TextDecoration.underline,
        decorationColor: underline);
  }
}
