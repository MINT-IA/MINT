# 🛠️ MINT Tools

Ce dossier contient les outils d'automatisation et de maintenance pour MINT.

## 🇨🇭 Tax Harvester (`fetch_tax_data.py`)

Ce script automatise la récupération des données fiscales suisses depuis le site de l'Administration Fédérale des Contributions (ESTV).

### Objectif
Récupérer chaque année :
1.  Les barèmes d'impôt sur le revenu (Income Tax Scales)
2.  Les barèmes d'impôt sur la fortune (Wealth Tax Scales)
3.  (Optionnel) Les multiplicateurs communaux

### Utilisation

1.  **Prérequis** : Python 3.x installé.
2.  **Installation des dépendances** :
    ```bash
    pip install requests
    ```
3.  **Lancer le Harvester** :
    ```bash
    cd tools
    python fetch_tax_data.py
    ```
4.  **Résultats** :
    Les fichiers JSON seront sauvegardés dans `../assets/data/tax/`.
    Vérifiez les logs `tax_fetch.log` pour les erreurs éventuelles.

### Maintenance Annuelle
Chaque mois de Janvier :
1.  Modifiez la variable `YEAR` dans le script `fetch_tax_data.py` (ex: 2025 -> 2026).
2.  Lancez le script.
3.  Vérifiez que l'API de l'ESTV n'a pas changé. Si oui, inspectez le réseau sur `swisstaxcalculator.estv.admin.ch` et mettez à jour `BASE_URL`.

---

## Autres Outils
(À venir : Générateur de PDF, Scraper de taux hypothécaires...)
