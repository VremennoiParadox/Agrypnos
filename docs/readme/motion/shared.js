// Helpers shared by the README motion pages: keyframe easing and the eye glyphs.

// Cubic in-out between keyframes [[t, v], ...]. Holds outside the range.
export const ease = x => x < .5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
export function k(t, keys) {
  if (t <= keys[0][0]) return keys[0][1];
  for (let i = 1; i < keys.length; i++) {
    const [t0, v0] = keys[i - 1], [t1, v1] = keys[i];
    if (t <= t1) return v0 + (v1 - v0) * ease((t - t0) / (t1 - t0));
  }
  return keys[keys.length - 1][1];
}
// 0 → 1 over f seconds from a, back to 0 over f seconds ending at b.
export const win = (t, a, b, f = .3) => Math.min(k(t, [[a, 0], [a + f, 1]]), k(t, [[b - f, 1], [b, 0]]));

// SF Symbols stand-ins: eye, eye.slash, eye.fill, and GlyphFactory's armed eye (eye + top-right dot).
const ALMOND = 'M1.5 8C4.5 3.2 8 1.2 12 1.2s7.5 2 10.5 6.8c-3 4.8-6.5 6.8-10.5 6.8S4.5 12.8 1.5 8z';
export function eye(kind, color, size = 22) {
  const body = kind === 'fill'
    ? `<path d="${ALMOND}" fill="${color}"/><circle cx="12" cy="8" r="3.6" fill="var(--glyph-cut, #16161c)"/><circle cx="12" cy="8" r="1.7" fill="${color}"/>`
    : `<path d="${ALMOND}" fill="none" stroke="${color}" stroke-width="1.7"/><circle cx="12" cy="8" r="3.3" fill="${color}"/>` +
      (kind === 'slash' ? `<path d="M4 .5 20 15.5" stroke="var(--glyph-cut, #16161c)" stroke-width="4"/><path d="M4 .5 20 15.5" stroke="${color}" stroke-width="1.7"/>` : '');
  const dot = kind === 'armed' ? `<circle cx="21.3" cy="2.7" r="2.4" fill="${color}"/>` : '';
  return `<svg width="${size}" height="${size * 16 / 24}" viewBox="0 0 24 16" stroke-linecap="round">${body}${dot}</svg>`;
}
