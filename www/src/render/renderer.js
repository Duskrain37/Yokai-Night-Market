import { BOARD, BOARD_H, BOARD_W, VIEW, cellCenter } from '../layout.js';
import { drawMower, drawPlant, drawZombie } from './art.js';
import { drawUI, drawMenuBackdrop } from '../ui/ui.js';
import { upgradeDots } from '../game/upgrade.js';
import { assets } from '../core/assets.js';
import { drawBoardArt, drawMapAnimation, drawMapBackdrop, drawMapForeground, mapSceneSignature } from './mapart.js';

function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}

let fireGlowSprite = null;
let starGlowSprite = null;
let fireTrailSprite = null;
let starSprite = null;

function makeRadialSprite(size, inner, mid, outer) {
  const c = document.createElement('canvas');
  c.width = c.height = size;
  const g = c.getContext('2d');
  const grad = g.createRadialGradient(size / 2, size / 2, 2, size / 2, size / 2, size / 2);
  grad.addColorStop(0, inner);
  grad.addColorStop(0.45, mid);
  grad.addColorStop(1, outer);
  g.fillStyle = grad;
  g.fillRect(0, 0, size, size);
  return c;
}

function getFireGlowSprite() {
  if (!fireGlowSprite) fireGlowSprite = makeRadialSprite(64, 'rgba(255,246,190,0.62)', 'rgba(255,162,68,0.3)', 'rgba(255,90,40,0)');
  return fireGlowSprite;
}

function getStarGlowSprite() {
  if (!starGlowSprite) starGlowSprite = makeRadialSprite(64, 'rgba(255,248,206,0.95)', 'rgba(255,190,80,0.35)', 'rgba(255,180,70,0)');
  return starGlowSprite;
}

function getFireTrailSprite() {
  if (fireTrailSprite) return fireTrailSprite;
  const c = document.createElement('canvas');
  c.width = 96;
  c.height = 56;
  const g = c.getContext('2d');
  const glow = g.createRadialGradient(70, 28, 2, 70, 28, 26);
  glow.addColorStop(0, 'rgba(255,248,200,0.95)');
  glow.addColorStop(0.4, 'rgba(255,170,70,0.45)');
  glow.addColorStop(1, 'rgba(255,90,40,0)');
  g.fillStyle = glow;
  g.fillRect(0, 0, 96, 56);
  g.globalCompositeOperation = 'lighter';
  const flames = [
    [68, 28, 7, 5, '#fff4c2'],
    [57, 26, 9, 6, '#ffc35e'],
    [46, 31, 10, 6, '#ff943e'],
    [34, 24, 10, 5, '#ff7a36'],
    [22, 30, 8, 4, '#d94a2d']
  ];
  for (const [x, y, rx, ry, color] of flames) {
    g.fillStyle = color;
    g.globalAlpha = 0.86;
    g.beginPath();
    g.ellipse(x, y, rx, ry, -0.18, 0, Math.PI * 2);
    g.fill();
  }
  g.globalAlpha = 1;
  fireTrailSprite = c;
  return c;
}

function getStarSprite() {
  if (starSprite) return starSprite;
  const c = document.createElement('canvas');
  c.width = c.height = 40;
  const g = c.getContext('2d');
  g.translate(20, 20);
  g.fillStyle = '#ffe9a6';
  g.strokeStyle = 'rgba(255,190,90,0.75)';
  g.lineWidth = 1.2;
  g.beginPath();
  for (let i = 0; i < 10; i++) {
    const a = (i / 10) * Math.PI * 2 - Math.PI / 2;
    const r = i % 2 === 0 ? 12 : 5;
    const sx = Math.cos(a) * r;
    const sy = Math.sin(a) * r;
    if (i === 0) g.moveTo(sx, sy);
    else g.lineTo(sx, sy);
  }
  g.closePath();
  g.fill();
  g.stroke();
  starSprite = c;
  return c;
}

