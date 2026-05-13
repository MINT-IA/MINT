import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/debug/debug_registry.dart';

void main() {
  setUp(DebugRegistry.reset);

  group('DebugRegistry', () {
    test('register + names is sorted alphabetically', () {
      DebugRegistry.register('zeta', () => {'z': 1});
      DebugRegistry.register('alpha', () => {'a': 1});
      DebugRegistry.register('mu', () => {'m': 1});
      expect(DebugRegistry.names(), ['alpha', 'mu', 'zeta']);
    });

    test('snapshot collects all surfaces in parallel', () async {
      DebugRegistry.register('one', () => {'val': 1});
      DebugRegistry.register('two', () async => {'val': 2});
      final snap = await DebugRegistry.snapshot();
      expect(snap['one'], {'val': 1});
      expect(snap['two'], {'val': 2});
    });

    test('snapshot filters via include list', () async {
      DebugRegistry.register('a', () => {'k': 'av'});
      DebugRegistry.register('b', () => {'k': 'bv'});
      final snap = await DebugRegistry.snapshot(include: ['a']);
      expect(snap.keys, ['a']);
    });

    test('one broken surface does not poison others — error surfaces', () async {
      DebugRegistry.register('good', () => {'ok': true});
      DebugRegistry.register('bad', () {
        throw StateError('boom');
      });
      final snap = await DebugRegistry.snapshot();
      expect(snap['good'], {'ok': true});
      expect(snap['bad'], isA<Map<String, dynamic>>());
      expect((snap['bad'] as Map)['_error'], contains('boom'));
      expect((snap['bad'] as Map)['_stack'], isNotNull);
    });

    test('unregister removes a surface', () async {
      DebugRegistry.register('tmp', () => {'a': 1});
      DebugRegistry.unregister('tmp');
      expect(DebugRegistry.names(), isEmpty);
    });

    test('reset clears every surface', () async {
      DebugRegistry.register('x', () => {'a': 1});
      DebugRegistry.register('y', () => {'b': 2});
      DebugRegistry.reset();
      expect(DebugRegistry.names(), isEmpty);
    });

    test('register overwrites an existing name (idempotent)', () async {
      DebugRegistry.register('k', () => {'v': 1});
      DebugRegistry.register('k', () => {'v': 2});
      final snap = await DebugRegistry.snapshot();
      expect(snap['k'], {'v': 2});
    });
  });
}
