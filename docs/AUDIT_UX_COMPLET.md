# AUDIT UX COMPLET - APPLICATION MINT

**Date** : 18 janvier 2026  
**Auditeur** : Expert UX Senior  
**Scope** : Expérience utilisateur globale, navigation, onboarding

---

## 🚨 PROBLÈMES CRITIQUES IDENTIFIÉS

### 1. NAVIGATION CONFUSE (Sévérité: CRITIQUE)

**Problème** : L'onglet "Parcours" ne communique pas clairement son rôle
- Aucun titre explicite ("Par où commencer ?")
- Pas d'étapes visibles (1, 2, 3...)
- Pas de progression claire
- Pas d'indication de durée estimée

**Impact** : L'utilisateur est perdu dès l'arrivée  
**Photo** : Overflow visible, questions sans contexte

---

### 2. ORDRE ILLOGIQUE DES QUESTIONS (Sévérité: CRITIQUE)

**Problème actuel** :
```
Question 13/14 : "As-tu déjà un 3a ?"
└─ Montre un slider avec 7'800 CHF
└─ D'où vient ce chiffre ??? Budget pas fait !
```

**Ce qui devrait se passer** :
```
1. CONTEXTE : Qui es-tu ? (nom, âge, canton, situation)
2. BUDGET : Revenus, charges, dettes
3. ANALYSE : Calcul capacité d'épargne
4. RECOMMANDATIONS : 3a, LPP, investissements
```

**Impact** : L'utilisateur ne comprend pas pourquoi on lui demande ça  
**Taux d'abandon estimé** : 70%+

---

### 3. DONNÉES ARBITRAIRES (Sévérité: ÉLEVÉE)

**Problème** : Le slider 3a affiche "CHF 7'800" mais :
- Le budget n'a pas été saisi
- On ne sait pas si l'utilisateur gagne 5k ou 15k
- Impossible de calculer la capacité réelle

**Impact** : Perte de crédibilité, recommandations non personnalisées

---

### 4. OVERFLOW VISUEL (Sévérité: MOYENNE)

**Problème** : Élément "OVERFLOW" visible sur le screenshot
- Widget 3a mal dimensionné
- Texte tronqué
- UX non professionnelle

**Impact** : Perception de qualité médiocre

---

### 5. ONBOARDING INEXISTANT (Sévérité: ÉLEVÉE)

**Problème** : Pas d'explication initiale
- Pas de "Bienvenue sur MINT"
- Pas de présentation du parcours
- Pas d'explication de la théorie des cercles
- Pas de durée estimée (10-15 min)

**Impact** : Utilisateur ne sait pas dans quoi il s'engage

---

### 6. DÉCONNEXION BUDGET ↔ PARCOURS (Sévérité: CRITIQUE)

**Problème actuel** :
- Onglet "Budget" existe
- Onglet "Parcours" existe
- **Aucun lien entre les deux !**

**Ce qui devrait se passer** :
```
Parcours = Wizard complet qui INCLUT le budget
OU
Budget OBLIGATOIRE avant Parcours
```

**Impact** : Deux sources de vérité, incohérence totale

---

## 📊 CARTE D'EMPATHIE UTILISATEUR

### Persona : Julien, 49 ans, Valais

**Ce qu'il PENSE** :
- "Je veux optimiser ma retraite"
- "J'ai 200k de rachat LPP disponible, c'est quoi la meilleure stratégie ?"

**Ce qu'il RESSENT** :
- ❓ Confus : "Pourquoi on me demande si j'ai un 3a sans connaître mon budget ?"
- 😠 Frustré : "7800 CHF, d'où ça sort ?"
- 🤔 Méfiant : "Est-ce que ce truc fonctionne vraiment ?"

**Ce qu'il VOIT** :
- Un écran "Parcours" sans explication
- Question 13/14 (déjà avancé ?)
- Un slider avec un montant mystérieux
- Un overflow technique

**Ce qu'il FAIT** :
- Clique sur "Parcours"
- Voit la question 3a
- Se demande s'il doit d'abord aller dans "Budget"
- **Ferme l'app** (abandon)

---

## 🎯 PARCOURS UTILISATEUR IDÉAL (Théorie des Cercles)

### PHASE 1 : ACCUEIL & ONBOARDING (30 secondes)

```
┌─────────────────────────────────────────┐
│  Bienvenue sur MINT 🌿                 │
│                                         │
│  Ton coach financier suisse            │
│  personnalisé                           │
│                                         │
│  ✓ Diagnostic complet (10-15 min)     │
│  ✓ Score de santé financière           │
│  ✓ Recommandations actionnables        │
│                                         │
│  [Commencer mon diagnostic]            │
│  [J'ai déjà un compte]                 │
└─────────────────────────────────────────┘
```

