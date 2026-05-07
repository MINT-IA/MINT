// ────────────────────────────────────────────────────────────────────
//  BetaProgramDisclosureSheet — first-launch beta disclosure
// ────────────────────────────────────────────────────────────────────
//
//  Per Apple App Store Review Guideline 5.1.1 (data collection
//  consent) + 1.2 (developer responsibility for beta content) +
//  TestFlight beta review criteria : MINT must inform first-launch
//  users that the app is in beta, what's expected of testers, and
//  what data is collected before any LLM call.
//
//  Per FINMA fintech sandbox + the Triage Expert verdict
//  (.planning/phases/54-testflight-gate-closure/54-VERIFICATION-REPORT.html
//  panel synthesis 2026-05-03) :
//   « MINT est en test, aucun conseil financier, aucune donnée
//     bancaire stockée chez nous, vos données restent sur l'appareil
//     sauf opt-in »
//
//  Design — minimal modal sheet on top of the landing screen :
//   • One-shot per device (SharedPreferences flag).
//   • Calm Handoff 2 voice — Fraunces italic em on key words.
//   • Single CTA « Je comprends, on y va » dismisses.
//   • A11y semantics with announced label for screen readers.
//
//  BUG-W2026-02 (2026-05-07) — the secondary « En savoir plus » link
//  was removed : it deeplinked to https://mint.ch/privacy via Safari
//  but the destination has no actual « About MINT en test » article,
//  so testers / journalists landed on a generic mint.ch page and lost
//  trust. The 4-bullet content (no advice, no bank, data local) +
//  semantics label are self-contained and explanatory enough.
//
//  Usage :
//   await BetaProgramDisclosureSheet.maybeShow(context);
//  Returns immediately if already acknowledged this device.
// ────────────────────────────────────────────────────────────────────

library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

const String _kBetaDisclosureSeenKey = 'mint_beta_disclosure_seen';

/// First-launch beta disclosure sheet. One-shot per device install.
/// Apple TestFlight beta review + FINMA fintech sandbox compliance.
class BetaProgramDisclosureSheet extends StatelessWidget {
  const BetaProgramDisclosureSheet({super.key});

  /// Show the sheet if it hasn't been acknowledged on this device yet.
  /// No-op when the SharedPreferences flag is already set.
  ///
  /// Returns true if the sheet was shown (and the user dismissed it),
  /// false if already acked / context unmounted / disabled via dart-define.
  ///
  /// Phase 83 (v2.11) SIMH-03 — `--dart-define=MINT_DISABLE_BETA_MODAL=true`
  /// short-circuits the modal entirely, bypassing the SharedPreferences
  /// flag check so walker runs (which `simctl erase` between archetypes,
  /// resetting the flag) don't have to dismiss it manually. Walker passes
  /// this flag in its `flutter build` invocation. NOT gated by
  /// `kReleaseMode` — only available when the build explicitly opts in.
  static Future<bool> maybeShow(BuildContext context) async {
    if (const bool.fromEnvironment('MINT_DISABLE_BETA_MODAL')) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_kBetaDisclosureSeenKey) ?? false;
    if (seen) return false;
    if (!context.mounted) return false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BetaProgramDisclosureSheet(),
    );
    return true;
  }

  /// Mark the disclosure as acknowledged. Public so callers can
  /// re-trigger the sheet for testing or QA verification.
  static Future<void> markAcknowledged() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBetaDisclosureSeenKey, true);
  }

  /// Reset the flag (test helper / settings « show me again » CTA).
  @visibleForTesting
  static Future<void> resetForTest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBetaDisclosureSeenKey);
  }

  Future<void> _onAcknowledge(BuildContext context) async {
    await markAcknowledged();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    // Handoff 2 alignment 2026-05-03 :
    //  - sheet bg : porcelaineHero (#F4F1EC) au lieu de craie cool
    //  - hairline : borderSubtle (#E8E4DE) warm
    //  - eyebrow : mintForest (#2F5F3F) signal vert handoff 2 (pas corail)
    //  - bullets « ▪ » : sauge (#B8C9B4) calme positif
    //  - primary CTA : inkPrimary (#1A1A1A) warm près-noir
    return Semantics(
      container: true,
      label: l.betaDisclosureSemanticsLabel,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: MintColors.porcelaineHero,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle — warm hairline.
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: MintColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Eyebrow — uppercase, deep forest signal (Handoff 2).
              Text(
                l.betaDisclosureEyebrow,
                style: MintTextStyles.labelMedium(
                  color: MintColors.mintForest,
                ).copyWith(
                  fontSize: 10.5,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              // Headline — editorial Fraunces italic em on warm ink.
              Text.rich(
                TextSpan(
                  style: MintTextStyles.editorialLarge(
                    color: MintColors.inkPrimary,
                  ).copyWith(height: 1.3),
                  children: [
                    TextSpan(text: l.betaDisclosureHeadlinePrefix),
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: l.betaDisclosureHeadlineEm,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                    TextSpan(text: l.betaDisclosureHeadlineSuffix),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Bullets — sauge calme positif sur tous les points.
              _bulletPoint(l.betaDisclosureBulletNoAdvice),
              const SizedBox(height: 6),
              _bulletPoint(l.betaDisclosureBulletNoBank),
              const SizedBox(height: 6),
              _bulletPoint(l.betaDisclosureBulletDataLocal),
              const SizedBox(height: 20),
              // Primary CTA — warm near-black ink (Handoff 2 ink-primary).
              FilledButton(
                onPressed: () => _onAcknowledge(context),
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.inkPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  l.betaDisclosureCta,
                  style: MintTextStyles.titleMedium(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bulletPoint(String text) {
    // Per Handoff 2 invariant : aucun emoji. For bullets, use « ▪ ».
    // Sauge positif Handoff 2 — calme, pas alerte.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5, right: 8),
          child: Text(
            '▪',
            style: MintTextStyles.bodySmall(
              color: MintColors.mintForest,
            ).copyWith(fontSize: 12, height: 1.0),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: MintTextStyles.bodyMedium(
              color: MintColors.textSecondaryAaa,
            ).copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}
