# Exemples de Parcours Wizard - Statut d'Emploi & 2e Pilier

## Vue d'ensemble

Ce document présente des exemples concrets de parcours utilisateur dans le wizard Mint, illustrant comment les questions s'adaptent selon le **statut d'emploi** et la **présence du 2e pilier LPP**.

---

## 📋 Parcours 1 : Sarah, Salariée avec LPP

### Profil
- **Nom** : Sarah Müller
- **Âge** : 32 ans
- **Canton** : Vaud
- **Situation** : Célibataire
- **Emploi** : Employée dans une entreprise de tech (contrat CDI)
- **LPP** : Oui, via employeur
- **Revenu net** : CHF 6'500/mois
- **Objectif** : Optimiser sa prévoyance et payer moins d'impôts

### Questions Posées (Ordre Chronologique)

#### Noyau Commun
1. ✅ `q_canton` → **Vaud**
2. ✅ `q_birth_year` → **1994**
3. ✅ `q_household_type` → **Seul(e)**
4. ✅ `q_employment_status` → **Salarié** ⭐
5. ✅ `q_has_2nd_pillar` → **Oui** ⭐
6. ✅ `q_international_complexity` → **Non**
7. ✅ `q_primary_goal` → **Optimiser ma prévoyance (LPP/3a)**
8. ✅ `q_time_horizon` → **3–10 ans**
9. ✅ `q_risk_preference` → **Équilibré**
10. ✅ `q_net_income_monthly` → **CHF 6'500**
11. ✅ `q_savings_monthly` → **CHF 1'000**
12. ✅ `q_has_13th_salary` → **Oui**
13. ✅ `q_13th_salary_month` → **Décembre**

#### Branche Salarié avec LPP ⭐
14. ✅ `q_employee_lpp_certificate` → **Oui** (upload prévu)
15. ✅ `q_employee_job_change_planned` → **Non**

#### Logement
16. ✅ `q_housing_status` → **Locataire**
17. ✅ `q_rent_monthly` → **CHF 1'800**

#### Prévoyance
18. ✅ `q_has_3a` → **Oui**
   - **Subtitle affiché** : "Le 3a te permet de déduire jusqu'à CHF 7'258/an (2025) de tes impôts."
19. ✅ `q_3a_type` → **Bancaire**
20. ✅ `q_3a_annual_contribution` → **CHF 7'000**

#### Dettes
21. ✅ `q_has_leasing` → **Non**
22. ✅ `q_has_consumer_credit` → **Non**
23. ✅ `q_credit_card_minimum` → **Jamais**

### Timeline Items Créés
- 📅 **Décembre 2026** : "Optimiser versement 3a (après 13e salaire)" - Récurrent annuel
- 📅 **Annuel** : "Évaluer potentiel rachat LPP (après réception certificat)"
- 📅 **Annuel** : "Revue plan + bénéficiaires/assurances"

### Recommandations Générées
1. ✅ **Maximiser 3a** : "Tu verses CHF 7'000/an, tu peux encore ajouter CHF 258 pour maximiser la déduction fiscale."
2. ✅ **Rachat LPP** : "Selon ton certificat LPP, tu as un potentiel de rachat de ~CHF 15'000. Cela pourrait réduire tes impôts de ~CHF 3'000."
3. ✅ **Fonds d'urgence** : "Avec CHF 1'000/mois d'épargne, construis d'abord un fonds d'urgence de 3-6 mois (CHF 15'000-30'000)."

**Total questions affichées** : 23 (dont 2 spécifiques salariés avec LPP)

---

## 📋 Parcours 2 : Marc, Indépendant sans LPP

### Profil
- **Nom** : Marc Dubois
- **Âge** : 38 ans
- **Canton** : Genève
- **Situation** : Marié, 1 enfant
- **Emploi** : Consultant indépendant (Sàrl)
- **LPP** : Non
- **Revenu net** : CHF 90'000/an
- **Objectif** : Optimiser fiscalité et sécuriser sa famille

### Questions Posées (Ordre Chronologique)

