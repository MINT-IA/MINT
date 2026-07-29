import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';

/// beads MINT_nosync-t5r — surface jumelle (Codex re-review PR #968).
///
/// Le chemin backend-first de l'écran RvC (`ApiService.compareRenteVsCapital`)
/// dérivait `capitalEpuiseAge` avec la MÊME heuristique « cashflow < 10 % de
/// l'an 1 » que le moteur local : off-by-one quand le dernier retrait partiel
/// vaut ≥ 10 % du retrait initial, faux négatif quand l'épuisement tombe en
/// fin d'horizon. La trajectoire backend plafonne le retrait au restant :
/// `netPatrimony` touche 0 l'année de l'épuisement (champ `year` = âge).
void main() {
  TrajectoireOption option(List<(int, double, double)> rows) =>
      TrajectoireOption(
        id: 'full_capital',
        label: 'Retrait en capital integral',
        trajectory: [
          for (final (year, netP, cashflow) in rows)
            YearlySnapshot(
              year: year,
              netPatrimony: netP,
              annualCashflow: cashflow,
              cumulativeTaxDelta: 0,
            ),
        ],
        terminalValue: rows.isEmpty ? 0 : rows.last.$2,
        cumulativeTaxImpact: 0,
      );

  group('ApiService.capitalEpuiseAgeFromTrajectory — surface jumelle', () {
    test('retrait final partiel ≥ 10 % : âge exact, pas un an de retard', () {
      // 66 : capital drainé par un retrait plafonné à 100 % du retrait
      // initial -> l'heuristique cashflow attendait 67 (cashflow 0).
      final r = ApiService.capitalEpuiseAgeFromTrajectory(option([
        (65, 100000, 50000),
        (66, 0, 50000),
        (67, 0, 0),
      ]));
      expect(r, 66);
    });

    test('épuisement sur la dernière année de l\'horizon : non-null', () {
      final r = ApiService.capitalEpuiseAgeFromTrajectory(option([
        (65, 100000, 50000),
        (66, 0, 50000),
      ]));
      expect(r, 66,
          reason: "aucune année « cashflow ≈ 0 » n'existe : l'heuristique "
              'rendait null');
    });

    test('capital jamais épuisé : null', () {
      final r = ApiService.capitalEpuiseAgeFromTrajectory(option([
        (65, 100000, 4000),
        (66, 99000, 4000),
        (67, 98000, 4000),
      ]));
      expect(r, isNull);
    });

    test('option absente : null', () {
      expect(ApiService.capitalEpuiseAgeFromTrajectory(null), isNull);
    });

    test('arrondi serveur 2 décimales : 0.00 détecté, 0.01 non', () {
      expect(
        ApiService.capitalEpuiseAgeFromTrajectory(option([
          (65, 0.00, 50000),
        ])),
        65,
      );
      expect(
        ApiService.capitalEpuiseAgeFromTrajectory(option([
          (65, 0.01, 50000),
        ])),
        isNull,
      );
    });
  });
}
