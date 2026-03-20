# MINT — Vision Unifiée V1
## "Cercles Herméneutiques" pour la Finance Suisse

> **Date**: 11 mars 2026
> **Statut**: Archive stratégique utile — principes encore valables, architecture IA obsolète
> **Supersède**: vision_product.md, vision_features.md, UX_V2_COACH_CONVERSATIONNEL.md (ces docs restent comme archives de référence)
> **Source de vérité**: non. Lire d'abord `CLAUDE.md` puis `MINT_UX_GRAAL_MASTERPLAN.md`.
> **Ce document reste utile pour**: principes suisses, lisibilité, transparence, garde-fous éducatifs.
> **Ce document n'est plus directeur pour**: navigation, nombre d'onglets, taxonomie écran, séquence de migration.

---

## 1. MISSION (inchangée)

**"Juste quand il faut: une explication, une action, un rappel."**

MINT est un mentor financier éducatif pour résidents suisses. Read-only, jamais de mouvement d'argent, jamais de conseil en investissement (LSFin art. 3).

---

## 2. LES 7 PRINCIPES HERMÉNEUTIQUES (H1–H7)

> Théorie: chaque cercle de compréhension enrichit le suivant. L'utilisateur part de "je ne sais pas ce que je ne sais pas" et arrive à "je vois clairement ma situation et mes options".

### H1 — Lisibilité immédiate
> "Si tu dois relire, c'est qu'on a échoué."

- **Règle**: 1 écran = 1 information = 1 action possible
- **Max**: 8 mots par titre, 2 lignes par explication
- **Chiffre-choc**: toujours UN nombre contextuel, jamais un tableau

**Amendement actuariel**: Le chiffre-choc doit inclure une fourchette (±X%) quand la confiance < 70%. Ne jamais montrer un nombre unique comme une certitude.

**Amendement fiscal**: Cadrer le chiffre en coût net, pas en économie brute. "Un rachat LPP de 15k te coûte 10'200 après économie fiscale" > "Économise 4'800 d'impôts".

**Amendement UX**: Le chiffre peut terrifier. Toujours cadrer en progrès: "Tu as couvert 65% de ton objectif retraite" > "Il te manque 450k".

### H2 — Progression naturelle
> "On ne montre pas l'altitude quand on apprend à marcher."

- **Cercle 1** (30 sec): Canton, âge, revenu, statut → première estimation (~25% visibilité)
- **Cercle 2** (5 min): Famille, épargne, 3a → estimation enrichie (~45%)
- **Cercle 3** (1 semaine): Certificat LPP, relevé fiscal → projection fiable (~70%)
- **Cercle 4** (1 mois): Open Banking, extrait AVS → vision quasi-complète (~85%)
- **Cercle 5** (annuel): Mise à jour certificats → maintien précision (>75%)

**Amendement prévoyance**: Ajouter "libre passage" comme jalon du Cercle 3. C'est le plus gros angle mort: des utilisateurs ont 50-200k en libre passage sans le savoir.

### H3 — Contextualité radicale
> "Ton profil dicte ce que tu vois."

