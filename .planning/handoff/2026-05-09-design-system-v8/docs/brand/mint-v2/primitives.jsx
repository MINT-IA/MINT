// MINT v2 — Primitives UI.
// Phone frame iOS-like minimal, StatusBar, HomeIndicator.

const { useState, useEffect, useRef } = React;

function Phone({ children, palette, style }) {
  const p = palette;
  return (
    <div style={{
      width: 360, height: 780,
      borderRadius: 46,
      background: p.ink,
      padding: 6,
      boxShadow: '0 30px 80px rgba(0,0,0,0.18), 0 4px 12px rgba(0,0,0,0.08)',
      position: 'relative',
      ...style,
    }}>
      <div style={{
        width: '100%', height: '100%',
        borderRadius: 40,
        background: p.bg,
        overflow: 'hidden',
        position: 'relative',
        display: 'flex', flexDirection: 'column',
      }}>
        {/* Dynamic island */}
        <div style={{
          position: 'absolute', top: 10, left: '50%', transform: 'translateX(-50%)',
          width: 110, height: 32, borderRadius: 20, background: p.ink, zIndex: 10,
        }}/>
        {/* Status bar */}
        <div style={{
          height: 52, padding: '18px 28px 0', display: 'flex',
          justifyContent: 'space-between', alignItems: 'flex-start',
          fontFamily: TYPE.ui, fontSize: 15, fontWeight: 600, color: p.ink,
          flexShrink: 0, zIndex: 5,
        }}>
          <span>9:41</span>
          <span style={{ display: 'flex', gap: 5, alignItems: 'center' }}>
            <svg width="17" height="11" viewBox="0 0 17 11"><path d="M1 8h2v2H1zM5 6h2v4H5zM9 3h2v7H9zM13 0h2v10h-2z" fill={p.ink}/></svg>
            <svg width="15" height="11" viewBox="0 0 15 11"><path d="M7.5 2.5a7 7 0 014.95 2.05l-.71.7a6 6 0 00-8.48 0l-.7-.7A7 7 0 017.5 2.5zm0 3a4 4 0 012.83 1.17l-.7.7a3 3 0 00-4.24 0l-.71-.7A4 4 0 017.5 5.5zm0 3l1.06 1.06L7.5 10.62 6.44 9.56 7.5 8.5z" fill={p.ink}/></svg>
            <div style={{
              width: 22, height: 10, border: `1px solid ${p.ink}`, borderRadius: 2.5,
              position: 'relative', padding: 1,
            }}>
              <div style={{ width: '75%', height: '100%', background: p.ink, borderRadius: 1 }}/>
            </div>
          </span>
        </div>
        <div style={{ flex: 1, overflow: 'hidden', position: 'relative' }}>
          {children}
        </div>
        {/* Home indicator */}
        <div style={{
          height: 28, display: 'flex', justifyContent: 'center', alignItems: 'center',
          flexShrink: 0,
        }}>
          <div style={{ width: 130, height: 4, borderRadius: 2, background: p.ink }}/>
        </div>
      </div>
    </div>
  );
}

// Fine horizontal rule
function Rule({ palette, style }) {
  return <div style={{ height: 1, background: palette.hairline, ...style }}/>;
}

// Eyebrow label
function Eyebrow({ children, palette, style }) {
  return <div style={{ ...SCALE.eyebrow, color: palette.inkMute, ...style }}>{children}</div>;
}

// Numbered stepper dot
function Stepper({ n, total, palette }) {
  return (
    <div style={{ display: 'flex', gap: 4 }}>
      {[...Array(total)].map((_, i) => (
        <div key={i} style={{
          width: i === n ? 18 : 4, height: 4, borderRadius: 2,
          background: i === n ? palette.ink : palette.inkFaint,
          transition: 'all .3s',
        }}/>
      ))}
    </div>
  );
}

// A number that animates in from blur
function HeroNumber({ children, palette, size = 'XL', suffix, prefix, style }) {
  const scale = size === 'XL' ? SCALE.numXL : size === 'L' ? SCALE.numL : SCALE.numM;
  return (
    <div style={{
      display: 'flex', alignItems: 'baseline', gap: 6,
      color: palette.ink, ...style,
    }}>
      {prefix && <span style={{ ...SCALE.bodyLg, color: palette.inkSoft }}>{prefix}</span>}
      <span style={scale}>{children}</span>
      {suffix && <span style={{ ...SCALE.bodyLg, color: palette.inkSoft, fontWeight: 500 }}>{suffix}</span>}
    </div>
  );
}

