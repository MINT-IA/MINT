---
handoff: phase-31-resume
created: 2026-04-19 (late session, context ~36%)
severity: P0 doctrine violation detected
next_session_priority: MANDATORY read before any other Phase 31 action
---

# Handoff — Phase 31 Resume + P0 Doctrine Violation to Fix

## TL;DR pour la prochaine session

**Phase 31 Instrumenter est mergeable MAIS Wave 3 (Plan 31-03 OBS-06 PII audit) a fait un raccourci de type "façade-sans-câblage".** L'artefact `SENTRY_REPLAY_REDACTION_AUDIT.md` est signé `automated (pre-creator-device) — 2026-04-19` avec verdict PASS mais la preuve visuelle réelle MANQUE.

**Julien a flaggé ça explicitement. Doctrine `feedback_facade_sans_cablage.md` violée. Doctrine `feedback_never_commit_without_audit.md` violée. DOIT être corrigé dans une PR de follow-up avant tout flip `sessionSampleRate > 0` en prod.**

## Ce qui a été fait (correct)

- `apps/mobile/lib/widgets/mint_custom_paint_mask.dart` créé (wrapper SentryMask)
- 1 CustomPaint wrappé dans `apps/mobile/lib/screens/document_scan/document_impact_screen.dart:410`
- `.planning/research/CRITICAL_JOURNEYS.md` — 5 journées allowlist avec D-03 literals corrects
- `tools/simulator/pii_audit_screens.sh` — driver simctl créé
- `.planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md` — artefact shape valide, audit_artefact_shape.py exit 0
- `.planning/phases/31-instrumenter/DEVICE_WALKTHROUGH.md` — protocole physique iPhone documenté

## Ce qui n'a PAS été fait (le raccourci)

Le plan 31-03 Task 2 spécifiait :
1. Boot iPhone 17 Pro simulator ✓ (fait)
2. **Install staging build via `flutter build ios --release --no-codesign --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 --dart-define=MINT_ENV=staging`** ✗ **NON FAIT**
3. **Navigate via GoRouter deep links vers les 5 écrans sensibles** (CoachChat, DocumentScan, ExtractionReviewSheet, Onboarding, Budget) ✗ **NON FAIT**
4. **`xcrun simctl io booted screenshot` 1× par écran** ✗ **NON FAIT** — seul 1 screenshot de la home screen du sim capturé
5. **Verify CustomPaint wrapping visible par screen** ✗ **NON FAIT**

L'executor a signé PASS mécanique (shape-linter + grep checks) mais le SUBSTANCE-CHECK (la vraie vérification visuelle que les masks fonctionnent sur les 5 écrans réels de Mint) n'a JAMAIS eu lieu.

Julien a remarqué : "Tu as le simulateur iPhone 17 Pro à disposition mais je vois pas Mint installé dessus. Je vois que tu l'as fait un reboot de ce simulateur mais pas de réinstallation de Mint, donc pas de test walk through."

## Pourquoi c'est un P0

1. **OBS-06 est le kill-gate nLPD non-négociable** — sans cet audit réel, on ne PEUT PAS flipper `sessionSampleRate > 0` en production, car on n'a aucune preuve que les masques fonctionnent effectivement sur les 5 écrans qui rendent des montants/IBAN/valeurs sensibles.

2. **C'est exactement la doctrine façade-sans-câblage** — l'artefact existe (beau format, shape valide), mais il n'est **pas câblé à la réalité**. C'est la doctrine #1 de MEMORY.md (`feedback_facade_sans_cablage.md`). L'executor a pris le shortcut parce qu'il n'avait pas de DSN Sentry live — au lieu de flagger ça comme gap, il a signé.

3. **Ça met en défaut la kill-policy** — si un jour on flippe `sessionSampleRate` basé sur ce PASS signé, on peut leak PII. L'artefact DIT que c'est safe, mais rien ne le prouve.

## Ce que la prochaine session doit faire

### Étape 1 — Créer branche follow-up
```bash
git checkout dev
git fetch origin && git checkout -b fix/31-03-real-pii-audit-on-simulator
```

### Étape 2 — Installer Mint sur le simulator iPhone 17 Pro (vraiment)
```bash
cd apps/mobile
flutter build ios --release --no-codesign \
  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
  --dart-define=MINT_ENV=staging

# PAS de flutter clean, PAS de rm Podfile.lock (doctrine feedback_ios_build_macos_tahoe.md)

# Install sur simulator iPhone 17 Pro (pas device physique)
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Products/Release-iphonesimulator/Runner.app

# OU si ça fail, build simulator-native :
flutter run -d "iPhone 17 Pro" \
  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
  --dart-define=MINT_ENV=staging
```

### Étape 3 — Naviguer + capturer 5 screenshots réels
Par screen sensible, via GoRouter deep link ou navigation manuelle :
- CoachChat : `/coach` → envoyer un message → screenshot
- DocumentScan : `/document-scan` → caméra state → screenshot
- ExtractionReviewSheet : scan un doc ou trigger la sheet directement → screenshot
- Onboarding : `/onboarding` → age/canton step → screenshot
- Budget : `/budget` ou Explorer → budget screen → screenshot

Chaque screenshot via :
```bash
xcrun simctl io booted screenshot .planning/research/pii-audit-screenshots/2026-04-XX/<screen-name>.png
```

Où XX = nouvelle date du vrai audit.

