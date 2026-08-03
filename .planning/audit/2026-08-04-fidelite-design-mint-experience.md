---
description: Audit de fidélité au design validé (mint-experience, 5e lentille) sur 4 surfaces fraîchement shippées — SafeModeGate + rachat échelonné (#1177), login localisé + « Recréer mon compte » (#1181), disclaimers 3a via ARB (#1181), ConfidenceEvolutionCard + MintTrameConfiance (#1168/#1169/#1163/#1164). Constat sans patch. Verdict par surface + checklist opératoire 5e lentille.
---

# Audit fidélité design — mint-experience — 2026-08-04

## TLDR

Lecture statique des 4 surfaces les plus récemment shippées, telles qu'elles
existent sur `origin/dev @ 347ab2725` (worktree isolé, aucune modification de
surface). Verdict global : **les nouveaux composants sont conformes au design
validé et à la doctrine « chaleur sans jugement, jamais de cul-de-sac »**, avec
un écart de cohérence à trancher par le propriétaire du design (deux
vocabulaires visuels de confiance coexistent désormais) et une poignée d'écarts
mineurs de voix, de tokens et d'accessibilité. Aucun patch appliqué (doctrine
audit-corpus-before-patching). Chaque écart cite `path:line`, la référence
canonique en tension, un correctif proposé (non appliqué) et une priorité.

**Important — statut de cet audit.** C'est un **constat** issu d'une relecture
du code et de la copie, pas une vérité. Aucune exécution sim, aucun test
utilisateur : les verdicts de compréhension sont analytiques (« test des
toilettes » appliqué de tête), pas mesurés. La reproduction mécanique — sim,
lint, ou l'œil de Julien — reste requise avant que toute conclusion tienne. Le
gate LSFin des termes bannis n'est **pas** tranché ici : deux items sont routés
vers `mint-swiss-brain` (mandat : je ne valide jamais ma propre copie ni la
conformité LSFin).

## Périmètre et méthode

| # | Surface | PR | Commit | Fichiers-clés audités |
|---|---------|----|--------|-----------------------|
| S1 | SafeModeGate rénové + rachat échelonné | #1177 | `94e5eac5e` | `widgets/common/safe_mode_gate.dart`, `screens/lpp_deep/rachat_echelonne_screen.dart` |
| S2 | Login : erreurs localisées + « Recréer mon compte » | #1181 | `d261b888f` | `screens/auth/login_screen.dart`, `providers/auth_provider.dart` |
| S3 | Écrans 3a profonds : disclaimers via ARB | #1181 | `d261b888f` | `screens/pillar_3a_deep/provider_comparator_screen.dart`, ARB `pillar3a*Disclaimer` |
| S4 | ConfidenceEvolutionCard / MintTrameConfiance | #1168 / #1169 / #1163 / #1164 | `9a4a4ee78` `f1f552fa0` `4f22b85ce` `9a210610e` | `widgets/aujourdhui/confidence_evolution_card.dart`, `widgets/trust/mint_trame_confiance.dart`, `screens/independants/dividende_vs_salaire_screen.dart` |

Chemins relatifs à `apps/mobile/lib/` (sauf ARB : `apps/mobile/lib/l10n/app_fr.arb`).
Grille par surface : (a) tokens couleur/typo/espacement · (b) voix ·
(c) air / hiérarchie / un chiffre d'abord · (d) accessibilité · (e) compréhension ·
(f) cohérence inter-écrans.

## Verdict de synthèse

| Surface | Verdict global | Écarts majeurs | Écarts mineurs | Escalades swiss-brain |
|---------|----------------|:---:|:---:|:---:|
| S1 SafeModeGate | **CONFORME** (structure exemplaire) | 0 | 4 | 0 |
| S2 Login | **CONFORME** | 0 | 2 | 0 |
| S3 Disclaimers 3a | **CONFORME** (fix), écart de voix | 0 | 2 | 2 |
| S4 Confidence / MTC | **CONFORME** (composants), **ÉCART MAJEUR** (cohérence) | 1 | 3 | 0 |

Un seul écart **majeur** au total (S4-F1), et c'est une décision de doctrine à
prendre, pas un défaut à corriger en aveugle.

