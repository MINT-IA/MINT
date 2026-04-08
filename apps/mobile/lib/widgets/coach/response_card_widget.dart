import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';

// ────────────────────────────────────────────────────────────
//  RESPONSE CARD WIDGET — V2 "Calm Narrative"
// ────────────────────────────────────────────────────────────
//
//  Principles (MINT_UX_GRAAL_MASTERPLAN.md §9 + §12):
//  - Narrative first, proof accessible, action ensuite
//  - 1 chiffre, 1 phrase, 1 CTA — lisible en 3 secondes
//  - Aucun diagnostic negatif sans levier
//  - Sources/alertes en panneau secondaire, pas exposes de force
//  - Tokens MintTextStyles, MintSpacing, MintColors uniquement
//
//  3 variantes:
//  - chat:    inline dans le coach, compact, cliquable
//  - sheet:   bottom sheet ou surface large, chiffre visible
//  - compact: minimal, titre + CTA seulement
//
//  Removed from V1:
//  - bordure gauche coloree
//  - badge "+X pts"
//  - largeur fixe 280
//  - GoogleFonts ad hoc
//  - source inline permanente
//  - alerte inline orange
// ────────────────────────────────────────────────────────────

/// Visual variant for ResponseCardWidget.
enum ResponseCardVariant {
  /// Inline in coach chat — compact narrative card.
  chat,

  /// Full surface — chiffre-choc visible, proof accessible.
  sheet,

  /// Minimal — title + subtitle + CTA only.
  compact,
}

/// Widget for a single ResponseCard.
///
/// State-of-the-art: Cleo-inspired calm narrative card.
/// Narrative → chiffre → CTA. Proof on demand.
class ResponseCardWidget extends StatelessWidget {
  final ResponseCard card;
  final ResponseCardVariant variant;

  /// Callback when CTA is tapped. Defaults to GoRouter push.
  final VoidCallback? onCtaTap;

  /// Optional confidence for the MTC slot. When non-null AND [isProjection]
  /// is true, MintTrameConfiance.inline is mounted at the bottom of the card
  /// (AESTH-07 MUJI 4-line grammar, line 4 = MTC). When null, no slot.
  ///
  /// Phase 4 Plan 04-02: the [ResponseCard] model does not yet carry a
  /// confidence field — callers pass `null` until Phase 8a wires the model.
  /// The null-safe fallback is a safe no-op (no MTC rendered).
  final EnhancedConfidence? confidence;

  /// Whether this response is a calculation/projection answer. Only projection
  /// answers get an MTC slot — chat replies and education content do not.
  /// See CONTEXT.md D-07.
  final bool isProjection;

  /// Optional voice level (from [resolveLevel]) to adapt MTC phrasing. The
  /// level never changes colors or timing — only the one-line summary wording.
  final VoiceLevel? audioTone;

  const ResponseCardWidget({
    super.key,
    required this.card,
    this.variant = ResponseCardVariant.sheet,
    this.onCtaTap,
    this.confidence,
    this.isProjection = false,
    this.audioTone,
  });

  /// Shortcut constructors
  const ResponseCardWidget.chat({
    super.key,
    required this.card,
    this.onCtaTap,
    this.confidence,
    this.isProjection = false,
    this.audioTone,
  }) : variant = ResponseCardVariant.chat;

