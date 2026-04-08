import 'package:flutter/material.dart';
import 'package:mint_mobile/widgets/premium/mint_loading_skeleton.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/services/slm/slm_download_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';
import 'package:mint_mobile/services/slm/slm_model_tier.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// SLM Settings Screen — On-device AI model management.
///
/// Allows the user to:
///   - Download/delete the Gemma 3n E4B model (~2.3 GB)
///   - Monitor download progress
///   - See model status (not downloaded / ready / running / error)
///   - Initialize the engine for on-device inference
///
/// Privacy: model runs 100% on-device, zero data leaves the device.
/// Resolve SLM error code keys to localized strings.
String _resolveSlmError(String? errorKey, S l10n) {
  if (errorKey == null) return l10n.slmDownloadFailedDefault;
  return switch (errorKey) {
    'slm_error_auth_denied' => l10n.slmErrorAuthDenied,
    'slm_error_token_invalid' => l10n.slmErrorTokenInvalid,
    'slm_error_model_not_found' => l10n.slmErrorModelNotFound,
    'slm_error_token_missing' => l10n.slmErrorTokenMissing,
    'slm_error_timeout' => l10n.slmErrorTimeout,
    'slm_error_network' => l10n.slmErrorNetwork,
    'slm_error_generic' => l10n.slmErrorGeneric,
    'slm_init_failed' => l10n.slmErrorInitFailed,
    'slm_auth_missing' => l10n.slmErrorAuthMissing,
    _ => errorKey, // Fallback: show raw string
  };
}