---

## S1 — SafeModeGate rénové + rachat échelonné (#1177)

**Verdict global : CONFORME.** La porte honore précisément la North Star
« la porte qui explique et se corrige » et le principe MINT_IDENTITY #2
(réduire la honte) : elle NOMME la cause, laisse corriger la donnée, et offre
TOUJOURS une sortie de poids égal. Aucun dark pattern. Écarts mineurs de casse
de titre, de cible tactile et de tokens d'espacement.

### (a) Tokens — CONFORME (1 écart mineur)
- Zéro hex en dur, tout via `MintColors.*` (`safe_mode_gate.dart:126-134,191,241`).
  Bordure seule, sans ombre (`:125-129`) → respecte DESIGN_SYSTEM §3.5
  « pas de bordure ET ombre ». **CONFORME.**
- **S1-A1 (ÉCART MINEUR, priorité basse)** — espacements hors échelle :
  `EdgeInsets.symmetric(vertical: 12)` (`:123`), `EdgeInsets.all(20)` (`:124`),
  `symmetric(vertical: 10)` (`:243`). L'échelle canonique (DESIGN_SYSTEM §3.3)
  est 4/8/16/24/32/48 ; 12/20/10 sont hors token. Réf. : DESIGN_SYSTEM §3.3 +
  North Star benchmark principe 11 (« tokens 8/16/24/40 »). **Correctif proposé :**
  `all(20)→MintSpacing.lg (24)`, `vertical:12→sm (8) ou md (16)`. **Nuance :** 20
  est la convention de padding horizontal de facto sur des dizaines d'écrans
  existants ; ce n'est pas une régression introduite par la PR, mais une dette de
  migration connue. Priorité basse.

### (b) Voix — CONFORME sur le corps, 1 écart mineur sur le titre
- Corps calme, factuel, non accusateur, conditionnel, sans terme banni :
  `safeModeMessage` = « …les optimisations avancées sont en pause. Priorité :
  stabiliser ta trésorerie. Le reste attendra. » ; motifs de provenance factuels
  (`safeModeReasonDebtLoad/HighDebtRatio/ThinCushion`). **CONFORME.**
- **S1-B1 (ÉCART MINEUR, priorité moyenne)** — `safeModeTitle` = « Concentration
  Prioritaire » (`app_fr.arb:10386`). Deux problèmes : (1) **Title Case** (« P »
  majuscule) alors que DESIGN_SYSTEM §6.2 et VOICE_SYSTEM §5 imposent le **sentence
  case** ; (2) titre **abstrait**, il échoue au « toilet test » de MINT_IDENTITY
  (compréhensible à moitié fatigué) — le sibling `confidenceCurveTitle` = « Ta
  lucidité grandit » montre le bon registre (concret, sentence case). **Correctif
  proposé :** un titre concret en sentence case, p. ex. « On stabilise d'abord »
  ou « Priorité : ta trésorerie ». Réf. : DESIGN_SYSTEM §6.2, VOICE_SYSTEM §5,
  MINT_IDENTITY toilet test.
- **S1-B2 (ÉCART MINEUR, priorité basse)** — `safeModeWhyBlockedBody` = « En mode
  protection, MINT priorise… » (`app_fr.arb:12802`). Le mot « protection » comme
  nom de mode entre en légère tension avec le pivot doctrinal « lucidité, pas
  protection » (CLAUDE.md règle 3). Sens différent (état financier de sûreté ≠
  cadrage assurantiel), mais un lecteur relit « protection » à contre-courant du
  positionnement. **Correctif proposé :** « mode prudence » ou « pause de
  stabilisation ». Priorité basse.
- **S1-B3 (ÉCART MINEUR, priorité basse)** — apostrophes typographiques
  incohérentes : `safeModeMessage` emploie l'apostrophe courbe (« qu'un ») tandis
  que `safeModeWhyBlockedTitle` emploie l'apostrophe droite (« c'est »). Hygiène
  typographique, non bloquant.

### (c) Air / hiérarchie — CONFORME
Une icône + titre + message + motifs + actions empilés, conteneur bordé aéré.
Le gate est un sous-composant d'un écran Simulator (catégorie B), pas un hero —
la densité est justifiée. **CONFORME.**

