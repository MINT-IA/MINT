# 🔧 MINT — Prompts Claude Code de FIX (nav, archi, design, bugs)

> **Contexte.** Tu (Julien) as déjà fait produire 3 audits exhaustifs dans le repo :
> - `NAVIGATION_AUDIT.md` — 4 P0, 4 P1, 5 P2 sur la navigation
> - `AUDIT_COMPLET.md` — 15 findings critiques (deadlock chat, iOS, OpenAPI, etc.)
> - `AUDIT_REPORT.md` — 5 duplicate classes + 2 routes GoRouter cassées
>
> Le problème : Claude Code n'**ouvre pas** ces audits. Ces prompts l'y forcent et lui donnent des **chemins exacts + lignes exactes** pour qu'il ne puisse pas dériver.
>
> **Ce que je SAIS de ton repo (vérifié) :**
> - `apps/mobile/lib/services/navigation/screen_registry.dart` ✓ existe
> - `apps/mobile/lib/services/navigation/route_planner.dart` ✓ existe
> - `apps/mobile/lib/services/navigation/readiness_gate.dart` ✓ existe
> - `apps/mobile/lib/services/coach/coach_orchestrator.dart` ✓ existe
> - `apps/mobile/lib/app.dart` ✓ existe (1908 lignes, GoRouter)
>
> **Ce que je NE sais PAS** : si les fixes des audits ont été appliqués depuis (le `NAVIGATION_AUDIT.md` dit "TOUS LES FINDINGS CORRIGÉS" mais le `AUDIT_COMPLET.md` du 17 avril liste les mêmes problèmes — donc soit le premier audit ment, soit il y a régression). **Le Prompt 0 ci-dessous force la vérification.**

---

## ⚠️ Mes limites honnêtes

| Je peux voir | Je ne peux pas voir |
|---|---|
| Tout le code Dart/Python statique | Les bugs runtime (crashs, race conditions transitoires) |
| Les incohérences d'architecture | Le rendu réel sur device |
| Les redirections cassées par construction | Les jank d'animation |
| Les duplications de classes | Les bugs liés à des libs tierces non lues |
| Les chemins de fichiers existants | L'historique produit (pourquoi un truc bizarre est volontaire) |

**Ce que je vais te livrer ci-dessous est basé sur les audits déjà produits dans ton repo, vérifiés contre la structure réelle.** Pas de fiction.

---

# PROMPT 0 — Réconciliation des audits (OBLIGATOIRE EN PREMIER)

> Pourquoi : le `NAVIGATION_AUDIT.md` prétend que tout est corrigé. Le `AUDIT_COMPLET.md` (10 jours plus tard) liste les mêmes bugs. **L'un des deux ment.** Avant de fixer quoi que ce soit, on tranche.

