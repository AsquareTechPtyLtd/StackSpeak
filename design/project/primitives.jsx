// StackSpeak — shared primitives

// Icons (stroke-style, Linear-flavored)
const Icon = {
  home: (s=20, c='currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M3 10.5L12 3l9 7.5"/><path d="M5 9.5V20h14V9.5"/></svg>
  ),
  review: (s=20, c='currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><rect x="3.5" y="4.5" width="17" height="15" rx="2"/><path d="M7.5 10h9M7.5 14h6"/></svg>
  ),
  search: (s=20, c='currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="6.5"/><path d="M20 20l-3.6-3.6"/></svg>
  ),
  profile: (s=20, c='currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="8.5" r="3.8"/><path d="M5 20c1.2-3.8 4-5.5 7-5.5s5.8 1.7 7 5.5"/></svg>
  ),
  bookmark: (s=20, c='currentColor', fill='none') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill={fill} stroke={c} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M6.5 4h11v17l-5.5-3.8L6.5 21z"/></svg>
  ),
  speaker: (s=18, c='currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M4 9.5v5h3.5L13 19V5L7.5 9.5H4z"/><path d="M16 8.5a4 4 0 010 7"/><path d="M18.5 6a7 7 0 010 12" opacity="0.55"/></svg>
  ),
  flame: (s=16, c='currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill={c} stroke="none"><path d="M12 2.5c.6 3.5-1.8 4.5-1.8 7a2.5 2.5 0 105 0c0-1-.4-1.8-1-2.5 2.5 1.5 4 4 4 6.8a6.2 6.2 0 11-12.4 0c0-3.8 3.5-5 3.5-8.5 0-1 .3-2 .5-2.8h2.2z"/></svg>
  ),
  arrow: (s=14, c='currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
  ),
  plus: (s=16, c='currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round"><path d="M12 5v14M5 12h14"/></svg>
  ),
  check: (s=14, c='currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M4 12l5 5L20 6"/></svg>
  ),
  close: (s=18, c='currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.8" strokeLinecap="round"><path d="M6 6l12 12M6 18L18 6"/></svg>
  ),
  mic: (s=18, c='currentColor', active=false) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill={active ? c : 'none'} stroke={c} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0014 0M12 18v3"/></svg>
  ),
  settings: (s=18, c='currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/></svg>
  ),
};

// Progress ring
function ProgressRing({ size = 44, stroke = 3, progress = 0.4, color, track }) {
  const r = (size - stroke) / 2;
  const C = 2 * Math.PI * r;
  return (
    <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={track} strokeWidth={stroke}/>
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={color} strokeWidth={stroke}
        strokeDasharray={C} strokeDashoffset={C * (1 - progress)} strokeLinecap="round"/>
    </svg>
  );
}

// Level chip (mono)
function LevelChip({ children, t }) {
  return (
    <span style={{
      fontFamily: t.f.mono, fontSize: 10.5, letterSpacing: 0.4,
      color: t.c.inkMuted, textTransform: 'uppercase',
      padding: '3px 7px', borderRadius: 4,
      background: t.c.accentBg, color: t.c.accent,
      border: `0.5px solid ${t.c.line}`,
    }}>{children}</span>
  );
}

// Tag chip (outlined)
function Tag({ children, t }) {
  return (
    <span style={{
      fontFamily: t.f.ui, fontSize: 11, fontWeight: 500,
      color: t.c.inkMuted,
      padding: '3px 8px', borderRadius: 999,
      border: `0.5px solid ${t.c.lineStrong}`,
      background: 'transparent',
    }}>{children}</span>
  );
}

// Divider
function Divider({ t }) {
  return <div style={{ height: 0.5, background: t.c.line, width: '100%' }} />;
}

