# Plafonds 3a par Année et Statut d'Emploi

## Vue d'ensemble

Les plafonds de cotisation au pilier 3a varient selon :
1. **Le statut d'emploi** (salarié vs indépendant)
2. **La présence d'une caisse de pension LPP**
3. **L'année fiscale**

Ce fichier centralise ces paramètres pour faciliter la maintenance et garantir la cohérence.

---

## Plafonds par Année

### 2026 (Prévisionnel)

| Statut | Condition LPP | Plafond Annuel | Règle de Calcul |
|--------|---------------|----------------|-----------------|
| Salarié | Avec LPP | CHF 7'258 | Montant fixe |
| Salarié | Sans LPP | CHF 36'288 | 20% du revenu net, plafonné |
| Indépendant | Avec LPP (volontaire) | CHF 7'258 | Montant fixe |
| Indépendant | Sans LPP | CHF 36'288 | 20% du revenu net, plafonné |
| Mixte | Avec LPP (via emploi salarié) | CHF 7'258 | Montant fixe |
| Mixte | Sans LPP | CHF 36'288 | 20% du revenu net total, plafonné |

**Note** : Les montants 2026 sont identiques à 2025 (pas d'indexation annoncée à ce jour).

### 2025 (Actuel)

| Statut | Condition LPP | Plafond Annuel | Règle de Calcul |
|--------|---------------|----------------|-----------------|
| Salarié | Avec LPP | CHF 7'258 | Montant fixe |
| Salarié | Sans LPP | CHF 36'288 | 20% du revenu net, plafonné |
| Indépendant | Avec LPP (volontaire) | CHF 7'258 | Montant fixe |
| Indépendant | Sans LPP | CHF 36'288 | 20% du revenu net, plafonné |
| Mixte | Avec LPP (via emploi salarié) | CHF 7'258 | Montant fixe |
| Mixte | Sans LPP | CHF 36'288 | 20% du revenu net total, plafonné |

### 2024

| Statut | Condition LPP | Plafond Annuel | Règle de Calcul |
|--------|---------------|----------------|-----------------|
| Salarié | Avec LPP | CHF 7'056 | Montant fixe |
| Salarié | Sans LPP | CHF 35'280 | 20% du revenu net, plafonné |
| Indépendant | Avec LPP (volontaire) | CHF 7'056 | Montant fixe |
| Indépendant | Sans LPP | CHF 35'280 | 20% du revenu net, plafonné |
| Mixte | Avec LPP (via emploi salarié) | CHF 7'056 | Montant fixe |
| Mixte | Sans LPP | CHF 35'280 | 20% du revenu net total, plafonné |

### 2023

| Statut | Condition LPP | Plafond Annuel | Règle de Calcul |
|--------|---------------|----------------|-----------------|
| Salarié | Avec LPP | CHF 6'883 | Montant fixe |
| Salarié | Sans LPP | CHF 34'416 | 20% du revenu net, plafonné |
| Indépendant | Avec LPP (volontaire) | CHF 6'883 | Montant fixe |
| Indépendant | Sans LPP | CHF 34'416 | 20% du revenu net, plafonné |
| Mixte | Avec LPP (via emploi salarié) | CHF 6'883 | Montant fixe |
| Mixte | Sans LPP | CHF 34'416 | 20% du revenu net total, plafonné |

---

## Règles de Calcul Détaillées

### 1. Salarié avec LPP
- **Plafond** : Montant fixe annuel (voir tableau)
- **Condition** : Affilié à une caisse de pension LPP via l'employeur
- **Déduction fiscale** : Montant versé déductible jusqu'au plafond

### 2. Salarié sans LPP
- **Plafond** : 20% du revenu net AVS, plafonné au montant maximal (voir tableau)
- **Condition** : Pas d'affiliation LPP (rare pour un salarié)
- **Calcul** : `min(revenu_net_AVS * 0.20, plafond_max)`

### 3. Indépendant avec LPP (volontaire)
- **Plafond** : Montant fixe annuel (voir tableau)
- **Condition** : Affilié volontairement à une caisse LPP (via association/fondation)
- **Déduction fiscale** : Montant versé déductible jusqu'au plafond

### 4. Indépendant sans LPP
- **Plafond** : 20% du revenu net AVS, plafonné au montant maximal (voir tableau)
- **Condition** : Pas d'affiliation LPP (cas le plus fréquent)
- **Calcul** : `min(revenu_net_AVS * 0.20, plafond_max)`
- **Important** : Le revenu net AVS est le revenu après déductions sociales

### 5. Mixte (Salarié + Indépendant)
- **Règle générale** : Le plafond dépend de l'activité principale
- **Si activité principale salariée avec LPP** : Plafond fixe (voir tableau)
- **Si activité principale indépendante sans LPP** : 20% du revenu net total, plafonné
- **Attention** : Cas complexe nécessitant un calcul précis par un fiscaliste

---

## Format JSON pour l'Implémentation

```json
{
  "pillar_3a_limits": {
    "2026": {
      "employee_with_lpp": {
        "limit": 7258,
        "calculation": "fixed",
        "currency": "CHF"
      },
      "employee_without_lpp": {
        "limit": 36288,
        "calculation": "percentage",
        "percentage": 0.20,
        "base": "net_income_avs",
        "currency": "CHF"
      },
      "self_employed_with_lpp": {
        "limit": 7258,
        "calculation": "fixed",
        "currency": "CHF"
      },
      "self_employed_without_lpp": {
        "limit": 36288,
        "calculation": "percentage",
        "percentage": 0.20,
        "base": "net_income_avs",
        "currency": "CHF"
      },
      "mixed_with_lpp": {
        "limit": 7258,
        "calculation": "fixed",
        "currency": "CHF"
      },
      "mixed_without_lpp": {
        "limit": 36288,
        "calculation": "percentage",
        "percentage": 0.20,
        "base": "net_income_avs_total",
        "currency": "CHF"
      }
    },
    "2025": {
      "employee_with_lpp": {
        "limit": 7258,
        "calculation": "fixed",
        "currency": "CHF"
      },
      "employee_without_lpp": {
        "limit": 36288,
        "calculation": "percentage",
        "percentage": 0.20,
        "base": "net_income_avs",
        "currency": "CHF"
      },
      "self_employed_with_lpp": {
        "limit": 7258,
        "calculation": "fixed",
        "currency": "CHF"
      },
      "self_employed_without_lpp": {
        "limit": 36288,
        "calculation": "percentage",
        "percentage": 0.20,
        "base": "net_income_avs",
        "currency": "CHF"
      },
      "mixed_with_lpp": {
        "limit": 7258,
        "calculation": "fixed",
        "currency": "CHF"
      },
      "mixed_without_lpp": {
        "limit": 36288,
        "calculation": "percentage",
        "percentage": 0.20,
        "base": "net_income_avs_total",
        "currency": "CHF"
      }
    },
    "2024": {
      "employee_with_lpp": {
        "limit": 7056,
        "calculation": "fixed",
        "currency": "CHF"
      },
      "employee_without_lpp": {
        "limit": 35280,
        "calculation": "percentage",
        "percentage": 0.20,
        "base": "net_income_avs",
        "currency": "CHF"
      },
      "self_employed_with_lpp": {
        "limit": 7056,
        "calculation": "fixed",
        "currency": "CHF"
      },
      "self_employed_without_lpp": {
        "limit": 35280,
        "calculation": "percentage",
        "percentage": 0.20,
        "base": "net_income_avs",
        "currency": "CHF"
      },
      "mixed_with_lpp": {
        "limit": 7056,
        "calculation": "fixed",
        "currency": "CHF"
      },
      "mixed_without_lpp": {
        "limit": 35280,
        "calculation": "percentage",
        "percentage": 0.20,
        "base": "net_income_avs_total",
        "currency": "CHF"
      }
    }
  }
}
```

---

## Fonction de Calcul (Pseudo-code)

```dart
double calculate3aLimit({
  required int year,
  required String employmentStatus,
  required bool has2ndPillar,
  double? netIncomeAVS,
}) {
  // Récupérer les paramètres de l'année
  final params = pillar3aLimits[year];
  
  // Déterminer la clé selon le statut
  String key;
  if (employmentStatus == 'employee') {
    key = has2ndPillar ? 'employee_with_lpp' : 'employee_without_lpp';
  } else if (employmentStatus == 'self_employed') {
    key = has2ndPillar ? 'self_employed_with_lpp' : 'self_employed_without_lpp';
  } else if (employmentStatus == 'mixed') {
    key = has2ndPillar ? 'mixed_with_lpp' : 'mixed_without_lpp';
  } else {
    return 0; // Étudiant, retraité, autre
  }
  
  final config = params[key];
  
  // Calculer selon la règle
  if (config['calculation'] == 'fixed') {
    return config['limit'];
  } else if (config['calculation'] == 'percentage') {
    if (netIncomeAVS == null) {
      return config['limit']; // Retourner le plafond max si revenu inconnu
    }
    final calculated = netIncomeAVS * config['percentage'];
    return min(calculated, config['limit']);
  }
  
  return 0;
}
```

---

## Sources et Références

- [Office fédéral des assurances sociales (OFAS)](https://www.bsv.admin.ch/)
- [Administration fédérale des contributions (AFC)](https://www.estv.admin.ch/)
- [Prévoyance professionnelle - Lois et ordonnances](https://www.admin.ch/gov/fr/accueil/droit-federal/recueil-systematique.html)

---

## Mise à Jour

Ce fichier doit être mis à jour **chaque année** (généralement en décembre) lorsque les nouveaux plafonds sont annoncés par l'OFAS.

**Dernière mise à jour** : 2026-01-11
**Prochaine révision prévue** : 2026-12-01
