// LPP — l'écran insolent. Une ligne cruelle, un chiffre énorme.
// "Ta LPP te doit de l'argent." + le montant + 1 action.

function ScreenLPP({ palette }) {
  const p = palette;
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', padding: '0 0 24px' }}>
      {/* Header */}
      <div style={{
        padding: '10px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      }}>
        <div style={{ width: 28, height: 28, display: 'flex', alignItems: 'center' }}>
          <svg width="18" height="18" viewBox="0 0 18 18"><path d="M11 4l-5 5 5 5" stroke={p.ink} strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
        </div>
        <div style={{ ...SCALE.eyebrow, color: p.inkMute }}>Scan LPP</div>
        <div style={{ width: 28 }}/>
      </div>

      {/* Hero — une phrase, un chiffre, c'est tout */}
      <div style={{ flex: 1, padding: '0 28px', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
        <div style={{ ...SCALE.titleM, color: p.ink, marginBottom: 28 }}>
          Ta LPP<br/>te doit de l'argent.
        </div>

        <div style={{ position: 'relative', marginBottom: 32 }}>
          <div style={{ ...SCALE.numXL, color: p.ink, lineHeight: 0.9 }}>
            3'400
          </div>
          <div style={{
            position: 'absolute', right: 0, bottom: 8,
            ...SCALE.bodyLg, color: p.inkSoft, fontWeight: 500,
          }}>
            CHF
          </div>
        </div>

        <div style={{ ...SCALE.bodyLg, color: p.ink, maxWidth: 280 }}>
          En impôts économisés.<br/>
          <span style={{ color: p.inkSoft }}>Tu n'as rien à faire de compliqué.</span>
        </div>

        <ConfidenceBand palette={p} level="high" reason="taux marginal calculé sur ton avis 2024" style={{ marginTop: 16 }}/>

        {/* Sparkline discrète — preuve du calcul */}
        <div style={{
          marginTop: 16, padding: '16px 20px',
          background: p.surface, borderRadius: 16,
          border: `1px solid ${p.hairline}`,
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
            <div style={{ ...SCALE.meta, color: p.inkSoft }}>Ton taux marginal</div>
            <div style={{ ...SCALE.meta, color: p.ink, fontWeight: 500 }}>34%</div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ ...SCALE.meta, color: p.inkSoft }}>Rachat possible</div>
            <div style={{ ...SCALE.meta, color: p.ink, fontWeight: 500 }}>jusqu'à 42'000</div>
          </div>
        </div>
      </div>

      <div style={{ padding: '0 16px' }}>
        <Pill palette={p} filled style={{ justifyContent: 'space-between', width: '100%' }}>
          <span>Racheter 10'000</span>
          <svg width="14" height="14" viewBox="0 0 14 14"><path d="M1 7h12m-4-4l4 4-4 4" stroke={p.bg} strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
        </Pill>
        <div style={{ ...SCALE.meta, color: p.inkMute, textAlign: 'center', marginTop: 12 }}>
          Ou <span style={{ color: p.ink, textDecoration: 'underline', textUnderlineOffset: 3 }}>étaler sur 3 ans</span>
        </div>
      </div>
    </div>
  );
}

window.ScreenLPP = ScreenLPP;
