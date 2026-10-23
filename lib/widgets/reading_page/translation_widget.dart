import 'package:anx_reader/utils/app_motion.dart';
import 'package:anx_reader/service/translate/classical_translation.dart';
import 'package:anx_reader/widgets/settings/classical_translation_settings.dart';
import 'package:anx_reader/widgets/reading_page/classical_translation_icon.dart';
import 'package:anx_reader/page/settings_page/translate.dart';
import 'package:anx_reader/page/settings_page/settings_page.dart';
import 'reader_menu_group.dart';
import 'package:anx_reader/l10n/modu_strings.dart';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/enums/lang_list.dart';
import 'package:anx_reader/enums/translation_mode.dart';
import 'package:anx_reader/page/book_player/epub_player.dart';
import 'package:anx_reader/service/translate/index.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/common/anx_segmented_button.dart';
import 'package:flutter/material.dart';

class TranslationWidget extends StatefulWidget {
  const TranslationWidget({
    super.key,
    required this.bookId,
    required this.epubPlayerKey,
    this.pageTranslationMode,
    this.onTranslatePage,
    this.onStopPageTranslation,
    this.classical = false,
  });

  final int bookId;
  final bool classical;
  final GlobalKey<EpubPlayerState> epubPlayerKey;
  final ValueNotifier<TranslationModeEnum>? pageTranslationMode;
  final Future<void> Function(TranslationModeEnum mode, bool force)?
      onTranslatePage;
  final VoidCallback? onStopPageTranslation;

  @override
  State<TranslationWidget> createState() => _TranslationWidgetState();
}

class _TranslationWidgetState extends State<TranslationWidget> {
  late TranslationModeEnum _displayMode;
  late TranslationModeEnum _activeMode;
  late TranslateService _activeService;
  late LangListEnum _activeTarget;
  bool _translating = false;
  int _operation = 0;
  ValueNotifier<TranslationModeEnum>? _mode;
  String? _error;
  String? _activeClassicalIdentity;

  bool get _isChinese => Localizations.localeOf(context).languageCode == 'zh';

  String _label(String zh, String en) => _isChinese ? zh : en;

  @override
  void initState() {
    super.initState();
    final savedMode = Prefs().getBookTranslationMode(widget.bookId);
    _mode = widget.pageTranslationMode ??
        (widget.classical
            ? widget.epubPlayerKey.currentState?.classicalTranslationMode
            : widget.epubPlayerKey.currentState?.translationMode);
    _activeMode = _mode?.value ?? TranslationModeEnum.off;
    _displayMode =
        (_activeMode != TranslationModeEnum.off ? _activeMode : savedMode) ==
                TranslationModeEnum.translationOnly
            ? TranslationModeEnum.translationOnly
            : TranslationModeEnum.bilingual;
    _activeService = Prefs().fullTextTranslateService;
    _activeClassicalIdentity =
        widget.classical ? ClassicalTranslation.current().identity : null;
    _activeTarget = Prefs().fullTextTranslateTo;
    _mode?.addListener(_syncMode);
  }

  void _syncMode() {
    if (mounted) {
      setState(() => _activeMode = _mode!.value);
    }
  }

  @override
  void dispose() {
    _mode?.removeListener(_syncMode);
    super.dispose();
  }

