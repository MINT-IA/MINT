# 📚 Documentation - Intégration Statut d'Emploi & 2e Pilier

## Vue d'ensemble

Cette documentation complète décrit l'intégration du **statut d'emploi** (salarié vs indépendant) et de la **présence du 2e pilier LPP** comme axes structurants du wizard Mint.

**Date de création** : 2026-01-11  
**Version** : 1.0  
**Auteur** : Antigravity (Google Deepmind)

---

## 📂 Fichiers de Documentation

### 1. **WIZARD_SPEC.md** (Mis à jour)
**Description** : Spécification générale du wizard onboarding

**Contenu** :
- ✅ Section "Axes Structurants : Statut d'Emploi & 2e Pilier"
- ✅ Mise à jour de la structure du wizard (9 questions dans "Profil Minimal")
- ✅ Explication des questions pivot et leurs impacts
- ✅ Branches de questions spécifiques par statut
- ✅ Effets sur la timeline proactive

**Public cible** : Product Managers, Designers, Développeurs

---

### 2. **WIZARD_QUESTIONS_SPEC.md** (Mis à jour)
**Description** : Spécification détaillée de toutes les questions du wizard

**Contenu** :
- ✅ Modification de `q_employment_status` (ajout option "Mixte")
- ✅ Ajout de `q_has_2nd_pillar` (nouvelle question pivot)
- ✅ Section "1B. Branches Spécifiques par Statut d'Emploi"
  - 3 questions pour salariés avec LPP
  - 4 questions pour indépendants sans LPP
  - 4 questions pour statut mixte
- ✅ Mise à jour de `q_has_3a` (subtitle dynamique)
- ✅ Ajout de 4 nouveaux événements de vie
- ✅ Détails des delta-sessions pour chaque événement
- ✅ Règles de timeline spécifiques par statut

**Public cible** : Développeurs, Product Managers

---

### 3. **PILLAR_3A_LIMITS.md** (Nouveau)
**Description** : Référence centralisée des plafonds 3a par année et statut

**Contenu** :
- ✅ Tableaux des plafonds 2023-2026
- ✅ Règles de calcul détaillées
- ✅ Format JSON pour l'implémentation
- ✅ Fonction de calcul (pseudo-code)
- ✅ Sources et références officielles

**Public cible** : Développeurs, Fiscalistes, Product Managers

**Utilité** :
- Maintenance facilitée (un seul endroit à mettre à jour chaque année)
- Cohérence garantie dans toute l'application
- Documentation claire pour les développeurs

---

### 4. **EMPLOYMENT_STATUS_INTEGRATION.md** (Nouveau)
**Description** : Récapitulatif complet de l'intégration

**Contenu** :
- ✅ Objectifs atteints
- ✅ Questions pivot ajoutées
- ✅ Branches conditionnelles créées (A, B, C)
- ✅ Événements de vie ajoutés (4 nouveaux)
- ✅ Impact UX (progressive disclosure)
- ✅ Timeline proactive (rappels automatiques)
- ✅ Checklist d'implémentation (6 phases)
- ✅ Prochaines étapes

**Public cible** : Product Managers, Tech Leads, Stakeholders

**Utilité** :
- Vision d'ensemble de l'intégration
- Suivi de l'avancement (checklist)
- Communication avec les stakeholders

---

### 5. **WIZARD_USER_JOURNEYS.md** (Nouveau)
**Description** : Exemples concrets de parcours utilisateur

**Contenu** :
- ✅ Parcours 1 : Sarah, Salariée avec LPP (23 questions)
- ✅ Parcours 2 : Marc, Indépendant sans LPP (27 questions)
- ✅ Parcours 3 : Julie, Statut Mixte (24 questions)
- ✅ Parcours 4 : Thomas, Indépendant avec LPP volontaire (28 questions)
- ✅ Comparaison des parcours
- ✅ Enseignements clés
- ✅ Notes d'implémentation (fonctions, conditions)

**Public cible** : Designers, Product Managers, Développeurs

**Utilité** :
- Comprendre l'expérience utilisateur concrète
- Valider la logique conditionnelle
- Tester les parcours avec des profils réels

