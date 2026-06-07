description: Row 23/CJT-063 iPhone 16e runtime proof for independent/no-LPP local Coach chat guidance.

# Row 23 - Independent No-LPP Coach Chat Runtime

## Scope

This evidence proves the runtime `/coach/chat` path for the
`independent_no_lpp_income_reality` persona after the local safe hard-gate and
route/UI changes.

Goal:

- open `/coach/chat` on iPhone 16e with the independent/no-LPP E2E persona;
- avoid `/waitlist` for the audited local no-LPP 3a question;
- render deterministic local guidance without false `API Claude` transparency;
- show Swiss-financial guidance checks and an income-aware 3a simulation card,
  not a product/provider instruction or generic salary-only answer;
- keep Row 23 and CJT-063 open for broader quality work.

## Flow

Runtime flow:

```bash
FLOW=tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_coach_chat_runtime.yaml
EVIDENCE=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-independent-no-lpp-coach-chat-runtime-fix-card-20260607T083521
MAESTRO_HARD_LIMIT=360 MAESTRO_STALL_THRESHOLD=120 MINT_WALKER_ARTIFACTS="$EVIDENCE" \
  bash tools/simulator/maestro_with_watchdog.sh test --format junit --output "$EVIDENCE/result.xml" "$FLOW"
```

Result:

- device: `iPhone 16e - iOS 26.2 - 9C9E9AAE-C3CF-49B8-B06D-625004880A9B`;
- JUnit: `tests=1`, `failures=0`;
- watchdog: `0`;
- elapsed: `31s`;
- evidence: `evidence/maestro-ci/row-23-independent-no-lpp-coach-chat-runtime-fix-card-20260607T083521/`.

## Runtime Assertions

The flow sends:

```text
Je suis indépendant sans LPP, combien verser en 3a ?
```

It then proves visible runtime content:

- `LPP facultative`;
- `couverture accident`;
- `perte de gain`;
- `liquidité`;
- `OPP3 art. 7`;
- `LPP art. 4`;
- `LAVS art. 8`;
- `Outil éducatif simplifié`;
- `Ne constitue pas un conseil financier`;
- no `Encore en chantier pour ton profil`;
- no `API Claude`;
- no stale generic card amount `7'137 CHF`;
- no `NaN`, `Infinity`, overflow marker, exception, or `NoSuchMethodError`.

The post-run runtime snapshot also showed:

- `statut AVS d'indépendant·e`;
- `revenu imposable pour l'impact fiscal`;
- `Réf. : OPP3 art. 7, LPP art. 4, LAVS art. 8`;
- `Ne constitue pas un conseil financier (LSFin)`.
- response card `Versement 3a 2026` initially corrected the stale absolute
  ceiling amount by switching the card to the canonical remaining-room
  calculation. Follow-up proof now uses a dedicated professional net-income
  source and shows `2'218 CHF` in
  `evidence/maestro-ci/row-23-independent-no-lpp-professional-net-source-20260607T091054/runtime-snapshot-professional-net-source.jpg`.

Screenshot artifact:

- `evidence/maestro-ci/row-23-independent-no-lpp-coach-chat-runtime-fix-card-20260607T083521/row23-independent-no-lpp-coach-local-guidance-fixed-card.png`
- `evidence/maestro-ci/row-23-independent-no-lpp-coach-chat-runtime-fix-card-20260607T083521/runtime-snapshot-visible-guidance-fixed-card.jpg`
- `evidence/maestro-ci/row-23-independent-no-lpp-coach-chat-runtime-fix-card-20260607T083521/watchdog-exit.txt`

## Debug Note

The first run in
`evidence/maestro-ci/row-23-independent-no-lpp-coach-chat-runtime-20260607T082120/`
failed because the assertion targeted `revenu net d'activité`, which was above
the visible viewport inside a long response. The product path had already
rendered the local guidance.

The next green run was blocked during review because the response card under
the local answer still showed `7'137 CHF`, computed from the absolute no-LPP
ceiling instead of the user's income-aware remaining 3a room. The first fix
switched `ResponseCardService` to
`Pillar3aRoomCalculator.remainingAnnualRoom(...)`.

Follow-up source review then found the remaining `3'068 CHF` runtime card was
still based on a gross-income fallback. The dedicated professional net-income
source fix is documented in
`row-23-independent-no-lpp-professional-net-source-20260607.md`, and the
runtime flow now fails if either `7'137 CHF` or `3'068 CHF` reappears.

## Boundaries

This does not close Row 23 or CJT-063.

Still open:

- broader independent/no-LPP natural-language Coach calibration beyond this
  audited local topic;
- live backend/LLM scoring for calibrated personas;
- restart/provenance proof for persona facts;
- runtime VoiceOver/AX traversal;
- updated persona-flow scoring after the Coach route/runtime change;
- broader screen and flow quality scoring across the 104-screen inventory.
