// Scène projetée — Rente vs Capital (Niveau 2)
// Le hero du DS Flutter, rendu inline dans le chat, interactif.
// Slider âge d'espérance de vie → les chiffres bougent en live.

function SceneRenteCapital({ onOpenCanvas, variant = 'inline' }) {
  const [age, setAge] = React.useState(89);
  const [mode, setMode] = React.useState('rente'); // 'rente' | 'capital'

  // Modèle simple mais cohérent avec le doc Phase 1→4
  // Hypothèse : capital LPP 520'000, rente annuelle 24'960 (conversion 4.8%)
  // Capital fiscalisé ~82% net. Rendement capital placé : 2.5% réel.
  const capitalBrut = 520000;
  const tauxConversion = 0.048;
  const renteAnnuelle = capitalBrut * tauxConversion; // 24'960
  const renteMensuelle = renteAnnuelle / 12; // 2'080
  const impotCapital = 0.18;
  const capitalNet = capitalBrut * (1 - impotCapital); // 426'400
  const rendementReel = 0.025;

  // À l'âge donné, combien la rente a versé cumulé (fiscalisé à ~20% revenu)
  const anneesRetraite = age - 65;
  const renteCumuleeNette = renteAnnuelle * 0.80 * anneesRetraite;

  // Capital placé : combien reste à l'âge donné (consommé au même rythme net que la rente nette)
  const depenseAnnuelleEquivalente = renteAnnuelle * 0.80;
  let capitalRestant = capitalNet;
  for (let i = 0; i < anneesRetraite; i++) {
    capitalRestant = capitalRestant * (1 + rendementReel) - depenseAnnuelleEquivalente;
  }
  // Combien le capital a donné (cumulé net) = capitalNet initial - reste + rendements consommés
  // simplification lisible : "équivalent rente jusqu'à épuisement"
  const ageEpuisement = (() => {
    let r = capitalNet;
    let a = 65;
    while (r > 0 && a < 110) {
      r = r * (1 + rendementReel) - depenseAnnuelleEquivalente;
      a++;
    }
    return a;
  })();

  const avantageRente = age > ageEpuisement;
  const deltaRente = renteCumuleeNette - (capitalNet + (capitalRestant > 0 ? 0 : -capitalRestant));

  return (
    <div style={{
      background: MINT.porcelaine,
      borderRadius: 20,
      padding: variant === 'inline' ? '20px 18px' : '28px 24px',
      border: `0.5px solid ${MINT.border}`,
      position: 'relative',
    }}>
      {/* Header éditorial */}
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 4 }}>
        <div style={{ ...TYPE.labelMedium, color: MINT.corailDiscret, textTransform: 'uppercase', letterSpacing: 1.2, fontWeight: 600 }}>
          Scène
        </div>
        <div style={{ ...TYPE.labelSmall, color: MINT.textMutedAaa }}>
          ta LPP · {fmtCHF(capitalBrut)} CHF
        </div>
      </div>
      <div style={{ ...TYPE.editorialLarge, color: MINT.textPrimary, marginBottom: 22, lineHeight: 1.25 }}>
        Si tu vis jusqu'à <span style={{ ...TYPE.editorialLarge, color: MINT.corailDiscret, fontWeight: 500 }}>{age} ans</span>, la rente te <span style={{ fontStyle: 'italic' }}>{avantageRente ? 'rapporte plus' : 'coûte plus'}</span>.
      </div>

      {/* Chiffres côte à côte */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 16 }}>
        <SceneColumn
          label="Rente à vie"
          amount={renteCumuleeNette}
          sub={`${fmtCHF(renteMensuelle)} CHF/mois`}
          highlighted={avantageRente}
          color={MINT.retirementLpp}
        />
        <SceneColumn
          label="Capital placé"
          amount={capitalNet + Math.max(0, capitalRestant)}
          sub={capitalRestant > 0 ? `reste ${fmtCHF(capitalRestant)}` : `épuisé à ${ageEpuisement} ans`}
          highlighted={!avantageRente}
          color={MINT.retirement3a}
        />
      </div>

      {/* Ligne de vie — barre horizontale 65→100 */}
      <div style={{ marginBottom: 14 }}>
        <LifeLine age={age} setAge={setAge} ageEpuisement={ageEpuisement} />
      </div>

      {/* Phrase de recul */}
      <div style={{
        ...TYPE.bodySmall,
        color: MINT.textSecondaryAaa,
        background: MINT.craie,
        padding: '10px 14px',
        borderRadius: 12,
        marginBottom: variant === 'inline' ? 14 : 0,
        lineHeight: 1.5,
      }}>
        {avantageRente
          ? <>Pour toi qui as peu d'autres revenus, la rente protège <em>contre le risque de vivre longtemps</em>.</>
          : <>Tu pars tôt — le capital laisse un reste à tes proches.</>}
      </div>

      {/* CTA creuser (seulement en mode inline) */}
      {variant === 'inline' && (
        <button onClick={onOpenCanvas} style={{
          width: '100%', padding: '14px 18px', borderRadius: 14,
          background: MINT.textPrimary, color: '#fff',
          border: 'none', cursor: 'pointer',
          ...TYPE.titleMedium, color: '#fff',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}>
          <span>Creuser — fiscalité, transmission, sensibilité</span>
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <path d="M3 7h8M7 3l4 4-4 4" stroke="#fff" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </button>
      )}
    </div>
  );
}

