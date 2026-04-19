// Carte Insight inline — Niveau 1 de projection
// Une petite scène éditoriale posée dans la bulle MINT, pas un widget grisâtre.

function InsightCard({ label, headline, supporting, color = null, pattern = 'porcelaine' }) {
  const bg = pattern === 'sauge' ? MINT.saugeClaire
    : pattern === 'peche' ? 'rgba(245, 200, 174, 0.35)'
    : pattern === 'craie' ? MINT.craie
    : MINT.porcelaine;
  const accent = color || MINT.corailDiscret;

  return (
    <div style={{
      background: bg,
      borderRadius: 16,
      padding: '16px 18px',
      border: `0.5px solid ${MINT.border}`,
      position: 'relative',
    }}>
      <div style={{
        ...TYPE.labelMedium, color: accent, textTransform: 'uppercase',
        letterSpacing: 1.2, fontWeight: 600, marginBottom: 6, fontSize: 10.5,
      }}>
        {label}
      </div>
      <div style={{ ...TYPE.editorialLarge, color: MINT.textPrimary, lineHeight: 1.3, marginBottom: supporting ? 6 : 0 }}>
        {headline}
      </div>
      {supporting && (
        <div style={{ ...TYPE.bodySmall, color: MINT.textSecondaryAaa, fontWeight: 400 }}>
          {supporting}
        </div>
      )}
    </div>
  );
}

// Petit widget "63% de ton train de vie" — montre une proportion vive
function RatioCard({ label, numerator, denominator, explainer }) {
  const pct = Math.round((numerator / denominator) * 100);
  return (
    <div style={{
      background: MINT.porcelaine,
      borderRadius: 16,
      padding: '18px 18px 16px',
      border: `0.5px solid ${MINT.border}`,
    }}>
      <div style={{
        ...TYPE.labelMedium, color: MINT.corailDiscret, textTransform: 'uppercase',
        letterSpacing: 1.2, fontWeight: 600, marginBottom: 10, fontSize: 10.5,
      }}>{label}</div>

      <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginBottom: 12 }}>
        <div style={{ ...TYPE.displayLarge, fontSize: 44, color: MINT.textPrimary, lineHeight: 1 }}>
          {pct}<span style={{ fontSize: 26, color: MINT.textSecondaryAaa, fontWeight: 600 }}>%</span>
        </div>
        <div style={{ ...TYPE.bodySmall, color: MINT.textSecondaryAaa, flex: 1, paddingBottom: 4 }}>
          {fmtCHF(numerator)} sur {fmtCHF(denominator)} CHF/mois
        </div>
      </div>

      {/* Barre de proportion */}
      <div style={{ position: 'relative', height: 6, borderRadius: 3, background: MINT.lightBorder, marginBottom: 10 }}>
        <div style={{
          position: 'absolute', left: 0, width: `${pct}%`, height: '100%', borderRadius: 3,
          background: `linear-gradient(90deg, ${MINT.retirementLpp}, ${MINT.retirementAvs})`,
        }} />
      </div>

      <div style={{ ...TYPE.bodySmall, color: MINT.textSecondaryAaa, lineHeight: 1.5 }}>
        {explainer}
      </div>
    </div>
  );
}

Object.assign(window, { InsightCard, RatioCard });
