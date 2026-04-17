// StackSpeak — screens

// ───────────────────────── Onboarding ─────────────────────────
function OnboardingScreen({ t }) {
  return (
    <div style={{
      height: '100%', background: t.c.bg, color: t.c.ink,
      fontFamily: t.f.ui, display: 'flex', flexDirection: 'column',
    }}>
      <div style={{ paddingTop: 72 }} />
      {/* Wordmark */}
      <div style={{ padding: '0 28px' }}>
        <div style={{
          fontFamily: t.f.mono, fontSize: 11, letterSpacing: 2,
          color: t.c.inkFaint, textTransform: 'uppercase', marginBottom: 24,
        }}>
          stack<span style={{ color: t.c.accent }}>/</span>speak
        </div>
        <div style={{
          fontSize: 38, fontWeight: 600, lineHeight: 1.1,
          letterSpacing: -0.9, marginBottom: 18, textWrap: 'pretty',
        }}>
          Five words.<br/>
          <span style={{ color: t.c.inkMuted }}>Every weekday.</span>
        </div>
        <div style={{
          fontFamily: t.f.serif, fontStyle: 'italic',
          fontSize: 18, lineHeight: 1.45, color: t.c.inkMuted,
          maxWidth: 300,
        }}>
          A quiet vocabulary for the engineer who reads more RFCs than novels.
        </div>
      </div>

      {/* How it works */}
      <div style={{ padding: '44px 28px 0', flex: 1 }}>
        <div style={{
          fontFamily: t.f.mono, fontSize: 10.5, letterSpacing: 1.2,
          color: t.c.inkFaint, textTransform: 'uppercase', marginBottom: 16,
        }}>How it works</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
          {[
            { n: '01', t: 'Start at L1', d: 'Fundamentals first — hoisting, closures, joins.' },
            { n: '02', t: 'Skip what you know', d: 'Mark a word as known; we level up automatically.' },
            { n: '03', t: 'Five a day', d: 'No more, no less. Ready at 9:00 AM.' },
          ].map(r => (
            <div key={r.n} style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
              <span style={{
                fontFamily: t.f.mono, fontSize: 11, fontWeight: 500,
                color: t.c.accent, letterSpacing: 0.3, paddingTop: 3,
              }}>{r.n}</span>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 15, fontWeight: 500, color: t.c.ink, marginBottom: 2 }}>{r.t}</div>
                <div style={{
                  fontFamily: t.f.serif, fontStyle: 'italic',
                  fontSize: 14, lineHeight: 1.45, color: t.c.inkMuted,
                }}>{r.d}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* CTA */}
      <div style={{ padding: '12px 20px 40px' }}>
        <button style={{
          width: '100%', height: 52, borderRadius: 14, border: 'none',
          background: t.c.ink, color: t.c.bg,
          fontFamily: t.f.ui, fontSize: 15, fontWeight: 600,
          letterSpacing: -0.2, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}>
          Begin at L1 <span style={{ opacity: 0.7 }}>{Icon.arrow(14, t.c.bg)}</span>
        </button>
        <div style={{
          textAlign: 'center', marginTop: 14,
          fontFamily: t.f.mono, fontSize: 11, color: t.c.inkFaint, letterSpacing: 0.3,
        }}>9:00 AM · daily · interruption-free</div>
      </div>
    </div>
  );
}

// ───────────────────────── Home / Today ─────────────────────────
function HomeScreen({ t, expanded, setExpanded, onOpen, knownIds, markKnown }) {
  const words = WORDS_TODAY.filter(w => !knownIds.includes(w.id));
  const done = Math.min(2, words.length); // pretend first 2 are read
  return (
    <div style={{
      height: '100%', background: t.c.bg, color: t.c.ink,
      fontFamily: t.f.ui, overflow: 'hidden',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Header */}
      <div style={{ padding: '54px 20px 14px', display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
        <div>
          <div style={{
            fontFamily: t.f.mono, fontSize: 10.5, letterSpacing: 1.2,
            color: t.c.inkFaint, textTransform: 'uppercase', marginBottom: 6,
          }}>Fri · Apr 18</div>
          <div style={{ fontSize: 28, fontWeight: 600, letterSpacing: -0.6 }}>Today’s five</div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 5,
            padding: '5px 9px', borderRadius: 999,
            background: t.c.accentBg, color: t.c.accent,
            fontFamily: t.f.mono, fontSize: 12, fontWeight: 500,
          }}>
            {Icon.flame(12, t.c.accent)} 47
          </div>
          <div style={{ position: 'relative', width: 38, height: 38 }}>
            <ProgressRing size={38} stroke={2.5} progress={done/5} color={t.c.accent} track={t.c.line}/>
            <div style={{
              position: 'absolute', inset: 0,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontFamily: t.f.mono, fontSize: 11, color: t.c.ink, fontWeight: 500,
            }}>{done}/5</div>
          </div>
        </div>
      </div>

      {/* Cards scroll */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '4px 16px 120px' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: t.d.cardGap }}>
          {words.map((w, i) => {
            const isOpen = expanded === w.id;
            const isDone = i < done;
            return (
              <div key={w.id}
                onClick={() => setExpanded(isOpen ? null : w.id)}
                style={{
                  background: t.c.surface,
                  borderRadius: 18,
                  border: `0.5px solid ${t.c.line}`,
                  padding: `${t.d.cardPadY}px ${t.d.cardPadX}px`,
                  cursor: 'pointer',
                  transition: 'all 0.2s',
                  opacity: isDone && !isOpen ? 0.55 : 1,
                }}>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginBottom: 4 }}>
                  <span style={{
                    fontFamily: t.f.mono, fontSize: 11, color: t.c.inkFaint, fontWeight: 500,
                  }}>{String(i+1).padStart(2,'0')}</span>
                  <span style={{
                    fontSize: t.d.titleSize, fontWeight: 600,
                    letterSpacing: -0.5, color: t.c.ink,
                  }}>{w.word}</span>
                  <span style={{
                    fontFamily: t.f.serif, fontStyle: 'italic',
                    fontSize: 13, color: t.c.inkFaint,
                  }}>{w.pos}</span>
                  {isDone && (
                    <span style={{ marginLeft: 'auto', color: t.c.good }}>
                      {Icon.check(14, t.c.good)}
                    </span>
                  )}
                </div>
                <div style={{
                  fontFamily: t.f.mono, fontSize: 11, color: t.c.inkFaint,
                  marginBottom: 10,
                }}>{w.ipa}</div>
                <div style={{
                  fontSize: 14.5, lineHeight: 1.45, color: t.c.inkMuted,
                  textWrap: 'pretty',
                }}>{w.short}</div>
                {isOpen && (
                  <div style={{ marginTop: 14, display: 'flex', flexDirection: 'column', gap: 12 }}>
                    <Divider t={t}/>
                    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                      <LevelChip t={t}>{w.level}</LevelChip>
                      {w.tags.map(tag => <Tag key={tag} t={t}>{tag}</Tag>)}
                    </div>
                    <CodeBlock code={w.example.code} lang={w.example.lang} t={t}/>
                    <SentencePractice word={w} t={t} compact={true}/>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
                      <button onClick={(e) => { e.stopPropagation(); onOpen(w.id); }} style={{
                        background: 'transparent', border: 'none',
                        color: t.c.accent, fontFamily: t.f.ui, fontSize: 13, fontWeight: 500,
                        cursor: 'pointer', padding: 0, display: 'flex', alignItems: 'center', gap: 4,
                      }}>Read more {Icon.arrow(12, t.c.accent)}</button>
                      <button onClick={(e) => { e.stopPropagation(); markKnown(w.id); }} style={{
                        background: 'transparent',
                        border: `0.5px solid ${t.c.lineStrong}`,
                        color: t.c.inkMuted, fontFamily: t.f.ui, fontSize: 12, fontWeight: 500,
                        cursor: 'pointer', padding: '6px 10px', borderRadius: 999,
                        display: 'flex', alignItems: 'center', gap: 5,
                      }}>
                        {Icon.check(11, t.c.inkMuted)} I know this
                      </button>
                    </div>
                  </div>
                )}
                {!isOpen && (
                  <button onClick={(e) => { e.stopPropagation(); markKnown(w.id); }} style={{
                    marginTop: 12, background: 'transparent', border: 'none',
                    color: t.c.inkFaint, fontFamily: t.f.mono, fontSize: 10.5,
                    letterSpacing: 0.4, textTransform: 'uppercase',
                    cursor: 'pointer', padding: 0,
                  }}>Skip — already known</button>
                )}
              </div>
            );
          })}
        </div>

        {/* End card */}
        <div style={{
          marginTop: 18, padding: '18px 18px', borderRadius: 18,
          border: `0.5px dashed ${t.c.lineStrong}`,
          textAlign: 'center',
        }}>
          <div style={{ fontFamily: t.f.serif, fontStyle: 'italic', fontSize: 15, color: t.c.inkMuted }}>
            That’s the set.
          </div>
          <div style={{ fontFamily: t.f.mono, fontSize: 11, color: t.c.inkFaint, marginTop: 4 }}>
            next delivery — tomorrow 9:00
          </div>
        </div>
      </div>
    </div>
  );
}

