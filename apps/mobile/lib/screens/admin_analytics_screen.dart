import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// Admin analytics dashboard — shows event summary + conversion funnel.
///
/// Route: /profile/admin-analytics
/// Access: authenticated admin only (backend enforces via require_current_user).
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  bool _loading = true;
  String? _error;
  int _days = 30;

  // Summary data
  int _totalEvents = 0;
  int _uniqueSessions = 0;
  Map<String, dynamic> _byCategory = {};
  Map<String, dynamic> _byScreen = {};

  // Funnel data
  List<Map<String, dynamic>> _funnelSteps = [];

  static const _funnelStepNames =
      'onboarding_minimal_started,onboarding_minimal_submitted,'
      'chiffre_choc_viewed,dashboard_viewed,paywall_shown,paywall_conversion';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.get('/analytics/summary?days=$_days'),
        ApiService.get('/analytics/funnel?steps=$_funnelStepNames&days=$_days'),
      ]);

      final summary = results[0];
      final funnel = results[1];

      if (!mounted) return;
      setState(() {
        _totalEvents = (summary['totalEvents'] ?? summary['total_events'] ?? 0) as int;
        _uniqueSessions = (summary['uniqueSessions'] ?? summary['unique_sessions'] ?? 0) as int;
        _byCategory = (summary['eventsByCategory'] ?? summary['events_by_category'] ?? {}) as Map<String, dynamic>;
        _byScreen = (summary['eventsByScreen'] ?? summary['events_by_screen'] ?? {}) as Map<String, dynamic>;

        final steps = funnel['steps'] as List<dynamic>? ?? [];
        _funnelSteps = steps.cast<Map<String, dynamic>>();

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.white,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        elevation: 0,
        title: Text(
          l10n.adminAnalyticsTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 60),
                child: CircularProgressIndicator(),
              ),
            )
          : _error != null
              ? _buildError(l10n)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(MintSpacing.lg - 4),
                  child: _buildContent(l10n),
                ),
    );
  }

  Widget _buildError(S l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: MintSpacing.xxl - 8),
            const Icon(Icons.cloud_off_rounded, size: 48, color: MintColors.textMuted),
            const SizedBox(height: MintSpacing.md),
            Text(
              l10n.adminAnalyticsLoadError,
              style: MintTextStyles.titleMedium(),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              _error!,
              style: MintTextStyles.bodySmall(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MintSpacing.lg),
            Semantics(
              label: l10n.adminAnalyticsRetry,
              button: true,
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.adminAnalyticsRetry),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(S l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period selector
        _buildPeriodSelector(),
        const SizedBox(height: MintSpacing.lg),

        // KPI cards
        _buildKpiRow(l10n),
        const SizedBox(height: MintSpacing.lg),

        // Funnel
        _buildSectionTitle(l10n.adminAnalyticsFunnel),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildFunnel(l10n),
        const SizedBox(height: MintSpacing.lg),

        // Events by screen
        _buildSectionTitle(l10n.adminAnalyticsByScreen),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildBreakdownCard(_byScreen, l10n),
        const SizedBox(height: MintSpacing.lg),

        // Events by category
        _buildSectionTitle(l10n.adminAnalyticsByCategory),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildBreakdownCard(_byCategory, l10n),
        const SizedBox(height: MintSpacing.xxl - 8),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        for (final d in [7, 14, 30, 90])
          Padding(
            padding: const EdgeInsets.only(right: MintSpacing.sm),
            child: ChoiceChip(
              label: Text('${d}j'),
              selected: _days == d,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _days = d);
                  _load();
                }
              },
              selectedColor: MintColors.primary.withValues(alpha: 0.12),
              labelStyle: MintTextStyles.bodySmall(
                color: _days == d ? MintColors.primary : MintColors.textSecondary,
              ).copyWith(
                fontWeight: _days == d ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        const Spacer(),
        Semantics(
          label: 'Rafraîchir',
          button: true,
          child: IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            color: MintColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiRow(S l10n) {
    return Row(
      children: [
        Expanded(child: _buildKpiCard(l10n.adminAnalyticsSessions, '$_uniqueSessions', Icons.people_outline_rounded)),
        const SizedBox(width: MintSpacing.sm + 4),
        Expanded(child: _buildKpiCard(l10n.adminAnalyticsEvents, '$_totalEvents', Icons.touch_app_rounded)),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MintColors.primary, size: 24),
          const SizedBox(height: MintSpacing.sm + 4),
          Text(
            value,
            style: MintTextStyles.displayMedium().copyWith(fontSize: 28),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            label,
            style: MintTextStyles.bodySmall(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: MintTextStyles.titleMedium(),
    );
  }

  Widget _buildFunnel(S l10n) {
    if (_funnelSteps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(MintSpacing.lg - 4),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          l10n.adminAnalyticsNoFunnel,
          style: MintTextStyles.bodyMedium(),
        ),
      );
    }

    final firstCount = (_funnelSteps.first['count'] as int?) ?? 1;

    return Container(
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        children: _funnelSteps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          final name = _readableName(step['stepName'] ?? step['step_name'] ?? '');
          final count = (step['count'] as int?) ?? 0;
          final rate = step['conversionRate'] ?? step['conversion_rate'];
          final barFraction = firstCount > 0 ? count / firstCount : 0.0;
          final isLast = i == _funnelSteps.length - 1;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md, vertical: MintSpacing.sm + 4),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(bottom: BorderSide(color: MintColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '$count',
                      style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
                    ),
                    if (rate != null) ...[
                      const SizedBox(width: MintSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: _rateColor(rate).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(rate as num).toStringAsFixed(0)}%',
                          style: MintTextStyles.labelSmall(
                            color: _rateColor(rate),
                          ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: barFraction.clamp(0.0, 1.0),
                    backgroundColor: MintColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      MintColors.primary.withValues(alpha: 0.4 + 0.6 * barFraction),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBreakdownCard(Map<String, dynamic> data, S l10n) {
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(MintSpacing.lg - 4),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          l10n.adminAnalyticsNoData,
          style: MintTextStyles.bodyMedium(),
        ),
      );
    }

    // Sort by count descending
    final entries = data.entries.toList()
      ..sort((a, b) => ((b.value as int?) ?? 0).compareTo((a.value as int?) ?? 0));

    return Container(
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        children: entries.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final isLast = i == entries.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md, vertical: MintSpacing.sm + 2),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(bottom: BorderSide(color: MintColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _readableName(e.key),
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${e.value}',
                  style: MintTextStyles.titleMedium().copyWith(fontSize: 14),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _rateColor(num rate) {
    if (rate >= 60) return MintColors.success;
    if (rate >= 30) return MintColors.warning;
    return MintColors.error;
  }

  /// Convert snake_case event name to readable label.
  String _readableName(String name) {
    return name
        .replaceAll('_', ' ')
        .replaceFirstMapped(RegExp(r'^[a-z]'), (m) => m[0]!.toUpperCase());
  }
}
