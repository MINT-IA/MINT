# ADR-20260415 — Tax Declaration Autopilot (Module Fiscal MINT)

**Status**: Proposed
**Date**: 2026-04-15
**Authors**: Julien + Claude (panel d'experts — voir §0)
**Scope**: Nouveau module produit "Préparer ma déclaration" — Phase 1 canton VS, extension multi-cantons en Phase 2
**Lifecycle event**: `taxDeclaration` (à ajouter aux 18 life events si on le promeut, sinon "moment récurrent annuel" transversal à tous les archétypes)

---

## 0. Panel d'experts mobilisé (méthode d'élaboration)

Cet ADR a été itéré contradictoirement entre six rôles, chacun avec un droit de veto sur sa zone. Les arbitrages sont tracés en §4 (Alternatives).

| Rôle | Mission dans l'ADR | Veto |
|------|--------------------|------|
| **Fiscaliste VS** (Brevet fédéral, ex-AFC) | Couverture des rubriques, exactitude juridique des barèmes et déductions VS | Si une déduction est manquante ou mal mappée |
| **Ingénieur OCR/IDP** | Faisabilité d'extraction document par document, taux d'erreur acceptable | Si extraction < 92% champs critiques |
| **Designer UX MINT** | Le module respecte la doctrine "ultra simple, calme, intime" et tient sur 5 écrans max | Si l'utilisateur doit comprendre une notion fiscale pour avancer |
| **Juriste LSFin / nLPD** | Pas de conseil fiscal personnalisé sans réserve, gestion des données sensibles, assurance E&O | Si le wording franchit la ligne du conseil réglementé |
| **Product Lead** | ROI utilisateur, intégration dans la roadmap V2, métriques de succès | Si la feature ne fait pas gagner ≥ 3h à l'utilisateur |
| **Sécurité / Privacy** | Stockage chiffré bout-en-bout, minimisation, droit à l'oubli annuel | Si des données identifiables fuient hors du device sans nécessité |

**Méthode** : 3 itérations (proposition → contre-arguments → synthèse). Chaque itération a réduit le scope MVP et augmenté la valeur perçue. Le résultat ci-dessous est le consensus.

---

## 1. Contexte

### 1.1 Le besoin utilisateur (story réelle, golden couple Julien+Lauren)

Chaque année, ~3.5 millions de contribuables suisses passent **8 à 25 heures** à compiler leur déclaration fiscale. Le canton du Valais (VS) impose l'usage du logiciel **VSTax** (extension `.vstax24` pour l'année fiscale 2024, `.vstax25` pour 2025…), un format **propriétaire chiffré** (signature `JFW_1.0`, basé sur le moteur JAXForm de la société Information Factory). Le contribuable doit re-saisir manuellement :

- Salaires (certificat employeur)
- Cotisations 3a (attestation banque/assurance)
- Avoirs LPP, rachats, retraits EPL
- Soldes bancaires au 31.12 + intérêts bruts
- Métaux précieux, titres, fonds
- Frais médicaux, dons, frais de formation, frais de garde
- Charges immobilières (intérêts, valeur locative, entretien)
- Pensions alimentaires, frais de déplacement, frais de repas
- Rentes AVS/AI/LPP perçues

**Ce que MINT a déjà** sur l'utilisateur (profil + Document Vault — cf. ADR-20260217) :
- Archétype, état civil, canton, communes, enfants, conjoint
- Salaires bruts (saisis ou OCR certificat), 3a, LPP avoir + rachats, EPL
- Calculateurs prêts : `tax_calculator`, `arbitrage_engine`, `confidence_scorer`
- Historique multi-années (snapshot annuel)

**Le constat** : MINT possède 60–70% des champs requis. L'utilisateur, lui, a juste à uploader 5–10 PDF qu'il a déjà reçus par la poste ou par e-banking entre janvier et mars.

### 1.2 La contrainte technique (verdict honnête)

Le format `.vstax24` est **chiffré et fermé** (clé interne au logiciel VSTax, susceptible de varier d'une année fiscale à l'autre). Reverse-engineer la clé :