// A serif italic accent phrase
function Serif({ children, size = 'S', palette, style }) {
  const scale = size === 'L' ? SCALE.displayL : size === 'M' ? SCALE.displayM : SCALE.displayS;
  return <span style={{ ...scale, color: palette.ink, ...style }}>{children}</span>;
}

// Pill button
function Pill({ children, palette, filled, onClick, style }) {
  const bg = filled ? palette.ink : 'transparent';
  const color = filled ? palette.bg : palette.ink;
  return (
    <button onClick={onClick} style={{
      ...SCALE.body, fontWeight: 500,
      padding: '12px 20px', borderRadius: 100,
      border: filled ? 'none' : `1px solid ${palette.ink}`,
      background: bg, color, cursor: 'pointer',
      display: 'inline-flex', alignItems: 'center', gap: 8,
      ...style,
    }}>
      {children}
    </button>
  );
}

// Sparkline (tiny chart) — accent colored
function Sparkline({ data, palette, width = 140, height = 36, filled = true }) {
  const max = Math.max(...data);
  const min = Math.min(...data);
  const range = max - min || 1;
  const step = width / (data.length - 1);
  const points = data.map((v, i) => [i * step, height - ((v - min) / range) * (height - 4) - 2]);
  const line = points.map((p, i) => (i === 0 ? `M${p[0]},${p[1]}` : `L${p[0]},${p[1]}`)).join(' ');
  const area = line + ` L${width},${height} L0,${height} Z`;
  return (
    <svg width={width} height={height}>
      {filled && <path d={area} fill={palette.accent} opacity="0.35"/>}
      <path d={line} fill="none" stroke={palette.ink} strokeWidth="1.5" strokeLinejoin="round" strokeLinecap="round"/>
    </svg>
  );
}

// Confidence band — exposes how sure MINT is about a number.
// level: 'high' | 'medium' | 'low'
// reason: short string (≤40 char) explaining what the number depends on.
function ConfidenceBand({ palette, level = 'medium', reason, style }) {
  const p = palette;
  const labels = { high: 'précis', medium: 'estimation', low: 'à confirmer' };
  const dots = { high: 3, medium: 2, low: 1 };
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 8,
      ...SCALE.meta, color: p.inkSoft, ...style,
    }}>
      <div style={{ display: 'flex', gap: 2 }}>
        {[0,1,2].map(i => (
          <div key={i} style={{
            width: 4, height: 4, borderRadius: 2,
            background: i < dots[level] ? p.ink : p.inkFaint,
          }}/>
        ))}
      </div>
      <span style={{ color: p.ink, fontWeight: 500 }}>{labels[level]}</span>
      {reason && <span style={{ color: p.inkMute }}>· {reason}</span>}
    </div>
  );
}

// EnrichmentPrompts — the questions MINT WOULD ask to make the number sharper.
// Tap one to add precision. Sits below a hero number.
function EnrichmentPrompts({ palette, prompts = [], onPick, style }) {
  const p = palette;
  if (!prompts.length) return null;
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, ...style }}>
      {prompts.map((q, i) => (
        <button key={i} onClick={() => onPick && onPick(q)} style={{
          ...SCALE.meta, color: p.ink, background: 'transparent',
          border: `1px dashed ${p.inkFaint}`, borderRadius: 100,
          padding: '6px 10px', cursor: 'pointer',
          display: 'inline-flex', alignItems: 'center', gap: 4,
        }}>
          <span style={{ color: p.inkMute }}>+</span> {q}
        </button>
      ))}
    </div>
  );
}

// Streaming indicator — for live LLM tokens.
function StreamingDots({ palette, style }) {
  const p = palette;
  return (
    <span style={{ display: 'inline-flex', gap: 3, alignItems: 'center', ...style }}>
      {[0,1,2].map(i => (
        <span key={i} style={{
          width: 4, height: 4, borderRadius: 2, background: p.ink,
          animation: `mintPulse 1.2s ${i * 0.15}s infinite ease-in-out`,
        }}/>
      ))}
      <style>{`@keyframes mintPulse{0%,80%,100%{opacity:.25}40%{opacity:1}}`}</style>
    </span>
  );
}

Object.assign(window, { Phone, Rule, Eyebrow, Stepper, HeroNumber, Serif, Pill, Sparkline, ConfidenceBand, EnrichmentPrompts, StreamingDots });
