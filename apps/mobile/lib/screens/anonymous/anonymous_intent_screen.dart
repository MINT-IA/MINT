import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/theme/colors.dart';

/// Full-screen anonymous intent screen — MINT's first screen for
/// unauthenticated users. Two opening lines fade in sequentially,
/// then 6 felt-state pills appear staggered, plus a free-text field.
/// Any interaction routes to the coach chat with the user's intent
/// as initialPrompt.
class AnonymousIntentScreen extends StatefulWidget {
  const AnonymousIntentScreen({super.key});

  @override
  State<AnonymousIntentScreen> createState() => _AnonymousIntentScreenState();
}

class _AnonymousIntentScreenState extends State<AnonymousIntentScreen>
    with TickerProviderStateMixin {
  late final AnimationController _line1Controller;
  late final AnimationController _line2Controller;
  late final List<AnimationController> _pillControllers;
  late final AnimationController _textFieldController;

  // Slide animations for pills (slide up + fade).
  late final List<Animation<Offset>> _pillSlides;

  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _line1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _line2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _pillControllers = List.generate(6, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
    });

    _pillSlides = _pillControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
    }).toList();

    _textFieldController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _startSequence());
  }

  void _startSequence() {
    // t=800ms: Line 1 fades in
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _line1Controller.forward();
    });

    // t=3500ms: Line 2 fades in
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _line2Controller.forward();
    });

    // t=6000ms: 6 pills staggered 200ms apart
    for (var i = 0; i < 6; i++) {
      Future.delayed(Duration(milliseconds: 6000 + i * 200), () {
        if (mounted) _pillControllers[i].forward();
      });
    }

    // t=8000ms: Text field fades in
    Future.delayed(const Duration(milliseconds: 8000), () {
      if (mounted) _textFieldController.forward();
    });
  }

  void _navigateWithPrompt(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    context.go('/anonymous/chat?intent=${Uri.encodeComponent(trimmed)}');
  }

  @override
  void dispose() {
    _line1Controller.dispose();
    _line2Controller.dispose();
    for (final c in _pillControllers) {
      c.dispose();
    }
    _textFieldController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final pills = [
      l10n.anonymousIntentPill1,
      l10n.anonymousIntentPill2,
      l10n.anonymousIntentPill3,
      l10n.anonymousIntentPill4,
      l10n.anonymousIntentPill5,
      l10n.anonymousIntentPill6,
    ];

    return Scaffold(
      backgroundColor: MintColors.warmWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Spacer to roughly center content vertically on tall screens.
              SizedBox(height: MediaQuery.of(context).size.height * 0.22),

              // Line 1
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: FadeTransition(
                  opacity: _line1Controller,
                  child: Text(
                    l10n.anonymousIntentLine1,
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: MintColors.textPrimary,
                      letterSpacing: -0.3,
                      height: 1.35,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Line 2
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: FadeTransition(
                  opacity: _line2Controller,
                  child: Text(
                    l10n.anonymousIntentLine2,
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: MintColors.textSecondary,
                      letterSpacing: -0.3,
                      height: 1.35,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Pills
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(6, (index) {
                    return SlideTransition(
                      position: _pillSlides[index],
                      child: FadeTransition(
                        opacity: _pillControllers[index],
                        child: Semantics(
                          label: pills[index],
                          button: true,
                          child: GestureDetector(
                            onTap: () => _navigateWithPrompt(pills[index]),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: MintColors.craie,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: MintColors.lightBorder,
                                ),
                              ),
                              child: Text(
                                pills[index],
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: MintColors.textPrimary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 40),

              // Free text field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: FadeTransition(
                  opacity: _textFieldController,
                  child: TextField(
                    controller: _textController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _navigateWithPrompt,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: MintColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.anonymousIntentFreeTextHint,
                      hintStyle: GoogleFonts.inter(
                        fontSize: 16,
                        color: MintColors.textMuted,
                      ),
                      border: const UnderlineInputBorder(
                        borderSide: BorderSide(color: MintColors.lightBorder),
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: MintColors.lightBorder),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: MintColors.textPrimary),
                      ),
                      filled: false,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
