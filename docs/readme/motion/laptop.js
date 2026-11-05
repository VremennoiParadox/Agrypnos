// The laptop, built in code with three.js: a silver Mac-like laptop with a notch, Touch ID and
// short function keys, and no logo. Units are screen pixels: the display is 1280 wide, about
// 4.23 px per millimetre. The base top sits at y = 0, the hinge runs along z = 0 and the base
// reaches toward +z.
import * as THREE from 'three';
import { keyboard, paintLegends } from './keys.js';

export const LOOK = {
  metal: 0xc4c6ca, rough: 0.3, well: 0x15161a, keys: 0x0f1012,
  screen: [1280, 831], menubar: 31, corner: 12, bezel: [24, 22, 76],   // side, top, chin
  base: 42, lid: 16, unit: 70, fnRow: 0.6, pad: [560, 340],
  ports: [['usbc', 150], ['usbc', 205], ['jack', 560]],
};
// The light version's finish.
export const SPACE_BLACK = { metal: 0x2e2e32, rough: 0.4, well: 0x050506, keys: 0x0b0b0c };

const PORTS = { usbc: [34, 11], jack: [15, 15] };

function roundedRect(w, h, r) {
  const s = new THREE.Shape(), x = -w / 2, y = -h / 2;
  s.moveTo(x + r, y);
  s.lineTo(x + w - r, y); s.quadraticCurveTo(x + w, y, x + w, y + r);
  s.lineTo(x + w, y + h - r); s.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  s.lineTo(x + r, y + h); s.quadraticCurveTo(x, y + h, x, y + h - r);
  s.lineTo(x, y + r); s.quadraticCurveTo(x, y, x + r, y);
  return s;
}

// A rounded slab in the XY plane, t thick along z, centred on the origin, edges bevelled by b.
function slab(w, h, t, r, b) {
  const g = new THREE.ExtrudeGeometry(roundedRect(w - 2 * b, h - 2 * b, Math.max(r - b, 0.5)), {
    depth: t - 2 * b, bevelEnabled: true, bevelThickness: b, bevelSize: b, bevelSegments: 4, curveSegments: 12,
  });
  return g.translate(0, 0, -(t - 2 * b) / 2);
}
const flat = g => g.rotateX(-Math.PI / 2);        // lay an XY shape on the base, facing up

function canvasTexture(w, h, draw) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  return new THREE.CanvasTexture(c);
}
const softShadow = () => canvasTexture(256, 256, g => {
  const r = g.createRadialGradient(128, 128, 0, 128, 128, 128);
  r.addColorStop(0, 'rgba(0,0,0,.75)'); r.addColorStop(0.55, 'rgba(0,0,0,.4)'); r.addColorStop(1, 'rgba(0,0,0,0)');
  g.fillStyle = r; g.fillRect(0, 0, 256, 256);
});

