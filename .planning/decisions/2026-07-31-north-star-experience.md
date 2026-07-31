---
description: North Star expérience (Proposed) — le chiffre d'abord, le changement ensuite, la profondeur sur demande, la chaleur sans jugement, et l'app se souvient de toi ; 5 chantiers D1-D5.
---

# North Star expérience — synthèse walkthrough humain + benchmark UX (Proposed)

Statut : **Proposed**. Fige la synthèse des deux études du 2026-07-31 :
le walkthrough « à hauteur d'humain » (agent regard-humain, parcours
complet sur simulateur, 25 captures) et le benchmark UX 12 principes
sourcés (agent ux-vision).

## Contexte

### Étude 1 — walkthrough à hauteur d'humain (regard-humain)

Parcours complet cold open → onboarding → premier éclairage → bifurcation
→ home → relance → coach → mon argent, documenté par 25 captures
(`shots/01-cold-open.png` … `shots/25-mon-argent.png`, scratchpad de
session ; re-générables via les flows Maestro `tools/simulator/flows/`).

Forces observées :

- **Premier éclairage interactif** (`17-onb-scene.png`,
  `18-scene-interact.png`) : le curseur recalcule en direct — le moment
  le plus vivant du parcours.
- **Bulle coach personnalisée** (`23-coach.png`, `24-coach-reply.png`) :
  « Il te reste 3'535 CHF » — le coach sait parler avec les chiffres du
  profil.
- **Landing aérée** (`02-landing.png`) et **choix d'intention justifié**
  (`04-onb-intents.png`).

Faiblesses observées :

- **« Sortir » → mur d'inscription** (`19-onb-bifurcation.png`) : la
  promesse « Anonyme · conservé sur cet appareil »
  (`apps/mobile/lib/l10n/app_fr.arb:13060`) n'est pas tenue sur ce
  chemin ; `enableLocalMode()` existe
  (`apps/mobile/lib/providers/auth_provider.dart:1421`) mais n'est pas
  atteint depuis la bifurcation.
- **Relance = amnésie totale** (`21-relaunch.png`) : la réouverture
  montre une landing d'inconnu, comme si l'utilisateur n'était jamais
  venu.
- **6 questions froides avant valeur** (`05-onb-step3.png` →
  `10-onb-step8.png`), puis dossier figé — les réponses ne sont plus
  retouchables dans le parcours observé.
- **CTA « Parle à Mint » qui ne tient pas sa promesse** : la porte
  n'ouvre pas une conversation amorcée ; **vide du coach à l'entrée**
  (l'écran attend que l'utilisateur trouve quoi dire).
- **LE manque structurel : aucune boucle retour/évolution** — « l'app
  réussit le jour 1 et fait revivre le jour 1 à chaque retour ».

### Étude 2 — benchmark UX 12 principes (ux-vision)

12 principes, chacun sourcé sur un produit de référence (sources
complètes dans le transcript ux-vision) :

1. **Un chiffre d'abord, 3 étages de profondeur** (WHOOP : un score,
   puis les composantes, puis le détail — jamais tout d'un coup).
2. **Une seule prochaine action** (Duolingo : un chemin de leçon unique,
   pas un menu).
3. **Le retour = rituel delta** : « voici ce qui a changé » depuis le
   dernier passage.
4. **Une idée par écran** (GOV.UK Service Manual, « one thing per
   page »).
5. **Lucidité cumulative qui ne se casse jamais** (Gentler Streak : la
   progression ne se perd pas, pas de mécanique punitive).
6. **« Toi d'avant vs toi maintenant »**, mesuré en compréhension, pas
   en dépenses (leçon Monzo : le relevé de dépenses culpabilise, la
   compréhension gagnée valorise).
7. **Ton grande-sœur sans sarcasme** (Cleo : la chaleur oui, la moquerie
   non).
8. **Notification = pouvoir d'agir, jamais faute**.
9. **Couleur = vocabulaire sémantique unique** (la confiance a UNE
   couleur, constante partout).
10. **Hiérarchie par taille et profondeur**, pas par ornement.
11. **L'air comme structure** : tokens d'espacement 8/16/24/40, max 2
    idées par viewport.
12. **Onboarding = valeur en 60 s** ; toute question différée jusqu'à ce
    qu'elle change l'écran.

## La North Star en une phrase

> **« Le chiffre d'abord, le changement ensuite, la profondeur sur
> demande, la chaleur sans jugement — et l'app se souvient de toi. »**

Les deux études convergent : les briques de valeur existent (éclairage
interactif, coach chiffré), mais l'expérience n'a pas de mémoire ni de
boucle. La North Star ordonne les corrections autour de ce manque.

## Décision (Proposed) — les 5 chantiers D1-D5, ordonnés

L'ordre suit la dépendance structurelle : sans mémoire locale (D1) il
n'y a pas de retour (D2) ; sans retour, l'évolution visible (D5) n'a pas
de support. D3 et D4 corrigent l'entrée et les portes en parallèle.

### D1 — Mode local invité : honorer la promesse

Depuis la bifurcation d'onboarding, « Sortir » aboutit à une home locale
peuplée avec les données saisies, sans création de compte — la promesse
« Anonyme · conservé sur cet appareil » devient vraie, ou elle est
retirée du copy.

**Critère de sortie** : flow sim « Sortir » → home locale peuplée →
kill + relance → mêmes données présentes (preuve Maestro + captures).
**Pré-requis** : gate privacy (mint-quality-gate) sur le stockage local
avant tout merge.

