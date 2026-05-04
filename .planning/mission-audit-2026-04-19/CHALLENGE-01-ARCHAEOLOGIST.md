# CHALLENGE-01 — ARCHAEOLOGIST

Date : 2026-04-19. Branche `feature/wave-c-scan-handoff-coach`. Lens : 10 ans Flutter refactor, je sais ce qui casse quand on delete.

---

## 1. Verdict — **MODIFY** (pas KEEP, pas KILL)

Les deux claims centraux — "70 écrans supprimables" et "~45 services orphelins" — **ne résistent pas au delete brut**. Preuves grep ci-dessous. Le plan PROMISE-GAP-MAP est bon sur les Phases 31-35 (câblage mission), **mais la Phase 36 "compression archi 4j" est sous-estimée d'un facteur 2-3** et la séquence de delete n'existe pas. Modifier = Phase 36 devient 8-12j + séquence explicite + CI ajustée.

---

## 2. Trois risques de delete cascade prouvés au grep

### Risque A — Les "écrans morts" sont câblés dans 3 services critiques
Pour les 5 écrans échantillonnés (`gender_gap`, `consumer_credit`, `simulator_leasing`, `naissance`, `divorce_simulator`), chacun est référencé dans :
- `apps/mobile/lib/services/navigation/screen_registry.dart` (1652 lignes, **132 `ScreenEntry`**, intentTag `gender_gap`:653, `leasing_simulator`:722, `consumer_credit_simulator`:733, `_naissance`:846)
- `apps/mobile/lib/services/response_card_service.dart` (1011 lignes, cas `lower.contains('naissance')`:284, `id:'gender_gap'`:449, `id:'leasing'`:502, `id:'consumer_credit'`:512)
- `apps/mobile/lib/services/coach/tool_call_parser.dart` (`/naissance`:90, `/simulator/leasing`:117)

**Conséquence** : delete screen seul = `ScreenEntry` référence classe supprimée → compile error cascading sur ~132 entries. Il faut amputer registry + response_card + tool_call_parser **en même temps** que screens, sinon flutter analyze explose.

### Risque B — Les smoke tests testent exactement ce qu'on veut delete
- `test/screens/simulator_screens_smoke_test.dart` (519 lignes) référence `gender_gap_screen` + `simulator_leasing_screen`
- `test/screens/life_event_screens_v2_smoke_test.dart` (639 lignes) référence `naissance_screen`
- `test/screens/life_event_screens_additional_smoke_test.dart` (420 lignes) référence `divorce_simulator_screen`
- `test/screens/core_screens_smoke_test.dart` (328 lignes) référence `consumer_credit_screen`

Total : **1906 lignes de test sur 4 fichiers** qui vont 100% casser sur 5/70 écrans. Extrapolation linéaire : **~15-20 fichiers de smoke tests** à amender ou delete. Sur 437 fichiers `.dart` de test, c'est ~5% de la suite.

### Risque C — Ghost dependencies backend + i18n + notifications
- Backend : `services/backend/app/services/coach/coach_tools.py:110,128,131` déclare les intent tags `"life_event_divorce"`, `"gender_gap"`, `"leasing_simulation"` → 7 intent tags Coach resteront **orphelins backend** si les screens Flutter meurent sans nettoyage backend correspondant (doctrine `feedback_facade_sans_cablage_absolu.md` viole explicitement).
- Notifications : `notification_service.dart` utilise des `payload: '/pilier-3a'`, `/home?tab=1&intent=...` (lignes 446,488,557,592,652,695,759). Si le deep-link cible est delete sans rediriger le payload → **push notif → écran blanc en prod**, silencieux.
- i18n : `app_fr.arb` compte **135 occurrences** de `divorce|genderGap|consumerCredit|leasing`. Delete screen sans nettoyer ARB = strings orphelines shippées en 6 langues (gaspillage + violation CI `flutter gen-l10n`).
- Backend tests : `test_divorce_simulator.py`, `test_housing_sale.py`, `test_family.py` (84 occurrences `naissance_service`) = si on delete `divorce_simulator_service.py` / `gender_gap_service.py`, **pytest backend casse**. Audit SYNTHESE ne liste PAS ces services backend dans "~45 fichiers à delete".

