# ADR-20260415 — Tax Declaration Autopilot (Vision Cible)

**Status**: Proposed (vision document)
**Date**: 2026-04-15
**Authors**: Julien + Claude, après 6 reviewers adversariaux + 13 designers dream-team + 4 experts consolidation
**Scope**: Vision + principes architecturaux du module "MINT Fiscal". **Implémentation Phase 0** : voir [ADR-20260501-tax-phase-0-wedge.md](ADR-20260501-tax-phase-0-wedge.md).
**Supersedes**: v1 (archivée dans `archive/`), v2 expanded (intégrée + rescopée ici en vision-only)
**Replaces**: le plan d'exécution de v2 (8 sprints, 6-8 fronts parallèles, browser-native PWA) — jugé non-shippable pour équipe solo post-Gate-0

---

## 1. Pourquoi cet ADR est minimaliste

ADR v1 (rejetée par panel adversarial 6/6) promettait trop sur fondations faibles.
ADR v2 étendue (browser-native Fiscal Twin) était stratégiquement défendable mais constituait un **pari plateforme massif** inadapté à une équipe solo avec Gate 0 cassé.

**Cet ADR = VISION uniquement.** Pas de plan d'exécution détaillé. Le plan d'exécution vit dans l'ADR Phase 0.

Ce document a deux fonctions :
1. Fixer la **thèse produit** de MINT Fiscal pour les 12-24 mois à venir.
2. Fixer les **principes architecturaux non-négociables** que toute phase d'implémentation doit respecter.

---

## 2. Thèse produit — "Le Dossier Fiscal Vivant"

**One-liner** :
> *"MINT ne prépare pas ta déclaration. MINT maintient ton dossier fiscal vivant toute l'année, pour qu'au 1er janvier il soit déjà là."*

**Valeur pour l'utilisateur (réalité terrain, validée par recherche sur 17 déductions VS 2025 + retours Tell Tax)** :
- Le contribuable reçoit déjà ses attestations (caisse maladie, 3a, LPP) en janvier-février → il les range dans un dossier email/iCloud/Files → il **hait** le moment VSTax où il faut ouvrir chaque fichier, écrire les chiffres, cocher les cases.
- MINT **lit automatiquement** ce dossier, remplit silencieusement les 17 rubriques documentables, et interroge l'utilisateur **uniquement sur ce qui n'est pas dans un PDF** (~6 questions ciblées).
- MINT **coache toute l'année** : "envoie-moi le ticket de l'ordi", "photo du compteur", "rachat LPP fenêtre novembre".
- Le moment déclaration devient une **récolte**, pas une course.

**Ce qu'on ne fait PAS** :
- Pas un Dr.Tax clone (saisie manuelle).
- Pas un Tell Tax clone (stockage passif + catégorisation manuelle). Tell Tax = gratuit, officiel, mais zéro intelligence, zéro coaching, zéro proactivité.
- Pas un conseiller en placement (LSFin territory — ne jamais recommander produit nommé ni quantifier "tu devrais verser X").

---

## 3. Différenciation vs concurrence

| Acteur | Ce qu'il fait | Ce qu'il ne fait pas | Positionnement MINT |
|--------|---------------|----------------------|---------------------|
| **Dr.Tax** (25 ans, CHF 49-99) | Saisie manuelle + submission pipeline | Pas de coaching, pas de lecture automatique, pas de proactivité | MINT = **layer amont** qui remplit ; handoff XML possible |
| **VSTax** (gratuit VS) | Formulaires officiels + import Tell Tax/QR + pré-remplissage N-1 | Pas de coaching, OCR Tell Tax à 60% accuracy, pas de rappels | MINT = **coach + qualité d'extraction supérieure** |
| **Tell Tax** (gratuit VS) | Stockage + classification manuelle + import VSTax | Pas de lecture, pas de leviers, pas de rappels, pas de coach | MINT = complémentaire, pas concurrent |
| **VZ Finanzplanung** | Contenu éditorial + conseillers humains | Pas d'app live, pas automatique | MINT = **automation + contenu vivant** |
| **Accountable** (CH fintech récente) | Déclaration pour indépendants | Pas de coaching fiscal année-courante | MINT = couverture plus large (salarié first) |

**Moat MINT** = combinaison de 4 capacités qu'aucun acteur CH ne réunit aujourd'hui :
1. **Lecture intelligente** des documents (Claude Vision) → qualité > Tell Tax OCR
2. **Questions proactives** sur leviers non-documentables (km voiture, achats pro, etc.)
3. **Plan de rappels année-courante** calé sur calendrier fiscal (mi-année, rentrée, fenêtre 3a, rachat LPP)
4. **Dossier vivant visible** hors saison déclaration — le produit fonctionne 12 mois/an, pas 2

---

## 4. Principes architecturaux non-négociables

Ces principes **ne bougent pas** peu importe la phase d'implémentation.

### 4.1 Ring-fence coach AI sur données fiscales (load-bearing)

**Aucun champ fiscal identifié ne transite par Anthropic dans le contexte coach général.**

