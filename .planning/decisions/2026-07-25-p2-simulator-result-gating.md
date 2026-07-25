---
date: 2026-07-25
status: Decided
authors: Claude (Product Leader), founder directive (Julien)
panel: 3-pers (mint-mobile UX+eng, mint-quality-gate a11y+adversarial, mint-swiss-brain meaning)
supersedes: —
superseded_by: —
description: Simulators must gate every computed "your situation" figure behind real user data (per-output, provenance = userProvidedFields ∪ touched); no fabricated default may feed a result.
related:
  - apps/mobile/lib/screens/donation_screen.dart
  - apps/mobile/lib/models/coach_profile.dart
  - apps/mobile/lib/services/donation_service.dart
  - .planning/audit/2026-07-life-event-screens-a11y-gap.md
---

# P2 — Simulators gate computed results behind real user data ("gate dur")

## TLDR

No simulator may present a computed "votre situation" figure built on a
fabricated default: each output is **gated per-output** behind the *determinative*
situation-facts that drive it, a fact counts as present only when its provenance
is `CoachProfile.userProvidedFields ∪ user-touched` (never value≠default), and
the gate is enforced at compute-time, not just render-time.

## Context

Founder P2 priority (2026-07, strategic reset): *« tout ce qui est calculé vient
bien des données de l'utilisateur uniquement, rien n'est inventé et s'il manque
quelque chose, il faut les collecter. »* Founder chose the strictest treatment
via AskUserQuestion 2026-07-25: **« Gate dur du résultat »** — no computation
until the required situation-facts come from the user's real data.

Trigger: PR #1032 (donation seed) got Codex VERDICT: FAIL — seeding real data
when available but *keeping fabricated defaults* (âge 55 / canton VD / 2 enfants /
fortune 800k) when the profile is empty still lets `_simulate()` compute a réserve
héréditaire on invented facts. This is systemic across ~10 simulators
(donation, first_job, naissance, mariage, deces_proche, demenagement, expat,
divorce, independants…), all of which pre-fill situation-facts with invented
defaults and compute on them.

PR #1031 (indépendant seed, merged 4d4fe7b59) established the race-safe
profile-seed + per-field `_touched` pattern this design builds on.

## Decision

We adopt a **per-output result gate** across all simulator screens, with a thin
reusable primitive. Concretely:

