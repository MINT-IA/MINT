import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/services/slm/slm_download_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auto-prompt for SLM model download on native platforms.
///
/// On iOS/Android first dashboard visit, shows a bottom sheet asking
/// the user if they want to download the Gemma 3n model for on-device
/// AI coaching. On web, does nothing (flutter_gemma is native-only).
///
/// Flow:
///   1. Check: kIsWeb → skip
///   2. Check: already prompted → skip
///   3. Check: model already installed → skip + mark prompted
///   4. Show bottom sheet with download CTA
///   5. If accepted, start download with progress indicator
///   6. Mark prompted regardless of choice
class SlmAutoPromptService {
  SlmAutoPromptService._();

  static const String _prefKey = 'slm_auto_prompt_shown';

  /// Whether the auto-prompt has already been shown.
  static Future<bool> _wasPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Mark the prompt as shown.
  static Future<void> _markPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  /// Check and show the SLM download prompt if appropriate.
  ///
  /// Call this from the dashboard's initState or didChangeDependencies.
  /// Safe to call multiple times — only shows once per install.
  static Future<void> checkAndPrompt(BuildContext context) async {
    // Web: flutter_gemma is native-only, skip silently.
    if (kIsWeb) return;

    // Already prompted this install → skip.
    if (await _wasPrompted()) return;

    if (!context.mounted) return;

    // Model already downloaded → mark and skip.
    final slm = context.read<SlmProvider>();
    if (slm.isModelReady) {
      await _markPrompted();
      return;
    }

    // Build not configured for model download (gated repo without token).
    // Do NOT mark as prompted so a future properly configured build
    // can still present the one-time auto-prompt.
    if (!slm.canAttemptDownload) {
      return;
    }

    // Small delay to let the dashboard fully render first.
    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (!context.mounted) return;

    // Show the prompt.
    await _showDownloadSheet(context);
    await _markPrompted();
  }

  /// Bottom sheet offering the SLM download.
  static Future<void> _showDownloadSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _SlmDownloadSheet(),
    );
  }
}

/// Bottom sheet widget for SLM download prompt.
class _SlmDownloadSheet extends StatelessWidget {
  const _SlmDownloadSheet();

  @override
  Widget build(BuildContext context) {
    final slm = context.watch<SlmProvider>();
    final isDownloading = slm.downloadState == DownloadState.downloading;
    final isCompleted = slm.isModelReady && !isDownloading;
    final hasError = slm.downloadState == DownloadState.failed;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Icon + Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MintColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: MintColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Coach IA sur ton appareil',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              'MINT peut installer un modele d\'IA directement sur ton telephone '
              'pour des conseils personnalises — 100% prive, aucune donnee ne quitte ton appareil.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),

            // Size + time info
            Row(
              children: [
                const Icon(Icons.storage,
                    size: 16, color: MintColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  SlmDownloadService.instance.modelSizeFormatted,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textMuted,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.wifi, size: 16, color: MintColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  '~${SlmDownloadService.instance.estimatedDownloadMinutes} min en WiFi',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress bar (when downloading)
            if (isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: slm.downloadProgress,
                  minHeight: 8,
                  backgroundColor: MintColors.lightBorder,
                  color: MintColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(slm.downloadProgress * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.primary,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Completed message
            if (isCompleted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MintColors.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: MintColors.success, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Coach IA installe ! Tes conseils seront personnalises.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: MintColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Continuer',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],

            // Error message
            if (hasError && !isDownloading) ...[
              Text(
                slm.lastError ??
                    'Le telechargement a echoue. Tu peux reessayer depuis les reglages.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.error,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action buttons (when not downloading and not completed)
            if (!isDownloading && !isCompleted) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: slm.isProcessing
                      ? null
                      : () => slm.downloadModel(),
                  icon: const Icon(Icons.download),
                  label: Text(
                    'Installer le coach IA',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Plus tard',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
