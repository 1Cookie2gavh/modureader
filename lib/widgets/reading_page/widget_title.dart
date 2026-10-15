import 'package:anx_reader/widgets/reading_page/more_settings/more_settings.dart';
import 'package:flutter/material.dart';

Widget widgetTitle(String title, ReadingSettings? settings,
    {VoidCallback? onSettings}) {
  Widget settingsButton = settings == null && onSettings == null
      ? const SizedBox(
          height: 48,
        )
      : SizedBox(
          height: 48,
          child: IconButton(
              onPressed: onSettings ?? () => showMoreSettings(settings!),
              icon: const Icon(Icons.settings)),
        );

  return Column(
    children: [
      Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontFamily: 'SourceHanSerif',
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          settingsButton,
        ],
      ),
      const Divider(),
    ],
  );
}
