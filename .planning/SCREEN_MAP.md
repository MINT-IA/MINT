# MINT App — Screen Map complet

**Date** : 2026-04-11
**Méthode** : 4 agents exhaustifs en parallèle (inventory, navigation actions, user flows, facades/loops)
**Sources** :
- `.planning/SCREEN_INVENTORY.md` (95 screens catalogués)
- `.planning/SCREEN_NAVIGATION_ACTIONS.md` (203 navigation actions)
- Analyse de flows utilisateurs + detection de boucles infinies
- Audit des facades et implémentations de back button

---

## 0. TL;DR — Ce qui est cassé

| # | Problème | Sévérité | Scope |
|---|---|---|---|
| **LOOP-01** | Budget infinite loop : Chat → Budget card → /budget facade → "Faire mon diagnostic" → /coach/chat?prompt=budget → Budget card → ... | **P0** | Bloque le flow budget |
| **FAC-01** | `budget_container_screen.dart` est une facade qui renvoie vers le chat au lieu de collecter les données | **P0** | Un écran complet inutile |
| **NAV-01** | `safePop()` (21 écrans) → si rien à pop, redirige vers `/coach/chat`. Signifie que "back" depuis une simulator deep-linked casse la mental map | **P1** | Pratique-toute l'app |
| **BACK-01** | Aucun écran ne gère correctement le cas "opened from chat via drawer" vs "opened via push". Le back button fait des choses différentes selon le contexte | **P1** | Incohérence UX globale |
| **REDIR-01** | 40+ routes de redirect vers `/coach/chat` (shimmed routes), créant l'illusion de pages qui n'existent pas | **P2** | Dette technique |
| **ORPHAN-01** | `BudgetScreen` n'a pas de route, seul `BudgetContainerScreen` (la facade) est routé | **P2** | Code mort |

**Conclusion** : L'app n'a pas un bug de navigation isolé. Elle a une **architecture où tout converge vers le chat** (coach-as-shell), mais où les écrans intermédiaires ne savent pas d'où ils viennent ni où retourner. Résultat : des boucles et des impasses permanentes.

---

## 1. Inventaire — 95 écrans

### Répartition par directory

| Directory | # Screens | Exemples |
|---|---|---|
| `screens/` (root) | 37 | landing, achievements, about, mariage, concubinage, naissance, divorce, etc. |
| `screens/coach/` | 7 | coach_chat, conversation_history, cockpit_detail, annual_refresh, retirement_dashboard |
| `screens/mortgage/` | 5 | affordability, amortization, epl_combined, saron, wohneigentum |
| `screens/independants/` | 5 | avs_cotisations, ijm, pillar_3a_indep, dividende_vs_salaire, lpp_volontaire |
| `screens/pillar_3a_deep/` | 4 | provider_comparator, real_return, retroactive_3a, staggered_withdrawal |
| `screens/arbitrage/` | 4 | bilan, allocation_annuelle, location_vs_property, rente_vs_capital |
| `screens/document_scan/` | 4 | document_scan, avs_guide, extraction_review, document_impact |
| `screens/auth/` | 4 | login, register, forgot_password, verify_email |
| `screens/disability/` | 3 | disability_gap, disability_insurance, disability_self_employed |
| `screens/debt_prevention/` | 3 | debt_ratio, repayment, debt_risk_check |
| `screens/open_banking/` | 3 | consent, transaction_list, open_banking_hub |
| `screens/lpp_deep/` | 3 | epl, libre_passage, rachat_echelonne |
| `screens/household/` | 2 | accept_invitation, couple (main) |
| `screens/education/` | 2 | comprendre_hub, theme_detail |
| `screens/advisor/` | 2 | financial_report_v2, score_reveal |
| `screens/profile/` | 2 | financial_summary, (+1) |
| `screens/budget/` | 2 | **budget_container (facade)**, budget_screen (orphan) |
| `screens/onboarding/` | 1 | data_block_enrichment |
| `screens/confidence/` | 1 | confidence_dashboard |
| `screens/settings/` | 1 | (voir settings pages dans profile/) |

**Total** : 95 screens déclarés dans lib/screens/

### Statistiques navigation

