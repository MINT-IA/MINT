// Canvas plein écran — Niveau 3 de projection
// La scène rente/capital se déplie avec ses 6 dimensions : fiscalité, inflation, transmission, sensibilité.
// L'utilisateur ferme → retour au chat avec récap du contexte vu.

function CanvasRenteCapital({ onClose, onReturnToChat }) {
  const [rendement, setRendement] = React.useState(2.5);
  const [ageVie, setAgeVie] = React.useState(89);

  const capitalBrut = 520000;
  const tauxConversion = 0.048;
  const renteAnn = capitalBrut * tauxConversion;
  const capitalNet = capitalBrut * 0.82;

  const ageEpuisement = React.useMemo(() => {
    let r = capitalNet;
    let a = 65;
    const depense = renteAnn * 0.80;
    while (r > 0 && a < 110) {
      r = r * (1 + rendement / 100) - depense;
      a++;
    }
    return a;
  }, [rendement]);

  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 100,
      background: MINT.porcelaine,
      overflowY: 'auto',
      overflowX: 'hidden',
      animation: 'slideUp 0.35s cubic-bezier(0.2, 0.8, 0.2, 1)',
    }}>
      <style>{`
        @keyframes slideUp {
          from { transform: translateY(40px); opacity: 0; }
          to { transform: translateY(0); opacity: 1; }
        }
      `}</style>

      {/* Header avec close */}
      <div style={{
        position: 'sticky', top: 0, zIndex: 10,
        padding: '52px 18px 14px',
        background: `linear-gradient(${MINT.porcelaine} 70%, rgba(247,244,238,0))`,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div>
          <div style={{ ...TYPE.labelMedium, color: MINT.corailDiscret, textTransform: 'uppercase', letterSpacing: 1.5, fontWeight: 600, marginBottom: 3 }}>
            Scène dépliée
          </div>
          <div style={{ ...TYPE.headlineMedium, color: MINT.textPrimary }}>Rente ou capital</div>
        </div>
        <button onClick={onClose} style={{
          width: 36, height: 36, borderRadius: 18, border: 'none', cursor: 'pointer',
          background: '#fff', boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="14" height="14" viewBox="0 0 14 14">
            <path d="M3 3l8 8M11 3l-8 8" stroke={MINT.textPrimary} strokeWidth="1.8" strokeLinecap="round" />
          </svg>
        </button>
      </div>

      <div style={{ padding: '0 18px 120px' }}>
        {/* Chapitre 1 — Ce que ça te verse */}
        <Chapitre num="01" titre="Ce que ça te verse">
          <div style={{ ...TYPE.editorialDisplay, fontSize: 30, color: MINT.textPrimary, marginBottom: 10, lineHeight: 1.15 }}>
            {fmtCHF(renteAnn / 12)} <span style={{ fontSize: 17, color: MINT.textSecondaryAaa, fontWeight: 500 }}>CHF/mois</span>, <span style={{ fontFamily: FONTS.editorial, fontStyle: 'italic', color: MINT.corailDiscret }}>à vie</span>.
          </div>
          <div style={{ ...TYPE.bodyMedium, color: MINT.textSecondaryAaa, marginBottom: 14 }}>
            La rente LPP vient chaque mois, aussi longtemps que tu vis. Ta caisse assume le risque de vieillesse.
          </div>
          <Hypothese>
            Capital vieillesse {fmtCHF(capitalBrut)} · Taux de conversion {(tauxConversion*100).toFixed(1)}%
          </Hypothese>
        </Chapitre>

        {/* Chapitre 2 — Ce que ça te coûte */}
        <Chapitre num="02" titre="Ce que ça te coûte">
          <div style={{ ...TYPE.editorialLarge, color: MINT.textPrimary, marginBottom: 16, lineHeight: 1.3 }}>
            Imposée chaque année comme un salaire.
          </div>
          <FiscalRow label="Rente" detail="~20% impôt annuel" value={fmtCHF(renteAnn * 0.80)} unit="CHF net/an" color={MINT.retirementLpp} />
          <FiscalRow label="Capital" detail="impôt séparé unique ~18%" value={fmtCHF(capitalNet)} unit="CHF net une fois" color={MINT.retirement3a} />
          <div style={{ ...TYPE.bodySmall, color: MINT.textSecondaryAaa, marginTop: 14, lineHeight: 1.5, fontStyle: 'italic' }}>
            L'impôt sur capital Genève à 18% est calculé séparément du revenu, taux réduit.
          </div>
        </Chapitre>

        {/* Chapitre 3 — Ce que ça te laisse (transmission + durée) */}
        <Chapitre num="03" titre="Ce que ça te laisse">
          <div style={{
            display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 16,
          }}>
            <MiniCard
              label="Rente à ton décès"
              value="60%"
              unit="au conjoint"
              sub="14'976 CHF/an"
              bg={MINT.saugeClaire}
            />
            <MiniCard
              label="Capital à ton décès"
              value="100%"
              unit="au conjoint"
              sub="ou aux enfants"
              bg="rgba(245, 200, 174, 0.5)"
            />
          </div>
          <div style={{ ...TYPE.bodyMedium, color: MINT.textSecondaryAaa, lineHeight: 1.5 }}>
            Si transmettre compte pour toi, le capital garde toute sa valeur. La rente protège surtout le conjoint, et s'éteint ensuite.
          </div>
        </Chapitre>

        {/* Chapitre 4 — Sensibilité : c'est ici que ça devient MINT */}
        <Chapitre num="04" titre="Sensibilité" subtitle="bouge les hypothèses, regarde ce qui tient">
          <SensibiliteWidget
            ageVie={ageVie} setAgeVie={setAgeVie}
            rendement={rendement} setRendement={setRendement}
            ageEpuisement={ageEpuisement}
          />
        </Chapitre>

        {/* Verdict */}
        <div style={{
          marginTop: 32, padding: '22px 20px',
          background: MINT.textPrimary, borderRadius: 20, color: '#fff',
        }}>
          <div style={{ ...TYPE.labelMedium, color: MINT.pecheDouce, textTransform: 'uppercase', letterSpacing: 1.5, fontWeight: 600, marginBottom: 8 }}>
            Ce que je retiens pour toi
          </div>
          <div style={{ ...TYPE.editorialLarge, color: '#fff', lineHeight: 1.35, marginBottom: 16 }}>
            Tu as peu d'autres revenus garantis. La rente <em style={{ color: MINT.pecheDouce }}>protège le long</em>. Le capital, lui, <em style={{ color: MINT.pecheDouce }}>protège les tiens</em>.
          </div>
          <button onClick={onReturnToChat} style={{
            width: '100%', padding: '14px', borderRadius: 14,
            background: '#fff', color: MINT.textPrimary,
            border: 'none', cursor: 'pointer',
            ...TYPE.titleMedium, color: MINT.textPrimary,
          }}>
            Revenir au fil — avec ce que je viens de voir
          </button>
        </div>
      </div>
    </div>
  );
}

function Chapitre({ num, titre, subtitle, children }) {
  return (
    <div style={{ marginTop: 28 }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginBottom: 14 }}>
        <div style={{ ...TYPE.labelSmall, color: MINT.corailDiscret, fontWeight: 700, letterSpacing: 1.5, fontSize: 11 }}>
          {num}
        </div>
        <div>
          <div style={{ ...TYPE.headlineSmall, color: MINT.textPrimary }}>{titre}</div>
          {subtitle && <div style={{ ...TYPE.bodySmall, color: MINT.textMutedAaa, marginTop: 2 }}>{subtitle}</div>}
        </div>
      </div>
      <div style={{ background: '#fff', borderRadius: 18, padding: '20px 18px', border: `0.5px solid ${MINT.lightBorder}` }}>
        {children}
      </div>
    </div>
  );
}

function FiscalRow({ label, detail, value, unit, color }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '12px 0', borderBottom: `0.5px solid ${MINT.lightBorder}`,
    }}>
      <div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 6, height: 6, borderRadius: 3, background: color }} />
          <div style={{ ...TYPE.titleMedium, color: MINT.textPrimary }}>{label}</div>
        </div>
        <div style={{ ...TYPE.labelSmall, color: MINT.textMutedAaa, marginTop: 2, paddingLeft: 14 }}>{detail}</div>
      </div>
      <div style={{ textAlign: 'right' }}>
        <div style={{ ...TYPE.displaySmall, fontSize: 22, color: MINT.textPrimary, fontVariantNumeric: 'tabular-nums' }}>{value}</div>
        <div style={{ ...TYPE.labelSmall, color: MINT.textMutedAaa }}>{unit}</div>
      </div>
    </div>
  );
}

