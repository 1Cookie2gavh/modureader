import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

typedef PinnedModelFile = ({int size, String sha256});

/// Only app-owned, pinned metadata is accepted. Never trust a user manifest.
Future<void> importPinnedModelFiles(Directory destination, List<File> sources,
    Map<String, PinnedModelFile> expected) async {
  if (sources.length != expected.length || expected.isEmpty) {
    throw const FormatException('Select all required model files together');
  }
  for (final name in expected.keys) {
    if (path.basename(name) != name || name == '.' || name == '..') {
      throw const FormatException('Invalid model filename');
    }
  }
  if (await FileSystemEntity.type(destination.path, followLinks: false) ==
      FileSystemEntityType.link) {
    throw const FileSystemException('Model directory cannot be a symlink');
  }
  await destination.create(recursive: true);
  final staging = await destination.createTemp('.import-');
  final replaced = <String>[];
  final installed = <String>[];
  var safeToClean = true;
  try {
    final unmatched = Map<String, PinnedModelFile>.of(expected);
    // Copy first, then hash the copy: source changes cannot bypass validation.
    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      final length = await source.length();
      if (!unmatched.values.any((spec) => spec.size == length)) {
        throw const FormatException('Model size does not match this model');
      }
      final copy = await source.copy(path.join(staging.path, 'source-$i'));
      final digest = await Isolate.run(
          () async => (await sha256.bind(copy.openRead()).first).toString());
      final matches = unmatched.entries.where((entry) =>
          entry.value.size == length && entry.value.sha256 == digest);
      if (matches.isEmpty || await copy.length() != length) {
        throw const FormatException('Model SHA-256 does not match this model');
      }
      final name = matches.first.key;
      unmatched.remove(name);
      await copy.rename(path.join(staging.path, name));
    }
    // Validate the entire selection before replacing any installed file.
    for (final name in expected.keys) {
      final target = path.join(destination.path, name);
      final type = await FileSystemEntity.type(target, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw const FileSystemException('Unexpected model destination type');
      }
    }
    try {
      for (final name in expected.keys) {
        final target = File(path.join(destination.path, name));
        if (await target.exists()) {
          await target.rename(path.join(staging.path, '$name.backup'));
          replaced.add(name);
        }
        await File(path.join(staging.path, name)).rename(target.path);
        installed.add(name);
      }
    } catch (_) {
      safeToClean = false;
      for (final name in installed.reversed) {
        await File(path.join(destination.path, name)).delete();
      }
      for (final name in replaced.reversed) {
        await File(path.join(staging.path, '$name.backup'))
            .rename(path.join(destination.path, name));
      }
      safeToClean = true;
      rethrow;
    }
  } finally {
    // Keep backups for recovery if the filesystem also refuses rollback.
    if (safeToClean) await staging.delete(recursive: true);
  }
}