- est techniquement possible mais **fragile** (peut casser à chaque version annuelle),
- est **juridiquement risqué** (CGU VSTax + art. 144bis CP — accès indu à un système informatique pourrait être invoqué selon l'interprétation),
- expose MINT à une **dette de maintenance** insoutenable (6 cantons romands × 1 format chacun = 6 reverse-engineerings annuels).

**Veto Sécurité + Juriste : on ne touche pas au binaire `.vstax24`.**

### 1.3 Le chemin officiel et standard

La Confédération a publié les standards **eCH-0119** (déclaration fiscale personne physique) et **eCH-0196** (échange électronique avec administrations fiscales). VSTax — comme la majorité des logiciels cantonaux — accepte un **import XML** conforme à ces schémas via le menu *Fichier → Importer*. Une fois importé, VSTax produit lui-même le `.vstax24` validable et soumissible à l'AFC valaisanne.

C'est la voie utilisée par **Dr.Tax**, **Taxme**, **Tax Warrior**, **MilleniumTax** et tous les comptables professionnels.

**Décision implicite** : MINT générera un **`.tax-mint.xml` (eCH-0119)** importable + un **PDF récapitulatif human-readable** + un **rapport d'optimisation** (la vraie valeur MINT).

---

## 2. Décision

### 2.1 Vision du module — "Tax Autopilot"

> **Promesse utilisateur (one-liner)** : "Dépose tes 5 documents. MINT prépare ta déclaration. En 12 minutes, tu sais où tu en es, ce que tu peux encore optimiser, et tu reçois un fichier prêt à importer dans VSTax."

**Trois livrables** à la fin du parcours :

1. **`declaration_2025.tax-mint.xml`** — fichier eCH-0119 importable directement dans VSTax (ou Dr.Tax, ou GeTax, ou Taxme selon canton).
2. **`declaration_2025_recapitulatif.pdf`** — récap humain de toutes les rubriques, signable, archivable.
3. **`mon_rapport_optimisation_2025.pdf`** — le **vrai différenciateur MINT** : 5 à 10 angles d'optimisation **personnalisés et chiffrés** ("Si tu avais versé 7'258 CHF en 3a en décembre 2025 au lieu de 4'200, tu aurais économisé environ 1'420 CHF d'impôt fédéral + cantonal — voici comment t'organiser pour 2026").

### 2.2 Parcours utilisateur (5 écrans, doctrine "ultra simple")

> **Veto UX activé** : si on dépasse 5 écrans avant le résultat, on coupe. La complexité fiscale est une charge cognitive de l'État, pas de l'utilisateur.

```
Écran 1 — Accueil "Préparer ma déclaration 2025"
   ├─ Visuel calme : un dossier qui se remplit
   ├─ Promesse : "12 minutes. Je m'occupe du reste."
   ├─ État : "MINT connaît déjà 73% de ta situation."
   └─ CTA : [ Commencer ]

Écran 2 — Dépose tes documents
   ├─ Drop zone unique (drag&drop ou photo iPhone)
   ├─ MINT classe automatiquement : Salaire, 3a, LPP, Banque, Médical, Autre
   ├─ Liste de ce qu'il MANQUE (intelligente, basée sur ton profil) :
   │     • "Tu as une assurance vie chez Helvetia → l'attestation 3b ?"
   │     • "Tu es propriétaire à Sion → ton dernier décompte de charges PPE ?"
   │     • "Lauren a un certificat de salaire 2025 ?" ✓ trouvé dans le vault
   └─ CTA : [ Tout est là ] / [ Je terminerai plus tard ]

Écran 3 — Vérifie en 60 secondes
   ├─ 1 seul écran scrollable, gros chiffres, inline-edit
   ├─ Section "Revenus du couple" → 2 lignes, 1 chiffre par ligne
   ├─ Section "Patrimoine au 31.12.2025" → 1 chiffre fortune nette
   ├─ Section "Tes déductions" → 8 lignes max, déjà cochées+remplies
   ├─ Confidence Score MINT visible (78% → "très fiable")
   └─ CTA : [ Tout est juste ] / [ Corriger un point ]

Écran 4 — Le moment "wow" : ton optimisation
   ├─ "Tu vas payer environ 24'380 CHF d'impôt 2025."
   ├─ "J'ai trouvé 4 leviers pour 2026 qui te feraient économiser ~3'920 CHF."
   ├─ Cards déroulables (1 par levier) :
   │     1. Pilier 3a complet (gap : 2'058 CHF) → -640 CHF
   │     2. Rachat LPP (capacité : 12'000 CHF) → -2'180 CHF
   │     3. Frais formation continue oubliés → -340 CHF
   │     4. Don déductible (gap caritatif) → -760 CHF
   ├─ Chaque card : pourquoi, comment, pour quand, source légale (LIFD art. X)
   └─ CTA : [ Voir ma déclaration ] [ Planifier ces actions ]

Écran 5 — Tes 3 fichiers sont prêts
   ├─ "Voilà tes trois documents. Tout est sur ton appareil, rien chez nous."
   ├─ [ Télécharger pour VSTax ] (.tax-mint.xml)
   ├─ [ Télécharger le récapitulatif ] (.pdf)
   ├─ [ Télécharger ton plan d'optimisation 2026 ] (.pdf)
   ├─ Mode d'emploi "import dans VSTax" — 3 captures d'écran, 30 secondes
   └─ CTA : [ Garder dans mon Vault MINT ] (chiffré, retrouvable l'an prochain)
```

### 2.3 Architecture technique

#### Backend (`services/backend/`)

```
app/services/tax/
  ├─ tax_declaration_service.py     # Orchestrateur
  ├─ document_ingestion/
  │    ├─ classifier.py              # Classifie un PDF (salaire/3a/LPP/banque/médical/...)
  │    ├─ extractors/
  │    │     ├─ certificat_salaire.py    # Extrait champs ELM 5.0 (norme suisse)
  │    │     ├─ attestation_3a.py
  │    │     ├─ certificat_lpp.py
  │    │     ├─ releve_bancaire.py
  │    │     ├─ frais_medicaux.py
  │    │     └─ generic_pdf.py
  │    └─ confidence.py              # Score confiance par champ extrait
  ├─ rubriques/
  │    ├─ revenus.py                 # Salaires, rentes, indépendant, accessoires
  │    ├─ fortune.py                 # Bancaire, titres, métaux, immo, véhicules
  │    ├─ deductions.py              # 3a, LPP, médical, formation, dons, garde
  │    ├─ immobilier.py              # Valeur locative, intérêts, entretien
  │    └─ couple.py                  # Splitting, charges famille, garde alternée
  ├─ canton/
  │    ├─ base.py                    # Interface CantonRules
  │    ├─ vs.py                      # Valais (MVP)
  │    ├─ vd.py                      # Vaud (Phase 2)
  │    ├─ ge.py / ne.py / fr.py / ju.py
  │    └─ zh.py / be.py / ti.py      # Phase 3
  ├─ exporters/
  │    ├─ ech0119_xml.py             # Export XML standard fédéral
  │    ├─ pdf_recapitulatif.py       # PDF lisible
  │    └─ optimization_report.py     # Rapport d'optimisation
  ├─ optimizer/
  │    ├─ engine.py                  # Détecte et chiffre les leviers
  │    ├─ rules/
  │    │     ├─ pillar3a_gap.py
  │    │     ├─ lpp_buyback_capacity.py
  │    │     ├─ formation_continue.py
  │    │     ├─ medical_threshold.py        # 5% revenu net (LIFD art. 33)
  │    │     ├─ dons_charitable_cap.py      # 20% revenu net
  │    │     ├─ frais_garde.py
  │    │     ├─ rente_vs_capital_2eme_pilier.py
  │    │     ├─ dechelonnement_3a.py        # multi-comptes 3a, retraits étalés
  │    │     ├─ valeur_locative_entretien.py
  │    │     └─ split_concubinage_vs_marriage.py
  │    └─ projection.py              # Avant/après chiffré + source légale
  └─ schemas/
       ├─ tax_declaration.py         # Pydantic v2 (camelCase alias)
       ├─ document_extraction.py
       └─ optimization_levers.py

app/api/v1/endpoints/tax.py
  POST   /tax/sessions                        # Crée une session déclaration N
  POST   /tax/sessions/{id}/documents         # Upload + classification
  GET    /tax/sessions/{id}/missing           # Liste intelligente du manquant
  PATCH  /tax/sessions/{id}/rubriques/{r}     # Edit inline d'une rubrique
  GET    /tax/sessions/{id}/preview           # Récap + impôt estimé + confidence
  GET    /tax/sessions/{id}/optimization      # Leviers chiffrés
  POST   /tax/sessions/{id}/export            # → xml + pdf + rapport
  DELETE /tax/sessions/{id}                   # Droit à l'oubli (immédiat)
```

#### Mobile (`apps/mobile/`)

```
lib/screens/tax/
  ├─ tax_home_screen.dart           # Écran 1
  ├─ tax_upload_screen.dart         # Écran 2 (drop zone + missing list)
  ├─ tax_review_screen.dart         # Écran 3 (vérif 60s)
  ├─ tax_optimization_screen.dart   # Écran 4 (le moment wow)
  └─ tax_export_screen.dart         # Écran 5 (3 fichiers)

lib/services/tax/
  ├─ tax_session_provider.dart
  ├─ tax_document_uploader.dart
  └─ tax_optimization_consumer.dart

lib/widgets/tax/
  ├─ document_drop_zone.dart
  ├─ missing_documents_list.dart
  ├─ rubrique_inline_editor.dart
  ├─ optimization_lever_card.dart
  └─ export_files_panel.dart
```

Intégration **Explorer → Fiscalité** (hub existant) + **bandeau Aujourd'hui** entre janvier et avril chaque année.

### 2.4 Doctrine MINT respectée

| Principe | Application dans le module |
|----------|----------------------------|
| Read-only | MINT ne soumet **jamais** la déclaration. L'utilisateur importe le XML dans VSTax et clique "Envoyer" lui-même. |
| No-Advice | Les leviers d'optimisation sont présentés comme **scénarios chiffrés avec source légale**, jamais comme "tu dois faire X". Toujours conditionnel ("envisager", "pourrait"). |
| No-Promise | "Économie estimée ~1'420 CHF (fourchette 1'200–1'650, dépend du barème commune)". |
| No-Ranking | Leviers triés par **gain estimé décroissant** (factuel), pas "le meilleur levier". |
| No-Social-Comparison | Jamais "tu paies plus que la moyenne". Toujours "voici ton chiffre, voici la marge personnelle". |
| Premier éclairage | Écran 4 EST le premier éclairage fiscal — chiffré, sourcé, actionnable. |
| Confidence Score | Visible sur chaque rubrique + score global déclaration. |
| Privacy | Documents **stockés chiffrés sur device** (Document Vault, ADR-20260217). Aucune donnée brute n'est envoyée au backend MINT — seuls des **agrégats normalisés** + champs anonymisés transitent pour les calculs serveur. Cf. §6. |
| Voix régionale | Wording VS : "ton décompte d'AVS", références grottes/Cervin pour le ton, jamais caricatural. |

---

## 3. Roadmap d'exécution (4 sprints)

> Aligné sur la roadmap V2 (cf. CLAUDE.md §11). Méthode : **autoresearch skills** (`/autoresearch-calculator-forge`, `/autoresearch-test-generation`, `/autoresearch-compliance-hardener`, `/autoresearch-ux-polish`).

### Sprint S57 — "Foundation Tax" (2 semaines)
**Goal** : Backend + parsers PDF prioritaires + canton VS rules.
- [ ] Schémas Pydantic `TaxDeclaration`, `DocumentExtraction`, `OptimizationLever`
- [ ] Parser certificat de salaire suisse (norme **ELM 5.0** — XML standardisé déjà obligatoire pour les employeurs depuis 2024 ; fallback OCR si PDF scanné)
- [ ] Parser attestation 3a (banques + assurances, formats hétérogènes → OCR + heuristiques)
- [ ] Parser certificat LPP (formats CPE, HOTELA, AXA, Swiss Life, Bâloise, Helvetia, Vaudoise)
- [ ] Parser relevé bancaire E-finance / UBS / Raiffeisen / BCV / BCVs (solde 31.12 + intérêts bruts)
- [ ] `CantonRules` interface + implémentation **VS** (barème 2025, déductions sociales, valeur locative)
- [ ] `tax_calculator` étendu : impôt fédéral direct + cantonal VS + communal Sion (coefficient 100%)
- [ ] **20 tests unitaires minimum** par parser (golden PDF anonymisés en `test/golden/tax/`)
- [ ] Test E2E sur le couple Julien+Lauren : reproduire le `.vstax24` existant en agrégats normalisés

### Sprint S58 — "Optimization Engine" (2 semaines)
**Goal** : Le différenciateur MINT — leviers d'optimisation chiffrés.
- [ ] `optimizer/engine.py` orchestre 10 règles en parallèle
- [ ] Règle 3a gap : compare versement effectué vs plafond (7'258 salarié / 36'288 indép.)
- [ ] Règle rachat LPP : exploite `lpp_calculator.computeBuybackCapacity()` existant
- [ ] Règle frais médicaux : seuil 5% revenu net (LIFD art. 33), liste complète des frais éligibles VS
- [ ] Règle dons : cap 20% revenu net, organisations reconnues
- [ ] Règle formation continue : plafond 12'000 CHF (LIFD art. 33 al. 1 let. j)
- [ ] Règle frais garde : 25'500 CHF/enfant (fédéral) + barème VS
- [ ] Règle valeur locative + entretien immobilier : forfait vs effectif (le plus avantageux)
- [ ] Règle déchelonnement 3a : multi-comptes pour étaler retraits → tax savings au retrait (LIFD art. 38 progressif)
- [ ] Règle rente vs capital LPP : préfigure le moment retraite (lien vers `arbitrage_engine`)
- [ ] Règle splitting concubinage vs mariage : si applicable (event `marriage` ou `concubinage`)
- [ ] **Chaque levier** = `{lever_id, label, gain_estimate_chf, gain_range, legal_source, action_steps[], deadline, confidence}`

### Sprint S59 — "Export & Import Path" (1 semaine)
**Goal** : Les 3 livrables téléchargeables.
- [ ] Exporter eCH-0119 v3.0 (schéma XSD officiel) — couvre 90% des cas VS
- [ ] Tester import dans **VSTax 2024** réel (validation manuelle Julien+Lauren)
- [ ] PDF récapitulatif avec **skill `pdf`** (signable, archivable, mise en page MINT)
- [ ] PDF rapport d'optimisation avec **skill `pdf`** (storytelling MINT, voix régionale)
- [ ] Mode d'emploi "import VSTax" : 3 captures + GIF court intégré dans l'écran 5

### Sprint S60 — "UI + Wow Moment" (2 semaines)
**Goal** : Les 5 écrans Flutter, l'expérience.
- [ ] 5 écrans Flutter (cf. §2.2) — un seul tap entre chaque
- [ ] Drop zone universel : photo iPhone, scan, drag&drop desktop
- [ ] Liste intelligente du manquant (utilise profil + archétype + canton + état civil + enfants + propriétaire)
- [ ] Confidence Score visible au niveau rubrique ET global
- [ ] Inline-edit avec re-calcul instantané de l'impôt et du Confidence Score
- [ ] **6 langues ARB** (fr template, en, de, es, it, pt — `flutter gen-l10n`)
- [ ] Animation "moment wow" écran 4 : chiffre d'économie qui s'incrémente, calme mais mémorable
- [ ] Bandeau Aujourd'hui contextuel (apparaît janvier, disparaît mai)
- [ ] **Tests UX** : 5 utilisateurs hors équipe, mesurer temps total < 15 min

### Sprint S61 (optionnel, Phase 2) — "Multi-cantons romands"
- VD, GE, NE, FR, JU avec leurs barèmes, formulaires, valeurs locatives
- Parsing supplémentaire pour formats spécifiques (FAR, retenue source frontaliers, etc.)

### Sprint S62+ (Phase 3) — "Suisse alémanique + tessinoise"
- ZH, BE, LU, ZG, BS, AG, SG + TI
- Voix régionale alémanique et tessinoise (cf. CLAUDE.md §6 RegionalVoiceService)
- Format Tax Warrior, Dr.Tax, Taxme : déjà eCH-0119, no-op

---

## 4. Alternatives considérées (et arbitrages du panel)

| Alternative | Pour | Contre | Verdict |
|-------------|------|--------|---------|
| **A. Reverse-engineer le `.vstax24`** | "Plug & play" total, l'utilisateur n'a rien à importer | Veto Juriste (CGU + 144bis CP), veto Sécu (clé annuelle), dette de maintenance × 26 cantons | **Rejeté** |
| **B. Export XML eCH-0119** (retenu) | Standard officiel, importable VSTax + tous logiciels cantonaux, maintenable | L'utilisateur a un import à faire (3 clics, 30s, mode d'emploi inclus) | **Retenu** |
| **C. Service web direct AFC valaisanne** | Soumission instantanée | API non publique en 2026 (roadmap Confédération 2027–2028 via eCH-0196 transactionnel), exigerait E&O insurance majeure | Reporté Phase 4 |
| **D. PDF formulaire pré-rempli uniquement** (pas de XML) | Plus simple à coder | L'utilisateur recopie tout dans VSTax = perte de la promesse | Rejeté par Product |
| **E. Conseil fiscal en chair et os (humain)** | Précision maximale | Coût, scaling, hors doctrine MINT (no-advice) | Renvoyé au Phase 3 "Expert tier" (cf. roadmap V2) |
| **F. Pas de module fiscal du tout** | Économie de scope | Énorme valeur perdue, désalignement avec promesse "MINT te dit ce que personne…" | Rejeté unanimement |

