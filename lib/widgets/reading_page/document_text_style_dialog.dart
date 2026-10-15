import 'package:flutter/material.dart';
import 'package:anx_reader/l10n/modu_strings.dart';
import 'package:anx_reader/service/ocr/document_text_style.dart';
import 'document_panel_widgets.dart';
import 'reader_popup.dart';
import 'reader_settings_scroll_view.dart';

class DocumentTextStyleDialog extends StatefulWidget {
  const DocumentTextStyleDialog(
      {super.key, required this.initial, this.save, this.embedded = false});
  final DocumentTextStyle initial;
  final Future<void> Function(DocumentTextStyle)? save;
  final bool embedded;
  @override
  State<DocumentTextStyleDialog> createState() =>
      _DocumentTextStyleDialogState();
}

class _DocumentTextStyleDialogState extends State<DocumentTextStyleDialog> {
  late DocumentTextStyle _style = widget.initial;
  bool _saving = false, _failed = false;
  String t(String zh, String en) => ModuStrings.text(context, zh, en);
  Future<void> _apply() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.save?.call(_style);
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  Widget _slider(String key, String label, double value, double min, double max,
          int divisions, {int decimals = 1}) =>
      DocumentControlRow(
          label: '$label  ${value.toStringAsFixed(decimals)}',
          child: Slider(
              key: ValueKey('ocr-style-$key'),
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: value.toStringAsFixed(decimals),
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _style = _style.withValue(key, v)),
              onChangeEnd: _saving ? null : (_) => _apply()));
  @override
  Widget build(BuildContext context) {
    final content = _content(context);
    if (widget.embedded) return content;
    return PopScope(
        canPop: !_saving,
        child: Dialog(
          insetPadding: const EdgeInsets.all(12),
          clipBehavior: Clip.antiAlias,
          constraints: ReaderPopup.constraints(context),
          child: SizedBox(
            width: double.infinity,
            height: ReaderPopup.height(context),
            child: content,
          ),
        ));
  }

  Widget _content(BuildContext context) => DocumentPanelTheme(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                widget.embedded
                    ? t('样式', 'Style')
                    : t('OCR 文字样式', 'OCR text style'),
                style: Theme.of(context).textTheme.titleLarge),
            Flexible(
                child: ReaderSettingsScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                  Text(t('仅用于本书识别后的文字和重排预览，不改变原版 PDF 或其他书籍。',
                      'Only affects this book’s extracted text and reflow preview, not the original PDF or other books.')),
                  Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: 12, horizontal: _style.margin),
                      child: Text(
                          t('文字识别之后，可以按照自己的阅读习惯调整样式。\n让阅读更清晰、更舒适。',
                              'Adjust the recognized text to suit your reading preferences.\nMake reading clearer and more comfortable.'),
                          key: const ValueKey('ocr-style-preview'),
                          style: _style.textStyle,
                          textAlign: _style.alignment)),
                  DropdownButtonFormField<bool>(
                      isExpanded: true,
                      initialValue: _style.serif,
                      key: ValueKey(_style.serif),
                      decoration: InputDecoration(labelText: t('字体', 'Font')),
                      items: [
                        DropdownMenuItem(
                            value: false,
                            child: Text(t('系统字体', 'System font'))),
                        DropdownMenuItem(
                            value: true,
                            child: Text(t('思源宋体', 'Source Han Serif')))
                      ],
                      onChanged: _saving
                          ? null
                          : (v) {
                              setState(() => _style =
                                  _style.withValue('serif', v ?? false));
                              _apply();
                            }),
                  _slider(
                      'size', t('字体大小', 'Font size'), _style.size, 14, 40, 26,
                      decimals: 0),
                  _slider('weight', t('字体粗细', 'Font weight'), _style.weight, .5,
                      2, 15),
                  Text(
                      t('实际粗细取决于字体支持；思源宋体内置常规和粗体。',
                          'Weight depends on the font; Source Han Serif includes regular and bold faces.'),
                      style: Theme.of(context).textTheme.bodySmall),
                  _slider('height', t('行间距', 'Line spacing'), _style.height,
                      1.2, 2.4, 12),
                  _slider('spacing', t('字间距', 'Letter spacing'), _style.spacing,
                      0, 6, 12),
                  _slider('margin', t('侧边距', 'Side margins'), _style.margin, 0,
                      60, 30,
                      decimals: 0),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('两端对齐', 'Justify text')),
                      value: _style.justify,
                      onChanged: _saving
                          ? null
                          : (v) {
                              setState(() =>
                                  _style = _style.withValue('justify', v));
                              _apply();
                            }),
                  if (_failed)
                    Text(t('保存失败，请重试', 'Could not save. Please retry.'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                ]))),
            Wrap(spacing: 8, alignment: WrapAlignment.end, children: [
              TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() => _style = const DocumentTextStyle());
                          _apply();
                        },
                  child: Text(t('恢复默认', 'Reset'))),
              if (!widget.embedded)
                TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(t('关闭', 'Close'))),
              if (_failed)
                TextButton(
                    onPressed: _saving ? null : _apply,
                    child: Text(t('重试', 'Retry'))),
            ]),
          ])));
}
