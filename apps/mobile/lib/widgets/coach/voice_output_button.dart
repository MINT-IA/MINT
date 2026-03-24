/// Voice output button — Sprint S63.
///
/// Small speaker icon button displayed next to coach messages.
/// Tapping starts TTS (text-to-speech) for the message text.
/// Tapping again stops playback.
///
/// Uses [VoiceService] + [VoiceConfig] via constructor injection for testability.
/// Accessibility: [Semantics] label toggles between play/stop.
/// All text via [S] (AppLocalizations). [MintColors] only — never hardcoded hex.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/coach/voice_config.dart';
import 'package:mint_mobile/services/coach/voice_service.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  VoiceOutputButton
// ────────────────────────────────────────────────────────────

/// Small speaker toggle button for coach message bubbles.
///
/// Usage:
/// ```dart
/// VoiceOutputButton(
///   voiceService: voiceService,
///   text: coachMessage.text,
/// )
/// ```
class VoiceOutputButton extends StatefulWidget {
  /// The [VoiceService] instance (injected for testability).
  final VoiceService voiceService;

  /// The coach message text to speak aloud.
  final String text;

  /// Optional [VoiceConfig]. Defaults to [VoiceConfig.standard].
  final VoiceConfig config;

  const VoiceOutputButton({
    super.key,
    required this.voiceService,
    required this.text,
    this.config = VoiceConfig.standard,
  });

  @override
  State<VoiceOutputButton> createState() => _VoiceOutputButtonState();
}

class _VoiceOutputButtonState extends State<VoiceOutputButton> {
  // Tracks whether *this* button instance is currently speaking.
  bool _isSpeakingThis = false;

  // ── Lifecycle ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    widget.voiceService.state.addListener(_onStateChange);
  }

  @override
  void dispose() {
    widget.voiceService.state.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;
    // If the service is no longer speaking, clear our local flag.
    if (widget.voiceService.state.value != VoiceState.speaking) {
      setState(() => _isSpeakingThis = false);
    }
  }

  // ── Tap handler ───────────────────────────────────────────

  Future<void> _onTap() async {
    if (_isSpeakingThis) {
      // Stop playback
      await widget.voiceService.stopSpeaking();
      setState(() => _isSpeakingThis = false);
      return;
    }

    // Guard: do not start if service is in an incompatible state
    final voiceState = widget.voiceService.state.value;
    if (voiceState == VoiceState.listening ||
        voiceState == VoiceState.processing) {
      return;
    }

    // Check TTS availability
    final available = await widget.voiceService.isTtsAvailable();
    if (!available || !mounted) return;

    setState(() => _isSpeakingThis = true);
    try {
      await widget.voiceService.speak(widget.text, config: widget.config);
    } on StateError {
      // Incompatible state — ignore.
    } catch (_) {
      // TTS unavailable — degrade gracefully.
    } finally {
      if (mounted) setState(() => _isSpeakingThis = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    final String semanticsLabel;
    final IconData icon;
    final Color iconColor;

    if (_isSpeakingThis) {
      semanticsLabel = l.voiceSpeakerStop;
      icon = Icons.stop_circle_outlined;
      iconColor = MintColors.primary;
    } else {
      semanticsLabel = l.voiceSpeakerLabel;
      icon = Icons.volume_up_outlined;
      iconColor = MintColors.textMuted;
    }

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: IconButton(
        onPressed: _onTap,
        icon: Icon(icon, color: iconColor),
        iconSize: 20.0,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        tooltip: semanticsLabel,
      ),
    );
  }
}