```
Tu es dev lead Flutter sur MINT. AVANT toute modification de code,
exécute STRICTEMENT cette mission de réconciliation.

═══════════════════════════════════════════════════════════════════
PHASE 0 — RÉCONCILIATION DES AUDITS (NE PRODUIT PAS DE CODE)
═══════════════════════════════════════════════════════════════════

ÉTAPE 0.1 — Lecture obligatoire IN FULL des 3 audits :

  1. NAVIGATION_AUDIT.md      (478 lignes — lis TOUT)
  2. AUDIT_COMPLET.md         (188 lignes — lis TOUT)
  3. AUDIT_REPORT.md          (173 lignes — lis TOUT)

ÉTAPE 0.2 — Vérification terrain. Pour CHAQUE finding P0 et P1 des 3
audits, exécute la vérification que je liste ci-dessous et produis
un fichier audits/RECONCILIATION.md avec ce tableau :

  | ID | Finding | Status réel | Preuve | Fix appliqué ? |

Liste exhaustive à vérifier (NE PAS EN OUBLIER UN SEUL) :

  N-P0-1  Paramètres query perdus /home?tab=1
          → grep "context.go.*'/home?tab=" dans apps/mobile/lib/
          → si 0 hits = fix appliqué ; sinon = NON corrigé

  N-P0-2  Email check redirige vers /home (onboarding bypass)
          → ouvre apps/mobile/lib/app.dart
          → cherche les 2 branches après vérification email
          → vérifie qu'elles divergent réellement

  N-P0-3  ScoreRevealScreen sans bouton retour
          → grep "score_reveal" : si fichier supprimé = N/A

  N-P0-4  FinancialReportScreenV2 perte de contexte
          → ouvre financial_report_screen_v2.dart
          → vérifier persistence des wizardAnswers

  N-P1-1  6 chaînes de double redirect → /coach/chat
          → grep les 6 routes listées dans NAVIGATION_AUDIT P1-1

  N-P1-2  13 écrans qui appellent /onboarding/quick, /home, etc.
          → grep "context.push('/onboarding/quick')"
          → grep "context.go('/home')"
          → comparer aux 13 lignes listées P1-2

  N-P1-3  20 écrans orphelins
          → vérifier que les 13 fichiers KILL-07 sont bien supprimés

  N-P1-4  14 PopScope custom à auditer
          → grep "PopScope" dans lib/screens/

  C-1     Coach chat deadlock (RAG lazy init)
          → ouvre services/backend/app/api/v1/endpoints/coach_chat.py
          → lignes 183-187, vérifier état du lock

  C-2     PrivacyInfo.xcprivacy iOS
          → ls apps/mobile/ios/Runner/PrivacyInfo.xcprivacy
          → existe = OK ; absent = bloquant App Store

  C-3     Chat context window 8 messages
          → ouvre coach_orchestrator.dart ligne 1235-1236 et 787
          → vérifier la valeur (8 ou 32+)

  C-4     OpenAPI drift 25 fields
          → diff tools/openapi/mint.openapi.yaml vs schemas Python

  C-5     142 clés FR orphelines
          → wc -l apps/mobile/lib/l10n/app_fr.arb vs autres ARB

  C-7     Archetype detection 5/8
          → minimal_profile_service.py:70-99

  C-8     StatefulShellBranch initialLocation inversée
          → app.dart lignes 284-354

  R-1     5 duplicate classes (ChiffreChoc, CoachNarrativeService,
          AdvisorDossier, WeeklyRecapService)
          → grep "class ChiffreChoc"
          → grep "class CoachNarrativeService"
          → etc. — chaque classe doit avoir UNE seule définition

  R-2     2 routes GoRouter cassées
          → grep "/premier-emploi" dans cap_sequence_engine.dart
          → grep "/location-vs-propriete" dans cap_sequence_engine.dart
          → vérifier qu'elles sont enregistrées dans app.dart

ÉTAPE 0.3 — Synthèse. À la fin de RECONCILIATION.md, écris 4 listes :

  A. ✅ DÉJÀ CORRIGÉS (preuve à l'appui — lien vers commit ou ligne).
  B. ❌ NON CORRIGÉS (avec sévérité P0/P1 et chemin:ligne précis).
  C. 🔄 PARTIELLEMENT CORRIGÉS (avec ce qui reste à faire).
  D. 🤷 IMPOSSIBLE À VÉRIFIER (avec ce que tu as besoin de Julien).

ÉTAPE 0.4 — STOP. Tu m'écris :

  "Réconciliation terminée. X findings vérifiés. Y déjà corrigés,
   Z encore ouverts, W partiels, V impossibles à vérifier.
   3 décisions critiques à prendre par Julien : [...]"

J'attends ta validation avant TOUTE modif de code.

RÈGLES :
- Tu ne modifies AUCUN fichier source.
- Tu crées UNIQUEMENT audits/RECONCILIATION.md.
- Si un finding ne peut pas être vérifié (ex. besoin d'une exécution),
  tu écris "IMPOSSIBLE À VÉRIFIER STATIQUEMENT" + ce qu'il faudrait.
- Tu ne devines JAMAIS. "Probablement corrigé" est interdit.

Commence maintenant.
```

---

# PROMPT 1 — Fix bloc NAVIGATION (P0 + P1 cassés)

> À coller **après** Prompt 0 si la réconciliation montre des findings nav non corrigés. Adapte la liste selon ce que Prompt 0 a remonté.