#### Noyau Commun
1. ✅ `q_canton` → **Genève**
2. ✅ `q_birth_year` → **1988**
3. ✅ `q_household_type` → **Famille (enfants)**
4. ✅ `q_children_count` → **1 enfant**
5. ✅ `q_employment_status` → **Indépendant** ⭐
6. ✅ `q_has_2nd_pillar` → **Non** ⭐
7. ✅ `q_international_complexity` → **Non**
8. ✅ `q_primary_goal` → **Payer moins d'impôts (3a + bases)**
9. ✅ `q_time_horizon` → **3–10 ans**
10. ✅ `q_risk_preference` → **Stabilité**
11. ✅ `q_net_income_monthly` → **CHF 7'500** (approximatif)
12. ✅ `q_savings_monthly` → **CHF 1'500**
13. ✅ `q_has_13th_salary` → **Non**

#### Branche Indépendant sans LPP ⭐
14. ✅ `q_self_employed_legal_form` → **Sàrl**
15. ✅ `q_self_employed_net_income` → **CHF 90'000/an**
16. ✅ `q_self_employed_voluntary_lpp` → **Non**
17. ℹ️ `q_self_employed_protection_gap` → Message d'alerte affiché

#### Logement
18. ✅ `q_housing_status` → **Propriétaire**
19. ✅ `q_mortgage_total` → **CHF 650'000**
20. ✅ `q_mortgage_type` → **Taux fixe**
21. ✅ `q_mortgage_fixed_end_date` → **06/2028**

#### Prévoyance
22. ✅ `q_has_3a` → **Oui**
   - **Subtitle affiché** : "Le 3a te permet de déduire jusqu'à 20% de ton revenu net (max CHF 36'288/an, 2025)."
23. ✅ `q_3a_type` → **Bancaire**
24. ✅ `q_3a_annual_contribution` → **CHF 15'000**
25. ✅ `q_has_life_insurance` → **Oui**

#### Famille
26. ✅ `q_family_children_ages` → **0–3 ans**
27. ✅ `q_family_childcare_costs` → **Oui**

### Timeline Items Créés
- 📅 **Décembre 2026** : "Optimiser montant 3a (20% net = CHF 18'000, max CHF 36'288)" - Récurrent annuel
- 📅 **Annuel** : "Revoir couverture protection (décès/invalidité)"
- 📅 **Tous les 2 ans** : "Évaluer opportunité affiliation LPP volontaire"
- 📅 **Avril 2028** : "Renégocier hypothèque (120 jours avant échéance)"
- 📅 **Annuel** : "Revue plan + bénéficiaires/assurances"

### Recommandations Générées
1. ⚠️ **Optimiser 3a** : "Tu verses CHF 15'000/an, mais tu peux déduire jusqu'à CHF 18'000 (20% de CHF 90'000). Cela pourrait réduire tes impôts de ~CHF 1'200 supplémentaires."
2. ⚠️ **Protection critique** : "Sans LPP, tu n'as pas de couverture décès/invalidité automatique. Avec une famille, c'est essentiel. Mint te recommande une assurance risque pur."
3. ✅ **LPP volontaire** : "Tu peux t'affilier volontairement à une caisse LPP. Avantages : couverture + déductions fiscales. Inconvénient : cotisations obligatoires."
4. ✅ **Hypothèque** : "Ton taux fixe expire en 06/2028. Mint te rappellera 120 jours avant pour comparer les offres."

**Total questions affichées** : 27 (dont 4 spécifiques indépendants sans LPP)

---

## 📋 Parcours 3 : Julie, Statut Mixte (Salariée + Indépendante)

### Profil
- **Nom** : Julie Renaud
- **Âge** : 29 ans
- **Canton** : Zurich
- **Situation** : Célibataire
- **Emploi principal** : Employée à 80% (design graphique)
- **Emploi secondaire** : Freelance (raison individuelle)
- **LPP** : Oui, via emploi principal
- **Revenu net salarié** : CHF 4'500/mois
- **Revenu net indépendant** : CHF 20'000/an
- **Objectif** : Optimiser fiscalité avec revenus multiples

