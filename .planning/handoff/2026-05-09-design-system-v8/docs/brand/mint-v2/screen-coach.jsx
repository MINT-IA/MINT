// Coach — le moment où le chat génère un visuel inline.
// 4 types d'artefacts, pas un seul. Selectable in-place.
// Streaming indicator pendant la génération.
// Confidence band exposée sur les chiffres clés.

const ARTEFACTS = [
  { id: 'decision',    label: 'Décision' },
  { id: 'comparison',  label: 'Comparaison' },
  { id: 'trajectory',  label: 'Trajectoire' },
  { id: 'sensitivity', label: 'Sensibilité' },
];

function ArtefactCard({ palette, kind, streaming }) {
  const p = palette;
  const wrap = {
    background: p.surface, borderRadius: 16,
    border: `1px solid ${p.hairline}`,
    padding: 18, marginBottom: 12,
    position: 'relative',
  };

  if (kind === 'decision') {
    return (
      <div style={wrap}>
        <div style={{ ...SCALE.eyebrow, color: p.inkMute, marginBottom: 12 }}>
          Rachat 10'000 · taux marginal 34%
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
          <div style={{
            height: 44, width: '66%', borderRadius: 6, background: p.inkFaint,
            display: 'flex', alignItems: 'center', paddingLeft: 12,
          }}>
            <div style={{ ...SCALE.meta, color: p.inkSoft }}>Toi · 6'600</div>
          </div>
          <div style={{
            height: 44, flex: 1, borderRadius: 6, background: p.accent,
            display: 'flex', alignItems: 'center', paddingLeft: 12,
          }}>
            <div style={{ ...SCALE.meta, color: p.ink, fontWeight: 500 }}>État · 3'400</div>
          </div>
        </div>
        <div style={{
          display: 'flex', alignItems: 'baseline', gap: 6,
          paddingTop: 12, borderTop: `1px solid ${p.hairline}`, marginBottom: 10,
        }}>
          <div style={{ ...SCALE.meta, color: p.inkSoft, flex: 1 }}>À 65 ans, ça fait</div>
          <div style={{ ...SCALE.numM, color: p.ink }}>+240</div>
          <div style={{ ...SCALE.meta, color: p.inkSoft }}>CHF/mois à vie</div>
        </div>
        <ConfidenceBand palette={p} level="high" reason="impôts vérifiés sur ton avis 2024"/>
      </div>
    );
  }

  if (kind === 'comparison') {
    return (
      <div style={wrap}>
        <div style={{ ...SCALE.eyebrow, color: p.inkMute, marginBottom: 14 }}>
          Rachat LPP vs amortir hypo
        </div>
        {[
          { l: 'Rachat LPP', val: '+3\'400', sub: 'impôts récupérés', strong: true },
          { l: 'Amortir hypo', val: '+1\'200', sub: 'intérêts/an évités' },
        ].map((o, i) => (
          <div key={i} style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '10px 0', borderBottom: i === 0 ? `1px solid ${p.hairline}` : 'none',
          }}>
            <div>
              <div style={{ ...SCALE.body, color: p.ink, fontWeight: o.strong ? 500 : 400 }}>{o.l}</div>
              <div style={{ ...SCALE.meta, color: p.inkSoft }}>{o.sub}</div>
            </div>
            <div style={{
              ...SCALE.numM, color: p.ink,
              background: o.strong ? `linear-gradient(180deg, transparent 60%, ${p.accent} 60%)` : 'transparent',
              padding: o.strong ? '0 4px' : 0,
            }}>{o.val}</div>
          </div>
        ))}
        <div style={{ marginTop: 12 }}>
          <ConfidenceBand palette={p} level="medium" reason="hypothèse : taux hypo 1.8% maintenu"/>
        </div>
      </div>
    );
  }

  if (kind === 'trajectory') {
    // Tiny area chart — 3 ans → 65
    const years = [40, 45, 50, 55, 60, 65];
    const sansLPP =  [1850, 2400, 3000, 3600, 3950, 4200];
    const avecLPP =  [1850, 2680, 3400, 4150, 4750, 5800];
    const max = Math.max(...avecLPP);
    const W = 270, H = 100;
    const xs = (i) => (i / (years.length - 1)) * W;
    const ys = (v) => H - (v / max) * (H - 8) - 4;
    const path = (data) => data.map((v, i) => `${i === 0 ? 'M' : 'L'}${xs(i)},${ys(v)}`).join(' ');
    return (
      <div style={wrap}>
        <div style={{ ...SCALE.eyebrow, color: p.inkMute, marginBottom: 14 }}>
          Rente projetée — 40 → 65 ans
        </div>
        <svg width={W} height={H} style={{ display: 'block', marginBottom: 6 }}>
          <path d={`${path(sansLPP)} L${W},${H} L0,${H} Z`} fill={p.inkFaint}/>
          <path d={`${path(avecLPP)} L${W},${H} L0,${H} Z`} fill={p.accent} opacity="0.5"/>
          <path d={path(avecLPP)} fill="none" stroke={p.ink} strokeWidth="1.5"/>
          <path d={path(sansLPP)} fill="none" stroke={p.inkMute} strokeWidth="1.2" strokeDasharray="3 3"/>
        </svg>
        <div style={{ display: 'flex', justifyContent: 'space-between', ...SCALE.meta, color: p.inkMute, marginBottom: 14 }}>
          <span>40</span><span>65</span>
        </div>
        <div style={{ display: 'flex', gap: 14, marginBottom: 10 }}>
          <div style={{ flex: 1 }}>
            <div style={{ ...SCALE.meta, color: p.inkSoft }}>Sans rachats</div>
            <div style={{ ...SCALE.titleS, color: p.ink, fontWeight: 500 }}>4'200</div>
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ ...SCALE.meta, color: p.inkSoft }}>Avec rachats</div>
            <div style={{ ...SCALE.titleS, color: p.ink, fontWeight: 500 }}>5'800</div>
          </div>
        </div>
        <ConfidenceBand palette={p} level="low" reason="29 ans · hypothèses salaire + rendement"/>
      </div>
    );
  }

  if (kind === 'sensitivity') {
    return (
      <div style={wrap}>
        <div style={{ ...SCALE.eyebrow, color: p.inkMute, marginBottom: 14 }}>
          Si ton revenu change…
        </div>
        {[
          { l: '−10% revenu', val: '−800', col: p.inkSoft },
          { l: 'aujourd\'hui', val: '3\'400', col: p.ink, strong: true },
          { l: '+10% revenu', val: '+940',  col: p.ink },
          { l: '+25% revenu', val: '+2\'200', col: p.ink },
        ].map((o, i) => (
          <div key={i} style={{
            display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8,
          }}>
            <div style={{ ...SCALE.meta, color: p.inkSoft, width: 90 }}>{o.l}</div>
            <div style={{
              flex: 1, height: 22, borderRadius: 4,
              background: o.strong ? p.accent : p.inkFaint,
              position: 'relative', overflow: 'hidden',
            }}>
              <div style={{
                position: 'absolute', left: 8, top: 0, bottom: 0,
                display: 'flex', alignItems: 'center',
                ...SCALE.meta, color: o.strong ? p.ink : p.inkSoft, fontWeight: o.strong ? 500 : 400,
              }}>{o.val}</div>
            </div>
          </div>
        ))}
        <div style={{ marginTop: 12 }}>
          <ConfidenceBand palette={p} level="medium" reason="taux marginal recalculé à chaque palier"/>
        </div>
      </div>
    );
  }
}

