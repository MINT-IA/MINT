/// Phase 53-03 — Tab 1 « Mes engagements & check-ins » surface.
///
/// Closes the « tool fires, persists, then disappears » UX gap caught by
/// Expert 5 in the post-Phase-52.2 panel: every `record_check_in` /
/// `show_commitment_card` chat tool persists silently and is then invisible
/// outside the chat bubble that produced it.
///
/// Reads two data sources:
///   * `CoachProfileProvider.profile.checkIns` — sync, in-memory; surfaced
///     immediately when the provider has loaded.
///   * `CommitmentService.getCommitments(status: 'active')` — async network
///     call; surfaced via FutureBuilder. Failure is silent (card hides the
///     commitments section rather than spamming an error).
///
/// Tap behavior: opens `/coach/chat`. Per `MonthlyCheckIn` model
/// (`coach_profile.dart:1187`) there is currently no `chatSessionId` field
/// to deep-link the originating conversation, so the tap falls back to a
/// generic resume. Adding `chatSessionId` is a follow-up plan (Phase 55+).
///
/// Empty-state contract: returns `SizedBox.shrink()` when BOTH sources are
/// empty. No « no data » placeholder — silent absence per Plan 53-03 spec.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/commitment_service.dart';
import 'package:mint_mobile/theme/colors.dart';

class CommitmentsAndCheckinsCard extends StatefulWidget {
  const CommitmentsAndCheckinsCard({
    super.key,
    this.commitmentService,
    this.maxItemsPerSection = 3,
  });

  /// Optional injection seam for tests.
  final CommitmentService? commitmentService;

  /// Number of items to show per section (commitments / check-ins).
  /// Older items are truncated; user can resume conversation to see all.
  final int maxItemsPerSection;

  @override
  State<CommitmentsAndCheckinsCard> createState() =>
      _CommitmentsAndCheckinsCardState();
}

class _CommitmentsAndCheckinsCardState
    extends State<CommitmentsAndCheckinsCard> {
  late final CommitmentService _service =
      widget.commitmentService ?? CommitmentService();

  late Future<List<Map<String, dynamic>>> _commitmentsFuture;

  @override
  void initState() {
    super.initState();
    _commitmentsFuture = _loadCommitments();
  }

  Future<List<Map<String, dynamic>>> _loadCommitments() async {
    try {
      return await _service.getCommitments(status: 'active');
    } catch (_) {
      // Silent failure: the card simply hides the commitments section.
      // The auth-failure path (no_auth) is the most common case for
      // anonymous users; surfacing the error would be noise.
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    if (l10n == null) return const SizedBox.shrink();

    final profile = context.watch<CoachProfileProvider>().profile;
    final checkIns = profile?.checkIns ?? const <MonthlyCheckIn>[];

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _commitmentsFuture,
      builder: (context, snapshot) {
        final commitments = snapshot.data ?? const <Map<String, dynamic>>[];
        if (commitments.isEmpty && checkIns.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.craie,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: MintColors.textMutedAaa.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (commitments.isNotEmpty) ...[
                  _SectionHeader(
                    title: l10n.aujourdhuiCommitmentsTitle,
                  ),
                  const SizedBox(height: 8),
                  ..._buildCommitmentRows(context, commitments, l10n),
                ],
                if (commitments.isNotEmpty && checkIns.isNotEmpty)
                  const SizedBox(height: 16),
                if (checkIns.isNotEmpty) ...[
                  _SectionHeader(
                    title: l10n.aujourdhuiCheckInsTitle,
                  ),
                  const SizedBox(height: 8),
                  ..._buildCheckInRows(context, checkIns, l10n),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildCommitmentRows(
    BuildContext context,
    List<Map<String, dynamic>> commitments,
    S l10n,
  ) {
    final shown = commitments.take(widget.maxItemsPerSection).toList();
    return shown
        .map(
          (c) => _ItemRow(
            icon: Icons.bookmark_border_rounded,
            text: _summarizeCommitment(c),
            relativeTime: _relativeTime(c['createdAt']?.toString()),
            onTap: () => _resumeConversation(context),
            semanticLabel: l10n.aujourdhuiResumeConversation,
          ),
        )
        .toList(growable: false);
  }

  List<Widget> _buildCheckInRows(
    BuildContext context,
    List<MonthlyCheckIn> checkIns,
    S l10n,
  ) {
    final sorted = [...checkIns]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final shown = sorted.take(widget.maxItemsPerSection).toList();
    return shown
        .map(
          (ci) => _ItemRow(
            icon: Icons.check_circle_outline_rounded,
            text: _summarizeCheckIn(ci),
            relativeTime: _relativeTime(ci.completedAt.toIso8601String()),
            onTap: () => _resumeConversation(context),
            semanticLabel: l10n.aujourdhuiResumeConversation,
          ),
        )
        .toList(growable: false);
  }

  String _summarizeCommitment(Map<String, dynamic> c) {
    final whenText = (c['whenText'] ?? '').toString();
    final ifThen = (c['ifThenText'] ?? '').toString();
    if (whenText.isNotEmpty && ifThen.isNotEmpty) {
      return '$whenText • $ifThen';
    }
    if (whenText.isNotEmpty) return whenText;
    if (ifThen.isNotEmpty) return ifThen;
    return (c['summary'] ?? '').toString();
  }

  String _summarizeCheckIn(MonthlyCheckIn ci) {
    final monthLabel = _monthLabel(ci.month);
    final total = ci.totalVersements;
    if (total > 0) {
      return '$monthLabel • ${total.toStringAsFixed(0)} CHF';
    }
    return monthLabel;
  }

  String _monthLabel(DateTime month) {
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    final idx = (month.month - 1).clamp(0, 11);
    return '${months[idx]} ${month.year}';
  }

  String _relativeTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) {
      return diff.inDays == 1
          ? 'il y a 1 jour'
          : 'il y a ${diff.inDays} jours';
    }
    if (diff.inHours >= 1) {
      return diff.inHours == 1
          ? 'il y a 1 h'
          : 'il y a ${diff.inHours} h';
    }
    return 'à l\'instant';
  }

  void _resumeConversation(BuildContext context) {
    context.push('/coach/chat');
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: MintColors.textPrimary,
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.icon,
    required this.text,
    required this.relativeTime,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final String text;
  final String relativeTime;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: MintColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: MintColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (relativeTime.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  relativeTime,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: MintColors.textMutedAaa,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