### Arbitrages internes au module (panel iter 2)

- **Faut-il OCR les pièces justificatives ou demander saisie manuelle ?** → OCR obligatoire pour les **5 documents critiques** (salaire, 3a, LPP, banque, médical), saisie manuelle acceptée en fallback. Veto UX si tout est manuel.
- **Faut-il afficher l'impôt total estimé sur l'écran 4 ?** → Oui, c'est anchoring sain ("voici la réalité"), mais entouré de conditionnel ("environ", "selon coefficient communal").
- **Faut-il proposer un mode "soumission directe" via partenariat fintech ?** → Reporté Phase 4, hors scope MVP.
- **Le rapport d'optimisation doit-il citer des produits nommés (banque X pour 3a Y) ?** → **Non, jamais** (doctrine no-advice). Citer classes de produits + caractéristiques recherchées.

---

## 5. Conséquences

### Positives
- **Valeur utilisateur massive** : ~10–20h économisées par an, par utilisateur. ROI immédiatement perceptible.
- **Différenciation produit forte** : aucune app suisse ne fait actuellement l'agrégation Profil → Documents → XML eCH-0119 → Optimisation chiffrée dans une UX MINT-grade. Concurrence directe = Dr.Tax (cher, complexe), Taxme (canton ZH-centric), comptables (cher).
- **Cohérence doctrinale parfaite** : "Mint te dit ce que personne n'a intérêt à te dire" — exactement le brief.
- **Effet de réactivation annuel** : chaque janvier, l'utilisateur rouvre MINT pour sa déclaration. Rétention structurelle.
- **Dataset propre pour Phase 2** : nouvelles règles d'optimisation détectables au fil des années (machine learning sur leviers les plus impactants par profil).

