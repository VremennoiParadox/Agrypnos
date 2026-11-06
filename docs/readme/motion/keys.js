// The Mac keyboard layout and its legends. Legends are painted onto one transparent sheet that
// floats just above the key tops, so ~80 keys need one texture. Icons are simple shapes drawn here.
//
// Rows run back to front. Each key is [width in key units, legend]. A legend is:
//   'Q'                one character, centred
//   '!1'               two characters, stacked
//   { word, at }       a word or symbol in a corner: at = 'bl' | 'br'
//   { sym, word, right } a modifier: symbol in the top corner, word along the bottom
//   { icon, f }        a function-row icon over its F label
//   { arrow }          left | right (half height, bottom) | ud (up and down stacked)
const mod = (sym, word, right = false) => ({ sym, word, right });
const FN_ICONS = ['dimmer', 'brighter', 'windows', 'search', 'mic', 'moon', 'rewind', 'play', 'forward', 'mute', 'quieter', 'louder'];
const each = (chars, w = 1) => [...chars].map(c => [w, c]);

export const keyboard = topRight => [
  [[1.5, { word: 'esc', at: 'bl' }], ...FN_ICONS.map((icon, i) => [1, { icon, f: `F${i + 1}` }]), [1.5, { icon: topRight }]],
  [[1, '~`'], ...'!1 @2 #3 $4 %5 ^6 &7 *8 (9 )0 _- +='.split(' ').map(p => [1, p]), [2, { word: '⌫', at: 'br' }]],
  [[1.5, { word: '⇥', at: 'bl' }], ...each('QWERTYUIOP'), [1, '{['], [1, '}]'], [1.5, '|\\']],
  [[1.75, { word: '⇪', at: 'bl', dot: true }], ...each('ASDFGHJKL'), [1, ':;'], [1, '"\''], [2.25, { word: '↩', at: 'br' }]],
  [[2.25, { word: '⇧', at: 'bl' }], ...each('ZXCVBNM'), [1, '<,'], [1, '>.'], [1, '?/'], [2.75, { word: '⇧', at: 'br' }]],
  [[1, { sym: 'fn', globe: true }], [1, mod('⌃', 'control')], [1, mod('⌥', 'option')], [1.25, mod('⌘', 'command')], [5.5, {}],
    [1.25, mod('⌘', 'command', true)], [1, mod('⌥', 'option', true)],
    [1, { arrow: 'left' }], [1, { arrow: 'ud' }], [1, { arrow: 'right' }]],
];

// Icons are drawn around (0, 0) at size r, white, with the stroke width already set.
function speaker(g, r) {
  g.beginPath();
  g.moveTo(-r * .95, -r * .3); g.lineTo(-r * .55, -r * .3); g.lineTo(-r * .1, -r * .72);
  g.lineTo(-r * .1, r * .72); g.lineTo(-r * .55, r * .3); g.lineTo(-r * .95, r * .3);
  g.fill();
}
function waves(g, r, n) {
  for (let i = 1; i <= n; i++) { g.beginPath(); g.arc(-r * .1, 0, r * (.12 + .32 * i), -.75, .75); g.stroke(); }
}
function sun(g, r, rays) {
  g.beginPath(); g.arc(0, 0, r * .32, 0, 7); g.fill();
  for (let i = 0; i < 8; i++) {
    const a = i * Math.PI / 4, c = Math.cos(a), s = Math.sin(a);
    g.beginPath(); g.moveTo(c * r * .55, s * r * .55); g.lineTo(c * r * (.55 + rays), s * r * (.55 + rays)); g.stroke();
  }
}
const tri = (g, pts) => { g.beginPath(); pts.forEach(([x, y], i) => i ? g.lineTo(x, y) : g.moveTo(x, y)); g.fill(); };
const ICONS = {
  dimmer: (g, r) => sun(g, r * .8, .25),
  brighter: (g, r) => sun(g, r, .45),
  windows: (g, r) => {
    for (const [x, y] of [[-r, -r * .62], [r * .1, -r * .62], [-r * .45, r * .12]]) { g.beginPath(); g.roundRect(x, y, r * .9, r * .5, r * .1); g.stroke(); }
  },
  search: (g, r) => {
    g.beginPath(); g.arc(-r * .15, -r * .15, r * .5, 0, 7); g.stroke();
    g.beginPath(); g.moveTo(r * .22, r * .22); g.lineTo(r * .72, r * .72); g.stroke();
  },
  mic: (g, r) => {
    g.beginPath(); g.roundRect(-r * .24, -r * .9, r * .48, r * .95, r * .24); g.fill();
    g.beginPath(); g.arc(0, -r * .2, r * .5, 0, Math.PI); g.stroke();
    g.beginPath(); g.moveTo(0, r * .3); g.lineTo(0, r * .7); g.moveTo(-r * .3, r * .7); g.lineTo(r * .3, r * .7); g.stroke();
  },
  moon: (g, r) => {
    g.beginPath(); g.arc(0, 0, r * .7, 0, 7); g.fill();
    g.globalCompositeOperation = 'destination-out';
    g.beginPath(); g.arc(r * .38, -r * .28, r * .6, 0, 7); g.fill();
    g.globalCompositeOperation = 'source-over';
  },
  rewind: (g, r) => { for (const x of [-r * .9, -r * .05]) tri(g, [[x, 0], [x + r * .8, -r * .55], [x + r * .8, r * .55]]); },
  forward: (g, r) => { for (const x of [r * .9, r * .05]) tri(g, [[x, 0], [x - r * .8, -r * .55], [x - r * .8, r * .55]]); },
  play: (g, r) => {
    tri(g, [[-r * .85, -r * .55], [-r * .1, 0], [-r * .85, r * .55]]);
    g.fillRect(r * .15, -r * .55, r * .2, r * 1.1); g.fillRect(r * .55, -r * .55, r * .2, r * 1.1);
  },
  mute: (g, r) => speaker(g, r),
  quieter: (g, r) => { speaker(g, r); waves(g, r, 1); },
  louder: (g, r) => { speaker(g, r); waves(g, r, 3); },
  touchid: (g, r) => { g.globalAlpha = .35; g.beginPath(); g.arc(0, 0, r * 1.9, 0, 7); g.stroke(); g.globalAlpha = 1; },
  power: (g, r) => {
    g.beginPath(); g.arc(0, 0, r * .62, -Math.PI / 2 + .7, Math.PI * 1.5 - .7); g.stroke();
    g.beginPath(); g.moveTo(0, -r * .85); g.lineTo(0, -r * .15); g.stroke();
  },
  globe: (g, r) => {
    g.beginPath(); g.arc(0, 0, r, 0, 7); g.stroke();
    g.beginPath(); g.ellipse(0, 0, r * .45, r, 0, 0, 7); g.stroke();
    g.beginPath(); g.moveTo(-r, 0); g.lineTo(r, 0); g.stroke();
  },
};

