import {
  BOARD, BTN, PREP, PREP_CINEMA, SETTINGS, TUTORIAL_UI, VIEW, cardRect, cellCenter, inRect,
  prepRosterRect, prepSlotRect, prepZombieRect,
  settingsPill, settingsRowEnabled
} from '../layout.js';
import { getLevel, PLANT_ORDER, PLANT_TYPES, ZOMBIE_TYPES, ZOMBIE_TIERS, zombieTierLabel } from '../content.js';
import { drawPlant, drawZombie } from '../render/art.js';
import { getFan, pathStatus, petalAt } from '../game/upgrade.js';
import { drawAlmanac } from './almanac.js';
import { drawLevels } from './levels.js';
import { assets } from '../core/assets.js';

const KAI = '"Microsoft YaHei UI","Microsoft YaHei","PingFang SC",sans-serif';
const DISPLAY = '"STKaiti","KaiTi","Kaiti SC",serif';

function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}

function clamp01(v) {
  return Math.max(0, Math.min(1, v));
}

function fmt(sec) {
  const s = Math.max(0, Math.floor(sec));
  return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
}

function speedLabel(v) {
  return v === 1 ? '1x' : v + 'x';
}

function difficultyLabel(v) {
  if (v === 'normal') return '普通';
  if (v === 'hard') return '困难';
  return '简单';
}

export function drawUI(ctx, game, t) {
  if (game.phase === 'menu') {
    drawMenu(ctx, game, t);
    if (game.overlay === 'settings') drawSettings(ctx, game);
    if (game.overlay === 'levels') drawLevels(ctx, game);
    if (game.overlay === 'prep') drawPrep(ctx, game, t);
    if (game.overlay === 'almanac') drawAlmanac(ctx, game);
    return;
  }

  drawHudCached(ctx, game, t);
  if (game.phase === 'playing' && game.menu) drawFan(ctx, game);
  if (game.tutorial && game.phase === 'playing') drawTutorial(ctx, game, t);
  if (game.phase === 'paused' || game.phase === 'won' || game.phase === 'lost') {
    drawOverlay(ctx, game);
  }
  if (game.overlay === 'settings') drawSettings(ctx, game);
  if (game.overlay === 'cheat') drawCheatPanel(ctx, game);
  if (game.overlay === 'almanac') drawAlmanac(ctx, game);
}

let hudCache = null;

function drawHudCached(ctx, game, t) {
  const scale = Math.max(1, Math.min(3, ctx.getTransform().a || 1));
  const key = scale.toFixed(3);
  if (!hudCache || hudCache.key !== key) {
    const canvas = document.createElement('canvas');
    canvas.width = Math.ceil(1280 * scale);
    canvas.height = Math.ceil(200 * scale);
    hudCache = { key, canvas, ctx: canvas.getContext('2d'), last: -1 };
  }
  if (t - hudCache.last >= 0.12) {
    const g = hudCache.ctx;
    g.setTransform(1, 0, 0, 1, 0, 0);
    g.clearRect(0, 0, hudCache.canvas.width, hudCache.canvas.height);
    g.scale(scale, scale);
    g.translate(0, -20);
    drawHud(g, game, t);
    hudCache.last = t;
  }
  ctx.drawImage(hudCache.canvas, 0, 20, 1280, 200);
}

