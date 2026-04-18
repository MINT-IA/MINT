# Wave E-PRIME Device Walkthrough — iPhone 17 Pro Simulator

Date : 2026-04-18
Device : iPhone 17 Pro simulator (UDID B03E429D-0422-4357-B754-536637D979F9)
Build : `flutter build ios --simulator --debug --no-codesign --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1`
Branche : `feature/wave-e-prime-facade-close` (tip f32330d8)
Objectif : vérifier que la suppression de ≈42K LOC (72 fichiers mobile + 4 backend) n'a pas cassé les flows touchés.

## Gate 1 — Build

iOS simulator build success après P4b fix (suppression de MintAlertObject dans
financial_report_screen_v2 + suppression de 2 tests intégration pour
infrastructure deleted).

```
Xcode build done. 9.5s
✓ Built build/ios/iphonesimulator/Runner.app
```

## Gate 2 — Cold launch landing

Écran 1 (`01-landing-post-waveE-prime.png`) :
- Wordmark MINT centré
- Tagline "Ta vie financière, en clair."
- Secondary "On éclaire. Tu décides."
- CTA button "Parle à Mint"
- Disclaimer LSFin
- Link "J'ai déjà un compte"

AX tree propre, 0 widget orphan détecté.

## Gate 3 — Coach chat ouverture silencieuse

Écran 2 (`02-coach-silent-post-waveE-prime.png`) après tap "Parle à Mint" :
- AppBar : Historique + Paramètres IA (boutons)
- Silent opener : "Tu veux en parler ?"
- 3 tone chips : Doux / Direct / Sans filtre
- Chat silent respecté (Wave 2 preservation)

Tap "Doux" → coach répond (screenshot 03-coach-after-doux-chip.png) : ton
preference enregistrée + première réponse streamée.

## Gate 4 — Home tab Aujourd'hui

Écran 4 (`04-home-tab-aujourdhui.png`) après tap bottom tab "Aujourd'hui" :
- CapDuJourBanner top : "Parle-moi de toi, ouvre le coach"
- Empty state : "Commence par parler au coach. Tes premières tensions
  apparaîtront ici."

Wave B-minimal CapDuJourBanner fonctionne — la suppression de
ContextualCardProvider n'a rien cassé puisqu'il n'a jamais eu de consumer.

Tap cap banner → re-navigation vers Coach chat (context.go). Wave B B1-fix-2
"cul-de-sac tap" fix préservé.

## Gate 5 — Bottom tabs

4 tabs détectés via AX tree :
- Aujourd'hui (y=760)
- Mon argent (y=760)
- Coach (y=760)
- Explorer (y=760)

Tab switching fonctionne. Aucun RSoD régression.

## Conclusion

Le delete massif Wave E-PRIME (42K LOC, 72 fichiers mobile + 4 backend) n'a
pas cassé les flows critiques. Landing + coach chat + home tab + tab nav
restent propres sur simulator. AX tree montre 0 widget orphan dans le rendu.

Preuve par device acquise. Wave E-PRIME prêt pour PR.
