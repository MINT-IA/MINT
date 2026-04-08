# MINT Operations — Structure documentaire

> Tout ce qui n'est pas du code mais qui est nécessaire pour opérer MINT comme une entreprise FinTech suisse.

## Structure

```
ops/
├── compliance/          # nLPD, FINMA, LSFin — tout ce qui est réglementaire
│   ├── DPA/             # Data Processing Agreements (Anthropic, OpenAI, Railway)
│   ├── DPIA.md          # Analyse d'impact protection des données
│   ├── PROCESSING_REGISTER.md  # Registre des traitements (Art. 12 OPDo)
│   ├── BREACH_PROCEDURE.md     # Procédure de notification de brèche (Art. 24 nLPD)
│   └── DPO_DESIGNATION.md      # Désignation du DPO + notification PFPDT
│
├── governance/          # Décisions stratégiques, OKRs, réunions
│   ├── DECISIONS_LOG.md         # Journal des décisions clés (date, qui, quoi, pourquoi)
│   ├── TEAM.md                  # Qui fait quoi (rôles, responsabilités)
│   └── MEETINGS/                # Comptes-rendus de réunions
│
├── marketing/           # Newsletters, landing pages, acquisition
│   ├── NEWSLETTER_CALENDAR.md   # Calendrier éditorial
│   ├── LAUNCH_PLAN.md           # Plan de lancement
│   └── ASSETS/                  # Visuels, copy, templates email
│
├── partnerships/        # Caisses de pension, banques, conseillers
│   ├── PARTNER_PIPELINE.md      # Pipeline de partenaires potentiels
│   └── CONTRACTS/               # Contrats signés (gitignored si sensibles)
│
├── finance/             # Budget, runway, métriques business
│   ├── BUDGET.md                # Budget opérationnel
│   └── METRICS.md               # KPIs clés (MAU, retention, NPS)
│
└── support/             # FAQ, procédures support, modération
    ├── FAQ.md                   # Questions fréquentes utilisateurs
    └── MODERATION_POLICY.md     # Règles modération Discord/communauté
```

## Convention

- **Documents sensibles** (DPA signés, contrats, données financières) → `.gitignore` ou stockage séparé (Notion/Drive)
- **Templates et processus** → versionnés dans git (transparence, historique)
- **Décisions** → datées, attribuées, avec le "pourquoi" (pas juste le "quoi")

## Outils recommandés

| Besoin | Outil | Pourquoi |
|--------|-------|----------|
| Communication quotidienne | **Discord** (existant) | Gratuit, déjà en place, bon pour les discussions rapides |
| Documentation structurée | **Ce dossier `ops/`** | Versionné, proche du code, pas de vendor lock-in |
| Gestion de projet (quand l'équipe grandit) | **Notion** ou **Linear** | Bases de données, kanban, wikis — quand Discord ne suffit plus |
| Documents signés | **Google Drive** ou **Tresorit** (CH) | Stockage sécurisé pour DPA signés, contrats, factures |

## Discord — Comment l'organiser

Channels recommandés pour MINT :

```
#general           — discussions libres
#dev-updates       — commits, PRs, déploiements (webhook GitHub)
#bugs-et-audits    — findings, corrections, suivi
#compliance        — nLPD, DPA, FINMA, LSFin
#marketing         — newsletters, landing, acquisition
#product           — features, feedback utilisateurs, roadmap
#support           — questions utilisateurs, incidents
```
