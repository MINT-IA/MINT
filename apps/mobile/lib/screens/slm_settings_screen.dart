import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/slm/slm_download_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';
import 'package:mint_mobile/theme/colors.dart';

/// SLM Settings Screen — On-device AI model management.
///
/// Allows the user to:
///   - Download/delete the Gemma 3n E4B model (~2.3 GB)
///   - Monitor download progress
///   - See model status (not downloaded / ready / running / error)
///   - Initialize the engine for on-device inference
///
/// Privacy: model runs 100% on-device, zero data leaves the device.
class SlmSettingsScreen extends StatefulWidget {
  const SlmSettingsScreen({super.key});

  @override
  State<SlmSettingsScreen> createState() => _SlmSettingsScreenState();
}

class _SlmSettingsScreenState extends State<SlmSettingsScreen> {
  final _downloadService = SlmDownloadService.instance;
  final _engine = SlmEngine.instance;

  ModelInfo? _modelInfo;
  bool _isLoading = true;
  bool _isProcessing = false;
  StreamSubscription<DownloadState>? _downloadSub;
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _loadModelInfo();
    _downloadSub = _downloadService.stateStream.listen((_) {
      _loadModelInfo();
    });
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  Future<void> _loadModelInfo() async {
    final seq = ++_loadSeq;
    final info = await _downloadService.getModelInfo();
    if (seq == _loadSeq && mounted) {
      setState(() {
        _modelInfo = info;
        _isLoading = false;
      });
    }
  }

  Future<void> _startDownload() async {
    if (_isProcessing) return;

    // Warn user about large download size before starting.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Telecharger le modele ?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Le modele fait ${SlmDownloadService.modelSizeFormatted}. '
          'Assure-toi d\'etre connecte en WiFi pour eviter '
          'une consommation importante de donnees mobiles.\n\n'
          '~${SlmDownloadService.estimatedDownloadMinutes()} min sur WiFi. '
          'Compatible : iPhone 13+ / Pixel 7+.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Telecharger'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isProcessing = true);

    final success = await _downloadService.downloadModel(
      onProgress: (progress, downloaded, total) {
        if (mounted) setState(() {});
      },
    );

    if (!mounted) return;
    if (success) {
      // Auto-init after a successful install so SLM can be used immediately.
      await _engine.initialize();
    }
    await _loadModelInfo();
    if (!mounted) return;

    setState(() => _isProcessing = false);

    if (!success && _downloadService.state == DownloadState.failed) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Echec du telechargement. '
            'Verifie ta connexion WiFi et l\'espace disponible.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Reessayer',
            textColor: Colors.white,
            onPressed: _startDownload,
          ),
        ),
      );
    }
  }

  Future<void> _deleteModel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Supprimer le modele ?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Cela liberera ${SlmDownloadService.modelSizeFormatted} '
          'd\'espace. Tu pourras le re-telecharger a tout moment.',
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

    if (confirm != true || !mounted) return;

    setState(() => _isProcessing = true);
    await _engine.dispose();
    await _downloadService.deleteModel();
    if (mounted) {
      await _loadModelInfo();
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _initializeEngine() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final success = await _engine.initialize();

    if (mounted) {
      setState(() => _isProcessing = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur d\'initialisation du modele. '
                'Verifie que ton appareil est compatible.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                _buildModelCard(),
                const SizedBox(height: 16),
                _buildStatusCard(),
                const SizedBox(height: 16),
                _buildInfoCard(),
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
              'Le modele fonctionne 100% sur ton appareil. '
              'Aucune donnee ne quitte ton telephone.',
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

  Widget _buildModelCard() {
    if (_isLoading || _modelInfo == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final info = _modelInfo!;
    final downloadState = _downloadService.state;
    final isDownloading = downloadState == DownloadState.downloading;
    final isFailed = downloadState == DownloadState.failed;

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

            // ── State: Starting download (processing, not yet downloading) ──
            if (_isProcessing && !isDownloading && !info.isReady) ...[
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
                    'Demarrage du telechargement...',
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
                  value: _downloadService.progress,
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
                    '${(_downloadService.progress * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: MintColors.primary,
                    ),
                  ),
                  Text(
                    _formatDownloadedSize(_downloadService.progress),
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
                  onPressed: () => _downloadService.cancelDownload(),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Annuler le telechargement'),
                ),
              ),
            ],

            // ── State: Download failed ──
            if (isFailed && !_isProcessing) ...[
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
                        'Le telechargement a echoue. '
                        'Verifie ta connexion WiFi et '
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
                  onPressed: _startDownload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reessayer le telechargement'),
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],

            // ── State: Not started (initial) ──
            if (!isDownloading && !isFailed && !info.isReady && !_isProcessing)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _startDownload,
                  icon: const Icon(Icons.download),
                  label: Text(
                    'Telecharger (${SlmDownloadService.modelSizeFormatted})',
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
                  onPressed: _isProcessing ? null : _deleteModel,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Supprimer le modele',
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

  /// Format downloaded size as "X Mo / 2.3 Go".
  String _formatDownloadedSize(double progress) {
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

  Widget _buildStatusCard() {
    final engineStatus = _engine.status;
    final isReady = _modelInfo?.isReady == true;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (engineStatus) {
      case SlmStatus.running:
        statusText = 'Pret — le coach utilise l\'IA on-device';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
      case SlmStatus.ready:
        statusText = 'Modele telecharge — initialisation requise';
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
      case SlmStatus.error:
        statusText = 'Erreur — appareil non compatible ou memoire insuffisante';
        statusColor = Colors.red;
        statusIcon = Icons.error;
      case SlmStatus.downloading:
        statusText = 'Telechargement en cours...';
        statusColor = MintColors.primary;
        statusIcon = Icons.downloading;
      case SlmStatus.notDownloaded:
        statusText = isReady
            ? 'Modele pret — lance l\'initialisation'
            : 'Modele non telecharge';
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
                  onPressed: _isProcessing ? null : _initializeEngine,
                  icon: _isProcessing
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
                    _isProcessing
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

  Widget _buildInfoCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comment ca marche ?',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.download,
              'Telecharge le modele une fois (~${SlmDownloadService.estimatedDownloadMinutes()} min sur WiFi)',
            ),
            _buildInfoRow(
              Icons.phone_android,
              'L\'IA tourne directement sur ton telephone',
            ),
            _buildInfoRow(
              Icons.wifi_off,
              'Fonctionne meme sans connexion internet',
            ),
            _buildInfoRow(
              Icons.shield,
              'Tes donnees ne quittent jamais ton appareil',
            ),
            _buildInfoRow(
              Icons.speed,
              'Reponses en 2-4 secondes sur un appareil recent',
            ),
            const Divider(height: 24),
            Text(
              'Compatibilite : iPhone 13+ / Pixel 7+ / equivalent recent.\n'
              'Le modele necessite ~3 Go d\'espace disque et ~2 Go de RAM.',
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
