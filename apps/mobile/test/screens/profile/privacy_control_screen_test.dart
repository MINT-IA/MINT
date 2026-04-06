import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/screens/profile/privacy_control_screen.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/biography/biography_repository.dart';

// ────────────────────────────────────────────────────────────
//  PRIVACY CONTROL SCREEN TESTS — Phase 03 / Memoire Narrative
// ────────────────────────────────────────────────────────────
//
// Widget tests for the privacy control screen ("Ce que MINT
// sait de toi"). Verifies rendering, edit sheet, delete dialog,
// empty state, stale fact warning, and fact grouping.
//
// Uses InMemoryBiographyDatabase + BiographyRepository.withDatabase()
// for deterministic testing without native SQLite.
// ────────────────────────────────────────────────────────────

/// In-memory database implementation for testing.
/// Duplicated from biography_repository_test.dart to avoid test coupling.
class _InMemoryDb implements BiographyDatabase {
  final List<Map<String, Object?>> _rows = [];

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {}

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql,
      [List<Object?>? arguments]) async {
    var results = List<Map<String, Object?>>.from(_rows);

    if (sql.contains('isDeleted = ?')) {
      final idx = _paramIndex(sql, 'isDeleted = ?');
      if (idx != null && arguments != null) {
        results =
            results.where((r) => r['isDeleted'] == arguments[idx]).toList();
      }
    }

    if (sql.contains('factType = ?')) {
      final idx = _paramIndex(sql, 'factType = ?');
      if (idx != null && arguments != null) {
        results =
            results.where((r) => r['factType'] == arguments[idx]).toList();
      }
    }

    if (sql.contains('ORDER BY updatedAt DESC')) {
      results.sort((a, b) =>
          (b['updatedAt'] as String).compareTo(a['updatedAt'] as String));
    }

    if (sql.contains('LIMIT 1') && results.isNotEmpty) {
      results = [results.first];
    }

    return results;
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    if (arguments == null || arguments.length < 12) return 0;
    _rows.add({
      'id': arguments[0],
      'factType': arguments[1],
      'fieldPath': arguments[2],
      'value': arguments[3],
      'source': arguments[4],
      'sourceDate': arguments[5],
      'createdAt': arguments[6],
      'updatedAt': arguments[7],
      'causalLinks': arguments[8],
      'temporalLinks': arguments[9],
      'isDeleted': arguments[10],
      'freshnessCategory': arguments[11],
    });
    return 1;
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    if (arguments == null) return 0;
    if (sql.contains('SET isDeleted = 1')) {
      final id = arguments.last;
      for (var i = 0; i < _rows.length; i++) {
        if (_rows[i]['id'] == id) {
          _rows[i] = Map.from(_rows[i])..['isDeleted'] = 1;
          return 1;
        }
      }
      return 0;
    }
    if (sql.contains('SET value = ?')) {
      final id = arguments[3];
      for (var i = 0; i < _rows.length; i++) {
        if (_rows[i]['id'] == id) {
          _rows[i] = Map.from(_rows[i])
            ..['value'] = arguments[0]
            ..['source'] = arguments[1]
            ..['updatedAt'] = arguments[2];
          return 1;
        }
      }
      return 0;
    }
    return 0;
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    if (arguments == null) return 0;
    final id = arguments.first;
    final before = _rows.length;
    _rows.removeWhere((r) => r['id'] == id);
    return before - _rows.length;
  }

  @override
  Future<void> close() async {}

  int? _paramIndex(String sql, String clause) {
    final pos = sql.indexOf(clause);
    if (pos < 0) return null;
    return sql.substring(0, pos).split('?').length - 1;
  }
}

/// Build test app with BiographyProvider and localization.
Widget _buildTestApp({required BiographyProvider provider}) {
  return ChangeNotifierProvider<BiographyProvider>.value(
    value: provider,
    child: const MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      locale: Locale('fr'),
      home: PrivacyControlScreen(),
    ),
  );
}

/// Create a fresh fact (updated now).
BiographyFact _freshFact({
  required String id,
  required FactType type,
  required String value,
  FactSource source = FactSource.document,
}) {
  final now = DateTime.now();
  return BiographyFact(
    id: id,
    factType: type,
    value: value,
    source: source,
    createdAt: now,
    updatedAt: now,
  );
}

/// Create a stale fact (updated 30 months ago).
BiographyFact _staleFact({
  required String id,
  required FactType type,
  required String value,
}) {
  final now = DateTime.now();
  final staleDate = now.subtract(const Duration(days: 900));
  return BiographyFact(
    id: id,
    factType: type,
    value: value,
    source: FactSource.document,
    createdAt: staleDate,
    updatedAt: staleDate,
  );
}

