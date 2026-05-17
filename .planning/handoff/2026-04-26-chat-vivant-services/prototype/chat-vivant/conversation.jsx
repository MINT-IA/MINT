// Conversation-démo : Phase 1 retraite (rente vs capital)
// 10 tours, 3 niveaux de projection démontrés

function Conversation({ onOpenCanvas, mode = 'vivant' }) {
  const [step, setStep] = React.useState(0);
  const scrollRef = React.useRef(null);

  const totalSteps = mode === 'vivant' ? 16 : 7;

  // Auto-scroll vers le bas à chaque nouvelle étape
  React.useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' });
    }
  }, [step]);

  // Auto-advance : démarre la conversation
  React.useEffect(() => {
    if (step >= totalSteps - 1) return;
    const delays = mode === 'vivant'
      ? [400, 900, 1800, 600, 2100, 700, 1200, 800, 1800, 1400, 2500, 800, 1800, 700, 1600, 600]
      : [400, 900, 1600, 900, 1400, 700, 1500];
    const t = setTimeout(() => setStep(s => s + 1), delays[step] || 1000);
    return () => clearTimeout(t);
  }, [step, mode, totalSteps]);

  // Reset quand on change de mode
  React.useEffect(() => { setStep(0); }, [mode]);

  return (
    <div ref={scrollRef} style={{
      flex: 1, overflowY: 'auto', overflowX: 'hidden',
      background: MINT.craie,
      padding: '18px 16px 40px',
    }}>
      {mode === 'vivant'
        ? <VivantScript step={step} onOpenCanvas={onOpenCanvas} />
        : <PlainScript step={step} />
      }

      {/* Bouton rejouer */}
      {step >= totalSteps - 1 && (
        <div style={{ display: 'flex', justifyContent: 'center', marginTop: 16 }}>
          <button onClick={() => setStep(0)} style={{
            padding: '8px 16px', borderRadius: 20,
            background: 'transparent', border: `0.5px solid ${MINT.border}`,
            ...TYPE.labelLarge, color: MINT.textSecondaryAaa, cursor: 'pointer',
            display: 'flex', alignItems: 'center', gap: 6,
          }}>
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
              <path d="M1 6a5 5 0 109-3L9 4M9 1v3H6" stroke={MINT.textMutedAaa} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
            Rejouer
          </button>
        </div>
      )}
    </div>
  );
}

