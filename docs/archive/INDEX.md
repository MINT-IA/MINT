# 📚 Index de la Documentation - Statut d'Emploi & 2e Pilier

**Dernière mise à jour** : 2026-01-11  
**Version** : 1.0

---

## 🎯 Par Rôle

### 👔 Pour les Stakeholders & Décideurs

**Commencez ici** :
1. **[EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md)** (10 min)
   - Objectif stratégique
   - Impact business & ROI
   - Recommandations de décision

**Ensuite** :
2. **[EMPLOYMENT_STATUS_SYNTHESIS.md](EMPLOYMENT_STATUS_SYNTHESIS.md)** (15 min)
   - Résumé complet des changements
   - Bénéfices pour les utilisateurs
   - Checklist d'implémentation

---

### 📋 Pour les Product Managers

**Commencez ici** :
1. **[EMPLOYMENT_STATUS_README.md](EMPLOYMENT_STATUS_README.md)** (10 min)
   - Vue d'ensemble de la documentation
   - Résumé des changements
   - Prochaines étapes

**Ensuite** :
2. **[WIZARD_SPEC.md](WIZARD_SPEC.md)** (15 min)
   - Structure générale du wizard
   - Axes structurants (statut d'emploi & 2e pilier)
   - Effets sur la timeline

3. **[WIZARD_QUESTIONS_SPEC.md](WIZARD_QUESTIONS_SPEC.md)** (30 min)
   - Spécification détaillée des 12 nouvelles questions
   - Branches conditionnelles
   - Événements de vie

4. **[WIZARD_USER_JOURNEYS.md](WIZARD_USER_JOURNEYS.md)** (20 min)
   - 4 parcours utilisateur détaillés
   - Comparaison des profils
   - Enseignements clés

---

### 🎨 Pour les Designers

**Commencez ici** :
1. **[WIZARD_USER_JOURNEYS.md](WIZARD_USER_JOURNEYS.md)** (20 min)
   - Exemples concrets de parcours
   - Nombre de questions par profil
   - Progressive disclosure

**Ensuite** :
2. **[WIZARD_FLOW_DIAGRAMS.md](WIZARD_FLOW_DIAGRAMS.md)** (15 min)
   - 7 diagrammes de flux ASCII
   - Visualisation de la logique conditionnelle
   - Branches par statut

3. **[WIZARD_QUESTIONS_SPEC.md](WIZARD_QUESTIONS_SPEC.md)** (30 min)
   - Textes des questions
   - Options de réponse
   - Messages d'information/alerte

---

### 💻 Pour les Développeurs

**Commencez ici** :
1. **[IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)** (45 min)
   - Architecture complète
   - Code prêt à l'emploi
   - Tests unitaires

**Ensuite** :
2. **[PILLAR_3A_LIMITS.md](PILLAR_3A_LIMITS.md)** (15 min)
   - Plafonds 3a 2023-2026
   - Format JSON pour configuration
   - Fonction de calcul

3. **[WIZARD_QUESTIONS_SPEC.md](WIZARD_QUESTIONS_SPEC.md)** (30 min)
   - IDs et types de questions
   - Conditions d'affichage
   - Règles de timeline

4. **[WIZARD_FLOW_DIAGRAMS.md](WIZARD_FLOW_DIAGRAMS.md)** (15 min)
   - Diagrammes de flux
   - Logique conditionnelle
   - Calcul plafonds 3a

---

### 🧪 Pour les QA / Testeurs

**Commencez ici** :
1. **[WIZARD_USER_JOURNEYS.md](WIZARD_USER_JOURNEYS.md)** (20 min)
   - 4 profils types à tester
   - Questions affichées par profil
   - Timeline items créés

**Ensuite** :
2. **[WIZARD_FLOW_DIAGRAMS.md](WIZARD_FLOW_DIAGRAMS.md)** (15 min)
   - Tous les parcours possibles
   - Branches conditionnelles
   - Cas limites

3. **[IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)** (section Tests, 15 min)
   - Tests unitaires à écrire
   - Tests d'intégration
   - Tests E2E

---

### 💰 Pour les Fiscalistes / Experts Métier

**Commencez ici** :
1. **[PILLAR_3A_LIMITS.md](PILLAR_3A_LIMITS.md)** (15 min)
   - Plafonds 3a par statut et année
   - Règles de calcul détaillées
   - Sources officielles

**Ensuite** :
2. **[WIZARD_QUESTIONS_SPEC.md](WIZARD_QUESTIONS_SPEC.md)** (30 min)
   - Questions fiscales posées
   - Logique de calcul
   - Messages d'information

---

## 📂 Par Type de Document

### 📊 Documents de Synthèse

| Fichier | Taille | Public | Temps Lecture |
|---------|--------|--------|---------------|
| **[EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md)** | 12 KB | Stakeholders | 10 min |
| **[EMPLOYMENT_STATUS_SYNTHESIS.md](EMPLOYMENT_STATUS_SYNTHESIS.md)** | 12 KB | Tous | 15 min |
| **[EMPLOYMENT_STATUS_README.md](EMPLOYMENT_STATUS_README.md)** | 11 KB | Tous | 10 min |

### 📋 Documents de Spécification

| Fichier | Taille | Public | Temps Lecture |
|---------|--------|--------|---------------|
| **[WIZARD_SPEC.md](WIZARD_SPEC.md)** | 11 KB | PM, Designers | 15 min |
| **[WIZARD_QUESTIONS_SPEC.md](WIZARD_QUESTIONS_SPEC.md)** | 49 KB | PM, Dev, QA | 30 min |
| **[PILLAR_3A_LIMITS.md](PILLAR_3A_LIMITS.md)** | 9 KB | Dev, Fiscalistes | 15 min |

### 💻 Documents d'Implémentation

| Fichier | Taille | Public | Temps Lecture |
|---------|--------|--------|---------------|
| **[IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)** | 24 KB | Développeurs | 45 min |
| **[WIZARD_FLOW_DIAGRAMS.md](WIZARD_FLOW_DIAGRAMS.md)** | 37 KB | Dev, Designers, QA | 15 min |

### 📖 Documents d'Exemples

| Fichier | Taille | Public | Temps Lecture |
|---------|--------|--------|---------------|
| **[WIZARD_USER_JOURNEYS.md](WIZARD_USER_JOURNEYS.md)** | 16 KB | PM, Designers, QA | 20 min |

---

## 🔍 Par Sujet

### Statut d'Emploi

**Questions Pivot** :
- `WIZARD_QUESTIONS_SPEC.md` → Section "1. Noyau Commun" → `q_employment_status`
- `WIZARD_QUESTIONS_SPEC.md` → Section "1. Noyau Commun" → `q_has_2nd_pillar`

**Branches Conditionnelles** :
- `WIZARD_QUESTIONS_SPEC.md` → Section "1B. Branches Spécifiques par Statut d'Emploi"
  - A) Salarié avec LPP
  - B) Indépendant sans LPP
  - C) Mixte