```
Phase Navigation. Tu travailles UNIQUEMENT dans apps/mobile/lib/.

PROTOCOLE STRICT par finding :
  1. Annonce : "Je commence FIX-N-XXX"
  2. Lis le fichier concerné
  3. Propose le diff exact (ne l'applique pas encore)
  4. Attends mon "go" → applique
  5. Lance flutter analyze + tests concernés
  6. Montre le résultat
  7. Attends "go" → finding suivant

═══════════════════════════════════════════════════════════════════
LISTE DES FIXES (ordre strict)
═══════════════════════════════════════════════════════════════════

FIX-N-P0-1 — Paramètres query perdus
  Fichiers :
    • apps/mobile/lib/app.dart:229 (redirect /home)
    • apps/mobile/lib/app.dart:286 (redirect /coach/checkin)
    • apps/mobile/lib/app.dart:782 (redirect /tools)
    • apps/mobile/lib/screens/document_scan/document_impact_screen.dart:626
  Action : remplacer les redirects /home?tab=1 par redirect direct
  vers /coach/chat (sans tab=). Si tab=1 portait une intention,
  la convertir en ?topic=... (cf. la logique screen= déjà présente
  dans le redirect global d'app.dart).

FIX-N-P0-2 — Onboarding bypass
  Fichier : apps/mobile/lib/app.dart:1186-1188
  Action : la branche `if (completed)` doit aller à /coach/chat ;
  la branche `else` doit aller à /onboarding/intent QUI MÈNE
  RÉELLEMENT à un écran de bienvenue, pas un shim qui redirige
  vers /coach/chat. Soit créer un écran d'accueil distinct, soit
  passer ?firstTime=1 et que CoachChatScreen lance le greeting
  correspondant. Choisis l'option la plus simple, montre-moi le
  diff, j'arbitre.

FIX-N-P0-4 — FinancialReportScreenV2 perte de contexte
  Fichiers :
    • apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart
    • apps/mobile/lib/app.dart:609-615
  Action : persister wizardAnswers via report_persistence_service.dart
  (qui existe déjà — vérifie sa signature). Au build, si state.extra
  vide, recharger les dernières wizardAnswers depuis la persistence.

FIX-N-P1-1 — Suppression des doubles redirects
  Fichier : apps/mobile/lib/app.dart
  Action : pour chaque ligne du tableau ci-dessous, remplacer le
  redirect intermédiaire par un redirect DIRECT vers /coach/chat,
  en préservant les query params via l'URI builder (cf. la logique
  screen= déjà en place lignes 130-180).
    /advisor                       → /coach/chat
    /advisor/wizard?section=X      → /coach/chat?topic=X (préserver section)
    /advisor/plan-30-days          → /coach/chat
    /coach/agir                    → /coach/chat
    /onboarding/smart              → /coach/chat
    /onboarding/minimal            → /coach/chat

FIX-N-P1-2 — 13 call-sites obsolètes
  Référence : NAVIGATION_AUDIT.md §P1-2 (tableau complet)
  Pour CHAQUE ligne du tableau, applique le remplacement listé.
  Ne saute aucune. Montre-moi le diff par fichier groupé.

FIX-R-2 — 2 routes GoRouter cassées
  Référence : AUDIT_REPORT.md §2
  Fichier : apps/mobile/lib/services/cap_sequence_engine.dart
  • Ligne 483 : '/premier-emploi' → soit changer pour '/first-job'
    (déjà dans GoRouter), soit ajouter un alias /premier-emploi
    dans app.dart. Préfère l'ALIAS pour préserver la sémantique FR.
  • Ligne 432 : '/location-vs-propriete' → idem, ajouter alias
    qui pointe vers /arbitrage/location-vs-propriete.

FIX-N-P1-4 — Audit des 14 PopScope
  Référence : NAVIGATION_AUDIT.md §P1-4 (tableau complet)
  Pour CHAQUE écran listé, ouvre le fichier et :
    • Vérifie que le user PEUT TOUJOURS sortir (pas de bloc total)
    • Si un dialog de confirmation existe, vérifie qu'il ne bloque
      pas quand AUCUNE donnée n'a été modifiée (track dirty state)
    • Note dans audits/POPSCOPE_AUDIT.md le statut par écran
  C'est de l'audit, pas du fix systématique. Liste-moi les écrans
  où il faut vraiment intervenir avant de toucher au code.

═══════════════════════════════════════════════════════════════════
RÈGLES NAVIGATION (NON-NÉGOCIABLES)
═══════════════════════════════════════════════════════════════════

R-NAV-1  Aucun context.push / context.go ne doit avaler des
         query params silencieusement. Si tu vois `extra` ou
         `?xxx=` quelque part, vérifie qu'il est utilisé en aval.

R-NAV-2  Le LLM ne décide jamais de la navigation. Il propose
         un intentTag → RoutePlanner.plan() → action. Si tu vois
         dans coach_orchestrator.dart un context.push direct, tu
         le flag dans audits/VIOLATIONS.md.

R-NAV-3  Toute route avec preferFromChat: true dans ScreenRegistry
         doit avoir un intentTag connu de IntentRouter. Vérifie
         la cohérence après chaque fix.

R-NAV-4  Aucune redirection en cascade. Une route va directement
         à sa destination. Pas de A→B→C.

R-NAV-5  Tests obligatoires : pour chaque FIX, ajouter un test
         dans test/router/ qui simule la nav et vérifie l'URL
         finale + les query params préservés.

Commence par FIX-N-P0-1.
```

