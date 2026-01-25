# Educational Inserts — Guardrails & Guidelines

Référence: [ADR-CH-EDU-SIMULATORS](/decisions/ADR-CH-EDU-SIMULATORS.md)

---

## Structure d'un Insert

Chaque fichier `.md` dans ce dossier définit un insert didactique attaché à une question wizard.

```yaml
questionId: "q_xxx"
learningGoal: "Ce que l'utilisateur doit comprendre"
copy_FR:
  title: "Titre affiché"
  body: "Texte explicatif"
  callToAction: "Action suggérée"
actions:
  - id: "action_xxx"
    label: "Libellé action"
    url: "/path/to/action"
disclaimer: "Texte de disclaimer obligatoire"
hypotheses:
  - "Hypothèse 1"
  - "Hypothèse 2"
```

---

## Guardrails Copywriting (Compliance FINMA / OECD)

### 1. Hypothèses Visibles
- Toute simulation doit lister ses hypothèses de calcul
- Utiliser des fourchettes, pas des valeurs exactes
- Format: "Basé sur un rendement de 3-5% (hypothèse pédagogique)"

### 2. Pas de Promesses
- ❌ "Vous économiserez CHF 1'800"
- ✅ "Économie potentielle estimée entre CHF 1'200 et CHF 2'400"
- ❌ "Votre retraite sera confortable"
- ✅ "Cet objectif dépend de nombreux facteurs"

### 3. Taux Marginal = Fourchette
- Ne jamais afficher un taux marginal exact
- Utiliser: "Votre taux marginal est estimé entre 25% et 32%"
- Toujours préciser: "Cette estimation dépend de votre canton, situation familiale, et déductions"

### 4. Pédagogique, Pas Conseil
- Chaque insert doit mentionner: "À titre pédagogique uniquement"
- Renvoyer vers un professionnel pour les décisions importantes
- Ne pas remplacer un conseiller fiscal ou financier agréé

### 5. Partner Handoff = Disclosure
- Si un insert suggère un partenaire (banque 3a, courtier hypothèque):
  - Mentionner: "Mint peut recevoir une compensation de ce partenaire"
  - Toujours proposer des alternatives
  - Ne jamais lier une récompense UX à l'utilisation d'un partenaire

### 6. Retraits 3a Échelonnés = Prudence Cantonale
- Mentionner: "La fiscalité varie selon les cantons"
- Avertir: "Certains cantons peuvent considérer des retraits trop rapprochés comme optimisation abusive"
- Renvoyer vers: "Consultez un conseiller fiscal pour votre situation"

---

## Checklist Avant Publication

- [ ] Le disclaimer est visible sans scroll
- [ ] Les hypothèses sont listées
- [ ] Aucune promesse de résultat garanti
- [ ] Le taux marginal est une fourchette
- [ ] Les partenaires sont disclosés avec alternatives
- [ ] Le wording "pédagogique" est présent
- [ ] Les sources sont citées si applicable

---

## Fichiers dans ce dossier

| Fichier | Question | Statut |
|---------|----------|--------|
| `q_has_pension_fund.md` | LPP Pivot | TODO |
| `q_has_3a.md` | 3a existence | TODO |
| `q_3a_annual_amount.md` | Versement 3a | TODO |
| `q_mortgage_type.md` | Type hypothèque | TODO |
| `q_has_consumer_credit.md` | Crédit conso | TODO |
| `q_has_leasing.md` | Leasing | TODO |
| `q_emergency_fund.md` | Fonds urgence | TODO |
