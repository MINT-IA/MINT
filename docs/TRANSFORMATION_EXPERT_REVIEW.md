# Transformation Sprint — Expert Review & Corrections

> **⚠️ LEGACY NOTE (2026-04-05):** Ce document utilise "chiffre choc" comme legacy term.
> Concept canonique : **"premier éclairage"** (voir `docs/MINT_IDENTITY.md`).
>
> Résultat du review par 4 experts (Swiss strategist, Cleo analyst,
> UX psychologue, Tech architect). Corrections à intégrer AVANT
> de lancer le sprint de transformation.

---

## 7 CORRECTIONS aux prompts de docs/TRANSFORMATION_SPRINT_PROMPTS.md

### CORRECTION 1 : Ajouter canton au 2-tap chiffre choc (Prompt 2)

Le canton est la variable #1 des calculs fiscaux suisses. Sans canton,
le chiffre choc est imprécis de 8-10%.

**Modifier Prompt 2 :**
- Ajouter un 3ème champ "Canton" (dropdown des 26 cantons, ou auto-detect)
- Utiliser le canton pour le calcul fiscal instantané
- Afficher un badge confiance : "Estimation ±15% — crée un compte pour plus de précision"

### CORRECTION 2 : Coach proactif = opt-in après 3 sessions (Prompt 1)

En culture suisse, un commentaire financier non sollicité est perçu comme
intrusif. VZ ne parle jamais en premier — le client demande.

**Modifier Prompt 1 :**
- Les 3 premières sessions : coach SILENCIEUX jusqu'à ce que l'utilisateur parle
- Après 3 sessions : proposer l'opt-in "Veux-tu que je te signale les priorités à l'ouverture ?"
- Si opt-in accepté : générer l'opener proactif
- Si refusé : ne plus proposer (respecter le choix)
- Pré-générer l'opener en background sur le PulseScreen (cache 4h)
- Si l'utilisateur tape dans les 2 premières secondes, annuler l'opener

### CORRECTION 3 : Intensité par défaut = 2, pas 3 (Prompt 1 & Voice)

L'intensité 4-5 contradicts le VOICE_SYSTEM ("calme, posé, jamais dans l'urgence").

**Modifier :**
- Default cashLevel = 2 (Clair) au lieu de 3 (Direct)
- Intensité 4-5 uniquement si l'utilisateur les choisit EXPLICITEMENT
- Les chips au premier chat montrent : Tranquille (1), Clair (2 — défaut), Direct (3), Cash (4)
- "Brut" (5) n'apparaît PAS dans les chips — accessible uniquement via settings ou commande vocale "mode brut"

### CORRECTION 4 : Glossary dans les ARB files, pas en Dart (Prompt 6)

Le GlossaryService hardcode les définitions en français dans un Map Dart.
Violation i18n (6 langues).

**Modifier Prompt 6 :**
- Les définitions vont dans les 6 ARB files : glossaryLpp, glossaryAvs, glossary3a, etc.
- GlossaryService.explain(term) lit depuis S.of(context)!.glossaryXxx
- Ajouter tracking analytics : AnalyticsService.trackEvent('glossary_lookup', {'term': term})
- Après 3 lookups du même terme, ne plus souligner (SharedPreferences flag)

### CORRECTION 5 : Couple preview personnalisée (Prompt 5)

Les exemples génériques (120k+80k) sont faibles. Si l'utilisateur a
déjà entré son salaire dans le 2-tap chiffre choc, utiliser SES données.

**Modifier Prompt 5 :**
- Si salary disponible (via le chiffre choc instantané) : calculer SA pénalité mariage
- Afficher : "Avec ton revenu de {salary}, la pénalité mariage serait d'environ {penalty}/an"
- Ajouter un signal d'espoir : "3 leviers existent pour la réduire"
- Si salary non disponible : fallback aux exemples statiques

### CORRECTION 6 : Remplacer progress bar par Confidence Score (Prompt 4)

Le progress bar "Profil 45% complet" est perçu comme une corvée.
Le Confidence Score ("Fiabilité 45%") est lié à quelque chose que
l'utilisateur VEUT (précision de sa projection).

**Modifier Prompt 4 :**
```
// AVANT : LinearProgressIndicator(value: completeness)
// APRÈS :
Text('Fiabilité de ta projection : ${confidence}%'),
Text('Ajoute ton certificat LPP → précision +25%'),
// Où confidence vient du ConfidenceScorer existant
```

### CORRECTION 7 : Ajouter analytics tracking (Tous les prompts)

Aucun prompt ne mesure quoi que ce soit. Sans analytics, impossible
de savoir si les transformations fonctionnent.

**Ajouter dans CHAQUE prompt :**
- Prompt 1 (Coach proactif) : `trackEvent('coach_opener_shown', {capId, cashLevel})`
- Prompt 2 (Chiffre choc) : `trackEvent('instant_chiffre_choc', {age, salary, result})`
- Prompt 3 (Action engine) : `trackEvent('action_cta_tapped', {screen, action, route})`
- Prompt 4 (Day-1 hook) : `trackEvent('day1_notification_tapped')` + `trackEvent('confidence_bar_shown', {pct})`
- Prompt 5 (Couple preview) : `trackEvent('couple_preview_shown', {salary, penalty})`
- Prompt 6 (Glossary) : `trackEvent('glossary_lookup', {term})`

---

## INSIGHTS ADDITIONNELS (non couverts par les prompts)

### Du Swiss strategist :
- Ajouter sur le landing : "Ce que VZ facture 1'200 CHF, tu l'as en 30 secondes"
- Le day-1 hook devrait aussi pousser le scan du certificat LPP (plus gros boost de confiance)

### Du Cleo analyst :
- Les actions doivent avoir un NOMBRE et un DÉLAI : pas "Simule ton 3a"
  mais "Verse 611 CHF avant le 31 décembre — économie fiscale : 1'833 CHF"
- Les modes d'intensité devraient être CHARACTER-based ("Mode zen" / "Mode franc")
  pas NUMBER-based ("Intensité 3")

### Du UX psychologue :
- J+1 notification : CURIOSITÉ ("On a calculé quelque chose d'intéressant")
- J+7 notification : LOSS FRAMING ("Chaque mois sans 3a, tu laisses X au fisc")
- La confiance se construit avant le loss framing — pas l'inverse

### Du Tech architect :
- Opener coach pré-généré en background (cache 4h) pour éviter 5s de latence
- Deep link notification → vérifier que le profil est chargé AVANT de naviguer
- Le couple preview ET le chiffre choc 2-tap modifient landing_screen.dart → conflit de merge probable