---

## 3. Estimation j-agent-réel pour la Purge

| Borne | Jours | Hypothèse |
|---|---|---|
| Inférieure (optimiste) | **6 j** | screens + registry + response_card + tool_call_parser + tests en 1 shot par cluster, 0 régression, ARB nettoyé par autoresearch-i18n. **Irréaliste** : ne couvre pas backend cleanup ni notif payload rewire. |
| **Médiane (réaliste)** | **11-13 j** | 5 écrans/j × 14 clusters (70 screens) = 14j, parallélisable à 2 tracks = 7j. + 2j services mobile (45 fichiers avec tests) + 2j cleanup backend cluster coach/narrative déjà fait + 2j i18n sweep + 1j notif payload audit + 1j pre-write gate = **11-13j**. |
| Supérieure (pessimiste) | **18-22 j** | Si 1 cascade non-anticipée par cluster (ex : `tool_call_parser` bloque coach routing device), rollback + re-test → +50%. |

**Claim PROMISE-GAP-MAP "Phase 36 = 4j agent non parallélisable"** : faux par ~3×. 4j ne couvre **que** les screens, **pas** le registry de 1652 lignes, **pas** les 15-20 smoke tests, **pas** les 135 strings ARB, **pas** les intent tags backend orphelins, **pas** le payload notif audit.