Enforcement :
- `DENY_LIST` hardcodée dans `apps/mobile/lib/services/context_injector_service.dart` + parallèle dans `services/backend/app/services/claude_coach_service.py`
- Path patterns bannis : `twin.revenues.*`, `twin.deductions.*`, `twin.employers.*`, `profile.salary_*`, `profile.iban`, `profile.fortune_*`, etc.
- CI gate bloquant : test qui instancie tous les `CoachContext` possibles et assert qu'aucun path DENY_LIST n'est présent.
- Audit log : chaque appel coach log `sha256(context_keys_sent)` pour audit post-hoc.

**Exception contrôlée** : un endpoint dédié à l'**extraction fiscale** peut appeler Claude Vision avec le contenu du document, mais **uniquement** pour extraction structurée (JSON schema contraint), jamais en contexte conversationnel. Données extraites ré-entrent dans un espace local strict, jamais re-injectées dans le coach général.

### 4.2 Doctrine "lucidité, pas protection" appliquée à la fiscalité

- **Read-only** : MINT ne soumet **jamais** la déclaration. Toujours handoff XML/PDF que l'utilisateur envoie lui-même.
- **No-Advice** : les leviers sont présentés comme **calculs de la loi** avec source légale (LIFD/LF-VS art. X), jamais comme "tu devrais". Conditionnel toujours.
- **No-Promise** : fourchettes min/max selon coefficient communal, jamais un chiffre ponctuel hors contexte (LCD art. 3 risk).
- **No-Ranking** : leviers triés par gain estimé décroissant (factuel), jamais "meilleur levier".
- **Prospectif N+1 only** : jamais "tu aurais économisé X en N" (shame trigger + année close). Toujours "pour N+1, voici ce qui est possible avec deadline".
- **Anti-shame absolu** : zéro copy qui culpabilise, même implicitement.

### 4.3 Compliance posture — éditeur de logiciel, pas prestataire de conseil

MINT **ne s'auto-classifie pas comme conseiller en placement LSFin**. Positionnement = éditeur de logiciel fiscal (LSFin art. 3 al. 3 — exception outil informatique), dans la tradition Dr.Tax (25 ans sans qualification LSFin).

Cela exige, dans chaque phase d'implémentation :
- Wording LSFin-safe (voir §4.2)
- Pas de produit nommé recommandé
- Pas de ranking de produits
- Disclaimer éducation explicite sur chaque écran
- E&O insurance tier "éditeur logiciel" (non pas tier "fintech service")
- Lettre informelle FINMA avant Phase 1 (qui introduit XML + PDF + leviers quantifiés chiffrés)

### 4.4 Privacy-first avec preuves, pas avec promesses

Pour chaque phase, la posture privacy est **vérifiable techniquement**, pas seulement promise :
- PDFs originaux **toujours device-local**, chiffrés via Document Vault (ADR-20260217 + upgrades Phase 1+)
- Backend ne reçoit **aucun champ fiscal identifié** dans le flow coach général
- Extraction fiscale via endpoint dédié, Claude Vision appelé **sans rétention** (zero-retention tier Anthropic)
- nLPD art. 22 DPIA alléguée pour Phase 0 (pas de transformation majeure du traitement existant), pleine DPIA pour Phase 1+
- Pas de transfert hors Suisse **documenté comme tel** (Anthropic US sous SCC + consentement séparé, ou migration Mistral/Swisscom Swiss-hosted en Phase 2)

### 4.5 Doctrine UX — dossier vivant, pas funnel déclaration

- **Le dossier existe avant que l'utilisateur le demande, et ne disparaît jamais.**
- Pas de 5 écrans en tunnel. Le dossier vit dans Explorer → Fiscalité, 12 mois/an.
- La saison déclaration = un moment orchestré dans le dossier (pas un module séparé).
- Vocabulaire : "dossier", "documents reçus", "il manque", "on en est là". Jamais "complète à 73%", jamais "12 minutes", jamais animation chiffres.
- Sortie principale = un récap structuré avec sources documentées ; sortie XML = phase ultérieure.

### 4.6 Canton VS first, extension phasée

VS est le canton de référence (fondateur + doctrine régionale + corpus réel). Autres cantons (VD/GE/NE/FR/JU/ZH/BE/TI) ajoutés par phases selon validation wedge.

**Exclusions MVP permanentes** :
- Frontaliers permis G (régime CDI-FR 1983 = impôt 100% France, pas de déclaration VS classique)
- Forfait fiscal art. 14 LIFD (cas rare, expert required)
- Indépendant complexe (SA/Sàrl, comptabilité commerciale) — déferred Phase 2+

---

## 5. Architecture long-terme (3 phases)

Cet ADR fixe **l'état-cible** à 18-24 mois. Chaque phase est un ADR séparé, dont seule la Phase 0 est planifiée à date.