- 8 archétypes (swiss_native, expat_eu, expat_us, independent_no_lpp, etc.)
- Chaque écran adapte: chiffres, références légales, alertes, CTAs
- Un concubin ne voit PAS le plafond AVS couple (LAVS art. 35)
- Un indépendant sans LPP voit le plafond 3a élargi (36'288 CHF)

**Amendement actuariel**: Les 3 incertitudes "tueuses" doivent être modélisées par archétype: rendement LPP réel (2-5%), inflation (0-2%), longévité (±5 ans). Chaque archétype a un profil de risque différent.

**Amendement compliance**: La contextualité NE DOIT PAS franchir la limite LSFin. "Simuler un rachat" = OK. "Racheter maintenant" = interdit. Le système doit détecter automatiquement les formulations prescriptives.

### H4 — Transparence totale
> "Jamais de boîte noire. Chaque chiffre a une source."

- Chaque projection: source légale (LPP art. X, LAVS art. Y)
- Chaque estimation: hypothèses explicites (taux 2%, inflation 1%)
- Chaque donnée: provenance visible (saisi manuellement / scanné / Open Banking)
- Micro-disclaimer inline, jamais caché par le scroll

**Amendement fiscal**: Ajouter l'impôt anticipé (Verrechnungssteuer 35%) comme hypothèse explicite sur tout rendement affiché. C'est le plus gros piège fiscal ignoré.

**Amendement compliance**: Le disclaimer doit être EN HAUT de chaque projection (pas en bas). L'utilisateur doit voir "outil éducatif" AVANT le chiffre-choc, pas après.

### H5 — Éducation avant action
> "Comprendre pourquoi > savoir quoi faire."

- Chaque CTA est éducatif: "Simuler", "Explorer", "Découvrir l'impact de…"
- Jamais prescriptif: ~~"Rachète"~~, ~~"Verse"~~, ~~"Améliore"~~
- Inserts éducatifs contextuels: 1 concept = 1 paragraphe = 1 exemple chiffré
- Format IF/THEN pour les actions: "Si tu as un 3a → simule l'impact fiscal"

**Amendement prévoyance**: L'éducation doit aussi couvrir les SÉQUENCES d'arbitrage. Les 5 leviers (3a, rachat LPP, EPL, amortissement, décaissement) interagissent. Montrer l'impact séquentiel, pas juste chaque levier isolément.

**Amendement UX**: Pour V1, utiliser des templates statiques intelligents plutôt que le coach LLM. 20 templates bien écrits couvrent 80% des cas. Le LLM est un risque de complexité non nécessaire au lancement.

### H6 — Couple comme unité
> "Deux parcours, une trajectoire commune."

- Profil double: chaque partenaire a son score, ses projections, ses alertes
- Score couple = moyenne pondérée par revenu, alerte si écart > 15 points
- Vue "Julien / Lauren / Couple" sur Pulse et dans le chat
- Séquençage: qui retire quoi et quand (optimisation décaissement couple)

**Amendement actuariel**: Ajouter le survivant LPP (rente de veuf/veuve ≠ pour concubins vs mariés). Le conjoint survivant est un angle mort majeur pour les concubins.

**Amendement fiscal**: Le couple doit voir le séquençage fiscal optimal de retrait du capital (étaler sur 2 années fiscales si possible).

### H7 — Sobriété intentionnelle
> "Chaque pixel doit mériter sa place."

- V1: ~25 écrans maximum (vs ~60+ aujourd'hui)
- Pas de feature flags, pas de modes cachés, pas de paramètres avancés
- Si un écran n'a pas de CTA éducatif clair, il n'existe pas
- Design: blanc/gris clair, accents pastel, typographie aérée, zéro ornement

**Amendement UX**: Couper ruthlessly. La tentation de "juste ajouter un petit truc" est l'ennemi #1. Chaque feature ajoutée AVANT le lancement retarde le lancement. Ship MLP (Minimum Lovable Product), mesurer la rétention J7/J30, PUIS ajouter.

---

## 3. ARCHITECTURE V1 — 3 ONGLETS, ~25 ÉCRANS

### Tab 1 — PULSE (data-first, aucune saisie requise)

```
┌─ Visibilité financière 72% ─────────┐
│  [████████████░░░░░]                │
│                                      │
│  💡 "Ton taux de remplacement est   │
│     estimé à 65%. L'objectif usuel  │
│     est 70-80%."                    │
│  ℹ️ Estimation · Hypothèses ▸       │
│                                      │
│  ─ Tes priorités ─                  │
│  ┌─────────────────────────────┐    │
│  │ 🎯 Retraite                 │    │
│  │ CHF 2'180/mois estimés      │    │
│  │ [Simuler ta projection →]   │    │
│  │ ℹ️ LAVS art. 34 · LPP art.14│   │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ 💰 Fiscalité                │    │
│  │ ~4'800 CHF d'impact 3a      │    │
│  │ [Découvrir l'impact →]      │    │
│  │ ℹ️ LIFD art. 33 · OPP3     │    │
│  └─────────────────────────────┘    │
│                                      │
│  ─ Comprendre ─                     │
│  Rente vs Capital · Rachat LPP ·    │
│  Optimisation 3a · Libre passage    │
│                                      │
│  ℹ️ Outil éducatif · LSFin art. 3  │
└──────────────────────────────────────┘
```

### Tab 2 — MINT (coach conversationnel)

- Chat avec SLM on-device / BYOK / templates fallback
- Response Cards inline (même format que Pulse)
- Suggestions contextuelles basées sur le profil
- ComplianceGuard + HallucinationDetector sur chaque réponse

### Tab 3 — MOI (profil & données)

- Profil personnel + conjoint
- Archétype détecté (modifiable)
- Score de visibilité détaillé (4 axes L/F/R/S)
- Connexions (documents scannés, Open Banking sandbox)
- Paramètres (langue, notifications, BYOK)

### Écrans dédiés (~15)

| # | Écran | CTA éducatif |
|---|-------|-------------|
| 1 | Onboarding — 4 questions d'or | Obtenir ma première estimation |
| 2 | Onboarding — Sélecteur de stress | Choisir ma priorité |
| 3 | Onboarding — Premier aperçu | Voir mes 3 premières pistes |
| 4 | Trajectoire retraite | Simuler mes scénarios |
| 5 | Rente vs Capital | Explorer le point d'équilibre |
| 6 | Rachat LPP | Simuler l'impact fiscal |
| 7 | EPL (retrait anticipé) | Simuler un retrait |
| 8 | Budget / Reste à vivre | Voir ma marge mensuelle |
| 9 | Pilier 3a | Découvrir l'impact fiscal |
| 10 | Hypothèque (Tragbarkeit) | Vérifier ma capacité |
| 11 | Optimisation décaissement | Simuler le séquençage |
| 12 | Scanner de document | Scanner mon certificat LPP |
| 13 | Couple — Invitation conjoint | Inviter mon/ma partenaire |
| 14 | Rapport PDF | Exporter mon bilan |
| 15 | Invalidité — gap analysis | Voir ma couverture |

### Écrans SUPPRIMÉS en V1

| Ancien écran | Raison | Contenu migré vers |
|-------------|--------|-------------------|
| ExploreTab | Redondant avec "Comprendre" | Pulse → section Comprendre |
| FinancialSummary standalone | Remplacé par Pulse | Tab 1 Pulse |
| MentorFAB (bouton flottant) | Remplacé par Tab 2 | Tab 2 Mint |
| Life events catalogue (18) | Trop de surface, pas assez de profondeur | Pulse → cartes contextuelles |
| Advisor directory | Hors scope éducatif | Lien externe si pertinent |
| Multiple wizard flows | Trop fragmenté | Onboarding unifié + profil |

---

## 4. SCORE "VISIBILITÉ FINANCIÈRE" — Spécification

### Définition
Mesure le **degré de connaissance** de l'utilisateur sur sa propre situation. PAS la qualité de sa situation.

- 72% = "Tu as une vision claire de 72% de ta situation"
- 100% = Vision complète (ne signifie PAS "tout va bien")

### 4 axes

| Axe | Mesure | /25 (Phase 0) |
|-----|--------|---------------|
| **L** Liquidité | Budget, épargne, dettes, coussin | 25 |
| **F** Fiscalité | Situation fiscale, optimisations connues | 25 |
| **R** Retraite | 1er + 2e + 3e pilier | 25 |
| **S** Sécurité | Assurances, protection famille, succession | 25 |

### Phase 0: Pondération uniforme (25/25/25/25)
### Phase 1: Pondération contextuelle

```
Défaut:            25 / 25 / 25 / 25
> 55 ans:          20 / 20 / 35 / 25
Indépendant:       30 / 25 / 20 / 25
Endetté:           35 / 20 / 20 / 25
Couple (écart>15): Alerte sur le partenaire le plus faible
```

### Fraîcheur: pas de punition

Le score affiché reste gelé à la dernière mise à jour. En interne, `ConfidenceScorer` applique la décroissance pour prioriser les actions. Nudge doux après 6 mois: "Tes données LPP datent de 8 mois. Mets à jour pour plus de précision."

---

## 5. COMPLIANCE — Exigences non-négociables V1

### 5.1 Déjà implémenté ✅
- Termes bannis (garanti, optimal, conseiller…) → détecteur actif
- Micro-disclaimer inline sur chaque carte
- Références légales sur chaque projection
- CTAs éducatifs (simuler/explorer, jamais prescriptif)
- ComplianceGuard sur les réponses LLM

### 5.2 À implémenter avant lancement 🔴

| # | Exigence | Priorité | Effort |
|---|----------|----------|--------|
| 1 | **Disclaimer EN HAUT** de chaque projection (pas en bas) | CRITIQUE | 4h |
| 2 | **Écran consentement BYOK** — l'utilisateur doit comprendre que ses données partent vers un LLM externe | CRITIQUE | 8h |
| 3 | **Consentement données couple** — le conjoint doit accepter le partage de ses données | CRITIQUE | 8h |
| 4 | **Détecteur prescriptif renforcé** — hardening du PrescriptiveDetector pour couvrir plus de patterns | HAUTE | 8h |
| 5 | **Intervalles de confiance** sur le score de visibilité quand < 70% | HAUTE | 4h |
| 6 | **Audit templates fallback** — vérifier que les 20 templates statiques sont LSFin-compliant | HAUTE | 8h |
| 7 | **CGU / Terms of Service** — document juridique avec acceptation explicite | CRITIQUE | 4h UI + externe |

### 5.3 Recommandation FINMA
Envoyer une lettre consultative à la FINMA décrivant le positionnement de MINT (information vs conseil). Non bloquant pour le lancement mais fortement recommandé.

---

## 6. CORRECTIONS ACTUARIELLES — À intégrer

| # | Bug / Lacune | Impact | Effort |
|---|-------------|--------|--------|
| 1 | **AVS cap appliqué aux concubins** — LAVS art. 35 s'applique UNIQUEMENT aux mariés | Calcul faux pour tous les concubins | 4h |
| 2 | **Rente survivant LPP** — pas surfacée pour les concubins (risque = 0 CHF) | Angle mort critique | 8h |
| 3 | **Libre passage** — aucun simulateur, données non collectées | Plus gros angle mort patrimonial | 12h |
| 4 | **EPL timeline/remboursement** — pas surfacé clairement | Utilisateur ignore le blocage 3 ans | 4h |
| 5 | **3 incertitudes tueuses** — rendement LPP réel, inflation, longévité non modélisées | Projections trop "certaines" | 8h |
| 6 | **Impôt anticipé (35%)** — absent de l'éducation fiscale | Piège fiscal #1 pour les rendements | 4h |
| 7 | **FATCA/PFIC** — éducation totalement absente pour archétype expat_us | Lauren (golden couple) non servie | 8h |

---

## 7. SLM ON-DEVICE — Décision stratégique

### Problème actuel
Gemma 3n 4B (2.3 GB) crash sur iPhone 13 (4 GB RAM). La pré-initialisation async crée une race condition, et le modèle est téléchargé au runtime (pas bundlé).

### Décision V1

**Option retenue: SLM conditionnel + templates fallback**

```
if (deviceRAM >= 6 GB) {
  // iPhone 14+, tous les Android haut de gamme
  → Télécharger + initialiser SLM (Gemma 3n 4B)
  → Timeout 10s sur l'init, fallback si échec
} else {
  // iPhone 13, appareils < 6 GB
  → Pas de téléchargement SLM
  → Templates statiques intelligents (20 templates)
  → Option BYOK (API externe) si l'utilisateur le souhaite
}
```

### Cascade CoachOrchestrator
1. **SLM on-device** (si RAM ≥ 6 GB et modèle prêt)
2. **BYOK** (si configuré par l'utilisateur, avec consentement)
3. **Templates fallback** (toujours disponible, LSFin-compliant garanti)

### Quick fixes à implémenter
1. `await` sur la pré-initialisation (éliminer la race condition)
2. Timeout 10s sur l'init SLM
3. Check RAM < 6 GB → désactiver SLM complètement

---

## 8. ROADMAP EXÉCUTION

### Phase 0 — "Pulse sur l'existant" (S48–S49)
- [ ] Transformer Tab 1 → Pulse (score + narrative + 3 cartes)
- [ ] Section "Comprendre" avec liens simulateurs
- [ ] Simplification langage (8 mots max, zéro jargon)
- [ ] Fix SLM (3 quick fixes ci-dessus)
- [ ] Disclaimer en haut des projections
- **Critère de succès**: App améliorée, 0 régression, 0 risque

### Phase 1 — "Response Cards" (S50–S51)
- [ ] 10 templates Response Card (retraite, budget, 3a, LPP, fiscal, couple, AVS, EPL, assurance, alerte)
- [ ] Intégration dans Pulse (cartes dynamiques)
- [ ] Intégration dans Chat (Response Cards inline)
- [ ] Suggestions personnalisées (profil + archétype)
- [ ] Pondération contextuelle du score
- [ ] Consentement BYOK + couple
- [ ] Fix concubin AVS cap
- **Critère de succès**: UX unifiée cards, chat enrichi, scoring affiné

### Phase 2 — "Cleanup & Consolidation" (S52–S53)
- [ ] Supprimer ExploreTab, FinancialSummary, MentorFAB
- [ ] Tab 3 → "Moi" (profil redesign, couple first-class)
- [ ] Sélecteur Julien/Lauren/Couple
- [ ] Audit compliance complet (7 exigences)
- [ ] Libre passage simulateur
- [ ] FATCA/PFIC éducation (archétype expat_us)
- **Critère de succès**: App finale 3 onglets, ~25 écrans, architecture cible

### Post-V1 (backlog)
- Webapp companion
- Open Banking production (gate FINMA)
- Institutional APIs (caisses de pension, AVS)
- Dark mode
- Custom NLU (si templates insuffisants)
- Lettre consultative FINMA

---

## 9. MÉTRIQUES DE SUCCÈS V1

| Métrique | Cible | Mesure |
|----------|-------|--------|
| Rétention J7 | > 40% | % utilisateurs actifs 7 jours après inscription |
| Rétention J30 | > 20% | % utilisateurs actifs 30 jours après inscription |
| Completion onboarding | > 70% | % qui finissent les 4 questions d'or |
| Score visibilité moyen | > 35% | Moyenne du score après onboarding |
| Actions simulées | > 1.5/user/semaine | Nombre de simulations lancées |
| NPS | > 40 | Net Promoter Score (survey in-app) |
| Compliance incidents | 0 | Formulations prescriptives détectées en production |

---

## 10. PRINCIPES DE DÉCISION

Quand un doute survient sur une feature, appliquer dans l'ordre:

1. **Est-ce lisible en 3 secondes?** (H1) — Si non, simplifier
2. **Est-ce éducatif ou prescriptif?** (H5) — Si prescriptif, reformuler
3. **Est-ce nécessaire pour V1?** (H7) — Si non, backlog
4. **Est-ce correct actuariellement?** (H4) — Si doute, afficher la fourchette
5. **Est-ce conforme LSFin?** (H4) — Si doute, demander compliance review

---

*Ce document est la source de vérité stratégique pour MINT V1. Toute divergence avec les anciens docs vision doit être résolue en faveur de ce document.*

*Validé par: [En attente]*
*Panel d'experts: actuaire, fiscaliste, UX fintech, prévoyance 3 piliers, compliance FINMA*
