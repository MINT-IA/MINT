# ADR-CH-EDU-SIMULATORS — Didactic Inserts + Simulators (Suisse)
Date: 2026-01-12
Status: Accepted

## 1) Cercle (Tout)
Mint est un mentor financier suisse qui délivre un Plan Mint (rapport) + une timeline proactive.
Objectif: transformer l'ambiguïté en actions sûres et compréhensibles, sans promesses implicites, avec hypothèses explicites, et transparence (commissions/conflits si partner handoff).
Le modèle d'éducation est "just-in-time information" + interactivité, avec nudges éthiques (pas de gamification incitative au risque). [OECD/INFE]

## 2) Cercle (Parties)
### 2.1 Concepts CH à couvrir (univers suisse)
A. Prévoyance (AVS/LPP/3a/3b)
- AVS: lacunes (à créer)
- LPP: schéma (pivot LPP oui/non), rachat (phase 2)
- 3a: plafonds (dépend LPP oui/non), économie fiscale (à garder)
- 3b: différence 3a/3b (phase 2)
- Retrait échelonné 3a (phase 2, 50+; prudence cantonale)

B. Fiscalité
- Taux marginal: affichage en fourchette + hypothèses (pas de calcul exact)
- Déductions: checklist (phase 2)
- Impôt sur retraits 2e/3e pilier (phase 2)
- Impôt fortune: explainer (phase 2)

C. Logement
- Fixe vs SARON: comparateur (phase 1)
- Coût réel propriété: calculateur (phase 2)
- Achat vs location: comparateur (phase 2)
- EPL (utilisation 2e/3e pilier): explainer (phase 2)

D. Dettes & risques
- Crédit conso: simulateur coût (phase 1)
- Leasing: simulateur coût (phase 1)
- Fonds d'urgence: calculateur 3–6 mois (phase 1)
- Ratio effort: pas de "33%" universel; seulement indicateur tension, et uniquement route logement.

E. Investissement (pédagogie)
- Intérêts composés: simulateur (phase 1)
- Risque vs rendement / diversification / frais: explainers (phase 2)

F. Assurances (Suisse)
- LAMal franchise: phase 2 (après garde-fous, car risque de simplification)
- Incapacité de gain: explainer (phase 2)
- RC: explainer (phase 2)

### 2.2 Standard UX Requis — Just-in-time
**Le modèle standard est: Question → Insert didactique → Action → Timeline reminder.**
- Les inserts sont "just-in-time": au moment où l'utilisateur touche le sujet.
- **Règles**: Inserts courts, neutres, sans promesse implicite, hypothèses/limites visibles pour les chiffres.
- **Actions**: formulées en “Si… alors…” et limitées à 1–3 next actions max.
- **Copy Compliance**: Hypothèses et limites toujours visibles. Toujours mentionner l'existence d'un aléa et l'incertitude du résultat.

Exemples requis:
- q_has_pension_fund -> schéma LPP oui/non -> impact plafond 3a
- q_has_3a / q_3a_annual_amount -> mini simulateur économie fiscale (avec hypothèses)
- q_mortgage_type -> comparateur Fixe vs SARON (neutre)
- q_has_consumer_credit -> alerte coût total + action
- q_has_leasing -> simulateur leasing vs achat + action

### 2.3 Guardrails Compliance (Suisse)
- Toute simulation doit afficher: hypothèses + "pédagogique" + limites.
- Le "taux marginal" est une estimation en fourchette, jamais présenté comme une décision fiscale définitive.
- Aucun scénario "marché 8%" sans bande d'incertitude et sans mention explicite d'hypothèses.
- Partner handoff: disclosure requise + alternatives; jamais lié à une récompense UX.
- Retraits échelonnés 3a: mentionner progressivité et variabilité cantonale (pas de promesse) et renvoyer vers "learn more".
Références: pratiques FINMA sur devoir d'information/communication non trompeuse et transparence sur rétrocessions. [FINMA]

### 2.5 Nouveaux Simulateurs & Outils
Les fonctions avancées sont débloquées uniquement si le Safe Mode (Dette) est inactif.