### Phase 0 — "Wedge Dossier Fiscal Vivant"
- Surface : intégrée dans l'app MINT existante (Flutter mobile)
- Capacités : ingestion bulk + extraction Claude Vision + 13 leviers VS + questionnaire conditionnel + capture passive année-courante + plan de rappels N+1
- Output : récap structuré à recopier dans VSTax (pas d'XML)
- Précondition : Gate 0 résolu (coach fonctionnel)
- Détails : [ADR-20260501-tax-phase-0-wedge.md](ADR-20260501-tax-phase-0-wedge.md)

### Phase 1 — "Full Automation + Partnership"
(Sera ADRisé quand Phase 0 valide wedge — critères dans §6)

- Export eCH-0119 v2.2 XML import direct VSTax
- PDF récap + PDF rapport d'optimisation (sous contrainte LSFin-safe)
- Extensions VD, GE (après retour terrain VS)
- Couple mode riche, flow FATCA clarifié
- Partenariat fiduciaire VS/VD (relecture humaine, revenue share)
- FINMA informal inquiry + E&O uplift + DPIA externe
- Auto-fetch cours fiscal titres via ICTax AFC

### Phase 2 — "Browser-Native Fiscal Twin" (optionnelle)
(Sera ADRisée seulement si Phase 1 valide demande d'automation + moat browser)

- Webapp `fiscal.mint.ch` (SvelteKit + WebLLM + OPFS + WebAuthn + CRDT)
- "Cut internet" auditable + reproducible build + open-source fiscal-core
- bLink / SFTI Common API pour ingestion e-banking automatique
- Multi-cantons ZH + BE + TI
- Non-négociable si cette phase advient : hardware-bound KEK, Swiss-hosted inference pour tout champ fiscal

**Note** : Phase 2 peut ne jamais advenir si Phase 1 démontre que la valeur produit est saturée dans l'app mobile + partnership fiduciaire. La discipline est de **ne pas sur-ingénierer par anticipation**.

---

## 6. Critères de promotion entre phases

### Phase 0 → Phase 1 (trigger pour draft Phase 1 ADR)

Tous simultanément, mesurés 3 mois après launch Phase 0 :
- ≥ 50 utilisateurs actifs ont complété un dossier fiscal 2025
- ≥ 30% ont indiqué "je vais faire" sur au moins un levier prospectif N+1
- Zéro fuite DENY_LIST en prod (Sentry alerts = 0)
- Zéro incident LSFin / PFPDT
- NPS ≥ 40 sur l'expérience Phase 0 globale
- Au moins 1 fiduciaire VS partenaire signé (LOI)

Si un critère échoue à M+3 → ajuster Phase 0 ou killer avant Phase 1.

### Phase 1 → Phase 2 (trigger pour draft Phase 2 ADR)

Tous simultanément, mesurés 6 mois après launch Phase 1 :
- ≥ 1'000 utilisateurs actifs ≥ 2 cantons (VS + VD ou VS + GE)
- Export XML utilisé par ≥ 60% des dossiers complétés
- FINMA réponse informelle favorable (éditeur logiciel confirmé)
- E&O insurance en force à prime ≤ CHF 15k/an
- Demande terrain explicite pour "MINT indépendant de l'app mobile" OU "audit transparence 'cut internet'"

---

## 7. Gate 0 précondition (hard stop sur toute phase)

Tax autopilot — **aucune phase** — **ne démarre** tant que les 5 Gate 0 issues d'état MINT ne sont pas résolues :
1. Auth state propagation
2. Coach context memory (ne perd plus le fil)
3. Markdown rendering
4. Document scanner fonctionnel
5. Premier éclairage load path

**Raison** : tax prep sur un coach cassé = double failure. L'utilisateur perd confiance en tout MINT en découvrant les bugs au pire moment de stress (saison déclaration). La priorité MINT n°1 reste Gate 0, pas le tax.

---

## 8. Références

- [ADR-20260415-tax-declaration-autopilot-REVIEW.md](ADR-20260415-tax-declaration-autopilot-REVIEW.md) — 6 reviewers adversariaux v1
- [ADR-20260501-tax-phase-0-wedge.md](ADR-20260501-tax-phase-0-wedge.md) — plan d'exécution Phase 0
- [ADR-20260217-document-vault-premium.md](ADR-20260217-document-vault-premium.md) — vault existant (base Phase 0)
- [ADR-20260223-unified-financial-engine.md](ADR-20260223-unified-financial-engine.md) — calculators réutilisés
- [archive/ADR-20260415-tax-declaration-autopilot-v1-REJECTED.md](archive/ADR-20260415-tax-declaration-autopilot-v1-REJECTED.md) — v1 archivée
- `~/.gstack/projects/MINT-IA-MINT/ceo-plans/2026-04-15-tax-autopilot-scope-reduction.md` — CEO plan (23 scope decisions)
- `CLAUDE.md` §2 (financial_core), §5 (business rules), §6 (compliance), §7 (UX)
- `docs/MINT_IDENTITY.md` — doctrine lucidité
- Standards : eCH-0119 v2.2, ELM 5.0, bLink (SIX) — watchlist Phase 1/2

---

**Fin ADR — Vision cible uniquement. Implémentation dans ADR Phase 0.**
