# Audit Autonome Profond MINT — 2026-04-17

> Branche: `feature/S57-navigation-v11`
> Methode: 6 agents code + 4 agents simulation + tests LIVE API staging
> Scope: cold-start → 1 mois d'utilisation simulé → edge cases
> Utilisateur test: `audit-test-20260417@minttest.ch` (staging)
> Profil: Julien 49 ans, VS Sion, 122'207 CHF/an, CPE LPP 70'377

---

## SYNTHESE EXECUTIVE

**Le coeur de metier (calculateurs financiers) est solide et conforme aux lois suisses. Mais le parcours utilisateur a 3 trous beants : le flow anonyme est mort, les donnees du coach ne remontent pas dans l'app, et le mode couple est une facade.**

| Categorie | Note /10 | Verdict |
|-----------|----------|---------|
| Calculateurs financiers (AVS, LPP, tax, mortgage) | **9/10** | Corrects, conformes aux lois |
| Navigation V11 (4 tabs, 50+ routes) | **8/10** | Solide, 1 bug `/explorer` fixe |
| Cold start (nouvel utilisateur non-auth) | **2/10** | Flow anonyme MORT, pas de conversion gate |
| Coach chat backend | **7/10** | Repond intelligemment, lit le profil |
| Pipeline scan documents | **8/10** | Extraction correcte, validation user, confidence |
| Pipeline save_fact → Flutter | **3/10** | TROU BEANT: donnees coach perdues pour Flutter |
| Mode couple | **2/10** | Facade: invitation email sans donnees financieres |
| Pre-remplissage ecrans | **5/10** | OK pour retraite/mortgage/3a, ABSENT pour famille |
| FATCA/expat_us | **4/10** | Label + template educatif, zero calcul specifique |
| Budget | **7/10** | Fonctionne via API, schema camelCase a respecter |
| Backend staging | **8/10** | UP, 223 routes, profil OK apres fix id:str |
| Repo hygiene | **2/10** | 177 fichiers fantomes macOS |

### Bugs trouves: 6 P0, 6 P1, 8 P2

---

## TESTS LIVE SUR STAGING API

### Jour 1: Register + Profil

```
POST /auth/register → 201 ✅ (user_id: 00590ad9-252d-4729-871b-7d1bfa48f227)
GET /profiles/me → 200 ✅ (profil vide, auto-bootstrap)
PATCH /profiles/{id} → 200 ✅ (Julien: 49 ans, VS, 122k, LPP 70377, 3a 32000)
```

**Finding**: `dateOfBirth: "1977-01-12"` envoye mais retourne `null`. Seul `birthYear: 1977` est accepte. Le champ dateOfBirth n'est pas persiste par le PATCH.

### Jour 2: Coach chat

```
POST /coach/chat (msg 1: "retraite, 49 ans, 122k, Valais") → REPONSE GENERIQUE ❌
POST /coach/chat (msg 2: "LPP 70377, rachat 539414, projection?") → MEME GENERIQUE ❌
POST /coach/chat (msg 3: "Combien aurai-je a la retraite?") → REPONSE RICHE ✅
```

- Message 3: "ton avoir LPP actuel ≈ 70k... taux de remplacement probablement sous 55%... l'AVS plafonne à 2'520/mois"
- Le coach LIT le profil backend (il cite les 70k LPP), il a le contexte
- Les 2 premiers messages generiques = probable cache/warmup ou conversation_history mal formattee
- `systemPromptUsed: true`, `model_used: claude-sonnet-4-5-20250929`, ~15'800 tokens/msg
- toolCalls: null sur les 3 messages — pas de save_fact, pas de route_to_screen

### Jour 3: Overview

```
GET /overview/me → 200 ✅
```

Resultats calcules par le backend:
- AVS mensuelle: **1'546 CHF** | Couple: **3'093 CHF/mois**
- LPP capital projete: **361'477 CHF** | Rente: **1'536 CHF/mois** | Breakeven: **83 ans**
- Completeness: **80%**
- Premier eclairage: "A 65 ans, ta projection tourne autour de 3082 CHF/mois (AVS + LPP)"
- Gaps: assurances sociales, revenu conjoint, budget

### Jour 4: Budget

```
PUT /budget/me (avec "lines" = mauvais schema) → 200 mais lines ignorees ⚠️
PUT /budget/me (avec "fixedLines" = bon schema) → 200 ✅
```

Budget final:
- Revenu: 8'500 CHF/mois
- Charges fixes: 3'905 CHF (loyer 1800, assurances 400, transport 200, alimentation 600, loisirs 300, 3a 605)
- Marge libre: **3'095 CHF/mois**
- Savings rate: **11.76%** → riskLevel "green"

