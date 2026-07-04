import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/confidence/confidence_dashboard_screen.dart';
import 'package:mint_mobile/services/confidence/enhanced_confidence_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/common/mint_empty_state.dart';

typedef ConfidenceAnswersLoader = Future<Map<String, dynamic>> Function();
typedef ConfidenceResultBuilder = ConfidenceResult Function(
  Map<String, dynamic> answers,
);
typedef ConfidenceResultLoader = Future<ConfidenceResult> Function(
  BuildContext context,
);

class ConfidenceRouteScreen extends StatefulWidget {
  static const defaultTimeout = Duration(seconds: 8);

  final ConfidenceResultLoader? loadResult;
  final ConfidenceAnswersLoader? loadAnswers;
  final ConfidenceResultBuilder? buildResult;
  final Duration timeout;

  const ConfidenceRouteScreen({
    super.key,
    this.loadResult,
    this.loadAnswers,
    this.buildResult,
    this.timeout = defaultTimeout,
  }) : assert(loadResult != null || buildResult != null);

  @override
  State<ConfidenceRouteScreen> createState() => _ConfidenceRouteScreenState();
}

class _ConfidenceRouteScreenState extends State<ConfidenceRouteScreen> {
  late Future<ConfidenceResult> _resultFuture;

  @override
  void initState() {
    super.initState();
    _resultFuture = _loadResult();
  }

  Future<ConfidenceResult> _loadResult() async {
    final resultLoader = widget.loadResult;
    if (resultLoader != null) {
      return resultLoader(context).timeout(widget.timeout);
    }

    final loader = widget.loadAnswers ?? ReportPersistenceService.loadAnswers;
    final answers = await loader().timeout(widget.timeout);
    return widget.buildResult!(answers);
  }

  void _retry() {
    setState(() {
      _resultFuture = _loadResult();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ConfidenceResult>(
      future: _resultFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _ConfidenceLoadScaffold(
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

        final result = snapshot.data;
        if (snapshot.hasError || result == null) {
          return _ConfidenceLoadScaffold(
            child: MintEmptyState(
              icon: Icons.error_outline,
              title: S.of(context)!.confidenceLoadErrorTitle,
              subtitle: S.of(context)!.confidenceLoadError,
              ctaLabel: S.of(context)!.confidenceLoadErrorRetry,
              onCta: _retry,
            ),
          );
        }

        return ConfidenceDashboardScreen(result: result);
      },
    );
  }
}

class _ConfidenceLoadScaffold extends StatelessWidget {
  final Widget child;

  const _ConfidenceLoadScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.surface,
      appBar: AppBar(
        title: Text(
          S.of(context)!.confidenceDashboardTitle,
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
