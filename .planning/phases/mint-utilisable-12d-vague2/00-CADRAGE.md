---
description: "Cadrage vague 2 de la revue 12D écran-par-écran (plan MINT utilisable v2.1). Post-firstJob (Tier A) + Tier B smoke : 6 clusters de 4-6 écrans ordonnés par valeur utilisateur × dette 12D restante, avec dimensions rouges dominantes, type d'unité à ouvrir (calcul/texte/route/doublon), persona seedée et critères de sortie. S'appuie sur le registre 12D rafraîchi (§8, delta PR #1097→#1156)."
---

# Cadrage — Vague 2 de la revue 12D (post-firstJob, post-Tier B)

TLDR : la tranche firstJob (Tier A) est drainée écran-par-écran (12 PR : receipt,
états, lois, AX, i18n) et les 18 life events portent une ancre smoke Tier B (D1
Route + D4 Logique). La vague 2 attaque la dette 12D résiduelle par **clusters de
4-6 écrans cohérents** (par domaine), ordonnés **valeur utilisateur × dette
restante**. Chaque cluster nomme ses dimensions rouges dominantes, le type
d'unité à ouvrir, la persona seedée réelle, et ses critères de sortie mécaniques.
Ce cadrage est un document de pilotage : il n'implémente rien. Registre source :
`.planning/audit-etat-des-lieux-2026-07/REGISTRE-ECRANS-12D.md` §8 (delta) + §1
(tableau maître) + §3 (clusters doublons) + §6 (top-10 défectueux).

## Contexte (ce qui a bougé depuis le SHA figé)

