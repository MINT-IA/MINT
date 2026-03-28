/// Voice input button — Sprint S63.
///
/// Mic button for the chat input area. Tapping starts STT listening;
/// the transcription is fed into the chat text field.
///
/// States: idle (mic_none) → listening (mic animated) → processing (hourglass).
/// Uses [VoiceService] + [VoiceConfig] via constructor injection for testability.
/// Accessibility: [Semantics] label changes with voice state.
/// All text via [S] (AppLocalizations). [MintColors] only — never hardcoded hex.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/coach/voice_config.dart';
import 'package:mint_mobile/services/coach/voice_service.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  VoiceInputButton
// ────────────────────────────────────────────────────────────

/// Animated mic button for the chat input bar.
///
/// Usage:
/// ```dart
/// VoiceInputButton(
///   voiceService: voiceService,
///   onTranscription: (text) => inputController.text = text,
/// )
/// ```
class VoiceInputButton extends StatefulWidget {
  /// The [VoiceService] instance (injected for testability).
  final VoiceService voiceService;

  /// Called when a final transcription is available.
  /// The caller should insert the text into the chat input field.
  final void Function(String transcript) onTranscription;

  /// Optional accessibility [VoiceConfig]. Defaults to [VoiceConfig.standard].
  final VoiceConfig config;

  /// Called when STT is unavailable on this device.
  final void Function()? onUnavailable;

  const VoiceInputButton({
    super.key,
    required this.voiceService,
    required this.onTranscription,
    this.config = VoiceConfig.standard,
    this.onUnavailable,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // ── Lifecycle ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    widget.voiceService.state.addListener(_onStateChange);
  }

  @override
  void dispose() {
    widget.voiceService.state.removeListener(_onStateChange);
    _pulseController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;
    setState(() {});
    final s = widget.voiceService.state.value;
    if (s == VoiceState.listening) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  // ── Tap handler ───────────────────────────────────────────

  Future<void> _onTap() async {
    final voiceState = widget.voiceService.state.value;

    // If already listening, stop
    if (voiceState == VoiceState.listening) {
      await widget.voiceService.stopListening();
      return;
    }

    // Guard: do nothing while speaking or processing
    if (voiceState == VoiceState.speaking ||
        voiceState == VoiceState.processing) {
      return;
    }

    // Check availability
    final available = await widget.voiceService.isAvailable();
    if (!available) {
      widget.onUnavailable?.call();
      return;
    }

    // Start listening
    try {
      final result = await widget.voiceService.listen(config: widget.config);
      if (!result.isEmpty) {
        widget.onTranscription(result.transcript.trim());
      }
    } on StateError {
      // Already in an incompatible state — ignore silently.
    } catch (_) {
      // Backend failure — degrade gracefully.
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final voiceState = widget.voiceService.state.value;
    final size = widget.config.voiceButtonSize;

    final String semanticsLabel;
    final IconData icon;
    final Color iconColor;
    final Color bgColor;

    switch (voiceState) {
      case VoiceState.listening:
        semanticsLabel = l.voiceMicListening;
        icon = Icons.mic;
        iconColor = Colors.white;
        bgColor = MintColors.primary;
      case VoiceState.processing:
        semanticsLabel = l.voiceMicProcessing;
        icon = Icons.hourglass_empty_rounded;
        iconColor = MintColors.textSecondary;
        bgColor = MintColors.surface;
      default:
        semanticsLabel = l.voiceMicLabel;
        icon = Icons.mic_none_rounded;
        iconColor = MintColors.textSecondary;
        bgColor = MintColors.surface;
    }

    Widget button = AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = voiceState == VoiceState.listening
            ? _pulseAnimation.value
            : 1.0;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: bgColor,
          shape: const CircleBorder(),
          elevation: voiceState == VoiceState.listening ? 4.0 : 0.0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _onTap,
            child: Center(
              child: voiceState == VoiceState.processing
                  ? SizedBox(
                      width: size * 0.40,
                      height: size * 0.40,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.0,
                        color: MintColors.textSecondary,
                      ),
                    )
                  : Icon(icon, color: iconColor, size: size * 0.45),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: button,
    );
  }
}