**Diagrammes** :
- `WIZARD_FLOW_DIAGRAMS.md` → Diagramme 1 : Flux Principal
- `WIZARD_FLOW_DIAGRAMS.md` → Diagramme 2 : Branche A (Salarié)
- `WIZARD_FLOW_DIAGRAMS.md` → Diagramme 3 : Branche B (Indépendant)
- `WIZARD_FLOW_DIAGRAMS.md` → Diagramme 4 : Branche D (Mixte)

---

### Plafonds 3a

**Référence Complète** :
- `PILLAR_3A_LIMITS.md` → Tableaux 2023-2026
- `PILLAR_3A_LIMITS.md` → Règles de calcul détaillées
- `PILLAR_3A_LIMITS.md` → Format JSON

**Implémentation** :
- `IMPLEMENTATION_GUIDE.md` → Section "Configuration des Plafonds 3a"
- `IMPLEMENTATION_GUIDE.md` → Classe `Pillar3aCalculator`

**Diagramme** :
- `WIZARD_FLOW_DIAGRAMS.md` → Diagramme 5 : Calcul du Plafond 3a

---

### Timeline Proactive

**Règles Générales** :
- `WIZARD_QUESTIONS_SPEC.md` → Section "5. Règles de Timeline"

**Règles Spécifiques** :
- `WIZARD_QUESTIONS_SPEC.md` → "Rappels Récurrents" → Par statut

**Implémentation** :
- `IMPLEMENTATION_GUIDE.md` → Section "Création de Timeline Items"
- `IMPLEMENTATION_GUIDE.md` → Classe `TimelineItemFactory`

