import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/slm/slm_download_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';
import 'package:mint_mobile/theme/colors.dart';
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

    // Model already downloaded → mark and skip.
    final isReady = await SlmDownloadService.instance.isModelReady;
    if (isReady) {
      await _markPrompted();
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
class _SlmDownloadSheet extends StatefulWidget {
  const _SlmDownloadSheet();

  @override
  State<_SlmDownloadSheet> createState() => _SlmDownloadSheetState();
}

class _SlmDownloadSheetState extends State<_SlmDownloadSheet> {
  bool _downloading = false;
  double _progress = 0;
  bool _completed = false;
  String? _error;
  StreamSubscription<DownloadState>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _error = null;
    });

    _sub = SlmDownloadService.instance.stateStream.listen((state) {
      if (!mounted) return;
      if (state == DownloadState.completed) {
        setState(() {
          _completed = true;
          _downloading = false;
          _progress = 1.0;
        });
        // Initialize the engine immediately after download.
        SlmEngine.instance.initialize();
      } else if (state == DownloadState.failed) {
        setState(() {
          _error = 'Le telechargement a echoue. Reessaie depuis les reglages.';
          _downloading = false;
        });
      }
    });

    final success = await SlmDownloadService.instance.downloadModel(
      onProgress: (progress, downloaded, total) {
        if (mounted) {
          setState(() => _progress = progress);
        }
      },
    );

    if (!success && mounted && !_completed) {
      setState(() {
        _downloading = false;
        _error ??=
            'Le telechargement a echoue. Tu peux reessayer depuis les reglages.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
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
                const Icon(Icons.storage, size: 16, color: MintColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  SlmDownloadService.modelSizeFormatted,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textMuted,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.wifi, size: 16, color: MintColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  '~${SlmDownloadService.estimatedDownloadMinutes()} min en WiFi',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress bar (when downloading)
            if (_downloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  backgroundColor: MintColors.lightBorder,
                  color: MintColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.primary,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Completed message
            if (_completed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MintColors.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: MintColors.success, size: 20),
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
            if (_error != null) ...[
              Text(
                _error!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.error,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action buttons (when not downloading and not completed)
            if (!_downloading && !_completed) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _startDownload,
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
