// Trajectoire — 4 phases, chacune avec une action.
// Renommé : "Plan retraite" → "Trajectoire". Pas de framing retraite-first.
// Voix : retiré "largement mieux que la moyenne" (claim comparatif → LSFin).
// Italique retiré. Confidence + enrichment exposés sur le chiffre projeté.

function ScreenPlan({ palette }) {
  const p = palette;
  const phases = [
    { n: '01', titre: 'Comprendre', fait: true, detail: 'Tes 3 piliers, scannés.' },
    { n: '02', titre: 'Boucher les trous', fait: true, detail: '3ᵉ pilier · ouvert.' },
    { n: '03', titre: 'Racheter LPP', fait: false, detail: '10\'000 · −3\'400 d\'impôts.', actif: true },
    { n: '04', titre: 'Projeter', fait: false, detail: '2053 · 5\'800 CHF/mois.' },
  ];

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      {/* Header */}
      <div style={{ padding: '10px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ ...SCALE.eyebrow, color: p.inkMute }}>Trajectoire</div>
        <div style={{ ...SCALE.meta, color: p.inkSoft }}>2/4</div>
      </div>

      {/* Hero — projection sans claim comparatif */}
      <div style={{ padding: '20px 28px 24px' }}>
        <div style={{ ...SCALE.body, color: p.inkSoft, marginBottom: 6 }}>
          En 2053, à 65 ans
        </div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
          <div style={{ ...SCALE.numL, color: p.ink }}>5'800</div>
          <div style={{ ...SCALE.bodyLg, color: p.inkSoft }}>CHF/mois</div>
        </div>
        <div style={{ ...SCALE.body, color: p.ink, marginTop: 10, maxWidth: 270, marginBottom: 14 }}>
          Si tu termines les 4 phases. Sans rachat ni 3ᵉ pilier : 4'200 CHF.
        </div>
        <ConfidenceBand palette={p} level="low" reason="29 ans d'écart · projection sensible aux revenus"/>
        <EnrichmentPrompts palette={p} style={{ marginTop: 10 }} prompts={[
          'évolution salaire',
          'enfants prévus ?',
          'achat immobilier ?',
        ]}/>
      </div>

      <Rule palette={p} style={{ margin: '0 28px' }}/>

      {/* Les 4 phases — stepper vertical */}
      <div style={{ flex: 1, padding: '8px 0', overflow: 'auto' }}>
        {phases.map((ph, i) => (
          <div key={ph.n} style={{
            padding: '18px 28px',
            display: 'flex', alignItems: 'flex-start', gap: 16,
            position: 'relative',
            background: ph.actif ? p.accent + '22' : 'transparent',
          }}>
            {/* Ligne verticale */}
            {i < phases.length - 1 && (
              <div style={{
                position: 'absolute', left: 37, top: 40, bottom: -18, width: 1,
                background: p.hairline,
              }}/>
            )}
            {/* Dot */}
            <div style={{
              width: 28, height: 28, borderRadius: 14,
              background: ph.fait ? p.ink : (ph.actif ? p.accent : 'transparent'),
              border: ph.fait || ph.actif ? 'none' : `1.5px solid ${p.inkFaint}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              flexShrink: 0,
              color: ph.fait ? p.bg : p.ink,
              ...SCALE.meta, fontWeight: 500,
            }}>
              {ph.fait ? (
                <svg width="12" height="12" viewBox="0 0 12 12"><path d="M2 6l3 3 5-6" stroke={p.bg} strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
              ) : i + 1}
            </div>
            <div style={{ flex: 1 }}>
              <div style={{
                ...SCALE.eyebrow, color: p.inkMute, marginBottom: 4,
              }}>
                Phase {ph.n}{ph.actif ? ' · en cours' : ''}
              </div>
              <div style={{
                ...SCALE.titleS, color: ph.fait ? p.inkSoft : p.ink,
                textDecoration: ph.fait ? 'line-through' : 'none',
                textDecorationColor: p.inkMute,
              }}>
                {ph.titre}
              </div>
              <div style={{ ...SCALE.meta, color: p.inkSoft, marginTop: 4 }}>
                {ph.detail}
              </div>
            </div>
            {ph.actif && (
              <svg width="14" height="14" viewBox="0 0 14 14" style={{ marginTop: 6 }}><path d="M5 2l5 5-5 5" stroke={p.ink} strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
            )}
          </div>
        ))}
      </div>

      <div style={{
        padding: '12px 16px 20px',
        borderTop: `1px solid ${p.hairline}`,
      }}>
        <Pill palette={p} filled style={{ justifyContent: 'center', width: '100%' }}>
          Continuer la phase 3
        </Pill>
      </div>
    </div>
  );
}

window.ScreenPlan = ScreenPlan;
