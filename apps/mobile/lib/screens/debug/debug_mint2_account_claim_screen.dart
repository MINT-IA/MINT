import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/services/account_handoff_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugMint2AccountClaimScreen extends StatefulWidget {
  final String mode;

  const DebugMint2AccountClaimScreen({
    super.key,
    required this.mode,
  });

  @override
  State<DebugMint2AccountClaimScreen> createState() =>
      _DebugMint2AccountClaimScreenState();
}

class _DebugMint2AccountClaimScreenState
    extends State<DebugMint2AccountClaimScreen> {
  static const _proofKey = 'e2e_mint2_axis_claim_proof_v1';
  static const _userId = 'e2e-mint2-axis-user';

  late final Future<Map<String, Object?>> _result = _run();

  Future<Map<String, Object?>> _run() async {
    if (kReleaseMode) {
      return _status('unavailable', mode: widget.mode, ok: false);
    }
    final mode = widget.mode;
    if (mode == 'status') return _status('status', mode: mode);
    if (mode == 'restart') {
      await AccountHandoffService.saveChoice(AccountHandoffChoice.restartClean);
      await AccountHandoffService.prepareLocalDataForAccount(
        _userId,
        handoffEnabled: true,
      );
      await _saveProof('restart_clean', 'absent', false, 0);
      return _status('restart_clean', mode: mode);
    }

    final handoff = await ReportPersistenceService.loadMint2AxisHandoff();
    final axis = handoff['onb_axis_v2'];
    final answers = await ReportPersistenceService.loadAnswers();
    final polluted = _polluted(answers);
    if (axis != 'lpp_rente_capital' ||
        handoff['onb_axis_schema_version'] != 2 ||
        polluted) {
      return _status(
        polluted ? 'wizard_polluted' : 'missing_axis',
        mode: mode,
        ok: false,
        axis: axis?.toString() ?? 'absent',
      );
    }

    await AccountHandoffService.saveChoice(AccountHandoffChoice.keepLocal);
    final shouldClaim = await AccountHandoffService.prepareLocalDataForAccount(
      _userId,
      handoffEnabled: true,
    );
    if (!shouldClaim) return _status('not_claimable', mode: mode, ok: false);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_data_owner', _userId);
    await prefs.setBool('local_data_migrated_$_userId', true);
    await _restoreSession();
    await _saveProof('claimed', axis.toString(), false, answers.length);
    return _status('claimed', mode: mode);
  }

  Future<Map<String, Object?>> _status(
    String fallbackClaim, {
    required String mode,
    bool ok = true,
    String? axis,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final proof = _proof(prefs);
    if ((proof['claim_status'] ?? fallbackClaim) == 'claimed' &&
        !(await AuthService.isLoggedIn())) {
      await _restoreSession();
    }
    final handoff = await ReportPersistenceService.loadMint2AxisHandoff();
    final answers = await ReportPersistenceService.loadAnswers();
    final claim = (proof['claim_status'] ?? fallbackClaim).toString();
    final resolvedAxis = axis ??
        (proof['axis'] ?? handoff['onb_axis_v2'] ?? 'absent').toString();
    final owner = prefs.getString('local_data_owner') == _userId &&
        (prefs.getBool('local_data_migrated_$_userId') ?? false);
    final auth = await AuthService.isLoggedIn();
    if (auth && mounted) await context.read<AuthProvider>().checkAuth();
    return {
      'ok': ok && (claim == 'claimed' || claim == 'restart_clean'),
      'mode': mode,
      'claim': claim,
      'axis': resolvedAxis,
      'wizardAnswers': answers.length,
      'axisInWizardAnswers': _polluted(answers),
      'owner': owner ? 'claimed' : 'absent',
      'auth': auth ? 'present' : 'absent',
    };
  }

  static bool _polluted(Map<String, dynamic> answers) {
    return answers.containsKey('mint2AxisHandoff') ||
        answers.containsKey('mint2_axis_handoff') ||
        answers.containsKey('onb_axis_v2') ||
        answers.containsKey('onb_axis_schema_version');
  }

  static Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auth_local_mode', false);
    ConversationStore.setCurrentUserId(_userId);
    await AuthService.saveToken(
      'e2e-local-claim-access',
      _userId,
      'e2e-mint2-axis-account',
      displayName: 'E2E Mint2',
      refreshToken: 'e2e-local-claim-refresh',
    );
  }

  static Future<void> _saveProof(
    String claim,
    String axis,
    bool polluted,
    int answersCount,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _proofKey,
      json.encode({
        'claim_status': claim,
        'axis': axis,
        'axis_in_wizard_answers': polluted,
        'wizard_answers_count': answersCount,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  static Map<String, dynamic> _proof(SharedPreferences prefs) {
    final raw = prefs.getString(_proofKey);
    if (raw == null) return const {};
    final decoded = json.decode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Map<String, Object?>>(
          future: _result,
          builder: (context, snapshot) {
            final result = snapshot.data;
            if (result == null) {
              return const Center(
                child: CircularProgressIndicator(
                  key: ValueKey('debug_mint2_axis_claim_loading'),
                ),
              );
            }
            final label = result.entries
                .map((entry) => '${entry.key}=${entry.value}')
                .join(' ');
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    key: const ValueKey('e2e_mint2_axis_claim_applied'),
                    identifier: 'e2e_mint2_axis_claim_applied',
                    label: label,
                    container: true,
                    child: const SizedBox.shrink(),
                  ),
                  for (final entry in result.entries)
                    Semantics(
                      identifier:
                          'e2e_mint2_axis_claim_${entry.key}_${entry.value}',
                      label: '${entry.key}: ${entry.value}',
                      container: true,
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
