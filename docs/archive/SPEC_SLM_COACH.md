# SPEC SLM COACH — Gemma 3n 4B E4B On-Device Integration

> **Status**: Spec approuvee, implementation prevue S35-S38
> **Source**: Audit externe revise (2026-02-25) + decisions architecturales internes
> **ADR lié**: `decisions/ADR-20260223-unified-financial-engine.md`
> **Fichiers impactes**: `coach_llm_service.dart` (remplacement), `coach_narrative_service.dart` (adaptation)

---

## 1. Decision

Remplacer l'architecture BYOK (Bring Your Own Key) par un SLM (Small Language Model) on-device comme source primaire de narration, tout en conservant les templates enrichis comme fallback et le BYOK cloud comme option power-user.

### Modele choisi

| Parametre | Valeur |
|-----------|--------|
| Modele | **Gemma 3n 4B E4B** (Google) |
| Architecture | Sparse — 4B parametres effectifs |
| Framework | **MediaPipe LLM Inference** (plugin Flutter) |
| Quantisation | INT4 |
| Taille disque | ~2.3 GB |
| Performance cible | 15-25 tokens/s (iPhone 14+, Neural Engine) |
| Plateformes | iOS + Android |

### Pourquoi Gemma 3n 4B E4B

- Architecture sparse: plus rapide qu'un dense 4B classique a parametres effectifs equivalents
- Optimise pour l'inference on-device par Google
- Compatible MediaPipe LLM Inference (plugin Flutter officiel)
- Sweet spot pour des micro-taches de 20-80 tokens (exactement le pattern CoachNarrative)

---

## 2. Architecture 3-Tiers

```
Tier 1 — SLM on-device (Gemma 3n 4B E4B)
  ├── 6 blocs narratifs CoachNarrative (greeting → milestone)
  ├── Reformulation du chiffre choc
  ├── Explication educative contextuelle
  ├── Post-OCR structuration (aide a l'extraction)
  └── Traduction a la volee (FR↔DE) des templates

Tier 2 — Templates enrichis (fallback, zero IA)
  ├── Mode actuel avec CoachContext injecte
  ├── Active si: device trop vieux, SLM en download, erreur, >2 blocs rejetes
  └── Qualite plancher garantie (pas de degradation UX)

Tier 3 — Cloud LLM via BYOK (optionnel, power users)
  ├── Deep Q&A juridique/fiscal (questions complexes)
  ├── Scenarios what-if conversationnels
  └── Analyse narrative longue (rapport annuel PDF)
```

### Logique de selection

```
if (slmLoaded && slmHealthy)
  → Tier 1 (SLM on-device)
  → si ComplianceGuard rejette >2 blocs sur 6 → fallback Tier 2
else if (byokConfigured)
  → Tier 3 (Cloud LLM)
else
  → Tier 2 (Templates enrichis)
```

---

## 3. Mapping SLM → CoachNarrative (6 blocs)

Chaque bloc est un appel independant et court. Le SLM ne produit jamais de texte long.

| Bloc | Tokens max | Exemple output |
|------|------------|----------------|
| `greeting` | ~20 | "Salut Julien, bonne journee pour ta prevoyance!" |
| `scoreSummary` | ~60 | "62 sur 100 — c'est solide. Ton 3a est en bonne voie, mais ton 2e pilier merite attention." |
| `trendMessage` | ~40 | "En progression depuis 3 mois — continue comme ca." |
| `topTipNarrative` | ~80 | "Ton rachat LPP pourrait t'economiser CHF {montant} d'impots cette annee. Ca vaut le coup d'y regarder." |
| `urgentAlert` | ~40 | "Attention: il reste {jours} jours pour verser sur ton 3a avant la cloture fiscale." |
| `milestoneMessage` | ~40 | "Bravo! Tu as franchi le cap des CHF {montant} de patrimoine net." |

---

## 4. Prompt Pattern

### System prompt (commun, charge une seule fois)

```
Tu es le coach financier de MINT, une app educative suisse.
Tu reformules des donnees en phrases naturelles et empathiques en francais (tutoiement).
Tu ne calcules JAMAIS.
Tu ne recommandes JAMAIS de produit financier specifique.
Tu n'inventes JAMAIS de chiffre.
Tu utilises UNIQUEMENT les donnees fournies dans le contexte.
Ton role est educatif: expliquer, alerter, encourager. Jamais prescrire.
```

### Template par bloc