function SceneColumn({ label, amount, sub, highlighted, color }) {
  return (
    <div style={{
      background: highlighted ? '#fff' : 'transparent',
      padding: highlighted ? '14px 14px' : '14px 4px',
      borderRadius: 14,
      border: highlighted ? `0.5px solid ${MINT.border}` : '0.5px solid transparent',
      boxShadow: highlighted ? '0 1px 3px rgba(0,0,0,0.04)' : 'none',
      transition: 'all 0.3s ease',
      position: 'relative',
    }}>
      <div style={{ ...TYPE.labelSmall, color: MINT.textMutedAaa, marginBottom: 6, letterSpacing: 0.2 }}>{label}</div>
      <div style={{
        ...TYPE.displaySmall,
        fontSize: 24,
        color: highlighted ? MINT.textPrimary : MINT.textSecondaryAaa,
        marginBottom: 2,
        fontVariantNumeric: 'tabular-nums',
      }}>
        <CountUp value={amount} duration={800} trigger={Math.round(amount / 1000)} /> <span style={{ fontSize: 13, fontWeight: 500, color: MINT.textMutedAaa }}>CHF</span>
      </div>
      <div style={{ ...TYPE.labelSmall, color: highlighted ? color : MINT.textMutedAaa, fontWeight: 500 }}>{sub}</div>
      {highlighted && (
        <div style={{
          position: 'absolute', top: 10, right: 10,
          width: 6, height: 6, borderRadius: 3, background: color,
        }} />
      )}
    </div>
  );
}

function LifeLine({ age, setAge, ageEpuisement }) {
  const min = 70, max = 100;
  const pct = ((age - min) / (max - min)) * 100;
  const epuisementPct = ((ageEpuisement - min) / (max - min)) * 100;

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6, ...TYPE.labelSmall, color: MINT.textMutedAaa }}>
        <span>70 ans</span>
        <span style={{ color: MINT.textSecondaryAaa, fontWeight: 600 }}>Espérance de vie</span>
        <span>100 ans</span>
      </div>
      <div style={{ position: 'relative', height: 36 }}>
        {/* track */}
        <div style={{
          position: 'absolute', left: 0, right: 0, top: 16, height: 4, borderRadius: 2,
          background: MINT.lightBorder,
        }} />
        {/* fill jusqu'à age */}
        <div style={{
          position: 'absolute', left: 0, width: `${pct}%`, top: 16, height: 4, borderRadius: 2,
          background: age > ageEpuisement ? MINT.retirementLpp : MINT.retirement3a,
          transition: 'width 0.2s ease, background 0.3s ease',
        }} />
        {/* marqueur épuisement capital */}
        <div style={{
          position: 'absolute', left: `${epuisementPct}%`, top: 10, width: 1.5, height: 16,
          background: MINT.textMutedAaa, opacity: 0.5, transform: 'translateX(-0.75px)',
        }} />
        <div style={{
          position: 'absolute', left: `${epuisementPct}%`, top: 28, ...TYPE.labelSmall,
          fontSize: 9.5, color: MINT.textMutedAaa, transform: 'translateX(-50%)', whiteSpace: 'nowrap',
        }}>
          capital épuisé
        </div>
        {/* slider invisible */}
        <input type="range" min={min} max={max} value={age} onChange={(e) => setAge(+e.target.value)}
          style={{
            position: 'absolute', inset: 0, width: '100%', height: '100%',
            opacity: 0, cursor: 'pointer', margin: 0,
          }} />
        {/* thumb visuel */}
        <div style={{
          position: 'absolute', left: `${pct}%`, top: 10, width: 16, height: 16, borderRadius: 8,
          background: '#fff', border: `2px solid ${age > ageEpuisement ? MINT.retirementLpp : MINT.retirement3a}`,
          transform: 'translateX(-50%)', boxShadow: '0 2px 6px rgba(0,0,0,0.15)',
          pointerEvents: 'none',
          transition: 'border-color 0.3s ease',
        }} />
      </div>
    </div>
  );
}

Object.assign(window, { SceneRenteCapital });
