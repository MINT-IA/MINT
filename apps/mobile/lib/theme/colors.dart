import 'package:flutter/material.dart';

class MintColors {
  // Primary - Neo-Sober Anthracite (Replaces Emerald/Teal)
  static const Color primary = Color(0xFF1D1D1F); // Apple Anthracite
  static const Color primaryLight = Color(0xFF2D2D2F); // Gradient end
  static const Color accent = Color(0xFF00382E); // Deep Green accent only
  static const Color accentPastel = Color(0xFFE0F2F1); // Soft Green for backgrounds

  
  // Selection / Highlight - Neutral & Premium
  static const Color selectionBg = Color(0xFFF5F5F7);
  
  // Transparent
  static const Color transparent = Color(0x00000000);

  // Neutrals - Minimalist
  static const Color background = Color(0xFFFFFFFF);
  static const Color appleSurface = Color(0xFFF5F5F7); 
  static const Color surface = Color(0xFFF5F5F7); 
  static const Color cardGround = Color(0xFFFBFBFD);
  static const Color card = Color(0xFFFFFFFF);
  
  // Text
  static const Color textPrimary = Color(0xFF1D1D1F);
  static const Color textSecondary = Color(0xFF6E6E73);
  static const Color textMuted = Color(0xFF86868B);
  