### PHASE 2 : PROFIL RAPIDE (2 minutes)

**Objectif** : Contexte minimal  
**Écran unique** avec 5 infos clés :
- Prénom (optionnel)
- Année de naissance → Affiche âge + années avant retraite
- Canton → Affiche info fiscalité locale
- Statut civil → Affiche impact fiscal
- Statut professionnel → Détermine LPP/3a

**Feedback immédiat** :
```
✓ Julien, 49 ans
✓ 16 ans avant la retraite (2041)
✓ Valais : fiscalité avantageuse
✓ Marié : splitting familial possible
```

### PHASE 3 : CERCLE 1 - BUDGET & PROTECTION (5 minutes)

**Introduction claire** :
```
┌─────────────────────────────────────────┐
│  🛡️ CERCLE 1 : PROTECTION             │
│                                         │
│  Avant d'investir, sécurisons ta base  │
│                                         │
│  ✓ Revenus & Charges                   │
│  ✓ Fonds d'urgence                     │
│  ✓ Dettes                              │
│                                         │
│  [Continuer • 3 min]                   │
└─────────────────────────────────────────┘
```

**Questions dans l'ordre** :
1. Revenu net mensuel (ménage si marié)
2. Fréquence de paiement (mensuel/bimensuel/hebdo)
3. Loyer ou hypothèque
4. Autres charges fixes
5. As-tu un fonds d'urgence 3-6 mois ?
6. As-tu des dettes de consommation ?

**Résultat immédiat** :
```
┌─────────────────────────────────────────┐
│  📊 TON BUDGET                         │
│                                         │
│  Revenus :        7'800 CHF/mois       │
│  Charges :        2'200 CHF/mois       │
│  ───────────────────────────────────   │
│  Capacité :       5'600 CHF/mois       │
│                                         │
│  💡 Tu peux épargner jusqu'à           │
│     80% = 4'480 CHF/mois               │
│                                         │
│  [Valider mon budget]                  │
└─────────────────────────────────────────┘
```

### PHASE 4 : CERCLE 2 - PRÉVOYANCE (4 minutes)

**Introduction** :
```
┌─────────────────────────────────────────┐
│  💰 CERCLE 2 : PRÉVOYANCE FISCALE      │
│                                         │
│  Optimisons tes impôts et ta retraite  │
│                                         │
│  ✓ 3a (Pilier 3a)                      │
│  ✓ LPP (Rachat 2e pilier)              │
│  ✓ AVS (Lacunes)                       │
│                                         │
│  [Continuer • 4 min]                   │
└─────────────────────────────────────────┘
```

