# MILESTONE-CONTEXT — "La Beauté de Mint" (Design v2.1 → v4.0)

> À consommer par `/gsd-new-milestone --reset-phase-numbers`.
> Source de la synthèse : `visions/MINT_DESIGN_MILESTONE_BRIEF.md` + 15 audits dans `/outputs/MINT_*_AUDIT.md`.

---

## Mandat

Élever radicalement la beauté, le design, l'UI et l'UX de MINT en 2026, en s'appuyant sur 15 audits cross-disciplinaires (motion, typographie, couleur, spatial, son, horlogerie, parfumerie, cinéma, gastronomie, chorégraphie, neurosciences, wabi-sabi, art génératif, ambient computing, produit social).

Ne **pas** casser l'existant. Construire en trois couches parallèles. Ne **shipper** que Layer 1 ce milestone — Layer 2 reste en prototypes internes, Layer 3 en R&D.

---

## Principes immuables (à ajouter à `docs/DESIGN_SYSTEM.md`)

1. Le vide est un composant. Chaque écran nomme son *ma*.
2. Une seule idée par plan.
3. L'incertitude est belle — toute projection a son `<ConfidenceObject>`.
4. Le mouvement est respiration (250ms ease-out, jamais bouncy).
5. La typographie est l'architecture (45-75 caractères, max 3 niveaux/écran).
6. Le son est UI. Le silence aussi.
7. Régional dans la voix, universel dans la grammaire.
8. Le partage est un murmure — jamais comparatif, jamais classé.
9. Présence sans interruption.
10. Designer pour 18 et 99 dans le même geste.

---

## Layer 1 — v2.1 "Le murmure" (CE MILESTONE — 4 à 8 semaines)

### L1.1 — Audit du vide
Passer chaque écran en revue avec une seule question : *qu'est-ce qu'on enlève ?* Objectif chiffré : -20% d'éléments visuels en moyenne, jamais de fonctionnalité supprimée. Livrable : `docs/DESIGN_AUDIT_VIDE.md` listant chaque écran et chaque suppression. Concerne en priorité Pulse, Retirement Dashboard, Rente vs Capital, Coach.

### L1.2 — `<ConfidenceObject>` v1 (CRITIQUE)
- Créer un composant Flutter unique réutilisable (nom à figer : recommandation `MintConfidenceHalo` ou `MintTrameConfiance` — décision Julien requise).
- Utilisé partout où s'affiche une projection (`projection_dashboard`, `rente_vs_capital`, `lpp_deep`, `forecaster`, `arbitrage`).
- Animation de bloom à l'apparition (250ms ease-out, opacité 0 → 1, scale 0.96 → 1).
- 4 axes visualisés : completeness × accuracy × freshness × understanding.
- Tap pour ouvrir le détail (mécanisme visible à la demande, sinon en filigrane).
- Tests goldens obligatoires.

### L1.3 — Microtypographie pass
- Audit Montserrat/Inter sur tous les écrans.
- Largeur de paragraphe : optimal length 45-75 caractères, jamais au-delà de 80.
- Kerning, line-height, espacement vertical revus.
- Maximum 3 niveaux de hiérarchie typographique visibles par écran.
- Livrable : MR Flutter touchant `lib/theme/text_styles.dart` + écrans hero.

### L1.4 — Lock Screen widget + Apple Watch complication
- Une ligne : "Le premier éclairage du jour" (jamais "chiffre choc" — terme banni, voir CLAUDE.md §1).
- Mise à jour 1×/jour. Glance-able, 0 interaction requise.
- iOS WidgetKit (small) + complication Watch (modular small).
- Backend : nouvel endpoint `GET /api/v1/daily-glimmer/{userId}` retournant 1 phrase ≤ 60 caractères + source.
- Compliance ComplianceGuard obligatoire avant envoi widget.

### L1.5 — Palate cleansers
- Insérer des écrans de respiration de ~2 secondes entre deux flows lourds (fiscalité ↔ succession, dette ↔ retraite, divorce ↔ patrimoine).
- Composant `MintBreathScreen` réutilisable : fond uni, phrase courte, animation respiration (4s in / 4s out), tap pour passer.
- Pas de skip forcé — l'utilisateur peut traverser instantanément.

### L1.6 — MINT Signature v0 (prototype interne uniquement)
- Glyphe/texture déterministe généré depuis l'archétype + canton + 2-3 événements de vie.
- Implémenté avec `CustomPainter` Flutter, seed = hash du profil.
- **Non shippé en prod ce milestone**. Test interne sur ≤ 50 testeurs (TestFlight closed group).
- Livrable : `lib/widgets/experimental/mint_signature.dart` + doc `docs/EXPERIMENTAL_SIGNATURE.md`.
- Inspiration technique : `outputs/MINT_GENERATIVE_TECHNICAL_SPEC.md`.

