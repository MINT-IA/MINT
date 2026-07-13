# Negative fixture — G1 P0 ledger dead-key gate

This fixture is intentionally invalid. It proves the gate rejects a duplicate
canonical key, a silently dead key labelled live, and missing blocking-ticket
metadata. It also carries an unsupported classification and a reserved
type/classification mismatch. It is test input, never a product contract.

## G1_P0_CANONICAL_KEYS

| canonical_key | storage_key | coach_profile_path | type_unit | allowed_sources | freshness_tier | confidence_weight | classification | profile_owner | write_path | reader_evidence | consumers | p0_loops | tier | required_for_output | allowed_output_when_missing | legal_source_asof | sensitivity_purpose | status | existing_gate | missing_gate | blocks_G2 | ticket |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| duplicateKey | q_duplicate | duplicate | CHF | userInput | annual | 0.60 | fact | self | mergeAnswers | apps/mobile/lib/models/coach_profile.dart#CoachProfile.toCoachingProfile@duplicate | retirement | RETIREMENT | P0 | yes | partial+ask | n/a | fixture | live | fixture_gate | provenance_on_write | yes | G1-NEG-01 |
| duplicateKey | q_duplicate_2 | duplicate2 | CHF | userInput | annual | 0.60 | fact | self | mergeAnswers | apps/mobile/lib/models/coach_profile.dart#CoachProfile.toCoachingProfile@duplicate2 | retirement | RETIREMENT | P0 | yes | partial+ask | n/a | fixture | live | fixture_gate | provenance_on_write | yes | G1-NEG-02 |
| silentDead | q_silent | silent | CHF | userInput | annual | 0.60 | fact | self | NONE | NONE | NONE | HOUSING | P0 | yes | partial+ask | n/a | fixture | live | NONE | behavioral_gate | yes | G1-NEG-03 |
| missingTicket | NONE | NONE | CHF | userInput | annual | 0.60 | fact | self | NONE | NONE | retirement | RETIREMENT | P0 | yes | partial+ask | required | fixture | missing | NONE | canonical_storage | yes | NONE |
| falseReader | q_false_reader | falseReader | CHF | userInput | annual | 0.60 | fact | self | mergeAnswers | apps/mobile/lib/models/does_not_exist.dart#CoachProfile.compute@falseReader | retirement | RETIREMENT | P0 | yes | partial+ask | n/a | fixture | live | fixture_gate | behavioral_gate | yes | G1-NEG-04 |
| falseReaderLine | q_false_reader_line | falseReaderLine | CHF | userInput | annual | 0.60 | fact | self | mergeAnswers | apps/mobile/lib/models/coach_profile.dart#CoachProfile.missingMember@falseReaderLine | retirement | RETIREMENT | P0 | yes | partial+ask | n/a | fixture | live | fixture_gate | behavioral_gate | yes | G1-NEG-05 |
| falseReaderSemantic | q_false_reader_semantic | falseReaderSemantic | CHF | userInput | annual | 0.60 | fact | self | mergeAnswers | apps/mobile/lib/models/coach_profile.dart#CoachProfile.toCoachingProfile@falseReaderSemantic | retirement | RETIREMENT | P0 | yes | partial+ask | n/a | fixture | live | fixture_gate | behavioral_gate | yes | G1-NEG-06 |
| badClassification | NONE | NONE | CHF | userInput | annual | 0.60 | banana | self | NONE | NONE | NONE | RETIREMENT | P0 | yes | partial+ask | n/a | fixture | quarantined | NONE | classification_contract | yes | G1-NEG-07 |
| badTypeClassification | q_bad_marker | userProvidedFields.badTypeClassification | CHF | userInput | annual | 0.60 | completion_marker | self | derived_on_rebuild | NONE | retirement | RETIREMENT | P0 | yes | partial+ask | n/a | fixture | quarantined | NONE | classification_contract | yes | G1-NEG-08 |