- **Screens avec navigation** : 62 / 95 (65%)
- **Widgets avec navigation** (response cards, drawer items, lightning menu) : 43
- **Actions de navigation totales** : 203
- **Routes statiques** : 40 (dont 15 "dead" = pas de route déclarée qui matche)
- **Routes dynamiques** (via variable) : 35
- **Orphans** : 1 (`BudgetScreen` sans route)

---

## 2. Graphe de navigation des flows principaux

### 2.1 Flow Landing → Chat (ENTRY POINT)

```
┌─────────────────┐
│  LandingScreen  │
│       /         │
└────────┬────────┘
         │ tap "Parle à Mint"
         │ context.go('/coach/chat')
         ▼
┌─────────────────────────┐
│   CoachChatScreen       │
│   /coach/chat           │
│                         │
│  - Input bar            │
│  - Lightning ⚡          │
│  - History icon         │
│  - Share icon           │
│  - ... menu             │
└─────────────────────────┘
```

✓ **Flow propre**. Le landing pousse directement sur le coach chat, full screen replace.

### 2.2 Flow Coach chat (HUB CENTRAL)

```
                        ┌───────────────┐
                        │ CoachChatScreen│
                        │  /coach/chat   │
                        └───┬─────┬──────┘
                            │     │
      ┌─────────┬───────────┤     ├────────┬─────────┬──────────┐
      │         │           │     │        │         │          │
      ▼         ▼           ▼     ▼        ▼         ▼          ▼
   [History]  [Share]   [⚡ Menu] [...]  [ResponseCards]  [Quick chips]
      │         │           │     │        │         │          │
      ▼         ▼           ▼     ▼        ▼         ▼          ▼
  /coach/    Export    LightningMenu  /profile/  Budget   LPP/65 ans
  history    PDF       drawer         byok       card     chips
                       (résoluble)                │
                                                  │ tap "Voir détail"
                                                  ▼
                                            /budget (FACADE) ❌
                                                  │
                                                  │ "Faire mon diagnostic"
                                                  ▼
                                            /coach/chat?prompt=budget
                                                  │
                                                  │ new ResponseCard
                                                  ▼
                                                LOOP ♾️
```

**Observations** :
- Le chat est un **hub** qui dispatche vers 6+ destinations
- **Le Budget flow est cassé** → boucle infinie (voir LOOP-01 plus bas)
- Le Lightning menu est **correctement implémenté** comme drawer (dismiss → retour au chat)
- L'historique et les settings ont un back button standard qui marche

### 2.3 Flow Simulators (Cat B/C)

```
CoachChatScreen → ResponseCard "LPP" / "Retraite" / "Fiscal"
                 → context.push(route)
                 │
                 ▼
         ┌───────────────┐
         │ Simulator     │   ← /pilier-3a, /retraite, /hypotheque, /fiscal, etc.
         │ Screen        │
         └───────┬───────┘
                 │ user interacts (sliders, inputs)
                 │
                 │ tap back button (safePop)
                 ▼
         ┌───────────────┐
         │ canPop ?      │
         ├───────────────┤
         │ YES → pop()   │   → retourne à CoachChat ✓
         │ NO  → /coach/chat│  ← si deep-link, redirige vers chat
         └───────────────┘
```

✓ **Simulator flow OK** dans le cas standard (push depuis chat → pop → chat).
⚠️ **Deep-link broken** : si tu ouvres `/pilier-3a` en premier (sans stack), le back renvoie à `/coach/chat` au lieu de landing.

### 2.4 Flow ACCESSOIRES (cassés)

```
Profile Drawer
      │
      ▼
  ┌────────────────────────────────┐
  │ /profile/byok  ───→ OK         │
  │ /profile/slm   ───→ OK         │
  │ /profile/bilan ───→ OK         │
  │ /profile/privacy-control → OK  │
  │ /profile/consent     → ❌ DEAD │ (fix déployé ?)
  │ /profile/data-transparency → ❌│ DEAD
  │ /settings/langue → OK          │
  │ /documents → OK                │
  │ /couple → OK                   │
  │ /coach/history → OK            │
  │ Logout → /  +  AuthProvider.logout() ✓ (fix Phase 3)│
  └────────────────────────────────┘
```