### D2 — Rituel du retour delta

Toute réouverture avec un profil existant affiche « depuis ton dernier
passage » : soit un delta réel (chiffre qui a bougé, information
ajoutée), soit un état stable assumé — et dans les deux cas UNE seule
prochaine action (principes 2 et 3).

**Critère de sortie** : relance sim sur état existant → l'écran d'entrée
n'est jamais la landing d'inconnu ; un delta ou un état stable est
affiché avec une prochaine action unique (captures avant/après).

### D3 — Onboarding re-séquencé valeur-d'abord

Le premier éclairage interactif arrive en ≤ 60 s de parcours ; chaque
question posée avant ce point change visiblement l'écran suivant
(principe 12) ; le dossier reste retouchable après l'onboarding.

**Critère de sortie** : flow Maestro chronométré cold start → premier
éclairage ≤ 60 s ; revue écran par écran — chaque question restante est
justifiée par un changement d'écran visible ; une réponse d'onboarding
peut être modifiée depuis l'app (preuve sim).

### D4 — Vérités des portes + guidage coach

Chaque CTA d'entrée (landing, home, coach) dit la vérité sur sa
destination ; l'entrée coach affiche une amorce personnalisée tirée du
profil sans action de l'utilisateur — le vide d'entrée disparaît.

**Critère de sortie** : tableau d'audit CTA → destination réelle, libellés
corrigés ; capture sim de l'entrée coach montrant l'amorce personnalisée
dès l'ouverture.

### D5 — Évolution visible « toi d'avant vs toi maintenant »

Après chaque enrichissement de profil, une surface montre la progression
sur la courbe de confiance (`EnhancedConfidence`) — mesurée en
compréhension, pas en dépenses (principes 5 et 6), sans mécanique
cassable.

**Critère de sortie** : sur sim, un enrichissement de profil produit un
avant/après visible sur la courbe de confiance (captures) ; aucune
régression possible de la progression affichée par simple inaction.

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?**
  L'inscription précoce est le chemin le plus court vers une rétention
  adressable (email) et une persistance simple (une seule source
  serveur). Un mode local invité ajoute une surface de données device
  entière — migration locale → compte, effacement, quota anonyme
  Keychain déjà observé comme persistant à la réinstallation — pour un
  segment dont la conversion n'est pas démontrée. Le rituel delta,
  ensuite, pourrait pousser vers une fréquence de consultation qui n'est
  pas un but en soi pour un outil de lucidité : le retour n'a de valeur
  que si quelque chose a réellement changé. Enfin, différer des questions
  d'onboarding pourrait dégrader la qualité du premier chiffre si des
  entrées nécessaires au calcul sont repoussées.
- **What does this source not address ?**
  Une seule persona parcourue (un profil, un canton, une intention) —
  les 8 archétypes ne sont pas couverts. La /home peuplée mature n'a pas
  été observée : le walkthrough a vu la home fraîche et la home seedée
  (`20-home.png`, `22-home-seeded.png`), pas une home avec des semaines
  d'historique. Aucune mesure quantitative interne (pas d'analytics de
  rétention réels) — les 12 principes viennent de produits externes non
  suisses, la transposition au cadre éducatif LSFin reste à vérifier
  écran par écran. D1 exige le gate privacy : la faisabilité du stockage
  local complet (volume, chiffrement, effacement) n'a été évaluée par
  aucune des deux études. Le seuil « 60 s » du principe 12 n'a pas été
  chronométré sur le parcours actuel.
- **What would change this conclusion ?**
  Des tests utilisateurs réels montrant que l'exploration anonyme ne
  convertit pas vers un profil durable (ou que le mur d'inscription ne
  coûte pas ce que le walkthrough suppose) → re-priorisation de D1. Un
  verdict privacy défavorable sur le stockage local invité →
  re-séquencement des chantiers. Une mesure montrant que « premier
  éclairage ≤ 60 s » force à dégrader la qualité du chiffre → arbitrage
  principe 1 vs principe 12 à re-litiger.

## Sources

- Transcript agent `regard-humain` (session 2026-07-31) — walkthrough
  complet, 25 captures `shots/01-cold-open.png` →
  `shots/25-mon-argent.png` (scratchpad de session ; re-générables via
  `tools/simulator/flows/`).
- Transcript agent `ux-vision` (session 2026-07-31) — benchmark 12
  principes avec sources produit : WHOOP (score à étages), Duolingo
  (action unique), GOV.UK Service Manual (« one thing per page »),
  Gentler Streak (progression non punitive), Monzo (leçon dépenses vs
  compréhension), Cleo (registre de ton).
- Code cité : `apps/mobile/lib/l10n/app_fr.arb:13060` (promesse
  « Anonyme · conservé sur cet appareil »),
  `apps/mobile/lib/providers/auth_provider.dart:1421`
  (`enableLocalMode()`), `apps/mobile/lib/l10n/app_fr.arb:637`
  (`landingLegalFooter` : « Tes données restent sur ton appareil »).

## Status & follow-up

- Implementation tracking : ouvrir D1 → D5 comme périmètres journey_os
  distincts, D1 en premier ; D1 passe le gate privacy
  (mint-quality-gate) avant tout merge.
- Re-litigation triggers : listés dans « What would change this
  conclusion ? » ci-dessus.
