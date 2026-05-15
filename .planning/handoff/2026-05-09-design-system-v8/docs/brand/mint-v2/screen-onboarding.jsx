// Onboarding — une question à la fois. Pas 5 champs sur un écran.
// "Tu es né quand ?" — 4 gros chiffres, rien d'autre.

function ScreenOnboarding({ palette }) {
  const p = palette;
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', padding: '0 0 24px' }}>
      {/* Header — progression discrète */}
      <div style={{ padding: '10px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ width: 28, height: 28, display: 'flex', alignItems: 'center' }}>
          <svg width="18" height="18" viewBox="0 0 18 18"><path d="M11 4l-5 5 5 5" stroke={p.ink} strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
        </div>
        <Stepper n={2} total={6} palette={p}/>
        <div style={{ width: 28 }}/>
      </div>

      {/* Question */}
      <div style={{ padding: '40px 28px 0' }}>
        <Eyebrow palette={p} style={{ marginBottom: 14 }}>03 — Profil</Eyebrow>
        <div style={{ ...SCALE.displayM, color: p.ink }}>
          Tu es né<br/>quand ?
        </div>
        <div style={{ ...SCALE.body, color: p.inkSoft, marginTop: 14 }}>
          Pour calibrer ton plan. Rien d'autre.
        </div>
      </div>

      {/* Input — 4 blocs chiffres, style iconique */}
      <div style={{ flex: 1, padding: '48px 28px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'baseline' }}>
          {['1', '9', '9', '2'].map((c, i) => (
            <div key={i} style={{
              width: 56, height: 80,
              background: i === 3 ? p.accent : p.surface,
              border: i === 3 ? 'none' : `1px solid ${p.hairline}`,
              borderRadius: 12,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              ...SCALE.numM, color: p.ink,
            }}>{c}</div>
          ))}
        </div>
      </div>

      <div style={{ padding: '0 16px' }}>
        <Pill palette={p} filled style={{ justifyContent: 'center', width: '100%' }}>
          Continuer
        </Pill>
      </div>
    </div>
  );
}

window.ScreenOnboarding = ScreenOnboarding;