---

## 3. LA boucle infinie principale — LOOP-01 (Budget)

### Reproduction étape par étape

**Étape 1** : Utilisateur tape "aide-moi à faire mon budget" dans le coach

```
coach_chat_screen.dart:578 → _sendMessage()
 → orchestrator.generateChat()
 → Claude génère une réponse + un ResponseCard "Budget"
```

**Étape 2** : Le card Budget s'affiche sous la réponse

```
widgets/coach/response_card_widget.dart:576
Card title: rcBudgetTitle ("Budget")
Card subtitle: "Combien il te reste à la fin du mois ?"
Card CTA: "Voir le détail →"
Card route: /budget (static, from ResponseCardService)
```

**Étape 3** : User tap "Voir le détail →"

```
response_card_widget.dart → _handleTap()
 → context.push(card.cta.route)
 → navigates to /budget
```

**Étape 4** : Arrive sur BudgetContainerScreen

```
screens/budget/budget_container_screen.dart:19-20
 → Check: BudgetProvider.inputs == null ?
 → YES (anonymous user, no profile yet)
 → Render empty state:
    • Icon wallet
    • Title: "Ton budget"
    • Body: "Complète ton diagnostic pour débloquer ton plan mensuel..."
    • Button: "Faire mon diagnostic"
```

**Étape 5** : User tap "Faire mon diagnostic"

```
budget_container_screen.dart:61
onPressed: () => context.push('/coach/chat?prompt=budget')
 → navigates back to CoachChatScreen
```

**Étape 6** : CoachChatScreen redémarre avec `prompt=budget`

```
coach_chat_screen.dart:316-321
 → initialPrompt detected
 → auto-send message "budget" as if user typed it
 → Claude generates response with... SAME Budget ResponseCard
```

**Retour à l'étape 2. LOOP INFINI.**

### Pourquoi c'est cassé

1. **`BudgetContainerScreen` est une facade** — il n'a **aucun moyen** de collecter les données budget (pas de form, pas d'input)
2. **Le seul bouton** envoie à l'endroit qui l'a créé (le chat avec même prompt)
3. **Le chat ne sait pas** qu'il a déjà montré le card Budget, donc le re-génère

### Fix

**Option A (rapide)** : Changer le button de `/coach/chat?prompt=budget` vers `/profile/bilan` (collecte réelle des revenus/charges)

**Option B (correct)** : Remplacer le facade par un vrai écran de collection de budget inline (sliders simples : revenu mensuel, loyer, épargne)

**Option C (contextuel)** : Le ResponseCard doit checker si `BudgetProvider.inputs != null` avant de router sur `/budget`. Sinon, router direct sur `/profile/bilan` ou un flow de collecte.

---

## 4. Screens facades

### FAC-01 : `screens/budget/budget_container_screen.dart`

| Attribut | Valeur |
|---|---|
| Route | `/budget` |
| Longueur | 79 lignes |
| Logique | `if (inputs == null) → empty state, else → BudgetScreen` |
| Empty state | Icon + title + body + 1 button |
| Button destination | `/coach/chat?prompt=budget` |
| Verdict | **FACADE confirmé** |

**Le screen BudgetScreen (orphan) existe** mais n'est jamais routé directement. Si on fixe la route `/budget` pour pointer vers `BudgetScreen` au lieu de `BudgetContainerScreen`, on supprime la facade.

### Autres suspects (NOT facades, legitimate)

- `portfolio_screen.dart` : empty state mais contenu éducatif
- `documents_screen.dart` : empty state avec CTA scan = légitime
- `achievements_screen.dart` : educational empty state = légitime

---

## 5. Routes mortes (DEAD_DESTINATIONS)

15 routes statiques dans le code qui **ne matchent aucune route** déclarée dans `app.dart` :

| Route émise | Où | Status |
|---|---|---|
| `/coach/chat?prompt=budget` | budget_container_screen.dart:61 | ⚠️ Dead pour la route strict mais query param → OK si handler |
| `/auth/verify-email?redirect=...` | register_screen.dart | ⚠️ Dead pour strict, query param OK |
| `/data-block/${category}` | coach_chat_screen.dart (dynamic) | ✓ Dynamic, resolved at runtime |
| `/documents/${id}` | documents_screen.dart (dynamic) | ✓ Dynamic |
| `/education/theme/${theme.id}` | comprendre_hub (dynamic) | ✓ Dynamic |
| (11 autres routes dynamiques) | divers | ✓ OK |

