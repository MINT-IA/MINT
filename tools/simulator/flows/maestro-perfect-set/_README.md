# Maestro perfect-set — 5 critical-journey flows

Built 2026-05-08 against Maestro 2.5.1 / Java 21 / iPhone 17 Pro sim
(boot-id resolved by harness ; tested target bundle id `ch.mint.app`).

These flows were designed to be the **canonical regression gate** for
the 5 highest-blast-radius journeys in MINT. They follow the
« semantic locators only » contract from
the phase 74 walker panel verdict and
budget at most 4-5 screenshots per run (no auto-Read in agent
sessions per `feedback_screenshot_budget`).

---

## 1. Flow inventory

| Flow file                          | Journey                                   | Duration | Pre-cond | Reliability |
|-----------------------------------|-------------------------------------------|----------|----------|-------------|
| `flow_landing_to_register.yaml`    | Anon → register screen visible            | ~25s     | clean state | HIGH    |
| `flow_drawer_navigation_smoke.yaml`| Drawer routing × 6 entries                | ~45s     | self deep-links to /explore | HIGH |
| `flow_3a_calculator.yaml`          | /pilier-3a renders + LSFin compliance     | ~20s     | deep-link to /pilier-3a | HIGH    |
| `flow_lpp_scan_review.yaml`        | Scan → extraction-review → confirm        | ~30s     | DEBUG build + deep-link to /scan | MEDIUM (debug-only) |
| `flow_empty_state_cascade.yaml`    | Anon empty state → coach greeting (B1+B7) | ~30s     | fresh install + on /explore | HIGH    |

Reliability = how flake-resistant the flow is on a clean cold launch.
HIGH = 100 % deterministic on stable network. MEDIUM = depends on a
debug-only feature.

---

## 2. How to run

### 2.1 Run all 5 sequentially

```bash
cd /Users/julienbattaglia/Desktop/MINT.nosync

# Pre-condition all 5 flows : clean install + dart-defines
flutter build ios --simulator --debug \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
xcrun simctl uninstall booted ch.mint.app
xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app

# Run flows in order. Each flow creates its own output sub-dir.
RUN_ID=$(date -u +%Y%m%d-%H%M%S)
OUT_BASE=".planning/walker/maestro-flows"

for flow in \
  flow_landing_to_register \
  flow_drawer_navigation_smoke \
  flow_3a_calculator \
  flow_lpp_scan_review \
  flow_empty_state_cascade
do
  # Some flows need a deep-link before maestro starts.
  case "$flow" in
    flow_empty_state_cascade)
      xcrun simctl openurl booted ch.mint.app://explore ;;
    flow_3a_calculator)
      xcrun simctl openurl booted ch.mint.app://pilier-3a ;;
    flow_lpp_scan_review)
      xcrun simctl openurl booted ch.mint.app://scan ;;
  esac

  mkdir -p "$OUT_BASE/${flow#flow_}/$RUN_ID"
  maestro test \
    "tools/simulator/flows/maestro-perfect-set/${flow}.yaml" \
    --output "$OUT_BASE/${flow#flow_}/$RUN_ID/result.xml" \
    --format junit \
    || { echo "FAIL: $flow"; exit 1; }
done
```

### 2.2 Run one flow individually

```bash
# Example : just the 3a calculator flow.
xcrun simctl openurl booted ch.mint.app://pilier-3a

maestro test tools/simulator/flows/maestro-perfect-set/flow_3a_calculator.yaml \
  --output .planning/walker/maestro-flows/3a-calculator/manual/result.xml \
  --format junit
```

Drop the `--format junit` to get default human-readable Maestro
output. Add `--debug-output <dir>` to capture a richer artifact set
(view-hierarchy XML dumps per step) when triaging a failure.

### 2.3 Run via the `mint-tools` harness (recommended)

A future harness `tools/simulator/maestro_perfect_set.sh` will wire
the build + uninstall + install + per-flow deep-link + junit roll-up
into one command. It does NOT exist yet (deferred). Until then, the
inline bash above is the supported entry point.

---

## 3. Pre-conditions (mandatory)

### 3.1 Common to all 5 flows

- iPhone 17 Pro sim **booted** (`xcrun simctl boot <udid>` if needed).
- App bundle `ch.mint.app` **installed**. Use a freshly-built
  `--debug --simulator` artifact ; release builds break
  `flow_lpp_scan_review` (debug-only example button).
- Java 21 in `$PATH`. Maestro 2.5.1 refuses to start on Java 17.
- `MINT_DISABLE_BETA_MODAL=true` dart-define recommended ; without
  it the beta gate splash hides the landing CTA.

### 3.2 Flow-specific

| Flow | Extra pre-condition |
|------|---------------------|
| `flow_landing_to_register`  | Logged-out state. If a previous run logged in, uninstall + reinstall (Maestro has no keychain wipe). |
| `flow_drawer_navigation_smoke` | Self-bootstraps from cold launch and deep-links to `/explore`; no harness deep-link precondition. |
| `flow_3a_calculator` | Harness deep-links to `/pilier-3a`. Optional `MINT_E2E_ARCHETYPE=julien_swiss` to seed a non-zero salaireBrutMensuel. |
| `flow_lpp_scan_review` | **DEBUG build mandatory** (debug example button). Harness deep-links to `/scan`. |
| `flow_empty_state_cascade` | **Fresh install mandatory** (an existing CoachProfile masks the empty state). PROHIBITED to set `MINT_E2E_ARCHETYPE`. |

---

