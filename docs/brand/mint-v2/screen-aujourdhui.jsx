// Aujourd'hui — un seul chiffre à retenir.
// Voix : observateur, pas jugeant. "3ᵉ semaine. tendance tenue."
// Italique : retiré (réservé à Landing/Onboarding).
// Confidence band exposée + enrichment prompts.

function ScreenAujourdhui({ palette }) {
  const p = palette;
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      {/* Header minimal */}
      <div style={{
        padding: '8px 28px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      }}>
        <div style={{ ...SCALE.eyebrow, color: p.inkMute }}>Mardi · Avril</div>
        <div style={{
          width: 32, height: 32, borderRadius: 16,
          background: p.inkFaint,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          ...SCALE.meta, color: p.ink, fontWeight: 500,
        }}>L</div>
      </div>

      {/* Le hero : un chiffre, une phrase observatrice */}
      <div style={{ flex: 1, padding: '0 28px', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
        <Eyebrow palette={p} style={{ marginBottom: 16 }}>Cette semaine</Eyebrow>
        <div style={{ ...SCALE.numXL, color: p.ink, marginBottom: 12 }}>
          +<span>340</span>
          <span style={{ ...SCALE.bodyLg, color: p.inkSoft, marginLeft: 8, fontWeight: 500 }}>CHF</span>
        </div>
        <div style={{ ...SCALE.titleM, color: p.ink, maxWidth: 280, marginBottom: 10 }}>
          Tu gagnes plus que tu dépenses.
        </div>
        <div style={{ ...SCALE.body, color: p.inkSoft, marginBottom: 14 }}>
          3ᵉ semaine. Tendance tenue.
        </div>
        <ConfidenceBand palette={p} level="medium" reason="dépend des achats récurrents non catégorisés" style={{ marginBottom: 12 }}/>
        <EnrichmentPrompts palette={p} prompts={[
          'tes loyers récents',
          '14 transactions à classer',
        ]}/>
      </div>

      {/* Preuve visuelle : petite barre, pas de carte */}
      <div style={{ padding: '0 28px 20px' }}>
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 6, height: 64, marginBottom: 10 }}>
          {[22, 34, 18, 41, 28, 52, 46].map((h, i) => (
            <div key={i} style={{
              flex: 1, height: `${h}px`, borderRadius: 2,
              background: i === 6 ? p.accent : p.inkFaint,
            }}/>
          ))}
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <div style={{ ...SCALE.meta, color: p.inkMute }}>lun</div>
          <div style={{ ...SCALE.meta, color: p.inkMute }}>dim</div>
        </div>
      </div>

      {/* Zone coach — suggestion douce, pas un CTA agressif */}
      <div style={{
        margin: '0 20px 18px', padding: '16px 20px',
        borderRadius: 20, background: p.surface, border: `1px solid ${p.hairline}`,
        display: 'flex', alignItems: 'center', gap: 14,
      }}>
        <div style={{
          width: 36, height: 36, borderRadius: 18,
          background: p.accent, flexShrink: 0,
        }}/>
        <div style={{ flex: 1 }}>
          <div style={{ ...SCALE.body, color: p.ink, fontWeight: 500 }}>
            Ta LPP cache 3'400 CHF.
          </div>
          <div style={{ ...SCALE.meta, color: p.inkSoft, marginTop: 2 }}>
            Je te montre ?
          </div>
        </div>
        <svg width="16" height="16" viewBox="0 0 16 16"><path d="M6 4l4 4-4 4" stroke={p.inkMute} strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
      </div>

      {/* Tab bar — 3 onglets, pas 5 */}
      <div style={{
        display: 'flex', padding: '0 48px 8px', justifyContent: 'space-between',
      }}>
        {[
          { l: 'Aujourd\'hui', active: true },
          { l: 'Coach' },
          { l: 'Trajectoire' },
        ].map(t => (
          <div key={t.l} style={{
            ...SCALE.meta, fontWeight: t.active ? 500 : 400,
            color: t.active ? p.ink : p.inkMute,
            padding: '8px 0',
          }}>{t.l}</div>
        ))}
      </div>
    </div>
  );
}

window.ScreenAujourdhui = ScreenAujourdhui;