// ───────────────────────── Word detail ─────────────────────────
function DetailScreen({ t, word, onBack, saved, setSaved }) {
  const w = word;
  const isSaved = saved.includes(w.word);
  return (
    <div style={{
      height: '100%', background: t.c.bg, color: t.c.ink,
      fontFamily: t.f.ui, overflow: 'hidden',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Top bar */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '54px 16px 6px',
      }}>
        <button onClick={onBack} style={{
          background: 'none', border: 'none', padding: 8, margin: -8, cursor: 'pointer',
          color: t.c.inkMuted, fontFamily: t.f.ui, fontSize: 14,
          display: 'flex', alignItems: 'center', gap: 6,
        }}>
          <svg width="12" height="18" viewBox="0 0 12 18" fill="none">
            <path d="M9 1L2 9l7 8" stroke={t.c.inkMuted} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
          Today
        </button>
        <button onClick={() => setSaved(isSaved ? saved.filter(x => x !== w.word) : [...saved, w.word])}
          style={{
            background: 'none', border: 'none', padding: 8, margin: -8, cursor: 'pointer',
            color: isSaved ? t.c.accent : t.c.inkMuted,
          }}>
          {Icon.bookmark(20, isSaved ? t.c.accent : t.c.inkMuted, isSaved ? t.c.accent : 'none')}
        </button>
      </div>

      {/* Body */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '8px 24px 120px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14 }}>
          <LevelChip t={t}>{w.level}</LevelChip>
          {w.tags.map(tg => <Tag key={tg} t={t}>{tg}</Tag>)}
        </div>

        <div style={{
          fontSize: 40, fontWeight: 600, letterSpacing: -1, lineHeight: 1.05,
          marginBottom: 8,
        }}>{w.word}</div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 24 }}>
          <span style={{ fontFamily: t.f.serif, fontStyle: 'italic', fontSize: 16, color: t.c.inkMuted }}>
            {w.pos}
          </span>
          <span style={{ fontFamily: t.f.mono, fontSize: 12, color: t.c.inkFaint }}>
            {w.ipa}
          </span>
          <button style={{
            background: 'transparent', border: `0.5px solid ${t.c.lineStrong}`,
            borderRadius: 999, padding: '4px 6px', cursor: 'pointer',
            color: t.c.inkMuted,
            display: 'flex', alignItems: 'center',
          }}>
            {Icon.speaker(16, t.c.inkMuted)}
          </button>
        </div>

        {/* Definition */}
        <div style={{
          fontFamily: t.f.mono, fontSize: 10.5, letterSpacing: 1.2,
          color: t.c.inkFaint, textTransform: 'uppercase', marginBottom: 8,
        }}>Definition</div>
        <div style={{ fontSize: 16, lineHeight: 1.55, color: t.c.ink, marginBottom: 28, textWrap: 'pretty' }}>
          {w.long}
        </div>

        {/* In a sentence */}
        <div style={{
          fontFamily: t.f.mono, fontSize: 10.5, letterSpacing: 1.2,
          color: t.c.inkFaint, textTransform: 'uppercase', marginBottom: 8,
        }}>In a sentence</div>
        <div style={{
          fontFamily: t.f.serif, fontStyle: 'italic', fontSize: 18, lineHeight: 1.4,
          color: t.c.ink, marginBottom: 28,
          paddingLeft: 14, borderLeft: `2px solid ${t.c.accent}`,
        }}>“{w.sentence}”</div>

        {/* Example */}
        <div style={{
          fontFamily: t.f.mono, fontSize: 10.5, letterSpacing: 1.2,
          color: t.c.inkFaint, textTransform: 'uppercase', marginBottom: 8,
        }}>Example</div>
        <CodeBlock code={w.example.code} lang={w.example.lang} t={t}/>

        {/* Your turn */}
        <div style={{
          fontFamily: t.f.mono, fontSize: 10.5, letterSpacing: 1.2,
          color: t.c.inkFaint, textTransform: 'uppercase', marginTop: 28, marginBottom: 8,
        }}>Your turn</div>
        <SentencePractice word={w} t={t}/>

        {/* Etymology */}
        <div style={{
          fontFamily: t.f.mono, fontSize: 10.5, letterSpacing: 1.2,
          color: t.c.inkFaint, textTransform: 'uppercase', marginTop: 28, marginBottom: 8,
        }}>Etymology</div>
        <div style={{
          fontFamily: t.f.serif, fontStyle: 'italic', fontSize: 15, lineHeight: 1.5,
          color: t.c.inkMuted,
        }}>{w.etymology}</div>
      </div>
    </div>
  );
}

