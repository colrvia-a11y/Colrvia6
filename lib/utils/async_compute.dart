import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';

class AsyncCompute {
  static Future<T> run<T, A>(FutureOr<T> Function(A arg) fn, A arg) async {
    if (kIsWeb) {
      // Isolates not supported on web; run synchronously.
      return await Future<T>.microtask(() => fn(arg));
    }
    return await Isolate.run(() => fn(arg));
  }
}