---

# PROMPT 2 — Fix bloc DUPLICATE CLASSES (compilation)

> Référence directe : `AUDIT_REPORT.md` §1. Ces 5 classes empêchent la compilation propre.

```
Phase Duplicates. Lis AUDIT_REPORT.md §1.

5 classes publiques sont définies à 2 endroits — Dart les tolère
parfois mais c'est une bombe à retardement.

PROTOCOLE :
  Pour chaque classe, tu :
  1. Identifies la version CANONIQUE (la plus complète, la plus
     récemment touchée, ou celle avec le plus d'imports entrants)
  2. Liste les call-sites qui importent la version DUPLICATE
  3. Migre les imports vers la version canonique
  4. Supprime le fichier duplicate
  5. Lance flutter analyze
  6. Attends mon go avant la suivante

═══════════════════════════════════════════════════════════════════
ORDRE DE TRAITEMENT
═══════════════════════════════════════════════════════════════════

DUP-1  ChiffreChoc (3 endroits)
  Canonique attendue : lib/models/response_card.dart
  Duplicates :
    • lib/models/minimal_profile_models.dart
    • lib/services/pillar_3a_deep_service.dart
  Vérifie d'abord que les 3 définitions sont COMPATIBLES. Si elles
  divergent, montre-moi les diffs et arbitre avec moi avant migration.

DUP-2  CoachNarrativeService (2 endroits)
  Candidats canoniques :
    • lib/services/coach_narrative_service.dart
    • lib/services/coach/coach_narrative_service.dart
  La convention récente du repo place les services coach dans
  lib/services/coach/. Si la version canonique est celle dans
  lib/services/coach/, supprime la version racine et migre.

DUP-3  AdvisorDossier (2 endroits)
  • lib/services/advisor/advisor_matching_service.dart
  • lib/services/expert/dossier_preparation_service.dart
  Vérifier la sémantique : si ce sont 2 concepts différents,
  RENOMMER l'un des deux (pas supprimer). Sinon, fusionner.

DUP-4  WeeklyRecapService (2 endroits)
  • lib/services/recap/weekly_recap_service.dart
  • lib/services/coach/weekly_recap_service.dart
  Idem DUP-2.

DUP-5  Privates partagés (low priority)
  _GaugePainter, _HubItemCard (×7), _PieChartPainter, etc.
  → ne PAS fixer maintenant. Crée audits/BACKLOG_PRIVATES.md
  avec la liste pour traitement futur.

═══════════════════════════════════════════════════════════════════

Attention : flutter analyze doit rester à 0 erreur après chaque
duplicate. Si erreur, rollback et explique-moi.

Commence par DUP-1.
```

---

# PROMPT 3 — Fix bloc CHAT (deadlock + context window)

> Référence : `AUDIT_COMPLET.md` findings #1 + #3 + #13.

