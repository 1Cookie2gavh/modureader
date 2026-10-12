import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const harmonyFileExportChannel = MethodChannel('modu/file_export');

Future<String?> saveHarmonyFile({
  Uint8List? bytes,
  String? sourceFilePath,
  required String fileName,
}) async {
  if (fileName.isEmpty ||
      fileName == '.' ||
      fileName == '..' ||
      fileName.contains(RegExp(r'[/\\\x00]'))) {
    throw ArgumentError.value(fileName, 'fileName', 'Expected a file name');
  }
  if (bytes == null && sourceFilePath == null) {
    throw ArgumentError('File content is required');
  }
  final staging =
      await (await getTemporaryDirectory()).createTemp('modu-export-');
  try {
    // Keep the original untouched and avoid sending large files over the channel.
    final snapshot = File(p.join(staging.path, fileName));
    if (bytes != null) {
      await snapshot.writeAsBytes(bytes, flush: true);
    } else {
      await File(sourceFilePath!).copy(snapshot.path);
    }
    return await harmonyFileExportChannel.invokeMethod<String>('saveFile', {
      'sourcePath': snapshot.path,
      'fileName': fileName,
    });
  } finally {
    await staging.delete(recursive: true);
  }
}
