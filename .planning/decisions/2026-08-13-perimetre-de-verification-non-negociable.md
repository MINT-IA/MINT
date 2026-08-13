---
description: Deux fois dans la même session j'ai annoncé « vert » sur un périmètre de tests que j'avais choisi moi-même, et trop étroit. Le remède n'est pas une règle de plus — la recherche la mesure nette-négative — mais un reçu machine que le crochet de pré-envoi compare à l'arbre envoyé.
status: Proposed
date: 2026-08-13
---

# Le périmètre de vérification cesse d'être mon choix

## Ce qui s'est passé

Deux fois le 2026-08-13, dans la même session.

**Première fois.** J'écris que les gates sont verts. Je n'avais pas lancé
`landing_screen_test.dart`. Trois tests y étaient cassés par mes propres
suppressions. C'est l'axe code de Codex qui les a trouvés.

**Deuxième fois.** Je commite `db78d11a0` en annonçant 82 tests verts. Les 82
étaient réels — sur le périmètre que j'avais choisi. La suite complète a ensuite
donné **10 917 tests et 9 échecs**, dont 7 ou 8 causés par moi :

| Échec | Pourquoi je ne l'ai pas vu |
|---|---|
| 4 références visuelles de la landing | le rendu change ; aucun appel de fonction ne relie l'écran à son image de référence |
| `routes_registry_screen_test` | il **compte** les valeurs de l'enum `RouteOwner`, à laquelle j'en avais ajouté une |
| `landing_v3_test` — long-press caché | j'avais retiré l'affordance ; le test l'exigeait |
| `start_route_contract_test` | il **lit le fichier source comme du texte** et cherche un littéral que j'avais supprimé |
| `navigation_push_doctrine_test` | mon correctif `/coach` → `/coach/chat` a transformé un `push` licite en violation, `/coach/chat` étant une racine de branche |

Aucun de ces cinq liens n'est visible dans un graphe d'appels. Trois d'entre eux
ne sont même pas des dépendances de code : une image, un décompte, une chaîne de
caractères.

## Le diagnostic, et il a un nom

Ce n'est pas « du code de mauvaise qualité ». C'est que **le périmètre de
vérification était mon choix, et je l'ai choisi trop étroit**. La littérature
nomme précisément les trois couches :

- **`false success`** — l'écart entre l'affirmation de complétion en langue
  naturelle et l'état réel de l'environnement.
- **régression *pass-to-pass*** — un agent modifie un élément partagé (un
  utilitaire, un composant, un champ de schéma) et casse des fonctionnalités
  qu'il n'a jamais touchées ; ses propres tests passent puisqu'ils sont alignés
  sur son changement.
- **sélection de tests non sûre** — 30 ans de littérature sur la *Regression
  Test Selection* appellent *safety* la propriété de ne jamais omettre un test
  dont le résultat peut changer. Une sélection statique par graphe d'appels
  n'est pas sûre.

Et la cause profonde est établie par trois travaux relus par les pairs : le
déficit d'un modèle est dans la **localisation** de l'erreur, pas dans sa
correction. Un modèle à qui l'on dit « sois plus rigoureux » ne gagne rien ; un
modèle à qui l'on dit **quels tests lancer** gagne beaucoup.

## Le remède que je n'ai PAS retenu

Ajouter une règle à `CLAUDE.md`. C'est le réflexe, et il est mesuré
contre-productif :

- une expérience d'ablation ajoutant des consignes procédurales de TDD **sans**
  dire quels tests précis vérifier fait **monter** les régressions de 6,08 % à
  9,94 % — pire que rien ;
- la documentation d'Anthropic le dit sur son propre outil : les instructions de
  doctrine sont **consultatives**, elles peuvent être noyées par le reste du
  contexte, et un fichier trop long fait ignorer les règles qu'il contient
  déjà. `CLAUDE.md` fait aujourd'hui plus de 200 lignes.

Une règle de plus aurait donc dégradé les règles voisines tout en ne
m'apprenant toujours pas qu'un écran d'administration compte les valeurs de
l'enum. **Je n'ai rien ajouté à `CLAUDE.md`.** C'est délibéré, pas un oubli.

## Le remède retenu

Deux fichiers, aucune promesse.

**`tools/verify_full.sh`** — une seule commande, dont le périmètre est *tout* :
analyse statique mobile, **suite mobile complète**, suite backend, garde Journey
OS, lint du wiki, intégrité du registre des communes, parité des six fichiers de
langue. Elle écrit un reçu portant l'identifiant de l'arbre Git vérifié et le
code de sortie de chaque gate. Un échec efface le reçu.

