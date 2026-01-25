import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReportPersistenceService Integration', () {
    test('Save and Load Letters History', () async {
      SharedPreferences.setMockInitialValues({});

      final history = [
        {'title': 'Rachat LPP', 'date': '2025-01-01', 'type': 'LPP_BUYBACK'},
      ];

      await ReportPersistenceService.saveLettersHistory(history);

      final loaded = await ReportPersistenceService.loadLettersHistory();

      expect(loaded.length, 1);
      expect(loaded[0]['title'], 'Rachat LPP');
    });

    test('Append history logic simulation', () async {
      SharedPreferences.setMockInitialValues({});

      // 1. Initial save
      await ReportPersistenceService.saveLettersHistory([
        {'title': 'Lettre 1'}
      ]);

      // 2. Load and append
      var current = await ReportPersistenceService.loadLettersHistory();
      current.add({'title': 'Lettre 2'});

      // 3. Save again
      await ReportPersistenceService.saveLettersHistory(current);

      // 4. Verify
      final check = await ReportPersistenceService.loadLettersHistory();
      expect(check.length, 2);
      expect(check[1]['title'], 'Lettre 2');
    });
  });
}