### Questions Posées (Ordre Chronologique)

#### Noyau Commun
1. ✅ `q_canton` → **Zurich**
2. ✅ `q_birth_year` → **1997**
3. ✅ `q_household_type` → **Seul(e)**
4. ✅ `q_employment_status` → **Mixte (salarié + indépendant)** ⭐
5. ✅ `q_has_2nd_pillar` → **Oui** (via emploi salarié) ⭐
6. ✅ `q_international_complexity` → **Non**
7. ✅ `q_primary_goal` → **Payer moins d'impôts (3a + bases)**
8. ✅ `q_time_horizon` → **1–3 ans**
9. ✅ `q_risk_preference` → **Équilibré**
10. ✅ `q_net_income_monthly` → **CHF 4'500** (salarié uniquement)
11. ✅ `q_savings_monthly` → **CHF 800**
12. ✅ `q_has_13th_salary` → **Oui**
13. ✅ `q_13th_salary_month` → **Décembre**

#### Branche Mixte ⭐
14. ✅ `q_mixed_primary_activity` → **Activité salariée**
15. ✅ `q_mixed_employee_has_lpp` → **Oui**
16. ✅ `q_mixed_self_employed_net_income` → **CHF 20'000/an**
17. ℹ️ `q_mixed_3a_calculation_note` → Message d'information affiché

#### Logement
18. ✅ `q_housing_status` → **Locataire**
19. ✅ `q_rent_monthly` → **CHF 1'400**

#### Prévoyance
20. ✅ `q_has_3a` → **Oui**
   - **Subtitle affiché** : "Le 3a te permet de déduire jusqu'à CHF 7'258/an (2025) de tes impôts."
   - **Note** : Plafond basé sur activité principale (salariée) avec LPP
21. ✅ `q_3a_type` → **Bancaire**
22. ✅ `q_3a_annual_contribution` → **CHF 6'000**

#### Dettes
23. ✅ `q_has_leasing` → **Non**
24. ✅ `q_has_consumer_credit` → **Non**

### Timeline Items Créés
- 📅 **Décembre 2026** : "Optimiser versement 3a (après 13e salaire)" - Récurrent annuel
- 📅 **Novembre 2026** : "Vérifier calcul correct plafond 3a (statut mixte)" - Récurrent annuel
- 📅 **Annuel** : "Bilan fiscal complexe (revenus multiples)"
- 📅 **Annuel** : "Revue plan + bénéficiaires/assurances"

### Recommandations Générées
1. ✅ **Optimiser 3a** : "Tu verses CHF 6'000/an, tu peux encore ajouter CHF 1'258 pour maximiser la déduction fiscale (plafond CHF 7'258)."
2. ℹ️ **Statut mixte** : "Avec des revenus salariés + indépendants, ton plafond 3a est de CHF 7'258 (car activité principale salariée avec LPP). Si ton activité indépendante devient principale, le plafond pourrait changer."
3. ⚠️ **Fiscalité complexe** : "Avec des revenus multiples, ta déclaration fiscale est plus complexe. Mint te recommande de consulter un fiscaliste pour optimiser tes déductions."
4. ✅ **Fonds d'urgence** : "Avec des revenus variables (freelance), un fonds d'urgence de 6 mois est recommandé (CHF 12'000-15'000)."

**Total questions affichées** : 24 (dont 4 spécifiques statut mixte)

---

## 📋 Parcours 4 : Thomas, Indépendant avec LPP Volontaire

### Profil
- **Nom** : Thomas Weber
- **Âge** : 45 ans
- **Canton** : Berne
- **Situation** : Marié, 2 enfants
- **Emploi** : Architecte indépendant (raison individuelle)
- **LPP** : Oui, affiliation volontaire via fondation
- **Revenu net** : CHF 120'000/an
- **Objectif** : Préparer retraite et optimiser fiscalité

### Questions Posées (Ordre Chronologique)