function drawFireProjectile(ctx, p, t) {
  let angle = 0;
  if (p.starRay) angle = Math.atan2(p.vy, p.vx);
  else if (p.homing && p.target) angle = Math.atan2(p.target.y - 24 - p.y, p.target.x - p.x);
  else if (p.lob) angle = Math.atan2(p.ty - p.y, p.tx - p.x);
  const flick = 0.92 + Math.sin(t * 17 + p.x * 0.04) * 0.08;
  ctx.save();
  ctx.translate(p.x, p.y);
  ctx.rotate(angle);
  ctx.globalAlpha = flick;
  const s = p.big ? 1.18 : 1;
  ctx.drawImage(getFireTrailSprite(), -72 * s, -28 * s, 96 * s, 56 * s);
  ctx.globalAlpha = 0.95;
  ctx.fillStyle = '#ff9a3d';
  ctx.beginPath();
  ctx.arc(0, 0, 5.2, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#fff6cf';
  ctx.beginPath();
  ctx.arc(0, 0, 2.6, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

export class Renderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.bgCanvas = document.getElementById('bg');
    this.ctx = canvas.getContext('2d', { alpha: true });
    if (this.bgCanvas) this.bgCtx = this.bgCanvas.getContext('2d', { alpha: false });
    this.resMode = 'auto';
    this.dpr = 1;
    this.cssW = 0;
    this.cssH = 0;
    this.canvasW = 0;
    this.canvasH = 0;
    this.scale = 1;
    this.ox = 0;
    this.oy = 0;
    this.cssScaleX = 1;
    this.cssScaleY = 1;
    this.cssOx = 0;
    this.cssOy = 0;
    this.resize();
    window.addEventListener('resize', () => this.resize());
  }

  setResolution(mode) {
    const next = ['auto', '720', '1080', '1600'].includes(mode) ? mode : 'auto';
    if (next === this.resMode) return;
    this.resMode = next;
    this.resize();
  }

  resize() {
    const dpr = window.devicePixelRatio || 1;
    const w = window.innerWidth;
    const h = window.innerHeight;
    const fixedWidth = { 720: 1280, 1080: 1920, 1600: 2560 }[this.resMode] || 0;
    const autoWidth = Math.min(Math.round(w * dpr), 1920);
    const bw = fixedWidth || autoWidth;
    const bh = Math.max(1, Math.round(bw * h / w));
    this.dpr = dpr;
    this.cssW = w;
    this.cssH = h;
    this.canvasW = bw;
    this.canvasH = bh;
    this.canvas.width = bw;
    this.canvas.height = bh;
    this.canvas.style.width = w + 'px';
    this.canvas.style.height = h + 'px';
    if (this.bgCanvas) {
      this.bgCanvas.width = bw;
      this.bgCanvas.height = bh;
      this.bgCanvas.style.width = w + 'px';
      this.bgCanvas.style.height = h + 'px';
    }
    this.scale = Math.min(bw / VIEW.w, bh / VIEW.h);
    this.ox = (bw - VIEW.w * this.scale) / 2;
    this.oy = (bh - VIEW.h * this.scale) / 2;
    this.cssScaleX = this.scale * (w / bw);
    this.cssScaleY = this.scale * (h / bh);
    this.cssOx = this.ox * (w / bw);
    this.cssOy = this.oy * (h / bh);
  }

  toLogical(clientX, clientY) {
    const r = this.canvas.getBoundingClientRect();
    return {
      x: (clientX - r.left - this.cssOx) / this.cssScaleX,
      y: (clientY - r.top - this.cssOy) / this.cssScaleY
    };
  }

  toClient(lx, ly) {
    const r = this.canvas.getBoundingClientRect();
    return {
      x: r.left + this.cssOx + lx * this.cssScaleX,
      y: r.top + this.cssOy + ly * this.cssScaleY
    };
  }

  render(game, t) {
    const ctx = this.ctx;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    this.composeBackground(game);
    ctx.clearRect(0, 0, this.canvasW, this.canvasH);

    ctx.translate(this.ox, this.oy);
    ctx.scale(this.scale, this.scale);

    ctx.save();
    ctx.beginPath();
    ctx.rect(0, 0, VIEW.w, VIEW.h);
    ctx.clip();

    if (game.shake > 0) {
      ctx.translate(Math.sin(t * 74) * game.shake * 0.8, Math.cos(t * 63) * game.shake * 0.6);
    }
    if (game.phase !== 'menu') {
      this.drawPetals(ctx, t);
      this.drawWorld(ctx, game, t);
    }
    ctx.restore();

    drawUI(ctx, game, t);
  }

  composeBackground(game) {
    if (!this.bgCtx) return;
    const mode = game.phase === 'menu' ? 'menu' : 'game';
    const sceneKey = mode === 'game'
      ? `${game.level?.day || 1}:${game.rows || BOARD.rows}:${mapSceneSignature(game)}`
      : '';
    const key = `${mode}:${this.scale.toFixed(4)}:${this.canvasW}x${this.canvasH}:${this.ox}x${this.oy}:${sceneKey}`;
    if (this._bgKey === key) return;
    this._bgKey = key;
    const bg = this.bgCtx;
    bg.setTransform(1, 0, 0, 1, 0, 0);
    bg.clearRect(0, 0, this.canvasW, this.canvasH);
    bg.fillStyle = '#060608';
    bg.fillRect(0, 0, this.canvasW, this.canvasH);
    if (mode === 'menu') {
      bg.save();
      bg.translate(this.ox, this.oy);
      bg.scale(this.scale, this.scale);
      drawMenuBackdrop(bg);
      bg.restore();
    } else {
      const layer = this.sceneLayer(game);
      bg.drawImage(layer, this.ox, this.oy, VIEW.w * this.scale, VIEW.h * this.scale);
    }
    this.drawLetterboxBackdrop(bg, game);
  }

  sceneLayer(game) {
    const key = `${this.scale.toFixed(4)}:${VIEW.w}x${VIEW.h}:${game.level?.day || 1}:${game.rows || BOARD.rows}:${mapSceneSignature(game)}`;
    if (this._sceneLayer && this._sceneLayer.key === key) return this._sceneLayer.canvas;
    const canvas = document.createElement('canvas');
    canvas.width = Math.ceil(VIEW.w * this.scale);
    canvas.height = Math.ceil(VIEW.h * this.scale);
    const layer = canvas.getContext('2d');
    layer.scale(this.scale, this.scale);
    drawMapBackdrop(layer, game);
    drawBoardArt(layer, game);
    this._sceneLayer = { key, canvas };
    return canvas;
  }

  drawLetterboxBackdrop(ctx, game) {
    const contentH = VIEW.h * this.scale;
    const top = Math.max(0, this.oy);
    const bottom = Math.max(0, this.canvasH - (this.oy + contentH));
    if (top <= 0 && bottom <= 0) return;
    ctx.save();
    if (top > 0) {
      const g = ctx.createLinearGradient(0, 0, 0, top);
      g.addColorStop(0, 'rgba(2,4,9,0.96)');
      g.addColorStop(1, 'rgba(5,8,15,0.82)');
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, this.canvasW, top);
    }
    if (bottom > 0) {
      const g = ctx.createLinearGradient(0, this.canvasH - bottom, 0, this.canvasH);
      g.addColorStop(0, 'rgba(5,8,15,0.82)');
      g.addColorStop(1, 'rgba(2,4,9,0.96)');
      ctx.fillStyle = g;
      ctx.fillRect(0, this.canvasH - bottom, this.canvasW, bottom);
    }
    ctx.strokeStyle = 'rgba(226,192,122,0.14)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, this.oy + 0.5);
    ctx.lineTo(this.canvasW, this.oy + 0.5);
    ctx.moveTo(0, this.oy + contentH - 0.5);
    ctx.lineTo(this.canvasW, this.oy + contentH - 0.5);
    ctx.stroke();
    ctx.restore();
  }

  drawPetals(ctx, t) {
    ctx.save();
    for (let i = 0; i < 16; i++) {
      const seed = i * 97.31;
      const x = ((seed * 13.7 + t * (9 + (i % 5) * 3)) % 1360) - 40;
      const y = ((seed * 7.3 + t * (11 + (i % 4) * 4)) % 820) - 30;
      const sway = Math.sin(t * 1.2 + i) * 10;
      ctx.globalAlpha = 0.26 + (i % 4) * 0.06;
      ctx.fillStyle = i % 3 === 0 ? '#ffd4dc' : '#ff9fb6';
      ctx.save();
      ctx.translate(x + sway, y);
      ctx.rotate(t * 0.55 + i);
      ctx.beginPath();
      ctx.ellipse(0, 0, 4.4, 2.1, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }
    ctx.restore();
    ctx.globalAlpha = 1;
  }

  drawWorld(ctx, game, t) {
    drawMapAnimation(ctx, game, t);
    for (const m of game.mowers) {
      drawMower(ctx, m.x, game.rowY(m.row) + 10, t, m);
    }

    const unitScale = game.unitScale || 1;
    for (let r = 0; r < game.rows; r++) {
      const lilies = [...game.lilies.values()].filter((p) => !p.dead && p.r === r).sort((a, b) => a.x - b.x);
      for (const p of lilies) {
        drawPlant(ctx, p.type, p.x, p.y, t, {
          phase: p.phase,
          hpRatio: p.maxHp ? p.hp / p.maxHp : 1,
          scale: unitScale,
          armed: true,
          arm: 1
        });
      }
      const plants = game.plants.filter((p) => !p.isLily && p.r === r).sort((a, b) => a.x - b.x);
      for (const p of plants) {
        drawPlant(ctx, p.type, p.x, p.y, t, {
          scale: unitScale,
          phase: p.phase,
          recoil: p.recoil,
          pulse: p.pulse,
          charge: p.charge,
          biteT: p.biteT,
          fuse: p.def.bomb ? Math.min(1, p.timer / p.def.bomb.fuse) : 0,
          hpRatio: p.maxHp ? p.hp / p.maxHp : 1,
          up: p.upgrades,
          buff: p.buffDamage || 0,
          haste: p.haste || 0,
          chew: p.chewMax > 0 ? Math.max(0, 1 - p.chewT / p.chewMax) : 0,
          armed: !!p.armed,
          arm: p.def.mine ? Math.min(1, (p.armT || 0) / p.def.mine.arm) : 1,
          pullT: p.pullT || 0,
          shell: p.shell || null
        });
        const dots = upgradeDots(p);
        if (dots.length) this.drawUpgradePips(ctx, p, dots);
        if (p.shell) this.drawShellBar(ctx, p);
      }
      const zombies = game.zombies.filter((z) => z.row === r).sort((a, b) => a.x - b.x);
      for (const z of zombies) {
        const zx = z.x + (z.hurt > 0 ? Math.sin(t * 80) * 2 : 0);
        const zMax = Math.max(1, z.maxHp || z.def.hp);
        drawZombie(ctx, z.type, zx, z.y, t, {
          phase: z.phase,
          animT: z.anim,
          eating: z.eating,
          eatBite: z.eatBite || 0,
          chompT: z.chomp || 0,
          slowT: z.slowT,
          armor: z.armor,
          maxArmor: z.maxArmor,
          armorRatio: z.maxArmor > 0 ? z.armor / z.maxArmor : 1,
          armorType: z.armorType,
          armorPulse: z.armorPulse,
          supportPulse: z.supportPulse,
          burnT: z.burnT,
          hpRatio: z.hp / zMax,
          hurt: z.hurt,
          stunT: z.stunT,
          rageT: z.rageT,
          auraPulse: z.auraPulse,
          wailT: z.wailT,
          dying: z.dying,
          death: z.dying ? Math.min(1, z.deathT / z.deathDur) : 0,
          deathDur: z.deathDur,
          vaultArc: z.vaultArc,
          objectHop: z.objectHop,
          def: z.def,
          scale: unitScale
        });
        if (!z.dying && game.settings.healthBars !== 'off') {
          this.drawHpBar(ctx, z, game.settings.healthBars);
        }
        if (!z.dying && z.vulnT > 0) {
          ctx.save();
          ctx.globalAlpha = 0.35 + Math.sin(t * 6 + z.phase) * 0.12;
          ctx.strokeStyle = 'rgba(182,112,190,0.9)';
          ctx.lineWidth = 1.4;
          ctx.setLineDash([4, 5]);
          ctx.lineDashOffset = -t * 14;
          ctx.beginPath();
          ctx.ellipse(z.x, z.y + 24, 24, 7, 0, 0, Math.PI * 2);
          ctx.stroke();
          ctx.restore();
        }
      }
    }

    for (const p of game.projectiles) {
      ctx.save();
      if (p.fire) drawFireProjectile(ctx, p, t);
      if (p.starRay) {
        const angle = Math.atan2(p.vy, p.vx);
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate(angle);
        ctx.strokeStyle = 'rgba(255,222,138,0.42)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(-28, 0);
        ctx.lineTo(-8, 0);
        ctx.stroke();
        ctx.rotate(t * 7);
        ctx.globalAlpha = 0.9;
        ctx.drawImage(getStarGlowSprite(), -18, -18, 36, 36);
        ctx.globalAlpha = 1;
        ctx.drawImage(getStarSprite(), -11, -11, 22, 22);
        ctx.restore();
        ctx.restore();
        continue;
      }
      if (p.homing) {
        const glow = ctx.createRadialGradient(p.x, p.y, 1, p.x, p.y, 16);
        glow.addColorStop(0, 'rgba(255,226,160,0.92)');
        glow.addColorStop(0.45, 'rgba(255,150,70,0.5)');
        glow.addColorStop(1, 'rgba(255,120,50,0)');
        ctx.fillStyle = glow;
        ctx.beginPath();
        ctx.arc(p.x, p.y, 16, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#ffe6b0';
        ctx.beginPath();
        ctx.ellipse(p.x, p.y, 5, 3.4, -0.4, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = 'rgba(255,170,90,0.55)';
        ctx.lineWidth = 1.6;
        ctx.beginPath();
        ctx.moveTo(p.x - 12, p.y + 4);
        ctx.quadraticCurveTo(p.x - 22, p.y - 4, p.x - 28, p.y + 2);
        ctx.stroke();
        ctx.restore();
        continue;
      }
      if (p.lob) {
        const groundY = game.rowY(p.row) + 30;
        ctx.fillStyle = 'rgba(0,0,0,0.22)';
        ctx.beginPath();
        ctx.ellipse(p.x, groundY, 8, 3, 0, 0, Math.PI * 2);
        ctx.fill();
        const glow = ctx.createRadialGradient(p.x, p.y, 1, p.x, p.y, 13);
        glow.addColorStop(0, 'rgba(255,244,214,0.8)');
        glow.addColorStop(1, 'rgba(230,200,150,0)');
        ctx.fillStyle = glow;
        ctx.beginPath();
        ctx.arc(p.x, p.y, 13, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#f4ead2';
        ctx.strokeStyle = '#b79a6a';
        ctx.lineWidth = 1.2;
        ctx.beginPath();
        ctx.arc(p.x, p.y, 6, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
        ctx.fillStyle = 'rgba(232,214,170,0.9)';
        ctx.beginPath();
        ctx.arc(p.x - 2, p.y - 2, 1.6, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
        continue;
      }
      if (p.star) {
        const glow = ctx.createRadialGradient(p.x, p.y, 1, p.x, p.y, 14);
        glow.addColorStop(0, 'rgba(255,240,190,0.85)');
        glow.addColorStop(1, 'rgba(240,190,90,0)');
        ctx.fillStyle = glow;
        ctx.beginPath();
        ctx.arc(p.x, p.y, 14, 0, Math.PI * 2);
        ctx.fill();
        ctx.translate(p.x, p.y);
        ctx.rotate(t * 6);
        ctx.fillStyle = '#ffe9a6';
        ctx.strokeStyle = 'rgba(255,190,90,0.7)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        for (let i = 0; i < 10; i++) {
          const a = (i / 10) * Math.PI * 2 - Math.PI / 2;
          const r = i % 2 === 0 ? 7 : 3;
          const px = Math.cos(a) * r;
          const py = Math.sin(a) * r;
          if (i === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
        ctx.restore();
        continue;
      }
      if (p.needle) {
        ctx.translate(p.x, p.y);
        ctx.strokeStyle = 'rgba(255,248,220,0.9)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(-12, 0);
        ctx.lineTo(9, 0);
        ctx.stroke();
        ctx.fillStyle = '#e7d18f';
        ctx.beginPath();
        ctx.moveTo(13, 0);
        ctx.lineTo(8, -3);
        ctx.lineTo(8, 3);
        ctx.closePath();
        ctx.fill();
        ctx.strokeStyle = 'rgba(220,200,150,0.35)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(-18, 2);
        ctx.lineTo(-11, 2);
        ctx.stroke();
        ctx.restore();
        continue;
      }
      if (p.gravel) {
        ctx.translate(p.x, p.y);
        ctx.rotate(Math.atan2(0, 1) + Math.sin(p.x * 0.1) * 0.4);
        ctx.fillStyle = '#b8aa92';
        ctx.strokeStyle = '#6d6255';
        ctx.lineWidth = 1.2;
        ctx.beginPath();
        ctx.moveTo(-6, -4);
        ctx.lineTo(4, -5);
        ctx.lineTo(7, 2);
        ctx.lineTo(1, 6);
        ctx.lineTo(-5, 4);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
        ctx.restore();
        continue;
      }
      if (p.big) {
        const glow = ctx.createRadialGradient(p.x, p.y, 2, p.x, p.y, 24);
        glow.addColorStop(0, 'rgba(255,225,150,0.55)');
        glow.addColorStop(1, 'rgba(255,200,90,0)');
        ctx.fillStyle = glow;
        ctx.beginPath();
        ctx.arc(p.x, p.y, 24, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.translate(p.x, p.y);
      ctx.scale(p.big ? 1.7 : 1, p.big ? 1.7 : 1);
      ctx.rotate(-0.12);
      ctx.strokeStyle = p.fire ? '#ffd08a' : p.big ? '#ffe9b0' : '#e0c88f';
      ctx.lineWidth = p.big ? 4 : 3;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(-9, 0);
      ctx.lineTo(8, 0);
      ctx.stroke();
      ctx.fillStyle = p.fire ? '#ff7a3c' : p.big ? '#d9a441' : '#b03a2c';
      ctx.beginPath();
      ctx.moveTo(8, 0);
      ctx.lineTo(3, -3);
      ctx.lineTo(3, 3);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    }

    for (const p of game.particles) {
      const a = Math.max(0, p.life / p.maxLife);
      ctx.globalAlpha = a;
      if (p.kind === 'ring') {
        ctx.strokeStyle = p.color;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size + (1 - a) * 26, 0, Math.PI * 2);
        ctx.stroke();
      } else if (p.kind === 'shard') {
        ctx.fillStyle = p.color;
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate(p.life * 6);
        ctx.fillRect(-p.size / 2, -p.size / 2, p.size, p.size * 0.7);
        ctx.restore();
      } else {
        ctx.fillStyle = p.color;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.globalAlpha = 1;
    }

    for (const o of game.orbs) {
      const bob = o.landed ? Math.sin(t * 3 + o.phase) * 2 : 0;
      const alpha = o.life < 2 ? 0.55 + Math.sin(t * 14) * 0.25 : 1;
      ctx.globalAlpha = alpha;
      const g = ctx.createRadialGradient(o.x, o.y + bob, 2, o.x, o.y + bob, 26);
      g.addColorStop(0, 'rgba(255,232,170,0.95)');
      g.addColorStop(0.35, 'rgba(255,170,70,0.6)');
      g.addColorStop(1, 'rgba(255,140,50,0)');
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(o.x, o.y + bob, 26, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#fff3cf';
      ctx.beginPath();
      ctx.arc(o.x, o.y + bob, 4.6, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 1;
    }

    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (const f of game.floaters) {
      const a = Math.max(0, f.life / f.maxLife);
      ctx.globalAlpha = Math.min(1, a * 1.6);
      ctx.font = `700 ${f.size ?? 18}px "KaiTi","STKaiti",serif`;
      ctx.lineWidth = 3;
      ctx.strokeStyle = 'rgba(20,12,9,0.8)';
      ctx.strokeText(f.text, f.x, f.y);
      ctx.fillStyle = f.color;
      ctx.fillText(f.text, f.x, f.y);
      ctx.globalAlpha = 1;
    }

    drawMapForeground(ctx, game, t);

    if (game.phase === 'playing' && game.hoverTarget && !game.selected && !game.shovel) {
      const hp = game.hoverTarget;
      const label = game.hoverLabel(hp);
      const baseH = hp.isShell ? 52 : hp.isLily ? 22 : (hp.def.spriteH || 80) * (game.unitScale || 1);
      ctx.save();
      ctx.strokeStyle = hp.isLily ? 'rgba(150,224,206,0.9)' : hp.isShell ? 'rgba(196,220,158,0.95)' : 'rgba(246,214,142,0.9)';
      ctx.lineWidth = 1.6;
      ctx.setLineDash([4, 5]);
      ctx.lineDashOffset = -t * 12;
      ctx.beginPath();
      if (hp.isShell) ctx.ellipse(hp.x, hp.y - 12, 47, 39, 0, 0, Math.PI * 2);
      else ctx.ellipse(hp.x, hp.y + (hp.isLily ? 22 : 20), hp.isLily ? 35 : 27, hp.isLily ? 10 : 7, 0, 0, Math.PI * 2);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.font = '700 11px "Microsoft YaHei UI","Microsoft YaHei",sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      const ty = hp.y - baseH - 8;
      const tw = Math.max(46, ctx.measureText(label).width + 18);
      ctx.fillStyle = 'rgba(8,13,20,0.82)';
      rr(ctx, hp.x - tw / 2, ty - 10, tw, 20, 6);
      ctx.fill();
      ctx.strokeStyle = 'rgba(226,192,122,0.3)';
      ctx.lineWidth = 1;
      rr(ctx, hp.x - tw / 2, ty - 10, tw, 20, 6);
      ctx.stroke();
      ctx.fillStyle = '#f2dfb2';
      ctx.fillText(label, hp.x, ty + 1);
      ctx.restore();
    }

    if (game.phase === 'playing' && game.shovel && game.hover) {
      const { c, r } = game.hover;
      const pos = game.cellPos(c, r);
      const occupied = !!game.cells[r][c];
      ctx.fillStyle = occupied ? 'rgba(200,60,45,0.16)' : 'rgba(230,200,120,0.05)';
      ctx.fillRect(
        pos.x - BOARD.cw / 2 + 2, pos.y - game.cellH / 2 + 2,
        BOARD.cw - 4, game.cellH - 4
      );
      ctx.strokeStyle = occupied ? 'rgba(235,110,80,0.9)' : 'rgba(240,200,120,0.35)';
      ctx.lineWidth = 2;
      ctx.setLineDash([6, 5]);
      ctx.strokeRect(
        pos.x - BOARD.cw / 2 + 3, pos.y - game.cellH / 2 + 3,
        BOARD.cw - 6, game.cellH - 6
      );
      ctx.setLineDash([]);
    }

    if (game.phase === 'playing' && game.selected >= 0 && game.hover) {
      const { c, r } = game.hover;
      const pos = game.cellPos(c, r);
      const occupied = !!game.cells[r][c];
      ctx.fillStyle = occupied ? 'rgba(180,60,45,0.18)' : 'rgba(235,190,105,0.12)';
      ctx.fillRect(
        pos.x - BOARD.cw / 2 + 2, pos.y - game.cellH / 2 + 2,
        BOARD.cw - 4, game.cellH - 4
      );
      ctx.strokeStyle = occupied ? 'rgba(220,90,60,0.8)' : 'rgba(240,200,120,0.85)';
      ctx.lineWidth = 2;
      ctx.setLineDash([6, 5]);
      ctx.strokeRect(
        pos.x - BOARD.cw / 2 + 3, pos.y - game.cellH / 2 + 3,
        BOARD.cw - 6, game.cellH - 6
      );
      ctx.setLineDash([]);
      if (!occupied) {
        ctx.globalAlpha = 0.42;
        drawPlant(ctx, game.cards[game.selected].id, pos.x, pos.y, t, { noShadow: true, armed: true, arm: 1, scale: unitScale });
        ctx.globalAlpha = 1;
      }
    }
  }

  drawHpBar(ctx, z, mode) {
    const maxHp = Math.max(1, z.maxHp || z.def.hp);
    const hp = Math.max(0, Math.min(maxHp, z.hp));
    const ratio = hp / maxHp;
    const maxArmor = Math.max(0, z.maxArmor || 0);
    const armor = Math.max(0, Math.min(maxArmor, z.armor || 0));
    const armorRatio = maxArmor > 0 ? armor / maxArmor : 0;
    const s = z.def.scale ?? 1;
    const w = z.type === 'sedan' || z.def.large ? 58 : 48;
    const h = 7;
    const x = z.x - w / 2;
    let y = z.y - 58 * s;
    if (assets.zombies[z.type]) {
      const baseH = z.def.spriteH ?? 96;
      y = z.y + (34 - baseH) * s - 12;
    }
    y = Math.max(maxArmor > 0 ? 194 : 184, y);

    if (maxArmor > 0) {
      const ay = y - 6;
      ctx.save();
      ctx.fillStyle = 'rgba(7,10,18,0.8)';
      rr(ctx, x - 1, ay - 1, w + 2, 5, 3);
      ctx.fill();
      ctx.restore();
      if (armorRatio > 0) {
        const ag = ctx.createLinearGradient(x, ay, x + w, ay);
        ag.addColorStop(0, '#f2d58a');
        ag.addColorStop(1, '#b07b36');
        ctx.fillStyle = ag;
        rr(ctx, x, ay, Math.max(1, w * armorRatio), 3, 2);
        ctx.fill();
      }
    }

    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,0.45)';
    ctx.shadowBlur = 6;
    ctx.fillStyle = 'rgba(7,10,18,0.8)';
    rr(ctx, x - 1, y - 1, w + 2, h + 2, 5);
    ctx.fill();
    ctx.restore();
    ctx.strokeStyle = 'rgba(235,205,145,0.35)';
    ctx.lineWidth = 1;
    rr(ctx, x - 1, y - 1, w + 2, h + 2, 5);
    ctx.stroke();

    if (ratio > 0) {
      const grad = ctx.createLinearGradient(x, y, x + w, y);
      grad.addColorStop(0, '#ff9d7c');
      grad.addColorStop(1, '#b52f2b');
      ctx.fillStyle = grad;
      rr(ctx, x, y, Math.max(2, w * ratio), h, 4);
      ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,0.30)';
      ctx.fillRect(x + 3, y + 1.2, Math.max(0, (w - 6) * ratio), 1.4);
    }

    if (mode === 'barText') {
      const label = maxArmor > 0
        ? `${Math.ceil(hp)}/${maxHp} · 甲${Math.ceil(armor)}/${maxArmor}`
        : `${Math.ceil(hp)} / ${maxHp}`;
      ctx.font = '700 8.5px "Microsoft YaHei UI","Microsoft YaHei",sans-serif';
      const tw = ctx.measureText(label).width;
      const cw = tw + 10;
      const cx = Math.max(x + w + 4, Math.min(1280 - cw - 4, x + w + 6));
      const cy = maxArmor > 0 ? y - 8 : y - 4;
      ctx.fillStyle = 'rgba(7,10,18,0.84)';
      rr(ctx, cx, cy, cw, 14, 5);
      ctx.fill();
      ctx.strokeStyle = 'rgba(235,205,145,0.3)';
      ctx.lineWidth = 1;
      ctx.stroke();
      ctx.fillStyle = '#f6e8c8';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(label, cx + cw / 2, cy + 7);
    }
  }

  drawShellBar(ctx, p) {
    const ratio = Math.max(0, Math.min(1, p.shell.hp / p.shell.maxHp));
    const w = 42;
    const h = 4;
    const x = p.x - w / 2;
    const y = p.y + 37;
    ctx.save();
    ctx.fillStyle = 'rgba(7,12,16,0.78)';
    rr(ctx, x - 1, y - 1, w + 2, h + 2, 3);
    ctx.fill();
    ctx.fillStyle = ratio > 0.35 ? '#8fb27a' : '#b8894c';
    rr(ctx, x, y, Math.max(1, w * ratio), h, 2);
    ctx.fill();
    ctx.restore();
  }

  drawUpgradePips(ctx, p, dots) {    const w = 8 + dots.length * 7;
    const x = p.x - w / 2;
    const y = p.y + 28;
    ctx.fillStyle = 'rgba(12,9,8,0.5)';
    ctx.beginPath();
    ctx.roundRect(x, y, w, 8, 4);
    ctx.fill();
    for (let i = 0; i < dots.length; i++) {
      ctx.fillStyle = dots[i];
      ctx.beginPath();
      ctx.arc(x + 5 + i * 7, y + 4, 2.2, 0, Math.PI * 2);
      ctx.fill();
    }
  }
}
