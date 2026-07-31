---
description: "Résiduel actuariel P1 (Codex #1144) — l'avoir de 2e pilier (avoirLppTotal) est reconverti en rente (~6,8 %) pour TOUT profil, y compris un retraité qui a déjà annuitisé OU retiré son capital LPP → revenu LPP potentiellement fabriqué. Verdict : ambigu par construction (aucun champ de statut de décaissement). Le palier caveat-seul est INSUFFISANT (Codex GO-avec-changements) car le montant contamine revenu total / impôt / taux de remplacement / alertes PC, et casse un test existant (alertes.single). Fix propre = état calculatoire « statut inconnu » conservateur, cross-moteur (2 Dart + 1 Python), sensible produit (change ce qu'un retraité voit) + wiring onboarding (contrat Flutter) → hors unité bornée. Décision produit + sign-off lead requis avant implémentation."
---

# Contrat de statut de l'avoir LPP — éviter le double comptage rente (retraité)

> Origine : mandat Codex #1144 (moteur famille/retraite), résiduel actuariel P1.
> Date d'audit : 2026-07-31 · Base : `dev@fa5e1d970` · Périmètre : `RetirementProjectionService`
> (Dart, /retraite rendu), `ForecasterService` (Dart), `retirement_projection_service.py`
> (miroir backend), modèle `PrevoyanceProfile`, seed `retraite_lausanne`.
> Challenge actuariel : Codex borné (verdict **GO-avec-changements**, ci-dessous §4).

## 0. TL;DR

Un retraité « en régime » avec un avoir LPP renseigné voit cet avoir **reconverti en rente
au taux de conversion (~6,8 %)** par les moteurs de projection — exactement comme un
cotisant actif. Or, à la retraite, l'avoir a déjà connu un **mode de décaissement** que le
schéma actuel ne capture pas :

- **rente déjà servie** (annuitisé) : la caisse a gardé le capital, verse la rente. Reconvertir
  l'avoir redonne ~le bon montant, mais l'avoir n'est plus un actif retirable distinct.
- **capital déjà retiré** (lump sum) : l'avoir est de la fortune libre, **il n'y a AUCUNE rente
  LPP**. Reconvertir **fabrique** une rente (~1'802/mois sur 318'000) qui n'existe pas → risque
  de **sur-promesse LSFin**.

**Verdict : ambigu par construction.** Aucun champ ni signal existant ne distingue « rente
servie » de « capital retiré ». Le seed `retraite_lausanne` (avoir 318'000 → 1'802/mois)
n'est cohérent **que** sous l'hypothèse « l'avoir finance encore une rente ».

**Le palier caveat-seul est rejeté** (Codex) : le montant fabriqué alimente ensuite le revenu
total, l'impôt estimé, le solde budgétaire, le taux de remplacement et l'alerte PC — un texte
adjacent ne neutralise pas ces calculs. Le fix honnête exige un **état calculatoire
« statut inconnu » conservateur**, ce qui est **cross-moteur + sensible produit + demande un
wiring onboarding (contrat Flutter)** → **trop large et trop sensible pour une unité bornée**.
D'où cette page (verdict + plan) plutôt qu'un fix bâclé.

## 1. Le mécanisme fautif (preuves)

### 1.1 `RetirementProjectionService` (Dart, module /retraite rendu)

`_computeIncomes` convertit l'avoir en rente sans aucun garde-fou de statut :

- `apps/mobile/lib/services/retirement_projection_service.dart:499` —
  `LppCalculator.projectToRetirement(currentBalance: profile.prevoyance.avoirLppTotal ?? 0, currentAge: profile.age, retirementAge: ageUser, ...)`.
- `:515` — `LppCalculator.blendedMonthly(annualRente, conversionRate: userAdjustedConvRate, ...)`.
- Pour `employmentStatus == 'retraite'`, `profile.age ≈ ageUser` → ~0 an d'accumulation →
  conversion de l'avoir courant → ~1'802/mois.
