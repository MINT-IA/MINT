# ADR-20260501 — Tax Phase 0 : Wedge "Dossier Fiscal Vivant" (plan d'exécution)

**Status**: Proposed
**Date**: 2026-04-15 (numérotation 20260501 = date prévisionnelle de kickoff post-Gate-0)
**Authors**: Julien + Claude + 4 experts consolidation (fiscaliste multi-canton, UX questionnaire, IDP stress-test, reminder scheduler)
**Scope**: plan d'exécution de la Phase 0 de la vision définie dans [ADR-20260415-tax-declaration-autopilot.md](ADR-20260415-tax-declaration-autopilot.md).
**Précondition (hard)**: Gate 0 résolu (auth, coach context, markdown, scanner). Cet ADR ne démarre pas tant que ces 4 issues persistent.

---

## 0. L'insight qui simplifie tout

**VSTax (et VDTax, GeTax, ZHprivateTax, etc.) font déjà les CALCULS fiscaux.** Les algorithmes cantonaux — barèmes, coefficient communal, déduction sociale fortune 30k/60k/+15k enfant, seuil 2% frais médicaux VS, quotient familial, progressivité — sont **dans le logiciel officiel**, maintenus par l'administration cantonale, à jour chaque année.

**Donc MINT ne recalcule PAS les impôts.** Ce n'est pas la valeur.

**La vraie valeur MINT** = livrer à VSTax (et à son équivalent autre canton) des **inputs propres, complets, exhaustifs**, sous forme d'**XML eCH-0119 v2.2** que l'utilisateur importe dans VSTax via "Fichier → Importer" (3 clics, 30 secondes), remplissant tous les champs d'un coup. Plus jamais de recopie manuelle des chiffres.

Les **PDF justificatifs** (pièces annexes obligatoires pour VSTax) restent uploadés séparément par l'utilisateur dans Tell Tax ou directement dans VSTax — c'est rapide (bulk upload 2 min) et ce n'est pas le pain point. Le pain point, c'est la **saisie des chiffres**, et c'est ça que l'XML élimine intégralement.

Cela simplifie massivement Phase 0 :
- Pas de moteur de calcul d'impôt complet.
- Pas d'exhaustivité sur barème par commune × année (VSTax fait ça).
- Focus ingestion + extraction + questionnaire + **génération XML eCH-0119 valide XSD**.
- Le moteur fiscal existant de MINT (`tax_calculator.dart`, `lpp_calculator.dart`, `arbitrage_engine.dart`) sert à :
  - Estimer les **fourchettes d'économie prospectives** des leviers N+1 ("verser 2'058 CHF sur ton 3a = baisse d'environ 10-15% ton impôt")
  - **Valider la cohérence** des chiffres extraits (sanity checks)
  - Jamais à calculer l'impôt final réel — VSTax le fait mieux.

**Conséquence marketing** : wording des leviers = **pourcentages indicatifs ou fourchettes larges**, pas de montant CHF précis. Ça désamorce le risque LCD art. 3 (publicité trompeuse). L'XML lui-même est neutre : il contient juste les chiffres inputs extraits, pas de claim marketing.

**Pourquoi l'XML eCH-0119 est Phase 0 et non Phase 1** (reprise d'un débat d'ADR précédent) :
- Le format eCH-0119 v2.2 est un **standard XML strict validé par XSD officiel** — s'il est bien formé, il ne peut pas être "faux" structurellement.
- Le risque juridique vient des **claims quantifiés dans l'UI** (ex. "tu économises 1'420 CHF"), pas du contenu de l'XML lui-même.
- Le risque d'extraction hallucinée (salaire brut 125k au lieu de 122k) existe **avec ou sans XML** — l'XML ne l'aggrave pas.
- Sans XML, MINT ne résout pas le vrai pain point (recopier 25 chiffres à la main) — il livre juste "Tell Tax qui lit mieux". **Insuffisant pour justifier le module.**

---

## 1. Périmètre Phase 0

### 1.1 Ce que Phase 0 fait

**A. Ingestion "drop-it-and-forget"**
- L'utilisateur partage un dossier entier (iOS Files / Android share sheet / email forward) ou drag-drop dans le chat coach
- Batch parallèle plafonné (Semaphore=5), UI type "Import Photos Apple"
- Thumbnails + états par doc (queued / reading / extracting / done / error)
- Résultats partiels toujours — un échec ne bloque pas le batch
- Swipe-to-cancel par doc + cancel global avec confirmation

