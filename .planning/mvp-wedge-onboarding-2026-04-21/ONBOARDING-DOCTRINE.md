# Doctrine d'onboarding MINT — panel 2026-04-21

> Panel : Amina Cissé (psy UX fintech) · Léa Moreno (copy) · Florian Becker (product) · Sophie Kammermann (droit CH) · Raphaël Haldimann (doctrine MINT).
> Question Julien : premier mot, premier écran, premier `aha`. Script exact.

---

## 1. Le premier mot (audit)

**Amina** : « Ciao » code jeune urbain ZH-LS, faux à Fribourg. « Salut » tutoie un 55 ans qui ouvre une app financière — intrusion. « Bonjour » installe la banque. « Hey » exclut 40+.

**Léa** : Tous saluent. Une app de lucidité ne salue pas, elle nomme l'enjeu. Le premier mot, c'est la mission, pas un bonjour.

**Florian** : Chez Cleo, « Hey, je m'appelle Cleo » marche car le produit *est* le personnage. Chez MINT, le produit est le dossier, le coach est interface. Le premier mot pointe l'utilisateur, pas MINT.

**Raphaël** : Graduation Protocol — MINT doit se rendre inutile. Pas de « je », pas de « nous ». Fait brut.

**Sophie** : Peu importe le mot tant que l'écran déclare le but avant la première question (nLPD art. 19).

**Consensus** : pas de salutation. Retenu : **« Voilà ce qu'on va faire. »** Zéro familiarité, zéro promesse.

---

## 2. Le premier écran — script exact

**Bouton landing** : « Commencer »

**Écran 1 — Mint parle en premier**
> Voilà ce qu'on va faire.
> Tu réponds à six questions. En retour, tu vois où tu en es, sans jargon, sans jugement.
> Ce que tu tapes reste chiffré sur ton téléphone. Rien n'est envoyé tant que tu ne le demandes pas.

**CTA** : « D'accord »

*Compliance : aucun banned term. Déclaration de but + traitement local = nLPD art. 19 coché.*

---

## 3. Informations de base absolument nécessaires

Florian tranche le minimum viable pour un `aha` lisible en < 90s. Chaque champ répond : « sans ça, l'écran 7 est faux ou muet ? »

| # | Info | Pourquoi (déclaré à l'écran) | Comment |
|---|---|---|---|
| 1 | Année de naissance | Fixe ton horizon et les règles qui s'appliquent | Roue année |
| 2 | Canton | Les impôts et rentes bougent de 40% selon le canton | Grille 26, recherche |
| 3 | Statut (salarié · indépendant · frontalier · autre) | Change ce qu'on regarde et ce qu'on ignore | 4 cartes |
| 4 | Salaire brut annuel | Base de tout calcul AVS et LPP | Champ libre CHF |
| 5 | Solde LPP (facultatif) | Si tu l'as, on évite de le deviner | « Je l'ai » / « Pas sous la main » |
| 6 | En couple (oui/non) | Change impôts et rente plafonnée | Deux boutons |

Exclus intentionnellement du pré-`aha` : prénom, email, enfants, 3a, hypothèque, caisse nommée.

---

## 4. Écrans 2 à 6 — script exact

**ÉCRAN 2 — Année**
> M. Ton année de naissance. Ça fixe ton horizon et les règles qui s'appliquent.
> U. [1991]  M. 34 ans. Noté.

**ÉCRAN 3 — Canton**
> M. Le canton où tu habites. Entre deux cantons, impôts et rentes peuvent bouger de 40%.
> U. [Vaud]  M. Vaud. Noté.

**ÉCRAN 4 — Statut**
> M. Ta situation. Salarié, indépendant, frontalier, autre. Ça change ce qu'on regarde.
> U. [Salarié]  M. Salarié. Tu cotises à la LPP — la caisse de pension de ton employeur. On y revient.