**Conclusion sur les dead routes** : la plupart sont des **query params ou variables résolues à runtime**, donc pas vraiment "mortes". Les vraies dead routes (fixes de Phase 5) sont déjà adressées.

---

## 6. Back button — inventaire

21 écrans utilisent `safePop(context)` (fix Phase 5/6) :

```
screens/document_scan/extraction_review_screen.dart:127
screens/document_scan/avs_guide_screen.dart:102
screens/document_scan/document_scan_screen.dart:150
screens/gender_gap_screen.dart:103
screens/expat_screen.dart:146
screens/debt_prevention/repayment_screen.dart:143
screens/lpp_deep/epl_screen.dart:250
screens/lpp_deep/libre_passage_screen.dart:96
screens/mariage_screen.dart:132
screens/confidence/confidence_dashboard_screen.dart:149
screens/first_job_screen.dart:286
screens/concubinage_screen.dart:121
screens/education/theme_detail_screen.dart:86
screens/independants/dividende_vs_salaire_screen.dart:114
screens/independants/lpp_volontaire_screen.dart:108
screens/independants/pillar_3a_indep_screen.dart:107
screens/documents_screen.dart:68
screens/lamal_franchise_screen.dart:128
screens/unemployment_screen.dart:94
screens/naissance_screen.dart:141
screens/coach/coach_chat_screen.dart:1377
```

**Comportement actuel de `safePop`** :
```dart
void safePop(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/coach/chat');  // ← fallback destination
  }
}
```

**Problème** : quand on **arrive sur un simulator via deep link ou notification** (stack vide), le back button te renvoie sur `/coach/chat` au lieu de la landing. **Pire** : depuis le chat, le back button du chat lui-même (ligne 1377) fait `safePop` → si stack vide → retourne au chat (no-op !). C'est ce que tu as observé.

**Fix recommandé** :
```dart
void safePop(BuildContext context, {String fallback = '/'}) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);  // landing by default
  }
}
```

Et pour les simulators ouverts depuis le chat : ils devraient avoir `fallback: '/coach/chat'` explicitement. Pour le chat lui-même, `fallback: '/'` (landing).

---

## 7. Flows par screen — les 9 flows critiques

### Flow 1 : Landing → Chat ✅ OK

`LandingScreen` → tap "Parle à Mint" → `context.go('/coach/chat')` → `CoachChatScreen`

### Flow 2 : Chat → Budget (**LOOP-01**) ❌

Voir section 3 ci-dessus.

### Flow 3 : Chat → LPP chip ✅ OK (mais via drawer)

`CoachChatScreen` → action chip "Ça vaut le coup de racheter du LPP ?" → `_routeForAction` → `/rachat-lpp`
→ `ChatDrawerHost.resolveDrawerWidget('/rachat-lpp')` → `RachatEchelonneScreen` as modal bottom sheet
→ dismiss (swipe down ou back) → retourne au chat ✓

### Flow 4 : Chat → History ✅ OK

`CoachChatScreen` → tap history icon → `context.push('/coach/history')` → `ConversationHistoryScreen`
→ back button standard Material → pop → retour au chat ✓

### Flow 5 : Chat → Export PDF ✅ OK

`CoachChatScreen` → tap share → `_exportConversation()` → génère PDF → pas de navigation ✓

### Flow 6 : Chat → ... (settings) ✅ OK

`CoachChatScreen` → tap ... → `context.push('/profile/byok')` → `ByokSettingsScreen`
→ back button standard → pop → retour au chat ✓

### Flow 7 : Chat → Lightning ⚡ ✅ OK

`CoachChatScreen` → tap lightning → `_showLightningMenu()` → modal bottom sheet
→ user picks item → `onNavigate(route)` → `ChatDrawerHost.resolveDrawerWidget(route)` → drawer over chat
→ dismiss → retour au chat ✓

