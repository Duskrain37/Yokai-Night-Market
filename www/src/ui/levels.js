import { LEVELS_UI, inRect, levelDayIsleRect, levelNodePoint } from '../layout.js';
import { DAYS, LEVELS } from '../content.js';
import { assets } from '../core/assets.js';

const KAI = '"Microsoft YaHei UI","Microsoft YaHei","PingFang SC",sans-serif';
const DISPLAY = '"STKaiti","KaiTi","Kaiti SC",serif';
const VIEW_W = 1280;
const VIEW_H = 720;

const ISLE_SHAPE = [
  [0.02, 0.58], [0, 0.38], [0.07, 0.18], [0.23, 0.08],
  [0.44, 0.04], [0.63, 0.08], [0.81, 0.16], [0.94, 0.32],
  [1, 0.53], [0.96, 0.72], [0.85, 0.85], [0.68, 0.93],
  [0.47, 0.97], [0.27, 0.94], [0.12, 0.86], [0.04, 0.73]
];

const DAY_LINES = {
  street: '从街口走到街尾，今夜由你点灯',
  market: '沿栈桥走到街尾，今夜由你点灯',
  water: '顺着暗河摸过去，今夜由你点灯'
};

const DAY_EN = { street: 'STREET', market: 'RIVER DOCKS', water: 'BLACK CANAL' };

const backdropCache = new Map();

function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}

function threatColor(threat) {
  if (threat >= 4.2) return '#d9684a';
  if (threat >= 2.8) return '#d88a4c';
  return '#d8b260';
}

function drawCover(ctx, img, x, y, w, h) {
  if (!img) return;
  const s = Math.max(w / img.width, h / img.height);
  const dw = img.width * s;
  const dh = img.height * s;
  ctx.drawImage(img, x + (w - dw) / 2, y + (h - dh) / 2, dw, dh);
}

function drawSpaced(ctx, text, x, y, spacing, align = 'center') {
  const chars = [...text];
  const widths = chars.map((ch) => ctx.measureText(ch).width);
  const total = widths.reduce((sum, w) => sum + w, 0) + spacing * Math.max(0, chars.length - 1);
  let cx = align === 'center' ? x - total / 2 : align === 'right' ? x - total : x;
  const oldAlign = ctx.textAlign;
  const oldBaseline = ctx.textBaseline;
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  for (let i = 0; i < chars.length; i++) {
    ctx.fillText(chars[i], cx, y);
    cx += widths[i] + spacing;
  }
  ctx.textAlign = oldAlign;
  ctx.textBaseline = oldBaseline;
  return total;
}

function islandPath(ctx, x, y, w, h) {
  const pts = ISLE_SHAPE.map(([px, py]) => [x + w * px, y + h * py]);
  ctx.beginPath();
  const last = pts[pts.length - 1];
  const first = pts[0];
  ctx.moveTo((last[0] + first[0]) / 2, (last[1] + first[1]) / 2);
  for (let i = 0; i < pts.length; i++) {
    const cur = pts[i];
    const next = pts[(i + 1) % pts.length];
    ctx.quadraticCurveTo(cur[0], cur[1], (cur[0] + next[0]) / 2, (cur[1] + next[1]) / 2);
  }
  ctx.closePath();
}

function routePath(ctx, pts) {
  if (!pts.length) return;
  ctx.beginPath();
  ctx.moveTo(pts[0].x, pts[0].y);
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[i - 1] || pts[i];
    const p1 = pts[i];
    const p2 = pts[i + 1];
    const p3 = pts[i + 2] || p2;
    const cp1x = p1.x + (p2.x - p0.x) / 6;
    const cp1y = p1.y + (p2.y - p0.y) / 6;
    const cp2x = p2.x - (p3.x - p1.x) / 6;
    const cp2y = p2.y - (p3.y - p1.y) / 6;
    ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
  }
}

