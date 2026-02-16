# Intégration Statut d'Emploi & 2e Pilier - Récapitulatif

## Vue d'ensemble

Ce document récapitule l'intégration du **statut d'emploi** et de la **présence du 2e pilier LPP** comme axes structurants du wizard Mint.

**Date de mise à jour** : 2026-01-11

---

## 🎯 Objectifs Atteints

### 1. Questions Pivot Ajoutées

Deux nouvelles questions **obligatoires** ont été ajoutées très tôt dans le wizard (section "Profil Minimal") :

#### `q_employment_status` (Question Pivot #1)
- **Position** : Juste après `q_children_count`, avant `q_international_complexity`
- **Type** : Choix unique
- **Options** :
  - Salarié
  - Indépendant
  - Mixte (salarié + indépendant) ⭐ NOUVEAU
  - Étudiant
  - Retraité
  - Autre
- **Impact** : Détermine toutes les branches conditionnelles suivantes

#### `q_has_2nd_pillar` (Question Pivot #2)
- **Position** : Juste après `q_employment_status`
- **Type** : Choix unique
- **Options** :
  - Oui
  - Non
  - Je ne sais pas
- **Conditions** : Affichée uniquement si `q_employment_status != student` et `!= retired`
- **Impact** : Détermine les plafonds 3a et les besoins de prévoyance

---

## 📋 Branches Conditionnelles Créées

### A) Salarié avec LPP
**Nouvelles questions** :
- `q_employee_lpp_certificate` : Certificat LPP disponible ?
- `q_employee_job_change_planned` : Changement d'employeur prévu ?
- `q_employee_job_change_date` : Date prévue du changement ?

**Plafond 3a** : CHF 7'258/an (2025)

**Timeline items créés** :
- Rappel 30 jours avant changement : "Préparer transfert LPP + mise à jour 3a"
- Annuel (après réception certificat LPP) : "Évaluer potentiel rachat LPP"

### B) Indépendant sans LPP
**Nouvelles questions** :
- `q_self_employed_legal_form` : Forme juridique (raison individuelle / Sàrl / SA / autre)
- `q_self_employed_net_income` : Revenu net annuel (pour calcul 20% 3a)
- `q_self_employed_voluntary_lpp` : Affiliation LPP volontaire ?
- `q_self_employed_protection_gap` : Message d'information sur la couverture

**Plafond 3a** : 20% du revenu net, max CHF 36'288/an (2025)

**Timeline items créés** :
- Annuel (décembre) : "Optimiser montant 3a (20% net, plafond)"
- Annuel : "Revoir couverture protection (décès/invalidité)"
- Tous les 2 ans : "Évaluer opportunité affiliation LPP volontaire"

### C) Mixte (Salarié + Indépendant)
**Nouvelles questions** :
- `q_mixed_primary_activity` : Activité principale (salariée ou indépendante)
- `q_mixed_employee_has_lpp` : Caisse LPP via activité salariée ?
- `q_mixed_self_employed_net_income` : Revenu net de l'activité indépendante
- `q_mixed_3a_calculation_note` : Message d'information sur le calcul

**Plafond 3a** : Dépend de l'activité principale et de la présence LPP
- Si LPP via emploi salarié : CHF 7'258/an
- Si pas de LPP : 20% du revenu net total, max CHF 36'288/an

**Timeline items créés** :
- Annuel (novembre) : "Vérifier calcul correct plafond 3a (statut mixte)"
- Annuel : "Bilan fiscal complexe (revenus multiples)"

---

## 🔄 Événements de Vie Ajoutés

Quatre nouveaux types d'événements ont été ajoutés à l'enum `LifeEventType` :

### 1. `selfEmployment` (Début activité indépendante)
**Questions delta** :
- Forme juridique
- Revenu net estimé
- As-tu quitté une caisse LPP ?
- Solution LPP volontaire envisagée ?
- Couverture décès/invalidité en place ?

**Timeline items** :
- "Mettre à jour prévoyance (LPP/3a) suite changement de statut" (30 jours)
- "Évaluer couverture protection (décès/invalidité)" (60 jours)
- "Rappel annuel (décembre) : optimiser montant 3a (20% net, plafond)" (récurrent)

### 2. `employmentStatusChange` (Changement de statut)
**Questions delta** :
- Nouveau statut (salarié → indépendant ou inverse)
- Date effective du changement
- Impact sur LPP ?
- Impact sur revenus ?