function MiniCard({ label, value, unit, sub, bg }) {
  return (
    <div style={{ background: bg, borderRadius: 14, padding: '14px 14px' }}>
      <div style={{ ...TYPE.labelSmall, color: MINT.textSecondaryAaa, fontWeight: 500, marginBottom: 6 }}>{label}</div>
      <div style={{ ...TYPE.displaySmall, fontSize: 26, color: MINT.textPrimary, marginBottom: 2 }}>
        {value}<span style={{ fontSize: 13, color: MINT.textSecondaryAaa, fontWeight: 500, marginLeft: 4 }}>{unit}</span>
      </div>
      <div style={{ ...TYPE.labelSmall, color: MINT.textMutedAaa }}>{sub}</div>
    </div>
  );
}

function Hypothese({ children }) {
  return (
    <div style={{
      ...TYPE.labelSmall, fontStyle: 'italic', color: MINT.textMutedAaa,
      paddingTop: 10, borderTop: `0.5px dashed ${MINT.border}`,
    }}>
      {children}
    </div>
  );
}

function SensibiliteWidget({ ageVie, setAgeVie, rendement, setRendement, ageEpuisement }) {
  return (
    <div>
      <SensSlider
        label="Espérance de vie"
        value={ageVie} setValue={setAgeVie} min={70} max={100}
        unit="ans" color={MINT.retirementLpp}
      />
      <div style={{ height: 14 }} />
      <SensSlider
        label="Rendement capital placé (réel)"
        value={rendement} setValue={setRendement} min={0} max={6} step={0.1}
        unit="%" color={MINT.retirement3a}
      />
      <div style={{
        marginTop: 18, padding: '14px 14px',
        background: MINT.porcelaine, borderRadius: 12,
        ...TYPE.bodySmall, color: MINT.textSecondaryAaa, lineHeight: 1.5,
      }}>
        <span style={{ fontFamily: FONTS.editorial, color: MINT.textPrimary, fontSize: 15 }}>
          Avec {rendement.toFixed(1)}% de rendement, ton capital s'épuise à <strong style={{ color: MINT.corailDiscret, fontWeight: 600 }}>{ageEpuisement} ans</strong>.
        </span>
        {' '}Si tu penses vivre plus longtemps, la rente reprend l'avantage.
      </div>
    </div>
  );
}