---

### 6. **IMPLEMENTATION_GUIDE.md** (Nouveau)
**Description** : Guide technique complet pour les développeurs

**Contenu** :
- ✅ Architecture (modèles de données)
- ✅ Configuration des plafonds 3a (JSON + classe)
- ✅ Logique conditionnelle du wizard
- ✅ Création de timeline items
- ✅ Tests unitaires
- ✅ Checklist d'implémentation détaillée

**Public cible** : Développeurs Flutter/Dart

**Utilité** :
- Code prêt à l'emploi (copy-paste)
- Tests unitaires inclus
- Checklist pour ne rien oublier

---

## 🎯 Résumé des Changements

### Questions Ajoutées
| ID | Type | Statut | Description |
|----|------|--------|-------------|
| `q_has_2nd_pillar` | Pivot | Tous (sauf étudiant/retraité) | Présence caisse LPP |
| `q_employee_lpp_certificate` | Conditionnelle | Salarié + LPP | Certificat LPP disponible |
| `q_employee_job_change_planned` | Conditionnelle | Salarié | Changement employeur prévu |
| `q_employee_job_change_date` | Conditionnelle | Salarié (si changement) | Date du changement |
| `q_self_employed_legal_form` | Conditionnelle | Indépendant | Forme juridique |
| `q_self_employed_net_income` | Conditionnelle | Indépendant - LPP | Revenu net annuel |
| `q_self_employed_voluntary_lpp` | Conditionnelle | Indépendant - LPP | Affiliation LPP volontaire |
| `q_self_employed_protection_gap` | Info | Indépendant - LPP | Alerte couverture |
| `q_mixed_primary_activity` | Conditionnelle | Mixte | Activité principale |
| `q_mixed_employee_has_lpp` | Conditionnelle | Mixte | LPP via emploi salarié |
| `q_mixed_self_employed_net_income` | Conditionnelle | Mixte | Revenu net indépendant |
| `q_mixed_3a_calculation_note` | Info | Mixte | Note calcul 3a |