// ─── Version VIVANTE (avec projections) ───
function VivantScript({ step, onOpenCanvas }) {
  return (
    <>
      {/* Marqueur de session éditorial */}
      <div style={{ textAlign: 'center', marginBottom: 18 }}>
        <div style={{ ...TYPE.labelSmall, color: MINT.textMutedAaa, letterSpacing: 1.2, textTransform: 'uppercase', fontSize: 10.5 }}>
          Aujourd'hui · 14:22
        </div>
        <div style={{ ...TYPE.bodySmall, color: MINT.textMutedAaa, marginTop: 2, fontStyle: 'italic', fontFamily: FONTS.editorial }}>
          Tu as 58 ans. 7 ans avant la retraite.
        </div>
      </div>

      {step >= 0 && (
        <Reveal>
          <UserBubble>Dis-moi — rente ou capital, à 65 ans ?</UserBubble>
        </Reveal>
      )}

      {step >= 1 && step < 2 && <TypingDots />}
      {step >= 2 && (
        <Reveal>
          <ChatBubbleMint>
            <MintText>
              Ni l'un ni l'autre avant qu'on regarde <em style={{ fontFamily: FONTS.editorial }}>combien tu gardes vraiment</em>, dans les deux cas.
            </MintText>
            <MintText>
              Tiens — je te pose la scène.
            </MintText>
          </ChatBubbleMint>
        </Reveal>
      )}

      {step >= 3 && (
        <Reveal delay={150}>
          <div style={{ marginLeft: 38, marginBottom: 14, marginRight: 2 }}>
            <SceneRenteCapital onOpenCanvas={onOpenCanvas} variant="inline" />
          </div>
        </Reveal>
      )}

      {step >= 4 && (
        <Reveal>
          <ChatBubbleMint showAvatar={false}>
            <MintText>
              Bouge l'âge — tu vois comment le vent tourne autour de <strong style={{ color: MINT.corailDiscret, fontWeight: 600 }}>{88} ans</strong>.
            </MintText>
          </ChatBubbleMint>
        </Reveal>
      )}

      {step >= 5 && (
        <Reveal>
          <UserBubble>Et si mon capital rapporte 4% ? Ça change quoi ?</UserBubble>
        </Reveal>
      )}

      {step >= 6 && step < 7 && <TypingDots />}
      {step >= 7 && (
        <Reveal>
          <ChatBubbleMint>
            <MintText>
              Ça repousse l'âge d'épuisement. Mais 4% réel net d'impôts, c'est <em style={{ fontFamily: FONTS.editorial }}>un pari</em>, pas une hypothèse.
            </MintText>
          </ChatBubbleMint>
        </Reveal>
      )}

      {step >= 8 && (
        <Reveal delay={100}>
          <div style={{ marginLeft: 38, marginBottom: 14, marginRight: 2 }}>
            <InsightCard
              label="Ce qui compte vraiment"
              pattern="sauge"
              color={MINT.successAaa}
              headline={<>Tu n'as pas besoin de choisir tout de suite. Tu dois <em style={{ fontFamily: FONTS.editorial }}>décider 3 ans avant</em>.</>}
              supporting="La LPP demande un préavis. On a le temps de regarder ça proprement, une variable à la fois."
            />
          </div>
        </Reveal>
      )}

      {step >= 9 && (
        <Reveal>
          <ChatBubbleMint showAvatar={false}>
            <MintText>
              On creuse la fiscalité et la transmission ?
            </MintText>
            <ActionChips>
              <Chip onClick={onOpenCanvas}>Creuser la scène</Chip>
              <Chip>Plus tard</Chip>
            </ActionChips>
          </ChatBubbleMint>
        </Reveal>
      )}

      {step >= 10 && (
        <Reveal>
          <UserBubble>Et si je rachetais sur mes dernières années de cotisation ?</UserBubble>
        </Reveal>
      )}

      {step >= 11 && step < 12 && <TypingDots />}
      {step >= 12 && (
        <Reveal>
          <ChatBubbleMint>
            <MintText>
              Là on touche à <em style={{ fontFamily: FONTS.editorial }}>la chose la plus rentable</em> que tu puisses faire avec ton salaire en Suisse. Regarde.
            </MintText>
          </ChatBubbleMint>
        </Reveal>
      )}

      {step >= 13 && (
        <Reveal delay={150}>
          <div style={{ marginLeft: 38, marginBottom: 14, marginRight: 2 }}>
            <SceneRachatLPP onOpenCanvas={onOpenCanvas} variant="inline" />
          </div>
        </Reveal>
      )}

      {step >= 14 && (
        <Reveal>
          <ChatBubbleMint showAvatar={false}>
            <MintText>
              Échelonné sur 4 ans, tu évites de casser la progressivité. Bouge le curseur pour sentir le levier.
            </MintText>
          </ChatBubbleMint>
        </Reveal>
      )}

      {step >= 15 && (
        <Reveal delay={200}>
          <div style={{ textAlign: 'center', marginTop: 18, marginBottom: 6 }}>
            <div style={{ ...TYPE.labelSmall, color: MINT.textMutedAaa, letterSpacing: 1, fontStyle: 'italic', fontFamily: FONTS.editorial, fontSize: 12 }}>
              — Fin du fil d'aujourd'hui —
            </div>
          </div>
        </Reveal>
      )}
    </>
  );
}

// ─── Version PLATE (chat actuel) — pour comparaison ───
function PlainScript({ step }) {
  return (
    <>
      {step >= 0 && (
        <Reveal>
          <UserBubble>Dis-moi — rente ou capital, à 65 ans ?</UserBubble>
        </Reveal>
      )}

      {step >= 1 && step < 2 && <TypingDots />}
      {step >= 2 && (
        <Reveal>
          <PlainBotBubble>
            Bonne question ! Le choix entre rente et capital dépend de plusieurs facteurs :
            {'\n\n'}
            • La rente te verse environ <strong>2'080 CHF/mois</strong> à vie{'\n'}
            • Le capital te donne <strong>426'400 CHF</strong> net (après impôts){'\n'}
            • La rente est plus intéressante si tu vis longtemps{'\n'}
            • Le capital est plus intéressant si tu as d'autres revenus
          </PlainBotBubble>
        </Reveal>
      )}

      {step >= 3 && (
        <Reveal>
          <PlainBotBubble>
            Pour approfondir, tu peux ouvrir la simulation "Rente vs Capital" dans l'onglet Explorer → Retraite → Rente ou capital.
          </PlainBotBubble>
        </Reveal>
      )}

      {step >= 4 && (
        <Reveal>
          <UserBubble>Et si mon capital rapporte 4% ? Ça change quoi ?</UserBubble>
        </Reveal>
      )}

      {step >= 5 && step < 6 && <TypingDots />}
      {step >= 6 && (
        <Reveal>
          <PlainBotBubble>
            Si ton capital rapporte 4% net d'impôts, l'âge d'épuisement se repousse d'environ 6-8 ans. Cependant, 4% net est une hypothèse ambitieuse à long terme.
            {'\n\n'}
            Tu peux modifier les paramètres dans le simulateur pour tester différents scénarios.
          </PlainBotBubble>
        </Reveal>
      )}
    </>
  );
}

function Reveal({ children, delay = 0 }) {
  return (
    <div style={{
      animation: `mintFadeIn 0.4s ease-out ${delay}ms both`,
    }}>
      <style>{`
        @keyframes mintFadeIn {
          from { opacity: 0; transform: translateY(6px); }
          to { opacity: 1; transform: translateY(0); }
        }
      `}</style>
      {children}
    </div>
  );
}

function ActionChips({ children }) {
  return (
    <div style={{ display: 'flex', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
      {children}
    </div>
  );
}

function Chip({ children, onClick }) {
  return (
    <button onClick={onClick} style={{
      padding: '8px 14px', borderRadius: 18,
      background: '#fff', border: `0.5px solid ${MINT.border}`,
      ...TYPE.labelLarge, color: MINT.textPrimary, fontWeight: 500,
      cursor: 'pointer',
    }}>
      {children}
    </button>
  );
}

Object.assign(window, { Conversation });
