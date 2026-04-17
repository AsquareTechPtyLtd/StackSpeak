// StackSpeak — design tokens (Linear/Bear blend)
// Cool-neutral grays, single indigo-ink accent, mono for metadata.

const THEMES = {
  light: {
    // surfaces
    bg:        '#F6F5F2',  // warm paper (Bear nod)
    surface:   '#FFFFFF',
    surfaceAlt:'#FBFAF7',
    elevated:  '#FFFFFF',
    // ink
    ink:       '#15161A',
    inkMuted:  '#5B5E66',
    inkFaint:  '#9A9CA3',
    // lines
    line:      'rgba(20, 22, 28, 0.08)',
    lineStrong:'rgba(20, 22, 28, 0.14)',
    // accent — indigo ink
    accent:    '#3E4BDB',
    accentBg:  'rgba(62, 75, 219, 0.08)',
    // syntax (mono code)
    codeBg:    '#F2F1EC',
    codeInk:   '#15161A',
    codeKey:   '#8B2F7A',  // magenta
    codeStr:   '#2F6F47',  // green
    codeCom:   '#8A8A7F',  // olive-gray
    codeNum:   '#B5651D',
    // status
    good:      '#2F6F47',
    warn:      '#B5651D',
    // chrome
    chromeFill:'rgba(246, 245, 242, 0.72)',
  },
  dark: {
    bg:        '#0B0C0E',  // near-black cool
    surface:   '#141519',
    surfaceAlt:'#0F1013',
    elevated:  '#1A1C21',
    ink:       '#F2F2F4',
    inkMuted:  '#A4A7B0',
    inkFaint:  '#6B6E77',
    line:      'rgba(255, 255, 255, 0.06)',
    lineStrong:'rgba(255, 255, 255, 0.12)',
    accent:    '#8B93FF',
    accentBg:  'rgba(139, 147, 255, 0.12)',
    codeBg:    '#0F1013',
    codeInk:   '#E6E6EA',
    codeKey:   '#D291E7',
    codeStr:   '#7FCF99',
    codeCom:   '#6B6E77',
    codeNum:   '#E0A878',
    good:      '#7FCF99',
    warn:      '#E0A878',
    chromeFill:'rgba(11, 12, 14, 0.72)',
  },
};

const DENSITY = {
  compact: { cardPadY: 16, cardPadX: 18, cardGap: 10, rowPad: 12, titleSize: 22 },
  roomy:   { cardPadY: 22, cardPadX: 22, cardGap: 14, rowPad: 16, titleSize: 26 },
};

const FONTS = {
  ui:    '"Inter", -apple-system, system-ui, sans-serif',
  mono:  '"JetBrains Mono", ui-monospace, Menlo, monospace',
  serif: '"Instrument Serif", Georgia, serif',
};

function useTheme(mode, density) {
  return { c: THEMES[mode], d: DENSITY[density], f: FONTS, mode };
}

Object.assign(window, { THEMES, DENSITY, FONTS, useTheme });