### Jour 5: Upload documents

```
POST /documents/upload (certificat LPP CPE) → 200 ✅
```

Extraction:
- `avoir_vieillesse_total: 70376.6` ✅ (golden: 70'377)
- `salaire_assure: 91967.0` ✅ (golden: 91'967)
- `rachat_maximum: 539413.7` ✅ (golden: 539'414)
- `rente_invalidite_annuelle: 55188.0` ✅
- `rente_conjoint_annuelle: 36792.0` ✅
- Confidence: 0.614 (8/18 champs extraits)
- OCR correct: lit le numero AVS, l'employeur FMV SA, le Plan Maxi

```
POST /documents/upload (2e PDF) → 403 "Limite de 2 documents" ⚠️
```

Paywall a 2 documents en free tier. Pas un bug, mais un friction point.

---

## P0 — BLOQUANTS

### P0-1: Backend `/profiles/me` crash UUID (staging)
- Fix applique localement (`id: str`), **PAS deploye sur staging**
- Les comptes existants avec id non-UUID4 crashent
- Le compte test cree pour l'audit fonctionne (nouvel UUID)
- **Action**: deployer la branche sur staging

### P0-2: Tab Coach → Mon argent (device build)
- Code correct dans `app.dart` (Tab 2 = `/coach/chat`, index 2)
- Probable build stale deploye sur iPhone
- **Action**: rebuild propre + clean install

### P0-3: `/explorer` route morte ✅ FIXE
- `timeline_provider.dart:225` corrige → `/explore`

### P0-5: Flow anonyme MORT — la conversion gate n'existe plus (NOUVEAU)
- La landing (`landing_screen.dart`) envoie "Parle a Mint" vers `/coach/chat` (le vrai coach)
- Mais `/anonymous/chat` (avec limite 3 messages + AuthGateBottomSheet) n'est JAMAIS atteint
- `AnonymousChatScreen` est un ecran **orphelin** — aucun CTA n'y mene
- **Consequence 1**: Un utilisateur non-auth arrive sur un ecran de chat VIDE
- **Consequence 2**: Sans SLM on-device, le premier message crashe (`no_auth` — le backend exige un JWT)
- **Consequence 3**: Il n'y a AUCUN mecanisme de conversion vers l'inscription dans le `CoachChatScreen`
- **Action**: Soit router la landing vers `/anonymous/chat`, soit ajouter une auth gate dans `CoachChatScreen`

### P0-6: Coach chat inaccessible sans auth ni SLM (NOUVEAU)
- `CoachChatApiService.chat()` exige un JWT (ligne 45-49)
- Un utilisateur non-auth qui tape un message voit "Il y a un souci de connexion"
- Le SLM on-device n'est pas garanti (depends du device)
- **Action**: Le fallback chain doit gerer le cas non-auth (soit via `/anonymous/chat`, soit via un endpoint public)

### P0-4: save_fact ne synchronise PAS vers Flutter (NOUVEAU — CRITIQUE)
- Le coach ecrit dans le backend via save_fact
- Mais les ecrans Flutter lisent le CoachProfile LOCAL (SharedPreferences)
- Resultat: l'utilisateur dit des choses au coach, le backend les sait, mais l'app ne les montre pas
- Le scan de documents ecrit correctement dans les 2 (SharedPrefs + backend)
- Les donnees entrees via wizard ecrivent correctement dans les 2
- **Seules les donnees entrees via conversation coach sont perdues pour Flutter**
- **Impact**: Mon argent, Budget, tous les simulateurs ignorent ce que le coach a appris
- **Fix requis**: apres un save_fact reussi, le chat screen Flutter doit mettre a jour CoachProfile local

---

## P1 — IMPORTANTS

### P1-1: Disclaimers empiles dans le coach chat
- Per-message `CoachDisclaimersSection` + footer permanent = bruit visuel
- 3 messages = 3 cartes disclaimer + 1 footer

### P1-2: Hypotheque en revenu individuel, pas couple
- `affordability_screen.dart` lit seulement le salaire principal
- Avec 122k seul → capacite ~800-900k. Avec couple 189k → capacite ~1.2M+
- Un couple marie sous-estime sa capacite d'achat de 30-40%

### P1-3: Mode couple = facade sans cablage
- `HouseholdProvider` = invitation email, ZERO donnee financiere
- `AvsCalculator.computeCouple()` existe mais aucun ecran ne l'appelle avec les donnees reelles du conjoint
- Le mode couple est un systeme social deconnecte des calculs financiers

### P1-4: Nudges 3a envoyes a Lauren (FATCA)
- Ni NudgeEngine, ni JitaiNudgeService, ni CommunityChallengeService ne verifient `canContribute3a`
- Lauren (expatUs) recevrait des nudges/challenges 3a qu'elle ne peut pas activer

### P1-5: LPP conversion rate ambigue
- Si le certificat CPE ne fournit pas le split oblig/surob, le fallback blended (5.8%) surestime
- Golden value 677'847 × 5.0% = 33'892. Code avec 5.8% = 39'315. Delta 5'400 CHF/an

### P1-6: Labels MintShell + Explorer hardcodes en francais (NOUVEAU)
- `mint_shell.dart` lignes 43-63 : "Aujourd'hui", "Mon argent", "Coach", "Explorer" = string literals
- `explorer_screen.dart` lignes 39-78 : noms des 7 hubs en dur
- Casse l'i18n pour de/en/es/it/pt
- ProfileDrawer "Se connecter" aussi hardcode

---

## P2 — A TRAITER

### P2-1: 177 fichiers fantomes macOS dans le repo
### P2-2: Mariage, Naissance, Divorce: ZERO pre-remplissage profil
- Mariage: defaults 80k/60k au lieu de 122k/67k
- Naissance: default 6000/mois au lieu de 8500
- Divorce: defaults 90k/50k au lieu de 122k/67k
- Violation directe de la regle "EVERY screen pre-fills ALL known data"

### P2-3: dateOfBirth non persiste par PATCH /profiles
- Le champ est accepte mais retourne null

### P2-4: Double imposition US/CH absente pour Lauren
- `TaxCalculator` = purement suisse. Un expat_us voit l'impot CH mais pas sa charge US
- Le coach (fallbackTemplate `fatcaGuidance`) est le SEUL point FATCA

### P2-5: Ecran expat aveugle a l'archetype
- US citizen voit le simulateur de forfait fiscal (qui ne le concerne pas)
- Pas de contenu FATCA/FBAR specifique

### P2-6: Rente vs Capital affiche la rente sur l'avoir ACTUEL
- Julien 49 ans voit 3'350 CHF/an (70k × 4.8%) au lieu de ~34k/an a 65 ans
- Misleading pour les utilisateurs loin de la retraite

### P2-7: Mois hardcodes en francais dans timeline_provider
### P2-8: Hub Explorer labels non internationalises

---

## CALCULATEURS — VERIFICATION GOLDEN VALUES

### AVS (Julien, 49 ans, 122'207 CHF)
| Calcul | Code | Golden | Verdict |
|--------|------|--------|---------|
| Rente mensuelle max | 2'520 CHF | 2'520 CHF | ✅ |
| Couple marie cap 150% | 3'780 CHF | 3'780 CHF | ✅ |
| 13e rente | Incluse | Incluse | ✅ |
| Annees cotisation (49 ans, arrive a 20) | 29 + 16 future = 44 | 44 | ✅ |

### LPP (CPE Plan Maxi)
| Calcul | Code | Golden | Verdict |
|--------|------|--------|---------|
| Salaire assure | 91'967 | 91'967 | ✅ |
| Bonification | 24% | 24% | ✅ |
| Taux remuneration caisse | 5% | 5% | ✅ |
| Avoir actuel | 70'377 | 70'377 | ✅ |
| Rachat max | 539'414 | 539'414 | ✅ |

### Mortgage (FINMA/ASB)
| Regle | Code | Loi | Verdict |
|-------|------|-----|---------|
| Taux theorique | 5% | FINMA | ✅ |
| Amortissement | 1%/an | ASB | ✅ |
| Frais | 1%/an | ASB | ✅ |
| Charges max | 1/3 revenu | FINMA | ✅ |
| Fonds propres | 20% | FINMA | ✅ |
| LPP max 2e pilier | 10% | OPP2 | ✅ |
| EPL minimum | 20'000 | OPP2 art. 5 | ✅ |

### 3a
| Calcul | Code | Loi | Verdict |
|--------|------|-----|---------|
| Plafond salarie LPP | 7'258 | OPP3 | ✅ |
| Plafond independant sans LPP | 36'288 | OPP3 | ✅ |
| Retroactif max annees | min(10, annees depuis 2025) | LPP art. 33a | ✅ |

### Document scan (extraction LPP CPE)
| Champ | Extrait | Golden | Verdict |
|-------|---------|--------|---------|
| avoir_vieillesse_total | 70'376.6 | 70'377 | ✅ |
| salaire_assure | 91'967.0 | 91'967 | ✅ |
| rachat_maximum | 539'413.7 | 539'414 | ✅ |
| rente_invalidite_annuelle | 55'188 | — | ✅ |
| rente_conjoint_annuelle | 36'792 | — | ✅ |

---

## ARCHITECTURE REELLE (pas revee)

### Flow de donnees — LE PROBLEME CENTRAL

```
                    ┌─────────────────────────────────────────────┐
                    │               BACKEND (Railway)              │
                    │  ProfileModel.data (PostgreSQL JSONB)        │
                    │  ↑ save_fact()     ↑ PATCH /profiles         │
                    │  ↑ upload/extract  ↑ budget/me               │
                    └──────────┬──────────────────────┬────────────┘
                               │                      │
                    ┌──────────▼──────────┐    ┌──────▼──────────────┐
                    │  /overview/me       │    │  /coach/chat        │
                    │  Lit ProfileModel   │    │  Lit ProfileModel   │
                    │  Calculs serveur    │    │  Contexte LLM       │
                    │  ✅ COMPLET         │    │  ✅ COMPLET         │
                    └─────────────────────┘    └─────────────────────┘

    ══════════════════════════ MURAL ══════════════════════════════

                    ┌─────────────────────────────────────────────┐
                    │              FLUTTER (Mobile)                │
                    │  CoachProfile (SharedPreferences)            │
                    │  ↑ scan confirm     ↑ wizard answers         │
                    │  ↑ mini-onboarding  ✗ PAS save_fact          │
                    └──────────┬──────────────────────┬────────────┘
                               │                      │
                    ┌──────────▼──────────┐    ┌──────▼──────────────┐
                    │  Mon argent         │    │  Simulateurs        │
                    │  PatrimoineAggr.    │    │  Retraite, Mortgage │
                    │  CoachWhisper       │    │  3a, Disability     │
                    │  ⚠️ PARTIEL         │    │  ⚠️ PARTIEL         │
                    └─────────────────────┘    └─────────────────────┘
```

**Le mur** : le backend a les donnees completes (save_fact + scan + wizard + PATCH). Flutter n'a que scan + wizard. Les donnees du coach sont perdues pour l'app.

### Navigation reelle

```
Landing (/) → /coach/chat (PAS /anonymous/chat!) → ecran vide si pas auth
                                                    → crash si pas SLM
  ⚠️ Le flow anonyme (/anonymous/chat avec 3 msg + conversion gate) est MORT

Shell 4 tabs:
├─ Aujourd'hui: Timeline tensions → deep links coach
├─ Mon argent: Budget + Patrimoine → scan, coach, bilan
├─ Coach: Chat AI (SLM → BYOK → Server → Fallback)
└─ Explorer: 7 hubs × 41 ecrans

ProfileDrawer: couple, documents, history, BYOK, langue, privacy

67 routes canoniques + ~30 redirects legacy
0 Navigator.push (GoRouter partout sauf 1 fullscreen dialog)
```

---

## PLAN D'ACTION PAR PRIORITE

### Immediat — avant tout (P0, bloquant)
1. **REPARER LE FLOW ANONYME** — soit router landing vers `/anonymous/chat`, soit ajouter auth gate + fallback dans `CoachChatScreen`. C'est LE blocker pour tout nouvel utilisateur.
2. **Deployer profile.py fix** sur staging (push branche → Railway auto-deploy)
3. **Cabler save_fact → CoachProfile Flutter** — apres chaque save_fact reussi dans le chat, mettre a jour SharedPreferences locales. Sans ca, les donnees du coach sont invisibles pour l'app.
4. **Rebuild device propre** pour verifier Coach tab routing

### Semaine 2 (P1)
5. **Hypotheque couple income** — lire revenu conjoint depuis profil
6. **Consolider disclaimers** — retirer per-message OU conditionner footer
7. **Guard 3a nudges pour FATCA** — `if (profile.canContribute3a)` dans NudgeEngine + JitaiService + CommunityChallenge
8. **LPP conversion rate** — stocker le taux enveloppe CPE depuis le certificat
9. **i18n MintShell + Explorer** — labels dans ARB files (6 langues cassees)

### Semaine 3 (P2)
10. **Pre-remplir Mariage/Naissance/Divorce** depuis CoachProfile
11. **dateOfBirth persistence** — debug backend PATCH
12. **Nettoyer 177 fichiers fantomes** macOS
13. **Ecran expat** — adapter le contenu par archetype (FATCA vs EU vs non-EU)

### Moyen terme
14. **Mode couple reel** — partager les donnees financieres entre conjoints
15. **Double imposition US/CH** — au moins un avertissement dans le simulateur fiscal
16. **Silent opener enrichi** — quand pas de keyNumber, afficher un message d'accueil au lieu d'un ecran vide
