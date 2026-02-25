import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/theme/colors.dart';

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
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Analytics',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [MintColors.primary, MintColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _error != null
                      ? _buildError()
                      : _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.cloud_off_rounded, size: 48, color: MintColors.textMuted),
        const SizedBox(height: 16),
        Text(
          'Impossible de charger les analytics',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _error!,
          style: GoogleFonts.inter(fontSize: 13, color: MintColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Reessayer'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period selector
        _buildPeriodSelector(),
        const SizedBox(height: 24),

        // KPI cards
        _buildKpiRow(),
        const SizedBox(height: 24),

        // Funnel
        _buildSectionTitle('Funnel de conversion'),
        const SizedBox(height: 12),
        _buildFunnel(),
        const SizedBox(height: 24),

        // Events by screen
        _buildSectionTitle('Events par ecran'),
        const SizedBox(height: 12),
        _buildBreakdownCard(_byScreen),
        const SizedBox(height: 24),

        // Events by category
        _buildSectionTitle('Events par categorie'),
        const SizedBox(height: 12),
        _buildBreakdownCard(_byCategory),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        for (final d in [7, 14, 30, 90])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${d}j'),
              selected: _days == d,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _days = d);
                  _load();
                }
              },
              selectedColor: MintColors.primary.withAlpha(30),
              labelStyle: GoogleFonts.inter(
                fontWeight: _days == d ? FontWeight.w600 : FontWeight.w400,
                color: _days == d ? MintColors.primary : MintColors.textSecondary,
              ),
            ),
          ),
        const Spacer(),
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          color: MintColors.textSecondary,
        ),
      ],
    );
  }

  Widget _buildKpiRow() {
    return Row(
      children: [
        Expanded(child: _buildKpiCard('Sessions', '$_uniqueSessions', Icons.people_outline_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _buildKpiCard('Events', '$_totalEvents', Icons.touch_app_rounded)),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MintColors.primary, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: MintColors.textPrimary,
      ),
    );
  }

  Widget _buildFunnel() {
    if (_funnelSteps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Pas encore de donnees de funnel.',
          style: GoogleFonts.inter(color: MintColors.textMuted),
        ),
      );
    }

    final firstCount = (_funnelSteps.first['count'] as int?) ?? 1;

    return Container(
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(bottom: BorderSide(color: MintColors.lightBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '$count',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    if (rate != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _rateColor(rate).withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(rate as num).toStringAsFixed(0)}%',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _rateColor(rate),
                          ),
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
                    backgroundColor: MintColors.lightBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      MintColors.primary.withAlpha((255 * (0.4 + 0.6 * barFraction)).round()),
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

  Widget _buildBreakdownCard(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Pas encore de donnees.',
          style: GoogleFonts.inter(color: MintColors.textMuted),
        ),
      );
    }

    // Sort by count descending
    final entries = data.entries.toList()
      ..sort((a, b) => ((b.value as int?) ?? 0).compareTo((a.value as int?) ?? 0));

    return Container(
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: entries.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final isLast = i == entries.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(bottom: BorderSide(color: MintColors.lightBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _readableName(e.key),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${e.value}',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _rateColor(num rate) {
    if (rate >= 60) return MintColors.scoreExcellent;
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
