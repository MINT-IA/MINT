import 'package:mint_mobile/models/mint_next_3a_tax_boundary.dart';

abstract interface class Pillar3aTaxDeltaEngine {
  Future<Pillar3aTaxDeltaResult> calculate(Pillar3aTaxDeltaRequest request);
}

class NoAttestedEngine implements Pillar3aTaxDeltaEngine {
  const NoAttestedEngine();

  @override
  Future<Pillar3aTaxDeltaResult> calculate(
      Pillar3aTaxDeltaRequest request) async {
    return const Pillar3aTaxDeltaUnavailable();
  }
}
