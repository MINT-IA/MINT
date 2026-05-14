# Vision Mon Argent — 3 propositions (Wave 0 step E)

> **Status** : PROPOSAL (3 options présentées) — Julien tranche en Wave 0 step E2.
> **Author** : Claude (Wave 0 Sentry — Product Leader mode).
> **Date** : 2026-05-14.
> **Context** : Le design doc APPROVED 2026-05-14 demande de définir le rôle de Mon Argent (« numbers panel statique » / « surface secondaire de la trajectoire » / « point d'entrée banking integration » — 3 directions exclusives, Open Question #3).
> **Drift audit `2026-05-14-handoff-vs-code-drift.md` Section A.3** a découvert que le PDF DS v2 mai 8 propose **3 tabs** (Aujourd'hui · Coach · Trajectoire) — Mon Argent disparaît. Cela change le scope de la décision : pas juste « que met-on dans Mon Argent », mais « Mon Argent existe-t-il toujours ? ».

---

## TLDR (4 phrases)

3 propositions exclusives sur Mon Argent : **(P1)** garder Mon Argent comme **panneau patrimoine multi-chiffre** (statu quo amélioré, 4-tab) ; **(P2)** dissoudre Mon Argent en **surface secondaire de Trajectoire** (PDF DS v2 mai 8 3-tab) ; **(P3)** transformer Mon Argent en **point d'entrée banking integration** (Open Banking hub + Premier-Éclairage cards). **Recommandation Claude : P2 (Trajectoire-first)** pour cohérence DS v2 + 0 cockpit + 18-events framing ; **mais P3 garde une raison d'être** si Open Banking devient strategic Wave 6+. **Risque P2** : 39 écrans actuellement référençant `MintColors.surface` (« Mon Argent surface ») doivent migrer — coût ~10-15 h.

---

## Section 1 — Contexte : où est Mon Argent aujourd'hui ?

État actuel ([mint_shell.dart:78-102](apps/mobile/lib/widgets/mint_shell.dart#L78-L102)) :
- Tab 2 / 4 : « Mon argent » (label `tabMonArgent`)
- Icône : `Icons.savings_outlined` / `Icons.savings`
- Contenu approximatif (per design doc §40) : « Budget remaining + Patrimoine summary + whisper déterministe + scan CTA »
- Vision doc **absente** jusqu'ici (Wave 0 step E doit en produire une)

État souhaité divergent selon source :
- **Design doc 2026-05-14** : Mon Argent reste comme tab, son contenu est à définir.
- **PDF DS v2 mai 8 + JSX `docs/brand/mint-v2/screen-aujourdhui.jsx`** : structure 3-tab (Aujourd'hui · Coach · Trajectoire). Mon Argent **disparaît**.
- **Code actuel** : 4-tab persistant (Phase 7 PAUSED 2026-05-14 maintient `chatTabVisible=true`).

L'absence de vision doc Mon Argent est **load-bearing** : sans définition, le tab dérive vers un mur de cartes (anti-pattern DS §7 #1 + grammaire PDF DS v2 mai 8 #1 « Une idée / écran »).

---

## Section 2 — 3 propositions exclusives

### Proposition P1 — Mon Argent = panneau patrimoine multi-chiffre (statu quo amélioré, garder 4-tab)

**Le rôle** :
- **Mon Argent = vue d'ensemble du patrimoine actuel** (snapshot, pas projection)
- 4-5 chiffres dominants : revenu / dépenses / épargne liquide / patrimoine net / dette
- ConfidenceBand sur chaque chiffre (PDF DS v2 mai 8 grammaire #6)
- EnrichmentPrompts pour les chiffres manquants

**Pourquoi P1 marche** :
- Préserve la séparation cognitive : Aujourd'hui = cette semaine / Mon Argent = ma situation / Coach = mes questions / Explorer = mes outils
- Reconnaît que tous les users n'ont pas l'envie de regarder leur trajectoire 30 ans — certains veulent juste « combien j'ai sur mon compte ce mois ».
- Cohérent avec audience adaptation VOICE_SYSTEM (« novice → autonome → expert »)

**Pourquoi P1 ne marche pas** :
- **Multi-chiffre = mur de cartes** = anti-pattern grammaire PDF DS v2 mai 8 règle #1 (« Une idée / écran »)
- Multi-chiffre = cockpit = anti-pattern ADR 2026-05-14-aujourdhui-doctrine (« MINT = l'anti-cockpit-d-avion »)
- Frame patrimoine actuel **sans contexte trajectoire** → fail mode Karpathy 2026 (« I can outsource the thinking but not the understanding ») — Julien lui-même comme user demande à voir la trajectoire, pas un snapshot.

**Coût** : ~5-8 h pour designer + 12-20 h pour implémenter (4-5 cartes premium + ConfidenceBand wraps).

---

### Proposition P2 — Mon Argent dissous dans Trajectoire (3-tab refonte PDF DS v2)

**Le rôle** :
- **Mon Argent disparaît** comme tab dédié
- La surface Aujourd'hui prend le delta hebdo + carte coach (cf. ADR 2026-05-14-aujourdhui-doctrine)
- Tab 3 = Trajectoire (TrajectoryMap horizontale — cf. wireframe v1 sub-agent C)
- Patrimoine actuel = **drawer / pull-down sur Trajectoire** (chiffre net access via tap milestone « M0 — Où tu en es aujourd'hui »)
- Coach overlay reste invocable depuis n'importe quel tab (chat-as-verb, doctrine Phase 96 — actuellement PAUSED Phase 7, mais cohérent avec Option C Coach vivant didactique)

**Pourquoi P2 marche** :
- **Strictement cohérent avec PDF DS v2 mai 8 page 3-4** (canonique)
- Strictement cohérent avec mockup 11 JSX `docs/brand/mint-v2/`
- Frame Karpathy 2026 « outsource thinking, keep understanding » → Trajectoire visualise le understanding
- Réduit la cognitive load : 3 tabs > 4 tabs (Hick's Law)
- Respecte « MINT ≠ retirement app » TOP rule #3 si Trajectoire est life-event-agnostic (cf. wireframe C W3 variants per-archetype)

**Pourquoi P2 ne marche pas** :
- **Migration coût élevé** : 39 écrans actuellement référençant `MintColors.surface` (« Mon Argent feel ») doivent migrer ; les liens internes (deep links vers Mon Argent : `mon-argent`, `mon-argent/patrimoine`, etc.) doivent rediriger
- **Régression UX** pour users qui aimaient « voir mes comptes en 1 tap » — si M0 « Où tu en es » n'est pas placé strategically dans Trajectoire, friction
- **Phase 7 chat-as-verb PAUSED** : le pivot 3-tab nécessite que Coach soit accessible depuis Trajectoire / Aujourd'hui / Explorer overlay-style ; or Phase 7 (`chatTabVisible=false`) est PAUSED. Tension non-résolue.

**Coût** : ~12-18 h refonte navigation + 10-15 h migration tokens + 8 h tests régression. **Wave 2 / Wave 3.**

**Pré-condition** : Phase 7 doit être ship-ou-pause définitive ET migration M0 (« Où tu en es ») designé.

---

### Proposition P3 — Mon Argent = point d'entrée banking integration (Open Banking hub)

**Le rôle** :
- **Mon Argent = surface banking-first**
- Page principale : « Tes comptes » (liste comptes connectés via Open Banking PSD2 / Swiss DataConnect)
- Sub-sections : « Transactions ce mois », « Subscriptions récurrentes détectées », « Sweep épargne intelligent »
- C'est un hub fonctionnel (catégorie F DESIGN_SYSTEM §2) + Premier-Éclairage cards (catégorie A) sur les détections

**Pourquoi P3 marche** :
- Différenciateur fort : la majorité des apps fintech suisses passent **sous** Open Banking ; en faire la surface principale = positionnement « ami cultivé fintech »
- Génère des chiffres Coach-disponibles (le LLM peut citer « tu as dépensé X en abonnements ce mois »)
- Synergie avec le forced-tool-invocation pattern : Coach répond en s'appuyant sur les data Open Banking via tools dédiés

**Pourquoi P3 ne marche pas** :
- **Open Banking suisse n'est pas généralement disponible MVP** — DataConnect SIX en early access, PSD2 EU ne couvre pas la Suisse natively, multibanking via Apto / Plaid Switzerland très partial
- Recompose le scope MVP autour d'une intégration non-stabilisée = risque
- Si OB ne fonctionne pas (banque non-supportée), Mon Argent = empty state — fail mode

**Coût** : ~3-5 sem pour integration partielle (UBS, PostFinance, Raiffeisen via DataConnect) — **scope creep majeur**.

**Pré-condition** : décision strategic + budget + partenaire OB sécurisé. Probablement **Wave 6+**, pas MVP.

---

## Section 3 — Critères de tri & recommendation

### Matrice évaluation

| Critère | Poids | P1 statu quo | P2 dissolved | P3 banking |
|---|---|---|---|---|
| Cohérence PDF DS v2 mai 8 | 20% | ❌ (multi-chiffre) | ✅ (canonique) | ⚠️ (différent du PDF) |
| Cohérence ADR Aujourd'hui doctrine | 15% | ❌ (cockpit-like) | ✅ | ⚠️ |
| Cohérence pivot Karpathy 2026 (outsource thinking, keep understanding) | 15% | ⚠️ (statique) | ✅ (trajectoire) | ⚠️ (transactions ≠ understanding) |
| Coût implémentation Wave 0-2 | 15% | ✅ (low) | ⚠️ (medium) | ❌ (high) |
| Risque MVP | 15% | ✅ (low) | ⚠️ (refonte nav) | ❌ (OB pas dispo) |
| Différenciation marché | 10% | ❌ | ⚠️ (Aesop éditorial) | ✅ (banking first) |
| Cohérence 18-events framing | 10% | ⚠️ (snapshot patrimoine ≠ events) | ✅ (Trajectoire = events) | ⚠️ |
| **Total pondéré** | 100% | **45%** | **78%** | **48%** |

**Recommandation Claude : P2 (Mon Argent dissous dans Trajectoire)** — score 78%, cohérent avec PDF DS v2 mai 8 canonique + ADR Aujourd'hui + pivot Karpathy. Bémol : coût refonte nav significatif Wave 2, pré-condition Phase 7 finalisation.

**Fallback : P1 lite** (si Julien veut garder 4-tab pour réduire risque MVP) — Mon Argent = **un seul chiffre dominant patrimoine net + Top 1 carte coach** (pas 4-5 chiffres). C'est P1 mais en mode « one-number aussi sur Mon Argent », pas mur de cartes.

**P3 reporté Wave 6+** — Open Banking comme strategy long-terme, pas Wave 2.

---

## Section 4 — Implémentation si P2 retenu (le path recommandé)

### Phase 1 — Wave 2 (avec TrajectoryMap)

1. **TrajectoryMap component** sur Aujourd'hui (composant) ou Trajectoire (tab dédié — décision rasée par P2)
2. **M0 milestone « Où tu en es aujourd'hui »** = entry point patrimoine snapshot (le chiffre dominant Mon Argent absorbé ici)
3. **Tab refonte** : `mint_shell.dart:78-102` passe de 4 destinations à 3 (Aujourd'hui · Coach · Trajectoire). Drop Mon Argent destination.
4. **Deep links migration** : routes `/mon-argent/*` redirect vers `/trajectoire/m0` ou `/aujourdhui` selon contexte
5. **Composants premium DS v2 propagation** : sur les écrans M0/M1/.../Mx, appliquer la grammaire DS v2 mai 8 (ConfidenceBand + EnrichmentPrompts mandatory cf. sub-agent H output)

### Phase 2 — Wave 3+ (consolidate)

- Mon Argent legacy code (si écrans dédiés `mon_argent_*.dart`) → archive + cleanup
- Tests régression : 0 régression sur les flows historiques qui passaient par Mon Argent
- Walker Maestro flow sur le nouveau path Aujourd'hui → Trajectoire → M0 → ConfidenceBand

### Phase 3 — Wave 4 (Coach overlay didactique)

- Si Phase 7 ship-ou-pause-définitif tranché : Coach overlay invocable depuis n'importe quel tab
- Si Phase 7 PAUSED indéfiniment : Coach reste tab à part entière, et 3-tab devient en réalité 3-tab (Aujourd'hui · Coach · Trajectoire) avec Coach toujours visible — paradoxalement plus cohérent que le 4-tab actuel

---

## Section 5 — Questions ouvertes pour Julien

1. **Approuves P2 ?** (statut Decided/Proposed/Reject)
2. **Si P2 : Phase 7 tu re-ouvres ou tu maintiens PAUSED ?** P2 force la question Phase 7 dans les semaines à venir.
3. **Si P2 : M0 « Où tu en es » sur Trajectoire = comment le styliser ?** Hero milestone avec chiffre dominant net worth ? Section overview ? Tap-to-expand ?
4. **Si P1 lite (fallback) : un seul chiffre Mon Argent — lequel ?** Patrimoine net ? Épargne disponible ? Solde du mois ? Score FRI ?
5. **Coach destination tab** : si P2 retenu, Coach reste tab persistante OU Coach devient overlay-only ? Le PDF DS v2 montre Coach comme tab page 4, mais Phase 96 doctrine = overlay.

---

## Section 6 — Caveats

1. Le scoring matrice §3 est subjectif — les poids reflètent l'interprétation Claude de la doctrine MINT actuelle, ils peuvent être contestés.
2. P2 « dissolution Mon Argent » risque user-side : si tu fais le test 5 utilisateurs Wave 0 et que ≥ 2/5 disent spontanément « je veux voir mes comptes / mes 4 piliers » → revisit.
3. P3 banking-first n'est pas mort à long-terme — c'est une décision **Wave 6+**, pas une réfutation de la valeur Open Banking.
4. La migration Wave 2 sous P2 dépend du sub-agent H output (DS v2 coverage) — si la dette propagation est plus lourde que 10-15h, P2 timeline glisse.

---

## Counter-arguments and data gaps (CLAUDE.md §8 Wiki practice 3)

- **Strongest opposing view (anti-P2)** : on tue 1 tab parce que le PDF DS v2 mai 8 le dit, mais le PDF est une **proposition design** (mai 8) qui n'a pas été testée user. On laisse une grammaire visuelle dicter une décision navigation sans valider que les utilisateurs s'en sortent en 3-tab. Risque : on optimise pour la cohérence DS au prix de la friction user.
- **Empirical gap** : aucun user n'a été observé en 4-tab actuel pour dire « je n'utilise jamais Mon Argent » OU « Mon Argent est mon premier réflexe ». Sans signal user, P2 est un pari.
- **What would change the conclusion** : si test 5 utilisateurs Wave 0 (sub-agent G persona guide → test wireframe) montre ≥ 4/5 « je trouve la trajectoire et le patrimoine snapshot intuitifs en 3 taps » → P2 confirmé. Si ≥ 3/5 demandent un tab dédié au patrimoine → P1 lite ou P3.

---

*Proposal v1 produit Wave 0 par Claude. Awaiting Julien decision. Sources : drift audit Section A.3 + PDF MINT-Design-System-2026-05-08 + ADR Aujourd'hui + design doc APPROVED 2026-05-14 + memories `feedback_mockup_examples` + `feedback_critical_pm_mode`.*