function ScreenCoach({ palette }) {
  const p = palette;
  const [kind, setKind] = useState('decision');
  const [streaming, setStreaming] = useState(false);

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      {/* Header minimal */}
      <div style={{
        padding: '10px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        borderBottom: `1px solid ${p.hairline}`,
      }}>
        <div style={{ width: 28, height: 28, display: 'flex', alignItems: 'center' }}>
          <svg width="18" height="18" viewBox="0 0 18 18"><path d="M11 4l-5 5 5 5" stroke={p.ink} strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
        </div>
        <div style={{ ...SCALE.meta, color: p.ink, fontWeight: 500 }}>Coach</div>
        <div style={{ width: 28 }}/>
      </div>

      {/* Thread */}
      <div style={{ flex: 1, overflow: 'auto', padding: '20px 20px 0', display: 'flex', flexDirection: 'column', gap: 16 }}>

        {/* User question */}
        <div style={{ alignSelf: 'flex-end', maxWidth: '78%' }}>
          <div style={{
            ...SCALE.body, color: p.ink,
            background: p.inkFaint, padding: '10px 14px', borderRadius: '16px 16px 4px 16px',
          }}>
            Rachat LPP 10k, ça vaut le coup ?
          </div>
        </div>

        {/* Coach réponse */}
        <div style={{ maxWidth: '100%' }}>
          <div style={{ ...SCALE.body, color: p.ink, marginBottom: 12 }}>
            Oui. Tu récupères <span style={{ fontWeight: 500 }}>3'400 CHF</span> d'impôts tout de suite.
            {streaming && <StreamingDots palette={p} style={{ marginLeft: 6 }}/>}
          </div>

          {/* Sélecteur d'artefact — discret, comme des onglets de spreadsheet */}
          <div style={{
            display: 'flex', gap: 0, marginBottom: 10,
            borderBottom: `1px solid ${p.hairline}`,
          }}>
            {ARTEFACTS.map(a => (
              <button key={a.id} onClick={() => setKind(a.id)} style={{
                ...SCALE.meta, color: kind === a.id ? p.ink : p.inkMute,
                background: 'transparent', border: 'none', cursor: 'pointer',
                padding: '6px 10px',
                borderBottom: kind === a.id ? `2px solid ${p.ink}` : '2px solid transparent',
                marginBottom: -1, fontWeight: kind === a.id ? 500 : 400,
              }}>{a.label}</button>
            ))}
          </div>

          {/* L'artefact lui-même */}
          <ArtefactCard palette={p} kind={kind} streaming={streaming}/>

          {/* Suggestions de creusement */}
          <EnrichmentPrompts palette={p} prompts={[
            'd\'où sort le taux 34% ?',
            'étaler sur 3 ans ?',
            'ajuster mon revenu',
          ]}/>
        </div>
      </div>

      {/* Input avec streaming visible */}
      <div style={{ padding: 16 }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          background: p.surface, borderRadius: 24, padding: '4px 4px 4px 18px',
          border: `1px solid ${p.hairline}`,
        }}>
          <div style={{ flex: 1, ...SCALE.body, color: p.inkMute, padding: '10px 0' }}>
            Demande-moi…
          </div>
          <button onClick={() => setStreaming(s => !s)} style={{
            width: 36, height: 36, borderRadius: 18, background: streaming ? p.accent : p.ink,
            border: 'none', cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            {streaming
              ? <div style={{ width: 10, height: 10, borderRadius: 2, background: p.ink }}/>
              : <svg width="14" height="14" viewBox="0 0 14 14"><path d="M7 12V2m-4 4l4-4 4 4" stroke={p.bg} strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>}
          </button>
        </div>
      </div>
    </div>
  );
}

window.ScreenCoach = ScreenCoach;
