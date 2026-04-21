# MVP Flow Walkthrough — 2026-04-21 (posture PM fintech)

**Mandat:** Julien demande posture PM fintech classe mondiale, pas plombier. Observer chaque écran, chaque bouton, se demander « un Suisse de 34 ans qui télécharge MINT, comprend-il, reste-t-il, fait-il confiance ? ». Questions philosophiques, pas surface.

**Persona test:** Julien-type. 34 ans. Lausanne. 7'500 CHF brut. Célibataire. Certificats qui traînent, jamais fait de bilan. Télécharge MINT mercredi soir après le travail, fatigué.

---

## ÉCRAN 1 — Landing (`/`)

**Observation:**
- Titre MINT (logo letter-spacing généreux)
- Tagline : « Ta vie financière, en clair. »
- Message : « On éclaire. Tu décides. »
- Bouton primaire : « Parle à Mint »
- Disclaimer LSFin : « Outil éducatif. Ne constitue pas un conseil financier au sens de la LSFin. »
- Link bas : « J'ai déjà un compte »

**Perception:**
- Minimalisme Chloé / Aesop niveau. ✓
- « On éclaire. Tu décides. » = humilité + empowerment. Pas Cleo-cute, pas banque froide. Calibré.
- Disclaimer LSFin dès le landing = **signal de trust Swiss-spécifique fort**. ✓
- Zéro promesse marketing, zéro screenshots. Courageux.

**Gaps PM:**
- 🟡 **1.1 — Pas de « qu'est-ce que ça fait »** avant engagement. Pas de preview, pas de démo, pas d'exemple. Un prospect sceptique veut voir. → Accepté MVP (doctrine minimalisme assumée).
- ✅ **Trust signal LSFin** = net pour MVP.

**Verdict: 🟢 MVP-ready.**

---

## ÉCRAN 2 — Coach chat premier contact (`/coach/chat`)

**Observation:**
- Top bar : Historique (300,66) + Paramètres IA (348,66) — 2 icônes sans label pour new user
- Prompt central italique : « Tu veux en parler ? »
- **3 chips non-labellées** : « Doux » / « Direct » / « Sans filtre » (640 y)
- Input field placeholder : « Dis-moi. »
- Send button (352,714) — petit cercle noir 38x38 avec flèche
- 4-tab shell déjà exposé : Aujourd'hui / Mon argent / Coach (actif) / Explorer