/// Create BiographyProvider backed by in-memory DB with initial facts.
Future<BiographyProvider> _createProvider(
    [List<BiographyFact> initialFacts = const []]) async {
  BiographyRepository.resetInstance();
  final db = _InMemoryDb();
  final repo = await BiographyRepository.withDatabase(db);

  // Pre-populate with initial facts
  for (final fact in initialFacts) {
    await repo.insertFact(fact);
  }

  return BiographyProvider(repository: repo);
}

void main() {
  setUp(() {
    BiographyRepository.resetInstance();
  });

  group('PrivacyControlScreen', () {
    testWidgets('renders title', (tester) async {
      final provider = await _createProvider();

      await tester.pumpWidget(_buildTestApp(provider: provider));
      await tester.pumpAndSettle();

      expect(find.text('Ce que MINT sait de toi'), findsOneWidget);
    });

    testWidgets('shows empty state when no facts', (tester) async {
      final provider = await _createProvider();

      await tester.pumpWidget(_buildTestApp(provider: provider));
      await tester.pumpAndSettle();

      expect(find.textContaining('Aucune donn'), findsOneWidget);
    });

    testWidgets('renders fact cards for each fact', (tester) async {
      final provider = await _createProvider([
        _freshFact(id: 'f1', type: FactType.salary, value: '120000'),
        _freshFact(id: 'f2', type: FactType.lppCapital, value: '70000'),
        _freshFact(id: 'f3', type: FactType.lifeEvent, value: 'marriage'),
      ]);

      await tester.pumpWidget(_buildTestApp(provider: provider));
      await tester.pumpAndSettle();

      expect(find.text('120000'), findsOneWidget);
      expect(find.text('70000'), findsOneWidget);
      expect(find.text('marriage'), findsOneWidget);
    });

    testWidgets('stale fact shows warning indicator', (tester) async {
      final provider = await _createProvider([
        _staleFact(id: 'stale1', type: FactType.salary, value: '100000'),
      ]);

      await tester.pumpWidget(_buildTestApp(provider: provider));
      await tester.pumpAndSettle();

      expect(find.textContaining('obsol'), findsOneWidget);
    });

    testWidgets('delete dialog appears on delete tap', (tester) async {
      final provider = await _createProvider([
        _freshFact(id: 'del1', type: FactType.salary, value: '90000'),
      ]);

      await tester.pumpWidget(_buildTestApp(provider: provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.textContaining('Supprimer cette'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
    });

    testWidgets('edit sheet appears on edit tap', (tester) async {
      final provider = await _createProvider([
        _freshFact(id: 'edit1', type: FactType.salary, value: '110000'),
      ]);

      await tester.pumpWidget(_buildTestApp(provider: provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Salaire'), findsWidgets);
      expect(find.text('Enregistrer'), findsOneWidget);
    });

    testWidgets('summary shows correct count', (tester) async {
      final provider = await _createProvider([
        _freshFact(id: 'c1', type: FactType.salary, value: '100000'),
        _freshFact(id: 'c2', type: FactType.lppCapital, value: '50000'),
        _staleFact(id: 'c3', type: FactType.taxRate, value: '22'),
      ]);

      await tester.pumpWidget(_buildTestApp(provider: provider));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 donn'), findsOneWidget);
    });

    testWidgets('delete confirmation removes fact', (tester) async {
      final provider = await _createProvider([
        _freshFact(id: 'rm1', type: FactType.canton, value: 'VS'),
      ]);

      await tester.pumpWidget(_buildTestApp(provider: provider));
      await tester.pumpAndSettle();

      expect(find.text('VS'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('VS'), findsNothing);
    });

    testWidgets('grouped sections show correct headers', (tester) async {
      final provider = await _createProvider([
        _freshFact(id: 'g1', type: FactType.salary, value: '100000'),
        _freshFact(id: 'g2', type: FactType.lifeEvent, value: 'birth'),
        _freshFact(id: 'g3', type: FactType.userDecision, value: 'rachat'),
      ]);

      await tester.pumpWidget(_buildTestApp(provider: provider));
      await tester.pumpAndSettle();

      expect(find.textContaining('financi'), findsOneWidget);
      expect(find.textContaining('nements de vie'), findsOneWidget);
      expect(find.textContaining('cisions'), findsOneWidget);
    });
  });
}
