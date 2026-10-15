import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/modu_strings.dart';
import 'package:flutter/material.dart';

class ContinuousScrollTile extends StatefulWidget {
  const ContinuousScrollTile({super.key, required this.onChanged});

  final ValueChanged<bool> onChanged;

  @override
  State<ContinuousScrollTile> createState() => _ContinuousScrollTileState();
}

class _ContinuousScrollTileState extends State<ContinuousScrollTile> {
  @override
  Widget build(BuildContext context) => SwitchListTile(
        key: const ValueKey('continuous-scroll'),
        contentPadding: EdgeInsets.zero,
        title: Text(ModuStrings.text(
            context, '跨章节连续滚动', 'Scroll continuously across chapters')),
        subtitle: Text(ModuStrings.text(
            context,
            '关闭后，每章独立滚动。读到章末后，点击翻页或使用目录进入下一章。',
            'Turn off to scroll one chapter at a time. At the end, use page turning or the contents to open the next chapter.')),
        value: Prefs().continuousScroll,
        onChanged: (value) {
          setState(() => Prefs().continuousScroll = value);
          widget.onChanged(value);
        },
      );
}