```
Context: {CoachContext serialise — ratios, scores, delais, pas de montants bruts sauf ceux explicitement fournis}

Task: Genere un {bloc_type} de maximum {max_tokens} mots.
Contraintes: Tutoiement. Pas de terme banni (garanti, certain, assure, sans risque, optimal, meilleur, parfait). Pas de calcul. Pas de recommandation de produit.
```

### Regle fondamentale

**Le SLM ne genere JAMAIS de chiffre.** Tous les nombres dans l'output proviennent du CoachContext, injectes comme variables `{montant}`, `{jours}`, `{score}`. Le ComplianceGuard verifie que tout nombre dans l'output est present dans le contexte d'entree (tolerance ±5%).

---

## 5. ComplianceGuard — 5 couches de post-processing

Chaque bloc est post-traite independamment AVANT affichage. Si un bloc echoue, il est remplace par son equivalent template (fallback invisible).

### Couche 1 — Termes bannis
```
Regex scan: /garanti|certain|assuré|sans risque|optimal|meilleur|parfait|conseiller/i
Action: REJECT bloc → fallback template
```

### Couche 2 — Detection prescriptive
```
Regex scan: /tu dois|tu devrais|il faut absolument|acheter|vendre|investir dans/i
Action: REJECT bloc → fallback template
```

### Couche 3 — Verification chiffres (anti-hallucination)
```
1. Extraire tous les nombres de l'output SLM
2. Verifier que chaque nombre existe dans le CoachContext (tolerance ±5%)
3. Si un nombre inconnu est detecte → REJECT bloc → fallback template
```

### Couche 4 — Disclaimer
```
Si le bloc contient une mention financiere specifique (montant, taux, rendement):
  → Ajouter micro-disclaimer: "Estimation educative — consulte un·e specialiste pour ta situation."
```

### Couche 5 — Longueur
```
Si le bloc depasse max_tokens × 1.5:
  → REJECT bloc → fallback template (le SLM "bavarde" parfois)
```

### Regle du fallback cascade

```
Si ComplianceGuard rejette > 2 blocs sur 6:
  → Basculer TOUS les blocs vers templates enrichis pour cette session
  → Logger l'evenement pour monitoring
  → L'utilisateur ne voit JAMAIS de message d'erreur IA
```

---

## 6. Lifecycle du modele (download, warm-up, memoire)

### Premier lancement

1. Detecter la compatibilite device (RAM >= 4GB, stockage >= 3GB libre)
2. Si compatible: proposer le download avec explication UX
   - "MINT telecharge ton coach financier personnel. Une seule fois, ensuite tout reste sur ton telephone."
   - Barre de progression, estimation du temps, possibilite d'annuler
   - Download en arriere-plan: l'utilisateur peut explorer l'app en mode templates pendant le telechargement
3. Si non compatible: rester en mode templates (Tier 2), aucune degradation UX

### Warm-up (chargement memoire)

- Duree: 3-8 secondes selon device
- **Strategie**: Charger le modele en background a l'ouverture de l'app, PAS quand l'utilisateur arrive sur le dashboard
- Le premier bloc (`greeting`) est pret instantanement quand l'utilisateur ouvre le dashboard
- Gestion memoire: decharger le modele si l'app passe en background > 5 minutes

### Pre-generation

- Avec le cache 24h existant dans CoachNarrativeService, on peut pre-generer les 6 blocs des que le modele est chaud
- Strategie: generer au warm-up + invalider si nouveau check-in

---

## 7. Integration dans le code existant

### Nouveau fichier: `slm_coach_service.dart`

Remplace `coach_llm_service.dart` (662 lignes) avec la meme interface publique mais un backend local.

```dart
// Interface identique a CoachLlmService
class SlmCoachService {
  // Singleton — charge le modele une seule fois
  static Future<void> warmUp();
  static bool get isReady;
  static bool get isDownloaded;
  static Future<void> downloadModel({Function(double)? onProgress});

  // Generation par bloc (identique a l'interface LLM)
  static Future<String> generateBlock({
    required CoachBlockType blockType,
    required CoachContext context,
    int maxTokens = 80,
  });

  // Cleanup memoire
  static Future<void> dispose();
}
```

### Modification: `coach_narrative_service.dart`

```dart
// Ligne ~118: Ajouter le SLM comme source primaire
// AVANT (dual mode):
//   BYOK configure → appel LLM via RagService
//   Pas de BYOK  → templates statiques
//
// APRES (tri mode):
//   SLM charge et pret → appel SLM on-device + ComplianceGuard
//   SLM indisponible + BYOK configure → appel LLM cloud
//   Sinon → templates statiques
```

### Nouveau fichier: `compliance_guard_service.dart`

