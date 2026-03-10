import 'package:flutter/material.dart';

class MintColors {
  // Primary - Neo-Sober Anthracite (Replaces Emerald/Teal)
  static const Color primary = Color(0xFF1D1D1F); // Apple Anthracite
  static const Color primaryLight = Color(0xFF2D2D2F); // Gradient end
  static const Color accent = Color(0xFF00382E); // Deep Green accent only
  static const Color accentPastel = Color(0xFFE0F2F1); // Soft Green for backgrounds

  
  // Selection / Highlight - Neutral & Premium
  static const Color selectionBg = Color(0xFFF5F5F7); 
  static const Color selectionBorder = Color(0xFF1D1D1F);
  
  // Neutrals - Minimalist
  static const Color background = Color(0xFFFFFFFF);
  static const Color appleSurface = Color(0xFFF5F5F7); 
  static const Color surface = Color(0xFFF5F5F7); 
  static const Color cardGround = Color(0xFFFBFBFD);  static const Color glassBackground = Color(0xB3FFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF); 
  static const Color card = Color(0xFFFFFFFF);
  
  // Text
  static const Color textPrimary = Color(0xFF1D1D1F);
  static const Color textSecondary = Color(0xFF6E6E73);
  static const Color textMuted = Color(0xFF86868B);
  
  // Accents
  static const Color success = Color(0xFF24B14D);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color error = Color(0xFFFF453A);
  static const Color info = Color(0xFF007AFF); // Apple Blue for neutral info
  
  // Borders
  static const Color border = Color(0xFFD2D2D7);
  static const Color lightBorder = Color(0xFFE5E5E7);

  // Trajectory colors (MINT Coach)
  static const Color trajectoryOptimiste = Color(0xFF24B14D);
  static const Color trajectoryBase = Color(0xFF007AFF);
  static const Color trajectoryPrudent = Color(0xFFFF9F0A);

  // Score gradient (MINT Coach)
  static const Color scoreExcellent = Color(0xFF24B14D);
  static const Color scoreBon = Color(0xFF8BC34A);
  static const Color scoreAttention = Color(0xFFFF9F0A);
  static const Color scoreCritique = Color(0xFFFF453A);
  // Score aliases (used by coach widgets)
  static const Color scoreGreen = scoreExcellent;
  static const Color scoreRed = scoreCritique;

  // Coach (MINT Coach)
  static const Color coachBubble = Color(0xFFF0F7FF);
  static const Color coachAccent = Color(0xFF007AFF);

  // Extended palette (educational themes & life events)
  static const Color purple = Color(0xFF8B5CF6);
  static const Color pink = Color(0xFFEC4899);
  static const Color cyan = Color(0xFF0891B2);
  static const Color indigo = Color(0xFF4F46E5);
  static const Color deepOrange = Color(0xFFEA580C);
  static const Color teal = Color(0xFF0D9488);
  static const Color amber = Color(0xFFF59E0B);

  // Retirement projection income sources
  static const Color retirementAvs = info;
  static const Color retirementLpp = success;
  static const Color retirement3a = purple;
  static const Color retirementLibre = teal;
}