## 4. Expected exit codes

All 5 flows follow Maestro's standard convention :

| Exit code | Meaning |
|-----------|---------|
| `0` | All `assertVisible` / `assertNotVisible` / `tapOn` succeeded. |
| `1` | At least one assertion failed OR a tap targeted an absent element. |
| `2` | Maestro itself failed (driver disconnect, sim crashed, install missing). |
| `124` | Step timeout (assertion didn't resolve before its `timeout:` window). |

Per-flow notes :

- `flow_landing_to_register` : exit 1 with assertion « Créer un compte »
  not visible likely means the anon free-turn cap changed and the auth
  gate didn't fire. Inspect anonymous_chat_screen.dart `_isAuthGateLocked`.
- `flow_drawer_navigation_smoke` : exit 1 with « ouvrir-profil-drawer »
  not visible means the `/explore` deep-link did not land on the shell
  screen or the Explorer AppBar semantics anchor drifted. Exit 1 with
  « Mon profil » not visible after the icon tap means ProfileDrawer did
  not open. Run with `--debug-output` to capture the view-hierarchy.
- `flow_3a_calculator` : exit 1 with « Gain fiscal annuel » not visible
  is a financial_core regression — the simulator failed to compute the
  3a tax saving. Check Simulator3aScreen build path.
- `flow_lpp_scan_review` : exit 1 with « VÉRIFICATION » not visible
  after tapping the example button means the seeded fixture dispatcher
  broke. Likely culprit : ExtractionResult shape changed.
- `flow_empty_state_cascade` : exit 1 with « Bienvenue dans MINT. … »
  not visible is the canonical PR #519 / PR #529 regression. Bisect
  the coach orchestrator first-turn greeting wiring.

---

## 5. Where output is written

Convention (matches `feedback_html_evidence_report` memory) :

```
.planning/walker/maestro-flows/<flow-slug>/<run-id>/
  ├── result.xml                  ← junit output
  ├── 01-*.png                    ← takeScreenshot screenshots in order
  ├── 02-*.png
  ├── …
  └── debug/                      ← view-hierarchy XML if --debug-output set
```

The harness rolls up all 5 flow result XMLs into the per-phase
verification HTML at `.planning/phases/<phase>/<phase>-VERIFICATION-REPORT.html`
(per `feedback_html_evidence_report`).

**NEVER** write Maestro output to `/tmp/...` — those artifacts
disappear across sessions and are unrecoverable for the GATE LOG.

---

## 6. Honesty disclosures (anti-sycophancy)

Per CLAUDE.md §9 (0-trust protocol), here is what is NOT yet proven
about these flows :

1. **None of the 5 have been executed end-to-end as of 2026-05-08.**
   They were designed by reading the screen source code + l10n ARBs.
   Each YAML is a reasoned hypothesis ; expect ~1-2 locator drifts on
   first run and budget time to fix them via Maestro's view-hierarchy
   inspector.

2. **`flow_empty_state_cascade` still depends on its own /explore
   precondition.** `flow_drawer_navigation_smoke` no longer has this
   gap as of 2026-05-24: it cold-launches, deep-links to `/explore`,
   and taps the semantic `ouvrir-profil-drawer` anchor.

3. **`flow_lpp_scan_review` step 5 (Confirmer)** has two `optional:`
   tap variants because we did not verify the exact label by reading
   the rendered widget — we only verified the FR string in app_fr.arb.
   If the « Confirmer » short label doesn't render, only « Confirmer
   ces valeurs » will. Both are tried ; one is enough for the screenshot.

4. **`flow_landing_to_register` does not assert that the register form
   is functional** — it stops at form visibility. Driving the form to
   submit and asserting the verify-email screen is a separate, longer
   flow that requires a real email + OTP path (deferred ; see
   `auth_coach_post_hotfix.yaml` header for the auth-seed gap).

5. **None of the 5 flows test reduced-motion, dark-mode, dynamic-type,
   non-FR locales, or A11y voiceover paths.** Those are independent
   axes that multiply the test matrix. This « perfect set » is the
   default-locale, default-motion, light-mode happy + regression set.

6. **`flow_lpp_scan_review` cannot run on a release/profile build.**
   The journalist-defense replacement uses `docScanPasteOcrText` — not
   scripted here. If the QA pipeline ever runs against a release
   build, this flow will silently fail at step 03 ; mark it skipped,
   don't « fix » it by editing release builds to expose debug buttons.

7. **No flow validates a successful network round-trip to staging.**
   Coach replies (`flow_landing_to_register` step 03,
   `flow_empty_state_cascade` step 04) require the staging coach
   endpoint up and the ANTHROPIC_API_KEY set in Railway. If staging
   is down, these flows fail at the « Réponse du coach » assertion
   and the failure looks identical to a real regression. Triage by
   `curl staging/health` first.

---

## 7. References

- Existing inspirations :
  `tools/simulator/flows/julien_swiss.yaml` (anon path, 9 steps)
  `tools/simulator/flows/lauren_expat_us.yaml` (expat_us seed)
  `tools/simulator/flows/auth_coach_post_hotfix.yaml` (auth path,
  blocked by missing auth-seed scaffolding — see its header)

- Locator rule : phase 74 walker panel verdict

- Lint enforcement : `tools/checks/maestro_locator_audit.py` —
  ensure these 5 YAMLs pass before promotion to the gate set.

- Output convention : `feedback_html_evidence_report` (user memory).

- Honesty contract : CLAUDE.md §9 (0-trust protocol).