class SlmSettingsScreen extends StatelessWidget {
  const SlmSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final slm = context.watch<SlmProvider>();
    final l10n = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.white,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        elevation: 0,
        title: Text(
          l10n.slmIaOnDevice,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: ListView(
        padding: const EdgeInsets.all(MintSpacing.md),
        children: [
          MintEntrance(child: _buildPrivacyBanner(context, l10n)),
          const SizedBox(height: MintSpacing.md),
          MintEntrance(delay: const Duration(milliseconds: 100), child: _buildTierSelector(context, slm, l10n)),
          const SizedBox(height: MintSpacing.md),
          MintEntrance(delay: const Duration(milliseconds: 200), child: _buildModelCard(context, slm, l10n)),
          const SizedBox(height: MintSpacing.md),
          MintEntrance(delay: const Duration(milliseconds: 300), child: _buildStatusCard(context, slm, l10n)),
          const SizedBox(height: MintSpacing.md),
          MintEntrance(delay: const Duration(milliseconds: 400), child: _buildInfoCard(context, slm, l10n)),
        ],
      ))),
    );
  }

  Widget _buildPrivacyBanner(BuildContext context, S l10n) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, color: MintColors.info, size: 28),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              l10n.slmPrivacyMessage,
              style: MintTextStyles.bodyMedium(color: MintColors.info),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierSelector(BuildContext context, SlmProvider slm, S l10n) {
    final recommended = slm.recommendedTier;
    final active = slm.activeTier;
    final isDownloading = slm.downloadState == DownloadState.downloading;

    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.lg - 4),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.slmChooseModel,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            l10n.slmTwoSizesAvailable,
            style: MintTextStyles.bodySmall(),
          ),
          const SizedBox(height: MintSpacing.md),
          for (final config in SlmTierConfig.allTiers) ...[
            _buildTierOption(
              context,
              l10n: l10n,
              config: config,
              isActive: active == config.tier,
              isRecommended: recommended == config.tier,
              isDisabled: isDownloading || slm.isProcessing,
              onTap: () => slm.selectTier(config.tier),
            ),
            if (config.tier != SlmTierConfig.allTiers.last.tier)
              const SizedBox(height: MintSpacing.sm + 2),
          ],
        ],
      ),
    );
  }

  Widget _buildTierOption(
    BuildContext context, {
    required S l10n,
    required SlmTierConfig config,
    required bool isActive,
    required bool isRecommended,
    required bool isDisabled,
    required VoidCallback onTap,
  }) {
    final borderColor = isActive
        ? MintColors.primary
        : MintColors.border;
    final bgColor = isActive
        ? MintColors.primary.withValues(alpha: 0.06)
        : MintColors.transparent;

    return Semantics(
      label: '${l10n.slmChooseModel} ${config.displayName}',
      button: true,
      selected: isActive,
      child: GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isActive ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isActive ? MintColors.primary : MintColors.textMuted,
              size: 22,
            ),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          config.displayName,
                          style: MintTextStyles.bodyMedium(
                            color: isActive
                                ? MintColors.primary
                                : MintColors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: MintSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MintSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: MintColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            l10n.slmRecommended,
                            style: MintTextStyles.labelSmall(
                              color: MintColors.success,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    '${config.modelSizeFormatted} \u2022 ~${config.estimatedDownloadMinutes} min \u2022 ${config.compatibilityHint}',
                    style: MintTextStyles.labelSmall(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildModelCard(BuildContext context, SlmProvider slm, S l10n) {
    if (slm.modelInfo == null) {
      return const MintSurface(
        padding: EdgeInsets.all(MintSpacing.lg),
        radius: 16,
        child: MintLoadingSkeleton(),
      );
    }

    final info = slm.modelInfo!;
    final isDownloading = slm.downloadState == DownloadState.downloading;
    final isFailed = slm.downloadState == DownloadState.failed;

    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.lg - 4),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                info.isReady
                    ? Icons.check_circle
                    : isFailed
                        ? Icons.error_outline
                        : Icons.cloud_download,
                color: info.isReady
                    ? MintColors.success
                    : isFailed
                        ? MintColors.error
                        : MintColors.primary,
                size: 24,
              ),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(
                  info.displayName,
                  style: MintTextStyles.titleLarge(),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            l10n.slmSizeLabel(SlmDownloadService.instance.modelSizeFormatted),
            style: MintTextStyles.bodyMedium(),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            l10n.slmVersionLabel(info.version),
            style: MintTextStyles.bodyMedium(),
          ),
          const SizedBox(height: MintSpacing.md),

          if (!info.isReady &&
              !slm.canAttemptDownload &&
              slm.prerequisiteWarning != null)
            Container(
              margin: const EdgeInsets.only(bottom: MintSpacing.sm + 4),
              padding: const EdgeInsets.all(MintSpacing.sm + 4),
              decoration: BoxDecoration(
                color: MintColors.warning.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline,
                      color: MintColors.warning, size: 20),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: Text(
                      _resolveSlmError(slm.prerequisiteWarning, l10n),
                      style: MintTextStyles.bodySmall(
                        color: MintColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── State: Starting download (processing, not yet downloading) ──
          if (slm.isProcessing && !isDownloading && !info.isReady) ...[
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: MintColors.primary,
                  ),
                ),
                const SizedBox(width: MintSpacing.sm + 4),
                Text(
                  l10n.slmStartingDownload,
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.primary,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],

          // ── State: Download in progress ──
          if (isDownloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: slm.downloadProgress,
                backgroundColor: MintColors.border,
                color: MintColors.primary,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: MintSpacing.sm + 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(slm.downloadProgress * 100).toStringAsFixed(1)}%',
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.primary,
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Text(
                  _formatDownloadedSize(slm.downloadProgress),
                  style: MintTextStyles.labelSmall(),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              l10n.slmWifiEstimate(SlmDownloadService.instance.estimatedDownloadMinutes),
              style: MintTextStyles.labelSmall(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                label: l10n.slmCancelDownload,
                button: true,
                child: OutlinedButton.icon(
                  onPressed: slm.cancelDownload,
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(l10n.slmCancelDownload),
                ),
              ),
            ),
          ],

          // ── State: Download failed ──
          if (isFailed && !slm.isProcessing) ...[
            Container(
              padding: const EdgeInsets.all(MintSpacing.sm + 4),
              decoration: BoxDecoration(
                color: MintColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MintColors.error.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      color: MintColors.error, size: 20),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: Text(
                      _resolveSlmError(slm.lastError, l10n),
                      style: MintTextStyles.bodySmall(
                        color: MintColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MintSpacing.sm + 4),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                label: slm.canAttemptDownload
                    ? l10n.slmRetryDownload
                    : l10n.slmDownloadUnavailable,
                button: true,
                child: FilledButton.icon(
                  onPressed: slm.canAttemptDownload
                      ? () => _startDownload(context, slm, l10n)
                      : null,
                  icon: Icon(
                      slm.canAttemptDownload ? Icons.refresh : Icons.lock),
                  label: Text(
                    slm.canAttemptDownload
                        ? l10n.slmRetryDownload
                        : l10n.slmDownloadUnavailable,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ],

          // ── State: Not started (initial) ──
          if (!isDownloading && !isFailed && !info.isReady && !slm.isProcessing)
            SizedBox(
              width: double.infinity,
              child: Semantics(
                label: slm.canAttemptDownload
                    ? l10n.slmDownloadButton(SlmDownloadService.instance.modelSizeFormatted)
                    : l10n.slmDownloadUnavailable,
                button: true,
                child: FilledButton.icon(
                  onPressed: slm.canAttemptDownload
                      ? () => _startDownload(context, slm, l10n)
                      : null,
                  icon: Icon(
                      slm.canAttemptDownload ? Icons.download : Icons.lock),
                  label: Text(
                    slm.canAttemptDownload
                        ? l10n.slmDownloadButton(SlmDownloadService.instance.modelSizeFormatted)
                        : l10n.slmDownloadUnavailable,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

          // ── State: Model ready ──
          if (!isDownloading && !isFailed && info.isReady) ...[
            SizedBox(
              width: double.infinity,
              child: Semantics(
                label: l10n.slmDeleteModelButton,
                button: true,
                child: OutlinedButton.icon(
                  onPressed:
                      slm.isProcessing ? null : () => _deleteModel(context, slm, l10n),
                  icon: const Icon(Icons.delete_outline, color: MintColors.error),
                  label: Text(
                    l10n.slmDeleteModelButton,
                    style: const TextStyle(color: MintColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: MintColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startDownload(BuildContext context, SlmProvider slm, S l10n) async {
    if (!slm.canAttemptDownload) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            _resolveSlmError(slm.prerequisiteWarning, l10n),
          ),
          backgroundColor: MintColors.error,
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.slmDownloadModelTitle,
          style: MintTextStyles.titleMedium(),
        ),
        content: Text(
          l10n.slmDownloadDialogBody(
            SlmDownloadService.instance.modelSizeFormatted,
            SlmDownloadService.instance.estimatedDownloadMinutes,
            slm.activeTierConfig.compatibilityHint,
          ),
          style: MintTextStyles.bodyMedium(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.slmCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.slmDownload),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final success = await slm.downloadModel();

    if (!success &&
        context.mounted &&
        slm.downloadState == DownloadState.failed) {
      final reason = _resolveSlmError(slm.lastError, l10n);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(l10n.slmDownloadFailedSnack(reason)),
          backgroundColor: MintColors.error,
          duration: const Duration(seconds: 6),
          action: slm.canAttemptDownload
              ? SnackBarAction(
                  label: l10n.commonRetry,
                  textColor: MintColors.white,
                  onPressed: () => _startDownload(context, slm, l10n),
                )
              : null,
        ),
      );
    }
  }

  Future<void> _deleteModel(BuildContext context, SlmProvider slm, S l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.slmDeleteModelTitle,
          style: MintTextStyles.titleMedium(),
        ),
        content: Text(
          l10n.slmDeleteModelContent(SlmDownloadService.instance.modelSizeFormatted),
          style: MintTextStyles.bodyMedium(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.slmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: MintColors.error),
            child: Text(l10n.slmDelete),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await slm.deleteModel();
  }

  /// Format downloaded size as "X Mo / 2.3 Go".
  static String _formatDownloadedSize(double progress) {
    final downloaded =
        progress.clamp(0.0, 1.0) * SlmDownloadService.instance.expectedSizeBytes;
    final totalGo = SlmDownloadService.instance.expectedSizeBytes / (1024 * 1024 * 1024);
    if (downloaded < 1024 * 1024) {
      return '${(downloaded / 1024).toStringAsFixed(0)} Ko / '
          '${totalGo.toStringAsFixed(1)} Go';
    }
    if (downloaded < 1024 * 1024 * 1024) {
      return '${(downloaded / (1024 * 1024)).toStringAsFixed(0)} Mo / '
          '${totalGo.toStringAsFixed(1)} Go';
    }
    return '${(downloaded / (1024 * 1024 * 1024)).toStringAsFixed(1)} Go / '
        '${totalGo.toStringAsFixed(1)} Go';
  }

  Widget _buildStatusCard(BuildContext context, SlmProvider slm, S l10n) {
    final engineStatus = slm.engineStatus;
    final isReady = slm.isModelReady;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (engineStatus) {
      case SlmStatus.running:
        statusText = l10n.slmStatusRunning;
        statusColor = MintColors.success;
        statusIcon = Icons.check_circle;
      case SlmStatus.ready:
        statusText = l10n.slmStatusReady;
        statusColor = MintColors.warning;
        statusIcon = Icons.pending;
      case SlmStatus.error:
        statusText = l10n.slmStatusError;
        statusColor = MintColors.error;
        statusIcon = Icons.error;
      case SlmStatus.downloading:
        statusText = l10n.slmStatusDownloading;
        statusColor = MintColors.primary;
        statusIcon = Icons.downloading;
      case SlmStatus.notDownloaded:
        statusText = isReady
            ? l10n.slmStatusModelReady
            : l10n.slmStatusNotDownloaded;
        statusColor = MintColors.textMuted;
        statusIcon = Icons.cloud_off;
    }

    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.lg - 4),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.slmEngineStatus,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(
                  statusText,
                  style: MintTextStyles.bodyMedium(color: statusColor),
                ),
              ),
            ],
          ),
          if (isReady && engineStatus != SlmStatus.running) ...[
            const SizedBox(height: MintSpacing.md),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                label: slm.isProcessing
                    ? l10n.slmInitializing
                    : l10n.slmInitEngine,
                button: true,
                child: FilledButton.icon(
                  onPressed: slm.isProcessing
                      ? null
                      : () async {
                          final success = await slm.initializeEngine();
                          if (!success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.slmInitError),
                              ),
                            );
                          }
                        },
                  icon: slm.isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MintColors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(
                    slm.isProcessing
                        ? l10n.slmInitializing
                        : l10n.slmInitEngine,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, SlmProvider slm, S l10n) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.lg - 4),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.slmHowItWorks,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          _buildInfoRow(
            Icons.download,
            l10n.slmInfoDownload(SlmDownloadService.instance.estimatedDownloadMinutes),
          ),
          _buildInfoRow(
            Icons.phone_android,
            l10n.slmInfoOnDevice,
          ),
          _buildInfoRow(
            Icons.wifi_off,
            l10n.slmInfoOffline,
          ),
          _buildInfoRow(
            Icons.shield,
            l10n.slmInfoPrivacy,
          ),
          _buildInfoRow(
            Icons.speed,
            l10n.slmInfoSpeed,
          ),
          const Divider(height: MintSpacing.lg),
          _buildInfoRow(
            Icons.link,
            l10n.slmInfoSourceModel(SlmDownloadService.modelId),
          ),
          _buildInfoRow(
            slm.hasAuthToken ? Icons.key : Icons.key_off,
            slm.hasAuthToken
                ? l10n.slmInfoAuthConfigured
                : l10n.slmInfoAuthNotConfigured,
          ),
          Text(
            l10n.slmInfoCompatibility(
              slm.activeTierConfig.compatibilityHint,
              slm.activeTierConfig.modelSizeFormatted,
              slm.activeTierConfig.minRamGb,
            ),
            style: MintTextStyles.labelSmall(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: MintColors.primary),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: MintTextStyles.bodySmall(),
            ),
          ),
        ],
      ),
    );
  }
}