export function buildLaptop(L) {
  const [SW, SH] = L.screen, [side, top, chin] = L.bezel;
  const W = SW + 2 * side, H = top + SH + chin, D = H, GAP = 3;
  const metal = new THREE.MeshPhysicalMaterial({ color: L.metal, metalness: 1, roughness: L.rough });
  const matte = c => new THREE.MeshStandardMaterial({ color: c, roughness: 0.5, metalness: 0.2 });
  const group = new THREE.Group();
  const add = (mesh, x, y, z) => { mesh.position.set(x, y, z); group.add(mesh); return mesh; };

  add(new THREE.Mesh(flat(slab(W, D, L.base, 36, 6)), metal), 0, -L.base / 2, D / 2);
  add(new THREE.Mesh(new THREE.CylinderGeometry(10, 10, W - 200, 24).rotateZ(Math.PI / 2), matte(0x0b0b0c)), 0, -8, -2);
  add(new THREE.Mesh(flat(new THREE.PlaneGeometry(W * 1.35, D * 1.4)),
    new THREE.MeshBasicMaterial({ map: softShadow(), transparent: true, depthWrite: false })), 0, -L.base - 1, D / 2);

  // Keyboard: keys in a dark well. The well glows for the backlight; key tops stay under the shut lid.
  const u = L.unit, kbW = 15 * u, kbD = (L.fnRow + 5) * u, kbZ = 60;
  const well = new THREE.MeshStandardMaterial({ color: L.well, roughness: 0.6, emissive: 0xffffff, emissiveIntensity: 0 });
  add(new THREE.Mesh(flat(new THREE.ShapeGeometry(roundedRect(kbW + 14, kbD + 14, 10))), well), 0, 0.2, kbZ + kbD / 2);
  const keyMat = new THREE.MeshStandardMaterial({ color: L.keys, roughness: 0.8, envMapIntensity: 0.25 }), keyGeo = {};
  const placed = [];      // keyboard-local, from the back-left corner, for the legend sheet
  const key = (x, z, w, d, legend) => {
    const gap = 0.13 * u;
    keyGeo[`${w}x${d}`] ??= flat(slab(w - gap, d - gap, 2.6, 5, 0.7));
    add(new THREE.Mesh(keyGeo[`${w}x${d}`], keyMat), x - kbW / 2 + w / 2, 1.1, kbZ + z + d / 2);
    placed.push({ x: x + gap / 2, z: z + gap / 2, w: w - gap, d: d - gap, legend });
  };
  let z = 0;
  keyboard('touchid').forEach((row, r) => {
    const d = (r ? 1 : L.fnRow) * u;
    let x = 0;
    for (const [units, legend] of row) {
      const w = units * u;
      if (legend.arrow === 'ud') { key(x, z, w, d / 2, { arrow: 'up' }); key(x, z + d / 2, w, d / 2, { arrow: 'down' }); }
      else if (legend.arrow) key(x, z + d / 2, w, d / 2, legend);
      else key(x, z, w, d, legend);
      x += w;
    }
    z += d;
  });
  // Legends: one transparent sheet just over the key tops, still under the shut lid.
  const legendMap = canvasTexture(kbW * 2.5, kbD * 2.5, g => paintLegends(g, placed, 2.5, u));
  legendMap.anisotropy = 16;
  const legendMat = new THREE.MeshBasicMaterial({ map: legendMap, transparent: true, depthWrite: false,
    polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 });
  add(new THREE.Mesh(flat(new THREE.PlaneGeometry(kbW, kbD)), legendMat), 0, 2.45, kbZ + kbD / 2);
  z += kbZ;

  const [pw, pd] = L.pad;
  add(new THREE.Mesh(flat(new THREE.ShapeGeometry(roundedRect(pw, pd, 16))),
    new THREE.MeshPhysicalMaterial({ color: L.metal, metalness: 0.8, roughness: 0.14 })), 0, 0.15, (z + D) / 2);

  for (const [kind, pz] of L.ports) {
    const [w, h] = PORTS[kind];
    add(new THREE.Mesh(new THREE.ShapeGeometry(roundedRect(w, h, h / 2)).rotateY(-Math.PI / 2), matte(0x050506)), -W / 2 - 0.3, -L.base / 2, pz);
  }

  // Lid: pivots on the hinge. Local y runs hinge → top edge, the screen faces local +z.
  const lid = new THREE.Group();
  lid.position.set(0, GAP, 0);
  group.add(lid);
  const onLid = (mesh, x, y, z) => { mesh.position.set(x, y, z); lid.add(mesh); return mesh; };
  onLid(new THREE.Mesh(slab(W, H, L.lid, 36, 4), metal), 0, H / 2, -L.lid / 2);
  onLid(new THREE.Mesh(new THREE.ShapeGeometry(roundedRect(W - 8, H - 8, 32), 16),
    new THREE.MeshPhysicalMaterial({ color: 0x030304, roughness: 0.08, envMapIntensity: 0.2 })), 0, H / 2, 0.35);

  const screenPoint = (x, y) => new THREE.Vector3(x - SW / 2, chin + SH - y, 0.6);
  return {
    group, lid, W, D,
    screenAnchor: screenPoint(SW / 2, SH / 2),
    screenPoint,
    setLid(deg) { lid.rotation.x = THREE.MathUtils.degToRad(90 - deg); },
    setGlow(v) { well.emissiveIntensity = 0.04 * v; legendMat.color.setScalar(0.5 + 0.45 * v); },
  };
}