```
Phase Chat. Le coach chat est CASSÉ EN PROD depuis 2026-03-22 selon
AUDIT_COMPLET.md #1. Lis AUDIT_COMPLET.md §"BLOQUANTS ABSOLUS"
en entier avant de toucher quoi que ce soit.

═══════════════════════════════════════════════════════════════════
ORDRE DE FIX
═══════════════════════════════════════════════════════════════════

FIX-C-1 — Coach chat deadlock (RAG lazy init)
  Fichier : services/backend/app/api/v1/endpoints/coach_chat.py:183-187
  Référence : FIX-2026-04-11 acknowledged mais jamais appliqué
  Action :
    • Lis les lignes 150-220 pour comprendre le pattern actuel
    • Ouvre le doc decisions/ et postmortems/ pour trouver
      FIX-2026-04-11
    • Applique le fix documenté
    • Si pas de doc claire : déplace l'init RAG hors du chemin
      critique (warm-up au boot, pas en lazy par requête)
    • Test : python -m pytest tests/test_coach_chat.py
    • Montre-moi le diff AVANT application

FIX-C-3 — Chat context window
  Fichiers :
    • apps/mobile/lib/services/coach/coach_orchestrator.dart:1235-1236
    • apps/mobile/lib/services/coach/coach_orchestrator.dart:787
  Bug : context window 8 messages, et l'history n'est pas envoyé
  aux paths SLM/BYOK.
  Action :
    • Passer 8 → 32 messages
    • S'assurer que l'history (tier SLM ET tier BYOK) reçoit
      bien la même fenêtre
    • Vérifier que le greeting initial est PIN au début (jamais
      éjecté de la fenêtre)
    • Test golden : conversation de 40 tours, vérifier que le
      coach se souvient du tour #2 au tour #38

FIX-C-13 — save_fact tool cassé
  Fichiers :
    • services/backend/app/services/coach/coach_tools.py:489-592
    • services/backend/app/api/v1/endpoints/coach_chat.py:2159-2200
  Bug : LLM n'appelle pas save_fact, fallback regex fragile.
  Action :
    • Lis le prompt actuel qui décrit save_fact
    • Cherche pourquoi le LLM ne le déclenche pas (description
      ambiguë ? exemples manquants ? trigger conditions floues ?)
    • Réécris la description du tool en suivant les guidelines
      Anthropic (1 verbe d'action clair, 2-3 exemples)
    • Test : conversation type "Je suis indépendant à Genève,
      40 ans, revenus variables" → save_fact doit être appelé
      avec archetype + canton + age

FIX-C-15 — MultiProvider sous MaterialApp.router
  Fichier : apps/mobile/lib/app.dart:173 + 1169
  Bug : ProviderNotFound race condition au cold start.
  Action : hoister MultiProvider AU-DESSUS de MaterialApp.router.
  C'est mécanique mais fais-le avec attention au _bindRouterAuthListener
  qui dépend de l'ordre de construction.

═══════════════════════════════════════════════════════════════════

Une étape à la fois. Diff avant application. Tests après.

Commence par FIX-C-1 (le plus critique — coach mort en prod).
```

---

# PROMPT 4 — Fix bloc DESIGN / UX paper cuts

> Pour les bugs de design + UX révélés par les audits + l'examen du DS.

