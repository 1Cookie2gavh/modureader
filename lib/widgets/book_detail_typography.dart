import 'package:flutter/material.dart';

class BookDetailTypography {
  static TextStyle title(BuildContext context) => TextStyle(
        fontSize: 24,
        fontFamily: 'SourceHanSerif',
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.bodyLarge!.color,
      );

  static TextStyle author(BuildContext context) => TextStyle(
        fontSize: 15,
        fontFamily: 'SourceHanSerif',
        color: Theme.of(context).textTheme.bodyLarge!.color,
      );
}
