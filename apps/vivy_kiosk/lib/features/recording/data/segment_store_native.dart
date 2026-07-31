import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

class StoredSegment {
  const StoredSegment({
    required this.path,
    required this.bytes,
    required this.modifiedAt,
  });

  final String path;
  final int bytes;
  final DateTime modifiedAt;
}

class SegmentStore {
  Future<StoredSegment> save(String id, XFile source) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/recordings');
    await directory.create(recursive: true);
    final destination = File('${directory.path}/$id.mp4');
    final sourceFile = File(source.path);
    if (await sourceFile.exists()) {
      await sourceFile.copy(destination.path);
      await sourceFile.delete();
    } else {
      await destination.writeAsBytes(await source.readAsBytes(), flush: true);
    }
    return StoredSegment(
      path: destination.path,
      bytes: await destination.length(),
      modifiedAt: await destination.lastModified(),
    );
  }

  Future<List<StoredSegment>> list() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/recordings');
    if (!await directory.exists()) return const [];
    final segments = <StoredSegment>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      segments.add(
        StoredSegment(
          path: entity.path,
          bytes: stat.size,
          modifiedAt: stat.modified,
        ),
      );
    }
    return segments;
  }

  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteAll() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/recordings');
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
