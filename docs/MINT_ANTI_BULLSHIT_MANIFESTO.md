# MINT Anti-Bullshit Manifesto

> Statut: garde-fou produit
> Role: empecher MINT de produire des feedbacks absurdes, hors contexte, ou non credibles
> Portee: coach, caps, suggestion chips, onboarding, sequences, scan, cohortes

---

## 1. Le vrai risque

Le pire bug de MINT n'est pas un crash.

Le pire bug de MINT, c'est un feedback qui donne a l'utilisateur l'impression que:
- MINT ne comprend pas sa situation
- MINT raconte n'importe quoi
- MINT plaque une pseudo-personnalisation vide
- MINT pousse une action incoherente

En finance, une suggestion stupide detruit la confiance beaucoup plus vite qu'un bug discret.

Règle:

**Un feedback absurde est un release-blocker.**

---

## 2. Principe central

**Mieux vaut moins de feedbacks, mais tres justes, que plus de feedbacks pseudo-smart mais fragiles.**

MINT ne doit jamais donner l'impression:
- d'improviser
- de deviner agressivement
- de plaquer un template sur tout le monde
- de pousser une action sans base suffisante

---

## 3. Les 7 interdits absolus

1. Ne jamais pousser un levier qui contredit les donnees connues
2. Ne jamais donner un chiffre fort sur une base fragile sans le signaler
3. Ne jamais utiliser un ton de certitude sur une estimation pedagogique
4. Ne jamais proposer une etape incoherente avec la cohorte ou la phase de vie
5. Ne jamais laisser un fallback legacy produire un message contradictoire
6. Ne jamais presenter une personnalisation non prouvee comme intelligente
7. Ne jamais shipper un feedback important sans test persona ou assertion comportementale

---

## 4. Les 5 questions obligatoires avant tout feedback

Avant d'afficher un cap, un CTA, une suggestion coach, un delta, un chiffre choc ou un next step, il faut pouvoir repondre oui a ces 5 questions:

1. Est-ce que ce feedback est coherent avec les donnees connues ?
2. Est-ce qu'il est coherent avec la phase de vie / cohorte / parcours en cours ?
3. Est-ce qu'il est honnete sur le niveau de confiance ?
4. Est-ce qu'un humain normal le trouverait intelligent et credible ?
5. Est-ce qu'on a un test ou une assertion qui verrouille ce comportement ?

Si la reponse est non a une de ces questions:

**on ne shippe pas**

---

## 5. Regles de formulation

### Quand la confiance est forte

On peut dire:
- ce qu'on sait
- ce que cela change
- la prochaine etape

### Quand la confiance est faible

On doit dire:
- ce qu'on sait vraiment
- ce qu'on estime
- ce qui manque
- comment ameliorer la precision

### On n'utilise jamais

- “garanti”
- “optimal”
- “meilleur”
- “parfait”
- “c'est sur”
- tout ton qui fait semblant d'etre plus precis que les donnees

---

## 6. Regles cohortes

Une logique cohort-aware n'est acceptable que si:
- elle repose sur une source canonique existante
- elle n'introduit pas une seconde classification concurrente
- elle ne pousse pas de feedback incoherent
- elle est testee sur personas golden

Exemples d'erreurs interdites:
- pousser `rachat LPP` a quelqu'un sans LPP
- pousser succession en priorite a un 22 ans
- pousser premier salaire a un retraite de 72 ans
- pousser retraite profonde en priorite a un profil demarrage sans contexte

---

## 7. Regles sequences

Une sequence ne doit jamais donner l'impression:
- d'avancer au hasard
- de repeter une etape inutilement
- de resumer quelque chose de faux
- de celebrer un changement qui n'existe pas

Donc:
- pas de delta visible sans vrai delta
- pas de resume final sans outputs fiables
- pas de “Continue” si la prochaine etape n'est pas reelle
- pas de message legacy contradictoire en parallele

---

## 8. Golden personas obligatoires

Tout systeme de feedback personnalise doit etre verifie au minimum sur:

- un 24 ans premier emploi
- un 33 ans projet logement
- un couple de 36 ans avec enfant
- un independant de 47 ans
- un pre-retraite de 59 ans
- un retraite de 72 ans

Question a poser pour chacun:

**"Est-ce que cette personne aurait l'impression que MINT comprend vraiment sa situation ?"**

Si non, il faut corriger.

---

## 9. Regle de release

Un feedback personnalise est release-ready seulement si:
- la source de verite est claire
- les preconditions metier sont explicites
- le chemin canonique est prouve
- les fallbacks sont verifies
- au moins un test persona ou une assertion comportementale existe

Sinon:

**le feedback est encore experimental, pas production-ready**

---

## 10. Règle finale

MINT n'a pas le droit d'etre “a cote de la plaque”.

Si MINT ne sait pas, il doit le dire proprement.
Si MINT estime, il doit le signaler.
Si MINT personnalise, il doit pouvoir le justifier.

La bonne personnalisation n'est pas:
- plus de texte
- plus de suggestions
- plus de sophistication apparente

La bonne personnalisation, c'est:

**la bonne chose, au bon moment, pour la bonne personne, avec le bon niveau de certitude.**

