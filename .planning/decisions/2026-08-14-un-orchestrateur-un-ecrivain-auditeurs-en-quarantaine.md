---
date: 2026-08-14
status: Proposed
authors: Claude (Product Leader), Codex (axe adverse), Julien (arbitrage)
panel: 1 axe adverse Codex + banc d'essai empirique de 6 lancements
supersedes: —
superseded_by: —
description: Un orchestrateur, un écrivain, des auditeurs en quarantaine — le nombre d'axes suit les classes de risque non couvertes, jamais un plafond.
related:
  - .planning/FEUILLE-DE-ROUTE.md
  - tools/verify_full.sh
  - tools/agent-drift/dashboard.py
  - apps/mobile/test/screens/onboarding/rente_projection_truth_test.dart
---

# Un orchestrateur, un écrivain, des auditeurs en quarantaine

## TLDR

Le multi-agent sert à **contredire**, jamais à fabriquer en parallèle : un seul
écrivain par lot, des auditeurs en lecture seule dont **aucune trouvaille n'est
publiable avant reproduction**, et un nombre d'axes qui suit les classes de
risque non couvertes plutôt qu'un plafond arbitraire.

## Context

Le 2026-08-14, une marche à la main de vingt minutes sur simulateur a trouvé
quatre défauts que 11 122 tests, 93 vérificateurs, 21 workflows et un flot
Maestro de bout en bout avaient laissé passer — dont un écran annonçant
« CHF 4'108 – 5'524 / mois dès 65 ans » en déclarant une seule hypothèse et en
taisant celles qui dominent.

La même journée a servi de **banc d'essai** au multi-agent, avec des chiffres
et non des impressions. Six axes Codex lancés, tous en lecture seule, tous
adverses, tous sur du travail déjà fait :

| Axe | Résultat |
|---|---|
| Classement des défauts | **Vrai** — mon classement était post hoc, une métrique disponible avait chassé un jugement |
| Invariants métamorphiques | **Vrai** — 3 de mes 5 invariants passaient pour de mauvaises raisons |
| Élagueur d'artefacts | **Vrai** — une racine symbolique laissait l'outil sortir du dépôt ; confirmé par mutation |
| Revendication de localité | **FAUX** — « matériellement fausse » ; le mécanisme existe (`coach_profile_provider.dart:569-577`). Repris dans la feuille de route avant vérification, puis retiré publiquement |
| Inventaire de vérité (1er essai) | **Mort** — tué par un délai de 340 s en pleine recherche |
| Inventaire de vérité (2e essai) | Vrai — dont le faux RAMD et le plafond de couple non appliqué |

Précision terminée **3/4 = 75 %** · rendement **0,5 défaut confirmé par
lancement** · délais dépassés **33 %** · lancements sans valeur **50 %**.

Le contexte immédiat vient de l'analyse de
<https://www.anthropic.com/engineering/multi-agent-research-system> (lu le
2026-08-14), qui rapporte un coût d'environ 15× celui d'un chat et note que la
**programmation se parallélise mal** parce qu'elle partage contexte et
dépendances.

## Decision

**1. Un orchestrateur, un écrivain.** Un seul acteur écrit dans un lot donné.
Le multi-agent contredit ; il ne fabrique pas en parallèle. Les six axes utiles
de la journée étaient tous en lecture seule, tous adverses, tous postérieurs au
travail.

**2. Les auditeurs sont en quarantaine.** La lecture seule protège l'intégrité
du dépôt, **jamais la justesse des conclusions**. Une trouvaille d'auditeur est
une hypothèse jusqu'à reproduction indépendante, et la reproduction prend
exactement une de ces quatre formes : un test, une mutation, une trace du
mécanisme dans le code, ou un contre-exemple exécutable. Sans cette règle, on
remplace une source d'erreur par une source d'erreur plus confiante — mesuré :
un axe sur quatre a produit une affirmation fausse déjà écrite dans un document
avant d'être retirée.

**3. Le nombre d'axes suit les classes de risque non couvertes.** Ni plafond ni
plancher. Pré-enregistrer les axes et la classe de défauts que chacun vise ;
commencer par deux ; n'en ajouter un que s'il couvre une classe encore absente,
ou si le précédent produit encore des défauts confirmés **uniques** ; arrêter
quand la duplication dépasse 70 %, ou quand deux axes marginaux successifs ne
trouvent rien d'unique. Cinq à sept axes restent défendables sur une surface
financière suisse — ils ne doivent simplement jamais être **automatiques**.

**4. Contractualiser chaque délégation**, y compris dans le temps. Objectif
falsifiable, format de sortie, fichiers autorisés, frontières — et l'ordre
explicite de **rendre un verdict partiel avant la limite** plutôt que de
continuer à chercher. Deux lancements sur six sont morts faute de cette
clause : coût payé, valeur nulle.

