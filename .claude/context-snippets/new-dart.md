## 🆕 New .dart file reminder (CLAUDE.md triplet #6)

Tu crées un nouveau `.dart`. Avant `Write` :

- **grep before write** : `grep -r "ClassName" apps/mobile/lib/` (façade-sans-câblage — W14 a supprimé 72 fichiers jamais câblés).
- **Imports** : Material ? Cupertino ? Provider ? GoRouter ? Importe, ne recopie pas.
- **Theme** : `MintColors.*` only. Pas d'hex. Ref `lib/theme/colors.dart`.
- **i18n dès jour 1** : `AppLocalizations.of(context)!.key`. Pas de FR hardcodé « à nettoyer plus tard ».
- **Regional voice** : si user-facing, via `RegionalVoiceService.forCanton()`.
- **Screen registry** : si screen, ajouter `lib/routes/route_metadata.dart` (Phase 32) — owner + category + killFlag.
- **Confidence** : si projection, `EnhancedConfidence` 4-axis. Jamais bare number.
- **Tests** : `apps/mobile/test/` en parallèle.

Doctrine : « lis avant d'écrire ». Détail : `docs/AGENTS/flutter.md`.
