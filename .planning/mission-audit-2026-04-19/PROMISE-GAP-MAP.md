# PROMISE-GAP-MAP — MINT mission vs code réel

Date : 2026-04-19
Sources : 5 audits créatifs (AUDIT-01 à AUDIT-05) + 13-AUDIT 2026-04-11 + NAVIGATION_GRAAL_V10 + CLAUDE.md + MINT_IDENTITY.md.

---

## 1. Mission promise (source = MINT_IDENTITY.md)

MINT = outil de **lucidité financière** pour TOUS les Suisses (18-99). Autour de **18 life events**. Via **4-layer insight engine** :
1. Factual extraction (le fait)
2. Human translation (ce que ça veut dire pour un humain)
3. Personal perspective (ce que ça signifie pour TOI, ton archétype, ta situation)
4. Questions to ask before signing (ce qu'il faut demander à l'autre partie)

Doctrine lucidité 2026-04-12 : dossier-first, couple asymétrique, anti-shame, situated learning.

Wire Spec V10 : 4 piliers (Aujourd'hui / Coach / Explorer / Dossier) + 7 hubs Explorer + capture contextuelle.

---

## 2. Réalité code (convergence 5/5 audits)

### Pattern central

**MINT a codé la mission "lucidité" avec la grammaire des SIMULATEURS-CALCULATEURS, pas celle des RENCONTRES-TRANSFORMATIONS.**

Preuves croisées :
- Audit 01 : les 18 life events sont codés en `TabController(length: 4)` — simulateurs-formulaires, pas scènes narrées. Layer 4 absent des 18 écrans.
- Audit 02 : 97 écrans `.dart`, 198 services, 286 widgets, 218 routes backend — dispersion structurelle qui contredit la promesse lucidité.
- Audit 03 : calculateurs fintech existent (LPP, tax, AVS, monte_carlo, arbitrage), mais ne sont pas déclenchés par les événements réels de la vie suisse (calendrier fiscal, LPP janvier, LAMal oct-nov, payslip).
- Audit 04 : inversion cognitive systémique — S1 facile là où il faut S2 gate juridique (`rachat_echelonne_screen.dart:236-294` écrit `dateRachats` à chaque slider drag = blocage EPL 3 ans ATF 142 II 399 en geste pouce).
- Audit 05 : matrice 108 cellules (18 life events × 6 dimensions) = **8 ✅ / 55 🟡 / 25 🔴 / 20 ❌**. Couverture live = **7.4%**.

### Chiffres agrégés

| Dimension | Promise | Reality |
|---|---|---|
| Destinations top-level | 4 (V10) | 3 tabs + drawer, doublons Explore/Mon argent |
| Life events live avec Layer 4 | 18/18 | **1/18** (audit 05) |
| Life events avec déclencheur UI visible | 18/18 | ~4/18 (`life_event_sheet.dart` sans call-site prod) |
| Enum LifeEvent persisté sur CoachProfile | oui | **0 hits grep** (audit 05) |
| Enum LifeEvent injecté dans coach context | oui | **0 hits grep** (audit 05) |
| Calendriers fiscaux cantonaux | 26 | 0 (audit 03) |
| Payslip parser | oui | absent (audit 03) |
| Diff LPP N/N-1 | oui | absent (audit 03) |
| S2-gate sur décisions irréversibles | oui | 0 (audit 04) |
| Écrans supprimables sans toucher mission | — | ~70/97 (audit 02) |

---

## 3. Les 5 vrais gaps qui invalident la mission aujourd'hui

### Gap A — Le life event n'est pas un citoyen de première classe
`LifeEventType` existe comme enum (`models/age_band_policy.dart:9-39`) mais n'est **ni persisté sur `CoachProfile`** ni **injecté dans `context_injector_service.dart`**. Résultat : un user qui vient d'avoir un enfant le dit au coach → rien ne persiste, rien ne déclenche, rien ne suit.

**Fix structurel** : `CoachProfile.lifeEvents: List<LifeEventRecord>` + service `LifeEventOrchestrator` qui route chaque event vers (a) persistance dossier, (b) injection coach context, (c) déclencheur UI approprié, (d) Layer 4 factory.

### Gap B — Layer 4 ("questions à poser") absent sur 17/18 events
C'est la **signature MINT** vs Cleo/VZ (MINT_IDENTITY §66-95). Sans elle, MINT est un calculateur élégant de plus. Avec elle, MINT devient "l'ami fintech dans ta poche".

**Fix structurel** : `Layer4Factory` centralisée qui produit les questions contextualisées (archétype × life event × situation). Pas par simulator. Une seule source de vérité.

### Gap C — Le calendrier suisse réel n'est pas câblé
MINT ignore quand la vie financière d'un Suisse bouge : LPP certificat (janvier), deadline fiscale cantonale (mars-juin selon canton), LAMal fenêtre résiliation (oct-nov), 3a cut-off (31 déc). Un seul rappel existe (3a oct-déc).

**Fix structurel** : `CantonalFinancialCalendar` (26 cantons × 5 events annuels) + widget banner `Aujourd'hui` + push notifications contextuelles + pré-remplissage déclaration.

### Gap D — Les décisions juridiquement irréversibles sont en geste pouce
`rachat_echelonne_screen.dart:236-294` — slider drag écrit `dateRachats` dans le profil = blocage EPL 3 ans. Zéro confirmation. C'est la définition même de l'anti-lucidité : l'user fait une décision qu'il ne comprend pas en un geste qu'il ne sait pas critique.

**Fix structurel** : `S2Gate` widget pattern sur 5 écrans (rachat LPP, EPL, retrait capital, donation, changement bénéficiaire). Confirmation modale + pre-mortem (déjà codé Phase 14) + 3 sec delay + ARB copy qui explique l'irréversibilité.

### Gap E — L'architecture à 97 écrans contredit la mission lucidité
La mission promet la clarté. L'archi délivre du gras. 70 écrans peuvent disparaître sans toucher la mission (Audit 02). 7 hubs Explorer se dédoublent avec "Mon argent", "Dossier", "Financial Summary", "Documents".

**Fix structurel** : converger vers V10 — 4 piliers (Aujourd'hui / Coach / Explorer / Dossier) + fusionner les 6 écrans "Mon argent / Financial Summary / Confidence / Documents / Portfolio / Privacy" → `Dossier` unique + supprimer les 7 hubs Explorer redondants (ou basculer vers la thèse "3 objets" d'Audit 02 si arbitrage radical).

---

## 4. Priorisation des 18 life events

### Tier 1 — Top 5 prioritaires (fréquence vie suisse × impact mission × faisabilité)

1. **newJob** — événement le plus fréquent (1-3× dans une carrière), déclenche LPP changement, salaire changement, fiscal impact. Aujourd'hui : rien de spécifique.
2. **cantonMove** — ~30k déménagements intercantonaux/an CH, fiscal marginal saute, LAMal peut changer, 3a banque peut-être à changer. Aujourd'hui : change de canton dans profil, rien d'autre.
3. **housingPurchase (EPL)** — décision irréversible + blocage 3 ans LPP. Aujourd'hui : simulator_epl existe, zéro Layer 4, zéro S2-gate.
4. **birth** — allocations LAFam cantonales, 3a plafond, LPP bonifications éducatives art. 29sexies. Aujourd'hui : `naissance_screen.dart` TabController 4 formulaire, aucun calcul cantonal, aucun flow narré.
5. **inheritance** — complexité fiscal + succession. Aujourd'hui : `donation_screen` existe, pas de flow héritage spécifique.

### Tier 2 — Secondaires (rapides à câbler, haut ROI)

6. **retirement** (déjà Tier 1 de v2.5 mais Layer 4 absent, +1j checklist selon audit 05)
7. **debtCrisis** (SafeMode déjà existant, +0.5j pour Layer 4)
8. **marriage** (couple mode asymétrique déjà en v2.5, manque Layer 4)

### Tier 3 — Long terme (complexité ou rareté)

9-18. divorce, concubinage, deathOfRelative, firstJob, selfEmployment, jobLoss, housingSale, donation, disability, countryMove (FATCA)

---

## 5. Plan de câblage ordonné (proposition pour milestone v2.8 "MINT Visible")

### Phase 31 — Câblage central (4 j agent, zone code partagée, séquentiel)

**Skill-pack** : `mint-backend-dev` + `mint-flutter-dev` + `mint-swiss-compliance` + `test-driven-development` + `verification-before-completion`.

Scope :
- `CoachProfile.lifeEvents: List<LifeEventRecord>` avec persistance backend (`/profiles/me/life-events`)
- `LifeEventOrchestrator` service (Dart + Python)
- `context_injector_service.dart` injection événements récents (< 90 jours) dans coach prompt
- `Layer4Factory` centralisée (mapping archétype × event → questions ARB 6 langues)
- Dossier cross-ref `SalaryConsistencyService` (salaire déclaré fiscal vs assuré LPP vs imposable vs budget)

Gate de sortie : 1 PR, tests green, smoke device sim iPhone : user déclare naissance → event persiste → coach en parle 2 sessions plus tard → Layer 4 affiché.

### Phase 32 — 5 life events prioritaires (8 j agent, parallélisable en 5 tracks)

Par life event (Tier 1 : newJob, cantonMove, housingPurchase, birth, inheritance), cycle chirurgical :
1. Scène narrée : remplacer `TabController(length: 4)` par flow linéaire en 4 beats (reconnaissance → translation → perspective → question)
2. Déclencheur UI : widget `Aujourd'hui` conditionnel + trigger scan/coach
3. 4 layers : fact (calculator existant) → human translation (ARB) → personal perspective (archetype-aware) → Layer 4 (Layer4Factory)
4. Persistance dossier (Phase 31 `LifeEventRecord`)
5. Tests sim iPhone : humain vit l'événement → MINT répond dans les 3 taps → Layer 4 screenshotable

**Skill-pack par agent** : `mint-flutter-dev` + `mint-swiss-compliance` (pour spécificités canton × archétype) + `test-driven-development` + `verification-before-completion`.

### Phase 33 — Calendrier fiscal 26 cantons (3 j agent, séquentiel puis parallèle)

- Service `CantonalFinancialCalendar` : table 26 cantons × 5 events annuels (fiscal deadline, LAMal oct-nov, LPP janvier, 3a 31 déc, AVS)
- Widget `Aujourd'hui` banner conditionnel si event < 30 jours
- Push notifications contextuelles (déjà infra dispo)
- Pré-remplissage déclaration si scan décl. disponible (parser existe)

**Skill-pack** : `mint-swiss-compliance` + `mint-backend-dev` + `mint-flutter-dev`.

### Phase 34 — Payslip + diff LPP N/N-1 (3 j agent)

- Parser `payslip_parser.py` (gabarit générique CH : brut, cotisations AVS/LPP/LAMal, net, 13e)
- Service `LppDiffService` : compare certificat N vs N-1, commente narrativement les écarts
- Alertes : "Ton salaire assuré a baissé de X%, voici ce que ça change" (Layer 2-3)

**Skill-pack** : `mint-backend-dev` + `mint-swiss-compliance` + `test-driven-development`.

### Phase 35 — S2-gates juridiques (2 j agent)

- Widget `S2Gate` pattern réutilisable : modal de confirmation + pre-mortem (déjà codé Phase 14) + 3 sec delay + ARB copy irréversibilité
- Application : rachat LPP, EPL, retrait capital, donation >50k, changement bénéficiaire

**Skill-pack** : `mint-flutter-dev` + `mint-swiss-compliance` (pour textes légaux cités correctement) + `verification-before-completion`.

### Phase 36 — Compression architecturale (4 j agent, séquentiel)

- Décision Julien : V10 (4 piliers) ou Audit-02 (3 objets Dossier/Coach/Action) ?
- Supprimer les 70 écrans non-mission (liste précise Audit 02)
- Fusionner Mon argent + Financial Summary + Confidence + Documents + Portfolio + Privacy → `Dossier` unique
- Supprimer les 7 hubs Explorer redondants avec life events

**Skill-pack** : `mint-flutter-dev` + `systematic-debugging` (pour détecter casses) + `verification-before-completion`.

### Phase 37 — Device gate humain (1 j)

Walkthrough sim iPhone complet : cold start → 5 life events tests (naissance, cantonMove, newJob, EPL, héritage). Metric composite (gravité × non-récurrence × NPS 1-mot). Pas "≤ 20 findings brut".

### Phase 38 — Anti-récidive invariants CI (2 j agent parallèle)

4 invariants Google-style :
- `no_unaccented_fr.py` (Dart + ARB, pas ARB seul) — resout la frustration accent définitivement
- `no_dead_tap.dart` (interdit `onTap: null` et callbacks stub)
- `no_provider_without_consumer.dart` (détecte façade)
- `no_orphan_life_event.dart` (événement dans enum sans flow câblé)

**Skill-pack** : `mint-flutter-dev` + `mint-backend-dev` + `test-driven-development`.

---

## 6. Debat radical à trancher : V10 (4 piliers) vs Audit-02 (3 objets)

**V10 (statu quo direction)** : Aujourd'hui / Coach / Explorer / Dossier. 4 destinations. Déjà documenté.
**Audit-02 (radical)** : Dossier / Coach / Action. 3 objets. Plus cohérent avec mission lucidité "toilet test MINT_IDENTITY §5".

Divergence : V10 garde un Explorer navigable. Audit-02 fusionne Action (Aujourd'hui + Explorer) en une seule surface.

Julien tranche : sa compression radicale favorise Audit-02, sa continuité doc favorise V10. Je note comme question ouverte. Phase 36 exécute selon son arbitrage.

---

## 7. Mesure de succès du milestone v2.8 "MINT Visible"

Critères composites :
- **Matrice couverture** : 108 cellules live passent de 8 (7.4%) à ≥ 80 (74%) sur Tier 1+2 (8 life events)
- **Layer 4 présent** : ≥ 10/18 life events
- **Architecture** : 97 écrans → ≤ 35 écrans, 3 ou 4 destinations top-level (selon arbitrage)
- **Calendrier suisse** : 26 cantons × 5 events = 130 triggers cantonaux live
- **S2-gates** : 5/5 décisions irréversibles protégées
- **Device walkthrough** : 5 life events testés sim iPhone, metric composite ≥ seuil (à définir avec Julien)
- **CI anti-récidive** : 4 invariants green, jamais skippés

---

## 8. Volume agent-work total

| Phase | Jours agent | Parallélisable |
|---|---|---|
| 31 Câblage central | 4 | non (code partagé) |
| 32 Life events ×5 | 8 | 5 tracks parallèles |
| 33 Calendrier cantonal | 3 | partiel |
| 34 Payslip + diff LPP | 3 | oui |
| 35 S2-gates | 2 | oui |
| 36 Compression archi | 4 | non (fragile) |
| 37 Device gate | 1 | non |
| 38 Invariants CI | 2 | 4 tracks parallèles |

**Total agent-work** : ~27j. En wall-clock avec parallélisme maximal : **5-8 jours calendaire**. Réaliste pour Julien solo + Claude.

Ce chiffre remplace les 21-38 jours de Quality Gate v2. Gain : le travail est fondé sur la mission, pas sur une liste de findings Léa.
