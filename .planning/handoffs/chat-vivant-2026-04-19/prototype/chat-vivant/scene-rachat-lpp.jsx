// Scène projetée — Rachat LPP échelonné (2e scène)
// "Et si tu rachetais 60'000 sur 4 ans ?" — l'économie fiscale animée + l'effet retraite.
// Plus minimal que la scène rente/capital : 1 slider (montant rachat), 2 chiffres signature.

function SceneRachatLPP({ onOpenCanvas, variant = 'inline' }) {
  const [montantRachat, setMontantRachat] = React.useState(60000);
  const [revealKey, setRevealKey] = React.useState(0);

  // Hypothèses (canton Genève, revenu 130k, marginal ~35%)
  const tauxMarginal = 0.35;
  const anneesEchelon = 4;
  const rachatAnnuel = montantRachat / anneesEchelon;
  const economieParAn = rachatAnnuel * tauxMarginal;
  const economieTotale = economieParAn * anneesEchelon;
  const coutReelNet = montantRachat - economieTotale;

  // Rente LPP additionnelle : taux de conversion 4.8%
  const renteAddAnnuelle = montantRachat * 0.048;
  const renteAddMensuelle = renteAddAnnuelle / 12;

  // Trigger un re-run du count-up quand le montant change
  React.useEffect(() => {
    const t = setTimeout(() => setRevealKey(k => k + 1), 80);
    return () => clearTimeout(t);
  }, [montantRachat]);

  return (
    <div style={{
      background: MINT.porcelaine,
      borderRadius: 20,
      padding: '20px 18px',
      border: `0.5px solid ${MINT.border}`,
    }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 4 }}>
        <div style={{ ...TYPE.labelMedium, color: MINT.corailDiscret, textTransform: 'uppercase', letterSpacing: 1.2, fontWeight: 600, fontSize: 10.5 }}>
          Scène
        </div>
        <div style={{ ...TYPE.labelSmall, color: MINT.textMutedAaa }}>
          rachat échelonné sur {anneesEchelon} ans
        </div>
      </div>
      <div style={{ ...TYPE.editorialLarge, color: MINT.textPrimary, marginBottom: 20, lineHeight: 1.25 }}>
        Si tu rachètes <span style={{ color: MINT.corailDiscret, fontWeight: 500 }}>{fmtCHF(montantRachat)}&nbsp;CHF</span>, tu <em style={{ fontStyle: 'italic' }}>récupères {fmtCHF(economieTotale)}&nbsp;CHF</em> en impôts.
      </div>

      {/* Deux chiffres côte à côte — économie / rente gagnée */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 18 }}>
        <div style={{
          background: '#fff', padding: '14px 14px', borderRadius: 14,
          border: `0.5px solid ${MINT.border}`,
        }}>
          <div style={{ ...TYPE.labelSmall, color: MINT.textMutedAaa, marginBottom: 6 }}>Économie fiscale</div>
          <div style={{ ...TYPE.displaySmall, fontSize: 24, color: MINT.successAaa, fontVariantNumeric: 'tabular-nums' }}>
            <CountUp value={economieTotale} duration={700} trigger={revealKey} /> <span style={{ fontSize: 13, fontWeight: 500, color: MINT.textMutedAaa }}>CHF</span>
          </div>
          <div style={{ ...TYPE.labelSmall, color: MINT.textMutedAaa, marginTop: 2 }}>
            ~{fmtCHF(economieParAn)}/an × {anneesEchelon}
          </div>
        </div>
        <div style={{
          background: '#fff', padding: '14px 14px', borderRadius: 14,
          border: `0.5px solid ${MINT.border}`,
        }}>
          <div style={{ ...TYPE.labelSmall, color: MINT.textMutedAaa, marginBottom: 6 }}>Rente en plus</div>
          <div style={{ ...TYPE.displaySmall, fontSize: 24, color: MINT.retirementLpp, fontVariantNumeric: 'tabular-nums' }}>
            +<CountUp value={renteAddMensuelle} duration={700} trigger={revealKey} /> <span style={{ fontSize: 13, fontWeight: 500, color: MINT.textMutedAaa }}>CHF/mois</span>
          </div>
          <div style={{ ...TYPE.labelSmall, color: MINT.textMutedAaa, marginTop: 2 }}>à vie dès 65 ans</div>
        </div>
      </div>

      {/* Slider montant rachat */}
      <RachatSlider montantRachat={montantRachat} setMontantRachat={setMontantRachat} />

      {/* Phrase de recul */}
      <div style={{
        ...TYPE.bodySmall,
        color: MINT.textSecondaryAaa,
        background: MINT.craie,
        padding: '10px 14px',
        borderRadius: 12,
        marginTop: 14, marginBottom: 14,
        lineHeight: 1.5,
      }}>
        Coût réel net : <strong style={{ color: MINT.textPrimary, fontWeight: 600 }}>{fmtCHF(coutReelNet)} CHF</strong>.
        {' '}Le reste, c'est l'État qui finance.
      </div>

      {variant === 'inline' && (
        <button onClick={onOpenCanvas} style={{
          width: '100%', padding: '14px 18px', borderRadius: 14,
          background: MINT.textPrimary, color: '#fff',
          border: 'none', cursor: 'pointer',
          ...TYPE.titleMedium, color: '#fff',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}>
          <span>Voir le plan année par année</span>
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <path d="M3 7h8M7 3l4 4-4 4" stroke="#fff" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </button>
      )}
    </div>
  );
}

function RachatSlider({ montantRachat, setMontantRachat }) {
  const min = 20000, max = 150000, step = 5000;
  const pct = ((montantRachat - min) / (max - min)) * 100;

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8, ...TYPE.labelSmall, color: MINT.textMutedAaa }}>
        <span>{fmtCHF(min)}</span>
        <span style={{ color: MINT.textSecondaryAaa, fontWeight: 600 }}>Montant du rachat</span>
        <span>{fmtCHF(max)}</span>
      </div>
      <div style={{ position: 'relative', height: 24 }}>
        <div style={{ position: 'absolute', left: 0, right: 0, top: 10, height: 4, borderRadius: 2, background: MINT.lightBorder }} />
        <div style={{
          position: 'absolute', left: 0, width: `${pct}%`, top: 10, height: 4, borderRadius: 2,
          background: MINT.corailDiscret,
          transition: 'width 0.2s ease',
        }} />
        <input type="range" min={min} max={max} step={step} value={montantRachat}
          onChange={(e) => setMontantRachat(+e.target.value)}
          style={{ position: 'absolute', inset: 0, width: '100%', opacity: 0, cursor: 'pointer', margin: 0 }} />
        <div style={{
          position: 'absolute', left: `${pct}%`, top: 4, width: 16, height: 16, borderRadius: 8,
          background: '#fff', border: `2px solid ${MINT.corailDiscret}`,
          transform: 'translateX(-50%)', boxShadow: '0 2px 6px rgba(0,0,0,0.15)',
          pointerEvents: 'none',
        }} />
      </div>
    </div>
  );
}

Object.assign(window, { SceneRachatLPP });