### 1. Provenance model (load-bearing correctness rule)
A situation-fact is **confirmed** iff `profile.userProvidedFields.contains(key)`
**OR** the user touched its control. **Never** infer "assumed" by comparing the
current value to the default — a real value equal to the default (age 55, canton
VD) and a legitimate zero (0 children, net-zero worth) both collapse under a
value-comparison test. `userProvidedFields` (`coach_profile.dart:1578`) is the
model's canonical provenance set; touching a control (including confirming a 0)
sets `_touched`. Provenance is **per-field, re-evaluated on every provider
notify** — the single `_prefilled` latch is removed (loadFromWizard notifies up
to 5× as cache→fresh→merged profiles arrive; a latch on notify #1 can strand a
field whose data arrives on notify #2).

### 2. Per-output gating (not per-screen)
Each *output card* gates on the facts that are **determinative for that output**,
not the union of all situation-facts. For donation:
- **Gift tax (cantonal, no federal gift tax):** gates on `canton` (situs canton
  for immovables). Child count / fortune / age are tax-irrelevant.
- **Réserve héréditaire (federal, CC art. 470-471):** gates on
  **marital-status / spouse-presence** + **présence d'enfants (0 vs ≥1)**.
  Canton is réserve-irrelevant.
- `age` drives **neither** output → **not gated** (pure friction, zero compliance
  benefit).
- `exact nombre d'enfants` → hard-gate only when donee = descendant; otherwise a
  surfaced, editable, documented assumption (presence suffices for aggregate
  quotité).
- `fortune nette` → needed only to translate the réserve *fraction* into a CHF
  figure; prefer expressing the quotité as a legally-exact, canton-independent
  fraction and gating only the CHF translation on fortune.
- `régime matrimonial` and prior-`avancement d'hoirie` (réunion, CC art. 475) are
  **situation facts**, surfaced as editable *documented* assumptions
  (participation aux acquêts = legal default, CC art. 181), conditional on
  marital status — never silent defaults.

### 3. Enforcement + freshness
- Gate at **compute-time**: `_simulate()` must not produce a figure for an output
  whose determinative facts aren't all confirmed; the CTA morphs to
  « Compléter ma situation (N/total) » and scrolls to the first gap (button stays
  enabled — no silent hard-disable).
- **Stale-result invalidation:** editing or re-seeding any determinative fact
  nulls the affected output result; a displayed figure never outlives a
  provenance change.
- **All-or-nothing per output:** no partial/preview figure on a missing fact.

### 4. Reusable primitive (ship once, apply per screen ~15-20 lines)
`SituationFact { key, l10nLabel, provenance∈{seededFromProfile,touched,assumed} }`
+ `SituationGate(facts) { bool complete; List<missing> }` (pure, unit-tested)
+ `SituationGateCard({missing, total, controls})` rendered **in the result slot**.
Do **not** reuse `PrecisionPromptCard` — its « Continuer avec l'estimation »
secondary action (`precision_prompt_card.dart:168`) is the exact escape hatch P2
bans. Borrow the visual vocabulary only.

### 5. Accessibility (ILLOG-02 class)
Gate + result render inside premium gradient surfaces that collapse on the iOS AX
bridge. Required: screen-root `Semantics(container:true, explicitChildNodes:true,
identifier:)` (rente_vs_capital pattern), gate card exposes **discrete
per-fact focusable labeled nodes** (not one icon+blob), `SemanticsService.announce`
on gate-lift (scroll ≠ focus move). Maestro/wrapper green is
necessary-but-insufficient — a **manual VoiceOver device pass** is the real gate
(the wrapper was proven insufficient on `invalidite`,
`.planning/audit/2026-07-life-event-screens-a11y-gap.md`). The revealed number
still owes NEVER #9 (uncertainty band, no naked number).

### 6. Anti-façade tests (assert on the RENDERED figure, not an internal bool)
Per screen, each must go RED if the gate is deleted: (a) no-profile → tap →
result figure findsNothing + gate lists missing facts; (b) partial profile →
still gated on the remainder; (c) complete profile with values ≠ defaults →
figure equals service output on seeded values; (d) touched-all → result present;
(e) two-notification race → fact confirms after the 2nd notify; (f)
default-collision pair (profile==defaults → shown; no-profile same numbers →
gated); (g) stale invalidation → edit fact → prior figure gone; (h) a11y
non-regression + a manual VoiceOver device-gate item.

### Swiss-law constants (verified P1-clean for donation)
`DonationService.reserves = {descendant:0.50, conjoint:0.50, parent:0.0}`
(`donation_service.dart:110-113`) is **post-2023 reform** correct. Pin all
réserve constants to the 1 Jan 2023 reform (descendants 1/2 not 3/4, parents 0,
spouse/partenaire enregistré 1/2) with CC citations; disclose the 1 Jan 2026
business-succession second tranche as out-of-scope when `type = entreprise`;
`partenaire enregistré` counts as `conjoint` (LPart).

## Counter-arguments and data gaps

- **Strongest opposing view (rejected):** "These are *simulateurs* — editable
  what-if tools; a pre-filled default is a neutral starting point the user
  reviews, not a claim about their situation, so seeding real data when available
  (the PR #1031 approach) is sufficient and the gate adds friction / abandonment
  risk." Steel-manned: for a pure exploration tool this is defensible, and the
  gate does raise completion cost. Rejected because the founder explicitly chose
  the strict gate, and because a réserve/gift-tax figure computed on a fabricated
  canton or family shape is *materially* wrong (off by the entire cantonal tax;
  wrong quotité), i.e. a misleading personalised statement under LSFin art. 8-9 /
  68 — not a neutral placeholder.
- **What this design does not yet address (data gaps):** (1) VoiceOver behaviour
  of the gated premium surface is **unmeasured** — the ILLOG-02 wrapper is
  documented insufficient on at least one sibling screen; needs a device pass. (2)
  The "legitimate zero vs unknown" product ruling (0 children, net-zero) needs an
  explicit `userProvidedFields` marker or a confirm-the-zero interaction; not all
  facts have a provenance key today (children + investissements/immobilier have
  **no** `userProvidedFields` key — only age/canton/salary/liquidSavings/debt do,
  `coach_profile.dart:3431-3504`), so some facts can currently only be confirmed
  via `_touched`. (3) Per-screen determinative-fact manifests for the other ~9
  simulators are not yet analysed (each needs its own Swiss-law pass). (4) Marital
  status is not currently a distinct donation-screen input; adding it + wiring to
  the réserve calc is required.
- **What would change this conclusion:** if the founder later re-scopes P2 to
  "seed-when-available, label-when-assumed" (the softer Option A), the hard gate
  is replaced by a visible-assumption banner; or if a `userProvidedFields` key is
  added for every situation fact, the `_touched`-only fallback for un-keyed facts
  can be dropped.

## Sources

- AskUserQuestion 2026-07-25 (founder chose « Gate dur du résultat »)
- Codex gpt-5.6-sol adversarial review of PR #1032 (VERDICT: FAIL)
- 3-panel verdicts 2026-07-25 (mint-mobile, mint-quality-gate, mint-swiss-brain)
- apps/mobile/lib/services/donation_service.dart:110-113 (post-2023 constants)
- apps/mobile/lib/models/coach_profile.dart:1578 (userProvidedFields), :3431-3504 (provided keys)
- .planning/audit/2026-07-life-event-screens-a11y-gap.md (ILLOG-02, VoiceOver-unmeasured)
- CC art. 181, 196 ff, 221 ff, 470-471, 475; reform 1 Jan 2023; business-succession tranche 1 Jan 2026; LPart

## Status & follow-up

- Reference implementation: PR #1032 (donation) — extend from seed-only to
  seed + provenance + per-output gate + primitive + a11y + anti-façade tests.
- Replication: one bead per remaining simulator, each with its own
  determinative-fact manifest (Swiss-law pass) — tracked as the P2 simulator
  phase.
- Re-litigation triggers: founder re-scopes P2 to soft "label-assumption";
  `userProvidedFields` gains keys for all situation facts; VoiceOver device pass
  invalidates the ILLOG-02 wrapper approach.
