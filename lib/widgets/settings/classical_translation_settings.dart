import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/modu_strings.dart';
import 'package:anx_reader/models/ai_provider.dart';
import 'package:anx_reader/service/translate/classical_translation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:anx_reader/widgets/settings/settings_tile.dart';

class ClassicalTranslationSettings extends StatefulWidget {
  const ClassicalTranslationSettings(
      {super.key,
      this.showCredentials = true,
      this.onChanged,
      this.onConfigure});
  final bool showCredentials;
  final VoidCallback? onChanged;
  final VoidCallback? onConfigure;
  @override
  State<ClassicalTranslationSettings> createState() =>
      _ClassicalTranslationSettingsState();
}

class _ClassicalTranslationSettingsState
    extends State<ClassicalTranslationSettings> {
  final Map<String, TextEditingController> controllers = {};
  final Set<String> revealed = {};
  String? savedStatus;
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String label(String zh, String en) => ModuStrings.text(context, zh, en);
  Widget choice<T>(
          {required Key key,
          required String title,
          required IconData icon,
          required T? value,
          required Map<T, String> options,
          required void Function(T) onChanged,
          String? hint}) =>
      SettingsTile.navigation(
          key: key,
          leading: Icon(icon),
          title: Text(title),
          value: Text(options[value] ?? hint ?? label('未配置', 'Not configured')),
          enabled: options.isNotEmpty,
          onPressed: (_) async {
            final selected = await showDialog<T>(
                context: context,
                builder: (context) =>
                    SimpleDialog(title: Text(title), children: [
                      for (final option in options.entries)
                        SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, option.key),
                            child: Row(children: [
                              Expanded(child: Text(option.value)),
                              if (option.key == value) const Icon(Icons.check)
                            ]))
                    ]));
            if (selected != null && mounted) onChanged(selected);
          });
  void changed() {
    setState(() => savedStatus = null);
    widget.onChanged?.call();
  }

  Widget field(String key, String title, {bool secret = false}) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
          key: ValueKey(key),
          controller: controllers.putIfAbsent(
              key,
              () => TextEditingController(
                  text: Prefs().classicalTranslationConfig[key] ?? '')),
          obscureText: secret && !revealed.contains(key),
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
              labelText: title,
              border: const OutlineInputBorder(),
              suffixIcon: secret
                  ? IconButton(
                      tooltip: label('显示／隐藏密钥', 'Show/hide key'),
                      icon: Icon(revealed.contains(key)
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(() {
                            revealed.contains(key)
                                ? revealed.remove(key)
                                : revealed.add(key);
                          }))
                  : null),
          onChanged: (_) => setState(() => savedStatus = null)));

  void saveCredentials(ClassicalTranslationEngine engine) {
    final keys = engine == ClassicalTranslationEngine.baidu
        ? ['baidu_appid', 'baidu_key']
        : ['microsoft_key', 'microsoft_region'];
    final values = {
      for (final key in keys) key: controllers[key]?.text.trim() ?? ''
    };
    if (engine == ClassicalTranslationEngine.baidu &&
        values.values.any((v) => v.isNotEmpty) &&
        values.values.any((v) => v.isEmpty)) {
      setState(() => savedStatus =
          label('请同时填写 APP ID 和密钥。', 'Enter both APP ID and secret key.'));
      return;
    }
    final region = values['microsoft_region'] ?? '';
    if (region.isNotEmpty && !RegExp(r'^[a-z0-9-]+$').hasMatch(region)) {
      setState(() => savedStatus = label('区域请填写 Azure 区域代码，例如 eastasia。',
          'Use an Azure region code, e.g. eastasia.'));
      return;
    }
    Prefs().classicalTranslationConfig = {
      ...Prefs().classicalTranslationConfig,
      ...values
    };
    setState(() => savedStatus = label('配置已保存，尚未发送翻译请求。',
        'Configuration saved. No translation request sent.'));
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = Prefs();
    final models = <AiProvider>[];
    for (final raw in prefs.getAiProviders()) {
      try {
        final model =
            AiProvider.fromJson(Map<String, dynamic>.from(raw as Map));
        if (model.enabled &&
            model.hasValidKey &&
            model.model.trim().isNotEmpty) {
          models.add(model);
        }
      } catch (_) {
        /* Malformed legacy providers are repaired in AI settings. */
      }
    }
    final engine = prefs.classicalTranslationEngine;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          choice<ClassicalTranslationDirection>(
              key: ValueKey(
                  'classical-direction-${prefs.classicalTranslationDirection.name}'),
              value: prefs.classicalTranslationDirection,
              icon: Icons.swap_horiz,
              title: label('翻译方向', 'Translation direction'),
              options: {
                ClassicalTranslationDirection.toModern:
                    label('文言文 → 现代汉语', 'Classical → Modern Chinese'),
                ClassicalTranslationDirection.toClassical:
                    label('现代汉语 → 文言文', 'Modern → Classical Chinese'),
              },
              onChanged: (value) {
                prefs.classicalTranslationDirection = value;
                changed();
              }),
          choice<ClassicalTranslationEngine>(
              key: ValueKey('classical-engine-${engine.name}'),
              value: engine,
              icon: Icons.translate_outlined,
              title: label('翻译引擎', 'Translation engine'),
              options: {
                ClassicalTranslationEngine.ai: 'AI',
                ClassicalTranslationEngine.baidu:
                    label('百度翻译', 'Baidu Translate'),
                ClassicalTranslationEngine.microsoft: 'Microsoft Translator',
              },
              onChanged: (value) {
                prefs.classicalTranslationEngine = value;
                changed();
              }),
          if (engine == ClassicalTranslationEngine.ai) ...[
            choice<String>(
                key: ValueKey(
                    'classical-model-${prefs.classicalTranslationAiService}'),
                value: models
                        .any((m) => m.id == prefs.classicalTranslationAiService)
                    ? prefs.classicalTranslationAiService
                    : null,
                icon: Icons.smart_toy_outlined,
                title: label('AI 模型', 'AI model'),
                hint:
                    label('请先在 AI 设置中配置模型', 'Configure a model in AI settings'),
                options: {
                  for (final m in models) m.id: '${m.title} · ${m.model}'
                },
                onChanged: (value) {
                  prefs.classicalTranslationAiService = value;
                  changed();
                }),
          ],
          if (widget.showCredentials &&
              engine == ClassicalTranslationEngine.baidu) ...[
            field('baidu_appid', 'APP ID'),
            field('baidu_key', label('密钥', 'Secret key'), secret: true),
            const SizedBox(height: 8),
            Text(label(
                '在百度翻译开放平台开通「通用文本翻译」，填写该服务的 APP ID 和密钥（不是百度智能云 API Key）。按账户套餐计费／抵扣免费额度；应用按标准版速率逐段请求。',
                'Enable General Text Translation on Baidu Translate and enter its APP ID and secret (not a Baidu AI Cloud API key). Your account quota and billing apply; requests are paced for the standard tier.')),
            TextButton(
                onPressed: () => launchUrl(
                    Uri.parse('https://fanyi-api.baidu.com/doc_bd/21'),
                    mode: LaunchMode.externalApplication),
                child: Text(label('百度官方接入文档', 'Baidu API documentation'))),
          ],
          if (widget.showCredentials &&
              engine == ClassicalTranslationEngine.microsoft) ...[
            field(
                'microsoft_key',
                label(
                    '订阅密钥（Key 1 或 Key 2）', 'Subscription key (Key 1 or Key 2)'),
                secret: true),
            field('microsoft_region',
                label('资源区域（例如 eastasia）', 'Resource region (e.g. eastasia)')),
            const SizedBox(height: 8),
            Text(label(
                '在 Azure 创建 Translator 资源，在「密钥和终结点」复制密钥和区域。区域资源／多服务资源必须填对应区域；全局单服务资源可留空或填 global。使用官方全球文本翻译端点；免费额度取决于所选套餐，不会自动切换付费套餐。',
                'Create an Azure Translator resource; copy its key and region from Keys and Endpoint. Regional/multi-service resources require their region; global single-service resources can leave it blank or use global. Uses the official global text endpoint. Free allowance depends on your tier; the app does not change your plan.')),
            TextButton(
                onPressed: () => launchUrl(
                    Uri.parse(
                        'https://learn.microsoft.com/azure/ai-services/translator/text-translation/reference/authentication'),
                    mode: LaunchMode.externalApplication),
                child: Text(label(
                    '微软官方接入文档', 'Microsoft authentication documentation'))),
          ],
          if (widget.showCredentials &&
              engine != ClassicalTranslationEngine.ai) ...[
            FilledButton.icon(
                key: const ValueKey('save-classical-credentials'),
                onPressed: () => saveCredentials(engine),
                icon: const Icon(Icons.save_outlined),
                label: Text(label('保存配置', 'Save configuration'))),
            if (savedStatus != null) Text(savedStatus!),
          ],
          if (!widget.showCredentials && widget.onConfigure != null)
            TextButton.icon(
                onPressed: widget.onConfigure,
                icon: const Icon(Icons.settings_outlined),
                label: Text(label('配置翻译服务', 'Configure translation service'))),
          const SizedBox(height: 8),
          Text(
              label('仅手动启动后发送待译内容；修改设置不会自动发起请求。',
                  'Text is sent only after you start translation. Changing settings never sends a request.'),
              style: Theme.of(context).textTheme.bodySmall),
        ]);
  }
}
