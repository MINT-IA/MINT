# AUDIT EXHAUSTIF DE NAVIGATION — MINT Mobile

> Date : 2026-04-09 | Scope : `apps/mobile/lib/` | 7 agents parallèles, ~105 écrans, 284 actions de navigation, 118+ routes
>
> Cet audit couvre : routes, redirections, éléments interactifs, écrans orphelins, cohérence logique des parcours, culs-de-sac, boucles, et incohérences.
>
> **Status : TOUS LES FINDINGS CORRIGÉS** (branch `feature/nav-audit-fixes`)
> - 4 P0 critiques : FIXED
> - 4 P1 importants : FIXED
> - 14 PopScope : audités, tous SAFE
> - 13 fichiers orphelins supprimés (~2000 LOC)
> - 16+ fichiers dupliqués corrompus (`* 2.dart`) nettoyés
> - 1 test d'intégration obsolète supprimé (IntentScreen/KILL-01)
> - flutter analyze : 0 erreurs

---

## RÉSUMÉ EXÉCUTIF

| Métrique | Valeur |
|----------|--------|
| Routes totales (GoRouter) | 118+ |
| Écrans réels (avec builder) | 71 |
| Routes de redirection | 47+ |
| Fichiers écran (.dart) | ~105 |
| Écrans orphelins | **20** (13 code mort, 5 Phase 4, 2 divers) |
| Actions de navigation | 284 |
| Éléments interactifs | 900+ |
| Callbacks vides/morts | **0** |
| Findings P0 (critique) | **4** |
| Findings P1 (important) | **4** |
| Findings P2 (modéré) | **5** |

---

## P0 — CRITIQUES (à corriger avant tout déploiement)

### P0-1. Paramètres query perdus dans les chaînes de redirection

**Problème** : `/home?tab=1` est utilisé par 2 routes (`/coach/checkin`, `/tools`) et 1 écran (`document_impact_screen.dart:626`), mais `/home` redirige vers `/coach/chat` — le `?tab=1` est **silencieusement avalé**.

```
/coach/checkin → /home?tab=1 → /coach/chat   ← tab=1 PERDU
/tools         → /home?tab=1 → /coach/chat   ← tab=1 PERDU
document_impact_screen.dart:626 → context.go('/home?tab=1') ← tab=1 PERDU
```

**Impact** : L'utilisateur qui finit un scan de document ou qui veut accéder au coach via un raccourci se retrouve au chat sans le contexte attendu.

