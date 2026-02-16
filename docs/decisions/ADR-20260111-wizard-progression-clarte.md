# ADR-20260111 : Progression de Clarté (Wizard Éducatif)

**Date** : 2026-01-11  
**Statut** : Accepté  
**Contexte** : Refonte du wizard onboarding pour améliorer la pédagogie sans créer de biais ou de risques de compliance

---

## Contexte

Le wizard onboarding de Mint doit transformer l'ambiguïté en un **plan d'actions sûr, compréhensible et exécutable**, avec transparence sur conflits/commissions et limites.

### Ce que "progression pédagogique" signifie
- Feedback immédiat sur l'impact des décisions
- Visualisation claire des scénarios (prudence/central/stress)
- Réduction de friction dans le parcours
- Amélioration de la clarté du plan (indice de précision)

### Ce que cela NE signifie PAS
- ❌ Jeu avec points/badges pour l'engagement
- ❌ Incitation à prendre plus de risques
- ❌ Mécaniques compulsives (farming de points)
- ❌ Récompenses liées à des partenaires (conflits d'intérêts)

---

## Invariants (Non-Négociables)

### 1. Rapport/Plan comme Livrable Central
- Le PDF final est le **livrable principal**, pas un "score"
- Aperçu du rapport disponible **dès l'Acte 3** (éviter drop-off)
- Toute mécanique de progression doit **servir** la qualité du rapport

### 2. Neutralité & Compliance
- **Aucune incitation** à l'investissement quand Safe Mode est actif
- **Aucune récompense** liée à un `partner_handoff` (conflit d'intérêts)
- Scénarios **prudence/central/stress** (jamais de promesse implicite)
- Hypothèses **toujours visibles** (taux, inflation, rendement pédagogique)

### 3. Simplicité
- **Une seule métrique** visible : Indice de Précision (0-100%)
- **Une seule action** suggérée à la fois : "Prochaine info la plus rentable"
- Éviter feature fatigue : contract-first, puis 1 simulation, puis tests

---

## Décision : Progression de Clarté

### Métrique Unique : Indice de Précision (0-100%)

**Calcul :**
- Profil minimal (canton, âge, situation) : +20%
- Cashflow (revenus, épargne) : +20%
- Dettes & risques (leasing, crédit) : +20%
- Prévoyance (3a, LPP) : +20%
- Objectif défini : +20%

**Affichage :**
```
Précision : 60% (Bon)
Prochaine info la plus rentable : "Montant 3a actuel"
```

**Code couleur :**
- 0-40% : Orange (Basique)
- 40-70% : Vert clair (Bon)
- 70-90% : Vert (Excellent)
- 90-100% : Vert foncé (Parfait)

### Actions Prêtes (au lieu de Points)

**Affichage :**
```
Actions prêtes : 2/5
✅ Fonds d'urgence : Objectif défini
✅ 3a : Versement annuel calculé
⏳ Rachat LPP : Info manquante
⏳ Optimisation fiscale : En attente
⏳ Diversification : Après les bases
```

### Badges Comportementaux (au lieu de "Investisseur/Maître")

**Débloqués uniquement sur actions réalisées :**
- 🛡️ **Protégé** : Fonds d'urgence constitué (upload preuve ou déclaration)
- 📅 **Régulier** : Ordre permanent 3a activé
- 📄 **Transparent** : Certificat LPP uploadé
- 🧠 **Prudent** : Bénéficiaires LPP/3a vérifiés

**Jamais débloqués sur :**
- ❌ Réponses aux questions
- ❌ `partner_handoff` (conflit d'intérêts)
- ❌ Choix de produits risqués

---

## Simulations : Scénarios Prudence/Central/Stress

### Exemple : Intérêts Composés

**Hypothèses visibles :**
```
Versement mensuel : CHF 500
Durée : 20 ans
Inflation : 1.5% (hypothèse pédagogique)

Scénarios (rendements annuels moyens) :
- Prudence (0.5%) : Compte épargne
- Central (3%) : 3a conservateur
- Stress (5%) : 3a équilibré
```

**Affichage :**
```
📊 Projection (hypothèses pédagogiques)

Prudence (0.5%) : CHF 122'000
Central (3%) : CHF 164'000
Stress (5%) : CHF 206'000

⚠️ Ces scénarios sont éducatifs, pas des promesses.
Les rendements passés ne garantissent pas les rendements futurs.
```

**Interdictions :**
- ❌ Scénario "marché 8%" sans disclaimer
- ❌ Graphique sans bande d'incertitude
- ❌ Suggestion implicite de prendre plus de risque

### Exemple : Rachat LPP

**Hypothèses visibles :**
```
Rachat : CHF 15'000
Taux marginal : 30% (estimé selon canton/revenu)
Taux de conversion LPP : 6% (hypothèse actuelle)
```

**Affichage :**
```
📊 Impact Rachat LPP (hypothèses)

Économie fiscale immédiate : CHF 4'500
Augmentation rente (dès 65 ans) : +CHF 900/an

⚠️ Hypothèses : taux marginal 30%, conversion 6%
Vérifier avec votre certificat LPP et conseiller fiscal.
```

---

## Safe Mode : Garde-Fous

### Règles Strictes

1. **Si Safe Mode actif** (dettes > 30% revenu OU pas de fonds d'urgence) :
   - ❌ Aucune simulation d'investissement
   - ❌ Aucune suggestion de 3a titres
   - ✅ Focus sur : remboursement dettes + fonds d'urgence

2. **Tests automatiques** :
   ```dart
   test('Safe Mode: no investment suggestions', () {
     final answers = {'debt_ratio': 0.35, 'emergency_fund': false};
     final suggestions = getSuggestions(answers);
     expect(suggestions.any((s) => s.type == 'investment'), false);
   });
   ```

3. **Disclosure obligatoire** si `partner_handoff` :
   ```
   ⚠️ Mint peut recevoir une commission de [Partenaire].
   Alternatives disponibles : [Liste]
   Tu es libre de choisir un autre prestataire.
   ```

---

## Process de Développement

### Contract-First
1. Définir le contrat (inputs/outputs, hypothèses, disclaimers)
2. Écrire les tests (scénarios prudence/central/stress)
3. Implémenter 1 simulation à la fois
4. Valider compliance (Safe Mode, disclaimers, alternatives)
5. Itérer

### Exemple : Simulation Intérêts Composés
```dart
// Contract
class CompoundInterestSimulation {
  final double monthlyAmount;
  final int years;
  final List<Scenario> scenarios; // Prudence/Central/Stress
  final String disclaimer;
  
  // Hypothèses explicites
  final double inflation;
  final String source; // "Hypothèse pédagogique"
}

// Test
test('Compound interest: 3 scenarios with disclaimer', () {
  final sim = CompoundInterestSimulation(
    monthlyAmount: 500,
    years: 20,
    scenarios: [
      Scenario(label: 'Prudence', rate: 0.5),
      Scenario(label: 'Central', rate: 3.0),
      Scenario(label: 'Stress', rate: 5.0),
    ],
    disclaimer: 'Hypothèses pédagogiques, pas des promesses',
  );
  
  expect(sim.scenarios.length, 3);
  expect(sim.disclaimer, isNotEmpty);
});
```

---

## Aperçu Rapport (Dès Acte 3)

**Affichage :**
```
📄 Aperçu de ton Plan Mint

Précision actuelle : 60% (Bon)

Top 3 Actions :
1. ✅ Fonds d'urgence : CHF 10'500 (3 mois)
2. ⏳ 3a : Versement CHF 7'258/an (info manquante)
3. ⏳ Rachat LPP : Potentiel CHF 15'000 (à vérifier)

[Bouton] Compléter pour débloquer le PDF final
```

---

## Références

- **OECD/INFE** : Techniques comportementales (dont gamification) pour littératie financière, si bien conçues
- **FINMA** : Gestion/transparence des conflits d'intérêts et rémunérations de tiers
- **Best Practices Fintech** : Éviter sur-gamification, feature fatigue, incitation au risque

---

## Actions Immédiates

1. ✅ Déplacer `WIZARD_GAMIFICATION.md` vers cette ADR
2. ✅ Remplacer points/badges par Clarté/Précision/Actions
3. ✅ Imposer scénarios prudence/central/stress dans toutes simulations
4. ⏳ Ajouter tests Safe Mode (no investment suggestions)
5. ⏳ Ajouter tests partner_handoff (disclosure + alternatives)
6. ⏳ Implémenter aperçu rapport dès Acte 3

---

## Conclusion

La "progression de clarté" remplace la "gamification" pour :
- ✅ Servir le plan d'action (pas le jeu)
- ✅ Respecter la neutralité (pas d'incitation au risque)
- ✅ Maintenir la simplicité (une métrique, une action)
- ✅ Garantir la compliance (Safe Mode, disclaimers, alternatives)
