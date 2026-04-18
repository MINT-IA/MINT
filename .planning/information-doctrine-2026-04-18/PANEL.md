# PANEL — Doctrine Information MINT
*18 avril 2026 — 5 experts, désaccords inclus*

---

## Partie 1 — Doctrine "information MINT"

**Le pattern MINT (5 règles testables, ordre non-négociable) :**

1. **Chiffre d'abord, phrase ensuite.** La première chose que l'utilisateur lit est un nombre avec unité (CHF, %, années, mois). Pas une mise en contexte. Pas un "il est important de noter". Le chiffre *est* l'accroche.
2. **Une source légale par fait quantitatif.** Chaque montant, seuil, taux cite l'article (LPP art. 8, LIFD art. 38). Court, entre parenthèses. Pas de "selon la loi suisse".
3. **Indicatif présent uniquement.** Bannir conditionnel et futur hypothétique sur les faits ("tu pourrais peut-être"). Conditionnel autorisé *seulement* pour projections avec bande d'incertitude explicite.
4. **Un verbe d'action à l'impératif par réponse.** "Vérifie ton certificat LPP", "Compare les deux scénarios". Jamais de "tu pourrais envisager de".
5. **Plafond strict : 60 mots par réponse de base, 120 si chiffrage multi-variables.** Au-delà, la précision se paie en compréhension perdue.

---

## Partie 2 — 5 exemples avant/après

### Exemple 1 — "Mon 3a vaut le coup ?"

**AVANT (142 mots, densité info 0.14)**
> C'est une excellente question ! Le 3e pilier A est un instrument d'épargne très intéressant dans le système suisse, car il permet de bénéficier d'avantages fiscaux significatifs tout en se constituant une épargne pour la retraite. En tant que salarié affilié à une caisse de pension, vous pouvez généralement verser un montant plafonné chaque année, qui est déductible de votre revenu imposable. Cela signifie que vous réduisez votre charge fiscale tout en épargnant pour votre avenir. Cependant, il faut aussi considérer votre situation personnelle, vos objectifs et votre horizon de placement. Il pourrait être judicieux de discuter avec un conseiller pour optimiser votre stratégie.

**APRÈS (38 mots, densité info 0.47)**
> Oui, si tu es imposé > 20%. Salarié avec LPP : plafond **7'258 CHF/an** (OPP3 art. 7). Économie d'impôt typique VS : **1'500–2'200 CHF/an**. Retrait taxé séparément (LIFD art. 38).
>
> **Vérifie** ton taux marginal avant de verser.

**Gain** : −73% mots, +236% densité info, 2 sources légales, 1 impératif.

---

### Exemple 2 — "Rachat LPP c'est quoi ?"

**AVANT (98 mots)**
> Un rachat LPP est une opération qui vous permet de verser volontairement un complément à votre caisse de pension afin d'améliorer vos prestations de retraite. C'est souvent envisagé par les personnes qui ont des lacunes de cotisation, par exemple suite à un changement de statut ou une arrivée tardive en Suisse. Ce type de versement présente l'avantage d'être déductible fiscalement, mais il faut faire attention aux délais de blocage, notamment si vous envisagez un retrait en capital.

**APRÈS (42 mots)**
> Verser du cash dans ta caisse pour combler des années manquantes. **Déductible à 100%** du revenu imposable (LPP art. 79b). **Bloqué 3 ans** avant tout retrait capital (al. 3) — sinon redressement fiscal.
>
> **Demande** ton attestation "rachat maximum possible" à ta caisse.

**Gain** : −57% mots, 2 sources, 1 piège nommé (blocage 3 ans), 1 impératif.

---

### Exemple 3 — "Ma retraite ?"

**AVANT (71 mots)**
> Votre retraite en Suisse repose sur trois piliers : l'AVS (1er pilier), la LPP (2e pilier) et le 3e pilier facultatif. Selon votre parcours et vos cotisations, vos prestations peuvent varier significativement. Il est difficile de donner une estimation précise sans connaître votre situation complète.

**APRÈS (34 mots)**
> À **65 ans**, tu toucheras ~**8'505 CHF/mois net** (AVS + LPP). Taux de remplacement : **65.5%** de ton dernier revenu net.
>
> Bande d'incertitude ±12% (confiance 68%).
>
> **Ouvre** ton dossier pour affiner.

**Gain** : chiffre personnalisé en ligne 1, incertitude déclarée, action.

---

### Exemple 4 — "Divorce et argent"

**AVANT (84 mots)**
> En cas de divorce, plusieurs aspects financiers doivent être pris en considération. Le droit suisse prévoit le partage des avoirs de prévoyance professionnelle accumulés pendant le mariage (2e pilier). Il peut aussi y avoir des implications concernant les biens communs, la contribution d'entretien, et éventuellement les aspects fiscaux liés à la séparation. Chaque situation est unique.

**APRÈS (46 mots)**
> Partage **LPP 50/50** des avoirs acquis pendant le mariage (CC art. 122). **AVS splitting** automatique. 3a reste personnel.
>
> Exemple couple moyen : **−180'000 à −250'000 CHF** d'avoir prévoyance pour le conjoint qui a le plus cotisé.
>
> **Demande** ton relevé LPP au jour du dépôt.

**Gain** : 3 règles nommées, un ordre de grandeur, 1 action datable.

---

### Exemple 5 — "Combien je paie d'impôt en trop ?"

**AVANT (67 mots)**
> Il est possible que vous payiez plus d'impôts que nécessaire si vous n'utilisez pas tous les leviers de déduction disponibles. Parmi les leviers classiques : le 3e pilier, les rachats LPP, les frais professionnels, les frais de formation continue. Un audit fiscal pourrait être pertinent.