// keys: [{ x, z, w, d, legend }] in world px from the keyboard's back-left corner; s = canvas px per world px.
export function paintLegends(g, keys, s, unit) {
  const U = unit * s, pad = .17 * U;
  g.fillStyle = g.strokeStyle = '#fff';
  g.lineCap = g.lineJoin = 'round';
  g.textBaseline = 'middle';
  const font = (size, weight = 400) => { g.font = `${weight} ${size * U}px -apple-system, "SF Pro Text", system-ui, sans-serif`; };
  const text = (str, x, y, align = 'center') => { g.textAlign = align; g.fillText(str, x, y); };
  const icon = (name, cx, cy, r) => {
    g.save(); g.translate(cx, cy); g.lineWidth = r * .17; ICONS[name](g, r); g.restore();
  };

  for (const { x: kx, z: kz, w: kw, d: kd, legend: L } of keys) {
    const x = kx * s, y = kz * s, w = kw * s, h = kd * s, cx = x + w / 2, short = Math.min(1, h / U);
    if (typeof L === 'string') {
      if (L.length === 1) { font(.27); text(L, cx, y + h / 2); }
      else { font(.2); text(L[0], cx, y + h * .32); text(L[1], cx, y + h * .68); }
    } else if (L.icon) {
      const r = .13 * U * (short < 1 ? .8 : 1);
      if (!L.f) { icon(L.icon, cx, y + h / 2, r); continue; }
      icon(L.icon, cx, y + h * (short < 1 ? .38 : .4), r);
      font(.1 * (short < 1 ? .9 : 1)); text(L.f, cx, y + h * .78);
    } else if (L.sym && !L.globe) {
      font(.2); text(L.sym, L.right ? x + pad : x + w - pad, y + pad + .02 * U, L.right ? 'left' : 'right');
      font(.12); text(L.word, cx, y + h - pad);
    } else if (L.word) {
      font(L.word.length > 1 ? .14 : .24);
      L.at === 'br' ? text(L.word, x + w - pad, y + h - pad * (short < 1 ? .6 : 1), 'right')
                    : text(L.word, x + pad, y + h - pad * (short < 1 ? .6 : 1), 'left');
      if (L.dot) { g.globalAlpha = .4; g.beginPath(); g.arc(x + pad, y + pad, .035 * U, 0, 7); g.fill(); g.globalAlpha = 1; }
    } else if (L.globe) {
      font(.14); text('fn', x + w - pad, y + pad, 'right');
      icon('globe', x + pad + .1 * U, y + h - pad - .06 * U, .1 * U);
    } else if (L.arrow) {
      const a = .07 * U, ax = cx, ay = y + h / 2, dir = { left: [-1, 0], right: [1, 0], up: [0, -1], down: [0, 1] }[L.arrow];
      const [dx, dy] = dir, [px, py] = [-dy, dx];
      tri(g, [[ax + dx * a, ay + dy * a], [ax - dx * a + px * a, ay - dy * a + py * a], [ax - dx * a - px * a, ay - dy * a - py * a]]);
    }
  }
}
