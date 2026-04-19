// MINT tokens — extraits du codebase Flutter (apps/mobile/lib/theme/)
// Source of truth : colors.dart + mint_text_styles.dart (main branch, 19 avril 2026)

const MINT = {
  // Neutres
  background: '#FFFFFF',
  textPrimary: '#1D1D1F',
  textSecondary: '#6E6E73',
  textMuted: '#737378',
  border: '#D2D2D7',
  lightBorder: '#E5E5E7',

  // Palette premium (Visual Graal 2027 — §6)
  porcelaine: '#F7F4EE',   // fond chaud hero
  craie: '#FCFBF8',        // fond coach chat
  saugeClaire: '#D8E4DB',  // succès, cap cards
  bleuAir: '#CFE2F7',      // info, coach
  ardoise: '#3A3D44',      // texte profond
  pecheDouce: '#F5C8AE',   // accent chaud
  corailDiscret: '#E6855E',// attention chaude
  warmWhite: '#FAF8F5',

  // Data viz retraite
  retirementAvs: '#0062CC',
  retirementLpp: '#157B35',
  retirement3a: '#8B5CF6',
  retirementLibre: '#0D9488',

  // États
  success: '#157B35',
  successDeep: '#2E7D32',
  positive: '#10B981',
  warning: '#B45309',
  info: '#0062CC',

  // AAA tokens (AESTH-04)
  textSecondaryAaa: '#555560',
  textMutedAaa: '#525256',
  successAaa: '#0F5E28',
  infoAaa: '#004FA3',
};

// Typo — Montserrat (display, headlines) + Inter (body, labels)
// Fraunces sera ajoutée pour les moments éditoriaux (signature MINT)
const FONTS = {
  display: `'Montserrat', -apple-system, system-ui, sans-serif`,
  body: `'Inter', -apple-system, system-ui, sans-serif`,
  editorial: `'Fraunces', Georgia, serif`, // ajouté pour moments signature
};

// Text styles — du mint_text_styles.dart
const TYPE = {
  // Display (chiffres dominants)
  displayHero: { fontFamily: FONTS.display, fontSize: 56, fontWeight: 800, letterSpacing: -1.5, lineHeight: 1.0 },
  displayLarge: { fontFamily: FONTS.display, fontSize: 48, fontWeight: 800, letterSpacing: -1, lineHeight: 1.1 },
  displayMedium: { fontFamily: FONTS.display, fontSize: 32, fontWeight: 700, letterSpacing: -0.5, lineHeight: 1.15 },
  displaySmall: { fontFamily: FONTS.display, fontSize: 28, fontWeight: 700, letterSpacing: -0.3, lineHeight: 1.15 },

  // Headlines
  headlineLarge: { fontFamily: FONTS.display, fontSize: 26, fontWeight: 700, letterSpacing: -0.5, lineHeight: 1.15 },
  headlineMedium: { fontFamily: FONTS.display, fontSize: 22, fontWeight: 600, lineHeight: 1.2 },
  headlineSmall: { fontFamily: FONTS.display, fontSize: 20, fontWeight: 600, lineHeight: 1.2 },

  // Titles
  titleLarge: { fontFamily: FONTS.body, fontSize: 18, fontWeight: 600, lineHeight: 1.3 },
  titleMedium: { fontFamily: FONTS.body, fontSize: 16, fontWeight: 600, lineHeight: 1.3 },

  // Body
  bodyLarge: { fontFamily: FONTS.body, fontSize: 16, fontWeight: 400, lineHeight: 1.5 },
  bodyMedium: { fontFamily: FONTS.body, fontSize: 14, fontWeight: 400, lineHeight: 1.5 },
  bodySmall: { fontFamily: FONTS.body, fontSize: 13, fontWeight: 500, lineHeight: 1.4 },

  // Labels
  labelLarge: { fontFamily: FONTS.body, fontSize: 15, fontWeight: 500, lineHeight: 1.4 },
  labelMedium: { fontFamily: FONTS.body, fontSize: 12, fontWeight: 500, lineHeight: 1.3 },
  labelSmall: { fontFamily: FONTS.body, fontSize: 11, fontWeight: 500, lineHeight: 1.3 },

  // Micro
  micro: { fontFamily: FONTS.body, fontSize: 10, fontWeight: 400, fontStyle: 'italic', lineHeight: 1.3 },

  // Editorial (nouveau — Fraunces pour signatures)
  editorialDisplay: { fontFamily: FONTS.editorial, fontSize: 32, fontWeight: 500, letterSpacing: -0.5, lineHeight: 1.15, fontOpticalSizing: 'auto' },
  editorialLarge: { fontFamily: FONTS.editorial, fontSize: 22, fontWeight: 400, lineHeight: 1.3 },
  editorialBody: { fontFamily: FONTS.editorial, fontSize: 17, fontWeight: 400, lineHeight: 1.5 },
};

// Formatters suisses
const fmtCHF = (n) => {
  const s = Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '\u2019');
  return s;
};
const fmtCHFCompact = (n) => {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(n % 1_000_000 === 0 ? 0 : 1).replace('.', ',') + ' M';
  if (n >= 10_000) return fmtCHF(n);
  return fmtCHF(n);
};

Object.assign(window, { MINT, FONTS, TYPE, fmtCHF, fmtCHFCompact });