function drawBackdrop(ctx, day) {
  const scale = Math.max(1, Math.min(3, ctx.getTransform().a || 1));
  const key = `${day}:${scale.toFixed(3)}`;
  let canvas = backdropCache.get(key);
  if (!canvas) {
    canvas = document.createElement('canvas');
    canvas.width = Math.ceil(VIEW_W * scale);
    canvas.height = Math.ceil(VIEW_H * scale);
    const g = canvas.getContext('2d');
    g.scale(scale, scale);
    const bg = assets.backgrounds[`day${day}`] || assets.backgrounds.menu;
    g.fillStyle = '#04080c';
    g.fillRect(0, 0, VIEW_W, VIEW_H);
    drawCover(g, bg, 0, 0, VIEW_W, VIEW_H);

    const shade = g.createLinearGradient(0, 0, 0, VIEW_H);
    shade.addColorStop(0, 'rgba(3,8,13,0.76)');
    shade.addColorStop(0.34, 'rgba(3,8,13,0.58)');
    shade.addColorStop(0.7, 'rgba(3,8,13,0.7)');
    shade.addColorStop(1, 'rgba(2,5,9,0.94)');
    g.fillStyle = shade;
    g.fillRect(0, 0, VIEW_W, VIEW_H);

    const vignette = g.createRadialGradient(640, 360, 240, 640, 360, 840);
    vignette.addColorStop(0, 'rgba(0,0,0,0)');
    vignette.addColorStop(0.62, 'rgba(1,3,7,0.16)');
    vignette.addColorStop(1, 'rgba(1,3,7,0.72)');
    g.fillStyle = vignette;
    g.fillRect(0, 0, VIEW_W, VIEW_H);

    const halo = g.createRadialGradient(608, 366, 60, 608, 366, 470);
    halo.addColorStop(0, 'rgba(255,176,96,0.16)');
    halo.addColorStop(0.5, 'rgba(255,150,70,0.05)');
    halo.addColorStop(1, 'rgba(255,150,70,0)');
    g.fillStyle = halo;
    g.fillRect(120, 110, 1040, 540);

    const mist = g.createLinearGradient(0, 520, 0, 720);
    mist.addColorStop(0, 'rgba(76,140,146,0)');
    mist.addColorStop(1, 'rgba(76,140,146,0.13)');
    g.fillStyle = mist;
    g.fillRect(0, 500, VIEW_W, 220);

    backdropCache.set(key, canvas);
  }
  ctx.drawImage(canvas, 0, 0, VIEW_W, VIEW_H);
}

function drawBackButton(ctx, b, hover) {
  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.45)';
  ctx.shadowBlur = 10;
  ctx.shadowOffsetY = 4;
  const g = ctx.createLinearGradient(0, b.y, 0, b.y + b.h);
  g.addColorStop(0, 'rgba(28,35,46,0.9)');
  g.addColorStop(1, 'rgba(8,12,18,0.92)');
  ctx.fillStyle = g;
  rr(ctx, b.x, b.y, b.w, b.h, 5);
  ctx.fill();
  ctx.restore();
  ctx.strokeStyle = hover ? 'rgba(244,206,126,0.8)' : 'rgba(228,191,120,0.38)';
  ctx.lineWidth = hover ? 1.6 : 1;
  rr(ctx, b.x, b.y, b.w, b.h, 5);
  ctx.stroke();
  ctx.fillStyle = '#cba86b';
  ctx.font = `400 19px ${KAI}`;
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillText('‹', b.x + 13, b.y + b.h / 2 - 1);
  ctx.fillStyle = '#e8d4ac';
  ctx.font = `400 15px ${DISPLAY}`;
  drawSpaced(ctx, '回封面', b.x + 31, b.y + b.h / 2, 1.8, 'left');
}

function drawIslandRim(ctx, x, y, w, h) {
  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.72)';
  ctx.shadowBlur = 34;
  ctx.shadowOffsetY = 18;
  const g = ctx.createLinearGradient(0, y - h * 0.08, 0, y + h * 1.06);
  g.addColorStop(0, '#445449');
  g.addColorStop(0.24, '#2c3730');
  g.addColorStop(0.52, '#1b2420');
  g.addColorStop(1, '#0b0f0d');
  ctx.fillStyle = g;
  islandPath(ctx, x - 9, y - 7, w + 18, h + 16);
  ctx.fill();
  ctx.restore();
  ctx.strokeStyle = 'rgba(126,166,132,0.3)';
  ctx.lineWidth = 1.4;
  islandPath(ctx, x - 9, y - 7, w + 18, h + 16);
  ctx.stroke();
}

