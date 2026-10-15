import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/modu_strings.dart';
import 'reader_popup.dart';
import 'reader_settings_scroll_view.dart';

/// Ebook chrome over the existing document reader. Menus must not resize the
/// text viewport, invalidate its selection, or restart page recognition.
class DocumentReaderSurface extends StatefulWidget {
  const DocumentReaderSurface(
      {super.key,
      required this.header,
      required this.body,
      required this.navigation,
      required this.tools,
      required this.style,
      this.actions = const [],
      this.brightness,
      this.narration,
      this.onMenuOpened,
      this.onBack});
  final Widget header, body, navigation, tools, style;
  final List<Widget> actions;
  final Widget? brightness, narration;
  final VoidCallback? onMenuOpened, onBack;

  @override
  State<DocumentReaderSurface> createState() => DocumentReaderSurfaceState();
}

class DocumentReaderSurfaceState extends State<DocumentReaderSurface> {
  String? _menu;
  bool get menuIsOpen => _menu != null;
  void closeMenu() {
    if (mounted) setState(() => _menu = null);
  }

  void openMenu(String menu, {bool toggle = true}) {
    widget.onMenuOpened?.call();
    setState(() => _menu = toggle && _menu == menu ? null : menu);
  }

  @override
  void didUpdateWidget(covariant DocumentReaderSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((_menu == 'narration' && widget.narration == null) ||
        (_menu == 'brightness' && widget.brightness == null)) {
      _menu = null;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Prefs(),
      builder: (context, _) {
        final theme = Prefs().readTheme;
        Color color(String value, Color fallback) =>
            Color(int.tryParse(value.replaceFirst('#', ''), radix: 16) ??
                fallback.toARGB32());
        final background = Prefs().eInkMode
            ? Colors.white
            : color(
                theme.backgroundColor, Theme.of(context).colorScheme.surface);
        final foreground = Prefs().eInkMode
            ? Colors.black
            : color(theme.textColor, Theme.of(context).colorScheme.onSurface);
        Widget readingColors(Widget child) => Theme(
            data: Theme.of(context).copyWith(
                textTheme: Theme.of(context)
                    .textTheme
                    .apply(bodyColor: foreground, displayColor: foreground),
                iconTheme: IconThemeData(color: foreground),
                colorScheme: Theme.of(context)
                    .colorScheme
                    .copyWith(surface: background, onSurface: foreground)),
            child: DefaultTextStyle.merge(
                style: TextStyle(color: foreground), child: child));
        String label(String menu, String zh, String en) => _menu == menu
            ? ModuStrings.text(context, '收起菜单', 'Hide menu')
            : ModuStrings.text(context, zh, en);
        final toolbar = Wrap(alignment: WrapAlignment.spaceAround, children: [
          IconButton(
              key: const ValueKey('document-style-menu'),
              tooltip: label('style', '样式', 'Style'),
              isSelected: _menu == 'style',
              icon: Icon(_menu == 'style'
                  ? Icons.keyboard_arrow_down
                  : Icons.color_lens),
              onPressed: () => openMenu('style')),
          ...widget.actions,
          if (widget.brightness != null)
            IconButton(
                tooltip: label('brightness', '亮度 / 配色', 'Brightness / colors'),
                icon: const Icon(Icons.brightness_6_outlined),
                onPressed: () => openMenu('brightness')),
          if (widget.narration != null)
            IconButton(
                tooltip: label('narration', '朗读', 'Read aloud'),
                icon: const Icon(Icons.headphones),
                onPressed: () => openMenu('narration')),
          IconButton(
              key: const ValueKey('document-tools-menu'),
              tooltip: label('tools', '识别 / 原页', 'Recognition / original page'),
              isSelected: _menu == 'tools',
              icon: const Icon(Icons.document_scanner_outlined),
              onPressed: () => openMenu('tools')),
        ]);
        return PopScope(
            canPop: _menu == null && widget.onBack == null,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (_menu != null) {
                closeMenu();
              } else {
                widget.onBack?.call();
              }
            },
            child: Material(
                color: background,
                child: SafeArea(
                    child: LayoutBuilder(
                        builder: (context, viewport) => Column(children: [
                              Expanded(
                                  child: LayoutBuilder(
                                      builder: (context, bodySpace) =>
                                          Stack(children: [
                                            Column(children: [
                                              Visibility(
                                                  visible: _menu == null,
                                                  maintainState: true,
                                                  maintainAnimation: true,
                                                  maintainSize: true,
                                                  child: readingColors(
                                                      widget.header)),
                                              Expanded(
                                                  child: DefaultTextStyle.merge(
                                                      style: TextStyle(
                                                          color: foreground),
                                                      child: widget.body)),
                                            ]),
                                            if (_menu != null) ...[
                                              Positioned.fill(
                                                  child: GestureDetector(
                                                      onTap: closeMenu,
                                                      behavior: HitTestBehavior
                                                          .opaque,
                                                      child: ColoredBox(
                                                          color: Colors.black
                                                              .withAlpha(30)))),
                                              Align(
                                                  alignment:
                                                      Alignment.bottomCenter,
                                                  child: BottomSheet(
                                                      enableDrag: false,
                                                      onClosing: closeMenu,
                                                      constraints: ReaderPopup
                                                          .constraints(context),
                                                      builder: (context) => ConstrainedBox(
                                                          constraints: BoxConstraints(maxHeight: math.max(0, ReaderPopup.height(context) - (viewport.maxHeight - bodySpace.maxHeight))),
                                                          child: ReaderQuickStylePanel(
                                                              content: Padding(
                                                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                                                                  child: _menu == 'style'
                                                                      ? widget.style
                                                                      : ReaderSettingsScrollView(
                                                                          child: _menu == 'brightness'
                                                                              ? widget.brightness!
                                                                              : _menu == 'narration'
                                                                                  ? widget.narration!
                                                                                  : widget.tools)),
                                                              toolbar: const SizedBox.shrink())))),
                                            ],
                                          ]))),
                              Material(
                                  color: _menu == null
                                      ? background
                                      : Theme.of(context).colorScheme.surface,
                                  child: ConstrainedBox(
                                      constraints:
                                          ReaderPopup.constraints(context),
                                      child: _menu == null
                                          ? readingColors(Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                  widget.navigation,
                                                  toolbar
                                                ]))
                                          : Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                  widget.navigation,
                                                  toolbar
                                                ]))),
                            ])))));
      });
}