**B. Extraction Claude Vision avec schéma Pydantic contraint**
- Modèle : **Claude Sonnet 4.5** (pas Opus — overkill) via pipeline backend Anthropic existant
- Schémas Pydantic par doc type (cert salaire, 3a, LPP, banque, médical)
- Cohérence arithmétique obligatoire (net = brut − déductions ± 50 CHF, taux AVS ∈ [4%-6.5%], year match)
- Retry automatique 1× avec prompt focalisé si validator échoue
- Coût réel estimé : **~0.18 CHF par user par saison** (moyen, 15 docs). Free tier génuinement gratuit.

**C. 13 leviers VS Phase 0, conditionnels par profil**

Base universelle salarié (8 leviers) :
1. Frais de transport voiture (LIFD art. 26 + LF-VS art. 23) — barème dégressif
2. Frais de transport TP (abonnement CFF / Mobilis)
3. Frais de repas extérieur midi (3'200 CHF/an max, LIFD art. 26 + OFrais 6)
4. Frais pro forfait 3% ou effectifs (plafond 4'000 IFD)
5. 3a bancaire salarié (plafond 7'258 CHF)
6. Frais médicaux non remboursés — **seuil 2% revenu net VS** (LF-VS art. 31 al. 1 let. h — à distinguer du 5% IFD)
7. Primes LAMal + LCA plafonnées (7'240 couple / 3'620 seul / 1'130 enfant — VS 2025)
8. Formation continue (plafond 12'550 VS, 12'900 IFD)

+ Conditionnel propriétaire (LE gros levier manqué dans mes versions précédentes) :
9. **Entretien immobilier effectif vs forfait 10%/20%** (LIFD art. 32 al. 4) — impact typique 3'000-15'000 CHF, révisable chaque année

+ Conditionnel avec enfants :
10. Enfants à charge (barème VS par âge : 7'860 / 8'940 / 11'930 CHF)
11. Frais de garde d'enfants (plafond VS ~3'000 / IFD 25'500 — divergence forte à surfacer)

+ Conditionnel couple marié :
12. Déduction couple marié double activité (6'290 CHF, LIFD art. 33 al. 2)

+ Universel :
13. Dons associations/partis reconnus (plafond VS 10% revenu net, IFD 20% ou 10'100 plafonné)

**Leviers NON inclus Phase 0** (déferrés Phase 1+ pour raisons fiscaliste/LSFin) :
- Rachat LPP volontaire (LSFin border + fenêtre 3 ans complexe) → Phase 1
- Pension alimentaire versée (cas sensible, UX à part) → Phase 1
- 3a indépendant sans LPP 20% (archétype indépendant = Phase 2)
- Rachat 3a rétroactif OPP3 art. 7a — **impossible pour déclaration 2025**, années éligibles ≥ 2025 rachetables en 2026+. Sera levier prospectif 2026 via rappels N+1.
- Frais handicap (pas de seuil, LIFD 33.1.hbis) → Phase 1
- Intérêts passifs sur dettes hors hypothèque → Phase 1
- Cotisations partis politiques (niche) → Phase 1

**D. Questionnaire conditionnel 6-13 questions**

Base 8 questions (toutes les utilisateurs) — strings finales voix MINT VS fournies par designer UX :
- Q1 Voiture pour aller bosser
- Q2 Abonnement TP domicile-travail
- Q3 Repas extérieur midi
- Q4 Matos et habits pro payés perso
- Q5 Formation continue payée perso
- Q6 Dons asso/parti/église
- Q7 Factures santé non remboursées (dentiste, lunettes, ostéo)
- Q8 Pension alimentaire versée (dernier, respect confiance)

Branches conditionnelles :
- +3 si propriétaire (entretien effectif vs forfait, investissements énergie, loyers perçus)
- +2 si retraité (retraits capital 2e/3a de l'année, 3e pilier B)
- +2 si expat/cadre international (jours hors CH, bonus/RSU/stock options)
- +1 si couple séparé/concubin parent (qui déduit l'enfant)
- +1 si permis B imposition ordinaire (revenu > 120k)

Durée médiane : 2 min 10 s (8 questions base). Pires cas avec branches : 3 min 30 s.

Pattern UX strict : tap-cards + CupertinoPicker pour nombres. **Aucun slider**. Aucun calcul mental demandé (MINT calcule km/an depuis pattern choisi).

Chaque réponse "non mais possible en N+1" → **génère automatiquement** un rappel N+1 avec texte pré-écrit.

**E. Récap structuré de revue (affichage pré-export)**

Page scrollable structurée comme les onglets VSTax :
- Revenus (salaires, rentes, allocations)
- Déductions (9-13 rubriques selon profil, avec source document référencée)
- Fortune au 31.12 (soldes bancaires, titres, 3a, LPP)
- Particularités (immobilier, pension alim, etc.)

Chaque ligne affiche : montant | source (doc ou réponse user) | confidence (vert/jaune/rouge + icône + label). Bouton permanent "Attends, ça c'est faux" ouvre le chat avec contexte pré-rempli.

Cette page sert à **valider les chiffres avant export XML**, pas à recopier manuellement. L'utilisateur passe au crible en 2-3 min puis lance l'export.

**E-bis. Export XML eCH-0119 v2.2 (le cœur de la valeur Phase 0)**

Après validation du récap, l'utilisateur exporte un fichier `declaration_2025.tax-mint.xml` conforme au standard fédéral **eCH-0119 v2.2** (version acceptée par VSTax 2024/2025).

Le fichier contient **tous les champs inputs** extraits/saisis :
- Identité + état civil + commune + archétype
- Revenus (salaire brut/net, cotisations AVS/AC/LPP/NAA, allocations, rentes si applicable)
- Fortune (soldes bancaires, titres, avoirs 3a/LPP)
- Déductions (3a versé, formation, frais médicaux, pro, transport, repas, dons, etc.)
- Charges immobilières si applicable

L'utilisateur ouvre VSTax → **Fichier → Importer** → sélectionne le XML → VSTax remplit tous les champs d'un coup. **Plus aucune recopie manuelle.** 30 secondes au lieu de 2 heures.

Tuto import intégré (vidéo 30s) + screenshots step-by-step dans l'app.

**Les PDF justificatifs** (pièces annexes exigées par VSTax/AFC) restent **uploadés séparément** par l'utilisateur :
- Option 1 — Tell Tax (app officielle VS, gratuite) : bulk upload depuis dossier iCloud/Files, 2 min
- Option 2 — Ajout manuel dans VSTax via `Justificatifs → Ajouter`

Ce n'est pas le pain point. Le pain point était la saisie des chiffres. L'XML le résout.

**Validation XSD** : l'XML est validé contre le schéma XSD officiel eCH-0119 côté backend avant retour à l'utilisateur. Si invalide, l'erreur est reportée avec ligne/champ concernés — pas de fichier silencieusement cassé.

**Signature d'intégrité** : `.tax-mint.xml` signé avec clé Ed25519 device (SHA-256 du contenu + timestamp). L'utilisateur peut vérifier côté VSTax avant import.

**F. Plan de rappels N+1 auto-généré**

Mode par défaut : **Light = 3 rappels/an**
- 30 juin : mi-année bundle
- 1er novembre : fenêtre versements 3a + opportunités optimisation
- 15 décembre : J-15 avant 31.12 (dernière chance 3a)

Upgrade en chat possible : Normal (8 rappels/an) ou Complet (15/an).

Calendrier 12 mois :
- Jan : récolte docs N-1
- Fév : saison déclaration → **zéro rappel année-courante** (sanctuaire)
- Mars : rituel gap-to-plan, génération plan N+1
- Avril : silence
- Mai : km voiture mi-course
- Juin : mi-année check
- Juillet-Août : silence estival
- Sept : rentrée (formation, garde)
- Oct : alerte 3a "plus que 3 mois"
- Nov : dernière fenêtre rachat LPP (Phase 1), dons fin d'année
- Déc : J-15, J-7, J-2 avant 31.12

Anti-spam mechanics (hard rules backend) :
- 1 push / semaine calendaire max
- Bundling par défaut (3 rappels même période = 1 seul push "3 trucs à checker")
- 12 push/an hard cap (mode Normal)
- Context skip auto (si 3a_ytd ≥ plafond → kill rappels 3a)
- Adaptive learning : 3 skips consécutifs sur un levier → coach demande "ce rappel te sert à rien ?" Si 5 skips → kill silencieux.

**G. Capture passive chat (année courante)**

User drop ticket/facture/cert dans le chat hors saison → MINT :
1. OCR + extraction type/montant/date/vendeur
2. Coach propose classification : "Ordi 1'450 CHF — ça part en frais pro 2026 ? Oui/Non/Privé"
3. Sur confirmation → Document Vault avec tags `fiscal_year`, `levier`, `montant`, `source=chat`
4. Compteur dashboard Fiscalité s'incrémente silencieusement
5. Mars N+1 → auto-pré-rempli dans dossier avec aperçu pièces

**H. Dashboard "Dossier N en cours" (Explorer → Fiscalité)**

Visible toute l'année. Maquette :
```
┌─────────────────────────────────────────────┐
│ Ton dossier fiscal 2026          [juin]     │
│ ─────────────────────────────────────────── │
│ Déductions sécurisées à date : 4'230 CHF    │
│ Estimation économie impôt : ~15% à 20%      │
│                                             │
│ Leviers actifs                              │
│  ● 3a          2'100 / 7'258   ██░░░░  29%  │
│  ● Km voiture  1'840 km notés  ████░░       │
│  ● Frais pro   3 pièces        ░░░ collecte │
│  ○ Rachat LPP  prévu novembre  — à venir    │
│  ○ Dons        —               — à venir    │
│                                             │
│ Prochain rappel : 30.06 — mi-année check    │
│                                             │
│ [+ Ajouter une pièce]  [Ajuster mon plan]   │
└─────────────────────────────────────────────┘
```

**I. Multi-contribuable (couple Julien+Lauren)**

Pre-onboarding Phase 0 : MINT demande **les NAVS13 hashés des 2 membres du couple**. Sans ça, attribution des docs impossible = récap faux pour 50% des utilisateurs mariés.

Extraction NAVS13 de chaque doc → hash → match contre ProfileModel. Mismatch → bottom sheet "Ce doc est au nom de quelqu'un d'autre. [Mon conjoint·e] [Ignorer] [Voir le doc]".

**J. Ring-fence coach AI (load-bearing, non-négociable)**

DENY_LIST hardcodée dans `context_injector_service.dart` + parallèle dans `claude_coach_service.py` + CI test bloquant. Détails §5.

### 1.2 Ce que Phase 0 NE fait PAS

- **Pas de recalcul d'impôt complet** (VSTax le fait, c'est sa valeur)
- Pas de PDF récapitulatif formel ni PDF rapport d'optimisation (Phase 1 — la version Phase 0 est une page écran)
- Pas de push direct serveur-serveur vers VSTax (Phase 1 — Phase 0 = user télécharge XML + import manuel)
- Pas d'intégration Tell Tax (Phase 1 — si partnership décidée)
- Pas d'upload automatique des PDF justificatifs vers VSTax ou Tell Tax (user gère les pièces lui-même, ce n'est pas le pain point)
- Pas de nouveaux écrans Flutter au-delà d'un onglet dans Explorer → Fiscalité + intégrations chat
- Pas de webapp séparée (Phase 2 si un jour)
- Pas de couple flow séparé (deux comptes MINT, vue partagée opt-in = Phase 1)
- Pas de multi-canton (VS uniquement — VDTax/GeTax/etc. = Phase 1-2)
- Pas de frontaliers permis G (exclu MVP, écran "couvert en Phase 2")
- Pas d'indépendants complexes (SA, Sàrl, comptabilité commerciale)
- Pas de FINMA pre-ruling (Phase 0 scope = éditeur logiciel pur, LSFin art. 3 al. 3 exception claire — XML livre juste des chiffres inputs, pas de conseil)
- Pas de DPIA externe (Phase 0 = extension de traitement existant, pas nouvelle finalité)
- Pas d'E&O uplift (Phase 0 sans claims quantifiés, policy MINT existante couvre)
- Pas de fiduciaire partnership (Phase 1)
- Pas d'auto-fetch cours fiscal titres via ICTax AFC (Phase 1)

---

## 2. Architecture technique Phase 0

### 2.1 Code existant réutilisé (80%)

- **`apps/mobile/lib/services/document_vault/`** — étendu avec DocType enum fiscal (salaire, 3a, LPP, bank, medical, autres)
- **`apps/mobile/lib/services/context_injector_service.dart`** — ajout DENY_LIST fiscale
- **`apps/mobile/lib/services/coach/`** — pipeline chat existant
- **`apps/mobile/lib/services/regional_voice_service.dart`** — extension scope fiscal VS
- **`lib/services/financial_core/tax_calculator.dart`** — uniquement pour estimer fourchettes % leviers (pas calcul impôt complet)
- **`lib/services/financial_core/lpp_calculator.dart`** — réutilisé à l'identique
- **`lib/services/financial_core/confidence_scorer.dart`** — étendu avec calibration par champ
- **`services/backend/app/services/claude_coach_service.py`** — pipeline vision existant
- **`lib/l10n/app_*.arb`** — ~30 nouvelles clés pour fiscalité

### 2.2 Nouveaux modules (~1'700 LOC total)

**Backend (Python)** :
- `services/backend/app/services/tax/fiscal_document_extractor.py` (~400 LOC) — orchestre Claude Vision + validation Pydantic + retry
- `services/backend/app/schemas/tax/` (~250 LOC) — schémas Pydantic par doc type avec validators
- `services/backend/app/services/tax/fiscal_insights_service.py` (~200 LOC) — orchestre 13 règles leviers
- `services/backend/app/services/tax/fiscal_coach_firewall.py` (~100 LOC) — DENY_LIST enforcement
- `services/backend/app/services/tax/reminder_scheduler.py` (~200 LOC) — plan N+1 + kill conditions
- `services/backend/app/services/tax/ech0119_xml_builder.py` (~300 LOC) — génération XML eCH-0119 v2.2 depuis FiscalSnapshot, utilise lxml, validation XSD bloquante, signature Ed25519
- `services/backend/app/services/tax/ech0119_xsd/` (~10 KB) — schémas XSD officiels eCH-0119 v2.2 (téléchargés depuis ech.ch, vendored + test CI qu'ils matchent le checksum officiel chaque semaine)

**Mobile (Dart)** :
- `apps/mobile/lib/screens/fiscalite/dossier_vivant_screen.dart` (~300 LOC) — dashboard
- `apps/mobile/lib/screens/fiscalite/ritual_questionnaire_screen.dart` (~250 LOC) — 8 questions + branches
- `apps/mobile/lib/screens/fiscalite/recap_review_screen.dart` (~200 LOC) — page revue avant export XML
- `apps/mobile/lib/screens/fiscalite/xml_export_screen.dart` (~150 LOC) — écran export + tuto import VSTax 30s + bouton partager/télécharger
- `apps/mobile/lib/services/tax/bulk_ingest_service.dart` (~150 LOC) — Semaphore batch + progress
- `apps/mobile/lib/services/tax/tax_session_state.dart` (~100 LOC) — persistence reprise

**Tests (~500 LOC)** :
- 15 tests leviers (3 cas par levier × 13 leviers, priorité sur les 8 base)
- Golden tests Julien+Lauren (extension du golden existant) — vérif XML produit ré-importable dans VSTax réel
- CI gate DENY_LIST (unit test qui énumère tous les contextes coach possibles)
- Tests failure modes ingestion (password-protected, year mismatch, NAVS13 mismatch, validator arithmétique)
- **Tests XSD roundtrip** — XML généré passe le XSD officiel eCH-0119 v2.2 pour 5 profils synthétiques (jeune célibataire VS, retraité VS, indépendant VS, propriétaire VS, couple Julien+Lauren)
- **Test import VSTax réel** — procédure manuelle (docs) : générer XML depuis Julien+Lauren → ouvrir VSTax 2025 → importer → vérifier que tous les champs sont bien remplis. À faire avant beta.

### 2.3 Pydantic schéma cert salaire (exemple représentatif)

```python
class CertificatSalaire(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    employeur_hash: str  # SHA-256 salé, jamais en clair
    navs13_hash: str  # pour attribution contribuable
    periode_debut: date
    periode_fin: date
    canton_imposition: str

    salaire_brut: Decimal
    avs_ai_apg: Decimal
    ac: Decimal
    lpp_salarie: Decimal
    naa_ijm: Decimal
    impot_source: Optional[Decimal] = None

    allocations_familiales: Decimal = Decimal(0)
    frais_effectifs: Decimal = Decimal(0)
    prestations_nature: Decimal = Decimal(0)

    salaire_net: Decimal

    confidence_per_field: dict[str, float]
    source_pages: list[int]

    @field_validator("avs_ai_apg")
    def avs_rate_plausible(cls, v, info):
        brut = info.data.get("salaire_brut", 0)
        if brut and not (0.04 <= v/brut <= 0.065):
            raise ValueError(f"Taux AVS hors plage [4-6.5%]")
        return v

    @model_validator(mode="after")
    def net_coherent(self):
        deductions = self.avs_ai_apg + self.ac + self.lpp_salarie + self.naa_ijm + (self.impot_source or 0)
        expected = self.salaire_brut - deductions + self.allocations_familiales
        if abs(expected - self.salaire_net) > Decimal("50"):
            raise ValueError(f"Net incohérent : {expected} vs {self.salaire_net}")
        return self
```

### 2.4 Gestion des 4 failure modes bloquants

| # | Scénario | Gestion |
|---|----------|---------|
| 1 | PDF password-protected (UBS/PostFinance ~20%) | `pikepdf.is_encrypted` → UI "ouvre-le, imprime-le en PDF non-protégé, réupload". Jamais demander password. |
| 2 | NAVS13 mismatch (doc au nom autre) | Bottom sheet "ce doc est au nom de [initiale+année]. Mon conjoint·e / Ignorer / Voir le doc" |
| 3 | Year mismatch (cert 2024 pour décla 2025) | Warning bloquant (peut déclarer tardivement mais user doit confirmer) |
| 4 | Validator arithmétique échoue (net ≠ brut-déductions) | Re-run Claude focalisé sur 3 champs. Si échec 2× → demander user pour ces 3 champs uniquement. |

---

## 3. Plan de sprint (5 sprints post-Gate-0)

**Sprint S57 Foundation (3 semaines)**
- DocType enum extension + Document Vault fiscal
- Pipeline extraction Claude Vision + schémas Pydantic + validators + retry
- DENY_LIST ring-fence dans context_injector + claude_coach_service + CI gate
- Golden tests Julien+Lauren (extension existant)
- Pré-onboarding couple (NAVS13 hashés)

**Sprint S58 Ingestion + Questionnaire (3 semaines)**
- Bulk ingest mobile (share sheet iOS/Android)
- Batch parallèle Semaphore=5 + progress UI Photos-Apple-style
- Questionnaire 8 questions base + branches conditionnelles
- Strings finales voix MINT VS (ARB 6 langues)
- Failure modes handling (4 modes §2.4)

**Sprint S59 Leviers + Récap (2 semaines)**
- 8 règles leviers base + 5 conditionnelles
- Calcul fourchettes prospectif N+1 (pas impôt réel — VSTax s'en occupe)
- Récap structuré VSTax-style avec sources documentées
- Rétrospectif/prospectif split strict (N-1 éducatif, N+1 actionnable deadline)

**Sprint S60 Export XML eCH-0119 (2 semaines — le cœur de la valeur)**
- Vendoring des schémas XSD officiels eCH-0119 v2.2 + CI qui checksum vs source officielle
- `ech0119_xml_builder.py` : mapping `FiscalSnapshot` → XML valide XSD pour profil VS
- Signature Ed25519 du fichier exporté (intégrité)
- Écran export mobile : bouton "Télécharger mon XML pour VSTax" + tuto import vidéo 30s
- 5 profils synthétiques de régression (célibataire jeune VS, retraité VS, indépendant VS, propriétaire VS, couple Julien+Lauren) — chacun doit produire un XML qui passe XSD
- **Test d'import VSTax 2025 réel** avec le XML de Julien+Lauren (procédure manuelle documentée)
- Si VSTax rejette un XML valide XSD → debug quirk VSTax, ajuster le builder, re-tester

**Sprint S61 Rappels + Capture passive (2 semaines)**
- Reminder scheduler (mode Light 3 rappels/an, Normal 8, Complet 15)
- Anti-spam mechanics (1 push/semaine max, bundling, kill conditions)
- Capture passive chat + classification + Document Vault tagging
- Dashboard "Dossier N en cours" (Explorer → Fiscalité)
- Feature flag `tax_insights_enabled` off par défaut (opt-in beta)

**Total : 12 semaines** (vs 8 mois v2, 6 mois v1). Realistic pour solo + agents post-Gate-0. Le sprint XML (S60) est le sprint le plus critique parce que c'est lui qui livre la vraie valeur Phase 0. Si l'XML ne s'importe pas proprement dans VSTax, Phase 0 échoue — donc test import réel obligatoire avant déclarer S60 done.

---

## 4. Critères de succès Phase 0 (triggers Phase 1 ADR)

À M+3 post-launch beta, **tous** doivent être verts pour drafter Phase 1 :

| Critère | Seuil | Mesure |
|---------|-------|--------|
| Utilisateurs beta ayant exporté leur XML eCH-0119 | ≥ 50 | Analytics `fiscal_xml_exported` |
| Utilisateurs ayant confirmé "XML importé dans VSTax avec succès" | ≥ 70% des exports | Follow-up chat 48h post-export |
| Taux "je vais faire" sur au moins 1 levier prospectif | ≥ 30% | Self-report dans questionnaire post-récap |
| Fuites DENY_LIST en prod | = 0 | Sentry alert |
| Incidents LSFin ou PFPDT | = 0 | Registre interne |
| NPS expérience Phase 0 | ≥ 40 | Survey post-récap |
| Taux échec XSD validation XML | < 2% | Analytics backend |
| Fiduciaire VS partenaire signé (LOI) | ≥ 1 | Contractuel |

Si 1 critère échoue à M+3 → ajuster Phase 0 (Normal mode si churn, par ex) ou killer avant Phase 1. Pas de compound des pertes.

---

## 5. Compliance Phase 0 (allégée vs Phase 1+)

Phase 0 est **éditeur logiciel pur, sans output quantifié chiffré ni recommandation** :
- Récap = calculs de la loi avec sources (LIFD art. X) — pas de recommandation
- Leviers prospectifs = pourcentages indicatifs ou fourchettes larges ("jusqu'à 15%"), jamais chiffres CHF précis
- Zéro produit nommé, zéro ranking
- Disclaimer éducation explicite sur chaque écran

**Donc Phase 0 NE DÉCLENCHE PAS** :
- FINMA pre-ruling (pas quantified advice)
- DPIA externe (extension traitement existant)
- E&O uplift (pas de claim chiffré)

**Mais Phase 0 DOIT RESPECTER** (hardcoded) :
- DENY_LIST coach AI sur tout champ fiscal (§5.1 vision ADR)
- Document Vault existant (device-local chiffré)
- Consentement explicite au premier flow fiscal
- LCD-safe marketing : pas de "12 minutes", pas de "économise X CHF", pas de "73% connu"
- US person hard stop clair (résident CH US célibataire ou marié à non-Suisse) — écran "MINT ne couvre pas ton cas, consulte un·e US tax preparer"

**Cas Julien+Lauren** : Lauren mariée à Julien (Suisse) → déclaration commune couple marié Suisse = **hors hard stop**. MINT fonctionne normalement pour eux. Le hard stop ne concerne que les US residents CH non-mariés-à-Suisse (cas rare).

---

## 6. Risques Phase 0 + mitigations

| Risque | Prob | Impact | Mitigation |
|--------|------|--------|------------|
| Attribution couple (NAVS13 mismatch) | High | Récap faux = confiance perdue | Pre-onboarding NAVS13 hashés non-skippable pour mode couple |
| Hallucination Claude sur amounts | Med | User recopie faux chiffres dans VSTax | Validator Pydantic bloquant + retry focalisé + 2× extraction T=0/T=0.3 pour champs critiques |
| Ingestion plante sur password-protected | High (20% cas) | UX cassée | Détection `pikepdf` + message explicite pré-MVP |
| Coach AI fuit champ fiscal | Med | nLPD violation + perte confiance | CI gate bloquant + Sentry alert runtime + audit log |
| VSTax rejette notre XML eCH-0119 | Med | Valeur Phase 0 = 0 si import échoue | Test import VSTax réel avant fin S60 (procédure manuelle documentée). Si quirks VSTax non-XSD, ajuster builder. Fallback : afficher récap + tuto recopie manuelle (mode dégradé). |
| Schéma eCH-0119 v2.2 évolue en v3.0 | Low | XML v2.2 rejeté année N+1 | Monitorer ech.ch trimestriellement. VSTax 2026/2027 acceptera probablement v2.2 + v3.0 en transition. Builder a un switch version. |
| Certificat salaire parsé a un champ manquant → XML incomplet | Med | VSTax refuse import ou remplit partiellement | XSD validation bloquante + "champs obligatoires manquants" signalés au user AVANT export, pas après. |
| Churn sur rappels trop fréquents | Med | Disable notifs = feature morte | Mode Light par défaut (3/an) + kill conditions agressives + adaptive learning |
| Tell Tax s'améliore et nous rattrape | Low-Med | Différenciation érodée | Monitorer releases Tell Tax trimestriellement. Moat MINT = coaching + rappels, pas OCR pur. |
| Gate 0 pas résolu → démarrage retardé | High | Calendar slip | Phase 0 **attend explicitement** Gate 0 — pas de start en parallèle |

---

## 7. Budget et ressources

**Temps** : 12 semaines solo + agents Claude Code (post-Gate-0). Le +2 sem vs version antérieure vient du sprint S60 dédié à l'export XML eCH-0119 v2.2 (builder + vendoring XSD + test import VSTax réel).

**Coûts opérationnels** :
- Claude Sonnet 4.5 Vision : ~0.18 CHF / user / saison (moyen), ~0.45 CHF P90
- Hosting : existant (Railway backend + Flutter app)
- Anthropic DPA zero-retention tier : à vérifier disponibilité, sinon migration vers Mistral Swiss en Phase 1
- Total marginal : **< 0.50 CHF / user / saison** — free tier génuinement gratuit à toute échelle

**Pas de coûts pré-launch** Phase 0 :
- Zéro legal counsel (éditeur logiciel, pas advice)
- Zéro E&O uplift (policy existante)
- Zéro audit externe (Compass Security seulement avant Phase 1)
- Zéro DPIA externe (extension traitement existant)

**Hire trigger** : à M+3 si ≥ 500 utilisateurs actifs + traction → raise pre-seed CHF 300-500k, hire 1 full-stack Flutter/Python. Pas avant.

---

## 8. Décisions unresolved (à confirmer par founder)

- [ ] Mode par défaut rappels : **Light (3/an)** recommandé ou Normal (8/an) ?
- [ ] Nom du produit dans l'app : **"Fiscalité"** (actuel hub Explorer) ou "Dossier fiscal" ou autre ?
- [ ] Seuils Phase 0 → Phase 1 (§4) : OK ou ajustement ?
- [ ] Acceptation explicite de la précondition Gate 0 (Phase 0 ne démarre QUE si coach réparé) ?

Par défaut : oui à tout. Si désaccord, noter avant kickoff S57.

---

## 9. Références

- [ADR-20260415-tax-declaration-autopilot.md](ADR-20260415-tax-declaration-autopilot.md) — vision cible (cet ADR l'implémente en Phase 0)
- [ADR-20260415-tax-declaration-autopilot-REVIEW.md](ADR-20260415-tax-declaration-autopilot-REVIEW.md) — 6 reviewers adversariaux v1
- `~/.gstack/projects/MINT-IA-MINT/ceo-plans/2026-04-15-tax-autopilot-scope-reduction.md` — CEO plan (23 décisions scope)
- Audits experts 2026-04-15 consolidation (4 agents) :
  - Fiscaliste multi-canton : confirmation 13 leviers, corrections 3 erreurs, branches conditionnelles
  - UX questionnaire : version finale 8 questions + rappels N+1 pré-rédigés
  - IDP/LLM stress-test : 10 failure modes, schéma Pydantic, Claude Sonnet 4.5, budget coût
  - Reminder scheduler : calendrier 12 mois, 3 modes, dashboard maquette
- [Mode d'emploi VSTax 2025 officiel](https://geo.vs.ch/documents/d/ext-cant-gouv-scc-vstax/guide_vstax_25_fr)
- [Les 17 déductions fiscales VS 2025 — FBK](https://fbk-conseils.ch/en/tax-deduction-in-valais/)
- [Tell Tax VS — page officielle](https://www.vs.ch/en/web/ext-cant-gouv-scc-vstax/tell-tax-app)
- CLAUDE.md §2, §5, §6, §7
- docs/MINT_IDENTITY.md

---

**Fin ADR Phase 0 — prêt à exécuter post-Gate-0.**
