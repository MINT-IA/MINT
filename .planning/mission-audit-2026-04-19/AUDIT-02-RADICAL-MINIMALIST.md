# AUDIT-02 — RADICAL MINIMALIST

> Lens : ex-Aesop / ex-Teenage Engineering. Un produit existe s'il tient en 3 objets irréductibles. Le reste est du gras ou un bug taxonomique.
> Mission testée : **lucidité financière**. Un produit qui promet la lucidité avec 97 écrans ne l'incarne pas — il la contredit.

---

## 1. Comptage réel (2026-04-19, branche `feature/wave-c-scan-handoff-coach`)

| Objet | Commande | Résultat |
|---|---|---|
| Écrans `.dart` | `find apps/mobile/lib/screens -name "*.dart" \| wc -l` | **97** |
| Dossiers d'écrans top-level | `ls apps/mobile/lib/screens/ \| wc -l` | **57** |
| Services mobiles | `find apps/mobile/lib/services -name "*.dart" \| wc -l` | **198** |
| Widgets | `find apps/mobile/lib/widgets -name "*.dart" \| wc -l` | **286** |
| Modèles | `find apps/mobile/lib/models -name "*.dart" \| wc -l` | **28** |
| Providers | `find apps/mobile/lib/providers -name "*.dart" \| wc -l` | **15** |
| Fichiers endpoints backend | `ls services/backend/app/api/v1/endpoints/ \| wc -l` | **59** |
| Routes backend (`@router.*`) | `grep -rE "@router\.(get\|post\|put\|patch\|delete)" services/backend/app/api/` | **218** |
| Calculateurs `financial_core` | `ls .../financial_core/ \| wc -l` | **17** |
| Tabs actuels | `home_shell` inspect | **3 tabs + drawer + contextual sheet** (Aujourd'hui, Coach, Explorer + ProfileDrawer + Capture) |

**Verdict brut** : 97 écrans pour 18 life events = **~5,4 écrans par événement de vie**. C'est un catalogue, pas un compagnon.

---

## 2. Les 3 objets irréductibles de MINT

Si on enlève l'un, la mission meurt. Si on en ajoute un quatrième, la mission se dilue.

### OBJET 1 — **Le Dossier** (la vérité)
La représentation unique et canonique de la situation financière de l'utilisateur : revenus, LPP, 3a, dettes, logement, famille, canton, archétype, confidence. **Remplace** : `mon_argent_screen`, `financial_summary_screen`, `confidence_dashboard_screen`, `documents_screen`, `portfolio_screen`, `privacy_control_screen`, `data_block_enrichment_screen`. **Irréductible car** : sans dossier, MINT n'a rien à éclairer. Le Dossier EST la lucidité matérialisée.

### OBJET 2 — **Le Coach** (la traduction)
Le moteur 4-couches (extraction → traduction → perspective → questions à poser) exposé comme conversation + scan. Le coach lit le Dossier, prend un document ou une question, et produit un éclairage. **Remplace** : `coach_chat_screen`, `ask_mint_screen`, `document_scan_screen`, `extraction_review_screen`, `document_impact_screen`, `annual_refresh_screen`, tous les `_screen.dart` de type "comparator/simulator" qui sont en réalité des dialogues déguisés. **Irréductible car** : un Dossier sans traducteur = un tableur. MINT n'est pas un tableur.

### OBJET 3 — **L'Action** (le prochain geste)
L'unique écran qui, à tout instant, répond à « qu'est-ce qui compte maintenant ? » : 1 à 3 prochains gestes concrets, nommés, datés, dérivés du Dossier × Coach. **Remplace** : `aujourdhui_screen`, `timeline_screen`, `explore_hub_screen`, `explorer_screen`, `comprendre_hub_screen`, `achievements_screen`, `cantonal_benchmark_screen`, `gender_gap_screen`. **Irréductible car** : sans geste, la lucidité est stérile (principe 4 de MINT_IDENTITY : « prise immédiate »).

> **Test Aesop** : Dossier / Coach / Action. Trois noms communs. Zéro jargon. Un enfant de 10 ans les nomme ; un senior de 72 ans les utilise.

---

## 3. Ce qui peut disparaître sans toucher la mission

**Tabs/hubs redondants (1 suffit)** : `explore/explore_hub_screen.dart`, `explore/explorer_screen.dart`, `education/comprendre_hub_screen.dart`, `open_banking/open_banking_hub_screen.dart`, `mon_argent/mon_argent_screen.dart`. Cinq surfaces pour un seul concept : « naviguer dans ce que MINT sait ». → c'est le Dossier.

**Screens « life-event » dédiés (18 pages = 18 formulaires)** : `mariage_screen`, `naissance_screen`, `divorce_simulator_screen`, `deces_proche_screen`, `demenagement_cantonal_screen`, `expat_screen`, `frontalier_screen`, `first_job_screen`, `unemployment_screen`, `concubinage_screen`, `donation_screen`, `housing_sale_screen`, `independant_screen`, `gender_gap_screen`. → tous fusionnables dans Coach (conversation déclenche le contexte, pas un screen).

**Simulateurs isolés** : `simulator_3a_screen`, `simulator_compound_screen`, `simulator_leasing_screen`, `consumer_credit_screen`, `job_comparison_screen`, `fiscal_comparator_screen`, `divorce_simulator_screen`. → ces 7 sont des **dialogues déguisés en formulaires**. Coach les absorbe.

**Arbitrage + lpp_deep + 3a_deep (10 écrans techniques)** : `arbitrage/*` (4), `lpp_deep/*` (3), `pillar_3a_deep/*` (4). → taxonomie dev-centric explicitement bannie par CLAUDE.md §7. À tuer en tant qu'écrans ; garder en tant que **capacités** appelées par Coach.

**Admin/settings/legal/auth (13 écrans)** : `admin_*` (2), `settings/langue`, `byok_settings`, `slm_settings`, `about_screen`, `auth/*` (3), `landing_screen`, `household/*` (3), `privacy_*` (2). → à reléguer dans un **drawer système** hors des 3 objets (chrome, pas produit).

**Total dégraissable : ~70 des 97 écrans.** Reste ≈ 27 écrans utiles, regroupables en 3 surfaces.

---

## 4. Fusions radicales

| Fusion | Rationale |
|---|---|
| `mon_argent` + `financial_summary` + `confidence_dashboard` + `documents` + `portfolio` + `data_block_enrichment` → **Dossier** | Tous montrent la même vérité sous 6 angles. Le Dossier est UNE vue avec des zooms contextuels, pas 6 écrans. |
| `coach_chat` + `ask_mint` + `conversation_history` + `document_scan` + `extraction_review` + `annual_refresh` + `cockpit_detail` + 7 simulateurs + 14 life-event screens → **Coach** | Un seul fil conversationnel avec slots typés (scan, chiffre, comparaison, life event). Pas 28 écrans pour la même mécanique. |
| `aujourdhui` + `timeline` + `explorer` + `explore_hub` + `comprendre_hub` + `achievements` + `cantonal_benchmark` → **Action** | Tous essayent de répondre « et maintenant ? ». Un seul écran répond. |
| 3 privacy screens → **1 section Dossier** | L'utilisateur voit et édite ce que MINT sait au même endroit où il le consulte. |
| 4 arbitrage + 3 lpp_deep + 4 3a_deep → **11 capacités Coach** | Pas des destinations. Des outils invoqués. |

---

## 5. Architecture « MINT en 3 objets »

```
┌─────────────────────────────────────────────────────┐
│  [Dossier]    [Coach]    [Action]                   │  ← 3 tabs. Point.
│                                                      │
│  (⚙ drawer système : compte, langue, BYOK, légal)   │  ← hors produit
└─────────────────────────────────────────────────────┘
```

- **Dossier** : vérité éditable, confidence par bloc, scan déclenché depuis un bloc vide, succession/famille/patrimoine comme sections zoomables — PAS comme onglets.
- **Coach** : conversation + scan + comparaison side-by-side, capable d'invoquer n'importe quel calculateur du `financial_core` (17 calculateurs, 218 routes backend = la **puissance**, pas la surface).
- **Action** : 1 à 3 prochains gestes, chacun rattaché à un bloc du Dossier ou un fil Coach. Une seule question par jour : « qu'est-ce qui compte ? ».

Suppression de Aujourd'hui+Explorer+MonArgent au profit de Dossier+Coach+Action inverse la logique : **le produit n'est plus un catalogue navigable, c'est une vérité conversée qui produit des gestes.**

---

## 6. Risque de ne PAS compresser

Si MINT reste à 97 écrans + 4 surfaces concurrentes (Aujourd'hui/MonArgent/Coach/Explorer) :

1. **Contradiction de mission** : promettre la lucidité avec un catalogue de 97 écrans = mentir par l'architecture. Le médium contredit le message.
2. **User perdu** : les données comportementales le montrent déjà (panels Wave C en cours). 4 tabs qui se recouvrent créent la paralysie, pas la clarté.
3. **Coût maintenance** : 198 services + 286 widgets + 218 routes maintenus pour exposer la même chose plusieurs fois. Chaque fix doit être propagé 3-5×.
4. **Impossibilité du toilet test** (MINT_IDENTITY §5) : « utilisable en 20s, compréhensible à moitié fatigué ». Un utilisateur fatigué devant 4 tabs + drawer + FAB + 57 dossiers d'écrans ne passe pas le test.
5. **Dilution du positionnement** : MINT devient « encore une app fintech ». Les 3 objets le sortent du lot — un Dossier qui parle, ça n'existe pas ailleurs.

**Conclusion chirurgicale** : garder 3 objets, tuer 70 écrans, promouvoir 11 capacités en outils Coach. La mission lucidité exige que l'architecture elle-même soit lucide.