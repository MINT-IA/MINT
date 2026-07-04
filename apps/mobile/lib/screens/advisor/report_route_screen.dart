import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/advisor/financial_report_screen_v2.dart';
import 'package:mint_mobile/services/local_profile_owner_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/common/mint_empty_state.dart';

typedef ReportAnswersLoader = Future<Map<String, dynamic>> Function();
typedef ReportOwnerIdResolver = Future<String> Function();
typedef ReportAnswersSaver = Future<void> Function(Map<String, dynamic>);

class ReportRouteScreen extends StatefulWidget {
  static const defaultTimeout = Duration(seconds: 8);

  final ReportAnswersLoader? loadAnswers;
  final ReportOwnerIdResolver? resolveOwnerId;
  final ReportAnswersSaver? saveAnswers;
  final Duration timeout;

  const ReportRouteScreen({
    super.key,
    this.loadAnswers,
    this.resolveOwnerId,
    this.saveAnswers,
    this.timeout = defaultTimeout,
  });

  @override
  State<ReportRouteScreen> createState() => _ReportRouteScreenState();
}

class _ReportRouteScreenState extends State<ReportRouteScreen> {
  late Future<Map<String, dynamic>> _answersFuture;

  @override
  void initState() {
    super.initState();
    _answersFuture = _loadAnswers();
  }

  Future<Map<String, dynamic>> _loadAnswers() async {
    final loader = widget.loadAnswers ?? ReportPersistenceService.loadAnswers;
    return (() async {
      final answers = await loader();
      return _withResolvedOwnerId(answers);
    })()
        .timeout(widget.timeout);
  }

  Future<Map<String, dynamic>> _withResolvedOwnerId(
    Map<String, dynamic> answers,
  ) async {
    if (answers.isEmpty) return answers;
    final explicit = _resolvedOwnerIdFrom(answers);
    if (explicit != null) {
      if (answers['_coach_profile_owner_id'] == explicit) return answers;
      final updated = {
        ...answers,
        '_coach_profile_owner_id': explicit,
      };
      await (widget.saveAnswers ?? ReportPersistenceService.saveAnswers)(
        updated,
      );
      return updated;
    }

    final ownerId = await (widget.resolveOwnerId ??
        LocalProfileOwnerService.getOrCreateOwnerId)();
    final ownerText = ownerId.trim();
    if (!_isResolvedOwnerId(ownerText)) {
      throw StateError('Report route resolved an invalid local owner id.');
    }
    final updated = {
      ...answers,
      '_coach_profile_owner_id': ownerText,
    };
    await (widget.saveAnswers ?? ReportPersistenceService.saveAnswers)(
      updated,
    );
    return updated;
  }

  String? _resolvedOwnerIdFrom(Map<String, dynamic> answers) {
    for (final key in const ['_coach_profile_owner_id', '_profile_owner_id']) {
      final value = answers[key]?.toString().trim();
      if (value != null && _isResolvedOwnerId(value)) return value;
    }
    return null;
  }

  bool _isResolvedOwnerId(String value) =>
      value.isNotEmpty && value != 'local_demo_pending';

  void _retry() {
    setState(() {
      _answersFuture = _loadAnswers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _answersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _ReportLoadScaffold(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: MintColors.primary),
                const SizedBox(height: 16),
                Text(
                  S.of(context)!.loadingGeneric,
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return _ReportLoadScaffold(
            child: MintEmptyState(
              icon: Icons.error_outline,
              title: S.of(context)!.financialReportLoadErrorTitle,
              subtitle: S.of(context)!.financialReportLoadErrorSubtitle,
              ctaLabel: S.of(context)!.commonRetry,
              onCta: _retry,
            ),
          );
        }

        return FinancialReportScreenV2(
          wizardAnswers: snapshot.data ?? const {},
        );
      },
    );
  }
}

class _ReportLoadScaffold extends StatelessWidget {
  final Widget child;

  const _ReportLoadScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.surface,
      appBar: AppBar(
        title: Text(
          S.of(context)!.reportTonPlanMint,
          style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
        ),
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Center(child: child),
    );
  }
}