function drawIslandLabel(ctx, dayInfo, map) {
  const w = 300;
  const h = 48;
  const x = 608 - w / 2;
  const y = 140;
  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.6)';
  ctx.shadowBlur = 18;
  ctx.shadowOffsetY = 7;
  const g = ctx.createLinearGradient(0, y, 0, y + h);
  g.addColorStop(0, '#40251a');
  g.addColorStop(1, '#1a0e09');
  ctx.fillStyle = g;
  rr(ctx, x, y, w, h, 4);
  ctx.fill();
  ctx.restore();
  ctx.strokeStyle = 'rgba(228,191,120,0.62)';
  ctx.lineWidth = 1;
  rr(ctx, x, y, w, h, 4);
  ctx.stroke();
  ctx.fillStyle = '#f5e2b7';
  ctx.font = `400 19px ${DISPLAY}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  drawSpaced(ctx, `${dayInfo.name} · ${dayInfo.sub}`, x + w / 2, y + 17, 3, 'center');
  ctx.fillStyle = 'rgba(235,212,168,0.45)';
  ctx.font = `400 8.5px ${KAI}`;
  drawSpaced(ctx, `5 NIGHTS · ${DAY_EN[map]}`, x + w / 2, y + 34, 1.6, 'center');
}

function drawIsland(ctx, day, t) {
  const isle = LEVELS_UI.island;
  const img = assets.backgrounds[`day${day}`];
  const pulse = 0.5 + Math.sin(t * 2.1) * 0.5;

  ctx.save();
  ctx.shadowColor = `rgba(255,176,96,${0.12 + pulse * 0.08})`;
  ctx.shadowBlur = 46;
  islandPath(ctx, isle.x - 4, isle.y - 4, isle.w + 8, isle.h + 8);
  ctx.fillStyle = 'rgba(255,180,100,0.05)';
  ctx.fill();
  ctx.restore();

  drawIslandRim(ctx, isle.x, isle.y, isle.w, isle.h);

  ctx.save();
  islandPath(ctx, isle.x, isle.y, isle.w, isle.h);
  ctx.clip();
  drawCover(ctx, img, isle.x, isle.y, isle.w, isle.h);
  const shade = ctx.createLinearGradient(0, isle.y, 0, isle.y + isle.h);
  shade.addColorStop(0, 'rgba(4,10,9,0.08)');
  shade.addColorStop(0.5, 'rgba(3,8,9,0.2)');
  shade.addColorStop(0.82, 'rgba(2,6,8,0.46)');
  shade.addColorStop(1, 'rgba(1,4,6,0.7)');
  ctx.fillStyle = shade;
  ctx.fillRect(isle.x, isle.y, isle.w, isle.h);
  const warm = ctx.createRadialGradient(isle.x + isle.w * 0.5, isle.y + isle.h * 0.44, 30, isle.x + isle.w * 0.5, isle.y + isle.h * 0.44, isle.w * 0.48);
  warm.addColorStop(0, 'rgba(255,182,104,0.06)');
  warm.addColorStop(1, 'rgba(255,182,104,0)');
  ctx.fillStyle = warm;
  ctx.fillRect(isle.x, isle.y, isle.w, isle.h);
  ctx.restore();

  ctx.strokeStyle = 'rgba(228,191,120,0.26)';
  ctx.lineWidth = 1.2;
  islandPath(ctx, isle.x, isle.y, isle.w, isle.h);
  ctx.stroke();

  const pts = LEVELS_UI.route.map((_, i) => levelNodePoint(i));
  routePath(ctx, pts);
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.strokeStyle = 'rgba(26,18,11,0.56)';
  ctx.lineWidth = 8;
  ctx.stroke();
  ctx.strokeStyle = 'rgba(255,202,124,0.1)';
  ctx.lineWidth = 4;
  ctx.stroke();
  ctx.setLineDash([7, 9]);
  ctx.lineDashOffset = -t * 14;
  ctx.strokeStyle = 'rgba(246,218,164,0.6)';
  ctx.lineWidth = 1.8;
  ctx.stroke();
  ctx.setLineDash([]);

  drawIslandLabel(ctx, DAYS[day - 1], DAYS[day - 1].map);
}

function drawLantern(ctx, x, y, size, state, hover, t, number) {
  const w = size * 0.84;
  const h = size;
  const selected = state === 'selected';
  const cleared = state === 'cleared';
  ctx.save();
  ctx.translate(x, y);
  if (selected) {
    const ring = 0.5 + Math.sin(t * 3.2) * 0.5;
    ctx.strokeStyle = `rgba(255,196,112,${0.16 + ring * 0.16})`;
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.arc(0, 0, size * 0.9, 0, Math.PI * 2);
    ctx.stroke();
  }
  if (hover && !selected) ctx.scale(1.08, 1.08);

  ctx.shadowColor = selected
    ? 'rgba(255,150,70,0.85)'
    : cleared
      ? 'rgba(120,210,176,0.34)'
      : 'rgba(0,0,0,0.5)';
  ctx.shadowBlur = selected ? 24 : hover ? 15 : 8;
  ctx.shadowOffsetY = 4;

  ctx.fillStyle = '#b88744';
  ctx.beginPath();
  ctx.moveTo(-w * 0.14, h * 0.44);
  ctx.lineTo(w * 0.14, h * 0.44);
  ctx.lineTo(w * 0.2, h * 0.66);
  ctx.lineTo(w * 0.07, h * 0.58);
  ctx.lineTo(0, h * 0.72);
  ctx.lineTo(-w * 0.07, h * 0.58);
  ctx.lineTo(-w * 0.2, h * 0.66);
  ctx.closePath();
  ctx.fill();

  const body = ctx.createRadialGradient(-w * 0.18, -h * 0.2, 1, 0, 0, w * 0.82);
  if (selected) {
    body.addColorStop(0, '#ffe6ae');
    body.addColorStop(0.34, '#ef7a45');
    body.addColorStop(0.7, '#b52e22');
    body.addColorStop(1, '#701811');
  } else if (cleared) {
    body.addColorStop(0, '#d6f0dc');
    body.addColorStop(0.38, '#7aa88e');
    body.addColorStop(0.72, '#3b6c5c');
    body.addColorStop(1, '#1e3b34');
  } else {
    body.addColorStop(0, '#e7b284');
    body.addColorStop(0.4, '#a8573a');
    body.addColorStop(0.78, '#742b22');
    body.addColorStop(1, '#421510');
  }
  ctx.fillStyle = body;
  ctx.beginPath();
  ctx.ellipse(0, 0, w / 2, h / 2, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.shadowColor = 'transparent';
  ctx.strokeStyle = selected ? '#ffdda0' : cleared ? '#c9e4c9' : 'rgba(255,221,160,0.55)';
  ctx.lineWidth = selected ? 1.6 : 1;
  ctx.beginPath();
  ctx.ellipse(0, 0, w / 2, h / 2, 0, 0, Math.PI * 2);
  ctx.stroke();

  ctx.strokeStyle = 'rgba(58,18,10,0.26)';
  ctx.lineWidth = 0.9;
  for (const k of [-0.28, 0.28]) {
    ctx.beginPath();
    ctx.moveTo(0, -h * 0.46);
    ctx.quadraticCurveTo(k * w, 0, 0, h * 0.46);
    ctx.stroke();
  }

  const cap = ctx.createLinearGradient(0, -h * 0.6, 0, -h * 0.44);
  cap.addColorStop(0, '#e2bd78');
  cap.addColorStop(1, '#8a5b2b');
  ctx.fillStyle = cap;
  rr(ctx, -w * 0.18, -h * 0.6, w * 0.36, h * 0.13, 2);
  ctx.fill();

  ctx.fillStyle = cleared ? '#17332c' : '#3a0f08';
  ctx.font = `700 ${Math.round(size * 0.42)}px ${DISPLAY}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(String(number), 0, 1);

  if (cleared) {
    ctx.beginPath();
    ctx.arc(w * 0.37, -h * 0.38, 7.5, 0, Math.PI * 2);
    ctx.fillStyle = '#254a3e';
    ctx.fill();
    ctx.strokeStyle = '#b6d6be';
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.fillStyle = '#e6f4e4';
    ctx.font = `700 8px ${KAI}`;
    ctx.fillText('✓', w * 0.37, -h * 0.38 + 0.5);
  }
  ctx.restore();
}