A. Simulation "Intérêt Réel" (3a/LPP)
- Objectif: Montrer l'effet levier de l'économie fiscale combinée au rendement.
- Entrées: Montant versé, Taux marginal estimé (fourchette), Rendement marché (scénarios).
- Sortie: Capital final vs Capital net investi.
- Règle: Jamais de projection unique. Toujours 3 scénarios (Pessimiste/Neutre/Optimiste) avec disclaimer sur l'incertitude fiscale et boursière.

B. Rachats LPP Échelonnés (Staggered Buybacks)
- Objectif: Visualiser l'avantage de lisser les rachats pour casser la progressivité de l'impôt.
- Visualisation: Comparaison "Tout en 1 an" vs "Sur 3-5 ans".
- Disclaimer: "Sous réserve d'acceptation par l'administration fiscale. Le lissage abusif (3 ans avant capital) peut être requalifié."

C. Module Retraite & PC (Prestations Complémentaires)
- Objectif: Détecter l'éligibilité potentielle sans se substituer à l'administration.
- Input: Revenu net approximatif + Fortune nette.
- Output: "Il est possible que vous ayez droit aux PC." -> Redirection vers l'office cantonal.
- Compliance: Disclaimer "Ceci n'est pas un calcul officiel."

D. Générateur de Lettres (Admin Empowerment)
- Objectif: Réduire la friction administrative.
- Fonction: Génération PDF local de modèles pré-remplis (Nom, Adresse).
- Templates:
  - Demande de rachat LPP (pour la caisse).
  - Demande d'attestation fiscale (3a/LPP).
  - Ruling fiscal simple (retrait planifié).
- Footer requis: "Ce document est un modèle. L'utilisateur est seul responsable de son contenu final et de son envoi."

## 3) Cercle (Retour / Réconciliation)
Critères de succès:
- Le wizard reste court (25–30 questions typiques), inserts non bloquants.
- Le report final est plus clair, pas plus long.
- Aucun wording trompeur; hypothèses visibles; pas de promesse.
- Timeline: max 6 items par session; items utiles (décembre 3a, hypothèque, dettes, etc.)

## 4) Backlog (Niveau 1/2/3)
Niveau 1 (priorité absolue, wizard inserts):
1) 3a + fiscalité (avec pivot LPP oui/non)
2) LPP pivot (schéma)
3) Fonds d'urgence (calculateur)
4) Fixe vs SARON (comparateur)
5) Leasing + Crédit conso (simulateurs coût)

Niveau 2 (rapport):
- Graphe "avec/sans optimisation" (indicateur simple)
- Graphe timeline (échéances)

Niveau 3 (phase 2):
- Retrait 3a échelonné (50+)
- Rachat LPP (35+ si LPP upload)
- LAMal franchise (avec prudence)
- Générateur de Lettres (ruling/rachat)
- Module PC (Checklist)

## 5) Notes "Suisse" à intégrer
- Retraits échelonnés: UBS explique l'intérêt fiscal via progressivité cantonale, mais mentionne aussi que les autorités cantonales peuvent considérer certains cas comme optimisation abusive; donc wording prudent nécessaire.
- OECD/INFE cite explicitement "just-in-time information" et l'usage de techniques inspirées des behavioral insights (dont gamification) — ce qui justifie vos inserts didactiques tant qu'ils restent éthiques et orientés action.
- Pratique FINMA: attention à l'"impression de bonne foi" et à la transparence sur rétrocessions/compensations; d'où la nécessité de disclaimers, hypothèses, et disclosure.

## 6) Références
- [OECD/INFE Guidance on Digital Delivery of Financial Education](https://www.oecd.org/en/publications/2022/04/oecd-infe-guidance-on-digital-delivery-of-financial-education_367fa011.html)
- [FINMA Circular on Rules of Conduct](https://www.homburger.ch/en/insights/finma-circular-duties-of-conduct-under-finsa-finso)
- [UBS Staggered Withdrawals](https://www.ubs.com/ch/en/services/guide/pension/articles/reduce-taxes-by-staggering-pay-outs.html)
