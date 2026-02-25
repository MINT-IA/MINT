import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/data/educational_themes.dart';
import 'package:mint_mobile/data/education_content.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/mint_ui_kit.dart';

class ThemeDetailScreen extends StatefulWidget {
  final String themeId;

  const ThemeDetailScreen({super.key, required this.themeId});

  @override
  State<ThemeDetailScreen> createState() => _ThemeDetailScreenState();
}

class _ThemeDetailScreenState extends State<ThemeDetailScreen>
    with SingleTickerProviderStateMixin {
  int? _selectedQuizAnswer;
  bool _quizAnswered = false;
  late AnimationController _heroController;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heroFade = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOut,
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOutCubic,
    ));
    _heroController.forward();
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawTheme = EducationData.getById(widget.themeId);
    if (rawTheme == null) {
      return Scaffold(
        backgroundColor: MintColors.background,
        appBar: AppBar(title: const Text('Theme inconnu')),
        body: const Center(
          child: Text('Ce theme n\'existe pas. Retour en arriere.'),
        ),
      );
    }
    final theme = rawTheme.localized(S.of(context));
    final content = EducationContentData.getContent(widget.themeId);

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Compact colored header ──
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: theme.color,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
              onPressed: () => context.pop(),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${theme.estimatedMinutes} min',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.color,
                      theme.color.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
                    child: SlideTransition(
                      position: _heroSlide,
                      child: FadeTransition(
                        opacity: _heroFade,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(theme.icon,
                                  color: Colors.white, size: 28),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              theme.title,
                              style: GoogleFonts.montserrat(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              theme.question,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.85),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Body content ──
          if (content != null)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildChiffreChoc(content, theme),
                  _buildIntro(content),
                  _buildKeyFacts(content, theme),
                  _buildQuiz(content, theme),
                  _buildFunFact(content, theme),
                  _buildSources(content),
                  _buildCTA(theme),
                  _buildReminder(theme),
                  _buildDisclaimer(),
                  const SizedBox(height: 40),
                ],
              ),
            )
          else
            // Fallback for themes without rich content
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(theme.icon, size: 64, color: theme.color),
                      const SizedBox(height: 24),
                      Text(
                        theme.question,
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: MintColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      MintPremiumButton(
                        title: theme.actionLabel,
                        subtitle: 'Action recommandee',
                        onTap: () => context.push(theme.route),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Chiffre Choc ───
  Widget _buildChiffreChoc(EducationTopicContent content, EducationalTheme theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.color.withValues(alpha: 0.08),
            theme.color.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.5 + (value * 0.5),
                  child: child,
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  content.chiffreChoc,
                  style: GoogleFonts.montserrat(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: theme.color,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  content.chiffreChocUnit,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content.chiffreChocLabel,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Introduction ───
  Widget _buildIntro(EducationTopicContent content) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Text(
        content.intro,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: MintColors.textPrimary,
          height: 1.6,
        ),
      ),
    );
  }

  // ─── Key Facts ───
  Widget _buildKeyFacts(EducationTopicContent content, EducationalTheme theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(Icons.checklist_rounded, size: 18, color: theme.color),
              ),
              const SizedBox(width: 10),
              Text(
                'L\'essentiel en 60 secondes',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...content.keyFacts.asMap().entries.map((entry) {
            final index = entry.key;
            final fact = entry.value;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 400 + (index * 100)),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(20 * (1 - value), 0),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: theme.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fact,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: MintColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Quiz ───
  Widget _buildQuiz(EducationTopicContent content, EducationalTheme theme) {
    final quiz = content.quiz;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _quizAnswered
              ? (_selectedQuizAnswer == quiz.correctIndex
                  ? MintColors.success.withValues(alpha: 0.3)
                  : MintColors.error.withValues(alpha: 0.3))
              : MintColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.quiz_outlined,
                    size: 18, color: Colors.purple),
              ),
              const SizedBox(width: 10),
              Text(
                'Teste tes connaissances',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            quiz.question,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ...quiz.options.asMap().entries.map((entry) {
            final idx = entry.key;
            final option = entry.value;
            final isSelected = _selectedQuizAnswer == idx;
            final isCorrect = idx == quiz.correctIndex;
            final showResult = _quizAnswered;

            Color bgColor = Colors.white;
            Color borderColor = MintColors.border;
            Color textColor = MintColors.textPrimary;
            IconData? trailingIcon;

            if (showResult && isCorrect) {
              bgColor = MintColors.success.withValues(alpha: 0.08);
              borderColor = MintColors.success;
              textColor = MintColors.success;
              trailingIcon = Icons.check_circle;
            } else if (showResult && isSelected && !isCorrect) {
              bgColor = MintColors.error.withValues(alpha: 0.08);
              borderColor = MintColors.error;
              textColor = MintColors.error;
              trailingIcon = Icons.cancel;
            } else if (isSelected && !showResult) {
              bgColor = theme.color.withValues(alpha: 0.08);
              borderColor = theme.color;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _quizAnswered
                      ? null
                      : () {
                          setState(() {
                            _selectedQuizAnswer = idx;
                            _quizAnswered = true;
                          });
                        },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: showResult && isCorrect
                                ? MintColors.success.withValues(alpha: 0.15)
                                : showResult && isSelected && !isCorrect
                                    ? MintColors.error.withValues(alpha: 0.15)
                                    : theme.color.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + idx), // A, B, C, D
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: showResult && isCorrect
                                    ? MintColors.success
                                    : showResult && isSelected && !isCorrect
                                        ? MintColors.error
                                        : theme.color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight:
                                  showResult && isCorrect
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (trailingIcon != null)
                          Icon(trailingIcon,
                              size: 22,
                              color: isCorrect
                                  ? MintColors.success
                                  : MintColors.error),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          // Quiz explanation
          if (_quizAnswered) ...[
            const SizedBox(height: 12),
            AnimatedOpacity(
              opacity: _quizAnswered ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selectedQuizAnswer == quiz.correctIndex
                      ? MintColors.success.withValues(alpha: 0.06)
                      : MintColors.warning.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedQuizAnswer == quiz.correctIndex
                        ? MintColors.success.withValues(alpha: 0.2)
                        : MintColors.warning.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _selectedQuizAnswer == quiz.correctIndex
                              ? Icons.celebration
                              : Icons.lightbulb_outline,
                          size: 18,
                          color: _selectedQuizAnswer == quiz.correctIndex
                              ? MintColors.success
                              : MintColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedQuizAnswer == quiz.correctIndex
                              ? 'Bravo !'
                              : 'Pas tout a fait...',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _selectedQuizAnswer == quiz.correctIndex
                                ? MintColors.success
                                : MintColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      quiz.explanation,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Fun Fact ───
  Widget _buildFunFact(EducationTopicContent content, EducationalTheme theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: MintColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 18, color: MintColors.warning),
              ),
              const SizedBox(width: 10),
              Text(
                'Le savais-tu ?',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content.funFact,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textPrimary,
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sources ───
  Widget _buildSources(EducationTopicContent content) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MintColors.lightBorder),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MintColors.lightBorder),
        ),
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        leading: const Icon(Icons.gavel_outlined,
            size: 18, color: MintColors.textMuted),
        title: Text(
          'Sources legales',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: MintColors.textSecondary,
          ),
        ),
        children: content.sources
            .map((source) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(Icons.article_outlined,
                            size: 14, color: MintColors.textMuted),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          source,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: MintColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ─── CTA ───
  Widget _buildCTA(EducationalTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: MintPremiumButton(
        title: theme.actionLabel,
        subtitle: 'Action recommandee \u2022 ${theme.estimatedMinutes} min',
        onTap: () => context.push(theme.route),
      ),
    );
  }

  // ─── Reminder ───
  Widget _buildReminder(EducationalTheme theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.notifications_active_outlined,
                size: 18, color: theme.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rappel',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  theme.reminderText,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Disclaimer (compliance) ───
  Widget _buildDisclaimer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline, size: 14, color: MintColors.textMuted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              EducationTopicContent.disclaimer,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textMuted,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