function drawHud(ctx, game, t) {
  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.42)';
  ctx.shadowBlur = 24;
  ctx.shadowOffsetY = 8;
  const panel = ctx.createLinearGradient(0, 30, 0, 174);
  panel.addColorStop(0, 'rgba(10,15,28,0.93)');
  panel.addColorStop(0.55, 'rgba(14,18,30,0.92)');
  panel.addColorStop(1, 'rgba(24,17,27,0.94)');
  ctx.fillStyle = panel;
  rr(ctx, 40, 30, 1200, 144, 20);
  ctx.fill();
  ctx.restore();

  ctx.strokeStyle = 'rgba(221,180,104,0.55)';
  ctx.lineWidth = 1.4;
  rr(ctx, 40, 30, 1200, 144, 20);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(255,235,190,0.08)';
  ctx.lineWidth = 1;
  rr(ctx, 46, 36, 1188, 132, 16);
  ctx.stroke();
  const topLight = ctx.createLinearGradient(60, 0, 1220, 0);
  topLight.addColorStop(0, 'rgba(255,214,140,0)');
  topLight.addColorStop(0.5, 'rgba(255,214,140,0.35)');
  topLight.addColorStop(1, 'rgba(255,214,140,0)');
  ctx.fillStyle = topLight;
  ctx.fillRect(60, 31, 1160, 1.2);

  ctx.fillStyle = 'rgba(0,0,0,0.16)';
  rr(ctx, 52, 48, 154, 108, 14);
  ctx.fill();
  ctx.strokeStyle = 'rgba(226,192,122,0.14)';
  ctx.lineWidth = 1;
  ctx.stroke();

  ctx.textAlign = 'left';
  ctx.textBaseline = 'alphabetic';
  ctx.font = `400 12px ${KAI}`;
  ctx.fillStyle = 'rgba(240,220,180,0.62)';
  ctx.fillText('香火', 68, 68);

  const fx = 92;
  const fy = 112;
  const glow = ctx.createRadialGradient(fx, fy, 2, fx, fy, 32);
  glow.addColorStop(0, 'rgba(255,222,150,0.46)');
  glow.addColorStop(0.5, 'rgba(255,168,74,0.22)');
  glow.addColorStop(1, 'rgba(255,130,45,0)');
  ctx.fillStyle = glow;
  ctx.beginPath();
  ctx.arc(fx, fy, 32, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = 'rgba(226,192,122,0.65)';
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.arc(fx, fy, 19, 0, Math.PI * 2);
  ctx.stroke();
  ctx.fillStyle = 'rgba(30,18,16,0.85)';
  ctx.beginPath();
  ctx.arc(fx, fy, 18, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#cf4230';
  ctx.beginPath();
  ctx.ellipse(fx, fy + 1, 8.5, 10.5, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#e7ba5f';
  ctx.fillRect(fx - 5, fy - 10, 10, 3);
  ctx.fillRect(fx - 5, fy + 9, 10, 3);
  ctx.fillStyle = '#2a1812';
  ctx.beginPath();
  ctx.arc(fx - 3, fy, 1.1, 0, Math.PI * 2);
  ctx.arc(fx + 3, fy, 1.1, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#f8e8c2';
  ctx.font = `700 30px ${KAI}`;
  ctx.fillText(String(game.sun), 122, 124);

  drawCards(ctx, game, t);
  drawProgress(ctx, game);
  drawPauseButton(ctx, game);

  if (game.phase === 'playing' && !game.tutorial) {
    drawShovelButton(ctx, game);
    if (game.settings.quickWave) drawQuickWaveButton(ctx, game);
    if (game.runCheats) drawCheatButton(ctx, game);
  }

  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = 'rgba(6,9,16,0.42)';
  rr(ctx, 390, 670, 500, 25, 12);
  ctx.fill();
  ctx.strokeStyle = 'rgba(226,192,122,0.10)';
  ctx.lineWidth = 1;
  ctx.stroke();
  ctx.font = `400 13px ${KAI}`;
  ctx.fillStyle = 'rgba(236,220,186,0.55)';
  ctx.fillText('点香火 · 选牌子 · 点空地放下 · 点单位升阶 · 铲子移除 · P 暂停', 640, 683);

  drawBanner(ctx, game);
}

function drawCards(ctx, game, t) {
  for (let i = 0; i < game.cards.length; i++) {
    const card = game.cards[i];
    const def = card.def;
    const r = cardRect(i, game.cards.length);
    const tight = r.w < 56;
    const cx = r.x + r.w / 2;
    const selected = game.selected === i;
    const hover = !selected && inRect(game.mouse.x, game.mouse.y, r);
    const y = r.y + (selected ? -6 : hover ? -2 : 0);
    const afford = game.sun >= def.cost;
    const ready = card.cd <= 0;

    ctx.save();
    ctx.shadowColor = selected ? 'rgba(244,198,112,0.55)' : 'rgba(0,0,0,0.38)';
    ctx.shadowBlur = selected ? 18 : 10;
    ctx.shadowOffsetY = 5;
    const fill = ctx.createLinearGradient(0, y, 0, y + r.h);
    fill.addColorStop(0, selected ? '#fbf2dc' : '#f2e5c9');
    fill.addColorStop(1, selected ? '#ecd6a9' : '#ddc69d');
    ctx.fillStyle = fill;
    rr(ctx, r.x, y, r.w, r.h, 10);
    ctx.fill();
    ctx.restore();

    ctx.strokeStyle = selected ? '#f4cd79' : 'rgba(124,87,47,0.72)';
    ctx.lineWidth = selected ? 2.4 : 1.4;
    rr(ctx, r.x, y, r.w, r.h, 10);
    ctx.stroke();

    ctx.save();
    rr(ctx, r.x, y, r.w, r.h, 10);
    ctx.clip();
    ctx.fillStyle = def.tint;
    ctx.globalAlpha = 0.9;
    ctx.fillRect(r.x, y, r.w, 5);
    ctx.globalAlpha = 1;
    const sheen = ctx.createLinearGradient(r.x, y, r.x + r.w, y + r.h);
    sheen.addColorStop(0, 'rgba(255,255,255,0.22)');
    sheen.addColorStop(0.45, 'rgba(255,255,255,0)');
    ctx.fillStyle = sheen;
    ctx.fillRect(r.x + 1, y + 1, r.w - 2, r.h - 2);
    ctx.restore();

    const glow = ctx.createRadialGradient(cx, y + 47, 3, cx, y + 47, 28);
    glow.addColorStop(0, def.tint + '38');
    glow.addColorStop(1, def.tint + '00');
    ctx.fillStyle = glow;
    ctx.beginPath();
    ctx.arc(cx, y + 47, 28, 0, Math.PI * 2);
    ctx.fill();

    drawPlant(ctx, def.id, cx, y + 49, t, { scale: tight ? 0.5 : 0.55, noShadow: true });

    ctx.fillStyle = 'rgba(36,24,16,0.9)';
    rr(ctx, r.x + 5, y + 5, 40, 17, 8);
    ctx.fill();
    ctx.strokeStyle = 'rgba(232,205,148,0.15)';
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.fillStyle = afford ? '#ffd98a' : '#ff8c78';
    ctx.beginPath();
    ctx.arc(r.x + 12, y + 13.5, 3.1, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = afford ? '#f7e7c6' : '#ff9e8e';
    ctx.font = `700 11.5px ${KAI}`;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.fillText(String(def.cost), r.x + 19, y + 14);

    ctx.textAlign = 'center';
    ctx.fillStyle = '#3a2919';
    ctx.font = `700 11.5px ${KAI}`;
    ctx.fillText(def.name, cx, y + 84);

    ctx.fillStyle = def.tint;
    ctx.globalAlpha = 0.45;
    ctx.fillRect(cx - 10, y + 90, 20, 1.5);
    ctx.globalAlpha = 1;

    if (!ready) {
      const ratio = clamp01(card.cd / def.cooldown);
      ctx.save();
      rr(ctx, r.x, y, r.w, r.h, 10);
      ctx.clip();
      ctx.fillStyle = 'rgba(8,12,22,0.74)';
      ctx.fillRect(r.x, y, r.w, r.h * ratio);
      ctx.restore();
      ctx.fillStyle = '#f8e9c8';
      ctx.font = `700 16px ${KAI}`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(Math.ceil(card.cd) + '秒', cx, y + 46);
    } else if (!afford) {
      ctx.save();
      rr(ctx, r.x, y, r.w, r.h, 10);
      ctx.clip();
      ctx.fillStyle = 'rgba(24,12,10,0.34)';
      ctx.fillRect(r.x, y, r.w, r.h);
      ctx.restore();
    }
  }
}

function drawProgress(ctx, game) {
  const pr = { x: 816, y: 80, w: 248, h: 18 };
  if (game.tutorial) {
    const idx = { collect: 0, plant: 1, upgrade: 2, battle: 2, finishing: 2, done: 3 }[game.tutorial.step] ?? 0;
    const stepNo = Math.min(3, idx + 1);
    const ratio = [0.12, 0.4, 0.68, 0.94][Math.min(3, idx)];
    ctx.textAlign = 'left';
    ctx.textBaseline = 'alphabetic';
    ctx.font = `400 11.5px ${KAI}`;
    ctx.fillStyle = 'rgba(240,220,180,0.7)';
    ctx.fillText(`新手教程 · 第 ${stepNo} / 3 步 · ×${speedLabel(game.tutorial ? 1 : game.settings.speed)}`, pr.x, pr.y - 9);
    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,0.35)';
    ctx.shadowBlur = 8;
    ctx.fillStyle = 'rgba(7,11,20,0.72)';
    rr(ctx, pr.x, pr.y, pr.w, pr.h, 9);
    ctx.fill();
    ctx.restore();
    ctx.strokeStyle = 'rgba(226,192,122,0.28)';
    ctx.lineWidth = 1;
    ctx.stroke();
    const g = ctx.createLinearGradient(pr.x, 0, pr.x + pr.w, 0);
    g.addColorStop(0, '#c9543a');
    g.addColorStop(0.65, '#e8a24b');
    g.addColorStop(1, '#f4d88f');
    ctx.fillStyle = g;
    rr(ctx, pr.x + 2, pr.y + 2, Math.max(2, (pr.w - 4) * ratio), pr.h - 4, 7);
    ctx.fill();
    return;
  }
  const waves = game.level.waves;
  const lastT = waves[waves.length - 1].t;
  const ratio = clamp01(Math.max(game.time / lastT, game.waveIndex / game.waveTotal));

  ctx.textAlign = 'left';
  ctx.textBaseline = 'alphabetic';
  ctx.font = `400 11.5px ${KAI}`;
  ctx.fillStyle = 'rgba(240,220,180,0.7)';
  const shown = Math.max(1, Math.min(game.waveIndex, game.waveTotal));
  ctx.fillText(
    `第${game.runLevelId}关 · ${shown}/${game.waveTotal}波 · ×${speedLabel(game.settings.speed)}`,
    pr.x, pr.y - 9
  );

  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.35)';
  ctx.shadowBlur = 8;
  ctx.fillStyle = 'rgba(7,11,20,0.72)';
  rr(ctx, pr.x, pr.y, pr.w, pr.h, 9);
  ctx.fill();
  ctx.restore();
  ctx.strokeStyle = 'rgba(226,192,122,0.28)';
  ctx.lineWidth = 1;
  ctx.stroke();

  if (ratio > 0) {
    const g = ctx.createLinearGradient(pr.x, 0, pr.x + pr.w, 0);
    g.addColorStop(0, '#c9543a');
    g.addColorStop(0.65, '#e8a24b');
    g.addColorStop(1, '#f4d88f');
    ctx.fillStyle = g;
    const fw = Math.max(0, (pr.w - 4) * ratio);
    rr(ctx, pr.x + 2, pr.y + 2, fw, pr.h - 4, 7);
    ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,0.32)';
    ctx.fillRect(pr.x + 5, pr.y + 3.5, Math.max(0, fw - 6), 1.2);
    if (ratio > 0.015) {
      const dot = ctx.createRadialGradient(
        pr.x + 2 + fw, pr.y + pr.h / 2, 1,
        pr.x + 2 + fw, pr.y + pr.h / 2, 10
      );
      dot.addColorStop(0, 'rgba(255,238,190,0.75)');
      dot.addColorStop(1, 'rgba(255,220,150,0)');
      ctx.fillStyle = dot;
      ctx.beginPath();
      ctx.arc(pr.x + 2 + fw, pr.y + pr.h / 2, 10, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  for (const wave of waves) {
    if (!wave.flag) continue;
    const x = pr.x + pr.w * (wave.t / lastT);
    ctx.strokeStyle = 'rgba(240,210,150,0.55)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x, pr.y - 2);
    ctx.lineTo(x, pr.y + pr.h + 2);
    ctx.stroke();
    ctx.fillStyle = 'rgba(214,68,48,0.9)';
    ctx.beginPath();
    ctx.moveTo(x, pr.y - 12);
    ctx.lineTo(x + 9, pr.y - 8.5);
    ctx.lineTo(x, pr.y - 5);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = 'rgba(240,210,150,0.6)';
    ctx.fillRect(x - 0.6, pr.y - 12, 1.2, 12);
  }
}

function drawGlassBox(ctx, b, opts = {}) {
  const hover = !!opts.hover;
  const active = !!opts.active;
  const disabled = !!opts.disabled;
  ctx.save();
  ctx.shadowColor = hover ? 'rgba(244,200,110,0.32)' : 'rgba(0,0,0,0.35)';
  ctx.shadowBlur = hover ? 14 : 8;
  ctx.shadowOffsetY = 3;
  const g = ctx.createLinearGradient(0, b.y, 0, b.y + b.h);
  g.addColorStop(0, active ? 'rgba(154,58,44,0.96)' : 'rgba(18,25,40,0.95)');
  g.addColorStop(1, active ? 'rgba(92,30,26,0.96)' : 'rgba(10,15,26,0.95)');
  ctx.fillStyle = g;
  rr(ctx, b.x, b.y, b.w, b.h, 11);
  ctx.fill();
  ctx.restore();
  ctx.strokeStyle = disabled
    ? 'rgba(226,192,122,0.15)'
    : active || hover
      ? 'rgba(244,206,126,0.85)'
      : 'rgba(226,192,122,0.34)';
  ctx.lineWidth = active || hover ? 1.8 : 1.2;
  rr(ctx, b.x, b.y, b.w, b.h, 11);
  ctx.stroke();
  if (!disabled) {
    ctx.fillStyle = 'rgba(255,246,214,0.07)';
    ctx.fillRect(b.x + 5, b.y + 2, b.w - 10, 1);
  }
}

function drawPauseButton(ctx, game) {
  const b = BTN.pause;
  const hover = inRect(game.mouse.x, game.mouse.y, b);
  drawGlassBox(ctx, b, { hover });
  ctx.fillStyle = '#f0d7a0';
  ctx.fillRect(b.x + 19, b.y + 16, 4.5, 20);
  ctx.fillRect(b.x + 29, b.y + 16, 4.5, 20);
}

function drawShovelButton(ctx, game) {
  const b = BTN.shovel;
  const active = game.shovel;
  const hover = inRect(game.mouse.x, game.mouse.y, b);
  drawGlassBox(ctx, b, { active, hover });

  const color = active ? '#fff0c8' : '#f0d6a0';
  ctx.strokeStyle = color;
  ctx.fillStyle = color;
  ctx.lineWidth = 3;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(b.x + 32, b.y + 12);
  ctx.lineTo(b.x + 23, b.y + 28);
  ctx.stroke();
  rr(ctx, b.x + 29, b.y + 8, 9, 5, 2);
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(b.x + 15, b.y + 27);
  ctx.quadraticCurveTo(b.x + 20, b.y + 39, b.x + 30, b.y + 34);
  ctx.lineTo(b.x + 26, b.y + 27);
  ctx.closePath();
  ctx.fill();
  ctx.font = `400 9px ${KAI}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('铲', b.x + 26, b.y + 47);
}

function drawQuickWaveButton(ctx, game) {
  const b = BTN.quickWave;
  const disabled = game.waveIndex >= game.waveTotal;
  const hover = !disabled && inRect(game.mouse.x, game.mouse.y, b);
  drawGlassBox(ctx, b, { hover, disabled });

  ctx.fillStyle = disabled ? 'rgba(220,200,160,0.26)' : '#f6d98d';
  ctx.beginPath();
  ctx.moveTo(b.x + 14, b.y + 13);
  ctx.lineTo(b.x + 14, b.y + 33);
  ctx.lineTo(b.x + 25, b.y + 23);
  ctx.closePath();
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(b.x + 27, b.y + 13);
  ctx.lineTo(b.x + 27, b.y + 33);
  ctx.lineTo(b.x + 38, b.y + 23);
  ctx.closePath();
  ctx.fill();

  ctx.font = `400 9px ${KAI}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = disabled ? 'rgba(220,200,160,0.26)' : 'rgba(246,217,141,0.82)';
  ctx.fillText('下一波', b.x + 26, b.y + 46);
}

function drawCheatButton(ctx, game) {
  const b = BTN.cheat;
  const open = game.overlay === 'cheat';
  const hover = inRect(game.mouse.x, game.mouse.y, b);
  drawGlassBox(ctx, b, { active: open, hover });
  ctx.fillStyle = open ? '#ffe1bd' : '#f2b28d';
  ctx.font = `700 15px ${KAI}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('作弊', b.x + b.w / 2, b.y + b.h / 2 + 1);
}

function drawBanner(ctx, game) {
  const b = game.banner;
  if (!b) return;
  const total = b.max ?? 3.4;
  const age = total - b.t;
  const alpha = Math.min(1, age / 0.22, b.t / 0.5);
  const slide = (1 - Math.min(1, age / 0.22)) * 40;
  const w = 470;
  const h = 66;

  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.translate(640, 248 - slide);
  ctx.shadowColor = 'rgba(0,0,0,0.4)';
  ctx.shadowBlur = 18;
  const g = ctx.createLinearGradient(0, -h / 2, 0, h / 2);
  g.addColorStop(0, 'rgba(150,44,32,0.96)');
  g.addColorStop(0.55, 'rgba(112,28,24,0.96)');
  g.addColorStop(1, 'rgba(72,18,18,0.96)');
  ctx.fillStyle = g;
  rr(ctx, -w / 2, -h / 2, w, h, 10);
  ctx.fill();
  ctx.shadowBlur = 0;
  ctx.strokeStyle = 'rgba(240,200,126,0.85)';
  ctx.lineWidth = 1.8;
  ctx.stroke();
  ctx.strokeStyle = 'rgba(255,230,180,0.22)';
  ctx.lineWidth = 1;
  rr(ctx, -w / 2 + 6, -h / 2 + 6, w - 12, h - 12, 6);
  ctx.stroke();

  ctx.fillStyle = 'rgba(240,200,126,0.65)';
  ctx.fillRect(-w / 2 + 20, -h / 2 + 3, w - 40, 1);
  ctx.fillRect(-w / 2 + 20, h / 2 - 4, w - 40, 1);

  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.font = `700 27px ${DISPLAY}`;
  const textGrad = ctx.createLinearGradient(0, -14, 0, 14);
  textGrad.addColorStop(0, '#fff4d8');
  textGrad.addColorStop(1, '#f0cf8b');
  ctx.fillStyle = textGrad;
  ctx.fillText(b.text, 0, 2);
  ctx.restore();
}

let menuBackdropCache = null;

export function drawMenuBackdrop(ctx) {
  const scale = Math.max(1, Math.min(3, ctx.getTransform().a || 1));
  if (!menuBackdropCache || menuBackdropCache.scale !== scale) {
    const canvas = document.createElement('canvas');
    canvas.width = Math.ceil(VIEW.w * scale);
    canvas.height = Math.ceil(VIEW.h * scale);
    const g = canvas.getContext('2d');
    g.scale(scale, scale);
    const bg = assets.backgrounds.menu;
    if (bg) {
      const s = Math.max(VIEW.w / bg.width, VIEW.h / bg.height);
      const w = bg.width * s;
      const h = bg.height * s;
      g.drawImage(bg, (VIEW.w - w) / 2, (VIEW.h - h) / 2, w, h);
    } else {
      g.fillStyle = '#0a0d16';
      g.fillRect(0, 0, VIEW.w, VIEW.h);
    }
    const shade = g.createLinearGradient(0, 0, 0, VIEW.h);
    shade.addColorStop(0, 'rgba(5,8,16,0.52)');
    shade.addColorStop(0.34, 'rgba(6,9,18,0.28)');
    shade.addColorStop(0.72, 'rgba(5,8,16,0.48)');
    shade.addColorStop(1, 'rgba(4,6,12,0.9)');
    g.fillStyle = shade;
    g.fillRect(0, 0, VIEW.w, VIEW.h);
    const halo = g.createRadialGradient(640, 300, 60, 640, 300, 520);
    halo.addColorStop(0, 'rgba(4,6,12,0.62)');
    halo.addColorStop(0.55, 'rgba(4,6,12,0.25)');
    halo.addColorStop(1, 'rgba(4,6,12,0)');
    g.fillStyle = halo;
    g.fillRect(0, 40, VIEW.w, 600);
    const vignette = g.createRadialGradient(640, 360, 280, 640, 360, 820);
    vignette.addColorStop(0, 'rgba(0,0,0,0)');
    vignette.addColorStop(1, 'rgba(2,4,9,0.66)');
    g.fillStyle = vignette;
    g.fillRect(0, 0, VIEW.w, VIEW.h);
    menuBackdropCache = { scale, canvas };
  }
  ctx.drawImage(menuBackdropCache.canvas, 0, 0, VIEW.w, VIEW.h);
}

function drawMenu(ctx, game, t) {
  drawMenuPetals(ctx, t);

  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';

  ctx.font = `900 104px ${DISPLAY}`;
  ctx.lineWidth = 14;
  ctx.strokeStyle = 'rgba(22,12,10,0.92)';
  ctx.strokeText('妖怪夜市', 640, 236);
  const titleGrad = ctx.createLinearGradient(0, 182, 0, 292);
  titleGrad.addColorStop(0, '#fff8e6');
  titleGrad.addColorStop(0.45, '#f3dca6');
  titleGrad.addColorStop(1, '#c99743');
  ctx.fillStyle = titleGrad;
  ctx.save();
  ctx.shadowColor = 'rgba(255,190,92,0.35)';
  ctx.shadowBlur = 38;
  ctx.fillText('妖怪夜市', 640, 236);
  ctx.restore();

  ctx.save();
  ctx.translate(888, 196);
  ctx.rotate(-0.06);
  ctx.fillStyle = 'rgba(158,42,32,0.94)';
  ctx.strokeStyle = '#e7c270';
  ctx.lineWidth = 2;
  rr(ctx, -34, -34, 68, 68, 8);
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#f3dca6';
  ctx.font = `700 24px ${DISPLAY}`;
  ctx.fillText('守', 0, -12);
  ctx.fillText('夜', 0, 16);
  ctx.restore();

  ctx.strokeStyle = 'rgba(226,192,122,0.35)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(330, 318);
  ctx.lineTo(520, 318);
  ctx.moveTo(760, 318);
  ctx.lineTo(950, 318);
  ctx.stroke();

  ctx.font = `400 20px ${KAI}`;
  ctx.fillStyle = 'rgba(240,225,194,0.88)';
  ctx.fillText('子时开张 · 恶客临门 · 摊上的物件醒了', 640, 318);

  const selectedLevel = getLevel(game.selectedLevel);
  ctx.fillStyle = 'rgba(4,7,14,0.38)';
  rr(ctx, 370, 416, 540, 28, 12);
  ctx.fill();
  ctx.strokeStyle = 'rgba(226,192,122,0.12)';
  ctx.lineWidth = 1;
  ctx.stroke();
  if (game.hasSave && game.saveMeta) {
    const m = game.saveMeta;
    const waveText = m.wave > 0 ? `第 ${m.wave} / ${m.total} 波` : '尚未开波';
    ctx.font = `400 13px ${KAI}`;
    ctx.fillStyle = 'rgba(244,229,200,0.82)';
    ctx.fillText(
      `上次停在 第 ${m.levelId} 关 · ${waveText} · 香火 ${m.sun} · ${difficultyLabel(m.difficulty)}${m.cheats ? ' · 作弊' : ''}`,
      640, 430
    );
  } else if (game.menuNotice) {
    ctx.font = `400 13px ${KAI}`;
    ctx.fillStyle = 'rgba(255,157,122,0.9)';
    ctx.fillText(game.menuNotice, 640, 430);
  } else {
    ctx.font = `400 13px ${KAI}`;
    ctx.fillStyle = 'rgba(244,229,200,0.78)';
    ctx.fillText(
      `十夜自由选关 · 当前停在 ${selectedLevel.name} · 综合难度 ${selectedLevel.threat.toFixed(1)}×`,
      640, 430
    );
  }

  drawButton(ctx, BTN.start, game.hasSave ? '继续上次对局' : '开始游戏', true);
  if (game.hasSave) {
    drawButton(ctx, BTN.newRun, '新开一局', false);
    drawButton(ctx, BTN.settingsMenuWide, '设置', false);
  } else {
    drawButton(ctx, BTN.settingsMenu, '设置', false);
  }

  ctx.fillStyle = 'rgba(4,7,14,0.42)';
  rr(ctx, 382, 578, 516, 58, 14);
  ctx.fill();
  ctx.strokeStyle = 'rgba(226,192,122,0.10)';
  ctx.lineWidth = 1;
  ctx.stroke();

  ctx.font = `400 13px ${KAI}`;
  ctx.fillStyle = 'rgba(232,216,186,0.66)';
  ctx.fillText(
    `${game.hasSave ? '新局：' : ''}第 ${selectedLevel.id} 关 · 难度 ${difficultyLabel(game.settings.difficulty)} · 作弊 ${game.settings.cheats ? '开' : '关'}`,
    640, 598
  );

  const r = game.records;
  const hasRecord = r.bestWave > 0 || r.bestKills > 0 || r.wins > 0;
  ctx.font = `400 11.5px ${KAI}`;
  ctx.fillStyle = 'rgba(232,216,186,0.42)';
  const bestTime = r.wins > 0 && r.bestWinTime != null ? ` · 最快 ${fmt(r.bestWinTime)}` : '';
  ctx.fillText(
    hasRecord
      ? `最高 第 ${Math.max(1, r.bestWave)} 波 · 击退 ${r.bestKills} · 通关 ${r.wins} 次${bestTime}`
      : '最佳：暂无记录',
    640, 622
  );

  ctx.font = `400 13px ${KAI}`;
  ctx.fillStyle = 'rgba(226,212,184,0.4)';
  ctx.fillText('点香火 · 选牌子 · 点空地放下 · 点已放置单位升阶 · P 暂停', 640, 658);

  drawLevelsMenuButton(ctx, game);
  drawAlmanacMenuButton(ctx, game);
  drawTutorialMenuButton(ctx, game);

  if (game.confirmNew) {
    drawConfirm(ctx, '新开一局？', '选择关卡后开始，会覆盖上次对局的存档');
  }
}

function drawMenuPetals(ctx, t) {
  ctx.save();
  for (let i = 0; i < 18; i++) {
    const seed = i * 83.17;
    const x = ((seed * 11.3 + t * (10 + (i % 5) * 4)) % 1360) - 40;
    const y = ((seed * 5.7 + t * (14 + (i % 3) * 5)) % 760) - 20;
    const sway = Math.sin(t * 1.15 + i * 0.7) * 12;
    ctx.globalAlpha = 0.20 + (i % 4) * 0.06;
    ctx.fillStyle = i % 3 === 0 ? '#ffd8e0' : '#ff9db4';
    ctx.save();
    ctx.translate(x + sway, y);
    ctx.rotate(t * 0.6 + i);
    ctx.beginPath();
    ctx.ellipse(0, 0, 4.6, 2.2, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
  ctx.restore();
  ctx.globalAlpha = 1;
}

function drawCornerButtonBase(ctx, b, hover) {
  ctx.save();
  ctx.shadowColor = hover ? 'rgba(242,199,112,0.28)' : 'rgba(0,0,0,0.35)';
  ctx.shadowBlur = hover ? 14 : 8;
  ctx.shadowOffsetY = 3;
  const g = ctx.createLinearGradient(0, b.y, 0, b.y + b.h);
  g.addColorStop(0, 'rgba(22,31,50,0.92)');
  g.addColorStop(1, 'rgba(9,14,24,0.92)');
  ctx.fillStyle = g;
  rr(ctx, b.x, b.y, b.w, b.h, 9);
  ctx.fill();
  ctx.restore();
  ctx.strokeStyle = hover ? 'rgba(244,206,126,0.8)' : 'rgba(226,192,122,0.32)';
  ctx.lineWidth = hover ? 1.6 : 1;
  ctx.stroke();
}

function drawLevelsMenuButton(ctx, game) {
  const b = BTN.levelsMenu;
  const level = getLevel(game.selectedLevel);
  const hover = inRect(game.mouse.x, game.mouse.y, b);
  drawCornerButtonBase(ctx, b, hover);

  ctx.strokeStyle = '#e2c07a';
  ctx.lineWidth = 1.3;
  const gx = b.x + 16;
  const gy = b.y + 12;
  for (let row = 0; row < 2; row++) {
    for (let col = 0; col < 2; col++) {
      ctx.strokeRect(gx + col * 8, gy + row * 8, 6, 6);
    }
  }

  ctx.fillStyle = '#f0dfb8';
  ctx.font = `700 15px ${KAI}`;
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillText('关卡', b.x + 42, b.y + 21);
  ctx.fillStyle = 'rgba(232,211,162,0.55)';
  ctx.font = `400 10px ${KAI}`;
  ctx.textAlign = 'right';
  ctx.fillText(`第${level.id}关`, b.x + b.w - 10, b.y + 21);
}

function drawAlmanacMenuButton(ctx, game) {
  const b = BTN.almanacMenu;
  const hover = inRect(game.mouse.x, game.mouse.y, b);
  drawCornerButtonBase(ctx, b, hover);

  const x = b.x + 16;
  const y = b.y + 12;
  ctx.strokeStyle = '#e2c07a';
  ctx.lineWidth = 1.4;
  ctx.strokeRect(x, y, 16, 18);
  ctx.beginPath();
  ctx.moveTo(x + 8, y);
  ctx.lineTo(x + 8, y + 18);
  ctx.moveTo(x + 3, y + 5);
  ctx.lineTo(x + 6, y + 5);
  ctx.moveTo(x + 10, y + 5);
  ctx.lineTo(x + 13, y + 5);
  ctx.stroke();

  ctx.fillStyle = '#f0dfb8';
  ctx.font = `700 15px ${KAI}`;
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillText('图鉴', b.x + 42, b.y + 21);
  ctx.fillStyle = 'rgba(232,211,162,0.45)';
  ctx.font = `400 10px ${KAI}`;
  ctx.textAlign = 'right';
  ctx.fillText('B', b.x + b.w - 10, b.y + 21);
}

function drawTutorialMenuButton(ctx, game) {
  const b = BTN.tutorialMenu;
  const hover = inRect(game.mouse.x, game.mouse.y, b);
  drawCornerButtonBase(ctx, b, hover);

  const x = b.x + 14;
  const y = b.y + 11;
  ctx.strokeStyle = '#e2c07a';
  ctx.lineWidth = 1.3;
  rr(ctx, x, y, 15, 20, 2);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(x + 3, y + 6);
  ctx.lineTo(x + 12, y + 6);
  ctx.moveTo(x + 3, y + 11);
  ctx.lineTo(x + 12, y + 11);
  ctx.moveTo(x + 3, y + 16);
  ctx.lineTo(x + 9, y + 16);
  ctx.stroke();
  ctx.fillStyle = '#c8402f';
  ctx.beginPath();
  ctx.arc(x + 20, y + 26, 4.5, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#f3dca6';
  ctx.font = '700 8px ' + KAI;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('学', x + 20, y + 26.5);

  ctx.fillStyle = '#f0dfb8';
  ctx.font = `700 14px ${KAI}`;
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillText('新手教程', b.x + 38, b.y + 21);
  ctx.fillStyle = 'rgba(232,211,162,0.45)';
  ctx.font = `400 10px ${KAI}`;
  ctx.textAlign = 'right';
  ctx.fillText('入门', b.x + b.w - 9, b.y + 21);
}

function drawTutorial(ctx, game, t) {
  const tut = game.tutorial;
  if (!tut) return;
  const pulse = 0.5 + Math.sin(t * 4.2) * 0.5;

  if (tut.step === 'collect' && tut.orb) {
    const o = tut.orb;
    ctx.save();
    ctx.strokeStyle = `rgba(255,224,150,${0.55 + pulse * 0.35})`;
    ctx.lineWidth = 2;
    ctx.setLineDash([5, 4]);
    ctx.lineDashOffset = -t * 22;
    ctx.beginPath();
    ctx.arc(o.x, o.y, 26 + pulse * 4, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
    tutorialTag(ctx, '点这里', o.x, o.y - 40);
  }

  if (tut.step === 'plant') {
    const cr = cardRect(0, game.cards.length);
    ctx.save();
    ctx.strokeStyle = `rgba(244,209,138,${0.5 + pulse * 0.4})`;
    ctx.lineWidth = 2.2;
    ctx.setLineDash([6, 5]);
    ctx.lineDashOffset = -t * 18;
    rr(ctx, cr.x - 3, cr.y - 3, cr.w + 6, cr.h + 6, 12);
    ctx.stroke();
    ctx.restore();
    tutorialTag(ctx, '选牌子', cr.x + cr.w / 2, cr.y + cr.h + 17);

    const cell = cellCenter(4, 2);
    const cx = cell.x - BOARD.cw / 2 + 3;
    const cy = cell.y - BOARD.ch / 2 + 3;
    const cw = BOARD.cw - 6;
    const ch = BOARD.ch - 6;
    ctx.save();
    ctx.fillStyle = 'rgba(244,209,138,0.08)';
    rr(ctx, cx, cy, cw, ch, 8);
    ctx.fill();
    ctx.strokeStyle = `rgba(244,209,138,${0.5 + pulse * 0.4})`;
    ctx.lineWidth = 2;
    ctx.setLineDash([6, 5]);
    ctx.lineDashOffset = -t * 18;
    rr(ctx, cx, cy, cw, ch, 8);
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.globalAlpha = 0.24;
    drawPlant(ctx, 'shooter', cell.x, cell.y, t, { noShadow: true });
    ctx.restore();
    tutorialTag(ctx, '种这里', cell.x, cell.y - 60);
  }

  if (tut.step === 'upgrade') {
    const p = tut.shooter;
    if (p && !p.dead) {
      ctx.save();
      ctx.strokeStyle = `rgba(244,209,138,${0.55 + pulse * 0.35})`;
      ctx.lineWidth = 2;
      ctx.setLineDash([6, 5]);
      ctx.lineDashOffset = -t * 18;
      ctx.beginPath();
      ctx.arc(p.x, p.y - 18, 38 + pulse * 3, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
      if (game.menu && game.menu.plant === p) {
        const fan = getFan(p);
        if (fan) {
          for (const petal of fan.petals) {
            ctx.save();
            ctx.strokeStyle = `rgba(244,209,138,${0.45 + pulse * 0.35})`;
            ctx.lineWidth = 1.8;
            ctx.setLineDash([5, 4]);
            ctx.lineDashOffset = -t * 16;
            rr(ctx, petal.x - petal.w / 2 - 2, petal.y - petal.h / 2 - 2, petal.w + 4, petal.h + 4, 10);
            ctx.stroke();
            ctx.restore();
          }
        }
      } else {
        tutorialTag(ctx, '点它升阶', p.x, Math.max(192, p.y - 68));
      }
    }
  }

  if ((tut.step === 'battle' || tut.step === 'finishing') && tut.zombie && !tut.zombie.dead) {
    const z = tut.zombie;
    ctx.save();
    ctx.strokeStyle = `rgba(220,96,72,${0.45 + pulse * 0.3})`;
    ctx.lineWidth = 2;
    ctx.setLineDash([5, 4]);
    ctx.lineDashOffset = -t * 18;
    ctx.beginPath();
    ctx.arc(z.x, z.y - 16, 34 + pulse * 3, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
    tutorialTag(ctx, '看签筒', z.x, Math.max(192, z.y - 96));
  }

  const info = {
    collect: ['第一步 · 收香火', '点一下红灯笼吐出的香火。香火是夜市里的钱。'],
    plant: ['第二步 · 种植物', '先点签筒牌子，再点发光的格子把它种下。'],
    upgrade: ['第三步 · 升阶', '点一下签筒，再从三条路里选一条，花 75 香火升阶。'],
    battle: ['第三步 · 守住', '恶客来了。签筒会自己出手，等它倒下。'],
    finishing: ['第三步 · 守住', '打得好。收摊，回封面。']
  }[tut.step] || ['新手教程', '跟着提示走。'];
  const idx = { collect: 0, plant: 1, upgrade: 2, battle: 2, finishing: 2 }[tut.step] ?? 0;
  const p = TUTORIAL_UI.panel;

  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.5)';
  ctx.shadowBlur = 18;
  ctx.shadowOffsetY = 5;
  const g = ctx.createLinearGradient(0, p.y, 0, p.y + p.h);
  g.addColorStop(0, 'rgba(17,25,42,0.94)');
  g.addColorStop(1, 'rgba(8,13,24,0.94)');
  ctx.fillStyle = g;
  rr(ctx, p.x, p.y, p.w, p.h, 12);
  ctx.fill();
  ctx.restore();
  ctx.strokeStyle = 'rgba(226,192,122,0.5)';
  ctx.lineWidth = 1.2;
  rr(ctx, p.x, p.y, p.w, p.h, 12);
  ctx.stroke();

  ctx.fillStyle = '#c8402f';
  rr(ctx, p.x + 1, p.y + 10, 3, p.h - 20, 2);
  ctx.fill();
  ctx.fillStyle = '#c8402f';
  ctx.beginPath();
  ctx.arc(p.x + 32, p.y + p.h / 2, 17, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = 'rgba(243,220,166,0.8)';
  ctx.lineWidth = 1.5;
  ctx.stroke();
  ctx.fillStyle = '#f8e8c2';
  ctx.font = `700 17px ${DISPLAY}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(String(idx + 1), p.x + 32, p.y + p.h / 2 + 1);

  ctx.textAlign = 'left';
  ctx.fillStyle = '#f3dca6';
  ctx.font = `700 15px ${KAI}`;
  ctx.fillText(info[0], p.x + 58, p.y + 19);
  ctx.fillStyle = 'rgba(238,222,190,0.8)';
  ctx.font = `400 12.5px ${KAI}`;
  ctx.fillText(info[1], p.x + 58, p.y + 39);

  for (let i = 0; i < 3; i++) {
    ctx.beginPath();
    ctx.arc(p.x + p.w - 154 + i * 13, p.y + p.h / 2, 3.2, 0, Math.PI * 2);
    ctx.fillStyle = i < idx ? 'rgba(244,209,138,0.85)' : i === idx ? '#f6d98d' : 'rgba(244,209,138,0.22)';
    ctx.fill();
  }

  const s = TUTORIAL_UI.skip;
  const hover = inRect(game.mouse.x, game.mouse.y, s);
  ctx.fillStyle = hover ? 'rgba(244,209,138,0.14)' : 'rgba(255,255,255,0.04)';
  rr(ctx, s.x, s.y, s.w, s.h, 8);
  ctx.fill();
  ctx.strokeStyle = hover ? 'rgba(244,209,138,0.7)' : 'rgba(226,192,122,0.28)';
  ctx.lineWidth = 1;
  ctx.stroke();
  ctx.fillStyle = hover ? '#f6d98d' : 'rgba(232,211,162,0.68)';
  ctx.font = `400 11px ${KAI}`;
  ctx.textAlign = 'center';
  ctx.fillText('退出教程', s.x + s.w / 2, s.y + s.h / 2 + 1);
}

function tutorialTag(ctx, text, x, y, color = '#f6d98d') {
  ctx.save();
  ctx.font = `700 12px ${KAI}`;
  const w = ctx.measureText(text).width + 18;
  ctx.shadowColor = 'rgba(0,0,0,0.45)';
  ctx.shadowBlur = 8;
  ctx.fillStyle = 'rgba(10,14,24,0.9)';
  rr(ctx, x - w / 2, y - 11, w, 22, 8);
  ctx.fill();
  ctx.shadowBlur = 0;
  ctx.strokeStyle = 'rgba(244,209,138,0.5)';
  ctx.lineWidth = 1;
  rr(ctx, x - w / 2, y - 11, w, 22, 8);
  ctx.stroke();
  ctx.fillStyle = color;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(text, x, y + 0.5);
  ctx.restore();
}

function drawGlassPanel(ctx, r, radius = 16) {
  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.5)';
  ctx.shadowBlur = 32;
  ctx.shadowOffsetY = 10;
  const g = ctx.createLinearGradient(0, r.y, 0, r.y + r.h);
  g.addColorStop(0, 'rgba(19,28,46,0.98)');
  g.addColorStop(0.5, 'rgba(13,20,34,0.98)');
  g.addColorStop(1, 'rgba(10,15,26,0.98)');
  ctx.fillStyle = g;
  rr(ctx, r.x, r.y, r.w, r.h, radius);
  ctx.fill();
  ctx.restore();

  ctx.strokeStyle = 'rgba(226,192,122,0.62)';
  ctx.lineWidth = 1.6;
  rr(ctx, r.x, r.y, r.w, r.h, radius);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(255,240,200,0.10)';
  ctx.lineWidth = 1;
  rr(ctx, r.x + 6, r.y + 6, r.w - 12, r.h - 12, Math.max(4, radius - 4));
  ctx.stroke();
  const gleam = ctx.createLinearGradient(r.x + 30, 0, r.x + r.w - 30, 0);
  gleam.addColorStop(0, 'rgba(255,220,150,0)');
  gleam.addColorStop(0.5, 'rgba(255,220,150,0.38)');
  gleam.addColorStop(1, 'rgba(255,220,150,0)');
  ctx.fillStyle = gleam;
  ctx.fillRect(r.x + 30, r.y + 1, r.w - 60, 1);

  ctx.strokeStyle = 'rgba(232,198,124,0.55)';
  ctx.lineWidth = 2;
  const corners = [
    [r.x + 12, r.y + 12, 1, 1],
    [r.x + r.w - 12, r.y + 12, -1, 1],
    [r.x + 12, r.y + r.h - 12, 1, -1],
    [r.x + r.w - 12, r.y + r.h - 12, -1, -1]
  ];
  for (const [x, y, sx, sy] of corners) {
    ctx.beginPath();
    ctx.moveTo(x + sx * 14, y);
    ctx.lineTo(x, y);
    ctx.lineTo(x, y + sy * 14);
    ctx.stroke();
  }
}

function drawOverlay(ctx, game) {
  ctx.fillStyle = 'rgba(4,6,12,0.66)';
  ctx.fillRect(0, 0, VIEW.w, VIEW.h);

  const panel = game.phase === 'paused'
    ? { x: 410, y: 240, w: 460, h: 380 }
    : { x: 410, y: 286, w: 460, h: 316 };
  drawGlassPanel(ctx, panel);

  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';

  if (game.phase === 'won' && game.tutorial && game.tutorial.step === 'done') {
    ctx.font = `700 44px ${DISPLAY}`;
    ctx.fillStyle = '#f2d79b';
    ctx.fillText('第一课 · 收摊', 640, 348);
    ctx.font = `400 16px ${KAI}`;
    ctx.fillStyle = 'rgba(235,218,184,0.72)';
    ctx.fillText('香火收了，签筒种下，也升了阶。', 640, 398);
    ctx.fillStyle = 'rgba(240,220,180,0.55)';
    ctx.font = `400 14px ${KAI}`;
    ctx.fillText('十夜还长，慢慢守。', 640, 430);
    drawButton(ctx, BTN.overlay, '再练一次', true);
    drawButton(ctx, BTN.toMenu, '回封面', false);
    return;
  }

  if (game.phase === 'paused') {
    ctx.font = `700 46px ${DISPLAY}`;
    ctx.fillStyle = '#efe0bd';
    ctx.fillText('暂歇', 640, 298);
    ctx.font = `400 16px ${KAI}`;
    ctx.fillStyle = 'rgba(235,218,184,0.6)';
    ctx.fillText(
      game.tutorial ? '新手教程 · 第一课 · 随时可退' : `${game.level.name} · ${difficultyLabel(game.runDifficulty)} · 本局锁定`,
      640, 338
    );

    drawButton(ctx, BTN.resume, '继续守夜', true);
    drawButton(ctx, BTN.pauseSettings, '设置', false);
    drawButton(ctx, BTN.restart, game.tutorial ? '从头再学' : '重新开张', false);
    drawButton(ctx, BTN.backMenu, '回封面', false);
    drawButton(ctx, BTN.pauseAlmanac, '图鉴', false);

    ctx.font = `400 11px ${KAI}`;
    ctx.fillStyle = 'rgba(235,218,184,0.4)';
    ctx.fillText(
      game.tutorial ? '教程不写入存档 · 退出不会覆盖已有对局' : '难度与作弊仅能在封面调整 · 对局自动存档',
      640, 578
    );
    if (game.confirmBack) {
      drawConfirm(
        ctx,
        game.tutorial ? '退出教程？' : '回到封面？',
        game.tutorial ? '教程进度不会保存，已有对局不受影响' : '本局会自动存档，可从封面继续'
      );
    }
    return;
  }

  const won = game.phase === 'won';
  ctx.font = `700 44px ${DISPLAY}`;
  ctx.fillStyle = won ? '#f2d79b' : '#e7b39a';
  ctx.fillText(won ? '天快亮了' : '摊子被抢空了', 640, 348);

  const res = game.result || { time: game.time, kills: game.kills, sun: game.sun };
  ctx.font = `400 16px ${KAI}`;
  ctx.fillStyle = 'rgba(235,218,184,0.7)';
  ctx.fillText(
    `第 ${game.runLevelId} 关 · 击退 ${res.kills} · 香火 ${res.sun} · ${fmt(res.time)}`,
    640, 396
  );

  if (won) {
    ctx.font = `400 14px ${KAI}`;
    ctx.fillStyle = 'rgba(240,220,180,0.55)';
    ctx.fillText('宵夜散场，今夜无失', 640, 430);
  }

  drawButton(ctx, BTN.overlay, won ? '再守一夜' : '重新开张', true);
  drawButton(ctx, BTN.toMenu, '回封面', false);
}

function drawConfirm(ctx, title, text) {
  ctx.fillStyle = 'rgba(3,5,10,0.72)';
  ctx.fillRect(0, 0, VIEW.w, VIEW.h);

  const p = { x: 440, y: 280, w: 400, h: 210 };
  drawGlassPanel(ctx, p, 14);

  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.font = `700 32px ${DISPLAY}`;
  ctx.fillStyle = '#f2e2bb';
  ctx.fillText(title, 640, 334);
  ctx.font = `400 14px ${KAI}`;
  ctx.fillStyle = 'rgba(235,218,184,0.68)';
  ctx.fillText(text, 640, 374);

  drawButton(ctx, BTN.confirmYes, '确定', true);
  drawButton(ctx, BTN.confirmNo, '取消', false);
}

function prepDiff(value) {
  if (value === 'normal') return { label: '普通', mult: 1.25 };
  if (value === 'hard') return { label: '困难', mult: 1.5 };
  return { label: '简单', mult: 1 };
}

function prepHoverAt(game) {
  if (!game.prep || game.prep.warning) return null;
  const { x, y } = game.mouse;
  for (let i = 0; i < 10; i++) {
    const id = game.prep.selected[i];
    if (id && inRect(x, y, prepSlotRect(i))) {
      return { kind: 'plant', def: PLANT_TYPES[id] };
    }
  }
  for (let i = 0; i < PLANT_ORDER.length; i++) {
    if (inRect(x, y, prepRosterRect(i))) {
      return { kind: 'plant', def: PLANT_TYPES[PLANT_ORDER[i]] };
    }
  }
  for (let i = 0; i < game.prep.zombies.length; i++) {
    if (inRect(x, y, prepZombieRect(i))) {
      return { kind: 'zombie', def: ZOMBIE_TYPES[game.prep.zombies[i].type] };
    }
  }
  return null;
}

function drawPrepTooltip(ctx, game) {
  const hover = prepHoverAt(game);
  if (!hover) return;
  const isPlant = hover.kind === 'plant';
  const name = hover.def.name;
  const sub = isPlant ? `${hover.def.role} · ${hover.def.cost} 香火` : hover.def.kind;
  ctx.save();
  ctx.font = `700 14px ${KAI}`;
  const nw = ctx.measureText(name).width;
  ctx.font = `400 11px ${KAI}`;
  const sw = ctx.measureText(sub).width;
  const w = Math.max(nw, sw) + 24;
  const h = 46;
  let x = game.mouse.x + 18;
  let y = game.mouse.y - h - 12;
  if (x + w > 1268) x = game.mouse.x - w - 14;
  if (y < 8) y = game.mouse.y + 18;
  ctx.shadowColor = 'rgba(0,0,0,0.5)';
  ctx.shadowBlur = 12;
  ctx.fillStyle = 'rgba(9,13,22,0.96)';
  rr(ctx, x, y, w, h, 8);
  ctx.fill();
  ctx.restore();
  ctx.strokeStyle = 'rgba(226,192,122,0.65)';
  ctx.lineWidth = 1.2;
  rr(ctx, x, y, w, h, 8);
  ctx.stroke();
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#f5e5c2';
  ctx.font = `700 14px ${KAI}`;
  ctx.fillText(name, x + 12, y + 16);
  ctx.fillStyle = 'rgba(232,211,162,0.62)';
  ctx.font = `400 11px ${KAI}`;
  ctx.fillText(sub, x + 12, y + 33);
}

function drawPrepRosterCard(ctx, game, i, def, t) {
  const r = prepRosterRect(i);
  const selected = game.prep.selected.includes(def.id);
  const hover = inRect(game.mouse.x, game.mouse.y, r);
  ctx.save();
  ctx.shadowColor = selected ? 'rgba(244,198,112,0.45)' : 'rgba(0,0,0,0.4)';
  ctx.shadowBlur = selected ? 16 : 9;
  ctx.shadowOffsetY = 4;
  const g = ctx.createLinearGradient(0, r.y, 0, r.y + r.h);
  if (selected) {
    g.addColorStop(0, 'rgba(92,66,38,0.96)');
    g.addColorStop(1, 'rgba(38,27,24,0.98)');
  } else {
    g.addColorStop(0, 'rgba(22,31,48,0.96)');
    g.addColorStop(1, 'rgba(11,17,29,0.98)');
  }
  ctx.fillStyle = g;
  rr(ctx, r.x, r.y, r.w, r.h, 9);
  ctx.fill();
  ctx.restore();

  ctx.strokeStyle = selected
    ? 'rgba(246,208,132,0.95)'
    : hover
      ? 'rgba(234,200,130,0.62)'
      : 'rgba(226,192,122,0.22)';
  ctx.lineWidth = selected ? 2.2 : 1.1;
  rr(ctx, r.x, r.y, r.w, r.h, 9);
  ctx.stroke();

  ctx.save();
  rr(ctx, r.x, r.y, r.w, r.h, 9);
  ctx.clip();
  ctx.fillStyle = def.tint;
  ctx.globalAlpha = selected ? 0.95 : 0.55;
  ctx.fillRect(r.x, r.y, r.w, 4);
  ctx.restore();

  const cx = r.x + r.w / 2;
  const cy = r.y + 38;
  const glow = ctx.createRadialGradient(cx, cy, 3, cx, cy, 24);
  glow.addColorStop(0, def.tint + '32');
  glow.addColorStop(1, def.tint + '00');
  ctx.fillStyle = glow;
  ctx.beginPath();
  ctx.arc(cx, cy, 24, 0, Math.PI * 2);
  ctx.fill();
  drawPlant(ctx, def.id, cx, cy, t, { scale: 0.34, noShadow: true });

  ctx.fillStyle = 'rgba(36,24,16,0.9)';
  rr(ctx, r.x + 5, r.y + 4, 34, 14, 7);
  ctx.fill();
  ctx.fillStyle = '#ffd98a';
  ctx.beginPath();
  ctx.arc(r.x + 11, r.y + 11, 2.5, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#f7e7c6';
  ctx.font = `700 10px ${KAI}`;
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillText(String(def.cost), r.x + 16, r.y + 11.5);

  if (selected) {
    ctx.fillStyle = 'rgba(247,210,134,0.95)';
    ctx.beginPath();
    ctx.arc(r.x + r.w - 10, r.y + 11, 7, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#402a18';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.moveTo(r.x + r.w - 13, r.y + 11);
    ctx.lineTo(r.x + r.w - 10, r.y + 14);
    ctx.lineTo(r.x + r.w - 6, r.y + 8);
    ctx.stroke();
  }

  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = selected ? '#f6e4bd' : 'rgba(236,216,178,0.66)';
  ctx.font = `700 10px ${KAI}`;
  ctx.fillText(def.role, cx, r.y + 68);
}

function drawPrepSlot(ctx, game, i, t) {
  const r = prepSlotRect(i);
  const id = game.prep.selected[i];
  const hover = inRect(game.mouse.x, game.mouse.y, r);
  if (!id) {
    ctx.save();
    ctx.setLineDash([5, 5]);
    ctx.strokeStyle = 'rgba(226,192,122,0.18)';
    ctx.lineWidth = 1.2;
    rr(ctx, r.x, r.y, r.w, r.h, 8);
    ctx.stroke();
    ctx.restore();
    ctx.fillStyle = 'rgba(232,211,162,0.18)';
    ctx.font = `700 12px ${KAI}`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(String(i + 1), r.x + r.w / 2, r.y + r.h / 2);
    return;
  }
  const def = PLANT_TYPES[id];
  ctx.save();
  ctx.shadowColor = hover ? 'rgba(244,198,112,0.4)' : 'rgba(0,0,0,0.35)';
  ctx.shadowBlur = hover ? 12 : 6;
  ctx.shadowOffsetY = 3;
  const g = ctx.createLinearGradient(0, r.y, 0, r.y + r.h);
  g.addColorStop(0, 'rgba(54,42,30,0.98)');
  g.addColorStop(1, 'rgba(20,18,24,0.98)');
  ctx.fillStyle = g;
  rr(ctx, r.x, r.y, r.w, r.h, 8);
  ctx.fill();
  ctx.restore();
  ctx.strokeStyle = hover ? 'rgba(246,208,132,0.9)' : 'rgba(226,192,122,0.4)';
  ctx.lineWidth = hover ? 1.8 : 1.2;
  rr(ctx, r.x, r.y, r.w, r.h, 8);
  ctx.stroke();

  ctx.save();
  rr(ctx, r.x, r.y, r.w, r.h, 8);
  ctx.clip();
  ctx.fillStyle = def.tint;
  ctx.globalAlpha = 0.8;
  ctx.fillRect(r.x, r.y, r.w, 3);
  ctx.restore();

  drawPlant(ctx, id, r.x + r.w / 2, r.y + 45, t, { scale: 0.42, noShadow: true });
  ctx.fillStyle = 'rgba(247,221,168,0.72)';
  ctx.font = `700 10px ${KAI}`;
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillText(String(i + 1), r.x + 7, r.y + 9);
  ctx.fillStyle = 'rgba(232,211,162,0.62)';
  ctx.font = `400 10px ${KAI}`;
  ctx.textAlign = 'center';
  ctx.fillText(def.role, r.x + r.w / 2, r.y + 77);
}

function drawPrepZombie(ctx, game, i, info, t) {
  const r = prepZombieRect(i);
  const def = ZOMBIE_TYPES[info.type];
  const hover = inRect(game.mouse.x, game.mouse.y, r);
  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.35)';
  ctx.shadowBlur = 8;
  ctx.shadowOffsetY = 3;
  ctx.fillStyle = hover ? 'rgba(40,30,34,0.96)' : 'rgba(16,22,34,0.94)';
  rr(ctx, r.x, r.y, r.w, r.h, 8);
  ctx.fill();
  ctx.restore();
  ctx.strokeStyle = hover ? 'rgba(234,190,120,0.7)' : 'rgba(226,192,122,0.24)';
  ctx.lineWidth = 1.2;
  rr(ctx, r.x, r.y, r.w, r.h, 8);
  ctx.stroke();
  drawZombie(ctx, info.type, r.x + r.w / 2, r.y + r.h - 26, t, {
    def, scale: 0.4, hpRatio: 1
  });
  ctx.fillStyle = 'rgba(244,210,146,0.72)';
  ctx.font = `700 9.5px ${KAI}`;
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillText(`第${info.firstWave}波`, r.x + 6, r.y + 10);
  const tierMeta = ZOMBIE_TIERS[def.tier] || ZOMBIE_TIERS.l;
  ctx.fillStyle = 'rgba(4,8,14,0.78)';
  rr(ctx, r.x + r.w - 20, r.y + 4, 16, 14, 4);
  ctx.fill();
  ctx.strokeStyle = tierMeta.color;
  ctx.lineWidth = 1;
  rr(ctx, r.x + r.w - 20, r.y + 4, 16, 14, 4);
  ctx.stroke();
  ctx.fillStyle = tierMeta.color;
  ctx.font = `700 9px ${KAI}`;
  ctx.textAlign = 'center';
  ctx.fillText(tierMeta.short, r.x + r.w - 12, r.y + 11.5);
  ctx.fillStyle = 'rgba(232,211,162,0.55)';
  ctx.font = `400 10px ${KAI}`;
  ctx.fillText(def.kind, r.x + r.w / 2, r.y + r.h - 7);
}

function drawPrepWarning(ctx, game) {
  const prep = game.prep;
  const empty = prep.warning === 'empty';
  ctx.fillStyle = 'rgba(2,3,8,0.72)';
  ctx.fillRect(0, 0, VIEW.w, VIEW.h);
  drawGlassPanel(ctx, PREP.warning, 18);
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#f4d7a0';
  ctx.font = `700 28px ${DISPLAY}`;
  ctx.fillText(empty ? '空手开张' : '香火将断', PREP.warning.x + PREP.warning.w / 2, PREP.warning.y + 54);
  ctx.strokeStyle = 'rgba(226,192,122,0.28)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(PREP.warning.x + 46, PREP.warning.y + 86);
  ctx.lineTo(PREP.warning.x + PREP.warning.w - 46, PREP.warning.y + 86);
  ctx.stroke();

  ctx.fillStyle = 'rgba(240,222,188,0.9)';
  ctx.font = `400 15px ${KAI}`;
  if (empty) {
    ctx.fillText('你还没有选择任何植物。', 640, PREP.warning.y + 124);
    ctx.fillStyle = 'rgba(232,211,162,0.62)';
    ctx.font = `400 13px ${KAI}`;
    ctx.fillText('至少带上一株，才能开摊。', 640, PREP.warning.y + 154);
    ctx.fillStyle = 'rgba(232,211,162,0.38)';
    ctx.font = `400 11px ${KAI}`;
    ctx.fillText('点击任意处返回选择 · 2 秒后自动返回', 640, PREP.warning.y + 180);
    drawButton(ctx, PREP.warningOnly, '返回选择', true);
  } else {
    ctx.fillText('你没有携带任何产能型植物（红灯笼）。', 640, PREP.warning.y + 122);
    ctx.fillStyle = 'rgba(232,211,162,0.62)';
    ctx.font = `400 13px ${KAI}`;
    ctx.fillText('开局后可能没有足够香火，仍要出战吗？', 640, PREP.warning.y + 152);
    drawButton(ctx, PREP.warningYes, '仍要出战', true);
    drawButton(ctx, PREP.warningNo, '返回调整', false);
  }
}

function easeInOut(x) {
  const k = clamp01(x);
  return k * k * (3 - 2 * k);
}

function drawCinemaBg(ctx, zoom, fx, fy) {
  const img = assets.backgrounds.board;
  if (!img) {
    const g = ctx.createLinearGradient(0, 0, 0, VIEW.h);
    g.addColorStop(0, '#0a1120');
    g.addColorStop(1, '#170f10');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, VIEW.w, VIEW.h);
    return;
  }
  const base = Math.max(VIEW.w / img.width, VIEW.h / img.height);
  const w = img.width * base * zoom;
  const h = img.height * base * zoom;
  ctx.drawImage(img, VIEW.w / 2 - fx * w, VIEW.h / 2 - fy * h, w, h);
}

function drawPrepCinematic(ctx, game, t) {
  const prep = game.prep;
  const level = getLevel(prep.levelId);
  const ct = Math.min(PREP_CINEMA.total, prep.cinemaT);
  const panStart = PREP_CINEMA.panStart;
  const revealStart = PREP_CINEMA.revealStart;
  const fadeStart = PREP_CINEMA.fadeStart;
  const panP = easeInOut(clamp01((ct - panStart) / (revealStart - panStart)));
  const zoom = ct < panStart
    ? 1.02 + 0.06 * (ct / panStart)
    : 1.08 + 0.47 * panP + (ct > revealStart ? Math.sin((ct - revealStart) * 0.7) * 0.008 : 0);
  const focusY = ct < panStart ? 0.545 : 0.545 - 0.115 * panP;
  const fade = clamp01((ct - fadeStart) / (PREP_CINEMA.total - fadeStart));

  ctx.save();
  ctx.fillStyle = '#050608';
  ctx.fillRect(0, 0, VIEW.w, VIEW.h);
  drawCinemaBg(ctx, zoom, 0.5, focusY);

  const warm = Math.max(0, 1 - ct / (panStart + 0.35));
  ctx.fillStyle = `rgba(255,150,64,${0.08 + warm * 0.09})`;
  ctx.fillRect(0, 0, VIEW.w, VIEW.h);
  const dark = clamp01((ct - panStart * 0.55) / (revealStart - panStart * 0.55 + 0.2));
  ctx.fillStyle = `rgba(4,8,18,${0.04 + dark * 0.5})`;
  ctx.fillRect(0, 0, VIEW.w, VIEW.h);

  const vignette = ctx.createRadialGradient(640, 350, 180, 640, 350, 760);
  vignette.addColorStop(0, 'rgba(0,0,0,0)');
  vignette.addColorStop(0.62, 'rgba(2,4,10,0.2)');
  vignette.addColorStop(1, 'rgba(1,2,6,0.72)');
  ctx.fillStyle = vignette;
  ctx.fillRect(0, 0, VIEW.w, VIEW.h);

  if (ct < revealStart + 1.2) {
    for (let i = 0; i < 18; i++) {
      const seed = i * 93.7;
      const x = ((seed * 11.3 + t * (7 + (i % 4) * 2)) % 1360) - 40;
      const y = 690 - ((seed * 7.7 + t * (12 + (i % 5) * 3)) % 760);
      const a = (0.18 + (i % 4) * 0.05) * (1 - dark * 0.55);
      ctx.fillStyle = `rgba(255,${i % 3 === 0 ? 214 : 172},${i % 3 === 0 ? 130 : 96},${a})`;
      ctx.beginPath();
      ctx.arc(x, y, 1.2 + (i % 3) * 0.7, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  const stage1A = Math.min(1, ct / 0.45) * (1 - clamp01((ct - 1.05) / 0.4));
  if (stage1A > 0) {
    ctx.globalAlpha = stage1A;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,0.62)';
    ctx.shadowBlur = 26;
    ctx.fillStyle = '#f7e3b6';
    ctx.font = `700 48px ${DISPLAY}`;
    ctx.fillText('夜市灯火通明', 640, 196);
    ctx.restore();
    ctx.fillStyle = 'rgba(246,224,180,0.78)';
    ctx.font = `400 16px ${KAI}`;
    ctx.fillText('摊子刚支起来，香气正热。', 640, 248);
    ctx.fillStyle = 'rgba(226,192,122,0.55)';
    ctx.font = `400 11px ${KAI}`;
    ctx.fillText(`${level.name} · ${level.tag} · 共 ${level.waves.length} 波`, 640, 286);
    ctx.globalAlpha = 1;
  }

  const panTextA = clamp01((ct - 1.12) / 0.32) * (1 - clamp01((ct - revealStart + 0.1) / 0.3));
  if (panTextA > 0) {
    ctx.globalAlpha = panTextA;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = 'rgba(244,226,190,0.9)';
    ctx.font = `700 24px ${DISPLAY}`;
    ctx.fillText('街尾的灯，好像被谁挡住了。', 640, 196);
    ctx.globalAlpha = 1;
    ctx.strokeStyle = `rgba(235,190,120,${0.22 * panTextA})`;
    ctx.lineWidth = 2;
    for (let i = 0; i < 4; i++) {
      const yy = 330 + i * 26;
      ctx.beginPath();
      ctx.moveTo(140 + i * 30, yy);
      ctx.lineTo(360 + i * 18, yy + 2);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(920 - i * 18, yy);
      ctx.lineTo(1140 - i * 30, yy + 2);
      ctx.stroke();
    }
  }

  const zombiesA = clamp01((ct - revealStart) / 0.35) * (1 - fade);
  if (zombiesA > 0) {
    ctx.globalAlpha = zombiesA;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,0.6)';
    ctx.shadowBlur = 20;
    ctx.fillStyle = '#f0d7a0';
    ctx.font = `700 28px ${DISPLAY}`;
    ctx.fillText('今夜恶客', 640, 100);
    ctx.restore();
    ctx.fillStyle = 'rgba(232,211,162,0.68)';
    ctx.font = `400 13px ${KAI}`;
    ctx.fillText('它们已经闻到香火了。', 640, 132);
    ctx.globalAlpha = 1;

    const list = prep.zombies;
    const n = list.length;
    const gap = n > 1 ? Math.min(196, 980 / (n - 1)) : 0;
    const startX = 640 - (gap * (n - 1)) / 2;
    const band = ctx.createLinearGradient(0, 480, 0, 640);
    band.addColorStop(0, 'rgba(3,5,10,0)');
    band.addColorStop(0.42, 'rgba(3,5,10,0.5)');
    band.addColorStop(1, 'rgba(3,5,10,0.82)');
    ctx.save();
    ctx.globalAlpha = zombiesA;
    ctx.fillStyle = band;
    ctx.fillRect(0, 480, VIEW.w, 170);
    ctx.restore();

    for (let i = 0; i < n; i++) {
      const info = list[i];
      const def = ZOMBIE_TYPES[info.type];
      const p = clamp01((ct - revealStart - i * 0.13) / 0.42);
      if (p <= 0) continue;
      const e = easeInOut(p);
      const x = startX + gap * i + (1 - e) * 42;
      const y = 478 + (1 - e) * 30;
      const a = p * (1 - fade);
      ctx.save();
      ctx.globalAlpha = a * 0.55;
      ctx.fillStyle = 'rgba(0,0,0,0.8)';
      ctx.beginPath();
      ctx.ellipse(x, 504, 36, 7, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
      ctx.save();
      ctx.globalAlpha = a;
      drawZombie(ctx, info.type, x, y, t, {
        def, scale: 0.72, hpRatio: 1
      });
      ctx.restore();
      if (p > 0.55) {
        const ta = (p - 0.55) / 0.45;
        ctx.globalAlpha = ta * (1 - fade);
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = '#f0dcb0';
        ctx.font = `700 16px ${KAI}`;
        ctx.fillText(def.name, x, 542);
        ctx.fillStyle = 'rgba(232,211,162,0.55)';
        ctx.font = `400 10.5px ${KAI}`;
        ctx.fillText(`${zombieTierLabel(def.tier)} · ${def.kind} · 第${info.firstWave}波`, x, 562);
        ctx.globalAlpha = 1;
      }
    }
  }

  if (fade > 0) {
    ctx.fillStyle = `rgba(2,3,6,${easeInOut(fade)})`;
    ctx.fillRect(0, 0, VIEW.w, VIEW.h);
    if (fade < 0.72) {
      ctx.globalAlpha = clamp01((fade - 0.1) / 0.35);
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillStyle = '#f4dca8';
      ctx.font = `700 26px ${DISPLAY}`;
      ctx.fillText('该选今晚守摊的家伙了。', 640, 356);
      ctx.globalAlpha = 1;
    }
  }

  ctx.fillStyle = 'rgba(1,2,4,0.96)';
  ctx.fillRect(0, 0, VIEW.w, 46);
  ctx.fillRect(0, VIEW.h - 46, VIEW.w, 46);
  ctx.fillStyle = 'rgba(226,192,122,0.55)';
  ctx.font = `400 10px ${KAI}`;
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillText('备战 · ' + level.name + ' · ' + level.tag, 54, 23);
  ctx.textAlign = 'right';
  ctx.fillStyle = 'rgba(232,211,162,0.5)';
  ctx.fillText('点击跳过', 1226, VIEW.h - 23);
  ctx.textAlign = 'left';
  ctx.restore();
}

function drawPrep(ctx, game, t) {
  const prep = game.prep;
  if (!prep) return;
  if (!prep.cinemaDone) {
    drawPrepCinematic(ctx, game, t);
    return;
  }
  const level = getLevel(prep.levelId);
  const diff = prepDiff(game.settings.difficulty);

  ctx.fillStyle = 'rgba(3,4,8,0.8)';
  ctx.fillRect(0, 0, VIEW.w, VIEW.h);
  drawGlassPanel(ctx, PREP.panel);

  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#f6e4ba';
  ctx.font = `700 34px ${DISPLAY}`;
  ctx.fillText('备战', 104, 76);
  ctx.fillStyle = '#e8cea0';
  ctx.font = `700 21px ${KAI}`;
  ctx.fillText(`${level.name} · ${level.tag}`, 210, 68);
  ctx.fillStyle = 'rgba(232,211,162,0.55)';
  ctx.font = `400 12px ${KAI}`;
  ctx.fillText(`第 ${level.id} 关 · 共 ${level.waves.length} 波`, 210, 92);

  const chip = { x: 920, y: 52, w: 250, h: 42 };
  ctx.fillStyle = 'rgba(255,235,196,0.06)';
  rr(ctx, chip.x, chip.y, chip.w, chip.h, 9);
  ctx.fill();
  ctx.strokeStyle = 'rgba(226,192,122,0.32)';
  ctx.lineWidth = 1.2;
  rr(ctx, chip.x, chip.y, chip.w, chip.h, 9);
  ctx.stroke();
  ctx.fillStyle = 'rgba(232,211,162,0.58)';
  ctx.font = `400 11px ${KAI}`;
  ctx.fillText('当前难度', chip.x + 14, chip.y + 14);
  ctx.fillStyle = '#f0d7a0';
  ctx.font = `700 16px ${KAI}`;
  ctx.fillText(`${diff.label} · 出怪/血量 ×${diff.mult.toFixed(2)}`, chip.x + 14, chip.y + 30);

  ctx.fillStyle = '#e2c07a';
  ctx.font = `700 15px ${KAI}`;
  ctx.fillText('本夜威胁', 104, 126);
  const tb = PREP.threatBar;
  ctx.fillStyle = 'rgba(7,11,20,0.75)';
  rr(ctx, tb.x, tb.y, tb.w, tb.h, 6);
  ctx.fill();
  ctx.strokeStyle = 'rgba(226,192,122,0.24)';
  ctx.lineWidth = 1;
  rr(ctx, tb.x, tb.y, tb.w, tb.h, 6);
  ctx.stroke();
  const ratio = clamp01(level.threat / 5);
  if (ratio > 0) {
    const g = ctx.createLinearGradient(tb.x, 0, tb.x + tb.w, 0);
    g.addColorStop(0, '#b83428');
    g.addColorStop(0.62, '#e08a3e');
    g.addColorStop(1, '#f2cf80');
    ctx.fillStyle = g;
    rr(ctx, tb.x + 2, tb.y + 2, Math.max(3, (tb.w - 4) * ratio), tb.h - 4, 4);
    ctx.fill();
  }
  for (let i = 1; i < 5; i++) {
    const tx = tb.x + (tb.w * i) / 5;
    ctx.strokeStyle = 'rgba(10,14,22,0.55)';
    ctx.beginPath();
    ctx.moveTo(tx, tb.y + 2);
    ctx.lineTo(tx, tb.y + tb.h - 2);
    ctx.stroke();
  }
  ctx.fillStyle = '#f2d59a';
  ctx.font = `700 15px ${KAI}`;
  ctx.fillText(`×${level.threat.toFixed(1)}`, 416, 156);

  ctx.fillStyle = 'rgba(232,211,162,0.62)';
  ctx.font = `400 12px ${KAI}`;
  ctx.fillText(`难度 ${diff.label}：出怪与血量各 ×${diff.mult.toFixed(2)}`, 104, 184);
  ctx.fillText(`${level.waves.length} 波 · ${prep.zombies.length} 种恶客`, 104, 206);
  ctx.fillStyle = 'rgba(232,211,162,0.4)';
  ctx.font = `400 11px ${KAI}`;
  ctx.fillText('难度可在封面设置中调整', 104, 228);

  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#e2c07a';
  ctx.font = `700 15px ${KAI}`;
  ctx.fillText('今夜恶客', 700, 126);
  ctx.fillStyle = 'rgba(232,211,162,0.45)';
  ctx.font = `400 10.5px ${KAI}`;
  ctx.textAlign = 'right';
  ctx.fillText('悬停看名称 · 右键查图鉴', 1170, 126);
  ctx.textAlign = 'left';
  for (let i = 0; i < prep.zombies.length; i++) {
    drawPrepZombie(ctx, game, i, prep.zombies[i], t);
  }

  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#e2c07a';
  ctx.font = `700 15px ${KAI}`;
  ctx.fillText('可出战植物', 294, 248);
  ctx.fillStyle = 'rgba(232,211,162,0.45)';
  ctx.font = `400 10.5px ${KAI}`;
  ctx.textAlign = 'right';
  ctx.fillText('左键加入/移出 · 右键查图鉴', 864, 248);
  ctx.textAlign = 'left';
  for (let i = 0; i < PLANT_ORDER.length; i++) {
    drawPrepRosterCard(ctx, game, i, PLANT_TYPES[PLANT_ORDER[i]], t);
  }

  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  const noPlants = prep.selected.length === 0;
  ctx.fillStyle = noPlants ? '#f08a6a' : '#e2c07a';
  ctx.font = `700 15px ${KAI}`;
  ctx.fillText(
    noPlants ? '出战栏 0/10 · 至少带 1 株' : `出战栏 ${prep.selected.length}/${10}`,
    294, 442
  );
  ctx.fillStyle = 'rgba(232,211,162,0.45)';
  ctx.font = `400 10.5px ${KAI}`;
  ctx.textAlign = 'right';
  ctx.fillText('点击已选植物可移除', 986, 442);
  ctx.textAlign = 'left';
  for (let i = 0; i < 10; i++) {
    drawPrepSlot(ctx, game, i, t);
  }

  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = 'rgba(232,211,162,0.45)';
  ctx.font = `400 11px ${KAI}`;
  ctx.fillText('最多 10 株 · 选择会自动记住 · 右键植物或恶客查看图鉴', 640, 560);
  drawButton(ctx, PREP.back, '返回', false);
  drawButton(ctx, PREP.confirm, '开战', true);

  if (prep.warning) {
    drawPrepWarning(ctx, game);
  } else {
    drawPrepTooltip(ctx, game);
  }
}

function drawSettings(ctx, game) {
  const fromMenu = game.overlayFrom === 'menu';
  const p = SETTINGS.panel;

  ctx.fillStyle = 'rgba(4,6,12,0.74)';
  ctx.fillRect(0, 0, VIEW.w, VIEW.h);
  drawGlassPanel(ctx, p);

  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.font = `700 30px ${DISPLAY}`;
  ctx.fillStyle = '#f2e2bb';
  ctx.fillText('设置', p.x + p.w / 2, SETTINGS.titleY);

  ctx.strokeStyle = 'rgba(226,192,122,0.22)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(p.x + 70, SETTINGS.titleY + 26);
  ctx.lineTo(p.x + p.w - 70, SETTINGS.titleY + 26);
  ctx.stroke();

  for (const row of SETTINGS.rows) {
    const runLocked = !settingsRowEnabled(row, fromMenu);
    const needsAuto = row.requires && !game.settings[row.requires];
    const enabled = !runLocked && !needsAuto;
    let currentValue = game.settings[row.key];
    if (row.lockInRun && !fromMenu) {
      currentValue = row.key === 'cheats' ? game.runCheats : game.runDifficulty;
    }

    ctx.textAlign = 'left';
    ctx.font = `700 16px ${KAI}`;
    ctx.fillStyle = enabled ? '#f0dfba' : 'rgba(220,200,168,0.28)';
    ctx.fillText(row.label, SETTINGS.labelX, row.y);

    let note = row.note;
    if (runLocked) note = '仅局外可改 · 本局已锁定';
    if (needsAuto) note = '需先开启自动拾取';
    ctx.font = `400 10.5px ${KAI}`;
    ctx.fillStyle = enabled ? 'rgba(230,210,175,0.42)' : 'rgba(230,210,175,0.22)';
    ctx.fillText(note, SETTINGS.labelX, row.y + 21);

    for (let i = 0; i < row.options.length; i++) {
      const pill = settingsPill(row, i);
      const selected = currentValue === pill.option.value;
      const hover = enabled && inRect(game.mouse.x, game.mouse.y, pill);
      drawPill(ctx, pill, pill.option.label, selected, enabled, hover);
    }
  }

  drawButton(ctx, SETTINGS.back, '返回', true);
}

function drawPill(ctx, rect, label, selected, enabled, hover) {
  ctx.save();
  ctx.globalAlpha = enabled ? 1 : 0.3;
  if (selected) {
    const g = ctx.createLinearGradient(0, rect.y, 0, rect.y + rect.h);
    g.addColorStop(0, '#f0d49a');
    g.addColorStop(1, '#c99a4a');
    ctx.fillStyle = g;
  } else {
    ctx.fillStyle = 'rgba(20,28,44,0.92)';
  }
  rr(ctx, rect.x, rect.y, rect.w, rect.h, 8);
  ctx.fill();
  ctx.strokeStyle = hover
    ? 'rgba(248,214,140,0.95)'
    : selected
      ? 'rgba(255,235,186,0.8)'
      : 'rgba(226,192,122,0.24)';
  ctx.lineWidth = hover ? 2 : 1.2;
  ctx.stroke();
  ctx.fillStyle = selected ? '#3b2917' : 'rgba(242,226,196,0.86)';
  ctx.font = `700 13.5px ${KAI}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(label, rect.x + rect.w / 2, rect.y + rect.h / 2 + 1);
  ctx.restore();
}

function drawCheatPanel(ctx, game) {
  ctx.fillStyle = 'rgba(2,3,8,0.42)';
  ctx.fillRect(0, 0, VIEW.w, VIEW.h);

  const p = BTN.cheatPanel;
  drawGlassPanel(ctx, p, 14);

  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.font = `700 18px ${DISPLAY}`;
  ctx.fillStyle = '#ffc09a';
  ctx.fillText('作弊', p.x + 18, p.y + 24);
  ctx.textAlign = 'right';
  ctx.font = `400 10px ${KAI}`;
  ctx.fillStyle = 'rgba(240,200,170,0.45)';
  ctx.fillText('再点作弊关闭', p.x + p.w - 16, p.y + 24);

  drawCheatRow(ctx, BTN.cheatAdd, '+500 香火', game.mouse);
  drawCheatRow(ctx, BTN.cheatKill, '秒杀全场恶客', game.mouse);
  drawCheatRow(ctx, BTN.cheatMowers, '恢复所有门神', game.mouse);
  drawCheatRow(ctx, BTN.cheatWin, '直接通关', game.mouse);
}

function drawCheatRow(ctx, r, label, mouse) {
  const hover = inRect(mouse.x, mouse.y, r);
  const g = ctx.createLinearGradient(0, r.y, 0, r.y + r.h);
  g.addColorStop(0, hover ? 'rgba(150,50,38,0.96)' : 'rgba(92,28,22,0.9)');
  g.addColorStop(1, hover ? 'rgba(100,32,26,0.96)' : 'rgba(58,20,18,0.9)');
  ctx.fillStyle = g;
  rr(ctx, r.x, r.y, r.w, r.h, 8);
  ctx.fill();
  ctx.strokeStyle = hover ? 'rgba(244,200,120,0.75)' : 'rgba(226,150,96,0.35)';
  ctx.lineWidth = hover ? 1.6 : 1;
  ctx.stroke();
  ctx.fillStyle = '#f6ddb2';
  ctx.font = `700 15px ${KAI}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(label, r.x + r.w / 2, r.y + r.h / 2 + 1);
}

function drawFan(ctx, game) {
  const plant = game.menu.plant;
  const fan = getFan(plant);
  if (!fan) return;
  const hover = petalAt(plant, game.mouse.x, game.mouse.y);

  ctx.save();

  ctx.strokeStyle = 'rgba(240,200,120,0.55)';
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.arc(plant.x, plant.y + 8, 31, 0, Math.PI * 2);
  ctx.stroke();

  const a0 = ((fan.dir === -1 ? -150 : 30) * Math.PI) / 180;
  const a1 = ((fan.dir === -1 ? -30 : 150) * Math.PI) / 180;
  ctx.strokeStyle = 'rgba(226,180,96,0.35)';
  ctx.setLineDash([5, 7]);
  ctx.beginPath();
  ctx.arc(plant.x, plant.y, fan.radius, a0, a1);
  ctx.stroke();
  ctx.setLineDash([]);

  for (const petal of fan.petals) {
    ctx.strokeStyle = 'rgba(226,180,96,0.16)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(plant.x, plant.y + 10);
    ctx.lineTo(petal.x, petal.y);
    ctx.stroke();
  }

  for (const petal of fan.petals) {
    drawUpgradePetal(ctx, game, plant, petal, hover === petal);
  }

  let text;
  if (hover) {
    const st = pathStatus(plant, hover.path.id);
    text = st.ok
      ? `${hover.path.id}-${st.nextTier} ${st.name}：${st.desc} · ${st.cost} 香火`
      : st.reason;
  } else {
    text = '左键升阶 · 每路逐级购买 · 最多两路 · 点空白收起';
  }
  const ty = fan.dir === -1 ? Math.min(622, plant.y + 58) : Math.max(190, plant.y - 58);
  ctx.font = `400 13px ${KAI}`;
  const textW = ctx.measureText(text).width;
  const panelW = Math.min(660, textW + 28);
  const cx = Math.max(14 + panelW / 2, Math.min(VIEW.w - 14 - panelW / 2, plant.x));
  ctx.fillStyle = 'rgba(16,11,8,0.82)';
  rr(ctx, cx - panelW / 2, ty - 16, panelW, 32, 8);
  ctx.fill();
  ctx.strokeStyle = 'rgba(226,180,96,0.25)';
  ctx.lineWidth = 1;
  ctx.stroke();
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.lineWidth = 3;
  ctx.strokeStyle = 'rgba(14,10,8,0.85)';
  ctx.strokeText(text, cx, ty);
  ctx.fillStyle = hover ? '#f7e3b0' : 'rgba(240,224,190,0.65)';
  ctx.fillText(text, cx, ty);

  ctx.restore();
}

function drawUpgradePetal(ctx, game, plant, petal, hovered) {
  const path = petal.path;
  const st = pathStatus(plant, path.id);
  const x = petal.x - petal.w / 2;
  const y = petal.y - petal.h / 2 - (hovered ? 3 : 0);
  const w = petal.w;
  const h = petal.h;
  const dimmed = !st.ok && st.kind !== 'maxed';

  ctx.save();
  ctx.fillStyle = 'rgba(8,6,5,0.4)';
  rr(ctx, x + 2, y + 5, w, h, 10);
  ctx.fill();

  ctx.fillStyle = '#e8dcc2';
  rr(ctx, x, y, w, h, 10);
  ctx.fill();

  ctx.save();
  rr(ctx, x, y, w, h, 10);
  ctx.clip();
  ctx.fillStyle = path.color;
  ctx.fillRect(x, y, w, 8);
  if (dimmed) {
    ctx.fillStyle = 'rgba(30,24,18,0.28)';
    ctx.fillRect(x, y, w, h);
  }
  ctx.restore();

  ctx.strokeStyle = hovered ? '#f0c96e' : st.kind === 'maxed' ? '#e3b45e' : path.color;
  ctx.lineWidth = hovered ? 2.6 : 1.6;
  rr(ctx, x + 0.5, y + 0.5, w - 1, h - 1, 10);
  ctx.stroke();

  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = dimmed ? 'rgba(58,36,24,0.55)' : '#3a2418';
  ctx.font = `700 12px ${KAI}`;
  ctx.fillText(path.name, x + 7, y + 22);

  ctx.textAlign = 'right';
  ctx.font = `400 9px ${KAI}`;
  ctx.fillStyle = 'rgba(58,36,24,0.55)';
  ctx.fillText(`${path.id}-${st.tier}`, x + w - 7, y + 22);

  for (let k = 0; k < 3; k++) {
    ctx.beginPath();
    ctx.arc(petal.x - 12 + k * 12, y + 37, 3.2, 0, Math.PI * 2);
    ctx.fillStyle = k < st.tier ? path.color : 'rgba(58,36,24,0.16)';
    ctx.fill();
  }

  ctx.textAlign = 'center';
  if (st.ok) {
    ctx.font = `700 11.5px ${KAI}`;
    ctx.fillStyle = '#3a2418';
    ctx.fillText(st.name, petal.x, y + 53);

    const afford = game.sun >= st.cost;
    ctx.fillStyle = afford ? '#e2893a' : '#a33024';
    ctx.beginPath();
    ctx.arc(petal.x - 11, y + 68, 4, 0, Math.PI * 2);
    ctx.fill();
    ctx.font = `700 12px ${KAI}`;
    ctx.fillStyle = afford ? '#3a2418' : '#a33024';
    ctx.fillText(String(st.cost), petal.x + 4, y + 69);
  } else {
    ctx.font = `700 10px ${KAI}`;
    const label = st.kind === 'maxed' ? '已满级' : st.kind === 'locked3' ? '三级关闭' : '第三路关闭';
    ctx.fillStyle = st.kind === 'maxed' ? '#8a6a26' : '#8a2f24';
    ctx.fillText(label, petal.x, y + 53);
    if (st.kind !== 'maxed') {
      ctx.font = `700 11px ${KAI}`;
      ctx.fillStyle = '#8a6a26';
      ctx.fillText('锁', petal.x, y + 69);
    }
  }

  ctx.restore();
}

function drawButton(ctx, r, label, primary) {
  ctx.save();
  ctx.shadowColor = primary ? 'rgba(170,50,34,0.42)' : 'rgba(0,0,0,0.4)';
  ctx.shadowBlur = 16;
  ctx.shadowOffsetY = 5;
  const g = ctx.createLinearGradient(0, r.y, 0, r.y + r.h);
  if (primary) {
    g.addColorStop(0, '#d35a41');
    g.addColorStop(0.5, '#a8372a');
    g.addColorStop(1, '#7a221c');
  } else {
    g.addColorStop(0, 'rgba(27,38,58,0.98)');
    g.addColorStop(1, 'rgba(12,18,30,0.98)');
  }
  ctx.fillStyle = g;
  rr(ctx, r.x, r.y, r.w, r.h, 12);
  ctx.fill();
  ctx.restore();

  ctx.strokeStyle = primary ? 'rgba(244,207,132,0.92)' : 'rgba(226,192,122,0.56)';
  ctx.lineWidth = primary ? 2 : 1.4;
  rr(ctx, r.x, r.y, r.w, r.h, 12);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(255,244,210,0.18)';
  ctx.lineWidth = 1;
  rr(ctx, r.x + 4, r.y + 4, r.w - 8, r.h - 8, 9);
  ctx.stroke();

  ctx.fillStyle = 'rgba(255,248,222,0.16)';
  ctx.fillRect(r.x + 12, r.y + 1.5, r.w - 24, 1.2);

  ctx.save();
  ctx.shadowColor = 'rgba(20,10,8,0.55)';
  ctx.shadowBlur = 5;
  ctx.shadowOffsetY = 1;
  ctx.fillStyle = primary ? '#fff1ce' : '#f2e4c6';
  ctx.font = `700 ${primary ? 25 : 21}px ${KAI}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(label, r.x + r.w / 2, r.y + r.h / 2 + 2);
  ctx.restore();
}