```
Phase Design. Tu vas auditer et fixer les paper cuts UX +
incohérences design.

PROTOCOLE :
  Pour chaque catégorie, tu produis d'abord un audit dans
  audits/DESIGN_<categorie>.md avec preuves (chemin:ligne +
  capture si dispo), PUIS tu attends mon go avant fix.

═══════════════════════════════════════════════════════════════════
CATÉGORIES À AUDITER
═══════════════════════════════════════════════════════════════════

DESIGN-1  Cohérence des tokens
  Référence : apps/mobile/lib/theme/colors.dart + mint_text_styles.dart
  Action : grep dans lib/screens/ pour détecter :
    • Color(0xFF...) hardcodés au lieu de MintColors.xxx
    • TextStyle(fontSize: ..., color: ...) au lieu de
      MintTextStyles.xxx
    • EdgeInsets numériques au lieu de tokens d'espacement
  Sortie : tableau "fichier:ligne | violation | fix proposé"

DESIGN-2  Hiérarchie typo cassée
  Pour les 10 écrans les plus utilisés (à toi d'identifier via
  les call-sites de _router) :
    • Vérifie qu'il n'y a qu'UN headline par écran
    • Vérifie qu'aucun body n'est plus gros que son headline
    • Liste les violations

DESIGN-3  Touch targets < 44x44
  grep "GestureDetector" dans lib/screens/ + lib/widgets/
  Pour chaque, vérifier que le child a une taille mini de
  44x44. Si InkWell sans Container parent dimensionné = à fixer.

DESIGN-4  Contrastes WCAG
  Référence : AUDIT_COMPLET.md "textSecondary sur S0 warmWhite = 3.2:1"
  Action :
    • Lister TOUS les couples (background, foreground) du DS
    • Calculer le ratio
    • Flag tous ceux < 4.5:1 (text) ou < 3:1 (icones/large text)
  Sortie : tableau couleurs + ratios + statut WCAG

DESIGN-5  Inconsistances de format
  Référence : AUDIT_COMPLET.md "CHF format inconsistant"
  Action :
    • grep formatage CHF (1'000 vs 1,000 vs 1000)
    • Centraliser via un helper format_chf() unique
    • Migrer tous les call-sites

DESIGN-6  Loading states / Empty states
  Pour chaque écran qui fetch des données :
    • A-t-il un loading state ?
    • A-t-il un empty state ?
    • A-t-il un error state ?
  Sortie : matrice écrans × 3 états

DESIGN-7  Animations / micro-interactions
  Référence : MOTION_INTERACTION_AUDIT.md (si présent)
  Action : lis ce fichier et liste les animations cassées
  ou manquantes selon les standards du repo.

═══════════════════════════════════════════════════════════════════

Tu produis les 7 fichiers d'audit AVANT tout fix.
Une fois validés, tu passes au fix par catégorie.

Commence par DESIGN-1.
```

---

# PROMPT 5 — Fix bloc COMPLIANCE / FINMA-killers

> Référence : `AUDIT_COMPLET.md` §"Red flags FINMA-killers".

```
Phase Compliance. 3 FINMA-killers identifiés. Lis
AUDIT_COMPLET.md §"Red flags FINMA-killers" + §"Compliance FINMA"
en entier.

═══════════════════════════════════════════════════════════════════
FIXES (par ordre de criticité)
═══════════════════════════════════════════════════════════════════

FIX-FINMA-1  Archetype detection 5/8 → 8/8
  Fichier : services/backend/app/services/onboarding/minimal_profile_service.py:70-99
  Bug : indép sans LPP, cross-border, returning_swiss jamais
  détectés → conseil 3a faux → LSFin art. 3 violé
  Action :
    • Lis la fonction detect_archetype()
    • Ajoute les 3 archetypes manquants avec leurs heuristiques
    • Ajoute test unitaire pour chacun avec un cas type
    • Vérifie que ChatProjectionService ne fait pas de cas par
      archetype hardcodé qui rendrait l'ajout invisible

FIX-FINMA-2  PII log gate flip warn-only → blocking
  Référence : AUDIT_COMPLET.md "Phase 29 incomplète"
  Action :
    • Trouve la config qui flip warn vs block (probablement
      services/backend/app/core/logging.py ou un middleware)
    • Flip à blocking en prod
    • Ajoute test : log d'une chaîne contenant un IBAN doit lever
      une exception en blocking mode
    • Vérifie qu'aucune feature legitimate ne passe par ce path
      (sinon casse la prod)

FIX-FINMA-3  AVS13 post-2026
  Référence : AUDIT_COMPLET.md "AVS13 pas géré post-2026 →
  projections sous-estiment 8% (2'520 CHF)"
  Action :
    • Identifie les calculators qui projettent l'AVS
    • Ajoute la 13e rente dans le calcul si année >= 2026
    • Ajuste tests de référence (golden values + 8%)

FIX-FINMA-4  Hallucination threshold 30% → 15%
  Référence : AUDIT_COMPLET.md
  Action :
    • Trouve hallucination_detector.dart ou .py
    • Baisse le seuil de 30% à 15%
    • Ajoute cumulative tracking (si plusieurs petites
      hallucinations dans la même réponse)

FIX-FINMA-5  ISIN/ticker regex
  Action : ajouter dans ComplianceGuard une regex qui catch
  les ISIN (^[A-Z]{2}[A-Z0-9]{9}\d$) et tickers, pour empêcher
  le coach de halluciner "CH0123456789" comme produit.

═══════════════════════════════════════════════════════════════════

Tests obligatoires pour chaque fix. Une étape à la fois.
```

