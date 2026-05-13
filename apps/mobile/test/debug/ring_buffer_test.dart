import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/debug/ring_buffer.dart';

void main() {
  group('RingBuffer', () {
    test('keeps insertion order up to capacity', () {
      final buf = RingBuffer<int>(3);
      buf.add(1);
      buf.add(2);
      buf.add(3);
      expect(buf.toList(), [1, 2, 3]);
      expect(buf.length, 3);
    });

    test('drops oldest entry past capacity (FIFO)', () {
      final buf = RingBuffer<int>(3);
      for (final i in [1, 2, 3, 4, 5]) {
        buf.add(i);
      }
      expect(buf.toList(), [3, 4, 5]);
      expect(buf.length, 3);
    });

    test('clear() empties the buffer', () {
      final buf = RingBuffer<String>(2)
        ..add('a')
        ..add('b');
      buf.clear();
      expect(buf.length, 0);
      expect(buf.toList(), isEmpty);
    });

    test('toList returns unmodifiable view', () {
      final buf = RingBuffer<int>(2)..add(1);
      final view = buf.toList();
      expect(() => view.add(99), throwsUnsupportedError);
    });

    test('capacity of 1 holds only the most recent', () {
      final buf = RingBuffer<int>(1);
      buf.add(1);
      buf.add(2);
      expect(buf.toList(), [2]);
    });

    test('rejects non-positive capacity', () {
      expect(() => RingBuffer<int>(0), throwsA(isA<AssertionError>()));
    });
  });
}