```dart
class ComplianceGuardService {
  /// Verifie un bloc SLM contre les 5 couches.
  /// Retourne le bloc valide ou null si rejete.
  static String? validate({
    required String slmOutput,
    required CoachBlockType blockType,
    required CoachContext inputContext,
  });

  /// Verifie que tous les nombres dans l'output existent dans le contexte.
  static bool verifyNumbers(String output, CoachContext context);
}
```

---

## 8. Tests adversariaux (pre-activation obligatoire)

Avant d'activer le SLM en production, une suite de tests adversariaux doit passer a 100%.

### Tests de compliance

```
- Injecter un prompt qui tente: "tu devrais acheter des ETF" → doit etre REJECT
- Injecter un prompt qui tente: "c'est garanti a 7%" → doit etre REJECT
- Injecter un prompt qui tente: "le meilleur investissement" → doit etre REJECT
- Verifier qu'un chiffre hallucine (absent du contexte) → doit etre REJECT
- Verifier que le fallback template est identique visuellement au bloc SLM valide
- Verifier que l'utilisateur ne voit jamais de message d'erreur IA
```

### Tests de performance

```
- Temps de generation < 3s par bloc sur iPhone 14
- Temps de generation < 5s par bloc sur Android mid-range (Pixel 7a)
- Memoire < 500MB en inference
- Batterie: < 2% par session complete (6 blocs)
- Taille download: verifier le poids reel du modele quantise
```

### Tests de fallback

```
- SLM indisponible → templates fonctionnent
- 3+ blocs rejetes → bascule totale vers templates
- Download interrompu → app fonctionnelle en mode templates
- Device incompatible → aucune proposition de download
```

---

## 9. Risques identifies

| Risque | Probabilite | Impact | Mitigation |
|--------|-------------|--------|------------|
| MediaPipe Flutter plugin instable | Moyenne | Haut | Tester compatibilite avant sprint. Fallback = templates |
| Modele trop gros (2.3 GB) | Haute | Moyen | Download background, explication UX, mode templates pendant download |
| Hallucination de chiffres | Haute | Critique | ComplianceGuard couche 3 (verification stricte) |
| Latence sur Android mid-range | Moyenne | Moyen | Pre-generation au warm-up, cache 24h |
| Termes bannis dans output | Moyenne | Haut | ComplianceGuard couche 1 (regex) |

---

## 10. Planning d'implementation

| Sprint | Livrable |
|--------|----------|
| **S35** | `SlmCoachService` + download manager + warm-up lifecycle |
| **S36** | `ComplianceGuardService` (5 couches) + tests adversariaux |
| **S37** | Integration `CoachNarrativeService` tri-mode + fallback cascade |
| **S38** | Tests perf (iOS + Android) + optimisation + activation conditionnelle |

### Pre-requis (a valider AVANT S35)

- [ ] Verifier compatibilite MediaPipe LLM Inference avec la version Flutter du projet
- [ ] Tester le modele Gemma 3n 4B E4B quantise INT4 sur un device reel (iPhone 14, Pixel 7a)
- [ ] Mesurer le poids reel du modele apres quantisation
- [ ] Valider que le plugin supporte iOS + Android simultanément

---

## 11. Pricing — Decision a prendre

L'auditeur recommande **9.90 CHF/mois** (119 CHF/an) au lieu de 4.90 CHF/mois.

**Arguments pour 9.90**: Valeur objective superieure (arbitrage rente vs capital peut impacter 50-200k CHF sur une carriere). Benchmark: True Wealth 0.5%/an (~500 CHF/an), VZ 250 CHF/h.

**Arguments pour 4.90**: Decision d'achat impulsive pour un produit sans marque etablie. Taux de conversion potentiellement superieur. Possibilite de monter apres 500 abonnes payants.

**Decision en attente**: A trancher avant activation du paywall (Mois 1 du plan 90 jours).

Fichier a modifier: `apps/mobile/lib/services/subscription_service.dart` (ligne ~88 + constantes de prix).

---

## 12. Distribution — Prochaines etapes

Le gap principal n'est ni technique ni produit — c'est la distribution.

### Canaux prioritaires

1. **Beta privee** (Mois 1): 20-30 testeurs cibles via TestFlight + Internal Testing
2. **Partenariats institutionnels**: FRC (Romandie), SKS (Suisse alemanique), caisses de pension (Swisscanto, CPEG)
3. **Presse**: Le Temps, NZZ — angle "l'app suisse qui democratise le conseil financier"
4. **B2B pilot**: 2-3 departements RH ou caisses de pension pour integration
