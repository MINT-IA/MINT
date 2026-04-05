# W17 — "MINT POUR TOUS" — Orchestration corrigée

> **⚠️ LEGACY NOTE (2026-04-05):** Sprint history. Uses "chiffre choc" (legacy term → "premier éclairage", see `docs/MINT_IDENTITY.md`).
>
> **Corrigé post-audit** : P2 supprimé (Pulse déjà adaptatif depuis 2026-03-22).
> 5 prompts au lieu de 6. Waves restructurées.

## CONTEXTE
MINT est une app de retraite déguisée en app de vie financière.
Les hubs Explorer sont hardcodés (Retraite #1 pour tous). L'instant chiffre choc ne call pas ChiffreChocSelector. L'émotion post-chiffre-choc est perdue. Les hub screens n'utilisent aucun content gating lifecycle.
W17 câble l'infrastructure existante (LifecyclePhaseService, ContentAdapterService, ChiffreChocSelector) aux écrans UI.

## RÈGLES
- Chaque prompt = sa propre feature branch depuis `dev`
- `flutter gen-l10n` + `flutter analyze` + `flutter test` après chaque merge
- APRÈS chaque merge, VÉRIFIER LE CÂBLAGE avec les tests grep fournis dans chaque prompt
- LIRE `CLAUDE.md` et `rules.md` AVANT de coder
- JAMAIS de push direct sur `dev`. Feature branch → merge local.

## PLAN D'EXÉCUTION (5 prompts, 3 vagues)

### VAGUE 1 — Adaptation lifecycle des écrans principaux (2 agents EN PARALLÈLE)
| Agent | Prompt | Branch | Scope |
|-------|--------|--------|-------|
| A | P1 (Explorer adaptatif) | `feature/w17-explorer-lifecycle` | `explore_tab.dart` |
| B | P6 (Content gating hubs) | `feature/w17-hub-gating` | `retraite_hub_screen.dart` + `patrimoine_hub_screen.dart` |

Pas de conflit de fichiers. Merger dans l'ordre : A → B.

### VAGUE 2 — Onboarding rewire (1 agent)
| Agent | Prompt | Branch | Scope |
|-------|--------|--------|-------|
| C | P3 (Onboarding rewire) | `feature/w17-onboarding-rewire` | `instant_chiffre_choc_screen.dart` + `landing_screen.dart` + 6 ARB |

Seul agent qui touche le landing et l'instant chiffre choc. Merger après vague 1.

### VAGUE 3 — Data passthrough (2 agents EN PARALLÈLE)
| Agent | Prompt | Branch | Scope |
|-------|--------|--------|-------|
| D | P4 (QuickStart pre-fill + fix defaults) | `feature/w17-quickstart-prefill` | `quick_start_screen.dart` |
| E | P5 (Coach payload) | `feature/w17-coach-payload` | `coach_chat_screen.dart` + `context_injector_service.dart` |

Dépendent de la vague 2 (les clés SharedPreferences doivent exister). Merger : D → E.

### APRÈS CHAQUE VAGUE
```bash
cd apps/mobile
flutter gen-l10n        # Si des ARB ont été modifiés
flutter analyze         # 0 issues
flutter test            # 0 failures
```

## VÉRIFICATION FINALE — 10 TESTS DE CÂBLAGE

### Adaptation lifecycle (Vague 1)

**Test 1** : Explorer utilise LifecyclePhaseService
```bash
grep -n "LifecyclePhaseService" apps/mobile/lib/screens/main_tabs/explore_tab.dart
```
→ Doit trouver au moins 1 import + 1 appel. ✅/❌

**Test 2** : Explorer a un ordre de hubs par phase
```bash
grep -n "demarrage\|construction\|acceleration" apps/mobile/lib/screens/main_tabs/explore_tab.dart
```
→ Doit trouver des références aux phases lifecycle. ✅/❌

**Test 3** : Retraite hub utilise ContentAdapterService
```bash
grep -n "ContentAdapterService\|showLppBuyback\|showWithdrawal" apps/mobile/lib/screens/explore/retraite_hub_screen.dart
```
→ Doit trouver des feature flags de content gating. ✅/❌

**Test 4** : Patrimoine hub gate la succession
```bash
grep -n "showEstatePlanning\|ContentAdapter" apps/mobile/lib/screens/explore/patrimoine_hub_screen.dart
```
→ Doit trouver un guard sur estate planning. ✅/❌

### Onboarding rewire (Vague 2)

**Test 5** : Landing passe birthYear
```bash
grep -n "'birthYear'" apps/mobile/lib/screens/landing_screen.dart
```
→ Doit trouver `'birthYear': _birthYear!` dans le route extra. ✅/❌

**Test 6** : Instant chiffre choc appelle ChiffreChocSelector
```bash
grep -n "ChiffreChocSelector" apps/mobile/lib/screens/onboarding/instant_chiffre_choc_screen.dart
```
→ Doit trouver `ChiffreChocSelector.select`. ✅/❌

**Test 7** : Plus de question générique
```bash
grep -n "chiffreChocSilenceQuestion" apps/mobile/lib/screens/onboarding/instant_chiffre_choc_screen.dart
```
→ NE DOIT PAS trouver cette clé (remplacée). ✅/❌

**Test 8** : Émotion stockée
```bash
grep -n "onboarding_emotion" apps/mobile/lib/screens/onboarding/instant_chiffre_choc_screen.dart
```
→ Doit trouver `prefs.setString('onboarding_emotion'`. ✅/❌

### Data passthrough (Vague 3)

**Test 9** : QuickStart lit les données d'onboarding
```bash
grep -n "onboarding_birth_year\|onboarding_gross_salary" apps/mobile/lib/screens/onboarding/quick_start_screen.dart
```
→ Doit trouver les 2 clés SharedPreferences. ✅/❌

**Test 10** : ContextInjector a un block onboarding
```bash
grep -n "CONTEXTE ONBOARDING" apps/mobile/lib/services/coach/context_injector_service.dart
```
→ Doit trouver la section. ✅/❌

## CRITÈRES DE SUCCÈS
- 5/5 branches mergées dans `dev`
- 0 issues `flutter analyze`
- 0 test failures (`flutter test`)
- **10/10 câblages vérifiés ✅**
- `flutter gen-l10n` → 0 erreurs

**Si UN SEUL ❌ dans les 10 câblages → sprint PAS terminé.**

## CE QUE W17 FAIT
- Explorer s'adapte par phase lifecycle (7 ordres différents)
- Retraite hub masque les outils avancés aux jeunes
- 18 ans voit "intérêts composés", pas "retraite"
- L'émotion post-chiffre-choc arrive au coach
- Le coach sait quel chiffre choc a été vu et réagit
- QuickStart a des defaults intelligents (plus de 1981/85000)

## CE QUE W17 NE FAIT PAS
- Pulse adaptatif (DÉJÀ FAIT — Budget est le default depuis 2026-03-22)
- Créer l'écran Promesse ("MINT reste avec toi") → W18
- Parser les tool_calls côté Flutter → W18
- Câbler les 5 services proactifs orphelins → W18
- Refondre l'architecture coach en Financial Reasoning Agent → W19
- Voice AI / GIF reactions → Phase 3
- Navigation pruning (archiver les 30+ écrans morts) → W18
