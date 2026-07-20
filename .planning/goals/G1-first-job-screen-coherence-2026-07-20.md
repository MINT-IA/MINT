# G1-COHERENCE-01 — First Job whole-screen coherence

Date: 2026-07-20

Owner chain: `mint-swiss-brain` → `mint-data-ledger-architect` → `mint-mobile`
→ `mint-quality-gate` → `mint-external-auditor` → `mint-lead`

Status: **OPEN P0 — blocks `RDY-GATE-01`, score >=9.0 and G2/G3.** This is a
whole-screen acceptance hard floor over the existing 31-row ledger/runtime
registry; it does not silently change a registry row or claim implementation.

## Why this gate exists

The accepted runtime capture at `f857b389d` proved route/native-return
plumbing, but direct review of the assembled `/first-job` screen found:

- LPP CHF 187 / 2.3% and net CHF 7'197 from `FirstJobService`, then LPP
  CHF 280 / 3.5% and net CHF 7'104 from `FirstSalaryFilmWidget`;
- three salary narratives and three checklist surfaces;
- unconditional 3a eligibility plus “Évite l'assurance-vie / privilégie une
  fintech”, without protection, liquidity, family, mortgage or contract facts;
- a fabricated LAMal premium curve, `TOP 2500`, a separate film recommendation
  of 1500, and “Max CHF 6'036/an” that is not a legal total maximum;
- adjacent projections using 20% of net versus the 3a ceiling without naming
  the changed contribution base, plus malformed `1641'000` formatting.

Component tests currently pin several of those opinions independently. Green
widgets therefore do not prove a coherent screen.

## RED contract

Command (must fail semantically before implementation, then pass unchanged):

```bash
cd apps/mobile && flutter test \
  test/screens/first_job_whole_screen_coherence_test.dart \
  test/services/first_job_service_test.dart \
  test/widgets/coach/first_salary_film_widget_test.dart \
  --reporter expanded
```

The RED test must prove the real assembled screen, not search source strings
alone:

1. Every visible salary/LPP/net occurrence consumes one canonical result; no
   widget owns a second calculation. The independent film calculations are
   deleted, not merely left dormant behind a different render branch.
2. Without reviewed payslip/certificate evidence, the exact employee LPP
   deduction is unknown. A statutory age-credit illustration, if retained, is
   labelled as an assumption and cannot produce an unqualified exact net.
3. The screen renders one salary explanation and one context-correct first-job
   checklist. The change-of-job checklist is absent.
4. No `TOP`, `recommandé`, `évite`, `privilégie`, provider-class preference or
   monthly “suggestion” appears without the suitability variables that would
   justify it.
5. LAMal uses real premium/expected-spend inputs through the existing insurance
   path, or remains educational without invented premiums. “Maximum” is
   reserved for legally bounded ordinary cost participation and explicitly
   excludes hospital contribution and uncovered costs.
6. At most one projection story is active at a time. It names contribution,
   start age, horizon, net-return assumption, fees/inflation/tax exclusions and
   illustrative status.
7. All CHF values use the canonical formatter. The test calls that formatter
   with the real projection value and proves `CHF 1'641'000`; a source-string
   search is insufficient.
8. One full-height screenshot and semantics inventory are inspected together,
   not as isolated crops.
9. Until this gate is GREEN, `FeatureFlags.enableFirstJobScreen` defaults false,
   stays outside `applyFromMap`, and only the compile-time
   `MINT_TEST_FIRST_JOB` opt-in may expose it for bounded runtime proof. A router
   test proves `/first-job` cannot render in production and redirects to the
   safe Work/Coach surface. `RouteMeta.killFlag` metadata alone is not
   enforcement.

## Swiss meaning boundary

- LPP art. 16 age credits apply to coordinated salary and are not an exact
  payroll deduction. Plan, risk/admin components and financing can differ; the
  employer's aggregate financing floor is not proof of an exact personal 50/50
  split. Before 25, risk coverage may still have a cost.
- Recognized 3a forms include insurance policies and bank-foundation accounts.
  Pure-risk protection, mixed savings, surrender/flexibility and lender
  requirements are distinct questions. No general federal mortgage rule makes
  life insurance universally mandatory.
- CHF 7'258 is the 2026 annual 3a ceiling for an eligible person affiliated to
  occupational pension provision, not a recommended CHF 605 monthly payment.
- LAMal selection depends on official premiums, model/region/accident cover,
  expected spending and liquidity. Compare scenarios; do not rank a franchise
  from age and a fictive premium alone.

Primary-source anchors:

- OFAS: <https://www.bsv.admin.ch/fr/prevoyance-vieillesse-prevoyance-professionnelle>
  and <https://www.bsv.admin.ch/fr/le-troisieme-pilier>
- OFSP: <https://www.bag.admin.ch/fr/assurance-maladie-primes-et-participation-aux-couts>
  and <https://www.bag.admin.ch/fr/priminfo-le-calculateur-de-primes-officiel-de-la-confederation>
- AFC: <https://www.estv.admin.ch/fr/simulateur-fiscal-calculer-vos-impots>
  and <https://www.estv.admin.ch/fr/impot-a-la-source>
- FINMA: <https://www.finma.ch/fr/surveillance/assurances/instruments-sp%C3%A9cifiques-%C3%A0-un-secteur/individual-life-insurance/>
  and <https://www.finma.ch/fr/news/2025/05/20250522-mm-hypothekarrisiken/>
- ch.ch: <https://www.ch.ch/en/work/salary/salary-certificate/>

## Runtime and audit acceptance

- TDD RED → unchanged-command GREEN plus affected screen/services tests.
- `docs/codex/FIRST_JOB_COHERENCE.mmd` renders through the Mermaid guard.
- Full Doctor before the same-slice Maestro + Patrol real-input proof.
- Lead directly inspects the full-height capture and native hierarchy.
- Wrapper `code` and `product-domain` audits pass with P0=0/P1=0; architecture
  lens is required if a new authority/model is introduced.
- Atomic implementation/evidence commits, push and exact-SHA GitHub CI success.

Private/golden certificates may be used only through existing bounded fixture
gates. Never commit raw derivatives or expose their contents in tracked
evidence.