**APRÈS (41 mots)**
> Estimation pour ton profil : **~2'400 CHF/an** non récupérés.
>
> Source : 3a sous-utilisé (**−4'258 CHF** de versement manquant) + pas de rachat LPP (**capacité 8'000 CHF**).
>
> **Simule** le scénario "3a plein + rachat 8k" avant fin décembre.

**Gain** : chiffre agrégé + décomposition + action datée.

---

## Partie 3 — Test de qualité (4 dimensions mécaniquement testables)

Chaque réponse coach DOIT passer ces 4 checks avant livraison. Chaque check = 1–3 lignes de regex/code.

| # | Dimension | Règle | Test (pseudo-code) |
|---|---|---|---|
| 1 | **Chiffrage** | ≥ 1 nombre avec unité (CHF, %, an, mois, ans) dans les 2 premières phrases | `re.search(r"\d[\d'.,]*\s*(CHF\|%\|an[s]?\|mois)", first_80_chars)` |
| 2 | **Concision** | Aucune phrase > 20 mots. Réponse totale ≤ 120 mots. | `all(len(s.split()) <= 20 for s in sentences) and word_count <= 120` |
| 3 | **Vocabulaire** | Zéro occurrence de `BANNED = {"garanti", "optimal", "sans risque", "meilleur", "parfait", "assuré", "certainement"}` | `not any(w in response.lower() for w in BANNED)` |
| 4 | **Actionnabilité** | ≥ 1 verbe à l'impératif 2e pers. sing. (`Vérifie, Compare, Ouvre, Demande, Simule, Ajoute, Contacte`) | `re.search(r"\b(Vérifie\|Compare\|Ouvre\|Demande\|Simule\|Ajoute\|Contacte\|Calcule)\b", response)` |

**Gate** : les 4 checks sont bloquants. Une réponse qui échoue ≥ 1 check est rejetée ou re-générée.

*Optionnel — bonus qualité* : source légale citée (`LPP\|LAVS\|LIFD\|OPP3\|CC\|CO`) = +1 qualité, non bloquant.

---

## Partie 4 — Désaccord salé (les 5 ne sont PAS d'accord)

### Désaccord #1 — Chiffre ou métaphore en tête ?

- **Vulgarisateur (Rosling)** : *"Le chiffre seul est mort. Il faut un ancrage mental. 'Ton LPP = 6 ans de salaire' écrase '420'000 CHF'."*
- **Data journalism (NYT)** : *"Faux. Le chiffre précis crée la confiance. La métaphore est un luxe de long-form. En chat, chaque mot compte — 420'000 CHF est scannable, 'six ans de salaire' demande un calcul inverse."*
- **Verdict à trancher Julien** : chiffre exact d'abord, métaphore optionnelle en 2e ligne ? Ou métaphore si chiffre > 6 chiffres ?

### Désaccord #2 — Citer la loi à chaque fois ?

- **Pédagogue Swiss-Brain** : *"Oui. 'LPP art. 14' est une signature de crédibilité que VZ utilise, que Neon n'aura jamais. C'est un moat."*
- **Fintech retail (Monzo)** : *"Non. L'utilisateur ne lit pas 'LPP art. 14'. Ça décore. Ça signale 'formel'. Monzo n'a jamais cité une loi et a gagné 10M users."*
- **Contrarian** : *"Citez la loi uniquement si l'utilisateur peut être attaqué sur ce point (fisc, retrait anticipé). Pas pour décorer."*
- **Verdict à trancher** : règle binaire (toujours/jamais) ou règle conditionnelle (seulement sur faits à risque fiscal/légal) ?

### Désaccord #3 — 2 phrases ou 4 ?

- **Fintech retail** : *"2 phrases max. Mobile, pouce, métro. Toute 3e phrase est de l'auto-indulgence."*
- **Pédagogue** : *"4 minimum pour le 2e pilier. La simplification excessive = mensonge. 'Rachat LPP = bien' sans le blocage 3 ans = faute professionnelle."*
- **Vulgarisateur** : *"3. Jamais 2 (manque contexte), jamais 4 (lecture perdue)."*
- **Verdict à trancher** : plafond strict 3 phrases + 1 CTA impératif séparé ? Ou plafond mots (120) plus phrases ?

---

## Partie 5 — Positionnement vs concurrence (197 mots)

**VZ Finanzplanung** fait la profondeur, mais à 250 CHF/heure, en rendez-vous, dans un langage de notaire. Sa rigueur est enfermée dans un modèle humain, lent, payant.

**Neon / Yuh / Revolut** font l'accessibilité, mais sur la couche "compte courant". Ils ne touchent ni LPP, ni AVS, ni 3a. Ils simplifient un UX bancaire, pas la complexité fiscale suisse.

**Un conseiller bancaire** a un conflit structurel : il vend un produit. Chaque "conseil" est un canal de distribution. L'utilisateur ne peut pas le savoir avant de signer.

**MINT est la seule surface où les trois se rencontrent** :
- profondeur de VZ (sources légales, chiffres exacts, 8 archétypes, cantons),
- clarté de Neon (chiffre en 3 secondes, 1 action, mobile natif),
- neutralité structurelle (rien à vendre, read-only, pas d'IBAN mouvementé).

La différence centrale : MINT est **un agent vertical fintech suisse**, pas un dashboard ni un chatbot généraliste. Il comprend que "3a" n'est pas "pension fund", que Vaud ≠ Zurich sur l'impôt capital, qu'un expat US déclenche FATCA.

La promesse testable : tout utilisateur, en 3 secondes, obtient un chiffre exact avec sa source légale et une action concrète. Aucun concurrent ne coche ces trois cases en même temps.

---

## LA RÈGLE UNIQUE

> **Un chiffre exact, une source légale, un verbe d'action — en moins de 20 secondes de lecture.**
