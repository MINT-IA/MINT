# UX Navigation Architecture — MINT V1

> **Statut** : Reference document pour implementation V1
> **Date** : 2026-03-15
> **Methode** : 20 iterations autoresearch, score final 95/100
> **Principe** : 3 onglets, 16 ecrans, 0 orphelins, max 3 taps

---

## TABLE DES MATIERES

1. [Architecture globale](#1-architecture-globale)
2. [Tab Pulse](#2-tab-pulse)
3. [Tab Mint](#3-tab-mint)
4. [Tab Moi](#4-tab-moi)
5. [Ecrans dedies — Retraite & Prevoyance](#5-ecrans-dedies--retraite--prevoyance)
6. [Ecrans dedies — Fiscalite](#6-ecrans-dedies--fiscalite)
7. [Ecrans dedies — Immobilier](#7-ecrans-dedies--immobilier)
8. [Ecrans dedies — Budget & Dette](#8-ecrans-dedies--budget--dette)
9. [Ecrans dedies — Famille](#9-ecrans-dedies--famille)
10. [Ecrans dedies — Emploi & Statut](#10-ecrans-dedies--emploi--statut)
11. [Ecrans dedies — Assurance & Sante](#11-ecrans-dedies--assurance--sante)
12. [Ecrans dedies — Documents](#12-ecrans-dedies--documents)
13. [Ecrans dedies — Education](#13-ecrans-dedies--education)
14. [Life events — Declencheurs](#14-life-events--declencheurs)
15. [Onboarding — Flow inline](#15-onboarding--flow-inline)
16. [Safe Mode — Comportement dette](#16-safe-mode--comportement-dette)
17. [Carte de navigation complete](#17-carte-de-navigation-complete)
18. [Inventaire complet des simulateurs](#18-inventaire-complet-des-simulateurs)
19. [Plan de migration](#19-plan-de-migration)

---

## 1. ARCHITECTURE GLOBALE

### Principes directeurs

```
Complex inside. Radically simple outside.
```

| Principe | Regle |
|----------|-------|
| **3 onglets max** | Pulse, Mint, Moi |
| **Max 3 taps** | N'importe quel contenu accessible en 3 taps max |
| **0 orphelins** | Chaque ecran a au moins 1 chemin d'acces |
| **0 doublons** | 1 route = 1 ecran, pas de redirections parasites |
| **Contextualite radicale** | L'archetype + confiance + calendrier determinent ce qui est visible |
| **Coach comme hub** | 49+ simulateurs accessibles via le coach (Response Cards) |
| **Education conversationnelle** | Pas de hub educatif separe — le coach repond aux questions |

### Les 3 onglets

```
┌─────────────────────────────────────────────────┐
│                                                 │
│              [Contenu du tab actif]             │
│                                                 │
│                                                 │
│                                         🟢 FAB │
│                                        Mentor  │
├─────────────────────────────────────────────────┤
│                                                 │
│   📊 Pulse      💬 Mint       👤 Moi          │
│   Ma situation   Mon coach     Mon profil       │
│                                                 │
└─────────────────────────────────────────────────┘
```

| Tab | Icone | Intention | Contenu principal |
|-----|-------|-----------|-------------------|
| **Pulse** | `show_chart` / `show_chart_outlined` | Ou j'en suis | Score visibilite + priorite contextuelle + chiffres cles |
| **Mint** | `chat_bubble` / `chat_bubble_outline` | Que faire | Chat coach + Response Cards + simulations inline |
| **Moi** | `person` / `person_outline` | Qui je suis | Fiche resumee editable + conjoint + parametres |

### FAB Mentor (toujours visible)

Le bouton flottant "Mentor" est present sur TOUS les tabs. Il ouvre le coach (tab Mint) avec un prompt contextuel selon le tab actif :
- Depuis Pulse : "Comment ameliorer ma situation ?"
- Depuis Moi : "Que me manque-t-il ?"
- Depuis Mint : masque (deja sur le coach)

### Carte de navigation simplifiee

```
                    ┌─────────┐
                    │ Landing │
                    │  (auth) │
                    └────┬────┘
                         │
                    ┌────┴────┐
                    │  /home  │
                    │ 3 tabs  │
                    └────┬────┘
           ┌─────────┬──┴──┬─────────┐
           │         │     │         │
      ┌────┴───┐ ┌──┴──┐ ┌┴────┐    │
      │ Pulse  │ │Mint │ │ Moi │    │
      │ tab 0  │ │tab 1│ │tab 2│    │
      └───┬────┘ └──┬──┘ └──┬──┘    │
          │         │       │        │
          ▼         ▼       ▼        │
    [Ecrans dedies via push navigation]
    ┌──────────────────────────────┐
    │ Retraite, Rente vs Capital,  │
    │ Rachat LPP, EPL, Budget,    │
    │ Pilier 3a, Hypotheque,      │
    │ Decaissement, Scanner,      │
    │ Review, Couple, Rapport,    │
    │ Invalidite, Divorce,        │
    │ Succession                   │
    └──────────────────────────────┘
```

### 16 ecrans — Inventaire complet

| # | Ecran | Route | Acces depuis | CTA educatif |
|---|-------|-------|-------------|-------------|
| — | **Pulse** (tab) | `/home` tab 0 | Tab bar | — |
| — | **Mint** (tab) | `/home` tab 1 | Tab bar | — |
| — | **Moi** (tab) | `/home` tab 2 | Tab bar | — |
| 1 | Auth | `/auth` | Premier lancement | Se connecter |
| 2 | Trajectoire retraite | `/retraite` | Pulse card / Coach | Simuler mes scenarios |
| 3 | Rente vs Capital | `/rente-vs-capital` | Coach / Pulse | Explorer le point d'equilibre |
| 4 | Rachat LPP | `/rachat-lpp` | Coach / Pulse | Simuler l'impact fiscal |
| 5 | EPL (retrait anticipe) | `/epl` | Coach response | Simuler un retrait |
| 6 | Budget / Reste a vivre | `/budget` | Pulse card | Voir ma marge mensuelle |
| 7 | Pilier 3a | `/pilier-3a` | Coach / Pulse | Decouvrir l'impact fiscal |
| 8 | Hypotheque | `/hypotheque` | Coach response | Verifier ma capacite |
| 9 | Decaissement optimise | `/decaissement` | Coach response | Simuler le sequencage |
| 10 | Scanner document | `/scan` | Pulse CTA / Moi | Scanner mon certificat |
| 11 | Review extraction | `/scan/review` | Apres scan | Verifier les valeurs |
| 12 | Couple — Invitation | `/couple/invite` | Moi | Inviter mon/ma partenaire |
| 13 | Rapport PDF | `/rapport` | Moi | Exporter mon bilan |
| 14 | Invalidite gap | `/invalidite` | Coach / Pulse | Voir ma couverture |
| 15 | Divorce simulateur | `/divorce` | Coach (life event) | Simuler l'impact |
| 16 | Succession simulateur | `/succession` | Coach (life event) | Simuler la transmission |

### Comment les 49+ simulateurs restent accessibles

Aucun simulateur n'est supprime. Ils sont TOUS accessibles via 2 chemins :

**Chemin 1 — Coach (principal)** : L'utilisateur pose une question au coach. Le coach repond avec une Response Card contenant le simulateur inline ou un lien "Voir le detail" vers l'ecran dedie.

**Chemin 2 — Recherche** : Le coach a une fonction recherche. "hypotheque", "3a", "invalidite" → resultats instantanes.

**Chemin 3 — Priorite contextuelle** : Pulse affiche 1-3 cartes d'action selon l'archetype. Ces cartes menent directement aux ecrans dedies.

### Mapping complet : ancien ecran → nouveau chemin

| Ancien ecran / route | Nouveau chemin |
|---------------------|---------------|
| `/retirement` | `/retraite` (ecran dedie #2) |
| `/coach/dashboard` | `/retraite` |
| `/coach/cockpit` | `/retraite` (section cockpit) |
| `/arbitrage/rente-vs-capital` | `/rente-vs-capital` (ecran dedie #3) |
| `/lpp-deep/rachat` | `/rachat-lpp` (ecran dedie #4) |
| `/arbitrage/rachat-vs-marche` | `/rachat-lpp` (section comparaison) |
| `/lpp-deep/epl` | `/epl` (ecran dedie #5) |
| `/lpp-deep/libre-passage` | Coach Response Card |
| `/budget` | `/budget` (ecran dedie #6) |
| `/simulator/3a` | `/pilier-3a` (ecran dedie #7) |
| `/3a-deep/comparator` | `/pilier-3a` (section comparateur) |
| `/3a-deep/real-return` | `/pilier-3a` (section rendement reel) |
| `/3a-deep/staggered-withdrawal` | `/pilier-3a` (section retrait echelonne) |
| `/mortgage/affordability` | `/hypotheque` (ecran dedie #8) |
| `/mortgage/amortization` | `/hypotheque` (section amortissement) |
| `/mortgage/epl-combined` | `/hypotheque` (section EPL + hypotheque) |
| `/mortgage/imputed-rental` | `/hypotheque` (section valeur locative) |
| `/mortgage/saron-vs-fixed` | `/hypotheque` (section SARON vs fixe) |
| `/coach/decaissement` | `/decaissement` (ecran dedie #9) |
| `/arbitrage/calendrier-retraits` | `/decaissement` (section calendrier) |
| `/arbitrage/allocation-annuelle` | Coach Response Card |
| `/arbitrage/location-vs-propriete` | Coach Response Card |
| `/arbitrage/bilan` | Coach Response Card |
| `/document-scan` | `/scan` (ecran dedie #10) |
| `/document-scan/extraction-review` | `/scan/review` (ecran dedie #11) |
| `/document-scan/avs-guide` | `/scan` (section guide integre) |
| `/document-scan/impact` | `/scan/review` (section impact) |
| `/household` | `/couple/invite` (ecran dedie #12) |
| `/household/accept` | `/couple/invite` (section acceptation) |
| `/report/v2` | `/rapport` (ecran dedie #13) |
| `/disability/gap` | `/invalidite` (ecran dedie #14) |
| `/disability/insurance` | `/invalidite` (section assurance) |
| `/disability/self-employed` | `/invalidite` (section independant) |
| `/life-event/divorce` | `/divorce` (ecran dedie #15) |
| `/life-event/succession` | `/succession` (ecran dedie #16) |
| `/coach/succession` | `/succession` |
| `/mariage` | Coach Response Card + declencheur profil |
| `/naissance` | Coach Response Card + declencheur profil |
| `/concubinage` | Coach Response Card + declencheur profil |
| `/expatriation` | Coach Response Card + declencheur profil |
| `/frontalier` | Coach Response Card |
| `/segments/independant` | Coach Response Card |
| `/segments/gender-gap` | Coach Response Card |
| `/unemployment` | Coach Response Card |
| `/first-job` | Coach Response Card |
| `/fiscal` | Coach Response Card |
| `/life-event/housing-sale` | Coach Response Card |
| `/life-event/donation` | Coach Response Card |
| `/check/debt` | `/budget` (Safe Mode) |
| `/debt/ratio` | `/budget` (section ratio) |
| `/debt/help` | `/budget` (Safe Mode ressources) |
| `/debt/repayment` | `/budget` (Safe Mode remboursement) |
| `/assurances/lamal` | Coach Response Card |
| `/assurances/coverage` | Coach Response Card |
| `/simulator/compound` | Coach Response Card |
| `/simulator/leasing` | Coach Response Card |
| `/simulator/credit` | Coach Response Card |
| `/simulator/job-comparison` | Coach Response Card |
| `/education/hub` | Coach (reponses educatives) |
| `/education/theme/:id` | Coach (reponses educatives) |
| `/tools` | Supprime (tout via coach) |
| `/portfolio` | Moi (section patrimoine) |
| `/timeline` | Moi (section historique) |
| `/confidence` | Moi (section confiance) |
| `/score-reveal` | Pulse (apres onboarding) |
| `/ask-mint` | Mint tab (= le coach) |
| `/open-banking/*` | Post-V1 |
| `/admin-*` | Dev only, hors navigation |
| `/auth/login` | `/auth` (magic link) |
| `/auth/register` | `/auth` (magic link) |
| `/auth/forgot-password` | `/auth` (magic link) |
| `/auth/verify-email` | `/auth` (magic link) |
| `/onboarding/*` | Pulse etat vide (inline) |
| `/coach/agir` | Pulse (section priorite) |
| `/coach/checkin` | Pulse (section check-in) |
| `/coach/refresh` | Pulse (notification annuelle) |
| `/coach/chat` | Mint tab |
| `/bank-import` | Post-V1 |
| `/data-block/:type` | Moi (edition inline) |

---

## 2. TAB PULSE

### Fiche ecran

- **Nom** : Pulse
- **Route** : `/home` (tab index 0)
- **Intention** : Repondre a "Ou j'en suis ?" en 3 secondes
- **Acces** : Tab bar (position 1)
- **Archetypes** : Tous — le contenu s'adapte

### Wireframe — Etat vide (premier lancement)

```
┌──────────────────────────────────────┐
│ PULSE                          [···] │
├──────────────────────────────────────┤
│                                      │
│  Bienvenue sur MINT                  │
│                                      │
│  Reponds a 3 questions               │
│  pour decouvrir ta situation         │
│  financiere en Suisse.               │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ Quel age as-tu ?               │  │
│  │ [          49            ]     │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ Ton salaire brut annuel ?      │  │
│  │ [      ~120'000 CHF      ]     │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ Ton canton ?                   │  │
│  │ [    VS - Valais         ▼]    │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  Decouvrir mon apercu →       │  │
│  └────────────────────────────────┘  │
│                                      │
│  Estimation basee sur 3 informations │
│  Plus tu precises, plus c'est fiable │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  Outil educatif · Ne constitue pas   │
│  un conseil · LSFin                  │
└──────────────────────────────────────┘
```

### Wireframe — Etat rempli (utilisateur avec profil)

```
┌──────────────────────────────────────┐
│ PULSE                    [Solo|Duo▼] │
├──────────────────────────────────────┤
│                                      │
│  ── HERO ADAPTATIF ──────────────    │
│                                      │
│  Ton revenu apres 65 ans             │
│                                      │
│       CHF 5'234 / mois              │
│                                      │
│  Aujourd'hui : CHF 8'333            │
│  Tu gardes 63% de ton train de vie   │
│                                      │
│  ▲ +CHF 180 vs il y a 3 mois        │
│                                      │
│  Confiance : ████████░░ 72%          │
│  ℹ Basé sur 12 donnees              │
│                                      │
│  ── PRIORITE #1 ─────────────────    │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 🟢 Rachat LPP                 │  │
│  │                                │  │
│  │ Tu pourrais economiser         │  │
│  │ CHF 12'400 d'impot             │  │
│  │ sur 5 ans.                     │  │
│  │                                │  │
│  │ [Simuler l'impact fiscal →]   │  │
│  │                                │  │
│  │ LPP art. 79b · LIFD art. 33   │  │
│  └────────────────────────────────┘  │
│                                      │
│  ── 3 PASTILLES ─────────────────    │
│                                      │
│  ┌──────────┬──────────┬──────────┐  │
│  │ Retraite │ Budget   │ Patri-   │  │
│  │          │          │ moine    │  │
│  │ 63%      │ +CHF 890 │ 122k    │  │
│  │ remplace-│ marge/   │ net      │  │
│  │ ment     │ mois     │          │  │
│  └──────────┴──────────┴──────────┘  │
│                                      │
│  ── ENRICHIR ────────────────────    │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 📄 Scanne ton certificat LPP  │  │
│  │    Confiance → +15 points      │  │
│  │    [Scanner →]                 │  │
│  └────────────────────────────────┘  │
│                                      │
│  ── SCORE DE PREPARATION ────────    │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  Solidite financiere : 47/100  │  │
│  │                                │  │
│  │  L ████░░░░  12/25 Liquidite   │  │
│  │  F ██████░░  15/25 Fiscalite   │  │
│  │  R █████░░░  13/25 Retraite    │  │
│  │  S ███░░░░░   7/25 Risques     │  │
│  │                                │  │
│  │  Progression : +4 ce trimestre │  │
│  │                                │  │
│  │  Action pour progresser :      │  │
│  │  Constituer 2 mois de reserve  │  │
│  └────────────────────────────────┘  │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  Calculs bases sur le droit en       │
│  vigueur au 01.01.2026              │
│  Outil educatif · LSFin · LAVS/LPP  │
└──────────────────────────────────────┘
```

### Wireframe — Etat couple

```
┌──────────────────────────────────────┐
│ PULSE                    [Solo|Duo●] │
├──────────────────────────────────────┤
│                                      │
│  Votre revenu apres 65 ans           │
│       (Julien + Lauren)              │
│                                      │
│       CHF 8'505 / mois              │
│                                      │
│  Aujourd'hui : CHF 12'978 net/mois   │
│  Vous gardez 65.5% ensemble          │
│                                      │
│  ┌──────────────┬───────────────┐    │
│  │   Julien     │    Lauren     │    │
│  │   CHF 5'890  │    CHF 2'615  │    │
│  │   71% conf.  │    38% conf.  │    │
│  │   swiss_nat. │    expat_us   │    │
│  └──────────────┴───────────────┘    │
│                                      │
│  ⚠ Lauren : confiance faible (38%)  │
│  [Inviter Lauren a scanner →]       │
│                                      │
│  ... (reste identique) ...           │
└──────────────────────────────────────┘
```

### Contenu adaptatif par archetype

| Archetype | Hero | Priorite #1 | Pastille accent |
|-----------|------|-------------|-----------------|
| `swiss_native` < 30 | Economie 3a / an | Ouvrir un 3a | Budget (marge) |
| `swiss_native` 30-50 | Revenu apres 65 | Rachat LPP | Retraite (ratio) |
| `swiss_native` 50+ | Point equilibre rente/capital | Calendrier retraits | Patrimoine |
| `expat_eu` | Annees AVS manquantes | Verifier periodes EU | Retraite |
| `expat_us` | Exposition FATCA | 3a restrictions | Fiscalite |
| `independent_no_lpp` | Gap retraite | 3a elargi (36k) | Retraite |
| `cross_border` | Differentiel fiscal | Impot source | Fiscalite |

### Interactions

| Action | Resultat |
|--------|---------|
| Tap hero | Push → ecran dedie correspondant (ex: `/retraite`) |
| Tap priorite #1 | Push → ecran dedie ou coach selon le type |
| Tap pastille | Push → ecran dedie du domaine |
| Tap "Scanner" | Push → `/scan` |
| Tap [Solo/Duo] | Toggle vue individuelle / couple |
| Scroll | Vertical, naturel. Hero en haut = toujours visible au retour |
| Pull-to-refresh | Recalcule projections + met a jour confiance |

### Animations

- Hero : CountUp animation sur le montant CHF (500ms ease-out)
- Pastilles : Stagger fade-in (200ms delay entre chaque)
- Priorite : Slide-in depuis la droite (300ms)
- Score FRI : Barres qui se remplissent (800ms spring)
- Couple switch : Cross-fade (200ms)

---

## 3. TAB MINT

### Fiche ecran

- **Nom** : Mint (Coach)
- **Route** : `/home` (tab index 1)
- **Intention** : Repondre a n'importe quelle question financiere suisse
- **Acces** : Tab bar (position 2) + FAB Mentor depuis tous les tabs
- **Archetypes** : Tous

### Wireframe — Etat initial (pas de conversation)

```
┌──────────────────────────────────────┐
│ MINT                      [Reglages] │
├──────────────────────────────────────┤
│                                      │
│         💬                          │
│                                      │
│  Salut ! Je suis ton compagnon       │
│  finances suisses.                   │
│                                      │
│  Pose-moi une question, ou           │
│  choisis un sujet :                  │
│                                      │
│  ┌──────────────────────────────┐    │
│  │ 🏖 Retraite & prevoyance    │    │
│  │ Combien je toucherai ?       │    │
│  └──────────────────────────────┘    │
│                                      │
│  ┌──────────────────────────────┐    │
│  │ 💰 Impots & 3e pilier       │    │
│  │ Comment payer moins ?        │    │
│  └──────────────────────────────┘    │
│                                      │
│  ┌──────────────────────────────┐    │
│  │ 🏠 Immobilier                │    │
│  │ Est-ce que je peux acheter ?  │    │
│  └──────────────────────────────┘    │
│                                      │
│  ┌──────────────────────────────┐    │
│  │ 🔍 Autre question            │    │
│  │ Divorce, invalidite, expat...│    │
│  └──────────────────────────────┘    │
│                                      │
│                                      │
├──────────────────────────────────────┤
│ [🔍 Rechercher...]    [🎤]   [📷]  │
└──────────────────────────────────────┘
```

### Wireframe — Conversation active avec Response Card

```
┌──────────────────────────────────────┐
│ MINT                      [Reglages] │
├──────────────────────────────────────┤
│                                      │
│                    ┌───────────────┐  │
│                    │ Est-ce que le │  │
│                    │ rachat LPP    │  │
│                    │ vaut le coup ?│  │
│                    └───────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 💬 Mint                        │  │
│  │                                │  │
│  │ Bonne question ! Avec ton      │  │
│  │ profil, voici ce que ca        │  │
│  │ donnerait :                    │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ ╔══ RESPONSE CARD ══════════╗  │  │
│  │ ║                           ║  │  │
│  │ ║  Rachat LPP vs Marche    ║  │  │
│  │ ║                           ║  │  │
│  │ ║  Rachat    │  Marche      ║  │  │
│  │ ║  +CHF 12.4k│ +CHF 9.8k  ║  │  │
│  │ ║  impot     │ rendement    ║  │  │
│  │ ║  sur 5 ans │ sur 5 ans   ║  │  │
│  │ ║                           ║  │  │
│  │ ║  Hypotheses :             ║  │  │
│  │ ║  Taux marginal: 28%       ║  │  │
│  │ ║  Rendement marche: 4%     ║  │  │
│  │ ║  Horizon: 16 ans          ║  │  │
│  │ ║                           ║  │  │
│  │ ║  [Modifier hypotheses]    ║  │  │
│  │ ║  [Voir detail complet →]  ║  │  │
│  │ ║                           ║  │  │
│  │ ║  LPP art. 79b             ║  │  │
│  │ ║  LIFD art. 33/38          ║  │  │
│  │ ╚═══════════════════════════╝  │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 💬 Mint                        │  │
│  │                                │  │
│  │ Dans ce scenario simule, le    │  │
│  │ rachat produit un patrimoine   │  │
│  │ superieur de CHF 18'400.       │  │
│  │                                │  │
│  │ Si le rendement marche depasse │  │
│  │ 5.2%, le resultat s'inverse.   │  │
│  │                                │  │
│  │ Souhaites-tu explorer :        │  │
│  │ • Le retrait echelonne ?       │  │
│  │ • L'impact sur ta retraite ?   │  │
│  └────────────────────────────────┘  │
│                                      │
├──────────────────────────────────────┤
│ [Message...]              [🎤] [➤]  │
└──────────────────────────────────────┘
```

### Wireframe — Response Card educative

```
┌────────────────────────────────────┐
│ ╔══ EDUCATION ═══════════════════╗ │
│ ║                                ║ │
│ ║  C'est quoi le 2e pilier ?     ║ │
│ ║                                ║ │
│ ║  Le 2e pilier (LPP), c'est    ║ │
│ ║  l'epargne retraite que ton    ║ │
│ ║  employeur et toi alimentez    ║ │
│ ║  chaque mois.                  ║ │
│ ║                                ║ │
│ ║  Pour toi :                    ║ │
│ ║  CHF 2'410/mois a la retraite ║ │
│ ║  (= 46% de ton revenu futur)  ║ │
│ ║                                ║ │
│ ║  ┌───────────────────────┐     ║ │
│ ║  │ 🧱 Pile de briques    │     ║ │
│ ║  │ ┌─────┐ CHF 890  3a  │     ║ │
│ ║  │ ├─────┤ CHF 2410 LPP │     ║ │
│ ║  │ ├─────┤ CHF 1934 AVS │     ║ │
│ ║  │ └─────┘               │     ║ │
│ ║  └───────────────────────┘     ║ │
│ ║                                ║ │
│ ║  [Simuler mon LPP →]          ║ │
│ ║                                ║ │
│ ║  LPP art. 14-16               ║ │
│ ╚════════════════════════════════╝ │
└────────────────────────────────────┘
```

### Types de Response Cards

| Type | Contenu | CTA | Ecran dedie |
|------|---------|-----|-------------|
| **Simulation** | Chiffres personnalises + hypotheses | "Voir detail complet" | Oui |
| **Arbitrage** | 2-3 options cote a cote | "Modifier hypotheses" | Oui |
| **Education** | Explication + chiffre personnel | "Simuler" | Optionnel |
| **Life event** | Impact estime + checklist | "Mettre a jour profil" | Non |
| **Alerte** | Seuil depasse + action | "Agir maintenant" | Oui |
| **Calendrier** | Echeance + montant | "Programmer" | Non |

### Simulateurs accessibles via Response Cards (sans ecran dedie)

Ces 33+ simulateurs sont entierement rendus DANS le coach via Response Cards :

| Simulateur | Declencheur conversation |
|-----------|-------------------------|
| Libre passage | "Qu'est-ce que le libre passage ?" |
| Allocation annuelle | "J'ai 10k, ou les mettre ?" |
| Location vs Propriete | "Louer ou acheter ?" |
| Bilan arbitrage | "Resume mes options" |
| Mariage impact | "Je me marie, quel impact ?" |
| Naissance impact | "J'attends un enfant" |
| Concubinage protection | "On n'est pas maries" |
| Expatriation | "Je pars a l'etranger" |
| Frontalier | "Je travaille en Suisse mais habite en France" |
| Independant hub | "Je me mets a mon compte" |
| AVS cotisations indep | "Combien je paie d'AVS en tant qu'independant ?" |
| IJM indemnites | "Assurance perte de gain" |
| 3a elargi indep | "3a sans LPP" |
| Dividende vs Salaire | "Me verser un dividende ou un salaire ?" |
| LPP volontaire | "LPP quand on est independant" |
| Gender gap | "Ecart femmes/hommes retraite" |
| Chomage | "J'ai perdu mon emploi" |
| Premier emploi | "C'est mon premier job" |
| Fiscal comparateur | "Quel canton est moins cher ?" |
| Vente immobiliere | "Je vends ma maison" |
| Donation | "Je veux donner a mes enfants" |
| LaMAL franchise | "Quelle franchise choisir ?" |
| Couverture check | "Suis-je bien assure ?" |
| Interet compose | "Combien rapporte l'interet compose ?" |
| Leasing | "Le leasing, bonne idee ?" |
| Credit consommation | "Un credit conso, ca coute combien ?" |
| Job comparison | "Comparer deux offres d'emploi" |
| Amortissement | "Amortir direct ou indirect ?" |
| Valeur locative | "C'est quoi la valeur locative ?" |
| SARON vs fixe | "Taux fixe ou SARON ?" |
| EPL combine | "Utiliser mon 2e pilier pour acheter ?" |
| Retrait 3a echelonne | "Retirer mon 3a en plusieurs fois" |
| Rendement reel 3a | "Mon 3a rapporte vraiment combien ?" |
| Comparateur 3a | "Quel prestataire 3a choisir ?" |

### Interactions

| Action | Resultat |
|--------|---------|
| Tap suggestion | Envoie le message pre-rempli au coach |
| Tap "Voir detail complet" | Push → ecran dedie |
| Tap "Modifier hypotheses" | Ouvre editeur inline (bottom sheet) |
| Recherche | Filtre instantane sur tous les sujets |
| Long press Response Card | Partager / Exporter |
| Scroll | Vertical conversation |

### Fallback (coach offline / pas de BYOK)

Si le SLM local et le BYOK sont tous deux indisponibles :
- Les suggestions pre-remplies fonctionnent avec des **templates statiques**
- Les Response Cards sont generees par le moteur de calcul (pas par LLM)
- Le texte conversationnel est remplace par des titres factuels
- L'app reste 100% fonctionnelle

---

## 4. TAB MOI

### Fiche ecran

- **Nom** : Moi
- **Route** : `/home` (tab index 2)
- **Intention** : Voir et modifier mes donnees personnelles
- **Acces** : Tab bar (position 3)
- **Archetypes** : Tous

### Wireframe — Etat rempli

```
┌──────────────────────────────────────┐
│ MOI                         [···]    │
├──────────────────────────────────────┤
│                                      │
│  ── IDENTITE ────────────────────    │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  Julien, 49 ans               │  │
│  │  Valais (VS) · Suisse          │  │
│  │  Archetype : swiss_native      │  │
│  │  Salaire brut : CHF 122'207    │  │
│  │  Statut : Salarie              │  │
│  │                                │  │
│  │  [Modifier ✏]                 │  │
│  └────────────────────────────────┘  │
│                                      │
│  ── CONJOINT ────────────────────    │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  Lauren, 43 ans                │  │
│  │  Confiance : 38% (⚠ faible)  │  │
│  │  Archetype : expat_us          │  │
│  │                                │  │
│  │  [Voir profil] [Inviter →]    │  │
│  └────────────────────────────────┘  │
│                                      │
│  ── PATRIMOINE ──────────────────    │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  LPP :     CHF 70'377 (CPE)   │  │
│  │  3a :      CHF 32'000          │  │
│  │  Epargne : CHF 45'000          │  │
│  │  Dettes :  CHF 0               │  │
│  │  Immob. :  —                   │  │
│  │                                │  │
│  │  [Modifier ✏]                 │  │
│  └────────────────────────────────┘  │
│                                      │
│  ── CONFIANCE ───────────────────    │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  Confiance globale : 72%       │  │
│  │                                │  │
│  │  ████████████████░░░░░░        │  │
│  │                                │  │
│  │  Revenu    ████████░░ 80%     │  │
│  │  LPP       ██████████ 95%     │  │
│  │  AVS       █████░░░░░ 50%     │  │
│  │  Patrimoine ██████░░░ 60%     │  │
│  │  Charges   ████░░░░░░ 40%     │  │
│  │                                │  │
│  │  Sources : certificat (LPP),   │  │
│  │  estimation (AVS, patrimoine)  │  │
│  │                                │  │
│  │  [Scanner un document →]      │  │
│  └────────────────────────────────┘  │
│                                      │
│  ── DOCUMENTS ───────────────────    │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  📄 Certificat LPP CPE        │  │
│  │     Scanne le 12.01.2026       │  │
│  │                                │  │
│  │  [Scanner +]  [Voir coffre →] │  │
│  └────────────────────────────────┘  │
│                                      │
│  ── HISTORIQUE ──────────────────    │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  Il y a 3 mois : 52% → 63%    │  │
│  │  Aujourd'hui : 65.5%           │  │
│  │                                │  │
│  │  [Voir timeline complete →]   │  │
│  └────────────────────────────────┘  │
│                                      │
│  ── PARAMETRES ──────────────────    │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  🌐 Langue : Francais (FR)    │  │
│  │  🤖 Moteur IA : SLM local     │  │
│  │  🔑 Cle API : Non configuree  │  │
│  │  🔔 Notifications : Activees  │  │
│  │  📊 Analytiques : Consentement│  │
│  │  📋 CGU · Mentions legales    │  │
│  │  🚪 Se deconnecter            │  │
│  │                                │  │
│  │  [Exporter mon rapport PDF →] │  │
│  └────────────────────────────────┘  │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  Tes donnees sont stockees           │
│  localement sur ton appareil.        │
│  nLPD · Consentement granulaire      │
└──────────────────────────────────────┘
```

### Edition inline

Chaque section a un bouton "Modifier" qui ouvre un **bottom sheet** avec les champs editables. Pas de navigation vers un ecran separe.

```
┌──────────────────────────────────────┐
│  ── Modifier : Identite ──────────   │
│                                      │
│  Prenom      [Julien            ]    │
│  Annee naiss.[1977              ]    │
│  Canton      [VS - Valais      ▼]   │
│  Nationalite [Suisse           ▼]   │
│  Salaire brut[122207            ]    │
│  Statut      [Salarie          ▼]   │
│                                      │
│  [Annuler]         [Enregistrer]     │
└──────────────────────────────────────┘
```

### Interactions

| Action | Resultat |
|--------|---------|
| Tap "Modifier" | Bottom sheet edition inline |
| Tap "Inviter" | Push → `/couple/invite` |
| Tap "Scanner" | Push → `/scan` |
| Tap "Voir coffre" | Push → documents list |
| Tap "Voir timeline" | Expand section historique |
| Tap "Exporter rapport" | Push → `/rapport` |
| Tap parametre | Bottom sheet configuration |
| Scroll | Vertical naturel |

---

## 5. ECRANS DEDIES — RETRAITE & PREVOYANCE

### 5.1 Trajectoire retraite

- **Nom** : Trajectoire retraite
- **Route** : `/retraite`
- **Intention** : Voir ma situation retraite complete et jouer avec les scenarios
- **Acces** : Pulse hero tap / Coach / Pastille "Retraite"
- **Archetypes** : Tous (adapte selon age)

```
┌──────────────────────────────────────┐
│ ← Trajectoire retraite              │
├──────────────────────────────────────┤
│                                      │
│  ── TON SALAIRE APRES 65 ANS ───    │
│                                      │
│  Aujourd'hui    →    A la retraite   │
│  CHF 8'333          CHF 5'234        │
│  ████████████       ████████         │
│                                      │
│  Tu gardes 63% de ton train de vie   │
│  "Pour la plupart des menages,       │
│   60-70% suffit"                     │
│                                      │
│  ── D'OU VIENT TON ARGENT ──────    │
│                                      │
│  ┌─────────┐  CHF 890   Ton epargne │
│  │ 3a/Libre│  ← Ce que TU as mis    │
│  ├─────────┤                         │
│  │  LPP    │  CHF 2'410 Ta caisse   │
│  │ (2eme)  │  ← Ton patron et toi   │
│  ├─────────┤                         │
│  │  AVS    │  CHF 1'934 L'Etat      │
│  │ (1er)   │  ← Garanti par la      │
│  └─────────┘    Confederation        │
│                                      │
│  ── ET SI JE PARTAIS A... ──────    │
│                                      │
│  58  60  62  63  64  65  66  67  70  │
│  ──🔴───🟡──────🟢──────🔵─────    │
│                ▲                     │
│           [CURSEUR]                  │
│                                      │
│  A 63 ans : CHF 4'510/mois (-14%)   │
│  "Tu perds CHF 724/mois a vie.      │
│   Mais tu gagnes 2 ans de liberte.   │
│   Cout total : ~CHF 174k sur 25 ans"│
│                                      │
│  ── COCKPIT EXPERT ─────────────    │
│  [Deplier ▼]                         │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ Monte Carlo : 72% chance       │  │
│  │ de maintenir ton niveau de vie │  │
│  │                                │  │
│  │ Sensibilite :                  │  │
│  │ Rendement +1% → +CHF 340/mois │  │
│  │ Inflation +1% → -CHF 280/mois │  │
│  │                                │  │
│  │ Hypotheses modifiables :       │  │
│  │ Rendement LPP : [5.0%    ]    │  │
│  │ Inflation :     [1.5%    ]    │  │
│  │ Age retraite :  [65      ]    │  │
│  └────────────────────────────────┘  │
│                                      │
│  ── ACTIONS ─────────────────────    │
│                                      │
│  [Simuler rente vs capital →]       │
│  [Simuler un rachat LPP →]         │
│  [Optimiser le decaissement →]      │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  Confiance : 72% · LAVS art. 21-40  │
│  LPP art. 14-16 · Outil educatif    │
└──────────────────────────────────────┘
```

### 5.2 Rente vs Capital

- **Nom** : Rente vs Capital
- **Route** : `/rente-vs-capital`
- **Intention** : Comparer les 3 options (rente, capital, mixte) pour la retraite
- **Acces** : Coach response / Pulse / Trajectoire retraite
- **Archetypes** : Tous 50+ (contextuel avant)

```
┌──────────────────────────────────────┐
│ ← Rente vs Capital                  │
├──────────────────────────────────────┤
│                                      │
│  ── LE GRAND CHOIX ─────────────    │
│                                      │
│  ┌─────────┬─────────┬──────────┐   │
│  │ Rente   │ Capital │ Mixte    │   │
│  │         │         │ (oblig.+ │   │
│  │         │         │ suroblig)│   │
│  ├─────────┼─────────┼──────────┤   │
│  │CHF 2'830│CHF 2'410│CHF 2'620│   │
│  │ /mois   │ /mois   │ /mois   │   │
│  │         │ (SWR 4%)│          │   │
│  ├─────────┼─────────┼──────────┤   │
│  │Garanti  │Variable │Equilibre│   │
│  │a vie    │mais     │des 2     │   │
│  │         │transmis │          │   │
│  │         │sible    │          │   │
│  └─────────┴─────────┴──────────┘   │
│                                      │
│  ⚖ Pas de classement.              │
│  Les 3 options sont valables.        │
│                                      │
│  ── POINT D'EQUILIBRE ──────────    │
│                                      │
│  [Graphique trajectoires croisees]   │
│                                      │
│  Les courbes se croisent a 82 ans.   │
│  Avant 82 ans : le capital produit   │
│  plus. Apres : la rente l'emporte.   │
│                                      │
│  ── ET SI... ────────────────────    │
│                                      │
│  Rendement capital [──●──────] 4%    │
│  "Si le rendement passe de 4%        │
│   a 3%, le point d'equilibre         │
│   recule a 78 ans."                  │
│                                      │
│  ── FISCALITE ───────────────────    │
│                                      │
│  Rente : imposee chaque annee        │
│  Capital : taxe une seule fois       │
│  (bareme progressif : voir detail)   │
│                                      │
│  ── HYPOTHESES ──────────────────    │
│  [Toutes visibles et modifiables]    │
│                                      │
│  Taux conversion oblig.: [6.8% ]    │
│  Taux conversion surob.: [5.2% ]    │
│  SWR :                   [4.0% ]    │
│  Canton :                [VS   ]    │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  LPP art. 14/37 · LIFD art. 22/38   │
│  Outil educatif · Scenarios simules  │
└──────────────────────────────────────┘
```

### 5.3 Rachat LPP

- **Nom** : Rachat LPP
- **Route** : `/rachat-lpp`
- **Intention** : Simuler l'impact d'un rachat LPP (fiscal + retraite + vs marche)
- **Acces** : Coach / Pulse priorite / Trajectoire retraite

```
┌──────────────────────────────────────┐
│ ← Rachat LPP                        │
├──────────────────────────────────────┤
│                                      │
│  ── CHIFFRE-CHOC ───────────────    │
│                                      │
│  Tu pourrais economiser              │
│  CHF 12'400 d'impot                 │
│  avec un rachat de CHF 50'000        │
│  sur 5 ans.                          │
│                                      │
│  ── AVANT / APRES ──────────────    │
│                                      │
│  ┌───────────┬──────────────────┐   │
│  │  Avant    │  Apres rachat    │   │
│  │  (grise)  │  (couleur)       │   │
│  ├───────────┼──────────────────┤   │
│  │ LPP 70k   │ LPP 120k        │   │
│  │ Rente     │ Rente            │   │
│  │ 2'410/m   │ 2'750/m (+340)  │   │
│  │ Impot     │ Impot            │   │
│  │ 28'500/an │ 26'020/an       │   │
│  └───────────┴──────────────────┘   │
│                                      │
│  ── ECHELONNEMENT ──────────────    │
│                                      │
│  Montant total [─────●───] 50k CHF  │
│  Etaler sur    [──●──────] 5 ans    │
│                                      │
│  Calendrier :                        │
│  2026 : CHF 10'000 → eco. 2'480    │
│  2027 : CHF 10'000 → eco. 2'480    │
│  2028 : CHF 10'000 → eco. 2'480    │
│  2029 : CHF 10'000 → eco. 2'480    │
│  2030 : CHF 10'000 → eco. 2'480    │
│                                      │
│  ── RACHAT VS MARCHE ───────────    │
│  [Section arbitrage integree]        │
│                                      │
│  Rachat LPP    │  Investissement     │
│  +CHF 12.4k    │  +CHF 9.8k         │
│  fiscal         │  rendement         │
│                                      │
│  Breakeven rendement : 5.2%         │
│                                      │
│  ── ATTENTION ───────────────────    │
│                                      │
│  ⚠ Delai de blocage : 3 ans        │
│  (LPP art. 79b al. 3)               │
│  Pas de retrait EPL avant 2029.      │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  LPP art. 79b · LIFD art. 33        │
│  OPP2 · Outil educatif              │
└──────────────────────────────────────┘
```

### 5.4 EPL (retrait anticipe LPP)

- **Nom** : EPL
- **Route** : `/epl`
- **Intention** : Simuler un retrait anticipe du 2e pilier pour achat immobilier
- **Acces** : Coach response / Hypotheque

```
┌──────────────────────────────────────┐
│ ← Retrait anticipe LPP (EPL)        │
├──────────────────────────────────────┤
│                                      │
│  ── CHIFFRE-CHOC ───────────────    │
│                                      │
│  Retirer CHF 20'000 de ton LPP      │
│  reduit ta rente de CHF 113/mois    │
│  a vie.                              │
│                                      │
│  ── SIMULATEUR ─────────────────    │
│                                      │
│  Montant EPL [────●─────] 20'000    │
│  (Min 20'000 · Max 70'377)           │
│                                      │
│  ┌───────────┬──────────────────┐   │
│  │  Avant    │  Apres EPL       │   │
│  ├───────────┼──────────────────┤   │
│  │ LPP 70k   │ LPP 50k         │   │
│  │ Rente     │ Rente            │   │
│  │ 2'410/m   │ 2'297/m (-113)  │   │
│  │ Retraite  │ Retraite         │   │
│  │ projetee  │ projetee         │   │
│  │ 678k      │ 598k             │   │
│  └───────────┴──────────────────┘   │
│                                      │
│  ── REMBOURSEMENT ──────────────    │
│                                      │
│  Obligation de rembourser avant      │
│  la retraite ou la vente du bien.    │
│                                      │
│  Si rembourse en 10 ans :            │
│  CHF 167/mois → rente restauree     │
│                                      │
│  ── FISCALITE ──────────────────    │
│                                      │
│  Impot au retrait : ~CHF 1'600      │
│  (bareme progressif, canton VS)      │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  LPP art. 30c · OPP2 art. 5         │
│  Outil educatif                      │
└──────────────────────────────────────┘
```

### 5.5 Decaissement optimise

- **Nom** : Decaissement optimise
- **Route** : `/decaissement`
- **Intention** : Optimiser le calendrier de retrait (3a, LPP, libre passage)
- **Acces** : Coach / Trajectoire retraite
- **Archetypes** : 55+ principalement

```
┌──────────────────────────────────────┐
│ ← Decaissement optimise              │
├──────────────────────────────────────┤
│                                      │
│  ── CHIFFRE-CHOC ───────────────    │
│                                      │
│  En etalant tes retraits sur 5 ans,  │
│  tu economises CHF 23'000 d'impot.  │
│                                      │
│  ── SCENARIO 1 : TOUT EN 1 AN ──    │
│                                      │
│  2042 : 3a + LPP = CHF 710k         │
│  Impot retrait : CHF 78'000         │
│                                      │
│  ── SCENARIO 2 : ETALE (optimise) ─ │
│                                      │
│  2038 : 3a compte 1  CHF 16k  → 1.3k│
│  2039 : 3a compte 2  CHF 16k  → 1.3k│
│  2040 : Libre passage CHF 45k → 4.2k│
│  2041 : (vide)                       │
│  2042 : LPP capital  CHF 633k → 48k │
│                                      │
│  Impot total : CHF 55'000           │
│  Economie : CHF 23'000 (-29%)       │
│                                      │
│  ── CALENDRIER COUPLE ──────────    │
│  (si conjoint)                       │
│                                      │
│  Julien + Lauren : optimisation      │
│  croisee possible.                   │
│  Retirer en annees differentes       │
│  → economie supplementaire           │
│                                      │
│  ── HYPOTHESES ─────────────────    │
│                                      │
│  Canton :    [VS          ▼]        │
│  Marie(e) :  [Oui         ▼]        │
│  Nb comptes 3a : [2       ]         │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  LIFD art. 38 · OPP3 art. 3         │
│  Outil educatif · Scenarios simules  │
└──────────────────────────────────────┘
```

---

## 6. ECRANS DEDIES — FISCALITE

### 6.1 Pilier 3a

- **Nom** : Pilier 3a
- **Route** : `/pilier-3a`
- **Intention** : Comprendre et optimiser son 3e pilier
- **Acces** : Coach / Pulse / Explore

```
┌──────────────────────────────────────┐
│ ← Pilier 3a                         │
├──────────────────────────────────────┤
│                                      │
│  ── CHIFFRE-CHOC ───────────────    │
│                                      │
│  Tu economises CHF 1'820/an          │
│  en versant le maximum 3a.           │
│  (Taux marginal : 25.1%)            │
│                                      │
│  ── IMPACT FISCAL ──────────────    │
│                                      │
│  Versement max 2026 : CHF 7'258     │
│  Economie impot : CHF 1'822         │
│  = CHF 152/mois en plus             │
│                                      │
│  ┌───────────┬──────────────────┐   │
│  │ Sans 3a   │ Avec 3a max      │   │
│  │ Impot     │ Impot            │   │
│  │ 28'500    │ 26'678 (-1'822)  │   │
│  └───────────┴──────────────────┘   │
│                                      │
│  ── RENDEMENT REEL ─────────────    │
│  [Section integree]                  │
│                                      │
│  Frais de gestion : [0.45%   ]      │
│  Rendement brut :   [4.0%    ]      │
│  Rendement net reel (apres frais    │
│  + inflation) : 2.05%                │
│                                      │
│  ── RETRAIT ECHELONNE ──────────    │
│  [Section integree]                  │
│                                      │
│  Etaler sur 5 ans (des 60 ans)       │
│  → economie impot retrait : ~8k     │
│                                      │
│  ── COMPARATEUR PRESTATAIRES ───    │
│  [Section integree]                  │
│                                      │
│  Banque    │ Frais │ Perf 5a │       │
│  VIAC      │ 0.44% │ +18.2%  │       │
│  Finpension│ 0.39% │ +17.8%  │       │
│  frankly   │ 0.45% │ +16.9%  │       │
│                                      │
│  ⚠ Classes d'actifs uniquement.     │
│  Pas de recommandation de produit.   │
│                                      │
│  ── INDEPENDANTS ───────────────    │
│  (visible si archetype independant)  │
│                                      │
│  Sans LPP : max CHF 36'288/an       │
│  Economie : CHF 9'100/an            │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  OPP3 art. 7 · LIFD art. 33         │
│  Outil educatif                      │
└──────────────────────────────────────┘
```

---

## 7. ECRANS DEDIES — IMMOBILIER

### 7.1 Hypotheque

- **Nom** : Hypotheque
- **Route** : `/hypotheque`
- **Intention** : Evaluer sa capacite d'emprunt et comprendre les couts
- **Acces** : Coach / Pulse

```
┌──────────────────────────────────────┐
│ ← Hypotheque                         │
├──────────────────────────────────────┤
│                                      │
│  ── CHIFFRE-CHOC ───────────────    │
│                                      │
│  Tu peux emprunter jusqu'a           │
│  CHF 580'000                        │
│  (bien de ~725k avec 20% fonds       │
│   propres)                           │
│                                      │
│  ── CAPACITE (Tragbarkeit) ─────    │
│                                      │
│  Prix du bien : [─────●───] 725k    │
│                                      │
│  Charges theoriques :                │
│  Interet 5%  : CHF 2'417/mois       │
│  Amorti 1%   : CHF  483/mois        │
│  Entretien 1%: CHF  483/mois        │
│  TOTAL       : CHF 3'383/mois       │
│                                      │
│  Revenu brut mensuel : CHF 10'184   │
│  Ratio charges/revenu : 33.2%        │
│  [████████████████████████░░░░] 33%  │
│                                      │
│  🟢 Faisable (limite FINMA : 33%)   │
│                                      │
│  ── FONDS PROPRES ──────────────    │
│                                      │
│  Requis (20%) : CHF 145'000         │
│  Dont max 10% du 2e pilier          │
│                                      │
│  ── SECTIONS SUPPLEMENTAIRES ───    │
│                                      │
│  [Amortissement direct vs indirect▼] │
│  [Valeur locative ▼]                │
│  [SARON vs taux fixe ▼]            │
│  [Utiliser mon LPP (EPL) ▼]        │
│                                      │
│  Chaque section se deplie inline     │
│  avec simulateur integre.            │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  FINMA circ. · CO art. 793ss         │
│  Outil educatif                      │
└──────────────────────────────────────┘
```

---

## 8. ECRANS DEDIES — BUDGET & DETTE

### 8.1 Budget / Reste a vivre

- **Nom** : Budget
- **Route** : `/budget`
- **Intention** : Voir sa marge mensuelle et identifier les leviers
- **Acces** : Pulse pastille "Budget" / Coach

```
┌──────────────────────────────────────┐
│ ← Mon budget                         │
├──────────────────────────────────────┤
│                                      │
│  ── CHIFFRE-CHOC ───────────────    │
│                                      │
│  Ta marge mensuelle :                │
│  CHF +890 / mois                    │
│  (apres toutes charges)              │
│                                      │
│  ── WATERFALL ──────────────────    │
│                                      │
│  Salaire net     ████████ 7'800     │
│  - Loyer         ████     -1'800    │
│  - LaMAL         ██       -450      │
│  - Transport     █        -200      │
│  - Alimentation  ███      -1'200    │
│  - Assurances    █        -300      │
│  - 3a            ██       -605      │
│  - Loisirs       ██       -800      │
│  - Divers        █        -555      │
│  = Marge         ██       +890      │
│                                      │
│  ── RULE 50/30/20 ──────────────    │
│                                      │
│  Besoins (50%) : 52% ⚠ leger      │
│  Envies (30%)  : 28% 🟢             │
│  Epargne (20%) : 20% 🟢             │
│                                      │
│  ── CRASH TEST ─────────────────    │
│  [Depliable]                         │
│                                      │
│  Si tu perds ton revenu :            │
│  Reserve : 3.2 mois                  │
│  🟡 Idealement 6 mois               │
│                                      │
│  ── SAFE MODE ──────────────────    │
│  [Visible si dette > 0]             │
│                                      │
│  ⚠ Dette detectee : CHF 15'000     │
│  Priorite : remboursement            │
│  Tous les simulateurs d'optimisation │
│  sont suspendus.                     │
│                                      │
│  [Plan de remboursement →]          │
│  [Ressources d'aide →]             │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  Outil educatif                      │
└──────────────────────────────────────┘
```

---

## 9. ECRANS DEDIES — FAMILLE

### 9.1 Couple — Invitation

- **Nom** : Couple
- **Route** : `/couple/invite`
- **Intention** : Inviter son conjoint et gerer la vue couple
- **Acces** : Moi → Conjoint

```
┌──────────────────────────────────────┐
│ ← Couple                             │
├──────────────────────────────────────┤
│                                      │
│  ── INVITATION ─────────────────    │
│  (si pas de conjoint lie)            │
│                                      │
│  Invite ton/ta partenaire pour       │
│  une vue couple de vos finances.     │
│                                      │
│  Code d'invitation : ABC-123-XYZ    │
│  [Copier] [Partager par message]     │
│                                      │
│  ── OU ─────────────────────────    │
│                                      │
│  [J'ai recu un code ▼]             │
│  [         ]  [Valider]              │
│                                      │
│  ── VUE COUPLE ─────────────────    │
│  (si conjoint lie)                   │
│                                      │
│  ┌──────────────┬───────────────┐   │
│  │   Julien     │    Lauren     │   │
│  │   49 ans     │    43 ans     │   │
│  │   swiss_nat. │    expat_us   │   │
│  │              │               │   │
│  │   LPP 70k   │    LPP 20k    │   │
│  │   3a 32k    │    3a 14k     │   │
│  │   Conf. 72% │    Conf. 38%  │   │
│  └──────────────┴───────────────┘   │
│                                      │
│  AVS couple : CHF 2'500/mois        │
│  (plafond 150% · LAVS art. 35)      │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  Donnees chiffrees sur appareil.     │
│  Seul le code est partage.           │
│  nLPD                                │
└──────────────────────────────────────┘
```

### 9.2 Divorce simulateur

- **Nom** : Divorce
- **Route** : `/divorce`
- **Intention** : Simuler l'impact financier d'un divorce
- **Acces** : Coach (life event) uniquement

```
┌──────────────────────────────────────┐
│ ← Impact financier : Divorce         │
├──────────────────────────────────────┤
│                                      │
│  ── CHIFFRE-CHOC ───────────────    │
│                                      │
│  En cas de divorce, ton revenu       │
│  retraite passe de                   │
│  CHF 5'234 a CHF 3'890/mois        │
│  (-25.7%)                            │
│                                      │
│  ── LE FILM EN 3 ACTES ────────    │
│                                      │
│  Acte 1 : Partage LPP               │
│  Avoir LPP partage 50/50            │
│  Ta part : CHF 35'189               │
│  Impact rente : -CHF 340/mois       │
│                                      │
│  Acte 2 : AVS                        │
│  Splitting des revenus               │
│  Impact rente AVS : -CHF 180/mois   │
│                                      │
│  Acte 3 : Fiscalite                  │
│  Retour bareme celibataire           │
│  Impot : +CHF 3'200/an              │
│                                      │
│  ── REGIME MATRIMONIAL ─────────    │
│                                      │
│  [Participation aux acquets ●]      │
│  [Separation de biens ○]            │
│  [Communaute de biens ○]            │
│                                      │
│  ── ACTIONS ────────────────────    │
│                                      │
│  Consulter un·e specialiste en       │
│  droit matrimonial.                  │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  CC art. 120ss · LPP art. 22        │
│  Outil educatif · Scenario simule    │
└──────────────────────────────────────┘
```

### 9.3 Succession simulateur

- **Nom** : Succession
- **Route** : `/succession`
- **Intention** : Simuler la transmission de patrimoine
- **Acces** : Coach (life event)

```
┌──────────────────────────────────────┐
│ ← Succession & Transmission         │
├──────────────────────────────────────┤
│                                      │
│  ── CHIFFRE-CHOC ───────────────    │
│                                      │
│  Ton patrimoine transmissible :      │
│  CHF 147'000                        │
│  (apres reserves hereditaires)       │
│                                      │
│  ── RESERVES LEGALES ───────────    │
│                                      │
│  [Donut chart]                       │
│                                      │
│  Conjoint : 50% (reserve 25%)       │
│  Enfants  : 50% (reserve 25%)       │
│  Quotite disponible : 50%            │
│                                      │
│  ── IMPOT SUCCESSORAL ──────────    │
│                                      │
│  Canton VS : exonere entre epoux     │
│  Ligne directe : exonere             │
│  Hors famille : 10-40% selon canton  │
│                                      │
│  ── DONATION DE SON VIVANT ─────    │
│                                      │
│  Avantage : reduire la masse         │
│  successorale + voir l'impact        │
│                                      │
│  [Simuler une donation →]           │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  CC art. 457-640 · Outil educatif    │
└──────────────────────────────────────┘
```

---

## 10. ECRANS DEDIES — EMPLOI & STATUT

Pas d'ecran dedie. Tous les simulateurs emploi passent par le coach via Response Cards :
- Premier emploi
- Nouveau job (comparaison)
- Independant (hub + 5 sous-simulateurs)
- Perte d'emploi / Chomage
- Frontalier
- Expat
- Gender gap

Le coach genere une Response Card personnalisee avec les chiffres de l'utilisateur. Si le sujet est complexe (>3 variables), la Response Card propose "Voir detail complet" qui ouvre un bottom sheet plein ecran.

---

## 11. ECRANS DEDIES — ASSURANCE & SANTE

### 11.1 Invalidite gap

- **Nom** : Invalidite
- **Route** : `/invalidite`
- **Intention** : Voir le gap de couverture en cas d'invalidite
- **Acces** : Coach / Pulse (si gap detecte)

```
┌──────────────────────────────────────┐
│ ← Couverture invalidite              │
├──────────────────────────────────────┤
│                                      │
│  ── CHIFFRE-CHOC ───────────────    │
│                                      │
│  En cas d'invalidite totale,         │
│  tu toucherais CHF 4'120/mois       │
│  (vs CHF 7'800 net aujourd'hui)     │
│  Gap : CHF 3'680/mois               │
│                                      │
│  ── DECOMPOSITION ──────────────    │
│                                      │
│  AI (1er pilier) : CHF 2'450/mois   │
│  LPP invalidite  : CHF 1'670/mois   │
│  Assurance prive  : CHF 0            │
│  TOTAL            : CHF 4'120/mois   │
│                                      │
│  ── DELAI DE CARENCE ───────────    │
│                                      │
│  AI : 12 mois minimum               │
│  LPP : selon reglement caisse        │
│  Pendant la carence : employeur      │
│  paie selon echelle cantonale.       │
│                                      │
│  ── INDEPENDANTS ───────────────    │
│  (visible si archetype independant)  │
│                                      │
│  ⚠ Pas de LPP invalidite           │
│  → Gap majeur                        │
│  → IJM (indemnite journaliere)       │
│    fortement recommandee              │
│                                      │
│  ── ASSURANCE INVALIDITE ───────    │
│  [Section integree]                  │
│                                      │
│  Prime estimee pour couvrir le gap : │
│  ~CHF 85/mois                        │
│  (Classes d'actifs, pas de produit)  │
│                                      │
│  ── ACTION ─────────────────────    │
│                                      │
│  Demander un devis a ta caisse       │
│  maladie ou un·e specialiste         │
│  en prevoyance.                      │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  LAI art. 28ss · LPP art. 23        │
│  Outil educatif                      │
└──────────────────────────────────────┘
```

Les autres simulateurs sante (LaMAL franchise, couverture check) passent par le coach via Response Cards.

---

## 12. ECRANS DEDIES — DOCUMENTS

### 12.1 Scanner document

- **Nom** : Scanner
- **Route** : `/scan`
- **Intention** : Scanner et extraire les donnees d'un document financier
- **Acces** : Pulse CTA / Moi / Coach

```
┌──────────────────────────────────────┐
│ ← Scanner un document                │
├──────────────────────────────────────┤
│                                      │
│  ── QUEL DOCUMENT ? ────────────    │
│                                      │
│  ┌──────────────────────────────┐   │
│  │ 📄 Certificat LPP            │   │
│  │    Confiance → +15 points     │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │ 📄 Certificat AVS            │   │
│  │    Confiance → +10 points     │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │ 📄 Declaration fiscale       │   │
│  │    Confiance → +12 points     │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │ 📄 Fiche de salaire          │   │
│  │    Confiance → +8 points      │   │
│  └──────────────────────────────┘   │
│                                      │
│  ── GUIDE ──────────────────────    │
│  (apparait au tap)                   │
│                                      │
│  Ou trouver ton certificat ?         │
│  → Ton employeur t'envoie chaque    │
│    annee un "certificat de           │
│    prevoyance". Cherche dans tes     │
│    courriers de janvier/fevrier.     │
│                                      │
│  [📷 Prendre en photo]              │
│  [📁 Choisir un fichier]            │
│                                      │
│  ── COFFRE-FORT ────────────────    │
│                                      │
│  Documents deja scannes :            │
│  📄 Certificat LPP CPE (12.01.26)  │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  Traitement local sur appareil.      │
│  Aucun document envoye a un serveur. │
│  nLPD                                │
└──────────────────────────────────────┘
```

### 12.2 Review extraction

- **Nom** : Review
- **Route** : `/scan/review`
- **Intention** : Verifier et valider les donnees extraites
- **Acces** : Apres scan

```
┌──────────────────────────────────────┐
│ ← Verification                       │
├──────────────────────────────────────┤
│                                      │
│  Donnees extraites de ton            │
│  certificat LPP :                    │
│                                      │
│  Avoir LPP :     [70'377   ] ✅     │
│  Rachat max :    [539'414  ] ✅     │
│  Taux remun. :   [5.0%     ] ✅     │
│  Caisse :        [CPE      ] ✅     │
│                                      │
│  ── IMPACT SUR TA CONFIANCE ────    │
│                                      │
│  Avant scan :  57%                   │
│  Apres scan :  72% (+15)             │
│  ████████████████████░░░░░░ 72%      │
│                                      │
│  Source : certificat (fiabilite 95%) │
│                                      │
│  ── IMPACT SUR TES PROJECTIONS ─    │
│                                      │
│  Rente LPP : 2'180 → 2'410/mois    │
│  (+CHF 230/mois, source verifiee)    │
│                                      │
│  [Valider et mettre a jour ✓]       │
│  [Corriger une valeur ✏]            │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  Donnees stockees localement.        │
└──────────────────────────────────────┘
```

---

## 13. ECRANS DEDIES — EDUCATION

Pas d'ecran dedie. L'education passe ENTIEREMENT par le coach (tab Mint).

### Comment ca fonctionne

| Question utilisateur | Reponse coach |
|---------------------|---------------|
| "C'est quoi le 2e pilier ?" | Response Card educative avec pile de briques |
| "Comment marche l'AVS ?" | Explication + chiffre personnel (annees, rente) |
| "C'est quoi la valeur locative ?" | Explication + impact fiscal personnel |
| "Le rachat LPP, ca vaut le coup ?" | Education + simulation personnalisee |

### Les 9 themes educatifs (anciennement dans le hub)

Tous migres vers des templates de reponse coach :

| Theme | Declencheur |
|-------|-----------|
| Pilier 3a | "Explique-moi le 3e pilier" |
| LPP (2e pilier) | "C'est quoi le 2e pilier ?" |
| Fiscalite | "Comment reduire mes impots ?" |
| AVS (1er pilier) | "L'AVS, comment ca marche ?" |
| Hypotheque | "Acheter ou louer ?" |
| Assurance | "Suis-je bien assure ?" |
| Succession | "Comment transmettre mon patrimoine ?" |
| Budget | "Comment gerer mon budget ?" |
| Independant | "Se mettre a son compte" |

### Les 18 inserts educatifs

Egalement migres vers le coach comme reponses contextuelles :

| Insert | Quand le coach l'utilise |
|--------|------------------------|
| Credit cost | Discussion sur dette/credit |
| Emergency fund | Budget avec reserve faible |
| Leasing trap | Question sur leasing |
| Mortgage comparison | Discussion hypotheque |
| Tax progressive | Simulation fiscale |
| Compound interest | Epargne long terme |
| Insurance gap | Discussion couverture |
| Retirement pillar | Premiere question retraite |
| Salary breakdown | Premier emploi |
| Unemployment timeline | Perte d'emploi |
| Parental leave | Naissance |
| Marriage penalty | Mariage |
| Divorce splitting | Divorce |
| Property sale tax | Vente immobiliere |
| Donation reserve | Donation |
| Concubinage risk | Concubinage |
| Death urgency | Deces |
| Debt spiral | Crise dette |

---

## 14. LIFE EVENTS — DECLENCHEURS

### Principe

Les 18 life events ne sont PAS des ecrans. Ce sont des **declencheurs de profil** qui reconfigurent Pulse et le coach.

### Mecanisme

1. L'utilisateur declare un life event (via Moi → "Il m'arrive quelque chose" ou via le coach)
2. Le profil est mis a jour (situation familiale, statut, etc.)
3. Pulse se reconfigure : nouveau hero, nouvelles priorites, nouvelles alertes
4. Le coach genere proactivement un message avec l'impact estime

### Les 18 life events et leur effet

| Life event | Declencheur | Effet sur Pulse | Effet sur coach |
|-----------|------------|-----------------|-----------------|
| `marriage` | "Je me marie" | Hero couple, AVS cap, fiscalite | Impact fiscal + LPP + AVS |
| `divorce` | "Je divorce" | Hero solo, alerte LPP splitting | Push → ecran dedie `/divorce` |
| `birth` | "J'attends un enfant" | Alerte budget, crash test | Conge parental + allocations |
| `concubinage` | "On vit ensemble" | Alerte protection, pas de AVS cap | Risques concubinage |
| `deathOfRelative` | "J'ai perdu un proche" | Succession urgente | Push → ecran `/succession` |
| `firstJob` | "Premier emploi" | Hero 3a, education piliers | Fiche de paie expliquee |
| `newJob` | "Je change d'emploi" | Alerte libre passage | Comparaison offres |
| `selfEmployment` | "Independant" | Hero gap retraite, IJM | Hub independant complet |
| `jobLoss` | "Perte d'emploi" | Alerte chomage, crash test | Droits, duree, montants |
| `retirement` | "Je prends ma retraite" | Hero decaissement | Calendrier retraits |
| `housingPurchase` | "J'achete" | Hero hypotheque | Push → `/hypotheque` |
| `housingSale` | "Je vends" | Gain/perte, reinvestir | Impact fiscal vente |
| `inheritance` | "J'herite" | Patrimoine mis a jour | Fiscalite succession |
| `donation` | "Je donne" | Patrimoine mis a jour | Reserve hereditaire |
| `disability` | "Invalidite" | Hero gap AI | Push → `/invalidite` |
| `cantonMove` | "Je demenage" | Fiscalite recalculee | Comparateur cantonal |
| `countryMove` | "Je pars/reviens" | Archetype recalcule | Impact sur piliers |
| `debtCrisis` | "J'ai des dettes" | SAFE MODE active | Priorite remboursement |

### Implementation : Bottom sheet declaration

Depuis Moi ou le coach, l'utilisateur peut declarer un life event :

```
┌──────────────────────────────────────┐
│  Il m'arrive quelque chose...        │
│                                      │
│  💍 Je me marie                      │
│  👶 J'attends un enfant              │
│  🏠 J'achete un bien                 │
│  💼 Je change d'emploi               │
│  🚀 Je me mets a mon compte          │
│  🏖 Je prends ma retraite            │
│  📦 Je demenage (canton)             │
│  ✈ Je quitte / reviens en Suisse    │
│  ⚠ J'ai des dettes                  │
│  ... [Voir tout (18)]               │
│                                      │
└──────────────────────────────────────┘
```

---

## 15. ONBOARDING — FLOW INLINE

### Principe

Pas d'ecran d'onboarding separe. Pulse s'affiche avec un etat vide et 3 champs inline.

### Flow complet

```
Etape 1 : App ouverte → Pulse etat vide → 3 questions
Etape 2 : Reponses → "Decouvrir mon apercu" → Chiffre-choc anime
Etape 3 : Pulse se remplit (hero + pastilles + score)
Etape 4 : CTA "Scanner un document" (enrichir)
Etape 5 : Utilisation normale
```

### Chiffre-choc (apres les 3 questions)

```
┌──────────────────────────────────────┐
│                                      │
│  A la retraite, ton revenu           │
│  mensuel estime serait de            │
│                                      │
│       CHF 3'420 / mois              │
│                                      │
│  Aujourd'hui, tu depenses            │
│  probablement autour de              │
│  CHF 5'800 / mois.                  │
│                                      │
│  ─────────────────────               │
│  Estimation basee sur 3 informations.│
│  Plus tu precises, plus c'est fiable.│
│                                      │
│  [Qu'est-ce que je peux faire ?]     │
│  [Affiner mon profil ↓]             │
│                                      │
│  Confiance : ███░░░░░░░ 28%         │
│                                      │
└──────────────────────────────────────┘
```

### Enrichissement progressif

Apres le premier apercu, chaque nouvelle donnee recalcule en temps reel :

| Rond | Questions | Impact confiance |
|------|-----------|-----------------|
| 1 (obligatoire) | Age, salaire, canton | 25-30% |
| 2 (optionnel) | Situation familiale, epargne, proprio/locataire | +15-20% |
| 3 (optionnel) | 3a existant, type LPP, dettes | +10-15% |
| Scan | Certificat LPP | +15-20% |
| Scan | Declaration fiscale | +10-15% |

---

## 16. SAFE MODE — COMPORTEMENT DETTE

### Declencheur

Active quand `dette > 0` ET `dette / revenu_net > 0.30` (ratio critique).

### Comportement

| Element | Normal | Safe Mode |
|---------|--------|-----------|
| Pulse hero | Revenu retraite | Marge de survie mensuelle |
| Pulse priorite | Rachat LPP / 3a | Plan de remboursement |
| Coach suggestions | Optimisation | Reduction dette |
| Simulateurs 3a, LPP, rachat | Actifs | Desactives |
| Budget | Normal | Accent sur coupes possibles |
| Ton | Encourageant | Direct, protecteur |

### Wireframe Pulse Safe Mode

```
┌──────────────────────────────────────┐
│ PULSE                          ⚠    │
├──────────────────────────────────────┤
│                                      │
│  ── TA PRIORITE ────────────────    │
│                                      │
│  Rembourser ta dette de              │
│  CHF 15'000                         │
│                                      │
│  Avec ta marge actuelle (CHF 890),   │
│  tu peux etre libre de dettes        │
│  dans ~17 mois.                      │
│                                      │
│  ── TON BUDGET ─────────────────    │
│                                      │
│  Marge mensuelle : CHF 890           │
│  Dont remboursement : CHF 500        │
│  Reste libre : CHF 390               │
│                                      │
│  [Ajuster mon plan →]              │
│                                      │
│  ── RESSOURCES ─────────────────    │
│                                      │
│  📞 Caritas Valais : 027 321 12 34  │
│  📞 Budget-conseil : 0848 300 300   │
│  📄 Guide anti-endettement           │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  La priorite est de retrouver       │
│  une marge de manoeuvre.              │
│  Outil educatif                      │
└──────────────────────────────────────┘
```

---

## 17. CARTE DE NAVIGATION COMPLETE

### Arbre de navigation (tous les chemins)

```
/ (Landing)
├── /auth (Magic link)
└── /home (Shell 3 tabs)
    ├── Tab 0: Pulse
    │   ├── [Hero tap] → /retraite
    │   ├── [Priorite tap] → /rachat-lpp | /pilier-3a | /budget | /invalidite
    │   ├── [Pastille Retraite] → /retraite
    │   ├── [Pastille Budget] → /budget
    │   ├── [Pastille Patrimoine] → Tab Moi (scroll patrimoine)
    │   ├── [Scanner CTA] → /scan
    │   └── [Couple switch] → Toggle solo/duo
    │
    ├── Tab 1: Mint (Coach)
    │   ├── [Suggestion tap] → Message pre-rempli → Response Card
    │   ├── [Response Card "Voir detail"] → /retraite | /rente-vs-capital | /rachat-lpp | /epl | /pilier-3a | /hypotheque | /decaissement | /invalidite | /divorce | /succession
    │   ├── [Response Card "Modifier hypotheses"] → Bottom sheet
    │   ├── [Recherche] → Filtre instantane
    │   └── [33+ simulateurs] → Response Cards inline (pas de push)
    │
    ├── Tab 2: Moi
    │   ├── [Modifier identite] → Bottom sheet
    │   ├── [Modifier patrimoine] → Bottom sheet
    │   ├── [Inviter conjoint] → /couple/invite
    │   ├── [Scanner] → /scan
    │   ├── [Voir coffre] → Liste documents inline
    │   ├── [Exporter rapport] → /rapport
    │   ├── [Parametres] → Bottom sheets
    │   └── [Life event] → Bottom sheet → reconfigure Pulse
    │
    └── Ecrans dedies (push depuis n'importe quel tab)
        ├── /retraite
        │   ├── [Rente vs Capital] → /rente-vs-capital
        │   ├── [Rachat LPP] → /rachat-lpp
        │   └── [Decaissement] → /decaissement
        ├── /rente-vs-capital
        ├── /rachat-lpp
        ├── /epl
        ├── /budget
        ├── /pilier-3a
        ├── /hypotheque
        │   └── [EPL] → /epl
        ├── /decaissement
        ├── /scan
        │   └── /scan/review
        ├── /couple/invite
        ├── /rapport
        ├── /invalidite
        ├── /divorce
        └── /succession
```

### Matrice d'accessibilite (taps depuis tab bar)

| Contenu | Depuis Pulse | Depuis Mint | Depuis Moi |
|---------|-------------|------------|-----------|
| Trajectoire retraite | 1 tap (hero) | 1 tap (suggestion) | 2 taps (via Pulse) |
| Rente vs Capital | 2 taps (hero → action) | 1 tap (question) | 2 taps |
| Rachat LPP | 1 tap (priorite) | 1 tap (question) | 2 taps |
| EPL | 2 taps (via hypotheque) | 1 tap (question) | 2 taps |
| Budget | 1 tap (pastille) | 1 tap (question) | 2 taps |
| Pilier 3a | 1-2 taps (priorite) | 1 tap (question) | 2 taps |
| Hypotheque | 2 taps | 1 tap (question) | 2 taps |
| Decaissement | 2 taps | 1 tap (question) | 2 taps |
| Scanner | 1 tap (CTA) | 2 taps | 1 tap |
| Couple | 2 taps (via Moi) | 2 taps | 1 tap |
| Rapport | 2 taps (via Moi) | 2 taps | 1 tap |
| Invalidite | 1-2 taps | 1 tap (question) | 2 taps |
| Divorce | 2 taps (via coach) | 1 tap (life event) | 2 taps |
| Succession | 2 taps (via coach) | 1 tap (life event) | 2 taps |
| N'importe quel simulateur | 2-3 taps | **1-2 taps** | 2-3 taps |

**Resultat** : Maximum 3 taps pour n'importe quoi. Le coach est le chemin le plus court.

---

## 18. INVENTAIRE COMPLET DES SIMULATEURS

Verification exhaustive : TOUS les simulateurs existants + leur nouveau chemin d'acces.

### Prevoyance & Retraite (12)

| # | Simulateur | Route actuelle | Nouveau chemin | Type |
|---|-----------|---------------|---------------|------|
| 1 | Trajectoire retraite | `/retirement` | `/retraite` | Ecran dedie |
| 2 | Rente vs Capital | `/arbitrage/rente-vs-capital` | `/rente-vs-capital` | Ecran dedie |
| 3 | Rachat LPP echelonne | `/lpp-deep/rachat` | `/rachat-lpp` | Ecran dedie |
| 4 | Rachat vs Marche | `/arbitrage/rachat-vs-marche` | `/rachat-lpp` (section) | Section integree |
| 5 | EPL retrait anticipe | `/lpp-deep/epl` | `/epl` | Ecran dedie |
| 6 | Libre passage | `/lpp-deep/libre-passage` | Coach Response Card | Inline coach |
| 7 | Decaissement optimise | `/coach/decaissement` | `/decaissement` | Ecran dedie |
| 8 | Calendrier retraits | `/arbitrage/calendrier-retraits` | `/decaissement` (section) | Section integree |
| 9 | Allocation annuelle | `/arbitrage/allocation-annuelle` | Coach Response Card | Inline coach |
| 10 | Simulateur 3a | `/simulator/3a` | `/pilier-3a` | Ecran dedie |
| 11 | Rendement reel 3a | `/3a-deep/real-return` | `/pilier-3a` (section) | Section integree |
| 12 | Retrait echelonne 3a | `/3a-deep/staggered-withdrawal` | `/pilier-3a` (section) | Section integree |

### Fiscalite (3)

| # | Simulateur | Route actuelle | Nouveau chemin | Type |
|---|-----------|---------------|---------------|------|
| 13 | Comparateur 3a prestataires | `/3a-deep/comparator` | `/pilier-3a` (section) | Section integree |
| 14 | Comparateur fiscal cantonal | `/fiscal` | Coach Response Card | Inline coach |
| 15 | Bilan arbitrage | `/arbitrage/bilan` | Coach Response Card | Inline coach |

### Immobilier (6)

| # | Simulateur | Route actuelle | Nouveau chemin | Type |
|---|-----------|---------------|---------------|------|
| 16 | Capacite hypothecaire | `/mortgage/affordability` | `/hypotheque` | Ecran dedie |
| 17 | Amortissement | `/mortgage/amortization` | `/hypotheque` (section) | Section integree |
| 18 | EPL combine | `/mortgage/epl-combined` | `/hypotheque` (section) | Section integree |
| 19 | Valeur locative | `/mortgage/imputed-rental` | `/hypotheque` (section) | Section integree |
| 20 | SARON vs fixe | `/mortgage/saron-vs-fixed` | `/hypotheque` (section) | Section integree |
| 21 | Location vs Propriete | `/arbitrage/location-vs-propriete` | Coach Response Card | Inline coach |

### Budget & Dette (4)

| # | Simulateur | Route actuelle | Nouveau chemin | Type |
|---|-----------|---------------|---------------|------|
| 22 | Budget / Reste a vivre | `/budget` | `/budget` | Ecran dedie |
| 23 | Ratio endettement | `/debt/ratio` | `/budget` (section) | Section integree |
| 24 | Plan remboursement | `/debt/repayment` | `/budget` (Safe Mode) | Section integree |
| 25 | Ressources aide | `/debt/help` | `/budget` (Safe Mode) | Section integree |

### Famille (7)

| # | Simulateur | Route actuelle | Nouveau chemin | Type |
|---|-----------|---------------|---------------|------|
| 26 | Divorce | `/life-event/divorce` | `/divorce` | Ecran dedie |
| 27 | Succession | `/life-event/succession` | `/succession` | Ecran dedie |
| 28 | Mariage impact | `/mariage` | Coach Response Card | Inline coach |
| 29 | Naissance impact | `/naissance` | Coach Response Card | Inline coach |
| 30 | Concubinage | `/concubinage` | Coach Response Card | Inline coach |
| 31 | Donation | `/life-event/donation` | Coach Response Card | Inline coach |
| 32 | Vente immobiliere | `/life-event/housing-sale` | Coach Response Card | Inline coach |

### Emploi (7)

| # | Simulateur | Route actuelle | Nouveau chemin | Type |
|---|-----------|---------------|---------------|------|
| 33 | Hub independant | `/segments/independant` | Coach Response Card | Inline coach |
| 34 | AVS cotisations indep | `/independants/avs` | Coach Response Card | Inline coach |
| 35 | IJM | `/independants/ijm` | Coach Response Card | Inline coach |
| 36 | 3a elargi indep | `/independants/3a` | Coach Response Card | Inline coach |
| 37 | Dividende vs Salaire | `/independants/dividende-salaire` | Coach Response Card | Inline coach |
| 38 | LPP volontaire | `/independants/lpp-volontaire` | Coach Response Card | Inline coach |
| 39 | Comparaison job | `/simulator/job-comparison` | Coach Response Card | Inline coach |

### Segments & Statut (4)

| # | Simulateur | Route actuelle | Nouveau chemin | Type |
|---|-----------|---------------|---------------|------|
| 40 | Frontalier | `/segments/frontalier` | Coach Response Card | Inline coach |
| 41 | Expat | `/expatriation` | Coach Response Card | Inline coach |
| 42 | Gender gap | `/segments/gender-gap` | Coach Response Card | Inline coach |
| 43 | Chomage | `/unemployment` | Coach Response Card | Inline coach |

### Assurance & Sante (4)

| # | Simulateur | Route actuelle | Nouveau chemin | Type |
|---|-----------|---------------|---------------|------|
| 44 | Invalidite gap | `/disability/gap` | `/invalidite` | Ecran dedie |
| 45 | Assurance invalidite | `/disability/insurance` | `/invalidite` (section) | Section integree |
| 46 | Invalidite independant | `/disability/self-employed` | `/invalidite` (section) | Section integree |
| 47 | LaMAL franchise | `/assurances/lamal` | Coach Response Card | Inline coach |
| 48 | Couverture check | `/assurances/coverage` | Coach Response Card | Inline coach |

### Utilitaires (4)

| # | Simulateur | Route actuelle | Nouveau chemin | Type |
|---|-----------|---------------|---------------|------|
| 49 | Interet compose | `/simulator/compound` | Coach Response Card | Inline coach |
| 50 | Leasing | `/simulator/leasing` | Coach Response Card | Inline coach |
| 51 | Credit consommation | `/simulator/credit` | Coach Response Card | Inline coach |
| 52 | Premier emploi | `/first-job` | Coach Response Card | Inline coach |

### Recapitulatif

| Categorie | Total | Ecrans dedies | Sections integrees | Coach Response Cards |
|-----------|-------|--------------|-------------------|---------------------|
| Prevoyance | 12 | 6 | 4 | 2 |
| Fiscalite | 3 | 0 | 1 | 2 |
| Immobilier | 6 | 1 | 4 | 1 |
| Budget | 4 | 1 | 3 | 0 |
| Famille | 7 | 2 | 0 | 5 |
| Emploi | 7 | 0 | 0 | 7 |
| Segments | 4 | 0 | 0 | 4 |
| Assurance | 5 | 1 | 2 | 2 |
| Utilitaires | 4 | 0 | 0 | 4 |
| **TOTAL** | **52** | **11** | **14** | **27** |

**52 simulateurs, 0 supprime. 11 ecrans dedies + 14 sections integrees + 27 via coach.**

---

## 19. PLAN DE MIGRATION

### Phase 1 — Restructurer le shell (1 sprint)

**Objectif** : Passer de 4 tabs a 3 tabs, creer le nouveau Pulse.

| Tache | Fichiers concernes |
|-------|-------------------|
| Modifier `MainNavigationShell` : 3 tabs | `main_navigation_shell.dart` |
| Remplacer `ExploreTab` par coach initial | `explore_tab.dart` → supprime |
| Remplacer `CoachAgirScreen` tab par Pulse enrichi | `coach_agir_screen.dart` |
| Creer nouveau Pulse V4 (hero + priorite + pastilles + FRI + enrichir) | `pulse_screen.dart` |
| Creer coach initial (suggestions + recherche) | Nouveau widget dans `coach_chat_screen.dart` |
| Deplacer profil en tab 2 (sans changement) | `profile_screen.dart` |

### Phase 2 — Simplifier le routing (1 sprint)

**Objectif** : Reduire `app.dart` de 97 routes a 19.

| Tache | Detail |
|-------|--------|
| Supprimer toutes les redirections legacy (11) | `app.dart` |
| Supprimer les routes des ecrans migres vers coach | `app.dart` |
| Renommer les routes restantes | Voir tableau section 1 |
| Supprimer les feature flags | `feature_flags.dart` |
| Verifier 0 orphelins (chaque route a un chemin d'acces) | Tests |

### Phase 3 — Coach Response Cards (1 sprint)

**Objectif** : Integrer les 27 simulateurs inline dans le coach.

| Tache | Detail |
|-------|--------|
| Creer `ResponseCardWidget` generique | Nouveau widget |
| Creer templates pour les 27 simulateurs | `response_card_templates/` |
| Integrer les inserts educatifs (18) comme templates | `education_templates/` |
| Fallback sans LLM (templates statiques) | Deja partiellement implemente |
| Life events comme declencheurs (bottom sheet) | Nouveau widget |

### Phase 4 — Ecrans dedies consolides (1 sprint)

**Objectif** : Consolider les ecrans dedies (sections depliables).

| Tache | Detail |
|-------|--------|
| `/retraite` : integrer cockpit + slider + pile | Merge 3 ecrans |
| `/rachat-lpp` : integrer rachat vs marche | Merge 2 ecrans |
| `/pilier-3a` : integrer comparateur + rendement + retrait | Merge 4 ecrans |
| `/hypotheque` : integrer amortissement + SARON + valeur locative + EPL | Merge 5 ecrans |
| `/budget` : integrer Safe Mode (ratio + remboursement + aide) | Merge 4 ecrans |
| `/invalidite` : integrer assurance + independant | Merge 3 ecrans |
| `/decaissement` : integrer calendrier retraits | Merge 2 ecrans |

### Phase 5 — Polish (1 sprint)

| Tache | Detail |
|-------|--------|
| Auth magic link (1 ecran vs 4) | Simplifier auth |
| Onboarding inline dans Pulse | Supprimer ecrans onboarding |
| Safe Mode complet | Tester avec profil endette |
| Couple switch | Toggle solo/duo dans Pulse |
| Suppression code mort (~40 fichiers) | Screens + widgets obsoletes |
| Tests end-to-end des 5 journeys | Smoke tests |
| `flutter analyze` = 0 | Verification |

### Fichiers a supprimer (estimation)

| Categorie | Fichiers | Raison |
|-----------|---------|--------|
| Screens supprimees | ~30 fichiers `.dart` | Migres vers coach ou consolides |
| `explore_tab.dart` | 1 | Remplace par coach |
| `tools_library_screen.dart` | 1 | Tout via coach |
| 4 auth screens → 1 | 3 fichiers | Magic link |
| 3 onboarding screens → 0 | 3 fichiers | Inline Pulse |
| Widgets orphelins | ~10 fichiers | Plus de parent |

### Risques et mitigations

| Risque | Mitigation |
|--------|-----------|
| Coach offline = pas d'acces aux 27 simulateurs | Templates fallback statiques (fonctionnent sans LLM) |
| Perte de discoverabilite (pas de liste complete) | Recherche dans le coach + suggestions contextuelles |
| Regression lors de la consolidation d'ecrans | Tests unitaires existants + golden tests |
| Utilisateurs habitudes aux 4 tabs | Changement une seule fois, communication in-app |

---

## ANNEXE A — Score final de l'architecture

| Critere | Score | Max | Notes |
|---------|-------|-----|-------|
| **H1 Lisibilite** | 10 | 10 | 1 ecran = 1 intention |
| **H2 Progression** | 10 | 10 | Cercles via confiance progressive |
| **H3 Contextualite** | 10 | 10 | Archetype masque radicale |
| **H4 Transparence** | 5 | 5 | Sources + hypotheses partout |
| **H5 Education** | 9 | 10 | Via coach (fallback templates) |
| **H6 Couple** | 5 | 5 | Natif dans Pulse |
| **H7 Sobriete** | 10 | 10 | 16 ecrans |
| Taps to action | 12 | 12 | Max 3 taps |
| Navigation depth | 8 | 8 | Max 2 niveaux |
| Zero orphans | 4 | 4 | Tous accessibles |
| Zero duplicates | 2 | 2 | 1 route = 1 ecran |
| Tab balance | 2 | 2 | 3 tabs equilibres |
| Anti-overwhelm | 6 | 6 | Coach = decouverte progressive |
| Bienveillance | 6 | 6 | Ton protecteur, Safe Mode |
| **TOTAL** | **95** | **100** | |

---

## ANNEXE B — User Journey Maps

**Journey 1 : Nouvel utilisateur**
```
App → Pulse (vide) → 3 questions → Chiffre-choc anime → Pulse rempli → "Scanne ton LPP" → Scan → Review → Pulse (28% → 72%)
```

**Journey 2 : Check-in mensuel**
```
Notification → Pulse → Score mis a jour → Nouvelle priorite → Coach: "Ce mois-ci..." → Action
```

**Journey 3 : Life event (mariage)**
```
Moi → "Il m'arrive quelque chose" → Mariage → Profil mis a jour → Pulse reconfigure (hero couple) → Coach proactif
```

**Journey 4 : Simulation avancee**
```
Coach: "Montre-moi rente vs capital" → Response Card inline → "Voir detail" → Ecran dedie → Modifier hypotheses → Retour
```

**Journey 5 : Couple**
```
Pulse → [Solo|Duo] → Score couple → Alerte ecart → "Inviter Lauren" → Lauren scanne → Vue couple mise a jour
```

**Journey 6 : Safe Mode (endette)**
```
Profil avec dette → Pulse Safe Mode → Budget + aide → Pas de simulateur optimisation → Coach mode dette → Remboursement → Dette a 0 → Mode normal restaure
```

**Journey 7 : Independant**
```
Coach: "Je me mets a mon compte" → Response Cards : AVS, IJM, 3a elargi, LPP volontaire → "C'est quoi l'IJM ?" → Education inline → Action
```

---

*Document genere le 2026-03-15 — Architecture MINT V1*
*Score autoresearch : 95/100 (20 iterations)*
*52 simulateurs, 0 supprime, 16 ecrans, 3 onglets*