**`tools/checks/verify_receipt_gate.py`**, câblé en `pre-push` dans
`lefthook.yml` — compare l'identifiant du reçu à celui de l'arbre qu'on envoie.
S'ils diffèrent, l'envoi est refusé. Pas parce qu'une règle a été oubliée :
parce que la preuve ne porte pas sur l'objet.

L'ordre de travail s'en trouve inversé, et c'est le point : **committer d'abord,
vérifier ensuite, envoyer en dernier**. Le reçu porte l'arbre committé, ce qui
rend mécaniquement impossible de vérifier un état et d'en envoyer un autre.

Ce que ce dispositif change concrètement pour moi : je ne peux plus écrire
« vert » à partir de ce que je crois avoir couvert. Je cite un reçu, ou je
n'écris rien.

## La relecture adversariale a cassé la première version

Le dispositif ci-dessus a été soumis à une relecture adversariale avant d'être
considéré comme acquis. Elle a rendu **REJET**, et sur deux points qui vidaient
le garde de son sens :

**Le crochet ne lisait pas ce qui était envoyé.** Un crochet `pre-push` reçoit
sur son entrée standard les références réellement poussées. Je ne les lisais
pas : je comparais le reçu à `HEAD^{tree}`. Donc
`git push origin <autre-sha>:refs/heads/dev` passait le garde tout en envoyant
un arbre jamais vérifié, sans le moindre `--no-verify`. Le poussé de plusieurs
références était pire : une seule pointe était contrôlée. La phrase de cet ADR
qui affirmait comparer « l'arbre qu'on envoie » était **fausse**. Le garde lit
désormais l'entrée standard et exige que chaque référence envoyée porte l'arbre
attesté.

**Le script testait le répertoire de travail et signait l'arbre committé.** Les
gates lisent les fichiers sur disque ; le reçu portait `HEAD^{tree}`. Un
correctif local non commité faisait donc passer les tests, puis signait un arbre
qui ne le contenait pas. La vérification refuse maintenant de démarrer sur un
répertoire modifié.

Deux défauts moindres corrigés dans la foulée : le reçu n'attestait pas que
**tous** les gates obligatoires avaient tourné (un reçu à trois gates passait),
et il était écrit sans atomicité (un disque plein produisait un reçu tronqué et
mensonger).

Il reste vrai — et c'est écrit plus bas — qu'un crochet local n'est pas une
garantie de dépôt.

## Pourquoi « tout » plutôt qu'une sélection intelligente

La tentation était de construire une carte d'impact — un index code → tests
interrogeable avant de modifier. La mesure existe et elle est bonne : −70 % de
régressions. Mais la même littérature est nette sur la limite : **la sélection
est une optimisation de vitesse, jamais un mécanisme de correction.** Une
sélection statique rate exactement mes trois cas — l'image, le décompte, la
chaîne de caractères.

La suite mobile complète prend **6 minutes 15** pour 10 941 tests. Tant qu'elle
tient dans ce budget, la bonne granularité est « tout ». Une carte d'impact
deviendra utile quand ce ne sera plus vrai, et pas avant.

## Counter-arguments and data gaps

**Contre-argument 1 — « six minutes avant chaque envoi, c'est du gaspillage ».**
Vrai en apparence. À comparer au coût réel constaté : deux annonces fausses, un
commit contenant 7 régressions, et la confiance entamée de la personne qui lit
mes messages. Six minutes est le prix bas.

**Contre-argument 2 — « le garde se contourne avec `--no-verify` ».** Oui, et
c'est voulu. Un contournement doit rester possible et **visible**. La différence
avec la situation d'avant n'est pas l'impossibilité, c'est que sauter la
vérification devient un acte explicite au lieu d'un oubli silencieux.

**Contre-argument 3 — « un reçu local ne prouve rien à distance ».** Exact. Le
reçu porte l'arbre vérifié **sur cette machine**. Il n'est pas versionné et ne
protège pas une CI ni un autre poste. Le seul gate qui survivrait à tout est un
contrôle obligatoire côté serveur avec file de fusion. Le reçu local est le
mécanisme le moins cher qui traite le mode de défaillance constaté ; il ne
remplace pas la CI.

**Lacune 1 — le garde ne couvre que `pre-push`.** Un commit peut encore
contenir des régressions. C'est assumé : à six minutes la vérification, la poser
sur chaque commit rendrait le travail impraticable, et l'unité qui compte pour
autrui est la branche envoyée, pas le commit intermédiaire.

**Lacune 2 — la suite backend n'a pas été chronométrée** dans ce cadre. Si
l'ensemble dépassait la dizaine de minutes, l'arbitrage « tout » devrait être
rejugé.