  const ResponseCardWidget.compact({
    super.key,
    required this.card,
    this.onCtaTap,
    this.confidence,
    this.isProjection = false,
    this.audioTone,
  }) : variant = ResponseCardVariant.compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${card.title} — ${card.subtitle}',
      child: GestureDetector(
        onTap: () => _handleTap(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.all(
            variant == ResponseCardVariant.compact
                ? MintSpacing.sm + 4
                : MintSpacing.md,
          ),
          // DELETE #1 (S4 audit): shadow-on-shadow ornament removed. The
          // border-radius + card surface token is sufficient separation on
          // porcelaine (D-03.b).
          decoration: BoxDecoration(
            color: MintColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (variant) {
      case ResponseCardVariant.compact:
        return _buildCompact(context);
      case ResponseCardVariant.chat:
        return _buildChat(context);
      case ResponseCardVariant.sheet:
        return _buildSheet(context);
    }
  }

  // ── COMPACT: titre seul (audit S4 DELETE #3 + #4) ─────────
  //
  // DELETE #3: decorative icon container for compact variant removed —
  // the compact row is a minimal title+subtitle stack, no pill needed.
  // DELETE #4: chevron removed — the whole card is tappable, chevron
  // restates what the tap affordance already implies (D-03.c).

  Widget _buildCompact(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          card.title,
          style: MintTextStyles.titleMedium(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (card.subtitle.isNotEmpty)
          Text(
            card.subtitle,
            style: MintTextStyles.bodySmall(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  // ── CHAT: narrative card for coach inline ─────────────────

  Widget _buildChat(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title row
        Row(
          children: [
            _buildIcon(size: 28),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Text(
                card.title,
                style: MintTextStyles.titleMedium(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_hasDeadline) _buildDeadlinePill(),
          ],
        ),
        const SizedBox(height: MintSpacing.sm),

        // Subtitle / narrative
        Text(
          card.subtitle,
          style: MintTextStyles.bodyMedium(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        // Chiffre-choc (if meaningful)
        if (_hasPremierEclairage) ...[
          const SizedBox(height: MintSpacing.sm + 4),
          Text(
            card.premierEclairage.formatted,
            style: MintTextStyles.headlineMedium(
              color: MintColors.textPrimary,
            ),
          ),
        ],

        const SizedBox(height: MintSpacing.md),

        // CTA
        _buildCta(context),

        // MTC slot (AESTH-07 MUJI 4-line, line 4) — conditional per D-07.
        ..._buildMtcSlot(),
      ],
    );
  }

  // ── SHEET: full surface with proof layer ──────────────────
  //
  // MUJI 4-line grammar (AESTH-07, D-06): exactly 4 slots, no chrome between
  // them. Each slot is wrapped in `_S4BodySlot` with a Semantics label
  // `s4-slot-N` so the microtypography test can count them precisely.
  //   (1) label/category   — header row (icon + title + subtitle + deadline)
  //   (2) current state    — premier eclairage (number + explanation)
  //   (3) without change   — MTC slot (per D-07) OR silent placeholder
  //   (4) next action      — CTA + optional proof access
  //
  // AESTH-03 Aesop rule: sentence carries rhythm, not the number — the
  // premier eclairage renders at bodyLarge w500, NOT displayMedium.

  Widget _buildSheet(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Slot 1 — label/category ──
        _S4BodySlot(
          role: 's4-slot-1',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(size: 36),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: MintTextStyles.titleMedium(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      card.subtitle,
                      style: MintTextStyles.bodySmall(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_hasDeadline) ...[
                const SizedBox(width: MintSpacing.sm),
                _buildDeadlinePill(),
              ],
            ],
          ),
        ),

        // ── Slot 2 — current state (the number, demoted) ──
        _S4BodySlot(
          role: 's4-slot-2',
          topGap: MintSpacing.md + 4,
          child: _hasPremierEclairage
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // AESTH-03 Aesop rule: sentence carries rhythm, not the
                    // number. bodyLarge w500 instead of displayMedium.
                    Text(
                      card.premierEclairage.formatted,
                      style: MintTextStyles.bodyLarge(
                        color: MintColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                    if (card.premierEclairage.explanation.isNotEmpty) ...[
                      const SizedBox(height: MintSpacing.xs),
                      Text(
                        card.premierEclairage.explanation,
                        style: MintTextStyles.bodySmall(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),

        // ── Slot 3 — without change (MTC per D-07) ──
        _S4BodySlot(
          role: 's4-slot-3',
          topGap: (confidence != null && isProjection) ? MintSpacing.md : 0,
          child: (confidence != null && isProjection)
              ? MintTrameConfiance.inline(
                  confidence: confidence!,
                  bloomStrategy: BloomStrategy.firstAppearance,
                  audioTone: audioTone,
                  isTopOfList: false,
                )
              : const SizedBox.shrink(),
        ),

        // ── Slot 4 — next action ──
        _S4BodySlot(
          role: 's4-slot-4',
          topGap: MintSpacing.md + 4,
          child: Row(
            children: [
              Expanded(child: _buildCta(context)),
              if (_hasProof) ...[
                const SizedBox(width: MintSpacing.sm),
                _buildProofButton(context),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── MTC SLOT ──────────────────────────────────────────────
  //
  // Plan 04-02 / CONTEXT.md D-07: mount `MintTrameConfiance.inline` at the
  // bottom of the card body when (confidence != null && isProjection).
  // The `BloomStrategy.firstAppearance` is used because S4 is a standalone
  // surface (per CONTEXT.md D-03 / D-07 — feeds use onlyIfTopOfList).
  //
  // When the response is not a projection or no confidence is available,
  // nothing is rendered (safe no-op). The ResponseCard model does not yet
  // carry a confidence field — this is intentional: Phase 8a wires the
  // model field, Phase 4 ships the slot infrastructure.

  List<Widget> _buildMtcSlot() {
    final c = confidence;
    if (c == null || !isProjection) return const [];
    return [
      const SizedBox(height: MintSpacing.sm + 4),
      MintTrameConfiance.inline(
        confidence: c,
        bloomStrategy: BloomStrategy.firstAppearance,
        audioTone: audioTone,
        isTopOfList: false,
      ),
    ];
  }

  // ── SHARED COMPONENTS ─────────────────────────────────────

  Widget _buildIcon({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        card.icon ?? _typeIcon,
        size: size * 0.5,
        color: MintColors.primary,
      ),
    );
  }

  Widget _buildDeadlinePill() {
    final badge = card.deadlineBadge;
    if (badge == null) return const SizedBox.shrink();

    final isUrgent = card.urgency == CardUrgency.high;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        // AESTH-06 per AUDIT_RETRAIT S4 (D-04 one-color-one-meaning:
        // urgent deadline = verifiable fact requiring attention → warningAaa)
        color: isUrgent
            ? MintColors.warningAaa.withValues(alpha: 0.08)
            : MintColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      // DELETE #2 (S4 audit): schedule Icon removed. The badge Text
      // ("dans N jours" / "J-N" / "Demain") already carries the time
      // semantic — the icon is redundant ornament (D-03.c).
      child: Text(
        badge,
        style: MintTextStyles.labelSmall(
          // AESTH-06 per AUDIT_RETRAIT S4 (D-04: warningAaa = only semantic color)
          color: isUrgent ? MintColors.warningAaa : MintColors.primary,
        ),
      ),
    );
  }

  Widget _buildCta(BuildContext context) {
    return Semantics(
      button: true,
      label: card.cta.label,
      child: GestureDetector(
        onTap: () => _handleTap(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.md,
            vertical: MintSpacing.sm + 4,
          ),
          decoration: BoxDecoration(
            color: MintColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  card.cta.label,
                  style: MintTextStyles.bodySmall(color: MintColors.white)
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: MintColors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Proof accessible" button — opens sources + alertes in a bottom sheet.
  /// Narrative first, proof on demand (MINT_UX_GRAAL_MASTERPLAN §9).
  Widget _buildProofButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showProofSheet(context),
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.sm + 4),
        decoration: BoxDecoration(
          color: MintColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.info_outline_rounded,
          size: 18,
          // AESTH-05 per AUDIT_RETRAIT S4 R3 (D-03 swap map)
          color: MintColors.textMutedAaa,
        ),
      ),
    );
  }

  void _showProofSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DELETE #5 (S4 audit): drag handle Container removed.
            // Native bottom sheets already expose a drag affordance; the
            // explicit handle is ornament (D-03.b).
            Text(card.title, style: MintTextStyles.titleMedium()),
            const SizedBox(height: MintSpacing.md),

            // DELETE #6 (S4 audit): "Sources" label Text removed — the
            // micro-text source rows below self-explain as citation list.
            if (card.sources.isNotEmpty) ...[
              ...card.sources.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(s, style: MintTextStyles.micro()),
                ),
              ),
              const SizedBox(height: MintSpacing.md),
            ],

            // Alertes
            if (card.alertes.isNotEmpty) ...[
              ...card.alertes.map(
                (a) => Container(
                  margin: const EdgeInsets.only(bottom: MintSpacing.sm),
                  padding: const EdgeInsets.all(MintSpacing.sm + 4),
                  decoration: BoxDecoration(
                    // AESTH-06 per AUDIT_RETRAIT S4 R5 (D-04 warningAaa)
                    color: MintColors.warningAaa.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        // AESTH-06 per AUDIT_RETRAIT S4 R5 (D-04 warningAaa)
                        color: MintColors.warningAaa.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: MintSpacing.sm),
                      Expanded(
                        child: Text(
                          a,
                          style: MintTextStyles.bodySmall(
                            // AESTH-05 per AUDIT_RETRAIT S4 R6 (D-03 swap map)
                            color: MintColors.textSecondaryAaa,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Disclaimer
            if (card.disclaimer.isNotEmpty) ...[
              const SizedBox(height: MintSpacing.sm),
              Text(card.disclaimer, style: MintTextStyles.micro()),
            ],

            const SizedBox(height: MintSpacing.md),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    if (onCtaTap != null) {
      onCtaTap!();
    } else {
      context.push(card.cta.route);
    }
  }

  // ── COMPUTED ──────────────────────────────────────────────

  bool get _hasPremierEclairage => card.premierEclairage.value != 0;
  bool get _hasDeadline => card.deadlineBadge != null;
  bool get _hasProof =>
      card.sources.isNotEmpty ||
      card.alertes.isNotEmpty ||
      card.disclaimer.isNotEmpty;

  IconData get _typeIcon => switch (card.type) {
        ResponseCardType.pillar3a => Icons.savings_rounded,
        ResponseCardType.lppBuyback => Icons.account_balance_rounded,
        ResponseCardType.replacementRate => Icons.trending_up_rounded,
        ResponseCardType.renteVsCapital => Icons.compare_arrows_rounded,
        ResponseCardType.avsGap => Icons.verified_user_rounded,
        ResponseCardType.taxOptimization => Icons.receipt_long_rounded,
        ResponseCardType.coupleAlert => Icons.family_restroom_rounded,
        ResponseCardType.patrimoine => Icons.account_balance_wallet_rounded,
        ResponseCardType.mortgage => Icons.home_rounded,
        ResponseCardType.independant => Icons.business_center_rounded,
      };
}

/// Scrollable strip of ResponseCards — used in coach chat.
///
/// V2: uses chat variant by default. Flexible width.
class ResponseCardStrip extends StatelessWidget {
  final List<ResponseCard> cards;
  final ResponseCardVariant variant;

  const ResponseCardStrip({
    super.key,
    required this.cards,
    this.variant = ResponseCardVariant.chat,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    if (cards.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
        child: ResponseCardWidget(card: cards.first, variant: variant),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 75% of available width, minimum 260, maximum 320.
        final cardWidth = (constraints.maxWidth * 0.75).clamp(260.0, 320.0);
        return SizedBox(
          height: _estimateHeight(),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
            itemCount: cards.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: MintSpacing.sm + 4),
            itemBuilder: (_, index) => SizedBox(
              width: cardWidth,
              child: ResponseCardWidget(card: cards[index], variant: variant),
            ),
          ),
        );
      },
    );
  }

  double _estimateHeight() {
    switch (variant) {
      case ResponseCardVariant.compact:
        return 72;
      case ResponseCardVariant.chat:
        return _hasPremierEclairage ? 200 : 160;
      case ResponseCardVariant.sheet:
        return _hasPremierEclairage ? 260 : 200;
    }
  }

  bool get _hasPremierEclairage =>
      cards.any((c) => c.premierEclairage.value != 0);
}

/// MUJI 4-line grammar slot wrapper (AESTH-07 / D-06).
///
/// The S4 sheet body Column must contain exactly 4 direct children in a
/// fixed order: label, current state, without-change (MTC), next action.
/// Each slot tags itself with a `Semantics(label: 's4-slot-N')` so the
/// microtypography test can count slots deterministically.
///
/// `topGap` is the rhythm gap before the slot (omitted for slot 1 or when
/// the slot is empty). Always a 4pt-grid multiple.
class _S4BodySlot extends StatelessWidget {
  final String role;
  final Widget child;
  final double topGap;

  const _S4BodySlot({
    required this.role,
    required this.child,
    this.topGap = 0,
  });

  @override
  Widget build(BuildContext context) {
    final body = KeyedSubtree(
      key: ValueKey<String>(role),
      child: child,
    );
    if (topGap == 0) return body;
    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: body,
    );
  }
}
