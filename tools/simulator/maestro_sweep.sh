#!/usr/bin/env bash
# tools/simulator/maestro_sweep.sh — S98 Phase 5.C
#
# Runs the Maestro flow inventory against a booted iOS sim,
# wraps each invocation in `maestro_with_watchdog.sh` (stall detector
# + auto-classifier), and aggregates findings into a sweep-summary.md.
#
# Per CLAUDE.md §9 0-trust : every claim about a flow's status carries
# a deterministic citation (exit code + artifact dir + classifier
# primary hypothesis).
#
# Usage:
#   tools/simulator/maestro_sweep.sh
#       — runs the curated default sweep (e2e + regression + top
#         perfect-set flows). Excludes deeplink + personas by default.
#   tools/simulator/maestro_sweep.sh --tier <tier>
#       — runs one tier. Tiers :
#           e2e        — the ship-gate journey (1 flow)
#           regression — bug-XXX regression locks (excl. deeplink)
#           perfect    — perfect-set flows (workflow E + LSFin)
#           personas   — Premier Éclairage personas (julien_swiss, lauren_expat_us)
#           fatca      — FATCA 3a gate, requires an expat_us seeded build
#           firstjob   — tranche firstJob acceptance, requires a
#                        jeune_diplome_zurich seeded build (+ PROOF_ANCHORS)
#           tierb-famille — Tier B smoke lot B1 (mariage/naissance/divorce/
#                        concubinage), requires a julien_swiss seeded build
#                        (+ PROOF_ANCHORS). Voir 00-CADRAGE Tier B smoke.
#           tierb-famille-seeded — Tier B smoke lot B1, variantes SEEDÉES
#                        famille_bern assertant le RÉSULTAT C2 chiffré
#                        (APG / rente survivant / matrice / impact fiscal).
#                        Requires a famille_bern seeded build (+ PROOF_ANCHORS)
#                        — un build = un seed, hors sweep normal.
#           tierb-travail — Tier B smoke lot B2 (newJob / jobLoss /
#                        selfEmployment), requires a julien_swiss seeded build
#                        (+ PROOF_ANCHORS). La persona SALARIÉE atteint C2 chiffré
#                        sur les 3 écrans. Voir 00-CADRAGE Tier B smoke.
#           tierb-logement — Tier B smoke lot B3 (housingPurchase / inheritance /
#                        housingSale / donation), requires a julien_swiss seeded
#                        build (+ PROOF_ANCHORS). hypotheque/succession chiffrent
#                        au repos ; housing-sale/donation après « Calculer »
#                        (donation gate fiscal ouvert seed-alone via le canton).
#                        Voir 00-CADRAGE Tier B smoke.
#           tierb-b4   — Tier B smoke lot B4 Décès/Santé/Mobilité (deathOfRelative
#                        / disability / cantonMove), requires a julien_swiss
#                        seeded build (+ PROOF_ANCHORS). deces/demenagement =
#                        AppBar FIXE (AX-sain) ; invalidite = motif firstJob
#                        (CustomScrollView + SliverAppBar + wrapper racine) →
#                        C5 (et possiblement C1) ROUGES ATTENDUS = SIGNAL AX du
#                        cadrage (dette AX, non masqué). Voir 00-CADRAGE Tier B.
#           deeplink   — opt-in deeplink/Universal Link flows (sim-unreliable,
#                        crashes SafariViewService on long-booted sims —
#                        per memory `feedback_sim_crash_mitigation`)
#           all        — e2e + regression + perfect + personas
#                        (no deeplink; no FATCA because FATCA needs expat_us)
#           default    — e2e + regression + perfect (no personas, no deeplink,
#                        no FATCA because one installed app cannot be both the
#                        normal user build and the expat_us seeded build)
#
# Env (forwarded to the watchdog) :
#   MAESTRO_STALL_THRESHOLD, MAESTRO_HARD_LIMIT, MINT_DEBUG_PORT, MINT_BUNDLE_ID
#
# Sweep-specific env :
#   MAESTRO_SWEEP_NO_REBOOT=1   skip the pre-sweep sim shutdown+boot
#                                (default: reboot for clean state)
#
# Output : `.planning/_walker/sweep-<TS>/`
#   ├── <flow_slug>/
#   │   ├── maestro.log
#   │   ├── debug-state.json (if Tier 2 endpoint reachable)
#   │   ├── oslog-mint.txt
#   │   ├── last-screen.png
#   │   ├── cassure-report.json (classifier output)
#   │   ├── STALLED (if applicable)
#   │   └── EXIT_CODE
#   └── sweep-summary.md (aggregate)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WATCHDOG="$SCRIPT_DIR/maestro_with_watchdog.sh"
CLASSIFIER="$REPO_ROOT/tools/debug/cassure-classifier.sh"