**Diagramme** :
- `WIZARD_FLOW_DIAGRAMS.md` → Diagramme 6 : Création de Timeline Items

---

### Événements de Vie

**Liste Complète** :
- `WIZARD_QUESTIONS_SPEC.md` → Section "4. Événements de Vie"
- `WIZARD_QUESTIONS_SPEC.md` → Enum `LifeEventType`

**Détails par Événement** :
- `WIZARD_QUESTIONS_SPEC.md` → "Événements Liés au Statut d'Emploi (Détails)"
  - newJob
  - employmentStatusChange
  - lppAffiliation
  - lppDisaffiliation

**Diagramme** :
- `WIZARD_FLOW_DIAGRAMS.md` → Diagramme 7 : Événements de Vie

---

### Parcours Utilisateur

**Exemples Détaillés** :
- `WIZARD_USER_JOURNEYS.md` → Parcours 1 : Sarah (Salariée + LPP)
- `WIZARD_USER_JOURNEYS.md` → Parcours 2 : Marc (Indépendant - LPP)
- `WIZARD_USER_JOURNEYS.md` → Parcours 3 : Julie (Mixte + LPP)
- `WIZARD_USER_JOURNEYS.md` → Parcours 4 : Thomas (Indépendant + LPP volontaire)

**Comparaison** :
- `WIZARD_USER_JOURNEYS.md` → Section "Comparaison des Parcours"

---

## 🚀 Parcours Recommandés

### 🎯 Parcours "Quick Start" (30 min)

Pour avoir une vue d'ensemble rapide :

1. **[EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md)** (10 min)
   - Objectif, impact, ROI

2. **[EMPLOYMENT_STATUS_SYNTHESIS.md](EMPLOYMENT_STATUS_SYNTHESIS.md)** (15 min)
   - Résumé complet des changements

3. **[WIZARD_USER_JOURNEYS.md](WIZARD_USER_JOURNEYS.md)** (5 min)
   - Parcours 2 : Marc (Indépendant) uniquement

---

### 📋 Parcours "Product Manager" (1h30)

Pour comprendre toute la spec fonctionnelle :

1. **[EMPLOYMENT_STATUS_README.md](EMPLOYMENT_STATUS_README.md)** (10 min)
2. **[WIZARD_SPEC.md](WIZARD_SPEC.md)** (15 min)
3. **[WIZARD_QUESTIONS_SPEC.md](WIZARD_QUESTIONS_SPEC.md)** (30 min)
4. **[WIZARD_USER_JOURNEYS.md](WIZARD_USER_JOURNEYS.md)** (20 min)
5. **[PILLAR_3A_LIMITS.md](PILLAR_3A_LIMITS.md)** (15 min)

---

### 💻 Parcours "Développeur" (2h)

Pour implémenter le code :

1. **[IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)** (45 min)
2. **[PILLAR_3A_LIMITS.md](PILLAR_3A_LIMITS.md)** (15 min)
3. **[WIZARD_QUESTIONS_SPEC.md](WIZARD_QUESTIONS_SPEC.md)** (30 min)
4. **[WIZARD_FLOW_DIAGRAMS.md](WIZARD_FLOW_DIAGRAMS.md)** (15 min)
5. **[WIZARD_USER_JOURNEYS.md](WIZARD_USER_JOURNEYS.md)** (15 min)

---

### 🧪 Parcours "QA / Testeur" (1h15)

Pour tester tous les cas :

1. **[WIZARD_USER_JOURNEYS.md](WIZARD_USER_JOURNEYS.md)** (20 min)
2. **[WIZARD_FLOW_DIAGRAMS.md](WIZARD_FLOW_DIAGRAMS.md)** (15 min)
3. **[WIZARD_QUESTIONS_SPEC.md](WIZARD_QUESTIONS_SPEC.md)** (30 min)
4. **[IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)** (section Tests, 10 min)

---

## 📊 Statistiques de la Documentation

### Fichiers Créés/Modifiés

| Type | Nombre | Taille Totale |
|------|--------|---------------|
| **Fichiers créés** | 8 | ~161 KB |
| **Fichiers modifiés** | 2 | ~60 KB |
| **TOTAL** | 10 | **~221 KB** |

### Détail par Fichier

