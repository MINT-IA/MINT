// Dev-only admin surface per D-03 + D-10 (CONTEXT v4).
// English-only by executor discretion — no i18n/ARB keys.
// Phase 34 no_hardcoded_fr.py MUST exempt lib/screens/admin/**
// (TODO: add exemption when Phase 34 plan ships lint-config.yaml).

/// Phase 32 MAP-02b — pure schema viewer for the 147-entry registry.
///
/// **Contract (D-06 v4):**
/// - Data source: `kRouteRegistry` (static const) + local FeatureFlags read.
/// - NO Sentry live health (use `./tools/mint-routes health` terminal).
/// - NO snapshot JSON read (iOS sandbox makes cross-filesystem share unreliable).
/// - NO backend call (D-10 local gates only).
///
/// **Access log (D-09 §4):** mount emits `mint.admin.routes.viewed`
/// breadcrumb with aggregates only (route_count, feature_flags_enabled_count).
library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/routes/route_metadata.dart';
import 'package:mint_mobile/routes/route_owner.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/sentry_breadcrumbs.dart';
import 'package:mint_mobile/theme/colors.dart';

class RoutesRegistryScreen extends StatefulWidget {
  const RoutesRegistryScreen({super.key});

  @override
  State<RoutesRegistryScreen> createState() => _RoutesRegistryScreenState();
}

class _RoutesRegistryScreenState extends State<RoutesRegistryScreen> {
  late final Map<RouteOwner, List<RouteMeta>> _grouped;
  late final int _enabledFlagCount;

  @override
  void initState() {
    super.initState();
    _grouped = _groupByOwner(kRouteRegistry);
    _enabledFlagCount = _countEnabledFlags();
    // D-09 §4 — aggregates only, no PII, no path.
    MintBreadcrumbs.adminRoutesViewed(
      routeCount: kRouteRegistry.length,
      featureFlagsEnabledCount: _enabledFlagCount,
      snapshotAgeMinutes: null, // N/A: schema viewer has no snapshot
    );
  }

  Map<RouteOwner, List<RouteMeta>> _groupByOwner(Map<String, RouteMeta> src) {
    final out = <RouteOwner, List<RouteMeta>>{};
    for (final meta in src.values) {
      out.putIfAbsent(meta.owner, () => []).add(meta);
    }
    for (final list in out.values) {
      list.sort((a, b) => a.path.compareTo(b.path));
    }
    return out;
  }

  /// Count boolean flags currently true in FeatureFlags. Uses only
  /// declared static fields — no reflection.
  int _countEnabledFlags() {
    int n = 0;
    if (FeatureFlags.enableAdminScreens) n++;
    if (FeatureFlags.enableOpenBanking) n++;
    if (FeatureFlags.enablePensionFundConnect) n++;
    if (FeatureFlags.enableExpertTier) n++;
    if (FeatureFlags.enableSlmNarratives) n++;
    if (FeatureFlags.enableDecisionScaffold) n++;
    if (FeatureFlags.enableCouplePlusTier) n++;
    if (FeatureFlags.valeurLocative2028Reform) n++;
    if (FeatureFlags.safeModeDegraded) n++;
    if (FeatureFlags.slmPluginReady) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    if (kRouteRegistry.isEmpty) {
      return const Center(
        child: Text(
          'Registry not generated. Run tools/mint-routes reconcile.',
        ),
      );
    }
    const owners = RouteOwner.values;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: owners.length,
            itemBuilder: (ctx, i) {
              final owner = owners[i];
              final routes = _grouped[owner] ?? const <RouteMeta>[];
              return ExpansionTile(
                title: Semantics(
                  label:
                      'Routes owned by ${owner.name}, ${routes.length} entries',
                  child: Text('${owner.name} (${routes.length})'),
                ),
                children: routes.map(_buildRow).toList(growable: false),
              );
            },
          ),
        ),
        const _Footer(),
      ],
    );
  }

  Widget _buildRow(RouteMeta meta) {
    return ListTile(
      dense: true,
      title: Text(meta.path),
      subtitle: Text(
        '${meta.category.name} | ${meta.owner.name}'
        '${meta.killFlag != null ? " | kill:${meta.killFlag}" : ""}'
        '${meta.requiresAuth ? " | auth" : " | public"}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: meta.killFlag != null
          ? const Icon(Icons.lock_outline,
              size: 16, color: MintColors.textMuted)
          : null,
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'Live health status: use `./tools/mint-routes health` terminal.\n'
        'This screen shows static schema + local FeatureFlags state only.',
        style: TextStyle(
          fontSize: 11,
          color: MintColors.textMuted,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
