import 'package:flutter/material.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/services/debug_profile_bootstrap_service.dart';
import 'package:provider/provider.dart';

class DebugProfileBootstrapScreen extends StatefulWidget {
  final String slug;
  final DebugProfileBootstrapMode mode;
  final double? selfEmployedNetIncomeAnnual;
  final double? annual3aContribution;

  const DebugProfileBootstrapScreen({
    super.key,
    required this.slug,
    this.mode = DebugProfileBootstrapMode.establish,
    this.selfEmployedNetIncomeAnnual,
    this.annual3aContribution,
  });

  @override
  State<DebugProfileBootstrapScreen> createState() =>
      _DebugProfileBootstrapScreenState();
}

class _DebugProfileBootstrapScreenState
    extends State<DebugProfileBootstrapScreen> {
  late final Future<DebugProfileBootstrapResult> _result;

  @override
  void initState() {
    super.initState();
    _result = _persistFixture();
  }

  Future<DebugProfileBootstrapResult> _persistFixture() async {
    final result = await DebugProfileBootstrapService.persistFixture(
      slug: widget.slug,
      mode: widget.mode,
      selfEmployedNetIncomeAnnual: widget.selfEmployedNetIncomeAnnual,
      annual3aContribution: widget.annual3aContribution,
    );
    if (result.ok && mounted) {
      await context.read<AuthProvider>().enableLocalMode();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<DebugProfileBootstrapResult>(
          future: _result,
          builder: (context, snapshot) {
            final result = snapshot.data;
            if (result == null) {
              return const Center(
                child: CircularProgressIndicator(
                  key: ValueKey('debug_profile_bootstrap_loading'),
                ),
              );
            }
            final label = [
              result.ok ? 'applied' : 'failed',
              'slug=${result.slug}',
              'mode=${result.mode.name}',
              'seed=${result.seedActive ? 'active' : 'absent'}',
              'storage=${result.storageMode}',
              if (result.selfEmployedNetIncomeAnnual != null)
                'annual=${result.selfEmployedNetIncomeAnnual!.round()}',
              if (result.annual3aContribution != null)
                'planned3a=${result.annual3aContribution!.round()}',
            ].join(' ');

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    key: const ValueKey('e2e_profile_fixture_applied'),
                    identifier: 'e2e_profile_fixture_applied',
                    label: label,
                    container: true,
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('slug: ${result.slug}'),
                  Text('mode: ${result.mode.name}'),
                  Text('seed: ${result.seedActive ? 'active' : 'absent'}'),
                  if (result.selfEmployedNetIncomeAnnual != null)
                    Text(
                      'self-employed annual: '
                      '${result.selfEmployedNetIncomeAnnual!.round()}',
                    ),
                  if (result.monthlyNetIncome != null)
                    Text(
                      'monthly net: ${result.monthlyNetIncome!.round()}',
                    ),
                  if (result.annual3aContribution != null)
                    Text(
                      '3a annual: ${result.annual3aContribution!.round()}',
                    ),
                  if (result.error != null) Text('error: ${result.error}'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
