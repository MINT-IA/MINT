# Vision: Product — MINT

> **⚠️ OBSOLETE (2026-04-05) — TO REWRITE**
> Ce document contient des éléments stratégiques utiles (horizons d'acquisition, open banking, séquence de confiance)
> mais son identité, sa cible (22-35), son tagline ("Juste quand il faut") et son hook ("chiffre choc") sont obsolètes.
> **Source of truth pour l'identité : `docs/MINT_IDENTITY.md`**
> Ce document sera réécrit pour s'aligner avec la nouvelle mission : "Mint te dit ce que personne n'a intérêt à te dire."

## The Problem
Swiss financial products are complex (Pillar 3a, LPP, tax optimization). The 22-35 segment (qualified professionals) enters peak capital formation but is paralyzed by complexity or biased advice. Existing tools ask for everything before giving anything.

### Stress financier = charge mentale
Le stress financier n'est pas qu'une affaire de chiffres, c'est une **charge mentale** qui paralyse la prise de décision. Plutôt que de "médicaliser" le problème, MINT traite la complexité comme un bruit cognitif à éliminer. La promesse JIT (Just-In-Time) vise à transformer cette anxiété en une suite d'actions simples et maîtrisées.

## The Promise: The Financial OS (Timeline-First)
**Mint is the proactive mentor for the next generation of Swiss wealth.**
**Tagline**: "Juste quand il faut: une explication, une action, un rappel."

### Core Loop — Juste quand il faut
MINT est un conseiller proactif de poche, mais d’abord un mentor éducatif: il intervient au moment précis où une décision financière se présente (pas après).
Notre boucle produit est volontairement simple et répétable: **"Juste quand il faut: une explication, une action, un rappel."**
Chaque interaction réduit l’ambiguïté en une décision sûre: une mini-explication contextualisée, une action unique (ou 1–3 next actions maximum), puis un rappel dans la timeline pour rendre l’effort durable.
La confiance est un avantage produit: MINT reste read-only, affiche ses hypothèses et limites, et ne demande jamais une connexion bancaire avant d’avoir prouvé sa valeur.

## Stratégie d’acquisition — “Cheval de Troie” (3 horizons)
**Horizon 1 — Acquisition (Hook): “Fiscal Mirror + Reste à vivre”**
Prouver la valeur immédiatement avec un onboarding minimal basé sur les **4 questions d’or** (Canton, Âge, Revenu, Statut).
- **Badge de Précision**: Affichage clair du niveau de fiabilité (Faible/Moyenne/Haute) expliquant "ce qu'on sait vs ce qu'on suppose".
- **Hook Viral & Sûr**: Révélation claire (Fiscal Mirror) et partageable, mais toujours avec des fourchettes et hypothèses visibles. Pas de projection de gain absolu, mais un insight de sécurité (Anti-dette / Reste à vivre).

**Horizon 2 — Confiance (Éducation)**
Inserts didactiques et simulateurs prudents: expliquer le standard **Just-in-time** ("Pourquoi avant quoi faire").
- **Preuve par le calcul**: Utilisation de taux réels mais présentés avec des bandes d'incertitude.
- **Sortie**: Un mini-rapport ou un plan de 1–3 actions formulées en "Si… alors…".

**Horizon 3 — Connexion (Open Banking)**
Open Banking comme **récompense après valeur** (Reward Flow).
- **Consent Dashboard**: Connexion demandée uniquement pour affiner le plan, avec contrôle total et révocation simple.
- **Read-Only**: Notifications proactives pour "ajuster le plan", jamais pour initier des mouvements d'argent.
- Cette séquence évite de "demander le mariage au premier rendez-vous".

**Horizon 4 — Données institutionnelles (Partenariats B2B)**
Connexion directe aux institutions financières suisses pour une précision maximale.

### 4A. Caisses de pension (LPP temps réel) — Le Graal
- **Réalité**: Aucune API standardisée parmi les ~1'400 caisses suisses. Quelques grandes caisses ont des portails membres (Publica, BVK, CPEV). Initiative SwissPensions en cours de standardisation.
- **Stratégie**: Pilote avec 2-3 grandes caisses → démontrer la valeur → attirer l'écosystème.
- **Caisses ciblées**: Swisscanto, Tellco, Profond, CPEG, CIA, Publica, BVK.
- **Données obtenues**: Solde LPP réel (oblig + suroblig), taux de conversion effectifs, potentiel de rachat, rente projetée, couverture invalidité/décès.
- **Impact ConfidenceScore**: +30-35 points. Rend les arbitrages rente vs capital fiables.
- **Modèle B2B**: MINT comme outil "financial wellness" proposé aux caisses elles-mêmes (5-15 CHF/employé/an), en échange d'un accès API aux données de prévoyance.

### 4B. Extrait AVS (Compte individuel)
- **Réalité**: Extrait CI disponible sur www.ahv-iv.ch, mais pas d'API publique. Le citoyen doit le demander manuellement (PDF).
- **Court terme**: Guidage in-app + parsing OCR du PDF (déjà implémenté).
- **Moyen terme**: Authentification eID (identité électronique suisse) → accès direct automatisé.
- **Données obtenues**: Années de cotisation exactes, RAMD, lacunes, bonifications éducatives.
- **Impact ConfidenceScore**: +20-25 points. La rente AVS est la plus grande composante du revenu retraite.

### 4C. Barèmes cantonaux (AFC / administrations fiscales)
- **Réalité**: Données publiques, certains cantons offrent des calculateurs avec APIs.
- **Statut**: Déjà couvert par TaxCalculator (26 cantons, S20). Amélioration possible avec barèmes communaux précis.

### 4D. Attestations assurance (LAMal, risque)
- **Réalité**: Aucune API standard parmi les assureurs. Certains (CSS, Helsana, Swica) offrent des attestations digitales.
- **Priorité basse**: Données moins dynamiques que LPP/AVS.
- **Approche**: Scan OCR des polices d'assurance (même pipeline que certificats LPP).

### Séquence d'acquisition des données (parcours utilisateur)
```
Onboarding (30 sec)    → 3 questions (âge, salaire, canton)           → Confiance ~25%
Première session       → Enrichissement progressif (famille, épargne) → Confiance ~40-50%
Première semaine       → Scan certificat LPP + attestation 3a         → Confiance ~65-75%
Premier mois           → Open Banking + extrait AVS                    → Confiance ~80-90%
Annuel                 → Scan déclaration fiscale + certificat LPP     → Confiance maintenue > 75%
Long terme             → APIs institutionnelles (caisses de pension)   → Confiance > 95%
```

## Core Capabilities
- **Pedagogical Simulators**: "Real Interest" combining tax savings + yield, and "Staggered Buybacks" visualization (Always with education-first, non-prescriptive scenarios).
- **Administrative Empowerment**: "Letter Generator" for rulings, pension fund requests, and social benefits (PC) inquiries.
- **Resource Bridge**: Proactive redirection to state services (e.g. PC office) when relevant.

## Core Pillars
1. **Priority Hierarchy**: **Anti-Debt & Budget First** > Optimization Second. No 3a/LPP suggestions if user is in financial distress (Safe Mode).
2. **Compliance as Advantage**: "Statement of Advice" (SoA) compliant by default. Explicit disclosure of conflicts/commissions before being forced.
3. **Neutrality & Trust**: "Mentor" status means red-flagging risky debt (consumer credit, leasing) and orientation towards debt-prevention resources (Safe Mode).
4. **Open Banking as Reward**: post-value connection (bLink) with a "Consent Dashboard" (Total control/Stop button).
5. **Hermeneutical Dialogue**: The session report is a living document that grows "more precise" as the FactFind completes.

## North Star Metric
**"Advisor Clarity & Action Conversion"**: How many users implemented 1 of the Top 3 actions within 14 days of a Session.
