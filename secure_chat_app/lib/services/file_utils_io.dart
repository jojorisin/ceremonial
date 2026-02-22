import 'dart:io';

/// Deletes temp file on mobile (dart:io available).
Future<void> deleteTempFileIfExists(String path) async {
  if (path.isEmpty) return;
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}