[ -x "$WATCHDOG" ]   || { echo "ERROR: watchdog at $WATCHDOG not found/executable" >&2; exit 1; }
[ -x "$CLASSIFIER" ] || { echo "ERROR: classifier at $CLASSIFIER not found/executable" >&2; exit 1; }

# ── Flow selection ────────────────────────────────────────────────────
TIER="${1:-default}"
[ "$TIER" = "--tier" ] && TIER="${2:-default}"

declare -a FLOWS

FLOWS_E2E=(
  "$REPO_ROOT/tools/simulator/flows/e2e/flow_e2e_new_user_full_journey.yaml"
)
FLOWS_REGRESSION=(
  "$REPO_ROOT/tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml"
  "$REPO_ROOT/tools/simulator/flows/regression/bug__F001__chat_input_bar_exists.yaml"
  "$REPO_ROOT/tools/simulator/flows/regression/bug__S001__cap_du_jour_action_bar_reachable.yaml"
  "$REPO_ROOT/tools/simulator/flows/regression/bug__S002__maestro_cold_launch_fragment.yaml"
  "$REPO_ROOT/tools/simulator/flows/regression/bug__P004__overlay_populated_on_open.yaml"
  "$REPO_ROOT/tools/simulator/flows/regression/bug__F001_S001_combined__chat_via_cap_du_jour.yaml"
)
# Deeplink/Safari flows are sim-unreliable per their own header docs
# (mintapp:// URL scheme + Universal Link both invoke SafariViewService
# fallbacks that crash on long-booted sims — confirmed 2026-05-14 via
# 2 EXC_BAD_ACCESS@0x20 crashes in one session, polluting bug__S003
# from ✅→❌ unrelated to app code). Pulled out of default --tier all
# into an opt-in --tier deeplink. Run them only on a freshly-booted
# sim or a real device.
FLOWS_DEEPLINK=(
  "$REPO_ROOT/tools/simulator/flows/regression/bug__S003__mintapp_scheme_opens_app.yaml"
  "$REPO_ROOT/tools/simulator/flows/regression/bug__S004_F006_F007__universal_link_opens_app.yaml"
)
FLOWS_PERFECT=(
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_landing_to_register.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_drawer_navigation_smoke.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_b15_concrete_facts_chips.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_empty_state_cascade.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_3a_calculator.yaml"
  # ── Sweep #3 audit (2026-05-14) — pivot per Julien feedback ──────────
  # The first curated set covered 1/3 of workflow E (only 3a calculator)
  # and 0/2 of LSFin compliance. Added :
  #   - flow_extractor_captures_age_canton — workflow E : profile data
  #     capture (canton + income + birthYear) via dual-LLM extractor.
  #     Requires COACH_DUAL_LLM_ENABLED=True on Railway staging.
  #   - flow_lpp_scan_review — workflow E : PDF LPP → ExtractionReview
  #     → save to Biography + CoachProfile. The « bibliothèque de
  #     variables » round-trip Julien named as critical.
  #   - flow_narrator_refuses_uncited_numbers — LSFin compliance gate
  #     (Phase 94 G1). Requires COACH_CITATION_GATE_ENABLED=true on
  #     Railway staging. Without this, the coach can fabricate CHF / %
  #     / duration in production = LSFin breach.
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_lpp_scan_review.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml"
)
FLOWS_FATCA=(
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_fatca_3a_gate.yaml"
)
# Tranche firstJob acceptance (ADR AX iOS 26.2 Etape 2, promu 2026-07-30).
# Tier SEEDE dedie : exige un build jeune_diplome_zurich + PROOF_ANCHORS
# (cf. en-tete du flow) — comme FATCA, un app installe normal ne peut pas
# le servir, donc hors des tiers auto (default / all).
FLOWS_FIRSTJOB=(
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_firstjob_tranche_acceptance_seeded.yaml"
)
# Tier B smoke — lot B1 Famille (cadrage mint-utilisable-tier-b-smoke).
# Tier SEEDÉ dédié : exige un build julien_swiss + PROOF_ANCHORS (cf. en-tête
# de chaque flow) — comme FATCA / firstJob, un app installé normal ne peut pas
# le servir, donc hors des tiers auto (default / all).
FLOWS_TIERB_FAMILLE=(
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_famille_mariage.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_famille_naissance.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_famille_divorce.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_famille_concubinage.yaml"
)
# Tier B smoke — lot B1 Famille SEEDÉ (famille_bern). Variantes assertant le
# RÉSULTAT C2 chiffré débloqué par le seed couple/enfant (#1135). Tier SEEDÉ
# dédié : exige un build famille_bern + PROOF_ANCHORS — un build = un seed, donc
# hors des tiers auto (default / all), comme FATCA / firstJob / tierb-famille.
FLOWS_TIERB_FAMILLE_SEEDED=(
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_famille_seeded_mariage.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_famille_seeded_naissance.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_famille_seeded_divorce.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_famille_seeded_concubinage.yaml"
)
# Tier B smoke — lot B2 Travail (cadrage mint-utilisable-tier-b-smoke). Tier SEEDÉ
# dédié : exige un build julien_swiss (salarié) + PROOF_ANCHORS — la persona
# salariée atteint C2 chiffré sur les 3 écrans (indemnité chômage / comparaison
# d'emploi / perte Jour J indépendant). Un build = un seed, hors sweep normal.
FLOWS_TIERB_TRAVAIL=(
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_travail_job_comparison.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_travail_unemployment.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_travail_independant.yaml"
)
# Tier B smoke lot B3 Logement & Patrimoine (housingPurchase / inheritance /
# housingSale / donation), tier de sweep dédié : exige un build julien_swiss +
# PROOF_ANCHORS. hypotheque/succession chiffrent au repos (SliverAppBar → dette AX
# C5) ; housing-sale/donation chiffrent après « Calculer » (AppBar fixe, AX-sain ;
# donation gate fiscal ouvert seed-alone via le canton). Un build = un seed, hors
# sweep normal.
FLOWS_TIERB_LOGEMENT=(
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_logement_hypotheque.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_logement_succession.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_logement_housing_sale.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_logement_donation.yaml"
)
# Tier B smoke lot B4 Décès / Santé / Mobilité (deathOfRelative / disability /
# cantonMove), tier de sweep dédié : exige un build julien_swiss + PROOF_ANCHORS.
# deces/demenagement = AppBar FIXE (AX-sain) : deces NON-VIDE au repos (chiffré
# CHF touch-only, prouvé au widget test) ; demenagement chiffre après 2 touches
# id-ciblées. invalidite = CustomScrollView + SliverAppBar + wrapper racine =
# motif firstJob → C5 (et possiblement C1) ROUGES ATTENDUS (dette AX, SIGNAL du
# cadrage, non masqué). Un build = un seed, hors sweep normal.
FLOWS_TIERB_B4=(
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_b4_deces.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_b4_demenagement.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_tierb_b4_invalidite.yaml"
)
FLOWS_PERSONAS=(
  "$REPO_ROOT/tools/simulator/flows/julien_swiss.yaml"
  "$REPO_ROOT/tools/simulator/flows/lauren_expat_us.yaml"
)
case "$TIER" in
  e2e)        FLOWS=("${FLOWS_E2E[@]}") ;;
  regression) FLOWS=("${FLOWS_REGRESSION[@]}") ;;
  perfect)    FLOWS=("${FLOWS_PERFECT[@]}") ;;
  fatca)      FLOWS=("${FLOWS_FATCA[@]}") ;;
  firstjob)   FLOWS=("${FLOWS_FIRSTJOB[@]}") ;;
  tierb-famille) FLOWS=("${FLOWS_TIERB_FAMILLE[@]}") ;;
  tierb-famille-seeded) FLOWS=("${FLOWS_TIERB_FAMILLE_SEEDED[@]}") ;;
  tierb-travail) FLOWS=("${FLOWS_TIERB_TRAVAIL[@]}") ;;
  tierb-logement) FLOWS=("${FLOWS_TIERB_LOGEMENT[@]}") ;;
  tierb-b4)   FLOWS=("${FLOWS_TIERB_B4[@]}") ;;
  personas)   FLOWS=("${FLOWS_PERSONAS[@]}") ;;
  deeplink)   FLOWS=("${FLOWS_DEEPLINK[@]}") ;;
  all)        FLOWS=("${FLOWS_E2E[@]}" "${FLOWS_REGRESSION[@]}" "${FLOWS_PERFECT[@]}" "${FLOWS_PERSONAS[@]}") ;;
  default)    FLOWS=("${FLOWS_E2E[@]}" "${FLOWS_REGRESSION[@]}" "${FLOWS_PERFECT[@]}") ;;
  *)          echo "Unknown tier: $TIER (use: e2e | regression | perfect | fatca | firstjob | tierb-famille | tierb-famille-seeded | tierb-travail | tierb-logement | tierb-b4 | personas | deeplink | all | default)" >&2; exit 1 ;;