**Timeline items** :
- "Mettre à jour prévoyance (LPP/3a)" (30 jours)
- "Revoir couverture assurances" (60 jours)
- "Bilan fiscal suite changement statut" (90 jours)

### 3. `lppAffiliation` (Affiliation à une caisse LPP)
**Questions delta** :
- Type d'affiliation (employeur / volontaire)
- Date d'affiliation
- Certificat LPP reçu ?

**Timeline items** :
- "Mettre à jour plafond 3a (passage à CHF 7'258)" (immédiat)
- "Upload certificat LPP" (30 jours)

### 4. `lppDisaffiliation` (Sortie d'une caisse LPP)
**Questions delta** :
- Raison de la sortie
- Capital LPP à transférer ?
- Nouvelle activité ?

**Timeline items** :
- "Mettre à jour plafond 3a (passage à 20% revenu net)" (immédiat)
- "Évaluer couverture protection" (30 jours)

---

## 📊 Plafonds 3a Centralisés

Un nouveau fichier `PILLAR_3A_LIMITS.md` a été créé pour centraliser tous les plafonds 3a par année et par statut.

**Contenu** :
- Tableaux des plafonds 2023-2026
- Règles de calcul détaillées
- Format JSON pour l'implémentation
- Fonction de calcul (pseudo-code)
- Sources et références

**Avantages** :
- Maintenance facilitée (un seul endroit à mettre à jour chaque année)
- Cohérence garantie dans toute l'application
- Documentation claire pour les développeurs

---

## 🔧 Modifications Techniques

### Fichiers Modifiés

#### 1. `docs/WIZARD_SPEC.md`
**Changements** :
- Ajout d'une section "Axes Structurants : Statut d'Emploi & 2e Pilier"
- Mise à jour de la section "B) Profil Minimal" (7 → 9 questions)
- Mise à jour de la section "I) Fiscalité & Administratif" (3 → 2 questions)
- Mise à jour du total de questions (~60 → ~65)

#### 2. `docs/WIZARD_QUESTIONS_SPEC.md`
**Changements** :
- Modification de `q_employment_status` (ajout option "Mixte", tags "pivot")
- Ajout de `q_has_2nd_pillar` (nouvelle question pivot)
- Modification de `q_has_3a` (subtitle dynamique selon statut)
- Ajout section "1B. Branches Spécifiques par Statut d'Emploi"
  - 3 nouvelles questions pour salariés avec LPP
  - 4 nouvelles questions pour indépendants sans LPP
  - 4 nouvelles questions pour statut mixte
- Ajout de 4 nouveaux événements de vie dans l'enum `LifeEventType`
- Ajout de détails pour chaque événement lié au statut d'emploi
- Mise à jour des règles de timeline avec rappels spécifiques par statut

#### 3. `docs/PILLAR_3A_LIMITS.md` (NOUVEAU)
**Contenu** :
- Plafonds 3a 2023-2026 par statut et condition LPP
- Règles de calcul détaillées
- Format JSON pour l'implémentation
- Fonction de calcul (pseudo-code)
- Sources et références

---

## 🎨 Impact UX

### Progressive Disclosure Améliorée

Le wizard adapte maintenant dynamiquement les questions selon le statut d'emploi :

**Exemple 1 : Salarié avec LPP**
1. Questions pivot → Salarié + Oui LPP
2. Questions spécifiques salariés (certificat LPP, changement employeur)
3. Question 3a avec plafond CHF 7'258
4. Pas de questions sur forme juridique ou revenu net indépendant

