import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef MigrationProgressCallback = void Function(
    String currentItem, int progress, int total);

/// Run before databases, logging and background writers open.
/// Preserve the source as a recovery copy.
Future<bool> performStorageMigration({
  required String sourcePath,
  required String destinationPath,
  MigrationProgressCallback? onProgress,
}) async {
  final source = Directory(sourcePath);
  final destination = Directory(destinationPath);
  if (!await source.exists()) return false;
  final created = <FileSystemEntity>[];
  try {
    await destination.create(recursive: true);
    final from = await source.resolveSymbolicLinks();
    final to = await destination.resolveSymbolicLinks();
    if (p.equals(from, to) ||
        p.isWithin(from, to) ||
        p.isWithin(to, from) ||
        !await isDirectoryEmpty(to)) {
      return false;
    }
    final entries = await source.list(followLinks: false).toList();
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final target = p.join(to, p.basename(entry.path));
      onProgress?.call(p.basename(entry.path), i + 1, entries.length);
      if (entry is Directory) {
        final dir = await Directory(target).create();
        created.add(dir);
        await _copyDirectory(entry, dir);
      } else if (entry is File) {
        final file = File(target);
        created.add(file);
        await _copyFile(entry, file);
      } else {
        throw const FileSystemException('Storage migration cannot copy links');
      }
    }
    return true;
  } catch (_) {
    // Remove only outputs from this attempt, never source data.
    for (final entity in created.reversed) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {}
    }
    return false;
  }
}

Future<bool> isDirectoryEmpty(String path) async {
  final dir = Directory(path);
  return !await dir.exists() || await dir.list().isEmpty;
}

Future<String> getDefaultStoragePath() async =>
    (await getApplicationSupportDirectory()).path;

Future<void> _copyFile(File source, File destination) async {
  await source.copy(destination.path);
  if (await sha256.bind(source.openRead()).first !=
      await sha256.bind(destination.openRead()).first) {
    throw const FileSystemException('Storage migration verification failed');
  }
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await for (final entity in source.list(followLinks: false)) {
    final target = p.join(destination.path, p.basename(entity.path));
    if (entity is File) {
      await _copyFile(entity, File(target));
    } else if (entity is Directory) {
      await _copyDirectory(entity, await Directory(target).create());
    } else {
      throw const FileSystemException('Storage migration cannot copy links');
    }
  }
}