// Simple syntax-colored code block
function CodeBlock({ code, lang, t }) {
  const rules = [
    { re: /(^|\n)(\/\/[^\n]*)/g, color: t.c.codeCom },
    { re: /(^|\n)(#[^\n]*)/g, color: t.c.codeCom },
    { re: /"([^"\\]|\\.)*"/g, color: t.c.codeStr },
    { re: /\b(PUT|POST|GET|DELETE|do|return|const|let|true|false|replicas|write_quorum|read_quorum|pipe|new|insert)\b/g, color: t.c.codeKey },
    { re: /\b\d+(\.\d+)?\b/g, color: t.c.codeNum },
  ];
  // tokenize in order; produce spans
  let spans = [{ text: code, color: t.c.codeInk }];
  for (const rule of rules) {
    const next = [];
    for (const sp of spans) {
      if (sp.color !== t.c.codeInk) { next.push(sp); continue; }
      let lastIdx = 0, m;
      const re = new RegExp(rule.re.source, rule.re.flags);
      while ((m = re.exec(sp.text)) !== null) {
        if (m.index > lastIdx) next.push({ text: sp.text.slice(lastIdx, m.index), color: t.c.codeInk });
        next.push({ text: m[0], color: rule.color });
        lastIdx = m.index + m[0].length;
        if (m[0].length === 0) re.lastIndex++;
      }
      if (lastIdx < sp.text.length) next.push({ text: sp.text.slice(lastIdx), color: t.c.codeInk });
    }
    spans = next;
  }
  return (
    <div style={{
      fontFamily: t.f.mono, fontSize: 12.5, lineHeight: 1.6,
      background: t.c.codeBg, color: t.c.codeInk,
      borderRadius: 10, padding: '12px 14px',
      border: `0.5px solid ${t.c.line}`,
      whiteSpace: 'pre-wrap', wordBreak: 'break-word',
    }}>
      <div style={{
        fontSize: 10, letterSpacing: 0.4, textTransform: 'uppercase',
        color: t.c.inkFaint, marginBottom: 6,
      }}>{lang}</div>
      {spans.map((sp, i) => <span key={i} style={{ color: sp.color }}>{sp.text}</span>)}
    </div>
  );
}

// Status bar — mini
function MiniStatusBar({ dark }) {
  return <IOSStatusBar dark={dark} />;
}

// Tab bar (bottom)
function TabBar({ active, onChange, t }) {
  const items = [
    { id: 'home',    label: 'Today',   icon: Icon.home },
    { id: 'review',  label: 'Review',  icon: Icon.review },
    { id: 'search',  label: 'Search',  icon: Icon.search },
    { id: 'profile', label: 'You',     icon: Icon.profile },
  ];
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 30,
      paddingBottom: 28, paddingTop: 8,
      background: t.c.chromeFill,
      backdropFilter: 'blur(24px) saturate(180%)',
      WebkitBackdropFilter: 'blur(24px) saturate(180%)',
      borderTop: `0.5px solid ${t.c.line}`,
      display: 'flex', justifyContent: 'space-around',
    }}>
      {items.map(it => {
        const is = active === it.id;
        const col = is ? t.c.accent : t.c.inkFaint;
        return (
          <button key={it.id} onClick={() => onChange(it.id)} style={{
            background: 'none', border: 'none', padding: '4px 8px',
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
            cursor: 'pointer', color: col,
            fontFamily: t.f.ui, fontSize: 10, fontWeight: 500, letterSpacing: 0.1,
          }}>
            {it.icon(22, col)}
            <span>{it.label}</span>
          </button>
        );
      })}
    </div>
  );
}