**Questions** :
1. As-tu un 3a ? Combien de comptes ? Où ?
2. Verses-tu le maximum (7'258 CHF) ?
3. [SI 45+ ans] Peux-tu racheter ta LPP ? Montant ?
4. [Widget comparateur VIAC vs Banque avec TON revenu]

**MAINTENANT le slider fait du sens** :
```
Ton revenu mensuel net : 7'800 CHF ✓
Versement max 3a : 7'258 CHF/an ✓
Économie fiscale (VS) : ~2'200 CHF ✓
```

### PHASE 5 : RAPPORT FINAL (Toujours accessible)

**Structure claire** :
1. Score global /100
2. Diagnostic par cercle
3. Top 3 actions prioritaires
4. Roadmap personnalisée
5. Export PDF

---

## 🏗️ ARCHITECTURE DE NAVIGATION PROPOSÉE

### Option A : Navigation Séquentielle (RECOMMANDÉE)

```
Home
  │
  ├─ "Commence ton diagnostic" [CTA Principal]
  │    │
  │    └─ Wizard Multi-Étapes
  │         ├─ Étape 1/5 : Profil (2 min)
  │         ├─ Étape 2/5 : Budget (3 min)
  │         ├─ Étape 3/5 : Prévoyance (4 min)
  │         ├─ Étape 4/5 : Patrimoine (2 min)
  │         └─ Étape 5/5 : Objectifs (2 min)
  │              │
  │              └─ Rapport Final
  │
  ├─ Budget (Consultable mais pas éditable sans wizard)
  ├─ Simulateurs (Accessibles après wizard)
  └─ Profil
```

### Option B : Navigation Hybride

```
Home
  │
  ├─ Mode Guidé (Assistant) → Wizard complet
  ├─ Mode Explorateur (Avancé) → Simulateurs directs
  ├─ Budget (Sync avec wizard)
  └─ Rapport (Généré après wizard)
```

---

## 📝 PLAN DE REFONTE PAR PRIORITÉ

### PRIORITÉ 1 : FIXES CRITIQUES (1-2 jours)

1. **Créer écran d'onboarding**
   - Explication MINT
   - Durée estimée
   - Théorie des cercles (vulgarisée)

2. **Réordonnancer le wizard**
   - Profil → Budget → Prévoyance → Patrimoine
   - Bloquer les étapes si budget incomplet

3. **Connecter Budget ↔ Wizard**
   - Budget devient la source de vérité
   - Wizard l'utilise pour calculs

4. **Fix overflow widget 3a**
   - Responsive sur mobile
   - Textes tronqués

### PRIORITÉ 2 : AMÉLIORATION UX (3-5 jours)

1. **Barre de progression claire**
   ```
   [●●●○○] Étape 3/5 : Prévoyance (60% complété)
   ```

2. **Feedback immédiat après chaque section**
   ```
   ✓ Budget complété
   Capacité d'épargne : 4'480 CHF/mois
   [Continuer vers Prévoyance]
   ```

3. **Tooltips & Éducation inline**
   - "Pourquoi cette question ?"
   - "Impact sur mon score"

4. **Sauvegarde automatique**
   - Reprendre où on s'est arrêté
   - "Tu as complété 60%, continue !"

### PRIORITÉ 3 : OPTIMISATIONS (1 semaine)

1. **Smart defaults**
   - Deviner fréquence paiement selon canton
   - Proposer plafond 3a selon statut

2. **Conditional logic avancée**
   - Skip questions non pertinentes
   - Adapter selon âge/situation

3. **Animations fluides**
   - Transitions entre écrans
   - Célébration fin de parcours

---

## 🎨 WIREFRAMES PROPOSÉS

### Écran 1 : Onboarding

```
┌────────────────────────────────────┐
│           [Logo MINT]              │
│                                    │
│    Ton diagnostic financier        │
│    en 10 minutes                   │
│                                    │
│  ┌──────────────────────────────┐ │
│  │  🛡️ Sécurité                │ │
│  │  Fonds urgence, dettes       │ │
│  └──────────────────────────────┘ │
│  ┌──────────────────────────────┐ │
│  │  💰 Prévoyance               │ │
│  │  3a, LPP, AVS                │ │
│  └──────────────────────────────┘ │
│  ┌──────────────────────────────┐ │
│  │  📈 Croissance               │ │
│  │  Investissements, immobilier │ │
│  └──────────────────────────────┘ │
│                                    │
│    [Commencer mon diagnostic]      │
│    [J'ai déjà commencé]            │
└────────────────────────────────────┘
```

### Écran 2 : Budget avec contexte

```
┌────────────────────────────────────┐
│  ← Étape 2/5 : Budget      [60%]  │
│                                    │
│  💡 Comprends ta capacité          │
│     d'épargne                      │
│                                    │
│  Revenu net mensuel (ménage)      │
│  ┌──────────────────────────────┐ │
│  │  7800                CHF     │ │
│  └──────────────────────────────┘ │
│                                    │
│  Loyer/Hypothèque                 │
│  ┌──────────────────────────────┐ │
│  │  1830                CHF     │ │
│  └──────────────────────────────┘ │
│                                    │
│  ✓ Capacité d'épargne :           │
│    5'970 CHF/mois                 │
│                                    │
│    [Continuer]                     │
└────────────────────────────────────┘
```

---

## 🚀 IMPLÉMENTATION RECOMMANDÉE

### Semaine 1 : Fondations
- Créer `OnboardingScreen`
- Créer `WizardStepperWidget` (barre progression)
- Créer `BudgetSummaryWidget`

### Semaine 2 : Refonte Wizard
- Réordonnancer questions (profil → budget → prévoyance)
- Intégrer budget dans calculs
- Fix overflow

### Semaine 3 : Polish & Tests
- Animations
- Tooltips
- Tests utilisateurs

---

## ✅ CHECKLIST QUALITÉ UX

- [ ] Tout utilisateur comprend le parcours en <10 secondes
- [ ] Aucune donnée arbitraire sans explication
- [ ] Progression visible à chaque instant
- [ ] Feedback immédiat après chaque action
- [ ] Temps estimé affiché et respecté
- [ ] Possibilité de sauvegarder et reprendre
- [ ] Rapport final actionnable avec roadmap

---

**Verdict** : L'application actuelle a un excellent moteur (théorie des cercles, calculs)  
mais une **interface déroutante**. La refonte UX est **critique** pour le succès.

**Estimation** : 2-3 semaines de refonte selon ce plan = Application production-ready