#### Noyau Commun
1. ✅ `q_canton` → **Berne**
2. ✅ `q_birth_year` → **1981**
3. ✅ `q_household_type` → **Famille (enfants)**
4. ✅ `q_children_count` → **2 enfants**
5. ✅ `q_employment_status` → **Indépendant** ⭐
6. ✅ `q_has_2nd_pillar` → **Oui** (volontaire) ⭐
7. ✅ `q_international_complexity` → **Non**
8. ✅ `q_primary_goal` → **Préparer la retraite (plan clair)**
9. ✅ `q_time_horizon` → **10+ ans**
10. ✅ `q_risk_preference` → **Équilibré**
11. ✅ `q_net_income_monthly` → **CHF 10'000** (approximatif)
12. ✅ `q_savings_monthly` → **CHF 2'500**
13. ✅ `q_has_13th_salary` → **Non**

#### Branche Indépendant (avec LPP) ⭐
14. ✅ `q_self_employed_legal_form` → **Raison individuelle**
15. ✅ `q_self_employed_voluntary_lpp` → **Oui**
   - **Note** : Question affichée car statut indépendant, mais réponse "Oui" cohérente avec `q_has_2nd_pillar`

#### Logement
16. ✅ `q_housing_status` → **Propriétaire**
17. ✅ `q_mortgage_total` → **CHF 450'000**
18. ✅ `q_mortgage_type` → **Taux fixe**
19. ✅ `q_mortgage_fixed_end_date` → **12/2027**

#### Prévoyance
20. ✅ `q_has_3a` → **Oui**
   - **Subtitle affiché** : "Le 3a te permet de déduire jusqu'à CHF 7'258/an (2025) de tes impôts."
   - **Note** : Plafond fixe car affiliation LPP volontaire
21. ✅ `q_3a_type` → **Bancaire**
22. ✅ `q_3a_annual_contribution` → **CHF 7'258** (maximisé)
23. ✅ `q_has_lpp_certificate` → **Oui**
24. ✅ `q_has_life_insurance` → **Oui**

#### Tranche d'âge 36-49
25. ✅ `q_peak_lpp_buyback` → **Oui**
26. ✅ `q_peak_variable_income` → **Oui**

#### Famille
27. ✅ `q_family_children_ages` → **7–12 ans**, **13–18 ans**
28. ✅ `q_family_childcare_costs` → **Non**

### Timeline Items Créés
- 📅 **Décembre 2026** : "Optimiser versement 3a (max CHF 7'258)" - Récurrent annuel
- 📅 **Annuel** : "Évaluer potentiel rachat LPP (après réception certificat)"
- 📅 **Septembre 2027** : "Renégocier hypothèque (120 jours avant échéance)"
- 📅 **Novembre 2026** : "Bilan fiscal + stratégie 3a + rachat LPP" - Récurrent annuel
- 📅 **Annuel** : "Revue plan + bénéficiaires/assurances"

### Recommandations Générées
1. ✅ **3a maximisé** : "Bravo ! Tu maximises déjà ton 3a (CHF 7'258/an)."
2. ✅ **Rachat LPP** : "Avec ton affiliation LPP volontaire, tu as un potentiel de rachat de ~CHF 40'000. Cela pourrait réduire tes impôts de ~CHF 10'000."
3. ✅ **Retraite** : "À 45 ans, tu as 20 ans pour préparer ta retraite. Avec CHF 2'500/mois d'épargne, tu peux construire un capital confortable."
4. ℹ️ **LPP volontaire** : "Ton affiliation LPP volontaire te donne accès au plafond 3a fixe (CHF 7'258) au lieu de 20% du revenu net. C'est avantageux si ton revenu est élevé."

**Total questions affichées** : 28 (dont 2 spécifiques indépendants avec LPP)

---

## 📊 Comparaison des Parcours

