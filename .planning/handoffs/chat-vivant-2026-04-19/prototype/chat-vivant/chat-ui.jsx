// Composants chat — bulles MINT, composer, timestamp éditoriaux

function ChatBubbleMint({ children, showAvatar = true }) {
  return (
    <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start', marginBottom: 12 }}>
      {showAvatar ? <MintAvatar /> : <div style={{ width: 28, flexShrink: 0 }} />}
      <div style={{ flex: 1, minWidth: 0 }}>
        {children}
      </div>
    </div>
  );
}

function MintAvatar() {
  return (
    <div style={{
      width: 28, height: 28, borderRadius: 14, flexShrink: 0,
      background: MINT.textPrimary,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      marginTop: 2,
    }}>
      <div style={{
        ...TYPE.labelSmall, color: '#fff', fontWeight: 700, letterSpacing: 0.5,
        fontFamily: FONTS.display, fontSize: 10.5,
      }}>m</div>
    </div>
  );
}

function MintText({ children, editorial = false }) {
  return (
    <div style={{
      ...(editorial ? TYPE.editorialBody : TYPE.bodyLarge),
      color: MINT.textPrimary,
      lineHeight: 1.55,
      marginBottom: 2,
    }}>
      {children}
    </div>
  );
}

function UserBubble({ children }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 12 }}>
      <div style={{
        maxWidth: '78%',
        background: MINT.textPrimary, color: '#fff',
        borderRadius: '22px 22px 6px 22px',
        padding: '11px 16px',
        ...TYPE.bodyLarge, color: '#fff',
        fontSize: 15,
      }}>
        {children}
      </div>
    </div>
  );
}

// Version "chat actuel" (pour tweak avant/après)
function PlainBotBubble({ children }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'flex-start', marginBottom: 10 }}>
      <div style={{
        maxWidth: '82%',
        background: '#F2F2F7',
        borderRadius: '22px 22px 22px 6px',
        padding: '11px 16px',
        ...TYPE.bodyLarge, color: MINT.textPrimary,
        fontSize: 15,
      }}>
        {children}
      </div>
    </div>
  );
}

function TypingDots() {
  return (
    <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start', marginBottom: 12 }}>
      <MintAvatar />
      <div style={{
        background: MINT.craie, borderRadius: '18px 18px 18px 6px',
        padding: '12px 16px', display: 'flex', gap: 4, alignItems: 'center',
      }}>
        <style>{`
          @keyframes mintDot { 0%, 60%, 100% { opacity: 0.3; transform: translateY(0); } 30% { opacity: 1; transform: translateY(-3px); } }
        `}</style>
        {[0, 1, 2].map(i => (
          <div key={i} style={{
            width: 6, height: 6, borderRadius: 3, background: MINT.textMutedAaa,
            animation: `mintDot 1.2s ease-in-out ${i * 0.15}s infinite`,
          }} />
        ))}
      </div>
    </div>
  );
}

function Composer() {
  return (
    <div style={{
      padding: '10px 14px 20px', background: MINT.craie,
      borderTop: `0.5px solid ${MINT.lightBorder}`,
    }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 10,
        background: '#fff', borderRadius: 22, padding: '8px 8px 8px 16px',
        border: `0.5px solid ${MINT.border}`,
      }}>
        <div style={{ ...TYPE.bodyLarge, color: MINT.textMutedAaa, flex: 1, fontSize: 15 }}>
          Écris ou demande…
        </div>
        <div style={{
          width: 32, height: 32, borderRadius: 16, background: MINT.porcelaine,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="14" height="14" viewBox="0 0 14 14">
            <path d="M7 1v10M7 1l-3 3M7 1l3 3" stroke={MINT.textMutedAaa} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </div>
      </div>
    </div>
  );
}

function ChatHeader({ onBack }) {
  return (
    <div style={{
      padding: '58px 18px 12px', background: MINT.craie,
      display: 'flex', alignItems: 'center', gap: 12,
      borderBottom: `0.5px solid ${MINT.lightBorder}`,
    }}>
      <button onClick={onBack} style={{
        width: 32, height: 32, borderRadius: 16, border: 'none', background: 'transparent',
        cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <svg width="10" height="16" viewBox="0 0 10 16">
          <path d="M8 2L2 8l6 6" stroke={MINT.textPrimary} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
        </svg>
      </button>
      <div style={{ flex: 1 }}>
        <div style={{ ...TYPE.titleMedium, color: MINT.textPrimary, fontSize: 15 }}>MINT</div>
        <div style={{ ...TYPE.labelSmall, color: MINT.textMutedAaa, marginTop: 1 }}>
          Ta retraite · Phase 1 sur 4
        </div>
      </div>
      <div style={{
        width: 30, height: 30, borderRadius: 15, background: MINT.saugeClaire,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <div style={{ ...TYPE.labelSmall, color: MINT.successAaa, fontWeight: 600, fontSize: 11 }}>F1</div>
      </div>
    </div>
  );
}

Object.assign(window, {
  ChatBubbleMint, MintAvatar, MintText, UserBubble,
  PlainBotBubble, TypingDots, Composer, ChatHeader,
});
