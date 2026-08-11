class MintNext3aFiscalContext {
  const MintNext3aFiscalContext({
    this.contextVersion = 1,
    required this.taxYear,
    required this.effectiveAt,
  });

  final int contextVersion;
  final int taxYear;
  final DateTime effectiveAt;
  static const capability = 'no_attested_engine';

  Map<String, Object> toJson() => {
        'context_version': contextVersion,
        'tax_year': taxYear,
        'effective_at': effectiveAt.toUtc().toIso8601String(),
        'capability': capability,
      };
}

class Pillar3aTaxDeltaRequest {
  const Pillar3aTaxDeltaRequest({required this.context});
  final MintNext3aFiscalContext context;
}

sealed class Pillar3aTaxDeltaResult {
  const Pillar3aTaxDeltaResult();
}

class Pillar3aTaxDeltaUnavailable extends Pillar3aTaxDeltaResult {
  const Pillar3aTaxDeltaUnavailable();

  @override
  bool operator ==(Object other) => other is Pillar3aTaxDeltaUnavailable;
  @override
  int get hashCode => runtimeType.hashCode;
}