| Critère | Sarah (Salarié+LPP) | Marc (Indép-LPP) | Julie (Mixte+LPP) | Thomas (Indép+LPP) |
|---------|---------------------|------------------|-------------------|---------------------|
| **Questions totales** | 23 | 27 | 24 | 28 |
| **Questions spécifiques** | +2 | +4 | +4 | +2 |
| **Plafond 3a** | CHF 7'258 | CHF 18'000 (20%) | CHF 7'258 | CHF 7'258 |
| **Timeline items** | 3 | 5 | 4 | 5 |
| **Complexité fiscale** | Faible | Moyenne | Moyenne | Élevée |
| **Focus protection** | Faible | **Élevé** ⚠️ | Moyen | Moyen |
| **Rachat LPP** | Oui | Non | Non | Oui |

---

## 🎯 Enseignements Clés

### 1. Progressive Disclosure Efficace
- Le nombre de questions varie de **23 à 28** selon le profil
- Chaque question supplémentaire est **pertinente et ciblée**
- Les utilisateurs ne voient **jamais de questions inutiles**

### 2. Plafonds 3a Correctement Calculés
- **Salarié avec LPP** : CHF 7'258 (fixe)
- **Indépendant sans LPP** : 20% du revenu net (max CHF 36'288)
- **Mixte avec LPP** : CHF 7'258 (basé sur activité principale)
- **Indépendant avec LPP volontaire** : CHF 7'258 (fixe)

### 3. Protection Adaptée au Statut
- **Salariés avec LPP** : Couverture automatique, focus sur optimisation
- **Indépendants sans LPP** : ⚠️ Alerte protection critique (décès/invalidité)
- **Mixtes** : Vérification couverture selon activité principale
- **Indépendants avec LPP volontaire** : Couverture OK, focus sur optimisation

### 4. Timeline Proactive
- **Rappels génériques** : Tous les profils (3a, bilan annuel)
- **Rappels spécifiques salariés** : Transfert LPP, rachat LPP
- **Rappels spécifiques indépendants** : Optimisation 3a (20%), protection, LPP volontaire
- **Rappels spécifiques mixtes** : Vérification calcul 3a, bilan fiscal complexe

---

## 📝 Notes d'Implémentation

### Fonction `dynamicSubtitle3a()`

```dart
String dynamicSubtitle3a(String employmentStatus, bool? has2ndPillar) {
  if (employmentStatus == 'employee' && has2ndPillar == true) {
    return "Le 3a te permet de déduire jusqu'à CHF 7'258/an (2025) de tes impôts.";
  } else if (employmentStatus == 'self_employed' && has2ndPillar == false) {
    return "Le 3a te permet de déduire jusqu'à 20% de ton revenu net (max CHF 36'288/an, 2025).";
  } else if (employmentStatus == 'mixed') {
    if (has2ndPillar == true) {
      return "Le 3a te permet de déduire jusqu'à CHF 7'258/an (2025) de tes impôts.";
    } else {
      return "Le 3a te permet de déduire jusqu'à 20% de ton revenu net (max CHF 36'288/an, 2025).";
    }
  } else if (employmentStatus == 'self_employed' && has2ndPillar == true) {
    return "Le 3a te permet de déduire jusqu'à CHF 7'258/an (2025) de tes impôts.";
  } else {
    return "Le 3a te permet de déduire une partie de tes impôts (plafond selon ton statut).";
  }
}
```

### Conditions d'Affichage

```dart
// Exemple pour q_employee_lpp_certificate
bool shouldShow_q_employee_lpp_certificate(Map<String, dynamic> answers) {
  return answers['q_employment_status'] == 'employee' && 
         answers['q_has_2nd_pillar'] == true;
}

// Exemple pour q_self_employed_net_income
bool shouldShow_q_self_employed_net_income(Map<String, dynamic> answers) {
  return answers['q_employment_status'] == 'self_employed' && 
         answers['q_has_2nd_pillar'] == false;
}

// Exemple pour q_mixed_primary_activity
bool shouldShow_q_mixed_primary_activity(Map<String, dynamic> answers) {
  return answers['q_employment_status'] == 'mixed';
}
```

---

**Document créé le** : 2026-01-11  
**Dernière mise à jour** : 2026-01-11  
**Auteur** : Antigravity (Google Deepmind)