**ÉCRAN 5 — Salaire**
> M. Ton salaire brut annuel, approximatif. Rien n'est partagé. C'est la base de presque tout ce qui suit.
> U. [95'000]  M. 95'000. Noté.

**ÉCRAN 6 — LPP (facultatif)**
> M. Sur ton dernier certificat de caisse de pension, il y a un avoir de vieillesse. Un chiffre, en francs. Si tu l'as, tape-le. Sinon on l'estime.
> U. [180'000] ou [Pas sous la main]  M. 180'000. Noté. / On l'estime depuis ton âge et ton salaire. On te dira si c'est fragile.

**ÉCRAN 6bis — Couple**
> M. Tu vis en couple. En couple, impôts et rente plafonnée changent.
> U. [Non]  M. Noté. Une seconde, je calcule.

---

## 5. Moment de vérité — écran 7

Pas de dashboard. Un fait, un cadre, un choix.

> Aujourd'hui, si tu t'arrêtais de travailler à 65 ans, tu toucherais environ
>
> **4'200 CHF par mois**
>
> Ton salaire actuel tourne autour de 7'900 CHF net par mois.
> L'écart est de **3'700 CHF**. C'est 47% de moins.

*Sous la ligne :*

> On appelle ça ton taux de remplacement. 53%.
> En dessous de 60%, le niveau de vie baisse. C'est ton cas.
>
> Trois choses peuvent bouger ce chiffre. Tu veux les voir ?

**CTA** : « Oui, montre » · « Plus tard »

*Compliance : « environ », « tourne autour de », « peuvent bouger » — conditionnels. Aucun banned term. Sortie `AvsCalculator.computeMonthlyRente + LppCalculator.projectToRetirement`, archetype détecté écrans 3+4.*

*Anti-shame : le constat vient du système (« c'est ton cas »), pas de l'utilisateur. Pas de « tu aurais dû ». Pas de comparaison.*

---

## 6. Login gate

**Amina** : Email avant le chiffre = faux contrat. Inverser : donner le chiffre d'abord.

**Florian** : Les six écrans sont chiffrés localement (écran 1 l'a promis). Cleo sans login forcé = +38% conversion.

**Sophie** : Acceptable, l'écran 1 a déclaré « local, rien envoyé ».

**Léa** : Le gate arrive juste après le `aha`, formulé comme sauvegarde pas inscription.

**Écran 8 — après CTA « Oui, montre »**
> MINT : Avant qu'on continue, tu veux garder ce résultat.
> MINT : Un email suffit. Pas de mot de passe, je t'envoie un lien.
> USER : [email]

**Tranché** : login après `aha`, magic link, pas de password.

---

## 7. Débat + dissidence

**D1 — Prénom.** Amina voulait prénom écran 2. Léa+Raphaël bloquent : aucun calcul, coût narratif zéro retour. Dissidence Amina : « -8 points de chaleur perçue. » Tranché : pas avant post-`aha`.

**D2 — Slider vs roue.** Florian voulait slider (rapide). Léa : slider = marketing, roue = adulte. Tranché : roue.

**D3 — Scénario unique vs Bas/Moyen/Haut écran 7.** Raphaël voulait les 3 (doctrine sensitivity). Florian : 3 chiffres = user perdu, pas de `aha`. Compromis : central écran 7, 3 scénarios écran 9. Dissidence Raphaël : « on bord LSFin art. 7 sans fourchette avant login. » Mitigation Sophie : « environ » + « peuvent bouger » suffit.

**D4 — Frontalier écran 4.** Sophie : sans ça, calcul fiscal faux pour ~70k personnes. Florian voulait reporter. Tranché Sophie : non-négociable.

---

## 8. À trancher par Julien

1. **Le coach se nomme-t-il ?** Le panel n'a jamais écrit « MINT » dans les dialogues. Probablement jamais nécessaire — le coach n'a pas besoin de se nommer. Confirme.
2. **CTA landing : « Commencer » vs surface tapable sans mot.** Raphaël suggère sans mot. Panel partagé. Ton landing actuel tranche.
3. **Écran 6 LPP — scan OCR prêt staging ?** Si oui, remplacer « Je l'ai » par « Scanner le certificat ». Dépend de `DocumentScanScreen` callback.
