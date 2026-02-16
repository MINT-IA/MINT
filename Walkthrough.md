# Walkthrough — Option A Verification (Mac Mini M4 Pro)

**Date**: 2026-01-31  
**Environment**: Mac Mini M4 Pro, macOS Tahoe  
**Status**: Architecture Verified ✅

## 1. Environment Setup & Fixes

L'application a été déployée et testée localement sur la nouvelle architecture M4 Pro :
- **Flutter SDK**: Installé (v3.27.3) avec support Web.
- **Backend Port**: Déplacé sur **8888** pour éviter les conflits (Frontend sur **4444**).
- **Fix Critique**: Résolution d'une erreur de compilation dans `EducationalInsertService` (paramètre `questionId` manquant).
- **Python**: Adaptation des prérequis (`pyproject.toml`) pour compatibilité avec Python 3.9.6.

## 2. Preuves de Travail (Option A)

### A. Onboarding & JIT Cards
L'onboarding intègre désormais des inserts didactiques "Just-In-Time" au bas de l'écran.
![JIT Cards Onboarding](file:///Users/julienbattaglia/.gemini/antigravity/brain/ab1dcd81-1c31-4cf7-b66c-773dca95bd2d/.system_generated/click_feedback/click_feedback_1769865896702.png)
*Exemple: Miroir Fiscal et Comparaison Cantonale (Le Voisin).*

### B. Widgets Interactifs (Pivot LPP)
Le "Pivot LPP" est correctement rendu comme un widget interactif pendant le wizard.
![Pivot LPP Widget](file:///Users/julienbattaglia/.gemini/antigravity/brain/ab1dcd81-1c31-4cf7-b66c-773dca95bd2d/.system_generated/click_feedback/click_feedback_1769865967522.png)

### C. Dashboard & Timeline
Le dashboard centralise désormais la timeline et les indicateurs de précision.
![Dashboard Dashboard](file:///Users/julienbattaglia/.gemini/antigravity/brain/ab1dcd81-1c31-4cf7-b66c-773dca95bd2d/.system_generated/click_feedback/click_feedback_1769866262859.png)

### D. Score & Impact (Suivre)
La vue de suivi montre l'impact cumulé et le score de santé financière.
![Suivre Screen](file:///Users/julienbattaglia/.gemini/antigravity/brain/ab1dcd81-1c31-4cf7-b66c-773dca95bd2d/.system_generated/click_feedback/click_feedback_1769866279034.png)

---

## 3. Résultats de Vérification (DoD)

| Point | Statut | Preuve |
|-------|--------|--------|
| **Backend Tests** | ✅ PASS | `test_docs_copy_compliance.py` validé |
| **Logic IF/THEN** | ✅ PASS | Top 3 actions générées dynamiquement |
| **Read-Only** | ✅ PASS | Aucune action de paiement détectée |
| **1 Screen = 1 Intent** | ✅ PASS | UX respectée |

## 4. Bugs Identifiés (À Corriger)

> [!WARNING]
> **Bug de Routage (Web)**: Le bouton "J'ai déjà un compte" sur le Splash Screen pointe vers `/login` qui n'est pas défini dans le GoRouter.

> [!CAUTION]
> **Assertion Navigation**: Une erreur `navigator.dart:5051:12` survient parfois à la fin du wizard sur Chrome, bloquant la redirection automatique.

---

## 5. Commandes de Validation

```bash
# Lancer le backend
cd services/backend && source .venv/bin/activate && uvicorn app.main:app --port 8888

# Lancer le frontend (Web)
cd apps/mobile && flutter run -d web-server --web-port 4444
```
