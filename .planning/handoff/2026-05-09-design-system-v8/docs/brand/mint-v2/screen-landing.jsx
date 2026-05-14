// Landing — une idée, beaucoup d'air.
// Slogan default : "Ta vie financière, enfin lisible."
// Pas de CTA géant, pas d'enchaînement de 3 écrans d'onboarding. Un geste, c'est tout.

function ScreenLanding({ palette, slogan }) {
  const p = palette;
  const [titre, soustitre] = slogan;
  return (
    <div style={{
      height: '100%', padding: '24px 28px 0', position: 'relative',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Wordmark — tout petit, en haut */}
      <div style={{
        ...SCALE.eyebrow, color: p.ink, letterSpacing: '0.24em',
        marginTop: 16,
      }}>
        MINT
      </div>

      {/* Le hero — italique + rupture de ligne poétique */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', marginTop: -40 }}>
        <div style={{ ...SCALE.displayL, color: p.ink, marginBottom: 20 }}>
          {titre.split('\n').map((l, i) => (
            <div key={i}>{l}</div>
          ))}
        </div>
        {soustitre && (
          <div style={{ ...SCALE.bodyLg, color: p.inkSoft, maxWidth: 260 }}>
            {soustitre}
          </div>
        )}
      </div>

      {/* Un seul geste, pas de CTA qui hurle */}
      <div style={{ paddingBottom: 28, display: 'flex', flexDirection: 'column', gap: 14 }}>
        <Pill palette={p} filled style={{ justifyContent: 'center', width: '100%' }}>
          Commencer
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M1 7h12m-4-4l4 4-4 4" stroke={p.bg} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
        </Pill>
        <div style={{ ...SCALE.meta, color: p.inkMute, textAlign: 'center' }}>
          Déjà là ? <span style={{ color: p.ink, textDecoration: 'underline', textUnderlineOffset: 3 }}>Se connecter</span>
        </div>
      </div>
    </div>
  );
}

window.ScreenLanding = ScreenLanding;