**Total** : 12 nouvelles questions (dont 2 messages d'information)

### Événements de Vie Ajoutés
| Événement | Description | Timeline Items Créés |
|-----------|-------------|----------------------|
| `employmentStatusChange` | Changement de statut | 3 items (30, 60, 90 jours) |
| `lppAffiliation` | Affiliation LPP | 2 items (immédiat, 30 jours) |
| `lppDisaffiliation` | Sortie LPP | 2 items (immédiat, 30 jours) |

**Total** : 3 nouveaux événements (+ `selfEmployment` déjà existant mais enrichi)

### Plafonds 3a
| Statut | Condition LPP | Plafond 2025 | Règle |
|--------|---------------|--------------|-------|
| Salarié | Avec | CHF 7'258 | Fixe |
| Salarié | Sans | CHF 36'288 | 20% net, plafonné |
| Indépendant | Avec | CHF 7'258 | Fixe |
| Indépendant | Sans | CHF 36'288 | 20% net, plafonné |
| Mixte | Avec | CHF 7'258 | Fixe |
| Mixte | Sans | CHF 36'288 | 20% net, plafonné |

---

## 📊 Impact sur le Wizard

### Nombre de Questions Affichées

| Profil | Questions Noyau | Questions Spécifiques | Total |
|--------|----------------|----------------------|-------|
| Salarié + LPP | ~21 | +2 | ~23 |
| Salarié - LPP | ~21 | +0 | ~21 |
| Indépendant + LPP | ~21 | +2 | ~23 |
| Indépendant - LPP | ~21 | +4 | ~25 |
| Mixte + LPP | ~21 | +4 | ~25 |
| Mixte - LPP | ~21 | +4 | ~25 |

**Moyenne** : 24 questions (au lieu de 25-30 avant optimisation)

### Progressive Disclosure
- ✅ Chaque question supplémentaire est **pertinente et ciblée**
- ✅ Les utilisateurs ne voient **jamais de questions inutiles**
- ✅ Le parcours s'adapte **dynamiquement** selon les réponses

---

## 🚀 Prochaines Étapes

### Phase 1 : Implémentation Backend (Priorité Haute)
- [ ] Créer fichier JSON `pillar_3a_limits.json`
- [ ] Implémenter classe `Pillar3aCalculator`
- [ ] Ajouter champs `has2ndPillar`, `legalForm`, etc. au modèle `UserProfile`
- [ ] Écrire tests unitaires

**Durée estimée** : 2-3 jours

### Phase 2 : Implémentation Frontend (Priorité Haute)
- [ ] Modifier `q_employment_status` (ajouter option "Mixte")
- [ ] Créer `q_has_2nd_pillar` et 11 nouvelles questions conditionnelles
- [ ] Implémenter logique conditionnelle (`WizardQuestionConditions`)
- [ ] Implémenter subtitle dynamique pour `q_has_3a`

**Durée estimée** : 3-4 jours

### Phase 3 : Timeline & Événements (Priorité Moyenne)
- [ ] Implémenter `TimelineItemFactory`
- [ ] Créer delta-sessions pour nouveaux événements
- [ ] Tester création automatique de timeline items

**Durée estimée** : 2-3 jours

### Phase 4 : Tests & Validation (Priorité Haute)
- [ ] Tests unitaires (backend)
- [ ] Tests d'intégration (wizard)
- [ ] Tests E2E (parcours complets)
- [ ] Validation avec 5 profils réels

**Durée estimée** : 3-4 jours

### Phase 5 : Documentation Utilisateur (Priorité Basse)
- [ ] Créer FAQ sur statut d'emploi et plafonds 3a
- [ ] Ajouter tooltips explicatifs dans l'UI
- [ ] Créer guide "Comprendre mon plafond 3a"

**Durée estimée** : 1-2 jours

**Durée totale estimée** : 11-16 jours

---

## 📚 Ressources Externes

### Références Officielles
- [Office fédéral des assurances sociales (OFAS)](https://www.bsv.admin.ch/)
- [Administration fédérale des contributions (AFC)](https://www.estv.admin.ch/)
- [Prévoyance professionnelle - Lois et ordonnances](https://www.admin.ch/gov/fr/accueil/droit-federal/recueil-systematique.html)

### Articles et Guides
- [Pilier 3a : Guide complet 2025](https://www.moneyland.ch/fr/pilier-3a-guide)
- [Indépendants : Prévoyance et fiscalité](https://www.kmu.admin.ch/kmu/fr/home/savoir-pratique/finances/assurances-prevoyance.html)
- [LPP volontaire pour indépendants](https://www.ch.ch/fr/travail/prevoyance-professionnelle/prevoyance-professionnelle-pour-independants/)

---

## 🤝 Contribution

### Comment Mettre à Jour cette Documentation

1. **Plafonds 3a** : Mettre à jour `PILLAR_3A_LIMITS.md` chaque année (décembre)
2. **Nouvelles questions** : Ajouter dans `WIZARD_QUESTIONS_SPEC.md`
3. **Nouveaux événements** : Mettre à jour `WIZARD_QUESTIONS_SPEC.md` (section 4)
4. **Nouveaux parcours** : Ajouter dans `WIZARD_USER_JOURNEYS.md`
5. **Code technique** : Mettre à jour `IMPLEMENTATION_GUIDE.md`

### Processus de Validation

1. **Product Manager** : Valide les specs fonctionnelles
2. **Designer** : Valide l'UX et les parcours utilisateur
3. **Tech Lead** : Valide l'architecture et le code
4. **Fiscaliste** : Valide les plafonds et règles fiscales
5. **QA** : Teste tous les parcours

---

## 📞 Contact

Pour toute question sur cette documentation :
- **Product Manager** : [Nom]
- **Tech Lead** : [Nom]
- **Auteur de la doc** : Antigravity (Google Deepmind)

---

## 📝 Historique des Versions

| Version | Date | Auteur | Changements |
|---------|------|--------|-------------|
| 1.0 | 2026-01-11 | Antigravity | Création initiale de la documentation complète |

---

**Dernière mise à jour** : 2026-01-11  
**Prochaine révision prévue** : 2026-12-01 (mise à jour plafonds 3a 2027)