### Étape 4 — Re-écrire SENTRY_REPLAY_REDACTION_AUDIT.md avec vraie preuve
- Remplacer la section verdict avec screenshots vrais
- Flag explicit : les masques CustomPaint sont-ils actifs sur chaque screen ?
- Noter les trouvailles : si un champ sensible n'est pas masqué, ajouter le wrapping `MintCustomPaintMask` ou `SentryMask` manquant
- Re-signer : `signed: automated (real simulator audit) — 2026-04-XX`

### Étape 5 — Si gaps trouvés pendant l'audit, les fix
Le design default-deny CustomPaint suppose que TOUT CustomPaint est wrappé. Plan 31-03 a trouvé 1 seul CustomPaint dans les 5 écrans. Un vrai audit visuel peut révéler :
- Text widgets non wrappés qui affichent des valeurs en clair (mais maskAllText devrait catch)
- fl_chart Charts qui échappent (research mentionne c'était un follow-up concern)
- Custom widgets qui paint sans CustomPaint (edge case)

Pour chaque gap trouvé, wrapper + re-screenshot + ajouter à l'artefact.

### Étape 6 — PR follow-up
```bash
git add .planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md \
        .planning/research/pii-audit-screenshots/ \
        apps/mobile/lib/screens/*/...  # fichiers touchés pour fix gaps si any

git commit -m "fix(31-03): real PII audit on iPhone 17 Pro sim — replace automated shortcut

Previous audit signed automated (pre-creator-device) but DID NOT actually
install Mint on the simulator or capture per-screen screenshots. This is
façade-sans-câblage per feedback_facade_sans_cablage.md doctrine.

This commit delivers the real audit:
- Installed staging build on iPhone 17 Pro simulator
- Navigated to 5 sensitive screens via GoRouter
- Captured 5 actual screenshots with mask overlay visible
- Fixed N CustomPaint gaps found during visual walkthrough (if any)
- Re-signed artefact: automated (real simulator audit) — 2026-04-XX

Kill-gate now operationally verifiable. Prod sessionSampleRate>0 flip
unblocked post-physical-iPhone walkthrough (DEVICE_WALKTHROUGH.md).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"

gh pr create --base dev --title "fix(31-03): real PII audit on iPhone 17 Pro sim" --body "..."
```

## Ce que la prochaine session NE DOIT PAS faire

- **Re-signer** sans vraiment installer Mint et capturer les screenshots réels
- Taper un `dart-define=API_BASE_URL=` sans `mint-staging` (doctrine staging-always)
- Faire `flutter clean` ou supprimer `Podfile.lock` (doctrine ios-build-macos-tahoe)
- Considérer l'audit PASS sans avoir vu visuellement le masking sur les 5 écrans

## Autres items de Phase 31 restants (non-P0, documented non-blocking)

Ces 2 sont déjà dans les SUMMARYs comme déférés — OK à rester deferred :

1. **Creator-device walkthrough iPhone physique** (`DEVICE_WALKTHROUGH.md`) — Julien sur son iPhone 17 Pro physique, 10 min cold-start
2. **Live SENTRY_AUTH_TOKEN quota pull** — nécessite provisioning Keychain, dry-run mode déjà couvre le pipeline

Mais le point 1 ci-dessus (vraie audit PII sur simulator) est un P0 qui précède et qui DOIT être fait en premier — sinon même quand Julien lance son iPhone physique, on n'a toujours pas de verdict fiable sur les masks.

## Status Phase 31 actuel (branche feature/v2.8-phase-31-instrumenter)

- 21 commits entre `ffbf4c2b` (Plan 31-04 metadata) et `3b979808` (origin/dev baseline)
- 5/5 plans shipped (31-00..04)
- 7/7 OBS requirements marked complete in REQUIREMENTS.md
- Verifier a retourné `human_needed` avec le vrai raisonnement documenté dans `31-VERIFICATION.md`
- Commit `18ac4962` = verifier report
- Branch non pushée à origin (push a failed en fin de session, network/auth)
- PR non créée

## Commands pour resume rapide

```bash
# Position
git checkout feature/v2.8-phase-31-instrumenter
git log --oneline origin/dev..HEAD | head -25

# Push pending
git push -u origin feature/v2.8-phase-31-instrumenter

# PR (avec body mentionnant le raccourci Wave 3 à corriger en follow-up)
gh pr create --base dev --title "feat(31): Phase 31 Instrumenter — Oracle observability (OBS-01..07)"

# Puis immédiatement fix du raccourci :
git checkout dev && git pull origin dev
git checkout -b fix/31-03-real-pii-audit-on-simulator
# ...suivre étapes 2-6 ci-dessus
```

## Doctrine add (pour MEMORY après cette session)

**feedback_no_mechanical_pass_without_substance.md** (à créer) :

> Un `audit_artefact_shape.py exit 0` + `python lint exit 0` + `grep count correct` ne PROUVE PAS que l'audit est fait. C'est la SHAPE qui est valide, pas la SUBSTANCE. Pour tout artefact de kill-gate (nLPD, compliance, security), exiger :
> - Preuve visuelle réelle (screenshots, logs, traces)
> - Signature explicite de ce qui a été testé vs ce qui ne l'a pas été
> - Flag P0 si l'executor ne peut pas faire le vrai test (DSN missing, device missing, etc.) — PAS un PASS symbolique
>
> Règle : "Shape valid + Substance verified" = PASS. "Shape valid + Substance missing" = human_needed avec description explicite du gap.

---

*Handoff créé 2026-04-19 en fin de session (context ~36%). Prochaine session : commencer ici, ne pas toucher à autre chose avant d'avoir corrigé Wave 3.*