function SensSlider({ label, value, setValue, min, max, step = 1, unit, color }) {
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
        <div style={{ ...TYPE.labelLarge, color: MINT.textSecondaryAaa, fontWeight: 500 }}>{label}</div>
        <div style={{ ...TYPE.titleMedium, color: MINT.textPrimary, fontVariantNumeric: 'tabular-nums' }}>
          {typeof value === 'number' && step < 1 ? value.toFixed(1) : value}
          <span style={{ ...TYPE.labelSmall, color: MINT.textMutedAaa, fontWeight: 500, marginLeft: 3 }}>{unit}</span>
        </div>
      </div>
      <div style={{ position: 'relative', height: 24 }}>
        <div style={{ position: 'absolute', left: 0, right: 0, top: 10, height: 4, borderRadius: 2, background: MINT.lightBorder }} />
        <div style={{ position: 'absolute', left: 0, width: `${pct}%`, top: 10, height: 4, borderRadius: 2, background: color }} />
        <input type="range" min={min} max={max} step={step} value={value} onChange={(e) => setValue(+e.target.value)}
          style={{ position: 'absolute', inset: 0, width: '100%', opacity: 0, cursor: 'pointer', margin: 0 }} />
        <div style={{
          position: 'absolute', left: `${pct}%`, top: 4, width: 16, height: 16, borderRadius: 8,
          background: '#fff', border: `2px solid ${color}`, transform: 'translateX(-50%)',
          boxShadow: '0 2px 6px rgba(0,0,0,0.15)', pointerEvents: 'none',
        }} />
      </div>
    </div>
  );
}

Object.assign(window, { CanvasRenteCapital });
