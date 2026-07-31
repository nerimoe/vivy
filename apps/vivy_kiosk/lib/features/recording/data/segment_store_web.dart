import 'dart:js_interop';

import 'package:camera/camera.dart';

@JS('vivyStoreSegment')
external JSPromise<JSObject> _storeSegment(JSString id, JSUint8Array bytes);

@JS('vivyDeleteSegment')
external JSPromise<JSAny?> _deleteSegment(JSString path);

extension type _StoredSegmentResult._(JSObject _) implements JSObject {
  external JSString get path;
  external JSNumber get bytes;
}

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
    final content = await source.readAsBytes();
    final raw = await _storeSegment(id.toJS, content.toJS).toDart;
    final result = _StoredSegmentResult._(raw);
    return StoredSegment(
      path: result.path.toDart,
      bytes: result.bytes.toDartInt,
      modifiedAt: DateTime.now(),
    );
  }

  Future<List<StoredSegment>> list() async => const [];

  Future<void> delete(String path) async {
    await _deleteSegment(path.toJS).toDart;
  }

  Future<void> deleteAll() async {}
}
