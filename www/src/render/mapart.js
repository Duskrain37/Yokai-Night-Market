import { BOARD, BOARD_H, BOARD_W, VIEW } from '../layout.js';
import { assets } from '../core/assets.js';

const THEMES = {
  1: {
    bg: 'day1', ground: 'stone', frame: 'wood',
    rim: '#c9a05f', warm: 'rgba(255,180,92,',
    tint: 'rgba(18,30,44,0.16)',
    fog: 'rgba(255,196,132,'
  },
  2: {
    bg: 'day2', ground: 'dock', frame: 'timber',
    rim: '#d0a464', warm: 'rgba(255,188,104,',
    tint: 'rgba(10,38,42,0.22)',
    fog: 'rgba(150,214,210,'
  },
  3: {
    bg: 'day3', ground: 'boardwalk', frame: 'stone',
    rim: '#87c9bd', warm: 'rgba(255,150,86,',
    tint: 'rgba(5,28,32,0.30)',
    fog: 'rgba(120,224,214,'
  }
};

function themeOf(game) {
  const day = game?.level?.day || 1;
  return { day, theme: THEMES[day] || THEMES[1] };
}

function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}

function rnd(seed) {
  const x = Math.sin(seed * 12.9898 + 4.1414) * 43758.5453;
  return x - Math.floor(x);
}

function cover(ctx, img, x, y, w, h, zoom = 1, fx = 0.5, fy = 0.5) {
  if (!img) return false;
  const s = Math.max(w / img.width, h / img.height) * zoom;
  const dw = img.width * s;
  const dh = img.height * s;
  ctx.drawImage(img, x + (w - dw) * fx, y + (h - dh) * fy, dw, dh);
  return true;
}

let glowWarm = null;
let glowCool = null;
let glowRed = null;
let puffSprite = null;

function radial(size, stops) {
  const c = document.createElement('canvas');
  c.width = c.height = size;
  const g = c.getContext('2d');
  const grad = g.createRadialGradient(size / 2, size / 2, 1, size / 2, size / 2, size / 2);
  for (const [p, color] of stops) grad.addColorStop(p, color);
  g.fillStyle = grad;
  g.fillRect(0, 0, size, size);
  return c;
}

function warmGlow() {
  if (!glowWarm) glowWarm = radial(128, [[0, 'rgba(255,214,140,0.75)'], [0.4, 'rgba(255,158,74,0.30)'], [1, 'rgba(255,130,50,0)']]);
  return glowWarm;
}

function coolGlow() {
  if (!glowCool) glowCool = radial(128, [[0, 'rgba(168,246,232,0.55)'], [0.45, 'rgba(90,198,196,0.22)'], [1, 'rgba(50,150,160,0)']]);
  return glowCool;
}

function redGlow() {
  if (!glowRed) glowRed = radial(128, [[0, 'rgba(255,150,120,0.6)'], [0.42, 'rgba(232,70,54,0.24)'], [1, 'rgba(180,40,30,0)']]);
  return glowRed;
}

function puff() {
  if (!puffSprite) puffSprite = radial(96, [[0, 'rgba(255,255,255,0.5)'], [0.5, 'rgba(255,255,255,0.16)'], [1, 'rgba(255,255,255,0)']]);
  return puffSprite;
}

function waterBandRows(game) {
  const bands = [];
  let start = -1;
  for (let r = 0; r <= game.rows; r++) {
    const wet = r < game.rows && game.tileAt(0, r).kind === 'water';
    if (wet && start < 0) start = r;
    if (!wet && start >= 0) {
      bands.push({ r0: start, count: r - start });
      start = -1;
    }
  }
  return bands;
}

function waterBandAt(game, r) {
  for (const band of waterBandRows(game)) {
    if (r >= band.r0 && r < band.r0 + band.count) return band;
  }
  return null;
}

export function mapSceneSignature(game) {
  if (!game?.tiles) return '0';
  let sig = '';
  for (let r = 0; r < game.rows; r++) {
    for (let c = 0; c < BOARD.cols; c++) {
      const tile = game.tileAt(c, r);
      sig += tile.kind === 'land' ? 'l' : tile.kind === 'water' ? 'w' : tile.kind === 'object' ? `o${tile.obj || 0}` : `b${tile.obj || 0}`;
    }
  }
  return sig;
}

export function drawMapBackdrop(ctx, game) {
  const { day, theme } = themeOf(game);
  const img = assets.backgrounds[theme.bg] || assets.backgrounds.board;
  const drawn = cover(ctx, img, 0, 0, VIEW.w, VIEW.h, 1.015);
  if (!drawn) {
    const g = ctx.createLinearGradient(0, 0, 0, VIEW.h);
    g.addColorStop(0, day === 3 ? '#07171b' : '#0a1220');
    g.addColorStop(1, day === 2 ? '#102226' : '#150f10');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, VIEW.w, VIEW.h);
  }

  const top = ctx.createLinearGradient(0, 0, 0, 230);
  top.addColorStop(0, 'rgba(3,6,12,0.62)');
  top.addColorStop(1, 'rgba(3,6,12,0)');
  ctx.fillStyle = top;
  ctx.fillRect(0, 0, VIEW.w, 230);

  const bottom = ctx.createLinearGradient(0, VIEW.h - 120, 0, VIEW.h);
  bottom.addColorStop(0, 'rgba(2,4,8,0)');
  bottom.addColorStop(1, 'rgba(2,4,8,0.78)');
  ctx.fillStyle = bottom;
  ctx.fillRect(0, VIEW.h - 120, VIEW.w, 120);

  const left = ctx.createLinearGradient(0, 0, 200, 0);
  left.addColorStop(0, 'rgba(2,4,7,0.58)');
  left.addColorStop(1, 'rgba(2,4,7,0)');
  ctx.fillStyle = left;
  ctx.fillRect(0, 0, 200, VIEW.h);

  const right = ctx.createLinearGradient(VIEW.w - 210, 0, VIEW.w, 0);
  right.addColorStop(0, 'rgba(2,4,7,0)');
  right.addColorStop(1, 'rgba(2,4,7,0.55)');
  ctx.fillStyle = right;
  ctx.fillRect(VIEW.w - 210, 0, 210, VIEW.h);

  ctx.fillStyle = theme.tint;
  ctx.fillRect(0, 0, VIEW.w, VIEW.h);

  if (day === 3) {
    const cold = ctx.createRadialGradient(1010, 600, 20, 1010, 600, 330);
    cold.addColorStop(0, 'rgba(80,214,208,0.20)');
    cold.addColorStop(0.55, 'rgba(48,140,150,0.08)');
    cold.addColorStop(1, 'rgba(20,70,80,0)');
    ctx.fillStyle = cold;
    ctx.fillRect(680, 270, 600, 450);
    const warm = ctx.createRadialGradient(110, 300, 10, 110, 300, 280);
    warm.addColorStop(0, 'rgba(255,120,70,0.16)');
    warm.addColorStop(1, 'rgba(255,110,60,0)');
    ctx.fillStyle = warm;
    ctx.fillRect(0, 80, 420, 520);
  } else if (day === 2) {
    const mist = ctx.createLinearGradient(0, 470, 0, 690);
    mist.addColorStop(0, 'rgba(150,210,208,0)');
    mist.addColorStop(0.55, 'rgba(150,210,208,0.075)');
    mist.addColorStop(1, 'rgba(120,180,180,0.02)');
    ctx.fillStyle = mist;
    ctx.fillRect(0, 470, VIEW.w, 220);
  } else {
    const warm = ctx.createRadialGradient(180, 380, 20, 180, 380, 380);
    warm.addColorStop(0, 'rgba(255,170,86,0.13)');
    warm.addColorStop(1, 'rgba(255,150,70,0)');
    ctx.fillStyle = warm;
    ctx.fillRect(0, 120, 620, 560);
    const warm2 = ctx.createRadialGradient(1180, 300, 20, 1180, 300, 320);
    warm2.addColorStop(0, 'rgba(255,160,90,0.10)');
    warm2.addColorStop(1, 'rgba(255,150,70,0)');
    ctx.fillStyle = warm2;
    ctx.fillRect(900, 60, 380, 520);
  }

  const vig = ctx.createRadialGradient(640, 390, 240, 640, 390, 760);
  vig.addColorStop(0, 'rgba(0,0,0,0)');
  vig.addColorStop(0.66, 'rgba(2,4,8,0.12)');
  vig.addColorStop(1, 'rgba(2,3,6,0.66)');
  ctx.fillStyle = vig;
  ctx.fillRect(0, 0, VIEW.w, VIEW.h);

  const behind = ctx.createRadialGradient(640, 420, 150, 640, 420, 520);
  behind.addColorStop(0, 'rgba(2,5,9,0.26)');
  behind.addColorStop(0.7, 'rgba(2,5,9,0.10)');
  behind.addColorStop(1, 'rgba(2,5,9,0)');
  ctx.fillStyle = behind;
  ctx.fillRect(160, 150, 980, 560);
}

function frameBase(ctx, day, fx, fy, fw, fh) {
  const g = ctx.createLinearGradient(0, fy, 0, fy + fh);
  if (day === 2) {
    g.addColorStop(0, '#3b2a1c');
    g.addColorStop(0.28, '#251a12');
    g.addColorStop(0.62, '#1a120d');
    g.addColorStop(1, '#33241a');
  } else if (day === 3) {
    g.addColorStop(0, '#39423f');
    g.addColorStop(0.3, '#232a29');
    g.addColorStop(0.66, '#161d1d');
    g.addColorStop(1, '#2b3330');
  } else {
    g.addColorStop(0, '#3c2c1f');
    g.addColorStop(0.28, '#231a13');
    g.addColorStop(0.62, '#17110e');
    g.addColorStop(1, '#30231a');
  }
  ctx.fillStyle = g;
  rr(ctx, fx, fy, fw, fh, 17);
  ctx.fill();
  ctx.strokeStyle = day === 3 ? 'rgba(150,206,196,0.30)' : 'rgba(226,186,110,0.40)';
  ctx.lineWidth = 1.4;
  rr(ctx, fx + 0.7, fy + 0.7, fw - 1.4, fh - 1.4, 16);
  ctx.stroke();
}

