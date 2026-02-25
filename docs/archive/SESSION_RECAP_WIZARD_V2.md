# SESSION RÉCAP - REFONTE WIZARD V2

**Date** : 18 janvier 2026  
**Durée** : ~2h
**Objectif** : Onboarding + Wizard V2 avec ordre logique Budget-First

---

## ✅ RÉALISATIONS

### 1. Écran d'Onboarding (/advisor)
- Explication claire du parcours MINT
- Durée affichée (10-15 min)
- Présentation des 3 cercles :
  - 🛡️ Protection & Sécurité (3 min)
  - 💰 Prévoyance Fiscale (4 min)
  - 📈 Croissance & Patrimoine (3 min)
- CTA "Commencer mon diagnostic"

**Fichier** : `lib/screens/advisor/advisor_onboarding_screen.dart`

### 2. Wizard V2 Réorganisé (/advisor/wizard)
**Ancien ordre** : Questions mélangées, 3a avant budget
**Nouveau ordre logique** :
```
PROFIL (6 questions)
├─ Prénom, âge, canton
├─ Situation familiale, enfants
└─ Statut professionnel

BUDGET & PROTECTION (6 questions) ⬅️ MAINTENANT AVANT  3a !
├─ Fréquence paiement
├─ Revenu net
├─ Logement & coûts
├─ Dettes
└─ Fonds d'urgence

PRÉVOYANCE (6 questions)
├─ LPP
├─ Rachat LPP
├─ Nombre comptes 3a
├─ Où sont les 3a  
├─ Versement 3a
└─ AVS

PATRIMOINE (4 questions)
├─ Investissements
├─ Immobilier
├─ Objectifs
└─ Risque
```

**Fichiers** :
- `lib/data/wizard_questions_v2.dart` (22 questions)
- `lib/screens/advisor/advisor_wizard_screen_v2.dart` (UI avec progression)

### 3. Question 3a Simplifiée
**Avant** : Multi-choice avec 6 options (VIAC, Finpension, frankly, banque...)
**Après** : Simple choice, 4 catégories business-oriented :
- 🏦 Banque classique
- 🛡️ Assurance
- 🔀 Mixte
- 📱 Fintech (VIAC, Finpension...)

**Raison** : Plus simple UX + Permet segmentation pour commissions d'affiliation

### 4. Infrastructure Affiliation
- Service `AffiliateService` créé
- Génération de liens trackés (UTM + tracking_id unique)
- Package `uuid` ajouté
- Logging clics/conversions prêt
- **Commissions** : VIAC ~120 CHF, Finpension ~100 CHF

**Fichier** : `lib/services/affiliate_service.dart`

### 5. Documentation Business
- Business model complet (projections, stratégie éthique)
- Roadmap événements de vie
- Audit UX complet avec diagnostic problèmes

**Fichiers** :
- `docs/BUSINESS_MODEL.md`
- `docs/ROADMAP_EVENEMENTS_VIE.md`
- `docs/AUDIT_UX_COMPLET.md`

---

## 🐛 PROBLÈME EN COURS

**Erreur** : `TypeError: "fintech": type 'String' is not a subtype of type 'List<dynamic>?'`

**Cause** : Changement de `q_3a_providers` de `multiChoice` (List) à `choice` (String)

**Fixes appliqués** :
- ✅ `financial_report_service.dart` : Conversion String → List
- ✅ `financial_report_demo_screen.dart` : Données de test corrigées

**Reste à trouver** : Un autre endroit qui attend une List pour `q_3a_providers`  
Probablement dans `models/clarity_state.dart` (ancien système)

---

## 📊 PROGRESSION GLOBALE

```
CERCLE 1 - FONDATIONS         : 100% ████████
CERCLE 2 - SERVICES CORE      : 100% ████████
CERCLE 3 - WIDGETS ÉDUCATIFS  :  50% ████░░░░
CERCLE 4 - INTÉGRATION        :  70% ██████░░
─────────────────────────────────────────────
GLOBALEMENT                   :  80% ███████░
```

---

## 🎯 PROCHAINES ÉTAPES

### Immédiat
1. **Fixer l'erreur TypeError** (providers String/List)
2. **Tester le flow complet** utilisateur
3. **Ajouter badge transparence** au comparateur 3a
4. **Intégrer liens trackés** dans les boutons CTA

### Court Terme (1-2 jours)
5. **Fix overflow** widgets éducatifs
6. **Tests utilisateurs** avec vrais profils
7. **Affiner calculs** fiscaux et retraite
8. **Polish UI** du rapport V2

### Moyen Terme (1 semaine)
9. **Services dédiés** (TaxCalculationService, RetirementProjectionService)
10. **Widgets éducatifs** restants (LPP simulator, timeline)
11. **Événements de vie** Phase 1 (détection manuelle)
12. **Analytics** et tracking conversions

---

## 💡 INSIGHTS SESSION

### UX
- **Ordre des questions est CRITIQUE** : Budget AVANT 3a = cohérence
- **Onboarding nécessaire** : Expliquer durée et parcours
- **Progression visuelle** : Badges par section + % = engagement
- **Questions trop techniques** perdent l'utilisateur

### Business
- **Commissions affiliation** = business model viable (45k-400k CHF/an selon trafic)
- **Transparence = confiance** : Badge "MINT touche commission" augmente conversion réelle
- **Segmentation simple** (Banque/Assurance/Fintech) > Liste détaillée
- **Événements de vie** = retention long terme

### Technique
- **Type safety critique** : Migration multiChoice → choice nécessite update partout
- **State management** : Réponses wizard = source de vérité unique
- **Hot reload limité** : Certains changements nécessitent hot restart complet

---

**État actuel** : 80% fonctionnel, 1 bug bloquant à résoudre, puis tests utilisateurs