esac

# ── Reboot the booted sim before any flow runs ────────────────────────
# Per memory `feedback_sim_crash_mitigation` (2026-05-14) : long-booted
# iOS sims accumulate state and produce EXC_BAD_ACCESS@0x20 crashes in
# SpringBoard / SafariViewService mid-sweep, contaminating downstream
# flow results (e.g. bug__S003 flipping ✅→❌ unrelated to app code).
# Shutdown + boot is idempotent + ~10s overhead ; isolates each sweep
# from the prior session's accumulated state.
#
# Set MAESTRO_SWEEP_NO_REBOOT=1 to skip (useful when chaining sweeps
# back-to-back during active investigation, or when the sim was JUST
# booted via simctl boot in the harness invocation).
if [ "${MAESTRO_SWEEP_NO_REBOOT:-0}" != "1" ]; then
  booted_udid=$(xcrun simctl list devices booted -j 2>/dev/null \
    | jq -r '.devices | to_entries[].value[] | select(.state=="Booted") | .udid' \
    | head -1)
  if [ -n "$booted_udid" ]; then
    echo "[sweep] rebooting sim $booted_udid for clean state..."
    xcrun simctl shutdown "$booted_udid" 2>/dev/null || true
    sleep 2
    xcrun simctl boot "$booted_udid" 2>/dev/null || true
    sleep 4
    # Re-launch app so the first flow's launchApp finds it installed
    # (xcrun simctl boot doesn't restore foreground app).
    xcrun simctl launch booted "${MINT_BUNDLE_ID:-ch.mint.app}" 2>/dev/null || true
    sleep 2
    echo "[sweep] reboot complete."
  else
    echo "[sweep] no booted sim found ; skipping reboot." >&2
  fi
