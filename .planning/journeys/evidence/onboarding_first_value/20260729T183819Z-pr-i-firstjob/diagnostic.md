# PR-I — preuve runtime tranche firstJob (2026-07-29)

Sim : iPhone 16e · iOS 26.2 · Flutter 3.41.6 · build debug simulator
`--dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1`
`--dart-define=MINT_E2E_ARCHETYPE=jeune_diplome_zurich` (Léa, 25 ans, ZH, brut 6'500).
Doctrine 0-TRUST : chaque claim ci-dessous porte sa preuve.

## Verdict

La tranche firstJob **s'affiche et calcule correctement** sur sim réel
(captures), mais le flow d'acceptation par **locators sémantiques ne peut PAS
passer au vert** sur ce sim : l'arbre AX iOS 26.2 **effondre la route
`/first-job` (et `rente_vs_capital`) en un seul nœud**, la rendant invisible à
Maestro/idb. Ce n'est PAS un défaut de la tranche firstJob — c'est une
régression systémique du pont d'accessibilité (touche le motif de référence
`rente_vs_capital` à l'identique). Le renommage `_red → CORE` n'est donc PAS
fait (le flow ne peut pas être vert).

## Ce qui est PROUVÉ (runtime, sim)

| Élément | Preuve | Statut |
|---|---|---|
| Seed jeune_diplome_zurich → shell `/home` | `idb describe` : Aujourd'hui/Mon argent/Coach/Explorer + carte firstJob | OK |
| RED-1 carte `home-lifeevent-card-firstJob` présente, tappable | Maestro `tapOn ... COMPLETED` (probe_home + run) ; nœud Button 358×70 enabled | OK |
| RED-1 nav → `/first-job` rend l'écran | capture `state_firstjob.png` : « Premier emploi / Ton premier salaire expliqué » avec seed 6'500 / 25 ans / ZH / 100 % | OK |
| Drain PR-A (un seul net) | capture `fj_luc_d2.png` : Brut 6'500 → Net **5'849** (90 %), AVS/AI/APG 5.3 %, AC, AANP 1.3 %, LPP 2.3 % ; employeur +605 | OK |
| Appareil de lucidité PR-C | capture `fj_luc_d2.png` : « ✓ AVS · AC · LPP · AANP · barèmes 2026 » (source-vintage) + « Pourquoi ce chiffre ? » (why-net) + trame confiance | OK |
| RED-2 CTA `firstjob-ask-coach` | capture `fj_luc_d2.png` : bouton « Demander au coach » rendu | OK (rendu ; tap non assertable, cf. infra) |
| LSFin PR-G | capture `fj_mid.png` : « ATTENTION — ASSURANCE-VIE 3A / Compare les types… » (badge TOP neutralisé) | OK |
| `firstjob-net-value` (ancre manquante PR-A, ajoutée PR-I) | widget test `first_job_lucidite_test.dart` 4/4 vert (findsOneWidget + porte receipt.value + findsNothing gate incomplet) | OK |

## Ce qui est BLOQUÉ (avec cause)

| Élément | Cause | Preuve |
|---|---|---|
| Assertions sémantiques `/first-job` (net-value, confidence-chip, source-vintage, ask-coach) | Effondrement AX iOS 26.2 : `/first-job` → 1 nœud « MINT » | JUnit `result.xml` : `first_job_screen is visible` = false alors que la capture Maestro d'échec montre l'écran RENDU ; `idb describe` /first-job = 1 nœud |
| Même effondrement sur `rente_vs_capital` (motif de référence ILLOG-02) | idem, systémique | `idb describe` rvc = 1 nœud « MINT » |
| Parité coach 5b/5c + store/resolve receipt | Staging **169 commits derrière dev** : `POST /api/v1/lucidity/receipts` = **404** (endpoint PR-B non déployé) ; `/api/v1/health` = 200, lucidity router = 401 | curl staging 2026-07-29 |
| Marche onboarding réelle (T0→T2 sémantique) | 9/11 testIDs `onb-*` absents du code (décision onboarding-canonique, hors-tranche) | grep `apps/mobile/lib` |
| Anti-critère A4 (bloc ANTI) | marqueurs `e2e-staging-down-marker` / `coach_empty_blank_state` **absents du code** → `runFlow when` jamais déclenché (no-op) | grep `apps/mobile/lib` |
| Corrections lois PR-H (partiel) | items checklist corrigés (`LFLP art. 2`, `LFLP art. 4 al. 2`, `LAMal art. 71`) MAIS le footer de section `jobChangeChecklistDisclaimer` cite encore « LPP art. 3 (libre passage), OLP art. 1-3 » | capture `fj_bottom.png` + `app_fr.arb:9493` |

## Seuils go/no-go (spec §5) — mesuré

- **Taps jusqu'au premier chiffre : 1** (tap `home-lifeevent-card-firstJob` depuis `/home` seedé) ≤ 12. Les taps d'onboarding sont exclus (onb-* non câblés) ; le compte end-to-end réel n'est pas mesurable en locators sémantiques aujourd'hui.
- **Temps jusqu'au premier chiffre : < 10 s** (rendu `/first-job` après tap, capture) ≤ 90 s. Non horodaté par Maestro (le chiffre n'est pas assertable — effondrement AX).
- **Crash-free : ~6 runs informels, 0 crash** (app vivante, `launchctl` OK). Sweep formel 20/20 NON effectué (le flow ne peut pas se terminer — effondrement AX).
- **Divergence intra-écran : 0** — le net 5'849 est unique (breakdown = lucidité = receipt.value), prouvé par widget test A2/A3.

## Reproduire

```
cd apps/mobile && CODE_SIGNING_ALLOWED=NO flutter build ios --debug --simulator --no-codesign \
  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
  --dart-define=MINT_E2E_ARCHETYPE=jeune_diplome_zurich
xcrun simctl install <UDID> build/ios/iphonesimulator/Runner.app
maestro test tools/simulator/flows/firstjob_tranche_acceptance_seeded.yaml   # échoue sur first_job_screen (effondrement AX)
```

Captures clés (scratchpad de session, non commitées — .png interdit sous journeys/evidence) :
`state_firstjob.png`, `fj_mid.png`, `fj_bottom.png`, `fj_luc_d2.png`.