**Preuve** : Wave E-PRIME (PR #356) vient de faire delete de 42K LOC, 10 commits, sur ~72 fichiers mobile + 4 backend = **~2 semaines wall-clock** avec 3 panels pré-audit. La Purge est 2-3× plus ambitieuse (70 screens + 45 services + invariants CI + pre-write gate).

---

## 4. Séquence de delete anti-cascade (ordre précis)

Le plan actuel PROMISE-GAP-MAP ne donne **aucun ordre**. Voici l'ordre obligatoire, prouvé par les dépendances grep :

```
Étape 0 : PRE-WRITE — Snapshot baseline
  - flutter analyze (0 erreurs attendus, sinon STOP)
  - flutter test (compter baseline passing)
  - pytest services/backend (compter baseline)
  - grep-inventaire : pour chaque screen flagué, générer le graphe de deps

Étape 1 : Kill tests AVANT kill code (sinon flutter test casse en cours)
  - supprimer les cas dans smoke tests (1906 lignes / 4 fichiers)
  - commit atomique par cluster de test

Étape 2 : Kill routes (app.dart) — screens plus atteignables
  - amputer app.dart lignes 19-73 (7 imports screens flagués)
  - amputer GoRouter entries correspondantes
  - commit : "chore(routing): delete dead routes (5 screens, cluster N)"

Étape 3 : Kill registry+response_card+tool_call_parser (services de routage coach)
  - supprimer ScreenEntry (132 → ~62 restantes)
  - supprimer intentTag → screen mapping
  - amputer response_card_service switch cases
  - commit : "chore(nav): purge dead intentTags from coach routing"

Étape 4 : Kill screens dart files
  - delete apps/mobile/lib/screens/<X>_screen.dart (par cluster)
  - commit : "chore(screens): delete dead screen <X>"

Étape 5 : Kill services backend orphelins correspondants
  - delete gender_gap_service, divorce_simulator, housing_sale_service si plus d'endpoint actif
  - amputer backend tests (test_divorce_simulator.py, etc.)
  - amputer coach_tools.py intent tags orphelins (ligne 110,128,131)
  - commit backend séparé : "chore(backend): delete orphan services post-screen-purge"

Étape 6 : Kill ARB strings (135 hits) + regen
  - flutter gen-l10n
  - commit : "chore(i18n): remove orphan strings (6 langs)"

Étape 7 : Audit notif payloads (7 hits dans notification_service)
  - vérifier que chaque payload résout encore → redirect si pas
  - commit si nécessaire

Étape 8 : GATE final
  - flutter analyze = 0
  - flutter test = baseline - (tests supprimés), 0 régression
  - pytest = baseline - (tests supprimés), 0 régression
  - device walkthrough sim iPhone : coach, scan, dossier, 3 life events
```

**Règle d'or** : chaque étape = 1 commit atomique, testable indépendamment. Rollback possible à chaque étape. Jamais de "big bang delete PR".

---

## 5. Pre-write gate technique : réaliste ?

**Réaliste, mais pas avec le scope proposé**.

### Implémentation concrète que je propose

`tools/checks/pre_write_gate.py` (Python, CI + pre-commit hook) :
```python
# 1. Pour chaque fichier .dart ajouté/modifié :
#    - si nouveau screen → doit exister dans screen_registry.dart ET app.dart
#    - si nouveau provider → doit exister au moins 1 Consumer<X> dans lib/
#    - si nouveau LifeEventType enum val → doit exister 1 screen routé
# 2. AST grep sur lib/ (dart analyze --machine output)
# 3. Fail fast : liste les 5 premiers orphelins, exit 1
```

Coût implémentation : **1-1.5j agent** (dart_style/analyzer_cli + parsing). Maintenable : la CI run 10s. **Réaliste**.

### Ce qui est utopique
- "Interdire la création d'un screen sans ses 3 layers Coach" : impossible à enforcer mécaniquement (Layer 4 est textuel, pas structurel). Utopique.
- "Interdire `onTap: null`" : trivial regex (`no_dead_tap`), mais il faut autoriser `null` pour états désactivés légitimes (`enabled: false`). Nécessite annotation `// @allow-null-tap: reason`.

### Verdict
Gate : oui si scopé à orphelins structurels (screens/providers/enum life events). Pas utopique pour ça. Utopique pour "mission-level" checks.

---

## 6. Les 4 invariants CI proposés

| Invariant | Pertinence | Commentaire |
|---|---|---|
| `no_unaccented_fr` (Dart+ARB) | **GOOD** | ARB seul = insuffisant, déjà prouvé en juillet (Dart contient des strings oubliés). Scope Dart+ARB est le bon. |
| `no_dead_tap` | **MODIFY** | Trop strict. Autoriser `onTap: null` quand bouton disabled via `enabled: false` ou flag explicite. Sinon faux positifs en cascade. |
| `no_provider_without_consumer` | **GOOD** | Directement issu de Wave E-PRIME (4 providers sans consumer détectés). `grep Provider<X>` + `grep Consumer<X>|context.watch<X>|context.read<X>` = trivial. |
| `no_orphan_life_event` | **GOOD** | Enum `LifeEventType` → must have screen routed. Actuellement **0 hits grep dans CoachProfile** (PROMISE-GAP-MAP §2). Invariant nécessaire. |

### 2 invariants manquants que je recommande

- **`no_orphan_intent_tag`** : chaque intent tag déclaré dans `coach_tools.py` ou backend doit avoir un mapping dans `screen_registry.dart` (Panel B a trouvé 7 orphelins = récidive certaine sans CI). Trivial : parse les deux fichiers, diff.
- **`no_route_without_go_route`** : chaque `context.push('/X')` / `GoRouter.of(...).push('/X')` doit avoir une entrée GoRouter enregistrée. Prévient le RSoD class tué en Wave 1. 12 call-sites ont déjà été corrigés manuellement — un invariant l'empêche définitivement.

---

## 7. Bilan en 1 phrase

La Purge est **techniquement faisable mais coûte 11-13j agent (pas 4j)**, nécessite une séquence stricte en 8 étapes (pas "kill 70 écrans"), et les 4 invariants CI couvrent 60% du besoin — il en manque 2 (intent tag + route) pour qu'anti-récidive tienne. **MODIFY le plan : +8j Phase 36, séquence documentée, 6 invariants au lieu de 4.**
