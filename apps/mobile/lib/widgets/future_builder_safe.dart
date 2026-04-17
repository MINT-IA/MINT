import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

/// [FutureBuilder] with first-class error + loading handling.
///
/// The stock [FutureBuilder] only exposes `hasData`; consumers routinely
/// forget `hasError`, leaving the UI stuck on a spinner (or a blank
/// screen) when a dependency throws. MINT's audit flagged nine screens
/// with this exact pattern — users see a blank page instead of a
/// message + retry affordance when the backend is down.
///
/// Usage:
/// ```dart
/// FutureBuilderSafe<List<ConsentReceipt>>(
///   future: _future,
///   onRetry: _refresh,
///   builder: (ctx, data) => _ConsentList(data),
/// )
/// ```
///
/// - `loadingBuilder` defaults to a centered [CircularProgressIndicator].
/// - `errorBuilder` defaults to a neutral error card with an optional
///   Retry button (shown when `onRetry` is provided).
class FutureBuilderSafe<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final VoidCallback? onRetry;

  const FutureBuilderSafe({
    required this.future,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.onRetry,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return loadingBuilder?.call(ctx) ?? const _DefaultLoading();
        }
        if (snap.hasError) {
          if (errorBuilder != null) {
            return errorBuilder!(ctx, snap.error!);
          }
          return _DefaultError(error: snap.error!, onRetry: onRetry);
        }
        if (!snap.hasData) {
          // Future completed with null. Treat as error so the user never
          // faces an unexplained blank screen.
          return _DefaultError(error: 'no-data', onRetry: onRetry);
        }
        return builder(ctx, snap.data as T);
      },
    );
  }
}

class _DefaultLoading extends StatelessWidget {
  const _DefaultLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: MintColors.success),
    );
  }
}

class _DefaultError extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const _DefaultError({required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    // TODO(i18n): move to ARB once the 6-locale backfill sprint lands.
    // This widget is a last-resort error UI; hardcoded FR is acceptable
    // until errorGenericTitle / errorGenericBody / actionRetry keys ship.
    const title = "Impossible de charger cette page";
    const body = "Vérifie ta connexion et réessaie dans quelques instants.";
    const retryLabel = "Réessayer";

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: MintColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