**5. Juger l'état final ET sa provenance.** Juger le seul état final efface les
délais dépassés, les faux positifs écartés tard et le coût d'arbitrage : c'est
un biais du survivant. On enregistre donc, par axe et en **une ligne de texte
ajoutée** — pas un schéma relationnel — : axe, SHA audité, statut
(`complet` / `délai` / `tué`), verdict (`confirmé` / `faux positif` / `réfuté` /
`corrigé puis confirmé`), minutes d'arbitrage. Les tables se construiront le
jour où il y aura dix lignes à analyser.

**6. Le dénominateur n'est pas le jeton.** MINT a un seul humain ; la ressource
rare est **l'attention de Julien jusqu'à une vérité vérifiée**. La bonne
question n'est pas « combien ça coûte » mais « est-ce que ça réduit ce que
Julien doit vérifier lui-même ». Les jetons restent une contrainte secondaire.

**7. Conséquence directe : la mémoire `feedback_expert_panel_pattern` est
retirée.** Elle prescrivait « 3-7 experts en parallèle, décide toi-même » de
façon automatique. La laisser coexister ajouterait une source de plus racontant
une prochaine action différente — le défaut que cette décision combat.

## Counter-arguments and data gaps

**Ce que dit la vue opposée la plus forte.** Six lancements ne fondent aucune
statistique. Une précision de 75 % mesurée sur quatre verdicts terminés a un
intervalle de confiance qui couvre à peu près tout ; l'axe qui s'est trompé
pouvait aussi bien être un mauvais jour qu'une tendance. Et la règle « aucune
publication avant reproduction » a un coût réel non mesuré : reproduire la
trouvaille sur la racine symbolique a demandé deux mutations et une réécriture
de test — si chaque trouvaille coûte ça, le rendement par heure humaine
pourrait devenir pire que celui d'une revue mono-agent, ce que cette décision
prétend justement optimiser. Enfin, « un écrivain » est une contrainte réelle
sur la vitesse : deux écrivains dans le même checkout se sont bloqués
aujourd'hui, mais ils ont aussi produit deux lots en parallèle.

**Ce que cette source ne traite pas.** L'article Anthropic mesure des systèmes
de recherche à plusieurs utilisateurs, pas un projet à un humain — le rapport
15× n'a pas de raison de transposer. Nous n'avons aucune mesure du contrefactuel :
personne n'a fait tourner la même journée en mono-agent pour comparer. Nous
n'avons pas non plus mesuré ce que les axes ont **manqué** : les défauts encore
présents dans l'écran de rente (faux RAMD, unités temporelles incohérentes) ont
été trouvés par un axe, mais rien ne dit combien restent invisibles aux deux.
Aucune donnée sur la corrélation entre axes : deux axes Codex partagent le même
modèle, donc probablement les mêmes angles morts — la « diversité » supposée
des lentilles n'est pas établie.

**Ce qui changerait cette conclusion.** Si, après dix missions comparables, le
rendement marginal par heure de Julien passe sous celui d'une revue
mono-agent, la règle 3 doit redescendre vers zéro axe par défaut. Si les faux
positifs plus les délais dépassés restent au-dessus de 30 % sur deux fenêtres
successives pour un axe donné, cet axe est suspendu. Si un bail d'écriture
mécanique ou des worktrees isolés sont mis en place, la règle 1 peut
s'assouplir vers plusieurs écrivains sur des périmètres disjoints — aujourd'hui
`verify_full.sh` ne fait que **détecter** la collision après coup, il ne
l'empêche pas. Et si un second modèle devient disponible pour les axes adverses,
il faut re-mesurer la corrélation avant de conclure quoi que ce soit sur la
diversité.

## Sources

- <https://www.anthropic.com/engineering/multi-agent-research-system> (lu le 2026-08-14)
- `apps/mobile/test/screens/onboarding/rente_projection_truth_test.dart` (commits `253f7c6fd`, `49a9601cc`)
- `tools/simulator/prune_runtime_artifacts.py` + ses tests (commit `600033188`)
- `tools/verify_full.sh` — refus d'attester un arbre modifié
- `.planning/FEUILLE-DE-ROUTE.md` § « Ce que la première marche a trouvé »
- Engram : `Codex avait tort sur la revendication de localité — vérifié mécaniquement` ; `Les invariants métamorphiques doivent être non stricts`

## Status & follow-up

- **Proposed** — validé par Julien le 2026-08-14, à passer en `Decided` après
  dix missions instrumentées.
- Suivi d'implémentation : retrait de `feedback_expert_panel_pattern` ;
  ligne de journal par axe à ajouter au prochain lot d'outillage.
- Déclencheurs de re-litige : les quatre signaux listés ci-dessus.
