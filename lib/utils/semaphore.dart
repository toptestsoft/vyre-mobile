import 'dart:async';

/// Ограничитель параллелизма через очередь Completer.
class Semaphore {
  final int maxConcurrency;
  int _current = 0;
  final List<Completer<void>> _queue = [];

  Semaphore(this.maxConcurrency);

  Future<void> withPermit(Future<void> Function() action) async {
    while (_current >= maxConcurrency) {
      final completer = Completer<void>();
      _queue.add(completer);
      await completer.future;
    }
    _current++;
    try {
      await action();
    } finally {
      _current--;
      if (_queue.isNotEmpty) {
        _queue.removeAt(0).complete();
      }
    }
  }
}