### L1.7 — Régional voice — pilote 3 cantons
- VS (suisse romand, direct/montagnard), ZH (deutschschweiz urbain), TI (italien chaleureux).
- Microcopy uniquement — JAMAIS la structure ni les fonctionnalités.
- Étendre `RegionalVoiceService.forCanton()` (déjà existant) + ARB files.
- Livrable : 30 chaînes microcopy localisées par canton pilote, validées par un native.

---

## Layer 2 — v3.0 "Le menu" (~6 mois — PROTOTYPES INTERNES SEULEMENT CE MILESTONE)

Documenter, prototyper, ne pas shipper :
- **L2.1** Taxonomie de plans (WIDE / CLOSE-UP / MONTAGE / SPLIT SCREEN / MASTER) → re-mapper les 67 routes canoniques. Doc dans `docs/DESIGN_PLAN_TAXONOMY.md`.
- **L2.2** Lifecycle = menu dégustation. Redesign des 18 événements de vie comme un menu. Doc + 1 prototype Figma.
- **L2.3** `<ConfidenceObject>` v2 : 4-axis helix interactive. Spike technique uniquement.
- **L2.4** MINT Signature v1 (généralisable). Pas en prod.
- **L2.5** AirPods coach voice — POC avec claude_coach_service. Pas en prod.
- **L2.6** MINT Cards format. POC + 5 cartes statiques.
- **L2.7** Couple/famille co-views. Mock Figma.
- **L2.8** Cérémonie mensuelle. Mock Figma + 1 prototype scrolly.

---

## Layer 3 — v4.0+ "L'air" (R&D — DOCUMENT SEULEMENT CE MILESTONE)

Créer `docs/DESIGN_HORIZON_2027_2028.md` listant :
- Vision Pro / smart glasses (visualisation spatiale couple)
- CarPlay / agent voix
- Biofeedback opt-in (HRV)
- Cantons APIs (intégration administrative profonde)
- MINT comme heirloom numérique (autobiographie financière transmissible)

Aucun code. Document de vision uniquement.

---

## Compliance & règles non-négociables

- **Aucune** comparaison sociale ("top X% des Suisses" reste banni — CLAUDE.md §6).
- **Aucun** ranking, classement, leaderboard.
- **Aucune** mention "chiffre choc" — utiliser **"premier éclairage"** systématiquement.
- ComplianceGuard sur **tout** texte généré côté widget/voice/coach.
- Régional reste subtil — jamais caricature.
- Designer pour 18-99 — jamais d'écran qui exclut une tranche d'âge.
- Aucun hardcode de couleur — `MintColors.*` uniquement.
- Toute string user-facing → ARB 6 langues.
- Tests goldens sur tous les écrans modifiés.
- `flutter analyze` 0 issue avant merge.

---

## Tests Visual QA — Double Filet

### Filet 1 — Goldens (CI obligatoire)
- Goldens régénérés sur tous les écrans touchés par L1.1, L1.2, L1.3, L1.4, L1.5.
- Échec golden = blocage MR.

### Filet 2 — Patrol integration tests
- Au moins **un test Patrol** par chantier L1 vérifiant le rendu réel sur device + screenshot live.
- Couverture cible : `MintConfidenceHalo`, widget Lock Screen, Watch complication, MintBreathScreen, écran Pulse retravaillé.
- Screenshots Patrol commités dans `test/visual/patrol_screens/` à chaque run CI principal.

---

## Decision points à demander à Julien AVANT exécution

1. Nom français du composant `<ConfidenceObject>` : `MintHaloConfiance` / `MintTrameConfiance` / autre ?
2. Layer 1 — quel chantier sacrifier si on ne peut en faire que 5 sur 7 ?
3. Lock Screen widget : iOS d'abord, ou iOS+Android en parallèle ?
4. Régional voice : VS/ZH/TI confirmé, ou autre tri ?
5. MINT Signature v0 : test interne autorisé sur 50 utilisateurs TestFlight, ou strictement local ?

---

## Sources documentaires

- Brief synthèse : `visions/MINT_DESIGN_MILESTONE_BRIEF.md`
- Wave 3 audits intégraux dans `/outputs/` :
  - `MINT_NEUROAESTHETICS_AUDIT.md`
  - `MINT_WABI_SABI_AUDIT.md`
  - `MINT_GENERATIVE_AUDIT.md` + `MINT_GENERATIVE_TECHNICAL_SPEC.md`
  - `MINT_AMBIENT_AUDIT.md`
  - `MINT_SOCIAL_PRODUCT_AUDIT.md`
- Wave 1 + Wave 2 : distillés dans le brief (à régénérer en archive si besoin).
- Existant à respecter : `docs/DESIGN_SYSTEM.md`, `docs/VOICE_SYSTEM.md`, `CLAUDE.md`, `rules.md`.

---

*Une fois ce milestone consommé par GSD, ce fichier sera supprimé. Le brief `MINT_DESIGN_MILESTONE_BRIEF.md` reste source de vérité long-terme dans `visions/`.*
