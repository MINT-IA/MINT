# Coach Home — Panel 5 experts (2026-04-18)

## 1. Expert UX minimaliste (Apple Weather, Linear, Things 3, Arc, Stripe Atlas)

**Insight** : Les grands produits minimalistes n'ouvrent jamais sur du vide ni sur du marketing. Ils ouvrent sur **l'état présent du user**, rendu en une seule donnée lisible à 30 cm. Apple Weather = la température maintenant, pas un onboarding. Things 3 = ta Today list, pas une inspiration quote. Linear = l'issue sur laquelle tu étais. Le pattern commun : **la dernière chose vraie que le système sait, rendue grande**.

**Proposition concrète** : L'écran Coach ouvre sur **un seul bloc de texte centré verticalement**, 28pt, qui est *la dernière chose que MINT sait de toi*. Profil vide → "On ne s'est pas encore parlé." (pas de CTA visible, juste un curseur qui clignote en bas). Profil partiel → "Valaisan, 43 ans. C'est à peu près tout ce que je sais." Profil riche → "Hier tu m'as parlé de ton 3a. Je n'ai pas oublié." **Zéro chrome, zéro carte, zéro suggestion**. Le clavier/mic apparaît au tap.

**Désaccord avec le contrarian** : je refuse le "silence total écran blanc" — Apple Weather n'est pas vide, il montre la température. Le vide pur n'est pas minimalisme, c'est abstention.

---

## 2. Expert fintech conversation (Cleo 3.0, Copilot, Ellevest, Monzo Manage)

**Insight** : Cleo a gagné parce qu'elle ne demande *jamais* "de quoi veux-tu parler ?" — elle **tend une perche spécifique à toi**. Copilot ouvre sur "Your net worth moved +2.3% this week". Monzo Manage ouvre sur "You've spent £312 this week, £40 less than last". La première impression finance réussie n'est **ni une question, ni un greeting** : c'est **un fait daté** que seul le système pouvait observer. Le user n'a rien à faire, juste à lire.

**Proposition concrète** : Profil partiel+ → afficher **un seul "fait silencieux"** généré par `CoachNarrativeService`, sans verbe d'injonction. Exemple : "Fribourg, 38 ans. Ton 3a 2025 se ferme dans 73 jours." — point final, pas de bouton, pas de question. Le user peut taper pour répondre ou ignorer. Retour après 4 jours → **un fait qui a bougé pendant l'absence** : "Pendant ton absence, le plafond 3a 2026 est passé à 7'258." Pas "content de te revoir".

**Désaccord avec la psychologue** : je pense qu'un fait chiffré n'est *pas* anxiogène s'il est neutre et daté. L'anxiété vient de l'injonction ("tu devrais"), pas de l'information.

---

## 3. Directeur créatif contrarian

**Insight** : Tout le monde dans la fintech converge vers le même écran d'entrée : un greeting + des suggestion chips + un input. C'est devenu **l'uniforme de la catégorie**. Si MINT fait pareil avec un peu plus de goût, MINT est oubliable. L'anti-pattern radical : **l'écran Coach n'est pas un écran d'accueil — c'est un écran de reprise**. Comme un carnet posé ouvert sur la table où tu étais. Il ne dit pas bonjour. Il ne se présente pas. Il **continue**.

**Proposition concrète** : Profil vide → **écran entièrement noir** sauf une ligne fine en bas : "écris quelque chose, n'importe quoi". Pas de logo, pas de titre "Coach", pas de suggestion. Le user doit écrire le premier mot — c'est un rite, pas une friction. Profil riche → **l'écran reprend exactement où la dernière conversation s'est arrêtée**, scrollé à la dernière bulle, avec un fin séparateur horizontal "— hier, 21h47 —" puis un curseur. Pas de résumé. Pas de widget d'overview. Le chat *est* l'écran, il n'y a rien d'autre à voir.

**Risque assumé** : certains users vont fermer l'app en ne comprenant pas quoi faire. C'est le prix du non-uniforme. On compense avec un empty state qui dit littéralement *quoi taper*, pas *quoi penser*.

---

## 4. Psychologue de la honte financière

**Insight** : L'anxiété financière à l'ouverture d'une app vient de **trois déclencheurs** : (a) une question qui présuppose de la compétence ("que veux-tu simuler ?"), (b) un score/chiffre perso visible avant qu'on soit prêt à le voir, (c) un rappel de retard ("tu n'as pas fait X"). Les random greetings piquants ("personne sait") cochent (a) implicitement — ils posent une question socratique dont la non-réponse du user = aveu d'ignorance. C'est pour ça que c'est *fatigant* : chaque ouverture d'app = mini-interrogatoire. La honte n'a pas besoin d'être explicite pour opérer.

**Proposition concrète** : Règle dure → **aucun chiffre personnel visible à l'ouverture du Coach avant interaction explicite du user**. Pas de "ton 3a = 14'000". Pas de "tu as mis de côté X%". Le Coach peut parler de **faits du monde** (plafond 3a, échéance fiscale du canton, délai LPP) mais **jamais de faits du user** tant que le user n'a pas tapé. Retour après 4 jours → **surtout pas** "ça fait 4 jours" (ça culpabilise). À la place : continuité pure, comme si 4 minutes s'étaient écoulées.