function drawDayIsle(ctx, i, active, cleared, hover) {
  const b = levelDayIsleRect(i);
  const dayInfo = DAYS[i];
  const img = assets.backgrounds[`day${i + 1}`];
  ctx.save();
  ctx.shadowColor = active ? 'rgba(255,178,96,0.35)' : 'rgba(0,0,0,0.55)';
  ctx.shadowBlur = active ? 22 : 12;
  ctx.shadowOffsetY = 7;
  islandPath(ctx, b.x - 2, b.y - 2, b.w + 4, b.h + 4);
  const rim = ctx.createLinearGradient(0, b.y, 0, b.y + b.h);
  rim.addColorStop(0, active ? 'rgba(120,132,108,0.72)' : 'rgba(66,76,66,0.7)');
  rim.addColorStop(1, 'rgba(12,17,15,0.9)');
  ctx.fillStyle = rim;
  ctx.fill();
  ctx.restore();

  ctx.save();
  islandPath(ctx, b.x, b.y, b.w, b.h);
  ctx.clip();
  drawCover(ctx, img, b.x, b.y, b.w, b.h);
  ctx.fillStyle = active ? 'rgba(3,8,10,0.22)' : 'rgba(3,8,10,0.52)';
  ctx.fillRect(b.x, b.y, b.w, b.h);
  const shade = ctx.createLinearGradient(0, b.y + 18, 0, b.y + b.h);
  shade.addColorStop(0, 'rgba(2,6,8,0)');
  shade.addColorStop(1, 'rgba(2,6,8,0.84)');
  ctx.fillStyle = shade;
  ctx.fillRect(b.x, b.y, b.w, b.h);
  if (hover && !active) {
    ctx.fillStyle = 'rgba(255,214,150,0.08)';
    ctx.fillRect(b.x, b.y, b.w, b.h);
  }
  ctx.restore();

  ctx.strokeStyle = active ? 'rgba(255,214,142,0.9)' : 'rgba(228,191,120,0.28)';
  ctx.lineWidth = active ? 1.8 : 1;
  islandPath(ctx, b.x, b.y, b.w, b.h);
  ctx.stroke();
  if (active) {
    ctx.strokeStyle = 'rgba(255,214,142,0.22)';
    ctx.lineWidth = 4;
    islandPath(ctx, b.x - 3, b.y - 3, b.w + 6, b.h + 6);
    ctx.stroke();
  }

  ctx.fillStyle = active ? '#f8e7c3' : 'rgba(238,220,186,0.72)';
  ctx.font = `400 18px ${DISPLAY}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  drawSpaced(ctx, dayInfo.name, b.x + b.w / 2, b.y + 30, 3, 'center');
  ctx.fillStyle = active ? 'rgba(238,220,186,0.68)' : 'rgba(238,220,186,0.42)';
  ctx.font = `400 9px ${KAI}`;
  ctx.fillText(`${dayInfo.sub} · ${cleared}/5`, b.x + b.w / 2, b.y + 49);

  const dotY = b.y + b.h - 12;
  for (let k = 0; k < 5; k++) {
    const dotX = b.x + b.w / 2 + (k - 2) * 11;
    ctx.beginPath();
    ctx.arc(dotX, dotY, 2.6, 0, Math.PI * 2);
    ctx.fillStyle = k < cleared ? '#e9bd6c' : 'rgba(228,191,120,0.2)';
    ctx.fill();
    ctx.strokeStyle = k < cleared ? 'rgba(255,220,160,0.5)' : 'rgba(228,191,120,0.35)';
    ctx.lineWidth = 0.8;
    ctx.stroke();
  }
}

function bandLabel(band) {
  if (band === 'early') return '低/中阶';
  if (band === 'mid') return '中/高阶';
  return '低/中/高阶';
}

function levelRule(level) {
  if (level.map === 'market') return '右 4 列障碍';
  if (level.map === 'water') return '暗河水面';
  return '夜市街';
}

function drawDetailCard(ctx, level, cleared) {
  const c = LEVELS_UI.card;
  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.6)';
  ctx.shadowBlur = 26;
  ctx.shadowOffsetY = 10;
  const g = ctx.createLinearGradient(0, c.y, 0, c.y + c.h);
  g.addColorStop(0, 'rgba(26,36,48,0.95)');
  g.addColorStop(1, 'rgba(8,13,20,0.97)');
  ctx.fillStyle = g;
  rr(ctx, c.x, c.y, c.w, c.h, 4);
  ctx.fill();
  ctx.restore();
  ctx.strokeStyle = 'rgba(228,191,120,0.55)';
  ctx.lineWidth = 1;
  rr(ctx, c.x, c.y, c.w, c.h, 4);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(255,240,200,0.08)';
  rr(ctx, c.x + 6, c.y + 6, c.w - 12, c.h - 12, 2);
  ctx.stroke();

  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#ffedc8';
  ctx.font = `400 18px ${DISPLAY}`;
  drawSpaced(ctx, `${level.name} · ${level.tag}`, c.x + 15, c.y + 24, 2, 'left');
  ctx.textAlign = 'right';
  ctx.fillStyle = threatColor(level.threat);
  ctx.font = `400 13px ${DISPLAY}`;
  ctx.fillText(`${level.threat.toFixed(1)}×`, c.x + c.w - 15, c.y + 24);

  ctx.textAlign = 'left';
  ctx.fillStyle = 'rgba(235,218,184,0.48)';
  ctx.font = `400 9.5px ${KAI}`;
  ctx.fillText(`${level.dayName} · ${level.daySub}`, c.x + 15, c.y + 43);
  if (cleared) {
    ctx.textAlign = 'right';
    ctx.fillStyle = 'rgba(154,206,172,0.72)';
    ctx.fillText('已过', c.x + c.w - 15, c.y + 43);
    ctx.textAlign = 'left';
  }

  ctx.strokeStyle = 'rgba(228,191,120,0.28)';
  ctx.beginPath();
  ctx.moveTo(c.x + 15, c.y + 55);
  ctx.lineTo(c.x + c.w - 15, c.y + 55);
  ctx.stroke();

  ctx.fillStyle = 'rgba(238,222,192,0.72)';
  ctx.font = `400 10.5px ${KAI}`;
  ctx.fillText(`${level.rows} 行 · ${levelRule(level)}`, c.x + 15, c.y + 72);
  ctx.fillText(`${level.waves.length} 波 · ${bandLabel(level.band)}`, c.x + 15, c.y + 91);
  ctx.fillText(`门神 ${level.rows} 尊 · 起始香火 ${level.startSun}`, c.x + 15, c.y + 110);

  ctx.fillStyle = 'rgba(235,218,184,0.3)';
  ctx.font = `400 9px ${KAI}`;
  ctx.fillText(`夜 ${String(level.id).padStart(2, '0')} / 15`, c.x + 15, c.y + c.h - 15);
  ctx.textAlign = 'right';
  ctx.fillStyle = 'rgba(235,218,184,0.24)';
  ctx.fillText('点击灯笼选夜', c.x + c.w - 15, c.y + c.h - 15);
}

function drawInfoStrip(ctx, level, cleared, hoverEnter) {
  const s = LEVELS_UI.info;
  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.55)';
  ctx.shadowBlur = 18;
  ctx.shadowOffsetY = 8;
  const g = ctx.createLinearGradient(0, s.y, 0, s.y + s.h);
  g.addColorStop(0, 'rgba(18,27,38,0.93)');
  g.addColorStop(1, 'rgba(7,12,19,0.96)');
  ctx.fillStyle = g;
  rr(ctx, s.x, s.y, s.w, s.h, 3);
  ctx.fill();
  ctx.restore();
  ctx.strokeStyle = 'rgba(228,191,120,0.38)';
  ctx.lineWidth = 1;
  rr(ctx, s.x, s.y, s.w, s.h, 3);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(255,240,200,0.06)';
  rr(ctx, s.x + 5, s.y + 5, s.w - 10, s.h - 10, 2);
  ctx.stroke();

  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#f6e4bd';
  ctx.font = `400 21px ${DISPLAY}`;
  drawSpaced(ctx, `${level.dayName} · ${level.name} · ${level.tag}`, s.x + 20, s.y + 25, 1.6, 'left');
  ctx.fillStyle = 'rgba(236,219,186,0.58)';
  ctx.font = `400 10.5px ${KAI}`;
  ctx.fillText(`综合 ${level.threat.toFixed(1)}× · ${level.rows} 行 · ${level.waves.length} 波 · ${levelRule(level)}`, s.x + 20, s.y + 48);
  ctx.fillStyle = cleared ? 'rgba(154,206,172,0.62)' : 'rgba(236,219,186,0.38)';
  ctx.fillText(cleared ? `已过 · 门神 ${level.rows} 尊 · 起始香火 ${level.startSun}` : `未开 · 门神 ${level.rows} 尊 · 起始香火 ${level.startSun}`, s.x + 20, s.y + 66);

  const b = LEVELS_UI.enter;
  ctx.save();
  ctx.shadowColor = hoverEnter ? 'rgba(190,70,40,0.5)' : 'rgba(90,24,16,0.4)';
  ctx.shadowBlur = hoverEnter ? 18 : 10;
  ctx.shadowOffsetY = 4;
  const bg = ctx.createLinearGradient(0, b.y, 0, b.y + b.h);
  bg.addColorStop(0, hoverEnter ? '#c14a34' : '#a63a2b');
  bg.addColorStop(1, hoverEnter ? '#84291f' : '#5e1b15');
  ctx.fillStyle = bg;
  rr(ctx, b.x, b.y, b.w, b.h, 6);
  ctx.fill();
  ctx.restore();
  ctx.strokeStyle = hoverEnter ? '#f0d39a' : 'rgba(228,191,120,0.55)';
  ctx.lineWidth = 1.2;
  rr(ctx, b.x, b.y, b.w, b.h, 6);
  ctx.stroke();
  ctx.fillStyle = '#ffe8bd';
  ctx.font = `400 17px ${DISPLAY}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  drawSpaced(ctx, '进入备战', b.x + b.w / 2, b.y + b.h / 2, 2, 'center');
}

