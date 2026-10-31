import { assets } from '../core/assets.js';
import { PLANT_TYPES, ZOMBIE_TYPES } from '../content.js';
import {
  drawShell, drawShellFront, shellPlant, catPlant, lobberPlant, torchPlant, starPlant, needlePlant, judgePlant, drawNewZombie
} from './newart.js';

function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}

function lilyPlant(ctx, t, bob, opt) {
  ctx.save();
  ctx.translate(0, bob * 0.5);
  ctx.fillStyle = '#224c45';
  ctx.beginPath();
  ctx.ellipse(0, 25, 32, 11, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#2f6e5d';
  ctx.beginPath();
  ctx.ellipse(0, 20, 36, 13, 0, 0.15, Math.PI * 2 - 0.15);
  ctx.fill();
  ctx.strokeStyle = 'rgba(206,220,154,0.7)';
  ctx.lineWidth = 1.2;
  for (let i = 0; i < 7; i++) {
    const a = -1.3 + i * 0.43;
    ctx.beginPath();
    ctx.moveTo(0, 22);
    ctx.lineTo(Math.cos(a) * 30, 19 + Math.sin(a) * 6);
    ctx.stroke();
  }
  ctx.fillStyle = '#e5dfae';
  for (let i = 0; i < 3; i++) {
    ctx.beginPath();
    ctx.ellipse(-6 + i * 6, 12 - i * 2, 3.5, 7, i * 0.2 - 0.2, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

function kelpPlant(ctx, t, bob, opt) {
  const pull = Math.max(0, Math.min(1, opt.pullT || 0));
  ctx.save();
  ctx.translate(0, bob * 0.4 + pull * 3);
  ctx.strokeStyle = '#315f53';
  ctx.lineWidth = 3;
  ctx.lineCap = 'round';
  for (let i = 0; i < 6; i++) {
    const sway = Math.sin(t * 2 + i * 1.3) * (6 + i * 1.5);
    ctx.beginPath();
    ctx.moveTo((i - 2.5) * 7, 28);
    ctx.quadraticCurveTo((i - 2.5) * 9 + sway, -4, (i - 2.5) * 11 - sway * 0.4, -34 - (i % 2) * 10);
    ctx.stroke();
  }
  ctx.strokeStyle = 'rgba(185,232,205,0.75)';
  ctx.lineWidth = 1.2;
  for (let i = 0; i < 4; i++) {
    const sway = Math.sin(t * 2.4 + i * 1.7) * 5;
    ctx.beginPath();
    ctx.moveTo((i - 1.5) * 10, 22);
    ctx.quadraticCurveTo((i - 1.5) * 12 + sway, -8, (i - 1.5) * 14 - sway, -28);
    ctx.stroke();
  }
  ctx.restore();
}

export function drawPlant(ctx, type, x, y, t, opt = {}) {
  const s = opt.scale ?? 1;
  const phase = opt.phase ?? 0;
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(s, s);
  if (!opt.noShadow) {
    ctx.save();
    ctx.fillStyle = 'rgba(0,0,0,0.28)';
    ctx.beginPath();
    ctx.ellipse(0, 30, type === 'wall' ? 30 : 22, type === 'wall' ? 9 : 6.5, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
  const bobAmp = {
    lantern: 3.2, shooter: 1.4, wall: 0.45, bomb: 0.7,
    bell: 0.7, censer: 1.1, umbrella: 1.3, lion: 1.0, mushroom: 0.5,
    cat: 1.6, lobber: 1.0, torch: 0.8, star: 1.5, needle: 0.6, judge: 0.8
  }[type] ?? 2;
  const bobSpeed = {
    lantern: 1.55, shooter: 2.4, wall: 0.95, bomb: 3.1,
    bell: 1.15, censer: 1.5, umbrella: 1.8, lion: 1.3, mushroom: 0.9,
    cat: 1.9, lobber: 1.6, torch: 2.2, star: 1.3, needle: 1.7, judge: 1.0
  }[type] ?? 2.2;
  const bob = Math.sin(t * bobSpeed + phase) * bobAmp;
  if (opt.shell) drawShell(ctx, opt.shell, t);
  if (type === 'censer') drawCenserGlow(ctx, t);
  const sprite = assets.plants[type];
  if (sprite) {
    const baseH = PLANT_TYPES[type]?.spriteH ?? 86;
    drawPlantSprite(ctx, type, sprite, t, bob, opt, baseH);
    drawPlantFx(ctx, type, t, opt, baseH);
  } else if (type === 'lantern') lanternPlant(ctx, t, bob);
  else if (type === 'shooter') shooterPlant(ctx, bob, opt);
  else if (type === 'wall') wallPlant(ctx, bob, opt);
  else if (type === 'bomb') bombPlant(ctx, t, bob, opt);
  else if (type === 'bell') bellPlant(ctx, bob, opt);
  else if (type === 'censer') censerPlant(ctx, t, bob);
  else if (type === 'umbrella') umbrellaPlant(ctx, t, bob, opt);
  else if (type === 'lion') lionPlant(ctx, t, bob, opt);
  else if (type === 'mushroom') mushroomPlant(ctx, t, bob, opt);
  else if (type === 'shell') shellPlant(ctx, t, bob);
  else if (type === 'cat') catPlant(ctx, t, bob, opt);
  else if (type === 'lobber') lobberPlant(ctx, t, bob, opt);
  else if (type === 'torch') torchPlant(ctx, t, bob, opt);
  else if (type === 'star') starPlant(ctx, t, bob, opt);
  else if (type === 'needle') needlePlant(ctx, t, bob, opt);
  else if (type === 'judge') judgePlant(ctx, t, bob, opt);
  else if (type === 'lily') lilyPlant(ctx, t, bob, opt);
  else if (type === 'kelp') kelpPlant(ctx, t, bob, opt);
  if (opt.shell) drawShellFront(ctx, opt.shell, t);
  drawPlantAura(ctx, t, opt);
  ctx.restore();
}

function drawPlantAura(ctx, t, opt) {
  const buff = opt.buff || 0;
  const haste = opt.haste || 0;
  if (buff <= 0 && haste <= 0) return;
  ctx.save();
  if (buff > 0) {
    const pulse = 0.65 + Math.sin(t * 5.2) * 0.15;
    ctx.strokeStyle = `rgba(236,118,64,${0.34 + buff * 1.2})`;
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.ellipse(0, 26, 25, 7.5, 0, 0, Math.PI * 2);
    ctx.stroke();
    for (let i = 0; i < 3; i++) {
      const k = (t * 0.55 + i / 3) % 1;
      ctx.globalAlpha = (1 - k) * 0.65;
      ctx.fillStyle = i % 2 ? '#ffca7a' : '#e86845';
      ctx.beginPath();
      ctx.arc(Math.sin(t * 2 + i * 2.1) * 13, 18 - k * 34, 1.8 + k * 1.4, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 0.18 + pulse * 0.1;
    ctx.setLineDash([4, 6]);
    ctx.lineDashOffset = -t * 18;
    ctx.strokeStyle = 'rgba(255,190,120,0.9)';
    ctx.beginPath();
    ctx.ellipse(0, 24, 28, 8.5, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);
  }
  if (haste > 0) {
    ctx.globalAlpha = 0.55;
    ctx.strokeStyle = 'rgba(126,205,208,0.9)';
    ctx.lineWidth = 1.4;
    for (let i = 0; i < 3; i++) {
      const a = t * 2.2 + i * (Math.PI * 2 / 3);
      ctx.beginPath();
      ctx.arc(0, -6, 31, a, a + 0.55);
      ctx.stroke();
    }
    ctx.globalAlpha = 0.7;
    ctx.fillStyle = '#a9e0dd';
    for (let i = 0; i < 2; i++) {
      const a = -t * 2.7 + i * Math.PI;
      ctx.beginPath();
      ctx.arc(Math.cos(a) * 20, -18 + Math.sin(a) * 8, 1.7, 0, Math.PI * 2);
      ctx.fill();
    }
  }
  ctx.restore();
}

function drawCenserGlow(ctx, t) {
  const ember = 0.5 + Math.sin(t * 5.2) * 0.16;
  const g = ctx.createRadialGradient(0, 4, 2, 0, 4, 42);
  g.addColorStop(0, `rgba(255,150,70,${0.22 * ember})`);
  g.addColorStop(1, 'rgba(255,120,50,0)');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(0, 4, 42, 0, Math.PI * 2);
  ctx.fill();
}

function plantMotion(type, t, phase, opt) {
  const recoil = Math.max(0, Math.min(1, opt.recoil ?? 0));
  const pulse = Math.max(0, Math.min(1, opt.pulse ?? 0));
  const fuse = Math.max(0, Math.min(1, opt.fuse ?? 0));
  const charge = Math.max(0, Math.min(1, opt.charge ?? 0));
  const bite = Math.max(0, Math.min(1, (opt.biteT ?? 0) / 0.2));
  let dx = 0;
  let dy = 0;
  let rot = 0;
  let sx = 1;
  let sy = 1;
  let pivotY = 28;
  const breath = Math.sin(t * 1.35 + phase);
  if (type === 'lantern') {
    pivotY = 0;
    dy = Math.sin(t * 1.55 + phase) * 3.4 - 4 * pulse;
    rot = Math.sin(t * 0.9 + phase) * 0.035;
    sx = 1 + breath * 0.012 + 0.09 * pulse;
    sy = 1 + breath * 0.014 + 0.09 * pulse;
  } else if (type === 'shooter') {
    dx = -5 * recoil + 1.8 * charge;
    dy = Math.sin(t * 1.5 + phase) * 0.5 + 1.8 * charge;
    rot = -0.055 * recoil + 0.03 * charge + Math.sin(t * 1.05 + phase) * 0.006;
    sx = 1 + 0.10 * recoil - 0.015 * charge;
    sy = 1 - 0.06 * recoil + 0.01 * charge;
  } else if (type === 'wall') {
    const hurt = 1 - Math.max(0, Math.min(1, opt.hpRatio ?? 1));
    const grind = Math.sin(t * 1.35 + phase);
    const press = Math.sin(t * 0.68 + phase * 0.7);
    sx = 1 + grind * 0.034 + press * 0.012;
    sy = 1 - grind * 0.03 - press * 0.014;
    dy = press * 1.4;
    dx = grind * 1.8 + Math.sin(t * 38) * 1.6 * bite;
    rot = grind * 0.016 + Math.sin(t * 0.8 + phase) * 0.009 + Math.sin(t * 31) * 0.012 * bite + hurt * Math.sin(t * 1.4) * 0.004;
  } else if (type === 'bell') {
    rot = Math.sin(t * 1.5 + phase) * 0.035 + Math.sin(t * 18) * 0.13 * pulse;
    dy = -2 * pulse;
    sx = 1 + 0.03 * pulse;
    sy = 1 - 0.02 * pulse;
    pivotY = 8;
  } else if (type === 'censer') {
    sx = 1 + 0.045 * charge + 0.07 * pulse;
    sy = 1 - 0.05 * charge + 0.07 * pulse;
    dy = 2.5 * charge - 2.5 * pulse;
    rot = Math.sin(t * 1.2 + phase) * 0.01;
  } else if (type === 'umbrella') {
    const chew = Math.max(0, Math.min(1, opt.chew ?? 0));
    rot = Math.sin(t * 1.7 + phase) * 0.025 + Math.sin(t * 20) * 0.08 * pulse + Math.sin(t * 9) * 0.035 * chew;
    sx = 1 - 0.08 * chew + 0.06 * pulse;
    sy = 1 + 0.05 * chew + 0.02 * pulse;
    dy = -2 * pulse + chew * 2 + Math.sin(t * 1.3 + phase) * 0.7;
  } else if (type === 'mushroom') {
    const arm = Math.max(0, Math.min(1, opt.arm ?? 1));
    const armed = !!opt.armed;
    dy = (1 - arm) * 12;
    if (armed) {
      const breathe = Math.sin(t * 1.9 + phase);
      const cap = Math.max(0, Math.sin(t * 3.2 + phase));
      sx = 1 + breathe * 0.028 + cap * 0.02;
      sy = 1 - breathe * 0.022 + cap * 0.012;
      dy = Math.sin(t * 1.6 + phase) * 1.2 - cap * 1.4;
      rot = Math.sin(t * 1.05 + phase) * 0.018;
    } else {
      const shiver = Math.sin(t * 5.2 + phase) * 0.6 * (1 - arm);
      const grow = 0.62 + arm * 0.3;
      dx = shiver;
      dy = (1 - arm) * 12 + Math.sin(t * 1.8 + phase) * 0.35;
      rot = shiver * 0.012;
      sx = grow;
      sy = grow;
    }
  } else if (type === 'lily') {
    const breathe = Math.sin(t * 1.7 + phase);
    dy = breathe * 0.9;
    sx = 1 + breathe * 0.018;
    sy = 1 - breathe * 0.012;
    rot = Math.sin(t * 0.8 + phase) * 0.012;
  } else if (type === 'kelp') {
    const pull = Math.max(0, Math.min(1, opt.pullT || 0));
    const sway = Math.sin(t * 2.2 + phase);
    dx = sway * (2 + pull * 4);
    dy = Math.cos(t * 1.8 + phase) * 1.4 - pull * 4;
    rot = sway * 0.035 + pull * 0.08;
    sx = 1 + pull * 0.06;
    sy = 1 - pull * 0.04;
  } else if (type === 'lion') {
    dx = 9 * recoil - 3 * charge;
    dy = -1.5 * charge + Math.sin(t * 1.7 + phase) * 0.4;
    rot = 0.055 * recoil - 0.03 * charge + Math.sin(t * 1.3 + phase) * 0.01 + Math.sin(t * 1.05 + phase) * 0.006;
    sx = 1 + 0.06 * recoil + 0.02 * charge;
    sy = 1 - 0.05 * recoil + 0.015 * charge;
  } else if (type === 'bomb') {
    const tremble = 0.5 + fuse * 3.2;
    dx = Math.sin(t * 47) * tremble;
    dy = Math.sin(t * 39 + 1.2) * tremble * 0.5;
    rot = Math.sin(t * 33) * 0.035 * fuse;
    const s = 1 + fuse * 0.07;
    sx = s;
    sy = s;
  } else if (type === 'cat') {
    const sway = Math.sin(t * 1.65 + phase);
    dx = Math.sin(t * 0.8 + phase) * 1.2 - 5 * recoil;
    dy = sway * 1.6 - 2.5 * pulse;
    rot = sway * 0.045 + Math.sin(t * 0.72 + phase) * 0.014 - 0.07 * recoil;
    sx = 1 + 0.05 * recoil + 0.02 * pulse;
    sy = 1 - 0.04 * recoil + 0.02 * pulse;
  } else if (type === 'lobber') {
    const wind = Math.max(0, Math.min(1, charge));
    dx = -3 * recoil + 1.5 * wind;
    dy = Math.sin(t * 1.75 + phase) * 1.2 + 2.2 * wind - 2 * pulse;
    rot = -0.045 * wind + 0.09 * recoil + Math.sin(t * 0.9 + phase) * 0.012;
    sx = 1 - 0.035 * wind + 0.05 * recoil;
    sy = 1 + 0.03 * wind - 0.035 * recoil;
  } else if (type === 'torch') {
    const flick = Math.sin(t * 12.5 + phase) * 0.022 + Math.sin(t * 21.7 + phase * 1.7) * 0.012;
    dx = Math.sin(t * 6.4 + phase) * 0.6;
    dy = Math.sin(t * 3.1 + phase) * 0.8 - 1.6 * pulse;
    rot = flick * 0.6;
    sx = 1 + flick + 0.035 * pulse;
    sy = 1 - flick + 0.055 * pulse;
  } else if (type === 'star') {
    dy = Math.sin(t * 1.4 + phase) * 2.6 - 2 * pulse;
    rot = Math.sin(t * 0.95 + phase) * 0.035 + Math.sin(t * 16) * 0.09 * pulse;
    sx = 1 + 0.035 * pulse + 0.03 * recoil;
    sy = 1 + 0.035 * pulse - 0.02 * recoil;
  } else if (type === 'needle') {
    dx = -4 * recoil + 1.2 * charge;
    dy = Math.sin(t * 1.6 + phase) * 0.7;
    rot = -0.05 * recoil + 0.02 * charge;
    sx = 1 + 0.06 * recoil - 0.01 * charge;
    sy = 1 - 0.03 * recoil;
  } else if (type === 'judge') {
    dx = -3 * recoil;
    dy = Math.sin(t * 0.9 + phase) * 1.2 - pulse;
    rot = Math.sin(t * 0.6 + phase) * 0.018 - 0.055 * recoil;
    sx = 1 + 0.035 * pulse + 0.02 * recoil;
    sy = 1 - 0.025 * pulse - 0.015 * recoil;
  }
  return { dx, dy, rot, sx, sy, pivotY };
}

function drawPlantSprite(ctx, type, img, t, bob, opt, baseH = 86) {
  const w = baseH * (img.width / img.height);
  const m = plantMotion(type, t, opt.phase ?? 0, opt);
  const pivotY = type === 'bell' ? 28 - baseH + 8 : m.pivotY;
  ctx.save();
  ctx.translate(m.dx, m.dy + bob * 0.55 + pivotY);
  ctx.rotate(m.rot);
  ctx.scale(m.sx, m.sy);
  ctx.translate(0, -pivotY);
  if (opt.fuse) {
    const glow = ctx.createRadialGradient(0, -18, 2, 0, -18, 48);
    glow.addColorStop(0, `rgba(255,150,70,${0.12 + opt.fuse * 0.28})`);
    glow.addColorStop(1, 'rgba(255,120,50,0)');
    ctx.fillStyle = glow;
    ctx.beginPath();
    ctx.arc(0, -18, 48, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.drawImage(img, -w / 2, 28 - baseH, w, baseH);
  ctx.restore();
}

function drawPlantFx(ctx, type, t, opt, baseH) {
  const recoil = Math.max(0, Math.min(1, opt.recoil ?? 0));
  const pulse = Math.max(0, Math.min(1, opt.pulse ?? 0));
  const fuse = Math.max(0, Math.min(1, opt.fuse ?? 0));
  const charge = Math.max(0, Math.min(1, opt.charge ?? 0));
  const bite = Math.max(0, Math.min(1, (opt.biteT ?? 0) / 0.2));
  if (type === 'lantern') {
    ctx.save();
    for (let i = 0; i < 2; i++) {
      const p = (t * 0.3 + i * 0.5) % 1;
      ctx.globalAlpha = (1 - p) * 0.35;
      ctx.fillStyle = '#ffe6a8';
      ctx.beginPath();
      ctx.arc(Math.sin(t * 1.2 + i * 2.2) * 24, -18 - p * 26, 1.4, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }
  if (type === 'shooter' && charge > 0.25 && recoil < 0.2) {
    ctx.save();
    ctx.globalAlpha = charge * 0.65;
    const g = ctx.createRadialGradient(25, -13, 1, 25, -13, 12 + charge * 8);
    g.addColorStop(0, 'rgba(255,242,196,0.95)');
    g.addColorStop(0.5, 'rgba(255,196,96,0.4)');
    g.addColorStop(1, 'rgba(255,150,60,0)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(25, -13, 12 + charge * 8, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
  if (type === 'shooter' && recoil > 0.2) {
    const k = recoil;
    ctx.save();
    ctx.translate(26, -12);
    ctx.globalAlpha = k;
    const g = ctx.createRadialGradient(0, 0, 2, 0, 0, 18);
    g.addColorStop(0, 'rgba(255,244,200,0.95)');
    g.addColorStop(0.5, 'rgba(255,190,90,0.45)');
    g.addColorStop(1, 'rgba(255,150,60,0)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(0, 0, 18, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = 'rgba(255,225,150,0.8)';
    ctx.lineWidth = 2;
    for (let i = 0; i < 4; i++) {
      const a = (i / 4) * Math.PI * 2 + 0.4;
      ctx.beginPath();
      ctx.moveTo(Math.cos(a) * 5, Math.sin(a) * 5);
      ctx.lineTo(Math.cos(a) * (12 + k * 8), Math.sin(a) * (12 + k * 8));
      ctx.stroke();
    }
    ctx.globalAlpha = k * 0.9;
    for (let i = 0; i < 2; i++) {
      ctx.save();
      ctx.translate(10 + i * 7, -14 - i * 8);
      ctx.rotate(-0.55 + i * 0.8 + Math.sin(t * 9 + i) * 0.08);
      ctx.fillStyle = i ? '#f2d28a' : '#e8c07a';
      ctx.fillRect(-4, -9, 8, 18);
      ctx.strokeStyle = 'rgba(150,54,38,0.85)';
      ctx.lineWidth = 1;
      ctx.strokeRect(-4, -9, 8, 18);
      ctx.fillStyle = '#a83a2e';
      ctx.fillRect(-1.5, -5, 3, 10);
      ctx.restore();
    }
    ctx.strokeStyle = 'rgba(255,236,180,0.7)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(0, 0, 18 + (1 - k) * 16, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }
  if (type === 'lantern' && pulse > 0) {
    const k = pulse / 0.45;
    ctx.save();
    ctx.globalAlpha = Math.min(1, k) * 0.7;
    const g = ctx.createRadialGradient(0, -16, 4, 0, -16, 52);
    g.addColorStop(0, 'rgba(255,235,170,0.55)');
    g.addColorStop(1, 'rgba(255,170,70,0)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(0, -16, 52, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#fff0b8';
    for (let i = 0; i < 4; i++) {
      const a = (i / 4) * Math.PI * 2 + t;
      const r = 24 + (1 - k) * 10;
      ctx.beginPath();
      ctx.arc(Math.cos(a) * r, -16 + Math.sin(a) * r * 0.6, 1.8, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }
  if (type === 'bell' && pulse > 0) {
    ctx.save();
    ctx.globalAlpha = Math.min(1, pulse / 0.55) * 0.65;
    ctx.strokeStyle = 'rgba(240,210,130,0.8)';
    ctx.lineWidth = 1.8;
    for (let i = 0; i < 2; i++) {
      const r = 30 + i * 9 + (0.55 - pulse) * 20;
      ctx.beginPath();
      ctx.arc(0, -4, r, -1.1, 1.1);
      ctx.stroke();
    }
    ctx.restore();
  }
  if (type === 'censer' && pulse > 0) {
    const k = pulse / 0.7;
    ctx.save();
    ctx.globalAlpha = Math.min(1, k) * 0.55;
    ctx.fillStyle = 'rgba(220,208,184,0.8)';
    for (let i = 0; i < 3; i++) {
      const a = t * 0.8 + (i / 3) * Math.PI * 2;
      const r = 14 + i * 8;
      ctx.beginPath();
      ctx.arc(Math.cos(a) * r * 0.5, -36 - i * 7 - (1 - k) * 8, 3.5 + i, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }
  if (type === 'umbrella' && (pulse > 0 || (opt.chew || 0) > 0)) {
    const k = Math.max(pulse / 0.6, opt.chew || 0);
    ctx.save();
    ctx.globalAlpha = Math.min(1, k) * 0.55;
    ctx.strokeStyle = 'rgba(236,190,116,0.95)';
    ctx.lineWidth = 1.4;
    for (let i = 0; i < 3; i++) {
      const a = t * 2.4 + i * 2.1;
      ctx.beginPath();
      ctx.arc(0, -8, 34 + i * 5, a, a + 0.8);
      ctx.stroke();
    }
    ctx.globalAlpha = Math.min(1, k) * 0.8;
    ctx.fillStyle = '#f0d49a';
    for (let i = 0; i < 4; i++) {
      const p2 = (t * 0.8 + i / 4) % 1;
      ctx.save();
      ctx.translate(Math.sin(t * 2 + i * 2.2) * 20, 10 - p2 * 34);
      ctx.rotate(t * 2 + i);
      ctx.fillRect(-3, -5, 6, 10);
      ctx.restore();
    }
    if (pulse > 0.1) {
      ctx.globalAlpha = Math.min(1, pulse / 0.55) * 0.9;
      ctx.fillStyle = '#f6ecd4';
      ctx.beginPath();
      ctx.moveTo(-11, -12);
      ctx.lineTo(-5, -3);
      ctx.lineTo(-1, -12);
      ctx.closePath();
      ctx.moveTo(11, -12);
      ctx.lineTo(5, -3);
      ctx.lineTo(1, -12);
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = 'rgba(188,62,44,0.85)';
      ctx.lineWidth = 1.8;
      ctx.beginPath();
      ctx.arc(0, 4, 12, 0.15, Math.PI - 0.15);
      ctx.stroke();
    }
    ctx.restore();
  }
  if (type === 'mushroom' && !opt.armed) {
    const arm = Math.max(0, Math.min(1, opt.arm ?? 0));
    const breath = 0.5 + Math.sin(t * 2.4) * 0.5;
    ctx.save();
    ctx.globalAlpha = 0.14 + breath * 0.1;
    ctx.fillStyle = 'rgba(138,176,104,0.8)';
    ctx.beginPath();
    ctx.ellipse(0, 30, 33, 10, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;
    const soil = ctx.createLinearGradient(0, 16, 0, 34);
    soil.addColorStop(0, '#5b4631');
    soil.addColorStop(1, '#2a2018');
    ctx.fillStyle = soil;
    ctx.beginPath();
    ctx.ellipse(0, 30, 30 + arm * 3, 13, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#453427';
    ctx.beginPath();
    ctx.ellipse(-7, 26, 13, 5, -0.2, 0, Math.PI * 2);
    ctx.ellipse(11, 27, 9, 4, 0.25, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#6d553c';
    ctx.beginPath();
    ctx.ellipse(-13, 25, 3.5, 2, 0, 0, Math.PI * 2);
    ctx.ellipse(4, 23, 2.8, 1.7, 0, 0, Math.PI * 2);
    ctx.ellipse(17, 29, 2.2, 1.5, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = 'rgba(28,20,14,0.7)';
    ctx.lineWidth = 1.1;
    ctx.beginPath();
    ctx.moveTo(-15, 28);
    ctx.lineTo(-6, 32);
    ctx.moveTo(7, 27);
    ctx.lineTo(14, 32);
    ctx.stroke();
    if (arm > 0.55) {
      ctx.globalAlpha = (arm - 0.55) * 1.8;
      ctx.strokeStyle = 'rgba(198,222,150,0.6)';
      ctx.lineWidth = 1.2;
      ctx.setLineDash([2, 4]);
      ctx.beginPath();
      ctx.arc(0, 24, 20 + breath * 4, 0.15, Math.PI - 0.15);
      ctx.stroke();
      ctx.setLineDash([]);
    }
    ctx.restore();
  }
  if (type === 'mushroom' && opt.armed) {
    const glow = 0.55 + Math.sin(t * 5.5) * 0.25;
    const breathe = 0.5 + Math.sin(t * 2.1) * 0.5;
    ctx.save();
    const capGlow = ctx.createRadialGradient(0, -30, 2, 0, -30, 52);
    capGlow.addColorStop(0, `rgba(255,224,150,${0.2 + glow * 0.18})`);
    capGlow.addColorStop(0.45, `rgba(178,220,126,${0.1 + glow * 0.12})`);
    capGlow.addColorStop(1, 'rgba(110,160,90,0)');
    ctx.fillStyle = capGlow;
    ctx.beginPath();
    ctx.arc(0, -30, 52, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = `rgba(178,226,140,${0.38 + glow * 0.22})`;
    ctx.lineWidth = 1.5;
    ctx.setLineDash([4, 6]);
    ctx.lineDashOffset = -t * 18;
    ctx.beginPath();
    ctx.ellipse(0, 26, 32 + breathe * 3, 9, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = `rgba(255,214,132,${0.5 + glow * 0.3})`;
    ctx.beginPath();
    ctx.arc(0, -32, 2.4 + glow * 1.2, 0, Math.PI * 2);
    ctx.fill();
    for (let i = 0; i < 6; i++) {
      const q = (t * 0.32 + i / 6) % 1;
      const sway = Math.sin(t * 1.7 + i * 2.2) * (7 + q * 8);
      ctx.globalAlpha = (1 - q) * 0.55;
      ctx.fillStyle = i % 2 ? '#e9f0b0' : '#b7d884';
      ctx.beginPath();
      ctx.arc(sway, -20 - q * 34, 1.4 + q * 2.2, 0, Math.PI * 2);
      ctx.fill();
    }
    if (pulse > 0) {
      const k = 1 - Math.min(1, pulse / 0.6);
      ctx.globalAlpha = Math.min(1, pulse / 0.6) * 0.55;
      ctx.strokeStyle = 'rgba(238,220,146,0.9)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(0, 5, 22 + k * 38, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }
  if (type === 'lily') {
    ctx.save();
    ctx.globalAlpha = 0.28 + Math.sin(t * 2.2) * 0.08;
    ctx.strokeStyle = 'rgba(160,224,212,0.85)';
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.ellipse(0, 28, 34 + Math.sin(t * 1.6) * 3, 10, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = 0.55;
    ctx.fillStyle = '#d9edc6';
    for (let i = 0; i < 3; i++) {
      const q = (t * 0.5 + i / 3) % 1;
      ctx.beginPath();
      ctx.arc(Math.sin(t + i * 2) * 20, 14 - q * 24, 1.2 + q * 1.4, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }
  if (type === 'kelp') {
    const pull = Math.max(0, Math.min(1, opt.pullT || 0));
    ctx.save();
    ctx.globalAlpha = 0.3 + pull * 0.35;
    const g = ctx.createRadialGradient(0, 4, 2, 0, 4, 34);
    g.addColorStop(0, `rgba(174,232,205,${0.35 + pull * 0.3})`);
    g.addColorStop(1, 'rgba(90,160,140,0)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(0, 4, 34, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#c5ead8';
    for (let i = 0; i < 4; i++) {
      const q = (t * 0.8 + i / 4) % 1;
      ctx.globalAlpha = (1 - q) * 0.6;
      ctx.beginPath();
      ctx.arc(Math.sin(t * 2 + i * 2) * 16, 8 - q * 30, 1.4 + q * 2, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }
  if (type === 'lion' && recoil > 0.2) {
    ctx.save();
    ctx.globalAlpha = recoil * 0.55;
    ctx.fillStyle = 'rgba(206,184,146,0.8)';
    for (let i = 0; i < 3; i++) {
      ctx.beginPath();
      ctx.ellipse(16 + i * 9, 28 - i * 2, 7 + i * 2, 2.6 + i, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = recoil * 0.85;
    ctx.strokeStyle = 'rgba(255,230,170,0.85)';
    ctx.lineWidth = 2.2;
    ctx.lineCap = 'round';
    for (let i = 0; i < 3; i++) {
      ctx.beginPath();
      ctx.moveTo(12 + i * 3, -18 + i * 8);
      ctx.quadraticCurveTo(28 + i * 5, -22 + i * 9, 38 + i * 5, -12 + i * 10);
      ctx.stroke();
    }
    ctx.restore();
  }
  if (type === 'lion' && charge > 0.45 && recoil < 0.2) {
    ctx.save();
    ctx.globalAlpha = charge * 0.35;
    ctx.fillStyle = 'rgba(220,190,150,0.7)';
    ctx.beginPath();
    ctx.ellipse(-16, 29, 7, 2.2, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
  if (type === 'cat') {
    ctx.save();
    for (let i = 0; i < 3; i++) {
      const p2 = (t * 0.42 + i / 3) % 1;
      ctx.globalAlpha = (1 - p2) * 0.42;
      ctx.fillStyle = i % 2 ? '#ffc46e' : '#ff8a4a';
      ctx.beginPath();
      ctx.arc(Math.sin(t * 1.8 + i * 2.4) * 18, 6 - p2 * 38, 1.6 + p2 * 1.6, 0, Math.PI * 2);
      ctx.fill();
    }
    if (recoil > 0.2) {
      const k = recoil;
      ctx.globalAlpha = k * 0.28;
      ctx.fillStyle = '#ff9a4a';
      ctx.beginPath();
      ctx.arc(-2, -18, 27, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = k * 0.32;
      ctx.fillStyle = '#fff0b0';
      ctx.beginPath();
      ctx.arc(-2, -18, 12, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = k * 0.85;
      ctx.lineCap = 'round';
      ctx.strokeStyle = 'rgba(255,206,122,0.85)';
      ctx.lineWidth = 4.2;
      ctx.beginPath();
      ctx.moveTo(-4, 18);
      ctx.bezierCurveTo(-18, -4, 4, -34, 30 + k * 6, -42);
      ctx.stroke();
      ctx.strokeStyle = 'rgba(255,248,214,0.9)';
      ctx.lineWidth = 1.4;
      ctx.beginPath();
      ctx.moveTo(-4, 18);
      ctx.bezierCurveTo(-16, -3, 4, -32, 29 + k * 6, -40);
      ctx.stroke();
      for (let i = 0; i < 5; i++) {
        const a = -0.9 + i * 0.36;
        const r = 22 + (i % 3) * 7;
        ctx.globalAlpha = k * (0.72 - i * 0.08);
        ctx.fillStyle = i % 2 ? '#ffd88a' : '#ff8a44';
        ctx.beginPath();
        ctx.arc(10 + Math.cos(a) * r, -18 + Math.sin(a) * r * 0.7, 1.8 + (i % 2), 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.restore();
  }
  if (type === 'lobber') {
    ctx.save();
    if (charge > 0.2 && recoil < 0.3) {
      ctx.globalAlpha = charge * 0.6;
      const g = ctx.createRadialGradient(17, -26, 1, 17, -26, 12);
      g.addColorStop(0, 'rgba(255,246,214,0.9)');
      g.addColorStop(1, 'rgba(232,204,156,0)');
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(17, -26, 12, 0, Math.PI * 2);
      ctx.fill();
    }
    if (recoil > 0.15) {
      ctx.globalAlpha = recoil * 0.55;
      ctx.fillStyle = 'rgba(245,226,188,0.9)';
      for (let i = 0; i < 4; i++) {
        ctx.beginPath();
        ctx.ellipse(18 + i * 8, -24 - i * 4, 2.2, 1.4, -0.5, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.restore();
  }
  if (type === 'torch') {
    ctx.save();
    const flame = 0.7 + Math.sin(t * 11) * 0.15 + Math.sin(t * 23) * 0.08;
    ctx.globalAlpha = 0.22 + flame * 0.12 + pulse * 0.2;
    const g = ctx.createRadialGradient(0, -34, 2, 0, -30, 40);
    g.addColorStop(0, 'rgba(255,230,150,0.85)');
    g.addColorStop(0.45, 'rgba(255,143,66,0.4)');
    g.addColorStop(1, 'rgba(220,80,40,0)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(0, -30, 40, 0, Math.PI * 2);
    ctx.fill();
    for (let i = 0; i < 4; i++) {
      const p2 = (t * 0.55 + i / 4) % 1;
      ctx.globalAlpha = (1 - p2) * (0.4 + pulse * 0.2);
      ctx.fillStyle = i % 2 ? '#ffd98a' : '#ff9a52';
      ctx.beginPath();
      ctx.arc(Math.sin(t * 2.2 + i * 2.1) * 10, -30 - p2 * 34, 1.4 + p2 * 2, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }
  if (type === 'star') {
    ctx.save();
    ctx.globalAlpha = 0.3 + pulse * 0.45;
    ctx.strokeStyle = 'rgba(255,218,132,0.9)';
    ctx.lineWidth = 1.4;
    const r = 28 + Math.sin(t * 2.2) * 3 + pulse * 12;
    for (let i = 0; i < 5; i++) {
      const a = -Math.PI / 2 + i * (Math.PI * 2 / 5) + Math.sin(t * 0.8) * 0.05;
      ctx.beginPath();
      ctx.moveTo(Math.cos(a) * (r - 10), Math.sin(a) * (r - 10));
      ctx.lineTo(Math.cos(a) * r, Math.sin(a) * r);
      ctx.stroke();
    }
    if (pulse > 0.1) {
      ctx.globalAlpha = pulse * 0.5;
      ctx.beginPath();
      ctx.arc(0, -18, 16 + (1 - pulse) * 28, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }
  if (type === 'needle') {
    ctx.save();
    ctx.globalAlpha = 0.18 + charge * 0.3;
    ctx.strokeStyle = 'rgba(238,238,220,0.8)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(-12, -10);
    ctx.lineTo(18, -24);
    ctx.stroke();
    if (recoil > 0.15) {
      ctx.globalAlpha = recoil * 0.55;
      ctx.strokeStyle = 'rgba(250,250,235,0.95)';
      ctx.lineWidth = 1.2;
      for (let i = 0; i < 3; i++) {
        ctx.beginPath();
        ctx.moveTo(20, -22 + i * 4);
        ctx.lineTo(38 + i * 6, -24 + i * 6);
        ctx.stroke();
      }
    }
    ctx.restore();
  }
  if (type === 'judge') {
    ctx.save();
    for (let i = 0; i < 3; i++) {
      const p2 = (t * 0.22 + i / 3) % 1;
      ctx.globalAlpha = (1 - p2) * 0.2;
      ctx.fillStyle = 'rgba(224,204,168,0.8)';
      ctx.beginPath();
      ctx.arc(Math.sin(t * 0.7 + i * 2) * 8, -48 - p2 * 26, 2 + p2 * 4, 0, Math.PI * 2);
      ctx.fill();
    }
    if (pulse > 0.1) {
      ctx.globalAlpha = pulse * 0.55;
      ctx.strokeStyle = 'rgba(255,198,108,0.9)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(0, -16, 30 + (1 - pulse) * 30, 0, Math.PI * 2);
      ctx.stroke();
      ctx.fillStyle = 'rgba(244,214,150,0.9)';
      for (let i = 0; i < 4; i++) {
        const a = t * 1.8 + i * (Math.PI / 2);
        ctx.fillRect(Math.cos(a) * 34 - 2, -16 + Math.sin(a) * 22 - 4, 4, 8);
      }
    }
    ctx.restore();
  }
  if (type === 'wall') {
    const phase = opt.phase ?? 0;
    ctx.save();
    for (let i = 0; i < 3; i++) {
      const p = ((t * 0.42 + phase + i / 3) % 1);
      ctx.globalAlpha = (1 - p) * 0.24;
      ctx.fillStyle = 'rgba(205,188,150,0.85)';
      ctx.beginPath();
      ctx.ellipse(
        -18 + i * 16 + Math.sin(t * 1.3 + i * 2.1) * 3,
        27 - p * 13,
        2.2 + p * 2, 1.1 + p * 1.2,
        0, 0, Math.PI * 2
      );
      ctx.fill();
    }
    ctx.globalAlpha = 0.13 + Math.sin(t * 1.1 + phase) * 0.035;
    ctx.strokeStyle = 'rgba(224,196,140,0.85)';
    ctx.lineWidth = 1.2;
    ctx.setLineDash([4, 6]);
    ctx.lineDashOffset = -t * 8;
    ctx.beginPath();
    ctx.ellipse(0, 25, 32, 8, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.restore();
  }
  if (type === 'wall' && recoil > 0.15) {
    ctx.save();
    ctx.globalAlpha = recoil * 0.7;
    for (let i = 0; i < 3; i++) {
      const a = -0.5 + i * 0.4;
      ctx.fillStyle = i % 2 ? '#b9a98c' : '#d3c4a2';
      ctx.beginPath();
      ctx.moveTo(20 + i * 5, -10 + Math.sin(a) * 10);
      ctx.lineTo(28 + i * 7, -14 + Math.sin(a) * 13);
      ctx.lineTo(25 + i * 6, -4 + Math.sin(a) * 11);
      ctx.closePath();
      ctx.fill();
    }
    ctx.restore();
  }
  if (type === 'wall' && bite > 0) {
    ctx.save();
    ctx.globalAlpha = bite * 0.5;
    ctx.fillStyle = 'rgba(196,176,142,0.8)';
    for (let i = 0; i < 3; i++) {
      ctx.beginPath();
      ctx.ellipse(-24 - i * 7, 22 + (i % 2) * 4, 4 + i, 1.6 + i * 0.5, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }
  if (type === 'bomb' && fuse > 0.6) {
    ctx.save();
    const k = (fuse - 0.6) / 0.4;
    ctx.globalAlpha = 0.25 + Math.sin(t * 18) * 0.12;
    ctx.strokeStyle = 'rgba(255,120,70,0.85)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(0, 2, 30 + k * 8, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }
  if (type === 'bomb' && fuse > 0) {
    ctx.save();
    ctx.globalAlpha = 0.4 + fuse * 0.5;
    ctx.fillStyle = '#ffd27a';
    for (let i = 0; i < 4; i++) {
      const a = t * 9 + i * 1.9;
      ctx.beginPath();
      ctx.arc(8 + Math.cos(a) * 8, -baseH + 20 + Math.sin(a) * 5, 1.8 + fuse * 1.5, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }
  if (type === 'wall') {
    const dmg = 1 - Math.max(0, Math.min(1, opt.hpRatio ?? 1));
    if (dmg > 0.18) {
      ctx.save();
      ctx.globalAlpha = 0.35 + dmg * 0.5;
      ctx.strokeStyle = 'rgba(38,31,25,0.9)';
      ctx.lineWidth = 1.4 + dmg * 1.2;
      ctx.beginPath();
      ctx.moveTo(-16, -18);
      ctx.lineTo(-11, -7);
      ctx.lineTo(-15, 4);
      ctx.lineTo(-9, 14);
      ctx.stroke();
      if (dmg > 0.5) {
        ctx.beginPath();
        ctx.moveTo(18, -10);
        ctx.lineTo(12, -1);
        ctx.lineTo(17, 9);
        ctx.lineTo(10, 20);
        ctx.stroke();
      }
      ctx.restore();
    }
  }
}

function lanternPlant(ctx, t, bob) {
  ctx.save();
  ctx.translate(0, bob - 10);
  const glow = ctx.createRadialGradient(0, 0, 4, 0, 0, 54);
  glow.addColorStop(0, 'rgba(255,176,78,0.34)');
  glow.addColorStop(1, 'rgba(255,140,50,0)');
  ctx.fillStyle = glow;
  ctx.beginPath();
  ctx.arc(0, 0, 54, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = '#d9a441';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(0, -30);
  ctx.lineTo(0, -42);
  ctx.stroke();
  ctx.fillStyle = '#d9a441';
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 1.6;
  rr(ctx, -10, -38, 20, 7, 3);
  ctx.fill();
  ctx.stroke();

  ctx.fillStyle = '#c33a2c';
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.ellipse(0, 0, 21, 26, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();

  ctx.strokeStyle = 'rgba(92,24,18,0.45)';
  ctx.lineWidth = 1;
  for (const rx of [7, 14]) {
    ctx.beginPath();
    ctx.ellipse(0, 0, rx, 26, 0, -1.1, 1.1);
    ctx.stroke();
  }

  ctx.fillStyle = '#241410';
  ctx.beginPath();
  ctx.arc(-7, -4, 2.6, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(7, -4, 2.6, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = 'rgba(255,244,214,0.9)';
  ctx.beginPath();
  ctx.arc(-7.8, -5, 0.9, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(6.2, -5, 0.9, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = '#331713';
  ctx.lineWidth = 1.4;
  ctx.beginPath();
  ctx.arc(0, 2, 5, 0.25, Math.PI - 0.25);
  ctx.stroke();

  ctx.fillStyle = 'rgba(255,150,110,0.45)';
  ctx.beginPath();
  ctx.ellipse(-12, 5, 4, 2.4, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.ellipse(12, 5, 4, 2.4, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#d9a441';
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 1.6;
  rr(ctx, -9, 24, 18, 6, 2);
  ctx.fill();
  ctx.stroke();
  ctx.strokeStyle = '#d9a441';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(0, 30);
  ctx.lineTo(0, 40);
  ctx.stroke();
  ctx.fillStyle = '#c33a2c';
  ctx.beginPath();
  ctx.moveTo(-5, 40);
  ctx.lineTo(5, 40);
  ctx.lineTo(0, 51);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

function shooterPlant(ctx, bob, opt) {
  ctx.save();
  ctx.translate(opt.recoil ? -3 : 0, bob);
  const up = opt.up || { 1: 0, 2: 0, 3: 0 };
  const count = 5 + (up[1] || 0) * 2;
  for (let i = 0; i < count; i++) {
    const k = count === 1 ? 0.5 : i / (count - 1);
    const sx = -15 + k * 30;
    const sy = -44 - Math.sin(k * Math.PI) * 5;
    ctx.strokeStyle = '#c9a15c';
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(sx, sy);
    ctx.lineTo(sx * 0.7, -22);
    ctx.stroke();
    ctx.fillStyle = up[3] > 0 ? '#e3b45e' : '#c33a2c';
    ctx.beginPath();
    ctx.arc(sx, sy, 3, 0, Math.PI * 2);
    ctx.fill();
  }

  ctx.fillStyle = '#c9a15c';
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 2;
  rr(ctx, -19, -24, 38, 50, 11);
  ctx.fill();
  ctx.stroke();

  ctx.fillStyle = '#7c5f38';
  ctx.beginPath();
  ctx.ellipse(0, -24, 19, 7, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();

  ctx.fillStyle = '#b03a2c';
  rr(ctx, -9, -8, 18, 30, 3);
  ctx.fill();
  ctx.fillStyle = '#e3b45e';
  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.lineTo(5, 7);
  ctx.lineTo(0, 14);
  ctx.lineTo(-5, 7);
  ctx.closePath();
  ctx.fill();

  if (up[2] > 0) {
    ctx.fillStyle = '#4f8a86';
    ctx.strokeStyle = '#191210';
    ctx.lineWidth = 1.6;
    rr(ctx, -29, 4, 11, 20, 4);
    ctx.fill();
    ctx.stroke();
    if (up[2] >= 2) {
      rr(ctx, 18, 4, 11, 20, 4);
      ctx.fill();
      ctx.stroke();
    }
  }

  if (up[3] > 0) {
    ctx.strokeStyle = '#e3b45e';
    ctx.lineWidth = 2;
    rr(ctx, -19, -24, 38, 50, 11);
    ctx.stroke();
  }

  ctx.fillStyle = '#241410';
  ctx.beginPath();
  ctx.arc(-13, 1, 2.2, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(13, 1, 2.2, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = '#3a2418';
  ctx.lineWidth = 1.3;
  ctx.beginPath();
  ctx.arc(0, 18, 4, 0.2, Math.PI - 0.2);
  ctx.stroke();

  ctx.strokeStyle = '#8a6a36';
  ctx.lineWidth = 3;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(-19, 6);
  ctx.lineTo(-26, 14);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(19, 6);
  ctx.lineTo(26, 14);
  ctx.stroke();
  ctx.restore();
}

function wallPlant(ctx, bob, opt) {
  ctx.save();
  ctx.translate(0, bob * 0.5);
  ctx.fillStyle = '#8b877b';
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 2.4;
  rr(ctx, -28, -26, 56, 52, 13);
  ctx.fill();
  ctx.stroke();

  ctx.fillStyle = '#a5a092';
  ctx.beginPath();
  ctx.ellipse(0, -26, 28, 9, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();

  ctx.fillStyle = '#4f4b43';
  ctx.beginPath();
  ctx.ellipse(0, -26, 7, 3.2, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = 'rgba(72,68,60,0.6)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.arc(0, 0, 20, 0.2, 1.1);
  ctx.stroke();
  ctx.beginPath();
  ctx.arc(0, 0, 20, 2.1, 3.0);
  ctx.stroke();

  ctx.fillStyle = '#241c17';
  ctx.beginPath();
  ctx.arc(-11, -2, 3, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(11, -2, 3, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = '#3b332a';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(-16, -9);
  ctx.lineTo(-6, -7);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(16, -9);
  ctx.lineTo(6, -7);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(-8, 12);
  ctx.lineTo(8, 12);
  ctx.stroke();

  if ((opt.hpRatio ?? 1) < 0.55) {
    ctx.strokeStyle = 'rgba(35,30,24,0.65)';
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.moveTo(-18, -20);
    ctx.lineTo(-12, -8);
    ctx.lineTo(-16, 2);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(16, 6);
    ctx.lineTo(10, 14);
    ctx.lineTo(15, 22);
    ctx.stroke();
  }
  ctx.restore();
}

function bombPlant(ctx, t, bob, opt) {
  const fuse = opt.fuse ?? 0;
  const pulse = 1 + Math.sin(t * 13) * 0.03 + fuse * 0.06;
  ctx.save();
  ctx.translate(0, bob);
  ctx.scale(pulse, pulse);

  ctx.fillStyle = 'rgba(255,120,50,' + (0.08 + fuse * 0.22) + ')';
  ctx.beginPath();
  ctx.arc(0, 0, 38, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#c33a2c';
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 2;
  rr(ctx, -17, -24, 34, 48, 8);
  ctx.fill();
  ctx.stroke();

  ctx.fillStyle = '#e3b45e';
  ctx.fillRect(-17, -10, 34, 5);
  ctx.fillRect(-17, 8, 34, 5);

  ctx.strokeStyle = 'rgba(90,20,14,0.6)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(0, -24);
  ctx.lineTo(0, 24);
  ctx.stroke();

  ctx.strokeStyle = '#6b4a24';
  ctx.lineWidth = 2.4;
  ctx.beginPath();
  ctx.moveTo(10, -24);
  ctx.quadraticCurveTo(22, -34, 18, -44);
  ctx.stroke();

  const flick = 1 + Math.sin(t * 20) * 0.3;
  ctx.fillStyle = 'rgba(255,200,90,0.35)';
  ctx.beginPath();
  ctx.arc(18, -45, 8 * flick, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#ffcf6a';
  ctx.beginPath();
  ctx.arc(18, -45, 3.4, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#241410';
  ctx.beginPath();
  ctx.arc(-8, -2, 2.4, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(8, -2, 2.4, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = '#2b1410';
  ctx.lineWidth = 1.6;
  ctx.beginPath();
  ctx.moveTo(-8, 15);
  ctx.lineTo(-3, 11);
  ctx.lineTo(2, 15);
  ctx.lineTo(7, 11);
  ctx.stroke();
  ctx.restore();
}

function bellPlant(ctx, bob, opt) {
  ctx.save();
  ctx.translate(0, bob);
  if ((opt.pulse ?? 0) > 0) {
    const k = 1 - opt.pulse / 0.55;
    ctx.strokeStyle = 'rgba(255,214,120,0.55)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(0, 2, 30 + k * 22, 0, Math.PI * 2);
    ctx.stroke();
  }

  ctx.fillStyle = '#c79a3b';
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(-21, 24);
  ctx.quadraticCurveTo(-24, 2, -17, -14);
  ctx.quadraticCurveTo(-10, -24, 0, -24);
  ctx.quadraticCurveTo(10, -24, 17, -14);
  ctx.quadraticCurveTo(24, 2, 21, 24);
  ctx.quadraticCurveTo(0, 29, -21, 24);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  ctx.strokeStyle = 'rgba(120,82,24,0.6)';
  ctx.lineWidth = 1.4;
  ctx.beginPath();
  ctx.moveTo(-18, 8);
  ctx.quadraticCurveTo(0, 14, 18, 8);
  ctx.stroke();

  ctx.fillStyle = '#8f6a26';
  rr(ctx, -3, -31, 6, 10, 2);
  ctx.fill();

  ctx.fillStyle = '#241410';
  ctx.beginPath();
  ctx.arc(-7, 0, 2.4, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(7, 0, 2.4, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = '#33200f';
  ctx.lineWidth = 1.3;
  ctx.beginPath();
  ctx.arc(0, 6, 4, 0.25, Math.PI - 0.25);
  ctx.stroke();
  ctx.restore();
}

function censerPlant(ctx, t, bob) {
  ctx.save();
  ctx.translate(0, bob);
  ctx.strokeStyle = '#191210';
  ctx.fillStyle = '#6f5a3f';
  ctx.lineWidth = 2;
  for (const lx of [-16, 0, 16]) {
    ctx.beginPath();
    ctx.moveTo(lx * 0.6, 12);
    ctx.lineTo(lx, 28);
    ctx.lineTo(lx + 6, 28);
    ctx.lineTo(lx + 3, 12);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
  }
  ctx.fillStyle = '#8a6f4d';
  ctx.beginPath();
  ctx.ellipse(0, 4, 24, 15, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#6e573c';
  ctx.beginPath();
  ctx.ellipse(0, -6, 22, 8, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#2f2118';
  ctx.beginPath();
  ctx.ellipse(0, -6, 17, 5, 0, 0, Math.PI * 2);
  ctx.fill();
  const glow = 0.6 + Math.sin(t * 6) * 0.2;
  for (let i = 0; i < 5; i++) {
    const a = i * 1.3 + t * 0.4;
    ctx.fillStyle = i % 2 ? `rgba(255,160,70,${0.55 * glow})` : '#e8b25a';
    ctx.beginPath();
    ctx.arc(Math.cos(a) * 9, -6 + Math.sin(a) * 2.4, 2.4 + (i % 3), 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.strokeStyle = 'rgba(190,180,160,0.34)';
  ctx.lineWidth = 2.2;
  for (let i = 0; i < 2; i++) {
    const k = (t * 0.7 + i * 0.5) % 1;
    ctx.beginPath();
    ctx.moveTo(-4 + i * 8, -12 - k * 10);
    ctx.quadraticCurveTo(-14 + i * 12, -28 - k * 12, -2 + i * 8, -40 - k * 8);
    ctx.stroke();
  }
  ctx.fillStyle = '#241410';
  ctx.beginPath();
  ctx.arc(-8, -2, 2.3, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(8, -2, 2.3, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#241410';
  ctx.lineWidth = 1.3;
  ctx.beginPath();
  ctx.arc(0, 4, 4, 0.25, Math.PI - 0.25);
  ctx.stroke();
  ctx.restore();
}

function umbrellaPlant(ctx, t, bob, opt) {
  ctx.save();
  ctx.translate(0, bob);
  const spin = opt.pulse ? Math.sin(opt.pulse * 18) * 0.25 : 0;
  ctx.save();
  ctx.translate(0, -18);
  ctx.rotate(spin + Math.sin(t * 1.6) * 0.03);
  ctx.fillStyle = '#b5493e';
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(-30, 0);
  ctx.quadraticCurveTo(0, -34, 30, 0);
  ctx.quadraticCurveTo(18, 5, 14, 0);
  ctx.quadraticCurveTo(7, 5, 0, 0);
  ctx.quadraticCurveTo(-7, 5, -14, 0);
  ctx.quadraticCurveTo(-20, 5, -30, 0);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
  ctx.strokeStyle = 'rgba(70,18,14,0.55)';
  ctx.lineWidth = 1;
  for (const rx of [-18, -8, 8, 18]) {
    ctx.beginPath();
    ctx.moveTo(0, -30);
    ctx.lineTo(rx, 1);
    ctx.stroke();
  }
  ctx.fillStyle = '#f0d9a4';
  ctx.beginPath();
  ctx.ellipse(0, -28, 3, 4, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#241410';
  ctx.beginPath();
  ctx.arc(-6, -14, 2.1, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(6, -14, 2.1, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#3a1a15';
  ctx.lineWidth = 1.2;
  ctx.beginPath();
  ctx.arc(0, -8, 3.6, 0.25, Math.PI - 0.25);
  ctx.stroke();
  ctx.restore();
  ctx.strokeStyle = '#7a5a30';
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(0, -18);
  ctx.lineTo(0, 24);
  ctx.stroke();
  ctx.fillStyle = '#c9a15c';
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 1.4;
  rr(ctx, -4, 22, 8, 6, 2);
  ctx.fill();
  ctx.stroke();
  ctx.restore();
}

function mushroomPlant(ctx, t, bob, opt) {
  ctx.save();
  ctx.translate(0, bob);
  ctx.fillStyle = '#463528';
  ctx.beginPath();
  ctx.ellipse(0, 26, 34, 9, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#d9c9a2';
  ctx.strokeStyle = '#241a12';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.ellipse(0, 0, 12, 24, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#c9b184';
  ctx.beginPath();
  ctx.ellipse(0, -23, 32, 15, 0, Math.PI, Math.PI * 2);
  ctx.quadraticCurveTo(20, -9, 0, -8);
  ctx.quadraticCurveTo(-20, -9, -32, -23);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#a8442f';
  ctx.fillRect(-3, -20, 6, 20);
  ctx.fillStyle = '#241a12';
  ctx.beginPath();
  ctx.arc(-7, -2, 2.2, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(7, -2, 2.2, 0, Math.PI * 2);
  ctx.fill();
  if (opt.armed) {
    ctx.globalAlpha = 0.4 + Math.sin(t * 5) * 0.2;
    ctx.strokeStyle = '#9fe08f';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.ellipse(0, 22, 26, 7, 0, 0, Math.PI * 2);
    ctx.stroke();
  }
  ctx.restore();
}

function lionPlant(ctx, t, bob, opt) {
  ctx.save();
  ctx.translate(opt.recoil ? -4 : 0, bob);
  if ((opt.pulse ?? 0) > 0) {
    ctx.strokeStyle = 'rgba(240,190,100,0.5)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(0, -6, 30 + (0.35 - opt.pulse) * 40, 0, Math.PI * 2);
    ctx.stroke();
  }
  ctx.fillStyle = '#c9472f';
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 2;
  for (let i = 0; i < 10; i++) {
    const a = (i / 10) * Math.PI * 2 + Math.sin(t * 2 + i) * 0.04;
    ctx.save();
    ctx.rotate(a);
    ctx.beginPath();
    ctx.moveTo(0, -22);
    ctx.quadraticCurveTo(-8, -37, 0, -44);
    ctx.quadraticCurveTo(8, -37, 0, -22);
    ctx.fill();
    ctx.stroke();
    ctx.restore();
  }
  ctx.fillStyle = '#d9a441';
  ctx.beginPath();
  ctx.ellipse(0, -12, 24, 21, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#f1e3c6';
  ctx.beginPath();
  ctx.ellipse(0, -4, 13, 10, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#241410';
  ctx.beginPath();
  ctx.ellipse(-8, -16, 3.4, 4.2, 0.15, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.ellipse(8, -16, 3.4, 4.2, -0.15, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#ffe09a';
  ctx.beginPath();
  ctx.arc(-8, -16, 1, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(8, -16, 1, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#7a2018';
  ctx.beginPath();
  ctx.ellipse(0, -7, 5, 3.4, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 1.6;
  ctx.beginPath();
  ctx.moveTo(-8, 1);
  ctx.lineTo(-3, 4);
  ctx.lineTo(0, 1);
  ctx.lineTo(3, 4);
  ctx.lineTo(8, 1);
  ctx.stroke();
  ctx.fillStyle = '#b03a2c';
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 1.6;
  rr(ctx, -15, 8, 30, 14, 5);
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#d9a441';
  rr(ctx, -12, 22, 8, 6, 2);
  ctx.fill();
  rr(ctx, 4, 22, 8, 6, 2);
  ctx.fill();
  ctx.restore();
}

const DAMAGE_ZONES = {
  ghost: {
    stains: [[0.36, 0.58, 0.08], [0.67, 0.64, 0.065]],
    scratches: [[0.22, 0.38, 0.36, 0.6], [0.66, 0.42, 0.78, 0.64]],
    chunks: [[0.1, 0.58, 0.075], [0.91, 0.66, 0.06]],
    holes: [[0.4, 0.66, 0.11], [0.67, 0.72, 0.085]]
  },
  paper: {
    stains: [[0.5, 0.5, 0.09], [0.35, 0.7, 0.065]],
    scratches: [[0.28, 0.36, 0.42, 0.58], [0.62, 0.4, 0.72, 0.62]],
    chunks: [[0.86, 0.28, 0.09], [0.14, 0.64, 0.065]],
    holes: [[0.45, 0.62, 0.1], [0.69, 0.56, 0.075]]
  },
  mountain: {
    stains: [[0.28, 0.6, 0.1], [0.7, 0.6, 0.075]],
    scratches: [[0.18, 0.38, 0.32, 0.62], [0.68, 0.36, 0.8, 0.6]],
    chunks: [[0.91, 0.5, 0.085], [0.1, 0.68, 0.07]],
    holes: [[0.32, 0.68, 0.11], [0.7, 0.7, 0.085]]
  },
  tongue: {
    stains: [[0.34, 0.64, 0.08], [0.68, 0.62, 0.065]],
    scratches: [[0.22, 0.42, 0.34, 0.64], [0.64, 0.4, 0.78, 0.66]],
    chunks: [[0.1, 0.64, 0.07], [0.9, 0.7, 0.055]],
    holes: [[0.38, 0.72, 0.1], [0.66, 0.68, 0.08]]
  },
  mourner: {
    stains: [[0.42, 0.7, 0.08], [0.62, 0.62, 0.06]],
    scratches: [[0.3, 0.46, 0.4, 0.68], [0.6, 0.44, 0.7, 0.66]],
    chunks: [[0.12, 0.7, 0.065], [0.89, 0.66, 0.055]],
    holes: [[0.42, 0.78, 0.1], [0.62, 0.7, 0.08]]
  },
  sedan: {
    stains: [[0.34, 0.5, 0.08], [0.58, 0.58, 0.075]],
    scratches: [[0.28, 0.4, 0.4, 0.58], [0.58, 0.36, 0.7, 0.56]],
    chunks: [[0.13, 0.55, 0.06], [0.88, 0.6, 0.06]],
    holes: null,
    tear: [0.36, 0.44, 0.6, 0.66]
  },
  straw: {
    stains: [[0.38, 0.6, 0.075], [0.66, 0.62, 0.06]],
    scratches: [[0.24, 0.4, 0.36, 0.62], [0.66, 0.42, 0.78, 0.64]],
    chunks: [[0.12, 0.62, 0.065], [0.9, 0.66, 0.055]],
    holes: [[0.4, 0.68, 0.1], [0.67, 0.7, 0.08]]
  },
  stonehat: {
    stains: [[0.34, 0.58, 0.08], [0.68, 0.6, 0.07]],
    scratches: [[0.2, 0.4, 0.34, 0.62], [0.65, 0.38, 0.8, 0.62]],
    chunks: [[0.1, 0.58, 0.07], [0.9, 0.62, 0.06]],
    holes: [[0.38, 0.66, 0.1], [0.68, 0.7, 0.08]]
  },
  bucket: {
    stains: [[0.4, 0.56, 0.075], [0.64, 0.64, 0.065]],
    scratches: [[0.24, 0.4, 0.36, 0.62], [0.64, 0.4, 0.78, 0.62]],
    chunks: [[0.12, 0.56, 0.065], [0.89, 0.6, 0.06]],
    holes: [[0.42, 0.68, 0.1], [0.66, 0.7, 0.08]]
  },
  vault: {
    stains: [[0.36, 0.62, 0.075], [0.66, 0.6, 0.06]],
    scratches: [[0.22, 0.42, 0.34, 0.64], [0.66, 0.4, 0.78, 0.64]],
    chunks: [[0.1, 0.64, 0.06], [0.9, 0.68, 0.055]],
    holes: [[0.4, 0.7, 0.09], [0.66, 0.72, 0.075]]
  },
  artisan: {
    stains: [[0.36, 0.54, 0.075], [0.64, 0.6, 0.065]],
    scratches: [[0.26, 0.38, 0.38, 0.6], [0.62, 0.4, 0.76, 0.62]],
    chunks: [[0.12, 0.6, 0.07], [0.88, 0.62, 0.06]],
    holes: [[0.4, 0.64, 0.095], [0.66, 0.68, 0.08]]
  },
  ironjudge: {
    stains: [[0.32, 0.56, 0.085], [0.68, 0.6, 0.075]],
    scratches: [[0.2, 0.36, 0.34, 0.6], [0.66, 0.38, 0.8, 0.62]],
    chunks: [[0.1, 0.56, 0.075], [0.9, 0.6, 0.065]],
    holes: [[0.36, 0.66, 0.105], [0.68, 0.7, 0.085]]
  }
};

const ZOMBIE_MOTION = {
  ghost: {
    cls: 'small', stride: 4.8, bob: 3.0, sway: 0.075, baseRot: 0.01,
    dust: 1.0, dustColor: '198,178,148', chompSpeed: 12,
    chompLean: 0.05, chompAmp: 0.02, chompBob: 1.0
  },
  tongue: {
    cls: 'ultra', stride: 8.2, bob: 1.8, sway: 0.11, baseRot: 0.03,
    dust: 0.55, dustColor: '174,196,164', chompSpeed: 16,
    chompLean: 0.08, chompAmp: 0.03, chompBob: 1.4, scuttle: true
  },
  paper: {
    cls: 'special', stride: 3.4, bob: 1.2, sway: 0.05, baseRot: 0,
    dust: 0.25, dustColor: '222,206,176', chompSpeed: 8,
    chompLean: 0.035, chompAmp: 0.018, chompBob: 0.8, flutter: true
  },
  mountain: {
    cls: 'heavy', stride: 1.5, bob: 4.8, sway: 0.065, baseRot: 0,
    dust: 2.2, dustColor: '188,164,132', chompSpeed: 5.4,
    chompLean: 0.055, chompAmp: 0.028, chompBob: 2.4, stomp: true
  },
  mourner: {
    cls: 'special', stride: 2.6, bob: 0.6, sway: 0.02, baseRot: 0,
    dust: 0.15, dustColor: '164,190,204', chompSpeed: 5,
    chompLean: 0.025, chompAmp: 0.012, chompBob: 0.5, glide: true
  },
  sedan: {
    cls: 'heavy', stride: 2.2, bob: 2.3, sway: 0.045, baseRot: 0,
    dust: 1.5, dustColor: '192,168,136', chompSpeed: 7,
    chompLean: 0.03, chompAmp: 0.022, chompBob: 2.0, stomp: true
  },
  straw: {
    cls: 'small', stride: 5.2, bob: 2.4, sway: 0.06, baseRot: 0.01,
    dust: 0.8, dustColor: '198,176,128', chompSpeed: 11,
    chompLean: 0.045, chompAmp: 0.02, chompBob: 0.9
  },
  stonehat: {
    cls: 'special', stride: 3.4, bob: 1.6, sway: 0.035, baseRot: 0.02,
    dust: 1.2, dustColor: '176,172,160', chompSpeed: 8,
    chompLean: 0.04, chompAmp: 0.018, chompBob: 1.0
  },
  bucket: {
    cls: 'heavy', stride: 2.8, bob: 1.4, sway: 0.03, baseRot: 0.01,
    dust: 1.4, dustColor: '160,164,166', chompSpeed: 7,
    chompLean: 0.035, chompAmp: 0.02, chompBob: 1.2, stomp: true
  },
  vault: {
    cls: 'ultra', stride: 9.0, bob: 2.2, sway: 0.1, baseRot: 0.03,
    dust: 0.7, dustColor: '198,170,120', chompSpeed: 14,
    chompLean: 0.07, chompAmp: 0.025, chompBob: 1.3, scuttle: true
  },
  artisan: {
    cls: 'special', stride: 2.8, bob: 1.0, sway: 0.025, baseRot: 0,
    dust: 0.4, dustColor: '206,192,160', chompSpeed: 6,
    chompLean: 0.025, chompAmp: 0.015, chompBob: 0.8, glide: true
  },
  ironjudge: {
    cls: 'heavy', stride: 1.8, bob: 2.0, sway: 0.04, baseRot: 0,
    dust: 1.8, dustColor: '160,158,150', chompSpeed: 5.6,
    chompLean: 0.05, chompAmp: 0.025, chompBob: 2.0, stomp: true
  }
};

const damageCache = new Map();

function damagedZombieSprite(type, img, stage) {
  const key = type + ':' + stage;
  if (damageCache.has(key)) return damageCache.get(key);
  const canvas = document.createElement('canvas');
  canvas.width = img.width;
  canvas.height = img.height;
  const x = canvas.getContext('2d');
  x.drawImage(img, 0, 0);
  const w = canvas.width;
  const h = canvas.height;
  const zones = DAMAGE_ZONES[type] || DAMAGE_ZONES.ghost;

  x.globalCompositeOperation = 'source-atop';
  x.fillStyle = stage === 1 ? 'rgba(28,18,18,0.16)' : 'rgba(20,10,10,0.32)';
  x.fillRect(0, 0, w, h);

  x.fillStyle = stage === 1 ? 'rgba(116,26,20,0.34)' : 'rgba(126,28,20,0.46)';
  for (const [ux, uy, r] of zones.stains) {
    x.beginPath();
    x.ellipse(ux * w, uy * h, r * w, r * h * 0.72, 0.4, 0, Math.PI * 2);
    x.fill();
  }

  x.strokeStyle = 'rgba(38,13,10,0.85)';
  x.lineWidth = Math.max(3, w * 0.009);
  x.lineCap = 'round';
  for (const [ax, ay, bx, by] of zones.scratches) {
    x.beginPath();
    x.moveTo(ax * w, ay * h);
    x.lineTo((ax + (bx - ax) * 0.45) * w, (ay + (by - ay) * 0.55) * h + h * 0.015);
    x.lineTo(bx * w, by * h);
    x.stroke();
  }

  const notchPath = (ux, uy, r, scale) => {
    x.beginPath();
    const rr = r * Math.min(w, h) * scale;
    for (let i = 0; i < 9; i++) {
      const a = (i / 9) * Math.PI * 2;
      const rad = rr * (i % 2 === 0 ? 1 : 0.62);
      const px = ux * w + Math.cos(a) * rad;
      const py = uy * h + Math.sin(a) * rad * 1.12;
      if (i === 0) x.moveTo(px, py);
      else x.lineTo(px, py);
    }
    x.closePath();
  };
  const notch = (ux, uy, r, scale) => {
    notchPath(ux, uy, r, scale);
    x.fill();
  };

  const gashes = stage === 1 ? [zones.scratches[0]] : zones.scratches;
  for (let gi = 0; gi < gashes.length; gi++) {
    const [ax, ay, bx, by] = gashes[gi];
    x.strokeStyle = gi === 0 ? 'rgba(196,58,38,0.85)' : 'rgba(162,42,30,0.7)';
    x.lineWidth = Math.max(5, w * 0.028);
    x.lineCap = 'round';
    x.beginPath();
    x.moveTo(ax * w, ay * h);
    x.lineTo((ax + (bx - ax) * 0.42) * w, (ay + (by - ay) * 0.5) * h + h * 0.018);
    x.lineTo(bx * w, by * h);
    x.stroke();
    x.strokeStyle = 'rgba(255,156,112,0.55)';
    x.lineWidth = Math.max(2, w * 0.009);
    x.stroke();
  }

  if (stage === 2) {
    x.strokeStyle = 'rgba(178,64,42,0.5)';
    x.lineWidth = Math.max(2, w * 0.005);
    for (const [ax, ay, bx, by] of zones.scratches) {
      x.beginPath();
      x.moveTo(ax * w + w * 0.008, ay * h + h * 0.01);
      x.lineTo(bx * w + w * 0.008, by * h + h * 0.01);
      x.stroke();
    }
    if (zones.tear) {
      const [ax, ay, bx, by] = zones.tear;
      x.fillStyle = 'rgba(22,8,8,0.68)';
      x.beginPath();
      x.moveTo(ax * w, ay * h);
      x.lineTo((ax + 0.08) * w, (ay + 0.08) * h);
      x.lineTo((ax + 0.04) * w, (ay + 0.18) * h);
      x.lineTo((bx - 0.02) * w, (by + 0.12) * h);
      x.lineTo((bx + 0.04) * w, by * h);
      x.lineTo((ax + 0.06) * w, (ay + 0.06) * h);
      x.closePath();
      x.fill();
    }
  }

  x.globalCompositeOperation = 'destination-out';
  x.fillStyle = 'rgba(0,0,0,1)';
  const chunks = stage === 2 ? zones.chunks : (zones.chunks || []).slice(0, 1);
  for (let ci = 0; ci < chunks.length; ci++) {
    const [ux, uy, r] = chunks[ci];
    notch(ux, uy, r, stage === 2 ? 1 : 0.7);
  }
  if (stage === 2 && zones.holes) {
    for (const [ux, uy, r] of zones.holes) notch(ux, uy, r, 1);
  }
  x.globalCompositeOperation = 'source-over';

  x.strokeStyle = 'rgba(206,178,140,0.32)';
  x.lineWidth = Math.max(2, w * 0.005);
  for (const [ux, uy, r] of chunks) {
    notchPath(ux, uy, r, stage === 2 ? 1 : 0.7);
    x.stroke();
  }

  if (stage === 2 && zones.holes) {
    x.strokeStyle = 'rgba(58,18,14,0.7)';
    x.lineWidth = Math.max(2, w * 0.006);
    for (const [ux, uy, r] of zones.holes) {
      x.beginPath();
      x.arc(ux * w, uy * h, r * Math.min(w, h) * 1.05, 0, Math.PI * 2);
      x.stroke();
    }
    x.strokeStyle = 'rgba(206,176,136,0.28)';
    x.lineWidth = Math.max(1.5, w * 0.0035);
    for (const [ux, uy, r] of zones.holes) {
      x.beginPath();
      x.arc(ux * w, uy * h, r * Math.min(w, h) * 1.16, 0, Math.PI * 2);
      x.stroke();
    }
  }
  x.globalCompositeOperation = 'source-over';
  damageCache.set(key, canvas);
  return canvas;
}

function zombieDamageStage(opt) {
  const hpFig = Math.max(0, Math.min(1, opt.hpRatio ?? 1));
  let stage = hpFig > 0.62 ? 0 : hpFig > 0.3 ? 1 : 2;
  const armorNow = opt.armor ?? opt.def?.armor ?? 0;
  const armorMax = opt.maxArmor ?? opt.def?.armor ?? 0;
  if (armorMax > 0 && ((opt.armorRatio ?? 1) < 0.35 || armorNow <= 0)) {
    stage = Math.max(stage, 1);
  }
  if (armorMax > 0 && armorNow <= 0) stage = Math.max(stage, 2);
  return stage;
}

const GAIT_TUNING = {
  ghost: { liftPx: 5.2, dropPx: 2.4, stepDx: 3.0, warp: 4.2, headBobMul: 1.5, leanFoot: 0.025, swayMul: 1.35, contactDx: 2.4 },
  tongue: { liftPx: 4.0, dropPx: 1.6, stepDx: 4.0, warp: 3.6, headBobMul: 1.2, leanFoot: 0.028, swayMul: 1.4, contactDx: 2.8 },
  paper: { liftPx: 3.0, dropPx: 1.2, stepDx: 2.2, warp: 3.0, headBobMul: 1.1, leanFoot: 0.018, swayMul: 1.3, contactDx: 1.6 },
  mountain: { warp: 4.6, headBobMul: 1.8, swayMul: 1.1, contactDx: 1.5 },
  mourner: { warp: 2.2, headBobMul: 1.2, swayMul: 1.1 },
  sedan: { liftPx: 4.2, dropPx: 2.0, stepDx: 2.2, warp: 3.8, headBobMul: 1.0, leanFoot: 0.016, swayMul: 1.2, contactDx: 1.8 },
  straw: { liftPx: 5.6, dropPx: 2.0, stepDx: 3.3, warp: 5.0, headBobMul: 1.8, leanFoot: 0.026, swayMul: 1.4, contactDx: 2.6 },
  stonehat: { liftPx: 4.0, dropPx: 2.2, stepDx: 2.2, warp: 3.6, headBobMul: 0.8, leanFoot: 0.018, swayMul: 1.2, contactDx: 2.0 },
  bucket: { liftPx: 3.8, dropPx: 2.0, stepDx: 2.2, warp: 3.2, headBobMul: 0.8, leanFoot: 0.017, swayMul: 1.2, contactDx: 2.0 },
  vault: { liftPx: 4.0, dropPx: 1.6, stepDx: 4.2, warp: 5.2, headBobMul: 1.3, leanFoot: 0.026, swayMul: 1.4, contactDx: 3.2 },
  artisan: { warp: 3.2, headBobMul: 1.2, swayMul: 1.15, contactDx: 1.0 },
  ironjudge: { liftPx: 5.0, dropPx: 2.4, stepDx: 2.4, warp: 3.2, headBobMul: 0.7, leanFoot: 0.014, swayMul: 1.15, contactDx: 1.8 }
};

function zombieMotion(type, t, phase, opt) {
  const prof = ZOMBIE_MOTION[type] || ZOMBIE_MOTION.ghost;
  const tune = GAIT_TUNING[type] || {};
  const rawSwing = Math.sin(t * prof.stride + phase);
  const swing = type === 'mountain'
    ? Math.sign(rawSwing) * Math.pow(Math.abs(rawSwing), 0.72)
    : rawSwing;
  const step = Math.abs(swing);
  const liftPx = prof.liftPx ?? tune.liftPx ?? Math.max(1.4, prof.bob * 0.95);
  const dropPx = prof.dropPx ?? tune.dropPx ?? Math.max(0.6, prof.bob * 0.4);
  let contact = Math.pow(Math.max(0, 1 - step), 2.4);
  let lift = step * liftPx;
  let slam = 0;
  let gaitAge = 0;
  const stage = zombieDamageStage(opt);
  let dx = swing * (prof.stepDx ?? tune.stepDx ?? 1.2) - contact * (prof.contactDx ?? tune.contactDx ?? 0);
  let dy = -lift + contact * dropPx;
  let rot = prof.baseRot +
    swing * prof.sway * (prof.swayMul ?? tune.swayMul ?? 1) +
    contact * (prof.leanFoot ?? tune.leanFoot ?? 0.012);
  let sx = 1 + contact * 0.03 - step * 0.01;
  let sy = 1 - contact * 0.04 + step * 0.02;
  if (prof.scuttle) {
    dx += Math.sin(t * prof.stride * 0.55 + phase) * 1.4;
    rot += Math.sin(t * prof.stride * 0.55) * 0.035;
  }
  if (prof.flutter) {
    rot += Math.sin(t * 9.5 + phase) * 0.03;
    dy += Math.sin(t * 6.2 + phase) * 0.9;
  }
  if (prof.glide) {
    dx = Math.sin(t * 0.9 + phase) * 1.2;
    dy = Math.sin(t * 1.1 + phase) * 1.2;
    rot = Math.sin(t * 0.9 + phase) * 0.02;
    sx = 1;
    sy = 1;
    contact = 0;
    lift = 0;
  }
  if (type === 'mountain') {
    const cycle = ((t * prof.stride + phase) % Math.PI + Math.PI) % Math.PI;
    gaitAge = cycle / prof.stride;
    slam = Math.exp(-gaitAge * 7);
    contact = slam;
    lift = step * 6.2;
    dy = -lift + slam * 3.8;
    rot = prof.baseRot + swing * 0.11 + slam * 0.018;
    sx = 1 + slam * 0.06 + step * 0.014;
    sy = 1 - slam * 0.064 - step * 0.014;
    dx = Math.sin(t * prof.stride * 0.5 + phase) * 2.3 + Math.sin(gaitAge * 34) * 0.8 * slam;
  } else if (prof.stomp) {
    sx = 1 + contact * 0.04 - step * 0.006;
    sy = 1 - contact * 0.05 + step * 0.014;
  }
  if (opt.eating) {
    const chew = Math.sin(t * prof.chompSpeed + phase);
    if (type === 'mountain') {
      dx = -3.2 + chew * 1.6;
      rot = 0.055 + chew * 0.06;
      dy = Math.abs(chew) * 2.2;
      sx = 1;
      sy = 1 + chew * prof.chompAmp;
    } else if (prof.glide) {
      dx = -1.2 + chew * 0.8;
      rot = 0.02 + chew * prof.chompLean;
      dy = 0.4 + Math.abs(chew) * prof.chompBob;
    } else if (prof.cls === 'heavy') {
      dx = -2 + chew * 1.2;
      rot = 0.04 + chew * prof.chompLean;
      dy = Math.abs(chew) * prof.chompBob;
      sy = 1 + chew * prof.chompAmp;
    } else if (prof.cls === 'ultra') {
      dx = -3 + chew * 2;
      rot = 0.035 + chew * prof.chompLean;
      dy = Math.abs(chew) * prof.chompBob;
    } else {
      dx = -2.5 + chew * 1.5;
      rot = 0.03 + chew * prof.chompLean;
      dy = Math.abs(chew) * prof.chompBob;
    }
    sx = 1;
    slam = 0;
    contact = 0;
    lift = 0;
  }
  if (stage === 2) {
    rot += Math.sin(t * prof.stride * 0.5 + phase) * 0.02;
    dx += Math.sin(t * 2.1 + phase) * 0.8;
    sy *= 0.985;
  }
  if (opt.wailT > 0) {
    const wail = Math.sin(Math.PI * Math.max(0, Math.min(1, 1 - opt.wailT / 0.95)));
    rot -= wail * 0.09;
    dy -= wail * 2.2;
    dx -= wail * 1.5;
  }
  if (opt.objectHop > 0) {
    const hop = Math.sin(Math.PI * Math.max(0, Math.min(1, 1 - opt.objectHop / 0.34)));
    dy -= hop * 7;
    rot += hop * 0.04;
  }
  if (opt.stunT > 0) {
    dx = 0;
    dy = 0;
    rot = Math.sin(t * 7) * 0.03;
    contact = 0;
    lift = 0;
  }
  if (opt.idle) {
    dx = Math.sin(t * 0.8 + phase) * 1.2;
    dy = Math.sin(t * 1.2 + phase) * 1.6;
    rot = Math.sin(t * 0.65 + phase) * 0.02;
    sx = 1;
    sy = 1;
    contact = 0;
    lift = 0;
  }
  const warpBase = prof.warp ?? tune.warp ?? (prof.cls === 'heavy' ? 2.8 : prof.cls === 'ultra' ? 2.5 : 2.2);
  let warp = warpBase * (0.35 + step * 0.8);
  if (prof.glide) warp = warpBase * 0.55;
  if (opt.eating) warp *= 0.25;
  if (opt.stunT > 0) warp *= 0.35;
  if (opt.idle) warp = 1.1;
  if (stage === 2) warp *= 0.85;
  const warpPhase = t * prof.stride + phase - Math.PI * 0.38;
  const headBob = opt.idle
    ? Math.sin(t * 1.2 + phase) * 1.2
    : opt.eating || opt.stunT > 0
      ? 0
      : (-step * liftPx * 0.55 + contact * dropPx * 0.8) * (prof.headBobMul ?? tune.headBobMul ?? 1);
  return {
    dx, dy, rot, sx, sy, step, swing, prof, stage, slam, gaitAge,
    eating: !!opt.eating, contact, lift, warp, warpPhase, headBob
  };
}

function drawZombieDust(ctx, motion, t, phase, type) {
  const prof = motion.prof;
  if (prof.glide) {
    const alpha = 0.1 + Math.sin(t * 1.2 + phase) * 0.03;
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.fillStyle = 'rgba(150,190,210,0.8)';
    ctx.beginPath();
    ctx.ellipse(-16, 30, 20, 3.2, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
    return;
  }
  if (type === 'mountain') {
    if (motion.eating) return;
    const slam = motion.slam ?? 0;
    if (slam < 0.015) return;
    const age = motion.gaitAge ?? 0;
    const k = Math.min(1, age / 0.7);
    const fade = Math.pow(1 - k, 1.15);
    ctx.save();
    ctx.strokeStyle = 'rgba(206,182,142,0.9)';
    const r = 14 + k * 58;
    for (let i = 0; i < 3; i++) {
      ctx.globalAlpha = (0.34 - i * 0.07) * fade;
      ctx.lineWidth = 1.7 * (1 - k) + 0.5;
      const a0 = 0.3 + i * 2.1 + k * 0.5;
      const rr = r * (1 - i * 0.13);
      ctx.beginPath();
      ctx.ellipse(0, 33, rr, rr * 0.24, 0, a0, a0 + 1.15 - i * 0.15);
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
    const puff = (x, y, rx, ry, a) => {
      const grad = ctx.createRadialGradient(x, y, 0, x, y, rx);
      grad.addColorStop(0, `rgba(204,182,144,${a})`);
      grad.addColorStop(0.55, `rgba(188,164,128,${a * 0.45})`);
      grad.addColorStop(1, 'rgba(188,164,128,0)');
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.ellipse(x, y, rx, ry, 0, 0, Math.PI * 2);
      ctx.fill();
    };
    puff(0, 28, 22 + k * 14, 7 + k * 4, 0.28 * fade);
    for (let i = 0; i < 6; i++) {
      const side = i < 3 ? -1 : 1;
      const step = i % 3;
      const x = side * (14 + step * 10 + k * 16) + Math.sin(i * 2.1) * 3;
      const y = 31 - (i % 2) * 3 + step * 1.2;
      puff(x, y, 10 + k * 12 + step * 2, 4 + k * 5, (0.3 + (i % 3) * 0.05) * fade);
    }
    for (let i = 0; i < 4; i++) {
      const p = Math.min(1, age / 0.65);
      puff(-24 + i * 16 + Math.sin(age * 6 + i) * 2, 27 - p * (11 + i * 3), 5 + p * 5, 2.6 + p * 3, 0.2 * (1 - p));
    }
    ctx.fillStyle = 'rgba(118,100,78,0.95)';
    for (let i = 0; i < 4; i++) {
      const p = Math.min(1, age / 0.52);
      const ang = -Math.PI / 2 + (i - 1.5) * 0.5;
      const sp = 34 + i * 6;
      ctx.globalAlpha = 0.8 * (1 - p);
      ctx.fillRect(Math.cos(ang) * sp * p, 29 + Math.sin(ang) * sp * p + 60 * p * p, 2.2, 2.2);
    }
    ctx.restore();
    return;
  }
  const contact = motion.contact ?? 0;
  if (contact < 0.28) return;
  const size = prof.cls === 'heavy' ? 1.7 : prof.cls === 'ultra' ? 0.65 : 1;
  const alpha = Math.min(0.35, (contact - 0.28) * 0.42 * prof.dust);
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.fillStyle = `rgba(${prof.dustColor},0.85)`;
  const count = prof.cls === 'heavy' ? 3 : 2;
  for (let i = 0; i < count; i++) {
    const p = (t * (prof.cls === 'ultra' ? 2.4 : 1.7) + phase + i * 1.7) % 1;
    ctx.beginPath();
    ctx.ellipse(
      -12 - i * 12 - p * 8, 32,
      (4 + p * 6) * size, (1.5 + p * 2.5) * size,
      0, 0, Math.PI * 2
    );
    ctx.fill();
  }
  ctx.restore();
}

export function drawZombie(ctx, type, x, y, t, opt = {}) {
  const s = (opt.scale ?? 1) * (opt.def?.scale ?? 1);
  const phase = opt.phase ?? 0;
  const def = opt.def ?? ZOMBIE_TYPES[type];
  const baseH = def?.spriteH ?? 96;
  const sprite = assets.zombies[type];
  const death = Math.max(0, Math.min(1, opt.death || 0));
  if (death > 0) {
    drawZombieDeath(ctx, type, x, y, t, opt, def, baseH, sprite, death);
    return;
  }
  const gaitT = opt.animT ?? t;
  const motion = zombieMotion(type, gaitT, phase, opt);
  if (opt.vaultArc) {
    motion.dy -= opt.vaultArc * 58;
    motion.rot -= opt.vaultArc * 0.18;
  }
  const chomp = opt.eating ? Math.sin(t * 10 + phase) * 2.4 : 0;

  ctx.save();
  ctx.translate(x, y);
  ctx.scale(s, s);

  const groundSlam = type === 'mountain' && !opt.eating ? (motion.slam ?? 0) : 0;
  const liftK = Math.min(1, (motion.lift || 0) / 9);
  ctx.fillStyle = type === 'mountain' ? `rgba(0,0,0,${0.26 + groundSlam * 0.18})` : 'rgba(0,0,0,0.32)';
  ctx.beginPath();
  ctx.ellipse(
    0, 32,
    27 * (1 - motion.step * 0.04 - liftK * 0.12 + groundSlam * 0.2),
    7.5 * (1 - motion.step * 0.02 - liftK * 0.08 + groundSlam * 0.14),
    0, 0, Math.PI * 2
  );
  ctx.fill();

  if (opt.slowT > 0) {
    ctx.fillStyle = 'rgba(120,190,210,0.16)';
    ctx.beginPath();
    ctx.ellipse(0, 4, 34, 44, 0, 0, Math.PI * 2);
    ctx.fill();
  }

  drawZombieDust(ctx, motion, gaitT, phase, type);
  if (opt.vaultArc > 0) drawVaultPole(ctx, opt, baseH, t);

  ctx.save();
  ctx.translate(motion.dx, motion.dy);
  ctx.translate(0, 34);
  ctx.rotate(motion.rot);
  ctx.scale(motion.sx, motion.sy);
  ctx.translate(0, -34);

  if (sprite) {
    const img = motion.stage ? damagedZombieSprite(type, sprite, motion.stage) : sprite;
    const w = baseH * (img.width / img.height);
    drawZombieSpriteWarped(ctx, img, w, baseH, motion);
  } else if (type === 'ghost') ghostZombie(ctx, chomp);
  else if (type === 'paper') paperZombie(ctx, chomp, opt);
  else if (type === 'mountain') mountainZombie(ctx, chomp);
  else if (type === 'tongue') tongueZombie(ctx, chomp);
  else if (type === 'mourner') mournerZombie(ctx, chomp, t);
  else if (type === 'sedan') sedanZombie(ctx, chomp, opt);
  else drawNewZombie(ctx, type, chomp, opt);

  const headV = 0.22;
  const headX = Math.sin(motion.warpPhase - headV * 2.1) * motion.warp *
    (Math.sin(Math.PI * headV) + 0.3 * (1 - headV));
  drawZombieArmor(ctx, type, opt, baseH, motion.headBob + (opt.eating ? chomp * 0.5 : 0), opt.eating ? 0 : headX);
  ctx.restore();
  if (type === 'mountain') drawZombieFrontDust(ctx, motion);
  if (motion.stage === 2) drawZombieDamageWisps(ctx, t, baseH);
  drawZombieStatus(ctx, t, opt, baseH);
  ctx.restore();
}

function drawVaultPole(ctx, opt, baseH, t) {
  const a = opt.vaultArc;
  ctx.save();
  ctx.globalAlpha = 0.7 + a * 0.25;
  ctx.strokeStyle = 'rgba(238,214,154,0.34)';
  ctx.lineWidth = 2;
  ctx.setLineDash([5, 7]);
  ctx.lineDashOffset = -t * 22;
  ctx.beginPath();
  ctx.arc(0, -6, 44, -Math.PI * 0.85, Math.PI * 0.12);
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.lineCap = 'round';
  ctx.strokeStyle = '#6a4628';
  ctx.lineWidth = 3.6;
  ctx.beginPath();
  ctx.moveTo(20, 30);
  ctx.lineTo(-12, -baseH * 0.72);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(216,178,102,0.9)';
  ctx.lineWidth = 1.3;
  ctx.beginPath();
  ctx.moveTo(20, 30);
  ctx.lineTo(-12, -baseH * 0.72);
  ctx.stroke();
  ctx.fillStyle = 'rgba(196,70,46,0.9)';
  ctx.beginPath();
  ctx.moveTo(-11, -baseH * 0.72);
  ctx.lineTo(-1, -baseH * 0.70);
  ctx.lineTo(-10, -baseH * 0.60);
  ctx.closePath();
  ctx.fill();
  for (let i = 0; i < 3; i++) {
    const k = Math.min(1, a * 1.2);
    ctx.globalAlpha = (0.28 - i * 0.06) * (1 - k * 0.4);
    ctx.strokeStyle = 'rgba(194,172,136,0.9)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(0, 25, 15 + i * 8 + k * 24, 0.2, Math.PI - 0.2);
    ctx.stroke();
  }
  ctx.restore();
}

function drawZombieSpriteWarped(ctx, img, w, baseH, motion) {
  const amp = motion.warp || 0;
  const top = 34 - baseH;
  if (amp < 0.18) {
    ctx.drawImage(img, -w / 2, top, w, baseH);
    return;
  }
  const strips = 16;
  const sh = img.height / strips;
  const dh = baseH / strips;
  for (let i = 0; i < strips; i++) {
    const v = (i + 0.5) / strips;
    const factor = Math.sin(Math.PI * v) + 0.3 * (1 - v);
    const dx = Math.sin(motion.warpPhase - v * 2.1) * amp * factor;
    ctx.drawImage(img, 0, i * sh, img.width, sh, -w / 2 + dx, top + i * dh, w, dh + 0.9);
  }
}

function drawZombieArmor(ctx, type, opt, baseH, headBob = 0, headX = 0) {
  const armor = opt.armor ?? (ZOMBIE_TYPES[type]?.armor || 0);
  const max = opt.maxArmor ?? (ZOMBIE_TYPES[type]?.armor || 0);
  if (armor <= 0 || max <= 0) return;
  const armorType = opt.armorType || ZOMBIE_TYPES[type]?.armorType;
  if (!armorType || armorType === 'paper' || armorType === 'sedan') return;
  const ratio = Math.max(0, Math.min(1, armor / max));
  const headFactor = armorType === 'straw' || armorType === 'charm'
    ? 0.8
    : armorType === 'mask' ? 0.84 : 0.9;
  const headY = 34 - baseH * headFactor + headBob;
  const death = Math.max(0, Math.min(1, opt.death || 0));
  ctx.save();
  if (death <= 0 && headX) ctx.translate(headX, 0);
  if (death > 0) {
    if (armorType === 'straw') {
      ctx.translate(-death * 16, death * 26);
      ctx.rotate(death * 1.1);
    } else if (armorType === 'stonehat') {
      ctx.translate(0, death * 22);
      ctx.rotate(death * 0.25);
    } else if (armorType === 'urn') {
      ctx.translate(death * 20, death * 14);
      ctx.rotate(death * 1.5);
    } else if (armorType === 'bucket') {
      ctx.translate(death * 18, death * 12);
      ctx.rotate(death * 1.8);
    } else if (armorType === 'mask') {
      ctx.translate(0, death * 12);
      ctx.rotate(death * 0.15);
    } else if (armorType === 'charm') {
      ctx.globalAlpha = 1 - death;
    }
  }
  if (armorType === 'straw') {
    ctx.fillStyle = ratio > 0.35 ? '#c9a45e' : '#a8824a';
    ctx.strokeStyle = '#6d4c28';
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.moveTo(-15, headY + 7);
    ctx.lineTo(15, headY + 7);
    ctx.lineTo(7, headY - 7);
    ctx.lineTo(-7, headY - 7);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.strokeStyle = 'rgba(110,76,40,0.55)';
    ctx.lineWidth = 1;
    for (let i = -1; i <= 1; i++) {
      ctx.beginPath();
      ctx.moveTo(i * 5, headY - 6);
      ctx.lineTo(i * 7, headY + 6);
      ctx.stroke();
    }
  } else if (armorType === 'stonehat') {
    ctx.fillStyle = ratio > 0.35 ? '#a8a69a' : '#7c7a70';
    ctx.strokeStyle = '#5f5d55';
    ctx.lineWidth = 1.8;
    ctx.beginPath();
    ctx.moveTo(-14, headY + 8);
    ctx.lineTo(-7, headY - 10);
    ctx.lineTo(7, headY - 10);
    ctx.lineTo(14, headY + 8);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.strokeStyle = 'rgba(80,78,70,0.5)';
    ctx.beginPath();
    ctx.moveTo(-9, headY + 1);
    ctx.lineTo(9, headY + 1);
    ctx.stroke();
  } else if (armorType === 'urn') {
    const clay = ctx.createLinearGradient(-14, 0, 14, 0);
    clay.addColorStop(0, '#8b5a38');
    clay.addColorStop(0.5, ratio > 0.35 ? '#b07a4e' : '#8d603f');
    clay.addColorStop(1, '#6f462e');
    ctx.fillStyle = clay;
    ctx.strokeStyle = '#4d2e1f';
    ctx.lineWidth = 1.8;
    ctx.beginPath();
    ctx.moveTo(-13, headY - 12);
    ctx.quadraticCurveTo(-16, headY + 2, -15, headY + 12);
    ctx.lineTo(15, headY + 12);
    ctx.quadraticCurveTo(16, headY + 2, 13, headY - 12);
    ctx.quadraticCurveTo(6, headY - 17, 0, headY - 16);
    ctx.quadraticCurveTo(-6, headY - 17, -13, headY - 12);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.strokeStyle = 'rgba(230,200,160,0.35)';
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.moveTo(-14, headY + 8);
    ctx.lineTo(14, headY + 8);
    ctx.stroke();
    ctx.strokeStyle = 'rgba(55,32,20,0.75)';
    ctx.beginPath();
    ctx.moveTo(-7, headY - 10);
    ctx.lineTo(-3, headY - 2);
    ctx.lineTo(-8, headY + 5);
    ctx.moveTo(8, headY - 6);
    ctx.lineTo(4, headY + 2);
    ctx.lineTo(9, headY + 9);
    ctx.stroke();
  } else if (armorType === 'bucket') {
    ctx.fillStyle = ratio > 0.35 ? '#8f999b' : '#6c7476';
    ctx.strokeStyle = '#4f585a';
    ctx.lineWidth = 1.8;
    ctx.beginPath();
    ctx.moveTo(-14, headY + 9);
    ctx.lineTo(-11, headY - 13);
    ctx.lineTo(11, headY - 13);
    ctx.lineTo(14, headY + 9);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.strokeStyle = 'rgba(220,230,230,0.35)';
    ctx.beginPath();
    ctx.moveTo(-12, headY - 1);
    ctx.lineTo(12, headY - 1);
    ctx.stroke();
    ctx.strokeStyle = 'rgba(60,66,68,0.6)';
    ctx.beginPath();
    ctx.moveTo(-13, headY + 6);
    ctx.lineTo(13, headY + 6);
    ctx.stroke();
  } else if (armorType === 'mask') {
    const iron = ctx.createLinearGradient(0, headY - 16, 0, headY + 20);
    iron.addColorStop(0, '#5e636a');
    iron.addColorStop(0.55, ratio > 0.35 ? '#3c4046' : '#303338');
    iron.addColorStop(1, '#232629');
    ctx.fillStyle = '#2b2e32';
    ctx.strokeStyle = '#4a4e52';
    ctx.lineWidth = 1.4;
    for (const side of [-1, 1]) {
      ctx.beginPath();
      ctx.moveTo(side * 13, headY - 8);
      ctx.quadraticCurveTo(side * 22, headY - 15, side * 19, headY - 24);
      ctx.quadraticCurveTo(side * 12, headY - 19, side * 8, headY - 12);
      ctx.closePath();
      ctx.fill();
      ctx.stroke();
    }
    ctx.fillStyle = iron;
    ctx.strokeStyle = ratio > 0.35 ? '#c9a35a' : '#7c6436';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-13, headY - 10);
    ctx.quadraticCurveTo(0, headY - 17, 13, headY - 10);
    ctx.lineTo(12, headY + 6);
    ctx.quadraticCurveTo(9, headY + 16, 0, headY + 21);
    ctx.quadraticCurveTo(-9, headY + 16, -12, headY + 6);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.strokeStyle = 'rgba(201,163,90,0.8)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-10, headY - 5);
    ctx.lineTo(-2, headY - 2);
    ctx.moveTo(10, headY - 5);
    ctx.lineTo(2, headY - 2);
    ctx.stroke();
    ctx.save();
    ctx.shadowColor = 'rgba(255,150,50,0.9)';
    ctx.shadowBlur = 6;
    ctx.fillStyle = '#ffb347';
    for (const side of [-1, 1]) {
      ctx.beginPath();
      ctx.moveTo(side * 9, headY + 1);
      ctx.lineTo(side * 3.5, headY + 3.2);
      ctx.lineTo(side * 4.5, headY + 5.6);
      ctx.lineTo(side * 9.5, headY + 3.6);
      ctx.closePath();
      ctx.fill();
    }
    ctx.restore();
    ctx.strokeStyle = 'rgba(20,22,24,0.7)';
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.moveTo(0, headY + 3);
    ctx.lineTo(-2.5, headY + 9);
    ctx.lineTo(2.5, headY + 9);
    ctx.stroke();
    ctx.fillStyle = '#151618';
    ctx.beginPath();
    ctx.roundRect(-7, headY + 11, 14, 5, 2);
    ctx.fill();
    ctx.fillStyle = '#efe6cd';
    for (let i = 0; i < 3; i++) {
      const fx = -4.5 + i * 4.5;
      ctx.beginPath();
      ctx.moveTo(fx - 1.4, headY + 11);
      ctx.lineTo(fx, headY + 16);
      ctx.lineTo(fx + 1.4, headY + 11);
      ctx.closePath();
      ctx.fill();
    }
  } else if (armorType === 'charm') {
    ctx.strokeStyle = 'rgba(232,216,166,0.85)';
    ctx.lineWidth = 2;
    for (let i = 0; i < 4; i++) {
      ctx.beginPath();
      ctx.moveTo(-16 + i * 10, headY + 4);
      ctx.lineTo(-12 + i * 10, 18);
      ctx.stroke();
    }
    ctx.fillStyle = 'rgba(226,204,150,0.8)';
    ctx.font = '700 9px serif';
    ctx.textAlign = 'center';
    ctx.fillText('甲', 0, headY + 22);
  }
  if (ratio < 0.35) {
    ctx.strokeStyle = 'rgba(30,24,18,0.7)';
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.moveTo(-12, headY - 10);
    ctx.lineTo(-4, headY);
    ctx.lineTo(-8, headY + 10);
    ctx.stroke();
  }
  ctx.restore();
}

function drawZombieDeath(ctx, type, x, y, t, opt, def, baseH, sprite, death) {
  const s = (opt.scale ?? 1) * (def?.scale ?? 1);
  const style = def?.deathStyle || type;
  let rot = 0;
  let dy = 0;
  let sx = 1;
  let sy = 1;
  let alpha = 1;
  if (style === 'ghost') {
    dy = -death * 34;
    alpha = 1 - death;
    sx = 1 - death * 0.12;
    sy = 1 - death * 0.18;
  } else if (style === 'paper' || style === 'artisan') {
    rot = death * 0.6;
    sx = 1 + death * 0.18;
    sy = 1 - death * 0.4;
    alpha = 1 - death * 0.35;
    dy = death * 4;
  } else if (style === 'tongue') {
    rot = -death * 0.9;
    dy = death * 8;
    sy = 1 - death * 0.22;
  } else if (style === 'mountain' || style === 'sedan' || style === 'ironjudge') {
    rot = death * 1.28;
    dy = death * 4;
    alpha = 1 - Math.max(0, death - 0.8) * 0.8;
  } else if (style === 'vault') {
    rot = -death * 1.0;
    dy = death * 5;
  } else if (style === 'mourner') {
    rot = death * 0.35;
    dy = death * 6;
    alpha = 1 - death * 0.55;
  } else {
    rot = death * 0.95;
    dy = death * 5;
    sy = 1 - death * 0.08;
  }
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(s, s);
  ctx.fillStyle = `rgba(0,0,0,${0.3 * (1 - death * 0.6)})`;
  ctx.beginPath();
  ctx.ellipse(0, 32, 27, 7, 0, 0, Math.PI * 2);
  ctx.fill();
  if (def?.large) {
    ctx.fillStyle = `rgba(170,150,120,${0.22 * death})`;
    ctx.beginPath();
    ctx.ellipse(0, 34, 30 + death * 22, 8 + death * 4, 0, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = alpha;
  ctx.translate(0, 34);
  ctx.rotate(rot);
  ctx.scale(sx, sy);
  ctx.translate(0, -34 + dy);
  if (sprite) {
    const img = damagedZombieSprite(type, sprite, 2);
    const w = baseH * (img.width / img.height);
    ctx.drawImage(img, -w / 2, 34 - baseH, w, baseH);
  } else if (style === 'ghost') ghostZombie(ctx, 0);
  else if (style === 'paper') paperZombie(ctx, 0, opt);
  else if (style === 'mountain') mountainZombie(ctx, 0);
  else if (style === 'tongue') tongueZombie(ctx, 0);
  else if (style === 'mourner') mournerZombie(ctx, 0, t);
  else if (style === 'sedan') sedanZombie(ctx, 0, opt);
  else drawNewZombie(ctx, type, 0, opt);
  drawZombieArmor(ctx, type, opt, baseH);
  ctx.restore();
}

function drawZombieFrontDust(ctx, motion) {
  if (motion.eating) return;
  const slam = motion.slam ?? 0;
  if (slam < 0.02) return;
  const k = Math.min(1, (motion.gaitAge ?? 0) / 0.6);
  const fade = Math.pow(1 - k, 1.3);
  const puff = (x, y, rx, ry, a) => {
    const grad = ctx.createRadialGradient(x, y, 0, x, y, rx);
    grad.addColorStop(0, `rgba(190,168,132,${a})`);
    grad.addColorStop(1, 'rgba(190,168,132,0)');
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.ellipse(x, y, rx, ry, 0, 0, Math.PI * 2);
    ctx.fill();
  };
  puff(-27 + k * 9, 35, 9 + k * 7, 3.4 + k * 2.6, 0.24 * fade);
  puff(25 - k * 8, 36, 8 + k * 8, 3 + k * 2.5, 0.22 * fade);
  puff(-4, 37, 12 + k * 9, 4 + k * 3, 0.17 * fade);
}

function drawZombieDamageWisps(ctx, t, baseH) {
  const top = 34 - baseH * 0.66;
  ctx.save();
  for (let i = 0; i < 3; i++) {
    const p = (t * 0.36 + i * 0.33) % 1;
    const x = (i - 1) * 11 + Math.sin(t * 2.1 + i * 1.7) * 3;
    const y = top - p * 22;
    ctx.globalAlpha = (1 - p) * 0.42;
    ctx.fillStyle = i % 2 === 0 ? '#c25a3c' : '#7d2d23';
    ctx.beginPath();
    ctx.arc(x, y, 1.4 + p * 1.6, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

function drawZombieStatus(ctx, t, opt, baseH) {
  if (opt.rageT > 0) {
    ctx.strokeStyle = 'rgba(226,112,74,0.55)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.ellipse(0, 30, 28, 8, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.lineWidth = 2;
    for (let i = -1; i <= 1; i++) {
      ctx.beginPath();
      ctx.moveTo(-30, 6 + i * 9);
      ctx.lineTo(-44, 4 + i * 11);
      ctx.stroke();
    }
  }
  if (opt.auraPulse > 0) {
    const a = opt.auraPulse / 0.85;
    ctx.strokeStyle = `rgba(214,142,112,${0.5 * a})`;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(0, 2, 28 + (1 - a) * 26, 0, Math.PI * 2);
    ctx.stroke();
  }
  if (opt.stunT > 0) {
    const headY = 34 - baseH * 0.92;
    for (let i = 0; i < 3; i++) {
      const a = t * 4 + (i / 3) * Math.PI * 2;
      const sx = Math.cos(a) * 16;
      const sy = headY + Math.sin(a) * 4;
      ctx.fillStyle = 'rgba(255,225,150,0.9)';
      ctx.save();
      ctx.translate(sx, sy);
      ctx.rotate(a);
      ctx.beginPath();
      for (let k = 0; k < 4; k++) {
        const ang = (k / 4) * Math.PI * 2;
        const rad = k % 2 === 0 ? 3.2 : 1.2;
        const px = Math.cos(ang) * rad;
        const py = Math.sin(ang) * rad;
        if (k === 0) ctx.moveTo(px, py);
        else ctx.lineTo(px, py);
      }
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    }
  }
  if (opt.burnT > 0) {
    for (let i = 0; i < 3; i++) {
      const p = (t * 1.6 + i * 0.33) % 1;
      ctx.globalAlpha = (1 - p) * 0.7;
      ctx.fillStyle = i % 2 ? '#ffb45e' : '#ff7a3c';
      ctx.beginPath();
      ctx.arc(Math.sin(t * 4 + i * 2) * 14, -p * 44 - 4, 2 + p * 2, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }
  if (opt.supportPulse > 0) {
    const a = opt.supportPulse / 0.85;
    ctx.strokeStyle = `rgba(236,214,156,${0.55 * a})`;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(0, 2, 26 + (1 - a) * 30, 0, Math.PI * 2);
    ctx.stroke();
    ctx.fillStyle = `rgba(238,218,166,${0.65 * a})`;
    for (let i = 0; i < 4; i++) {
      const ang = t * 2.3 + i * Math.PI * 0.5;
      const sx = Math.cos(ang) * 25;
      const sy = -26 + Math.sin(ang) * 9;
      ctx.save();
      ctx.translate(sx, sy);
      ctx.rotate(ang + Math.PI * 0.5);
      ctx.fillRect(-4, -7, 8, 14);
      ctx.restore();
    }
  }
  if (opt.wailT > 0) {
    const progress = 1 - opt.wailT / 0.95;
    const env = Math.sin(Math.PI * Math.max(0, Math.min(1, progress)));
    const headY = 34 - baseH * 0.78;
    ctx.save();
    for (let i = 0; i < 3; i++) {
      ctx.globalAlpha = env * (0.55 - i * 0.12);
      ctx.strokeStyle = i % 2 ? 'rgba(168,218,230,0.9)' : 'rgba(220,236,238,0.8)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(0, headY + 8, 20 + i * 10 + progress * 34, Math.PI * 0.62, Math.PI * 1.38);
      ctx.stroke();
    }
    for (let i = 0; i < 5; i++) {
      const q = (progress * 1.2 + i / 5) % 1;
      ctx.globalAlpha = (1 - q) * env * 0.7;
      ctx.fillStyle = i % 2 ? '#d9eef2' : '#9ecbd8';
      ctx.beginPath();
      ctx.arc(-12 + Math.sin(t * 2 + i * 1.8) * 8, headY - q * 30, 1.5 + q * 2, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = env * 0.5;
    ctx.fillStyle = 'rgba(24,42,48,0.8)';
    ctx.beginPath();
    ctx.ellipse(0, headY + 16, 4.5, 7 + env * 3, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
  if (opt.armorPulse > 0) {
    const a = Math.min(1, opt.armorPulse / 0.9);
    ctx.strokeStyle = `rgba(160,210,190,${0.45 * a})`;
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.ellipse(0, 28, 30 + (1 - a) * 18, 8 + (1 - a) * 4, 0, 0, Math.PI * 2);
    ctx.stroke();
  }
}

function tongueZombie(ctx, chomp) {
  ctx.fillStyle = '#87a87d';
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 2.2;
  ctx.beginPath();
  ctx.moveTo(-19, 28);
  ctx.quadraticCurveTo(-27, 6, -19, -12);
  ctx.quadraticCurveTo(-12, -28, 3, -27);
  ctx.quadraticCurveTo(20, -26, 24, -8);
  ctx.quadraticCurveTo(29, 8, 19, 28);
  ctx.lineTo(10, 22);
  ctx.lineTo(4, 29);
  ctx.lineTo(-4, 22);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#191210';
  ctx.beginPath();
  ctx.ellipse(-9, -14, 4.2, 5.2, 0.1, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.ellipse(7, -14, 4.2, 5.2, -0.1, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = 'rgba(180,230,160,0.8)';
  ctx.beginPath();
  ctx.arc(-9, -14, 1.1, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(7, -14, 1.1, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#f0c0b4';
  ctx.strokeStyle = '#7a3a32';
  ctx.lineWidth = 1.6;
  ctx.beginPath();
  ctx.moveTo(0, 2);
  ctx.quadraticCurveTo(20, 8 + chomp, 32, 2);
  ctx.quadraticCurveTo(24, 10 + chomp, 0, 7);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
  ctx.strokeStyle = '#5e3a30';
  ctx.beginPath();
  ctx.moveTo(0, 4 + chomp * 0.3);
  ctx.lineTo(24, 6);
  ctx.stroke();
}

function mournerZombie(ctx, chomp, t) {
  ctx.fillStyle = '#d7d2c3';
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(-23, 30);
  ctx.quadraticCurveTo(-18, 4, -15, -8);
  ctx.quadraticCurveTo(-8, -22, 0, -24);
  ctx.quadraticCurveTo(10, -22, 16, -8);
  ctx.quadraticCurveTo(21, 6, 23, 30);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
  ctx.strokeStyle = 'rgba(120,116,108,0.5)';
  ctx.lineWidth = 1;
  for (const x of [-9, 0, 9]) {
    ctx.beginPath();
    ctx.moveTo(x, -6);
    ctx.lineTo(x * 1.4, 28);
    ctx.stroke();
  }
  ctx.fillStyle = '#1d1714';
  ctx.beginPath();
  ctx.moveTo(-18, -12);
  ctx.quadraticCurveTo(-22, 2, -14, 10);
  ctx.lineTo(-8, -2);
  ctx.quadraticCurveTo(-4, -20, 0, -24);
  ctx.quadraticCurveTo(8, -20, 12, -4);
  ctx.lineTo(18, 8);
  ctx.quadraticCurveTo(22, 0, 17, -12);
  ctx.quadraticCurveTo(0, -32, -18, -12);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = '#d9d3c5';
  ctx.beginPath();
  ctx.ellipse(0, -10, 12, 14, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#1d1714';
  ctx.beginPath();
  ctx.arc(-5, -12, 2.1, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(5, -12, 2.1, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#1d1714';
  ctx.lineWidth = 1.2;
  ctx.beginPath();
  ctx.arc(0, -5 + chomp * 0.2, 3.2, 0.35, Math.PI - 0.35);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(120,180,200,0.75)';
  ctx.lineWidth = 1.4;
  const tear = (t * 0.8) % 1;
  ctx.beginPath();
  ctx.moveTo(-6, -8 + tear * 14);
  ctx.lineTo(-6, -4 + tear * 14);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(6, -8 + ((tear + 0.4) % 1) * 14);
  ctx.lineTo(6, -4 + ((tear + 0.4) % 1) * 14);
  ctx.stroke();
}

function sedanZombie(ctx, chomp, opt) {
  ctx.strokeStyle = '#191210';
  ctx.fillStyle = '#5a3a2c';
  ctx.lineWidth = 2;
  for (const lx of [-22, -8, 10, 24]) {
    ctx.beginPath();
    ctx.moveTo(lx, 10);
    ctx.lineTo(lx - 2, 30);
    ctx.lineTo(lx + 6, 30);
    ctx.lineTo(lx + 8, 10);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
  }
  ctx.fillStyle = '#a83a2e';
  ctx.beginPath();
  ctx.roundRect(-32, -34, 64, 46, 7);
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#7a2018';
  ctx.beginPath();
  ctx.moveTo(-38, -34);
  ctx.quadraticCurveTo(0, -56, 38, -34);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#e2c07a';
  ctx.fillRect(-32, -16, 64, 3);
  ctx.fillRect(-32, 0, 64, 3);
  ctx.fillStyle = 'rgba(30,18,14,0.6)';
  ctx.beginPath();
  ctx.roundRect(-12, -14, 24, 20, 3);
  ctx.fill();
  const intact = (opt.armor ?? 0) > 0;
  if (intact) {
    ctx.fillStyle = '#c9a15c';
    for (const hx of [-20, 20]) {
      ctx.beginPath();
      ctx.arc(hx, -8, 7, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = '#191210';
      ctx.beginPath();
      ctx.arc(hx - 2, -9, 1.3, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(hx + 2, -9, 1.3, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#c9a15c';
    }
  } else {
    ctx.fillStyle = '#1d1512';
    ctx.beginPath();
    ctx.ellipse(-8, -20, 3.4, 4, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.ellipse(8, -20, 3.4, 4, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#f0c0b4';
    ctx.beginPath();
    ctx.ellipse(0, -8 + chomp * 0.3, 3.4, 2.2, 0, 0, Math.PI * 2);
    ctx.fill();
  }
}

function ghostZombie(ctx, chomp) {
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 9;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(-16, -2);
  ctx.quadraticCurveTo(-28, 4, -34, 14);
  ctx.stroke();
  ctx.strokeStyle = '#a9bfae';
  ctx.lineWidth = 6;
  ctx.beginPath();
  ctx.moveTo(-16, -2);
  ctx.quadraticCurveTo(-28, 4, -34, 14);
  ctx.stroke();

  ctx.fillStyle = '#a9bfae';
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(-20, 28);
  ctx.quadraticCurveTo(-30, 4, -22, -14);
  ctx.quadraticCurveTo(-17, -32, 0, -32);
  ctx.quadraticCurveTo(17, -32, 22, -14);
  ctx.quadraticCurveTo(30, 4, 20, 28);
  ctx.lineTo(12, 21);
  ctx.lineTo(6, 29);
  ctx.lineTo(-2, 21);
  ctx.lineTo(-10, 29);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  ctx.fillStyle = '#17110f';
  ctx.beginPath();
  ctx.ellipse(-8, -15, 4.2, 5.2, 0.15, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.ellipse(6, -15, 4.2, 5.2, -0.15, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = 'rgba(170,220,150,0.7)';
  ctx.beginPath();
  ctx.arc(-8, -15, 1.2, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(6, -15, 1.2, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#241210';
  ctx.beginPath();
  ctx.ellipse(0, -3 + chomp * 0.5, 5, 3.4 + Math.abs(chomp) * 0.35, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = '#6f8a7c';
  ctx.lineWidth = 1.6;
  ctx.beginPath();
  ctx.moveTo(-6, -31);
  ctx.quadraticCurveTo(-10, -38, -4, -40);
  ctx.stroke();
}

function paperZombie(ctx, chomp, opt) {
  const intact = (opt.armor ?? 0) > 0;
  if (intact) {
    ctx.fillStyle = '#f1e9d5';
    ctx.strokeStyle = '#191210';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-22, 30);
    ctx.lineTo(-26, -8);
    ctx.lineTo(-17, -28);
    ctx.lineTo(0, -36);
    ctx.lineTo(17, -28);
    ctx.lineTo(26, -8);
    ctx.lineTo(22, 30);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.strokeStyle = '#b03a2c';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.moveTo(-20, 4);
    ctx.lineTo(20, 4);
    ctx.stroke();
    ctx.fillStyle = '#b03a2c';
    ctx.beginPath();
    ctx.arc(0, 4, 4, 0, Math.PI * 2);
    ctx.fill();
  }

  ctx.fillStyle = intact ? '#f6efdc' : '#e2d8c0';
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(-15, 28);
  ctx.lineTo(-17, -6);
  ctx.lineTo(-10, -20);
  ctx.lineTo(10, -20);
  ctx.lineTo(17, -6);
  ctx.lineTo(15, 28);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  ctx.beginPath();
  ctx.rect(-12, -38, 24, 20);
  ctx.fill();
  ctx.stroke();

  ctx.strokeStyle = 'rgba(140,116,86,0.4)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(-8, -18);
  ctx.lineTo(-4, 26);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(8, -18);
  ctx.lineTo(4, 26);
  ctx.stroke();

  ctx.fillStyle = 'rgba(190,60,45,0.5)';
  ctx.beginPath();
  ctx.arc(-7, -26, 3, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(7, -26, 3, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#1d1512';
  ctx.beginPath();
  ctx.arc(-5, -31, 1.8, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(5, -31, 1.8, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = '#1d1512';
  ctx.lineWidth = 1.2;
  ctx.beginPath();
  ctx.arc(0, -27 + chomp * 0.3, 3, 0.3, Math.PI - 0.3);
  ctx.stroke();
}

function mountainZombie(ctx, chomp) {
  ctx.fillStyle = '#4a3326';
  ctx.strokeStyle = '#191210';
  ctx.lineWidth = 2.5;
  ctx.beginPath();
  ctx.ellipse(-28, 2, 12, 24, 0.4, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();
  ctx.beginPath();
  ctx.ellipse(28, 2, 12, 24, -0.4, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();

  ctx.beginPath();
  ctx.moveTo(-32, 32);
  ctx.quadraticCurveTo(-36, -6, -18, -20);
  ctx.quadraticCurveTo(0, -32, 18, -20);
  ctx.quadraticCurveTo(36, -6, 32, 32);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  ctx.fillStyle = '#a83a2e';
  ctx.beginPath();
  ctx.ellipse(0, -16, 20, 17, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();

  ctx.fillStyle = '#d8c79a';
  ctx.beginPath();
  ctx.moveTo(-16, -28);
  ctx.quadraticCurveTo(-24, -44, -12, -40);
  ctx.quadraticCurveTo(-10, -34, -8, -30);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(16, -28);
  ctx.quadraticCurveTo(24, -44, 12, -40);
  ctx.quadraticCurveTo(10, -34, 8, -30);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  ctx.fillStyle = '#ffcf6a';
  ctx.beginPath();
  ctx.ellipse(-7, -20, 3.2, 2.6, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.ellipse(7, -20, 3.2, 2.6, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#1a110d';
  ctx.beginPath();
  ctx.arc(-7, -20, 1.3, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(7, -20, 1.3, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#2a1310';
  ctx.beginPath();
  ctx.ellipse(0, -7 + chomp * 0.4, 8, 4 + Math.abs(chomp) * 0.3, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#efe5c8';
  ctx.beginPath();
  ctx.moveTo(-5, -9);
  ctx.lineTo(-2, -2);
  ctx.lineTo(0, -9);
  ctx.closePath();
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(5, -9);
  ctx.lineTo(2, -2);
  ctx.lineTo(0, -9);
  ctx.closePath();
  ctx.fill();
}

export function drawMower(ctx, x, y, t, m) {
  const img = assets.guardian;
  if (img) {
    const baseH = 64;
    const w = baseH * (img.width / img.height);
    ctx.save();
    ctx.translate(x, y);
    ctx.fillStyle = 'rgba(0,0,0,0.3)';
    ctx.beginPath();
    ctx.ellipse(0, 24, w * 0.45, 6, 0, 0, Math.PI * 2);
    ctx.fill();

    if (m.active) {
      const glow = ctx.createRadialGradient(4, 0, 4, 4, 0, 48);
      glow.addColorStop(0, 'rgba(255,220,140,0.55)');
      glow.addColorStop(1, 'rgba(255,170,75,0)');
      ctx.fillStyle = glow;
      ctx.beginPath();
      ctx.arc(4, 0, 48, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = 'rgba(255,225,160,0.55)';
      ctx.lineWidth = 2;
      for (let i = -2; i <= 2; i++) {
        ctx.beginPath();
        ctx.moveTo(-42, i * 9);
        ctx.lineTo(-62, i * 12);
        ctx.stroke();
      }
    }

    const bob = m.active ? 0 : m.ready ? Math.sin(t * 2 + y) * 1 : 0;
    ctx.globalAlpha = m.ready || m.active ? 1 : 0.36;
    ctx.drawImage(img, -w / 2, 24 - baseH + bob, w, baseH);
    ctx.globalAlpha = 1;

    if (!m.ready && !m.active) {
      ctx.strokeStyle = 'rgba(180,54,40,0.75)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(-10, -28);
      ctx.lineTo(10, 8);
      ctx.moveTo(10, -28);
      ctx.lineTo(-10, 8);
      ctx.stroke();
    }
    ctx.restore();
    return;
  }

  ctx.save();
  ctx.translate(x, y);
  if (m.active) {
    ctx.globalAlpha = 0.85;
    const g = ctx.createLinearGradient(-40, 0, 40, 0);
    g.addColorStop(0, 'rgba(255,214,120,0)');
    g.addColorStop(0.5, 'rgba(255,214,120,0.75)');
    g.addColorStop(1, 'rgba(255,140,60,0)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.ellipse(0, 0, 46, 34, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#f6df9e';
    ctx.beginPath();
    ctx.ellipse(0, -6, 14, 22, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#e8b45f';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(-34, 12);
    ctx.lineTo(38, -16);
    ctx.stroke();
    ctx.strokeStyle = 'rgba(255,225,160,0.5)';
    ctx.lineWidth = 2;
    for (let i = -2; i <= 2; i++) {
      ctx.beginPath();
      ctx.moveTo(-30, i * 9);
      ctx.lineTo(-46, i * 12);
      ctx.stroke();
    }
  } else {
    ctx.fillStyle = 'rgba(0,0,0,0.3)';
    ctx.beginPath();
    ctx.ellipse(0, 24, 20, 6, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = m.ready ? '#6f6a5e' : '#57534a';
    ctx.strokeStyle = '#191210';
    ctx.lineWidth = 2;
    rr(ctx, -15, -40, 30, 54, 5);
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = m.ready ? '#7c2a22' : '#4f3a33';
    rr(ctx, -11, -34, 22, 32, 3);
    ctx.fill();

    ctx.strokeStyle = m.ready ? '#e3b45e' : '#8f7f66';
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.moveTo(-7, -25);
    ctx.lineTo(-2, -21);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(7, -25);
    ctx.lineTo(2, -21);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(0, -20);
    ctx.lineTo(0, -14);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(-6, -10);
    ctx.quadraticCurveTo(0, -4, 6, -10);
    ctx.stroke();

    ctx.fillStyle = '#4c463c';
    ctx.strokeStyle = '#191210';
    ctx.lineWidth = 1.6;
    rr(ctx, -21, 14, 42, 9, 3);
    ctx.fill();
    ctx.stroke();

    if (!m.ready) {
      ctx.strokeStyle = 'rgba(30,26,22,0.7)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(-10, -30);
      ctx.lineTo(-4, -16);
      ctx.lineTo(-9, 4);
      ctx.stroke();
    }
  }
  ctx.restore();
}