### (d) Accessibilité — CONFORME sauf 1 cible tactile
- Boutons « Corriger mes données » (`OutlinedButton`, `:238`) et « Continuer
  quand même » (`TextButton`, `:276`) : cibles tactiles ≥ 48pt par le
  `MaterialTapTargetSize.padded` par défaut. `Semantics(button:true)` sur le lien
  « Pourquoi » (`:180-182`). **CONFORME.**
- **S1-D1 (ÉCART MINEUR, priorité moyenne)** — le lien « Pourquoi est-ce en
  pause ? » est un `InkWell` (`:183`) qui enveloppe directement un `Text`
  (`:228-231`), **sans padding ni contrainte de taille minimale** → cible tactile
  ≈ hauteur de texte (~18pt), sous le plancher 44pt. `Semantics(button:true)`
  aide le lecteur d'écran mais **ne dimensionne pas** la cible physique. Réf. :
  DESIGN_SYSTEM §8 (Semantics sur interactifs) + plancher 44pt (WCAG 2.5.5).
  **Correctif proposé :** envelopper le `Text` dans un padding/`ConstrainedBox`
  ≥ 44pt, ou transformer le lien en `TextButton` (qui obtient la cible padded).

### (e) Compréhension — CONFORME (structure), réserve sur le titre
La porte explique (motifs de provenance), corrige (« Corriger mes données » →
`/budget`) et ne bloque jamais (« Continuer quand même » révèle l'enfant,
`:278`). C'est un modèle du genre. Seule réserve : le titre S1-B1 fait entrer
par une abstraction. **S1-E1 (ÉCART MINEUR, priorité basse) :** incohérence
mineure — `reasons.take(3)` inline (`:156`) vs `take(4)` dans la bottom sheet
(`:213`). Aligner à un seul plafond.

### (f) Cohérence — CONFORME (fort)
La sortie « Continuer quand même » est une échappatoire réelle, de poids visuel
égal, pas un opt-out honteux → **aucun dark pattern**, aligné MINT_IDENTITY #2 et
la North Star « chaleur sans jugement ». **CONFORME.**

---

## S2 — Login : erreurs localisées + « Recréer mon compte » (#1181)

**Verdict global : CONFORME.** Le fix supprime la fuite du message serveur brut
anglais et le remplace par une copie humaine localisée, avec `liveRegion` pour
VoiceOver et un CTA de récupération explicite. Catégorie E (Utility) — pas de
premier éclairage, Material 3 standard attendu.

### (a) Tokens — CONFORME
`MintColors.error/primary`, `MintSpacing.sm/xs/lg`, `MintTextStyles.bodySmall/bodyMedium`.
Zéro hex (`login_screen.dart:451-478`). **CONFORME.**