// ───────────────────────── Review ─────────────────────────
function ReviewScreen({ t }) {
  const [idx, setIdx] = React.useState(0);
  const [flipped, setFlipped] = React.useState(false);
  const deck = WORDS_TODAY.slice(0, 4);
  const w = deck[idx];
  const next = (known) => {
    setFlipped(false);
    setIdx(i => Math.min(i + 1, deck.length - 1));
  };
  return (
    <div style={{
      height: '100%', background: t.c.bg, color: t.c.ink,
      fontFamily: t.f.ui, overflow: 'hidden',
      display: 'flex', flexDirection: 'column',
    }}>
      <div style={{ padding: '54px 20px 10px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{
            fontFamily: t.f.mono, fontSize: 10.5, letterSpacing: 1.2,
            color: t.c.inkFaint, textTransform: 'uppercase', marginBottom: 4,
          }}>Review session</div>
          <div style={{ fontSize: 22, fontWeight: 600, letterSpacing: -0.4 }}>
            {idx+1} <span style={{ color: t.c.inkFaint, fontWeight: 400 }}>/ {deck.length}</span>
          </div>
        </div>
        <button style={{
          background: 'none', border: 'none', color: t.c.inkMuted, padding: 8, margin: -8, cursor: 'pointer',
        }}>{Icon.close(20, t.c.inkMuted)}</button>
      </div>

      {/* Progress segments */}
      <div style={{ padding: '0 20px 18px', display: 'flex', gap: 4 }}>
        {deck.map((_, i) => (
          <div key={i} style={{
            flex: 1, height: 3, borderRadius: 2,
            background: i <= idx ? t.c.accent : t.c.line,
          }}/>
        ))}
      </div>

      {/* Flash card */}
      <div style={{ flex: 1, padding: '0 20px', display: 'flex', flexDirection: 'column' }}>
        <div onClick={() => setFlipped(f => !f)} style={{
          flex: 1, background: t.c.surface, borderRadius: 22,
          border: `0.5px solid ${t.c.line}`,
          padding: 24, cursor: 'pointer',
          display: 'flex', flexDirection: 'column', justifyContent: 'center',
        }}>
          {!flipped ? (
            <>
              <div style={{ fontFamily: t.f.mono, fontSize: 10.5, color: t.c.inkFaint, letterSpacing: 1.2, textTransform: 'uppercase', marginBottom: 18 }}>
                Recall the definition
              </div>
              <div style={{ fontSize: 36, fontWeight: 600, letterSpacing: -0.8, lineHeight: 1.1, marginBottom: 10 }}>
                {w.word}
              </div>
              <div style={{ fontFamily: t.f.mono, fontSize: 12, color: t.c.inkFaint }}>
                {w.ipa} · {w.pos}
              </div>
              <div style={{
                marginTop: 'auto', paddingTop: 20, textAlign: 'center',
                fontFamily: t.f.mono, fontSize: 11, color: t.c.inkFaint,
              }}>tap to reveal</div>
            </>
          ) : (
            <>
              <div style={{ fontFamily: t.f.mono, fontSize: 10.5, color: t.c.inkFaint, letterSpacing: 1.2, textTransform: 'uppercase', marginBottom: 14 }}>
                {w.word}
              </div>
              <div style={{ fontSize: 18, lineHeight: 1.45, color: t.c.ink, marginBottom: 20, textWrap: 'pretty' }}>
                {w.short}
              </div>
              <div style={{
                fontFamily: t.f.serif, fontStyle: 'italic', fontSize: 15, lineHeight: 1.4,
                color: t.c.inkMuted, paddingLeft: 12, borderLeft: `2px solid ${t.c.accent}`,
              }}>“{w.sentence}”</div>
            </>
          )}
        </div>

        {/* Self-rate */}
        <div style={{ display: 'flex', gap: 10, padding: '18px 0 24px' }}>
          {[
            { k: 'again', label: 'Again', hint: '< 10m' },
            { k: 'hard',  label: 'Hard',  hint: '1d' },
            { k: 'good',  label: 'Good',  hint: '4d' },
            { k: 'easy',  label: 'Easy',  hint: '2w' },
          ].map((b, i) => (
            <button key={b.k} onClick={() => next(b.k)} style={{
              flex: 1, height: 56, borderRadius: 12,
              background: i === 2 ? t.c.ink : t.c.surface,
              color: i === 2 ? t.c.bg : t.c.ink,
              border: i === 2 ? 'none' : `0.5px solid ${t.c.lineStrong}`,
              fontFamily: t.f.ui, cursor: 'pointer',
              display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2,
            }}>
              <span style={{ fontSize: 13, fontWeight: 600 }}>{b.label}</span>
              <span style={{
                fontFamily: t.f.mono, fontSize: 10,
                color: i === 2 ? t.c.bg : t.c.inkFaint, opacity: i === 2 ? 0.7 : 1,
              }}>{b.hint}</span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

// ───────────────────────── Search / Library ─────────────────────────
function SearchScreen({ t }) {
  const [q, setQ] = React.useState('');
  const list = RECENT_WORDS.filter(w => !q || w.word.toLowerCase().includes(q.toLowerCase()));
  return (
    <div style={{
      height: '100%', background: t.c.bg, color: t.c.ink,
      fontFamily: t.f.ui, display: 'flex', flexDirection: 'column',
    }}>
      <div style={{ padding: '54px 20px 10px' }}>
        <div style={{ fontSize: 28, fontWeight: 600, letterSpacing: -0.6, marginBottom: 14 }}>Library</div>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          background: t.c.surface, borderRadius: 12,
          border: `0.5px solid ${t.c.line}`, padding: '10px 12px',
        }}>
          {Icon.search(16, t.c.inkFaint)}
          <input
            value={q} onChange={e => setQ(e.target.value)}
            placeholder="Search 184 learned words"
            style={{
              flex: 1, border: 'none', outline: 'none', background: 'transparent',
              fontFamily: t.f.ui, fontSize: 14, color: t.c.ink,
            }}
          />
          <span style={{ fontFamily: t.f.mono, fontSize: 10, color: t.c.inkFaint }}>⌘K</span>
        </div>
      </div>

      {/* Filters */}
      <div style={{ padding: '12px 20px 8px', display: 'flex', gap: 6, flexWrap: 'wrap' }}>
        {['All', 'Saved · 12', 'L1', 'L2', 'L3', 'L4'].map((f, i) => (
          <button key={f} style={{
            padding: '5px 10px', borderRadius: 999,
            fontFamily: i === 0 ? t.f.ui : t.f.mono,
            fontSize: i === 0 ? 12 : 11, fontWeight: 500,
            background: i === 0 ? t.c.ink : 'transparent',
            color: i === 0 ? t.c.bg : t.c.inkMuted,
            border: i === 0 ? 'none' : `0.5px solid ${t.c.lineStrong}`,
            cursor: 'pointer',
          }}>{f}</button>
        ))}
      </div>

      {/* Section */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '6px 20px 120px' }}>
        <div style={{
          fontFamily: t.f.mono, fontSize: 10.5, letterSpacing: 1.2,
          color: t.c.inkFaint, textTransform: 'uppercase', padding: '14px 0 8px',
        }}>This week</div>
        <div style={{
          background: t.c.surface, borderRadius: 16,
          border: `0.5px solid ${t.c.line}`, overflow: 'hidden',
        }}>
          {list.map((w, i) => (
            <React.Fragment key={w.word}>
              {i > 0 && <div style={{ height: 0.5, background: t.c.line, marginLeft: 16 }}/>}
              <div style={{
                padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12,
              }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 2 }}>
                    <span style={{ fontSize: 15, fontWeight: 500, color: t.c.ink }}>{w.word}</span>
                    <span style={{ fontFamily: t.f.mono, fontSize: 10, color: t.c.accent, letterSpacing: 0.3 }}>{w.level}</span>
                  </div>
                  <div style={{
                    fontSize: 12.5, color: t.c.inkMuted, lineHeight: 1.35,
                    whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                  }}>{w.short}</div>
                </div>
                <span style={{ fontFamily: t.f.mono, fontSize: 10.5, color: t.c.inkFaint }}>{w.date}</span>
              </div>
            </React.Fragment>
          ))}
        </div>
      </div>
    </div>
  );
}

// ───────────────────────── Profile ─────────────────────────
function ProfileScreen({ t }) {
  // 12-week heatmap
  const weeks = 14, days = 7;
  const grid = [];
  let seed = 13;
  for (let w = 0; w < weeks; w++) {
    const col = [];
    for (let d = 0; d < days; d++) {
      seed = (seed * 9301 + 49297) % 233280;
      const r = seed / 233280;
      let v = 0;
      if (r > 0.25) v = 1;
      if (r > 0.55) v = 2;
      if (r > 0.82) v = 3;
      // last column = today, partial
      if (w === weeks - 1 && d > 4) v = 0;
      col.push(v);
    }
    grid.push(col);
  }
  const heatColor = (v) => {
    if (v === 0) return t.c.line;
    if (v === 1) return t.mode === 'dark' ? 'rgba(139,147,255,0.25)' : 'rgba(62,75,219,0.18)';
    if (v === 2) return t.mode === 'dark' ? 'rgba(139,147,255,0.55)' : 'rgba(62,75,219,0.45)';
    return t.c.accent;
  };

  return (
    <div style={{
      height: '100%', background: t.c.bg, color: t.c.ink,
      fontFamily: t.f.ui, display: 'flex', flexDirection: 'column',
    }}>
      <div style={{
        padding: '54px 20px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div style={{ fontSize: 28, fontWeight: 600, letterSpacing: -0.6 }}>You</div>
        <button style={{ background: 'none', border: 'none', padding: 6, margin: -6, cursor: 'pointer', color: t.c.inkMuted }}>
          {Icon.settings(20, t.c.inkMuted)}
        </button>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '4px 20px 120px' }}>
        {/* Identity */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '10px 0 20px' }}>
          <div style={{
            width: 52, height: 52, borderRadius: 14,
            background: t.c.accent, color: t.mode === 'dark' ? '#0B0C0E' : '#fff',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontFamily: t.f.mono, fontSize: 18, fontWeight: 600,
          }}>ad</div>
          <div>
            <div style={{ fontSize: 17, fontWeight: 600, letterSpacing: -0.2 }}>ada.dev</div>
            <div style={{ fontFamily: t.f.mono, fontSize: 11, color: t.c.inkFaint, marginTop: 2 }}>
              L3 · Engineer · joined Feb ’26
            </div>
          </div>
        </div>

        {/* Stats grid */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8, marginBottom: 22 }}>
          {[
            { n: '47', l: 'day streak' },
            { n: '184', l: 'words learned' },
            { n: '92%', l: 'recall rate' },
          ].map(s => (
            <div key={s.l} style={{
              background: t.c.surface, border: `0.5px solid ${t.c.line}`,
              borderRadius: 14, padding: '14px 12px',
            }}>
              <div style={{ fontFamily: t.f.mono, fontSize: 22, fontWeight: 500, letterSpacing: -0.5, color: t.c.ink }}>{s.n}</div>
              <div style={{ fontSize: 11, color: t.c.inkFaint, marginTop: 2 }}>{s.l}</div>
            </div>
          ))}
        </div>

        {/* Heatmap */}
        <div style={{
          background: t.c.surface, border: `0.5px solid ${t.c.line}`,
          borderRadius: 16, padding: '16px 16px 14px', marginBottom: 22,
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 14 }}>
            <div style={{
              fontFamily: t.f.mono, fontSize: 10.5, letterSpacing: 1.2,
              color: t.c.inkFaint, textTransform: 'uppercase',
            }}>Activity · 14 weeks</div>
            <div style={{ fontFamily: t.f.mono, fontSize: 11, color: t.c.inkMuted }}>
              {Icon.flame(11, t.c.accent)} <span style={{ color: t.c.ink, marginLeft: 4 }}>47 days</span>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 3, justifyContent: 'space-between' }}>
            {grid.map((col, i) => (
              <div key={i} style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
                {col.map((v, j) => (
                  <div key={j} style={{
                    width: 14, height: 14, borderRadius: 3,
                    background: heatColor(v),
                  }}/>
                ))}
              </div>
            ))}
          </div>
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'flex-end',
            gap: 6, marginTop: 12, fontFamily: t.f.mono, fontSize: 10, color: t.c.inkFaint,
          }}>
            less {[0,1,2,3].map(v => (
              <div key={v} style={{ width: 10, height: 10, borderRadius: 2, background: heatColor(v) }}/>
            ))} more
          </div>
        </div>

        {/* Saved */}
        <div style={{
          fontFamily: t.f.mono, fontSize: 10.5, letterSpacing: 1.2,
          color: t.c.inkFaint, textTransform: 'uppercase', marginBottom: 8,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        }}>
          <span>Saved · {SAVED_WORDS.length}</span>
          <span style={{ color: t.c.accent, letterSpacing: 0.2, textTransform: 'none' }}>See all</span>
        </div>
        <div style={{
          background: t.c.surface, border: `0.5px solid ${t.c.line}`,
          borderRadius: 16, overflow: 'hidden',
        }}>
          {SAVED_WORDS.slice(0, 4).map((w, i) => (
            <React.Fragment key={w}>
              {i > 0 && <div style={{ height: 0.5, background: t.c.line, marginLeft: 16 }}/>}
              <div style={{
                padding: '12px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              }}>
                <span style={{ fontSize: 14.5, color: t.c.ink }}>{w}</span>
                {Icon.bookmark(14, t.c.accent, t.c.accent)}
              </div>
            </React.Fragment>
          ))}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { OnboardingScreen, HomeScreen, DetailScreen, ReviewScreen, SearchScreen, ProfileScreen });