| Fichier | Statut | Taille | Lignes |
|---------|--------|--------|--------|
| EXECUTIVE_SUMMARY.md | ✅ Créé | 12 KB | ~400 |
| EMPLOYMENT_STATUS_SYNTHESIS.md | ✅ Créé | 12 KB | ~450 |
| EMPLOYMENT_STATUS_README.md | ✅ Créé | 11 KB | ~400 |
| EMPLOYMENT_STATUS_INTEGRATION.md | ✅ Créé | 11 KB | ~350 |
| IMPLEMENTATION_GUIDE.md | ✅ Créé | 24 KB | ~800 |
| WIZARD_FLOW_DIAGRAMS.md | ✅ Créé | 37 KB | ~1200 |
| WIZARD_USER_JOURNEYS.md | ✅ Créé | 16 KB | ~550 |
| PILLAR_3A_LIMITS.md | ✅ Créé | 9 KB | ~300 |
| WIZARD_SPEC.md | 🔄 Modifié | 11 KB | ~280 |
| WIZARD_QUESTIONS_SPEC.md | 🔄 Modifié | 49 KB | ~1500 |
| **INDEX.md** | ✅ Créé | 12 KB | ~400 |

---

## 🔗 Liens Rapides

### Documents Essentiels
- [Résumé Exécutif](EXECUTIVE_SUMMARY.md) - Pour décideurs
- [Synthèse Complète](EMPLOYMENT_STATUS_SYNTHESIS.md) - Vue d'ensemble
- [Guide d'Implémentation](IMPLEMENTATION_GUIDE.md) - Pour développeurs

### Spécifications
- [Structure du Wizard](WIZARD_SPEC.md)
- [Questions Détaillées](WIZARD_QUESTIONS_SPEC.md)
- [Plafonds 3a](PILLAR_3A_LIMITS.md)

### Exemples & Diagrammes
- [Parcours Utilisateur](WIZARD_USER_JOURNEYS.md)
- [Diagrammes de Flux](WIZARD_FLOW_DIAGRAMS.md)

### Récapitulatifs
- [README Principal](EMPLOYMENT_STATUS_README.md)
- [Intégration Complète](EMPLOYMENT_STATUS_INTEGRATION.md)

---

## 📞 Support

### Questions Fréquentes

**Q : Par où commencer ?**
→ Voir section "Parcours Recommandés" ci-dessus selon votre rôle

**Q : Comment implémenter le code ?**
→ Lire `IMPLEMENTATION_GUIDE.md` (guide complet avec code)

**Q : Comment tester tous les cas ?**
→ Lire `WIZARD_USER_JOURNEYS.md` (4 profils types)

**Q : Quels sont les plafonds 3a corrects ?**
→ Lire `PILLAR_3A_LIMITS.md` (tableaux 2023-2026)

**Q : Comment visualiser la logique ?**
→ Lire `WIZARD_FLOW_DIAGRAMS.md` (7 diagrammes ASCII)

### Contacts
- **Product Manager** : [Nom]
- **Tech Lead** : [Nom]
- **Fiscaliste** : [Nom]
- **Auteur de la documentation** : Antigravity (Google Deepmind)

---

## ✅ Checklist de Lecture

Cochez au fur et à mesure de votre lecture :

### Pour Stakeholders
- [ ] EXECUTIVE_SUMMARY.md
- [ ] EMPLOYMENT_STATUS_SYNTHESIS.md

### Pour Product Managers
- [ ] EMPLOYMENT_STATUS_README.md
- [ ] WIZARD_SPEC.md
- [ ] WIZARD_QUESTIONS_SPEC.md
- [ ] WIZARD_USER_JOURNEYS.md

### Pour Développeurs
- [ ] IMPLEMENTATION_GUIDE.md
- [ ] PILLAR_3A_LIMITS.md
- [ ] WIZARD_QUESTIONS_SPEC.md
- [ ] WIZARD_FLOW_DIAGRAMS.md

### Pour QA / Testeurs
- [ ] WIZARD_USER_JOURNEYS.md
- [ ] WIZARD_FLOW_DIAGRAMS.md
- [ ] WIZARD_QUESTIONS_SPEC.md

---

**Dernière mise à jour** : 2026-01-11  
**Version** : 1.0  
**Auteur** : Antigravity (Google Deepmind)
