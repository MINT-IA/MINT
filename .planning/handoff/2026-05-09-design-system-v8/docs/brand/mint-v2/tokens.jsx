// MINT v2 — Tokens. Trois palettes, une typo.
// Typo : PP Neue Montreal (grotesque, UI) + PP Editorial New (display, italique rare).
// Fallbacks solides.

const PALETTES = {
  // A — Menthe vive. Iconique, frais, Swiss precision.
  menthe: {
    id: 'menthe',
    name: 'Menthe vive',
    bg: '#F7F5EE',        // crème papier
    surface: '#FFFFFF',
    ink: '#0A0A0A',       // noir profond
    inkSoft: 'rgba(10,10,10,0.64)',
    inkMute: 'rgba(10,10,10,0.42)',
    inkFaint: 'rgba(10,10,10,0.12)',
    accent: '#9EE5C5',    // menthe saturée
    accentDeep: '#1C8466',
    hairline: 'rgba(10,10,10,0.08)',
  },
  // B — Encre + jaune acide. Radical.
  encre: {
    id: 'encre',
    name: 'Encre + acide',
    bg: '#F3F1EC',
    surface: '#FFFFFF',
    ink: '#0F0F10',
    inkSoft: 'rgba(15,15,16,0.62)',
    inkMute: 'rgba(15,15,16,0.40)',
    inkFaint: 'rgba(15,15,16,0.10)',
    accent: '#E8FF4D',    // jaune acide
    accentDeep: '#6A7A00',
    hairline: 'rgba(15,15,16,0.08)',
  },
  // C — Nuit suisse. Fintech posée.
  nuit: {
    id: 'nuit',
    name: 'Nuit suisse',
    bg: '#F4F4F2',
    surface: '#FFFFFF',
    ink: '#0E1B2E',
    inkSoft: 'rgba(14,27,46,0.66)',
    inkMute: 'rgba(14,27,46,0.44)',
    inkFaint: 'rgba(14,27,46,0.12)',
    accent: '#F0C9B8',    // rose papier
    accentDeep: '#B8442A',
    hairline: 'rgba(14,27,46,0.09)',
  },
  // D — Dark mode. Vrai noir.
  dark: {
    id: 'dark',
    name: 'Dark',
    bg: '#0B0B0C',
    surface: '#151517',
    ink: '#F4F2EC',
    inkSoft: 'rgba(244,242,236,0.64)',
    inkMute: 'rgba(244,242,236,0.42)',
    inkFaint: 'rgba(244,242,236,0.10)',
    accent: '#9EE5C5',
    accentDeep: '#1C8466',
    hairline: 'rgba(244,242,236,0.08)',
  },
};

const TYPE = {
  // Grotesque moderne — PP Neue Montreal via Fontshare
  ui: "'PP Neue Montreal', 'Neue Haas Grotesk', 'Inter', -apple-system, system-ui, sans-serif",
  // Display éditorial italique — PP Editorial New
  display: "'PP Editorial New', 'GT Sectra', 'Canela', 'Times New Roman', serif",
  // Mono pour chiffres techniques
  mono: "'JetBrains Mono', 'SF Mono', ui-monospace, monospace",
};

const SCALE = {
  // Micro / meta
  eyebrow: { fontFamily: 'var(--ui)', fontSize: 10, fontWeight: 500, letterSpacing: '0.14em', textTransform: 'uppercase' },
  meta:    { fontFamily: 'var(--ui)', fontSize: 12, fontWeight: 400, letterSpacing: '0.02em' },
  // Body
  body:    { fontFamily: 'var(--ui)', fontSize: 15, fontWeight: 400, lineHeight: 1.45, letterSpacing: '-0.005em' },
  bodyLg:  { fontFamily: 'var(--ui)', fontSize: 17, fontWeight: 400, lineHeight: 1.42, letterSpacing: '-0.008em' },
  // Titres UI
  titleS:  { fontFamily: 'var(--ui)', fontSize: 19, fontWeight: 500, lineHeight: 1.25, letterSpacing: '-0.01em' },
  titleM:  { fontFamily: 'var(--ui)', fontSize: 24, fontWeight: 500, lineHeight: 1.2,  letterSpacing: '-0.015em' },
  // Display éditorial — italique rare, réservé aux moments iconiques
  displayS: { fontFamily: 'var(--display)', fontStyle: 'italic', fontSize: 32, fontWeight: 400, lineHeight: 1.05, letterSpacing: '-0.02em' },
  displayM: { fontFamily: 'var(--display)', fontStyle: 'italic', fontSize: 44, fontWeight: 400, lineHeight: 1.0,  letterSpacing: '-0.025em' },
  displayL: { fontFamily: 'var(--display)', fontStyle: 'italic', fontSize: 62, fontWeight: 400, lineHeight: 0.96, letterSpacing: '-0.03em' },
  // Chiffres — grotesque tabulaire, PAS italique
  numXL:    { fontFamily: 'var(--ui)', fontSize: 88, fontWeight: 400, lineHeight: 0.9,  letterSpacing: '-0.04em', fontVariantNumeric: 'tabular-nums' },
  numL:     { fontFamily: 'var(--ui)', fontSize: 56, fontWeight: 400, lineHeight: 0.95, letterSpacing: '-0.03em', fontVariantNumeric: 'tabular-nums' },
  numM:     { fontFamily: 'var(--ui)', fontSize: 32, fontWeight: 400, lineHeight: 1.0,  letterSpacing: '-0.02em', fontVariantNumeric: 'tabular-nums' },
};

// Spacing suivant un rythme 4
const SP = { 1: 4, 2: 8, 3: 12, 4: 16, 5: 20, 6: 24, 8: 32, 10: 40, 12: 48, 16: 64 };

window.PALETTES = PALETTES;
window.TYPE = TYPE;
window.SCALE = SCALE;
window.SP = SP;