- Cette source est sommée dans `revenuMensuel` (`:221`) puis dans `budgetGap`
  (`totalRevenusMensuel`, `:1159`) qui alimente **impôt estimé** (`:1181`), **taux de
  remplacement** (`:1206`), **solde** (`:1215`) et **alerte PC** (`:1247`).
- **Aucune** branche `employmentStatus == 'retraite'` ne modifie ce calcul LPP (contraste avec
  l'AVS, où `_declaredAvsMonthly` `:1336` honore une rente déclarée). Il n'existe **pas**
  d'équivalent `_declaredLppMonthly`.

### 1.2 `ForecasterService` (Dart)

- `apps/mobile/lib/services/forecaster_service.dart:533` — `lppBalance = avoirLppTotal ?? 0`.
- `:520-529` — branche « retraité déjà en régime » : `months <= 0 && isRetiredNow` n'ouvre
  PAS le court-circuit ; la boucle tourne 0 mois puis convertit les **soldes courants**.
- `:950` — `renteLppUser = lppBalance × envelopingRate` ; `:1005-1011` — inclus dans
  `revenuRetraiteAnnuel`.
- **Incohérence stock/flux** (relevée par Codex) : `capitalFinal` (`:1011`, via `totalCapital`
  `:810-816`) inclut `lppBalance` **et** `revenuAnnuelRetraite` inclut `lppBalance × taux`.
  Vérifié : les deux champs **ne sont jamais additionnés dans un même total rendu** (seule
  cooccurrence = un commentaire, `:224`). C'est donc une double-représentation conceptuelle
  du même capital (stock + flux), pas une double-addition dans un total unique — mais pour un
  retraité c'est exactement l'ambiguïté annuitisé-vs-retiré.

### 1.3 Miroir backend `retirement_projection_service.py`

- `services/backend/app/services/retirement/retirement_projection_service.py:151-170` —
  `if avoir_lpp is not None and float(avoir_lpp) > 0: ... years_to_retirement = max(0, ...)`
  puis `LppConversionService().compare(capital_lpp=projected_capital, ...)`.
- **Même logique, aucun garde-fou de statut.** Le dict `profile_data` ne porte ni
  `employmentStatus` ni statut LPP. Un fix Dart seul **diverge** du backend (parité rompue).

### 1.4 Le schéma ne peut pas trancher

`PrevoyanceProfile` (`apps/mobile/lib/models/coach_profile.dart:379-409`) porte :
`avoirLppTotal`, `avoirLppObligatoire/Surobligatoire`, `renteAVSEstimeeMensuelle` (rente AVS
déclarée, honorée), `projectedRenteLpp` (« rente projetée à 65 » — **provient uniquement d'un
scan de certificat**, jamais de l'onboarding, et **n'est consommée par aucun des deux moteurs**
de projection). **Aucun champ de statut de décaissement de l'avoir LPP.**

### 1.5 Le seed le documente déjà

`apps/mobile/lib/services/coach/coach_profile_seeds.dart:596-607` (persona `retraite_lausanne`,
`lppBalanceTotal: 318000`, `:654`) : « la rente LPP mensuelle est modélisée par l'AVOIR de 2e
pilier que RetirementProjectionService convertit en rente via le taux de conversion — SEULE
modélisation lue par le module retraite ». Le montant 1'802 est donc **une approximation par
construction**, correcte seulement si l'avoir finance encore une rente.

## 2. Verdict d'ambiguïté

**Ambigu par construction — confirmé.** Trois sens incompatibles pour un même
`avoirLppTotal > 0` sur un profil retraité :

| # | Interprétation | Rente LPP réelle | Ce que fait le moteur | Honnête ? |
|---|---|---|---|---|
| 1 | cotisant-en-cours (actif) | s'établira à la retraite | convertit après accumulation | ✅ nominal |
| 2 | rente déjà servie (annuitisé) | ≈ avoir × TC | reconvertit → ~bon nombre | ⚠️ nombre ~ok, l'avoir n'est plus un actif distinct |
| 3 | capital déjà retiré (lump sum) | **0** | reconvertit → **fabrique** ~1'802 | ❌ sur-promesse |

Aucun signal EXISTANT ne sépare (2) de (3) : `lppSource`/certificat prouve la **provenance**,
pas le **mode de sortie** ; une fortune libre positive ne prouve pas qu'elle vient de la LPP ;
`projectedRenteLpp` est une projection à 65 (pas la rente effectivement servie) et n'est de
toute façon pas lue par les moteurs ; l'absence de croissance signifie seulement que la date
cible est passée.

## 3. Pourquoi le fix caveat-seul (option 2 « molle ») ne suffit pas

Le palier initialement envisagé — « garder 1'802, ajouter un caveat rendu + note de confiance
abaissée » — a été **soumis à Codex avant implémentation** (rituel #1144) et **rejeté** :

1. **Contamination des totaux.** Les 1'802 alimentent revenu total, impôt estimé, solde
   budgétaire, taux de remplacement et alerte PC. Un caveat adjacent **ne neutralise pas** ces
   calculs → la sur-promesse persiste dans les chiffres, seulement « annotée ».
2. **Coût non nul.** Un test existant asserte **exactement une** alerte :
   `apps/mobile/test/services/retirement_projection_service_test.dart:283`
   (`result.budgetGap.alertes.single`). Ajouter une entrée casse ce test → le caveat n'est
   même pas « gratuit ».
3. **Baisser le score global mélange** la qualité générale du profil avec l'ambiguïté d'un
   scénario particulier — mauvais signal.
4. **`enrichmentPrompts` n'est pas nécessairement visible** sur la surface où le chiffre
   trompeur apparaît.

**Conclusion : un caveat sans traitement calculatoire reste une sur-promesse, même
correctement divulguée.** (Verdict Codex : « pas forcément l'enum complet maintenant, mais
obligatoirement un état calculatoire "inconnu" conservateur. »)

## 4. Modélisation propre retenue (plan)

Défaut sûr pour un retraité avec avoir positif et **statut LPP inconnu** :

1. **Traiter l'avoir comme statut inconnu = conservateur**, PAS implicitement « annuitisé ».
2. **Double scénario conditionnel rendu**, jamais un point unique :
   - « si cet avoir finance encore une rente : ~CHF 1'802/mois » ;
   - « si le capital a déjà été retiré : rente LPP CHF 0 (l'avoir est de la fortune libre) ».
3. **Headline / revenu de continuité / budget gap / impôt / taux de remplacement / alerte PC**
   utilisent la **branche conservatrice** (rente LPP non confirmée exclue du socle de revenu
   confirmé) jusqu'à confirmation utilisateur.
4. **Ne jamais présenter simultanément** le même avoir comme capital disponible ET rente
   acquise.
5. **Honorer une rente LPP servie déclarée** si un champ dédié existe (cf. AVS déclarée).
6. **Cas cotisant (actif) STRICTEMENT inchangé** — la condition n'active le traitement que pour
   `employmentStatus == 'retraite'`.

### Portée d'implémentation (pourquoi hors unité bornée)

| Chantier | Surface | Note |
|---|---|---|
| Champ / état de statut LPP | `PrevoyanceProfile` (Dart) + schéma profil (Python) | contrat de données ; défaut = inconnu-conservateur |
| Moteur 1 | `retirement_projection_service.dart` | branche conservatrice + double scénario |
| Moteur 2 | `forecaster_service.dart` | idem + cohérence stock/flux |
| Miroir | `retirement_projection_service.py` | **parité py↔dart** sinon divergence numérique |
| Producteur du statut | **onboarding wizard (contrat Flutter)** | sans producteur le champ est mort → wiring requis ; **hors périmètre mint-backend sans assignation lead** |
| Contrat API | `tools/openapi/mint.openapi.canonical.json` | regen si le statut traverse le sync |
| Rendu | écran /retraite (double scénario) | UX à dessiner |
| Non-régression | seed `retraite_lausanne`, snapshots `ProjectionResult.fromJson`, textes localisés (6 ARB), goldens Julien/Lauren | |
| Tests | actif · retraité annuitisé · retraité capital-retiré · statut inconnu · duplication LPP/fortune libre · parité py↔dart | |

### Décision PRODUIT requise (sign-off lead/Julien avant tout code)

Le traitement conservateur **change ce qu'un vrai retraité voit** : pour `retraite_lausanne`,
la ventilation /retraite passerait de « AVS 2'000 + LPP 1'802 ≈ 3'800 » à un double scénario
où le **socle de revenu confirmé n'inclut plus** la rente LPP tant qu'elle n'est pas confirmée. C'est une
amélioration d'honnêteté LSFin, mais un **choix produit** (risque de messagerie « ta retraite
paraît vide »), à trancher explicitement — pas une correction mécanique que l'agent backend
peut expédier seul. Le budget PRÉSENT de /home (net explicite 3'800, source distincte) n'est
pas affecté ; seule la ventilation projetée l'est.

## 5. Contre-arguments et angles morts (bias-check)

- **« Le seed a été validé, ne le casse pas. »** Le seed a été conçu (Lot B2 #1133) pour
  débloquer un /home non-vide ; sa ventilation /retraite était déjà signalée comme dégradée
  (AVS recalculée à 0 avant #1154). Le 1'802 est un **artefact de modélisation**, précisément
  le résiduel P1 signalé. Le changer relève de l'intention du mandat, pas d'une régression.
- **« Défaut = 0 est aussi un mensonge (sous-promesse) pour un retraité annuitisé. »** Vrai —
  d'où le **double scénario conditionnel** plutôt qu'un simple 0 : on montre les deux bornes,
  on n'engage le socle de revenu confirmé que sur la borne basse. La sous-estimation d'un socle
  confirmé est moins dommageable (LSFin) qu'une sur-promesse.
- **« Ajouter un champ mort viole Karpathy simplicité. »** Vrai si le champ n'a pas de
  producteur. D'où : le champ n'a de valeur qu'avec le wiring onboarding — ce qui confirme que
  le fix complet dépasse une unité backend bornée.
- **Angle mort double comptage data-entry** : si l'utilisateur saisit le même capital dans
  `avoirLppTotal` ET `epargneLiquide/investissements`, `RetirementProjectionService` produit
  rente LPP (avoir) + SWR (libre) = deux revenus d'un seul capital. Non traité ici (validation
  de saisie, hors périmètre), à ouvrir séparément.

## 6. Data gaps

- Pas de source produit sur la répartition réelle rente/capital des retraités MINT (aucun
  télémétrique) — l'hypothèse « inconnu = conservateur » est un choix de prudence, pas une
  distribution mesurée.
- `projectedRenteLpp` n'est jamais peuplé hors scan certificat : on ignore la couverture réelle
  de ce champ en base.
- Le rendu /retraite « double scénario » n'a pas de maquette ; l'UX reste à cadrer (panel
  design avant push écran, cf. doctrine).

## 7. Recommandation

1. **Ne pas** expédier de fix caveat-seul (insuffisant + casse `alertes.single`).
2. Porter cette page au lead pour **décision produit** (traitement conservateur + double
   scénario) et **assignation du wiring onboarding** (contrat Flutter).
3. Découper ensuite en unité GSD : (a) champ/état de statut + défaut conservateur dans les
   **deux moteurs Dart** + **miroir Python** avec parité ; (b) producteur onboarding + OpenAPI ;
   (c) rendu double scénario + non-régression seed/snapshots/goldens/ARB.

Le cas nominal cotisant reste intouché dans toutes les branches.
