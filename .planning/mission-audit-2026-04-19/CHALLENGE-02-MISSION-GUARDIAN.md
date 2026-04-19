# CHALLENGE-02 — Mission Guardian

Date : 2026-04-19 • Gardien : MINT_IDENTITY.md + pivot lucidité 2026-04-12

---

## 1. Verdict

**L'ordre "Purge d'abord, Câblage ensuite" contredit la mission.** Il traite l'abondance (symptôme) avant l'absence de transformation (cause). MINT_IDENTITY §40 : *"Prise immediate. Pas juste de la comprehension. Toujours : un danger evite, un piege eclaire, une question a poser, un prochain geste."* Supprimer 70 écrans ne crée aucun "prochain geste". Câbler 1 life event en crée un.

---

## 2. Arguments FOR (Purge → Câblage)

**F1 — Clarté cognitive agent.** 97 écrans dispersent le contexte Claude et engendrent la dérive-agent-amnésique. Un codebase plus petit = moins de façade à ré-imiter.

**F2 — Invariants CI avant câblage = garde-fou permanent.** `no_orphan_life_event.dart` n'a de sens que si le template life event est déjà défini. Poser la grammaire AVANT d'ajouter de la matière.

**F3 — Toilet test (§55).** *"Utilisable en 20 secondes. Jamais pompeux."* 97 écrans échouent au toilet test avant même le premier Layer 4. Purger = condition nécessaire de lucidité UX.

---

## 3. Arguments AGAINST (Purge → Câblage)

**A1 — La Purge ne crée aucune transformation.** 13-AUDIT §42 : *"MINT opère à un niveau d'abstraction trop élevé. MINT produit de l'information quand le monde a besoin d'un produit qui fabrique de la transformation."* Supprimer = réduire l'information. Câbler = produire la transformation. v2.8 sans câblage = MINT reste un filing cabinet plus petit.

**A2 — Critère de suppression introuvable sans grammaire.** Sans 1 life event bout-en-bout, impossible de dire *"cet écran ne sert pas la mission"*. Risque documenté Audit-05 : suppression prématurée de `testament_invisible_widget`, `marriage_penalty_gauge`, `survivor_pension_widget` — pièces orphelines aujourd'hui, câblables demain. Purge aveugle = destruction de futur dossier-first.

**A3 — Cause racine = absence de Layer 4, pas abondance.** La dérive-agent vient de ce que la grammaire MINT (4-couches §66-95) n'est codifiée nulle part en template exécutable. Un agent ne peut pas "imiter MINT" car MINT n'existe pas encore en machine. Câbler Layer 4 sur 1 event = donner la grammaire aux agents futurs. Purger d'abord = imposer un vide comme norme.

---

## 4. Position finale : **Hybride — "Purge guidée par grammaire"**

Un seul milestone, pas deux. Ordre intérieur :

1. **Câbler 1 life event bout-en-bout d'abord (ex : newJob ou birth)** — 4 couches + persistance + coach injection + S2-gate si applicable. Devient le template de référence.
2. **Extraire invariants CI depuis ce template** — `no_orphan_life_event` peut alors vérifier concrètement, pas en spéculation.
3. **Purger à la lumière du template** — tout écran qui ne peut pas être reformulé dans la grammaire du template est suspect. Critère explicite, pas "gut feeling".
4. **Câbler les 4 life events restants** (Tier 1 PROMISE-GAP §83) en appliquant le template.

Un Julien qui installe MINT après ce cycle trouve : moins d'écrans ET 5 life events vivants. Pas "moins d'écrans ET mission toujours morte".

---

## 5. Scope exact v2.8 "MINT Visible" (hybride)

- Phase 31 câblage central (CoachProfile.lifeEvents + LifeEventOrchestrator + context_injector) — **4 j**
- Phase 32 **1 life event pilote** bout-en-bout (newJob : fréquent, LPP libre passage, Layer 4 clair) — **2 j**
- Phase 38a **invariants CI dérivés du pilote** — **1 j**
- Phase 36 **Purge guidée** (critère = "expressible dans grammaire pilote") — **3 j**
- Phase 32b **4 life events Tier 1 restants** (cantonMove, birth, housingPurchase, inheritance) — **6 j**
- Phase 37 device gate — **1 j**

Total : ~17 j agent, parallélisable à 4-6 j calendaire.

---

## 6. Risque mission si on se trompe d'ordre

Purge d'abord sans câblage = **v2.8 qui ship un codebase propre mais où MINT_IDENTITY §136 (*"Une intelligence calme, intime, fiable, dans la poche"*) reste une promesse creuse.** Pire qu'un codebase gros avec 3 life events câblés : l'utilisateur qui télécharge v2.8 reçoit *moins de façade*, pas *plus de lucidité*. Le pivot 2026-04-12 ("paix, contrôle, compréhension, zéro effort") exige du câblage, pas du vide.

Risque symétrique (câblage pur sans purge) : dérive-agent continue, façade accumule. Le hybride ci-dessus résout les deux.

**Mint n'accuse pas. Mint éclaire** (§20). Une Purge qui n'éclaire rien n'est pas MINT.
