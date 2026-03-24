import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

typedef AdminMapLoader = Future<Map<String, dynamic>> Function({int days});
typedef AdminCsvLoader = Future<String> Function({int days});

class AdminObservabilityScreen extends StatefulWidget {
  final AdminMapLoader? observabilityLoader;
  final AdminMapLoader? onboardingQualityLoader;
  final AdminMapLoader? onboardingCohortsLoader;
  final AdminCsvLoader? csvLoader;

  const AdminObservabilityScreen({
    super.key,
    this.observabilityLoader,
    this.onboardingQualityLoader,
    this.onboardingCohortsLoader,
    this.csvLoader,
  });

  @override
  State<AdminObservabilityScreen> createState() =>
      _AdminObservabilityScreenState();
}

class _AdminObservabilityScreenState extends State<AdminObservabilityScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _obs = const {};
  Map<String, dynamic> _quality = const {};
  Map<String, dynamic> _cohorts = const {};
  int _days = 30;

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
      final results = await Future.wait<dynamic>([
        (widget.observabilityLoader ?? _defaultObservabilityLoader)(days: _days),
        (widget.onboardingQualityLoader ?? _defaultOnboardingQualityLoader)(
          days: _days,
        ),
        (widget.onboardingCohortsLoader ?? _defaultOnboardingCohortsLoader)(
          days: _days,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _obs = (results[0] as Map<String, dynamic>);
        _quality = (results[1] as Map<String, dynamic>);
        _cohorts = (results[2] as Map<String, dynamic>);
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

  Future<void> _copyCsvExport() async {
    final l10n = S.of(context)!;
    try {
      final csv = await (widget.csvLoader ?? _defaultCsvLoader)(days: _days);
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminObsCsvCopied)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.adminObsExportFailed}: $e')),
      );
    }
  }

  Future<Map<String, dynamic>> _defaultObservabilityLoader({int days = 30}) {
    return ApiService.getAdminObservability();
  }

  Future<Map<String, dynamic>> _defaultOnboardingQualityLoader({
    int days = 30,
  }) {
    return ApiService.getAdminOnboardingQuality(days: days);
  }

  Future<Map<String, dynamic>> _defaultOnboardingCohortsLoader({
    int days = 30,
  }) {
    return ApiService.getAdminOnboardingQualityCohorts(days: days);
  }

  Future<String> _defaultCsvLoader({int days = 30}) {
    return ApiService.exportAdminCohortsCsv(days: days);
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
          l10n.adminObsTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(l10n)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(MintSpacing.md),
                    children: [
                      MintEntrance(child: _buildHeaderControls(l10n)),
                      const SizedBox(height: MintSpacing.sm + 4),
                      MintEntrance(delay: const Duration(milliseconds: 100), child: _buildObsCard(l10n)),
                      const SizedBox(height: MintSpacing.sm + 4),
                      MintEntrance(delay: const Duration(milliseconds: 200), child: _buildQualityCard(l10n)),
                      const SizedBox(height: MintSpacing.sm + 4),
                      MintEntrance(delay: const Duration(milliseconds: 300), child: _buildCohortsCard(l10n)),
                      const SizedBox(height: MintSpacing.sm + 4),
                      MintEntrance(delay: const Duration(milliseconds: 400), child: Semantics(
                        label: l10n.adminObsExportCsv,
                        button: true,
                        child: OutlinedButton.icon(
                          onPressed: _copyCsvExport,
                          icon: const Icon(Icons.download_outlined),
                          label: Text(l10n.adminObsExportCsv),
                        ),
                      )),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError(S l10n) {
    return ListView(
      padding: const EdgeInsets.all(MintSpacing.md),
      children: [
        Container(
          padding: const EdgeInsets.all(MintSpacing.md),
          decoration: BoxDecoration(
            color: MintColors.error.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: MintColors.error.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            _error!,
            style: MintTextStyles.bodyMedium(color: MintColors.error),
          ),
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        Semantics(
          label: l10n.commonRetry,
          button: true,
          child: FilledButton(
            onPressed: _load,
            child: Text(l10n.commonRetry),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderControls(S l10n) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${l10n.adminObsWindowLabel}: $_days ${l10n.commonDays}',
            style: MintTextStyles.bodyMedium(
              color: MintColors.textSecondary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7j')),
            ButtonSegment(value: 30, label: Text('30j')),
            ButtonSegment(value: 90, label: Text('90j')),
          ],
          selected: {_days},
          onSelectionChanged: (values) {
            final selected = values.first;
            if (selected == _days) return;
            setState(() => _days = selected);
            _load();
          },
        ),
      ],
    );
  }

  Widget _buildObsCard(S l10n) {
    return _Card(
      title: l10n.adminObsAuthBilling,
      child: Wrap(
        spacing: MintSpacing.sm,
        runSpacing: MintSpacing.sm,
        children: [
          _chip('Users', '${_obs['users_total'] ?? 0}'),
          _chip('Verified', '${_obs['users_verified'] ?? 0}'),
          _chip('Unverified', '${_obs['users_unverified'] ?? 0}'),
          _chip('Locked now', '${_obs['login_states_locked_now'] ?? 0}'),
          _chip('Sub active', '${_obs['subscriptions_active_like'] ?? 0}'),
        ],
      ),
    );
  }

  Widget _buildQualityCard(S l10n) {
    final score = (_quality['quality_score'] as num?)?.toDouble() ?? 0;
    return _Card(
      title: l10n.adminObsOnboardingQuality,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${score.toStringAsFixed(1)} / 100',
            style: MintTextStyles.displayMedium().copyWith(fontSize: 28),
          ),
          const SizedBox(height: MintSpacing.sm),
          LinearProgressIndicator(
            value: (score / 100).clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Wrap(
            spacing: MintSpacing.sm,
            runSpacing: MintSpacing.sm,
            children: [
              _chip('Started', '${_quality['sessions_started'] ?? 0}'),
              _chip('Completed', '${_quality['sessions_completed'] ?? 0}'),
              _chip(
                'Completion',
                '${(_quality['completion_rate_pct'] ?? 0).toString()}%',
              ),
              _chip(
                'Avg step',
                '${(_quality['avg_step_duration_seconds'] ?? 0).toString()}s',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCohortsCard(S l10n) {
    final rows = (_cohorts['cohorts'] as List?)?.cast<Map>() ?? const [];
    return _Card(
      title: l10n.adminObsCohorts,
      child: rows.isEmpty
          ? Text(
              l10n.adminObsNoData,
              style: MintTextStyles.bodyMedium(),
            )
          : Column(
              children: rows.take(8).map((row) {
                final quality = (row['quality_score'] ?? 0).toString();
                final completion = (row['completion_rate_pct'] ?? 0).toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: MintSpacing.sm + 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${row['variant']} \u00b7 ${row['platform']}',
                          style: MintTextStyles.bodyMedium(
                            color: MintColors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '$completion% \u00b7 Q$quality',
                        style: MintTextStyles.bodyMedium(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _chip(String label, String value) {
    return MintSurface(
      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm + 2, vertical: 7),
      radius: 9,
      child: Text(
        '$label: $value',
        style: MintTextStyles.labelSmall(
          color: MintColors.textPrimary,
        ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;

  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return MintSurface(
      padding: const EdgeInsets.all(14),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
          ),
          const SizedBox(height: MintSpacing.sm + 2),
          child,
        ],
      ),
    );
  }
}
