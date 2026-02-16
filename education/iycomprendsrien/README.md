# Hub Éducatif "J'y comprends rien"

Référence: [vision_features.md](/visions/vision_features.md) §6 C1 ComprendreHubScreen

---

## Principe

Le hub "J'y comprends rien" est le point d'entrée vers l'éducation financière MINT.
Chaque thème suit le pattern JIT: **Question → Action → Rappel**.

---

## Thèmes Disponibles

### 1. Le 3e pilier (3a)
| Champ | Contenu |
|-------|---------|
| **Question** | "C'est quoi le 3a et pourquoi tout le monde en parle ?" |
| **Action** | "Estimer mon économie fiscale" |
| **Route** | `/simulators/tax_impact_3a` |
| **Rappel** | "Décembre → Dernier moment pour verser cette année" |

---

### 2. La caisse de pension (LPP / 2e pilier)
| Champ | Contenu |
|-------|---------|
| **Question** | "Est-ce que j'ai une caisse de pension ?" |
| **Action** | "Comprendre LPP → plafond 3a" |
| **Route** | `/learn/lpp_vs_3a_cap` |
| **Rappel** | "Demander mon certificat LPP à mon employeur" |

---

### 3. Les lacunes AVS (1er pilier)
| Champ | Contenu |
|-------|---------|
| **Question** | "Ai-je des années de cotisation manquantes ?" |
| **Action** | "Vérifier mon extrait de compte AVS" |
| **Route** | `/learn/avs_gaps` |
| **Rappel** | "Commander mon extrait sur ahv-iv.ch" |

---

### 4. Le fonds d'urgence
| Champ | Contenu |
|-------|---------|
| **Question** | "Combien je devrais avoir de côté ?" |
| **Action** | "Calculer mon objectif fonds d'urgence" |
| **Route** | `/simulators/emergency_fund` |
| **Rappel** | "Vérifier mon épargne de sécurité chaque trimestre" |

---

### 5. Les dettes (crédit & leasing)
| Champ | Contenu |
|-------|---------|
| **Question** | "Combien me coûte vraiment ma dette ?" |
| **Action** | "Calculer le coût total de ma dette" |
| **Route** | `/simulators/leasing_vs_buy` |
| **Rappel** | "Priorité: rembourser avant d'investir" |

---

### 6. L'hypothèque (Fixe vs SARON)
| Champ | Contenu |
|-------|---------|
| **Question** | "Fixe ou SARON, c'est quoi la différence ?" |
| **Action** | "Comparer les deux stratégies" |
| **Route** | `/simulators/mortgage_strategy` |
| **Rappel** | "Avant renouvellement: comparer 3 mois à l'avance" |

---

### 7. Le reste à vivre
| Champ | Contenu |
|-------|---------|
| **Question** | "Combien il me reste après les charges fixes ?" |
| **Action** | "Estimer mon reste à vivre" |
| **Route** | `/simulators/just_available` |
| **Rappel** | "Revoir mon budget chaque mois" |

---

### 8. Les subsides LAMal
| Champ | Contenu |
|-------|---------|
| **Question** | "Ai-je droit à une aide pour mes primes ?" |
| **Action** | "Vérifier mon éligibilité (estimation)" |
| **Route** | `/learn/lamal_subsidy` |
| **Rappel** | "Les critères changent selon le canton" |

---

## Guardrails

- **Pas de promesse**: Chaque action mène à une estimation, jamais un résultat absolu
- **IF/THEN**: Les rappels utilisent toujours le format "Si... alors..."
- **Read-only**: Aucune action ne déclenche de mouvement d'argent
- **Limites visibles**: Chaque simulateur affiche ses hypothèses