**Lacune 3 — rien ne mesure encore si le dispositif marche.** La seule preuve
sera l'absence de nouvelle annonce fausse sur les prochaines sessions. Un reçu
existant ne garantit pas que je le cite honnêtement ; il garantit seulement que
l'envoi est bloqué sans lui.

**Lacune 4 — le contexte de branche n'est pas couvert.** Le reçu identifie un
*contenu* (l'arbre), pas un contexte. Or au moins un gate — le garde Journey OS
— compare le travail à `origin/dev`. Le même arbre poussé depuis une autre
branche n'a donc pas forcément le même verdict. Choisir l'arbre plutôt que le
commit évite de tout revérifier après un simple changement de message ; c'est un
arbitrage assumé, pas une propriété démontrée.

**Lacune 5 — les quatre travaux les plus directement applicables (TDAD, false
success, building-to-the-test) sont des préprints non relus par les pairs**, et
l'un d'eux est signé d'un seul auteur. Les résultats sur l'incapacité à
s'auto-corriger, eux, sont publiés en conférence (ICLR, TACL, ACL).

## Sources

- Huang et al., *Large Language Models Cannot Self-Correct Reasoning Yet*,
  ICLR 2024 — <https://arxiv.org/abs/2310.01798>
- Kamoi et al., *When Can LLMs Actually Correct Their Own Mistakes?*, TACL 2024
  — <https://aclanthology.org/2024.tacl-1.78/>
- Tyen et al. (Google), *LLMs cannot find reasoning errors, but can correct them
  given the error location*, ACL Findings 2024 —
  <https://aclanthology.org/2024.findings-acl.826/>
- Alonso, Yovine, Braberman, *TDAD: Test-Driven Agentic Development*,
  arXiv:2603.17973 — <https://arxiv.org/html/2603.17973v2>
- Advani, *From Confident Closing to Silent Failure: Characterizing False
  Success in LLM Agents*, arXiv:2606.09863 —
  <https://arxiv.org/html/2606.09863>
- Ma, Kereopa-Yorke, Schultz (Microsoft), *Building to the Test*,
  arXiv:2606.28430 — <https://arxiv.org/html/2606.28430>
- Machalica et al. (Facebook), *Predictive Test Selection*, ICSE-SEIP 2019 —
  <https://arxiv.org/abs/1810.05286>
- *Reflection-aware static regression test selection*, OOPSLA 2019 —
  <https://lingming.cs.illinois.edu/publications/oopsla2019.pdf>
- Anthropic, *Best practices for Claude Code* —
  <https://code.claude.com/docs/en/best-practices>
- Anthropic, *Get started with hooks* —
  <https://code.claude.com/docs/en/hooks-guide>
- Autonoma, *When your AI agent breaks existing features* —
  <https://getautonoma.com/blog/ai-agent-breaks-existing-features>
- Graphite, *bors, Google TAP and merge queues* —
  <https://graphite.com/blog/bors-google-tap-merge-queue>

## La relecture payante devient permanente sans devenir ruineuse

Julien : « collaboration maximale avec Codex, y compris sur ce sujet, et rendre
l'infra permanente mais sans qu'elle ne coûte une fortune en jetons ».

Les deux exigences ne s'opposent que si les axes sont lancés à l'aveugle.
`tools/codex_axes.sh` les déduit désormais des chemins modifiés :

| Axe | Déclencheur mécanique |
|---|---|
| code | tout `.dart`, `.py`, `.sh`, `.yml` |
| ux | `lib/screens/`, `lib/widgets/`, `lib/routes/` |
| copie | `lib/l10n/`, `lib/screens/`, `lib/widgets/`, tout `.arb` |
| données | `lib/data/`, `lib/models/`, `financial_core/`, `backend/app/{services,models}/`, `assets/`, migrations |

Trois règles bornent la dépense. **Le gratuit passe d'abord** : sans reçu
valable, aucune relecture n'est lancée — payer un modèle pour diagnostiquer un
arbre dont les tests échouent, c'est acheter ce que la suite donne pour rien.
**Une seule batterie par lot**, sur la pointe candidate, jamais à chaque commit.
Et **tout défaut trouvé qui est mécaniquement détectable devient un contrôle
gratuit**, pour ne plus jamais être payé deux fois — c'est ce qui a été fait ici
même : les deux failles du garde sont devenues des cas de test.

Ce que l'on envoie est le diff, pas le dépôt. On y perd le contexte lointain ;
on y gagne de pouvoir lancer plusieurs axes.

Lié : [[feedback_zero_trust_protocol]] · `CLAUDE.md` §9 ·
`.planning/decisions/2026-08-13-identite-communale-registre-federal.md`
