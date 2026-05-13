import 'dart:collection';

/// Bounded FIFO buffer — drops the oldest entry once [capacity] is reached.
///
/// Used by `MintHttpClient` (last N HTTP req/res) and the debug Zone logger
/// (last N debugPrint lines). Holds strong references — keep entries small.
class RingBuffer<T> {
  RingBuffer(this.capacity) : assert(capacity > 0);

  final int capacity;
  final Queue<T> _items = Queue<T>();

  void add(T item) {
    if (_items.length >= capacity) {
      _items.removeFirst();
    }
    _items.add(item);
  }

  void clear() => _items.clear();

  /// Snapshot copy — caller is free to mutate. Oldest first.
  List<T> toList() => List<T>.unmodifiable(_items);

  int get length => _items.length;
}
