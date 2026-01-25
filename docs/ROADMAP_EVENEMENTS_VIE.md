# ROADMAP - ÉVÉNEMENTS DE VIE

## 🎯 Concept : Mise à Jour Contextuelle du Plan

Les événements de vie majeurs nécessitent une **réévaluation complète** du plan financier.

---

## 📋 ÉVÉNEMENTS À TRACKER

### Vie Familiale
- **Mariage** → Impact fiscal majeur (splitting), changement assurances, 3a conjoint
- **Naissance** → Déduction fiscale, congé parental, LPP prévoyance survivants
- **Divorce** → Séparation patrimoine, pension alimentaire, rachat LPP
- **Décès conjoint** → Rente survivant, héritage, adaptation budget

### Vie Professionnelle
- **Changement emploi** → Nouveau salaire, nouvelle LPP (virement de libre passage)
- **Passage indépendant** → Plus de LPP, 3a max augmenté (36k), AVS volontaire
- **Promotion/Augmentation** → Nouvelle capacité épargne, rachat LPP
- **Perte emploi** → Chômage, puiser fonds urgence, pause 3a
- **Départ retraite** → Retrait 3a/LPP optimisé, rentes AVS

### Patrimoine
- **Achat immobilier** → Retrait 2e pilier EPL, hypothèque, charges
- **Vente immobilier** → Remboursement pilier, réinvestissement
- **Héritage** → Nouveau capital, optimisation fiscale
- **Grosse dépense** → Voiture, rénovation, impact épargne

### Santé
- **Problème santé** → Assurance complémentaire, perte de gain
- **Accident** → IJM, assurance accidents

---

## 🎨 UX PROPOSÉE

### 1. Notification Proactive

```
┌────────────────────────────────────────┐
│  📣 Événement de vie ?                │
│                                        │
│  Un changement dans ta situation ?    │
│                                        │
│  [Nouveau job]  [Mariage]             │
│  [Naissance]    [Achat immo]          │
│  [Autre...]                           │
│                                        │
│  Mets à jour ton plan en 2 min        │
└────────────────────────────────────────┘
```

### 2. Wizard Adapté par Événement

#### Exemple : "Mariage"
```
Questions ciblées :
1. Date du mariage (pour fiscalité année en cours)
2. Revenu du conjoint
3. Situation LPP du conjoint
4. Le conjoint a-t-il un 3a ?
5. Régime matrimonial (séparation/communauté de biens)

→ Recalcul automatique :
- Splitting fiscal
- Capacité épargne ménage
- Recommandation 3a conjoint si manquant
- Prévoyance survivants
```

#### Exemple : "Naissance"
```
Questions ciblées :
1. Date de naissance
2. Congé parental pris
3. Réduction activité (%)
4. Frais garde prévus

→ Recalcul :
- Déduction fiscale enfant
- Impact revenu (congé)
- Budget garde
- Recommandation assurance risque pur (couverture décès)
```

---

## 🏗️ ARCHITECTURE TECHNIQUE

### Base de Données

```dart
class LifeEvent {
  String id;
  String userId;
  LifeEventType type;
  DateTime occurredAt;
  Map<String, dynamic> data;
  bool hasUpdatedPlan; // Flag si plan mis à jour
  
  // Trigger auto
  List<String> triggeredRecommendations;
}

enum LifeEventType {
  marriage,
  birth,
  divorce,
  death,
  jobChange,
  jobLoss,
  retirement,
  realEstatePurchase,
  realEstateSale,
  inheritance,
  healthIssue,
  other,
}
```

### Notifications Intelligentes

```dart
class LifeEventDetector {
  // Détection automatique via changements réponses wizard
  void detectEvents(Map<String, dynamic> oldAnswers, Map<String, dynamic> newAnswers) {
    // Exemple : Statut civil changé → Événement mariage/divorce
    if (oldAnswers['q_civil_status'] != newAnswers['q_civil_status']) {
      if (newAnswers['q_civil_status'] == 'married') {
        _triggerEvent(LifeEventType.marriage);
      }
    }
    
    // Exemple : Nb enfants augmenté → Naissance
    if ((newAnswers['q_children'] ?? 0) > (oldAnswers['q_children'] ?? 0)) {
      _triggerEvent(LifeEventType.birth);
    }
  }
}
```

### Wizard Conditionnel

```dart
class LifeEventWizard {
  List<WizardQuestion> getQuestionsForEvent(LifeEventType event) {
    switch (event) {
      case LifeEventType.marriage:
        return _marriageQuestions;
      case LifeEventType.birth:
        return _birthQuestions;
      // ...
    }
  }
}
```

---

## 📅 IMPLÉMENTATION PAR PHASES

### Phase 1 : Détection Manuelle (MVP)
- Bouton "Événement de vie" dans le profil
- Liste des événements courants
- Mini-wizard adapté
- **Durée** : 1 semaine

### Phase 2 : Détection Automatique
- Comparaison réponses wizard
- Notifications push
- Timeline des événements
- **Durée** : 2 semaines

### Phase 3 : Prédiction & Conseils
- IA prédictive (âge → probabilité événements)
- "Dans 2 ans tu auras 65 ans, prépare ta retraite"
- Checklist pré-événement
- **Durée** : 3 semaines

---

## 💡 EXEMPLES CONCRETS

### Utilisateur : Julien, 49 ans, Valais

**Événement détecté : Proche retraite (16 ans)**

```
┌─────────────────────────────────────────┐
│  📅 Retraite dans 16 ans (2041)        │
│                                         │
│  Prépare-toi dès maintenant :          │
│                                         │
│  ✓ Racheter LPP échelonné (200k)      │
│  ✓ Optimiser nb comptes 3a (2-3)      │
│  ✓ Vérifier lacunes AVS               │
│  ✓ Prévoir retrait 3a sur 5 ans       │
│                                         │
│  [Voir ma stratégie retraite]          │
└─────────────────────────────────────────┘
```

**Événement futur : 65 ans (2041)**

```
Auto-suggestion 6 mois avant :
"Tu atteins 65 ans en 2041. Lance ta simulation de retrait optimal 3a/LPP"
```

---

## 🔔 NOTIFICATIONS TYPES

### Proactive (Basée sur profil)
- "Tu as 45 ans, moment idéal pour vérifier ton rachat LPP"
- "Marié depuis 1 an, as-tu optimisé votre fiscalité de couple ?"

### Réactive (Basée sur actions)
- "Tu as ajouté un enfant, voici tes nouvelles déductions"
- "Changement d'emploi détecté, veux-tu mettre à jour ton plan ?"

### Saisonnière
- "Fin d'année : Dernière chance pour rachat LPP 2026"
- "Déclaration impôts approche, voici ton récap déductions"

---

**Priorité** : Phase 1 dans 1-2 sprints après wizard V2 stabilisé

**Impact estimé** : +40% engagement long terme, rétention utilisateurs