  Future<void> _showServicePicker() async {
    final selected = await showModalBottomSheet<TranslateService>(
      sheetAnimationStyle: AppMotion.style,
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  ModuStrings.text(context, '翻译引擎', 'Translation engine'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            ReaderMenuGroup(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: RadioGroup<TranslateService>(
                    groupValue: Prefs().fullTextTranslateService,
                    onChanged: (value) => Navigator.pop(context, value),
                    child: Column(children: [
                      for (final service in TranslateService.readAnyValues)
                        RadioListTile<TranslateService>(
                          value: service,
                          title: Text(service.getLabel(context)),
                        ),
                    ]))),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null) return;
    Prefs().translateService = selected;
    Prefs().fullTextTranslateService = selected;
    setState(() => _error = null);
  }

  Future<void> _showLanguagePicker() async {
    final languages = LangListEnum.values
        .where((language) => language != LangListEnum.auto)
        .toList(growable: false);
    final selected = await showModalBottomSheet<LangListEnum>(
      sheetAnimationStyle: AppMotion.style,
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    ModuStrings.text(context, '目标语言', 'Target language'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              Expanded(
                child: ReaderMenuGroup(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: RadioGroup<LangListEnum>(
                        groupValue: Prefs().fullTextTranslateTo,
                        onChanged: (value) => Navigator.pop(context, value),
                        child: ListView.builder(
                          itemCount: languages.length,
                          itemBuilder: (context, index) {
                            final language = languages[index];
                            return RadioListTile<LangListEnum>(
                              value: language,
                              title: Text(language.nativeName),
                            );
                          },
                        ))),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    Prefs().translateFrom = LangListEnum.auto;
    Prefs().fullTextTranslateFrom = LangListEnum.auto;
    Prefs().translateTo = selected;
    Prefs().fullTextTranslateTo = selected;
    setState(() => _error = null);
  }

  Future<void> _translate() async {
    if (_translating) return;
    final player = widget.epubPlayerKey.currentState;
    if (player == null && widget.onTranslatePage == null) return;

    final operation = ++_operation;

    final service = Prefs().fullTextTranslateService;
    final target = Prefs().fullTextTranslateTo;
    final classicalIdentity =
        widget.classical ? ClassicalTranslation.current().identity : null;
    final needsFreshTranslation = _activeMode != TranslationModeEnum.off &&
        (widget.classical
            ? ClassicalTranslation.current().identity !=
                _activeClassicalIdentity
            : service != _activeService || target != _activeTarget);

    setState(() {
      _translating = true;
      _error = null;
    });
    try {
      if (widget.onTranslatePage != null) {
        await widget.onTranslatePage!(
            _displayMode, needsFreshTranslation || _activeMode == _displayMode);
      } else {
        await player!.translateCurrentChapter(
          _displayMode,
          force: needsFreshTranslation || _activeMode == _displayMode,
          classical: widget.classical,
        );
      }
      if (!mounted || operation != _operation) return;
      setState(() {
        _activeMode = _mode?.value ?? TranslationModeEnum.off;
        _activeService = service;
        _activeTarget = target;
        _activeClassicalIdentity = classicalIdentity;
      });
    } catch (error) {
      if (!mounted || operation != _operation) return;
      setState(() => _error = error.toString());
      AnxToast.show(_label('翻译失败：$error', 'Translation failed: $error'));
    } finally {
      if (mounted && operation == _operation) {
        setState(() => _translating = false);
      }
    }
  }

  Future<void> _stopTranslation() async {
    ++_operation;
    setState(() {
      _translating = false;
      _activeMode = TranslationModeEnum.off;
    });
    final player = widget.epubPlayerKey.currentState;
    if (widget.onStopPageTranslation != null) {
      widget.onStopPageTranslation!();
      return;
    }
    if (player == null) return;
    try {
      await player.setTranslationMode(TranslationModeEnum.off);
      Prefs().setBookTranslationMode(widget.bookId, TranslationModeEnum.off);
      if (mounted) {
        setState(() {
          _activeMode = TranslationModeEnum.off;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = Prefs().fullTextTranslateService;
    final target = Prefs().fullTextTranslateTo;
    final settingsChanged = widget.classical
        ? ClassicalTranslation.current().identity != _activeClassicalIdentity
        : service != _activeService || target != _activeTarget;
    final modeChanged = _displayMode != _activeMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              if (widget.classical)
                const ClassicalTranslationIcon()
              else
                const Icon(Icons.translate_outlined),
              Text(
                widget.classical
                    ? ModuStrings.text(context, '文言文翻译', 'Classical Chinese')
                    : ModuStrings.text(context, '阅读翻译', 'Reader translation'),
                style: theme.textTheme.titleMedium,
              ),
              if (_translating || _activeMode != TranslationModeEnum.off)
                TextButton.icon(
                  key: const ValueKey('reader-stop-translation'),
                  onPressed: _stopTranslation,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: Text(
                      ModuStrings.text(context, '停止翻译', 'Stop translation')),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ReaderMenuGroup(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.classical)
                  IgnorePointer(
                      ignoring: _translating,
                      child: ClassicalTranslationSettings(
                        showCredentials: false,
                        onChanged: () => setState(() => _error = null),
                        onConfigure: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => SettingsPageBody(
                                  title: ModuStrings.text(context, '文言文翻译',
                                      'Classical Chinese translation'),
                                  isMobile: true,
                                  sections:
                                      const ClassicalTranslateSetting())));
                          if (mounted) setState(() {});
                        },
                      ))
                else
                  Row(
                    children: [
                      Expanded(
                        child: _ChoiceButton(
                          label: ModuStrings.text(context, '翻译引擎', 'Engine'),
                          value: service.getLabel(context),
                          icon: Icons.translate_outlined,
                          onTap: _translating ? null : _showServicePicker,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChoiceButton(
                          label: ModuStrings.text(
                              context, '目标语言', 'Target language'),
                          value: target.nativeName,
                          icon: Icons.language_outlined,
                          onTap: _translating ? null : _showLanguagePicker,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 14),
                Text(
                  ModuStrings.text(context, '显示方式', 'Display'),
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: AnxSegmentedButton<TranslationModeEnum>(
                    enabled: !_translating,
                    segments: [
                      SegmentButtonItem(
                        label: ModuStrings.text(
                            context, '仅译文', 'Translation only'),
                        value: TranslationModeEnum.translationOnly,
                        icon: const Icon(Icons.g_translate),
                      ),
                      SegmentButtonItem(
                        label: ModuStrings.text(
                            context, '原文 + 译文', 'Original + translation'),
                        value: TranslationModeEnum.bilingual,
                        icon: const Icon(Icons.compare_outlined),
                      ),
                    ],
                    selected: {_displayMode},
                    onSelectionChanged: (value) {
                      setState(() {
                        _displayMode = value.first;
                        _error = null;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _translating ? null : _translate,
              icon: _translating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: EinkStaticIndicator(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : const Icon(Icons.translate),
              label: Text(
                _translating
                    ? ModuStrings.text(context, '翻译中…', 'Translating…')
                    : _activeMode == TranslationModeEnum.off
                        ? ModuStrings.text(
                            context, '翻译当前阅读内容', 'Translate visible content')
                        : settingsChanged
                            ? ModuStrings.text(context, '按新设置重新翻译',
                                'Retranslate with new settings')
                            : modeChanged
                                ? ModuStrings.text(
                                    context, '应用显示方式', 'Apply display mode')
                                : ModuStrings.text(context, '重新翻译当前内容',
                                    'Retranslate current content'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.onTranslatePage != null
                ? ModuStrings.text(
                    context,
                    '仅翻译重排界面的可见段落，滚动时逐段加载。优先使用已保存的编辑稿，否则使用识别文字。翻原书页或停止后恢复原文；译文不会写入 OCR 缓存和笔记。内容会发送给所选翻译引擎。',
                    'Translate visible reflow paragraphs, loading more as you scroll. Saved edits take precedence over recognized text. Turning the source page or stopping restores the original. Translation never overwrites OCR or notes. Text is sent to the selected translation service.')
                : ModuStrings.text(
                    context,
                    '仅在你启动后翻译可见段落，滚动时逐段加载，不会一次发送整章。可随时停止；关闭书籍后停止，重新打开不会自动继续。',
                    'Translate visible paragraphs only after you start; scrolling loads them one at a time. Stop at any time. Closing the book stops translation; reopening never resumes it automatically.'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        alignment: AlignmentDirectional.centerStart,
      ),
      child: Row(
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.expand_more, size: 18),
        ],
      ),
    );
  }
}