---

# PROMPT 6 — iOS / App Store compliance

> Référence : `AUDIT_COMPLET.md` finding #2.

```
Phase iOS. Le rejet App Store est imminent à 95%.

FIX-IOS-1  PrivacyInfo.xcprivacy
  Fichier à créer : apps/mobile/ios/Runner/PrivacyInfo.xcprivacy
  Action :
    • Lire la doc officielle Apple sur les "Required Reasons API"
    • Identifier les APIs concernées dans l'app (UserDefaults,
      file timestamps, system boot time, disk space)
    • Générer le fichier avec les déclarations correctes
    • Vérifier que la build iOS Release inclut bien le fichier

FIX-IOS-2  NSBonjourServices en Release
  Fichier : apps/mobile/ios/Runner/Info.plist
  Action : retirer _dartobservatory._tcp en Release (laisser
  uniquement en Debug via xcconfig flavor)

FIX-IOS-3  Entitlements push
  Fichier : apps/mobile/ios/Runner/Runner.entitlements
  Action : ajouter aps-environment + associated-domains
  selon les besoins notification + deep links

FIX-IOS-4  Deep links mint://
  Fichier : apps/mobile/ios/Runner/Info.plist
  Action : configurer URL schemes + universal links
```

---

# 🧪 Comment vérifier que Claude Code a bien tout fait

Après chaque PROMPT, demande :

```
Avant que je valide la phase, exécute ces 4 vérifications :

1. flutter analyze → 0 erreur, 0 warning
2. cd apps/mobile && flutter test → 100% green
3. cd services/backend && pytest → 100% green
4. Liste les fichiers que tu as touchés avec leur diff size
   (lignes ajoutées / supprimées par fichier)

Si une de ces 4 fail, on ne valide pas. On corrige avant.
```

---

# 🆘 Boîte à outils anti-dérapage

| Symptôme | Réponse |
|---|---|
| « Je vais aussi refactorer X » | « Hors scope. Note dans BACKLOG.md. Reviens au FIX en cours. » |
| « J'ai tout fait » sans diff | « Diff par fichier ou je n'avance pas. » |
| Il invente un chemin | « `find . -name "<fichier>"` et donne-moi la sortie. » |
| Il saute une étape du protocole | « Reviens à l'étape : annonce → diff → go → fix → test → go. » |
| Il viole un invariant | « Invariant R-NAV-2 violé ligne X. Annule. » |
| Il dit "probablement corrigé" | « Probablement = pas vérifié. Donne-moi la preuve. » |

---

# 🎯 Mon honnête évaluation

**Ce que je vois clair :**
- Tes audits sont déjà excellents — le travail d'investigation est fait
- Le problème n'est pas l'identification des bugs, c'est leur **exécution**
- Claude Code a besoin de **chemins exacts + ordre strict + portes de validation**

**Ce que je vois moyen :**
- Tu as 3 audits qui se contredisent partiellement (NAVIGATION dit "FIXED", AUDIT_COMPLET 10 jours plus tard dit "encore là"). **Prompt 0 doit trancher avant de lancer les fixes.**

**Ce que j'ignore :**
- Si certains fixes ont été appliqués depuis avril sans mise à jour des docs
- L'état des tests existants (j'ai vu test/ et tests/ mais pas leur santé)
- Si tu as un environnement de staging pour valider avant prod

**Mon conseil :** lance le **Prompt 0 d'abord**. Sa sortie te dira quels prompts (1, 2, 3, 4, 5, 6) sont pertinents et dans quel ordre. Ne lance pas les 6 en parallèle — Claude Code se perd, et toi aussi.
