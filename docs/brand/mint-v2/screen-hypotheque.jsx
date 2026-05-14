// Hypothèque — écran dense justifié.
// Voix : retiré "de justesse." (italique + jugeant) → observation neutre.
// Confidence + enrichment exposés sur le verdict.

function ScreenHypotheque({ palette }) {
  const p = palette;
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '10px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ width: 28, height: 28, display: 'flex', alignItems: 'center' }}>
          <svg width="18" height="18" viewBox="0 0 18 18"><path d="M11 4l-5 5 5 5" stroke={p.ink} strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
        </div>
        <div style={{ ...SCALE.eyebrow, color: p.inkMute }}>Hypothèque</div>
        <div style={{ width: 28 }}/>
      </div>

      {/* Titre court — observation, pas verdict */}
      <div style={{ padding: '16px 28px 20px' }}>
        <Eyebrow palette={p} style={{ marginBottom: 10 }}>Simulation · 820'000 CHF</Eyebrow>
        <div style={{ ...SCALE.titleM, color: p.ink, maxWidth: 280, marginBottom: 8 }}>
          Tu passes le test FINMA.
        </div>
        <div style={{ ...SCALE.body, color: p.inkSoft }}>
          Marge fine : 2'800 CHF/mois pour vivre.
        </div>
      </div>

      {/* Les 3 chiffres clés — alignés en grille, petits mais respirent */}
      <div style={{
        margin: '0 20px 12px', padding: '20px',
        background: p.surface, borderRadius: 20, border: `1px solid ${p.hairline}`,
      }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 0, marginBottom: 14 }}>
          <div>
            <div style={{ ...SCALE.numM, color: p.ink }}>28%</div>
            <div style={{ ...SCALE.meta, color: p.inkSoft, marginTop: 2 }}>taux d'effort</div>
          </div>
          <div style={{ borderLeft: `1px solid ${p.hairline}`, paddingLeft: 14 }}>
            <div style={{ ...SCALE.numM, color: p.ink }}>164k</div>
            <div style={{ ...SCALE.meta, color: p.inkSoft, marginTop: 2 }}>fonds propres</div>
          </div>
          <div style={{ borderLeft: `1px solid ${p.hairline}`, paddingLeft: 14 }}>
            <div style={{ ...SCALE.numM, color: p.ink }}>1.8%</div>
            <div style={{ ...SCALE.meta, color: p.inkSoft, marginTop: 2 }}>taux 10 ans</div>
          </div>
        </div>
        <ConfidenceBand palette={p} level="medium" reason="taux indicatif · banque à confirmer"/>
      </div>

      {/* Verdict — point insolent, accent papier, sans italique */}
      <div style={{ padding: '4px 28px 16px' }}>
        <div style={{ ...SCALE.body, color: p.ink, maxWidth: 310, marginBottom: 6 }}>
          Avec 164k en fonds propres, tu passes. Mais il te reste <span style={{ fontWeight: 500, background: `linear-gradient(180deg, transparent 60%, ${p.accent} 60%)`, padding: '0 2px' }}>2'800 CHF/mois</span> pour vivre.
        </div>
        <div style={{ ...SCALE.body, color: p.inkSoft, marginBottom: 10 }}>
          Large à Bulle. Serré à Genève.
        </div>
        <EnrichmentPrompts palette={p} prompts={[
          'tes charges mensuelles',
          'budget vacances ?',
        ]}/>
      </div>

      {/* Choix — 2 chemins, sans parti pris agressif */}
      <div style={{ padding: '0 16px 20px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div style={{
          padding: '16px 20px', background: p.surface, borderRadius: 16,
          border: `1.5px solid ${p.ink}`,
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
            <div style={{ ...SCALE.titleS, color: p.ink }}>Viser 650k</div>
            <div style={{ ...SCALE.meta, color: p.inkSoft }}>marge ample</div>
          </div>
          <div style={{ ...SCALE.meta, color: p.inkSoft }}>
            Mensualités 1'950 · reste 4'100 pour vivre
          </div>
        </div>
        <div style={{
          padding: '16px 20px', background: 'transparent', borderRadius: 16,
          border: `1px solid ${p.hairline}`,
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
            <div style={{ ...SCALE.titleS, color: p.ink }}>Tenir le 820k</div>
            <div style={{ ...SCALE.meta, color: p.inkSoft }}>marge fine</div>
          </div>
          <div style={{ ...SCALE.meta, color: p.inkSoft }}>
            2'460/mois · reste 2'800 pour vivre
          </div>
        </div>
      </div>
    </div>
  );
}

window.ScreenHypotheque = ScreenHypotheque;
