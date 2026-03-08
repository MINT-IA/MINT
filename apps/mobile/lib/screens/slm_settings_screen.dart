import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/services/slm/slm_download_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';
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
              'IA on-device',
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
                _buildPrivacyBanner(),
                const SizedBox(height: 16),
                _buildModelCard(context, slm),
                const SizedBox(height: 16),
                _buildStatusCard(context, slm),
                const SizedBox(height: 16),
                _buildInfoCard(slm),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyBanner() {
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
              'Le modèle fonctionne 100% sur ton appareil. '
              'Aucune donnée ne quitte ton téléphone.',
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
                      ? Colors.green
                      : isFailed
                          ? Colors.red
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
              'Taille : ${SlmDownloadService.modelSizeFormatted}',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Version : ${info.version}',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            if (!info.isReady &&
                !slm.canAttemptDownload &&
                slm.prerequisiteWarning != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        slm.prerequisiteWarning!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.orange[900],
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
                    'Démarrage du téléchargement...',
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
                  backgroundColor: Colors.grey[200],
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
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '~${SlmDownloadService.estimatedDownloadMinutes()} min sur WiFi',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: slm.cancelDownload,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Annuler le téléchargement'),
                ),
              ),
            ],

            // ── State: Download failed ──
            if (isFailed && !slm.isProcessing) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        slm.lastError ??
                            'Le téléchargement a échoué. '
                                'Vérifie ta connexion WiFi et '
                                'l\'espace disponible sur ton appareil.',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.red[700]),
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
                        ? 'Réessayer le téléchargement'
                        : 'Téléchargement indisponible sur ce build',
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
                        ? 'Télécharger (${SlmDownloadService.modelSizeFormatted})'
                        : 'Téléchargement indisponible sur ce build',
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
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Supprimer le modèle',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
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
                'Ce build ne permet pas le téléchargement du modèle.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Télécharger le modèle ?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Le modèle fait ${SlmDownloadService.modelSizeFormatted}. '
          'Assure-toi d\'être connecté en WiFi pour éviter '
          'une consommation importante de données mobiles.\n\n'
          '~${SlmDownloadService.estimatedDownloadMinutes()} min sur WiFi. '
          'Compatible\u00a0: iPhone 13+ / Pixel 7+.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Télécharger'),
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
          slm.lastError ?? 'Vérifie ta connexion WiFi et l\'espace disponible.';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            'Échec du téléchargement. $reason',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
          action: slm.canAttemptDownload
              ? SnackBarAction(
                  label: 'Réessayer',
                  textColor: Colors.white,
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
          'Supprimer le modèle ?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Cela libérera ${SlmDownloadService.modelSizeFormatted} '
          'd\'espace. Tu pourras le re-télécharger à tout moment.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
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
        progress.clamp(0.0, 1.0) * SlmDownloadService.expectedSizeBytes;
    final totalGo = SlmDownloadService.expectedSizeBytes / (1024 * 1024 * 1024);
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

    switch (engineStatus) {
      case SlmStatus.running:
        statusText = 'Prêt — le coach utilise l\'IA on-device';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
      case SlmStatus.ready:
        statusText = 'Modèle téléchargé — initialisation requise';
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
      case SlmStatus.error:
        statusText = 'Erreur — appareil non compatible ou mémoire insuffisante';
        statusColor = Colors.red;
        statusIcon = Icons.error;
      case SlmStatus.downloading:
        statusText = 'Téléchargement en cours...';
        statusColor = MintColors.primary;
        statusIcon = Icons.downloading;
      case SlmStatus.notDownloaded:
        statusText = isReady
            ? 'Modèle prêt — lance l\'initialisation'
            : 'Modèle non téléchargé';
        statusColor = Colors.grey;
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
              'Statut du moteur',
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
                              const SnackBar(
                                content: Text(
                                    'Erreur d\'initialisation du modèle. '
                                    'Vérifie que ton appareil est compatible.'),
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
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(
                    slm.isProcessing
                        ? 'Initialisation...'
                        : 'Initialiser le moteur',
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

  Widget _buildInfoCard(SlmProvider slm) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comment ça marche ?',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.download,
              'Télécharge le modèle une fois (~${SlmDownloadService.estimatedDownloadMinutes()} min sur WiFi)',
            ),
            _buildInfoRow(
              Icons.phone_android,
              'L\'IA tourne directement sur ton téléphone',
            ),
            _buildInfoRow(
              Icons.wifi_off,
              'Fonctionne même sans connexion internet',
            ),
            _buildInfoRow(
              Icons.shield,
              'Tes données ne quittent jamais ton appareil',
            ),
            _buildInfoRow(
              Icons.speed,
              'Réponses en 2-4 secondes sur un appareil récent',
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.link,
              'Source modèle : ${SlmDownloadService.modelId}',
            ),
            _buildInfoRow(
              slm.hasAuthToken ? Icons.key : Icons.key_off,
              slm.hasAuthToken
                  ? 'Authentification HuggingFace : configurée'
                  : 'Authentification HuggingFace : non configurée (download impossible si URL Gemma gated)',
            ),
            Text(
              'Compatibilité : iPhone 13+ / Pixel 7+ / équivalent récent.\n'
              'Le modèle nécessite ~3 Go d\'espace disque et ~2 Go de RAM.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
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