- Registre pré-rempli sur `dev@5199757` (2026-07-29, PR #1090). Tête au cadrage :
  `dev@9096d462` (2026-07-31). 45 PR fusionnées (#1097→#1156).
- Tier A firstJob : drainé (Calc/Texte/Logique/Lois/A11y/Lucidité) — voir registre
  §8.2. Reste : littéraux de bornes de sliders, perf listes non virtualisées.
- Tier B smoke : les 18 life events ont une ancre « atteignable » (D1) + « pas de
  cul-de-sac » (D4) posée en motif profond (jamais wrapper racine, leçon ADR AX
  iOS 26.2) — registre §8.3. Ancre ≠ profondeur chiffrée : Calc/Lucidité/Lois
  restent la dette de la vague 2.
- AX iOS 26.2 : AppBar classique re-landée sur le chemin du gate + tranches 1-2
  (registre §8.4). Flutter 3.44.8 (#1126).
- La dimension 5 (doublons) reste la moins traitée : 1 violation « un seul
  étalon » LIVE détectée (rente LPP survivant, cf. §Doublons ci-dessous et
  registre §8.7).

## Principe d'ordonnancement

Score de priorité = **valeur utilisateur** (fréquence d'usage × centralité du
parcours × archétype nommé non-edge-case, cf. CLAUDE.md NEVER #7) **×** **dette
12D restante** (nombre de dimensions rouges dominantes non adressées par les 45
PR). Une violation « un seul étalon » LIVE (D5 avec chiffres divergents) est un
sur-pondérateur : elle casse la confiance transversalement.

Un cluster = un lot Codex (écran + widgets + services nourriciers), revu en
unités atomiques (1 unité = 1 branche = 1 PR). Design panel AVANT tout push
d'écran (mémoire `feedback_design_panel_before_push`). Tier C (receipt + parité +
oracle) par PR touchant une surface fiscale.

## Clusters ordonnés

### V2-1 — Indépendants (fiscalité SA/Sàrl + prévoyance libre) — PRIORITÉ 1

- **Écrans (6)** : `screens/independants/dividende_vs_salaire_screen.dart`
  (score 37, #2 top-défauts), `screens/independant_screen.dart` (score 31,
  post-#1130/#1140), `screens/independants/avs_cotisations_screen.dart`,
  `screens/independants/pillar_3a_indep_screen.dart`,
  `screens/independants/lpp_volontaire_screen.dart`,
  `screens/independants/ijm_screen.dart`. (= LOT-6 du registre.)
- **Dimensions rouges dominantes** : **D2 Calc** (calc local SANS financial_core /
  backend = NEVER #3 — split salaire/dividende, « AVS ~12.5% » en dur) · **D3
  Texte** (45 + 13 strings FR hardcodées, 0 réf l10n) · **D6 Lois** (LIFD art.
  18/20/33, CO art. 660, LFLP/LPP/OPP2 non tranchés swiss-brain) · **D10
  Lucidité(0)**.
- **Type d'unité à ouvrir** : (1) **calcul** — drainer le split salaire/dividende
  et l'AVS indépendant vers l'étalon backend (parité écran↔coach) ; (2) **texte**
  — extraction ARB 6 langues ; (3) **doublon** — vérifier que la logique dividende
  n'est pas dupliquée entre l'écran et `fiscal_superpower_widget`.
- **Persona seedée** : `independent_no_lpp` (route `/__e2e/row23-independent-no-lpp-profile`,
  flows `flow_row23_independent_no_lpp_*` + `row23_assert_independent_budget_formula.js`).
- **Justification** : 2 des 5 écrans les plus défectueux ; archétype explicitement
  nommé non-edge-case ; le calc-local-sans-core est le risque NEVER #3 le plus
  concentré du repo.

### V2-2 — Segments à risque (expat / frontalier / invalidité) — PRIORITÉ 2

- **Écrans (6)** : `screens/expat_screen.dart` (score 37, **#1** top-défauts),
  `screens/frontalier_screen.dart` (post-#1115), `screens/disability/disability_insurance_screen.dart`
  (score 27), `screens/disability/disability_gap_screen.dart` (post-#1142),
  `screens/disability/disability_self_employed_screen.dart`,
  `screens/gender_gap_screen.dart`. (≈ LOT-9 du registre.)
- **Dimensions rouges dominantes** : **D3 Texte** (32 + 14 strings hardcodées) ·
  **D6 Lois** (22 citations expat ; LAI art. 28, LAMal art. 67-77, LPP art. 23-26
  invalidité) · **D2 Calc** (« AVS −2.3%/an », « 80% salaire 720j » en dur) ·
  **D5 Doublon** (C5-disability : 3 écrans invalidité, frontière lacune ↔ assurance
  ↔ indépendant à trancher produit) · **D10 Lucidité(0)**.
- **Type d'unité à ouvrir** : (1) **texte + lois** — extraction ARB + drain des
  citations vers le registre réglementaire ; (2) **doublon** — résoudre C5 vers un
  canonique (ou différenciation documentée).
- **Persona seedée** : `expat_us` (`flow_hardgate_expat_us`, FATCA) + `frontalier_geneve`/
  `cross_border` (seed #1133, `flow_tierb_expat`).
- **Justification** : `expat_screen` est le #1 des défauts statiques ; expat_us et
  frontalier sont des personas Tier B ; C5-disability est un doublon à 3 têtes non
  résolu.

### V2-3 — Famille / succession (fiscalité vie + rente survivant) — PRIORITÉ 3

- **Écrans (6-7)** : `screens/mariage_screen.dart` (post-#1136),
  `screens/concubinage_screen.dart`, `screens/naissance_screen.dart`,
  `screens/divorce_simulator_screen.dart`, `screens/deces_proche_screen.dart`,
  `screens/donation_screen.dart` (post-#1145/#1156),
  `screens/coach/succession_patrimoine_screen.dart` (post-#1141/#1148).
  (= LOT-8 du registre.)
- **Dimensions rouges dominantes** : **D5 Doublon (LIVE)** — la rente LPP de
  survivant à 60% est décrite dans `mariage_screen` (cite LPP art. 21 al. 1) ET
  `concubinage_screen` (cite LPP art. 19), même taux, **citation d'article
  divergente** → violation « un seul étalon » · **D6 Lois** · **D2 Calc**
  (`compareFiscalMariage` drainé vers l'étalon #1136 → étendre naissance / divorce
  / décès) · **D10 Lucidité**.
- **Type d'unité à ouvrir** : (1) **doublon** — unifier la narration « rente
  survivant » vers une source unique + article tranché par swiss-brain ; (2)
  **calcul** — drain fiscal famille vers l'étalon (comme #1136) ; (3) **lois**.
- **Persona seedée** : `famille_bern` (seed #1135, `flow_tierb_famille_seeded_*`).
- **Justification** : porte la seule violation « un seul étalon » LIVE détectée ;
  famille est un domaine Tier B seedé ; le drain fiscal #1136 donne le patron à
  répliquer.

### V2-4 — Retraite / prévoyance profonde + parité receipt (C4) — PRIORITÉ 4

- **Écrans (5)** : `screens/coach/retirement_dashboard_screen.dart` (Lucid RT(57),
  post-#1143/#1144/#1148/#1154), `screens/arbitrage/rente_vs_capital_screen.dart`
  (post-#1097/#1123/#1127/#1129), `screens/lpp_deep/rachat_echelonne_screen.dart`,
  `screens/lpp_deep/libre_passage_screen.dart` (post-#1125/#1128/#1130),
  `screens/coach/optimisation_decaissement_screen.dart`. (≈ LOT-4 du registre.)
- **Dimensions rouges dominantes** : **D10 Lucidité** — `retirement_dashboard`
  RT(57) est la plus grosse dette lucidité non adressée (appareil de confiance +
  bande d'incertitude à rendre) · **D5 Doublon** — le MoneyTruthReceipt est câblé
  sur firstJob (#1107/#1108/#1109) mais **PAS propagé** aux surfaces retraite /
  dashboard → la parité dashboard↔coach (`inputs_hash`) n'est garantie que sur
  firstJob · **D2 Calc** (parité receipt).
- **Type d'unité à ouvrir** : (1) **lucidité** — propager le MoneyTruthReceipt
  firstJob → retraite/dashboards (appareil de confiance) ; (2) **doublon** —
  assertion `inputs_hash` dashboard↔coach hors firstJob.
- **Persona seedée** : `retraite_lausanne` (seed #1138, `flow_tierb_retraite`).
- **Justification** : retraite = surface centrale ; propager le receipt est
  l'extension directe du mécanisme north-star déjà prouvé sur firstJob.

### V2-5 — Argent / budget / dashboards quotidiens (C4 canonique) — PRIORITÉ 5

- **Écrans (5)** : `screens/aujourdhui/aujourdhui_screen.dart` (/home,
  post-#1106), `screens/mon_argent/mon_argent_screen.dart` (post-#1129),
  `screens/profile/financial_summary_screen.dart` (/profile/bilan, post-#1140),
  `screens/confidence/confidence_dashboard_screen.dart`,
  `screens/budget/budget_container_screen.dart` (+ budget_screen / budget_setup).
  (≈ LOT-3 du registre.)
- **Dimensions rouges dominantes** : **D5 Doublon** (C4-dashboards : 5 surfaces
  « dashboard » ; chevauchement **confidence ↔ bilan** à trancher — les deux
  affichent complétude/patrimoine ; 1 tap mort sur `confidence_dashboard`) · **D10
  Lucidité** · **D1 Route** (`budget_screen` 🟠 sans route directe — vérifier
  dérive vs container).
- **Type d'unité à ouvrir** : (1) **doublon** — trancher confidence↔bilan vers un
  canonique, retirer le tap mort ; (2) **route** — statuer sur `budget_screen`.
- **Persona seedée** : `famille_bern` (dashboard peuplé) ou `swiss_native`
  (baseline).
- **Justification** : surface quotidienne ; le chevauchement confidence↔bilan est
  un doublon fonctionnel non résolu qui dilue le message.

### V2-6 — Logement / hypothèque (C6-epl) — PRIORITÉ 6

- **Écrans (6)** : `screens/mortgage/affordability_screen.dart` (/hypotheque,
  post-#1141/#1148), `screens/lpp_deep/epl_screen.dart` (C6-epl canonique),
  `screens/mortgage/epl_combined_screen.dart` (C6-epl 2e tête),
  `screens/mortgage/amortization_screen.dart`,
  `screens/mortgage/imputed_rental_screen.dart`,
  `screens/mortgage/saron_vs_fixed_screen.dart`,
  `screens/housing_sale_screen.dart` (post-#1129/#1141). (= LOT-7 du registre.)
- **Dimensions rouges dominantes** : **D5 Doublon** (C6-epl : `epl_screen` ↔
  `epl_combined_screen` — fusion ou différenciation claire à trancher) · **D2
  Calc** (calcul hypothécaire local) · **D6 Lois**.
- **Type d'unité à ouvrir** : (1) **doublon** — trancher C6-epl ; (2) **calcul** —
  tracer les chiffres hypothécaires.
- **Persona seedée** : `swiss_native` propriétaire.
- **Justification** : valeur moyenne ; le doublon EPL est un cluster identifié non
  tranché, à faible risque mais à clarifier avant profondeur chiffrée.

## Doublons inter-écrans détectés (dimension 5 — passe ciblée)

1. **Rente LPP survivant 60% (LIVE, divergence de citation)** — `mariage_screen.dart`
   (« 60 % … LPP art. 21 al. 1 ») vs `concubinage_screen.dart` (« 60 % … LPP art.
   19 »). Même taux, articles divergents. Ajout de la citation mariage par #1136
   sans réconcilier concubinage. **Action** : arbitrage swiss-brain sur l'article
   correct + narration unique. → traité en V2-3.
2. **`anonymous_chat_screen.dart` — façade projection figée** : projection retraite
   entièrement en dur (avsMonthlyRente 1800, lppAnnualRente 18000,
   totalMonthlyRetirement 3300, plafond3a 7258, existingLpp 35000) qui double la
   projection réelle calculée par les providers C4. Écran orphelin (route →
   redirect /onb), déjà candidat SUPPRESSION (registre §3 C3-chat / LOT-14). →
   confirmé comme doublon-façade à chiffres divergents ; **supprimer** (LOT-14).
3. **Résolu (à noter)** : le taux de remplacement lit désormais
   `proj.tauxRemplacementBase` (objet projection partagé) sur `retirement_dashboard`
   ET `coach_chat` ; #1154 a rendu le libellé honnête → la duplication
   dashboard↔coach du taux est résolue À LA SOURCE.
4. **Non-doublon confirmé** : `lppSeuilEntree` est une constante partagée
   (`social_insurance.dart` + lookup `reg('lpp.entry_threshold', …)`) sur
   disability_gap / disability_insurance / onboarding_provider — centralisé, pas
   de divergence.
5. **C4-dashboards, doublon runtime (pas statique)** : les 5 écrans dashboard
   lisent en RT depuis les providers/services — pas de littéral dupliqué dans les
   écrans ; le risque « même projection potentiellement divergente » est une
   parité RUNTIME (assertion `inputs_hash` / receipt), non un doublon statique. →
   traité en V2-4 (propagation receipt) + V2-5 (canonique C4).

## Critères de sortie par cluster (mécaniques)

Un cluster est « fait » quand ses dimensions rouges dominantes sont fermées avec
la preuve du bon type (0-trust) :

- **D2 Calc** : chaque chiffre user-facing tracé (étalon ESTV / financial_core /
  receipt) ; 0 littéral numérique nu ; fixture de parité écran↔coach verte
  (Tier C par PR fiscale).
- **D3 Texte** : 0 string FR hardcodée sur les écrans du cluster
  (`validate_arb_parity()` 6 langues) ; accents FR (accent_lint) ; 0 terme banni
  LSFin (`check_banned_terms`).
- **D5 Doublon** : cluster résolu vers 1 canonique OU différenciation documentée ;
  0 chiffre / citation divergents entre écrans du même concept.
- **D6 Lois** : articles vérifiés swiss-brain (registre réglementaire) ;
  disclaimers LSFin présents.
- **D10 Lucidité** : appareil de confiance + bande d'incertitude rendus ;
  « pourquoi ce chiffre » accessible.
- **Preuve transverse** : flow Maestro seedé (persona du cluster) vert cité +
  Codex borné 330 s sur chaque diff + design panel avant push d'écran.

**Gate de non-régression** : Tier B smoke (18 life events) reste vert à chaque
vague (registre §8.3). Aucun cluster ne ferme sans que sa persona seedée termine
son flow sans cul-de-sac.

## Limites / angles morts (data gaps)

- Le delta §8 du registre marque « dimension TOUCHÉE par PR #N », pas « re-scanné
  propre » : la vérification runtime (Phase 2) reste due par écran.
- L'ordonnancement valeur×dette est un jugement de pilotage, pas une mesure ; à
  reconfirmer si l'audit de fréquence d'usage réel contredit (ex. logement plus
  utilisé qu'anticipé → remonter V2-6).
- Les scores 12D statiques du §6 sont des planchers regex (faux positifs
  possibles : clés, labels debug) — chaque site se relit en passe Codex.
- Personas seedées vérifiées présentes au 2026-07-31 ; si un seed est retiré, le
  cluster perd son gate de non-régression et doit re-seeder avant de fermer.