**Fix** : Rediriger directement vers `/coach/chat` (supprimer l'indirection via `/home?tab=1`).

**Fichiers concernés** :
- `app.dart:229` (redirect /home)
- `app.dart:286` (redirect /coach/checkin)
- `app.dart:782` (redirect /tools)
- `screens/document_scan/document_impact_screen.dart:626`

---

### P0-2. Vérification email : onboarding check contourné

**Problème** : Après vérification email (`app.dart:1186-1188`), les deux branches convergent au même endroit :

```dart
if (completed) {
  context.go('/home');              // → /coach/chat
} else {
  context.go('/onboarding/intent'); // → /coach/chat (redirect shim!)
}
```

**Impact** : Un utilisateur qui n'a PAS complété l'onboarding arrive au même écran qu'un utilisateur onboardé. La distinction onboarding/non-onboarding est **morte**.

**Fix** : Soit passer un `?prompt=welcome` pour déclencher le flow de bienvenue du coach, soit créer une logique côté CoachChatScreen qui détecte un profil vide.

**Fichiers concernés** :
- `app.dart:1186-1188`

---

### P0-3. ScoreRevealScreen : pas de bouton retour, piège potentiel

**Problème** : L'écran de révélation du score financier (`score_reveal_screen.dart`) n'a **aucun AppBar, aucun bouton retour**. Les deux CTAs ("Voir mon tableau de bord", "Voir le rapport détaillé") n'apparaissent **qu'après la fin de l'animation** (5 phases).

**Scénario piège** : Si l'animation ne rend pas les CTAs (bug, lag, ou timeout), l'utilisateur est **bloqué** sur un écran vide sans aucune porte de sortie sauf le swipe-back iOS ou le bouton back Android.

**Impact** : Cul-de-sac dur sur un écran critique du parcours utilisateur.

**Fix** :
1. Ajouter un `IconButton` close en haut à droite (visible immédiatement)
2. Ajouter un timeout qui force l'affichage des CTAs après 5 secondes

**Fichier concerné** :
- `screens/advisor/score_reveal_screen.dart`

---

### P0-4. FinancialReportScreenV2 : perte de contexte totale au retour

**Problème** : Le rapport financier (`/rapport`) reçoit ses données via `state.extra` (wizardAnswers). Si l'utilisateur navigue ailleurs puis revient à `/rapport` sans extra, l'écran affiche un état vide.

```dart
// app.dart:612-614
builder: (context, state) {
  final extra = state.extra as Map<String, dynamic>? ?? {};
  return FinancialReportScreenV2(wizardAnswers: extra); // {} = rapport vide
},
```

**Impact** : L'utilisateur perd son rapport en naviguant. Pas de cache, pas de persistence.

**Fix** : Persister les `wizardAnswers` dans un Provider ou SharedPreferences. Recharger automatiquement les dernières données si `extra` est vide.

**Fichier concerné** :
- `screens/advisor/financial_report_screen_v2.dart`
- `app.dart:609-615`

---

## P1 — IMPORTANTS (à corriger dans le sprint en cours)

### P1-1. Double/triple redirections avec perte de paramètres

5 chaînes de redirection passent par un intermédiaire inutile :

| Route originale | Chemin réel | Problème |
|----------------|-------------|----------|
| `/advisor` | → `/onboarding/quick` → `/coach/chat` | 2 hops inutiles |
| `/advisor/wizard?section=X` | → `/onboarding/quick?section=X` → `/coach/chat` | **section= PERDU** |
| `/advisor/plan-30-days` | → `/home` → `/coach/chat` | 2 hops inutiles |
| `/coach/agir` | → `/home` → `/coach/chat` | 2 hops inutiles |
| `/onboarding/smart` | → `/onboarding/quick` → `/coach/chat` | 2 hops inutiles |
| `/onboarding/minimal` | → `/onboarding/quick` → `/coach/chat` | 2 hops inutiles |

**Fix** : Rediriger tous directement vers `/coach/chat`. Supprimer les hops intermédiaires.

---

### P1-2. Écrans qui appellent encore les routes supprimées

Plusieurs écrans naviguent vers `/onboarding/quick`, `/onboarding/intent`, ou `/home` — qui sont des shims de redirection. Ils devraient appeler `/coach/chat` directement :

| Fichier | Ligne | Appel actuel | Devrait être |
|---------|-------|-------------|-------------|
| `budget/budget_screen.dart` | 241 | `context.push('/onboarding/quick')` | `context.push('/coach/chat')` |
| `advisor/financial_report_screen_v2.dart` | 68 | `context.go('/home')` | `context.go('/coach/chat')` |
| `advisor/financial_report_screen_v2.dart` | 76 | `context.go('/onboarding/intent')` | `context.go('/coach/chat')` |
| `expert/expert_tier_screen.dart` | 101 | `context.push('/onboarding/intent')` | `context.push('/coach/chat')` |
| `pillar_3a_deep/staggered_withdrawal_screen.dart` | 183 | `context.push('/onboarding/quick')` | `context.push('/coach/chat')` |
| `pillar_3a_deep/retroactive_3a_screen.dart` | 213 | `context.push('/onboarding/quick')` | `context.push('/coach/chat')` |
| `arbitrage/arbitrage_bilan_screen.dart` | 53 | `context.push('/onboarding/quick')` | `context.push('/coach/chat')` |
| `budget/budget_container_screen.dart` | 61 | `context.push('/advisor/wizard?section=budget')` | `context.push('/coach/chat?prompt=budget')` |
| `coach/annual_refresh_screen.dart` | 782 | `context.go('/home')` | `context.go('/coach/chat')` |
| `app.dart` | 1186 | `context.go('/home')` | `context.go('/coach/chat')` |
| `app.dart` | 1188 | `context.go('/onboarding/intent')` | `context.go('/coach/chat')` |
| `app.dart` | 1276 | `context.go('/home')` | `context.go('/coach/chat')` |

---

### P1-3. 20 écrans orphelins dont 13 code mort (~2000 LOC)

**Code mort supprimable immédiatement (13 fichiers)** :

| Fichier | Raison | LOC estimé |
|---------|--------|-----------|
| `screens/explore/famille_hub_screen.dart` | KILL-07 Shell collapse | ~120 |
| `screens/explore/fiscalite_hub_screen.dart` | KILL-07 | ~120 |
| `screens/explore/logement_hub_screen.dart` | KILL-07 | ~120 |
| `screens/explore/patrimoine_hub_screen.dart` | KILL-07 | ~120 |
| `screens/explore/retraite_hub_screen.dart` | KILL-07 | ~200 |
| `screens/explore/sante_hub_screen.dart` | KILL-07 | ~120 |
| `screens/explore/travail_hub_screen.dart` | KILL-07 | ~160 |
| `screens/main_tabs/dossier_tab.dart` | Shell removed | ~200 |
| `screens/main_tabs/mint_coach_tab.dart` | Shell removed | ~50 |
| `screens/main_tabs/mint_home_screen.dart` | Shell removed | ~300 |
| `screens/tools_library_screen.dart` | STAB-14 archived | ~200 |
| `screens/coach/weekly_recap_screen.dart` | Zero callers | ~200 |
| `screens/import/bank_import_screen.dart` | Duplicate V2, never deployed | ~150 |

**Phase 4 (garder mais tracker) — 5 fichiers** :
- `screens/b2b/b2b_hub_screen.dart`
- `screens/coach/coach_checkin_screen.dart`
- `screens/expert/expert_tier_screen.dart`
- `screens/institutional/pension_fund_connect_screen.dart`
- `screens/profile/data_transparency_screen.dart`

**À investiguer** :
- `screens/pulse/pulse_screen.dart` — référencé dans des commentaires mais aucune route

---

### P1-4. 14 écrans avec PopScope custom : logique de retour non-standard

Ces écrans interceptent le bouton retour avec un `PopScope`. Chacun doit être vérifié pour s'assurer qu'il ne piège pas l'utilisateur :

| Écran | Risque |
|-------|--------|
| `simulator_3a_screen.dart` | Confirmation avant quitter ? |
| `fiscal_comparator_screen.dart` | Confirmation avant quitter ? |
| `first_job_screen.dart` | Confirmation avant quitter ? |
| `budget/budget_screen.dart` | Confirmation avant quitter ? |
| `arbitrage/rente_vs_capital_screen.dart` | Confirmation avant quitter ? |
| `coach/retirement_dashboard_screen.dart` | Confirmation avant quitter ? |
| `coach/optimisation_decaissement_screen.dart` | Confirmation avant quitter ? |
| `lpp_deep/rachat_echelonne_screen.dart` | Confirmation avant quitter ? |
| `lpp_deep/epl_screen.dart` | Confirmation avant quitter ? |
| `mortgage/affordability_screen.dart` | Confirmation avant quitter ? |
| `pillar_3a_deep/staggered_withdrawal_screen.dart` | Confirmation avant quitter ? |
| `pillar_3a_deep/real_return_screen.dart` | Confirmation avant quitter ? |
| `debt_prevention/repayment_screen.dart` | Confirmation avant quitter ? |
| `debt_prevention/debt_ratio_screen.dart` | Confirmation avant quitter ? |

**Fix** : Auditer chaque PopScope. S'assurer que (a) l'utilisateur peut toujours sortir et (b) le dialog de confirmation ne bloque pas la navigation si aucune donnée n'a été modifiée.

---

## P2 — MODÉRÉS (backlog)

### P2-1. Budget empty state : pas de back button explicite

`budget_container_screen.dart` en état vide n'offre qu'un CTA vers le wizard. Pas de bouton retour visible. L'utilisateur dépend du geste système (swipe back iOS / back Android).

### P2-2. Document scan : pas de persistence mid-flow

Si l'utilisateur quitte le flux scan → review → impact, les données extraites sont perdues. Pas de cache intermédiaire.

### P2-3. PulseScreen : fantôme dans le codebase

`screens/pulse/pulse_screen.dart` est référencé dans 4 commentaires de services mais n'a aucune route, aucun import. Code zombie.

### P2-4. cockpit_detail_screen.dart:490 — onTap: null

Score card avec `onTap: null` hardcodé. Intentionnel (lecture seule) mais visuellement, la card ressemble à un élément cliquable.

### P2-5. Data enrichment : données non sauvegardées tant que le flow n'est pas complété

`data_block_enrichment_screen.dart` montre les données du profil mais ne sauvegarde rien directement. L'utilisateur doit compléter le flow d'enrichissement pour persister ses changements. Si il quitte avant, tout est perdu.

---

## ARCHITECTURE DE NAVIGATION — VUE D'ENSEMBLE

```
┌─────────────┐
│  Landing /  │
│  (public)   │
└──────┬──────┘
       │ CTA unique
       ▼
┌──────────────────────────────────────────────────────┐
│                  /coach/chat                          │
│              (HUB CENTRAL — public)                  │
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │ History  │  │ Settings │  │ Lightning Menu   │   │
│  │/coach/   │  │/profile/ │  │ (bottom sheet)   │   │
│  │ history  │  │ byok     │  │                  │   │
│  └──────────┘  └──────────┘  └──────────────────┘   │
│                                                      │
│  AI Coach → RoutePlanner → push vers n'importe quel  │
│             écran via intent_tag + confidence         │
└──────────────────────┬───────────────────────────────┘
                       │ context.push(route)
                       ▼
        ┌──────────────────────────────┐
        │     ÉCRANS SPÉCIALISÉS       │
        │                              │
        │  Retraite  │  Budget  │ Scan │
        │  Fiscalité │  Famille │ Debt │
        │  Immobilier│  Emploi  │ Arb. │
        │  Indépend. │  Assur.  │ Educ.│
        │                              │
        │  Tous: AppBar + pop() → chat │
        └──────────────────────────────┘
```

### Points forts de l'architecture

1. **Hub unique cohérent** : CoachChatScreen est le vrai centre. Toutes les routes /home et /explore/* convergent correctement.
2. **0 callback vide** : Aucun bouton mort, aucun TODO dans les handlers interactifs.
3. **Accessibilité** : 250+ widgets avec `Semantics(button: true)`, couverture > 95%.
4. **Retour systématique** : 93/105 écrans ont un AppBar avec back button automatique. Aucun `automaticallyImplyLeading: false`.
5. **Auth guard** : Système `RouteScope` propre, fail-closed, scope déclaratif.
6. **Legacy compat** : 47+ redirections préservent la backward compatibility des deep links.

### Points faibles structurels

1. **Trop de redirections en cascade** : 6 chaînes de double/triple redirect créent des pertes de paramètres silencieuses.
2. **state.extra comme seul transport de données** : 5 routes critiques passent des données complexes via `extra` (non persisté, perdu au refresh ou retour).
3. **Code mort accumulé** : 17.5% des fichiers écran sont orphelins (13 supprimables, 5 Phase 4).
4. **Pas de shell/tab navigator** : Après KILL-07, plus aucune navigation par tabs. Tout passe par le coach + push. C'est un choix assumé, mais ça signifie que l'utilisateur ne peut pas "surfer" entre sections sans repasser par le chat.

---

## PARCOURS UTILISATEUR — AUDIT LOGIQUE

### Parcours 1 : Premier lancement → Premier insight

```
Landing (/) → CTA → /coach/chat → Coach propose de se présenter
→ Utilisateur donne âge, revenu, canton → Coach génère premier éclairage
→ CTA "Voir votre rapport" → /rapport (avec wizardAnswers via extra)
```

**Verdict** : ✅ Fluide. Mais si l'utilisateur quitte le rapport et revient, les données sont perdues (P0-4).

### Parcours 2 : Scanner un document

```
/coach/chat → Lightning menu "Scanner" → /scan
→ Capture image → /scan/review → Confirmer
→ /scan/impact → "Voir impact sur mon profil"
→ context.go('/home?tab=1') ← ⚠️ tab=1 PERDU (P0-1)
→ Atterrit sur /coach/chat sans contexte de scan
```

**Verdict** : ⚠️ Le retour post-scan est cassé. L'utilisateur devrait atterrir sur le chat avec un message contextuel type "Tes données ont été mises à jour".

### Parcours 3 : Vérification email → Premier usage

```
Email cliqué → /auth/verify → Vérifie token
→ Si onboarding complété : context.go('/home') → /coach/chat
→ Si onboarding PAS complété : context.go('/onboarding/intent') → /coach/chat
→ MÊME RÉSULTAT dans les deux cas (P0-2)
```

**Verdict** : ❌ L'onboarding check est mort. Les deux branches mènent au même endroit sans distinction.

### Parcours 4 : Explorer un simulateur depuis le rapport

```
/rapport → CTA "Optimiser 3a" → /pilier-3a → Simule
→ Back → pop() → retour à /rapport
→ MAIS /rapport a perdu ses wizardAnswers (P0-4)
→ Rapport VIDE
```

**Verdict** : ❌ Boucle cassée. L'utilisateur perd son rapport en explorant les recommandations.

### Parcours 5 : Score reveal → Rapport → Simulateur → Retour

```
/score-reveal → Animation → CTA "Voir rapport détaillé"
→ /rapport (avec wizardAnswers) → CTA "Optimiser budget"
→ /budget → Back → pop() → /rapport (VIDE, extra perdu)
→ Back → pop() → /score-reveal (animation re-jouée ? état ?)
```

**Verdict** : ❌ Cascade de pertes de contexte.

### Parcours 6 : Navigation depuis le Retirement Dashboard

```
/coach/chat → Coach recommande /retraite → push
→ RetirementDashboard → "Mon cockpit" → /coach/cockpit → push
→ CockpitDetail → "Scanner un document" → /scan → push
→ Scan flow → ... → pop → pop → pop → retour /retraite
```

**Verdict** : ✅ La pile de navigation fonctionne correctement. Chaque push/pop est cohérent. Pas de boucle.

### Parcours 7 : Budget vide → Enrichissement

```
/coach/chat → Coach recommande /budget → push
→ BudgetContainer (VIDE) → CTA unique "Remplir mon budget"
→ context.push('/advisor/wizard?section=budget')
→ Redirigé vers /onboarding/quick → /coach/chat ← ⚠️ section= PERDU
→ L'utilisateur revient au chat, PAS au wizard budget
```

**Verdict** : ❌ Le CTA du budget vide est cassé. L'utilisateur ne peut jamais remplir son budget depuis cet écran.

---

## MATRICE DE TOUS LES ÉCRANS

### Écrans avec route active (71)

| Catégorie | Routes | Statut nav |
|-----------|--------|------------|
| Auth (5) | `/`, `/auth/*` | ✅ OK |
| Coach (5) | `/coach/chat`, `/coach/history`, `/coach/cockpit`, `/coach/refresh`, `/retraite` | ✅ OK |
| Prévoyance (7) | `/rente-vs-capital`, `/rachat-lpp`, `/epl`, `/decaissement`, `/libre-passage`, `/succession` | ✅ OK |
| Fiscalité (6) | `/pilier-3a`, `/3a-deep/*`, `/3a-retroactif`, `/fiscal` | ✅ OK |
| Immobilier (5) | `/hypotheque`, `/mortgage/*` | ✅ OK |
| Budget & Dette (5) | `/budget`, `/check/debt`, `/debt/*` | ⚠️ Budget vide cassé |
| Famille (4) | `/divorce`, `/mariage`, `/naissance`, `/concubinage` | ✅ OK |
| Emploi (4) | `/unemployment`, `/first-job`, `/expatriation`, `/simulator/job-comparison` | ✅ OK |
| Indépendants (6) | `/segments/independant`, `/independants/*` | ✅ OK |
| Assurance (5) | `/invalidite`, `/disability/*`, `/assurances/*` | ✅ OK |
| Documents (6) | `/scan`, `/scan/*`, `/documents`, `/documents/:id` | ⚠️ Retour post-scan cassé |
| Couple (2) | `/couple`, `/couple/accept` | ✅ OK |
| Rapport (2) | `/rapport`, `/score-reveal` | ❌ Contexte perdu |
| Profile (6) | `/profile/byok`, `/profile/slm`, `/profile/bilan`, etc. | ✅ OK |
| Éducation (2) | `/education/hub`, `/education/theme/:id` | ✅ OK |
| Simulateurs (3) | `/simulator/compound`, `/leasing`, `/credit` | ✅ OK |
| Arbitrage (3) | `/arbitrage/bilan`, `/allocation-annuelle`, `/location-vs-propriete` | ✅ OK |
| Divers (5) | `/achievements`, `/cantonal-benchmark`, `/settings/langue`, `/about`, `/ask-mint` | ✅ OK |
| Onboarding (1) | `/data-block/:type` | ✅ OK |
| Open Banking (4) | `/open-banking/*`, `/bank-import` | ✅ OK (feature-gated) |

### Écrans orphelins (20)

Voir section P1-3 ci-dessus.

---

## ACTIONS RECOMMANDÉES — PAR PRIORITÉ

### Sprint immédiat (P0)

1. **Supprimer les redirections via `/home`** — Rediriger `/coach/checkin`, `/tools`, `/coach/agir`, `/advisor/plan-30-days` directement vers `/coach/chat`
2. **Fixer le retour post-scan** — `document_impact_screen.dart:626` doit appeler `context.go('/coach/chat')` au lieu de `/home?tab=1`
3. **Ajouter un back button à ScoreRevealScreen** — `IconButton(icon: Icon(Icons.close), onPressed: () => context.pop())`
4. **Persister wizardAnswers** — Cache dans un Provider pour que `/rapport` survive à la navigation
5. **Fixer la vérification email** — Différencier le comportement onboarding complété vs non complété

### Sprint suivant (P1)

6. **Nettoyer les appels à routes mortes** — Remplacer 12 appels à `/onboarding/quick`, `/onboarding/intent`, `/home` par `/coach/chat`
7. **Supprimer le code mort** — 13 fichiers orphelins, ~2000 LOC
8. **Auditer les 14 PopScope** — Vérifier que chaque PopScope permet toujours de sortir
9. **Fixer le CTA budget vide** — `budget_container_screen.dart:61` doit mener à un vrai flux d'entrée de données

### Backlog (P2)

10. Persister le scan mid-flow
11. Supprimer PulseScreen
12. Corriger le cockpit_detail_screen onTap: null
13. Sauvegarder les données enrichment avant complétion du flow

---

## ANNEXE : REDIRECTIONS COMPLÈTES

### Redirections saines (single-hop, 23 routes) ✅

| De | Vers |
|----|------|
| `/explore/*` (×7) | `/coach/chat` |
| `/coach/dashboard` | `/retraite` |
| `/retirement` | `/retraite` |
| `/retirement/projection` | `/retraite` |
| `/arbitrage/rente-vs-capital` | `/rente-vs-capital` |
| `/simulator/rente-capital` | `/rente-vs-capital` |
| `/lpp-deep/rachat` | `/rachat-lpp` |
| `/lpp-deep/epl` | `/epl` |
| `/coach/decaissement` | `/decaissement` |
| `/arbitrage/calendrier-retraits` | `/decaissement` |
| `/coach/succession` | `/succession` |
| `/life-event/succession` | `/succession` |
| `/lpp-deep/libre-passage` | `/libre-passage` |
| `/simulator/3a` | `/pilier-3a` |
| `/mortgage/affordability` | `/hypotheque` |
| `/disability/gap` | `/invalidite` |
| `/simulator/disability-gap` | `/invalidite` |
| `/document-scan` | `/scan` |
| `/document-scan/avs-guide` | `/scan/avs-guide` |
| `/household` | `/couple` |
| `/household/accept` | `/couple/accept` |
| `/report`, `/report/v2` | `/rapport` |
| `/onboarding/enrichment` | `/profile/bilan` |

### Redirections cassées (multi-hop ou perte de params) ❌

| De | Hop 1 | Hop 2 | Problème |
|----|-------|-------|----------|
| `/coach/checkin` | `/home?tab=1` | `/coach/chat` | tab=1 perdu |
| `/tools` | `/home?tab=1` | `/coach/chat` | tab=1 perdu |
| `/coach/agir` | `/home` | `/coach/chat` | 2 hops inutiles |
| `/advisor/plan-30-days` | `/home` | `/coach/chat` | 2 hops inutiles |
| `/advisor` | `/onboarding/quick` | `/coach/chat` | 2 hops inutiles |
| `/advisor/wizard?section=X` | `/onboarding/quick?section=X` | `/coach/chat` | section perdu |
| `/onboarding/smart` | `/onboarding/quick` | `/coach/chat` | 2 hops inutiles |
| `/onboarding/minimal` | `/onboarding/quick` | `/coach/chat` | 2 hops inutiles |
