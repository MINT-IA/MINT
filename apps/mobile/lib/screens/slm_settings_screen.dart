import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/services/slm/slm_download_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';
import 'package:mint_mobile/services/slm/slm_model_tier.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:provider/provider.dart';

/// SLM Settings Screen — On-device AI model management.
///
/// Allows the user to:
///   - Download/delete the Gemma 3n E4B model (~2.3 GB)
///   - Monitor download progress
///   - See model status (not downloaded / ready / running / error)
///   - Initialize the engine for on-device inference
///
/// Privacy: model runs 100% on-device, zero data leaves the device.
class SlmSettingsScreen extends StatelessWidget {
  const SlmSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final slm = context.watch<SlmProvider>();

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              S.of(context)!.slmIaOnDevice,
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [MintColors.primary, MintColors.accent],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildPrivacyBanner(context),
                const SizedBox(height: 16),
                _buildTierSelector(context, slm),
                const SizedBox(height: 16),
                _buildModelCard(context, slm),
                const SizedBox(height: 16),
                _buildStatusCard(context, slm),
                const SizedBox(height: 16),
                _buildInfoCard(context, slm),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, color: MintColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.slmPrivacyMessage,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierSelector(BuildContext context, SlmProvider slm) {
    final recommended = slm.recommendedTier;
    final active = slm.activeTier;
    final isDownloading = slm.downloadState == DownloadState.downloading;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context)!.slmSettingsChooseModel,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              S.of(context)!.slmSettingsTwoSizesAvailable,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            for (final config in SlmTierConfig.allTiers) ...[
              _buildTierOption(
                context,
                config: config,
                isActive: active == config.tier,
                isRecommended: recommended == config.tier,
                isDisabled: isDownloading || slm.isProcessing,
                onTap: () => slm.selectTier(config.tier),
              ),
              if (config.tier != SlmTierConfig.allTiers.last.tier)
                const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTierOption(
    BuildContext context, {
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
        : Colors.transparent;

    return GestureDetector(
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          config.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? MintColors.primary
                                : MintColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: MintColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            S.of(context)!.slmSettingsRecommended,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: MintColors.success,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    S.of(context)!.slmSettingsTierDetails(config.modelSizeFormatted, '${config.estimatedDownloadMinutes}', config.compatibilityHint),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelCard(BuildContext context, SlmProvider slm) {
    if (slm.modelInfo == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final info = slm.modelInfo!;
    final isDownloading = slm.downloadState == DownloadState.downloading;
    final isFailed = slm.downloadState == DownloadState.failed;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    info.displayName,
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              S.of(context)!.slmSettingsModelSize(SlmDownloadService.instance.modelSizeFormatted),
              style: GoogleFonts.inter(fontSize: 14, color: MintColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              S.of(context)!.slmSettingsModelVersion(info.version),
              style: GoogleFonts.inter(fontSize: 14, color: MintColors.textSecondary),
            ),
            const SizedBox(height: 16),

            if (!info.isReady &&
                !slm.canAttemptDownload &&
                slm.prerequisiteWarning != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MintColors.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: MintColors.warning.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline,
                        color: MintColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        slm.prerequisiteWarning!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.warningText,
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
                  const SizedBox(width: 12),
                  Text(
                    S.of(context)!.slmStartingDownload,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MintColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
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
                  backgroundColor: MintColors.lightBorder,
                  color: MintColors.primary,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(slm.downloadProgress * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: MintColors.primary,
                    ),
                  ),
                  Text(
                    _formatDownloadedSize(slm.downloadProgress),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: MintColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                S.of(context)!.slmSettingsEstimatedTime('${SlmDownloadService.instance.estimatedDownloadMinutes}'),
                style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: slm.cancelDownload,
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(S.of(context)!.slmCancelDownload),
                ),
              ),
            ],

            // ── State: Download failed ──
            if (isFailed && !slm.isProcessing) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MintColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MintColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        color: MintColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        slm.lastError ??
                            S.of(context)!.slmSettingsDownloadFailedDefault,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: MintColors.redMedium),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: slm.canAttemptDownload
                      ? () => _startDownload(context, slm)
                      : null,
                  icon: Icon(
                      slm.canAttemptDownload ? Icons.refresh : Icons.lock),
                  label: Text(
                    slm.canAttemptDownload
                        ? S.of(context)!.slmRetryDownload
                        : S.of(context)!.slmDownloadUnavailable,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],

            // ── State: Not started (initial) ──
            if (!isDownloading && !isFailed && !info.isReady && !slm.isProcessing)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: slm.canAttemptDownload
                      ? () => _startDownload(context, slm)
                      : null,
                  icon: Icon(
                      slm.canAttemptDownload ? Icons.download : Icons.lock),
                  label: Text(
                    slm.canAttemptDownload
                        ? S.of(context)!.slmSettingsDownloadButton(SlmDownloadService.instance.modelSizeFormatted)
                        : S.of(context)!.slmDownloadUnavailable,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

            // ── State: Model ready ──
            if (!isDownloading && !isFailed && info.isReady) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      slm.isProcessing ? null : () => _deleteModel(context, slm),
                  icon: const Icon(Icons.delete_outline, color: MintColors.error),
                  label: Text(
                    S.of(context)!.slmDeleteModelButton,
                    style: const TextStyle(color: MintColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: MintColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startDownload(BuildContext context, SlmProvider slm) async {
    if (!slm.canAttemptDownload) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            slm.prerequisiteWarning ??
                S.of(context)!.slmSettingsBuildDownloadUnavailable,
            style: GoogleFonts.inter(),
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
          S.of(context)!.slmDownloadModelTitle,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          S.of(context)!.slmSettingsDownloadDialogContent(
            SlmDownloadService.instance.modelSizeFormatted,
            '${SlmDownloadService.instance.estimatedDownloadMinutes}',
            slm.activeTierConfig.compatibilityHint,
          ),
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(context)!.slmCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.of(context)!.slmDownload),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final success = await slm.downloadModel();

    if (!success &&
        context.mounted &&
        slm.downloadState == DownloadState.failed) {
      final reason =
          slm.lastError ?? S.of(context)!.slmSettingsCheckWifiAndStorage;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            S.of(context)!.slmSettingsDownloadFailed(reason),
            style: GoogleFonts.inter(),
          ),
          backgroundColor: MintColors.error,
          duration: const Duration(seconds: 6),
          action: slm.canAttemptDownload
              ? SnackBarAction(
                  label: S.of(context)!.slmSettingsRetryAction,
                  textColor: MintColors.white,
                  onPressed: () => _startDownload(context, slm),
                )
              : null,
        ),
      );
    }
  }

  Future<void> _deleteModel(BuildContext context, SlmProvider slm) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          S.of(context)!.slmDeleteModelTitle,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          S.of(context)!.slmDeleteModelContent(SlmDownloadService.instance.modelSizeFormatted),
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(context)!.slmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: MintColors.error),
            child: Text(S.of(context)!.slmDelete),
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

  Widget _buildStatusCard(BuildContext context, SlmProvider slm) {
    final engineStatus = slm.engineStatus;
    final isReady = slm.isModelReady;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    final s = S.of(context)!;
    switch (engineStatus) {
      case SlmStatus.running:
        statusText = s.slmSettingsStatusRunning;
        statusColor = MintColors.success;
        statusIcon = Icons.check_circle;
      case SlmStatus.ready:
        statusText = s.slmSettingsStatusReady;
        statusColor = MintColors.warning;
        statusIcon = Icons.pending;
      case SlmStatus.error:
        statusText = s.slmSettingsStatusError;
        statusColor = MintColors.error;
        statusIcon = Icons.error;
      case SlmStatus.downloading:
        statusText = s.slmSettingsStatusDownloading;
        statusColor = MintColors.primary;
        statusIcon = Icons.downloading;
      case SlmStatus.notDownloaded:
        statusText = isReady
            ? s.slmSettingsStatusModelReady
            : s.slmSettingsStatusNotDownloaded;
        statusColor = MintColors.greyMedium;
        statusIcon = Icons.cloud_off;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context)!.slmEngineStatus,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: GoogleFonts.inter(fontSize: 14, color: statusColor),
                  ),
                ),
              ],
            ),
            if (isReady && engineStatus != SlmStatus.running) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: slm.isProcessing
                      ? null
                      : () async {
                          final success = await slm.initializeEngine();
                          if (!success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    S.of(context)!.slmSettingsInitError),
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
                        ? S.of(context)!.slmSettingsInitializing
                        : S.of(context)!.slmSettingsInitializeEngine,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, SlmProvider slm) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context)!.slmHowItWorks,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.download,
              S.of(context)!.slmSettingsInfoDownload('${SlmDownloadService.instance.estimatedDownloadMinutes}'),
            ),
            _buildInfoRow(
              Icons.phone_android,
              S.of(context)!.slmSettingsInfoOnDevice,
            ),
            _buildInfoRow(
              Icons.wifi_off,
              S.of(context)!.slmSettingsInfoOffline,
            ),
            _buildInfoRow(
              Icons.shield,
              S.of(context)!.slmSettingsInfoPrivacy,
            ),
            _buildInfoRow(
              Icons.speed,
              S.of(context)!.slmSettingsInfoSpeed,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.link,
              S.of(context)!.slmSettingsInfoSource(SlmDownloadService.modelId),
            ),
            _buildInfoRow(
              slm.hasAuthToken ? Icons.key : Icons.key_off,
              slm.hasAuthToken
                  ? S.of(context)!.slmSettingsAuthConfigured
                  : S.of(context)!.slmSettingsAuthNotConfigured,
            ),
            Text(
              S.of(context)!.slmSettingsCompatibilityInfo(
                slm.activeTierConfig.compatibilityHint,
                slm.activeTierConfig.modelSizeFormatted,
                '${slm.activeTierConfig.minRamGb}',
              ),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: MintColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