  // Accents
  // WCAG AA contrast fix: old #24B14D (2.81:1) → #1A8A3A (~4.8:1 on white)
  static const Color success = Color(0xFF1A8A3A);
  // WCAG AA contrast fix: old #FF9F0A (2.06:1) → #D97706 (~4.7:1 on white)
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFFF453A);
  static const Color info = Color(0xFF007AFF); // Apple Blue for neutral info
  
  // Borders
  static const Color border = Color(0xFFD2D2D7);
  static const Color lightBorder = Color(0xFFE5E5E7);

  // ── Premium palette (Visual Graal 2027 — Masterplan §6) ──
  /// Warm off-white background — replaces cold #FFFFFF on hero screens.
  static const Color porcelaine = Color(0xFFF7F4EE);
  /// Cream white — coach chat background, subtle warmth.
  static const Color craie = Color(0xFFFCFBF8);
  /// Sage green — success surfaces, cap cards, positive signals.
  static const Color saugeClaire = Color(0xFFD8E4DB);
  /// Air blue — coach bubbles, info surfaces.
  static const Color bleuAir = Color(0xFFCFE2F7);
  /// Slate — deep text alternative, premium contrast.
  static const Color ardoise = Color(0xFF3A3D44);
  /// Soft peach — warm accent, progression, milestones.
  static const Color pecheDouce = Color(0xFFF5C8AE);
  /// Discreet coral — attention accent, warm emphasis.
  static const Color corailDiscret = Color(0xFFE6855E);

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

  // Coach (MINT Coach) — warm cream, not cold support-chat blue.
  // "Ami cultivé qui travaille dans la finance suisse."
  static const Color coachBubble = Color(0xFFFCFBF8); // craie — warm
  static const Color coachAccent = Color(0xFF3A3D44); // ardoise — premium slate

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

  // Sentiment / risk indicators
  static const Color danger = Color(0xFFEF4444); // Negative delta, expenses
  static const Color positive = Color(0xFF10B981); // Positive delta, on-track
  static const Color critical = Color(0xFFB71C1C); // Severe status (disability)
  static const Color crisisRed = Color(0xFFDC2626); // Debt/crisis context
  static const Color successDeep = Color(0xFF2E7D32); // High confidence

  // Pillar & projection chart colors
  static const Color pillarLpp = Color(0xFF6366F1); // 2nd pillar (indigo-400)
  static const Color pillarAvsConjoint = Color(0xFF4DA6FF); // AVS spouse
  static const Color spouseSegment = Color(0xFF7C4DFF); // Regime matrimonial
  static const Color centralScenario = Color(0xFF4CAF50); // Central projection
  static const Color centralScenarioLight = Color(0xFF81C784); // Central light
  static const Color stressScenario = Color(0xFF2D6A4F); // Stress/prudent dark

  // Tool library category accents
  static const Color categoryGreen = Color(0xFF059669); // Savings, legal, tax
  static const Color categoryBlue = Color(0xFF2563EB); // Emploi, banque, hypothèque
  static const Color categoryAmber = Color(0xFFD97706); // Budget, dettes
  static const Color categoryPurple = Color(0xFF7C3AED); // 3a advanced, marriage
  static const Color categoryMagenta = Color(0xFFDB2777); // Family/marriage
  static const Color categoryMisc = Color(0xFFA2845E); // Default/miscellaneous

  // Urgency & pastel backgrounds
  static const Color urgentBg = Color(0xFFFFEBEE); // High urgency (light red)
  static const Color neutralBg = Color(0xFFE3F2FD); // Medium urgency (light blue)
  static const Color successBg = Color(0xFFE8F5E9); // Positive (light green)
  static const Color warningBg = Color(0xFFFFF3E0); // Caution (light amber)
  static const Color disclaimerBg = Color(0xFFFFF8E1); // Disclaimer (pale amber)
  static const Color successionBg = Color(0xFFF3E5F5); // Succession (light purple)
  static const Color pinkBg = Color(0xFFFCE4EC); // Family (light pink)

  // Contextual accents
  static const Color urgentOrange = Color(0xFFE65100); // Succession/retirement
  static const Color successionDark = Color(0xFF37474F); // Legal/succession header
  static const Color withdrawalOptim = Color(0xFF00695C); // Decaissement teal
  static const Color charcoal = Color(0xFF2D2D30); // Premium dark gradients

  // Additional chart & visualization colors
  static const Color greenLight = Color(0xFFA5D6A7); // Light green segments
  static const Color blueDark = Color(0xFF1565C0); // Dark blue charts
  static const Color violetDeep = Color(0xFF9333EA); // Deep purple
  static const Color purpleDark = Color(0xFF6A1B9A); // Dark purple
  static const Color indigoDeep = Color(0xFF4338CA); // Deep indigo
  static const Color indigoDark = Color(0xFF312E81); // Darkest indigo
  static const Color roseDeep = Color(0xFFE91E63); // Rose/pink
  static const Color orangeMaterial = Color(0xFFF97316); // Orange-400
  static const Color amberLight = Color(0xFFFBBF24); // Amber-400
  static const Color redDark = Color(0xFFC62828); // Dark red
  static const Color redDeep = Color(0xFFE53935); // Deep red
  static const Color greenApple = Color(0xFF34C759); // iOS green

  // Misc single-use (bank import, open banking, etc.)
  static const Color greyMedium = Color(0xFF9E9E9E); // Grey-500
  static const Color greyDark = Color(0xFF616161); // Grey-700
  static const Color greyWarm = Color(0xFF6B7280); // Grey-500 warm
  static const Color greyBorder = Color(0xFFE0E0E0); // Grey-300 border
  static const Color greyBorderLight = Color(0xFFBDBDBD); // Grey-400
  static const Color ecruBg = Color(0xFFECEFF1); // Blue-grey 50
  static const Color indigoBg = Color(0xFFE8EAF6); // Indigo-50
  static const Color redBg = Color(0xFFFFCDD2); // Red-100
  static const Color yellowGold = Color(0xFFFFE082); // Amber-200
  static const Color amberWarm = Color(0xFFFFECB3); // Amber-100
  static const Color amberDark = Color(0xFF856404); // Dark amber text
  static const Color orangeWarm = Color(0xFFFFA726); // Orange-400
  static const Color salmonLight = Color(0xFFFF7043); // Deep-orange 400
  static const Color coralLight = Color(0xFFFF6B6B); // Coral
  static const Color mintLight = Color(0xFF55E6C1); // Mint/teal light
  static const Color greenBright = Color(0xFF7BED9F); // Bright green
  static const Color greenNeon = Color(0xFF2ECC71); // Emerald (flat-ui)
  static const Color tealLight = Color(0xFF16A085); // Teal (flat-ui)
  static const Color greenIos = Color(0xFF30D158); // iOS system green
  static const Color greenForest = Color(0xFF1B5E20); // Green-900
  static const Color brownWarm = Color(0xFF5D4037); // Brown-700
  static const Color blueSteel = Color(0xFF78909C); // Blue-grey 400
  static const Color indigoMuted = Color(0xFF5C6BC0); // Indigo-400
  static const Color purpleApple = Color(0xFFAF52DE); // Apple purple
  static const Color blueApple = Color(0xFF5AC8FA); // Apple light blue
  static const Color purpleIos = Color(0xFF5856D6); // iOS purple
  static const Color darkNight = Color(0xFF1A1A2E); // Night dark
  static const Color darkDeep = Color(0xFF0D1117); // GitHub dark
  static const Color orangeFlat = Color(0xFFE67E22); // Orange flat-ui
  static const Color orangeNeon = Color(0xFFEE5A24); // Neon orange
  static const Color pinkHot = Color(0xFFFF6482); // Hot pink
  static const Color redApple = Color(0xFFFF2D55); // Apple red
  static const Color greenDirect = Color(0xFF22C55E); // Green-500
  static const Color greenDark = Color(0xFF388E3C); // Green-700
  static const Color greenMint = Color(0xFF32D74B); // iOS green mint
  static const Color greenClassic = Color(0xFF27AE60); // Flat green
  static const Color blueClassic = Color(0xFF2196F3); // Blue-500
  static const Color blueBright = Color(0xFF3B82F6); // Blue-500 tailwind
  static const Color tealDark = Color(0xFF004D40); // Teal-900
  static const Color orangeDarkDeep = Color(0xFFF57C00); // Orange-800
  static const Color orangeGold = Color(0xFFFF9500); // iOS orange
  static const Color orangeRetroWarm = Color(0xFFFF9F43); // Retro warm
  static const Color orangeSpice = Color(0xFFFFBE76); // Spice orange
  static const Color warningText = Color(0xFFF57F17); // Amber-900
  static const Color greyApple = Color(0xFF8E8E93); // Apple grey
  static const Color redBgLight = Color(0xFFFFF1F1); // Very light red bg
  static const Color warningBgLight = Color(0xFFFFF3CD); // Warning banner bg
  static const Color warningBgWarm = Color(0xFFFEF3C7); // Warm warning bg
  static const Color greenBgLight = Color(0xFFF0F9F4); // Very light green bg
  static const Color surfaceLight = Color(0xFFF5F5F5); // Near-white surface
  static const Color surfaceCool = Color(0xFFF0F0F2); // Cool surface
  static const Color darkRed = Color(0xFF991111); // Very dark red
  static const Color deepRed = Color(0xFF7B0000); // Deepest red
  static const Color redWine = Color(0xFFCC3333); // Wine red
  static const Color redMedium = Color(0xFFD32F2F); // Material red-700
  static const Color greenPastel = Color(0xFF66BB6A); // Green-400
  static const Color nearBlack = Color(0xFF0A0A0F); // Near-black overlay
  static const Color blueMaterial900 = Color(0xFF0D47A1); // Blue-900

  // Core neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color white70 = Color(0xB3FFFFFF); // 70% white
  static const Color white60 = Color(0x99FFFFFF); // 60% white
  static const Color white54 = Color(0x8AFFFFFF); // 54% white
  static const Color white30 = Color(0x4DFFFFFF); // 30% white
  static const Color white24 = Color(0x3DFFFFFF); // 24% white

}
