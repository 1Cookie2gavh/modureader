import 'ocr_precache_settings.dart';
import 'widget_title.dart';
import 'document_saved_text_actions.dart';
import 'package:anx_reader/service/ocr/document_reflow_store.dart';
import 'package:anx_reader/utils/app_motion.dart';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/service/book_player/document_layout_store.dart';
import 'package:anx_reader/models/document_page_layout.dart';
import 'package:anx_reader/l10n/modu_strings.dart';
import 'package:anx_reader/page/book_player/epub_player.dart';
import 'package:anx_reader/widgets/reading_page/pdf_region_preview.dart';
import 'package:anx_reader/widgets/reading_page/pdf_reading_controls.dart';
import 'package:flutter/material.dart';
import 'package:anx_reader/widgets/reading_page/document_panel_widgets.dart';
import 'eink_refresh_controls.dart';
import 'reader_settings_scroll_view.dart';

/// Quick controls for fixed-page documents, not the text-book style settings.
class DocumentStyleWidget extends StatefulWidget {
  const DocumentStyleWidget(
      {super.key,
      required this.player,
      this.openReflow,
      this.comparison = false,
      this.onComparisonChanged,
      this.textOnly = false,
      this.openExtraction});
  final EpubPlayerState player;
  final void Function(bool forceOcr)? openReflow;
  final bool comparison;
  final ValueChanged<bool>? onComparisonChanged;
  final bool textOnly;
  final VoidCallback? openExtraction;

  @override
  State<DocumentStyleWidget> createState() => _DocumentStyleWidgetState();
}

class _DocumentStyleWidgetState extends State<DocumentStyleWidget> {
  bool _watermarkAvailable = false;
  Listenable? _documentMode;
  bool _savedTextBusy = false;