fi

# ── Setup sweep dir + summary header ──────────────────────────────────
TS="$(date +%Y%m%dT%H%M%S)"
SWEEP_DIR="$REPO_ROOT/.planning/_walker/sweep-$TS"
mkdir -p "$SWEEP_DIR"
SUMMARY="$SWEEP_DIR/sweep-summary.md"

{
  echo "# Maestro sweep — $TS"
  echo ""
  echo "**Tier:** $TIER"
  echo "**Flow count:** ${#FLOWS[@]}"
  echo "**Watchdog stall threshold:** ${MAESTRO_STALL_THRESHOLD:-90}s"
  echo "**Watchdog hard limit:** ${MAESTRO_HARD_LIMIT:-900}s"
  echo "**Sweep dir:** \`$SWEEP_DIR\`"
  echo ""
  echo "## Per-flow results"
  echo ""
  echo "| Exit | Flow | Hypothesis | Suspect file |"
  echo "|---:|:---|:---|:---|"
} > "$SUMMARY"

# ── Run each flow ─────────────────────────────────────────────────────
total=${#FLOWS[@]}
i=0
green=0
red=0
stalled=0
hard_limit=0

for flow in "${FLOWS[@]}"; do
  i=$((i + 1))
  slug=$(basename "$flow" .yaml)
  echo ""
  echo "[$i/$total] $slug"
  echo "  → $flow"

  if [ ! -f "$flow" ]; then
    echo "  SKIP  flow file missing"
    echo "| ⚠️ skip | \`$slug\` | (missing flow file) | — |" >> "$SUMMARY"
    continue
  fi

  flow_dir="$SWEEP_DIR/$slug"
  mkdir -p "$flow_dir"

  extra_maestro_args=()
  if [ "$slug" = "flow_e2e_new_user_full_journey" ]; then
    e2e_email="${MINT_E2E_EMAIL:-e2e+${TS}@mint-e2e.ch}"
    e2e_password="${MINT_E2E_PASSWORD:-TestE2E123!}"
    printf 'MINT_E2E_EMAIL=%s\n' "$e2e_email" > "$flow_dir/env.txt"
    extra_maestro_args=(
      --env "MINT_E2E_EMAIL=$e2e_email"
      --env "MINT_E2E_PASSWORD=$e2e_password"
    )
  fi

  # Run via watchdog. `set +e` so a non-zero exit doesn't kill the sweep.
  # Note: NO `--device booted` flag. That's an Android convention ; on
  # iOS Maestro 2.5.1 it raises « Device booted was requested, but it is
  # not connected. » even when a sim IS booted. Maestro auto-discovers
  # the booted iOS sim when --device is omitted.
  set +e
  if [ "${#extra_maestro_args[@]}" -gt 0 ]; then
    MINT_WALKER_ARTIFACTS="$flow_dir" \
      "$WATCHDOG" test "$flow" "${extra_maestro_args[@]}"
  else
    MINT_WALKER_ARTIFACTS="$flow_dir" \
      "$WATCHDOG" test "$flow"
  fi
  rc=$?
  set -e
  echo "$rc" > "$flow_dir/EXIT_CODE"

  # Determine status emoji + counters
  case "$rc" in
    0)    icon="✅"; green=$((green + 1)) ;;
    124)  icon="⏸️ stall"; stalled=$((stalled + 1)) ;;
    137)  icon="🛑 hard-limit"; hard_limit=$((hard_limit + 1)) ;;
    *)    icon="❌ exit $rc"; red=$((red + 1)) ;;
  esac

  # Classifier already ran inside the watchdog dump path on stall.
  # For non-stall failures (rc!=0, rc!=124, rc!=137), the watchdog never
  # called dump_state() — so flow_dir contains only EXIT_CODE + maestro.log.
  # The classifier degrades gracefully on missing inputs, but to maximize
  # signal we proactively capture the same artifacts the stall path would
  # have produced :
  #   - last-screen.png  ← Maestro's own debug screenshot from
  #                        ~/.maestro/tests/<latest>/screenshot-❌-*.png
  #                        (Maestro takes one on assertion failure)
  #   - oslog-mint.txt   ← simctl log show, ch.mint.* tag, last 5 min
  #   - cassure-report.json ← classifier output, always invoked on rc!=0
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 124 ] && [ "$rc" -ne 137 ]; then
    # Maestro screenshot (best-effort).
    if [ -d "$HOME/.maestro/tests" ]; then
      latest_trace=$(ls -t "$HOME/.maestro/tests" 2>/dev/null | head -1)
      if [ -n "$latest_trace" ]; then
        # Maestro names failure screenshots screenshot-❌-<ms>-<flow>.png.
        # Copy the most recent one into the flow_dir as last-screen.png.
        latest_screenshot=$(ls -t "$HOME/.maestro/tests/$latest_trace"/screenshot-*.png 2>/dev/null | head -1 || true)
        if [ -n "$latest_screenshot" ]; then
          cp "$latest_screenshot" "$flow_dir/last-screen.png" 2>/dev/null || true
        fi
        # Also copy Maestro's full per-flow trace dir for downstream forensics.
        cp -R "$HOME/.maestro/tests/$latest_trace" "$flow_dir/maestro-trace/" 2>/dev/null || true
      fi
    fi
    # Sim OSLog (best-effort, requires booted sim).
    xcrun simctl spawn booted log show --last 5m \
      --predicate 'subsystem CONTAINS "mint" OR category CONTAINS "mint"' \
      --style compact > "$flow_dir/oslog-mint.txt" 2>/dev/null || true
    # Always invoke classifier — it degrades gracefully on missing inputs
    # and produces at minimum the maestro_assertion_failed hypothesis from
    # parsing the FAILED line in maestro.log.
    "$CLASSIFIER" \
      --state       "$flow_dir/debug-state.json" \
      --oslog       "$flow_dir/oslog-mint.txt" \
      --maestro-log "$flow_dir/maestro.log" \
      --flow-path   "$flow" \
      --out         "$flow_dir/cassure-report.json" \
      2> "$flow_dir/classifier.log" || true
  fi

  # Pull primary hypothesis if a report exists
  hyp="—"
  suspect="—"
  if [ -f "$flow_dir/cassure-report.json" ]; then
    hyp=$(jq -r '.primary_hypothesis.hypothesis // "—"' "$flow_dir/cassure-report.json" 2>/dev/null || echo "—")
    suspect=$(jq -r '.primary_hypothesis.suspect_file // "—"' "$flow_dir/cassure-report.json" 2>/dev/null || echo "—")
  fi

  echo "  $icon  hypothesis=$hyp"
  echo "| $icon | \`$slug\` | $hyp | \`$suspect\` |" >> "$SUMMARY"
