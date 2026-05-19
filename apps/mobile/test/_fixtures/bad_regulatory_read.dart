// Phase mint-data-architecture-v1-02 iter-2 B2 — bad-fixture for
// tools/checks/no_mobile_fact_current_regulatory_read.py
//
// This file intentionally violates the L1/L2 boundary contract :
// Mobile MUST NOT read fact_current(subject_type='regulatory') directly.
// The lint must FLAG the pattern below ; self-exempted by path glob
// (`apps/mobile/test/_fixtures/`) so this file does NOT trigger the
// HARD lefthook gate on commit.

class BadRegulatoryReader {
  Future<dynamic> readRegulatoryConstant(String key) async {
    // VIOLATION : direct read of fact_current(subject_type='regulatory').
    // Should go through codegen-baked regulatoryConstantsVersionHash.
    final query = "SELECT value_enc FROM fact_current WHERE subject_type = 'regulatory' AND fact_type = ?";
    return query;
  }
}