  Future<void> _exportSavedText() async {
    if (_savedTextBusy) return;
    setState(() => _savedTextBusy = true);
    try {
      final store = DocumentReflowStore(widget.player.cssBookKey);
      await exportSavedDocumentText(context, store);
    } finally {
      if (mounted) setState(() => _savedTextBusy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final player = widget.player;
    _documentMode = player.documentReadingMode;
    _documentMode?.addListener(_documentModeChanged);
    if (player.isPdfDocument == true) {
      player.pdfRegionInfo(null).then((info) {
        if (mounted) {
          setState(() => _watermarkAvailable =
              (info['watermarks'] as List?)?.isNotEmpty == true);
        }
      }).catchError((_) {});
    }
  }

  void _documentModeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _documentMode?.removeListener(_documentModeChanged);
    super.dispose();
  }

  Future<void> _openPdfPreview({bool editLayout = false}) async {
    final player = widget.player;
    await player.pauseDocumentOcrCache();
    if (!mounted) {
      player.resumeDocumentOcrCache();
      return;
    }
    try {
      await showDialog<DocumentLayoutConfig>(
        animationStyle: AppMotion.style,
        context: context,
        builder: (_) => PdfRegionPreview(
          startWithLayoutEditor: editLayout,
          panelReading: player.pdfPanelReading,
          setPanelReading: player.setPdfPanelReading,
          info: player.pdfRegionInfo,
          initialLayout:
              DocumentLayoutStore(Prefs().prefs).read(player.cssBookKey),
          saveLayout: player.savePdfLayout,
          render: player.renderPdfRegion,
          cancelRender: () => player.cancelPdfRegionRender(),
          close: () => player.cancelPdfRegionRender(close: true),
          initialEnhancement: player.pdfReadingView.enhancement,
          saveEnhancement: (value) => player.setPdfReadingView(
              player.pdfReadingView.copyWith(enhancement: value)),
        ),
      );
    } finally {
      player.resumeDocumentOcrCache();
    }
    if (mounted) setState(() {});
  }

  Future<void> _openEpubImages({bool editLayout = false}) async {
    final player = widget.player;
    await player.pauseDocumentOcrCache();
    if (!mounted) {
      player.resumeDocumentOcrCache();
      return;
    }
    try {
      await showDialog<DocumentLayoutConfig>(
          animationStyle: AppMotion.style,
          context: context,
          builder: (_) => PdfRegionPreview(
                imageEpub: true,
                startWithLayoutEditor: editLayout,
                panelReading: player.pdfPanelReading,
                setPanelReading: player.setPdfPanelReading,
                info: player.epubImageInfo,
                initialLayout:
                    DocumentLayoutStore(Prefs().prefs).read(player.cssBookKey),
                saveLayout: player.savePdfLayout,
                initialEnhancement: player.pdfReadingView.enhancement,
                saveEnhancement: (value) => player.setPdfReadingView(
                    player.pdfReadingView.copyWith(enhancement: value)),
                render: (request) =>
                    player.renderPdfRegion({...request, 'source': 'epub'}),
                cancelRender: () => player.cancelEpubImageRender(),
                close: () => player.cancelEpubImageRender(close: true),
              ));
    } finally {
      player.resumeDocumentOcrCache();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.textOnly) {
      String text(String zh, String en) => ModuStrings.text(context, zh, en);
      return DocumentPanelTheme(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ReaderSettingsScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widgetTitle(text('文字', 'Text'), null),
            ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(text('文字重排', 'Reflow text')),
                subtitle: Text(text('优先使用文字层，无文字时自动 OCR',
                    'Use embedded text, or OCR when no text is available')),
                onTap: widget.openReflow == null
                    ? null
                    : () => widget.openReflow!(false)),
            if (widget.onComparisonChanged != null)
              SwitchListTile(
                  key: const ValueKey('document-comparison-switch'),
                  title: Text(text('原页对照重排', 'Compare original and reflow')),
                  subtitle: Text(text('竖屏上下，横屏左右',
                      'Top/bottom in portrait, side by side in landscape')),
                  value: widget.comparison,
                  onChanged: widget.onComparisonChanged),
            ListTile(
                leading: const Icon(Icons.crop_free),
                title: Text(
                    text('框选提取与连续识别', 'Region extraction and continuous OCR')),
                subtitle: Text(text('保留识别缓存、编辑和导出 TXT',
                    'Includes cached results, editing and TXT export')),
                onTap: widget.openExtraction),
            OcrPrecacheSettings(cache: widget.player.ocrPrecache),
            ListTile(
                key: const ValueKey('export-saved-txt'),
                leading: const Icon(Icons.file_download_outlined),
                title: Text(text('导出本书已保存文字 TXT', 'Export saved pages as TXT')),
                subtitle: Text(text('按原始页码排列，优先导出编辑结果',
                    'Original page order; edited text takes priority')),
                onTap: _savedTextBusy ? null : _exportSavedText),
          ],
        )),
      ));
    }
    final cropControls = ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.crop),
      trailing: const Icon(Icons.chevron_right),
      onTap: widget.player.isImageEpub
          ? () => _openEpubImages(editLayout: true)
          : () => _openPdfPreview(editLayout: true),
      title: Text(ModuStrings.text(
          context,
          widget.player.isImageEpub ? '扫描图片裁边与分格' : 'PDF 裁边与分格',
          widget.player.isImageEpub
              ? 'Scanned image crop and panels'
              : 'PDF crop and panels')),
      subtitle: Text(ModuStrings.text(context, '自动裁边、留白、漫画与论文分栏在独立预览中调整',
          'Auto crop, margins, comics and columns are adjusted in the separate preview')),
    );
    return DocumentPanelTheme(
        child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ReaderSettingsScrollView(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          widgetTitle(ModuStrings.text(context, '页面', 'Page'), null),
          ListenableBuilder(
            listenable: Prefs(),
            builder: (context, _) =>
                Prefs().eInkMode && widget.player.supportsDocumentImages
                    ? EinkRefreshControls(
                        supported: widget.player.einkRefresh.supported,
                        refresh: widget.player.refreshEinkScreen)
                    : const SizedBox.shrink(),
          ),
          if (widget.player.supportsDocumentImages == true)
            PdfReadingControls(
              key: ValueKey(widget.player.cssBookKey),
              initial: widget.player.pdfReadingView,
              cropControls: cropControls,
              watermarkAvailable: _watermarkAvailable,
              save: widget.player.setPdfReadingView,
              preview: (request) async {
                final player = widget.player;
                await player.pauseDocumentOcrCache();
                try {
                  final info = await (player.isImageEpub
                      ? player.epubImageInfo(null)
                      : player.pdfRegionInfo(null));
                  return await player.renderPdfRegion({
                    ...request,
                    'page': info['page'],
                    if (player.isImageEpub) 'source': 'epub'
                  });
                } finally {
                  player.resumeDocumentOcrCache();
                }
              },
              cancelPreview: () {
                final player = widget.player;
                if (player.isImageEpub == true) {
                  player.cancelEpubImageRender();
                } else {
                  player.cancelPdfRegionRender();
                }
              },
            ),
        ]),
      ),
    ));
  }
}