**Perception (Suisse 34 ans, mercredi soir, fatigué):**
- « Tu veux en parler ? » = **très intime pour un premier contact**. Pour 20% c'est émouvant, pour 80% c'est inconfortable. Il ne sait pas de quoi parler, ne sait pas si l'app a besoin de cash-flow, de projets, de rêves, ou de chiffres.
- « Dis-moi. » = invite au silence. Et au silence, **80% des users quittent**. Minimalism sans prompt = paralysie.
- 3 chips **ambiguës** : Doux / Direct / Sans filtre. Aucune indication de ce que ça change. Tap sur Doux → zéro feedback visuel. L'utilisateur se demande « qu'est-ce que j'ai fait ? ».
- Send button 38x38 = sous-dimensionné pour un doigt Suisse moyen (Fitts' Law).
- 4-tab shell présent au premier contact → user peut zapper chat et aller Mon argent sans avoir rien dit → Mon argent vide → cul-de-sac.

**Gaps PM:**

### 🔴 **2.1 (P0 MVP BLOCKER)** — Pas de conversation starter
Un first-time user doit **inventer** une première question. Wise / Revolut / Yuh affichent des chips de démarrage (« Mon salaire et charges », « Mes impôts », « Mes projets »). MINT laisse silence absolu.

**Tension doctrinale:** la doctrine « chat silencieux » (memory/feedback_chat_must_be_silent) a été écrite pour éviter **widgets proactifs** (scores, graphiques, badges) qui jugent l'utilisateur. Elle n'a **PAS** été écrite pour refuser un message d'ouverture du coach.

**Position PM:** un message coach d'ouverture n'est PAS un widget, c'est une conversation starter. Compatible avec la doctrine. À valider panel.

**Proposition:**
```
"Salut. Je suis Mint. Je peux t'aider à y voir plus clair.
 Pour commencer, tu peux me dire ce que tu cherches,
 ou choisir l'une de ces pistes :

 → 🎯 Juste comprendre ma situation
 → 📄 Scanner un document (salaire, LPP)
 → 🏠 J'ai un projet (achat, rachat)
 → 💰 Optimiser mes impôts
```

### 🔴 **2.2 (P0 MVP BLOCKER)** — Chat ne persiste pas les données extraites
**Test live J+21-minutes:**
- User type: `salaire brut 7500 par mois`
- Coach répond : insight contextuel avec « À 34 ans avec 7500 CHF brut à Vaud, tu te situes légèrement au-dessus du salaire médian... »
- Kill app + relaunch
- **`wizard_answers_v2` en plist = VIDE.** Aucun q_canton, q_birth_year, q_net_income_period_chf.
- Seul `_coach_events_anon` contient le text summary (via `_extractAndSaveInsight` regex).

**Conclusion:** le coach UI comprend, mais `save_fact` tool n'est PAS invoqué par Claude sur ce type de message. Mon fix client-side `applySaveFact` existe mais Claude ne déclenche jamais le tool → path mort.

**Impact user:** MINT fait semblant de comprendre. Next session = vierge. Le MVP « je tape dans le chat, MINT se souvient » **est cassé**.

**Root cause probable:**
- System prompt backend ne force pas Claude à toujours tool_call save_fact
- Claude priorise la réponse conversationnelle sur l'extraction structurée
- Anon user (pas de user_id) peut bias le comportement

**3 options (à arbitrer panel):**
- **A. Forcer Claude via system prompt** : « Tu DOIS appeler save_fact pour toute valeur financière détectée ». Risque : over-extraction, save noise.
- **B. Fallback Dart regex extractor** : parser les messages user pour montants / âge / canton, appeler applySaveFact directement. Robuste mais double-vérification LLM nécessaire.
- **C. Explicit confirm chip** : après chaque extraction, coach répond « J'ai compris 7'500 CHF brut / mois. C'est ça ? [Oui] [Corriger] ». User voit ce qui est capté, consent explicite.

**Position PM:** **Option C** pour MVP.
- Trust-preserving (user voit ce que MINT a retenu)
- Évite surprises au next launch (« MINT pense que je gagne X alors que je ne l'ai jamais dit »)
- Aligne avec doctrine « no stealth saves » + anti-shame
- Post-MVP : Option B fallback pour réduire friction

### 🟠 **2.3 (P1 UX)** — Chips tonalité Doux/Direct/Sans filtre non-autoporteuses
Un user ne sait pas ce que ça change. Pas de tooltip, pas de description. Risque de ignore par défaut → feature ne sert à rien.

**Proposition:** réduire à 1 chip ambigüe « Change de ton » qui ouvre un sheet explicatif OU cacher derrière Paramètres IA. Pour MVP, cacher.

### 🟠 **2.4 (P1 UX)** — Send button sous-dimensionné
38x38 pour une action critique = violation Fitts. Minimum iOS = 44x44.

### 🟡 **2.5 (P2 — cosmétique)** — Privacy disclaimer possiblement trompeur
« Ton salaire exact n'est PAS envoyé — seuls ton âge, canton et archétype sont partagés. » 
Mais si user tape « salaire 7500 » dans le message, le message part en clair à Claude. Le disclaimer concerne les champs du profil, pas les user messages. À clarifier ou retirer.

**Verdict: 🔴 P0-MVP — 2 blockers majeurs (2.1 + 2.2) + 2 P1 UX**

---

## ÉCRAN 3 — Mon argent (`/mon-argent`) — après scan

**Observation (avec données scan):**
- « Ton budget ce mois » — card, bouton « Commencer »
- « Ton point de départ. Net 143'288 CHF. — 33 % des données capturées »
- « 2e pilier | 143'288 CHF »
- « 💡 Scanne un certificat LPP ou 3a pour affiner ta vue. »
- « Enrichis ton dossier pour une vue plus précise »

**Observation (sans données):**
- « Ton budget ce mois » — Commencer
- « Ton point de départ » — Scanner

**Perception:**
- Card budget + card patrimoine = structure claire. ✓
- « 33% des données capturées » = progress quantifié = motivant. ✓
- « Commencer » et « Scanner » = actions précises.

**Gaps PM:**

### 🔴 **3.1 (P0 MVP)** — Budget Commencer = Coach chat topic=budget (sans préparation)
Tap Commencer → écran « Complète ton diagnostic pour débloquer ton plan mensuel... » → 2 boutons overlappés au même endroit (Commencer la saisie / Faire mon diagnostic) pointant vers `/coach/chat?topic=budget`. Pas de formulaire budget. Tout passe par coach chat.

Problème: user qui veut juste « saisir mes dépenses du mois » doit converser avec un coach, qui lui demande des questions, qui ne capture pas les chiffres (cf 2.2). → **Boucle morte**.

**Proposition:**
- Budget a besoin d'une saisie structurée (au moins optionnelle) : « Loyer : 1600 / Assurance maladie : 320 / Transport : 80 / ... » avec totaux temps-réel.
- Laisser le coach chat comme **alternative** pour ceux qui préfèrent parler.
- Hybride = respectueux doctrine « modern inputs no sliders » ≠ « exclusivement conversational ».

### 🟠 **3.2** — Overlap des 2 boutons au même coord
`Commencer la saisie du budget` + `Faire mon diagnostic` → même onTap `/coach/chat?topic=budget`, même position (82, 584). Labels contradictoires. **Simplifier : 1 seul bouton.**

**Verdict: 🟠 P0-MVP pour 3.1, P1 pour 3.2**

---

## ÉCRAN 4 — Aujourd'hui (`/home`) — après scan

**Observation:**
- Cap du jour : « Il manque une pièce — Commande ton extrait AVS — sans cette donnée, ta projection reste floue. »
- Sections : « Première conversation » / « Engagement en cours » / « Ton avenir financier »
- Timeline : « AVRIL 2026 » avec entries existantes

**Perception:**
- Cap du jour ciblé + contextuel = excellent. ✓
- Timeline = historique visible, user sent la continuité. ✓
- Sections séparées = structure claire.

**Gap:**

### 🟡 **4.1 (P2)** — Sections vides (« Première conversation », « Engagement en cours ») au J0
Pour un nouveau user, ces sections sont creuses. Soit on les montre grisées avec teaser, soit on les cache jusqu'à remplissage.

**Verdict: 🟢 MVP-ready avec ajustement mineur.**

---

## ÉCRAN 5 — Explorer (`/explore`)

**Observation:**
- 7 hubs : Retraite/Prévoyance, Famille, Travail/Statut, Logement, Fiscalité, Patrimoine & Succession, Santé & Protection
- Layout 2-col cards

**Perception:**
- Groupement par life event category = cohérent avec doctrine MINT « 18 life events ». ✓
- Labels clairs, icônes (supposées) parlantes.

**Gaps PM:**

### 🟡 **5.1 (P2)** — Accents manquants sur sous-items
« Sequence de decaissement » → « Séquence de décaissement » (Retraite hub)
« Fiscalite » → « Fiscalité » (si titre du hub aussi)
Violation CLAUDE.md règle #2. Reporté au dossier design handoff, mais impact trust Swiss.

### 🟡 **5.2** — Simulateurs sous-câblés (cf service audit)
`LifeEventsService` : 1 caller (divorce_simulator), les 17 autres simulateurs lisent directement `CoachProfileProvider` sans passer par le hub central. Fonctionne en isolé mais pas de vue « tes life events actifs ».

**Verdict: 🟢 MVP-ready pour le hub lui-même, 5.1 handoff design, 5.2 post-MVP.**

---

## BLOCKERS MVP SYNTHÈSE

| # | Écran | Blocker | Gravité |
|---|-------|---------|---------|
| 2.1 | Coach premier contact | Pas de conversation starter | 🔴 P0 |
| 2.2 | Coach data capture | save_fact pas triggered → données pas persistées | 🔴 P0 |
| 3.1 | Budget | Saisie budget = coach chat sans capture → boucle morte | 🔴 P0 |
| 3.2 | Budget | 2 boutons overlappés labels contradictoires | 🟠 P1 |
| 2.3 | Coach chips | Tonalité ambiguë, zéro feedback | 🟠 P1 |
| 2.4 | Coach send | Button 38x38 sous-dimensionné | 🟠 P1 |
| 2.5 | Coach disclaimer | Possiblement trompeur sur portée privacy | 🟡 P2 |
| 4.1 | Aujourd'hui | Sections vides au J0 | 🟡 P2 |
| 5.1 | Explorer | Accents manquants | 🟡 P2 (handoff design) |

**3 blockers P0 MVP = 3 patches à faire.** Les P1/P2 peuvent suivre.

---

## STRATÉGIE EXÉCUTION

**Étape 2 (suivant) — Panel 5 experts** convoqué en parallèle sur les 3 P0 (2.1, 2.2, 3.1) pour arbitrer :
- Conversation starter : quel wording exact, quels chips, respect doctrine silencieuse ?
- Data capture : Option A/B/C (system prompt / regex / confirm chip) — quelle stack pour MVP ?
- Budget : saisie structurée hybride avec chat fallback vs chat-only ?

**Étape 3** — Consolidation en `MVP-PLAN.md` avec ordre d'exécution + estimate.

**Étape 4** — Exécution sérielle des P0 : 1 fix = 1 branche = 1 walkthrough post-fix. Pas de parallèle.