done

# ── Aggregate footer ──────────────────────────────────────────────────
{
  echo ""
  echo "## Totals"
  echo ""
  echo "- ✅ green: $green / $total"
  echo "- ❌ red: $red / $total"
  echo "- ⏸️ stalled: $stalled / $total"
  echo "- 🛑 hard-limit: $hard_limit / $total"
  echo ""
  echo "## Next steps"
  echo ""
  if [ "$red" -gt 0 ] || [ "$stalled" -gt 0 ] || [ "$hard_limit" -gt 0 ]; then
    echo "1. Open each non-green artifact dir under \`$SWEEP_DIR/\`."
    echo "2. Read its \`cassure-report.json\` \`primary_hypothesis\`."
    echo "3. The \`suspect_file\` is the first place to look."
    echo "4. \`oslog-mint.txt\` + \`last-screen.png\` are the second-line evidence."
  else
    echo "Selected tier \`$TIER\` is green."
    echo ""
    echo "Scope note: \`default\` and \`all\` intentionally exclude opt-in"
    echo "deeplink/Universal Link flows, and they exclude FATCA unless"
    echo "the dedicated \`fatca\` tier is run against an expat_us build."
    echo "Do not use this summary alone as signed device/TestFlight or"
    echo "store-signing evidence."
  fi
} >> "$SUMMARY"

echo ""
echo "=== Sweep complete ==="
echo "  Summary: $SUMMARY"
echo "  Green:   $green / $total"
echo "  Red:     $red / $total"
echo "  Stalled: $stalled / $total"
echo "  Hard:    $hard_limit / $total"

# Non-zero exit if any flow failed — useful for CI gating downstream.
if [ "$red" -gt 0 ] || [ "$stalled" -gt 0 ] || [ "$hard_limit" -gt 0 ]; then
  exit 1
fi
exit 0