export function drawLevels(ctx, game, t = 0) {
  const day = game.levelDay || Math.ceil((game.selectedLevel || 1) / 5);
  const dayInfo = DAYS[day - 1] || DAYS[0];
  drawBackdrop(ctx, day);

  const dayLevels = LEVELS.slice((day - 1) * 5, day * 5);
  const selected = dayLevels.find((level) => level.id === game.selectedLevel) || dayLevels[0];
  const clearedCount = game.progress.cleared.length;
  const mouse = game.mouse;

  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.save();
  ctx.shadowColor = 'rgba(255,190,100,0.28)';
  ctx.shadowBlur = 24;
  ctx.fillStyle = '#f2dfb5';
  ctx.font = `700 38px ${DISPLAY}`;
  drawSpaced(ctx, `${dayInfo.name} · 十五夜`, 640, 66, 7, 'center');
  ctx.restore();
  ctx.fillStyle = 'rgba(236,219,186,0.48)';
  ctx.font = `400 10.5px ${KAI}`;
  drawSpaced(ctx, DAY_LINES[dayInfo.map] || DAY_LINES.market, 640, 95, 2.2, 'center');

  drawBackButton(ctx, LEVELS_UI.back, inRect(mouse.x, mouse.y, LEVELS_UI.back));
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = 'rgba(235,218,184,0.55)';
  ctx.font = `400 10.5px ${KAI}`;
  ctx.fillText(`已过 ${clearedCount} / ${LEVELS.length} 夜`, 54, 109);
  ctx.fillStyle = 'rgba(235,218,184,0.35)';
  ctx.fillText('点灯笼选夜 · 小岛切日', 54, 127);

  drawIsland(ctx, day, t);

  const points = LEVELS_UI.route.map((_, i) => levelNodePoint(i));
  for (let i = 0; i < dayLevels.length; i++) {
    const level = dayLevels[i];
    const isSelected = level.id === selected.id;
    const cleared = game.progress.cleared.includes(level.id);
    const hover = inRect(mouse.x, mouse.y, {
      x: points[i].x - 27,
      y: points[i].y - 30,
      w: 54,
      h: 60
    });
    drawLantern(
      ctx, points[i].x, points[i].y,
      isSelected ? 46 : 32,
      isSelected ? 'selected' : cleared ? 'cleared' : 'open',
      hover, t, i + 1
    );
  }

  for (let i = 0; i < 3; i++) {
    let cleared = 0;
    for (let k = 0; k < 5; k++) {
      const level = LEVELS[i * 5 + k];
      if (level && game.progress.cleared.includes(level.id)) cleared += 1;
    }
    drawDayIsle(ctx, i, day === i + 1, cleared, inRect(mouse.x, mouse.y, levelDayIsleRect(i)));
  }

  drawDetailCard(ctx, selected, game.progress.cleared.includes(selected.id));
  drawInfoStrip(
    ctx, selected,
    game.progress.cleared.includes(selected.id),
    inRect(mouse.x, mouse.y, LEVELS_UI.enter)
  );

  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = 'rgba(235,218,184,0.34)';
  ctx.font = `400 10.5px ${KAI}`;
  drawSpaced(ctx, '点右侧小岛切日 · 点灯笼选夜 · 进入备战', 600, LEVELS_UI.legendY, 1.2, 'left');
}
