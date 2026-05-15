// Coach — état vide. Premier lancement, aucune donnée.
// Pas de "Bienvenue dans MINT 👋". Pas de tutoriel. Une question.
// L'utilisateur tape, MINT répond. C'est ça MINT.

function ScreenCoachEmpty({ palette }) {
  const p = palette;
  const seeds = [
    'Combien je peux racheter en LPP ?',
    'Mon hypothèque tient à 720k ?',
    'Si je passe indépendant, je perds quoi ?',
    'Mariage : qu\'est-ce qui change pour mon impôt ?',
  ];
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

      {/* Espace vide assumé — un seul prompt central */}
      <div style={{
        flex: 1, padding: '0 28px',
        display: 'flex', flexDirection: 'column', justifyContent: 'center',
      }}>
        <Eyebrow palette={p} style={{ marginBottom: 14 }}>Demande</Eyebrow>
        <div style={{ ...SCALE.titleM, color: p.ink, maxWidth: 280, marginBottom: 8 }}>
          Pose ta question.
        </div>
        <div style={{ ...SCALE.body, color: p.inkSoft, marginBottom: 28 }}>
          Je réponds avec un graphique, pas un mur de texte.
        </div>

        {/* Suggestions seed — pas trop, pas formel */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {seeds.map((q, i) => (
            <button key={i} style={{
              ...SCALE.body, color: p.ink, background: p.surface,
              border: `1px solid ${p.hairline}`, borderRadius: 14,
              padding: '12px 16px', cursor: 'pointer', textAlign: 'left',
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              fontFamily: 'var(--ui)',
            }}>
              <span>{q}</span>
              <svg width="14" height="14" viewBox="0 0 14 14"><path d="M5 2l5 5-5 5" stroke={p.inkMute} strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
            </button>
          ))}
        </div>
      </div>

      {/* Input */}
      <div style={{ padding: 16 }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          background: p.surface, borderRadius: 24, padding: '4px 4px 4px 18px',
          border: `1px solid ${p.hairline}`,
        }}>
          <div style={{ flex: 1, ...SCALE.body, color: p.inkMute, padding: '10px 0' }}>
            Demande-moi…
          </div>
          <button style={{
            width: 36, height: 36, borderRadius: 18, background: p.ink,
            border: 'none', cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="14" height="14" viewBox="0 0 14 14"><path d="M7 12V2m-4 4l4-4 4 4" stroke={p.bg} strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </button>
        </div>
      </div>
    </div>
  );
}

window.ScreenCoachEmpty = ScreenCoachEmpty;