**Exemple 2 : Indépendant sans LPP**
1. Questions pivot → Indépendant + Non LPP
2. Questions spécifiques indépendants (forme juridique, revenu net)
3. Question 3a avec plafond 20% revenu net (max CHF 36'288)
4. Message d'alerte sur couverture protection
5. Pas de questions sur certificat LPP ou changement employeur

**Exemple 3 : Mixte**
1. Questions pivot → Mixte
2. Questions pour déterminer activité principale et présence LPP
3. Questions sur revenus des deux activités
4. Message d'information sur calcul complexe plafond 3a
5. Pas de questions redondantes

### Nombre de Questions Affichées

| Statut | Avec LPP | Sans LPP | Questions Supplémentaires |
|--------|----------|----------|---------------------------|
| Salarié | ✅ | ❌ | +3 (certificat, changement) |
| Salarié | ❌ | ✅ | +0 (rare) |
| Indépendant | ✅ | ❌ | +2 (forme, LPP volontaire) |
| Indépendant | ❌ | ✅ | +4 (forme, revenu, LPP volontaire, protection) |
| Mixte | ✅ | ❌ | +4 (activité principale, LPP, revenus, note) |
| Mixte | ❌ | ✅ | +4 (activité principale, LPP, revenus, note) |

**Impact total** : +0 à +4 questions selon le profil, mais toujours pertinentes et ciblées.

---

## 📅 Timeline Proactive

### Rappels Automatiques Créés

#### Pour Salariés avec LPP
- **Avant changement d'emploi** (30 jours) : "Préparer transfert LPP + mise à jour 3a"
- **Annuel** : "Évaluer potentiel rachat LPP"
- **Décembre** : "Optimiser versement 3a (max CHF 7'258)"

#### Pour Indépendants sans LPP
- **Décembre** : "Optimiser montant 3a (20% net, max CHF 36'288)"
- **Annuel** : "Revoir couverture protection (décès/invalidité)"
- **Tous les 2 ans** : "Évaluer opportunité affiliation LPP volontaire"

#### Pour Mixtes
- **Novembre** : "Vérifier calcul correct plafond 3a (statut mixte)"
- **Annuel** : "Bilan fiscal complexe (revenus multiples)"

---

## ✅ Checklist d'Implémentation

### Phase 1 : Modèles de Données ✅
- [x] Ajouter option "mixed" à l'enum `EmploymentStatus`
- [x] Créer champ `has2ndPillar` (bool?) dans le profil utilisateur
- [x] Ajouter nouveaux événements de vie à l'enum `LifeEventType`

### Phase 2 : Questions Wizard ✅
- [x] Modifier `q_employment_status` (ajouter "Mixte")
- [x] Créer `q_has_2nd_pillar`
- [x] Créer 11 nouvelles questions conditionnelles (3 salariés + 4 indépendants + 4 mixtes)
- [x] Modifier `q_has_3a` pour subtitle dynamique

### Phase 3 : Logique Conditionnelle ⏳
- [ ] Implémenter fonction `dynamicSubtitle3a()`
- [ ] Implémenter conditions d'affichage pour toutes les nouvelles questions
- [ ] Tester tous les parcours (salarié/indépendant/mixte × avec/sans LPP)

### Phase 4 : Calcul Plafonds 3a ⏳
- [ ] Créer fichier de configuration JSON avec plafonds par année
- [ ] Implémenter fonction `calculate3aLimit()`
- [ ] Intégrer calcul dans le moteur de recommandations
- [ ] Afficher plafond correct dans l'UI selon le profil

### Phase 5 : Timeline & Événements ⏳
- [ ] Créer delta-sessions pour les 4 nouveaux événements
- [ ] Implémenter création automatique de timeline items selon le statut
- [ ] Tester rappels spécifiques (salariés vs indépendants vs mixtes)

### Phase 6 : Tests & Validation ⏳
- [ ] Tests unitaires pour `calculate3aLimit()`
- [ ] Tests d'intégration pour tous les parcours wizard
- [ ] Tests E2E pour événements de vie
- [ ] Validation avec cas réels (3-5 profils types)

---

## 🚀 Prochaines Étapes

1. **Implémenter la logique conditionnelle** dans le wizard Flutter
2. **Créer le fichier JSON de configuration** des plafonds 3a
3. **Développer la fonction de calcul** du plafond 3a
4. **Créer les delta-sessions** pour les événements de vie
5. **Tester avec des profils réels** (salarié, indépendant, mixte)
6. **Documenter les cas limites** (ex: mixte avec LPP partielle)

---

## 📚 Références

- `docs/WIZARD_SPEC.md` : Spécification générale du wizard
- `docs/WIZARD_QUESTIONS_SPEC.md` : Spécification détaillée des questions
- `docs/PILLAR_3A_LIMITS.md` : Plafonds 3a par année et statut
- [OFAS - Prévoyance professionnelle](https://www.bsv.admin.ch/)
- [AFC - Pilier 3a](https://www.estv.admin.ch/)

---

**Document créé le** : 2026-01-11  
**Dernière mise à jour** : 2026-01-11  
**Auteur** : Antigravity (Google Deepmind)
