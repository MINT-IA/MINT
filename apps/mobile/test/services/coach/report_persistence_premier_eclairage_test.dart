import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ReportPersistenceService — PremierEclairage persistence', () {
    test('savePremierEclairageSnapshot stores a map and loadPremierEclairageSnapshot retrieves it identically', () async {
      const snapshot = {
        'value': 'CHF 7\'258',
        'title': 'Économie 3a possible',
        'subtitle': 'Montant annuel déductible',
        'colorKey': 'accent_green',
        'suggestedRoute': '/pilier-3a',
      };
      await ReportPersistenceService.savePremierEclairageSnapshot(snapshot);
      final loaded = await ReportPersistenceService.loadPremierEclairageSnapshot();
      expect(loaded, isNotNull);
      expect(loaded!['value'], equals('CHF 7\'258'));
      expect(loaded['title'], equals('Économie 3a possible'));
      expect(loaded['subtitle'], equals('Montant annuel déductible'));
      expect(loaded['colorKey'], equals('accent_green'));
      expect(loaded['suggestedRoute'], equals('/pilier-3a'));
    });

    test('loadPremierEclairageSnapshot returns null when nothing has been saved', () async {
      final loaded = await ReportPersistenceService.loadPremierEclairageSnapshot();
      expect(loaded, isNull);
    });

    test('hasSeenPremierEclairage returns false by default', () async {
      final seen = await ReportPersistenceService.hasSeenPremierEclairage();
      expect(seen, isFalse);
    });

    test('markPremierEclairageSeen sets the flag to true', () async {
      await ReportPersistenceService.markPremierEclairageSeen();
      final seen = await ReportPersistenceService.hasSeenPremierEclairage();
      expect(seen, isTrue);
    });

    test('hasSeenPremierEclairage returns false before markPremierEclairageSeen is called', () async {
      // Confirm default is false
      expect(await ReportPersistenceService.hasSeenPremierEclairage(), isFalse);
      // Mark as seen
      await ReportPersistenceService.markPremierEclairageSeen();
      // Now should be true
      expect(await ReportPersistenceService.hasSeenPremierEclairage(), isTrue);
    });

    test('clearDiagnostic also clears premierEclairageSnapshot', () async {
      await ReportPersistenceService.savePremierEclairageSnapshot({
        'value': 'CHF 1000',
        'title': 'Test',
        'subtitle': 'Sub',
        'colorKey': 'accent_blue',
        'suggestedRoute': '/test',
      });
      await ReportPersistenceService.clearDiagnostic();
      final loaded = await ReportPersistenceService.loadPremierEclairageSnapshot();
      expect(loaded, isNull);
    });

    test('clearDiagnostic also clears hasSeenPremierEclairage flag', () async {
      await ReportPersistenceService.markPremierEclairageSeen();
      expect(await ReportPersistenceService.hasSeenPremierEclairage(), isTrue);
      await ReportPersistenceService.clearDiagnostic();
      expect(await ReportPersistenceService.hasSeenPremierEclairage(), isFalse);
    });

    test('loadPremierEclairageSnapshot returns null after clearDiagnostic', () async {
      await ReportPersistenceService.savePremierEclairageSnapshot({'value': 'x'});
      await ReportPersistenceService.clearDiagnostic();
      expect(await ReportPersistenceService.loadPremierEclairageSnapshot(), isNull);
    });

    test('savePremierEclairageSnapshot overwrites previous snapshot', () async {
      await ReportPersistenceService.savePremierEclairageSnapshot({'value': 'first'});
      await ReportPersistenceService.savePremierEclairageSnapshot({'value': 'second'});
      final loaded = await ReportPersistenceService.loadPremierEclairageSnapshot();
      expect(loaded!['value'], equals('second'));
    });

    test('loadPremierEclairageSnapshot handles malformed JSON gracefully (returns null)', () async {
      // Directly set malformed JSON in prefs
      SharedPreferences.setMockInitialValues({
        'premier_eclairage_snapshot_v1': 'not_valid_json{{',
      });
      final loaded = await ReportPersistenceService.loadPremierEclairageSnapshot();
      expect(loaded, isNull);
    });

    test('snapshot does not store PII fields (salary, IBAN)', () async {
      // Only display fields allowed per T-03-02 threat mitigation
      const snapshot = {
        'value': 'CHF 7\'258',
        'title': 'Test title',
        'subtitle': 'Test subtitle',
        'colorKey': 'accent_blue',
        'suggestedRoute': '/pilier-3a',
      };
      // These should NOT be in snapshot keys
      expect(snapshot.containsKey('salary'), isFalse);
      expect(snapshot.containsKey('iban'), isFalse);
      expect(snapshot.containsKey('grossAnnualSalary'), isFalse);
      await ReportPersistenceService.savePremierEclairageSnapshot(snapshot);
      final loaded = await ReportPersistenceService.loadPremierEclairageSnapshot();
      expect(loaded!.containsKey('salary'), isFalse);
      expect(loaded.containsKey('iban'), isFalse);
    });

    test('markPremierEclairageSeen is idempotent (calling twice stays true)', () async {
      await ReportPersistenceService.markPremierEclairageSeen();
      await ReportPersistenceService.markPremierEclairageSeen();
      expect(await ReportPersistenceService.hasSeenPremierEclairage(), isTrue);
    });
  });
}