function brassCorner(ctx, x, y, sx, sy, color = '#c8a15e') {
  ctx.save();
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.6;
  ctx.beginPath();
  ctx.moveTo(x + sx * 26, y);
  ctx.lineTo(x + sx * 6, y);
  ctx.quadraticCurveTo(x, y, x, y + sy * 6);
  ctx.lineTo(x, y + sy * 26);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(0,0,0,0.5)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(x + sx * 24, y + sy * 4);
  ctx.lineTo(x + sx * 8, y + sy * 4);
  ctx.lineTo(x + sx * 4, y + sy * 8);
  ctx.lineTo(x + sx * 4, y + sy * 24);
  ctx.stroke();
  ctx.fillStyle = color;
  for (const [dx, dy] of [[10, 10], [20, 7], [7, 20]]) {
    ctx.beginPath();
    ctx.arc(x + sx * dx, y + sy * dy, 1.5, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

function drawFrameBand(ctx, game, day, fx, fy, fw, fh) {
  const innerX = BOARD.x;
  const innerY = BOARD.y;
  const bandW = innerX - fx;
  ctx.save();
  if (day === 2) {
    for (let x = fx + 4; x < fx + fw - 4; x += 13) {
      const top = fy + 3 + rnd(x) * 2;
      const bottom = fy + fh - 3 - rnd(x + 7) * 2;
      ctx.strokeStyle = 'rgba(118,84,52,0.26)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(x, top);
      ctx.lineTo(x + 1, bottom);
      ctx.stroke();
    }
    ctx.strokeStyle = 'rgba(196,152,94,0.30)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(fx + 6, fy + 6.5);
    ctx.lineTo(fx + fw - 6, fy + 6.5);
    ctx.stroke();
    ctx.strokeStyle = 'rgba(0,0,0,0.55)';
    ctx.beginPath();
    ctx.moveTo(fx + 6, fy + fh - 6.5);
    ctx.lineTo(fx + fw - 6, fy + fh - 6.5);
    ctx.stroke();
    for (let x = fx + 22; x < fx + fw - 12; x += 46) {
      for (const y of [fy + 10, fy + fh - 10]) {
        ctx.fillStyle = 'rgba(18,12,8,0.62)';
        ctx.beginPath();
        ctx.arc(x, y, 2.1, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = 'rgba(190,150,98,0.45)';
        ctx.beginPath();
        ctx.arc(x - 0.6, y - 0.6, 0.8, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.lineCap = 'round';
    ctx.strokeStyle = 'rgba(158,124,82,0.5)';
    ctx.lineWidth = 3;
    for (const [x, y, sx] of [[fx + 16, fy + 16, 1], [fx + fw - 16, fy + fh - 16, -1]]) {
      ctx.beginPath();
      ctx.moveTo(x - sx * 12, y + 8);
      ctx.quadraticCurveTo(x, y - 6, x + sx * 14, y + 8);
      ctx.stroke();
      ctx.strokeStyle = 'rgba(60,42,26,0.6)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(x - sx * 10, y + 7);
      ctx.quadraticCurveTo(x, y - 4, x + sx * 12, y + 7);
      ctx.stroke();
      ctx.strokeStyle = 'rgba(158,124,82,0.5)';
      ctx.lineWidth = 3;
    }
  } else if (day === 3) {
    ctx.strokeStyle = 'rgba(150,210,198,0.10)';
    ctx.lineWidth = 3;
    for (const [ox, oy, sx, sy] of [[8, 8, 1, 1], [-8, 8, -1, 1], [8, -8, 1, -1], [-8, -8, -1, -1]]) {
      ctx.beginPath();
      ctx.moveTo(fx + (sx > 0 ? 20 : fw - 20), fy + (sy > 0 ? 8 : fh - 8));
      ctx.lineTo(fx + (sx > 0 ? 8 : fw - 8), fy + (sy > 0 ? 8 : fh - 8));
      ctx.stroke();
    }
    for (let x = fx + 40; x < fx + fw - 20; x += 40) {
      const seed = x * 1.7;
      const h = 2 + rnd(seed) * 5;
      ctx.fillStyle = 'rgba(88,132,110,0.22)';
      ctx.beginPath();
      ctx.ellipse(x, fy + h + 2, 8 + rnd(seed + 1) * 10, h, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = 'rgba(120,200,190,0.16)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(x - 5, fy + fh - 9);
      ctx.lineTo(x + 5, fy + fh - 9);
      ctx.stroke();
    }
    for (const [x, y] of [[fx + 17, fy + 17], [fx + fw - 17, fy + 17], [fx + 17, fy + fh - 17], [fx + fw - 17, fy + fh - 17]]) {
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(Math.PI / 4);
      ctx.strokeStyle = 'rgba(128,222,208,0.44)';
      ctx.lineWidth = 1.2;
      ctx.strokeRect(-4.5, -4.5, 9, 9);
      ctx.fillStyle = 'rgba(128,222,208,0.20)';
      ctx.fillRect(-2, -2, 4, 4);
      ctx.restore();
    }
  } else {
    ctx.strokeStyle = 'rgba(255,214,150,0.07)';
    ctx.lineWidth = 1;
    for (let x = fx + 6; x < fx + fw; x += 30) {
      ctx.beginPath();
      ctx.moveTo(x, fy + 5);
      ctx.lineTo(x, fy + fh - 5);
      ctx.stroke();
    }
    const blocksY = [fy + 6, fy + fh - 21];
    for (const by of blocksY) {
      for (let x = fx + 8; x < fx + fw - 8; x += 34) {
        ctx.fillStyle = 'rgba(84,74,60,0.22)';
        ctx.fillRect(x, by, 31, 15);
        ctx.strokeStyle = 'rgba(12,9,7,0.45)';
        ctx.lineWidth = 1;
        ctx.strokeRect(x + 0.5, by + 0.5, 30, 14);
        ctx.strokeStyle = 'rgba(255,226,170,0.07)';
        ctx.beginPath();
        ctx.moveTo(x + 1, by + 1);
        ctx.lineTo(x + 30, by + 1);
        ctx.stroke();
      }
    }
    ctx.strokeStyle = 'rgba(212,166,96,0.20)';
    ctx.lineWidth = 1;
    ctx.strokeRect(fx + bandW - 2, fy + 14, fw - bandW * 2 + 4, fh - 28);
    ctx.strokeStyle = 'rgba(255,220,150,0.10)';
    ctx.beginPath();
    ctx.moveTo(innerX + BOARD_W + 3, innerY + 2);
    ctx.lineTo(innerX + BOARD_W + 3, innerY + BOARD_H - 2);
    ctx.stroke();
  }
  ctx.restore();
}

function drawWaterSurface(ctx, game, t = 0, animated = false) {
  const B = BOARD;
  const bands = waterBandRows(game);
  const tex = assets.backgrounds.water;
  for (const band of bands) {
    const y = B.y + band.r0 * game.cellH;
    const h = band.count * game.cellH;
    ctx.save();
    ctx.beginPath();
    ctx.rect(B.x, y, BOARD_W, h);
    ctx.clip();

    if (tex) {
      const sy = (band.r0 / game.rows) * tex.height * 0.92;
      const sh = Math.min(tex.height - sy, (h / BOARD_H) * tex.height * 1.15);
      ctx.drawImage(tex, 0, sy, tex.width, sh, B.x, y, BOARD_W, h + 1);
      ctx.globalCompositeOperation = 'multiply';
      ctx.fillStyle = 'rgba(74,148,146,0.58)';
      ctx.fillRect(B.x, y, BOARD_W, h);
      ctx.globalCompositeOperation = 'source-over';
    } else {
      const g = ctx.createLinearGradient(0, y, 0, y + h);
      g.addColorStop(0, '#07181b');
      g.addColorStop(0.5, '#0b2a2e');
      g.addColorStop(1, '#051417');
      ctx.fillStyle = g;
      ctx.fillRect(B.x, y, BOARD_W, h);
    }

    const deep = ctx.createLinearGradient(0, y, 0, y + h);
    deep.addColorStop(0, 'rgba(2,18,20,0.66)');
    deep.addColorStop(0.28, 'rgba(6,40,44,0.24)');
    deep.addColorStop(0.72, 'rgba(4,28,32,0.20)');
    deep.addColorStop(1, 'rgba(1,12,14,0.72)');
    ctx.fillStyle = deep;
    ctx.fillRect(B.x, y, BOARD_W, h);

    const sheen = ctx.createLinearGradient(0, y + h * 0.1, 0, y + h * 0.8);
    sheen.addColorStop(0, 'rgba(110,226,216,0.02)');
    sheen.addColorStop(0.46, 'rgba(138,240,228,0.115)');
    sheen.addColorStop(0.8, 'rgba(70,178,184,0.035)');
    sheen.addColorStop(1, 'rgba(40,130,144,0)');
    ctx.fillStyle = sheen;
    ctx.fillRect(B.x, y, BOARD_W, h);

    for (let i = 0; i < 4; i++) {
      const rx = B.x + BOARD_W * (0.12 + i * 0.24) + Math.sin(i * 2.1) * 20;
      const rg = ctx.createLinearGradient(0, y, 0, y + h);
      rg.addColorStop(0, 'rgba(255,168,98,0)');
      rg.addColorStop(0.35, `rgba(255,168,98,${0.035 + i * 0.008})`);
      rg.addColorStop(1, 'rgba(255,150,80,0)');
      ctx.fillStyle = rg;
      ctx.fillRect(rx - 5, y, 10, h);
    }

    for (let c = 0; c < B.cols; c++) {
      const cx = B.x + c * B.cw;
      for (let i = 0; i < 3; i++) {
        const seed = c * 7.3 + band.r0 * 11.1 + i * 3.9;
        const yy = y + 12 + ((seed * 31.7) % (h - 20));
        ctx.strokeStyle = `rgba(158,232,226,${0.05 + rnd(seed) * 0.055})`;
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(cx + 8, yy);
        ctx.quadraticCurveTo(cx + B.cw * 0.5, yy - 3 - rnd(seed + 1) * 3, cx + B.cw - 8, yy);
        ctx.stroke();
      }
      const float = 0.18 + rnd(c * 5.1 + band.r0) * 0.12;
      ctx.fillStyle = `rgba(4,12,14,${float})`;
      ctx.beginPath();
      ctx.ellipse(cx + B.cw * 0.62, y + h * 0.62, 12, 2.6, 0.05, 0, Math.PI * 2);
      ctx.fill();
    }

    if (!animated) {
      const top = y;
      const bottom = y + h;
      for (const [by, flip] of [[top, 1], [bottom - 6, -1]]) {
        const beam = ctx.createLinearGradient(0, by, 0, by + 7);
        beam.addColorStop(0, '#20160e');
        beam.addColorStop(0.55, '#4b3823');
        beam.addColorStop(1, '#1a120b');
        ctx.fillStyle = beam;
        ctx.fillRect(B.x, by, BOARD_W, 7);
        ctx.strokeStyle = 'rgba(0,0,0,0.55)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(B.x, by + (flip > 0 ? 6.5 : 0.5));
        ctx.lineTo(B.x + BOARD_W, by + (flip > 0 ? 6.5 : 0.5));
        ctx.stroke();
        ctx.strokeStyle = 'rgba(196,158,104,0.20)';
        ctx.beginPath();
        ctx.moveTo(B.x, by + (flip > 0 ? 1.5 : 2.5));
        ctx.lineTo(B.x + BOARD_W, by + (flip > 0 ? 1.5 : 2.5));
        ctx.stroke();
        for (let c = 0; c <= B.cols; c++) {
          const nx = B.x + c * B.cw;
          ctx.fillStyle = 'rgba(3,4,4,0.7)';
          ctx.beginPath();
          ctx.arc(nx, by + 3.5, 1.7, 0, Math.PI * 2);
          ctx.fill();
          ctx.fillStyle = 'rgba(214,176,116,0.34)';
          ctx.beginPath();
          ctx.arc(nx - 0.4, by + 3.1, 0.65, 0, Math.PI * 2);
          ctx.fill();
          if (c % 2 === 0) {
            ctx.fillStyle = 'rgba(74,126,92,0.28)';
            ctx.beginPath();
            ctx.ellipse(nx + 18, by + 4 + flip * 1.4, 9, 2.4, 0.1, 0, Math.PI * 2);
            ctx.fill();
          }
        }
        ctx.strokeStyle = 'rgba(174,236,226,0.12)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(B.x + 6, by + (flip > 0 ? 9 : -2));
        ctx.lineTo(B.x + BOARD_W - 6, by + (flip > 0 ? 9 : -2));
        ctx.stroke();
      }
      for (let c = 0; c < B.cols; c += 2) {
        const px = B.x + c * B.cw + ((c * 37) % 40) + 22;
        ctx.fillStyle = 'rgba(66,96,82,0.5)';
        ctx.beginPath();
        ctx.ellipse(px, top + 3, 11, 3, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = 'rgba(116,152,124,0.22)';
        ctx.fillRect(px - 8, top + 1, 4, 2);
      }
    }
    ctx.restore();
  }
}

function drawGrid(ctx, game, day) {
  const B = BOARD;
  ctx.save();
  for (let r = 0; r < game.rows; r++) {
    const y = B.y + r * game.cellH;
    for (let c = 0; c < B.cols; c++) {
      const x = B.x + c * B.cw;
      const water = game.tileAt(c, r).kind === 'water';
      if (!water && (r + c) % 2 === 0) {
        ctx.fillStyle = day === 2 ? 'rgba(255,228,184,0.020)' : day === 3 ? 'rgba(160,224,212,0.012)' : 'rgba(206,228,248,0.024)';
        ctx.fillRect(x, y, B.cw, game.cellH);
      }
      ctx.strokeStyle = water
        ? 'rgba(150,230,220,0.14)'
        : day === 3 ? 'rgba(1,8,8,0.56)' : 'rgba(8,5,4,0.48)';
      ctx.lineWidth = 1.15;
      ctx.strokeRect(x + 0.5, y + 0.5, B.cw - 1, game.cellH - 1);
      ctx.strokeStyle = water
        ? 'rgba(210,255,246,0.055)'
        : day === 3 ? 'rgba(158,214,200,0.085)' : 'rgba(255,232,190,0.095)';
      ctx.lineWidth = 0.8;
      ctx.beginPath();
      ctx.moveTo(x + 1.2, y + 1.2);
      ctx.lineTo(x + B.cw - 1.2, y + 1.2);
      ctx.moveTo(x + 1.2, y + 1.2);
      ctx.lineTo(x + 1.2, y + game.cellH - 1.2);
      ctx.stroke();
    }
  }

  for (let c = 0; c <= B.cols; c++) {
    const x = B.x + c * B.cw;
    ctx.strokeStyle = 'rgba(255,226,168,0.05)';
    ctx.beginPath();
    ctx.moveTo(x, B.y + 2);
    ctx.lineTo(x, B.y + BOARD_H - 2);
    ctx.stroke();
  }

  const stud = day === 3 ? 'rgba(150,220,206,0.50)' : 'rgba(222,180,108,0.55)';
  for (let c = 0; c <= B.cols; c += 2) {
    for (let r = 0; r <= game.rows; r += 2) {
      const x = B.x + c * B.cw;
      const y = B.y + r * game.cellH;
      ctx.fillStyle = 'rgba(2,4,5,0.55)';
      ctx.beginPath();
      ctx.arc(x, y, 2.1, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = stud;
      ctx.beginPath();
      ctx.arc(x - 0.35, y - 0.35, 0.85, 0, Math.PI * 2);
      ctx.fill();
    }
  }
  ctx.restore();
}

function drawDeckSeams(ctx, game, day) {
  const B = BOARD;
  ctx.save();
  for (let r = 0; r < game.rows; r++) {
    const water = game.tileAt(0, r).kind === 'water';
    if (water) continue;
    const y = B.y + r * game.cellH;
    if (day === 1) {
      const split = 0.42 + rnd(r * 11.3 + 4) * 0.18;
      ctx.strokeStyle = 'rgba(6,8,11,0.38)';
      ctx.lineWidth = 1.1;
      ctx.beginPath();
      ctx.moveTo(B.x, y + game.cellH * split);
      ctx.lineTo(B.x + BOARD_W, y + game.cellH * split);
      ctx.stroke();
      ctx.strokeStyle = 'rgba(226,240,255,0.065)';
      ctx.lineWidth = 0.8;
      ctx.beginPath();
      ctx.moveTo(B.x, y + game.cellH * split + 1.1);
      ctx.lineTo(B.x + BOARD_W, y + game.cellH * split + 1.1);
      ctx.stroke();
      for (let c = 0; c < B.cols; c += 2) {
        const off = 0.28 + rnd(c * 7.7 + r * 5.1) * 0.44;
        const jx = B.x + (c + off) * B.cw;
        ctx.strokeStyle = 'rgba(5,7,10,0.30)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(jx, y + 2);
        ctx.lineTo(jx + (rnd(jx) - 0.5) * 4, y + game.cellH - 2);
        ctx.stroke();
        ctx.strokeStyle = 'rgba(230,244,255,0.05)';
        ctx.beginPath();
        ctx.moveTo(jx + 1, y + 2);
        ctx.lineTo(jx + 1, y + game.cellH - 2);
        ctx.stroke();
      }
    } else {
      const cold = day === 3;
      const groove = ctx.createLinearGradient(0, y - 2, 0, y + 5);
      groove.addColorStop(0, 'rgba(6,4,3,0.02)');
      groove.addColorStop(0.35, cold ? 'rgba(2,8,8,0.62)' : 'rgba(8,5,3,0.56)');
      groove.addColorStop(1, 'rgba(8,5,3,0)');
      ctx.fillStyle = groove;
      ctx.fillRect(B.x, y - 2, BOARD_W, 7);
      ctx.strokeStyle = cold ? 'rgba(150,214,200,0.12)' : 'rgba(255,218,156,0.12)';
      ctx.lineWidth = 0.8;
      ctx.beginPath();
      ctx.moveTo(B.x, y + 4.2);
      ctx.lineTo(B.x + BOARD_W, y + 4.2);
      ctx.stroke();

      for (let c = 0; c < B.cols; c += 3) {
        const jx = B.x + (c + 0.5 + (r % 2) * 0.5) * B.cw;
        ctx.strokeStyle = cold ? 'rgba(2,8,8,0.42)' : 'rgba(10,6,4,0.38)';
        ctx.lineWidth = 1.1;
        ctx.beginPath();
        ctx.moveTo(jx + (rnd(jx + r) - 0.5) * 2, y + 5);
        ctx.lineTo(jx + (rnd(jx + r + 3) - 0.5) * 2, y + game.cellH - 1);
        ctx.stroke();
        for (const ny of [y + 12, y + game.cellH - 11]) {
          ctx.fillStyle = 'rgba(2,3,4,0.62)';
          ctx.beginPath();
          ctx.arc(jx - 6, ny, 1.6, 0, Math.PI * 2);
          ctx.fill();
          ctx.fillStyle = cold ? 'rgba(170,230,216,0.28)' : 'rgba(210,170,110,0.30)';
          ctx.beginPath();
          ctx.arc(jx - 6.3, ny - 0.3, 0.6, 0, Math.PI * 2);
          ctx.fill();
          ctx.beginPath();
          ctx.arc(jx + 6, ny + 2, 1.3, 0, Math.PI * 2);
          ctx.fill();
        }
        ctx.strokeStyle = cold ? 'rgba(92,156,132,0.20)' : 'rgba(114,86,54,0.20)';
        ctx.lineWidth = 1;
        for (let g = 0; g < 3; g++) {
          const gy = y + 10 + rnd(jx + g * 5.1) * (game.cellH - 20);
          ctx.beginPath();
          ctx.moveTo(jx - 30, gy);
          ctx.quadraticCurveTo(jx - 12, gy - 1.4, jx + 8, gy + 0.6);
          ctx.stroke();
        }
      }
    }
  }
  ctx.restore();
}

function drawCellDressing(ctx, game, day) {
  const B = BOARD;
  ctx.save();
  for (let r = 0; r < game.rows; r++) {
    for (let c = 0; c < B.cols; c++) {
      if (game.tileAt(c, r).kind !== 'land') continue;
      const x = B.x + c * B.cw;
      const y = B.y + r * game.cellH;
      const seed = c * 19.73 + r * 7.31 + day * 53.17;
      const cx = x + B.cw * (0.22 + rnd(seed + 1) * 0.56);
      const cy = y + game.cellH * (0.2 + rnd(seed + 2) * 0.6);

      if (rnd(seed + 3) < (day === 1 ? 0.62 : day === 2 ? 0.24 : 0.34)) {
        const w = 12 + rnd(seed + 4) * 26;
        const h = 3 + rnd(seed + 5) * 8;
        const g = ctx.createRadialGradient(cx - w * 0.2, cy - h * 0.2, 1, cx, cy, w);
        g.addColorStop(0, day === 1 ? 'rgba(108,146,174,0.17)' : day === 2 ? 'rgba(96,126,106,0.11)' : 'rgba(80,176,160,0.12)');
        g.addColorStop(0.6, day === 1 ? 'rgba(20,36,50,0.20)' : 'rgba(10,18,16,0.16)');
        g.addColorStop(1, 'rgba(4,8,10,0)');
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.ellipse(cx, cy, w, h, -0.1 + rnd(seed + 6) * 0.25, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = day === 3 ? 'rgba(160,236,220,0.10)' : 'rgba(196,224,238,0.10)';
        ctx.lineWidth = 0.8;
        ctx.beginPath();
        ctx.ellipse(cx - 1, cy - 0.6, w * 0.64, h * 0.5, 0, 0.1, Math.PI - 0.3);
        ctx.stroke();
      }

      if (rnd(seed + 7) < 0.44) {
        const n = 3 + Math.floor(rnd(seed + 8) * 5);
        for (let i = 0; i < n; i++) {
          const mx = x + 5 + rnd(seed + 9 + i * 3.1) * (B.cw - 10);
          const my = y + (i % 2 === 0 ? 2 + rnd(seed + i) * 7 : game.cellH - 2 - rnd(seed + i) * 7);
          ctx.fillStyle = day === 3 ? `rgba(74,132,104,${0.16 + rnd(seed + i) * 0.14})` : `rgba(86,98,62,${0.14 + rnd(seed + i) * 0.12})`;
          ctx.beginPath();
          ctx.ellipse(mx, my, 3.4 + rnd(seed + i + 1) * 4, 1.6 + rnd(seed + i + 2) * 2, rnd(seed + i) * 1.2, 0, Math.PI * 2);
          ctx.fill();
        }
      }

      if (rnd(seed + 12) < 0.42) {
        const lx = x + 8 + rnd(seed + 13) * (B.cw - 20);
        const ly = y + 8 + rnd(seed + 14) * (game.cellH - 16);
        ctx.save();
        ctx.translate(lx, ly);
        ctx.rotate(rnd(seed + 15) * 5.2);
        ctx.fillStyle = day === 3 ? 'rgba(172,168,132,0.24)' : day === 2 ? 'rgba(130,96,50,0.30)' : 'rgba(132,106,58,0.32)';
        ctx.beginPath();
        ctx.ellipse(0, 0, 4.6 + rnd(seed + 16) * 2.4, 2.1, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = 'rgba(28,20,12,0.24)';
        ctx.lineWidth = 0.6;
        ctx.beginPath();
        ctx.moveTo(-4, 0);
        ctx.lineTo(4, 0);
        ctx.stroke();
        ctx.restore();
      }

      if (day === 1 && rnd(seed + 17) < 0.38) {
        ctx.strokeStyle = 'rgba(4,6,9,0.34)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        const sx = x + rnd(seed + 18) * B.cw;
        const sy = y + rnd(seed + 19) * game.cellH;
        ctx.moveTo(sx, sy);
        ctx.lineTo(sx + 7, sy + 5);
        ctx.lineTo(sx + 4, sy + 14);
        ctx.lineTo(sx + 12, sy + 19);
        ctx.stroke();
      } else if (day === 2 && rnd(seed + 20) < 0.3) {
        ctx.strokeStyle = 'rgba(30,20,10,0.30)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.ellipse(cx, cy, 4.5, 2.4, 0.2, 0, Math.PI * 2);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(cx - 12, cy + 4);
        ctx.quadraticCurveTo(cx - 4, cy + 1, cx + 8, cy + 3);
        ctx.stroke();
      } else if (day === 3 && rnd(seed + 21) < 0.35) {
        for (let i = 0; i < 4; i++) {
          const gx = x + 8 + rnd(seed + 22 + i) * (B.cw - 16);
          const gy = y + game.cellH - 4 - rnd(seed + 26 + i) * 6;
          ctx.fillStyle = `rgba(96,242,224,${0.10 + rnd(seed + i) * 0.12})`;
          ctx.beginPath();
          ctx.arc(gx, gy, 1.1 + rnd(seed + i) * 1.2, 0, Math.PI * 2);
          ctx.fill();
        }
      }
    }
  }
  ctx.restore();
}

function drawLaneLight(ctx, game, day) {
  const B = BOARD;
  ctx.save();
  if (day === 1) {
    ctx.globalCompositeOperation = 'lighter';
    const moon = ctx.createLinearGradient(B.x, B.y, B.x + BOARD_W * 0.9, B.y + BOARD_H);
    moon.addColorStop(0, 'rgba(120,176,208,0.075)');
    moon.addColorStop(0.45, 'rgba(100,150,188,0.024)');
    moon.addColorStop(1, 'rgba(255,186,120,0.05)');
    ctx.fillStyle = moon;
    ctx.fillRect(B.x, B.y, BOARD_W, BOARD_H);
    const pool = ctx.createRadialGradient(B.x + BOARD_W * 0.82, B.y + BOARD_H - 30, 12, B.x + BOARD_W * 0.82, B.y + BOARD_H - 30, 250);
    pool.addColorStop(0, 'rgba(255,166,88,0.12)');
    pool.addColorStop(1, 'rgba(255,150,80,0)');
    ctx.fillStyle = pool;
    ctx.fillRect(B.x, B.y, BOARD_W, BOARD_H);
  } else if (day === 2) {
    const warm = ctx.createLinearGradient(B.x + BOARD_W * 0.52, B.y, B.x + BOARD_W, B.y + BOARD_H);
    warm.addColorStop(0, 'rgba(255,162,84,0)');
    warm.addColorStop(1, 'rgba(255,170,94,0.085)');
    ctx.fillStyle = warm;
    ctx.fillRect(B.x, B.y, BOARD_W, BOARD_H);
    ctx.globalCompositeOperation = 'lighter';
    const edgeGlow = ctx.createRadialGradient(B.x + BOARD_W + 60, B.y + 120, 10, B.x + BOARD_W + 60, B.y + 120, 330);
    edgeGlow.addColorStop(0, 'rgba(255,158,86,0.11)');
    edgeGlow.addColorStop(1, 'rgba(255,140,70,0)');
    ctx.fillStyle = edgeGlow;
    ctx.fillRect(B.x, B.y, BOARD_W, BOARD_H);
  } else {
    for (const band of waterBandRows(game)) {
      const top = B.y + band.r0 * game.cellH;
      const h = band.count * game.cellH;
      const g1 = ctx.createLinearGradient(0, top - 34, 0, top);
      g1.addColorStop(0, 'rgba(66,190,184,0)');
      g1.addColorStop(1, 'rgba(66,196,190,0.10)');
      ctx.fillStyle = g1;
      ctx.fillRect(B.x, top - 34, BOARD_W, 34);
      const g2 = ctx.createLinearGradient(0, top + h, 0, top + h + 34);
      g2.addColorStop(0, 'rgba(66,196,190,0.10)');
      g2.addColorStop(1, 'rgba(66,190,184,0)');
      ctx.fillStyle = g2;
      ctx.fillRect(B.x, top + h, BOARD_W, 34);
    }
    ctx.globalCompositeOperation = 'lighter';
    const glow = ctx.createRadialGradient(B.x + BOARD_W * 0.18, B.y + BOARD_H * 0.18, 10, B.x + BOARD_W * 0.18, B.y + BOARD_H * 0.18, 260);
    glow.addColorStop(0, 'rgba(255,144,80,0.08)');
    glow.addColorStop(1, 'rgba(255,130,70,0)');
    ctx.fillStyle = glow;
    ctx.fillRect(B.x, B.y, BOARD_W, BOARD_H);
  }
  ctx.restore();
}


function drawPuddles(ctx, game) {
  const spots = [
    [1.6, 3.4, 0.85], [5.2, 1.2, 0.7], [7.4, 4.3, 0.62]
  ];
  for (const [cc, rr0, s] of spots) {
    const x = BOARD.x + cc * BOARD.cw;
    const y = BOARD.y + rr0 * game.cellH;
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(s, s);
    ctx.fillStyle = 'rgba(8,14,20,0.42)';
    ctx.beginPath();
    ctx.ellipse(0, 0, 38, 14, -0.12, 0, Math.PI * 2);
    ctx.fill();
    const g = ctx.createRadialGradient(-6, -2, 2, 0, 0, 38);
    g.addColorStop(0, 'rgba(116,152,178,0.24)');
    g.addColorStop(0.45, 'rgba(40,62,82,0.20)');
    g.addColorStop(1, 'rgba(10,18,26,0)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.ellipse(0, 0, 38, 14, -0.12, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = 'rgba(173,206,220,0.14)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.ellipse(-2, -1, 30, 10, -0.12, 0.1, Math.PI - 0.2);
    ctx.stroke();
    ctx.strokeStyle = 'rgba(255,190,110,0.25)';
    ctx.beginPath();
    ctx.moveTo(6, -4);
    ctx.quadraticCurveTo(18, -1, 28, -3);
    ctx.stroke();
    ctx.restore();
  }
}

function drawStall(ctx, cx, base, s, variant) {
  const w = 78 * s;
  const h = 66 * s;
  ctx.save();
  ctx.translate(cx, base);
  ctx.scale(s, s);

  ctx.fillStyle = 'rgba(0,0,0,0.42)';
  ctx.beginPath();
  ctx.ellipse(0, 2, 40, 9, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = '#6a4a2d';
  ctx.lineWidth = 2.6;
  for (const x of [-32, 31]) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, -52);
    ctx.stroke();
    ctx.fillStyle = '#3c2918';
    ctx.fillRect(x - 2.5, -56, 5, 8);
  }

  const cloth = ctx.createLinearGradient(0, -62, 0, -42);
  cloth.addColorStop(0, variant === 1 ? '#7d3630' : variant === 2 ? '#4e5a52' : '#8a4634');
  cloth.addColorStop(1, variant === 1 ? '#4d211f' : variant === 2 ? '#2c3833' : '#54271d');
  ctx.fillStyle = cloth;
  ctx.beginPath();
  ctx.moveTo(-44, -61);
  ctx.lineTo(44, -61);
  ctx.lineTo(37, -44);
  ctx.quadraticCurveTo(28, -38, 20, -44);
  ctx.quadraticCurveTo(10, -38, 0, -44);
  ctx.quadraticCurveTo(-10, -38, -20, -44);
  ctx.quadraticCurveTo(-30, -38, -38, -44);
  ctx.closePath();
  ctx.fill();
  ctx.strokeStyle = 'rgba(28,16,12,0.75)';
  ctx.lineWidth = 1.2;
  ctx.stroke();
  ctx.strokeStyle = 'rgba(238,214,170,0.20)';
  ctx.lineWidth = 1;
  for (let x = -38; x < 36; x += 12) {
    ctx.beginPath();
    ctx.moveTo(x, -60);
    ctx.lineTo(x + 2, -44);
    ctx.stroke();
  }
  ctx.fillStyle = 'rgba(255,224,176,0.20)';
  ctx.fillRect(-44, -62, 88, 2);

  const table = ctx.createLinearGradient(0, -30, 0, -6);
  table.addColorStop(0, '#6e4d2f');
  table.addColorStop(1, '#3d2917');
  ctx.fillStyle = table;
  rr(ctx, -37, -30, 74, 26, 3);
  ctx.fill();
  ctx.strokeStyle = 'rgba(20,12,8,0.7)';
  ctx.lineWidth = 1.4;
  ctx.stroke();
  ctx.fillStyle = 'rgba(255,214,152,0.16)';
  ctx.fillRect(-35, -29, 70, 2);
  ctx.strokeStyle = 'rgba(92,62,36,0.75)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(-24, -6);
  ctx.lineTo(-24, 0);
  ctx.moveTo(23, -6);
  ctx.lineTo(23, 0);
  ctx.stroke();

  if (variant === 0) {
    ctx.fillStyle = '#8a6a42';
    ctx.beginPath();
    ctx.ellipse(-14, -33, 12, 4.5, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#a98250';
    ctx.beginPath();
    ctx.ellipse(-14, -37, 12, 4.5, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#b98f58';
    ctx.beginPath();
    ctx.ellipse(-14, -41, 11, 4.2, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = 'rgba(60,40,22,0.8)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.ellipse(-14, -41, 11, 4.2, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.fillStyle = '#5b3a2a';
    ctx.beginPath();
    ctx.ellipse(12, -36, 9, 7, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#7d4d35';
    ctx.fillRect(6, -46, 12, 5);
    ctx.fillStyle = '#d2a55d';
    ctx.beginPath();
    ctx.ellipse(12, -36, 6, 4.4, 0, 0, Math.PI * 2);
    ctx.fill();
  } else if (variant === 1) {
    for (const [x, y, r] of [[-20, -35, 10], [2, -33, 8], [19, -36, 9]]) {
      ctx.fillStyle = '#6c4a2c';
      ctx.beginPath();
      ctx.ellipse(x, y, r, r * 0.55, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#c98d4c';
      ctx.beginPath();
      ctx.arc(x - 1, y - 2, r * 0.55, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#edc37a';
      ctx.beginPath();
      ctx.arc(x - 2, y - 3, r * 0.25, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.fillStyle = '#4b3220';
    ctx.fillRect(24, -40, 5, 10);
  } else {
    for (const [x, y, r] of [[-19, -35, 8], [-2, -33, 9], [16, -35, 7]]) {
      ctx.fillStyle = '#4a3b30';
      ctx.beginPath();
      ctx.ellipse(x, y, r, r * 1.1, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#6b5846';
      ctx.beginPath();
      ctx.ellipse(x - 1, y - 1, r * 0.82, r * 0.95, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#3a2b22';
      ctx.fillRect(x - 2, y - r - 2, 4, 3);
    }
  }

  ctx.strokeStyle = 'rgba(200,158,96,0.55)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(31, -54);
  ctx.lineTo(38, -43);
  ctx.stroke();
  ctx.fillStyle = '#a3332a';
  ctx.beginPath();
  ctx.ellipse(38, -40, 4.6, 6.2, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = 'rgba(255,196,120,0.85)';
  ctx.beginPath();
  ctx.arc(38, -40, 1.7, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function drawPier(ctx, cx, base, s, variant) {
  ctx.save();
  ctx.translate(cx, base);
  ctx.scale(s, s);
  ctx.fillStyle = 'rgba(0,0,0,0.38)';
  ctx.beginPath();
  ctx.ellipse(0, 6, 36, 11, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#3b2a1b';
  for (const x of [-27, -9, 9, 27]) {
    ctx.fillRect(x - 2, -6, 4, 18);
    ctx.fillStyle = 'rgba(150,200,188,0.20)';
    ctx.fillRect(x - 2, 8, 4, 3);
    ctx.fillStyle = '#3b2a1b';
  }
  const planks = ctx.createLinearGradient(0, -22, 0, -4);
  planks.addColorStop(0, '#6b5134');
  planks.addColorStop(1, '#3f2d1c');
  ctx.fillStyle = planks;
  rr(ctx, -33, -22, 66, 18, 3);
  ctx.fill();
  ctx.strokeStyle = 'rgba(16,10,7,0.7)';
  ctx.lineWidth = 1.2;
  ctx.stroke();
  ctx.strokeStyle = 'rgba(210,180,126,0.25)';
  for (let x = -28; x < 30; x += 9) {
    ctx.beginPath();
    ctx.moveTo(x, -21);
    ctx.lineTo(x, -5);
    ctx.stroke();
  }
  ctx.fillStyle = 'rgba(255,216,156,0.16)';
  ctx.fillRect(-31, -22, 62, 2);

  if (variant === 0) {
    ctx.fillStyle = '#4b3a24';
    ctx.fillRect(-24, -59, 3.4, 38);
    ctx.strokeStyle = 'rgba(220,178,108,0.55)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(-23, -56);
    ctx.lineTo(-14, -54);
    ctx.stroke();
    ctx.fillStyle = '#a4342a';
    ctx.beginPath();
    ctx.ellipse(-9, -52, 8, 10, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = 'rgba(255,206,140,0.95)';
    ctx.beginPath();
    ctx.arc(-9, -52, 3.4, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = 'rgba(255,170,90,0.18)';
    ctx.beginPath();
    ctx.arc(-9, -52, 18, 0, Math.PI * 2);
    ctx.fill();
  } else if (variant === 1) {
    ctx.fillStyle = '#5a4026';
    ctx.beginPath();
    ctx.ellipse(12, -30, 13, 8, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#7a5a35';
    ctx.beginPath();
    ctx.ellipse(12, -34, 12, 7, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = 'rgba(220,186,130,0.35)';
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.ellipse(12, -34, 8, 4.5, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.fillStyle = '#3f2f1d';
    ctx.fillRect(10, -44, 4, 6);
    ctx.fillStyle = '#d7c49a';
    ctx.beginPath();
    ctx.moveTo(12, -45);
    ctx.lineTo(24, -41);
    ctx.lineTo(12, -37);
    ctx.closePath();
    ctx.fill();
  } else {
    ctx.fillStyle = '#49351f';
    ctx.fillRect(-26, -40, 4, 22);
    ctx.fillRect(20, -40, 4, 22);
    ctx.fillRect(-26, -40, 50, 3);
    ctx.strokeStyle = 'rgba(180,148,96,0.55)';
    ctx.lineWidth = 1.4;
    for (let i = 0; i < 3; i++) {
      ctx.beginPath();
      ctx.moveTo(-24, -36 + i * 4);
      ctx.lineTo(-14, -30 + i * 4);
      ctx.stroke();
    }
    ctx.fillStyle = '#9c3328';
    ctx.beginPath();
    ctx.ellipse(2, -46, 4, 5.4, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = 'rgba(255,200,120,0.8)';
    ctx.beginPath();
    ctx.arc(2, -46, 1.4, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

function drawMowerDais(ctx, game, t, day) {
  const x = BOARD.x - 32;
  for (let r = 0; r < game.rows; r++) {
    const y = game.rowY(r) + 10;
    ctx.save();
    ctx.translate(x, y + 14);
    ctx.fillStyle = 'rgba(0,0,0,0.4)';
    ctx.beginPath();
    ctx.ellipse(0, 8, 29, 7, 0, 0, Math.PI * 2);
    ctx.fill();
    const g = ctx.createLinearGradient(0, -8, 0, 8);
    if (day === 2) {
      g.addColorStop(0, '#5e452b');
      g.addColorStop(1, '#2f2115');
    } else if (day === 3) {
      g.addColorStop(0, '#3f4744');
      g.addColorStop(1, '#1d2523');
    } else {
      g.addColorStop(0, '#4c453b');
      g.addColorStop(1, '#262019');
    }
    ctx.fillStyle = g;
    rr(ctx, -26, -7, 52, 15, 5);
    ctx.fill();
    ctx.strokeStyle = day === 3 ? 'rgba(128,214,200,0.30)' : 'rgba(222,180,110,0.32)';
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.fillStyle = 'rgba(255,226,170,0.10)';
    ctx.fillRect(-23, -6, 46, 1.4);
    if (day === 3) {
      ctx.strokeStyle = `rgba(120,224,212,${0.22 + Math.sin(t * 1.4 + r) * 0.08})`;
      ctx.beginPath();
      ctx.moveTo(-13, 2);
      ctx.lineTo(-5, 2);
      ctx.lineTo(0, -2);
      ctx.lineTo(5, 2);
      ctx.lineTo(13, 2);
      ctx.stroke();
    } else {
      ctx.fillStyle = 'rgba(196,160,96,0.35)';
      ctx.fillRect(-10, 0, 20, 2.4);
    }
    ctx.restore();
  }
}

function drawFrameExtras(ctx, game, day, fx, fy, fw, fh) {
  ctx.save();
  if (day === 1) {
    ctx.strokeStyle = 'rgba(38,26,18,0.9)';
    ctx.lineWidth = 2.4;
    ctx.beginPath();
    ctx.moveTo(fx + fw + 10, fy + 24);
    ctx.lineTo(fx + fw + 30, fy + 16);
    ctx.lineTo(fx + fw + 32, fy + 30);
    ctx.stroke();
    const lx = fx + fw + 32;
    const ly = fy + 44;
    ctx.fillStyle = 'rgba(12,8,6,0.5)';
    ctx.beginPath();
    ctx.ellipse(lx, ly + 14, 13, 4, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#b93e2e';
    ctx.beginPath();
    ctx.ellipse(lx, ly, 9, 12, 0.04, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = 'rgba(255,214,148,0.55)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.ellipse(lx, ly, 8, 11, 0, 0.2, Math.PI - 0.2);
    ctx.stroke();
    ctx.fillStyle = '#f0c06a';
    ctx.fillRect(lx - 6, ly - 13, 12, 2);
    ctx.fillRect(lx - 6, ly + 11, 12, 2);
    ctx.globalCompositeOperation = 'lighter';
    ctx.drawImage(warmGlow(), lx - 32, ly - 30, 64, 64);
    ctx.globalCompositeOperation = 'source-over';
  } else if (day === 2) {
    ctx.lineCap = 'round';
    for (const [x0, y0, x1, y1, sag] of [
      [fx + 12, fy + fh - 10, fx - 128, fy + fh + 54, 22],
      [fx + fw - 14, fy + fh - 8, fx + fw + 118, fy + fh + 58, 26]
    ]) {
      ctx.strokeStyle = 'rgba(20,14,9,0.82)';
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(x0, y0);
      ctx.quadraticCurveTo((x0 + x1) / 2, (y0 + y1) / 2 + sag, x1, y1);
      ctx.stroke();
      ctx.strokeStyle = 'rgba(144,108,68,0.42)';
      ctx.lineWidth = 1.2;
      ctx.beginPath();
      ctx.moveTo(x0 - 1, y0 - 1);
      ctx.quadraticCurveTo((x0 + x1) / 2 - 1, (y0 + y1) / 2 + sag - 1, x1 - 1, y1 - 1);
      ctx.stroke();
    }
    ctx.strokeStyle = 'rgba(124,92,58,0.58)';
    ctx.lineWidth = 3.4;
    for (let i = 0; i < 3; i++) {
      ctx.beginPath();
      ctx.ellipse(fx + 18 + i * 2.4, fy + fh + 2 - i * 2.4, 15, 5.2, 0.06, 0, Math.PI * 2);
      ctx.stroke();
    }
    const fx2 = fx - 70;
    const fy2 = fy + 118;
    ctx.fillStyle = 'rgba(8,12,12,0.54)';
    ctx.beginPath();
    ctx.ellipse(fx2, fy2 + 8, 12, 4, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#a9402e';
    ctx.beginPath();
    ctx.ellipse(fx2, fy2, 8, 10, 0.05, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = 'rgba(255,224,160,0.9)';
    ctx.beginPath();
    ctx.ellipse(fx2 - 1, fy2 + 2, 2.4, 3, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalCompositeOperation = 'lighter';
    ctx.drawImage(warmGlow(), fx2 - 28, fy2 - 26, 56, 56);
    ctx.globalCompositeOperation = 'source-over';
    ctx.strokeStyle = 'rgba(112,190,182,0.12)';
    ctx.lineWidth = 1;
    for (let i = 0; i < 3; i++) {
      ctx.beginPath();
      ctx.ellipse(fx2, fy2 + 12 + i * 6, 11 + i * 5, 2.4 + i, 0, 0, Math.PI * 2);
      ctx.stroke();
    }
  } else {
    ctx.strokeStyle = 'rgba(34,66,54,0.86)';
    ctx.lineWidth = 2.2;
    for (let i = 0; i < 4; i++) {
      const x = fx + 44 + i * 18;
      const len = 22 + rnd(i * 4.7) * 26;
      ctx.beginPath();
      ctx.moveTo(x, fy + 4);
      ctx.quadraticCurveTo(x - 4, fy + len * 0.6, x + 2, fy + len);
      ctx.stroke();
      ctx.fillStyle = 'rgba(116,190,158,0.30)';
      ctx.beginPath();
      ctx.ellipse(x + 2, fy + len, 3 + rnd(i) * 2, 1.6, 0.2, 0, Math.PI * 2);
      ctx.fill();
    }
    for (let i = 0; i < 3; i++) {
      const x = fx + fw - 30 - i * 16;
      const len = 16 + rnd(i * 8.1) * 22;
      ctx.strokeStyle = `rgba(104,214,198,${0.14 + rnd(i) * 0.1})`;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(x, fy + fh - 2);
      ctx.quadraticCurveTo(x + 3, fy + fh + len * 0.5, x - 2, fy + fh + len);
      ctx.stroke();
    }
    ctx.globalCompositeOperation = 'lighter';
    for (const [gx, gy] of [[fx - 36, fy + fh - 42], [fx + fw + 32, fy + 24]]) {
      const g = ctx.createRadialGradient(gx, gy, 2, gx, gy, 34);
      g.addColorStop(0, 'rgba(90,236,216,0.22)');
      g.addColorStop(1, 'rgba(50,150,150,0)');
      ctx.fillStyle = g;
      ctx.fillRect(gx - 34, gy - 34, 68, 68);
      for (let i = 0; i < 3; i++) {
        const mx = gx + (rnd(i * 3.1) - 0.5) * 24;
        const my = gy + (rnd(i * 7.7) - 0.5) * 16;
        ctx.fillStyle = 'rgba(118,242,224,0.32)';
        ctx.beginPath();
        ctx.ellipse(mx, my, 4.6, 2.2, 0.1, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = 'rgba(98,212,196,0.26)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(mx, my + 2);
        ctx.lineTo(mx - 1, my + 9);
        ctx.stroke();
      }
    }
    ctx.globalCompositeOperation = 'source-over';
  }
  ctx.restore();
}

export function drawBoardArt(ctx, game) {
  const { day, theme } = themeOf(game);
  const B = BOARD;
  const fx = B.x - 26;
  const fy = B.y - 26;
  const fw = BOARD_W + 52;
  const fh = BOARD_H + 52;

  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.78)';
  ctx.shadowBlur = 34;
  ctx.shadowOffsetY = 16;
  ctx.fillStyle = '#050607';
  rr(ctx, fx - 6, fy - 4, fw + 12, fh + 18, 22);
  ctx.fill();
  ctx.restore();

  ctx.save();
  frameBase(ctx, day, fx, fy, fw, fh);
  drawFrameBand(ctx, game, day, fx, fy, fw, fh);

  ctx.save();
  rr(ctx, B.x - 4, B.y - 4, BOARD_W + 8, BOARD_H + 8, 7);
  ctx.clip();

  const base = ctx.createLinearGradient(0, B.y, 0, B.y + BOARD_H);
  if (day === 2) {
    base.addColorStop(0, '#4a3522');
    base.addColorStop(0.5, '#372818');
    base.addColorStop(1, '#2a1e14');
  } else if (day === 3) {
    base.addColorStop(0, '#25302a');
    base.addColorStop(0.5, '#1a2521');
    base.addColorStop(1, '#131d1b');
  } else {
    base.addColorStop(0, '#3b424e');
    base.addColorStop(0.5, '#303844');
    base.addColorStop(1, '#272d38');
  }
  ctx.fillStyle = base;
  ctx.fillRect(B.x, B.y, BOARD_W, BOARD_H);

  const ground = assets.backgrounds[theme.ground];
  if (ground) {
    ctx.globalAlpha = day === 2 ? 0.58 : day === 3 ? 0.66 : 0.82;
    const zoom = day === 1 ? 1.34 : day === 2 ? 1.16 : 1.3;
    cover(ctx, ground, B.x, B.y, BOARD_W, BOARD_H, zoom, 0.5, day === 2 ? 0.42 : 0.5);
    ctx.globalAlpha = 1;
  }

  ctx.save();
  if (day === 1) {
    ctx.globalCompositeOperation = 'overlay';
    ctx.fillStyle = 'rgba(34,84,116,0.30)';
    ctx.fillRect(B.x, B.y, BOARD_W, BOARD_H);
    ctx.globalCompositeOperation = 'source-over';
    ctx.fillStyle = 'rgba(10,20,30,0.24)';
    ctx.fillRect(B.x, B.y, BOARD_W, BOARD_H);
  } else if (day === 2) {
    ctx.globalCompositeOperation = 'overlay';
    ctx.fillStyle = 'rgba(124,74,34,0.34)';
    ctx.fillRect(B.x, B.y, BOARD_W, BOARD_H);
    ctx.globalCompositeOperation = 'source-over';
    ctx.fillStyle = 'rgba(34,22,12,0.18)';
    ctx.fillRect(B.x, B.y, BOARD_W, BOARD_H);
  } else {
    ctx.globalCompositeOperation = 'overlay';
    ctx.fillStyle = 'rgba(24,84,74,0.28)';
    ctx.fillRect(B.x, B.y, BOARD_W, BOARD_H);
    ctx.globalCompositeOperation = 'source-over';
    ctx.fillStyle = 'rgba(5,17,16,0.34)';
    ctx.fillRect(B.x, B.y, BOARD_W, BOARD_H);
  }
  ctx.restore();

  drawDeckSeams(ctx, game, day);
  drawCellDressing(ctx, game, day);
  if (day === 1) drawPuddles(ctx, game);
  drawWaterSurface(ctx, game, 0, false);
  drawGrid(ctx, game, day);
  drawLaneLight(ctx, game, day);

  for (let r = 0; r < game.rows; r++) {
    for (let c = 0; c < B.cols; c++) {
      const tile = game.tileAt(c, r);
      if (tile.kind !== 'blocked' && tile.kind !== 'object') continue;
      const rawCx = B.x + c * B.cw + B.cw / 2;
      const cx = Math.max(B.x + 44, Math.min(B.x + BOARD_W - 44, rawCx));
      const baseY = B.y + r * game.cellH + game.cellH - 5;
      if (tile.kind === 'blocked') {
        const s = Math.min(0.96, (game.cellH - 7) / 66);
        drawStall(ctx, cx, baseY, s, tile.obj || 0);
      } else {
        const s = Math.min(1, (game.cellH - 4) / 82);
        drawPier(ctx, cx, baseY - 2, s, tile.obj || 0);
      }
    }
  }

  const edge = ctx.createLinearGradient(0, B.y, 0, B.y + 34);
  edge.addColorStop(0, 'rgba(0,0,0,0.58)');
  edge.addColorStop(0.55, 'rgba(0,0,0,0.16)');
  edge.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = edge;
  ctx.fillRect(B.x, B.y, BOARD_W, 34);
  const edgeB = ctx.createLinearGradient(0, B.y + BOARD_H - 30, 0, B.y + BOARD_H);
  edgeB.addColorStop(0, 'rgba(0,0,0,0)');
  edgeB.addColorStop(1, 'rgba(0,0,0,0.46)');
  ctx.fillStyle = edgeB;
  ctx.fillRect(B.x, B.y + BOARD_H - 30, BOARD_W, 30);
  const edgeL = ctx.createLinearGradient(B.x, 0, B.x + 38, 0);
  edgeL.addColorStop(0, 'rgba(0,0,0,0.40)');
  edgeL.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = edgeL;
  ctx.fillRect(B.x, B.y, 38, BOARD_H);
  const edgeR = ctx.createLinearGradient(B.x + BOARD_W - 38, 0, B.x + BOARD_W, 0);
  edgeR.addColorStop(0, 'rgba(0,0,0,0)');
  edgeR.addColorStop(1, 'rgba(0,0,0,0.38)');
  ctx.fillStyle = edgeR;
  ctx.fillRect(B.x + BOARD_W - 38, B.y, 38, BOARD_H);

  const rim = ctx.createLinearGradient(0, B.y, 0, B.y + BOARD_H);
  rim.addColorStop(0, day === 3 ? 'rgba(150,218,206,0.10)' : 'rgba(255,214,150,0.10)');
  rim.addColorStop(0.12, 'rgba(0,0,0,0)');
  rim.addColorStop(0.88, 'rgba(0,0,0,0)');
  rim.addColorStop(1, 'rgba(0,0,0,0.22)');
  ctx.fillStyle = rim;
  ctx.fillRect(B.x, B.y, BOARD_W, BOARD_H);

  ctx.restore();

  ctx.strokeStyle = day === 3 ? 'rgba(150,224,212,0.30)' : 'rgba(232,196,128,0.34)';
  ctx.lineWidth = 1.4;
  rr(ctx, B.x - 3.5, B.y - 3.5, BOARD_W + 7, BOARD_H + 7, 7);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(0,0,0,0.62)';
  ctx.lineWidth = 2.4;
  rr(ctx, B.x + 2, B.y + 2, BOARD_W - 4, BOARD_H - 4, 5);
  ctx.stroke();

  for (const [x, y, sx, sy] of [
    [fx + 6, fy + 6, 1, 1],
    [fx + fw - 6, fy + 6, -1, 1],
    [fx + 6, fy + fh - 6, 1, -1],
    [fx + fw - 6, fy + fh - 6, -1, -1]
  ]) {
    brassCorner(ctx, x, y, sx, sy, day === 3 ? 'rgba(132,212,200,0.6)' : undefined);
  }

  drawFrameExtras(ctx, game, day, fx, fy, fw, fh);
  drawMowerDais(ctx, game, 0, day);
  ctx.restore();
}


function drawWaterAnimation(ctx, game, t, day) {
  const B = BOARD;
  const bands = waterBandRows(game);
  if (!bands.length) return;
  ctx.save();
  for (const band of bands) {
    const y = B.y + band.r0 * game.cellH;
    const h = band.count * game.cellH;
    ctx.save();
    ctx.beginPath();
    ctx.rect(B.x, y, BOARD_W, h);
    ctx.clip();
    ctx.globalCompositeOperation = 'lighter';
    for (let c = 0; c < B.cols; c++) {
      const cx = B.x + c * B.cw;
      for (let i = 0; i < 2; i++) {
        const seed = c * 5.7 + band.r0 * 9.3 + i * 4.1;
        const speed = 9 + rnd(seed) * 14;
        const yy = y + 14 + ((rnd(seed + 2) * (h - 26) + t * speed) % (h - 26));
        const len = 16 + rnd(seed + 4) * 30;
        const alpha = 0.035 + rnd(seed + 6) * 0.055;
        ctx.strokeStyle = `rgba(152,236,226,${alpha})`;
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(cx + 10, yy);
        ctx.quadraticCurveTo(cx + B.cw * 0.45, yy - 4, cx + 10 + len, yy - 1);
        ctx.stroke();
        const xx = cx + 16 + rnd(seed + 8) * (B.cw - 34);
        ctx.fillStyle = `rgba(200,255,246,${alpha * 0.9})`;
        ctx.beginPath();
        ctx.ellipse(xx, yy - 1.2, 2.2, 0.7, 0, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    const glows = [0.12, 0.38, 0.64, 0.88];
    for (let i = 0; i < glows.length; i++) {
      const gx = B.x + glows[i] * BOARD_W + Math.sin(t * 0.6 + i * 1.7) * 6;
      const gy = y + h * (i % 2 === 0 ? 0.34 : 0.7);
      const flick = 0.4 + Math.sin(t * 2.1 + i * 2.3) * 0.18;
      const g = ctx.createRadialGradient(gx, gy, 1, gx, gy, 26);
      g.addColorStop(0, `rgba(255,158,92,${0.10 * flick})`);
      g.addColorStop(1, 'rgba(255,120,60,0)');
      ctx.fillStyle = g;
      ctx.fillRect(gx - 26, gy - 26, 52, 52);
      ctx.strokeStyle = `rgba(255,170,104,${0.10 * flick})`;
      ctx.lineWidth = 1.6;
      for (let k = 0; k < 2; k++) {
        const w = 5 + Math.sin(t * 1.5 + i + k) * 2;
        ctx.beginPath();
        ctx.moveTo(gx + k * 6 - 3, gy + 4);
        ctx.quadraticCurveTo(gx + k * 6 + w, gy + 12, gx + k * 6 - 1, gy + 20 + (i % 2) * 5);
        ctx.stroke();
      }
    }
    const ang = t * 0.5;
    const fx = B.x + BOARD_W * 0.3 + Math.sin(ang) * 30;
    const fy = y + h * 0.55 + Math.cos(ang * 1.7) * 5;
    ctx.fillStyle = 'rgba(2,10,12,0.35)';
    ctx.beginPath();
    ctx.ellipse(fx, fy, 12, 3, 0.15, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalCompositeOperation = 'source-over';
    ctx.restore();
  }
  ctx.restore();
}

function drawSteam(ctx, game, t, day) {
  const puffs = [];
  for (let r = 0; r < game.rows; r++) {
    for (let c = 0; c < BOARD.cols; c++) {
      const tile = game.tileAt(c, r);
      if (tile.kind === 'blocked') {
        puffs.push({
          x: BOARD.x + c * BOARD.cw + 40,
          y: BOARD.y + r * game.cellH + game.cellH - 68,
          seed: c * 3.7 + r * 8.1
        });
      }
    }
  }
  if (day === 1) {
    puffs.push({ x: BOARD.x + 90, y: BOARD.y + BOARD_H - 30, seed: 4.4 });
    puffs.push({ x: BOARD.x + 9 * BOARD.cw - 80, y: BOARD.y + BOARD_H - 26, seed: 9.2 });
  }
  const sprite = puff();
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  for (const p of puffs) {
    for (let i = 0; i < 3; i++) {
      const life = (t * 0.18 + i / 3 + rnd(p.seed) * 0.3) % 1;
      const alpha = 0.05 * (1 - life) * (i === 1 ? 0.8 : 1);
      const size = 14 + life * 26;
      ctx.globalAlpha = alpha;
      ctx.drawImage(sprite, p.x - size / 2 + Math.sin(t * 0.8 + p.seed + i) * 7, p.y - life * 36, size, size);
    }
  }
  ctx.restore();
}

function drawAmbientMotes(ctx, game, t, day) {
  const count = day === 3 ? 26 : day === 2 ? 18 : 22;
  ctx.save();
  for (let i = 0; i < count; i++) {
    const seed = i * 13.71;
    const baseX = rnd(seed) * VIEW.w;
    const speed = 6 + rnd(seed + 1) * 12;
    const drift = Math.sin(t * 0.5 + i) * 14;
    const y = ((rnd(seed + 2) * VIEW.h + t * speed * (day === 1 ? -1 : 0.6)) % VIEW.h + VIEW.h) % VIEW.h;
    const x = baseX + drift;
    const twinkle = 0.35 + Math.sin(t * 2 + i * 1.3) * 0.3;
    ctx.globalAlpha = Math.max(0.08, twinkle * 0.8);
    ctx.fillStyle = day === 3 ? (i % 3 === 0 ? '#ffc59a' : '#9ff4e6') : day === 2 ? '#ffd9a0' : '#ffc27a';
    ctx.beginPath();
    ctx.arc(x, y, i % 5 === 0 ? 1.8 : 1, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

function drawMist(ctx, game, t, day) {
  if (day === 1) return;
  ctx.save();
  const sprite = puff();
  const bands = day === 3 ? [
    { y: 590, a: 0.10, c: 'rgba(120,220,214,' },
    { y: 640, a: 0.08, c: 'rgba(120,220,214,' }
  ] : [
    { y: 610, a: 0.08, c: 'rgba(150,214,208,' },
    { y: 660, a: 0.05, c: 'rgba(150,214,208,' }
  ];
  for (let bi = 0; bi < bands.length; bi++) {
    const b = bands[bi];
    for (let i = 0; i < 4; i++) {
      const x = ((t * (5 + bi * 3) + i * 280 + bi * 130) % (VIEW.w + 260)) - 130;
      const y = b.y + Math.sin(t * 0.4 + i * 1.7 + bi) * 8;
      const w = 260 + i * 40;
      ctx.globalAlpha = b.a * (0.7 + Math.sin(t * 0.7 + i) * 0.25);
      ctx.drawImage(sprite, x - w / 2, y - 28, w, 56);
    }
  }
  ctx.restore();
}

function drawForegroundLanterns(ctx, game, t, day) {
  const anchors = day === 3
    ? [[58, 268, 1.1], [1222, 238, 1.0]]
    : [[52, 300, 1.0], [1226, 320, 0.94]];
  for (let i = 0; i < anchors.length; i++) {
    const [x, y, s] = anchors[i];
    const sway = Math.sin(t * 0.8 + i * 2) * 0.03;
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(sway);
    ctx.scale(s, s);
    ctx.strokeStyle = 'rgba(38,26,18,0.75)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(0, -120);
    ctx.lineTo(0, -34);
    ctx.stroke();
    ctx.fillStyle = 'rgba(10,7,5,0.65)';
    ctx.beginPath();
    ctx.ellipse(0, 0, 15, 20, 0, 0, Math.PI * 2);
    ctx.fill();
    const flick = 0.85 + Math.sin(t * 2.4 + i * 1.1) * 0.15;
    ctx.globalCompositeOperation = 'lighter';
    ctx.globalAlpha = 0.55 * flick;
    ctx.drawImage(redGlow(), -58, -58, 116, 116);
    ctx.globalAlpha = 0.9;
    ctx.fillStyle = 'rgba(255,144,96,0.8)';
    ctx.beginPath();
    ctx.ellipse(0, 0, 8, 12, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalCompositeOperation = 'source-over';
    ctx.globalAlpha = 1;
    ctx.fillStyle = '#2b1a12';
    ctx.fillRect(-9, 17, 18, 4);
    ctx.strokeStyle = 'rgba(180,60,40,0.5)';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.moveTo(0, 21);
    ctx.lineTo(0, 36);
    ctx.stroke();
    ctx.restore();
  }
}

function drawCornerProps(ctx, game, t, day) {
  ctx.save();
  if (day === 1) {
    ctx.fillStyle = 'rgba(8,7,7,0.82)';
    ctx.beginPath();
    ctx.ellipse(54, 716, 96, 34, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = 'rgba(20,15,12,0.9)';
    ctx.beginPath();
    ctx.moveTo(0, 676);
    ctx.quadraticCurveTo(38, 660, 92, 686);
    ctx.lineTo(118, 720);
    ctx.lineTo(0, 720);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = 'rgba(168,124,72,0.28)';
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.moveTo(16, 690);
    ctx.quadraticCurveTo(44, 676, 82, 692);
    ctx.stroke();
    ctx.fillStyle = 'rgba(255,168,90,0.14)';
    ctx.beginPath();
    ctx.ellipse(52, 700, 34, 8, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = 'rgba(7,6,6,0.85)';
    ctx.beginPath();
    ctx.moveTo(1280, 668);
    ctx.quadraticCurveTo(1232, 660, 1204, 690);
    ctx.lineTo(1180, 720);
    ctx.lineTo(1280, 720);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = 'rgba(190,148,90,0.22)';
    ctx.beginPath();
    ctx.moveTo(1262, 682);
    ctx.lineTo(1218, 700);
    ctx.stroke();
  } else if (day === 2) {
    ctx.strokeStyle = 'rgba(12,8,6,0.9)';
    ctx.lineWidth = 13;
    ctx.beginPath();
    ctx.moveTo(56, 700);
    ctx.lineTo(56, 640);
    ctx.stroke();
    ctx.lineWidth = 3;
    ctx.strokeStyle = 'rgba(158,120,76,0.30)';
    ctx.beginPath();
    ctx.moveTo(51, 690);
    ctx.lineTo(51, 646);
    ctx.stroke();
    ctx.strokeStyle = 'rgba(140,110,76,0.40)';
    ctx.lineWidth = 5;
    for (let i = 0; i < 3; i++) {
      ctx.beginPath();
      ctx.ellipse(58 + i * 3, 706 - i * 3, 27, 9, 0, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.fillStyle = 'rgba(6,7,7,0.86)';
    ctx.beginPath();
    ctx.moveTo(1244, 690);
    ctx.quadraticCurveTo(1192, 682, 1166, 714);
    ctx.lineTo(1166, 720);
    ctx.lineTo(1280, 720);
    ctx.lineTo(1280, 704);
    ctx.quadraticCurveTo(1262, 690, 1244, 690);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = 'rgba(190,150,92,0.22)';
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.moveTo(1208, 702);
    ctx.quadraticCurveTo(1234, 694, 1262, 702);
    ctx.stroke();
  } else {
    ctx.fillStyle = 'rgba(5,10,10,0.9)';
    ctx.beginPath();
    ctx.ellipse(70, 716, 110, 36, 0, 0, Math.PI * 2);
    ctx.fill();
    for (let i = 0; i < 5; i++) {
      const x = 26 + i * 22;
      const h = 28 + (i % 3) * 14;
      const glow = 0.22 + Math.sin(t * 1.5 + i) * 0.08;
      ctx.strokeStyle = `rgba(110,236,224,${glow})`;
      ctx.lineWidth = 1.4;
      ctx.beginPath();
      ctx.moveTo(x, 704);
      ctx.quadraticCurveTo(x - 4, 704 - h * 0.6, x + 3, 704 - h);
      ctx.stroke();
      ctx.fillStyle = `rgba(120,240,226,${glow * 0.9})`;
      ctx.beginPath();
      ctx.ellipse(x + 2, 704 - h, 7, 4, 0.2, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.fillStyle = 'rgba(5,10,10,0.9)';
    ctx.beginPath();
    ctx.ellipse(1222, 718, 96, 30, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = 'rgba(30,52,48,0.9)';
    ctx.lineWidth = 3;
    for (let i = 0; i < 6; i++) {
      const x = 1166 + i * 18;
      ctx.beginPath();
      ctx.moveTo(x, 714);
      ctx.quadraticCurveTo(x + 5, 690, x + 1, 652 + (i % 3) * 10);
      ctx.stroke();
    }
    ctx.strokeStyle = `rgba(120,226,212,${0.18 + Math.sin(t * 1.2) * 0.06})`;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(1180, 690);
    ctx.quadraticCurveTo(1216, 680, 1256, 692);
    ctx.stroke();
  }
  ctx.restore();
}

export function drawMapAnimation(ctx, game, t) {
  const { day } = themeOf(game);
  if (game.tiles) {
    for (let r = 0; r < game.rows; r++) {
      if (game.tileAt(0, r).kind === 'water') {
        drawWaterAnimation(ctx, game, t, day);
        break;
      }
    }
  }
  drawSteam(ctx, game, t, day);
  if (day === 1) {
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    const spots = [[1.9, 3.3], [7.4, 4.2]];
    for (let i = 0; i < spots.length; i++) {
      const [cc, rr0] = spots[i];
      const x = BOARD.x + cc * BOARD.cw + Math.sin(t * 0.8 + i) * 4;
      const y = BOARD.y + rr0 * game.cellH;
      ctx.globalAlpha = 0.10 + Math.sin(t * 1.6 + i * 2) * 0.04;
      ctx.fillStyle = 'rgba(255,200,130,0.7)';
      ctx.beginPath();
      ctx.ellipse(x, y, 22, 4, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }
}

export function drawMapForeground(ctx, game, t) {
  const { day } = themeOf(game);
  drawMist(ctx, game, t, day);
  drawAmbientMotes(ctx, game, t, day);
  drawForegroundLanterns(ctx, game, t, day);
  drawCornerProps(ctx, game, t, day);

  ctx.save();
  const bottom = ctx.createLinearGradient(0, VIEW.h - 96, 0, VIEW.h);
  bottom.addColorStop(0, 'rgba(2,4,7,0)');
  bottom.addColorStop(1, day === 3 ? 'rgba(1,6,8,0.66)' : 'rgba(2,4,7,0.58)');
  ctx.fillStyle = bottom;
  ctx.fillRect(0, VIEW.h - 96, VIEW.w, 96);
  const l = ctx.createLinearGradient(0, 0, 88, 0);
  l.addColorStop(0, 'rgba(0,0,0,0.40)');
  l.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = l;
  ctx.fillRect(0, 0, 88, VIEW.h);
  const r = ctx.createLinearGradient(VIEW.w - 88, 0, VIEW.w, 0);
  r.addColorStop(0, 'rgba(0,0,0,0)');
  r.addColorStop(1, 'rgba(0,0,0,0.36)');
  ctx.fillStyle = r;
  ctx.fillRect(VIEW.w - 88, 0, 88, VIEW.h);

  if (day === 3) {
    const cyan = ctx.createRadialGradient(640, 600, 60, 640, 600, 480);
    cyan.addColorStop(0, 'rgba(70,210,200,0.07)');
    cyan.addColorStop(1, 'rgba(20,80,90,0)');
    ctx.fillStyle = cyan;
    ctx.fillRect(160, 300, 960, 420);
  }
  ctx.restore();
}
