import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

Future<void> clearLocalPrivateCaches() async {
  await clearPlaybackTempFiles();
  imageCache.clear();
  imageCache.clearLiveImages();
}

Future<void> clearPlaybackTempFiles() async {
  final directory = await getTemporaryDirectory();
  if (!directory.existsSync()) return;

  final deletions = <Future<void>>[];
  await for (final entity in directory.list()) {
    if (entity is File && _isPrivatePlaybackFile(entity)) {
      deletions.add(_deleteIfPresent(entity));
    }
  }
  await Future.wait(deletions);
}

bool _isPrivatePlaybackFile(File file) {
  final name = file.uri.pathSegments.isEmpty
      ? file.path
      : file.uri.pathSegments.last;
  if (!name.endsWith('.mp4')) return false;
  return name.startsWith('swinglens_') || name.startsWith('tracer_');
}

Future<void> _deleteIfPresent(File file) async {
  try {
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // Best-effort cleanup; temp files may be open by a disposed player briefly.
  }
}
