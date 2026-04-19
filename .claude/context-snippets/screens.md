## 📱 Flutter screen reminder (CLAUDE.md triplets #1 #2 #5)

Tu édites un `.dart` sous `apps/mobile/lib/screens/`. Avant d'écrire :

- **i18n** : toute string user-facing via `AppLocalizations.of(context)!.key`. **JAMAIS** `Text('Bonjour')`.
- **Couleurs** : `MintColors.*` depuis `lib/theme/colors.dart`. **JAMAIS** `Color(0xFF...)`. 12 tokens core (DESIGN_SYSTEM.md §3.2).
- **Navigation** : `context.go('/path')` (GoRouter). **JAMAIS** `Navigator.push`.
- **State** : Provider (`ChangeNotifierProvider`). Pas de raw StatefulWidget pour cross-screen.
- **Accents FR 100%** : `creer → créer`, `eclairage → éclairage`, `securite → sécurité`.
- **Avant nouveau widget** : `grep -r "YourWidget" apps/mobile/lib/` (façade-sans-câblage).
- **Déprécié** : `MintGlassCard`, `MintPremiumButton` legacy, font `Outfit`.

Détail : `docs/AGENTS/flutter.md §2 + §8`.
