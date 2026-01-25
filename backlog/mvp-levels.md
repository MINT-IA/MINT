# Backlog MVP — Didactic Inserts & Simulators CH

Référence: [ADR-CH-EDU-SIMULATORS](/decisions/ADR-CH-EDU-SIMULATORS.md)

---

## Niveau 1.0 — Budget & Emergency Fund (Immediate This Year)
**Status**: Implemented (Standalone local module)
**Questions**: `q_pay_frequency`, `q_net_income_period_chf`, `q_housing_cost_period_chf`, `q_debt_payments_period_chf`, `q_budget_style`
**User Stories**:
- [x] US-1.0.1: Wizard avec input par fréquence (mois/semaine) pour plus de flexibilité.
- [x] US-1.0.2: Calculateur Available = Revenu - Logement - Dettes.
- [x] US-1.0.3: UI avec Slider pour répartir le disponible (Variables vs Futur).
- [x] US-1.0.4: Safe Mode: Si dettes > 0 ou variables=0, Callout Warning + Reco Report "Dette".

## Niveau 1 — Wizard Inserts (Priorité Absolue)

### 1.1 Insert 3a + Fiscalité
**Question**: `q_has_3a`, `q_3a_annual_amount`
**User Stories**:
- [ ] US-1.1.1: En tant qu'utilisateur répondant à "As-tu un 3a ?", je vois un mini-simulateur montrant l'économie fiscale potentielle avec des curseurs (revenu, taux estimé).
- [ ] US-1.1.2: Le simulateur affiche une fourchette d'économie (pas un montant exact) avec hypothèses visibles.

### 1.2 Insert LPP Pivot
**Question**: `q_has_pension_fund`
**User Stories**:
- [ ] US-1.2.1: En tant qu'utilisateur répondant à "Es-tu affilié LPP ?", je vois un schéma expliquant la différence de plafond 3a (CHF 7'258 vs 20% du revenu).
- [ ] US-1.2.2: Le schéma mentionne que "sans LPP" concerne principalement les indépendants et temps partiels.

### 1.3 Insert Fonds d'urgence
**Question**: `q_emergency_fund` (à créer)
**User Stories**:
- [ ] US-1.3.1: En tant qu'utilisateur, je vois un calculateur "3-6 mois de charges" basé sur mes dépenses fixes renseignées.
- [ ] US-1.3.2: Le résultat montre une cible en CHF avec un indicateur de progression.

### 1.4 Insert Hypothèque Fixe vs SARON
**Question**: `q_mortgage_type`
**User Stories**:
- [ ] US-1.4.1: En tant que propriétaire, je vois un comparateur neutre Fixe vs SARON avec avantages/inconvénients.
- [ ] US-1.4.2: Le comparateur ne recommande pas un type mais explique les risques de chaque option.

### 1.5 Insert Leasing + Crédit Conso
**Questions**: `q_has_leasing`, `q_has_consumer_credit`
**User Stories**:
- [ ] US-1.5.1: En tant qu'utilisateur avec leasing/crédit, je vois le coût total réel (capital + intérêts) de mon engagement.
- [ ] US-1.5.2: L'insert propose une action "Rembourser en priorité" si Safe Mode actif.

---

## Niveau 2 — Rapport (Graphiques)

### 2.1 Graphe Évolution Patrimoine
**User Stories**:
- [ ] US-2.1.1: Le rapport final affiche un graphique "avec optimisation" vs "sans" sur 10/20/30 ans.
- [ ] US-2.1.2: Le graphique utilise des bandes d'incertitude (pas de courbe unique).

### 2.2 Graphe Timeline
**User Stories**:
- [ ] US-2.2.1: Le rapport affiche une frise chronologique des échéances clés (3a décembre, hypothèque, etc.).

---

## Niveau 3 — Phase 2 (Après MVP)

### 3.1 Retrait 3a Échelonné
**Conditions**: Age 50+, q_has_3a == yes
**User Stories**:
- [ ] US-3.1.1: Simulateur montrant l'économie fiscale du retrait sur plusieurs années.
- [ ] US-3.1.2: Disclaimer obligatoire sur variabilité cantonale et risque d'optimisation abusive.

### 3.2 Rachat LPP
**Conditions**: Age 35+, LPP certificate uploaded
**User Stories**:
- [ ] US-3.2.1: Calculateur de potentiel de rachat basé sur le certificat.
- [ ] US-3.2.2: Avertissement que le rachat bloque les fonds jusqu'à la retraite.

### 3.3 Franchise LAMal Optimale
**User Stories**:
- [ ] US-3.3.1: Calculateur comparant franchise 300 vs 2500 selon profil santé.
- [ ] US-3.3.2: Prudence: ne pas promettre d'économies, montrer les scénarios.

---

## Critères de Validation Globaux
- [ ] Chaque insert a un disclaimer visible
- [ ] Aucun taux marginal exact (uniquement fourchettes)
- [ ] Aucune promesse d'économie fiscale garantie
- [ ] Hypothèses explicites sur chaque simulation
- [ ] Partner handoff avec disclosure obligatoire