### Négatives / Risques
- **Surface d'attaque privacy étendue** — atténué par stockage chiffré device-only et transit normalisé (cf. §6).
- **Complexité maintenance multi-cantons** — atténué par interface `CantonRules` + couverture progressive.
- **Risque réglementaire LSFin/LCD** si wording dérive vers le conseil → **gate `LEGAL_RELEASE_CHECK.md`** obligatoire avant chaque release du module + revue juridique externe avant Phase 1 launch.
- **Risque réputationnel si XML rejeté par VSTax** → tests automatisés contre VSTax réel chaque trimestre + canary release sur 50 utilisateurs janvier 2027 avant general availability.
- **Erreur OCR conduisant à mauvaise déclaration** → écran 3 force la vérification utilisateur, Confidence Score visible, disclaimer "tu restes responsable de ta déclaration".

---

## 6. Privacy & Sécurité (gate non-négociable)

> Veto Sécurité activé : tout écart à cette section bloque la release.

| Donnée | Stockage | Transit | Rétention |
|--------|----------|---------|-----------|
| PDF originaux uploadés | **Device-only**, chiffré (Document Vault, ADR-20260217) | Jamais sur backend MINT | Suppression auto à J+395 (1 an + 30j buffer), purge immédiate sur demande |
| Champs extraits (montants, dates) | Device-only chiffré + agrégats anonymisés sur backend pour calcul | Backend reçoit valeurs **sans** nom, IBAN masqué (4 derniers), employeur hashé | Backend = session éphémère 24h, purge automatique |
| Résultat XML eCH-0119 | Device-only chiffré | Jamais transmis | Comme PDF originaux |
| Rapport d'optimisation | Device-only chiffré | Généré côté backend depuis agrégats puis renvoyé, jamais persisté | Comme PDF originaux |
| Logs serveur | Anonymisés (session_id seul) | N/A | 30j max, art. 5 nLPD |

