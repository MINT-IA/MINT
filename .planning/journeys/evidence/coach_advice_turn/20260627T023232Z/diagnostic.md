description: Diagnostic for the JOS-004 Coach advice turn red runtime proof.

# JOS-004 Coach Advice Turn Diagnostic

Verdict: red.

Runtime path:
- Build: iOS simulator debug, staging API, `MINT_DISABLE_BETA_MODAL=true`, `MINT_E2E_ARCHETYPE=cadre_salarie_lpp_suisse_ready`.
- Flow: `tools/simulator/flows/maestro-perfect-set/flow_jos004_coach_advice_turn_runtime.yaml`.
- Device: iPhone 17 Pro, iOS 26.2.

Observed behavior:
- The flow reached `/coach/chat`.
- The user prompt was sent: `Quel est le plafond legal 3a 2026 avec LPP ?`.
- The visible assistant reply was: `Je n'ai pas cette donnée à jour pour l'instant.`
- The flow failed because no visible `OPP3`, `LIFD`, `art. 7`, `art. 33`, or `art. 38` citation appeared.

Expected behavior:
- Coach should return the 2026 salaried-LPP 3a ceiling, `7'258 CHF`, with OPP3/LIFD provenance and bounded educational wording.

Regulatory source check:
- `get_swiss_constants({"category":"pillar3a"})` returned `pillar3a.historical_limits.2026 = 7258.0 CHF`, source `OPP3 art. 7 — OFAS publication annuelle`, tax year `2026`.

Likely root-cause area:
- Backend Coach regulatory dispatch / citation grammar / runtime freshness gate interaction. The canonical salaried-LPP seed also carries a `7056` 3a contribution value, which is a stale historical regulatory value if interpreted as an official ceiling. The fix must distinguish user/profile amounts from stale official regulatory ceilings instead of falling back for the whole turn.
