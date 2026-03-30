import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P11-C  La Checklist 48h — nouveau job
//  Charte : L5 (1 action)
//  Source : LPP art. 3 (libre passage), OLP art. 1-3
// ────────────────────────────────────────────────────────────

class ChecklistItem {
  const ChecklistItem({
    required this.deadline,
    required this.action,
    required this.legalRef,
    this.emoji = '📋',
    this.consequence,
  });

  final String deadline;
  final String action;
  final String legalRef;
  final String emoji;
  final String? consequence;
}

class JobChangeChecklistWidget extends StatefulWidget {
  const JobChangeChecklistWidget({
    super.key,
    required this.items,
  });

  final List<ChecklistItem> items;

  @override
  State<JobChangeChecklistWidget> createState() => _JobChangeChecklistWidgetState();
}

class _JobChangeChecklistWidgetState extends State<JobChangeChecklistWidget> {
  late List<bool> _checked;

  @override
  void initState() {
    super.initState();
    _checked = List.filled(widget.items.length, false);
  }

  int get _completedCount => _checked.where((c) => c).length;
  double get _progress => widget.items.isEmpty ? 0 : _completedCount / widget.items.length;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: S.of(context)!.jobChangeChecklistSemantics,
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgress(),
                  const SizedBox(height: 16),
                  ...widget.items.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildCheckItem(e.key, e.value),
                  )),
                  const SizedBox(height: 12),
                  _buildCriticalAlert(),
                  const SizedBox(height: 16),
                  _buildDisclaimer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: MintColors.indigoBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.jobChangeChecklistTitle,
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  S.of(context)!.jobChangeChecklistSubtitle,
                  style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              S.of(context)!.jobChangeChecklistProgress(_completedCount, widget.items.length),
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '${(_progress * 100).round()}%',
              style: MintTextStyles.bodySmall(color: _progress == 1 ? MintColors.scoreExcellent : MintColors.primary).copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 8,
            backgroundColor: MintColors.lightBorder,
            valueColor: AlwaysStoppedAnimation<Color>(
              _progress == 1 ? MintColors.scoreExcellent : MintColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckItem(int index, ChecklistItem item) {
    final isDone = _checked[index];
    return GestureDetector(
      onTap: () => setState(() => _checked[index] = !_checked[index]),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDone
              ? MintColors.scoreExcellent.withValues(alpha: 0.07)
              : MintColors.appleSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDone
                ? MintColors.scoreExcellent.withValues(alpha: 0.3)
                : MintColors.lightBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isDone ? MintColors.scoreExcellent : MintColors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone ? MintColors.scoreExcellent : MintColors.lightBorder,
                  width: 2,
                ),
              ),
              child: isDone
                  ? const Icon(Icons.check, color: MintColors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: MintColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.deadline,
                          style: MintTextStyles.micro(color: MintColors.primary).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(item.emoji, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.action,
                    style: MintTextStyles.bodySmall(color: isDone ? MintColors.textSecondary : MintColors.textPrimary).copyWith(decoration: isDone ? TextDecoration.lineThrough : null, height: 1.4),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.legalRef,
                    style: MintTextStyles.micro(color: MintColors.textSecondary),
                  ),
                  if (item.consequence != null && !isDone) ...[
                    const SizedBox(height: 4),
                    Text(
                      '⚠️ ${item.consequence}',
                      style: MintTextStyles.micro(color: MintColors.scoreAttention),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriticalAlert() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔑', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.jobChangeChecklistAlertTitle,
                  style: MintTextStyles.bodySmall(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  S.of(context)!.jobChangeChecklistAlertBody,
                  style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      S.of(context)!.jobChangeChecklistDisclaimer,
      style: MintTextStyles.micro(color: MintColors.textSecondary),
    );
  }
}