**Conformité nLPD** :
- Base légale : consentement explicite à l'écran 1
- Finalité unique : préparation déclaration fiscale de l'utilisateur
- Minimisation : seuls agrégats normalisés transitent
- Droit à l'oubli : bouton "Supprimer toute ma fiscalité" → purge immédiate device + backend
- Pas de profilage commercial sur ces données
- Pas de transfert hors Suisse

**Conformité LSFin / LCD** :
- Aucune recommandation produit nommé
- Disclaimer "outil éducatif, ne constitue pas un conseil fiscal" sur chaque écran
- Renvoi vers fiduciaire / fiscaliste agréé pour cas complexes (succession, indépendant complexe, expatriation US)

---

## 7. Métriques de succès (Definition of Done produit)

| Métrique | Cible MVP (S60) | Cible 6 mois post-launch |
|----------|-----------------|--------------------------|
| Temps utilisateur médian | < 15 min | < 10 min |
| Taux de complétion (commencé → 3 fichiers téléchargés) | > 65% | > 80% |
| Documents auto-classés correctement | > 92% | > 97% |
| Champs auto-extraits avec confidence > 80% | > 85% | > 92% |
| Économie médiane détectée par utilisateur | ≥ 800 CHF/an | ≥ 1'200 CHF/an |
| NPS post-déclaration | > 50 | > 65 |
| Import XML accepté par VSTax sans erreur | 100% sur cas testés | 100% en production |
| Réactivation année N+1 (utilisateurs 2025 qui reviennent en 2026) | N/A | > 75% |

