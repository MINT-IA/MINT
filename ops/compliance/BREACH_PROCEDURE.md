# Procédure de notification de brèche de données

> nLPD Art. 24 — Obligation de notification au PFPDT et aux personnes concernées

## Définition

Une brèche de données est tout incident de sécurité entraînant :
- Un accès non autorisé à des données personnelles
- Une perte ou destruction de données personnelles
- Une divulgation non intentionnelle de données personnelles

## Processus en 4 étapes

### Étape 1 — Détection et évaluation (0-4h)

| Action | Responsable | Délai |
|--------|-------------|-------|
| Identifier la nature de l'incident | DPO | Immédiat |
| Évaluer les données affectées (quoi, combien, qui) | DPO + Dev | 2h |
| Évaluer le risque pour les personnes | DPO | 4h |
| Documenter dans le journal d'incidents | DPO | 4h |

### Étape 2 — Notification PFPDT (si risque élevé, dans les 72h)

| Champ | À remplir |
|-------|-----------|
| Contact PFPDT | https://databreach.edoeb.admin.ch/ |
| Nature de la brèche | _Description_ |
| Données affectées | _Types et volume_ |
| Personnes affectées | _Nombre approximatif_ |
| Mesures prises | _Actions correctives_ |
| Conséquences possibles | _Impact évalué_ |

### Étape 3 — Notification aux personnes (si risque élevé)

- Email à tous les utilisateurs affectés
- Contenu : nature de la brèche, données concernées, mesures prises, actions recommandées
- Délai : dès que possible après notification PFPDT

### Étape 4 — Post-mortem (7 jours)

- Analyse root cause
- Mesures correctives permanentes
- Mise à jour des mesures de sécurité
- Archivage dans `postmortems/`

## Exemples de scénarios

| Scénario | Risque | Action |
|----------|--------|--------|
| Base de données Railway compromise | Élevé | Étapes 1-2-3-4 complètes |
| Clé API Anthropic fuitée | Moyen | Révoquer la clé, évaluer l'accès aux données |
| Bug affichant le profil d'un autre user | Élevé | Fix immédiat + notification si données lues |
| SharedPreferences lisibles sur appareil rooté | Bas | Documentation, pas de notification |

## Contacts d'urgence

| Rôle | Nom | Contact |
|------|-----|---------|
| DPO | _À compléter_ | privacy@mint-app.ch |
| Dev Lead | _À compléter_ | _À compléter_ |
| Hébergeur (Railway) | Support | support@railway.app |