// Sentence practice — type OR speak a sentence using the word
function SentencePractice({ word, t, compact = false }) {
  const [text, setText] = React.useState('');
  const [listening, setListening] = React.useState(false);
  const [recent, setRecent] = React.useState(null);

  // Fake mic capture: simulates 2s listen, drops a realistic transcription
  const startListening = () => {
    if (listening) { setListening(false); return; }
    setListening(true);
    setTimeout(() => {
      setListening(false);
      const sample = `The retry was safe because our ${word.word} endpoint could be called twice.`;
      setText(sample);
      setRecent(sample);
    }, 1800);
  };

  const usesWord = text.toLowerCase().includes(word.word.toLowerCase());
  const wordCount = text.trim().split(/\s+/).filter(Boolean).length;
  const ok = usesWord && wordCount >= 5;

  return (
    <div style={{
      background: t.c.surfaceAlt, borderRadius: 14,
      border: `0.5px solid ${t.c.line}`,
      padding: compact ? 12 : 14,
      display: 'flex', flexDirection: 'column', gap: 10,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{
          fontFamily: t.f.mono, fontSize: 10.5, letterSpacing: 1.2,
          color: t.c.inkFaint, textTransform: 'uppercase',
        }}>Your turn</div>
        <div style={{
          fontFamily: t.f.serif, fontStyle: 'italic',
          fontSize: 12, color: t.c.inkFaint,
        }}>use “{word.word}” in a sentence</div>
      </div>

      <div style={{
        position: 'relative',
        background: t.c.surface, borderRadius: 10,
        border: `0.5px solid ${ok ? t.c.accent : t.c.line}`,
        transition: 'border-color .2s',
        display: 'flex', alignItems: 'flex-start', gap: 8,
        padding: '10px 10px 10px 12px',
      }}>
        <textarea
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder={listening ? 'Listening…' : `e.g. “${word.sentence}”`}
          onClick={(e) => e.stopPropagation()}
          rows={compact ? 2 : 3}
          style={{
            flex: 1, resize: 'none', border: 'none', outline: 'none',
            background: 'transparent', color: t.c.ink,
            fontFamily: t.f.ui, fontSize: 14, lineHeight: 1.5,
            padding: 0, textWrap: 'pretty',
          }}
        />
        <button
          onClick={(e) => { e.stopPropagation(); startListening(); }}
          style={{
            flexShrink: 0, position: 'relative',
            width: 36, height: 36, borderRadius: 999,
            border: 'none', cursor: 'pointer',
            background: listening ? t.c.accent : t.c.accentBg,
            color: listening ? (t.mode === 'dark' ? '#0B0C0E' : '#fff') : t.c.accent,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}
          aria-label={listening ? 'Stop listening' : 'Speak your sentence'}
        >
          {Icon.mic(18, listening ? (t.mode === 'dark' ? '#0B0C0E' : '#fff') : t.c.accent, listening)}
          {listening && (
            <span style={{
              position: 'absolute', inset: -6, borderRadius: 999,
              border: `1.5px solid ${t.c.accent}`,
              animation: 'sspulse 1.2s ease-out infinite',
              pointerEvents: 'none',
            }}/>
          )}
        </button>
      </div>

      {/* Status line */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        fontFamily: t.f.mono, fontSize: 10.5, color: t.c.inkFaint, letterSpacing: 0.3,
      }}>
        <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          {listening ? (
            <span style={{ color: t.c.accent }}>
              {'\u25CF'} <span style={{ letterSpacing: 1.2, textTransform: 'uppercase' }}>recording</span>
            </span>
          ) : ok ? (
            <span style={{ color: t.c.good, display: 'flex', alignItems: 'center', gap: 4 }}>
              {Icon.check(10, t.c.good)} looks good
            </span>
          ) : text ? (
            <span>{usesWord ? 'add a bit more context' : `include the word`}</span>
          ) : (
            <span>type or tap the mic</span>
          )}
        </span>
        <span>{wordCount} words</span>
      </div>

      <style>{`@keyframes sspulse { 0%{transform:scale(1);opacity:.8} 100%{transform:scale(1.6);opacity:0} }`}</style>
    </div>
  );
}

Object.assign(window, { Icon, ProgressRing, LevelChip, Tag, Divider, CodeBlock, MiniStatusBar, TabBar, SentencePractice });
