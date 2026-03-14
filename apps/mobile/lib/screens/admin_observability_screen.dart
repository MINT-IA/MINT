import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/theme/colors.dart';

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
        SnackBar(
          content: Text(l10n.adminObsCsvCopied),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.adminObsExportFailed}\u00a0: $e'),
        ),
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
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.background,
        title: Text(
          l10n.adminObsTitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeaderControls(),
                      const SizedBox(height: 12),
                      _buildObsCard(),
                      const SizedBox(height: 12),
                      _buildQualityCard(),
                      const SizedBox(height: 12),
                      _buildCohortsCard(),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _copyCsvExport,
                        icon: const Icon(Icons.download_outlined),
                        label: Text(l10n.adminObsExportCsv),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MintColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _error!,
            style: GoogleFonts.inter(color: MintColors.error),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _load,
          child: Text(S.of(context)!.commonRetry),
        ),
      ],
    );
  }

  Widget _buildHeaderControls() {
    final s = S.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Text(
            '${s.adminObsWindowLabel}\u00a0: $_days ${s.commonDays}',
            style: GoogleFonts.inter(
              color: MintColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 7, label: Text(s.adminObsSegment7j)),
            ButtonSegment(value: 30, label: Text(s.adminObsSegment30j)),
            ButtonSegment(value: 90, label: Text(s.adminObsSegment90j)),
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

  Widget _buildObsCard() {
    final s = S.of(context)!;
    return _Card(
      title: s.adminObsAuthBilling,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip(s.adminObsUsers, '${_obs['users_total'] ?? 0}'),
          _chip(s.adminObsVerified, '${_obs['users_verified'] ?? 0}'),
          _chip(s.adminObsUnverified, '${_obs['users_unverified'] ?? 0}'),
          _chip(s.adminObsLockedNow, '${_obs['login_states_locked_now'] ?? 0}'),
          _chip(s.adminObsSubActive, '${_obs['subscriptions_active_like'] ?? 0}'),
        ],
      ),
    );
  }

  Widget _buildQualityCard() {
    final s = S.of(context)!;
    final score = (_quality['quality_score'] as num?)?.toDouble() ?? 0;
    return _Card(
      title: s.adminObsOnboardingQuality,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${score.toStringAsFixed(1)} / 100',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (score / 100).clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(s.adminObsStarted, '${_quality['sessions_started'] ?? 0}'),
              _chip(s.adminObsCompleted, '${_quality['sessions_completed'] ?? 0}'),
              _chip(
                s.adminObsCompletion,
                '${(_quality['completion_rate_pct'] ?? 0).toString()}\u00a0%',
              ),
              _chip(
                s.adminObsAvgStep,
                '${(_quality['avg_step_duration_seconds'] ?? 0).toString()}s',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCohortsCard() {
    final s = S.of(context)!;
    final rows = (_cohorts['cohorts'] as List?)?.cast<Map>() ?? const [];
    return _Card(
      title: s.adminObsCohortsTitle,
      child: rows.isEmpty
          ? Text(
              s.adminObsNoData,
              style: GoogleFonts.inter(color: MintColors.textSecondary),
            )
          : Column(
              children: rows.take(8).map((row) {
                final quality = (row['quality_score'] ?? 0).toString();
                final completion = (row['completion_rate_pct'] ?? 0).toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${row['variant']} · ${row['platform']}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '$completion% · Q$quality',
                        style: GoogleFonts.inter(color: MintColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: MintColors.border),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
