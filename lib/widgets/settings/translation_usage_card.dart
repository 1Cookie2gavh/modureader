import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/modu_strings.dart';
import 'package:anx_reader/service/translate/translation_usage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class TranslationUsageCard extends StatefulWidget {
  const TranslationUsageCard(
      {super.key, required this.engine, required this.config});
  final String engine;
  final Map<String, String> config;
  @override
  State<TranslationUsageCard> createState() => _TranslationUsageCardState();
}

class _TranslationUsageCardState extends State<TranslationUsageCard> {
  String label(String zh, String en) => ModuStrings.text(context, zh, en);
  Future<void> editQuota(TranslationUsage usage, String account) async {
    final controller = TextEditingController(
        text: usage.quota(account, widget.engine).toString());
    final value = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(label('参考免费额度', 'Reference free allowance')),
              content: TextField(
                key: const ValueKey('translation-usage-quota-input'),
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13)
                ],
                decoration: InputDecoration(
                    labelText: label('字符数，以官方套餐为准',
                        'Characters — check your official plan')),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(label('取消', 'Cancel'))),
                ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final number = int.tryParse(value.text) ?? 0;
                      return TextButton(
                          onPressed: number > 0 && number <= 1000000000000
                              ? () => Navigator.pop(dialogContext, number)
                              : null,
                          child: Text(label('保存', 'Save')));
                    }),
              ],
            ));
    // Let the dialog finish its exit animation before disposing its controller.
    if (value != null) {
      await usage.setQuota(account, value);
      if (mounted) setState(() {});
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([Prefs(), TranslationUsage.changes]),
      builder: (context, _) {
        final usage = TranslationUsage(Prefs().prefs);
        final account = TranslationUsage.account(widget.engine, widget.config);
        final configured = (widget.config[widget.engine == 'baidu'
                    ? 'baidu_appid'
                    : 'microsoft_key'] ??
                '')
            .trim()
            .isNotEmpty;
        final used = configured ? usage.used(account) : 0;
        final quota = usage.quota(account, widget.engine);
        final format = NumberFormat.decimalPattern();
        final ratio = used / quota;
        return Card.outlined(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        label('翻译用量（已同步设备估算）',
                            'Translation usage (synced-device estimate)'),
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(
                        '${TranslationUsage.month()} · ${label('UTC 自然月', 'UTC calendar month')}'),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                        key: const ValueKey('translation-usage-progress'),
                        value: ratio.clamp(0.0, 1.0),
                        color: ratio >= 1
                            ? Theme.of(context).colorScheme.error
                            : null,
                        semanticsLabel: label('估算用量占参考额度',
                            'Estimated usage against reference allowance')),
                    const SizedBox(height: 8),
                    Text(
                        '${format.format(used)} / ${format.format(quota)} ${label('字符', 'characters')} · ${(ratio * 100).toStringAsFixed(1)}%'),
                    const SizedBox(height: 8),
                    Text(label(
                        '仅统计 Modu 成功收到结果的请求；语种翻译与文言文翻译合并计算。需各设备更新并开启「AI 服务设置同步」，完成同步后汇总相同配置的用量。微软不同密钥分别统计。',
                        'Counts requests successfully received by Modu, across language and classical translation. Update each device and enable AI service settings sync; totals combine matching configurations after sync. Different Microsoft keys are counted separately.')),
                    const SizedBox(height: 8),
                    Text(label(
                        '这是估算进度，不是官方余额。历史调用、其他应用、超时或取消后服务端已计费的请求可能未计入；官方结算周期可能不同。参考额度不会阻止超额调用或改变服务套餐。',
                        'This is an estimate, not an official balance. Earlier calls, other apps, and requests billed after timeout or cancellation may be missing. Official billing periods can differ. The reference allowance does not block excess requests or change your plan.')),
                    Wrap(spacing: 8, children: [
                      TextButton(
                          onPressed: configured
                              ? () => editQuota(usage, account)
                              : null,
                          child:
                              Text(label('设置参考额度', 'Set reference allowance'))),
                      TextButton(
                          onPressed: () => launchUrl(
                              Uri.parse(widget.engine == 'baidu'
                                  ? 'https://fanyi-api.baidu.com/manage/developer'
                                  : 'https://portal.azure.com/'),
                              mode: LaunchMode.externalApplication),
                          child:
                              Text(label('官方用量控制台', 'Official usage console'))),
                    ]),
                  ],
                )));
      });
}