---

## 8. Plan de migration / Rollout

1. **Avril 2026 — Validation panel** (cet ADR)
2. **Mai–juin 2026 — Sprints S57–S58** : backend + optimizer + tests sur Julien+Lauren
3. **Juillet 2026 — Sprint S59** : exporters + import-test VSTax réel
4. **Août 2026 — Sprint S60** : UI Flutter + tests UX externes
5. **Septembre 2026 — LEGAL_RELEASE_CHECK** + revue juridique externe (avocat fiscaliste VS)
6. **Octobre 2026 — Beta fermée** : 50 utilisateurs MINT volontaires (déclaration 2025 anticipée)
7. **Janvier 2027 — Canary** : 10% utilisateurs canton VS
8. **Février 2027 — General Availability VS** + ouverture phase 2 (VD/GE/NE/FR/JU)
9. **Mars 2027 — Bilan campagne**, ajustements optimizer
10. **Été 2027 — Phase 3** : suisse alémanique + tessinoise

---

## 9. Liens

- ADR-20260217-document-vault-premium.md (storage chiffré device)
- ADR-20260223-unified-financial-engine.md (réutilise tax_calculator, lpp_calculator)
- ADR-20260223-archetype-driven-retirement.md (archétypes appliqués au fiscal aussi)
- docs/MINT_IDENTITY.md (doctrine 4-layer engine, principe protection-first)
- docs/ROADMAP_V2.md (sprints S57–S62)
- LEGAL_RELEASE_CHECK.md (gate avant release)
- visions/vision_compliance.md (cadre LSFin/nLPD)
- Standards : eCH-0119 v3.0, eCH-0196, ELM 5.0 (norme certificat salaire CH)
- VSTax officiel : https://www.vs.ch/web/scc/vstax (canton du Valais, Service cantonal des contributions)

---

## 10. Décision finale du panel

**Approuvé à l'unanimité** (6/6 rôles), sous réserve de :

1. La revue juridique externe avant launch (Sprint S60 + 1)
2. Le gate `LEGAL_RELEASE_CHECK.md` complété
3. Le test d'import VSTax réel passé sur le couple Julien+Lauren ET sur 5 profils synthétiques (jeune célibataire VS, retraité VS, indépendant VS, propriétaire VS, expat US résident VS)
4. Aucun PDF original ne quitte le device de l'utilisateur
5. Le wording du rapport d'optimisation est validé contre la liste de termes bannis (CLAUDE.md §6)

> **Signature symbolique du panel** : Fiscaliste VS ✓ · Ingénieur OCR ✓ · Designer UX ✓ · Juriste LSFin/nLPD ✓ · Product Lead ✓ · Sécurité/Privacy ✓
