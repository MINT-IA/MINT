import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/data/educational_themes.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/mint_ui_kit.dart';

class ThemeDetailScreen extends StatelessWidget {
  final String themeId;

  const ThemeDetailScreen({super.key, required this.themeId});

  @override
  Widget build(BuildContext context) {
    final theme = EducationData.getById(themeId);

    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: MintColors.textPrimary, size: 28),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Icon header
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(theme.icon, size: 48, color: theme.color),
                ),
              ),
              const SizedBox(height: 32),
              
              // Question (Hero)
              Text(
                theme.question,
                style: GoogleFonts.montserrat(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: MintColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const Spacer(),
              
              // Action Card (Premium Button)
              MintPremiumButton(
                title: theme.actionLabel,
                subtitle: "Action recommandée • 2 min", // Dynamic based on theme if possible, otherwise generic
                onTap: () {
                  context.push(theme.route);
                },
              ),
              
              const SizedBox(height: 32),
              
              // Reminder
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MintColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_outlined, size: 20, color: MintColors.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        theme.reminderText,
                        style: TextStyle(
                          fontSize: 13,
                          color: MintColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
