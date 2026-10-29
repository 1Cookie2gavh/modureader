import 'package:anx_reader/l10n/modu_strings.dart';
import 'package:flutter/material.dart';

/// Keep explanations available without making every setting several lines tall.
class SettingHelpTitle extends StatelessWidget {
  const SettingHelpTitle(
      {super.key, required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(children: [
        Flexible(child: Text(title)),
        IconButton(
          tooltip: ModuStrings.text(context, '$title：说明', '$title: Help'),
          icon: const Icon(Icons.help_outline, size: 20),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(title),
              scrollable: true,
              content: Text(description),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child:
                      Text(MaterialLocalizations.of(context).closeButtonLabel),
                )
              ],
            ),
          ),
        ),
      ]);
}
