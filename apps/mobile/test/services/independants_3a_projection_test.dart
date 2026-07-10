import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/independants_service.dart';

void main() {
  group('IndependantsService - 3a projection bridge', () {
    test('compares petit and grand 3a through financial_core projection', () {
      final withoutLpp = IndependantsService.calculate3aIndependant(
        100000,
        false,
        0.30,
      );
      final withoutLppProjection =
          IndependantsService.project3aIndependant20Years(withoutLpp);

      expect(
        withoutLppProjection.projectionIndependant,
        greaterThan(withoutLppProjection.projectionSalarie),
      );
      expect(
        withoutLppProjection.difference,
        closeTo(
          withoutLppProjection.projectionIndependant -
              withoutLppProjection.projectionSalarie,
          0.01,
        ),
      );

      final withLpp = IndependantsService.calculate3aIndependant(
        100000,
        true,
        0.30,
      );
      final withLppProjection =
          IndependantsService.project3aIndependant20Years(withLpp);
      expect(withLppProjection.difference, closeTo(0, 0.01));
    });
  });
}