### (b) Voix — CONFORME (1 écart mineur de registre)
- Messages clairs, calmes, actionnables, honnêtes, sans terme banni.
  `authErrorAccountDeletedRecreate` = « Ce compte Apple a été supprimé. Recrée
  ton compte avec Apple pour continuer. » + CTA `authRecreateAccountCta` =
  « Recréer mon compte ». Aligné VOICE_SYSTEM §5 erreurs ([ce qui s'est passé] +
  [ce qu'on peut faire]). **CONFORME.**
- **S2-B1 (ÉCART MINEUR, priorité basse)** — deux messages au registre légèrement
  administratif/technique : `authErrorInvalid` = « Les informations saisies sont
  invalides. » (`app_fr.arb:8547`, ton froid) et `authErrorService` = « …sur cet
  environnement… » (`:8577`, « environnement » est du vocabulaire dev, opaque pour
  un débutant). **Correctif proposé :** « On n'a pas pu lire ces informations,
  réessaie » ; « …pas disponible ici pour l'instant. Utilise le mode local. »

### (c) Air / hiérarchie — CONFORME
Texte d'erreur + CTA de récupération en dessous, centrés. Sobre. **CONFORME.**

### (d) Accessibilité — CONFORME (fort)
`Semantics(liveRegion:true)` sur le texte d'erreur (`:451`) → VoiceOver annonce
l'erreur et le CTA dès l'apparition via `setState`. `Semantics(label + button)`
sur le CTA (`:468`), cible padded par défaut. **CONFORME.**

### (e) Compréhension — CONFORME
Le gain central : un message serveur brut anglais (« Apple account was
deleted… ») devient une phrase humaine localisée avec une sortie. **CONFORME.**

### (f) Cohérence — 1 écart mineur
- **S2-F1 (ÉCART MINEUR, priorité basse)** — le CTA « Recréer mon compte » est un
  `TextButton` (Ghost) coloré en `MintColors.primary` (`:476`). DESIGN_SYSTEM §4.2
  spécifie la couleur de texte Ghost = `info`. L'usage de `primary` (anthracite)
  sur une action de récupération est défendable mais dévie du token Ghost.
  **Correctif proposé :** aligner sur `info`, ou entériner `primary` comme
  variante « récupération » documentée.

---

## S3 — Écrans 3a profonds : disclaimers via ARB (#1181)

**Verdict global : CONFORME sur le fix, avec un écart de voix réel.** Le fix fait
enfin rendre les disclaimers **avec accents** (l'appel passait `l: S.of(context)`
au lieu du fallback ASCII) et route les libellés prestataires via ARB. Accents
désormais corrects partout. Mais la **famille de disclaimers mélange tu et vous**,
et une formulation flirte avec la surface des termes bannis.

### (a) Tokens — CONFORME
Le conteneur de disclaimer utilise `MintSpacing.md` et `MintTextStyles.labelSmall(color: MintColors.textMuted)`
(`provider_comparator_screen.dart:363-366` et suivants). **CONFORME.**

### (b) Voix — ÉCART MINEUR (voix), priorité moyenne
- **S3-B1 (ÉCART MINEUR, priorité moyenne) — mélange tu / vous dans la même
  famille.** Trois disclaimers terminent en **vous** : « **Consultez** un ou une
  spécialiste » (`app_fr.arb:10036`, `:10037`, `:10038`) alors que la même phrase
  emploie **tu** juste avant (« dépend de **ta** situation », « **ton** taux »).
  Or `pillar3aIndepDisclaimer` (`:5696`) dit correctement « **Consulte** un·e
  spécialiste » (tu). DESIGN_SYSTEM §6.1 et VOICE_SYSTEM §3 posent le tutoiement
  comme ce qui **ne change JAMAIS**. C'est à la fois un écart à la règle et une
  **incohérence interne** entre disclaimers frères. **Correctif proposé :**
  « Consultez » → « Consulte » sur les trois clés. Surface sensible (conformité) :
  le correctif ne touche que le registre, pas le fond légal.
- **S3-B2 (ÉCART MINEUR, priorité moyenne + escalade)** — `pillar3aDisclaimer`
  (`:2548`) dit « …ne constituent pas une **assurance de résultat** » alors que
  les trois autres disent la forme plus propre « ne préjugent pas des rendements
  futurs ». La forme « assurance de résultat » est plus faible et fait surface le
  mot « assurance » (négation d'une garantie — sémantiquement un disclaimer, mais
  proche de la surface des termes bannis LSFin). **Ce n'est pas mon ressort de
  trancher le gate LSFin →** routé à `mint-swiss-brain` (voir Escalades).
  **Correctif proposé (sous réserve swiss-brain) :** uniformiser sur « ne
  préjugent pas des rendements futurs ».
- **Note positive** — « un ou une spécialiste » (forme développée) est **plus
  favorable aux lecteurs d'écran** que la forme à point médian « un·e » que le
  DESIGN_SYSTEM §6.1 donne en exemple. Recommandation transverse : standardiser
  la forme développée pour l'accessibilité TTS.
- Accents : tous corrects sur l'ensemble de la famille. **CONFORME.**

### (c) Air / hiérarchie — CONFORME
Disclaimer en footer, style `labelSmall`/`micro`, sur écrans Simulator (B) où le
disclaimer + sources est obligatoire (DESIGN_SYSTEM §2-B, §6.5). **CONFORME.**

### (d) Accessibilité — CONFORME
Texte statique. La forme développée « un ou une spécialiste » évite le point
médian problématique en synthèse vocale. **CONFORME.**

### (e) Compréhension — CONFORME
Registre dense/expert (KPMG, LIFD, OPP3) mais c'est la fonction d'un footer légal,
et l'audience 3a profonde est autonome/experte (VOICE_SYSTEM axe 2). Bases légales
citées. **CONFORME.**

### (f) Cohérence — voir S3-B1/B2
Le split tu/vous et le split « assurance de résultat » vs « ne préjugent pas »
sont les écarts de cohérence de la famille. Traités en (b).

### Escalades `mint-swiss-brain` (hors de mon mandat — je ne valide pas le gate LSFin)
- **S3-X1** — `pillar3aDisclaimer:2548` : « assurance de résultat » à faire
  passer au `check_banned_terms`.
- **S3-X2** — `pillar3aProviderAssuranceWarning` (`:8563`) : « une assurance 3a te
  coûte environ CHF {montant} de rendement en moins … par rapport à une fintech.
  Frais élevés et flexibilité réduite. » nomme un type de produit générique de
  façon défavorable. MINT_IDENTITY autorise l'analyse des caractéristiques
  génériques et la comparaison structurelle factuelle, mais le cadrage « te coûte
  en moins » oriente. À faire trancher par swiss-brain (chaîne éducative vs
  recommandation). **Note :** chaîne pré-existante, seulement re-surfacée par la
  PR (non introduite).

---

## S4 — ConfidenceEvolutionCard / MintTrameConfiance (#1168/#1169/#1163/#1164)

**Verdict global : composants CONFORMES (et forts), mais ÉCART MAJEUR de
cohérence inter-écrans.** Les deux widgets pris isolément sont exemplaires
(anti-honte, monotonie non régressante, Semantics porteur de sens, tokens AAA,
zéro hex). L'écart majeur est systémique : **deux vocabulaires visuels de
confiance coexistent désormais**, et cela touche une doctrine verrouillée +
un principe du benchmark North Star.

### (a) Tokens — CONFORME (1 écart mineur d'espacement)
- Zéro hex dans les deux widgets (vérifié : `grep Color(0x` → aucun).
  `confidence_evolution_card.dart` utilise `craie`, `borderSubtle`, `mintForest`,
  `primary`, `textMutedAaa` ; `mint_trame_confiance.dart` utilise `textMutedAaa`/
  `textSecondaryAaa` (peintre `:206-208`). **CONFORME.**
- **S4-A1 (ÉCART MINEUR, priorité basse)** — espacements hors échelle dans la
  carte : `fromLTRB(20, 8, 20, 8)` (`:107`), `all(20)` (`:109`). Même remarque
  qu'en S1-A1 (convention de facto, pas une régression). Priorité basse.

### (b) Voix — CONFORME (fort ; 1 dérive terminologique mineure)
- `confidenceCurveTitle` = « Ta lucidité grandit » — sentence case, concret,
  chaleureux, aligné North Star D5. Jalons **anti-honte** : ne nomment que des
  accomplissements (`_kMilestoneTriggers = {document_scan, check_in}`, `:28`),
  jamais l'absence — « Tu as éclairé un document le {date}. » Les résumés MTC ont
  MINT pour sujet de toute limite (« Mint reste prudent », « Mint préfère le
  redire »). Aligné D-04 anti-honte. **CONFORME.**
- **S4-B1 (ÉCART MINEUR, priorité basse)** — dérive terminologique : le titre dit
  « lucidité » (`confidenceCurveTitle:5918`) mais le label Semantics dit
  « confiance » (`confidenceCurveTrendSemantics:5930` : « Ta confiance est passée
  de … »). Choisir un terme dominant (la North Star emploie les deux ; « lucidité »
  est le mot de marque, « confiance » le mot du modèle). Priorité basse.

### (c) Air / hiérarchie / un chiffre d'abord — CONFORME (fort)
Un chiffre (`$latest` en `headlineSmall`, `:192-197`) + label « maintenant » +
courbe + un jalon nommé. Aucun axe, aucune grille (`_ConfidenceCurvePainter`) —
« l'air est une structure » (North Star principe 11). **CONFORME.**

### (d) Accessibilité — CONFORME (fort)
La courbe porte sa tendance **en mots** via `Semantics(label: confidenceCurveTrendSemantics(start, latest))`
(`:212-216`) — la ligne peinte est invisible au lecteur d'écran, ils l'ont géré.
MTC : annonce unique par changement de référence (D-11), fallback reduced-motion
50 ms (`:400-412`), tokens AAA. **CONFORME.**

### (e) Compréhension — CONFORME (fort)
« Toi d'avant vs toi maintenant » rendu par une courbe de croissance + un jalon
nommé, mesuré en compréhension et non en dépenses (North Star principes 6-8).
Monotonie au rendu (`confidenceRunningMax`, `:36-48`) → un utilisateur passif ne
voit jamais la courbe régresser par inaction (critère de sortie D5). **CONFORME.**

### (f) Cohérence — **ÉCART MAJEUR (S4-F1), priorité haute**

**Constat.** Deux primitifs de rendu de confiance coexistent après ces PRs :

1. **`MintTrameConfiance`** (bande D10 sur `dividende_vs_salaire_screen.dart:290-296`)
   — trame grise de 4dp (`textMutedAaa`/`textSecondaryAaa`), axe le plus faible,
   **AUCUN chiffre**. Sa doctrine se déclare « le **SEUL** primitif de rendu de
   confiance » (`dividende_vs_salaire_screen.dart:266-268`), avec D-04 « no
   headline number » et D-08 « no public score getter … prevents the renderer
   from being weaponized for ranking surfaces » (`mint_trame_confiance.dart:12-17`).
2. **`ConfidenceEvolutionCard`** (`aujourdhui_screen`) — un `CustomPainter`
   maison : ligne anthracite (`primary`) + point terminal `mintForest` + **un
   chiffre en tête** (`$latest`, `:192-197`).

Cela met en tension trois références canoniques :
- la doctrine MTC « seul primitif de confiance » + D-04/D-08 (pas de chiffre nu
  de confiance, pour éviter la « weaponisation » en surface de ranking) ;
- le benchmark North Star **principe 9** : « la confiance a **UNE** couleur,
  constante partout » — or ici gris (MTC) vs anthracite+forêt (courbe) ;
- la note anti-honte de `colors.dart` (`successAaa` : « NOT for score badges
  (banned by anti-shame doctrine) ») — un chiffre de confiance en tête ressemble
  à un badge de score.

**Nuance qui joue en faveur du design shippé.** Les deux objets encodent des
choses **différentes** : MTC = « à quel point faire confiance à CE chiffre-ci
maintenant » (axe faible, une prudence) ; la courbe = « ta compréhension dans le
temps » (une trajectoire). La doctrine « MTC seul primitif » a été écrite pour la
confiance **par-chiffre**. Qu'une **courbe de lucidité dans le temps** compte ou
non comme « rendu de confiance » est une **ambiguïté réelle et non tranchée**.

**C'est pourquoi c'est un écart MAJEUR sans être un défaut à corriger en
aveugle.** La 5e lentille signale ceci pour une **décision du propriétaire du
design**, pas pour une homogénéisation automatique. Deux issues possibles :
- **(A, recommandé)** déclarer formellement la courbe d'évolution comme un objet
  sémantique **distinct** (« trajectoire de lucidité dans le temps » ≠ confiance
  par-chiffre), avec sa propre grammaire documentée (anthracite + un accent
  forêt, chiffre autorisé **en tant que croissance, pas en tant que note**), et
  écrire cette frontière dans la doctrine MTC / DESIGN_SYSTEM ;
- **(B)** aligner le vocabulaire couleur de la courbe sur MTC et retirer le
  chiffre nu.

Je recommande **(A)** car les deux objets diffèrent réellement — mais la
frontière est aujourd'hui **implicite**, et mon mandat interdit que la cohérence
design prime sur la compréhension : ici la courbe **sert** la compréhension
(North Star D5), donc c'est la cohérence qui doit céder, et le correctif est de
**documenter la distinction**, pas de bleachiser la courbe. **Correctif proposé
(non appliqué) :** ajouter une section « confiance par-chiffre (MTC) vs
trajectoire de lucidité (courbe) » dans la doctrine MTC + DESIGN_SYSTEM, et
confirmer (œil de Julien) que le chiffre `$latest`, encadré par « Ta lucidité
grandit » + « maintenant » + la courbe, se lit comme **croissance** et non comme
**note honteuse**.

### (f-bis) Défauts adjacents PRÉ-EXISTANTS sur l'écran hôte — constat, hors périmètre shippé
Repérés en balayant l'écran qui héberge la bande D10, **non introduits** par les
PRs auditées (Karpathy #3 : signaler l'adjacent, ne pas le corriger sans mandat) :
- **S4-Z1 (priorité basse)** — légendes de chart en **français codé en dur** :
  `_buildChartLegend(MintColors.success, 'Split adapte')` (`dividende_vs_salaire_screen.dart:487`,
  **accent manquant** : « adapté »), plus `'Charge totale'` (`:485`) et
  `'Position actuelle'` (`:489`). Écart i18n (CLAUDE.md règle 5) + accent.
  Blame `7daaa65c1e` (2026-04-08) — **pré-existant**, pas la PR D10.
- **S4-Z2 (priorité basse)** — en-têtes de section en **UPPERCASE + letterSpacing** :
  `'CHARGE TOTALE PAR SPLIT'` (`:452-453`) et `'À RETENIR'` (`:528-529`).
  DESIGN_SYSTEM §7 pattern interdit #5. Pré-existants (même blame). À planifier
  en nettoyage séparé, hors verdict de fidélité des surfaces shippées.

---

## Priorisation consolidée

| Priorité | ID | Surface | Nature | Correctif (non appliqué) |
|:---:|----|---------|--------|--------------------------|
| **P1 — haute** | S4-F1 | Confidence/MTC | Cohérence : 2 vocabulaires de confiance + chiffre nu | Décision propriétaire design : documenter la distinction (recommandé) ou aligner |
| **P2 — moyenne** | S1-B1 | SafeModeGate | Titre Title Case + abstrait | Sentence case + concret |
| **P2 — moyenne** | S1-D1 | SafeModeGate | Lien « Pourquoi » cible < 44pt | Padding/ConstrainedBox ≥ 44pt ou TextButton |
| **P2 — moyenne** | S3-B1 | Disclaimers 3a | Mélange tu/vous | « Consultez » → « Consulte » ×3 |
| **P2 — moyenne** | S3-X1/X2 | Disclaimers 3a | Termes bannis / cadrage produit | **Escalade swiss-brain** (pas mon ressort) |
| P3 — basse | S1-A1, S4-A1 | Gate, Card | Espacement hors échelle | Tokens 4/8/16/24/32/48 |
| P3 — basse | S1-B2 | SafeModeGate | « mode protection » | « mode prudence » |
| P3 — basse | S1-B3 | SafeModeGate | Apostrophes mixtes | Uniformiser courbe |
| P3 — basse | S1-E1 | SafeModeGate | `take(3)` vs `take(4)` | Un seul plafond |
| P3 — basse | S2-B1 | Login | Registre « environnement » / « invalides » | Reformuler humain |
| P3 — basse | S2-F1 | Login | CTA Ghost en `primary` | Aligner `info` ou entériner |
| P3 — basse | S4-B1 | Card | « lucidité » vs « confiance » | Terme dominant |
| P3 — basse | S4-Z1, S4-Z2 | dividende (hôte) | i18n + accent + UPPERCASE **pré-existants** | Nettoyage séparé, hors périmètre |

---

## Checklist opératoire « 5e lentille » pour les futurs panels design

Bornée par le mandat : la cohérence design **ne prime jamais** sur
l'accessibilité (points 6-7) ni sur les résultats de compréhension mesurés
(points 1-2). Quand un point de cohérence (5, 9) entre en conflit avec un point
a11y ou compréhension, **c'est la cohérence qui cède**, et le correctif est de
documenter la distinction, pas d'homogénéiser.

1. **Un chiffre d'abord, jamais nu.** Un seul chiffre domine, avec un label
   humain. Un chiffre projeté/estimé s'accompagne de son cadre de confiance ; un
   chiffre de confiance/score ne se lit jamais comme une **note** (anti-honte).
2. **Titres : sentence case + concret (toilet test).** Rejeter Title Case,
   UPPERCASE et abstractions. Test : compréhensible à moitié fatigué.
3. **Tutoiement systématique.** Traquer tout « vous / Consultez / Veuillez »,
   **y compris dans les disclaimers**, et vérifier la cohérence tu entre écrans
   frères.
4. **Termes bannis LSFin : ne jamais valider seul.** Router tout doute
   (assurance/garanti/optimal/meilleur…) vers `mint-swiss-brain` + le gate
   `check_banned_terms` **avant** merge.
5. **Une seule couleur = un seul sens pour la confiance.** Tout nouveau rendu de
   confiance passe par `MintTrameConfiance`, **ou** documente explicitement
   pourquoi c'est un objet sémantique distinct (couleur/chiffre autorisés).
6. **Cibles tactiles ≥ 44pt sur TOUT interactif.** `Semantics(button:true)` ne
   dimensionne pas la cible : vérifier padding/minSize, surtout sur les liens
   texte et chips.
7. **Le Semantics porte le sens qu'une peinture cache.** Toute courbe / trame /
   couleur-seule a un label texte (tendance en mots) ; reduced-motion géré.
8. **Jamais de cul-de-sac, jamais de honte, jamais de dark pattern.** Toute porte
   qui met en pause NOMME la cause, offre une correction ET une sortie de **poids
   égal**. La sortie n'est jamais un opt-out honteux.
9. **Tokens only.** Zéro hex ; espacement sur l'échelle 4/8/16/24/32/48 ;
   `MintTextStyles` ; deux fonts max (Montserrat + Inter). Signaler l'off-scale.
10. **i18n + accents parfaits.** Zéro string FR en dur (surtout légendes de
    charts) ; accents complets ; toute copie relue par le gate accent FR et
    `validate_arb_parity()` avant merge.

---

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?** Que je sur-indexe sur la
  cohérence : imposer « une seule couleur de confiance » (S4-F1) risque
  d'étouffer un second visuel réellement utile — la courbe de croissance de
  lucidité, qui est justement un des rares moments vivants de la North Star. De
  même, des règles rigides de casse (S1-B1) et de tokens (S1-A1, S4-A1)
  pourraient délaver la chaleur éditoriale au nom d'une échelle. Réponse alignée
  au mandat : là où la courbe sert la compréhension, la cohérence cède — le
  correctif recommandé est de **documenter la distinction**, pas d'homogénéiser ;
  et les écarts de tokens sont explicitement classés priorité basse, non
  bloquants.
- **What does this source not address ?** (1) Aucune exécution sim ni test
  utilisateur : les verdicts de compréhension sont analytiques, non mesurés — le
  « toilet test » sur « Concentration Prioritaire » est mon œil, pas un
  débutant réel. (2) Seul le FR a été audité ; la parité et le ton des 5 autres
  ARB (de/en/es/it/pt) ne sont pas couverts. (3) Contraste couleur non
  re-mesuré pixel par pixel — je m'appuie sur les commentaires WCAG de
  `colors.dart`. (4) Les défauts pré-existants (S4-Z1/Z2) sont des constats
  blame-cités, pas attribués aux PRs.
- **What would change this conclusion ?** Un test avec un vrai débutant montrant
  que « Concentration Prioritaire » est compris en < 20 s invaliderait S1-B1. Une
  décision documentée du propriétaire du design déclarant la courbe d'évolution
  objet distinct **résout** S4-F1 sans changement de code. Un verdict swiss-brain
  sur S3-X1/X2 tranche ces deux items hors de mon ressort. Une reproduction
  mécanique (sim / lint / œil de Julien) prime sur tout verdict ci-dessus.

## Statut & suite

- **Constat, pas vérité.** Sortie d'agent = finding ; reproduction mécanique
  requise avant qu'une conclusion tienne. Aucun patch appliqué.
- **Décision de merge : lead.** Cet audit n'ouvre aucun périmètre d'implémentation.
- **Escalades :** S3-X1, S3-X2 → `mint-swiss-brain`. S4-F1 → propriétaire du
  design (ruling A vs B).