### Flow 8 : Profile drawer → items ✅ OK (post Phase 5/6)

Drawer pops on tap → navigation to `/profile/*` → back button → retour à la source ✓

### Flow 9 : Simulator → back ⚠️ OK standard, broken on deep-link

- Ouvert via push depuis chat : back → pop → chat ✓
- Ouvert via deep-link (ex: notification) : back → `safePop` → `/coach/chat` (au lieu de `/`)

---

## 8. Plan de fix priorisé

### Sprint 1 — Casser la boucle budget (P0, 2h)

1. **Fix LOOP-01** : Modifier `BudgetContainerScreen` pour router vers `/profile/bilan` au lieu de `/coach/chat?prompt=budget` quand empty
2. **OU mieux** : Pointer la route `/budget` vers `BudgetScreen` (orphan) avec fallback sur `BudgetContainerScreen` si pas de données
3. **Tester** : tap Budget card dans chat → atterrit sur vrai écran budget (pas sur facade)

### Sprint 2 — Back button propre (P1, 4h)

1. Modifier `safePop(context, {fallback = '/'})` pour accepter un fallback param
2. Auditer les 21 appels et donner le bon fallback :
   - Simulators ouverts depuis chat → fallback `/coach/chat`
   - Simulators ouverts depuis deep-link → fallback `/`
   - Chat lui-même → fallback `/` (retourne à landing si rien à pop)
3. Ajouter un test widget pour chaque cas

### Sprint 3 — Cleanup facades et orphans (P2, 2h)

1. Renommer `BudgetContainerScreen` en `BudgetEmptyStateScreen`
2. Router `/budget` vers `BudgetScreen` (le vrai)
3. Utiliser `BudgetEmptyStateScreen` comme wrapper conditionnel interne
4. Supprimer les dead routes confirmées de `intent_router`, etc. (déjà fait en Phase 5)

### Sprint 4 — Audit device walkthrough (P0 après Sprint 1-3)

1. Sur iPhone réel, marcher chaque flow (landing → coach → chaque destination)
2. Vérifier qu'il n'y a plus de boucle
3. Vérifier que chaque back button retourne où on attend
4. Documenter avec screenshots

---

## 9. Ce qu'on n'a pas encore mappé (gaps)

Malgré l'exhaustivité, certaines zones grises restent :

1. **Response cards dynamiques** : le contenu et les routes des ResponseCards dépendent de `ResponseCardService.generateForChat(profile, userMessage)`. Une boucle similaire peut exister sur d'autres cards (LPP, Retraite, Fiscal) si leurs target screens sont aussi des facades.
2. **Navigation par notifications** : quand l'app reçoit une notification et ouvre une route directement, le stack est vide → safePop → chat. Non couvert.
3. **Deep links externes** : si quelqu'un partage un lien MINT (ex: via SMS), comportement non audité.
4. **Tool calls de Claude** : `route_to_screen` tool_use peut envoyer le user vers une route arbitraire. Si Claude hallucine une route qui n'existe pas, comportement ?

---

## 10. Annexes

### A. Fichiers de référence

- `.planning/SCREEN_INVENTORY.md` (95 screens, 16 KB)
- `.planning/SCREEN_NAVIGATION_ACTIONS.md` (203 actions, 21 KB)
- `apps/mobile/lib/app.dart` (routes définitions)
- `apps/mobile/lib/services/navigation/safe_pop.dart` (14 lines)
- `apps/mobile/lib/services/navigation/screen_registry.dart` (screen registry data)

### B. Commandes de vérification

```bash
# Trouver tous les safePop usages
grep -rn "safePop(" apps/mobile/lib/

# Trouver tous les context.push/go avec string littéral
grep -rn "context\.\(push\|go\)(" apps/mobile/lib/

# Trouver les routes déclarées dans app.dart
grep -n "GoRoute\|ScopedGoRoute" apps/mobile/lib/app.dart

# Trouver les facades (screens très courts avec 1 button)
wc -l apps/mobile/lib/screens/**/*.dart | sort -n | head -20
```

---

**Ce document est le vrai mapping que tu m'as demandé 3 fois. C'est la référence pour le sprint de navigation à venir.**