**Désaccord avec le fintech expert** : afficher "ton 3a 2025 ferme dans 73 jours" en ouverture *est* un déclencheur de honte pour le user qui n'a pas versé. Le fait paraît neutre mais le sous-texte est "et tu n'as rien fait". À reformuler en fait du monde : "Le 3a 2025 ferme dans 73 jours pour tout le monde." — le "pour tout le monde" désindividualise.

---

## 5. PM Swiss fintech

**Insight** : Le user suisse n'aime pas qu'on lui parle. Il aime qu'on soit prêt. Raiffeisen, PostFinance, Neon, Yuh — aucune ne fait de greeting chaleureux à l'ouverture. Elles ouvrent sur le solde, point. La chaleur est perçue comme **intrusive et non-sérieuse**. Par ailleurs, la discrétion suisse veut qu'on **ne montre pas qu'on se souvient trop** — un coach qui dit "je n'ai pas oublié ta conversation d'hier sur le 3a" sonne collant. Mieux : le coach se souvient mais ne le dit pas; le user le découvre en tapant.

**Proposition concrète** : Écran Coach = **zone de saisie en bas + zone vide au-dessus qui se remplit à mesure**. Pas de header "Coach". Pas de greeting. Profil partiel → une ligne grise 13pt tout en haut : "Valais · avril 2026" (contextualisation canton + mois fiscal en cours). C'est tout. C'est sobre, c'est daté, c'est suisse. Profil riche → même ligne + le dernier échange visible scrollable vers le haut. Le coach se souvient en silence; il le prouve quand on lui parle, pas avant.

**Désaccord avec le contrarian** : écran noir total = trop théâtral, pas suisse. Le canton + le mois en gris clair, c'est le bon degré de présence.

---

## Traitement par état (synthèse des 5 voix)

| État | Ce qui s'affiche |
|------|------------------|
| **Profil vide** | Écran quasi vide. Une ligne de header gris 13pt : "Coach". Zone de saisie en bas, placeholder : *"écris quelque chose, n'importe quoi"*. Pas de chips, pas de greeting, pas de logo central. |
| **Profil partiel** | Header 13pt gris : "Canton · mois" (ex: "Valais · avril"). Rien d'autre au-dessus de la zone de saisie. Le coach *a* des données mais ne les brandit pas. |
| **Profil riche + conversation active** | Header 13pt gris identique. Dernier échange visible, scrollé au dernier message. Séparateur fin avec timestamp relatif discret ("il y a 2 jours"). Curseur prêt. |
| **Retour après 4 jours** | Identique au profil riche. **Aucun** "content de te revoir", **aucun** "ça fait 4 jours". Le temps écoulé se lit dans le timestamp du séparateur, pas dans une phrase. Un seul changement autorisé : si un fait du monde a bougé (plafond 3a, échéance fiscale), il apparaît **une seule fois**, en ligne grise, au-dessus du séparateur — formulé comme fait collectif ("le 3a 2026 a ouvert"), jamais comme reproche perso. |

---

## 3 propositions finales à tester

**1. "Carnet ouvert"** — L'écran Coach n'est jamais un accueil, c'est une reprise. Profil vide = écran quasi-noir avec une ligne d'invitation à écrire. Profil riche = la conversation exacte d'hier, scrollée au dernier message, sans résumé ni greeting.
- *Pourquoi ça marche* : supprime le mini-interrogatoire qui fatigue le user à chaque ouverture, et crée une sensation de continuité qui imite un vrai journal personnel.
- *Risque* : certains users ne comprennent pas quoi faire à l'écran vide et ferment l'app — à mesurer via taux de premier message dans 60s.

**2. "Header canton · mois"** — Une seule ligne 13pt grise en haut, format "Valais · avril", et rien d'autre au-dessus de l'input. Le coach prouve qu'il sait où tu vis et à quel moment de l'année fiscale tu es, sans jamais te parler de toi.
- *Pourquoi ça marche* : donne un signal de compétence suisse (canton + fiscalité) sans déclencher la honte (aucune donnée perso exposée), et reste compatible 18-99 ans car ça ne présume d'aucun life event.
- *Risque* : peut paraître *trop* sobre pour certains users habitués aux apps chaleureuses — à tester contre une variante avec une deuxième ligne optionnelle.

**3. "Fait du monde, jamais fait du user"** — Si MINT a une info à communiquer à l'ouverture (échéance, plafond qui change, nouvelle règle), elle apparaît formulée collectivement ("le 3a 2026 ferme dans 73 jours pour tout le monde") et jamais individuellement ("ton 3a"). Règle dure : aucun chiffre personnel visible avant interaction explicite.
- *Pourquoi ça marche* : neutralise le déclencheur de honte #1 (faits perso = reproche implicite) tout en gardant une valeur informationnelle réelle, alignée avec la doctrine anti-shame.
- *Risque* : sous-utilise les données riches du profil — certains users voudraient *justement* voir leur chiffre en ouvrant l'app; à résoudre via un tap explicite ("afficher mes chiffres") plutôt que par affichage automatique.
