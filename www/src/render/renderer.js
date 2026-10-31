import { BOARD, BOARD_H, BOARD_W, VIEW, cellCenter } from '../layout.js';
import { drawMower, drawPlant, drawZombie } from './art.js';
import { drawUI, drawMenuBackdrop } from '../ui/ui.js';
import { upgradeDots } from '../game/upgrade.js';
import { assets } from '../core/assets.js';

const ROW_Y = Array.from({ length: BOARD.rows }, (_, r) =>
  BOARD.y + r * BOARD.ch + BOARD.ch / 2
);

function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
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
    const key = `${mode}:${this.scale.toFixed(4)}:${this.canvasW}x${this.canvasH}:${this.ox}x${this.oy}`;
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
      const layer = this.sceneLayer();
      bg.drawImage(layer, this.ox, this.oy, VIEW.w * this.scale, VIEW.h * this.scale);
    }
    this.drawLetterboxBackdrop(bg, game);
  }

  sceneLayer() {
    const key = `${this.scale.toFixed(4)}:${VIEW.w}x${VIEW.h}`;
    if (this._sceneLayer && this._sceneLayer.key === key) return this._sceneLayer.canvas;
    const canvas = document.createElement('canvas');
    canvas.width = Math.ceil(VIEW.w * this.scale);
    canvas.height = Math.ceil(VIEW.h * this.scale);
    const layer = canvas.getContext('2d');
    layer.scale(this.scale, this.scale);
    this.drawBackgroundBase(layer);
    this.drawBoard(layer);
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

  drawBackgroundBase(ctx) {
    const bg = assets.backgrounds.board;
    if (bg) {
      const scale = Math.max(VIEW.w / bg.width, VIEW.h / bg.height);
      const w = bg.width * scale;
      const h = bg.height * scale;
      ctx.drawImage(bg, (VIEW.w - w) / 2, (VIEW.h - h) / 2, w, h);

      const shade = ctx.createLinearGradient(0, 0, 0, VIEW.h);
      shade.addColorStop(0, 'rgba(5,9,20,0.62)');
      shade.addColorStop(0.42, 'rgba(7,11,22,0.22)');
      shade.addColorStop(1, 'rgba(4,6,12,0.66)');
      ctx.fillStyle = shade;
      ctx.fillRect(0, 0, VIEW.w, VIEW.h);

      const vignette = ctx.createRadialGradient(640, 360, 210, 640, 360, 780);
      vignette.addColorStop(0, 'rgba(0,0,0,0)');
      vignette.addColorStop(0.72, 'rgba(3,5,10,0.18)');
      vignette.addColorStop(1, 'rgba(2,3,7,0.62)');
      ctx.fillStyle = vignette;
      ctx.fillRect(0, 0, VIEW.w, VIEW.h);

      const warm = ctx.createRadialGradient(640, 150, 20, 640, 150, 560);
      warm.addColorStop(0, 'rgba(255,178,88,0.10)');
      warm.addColorStop(1, 'rgba(255,160,70,0)');
      ctx.fillStyle = warm;
      ctx.fillRect(0, 0, VIEW.w, VIEW.h);

      return;
    }

    const g = ctx.createLinearGradient(0, 0, 0, VIEW.h);
    g.addColorStop(0, '#0b0e16');
    g.addColorStop(0.42, '#171d27');
    g.addColorStop(1, '#120e12');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, VIEW.w, VIEW.h);

    const mg = ctx.createRadialGradient(1100, 90, 8, 1100, 90, 170);
    mg.addColorStop(0, 'rgba(216,226,244,0.18)');
    mg.addColorStop(1, 'rgba(216,226,244,0)');
    ctx.fillStyle = mg;
    ctx.fillRect(900, 0, 380, 320);
    ctx.fillStyle = 'rgba(230,234,244,0.25)';
    ctx.beginPath();
    ctx.arc(1100, 94, 32, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#0a0c11';
    ctx.beginPath();
    ctx.moveTo(0, 196);
    for (let x = 0; x <= VIEW.w; x += 64) {
      const top = 150 + ((x * 17) % 30);
      ctx.lineTo(x + 14, top);
      ctx.lineTo(x + 36, top + 16);
      ctx.lineTo(x + 64, 182);
    }
    ctx.lineTo(VIEW.w, 210);
    ctx.lineTo(VIEW.w, 244);
    ctx.lineTo(0, 244);
    ctx.closePath();
    ctx.fill();

    ctx.fillStyle = '#1a120f';
    ctx.fillRect(0, 0, 226, VIEW.h);
    ctx.strokeStyle = 'rgba(96,64,42,0.22)';
    ctx.lineWidth = 1;
    for (let x = 16; x < 226; x += 32) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, VIEW.h);
      ctx.stroke();
    }

    ctx.fillStyle = '#0d0e13';
    ctx.beginPath();
    ctx.moveTo(1046, VIEW.h);
    ctx.lineTo(1046, 330);
    ctx.lineTo(1100, 300);
    ctx.lineTo(1180, 312);
    ctx.lineTo(1240, 284);
    ctx.lineTo(1280, 300);
    ctx.lineTo(1280, VIEW.h);
    ctx.closePath();
    ctx.fill();

    this.hangingLantern(ctx, 1226, 250, t, 0.9);
    this.hangingLantern(ctx, 1262, 408, t, 0.75);
    this.hangingLantern(ctx, 1210, 520, t, 0.85);

    const mist = ctx.createLinearGradient(0, 200, 0, 330);
    mist.addColorStop(0, 'rgba(120,140,170,0.05)');
    mist.addColorStop(1, 'rgba(120,140,170,0)');
    ctx.fillStyle = mist;
    ctx.fillRect(226, 180, 1054, 180);
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

  hangingLantern(ctx, x, y, t, s) {
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(s, s);
    ctx.rotate(Math.sin(t * 1.6 + x) * 0.04);
    ctx.strokeStyle = 'rgba(120,90,60,0.5)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(0, -80);
    ctx.lineTo(0, -22);
    ctx.stroke();

    const g = ctx.createRadialGradient(0, 0, 3, 0, 0, 34);
    g.addColorStop(0, 'rgba(255,170,70,0.35)');
    g.addColorStop(1, 'rgba(255,140,50,0)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(0, 0, 34, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#b8342a';
    ctx.strokeStyle = 'rgba(24,14,10,0.8)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.ellipse(0, 0, 13, 17, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = '#d9a441';
    ctx.fillRect(-6, -19, 12, 4);
    ctx.fillRect(-6, 15, 12, 4);
    ctx.restore();
  }

  drawBoard(ctx) {
    const B = BOARD;
    ctx.save();

    ctx.shadowColor = 'rgba(0,0,0,0.5)';
    ctx.shadowBlur = 30;
    const frame = ctx.createLinearGradient(0, B.y - 20, 0, B.y + BOARD_H + 20);
    frame.addColorStop(0, 'rgba(48,35,25,0.88)');
    frame.addColorStop(0.5, 'rgba(20,16,20,0.9)');
    frame.addColorStop(1, 'rgba(38,26,20,0.92)');
    ctx.fillStyle = frame;
    rr(ctx, B.x - 20, B.y - 20, BOARD_W + 40, BOARD_H + 40, 18);
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.strokeStyle = 'rgba(222,180,104,0.66)';
    ctx.lineWidth = 1.6;
    ctx.stroke();

    ctx.fillStyle = 'rgba(8,13,24,0.58)';
    rr(ctx, B.x - 2, B.y - 2, BOARD_W + 4, BOARD_H + 4, 12);
    ctx.fill();

    for (let r = 0; r < B.rows; r++) {
      for (let c = 0; c < B.cols; c++) {
        const x = B.x + c * B.cw;
        const y = B.y + r * B.ch;
        ctx.fillStyle = (r + c) % 2 === 0
          ? 'rgba(11,18,31,0.50)'
          : 'rgba(16,24,39,0.40)';
        ctx.fillRect(x, y, B.cw, B.ch);
        ctx.strokeStyle = 'rgba(228,192,120,0.075)';
        ctx.lineWidth = 1;
        ctx.strokeRect(x + 0.5, y + 0.5, B.cw - 1, B.ch - 1);
        ctx.strokeStyle = 'rgba(150,210,210,0.035)';
        ctx.beginPath();
        ctx.moveTo(x + 10, y + B.ch - 13);
        ctx.lineTo(x + B.cw - 12, y + B.ch - 13);
        ctx.stroke();
      }
    }

    const laneGlow = ctx.createLinearGradient(0, B.y, 0, B.y + BOARD_H);
    laneGlow.addColorStop(0, 'rgba(255,182,96,0.06)');
    laneGlow.addColorStop(0.5, 'rgba(255,182,96,0.015)');
    laneGlow.addColorStop(1, 'rgba(40,90,110,0.05)');
    ctx.fillStyle = laneGlow;
    ctx.fillRect(B.x, B.y, BOARD_W, BOARD_H);

    const lg = ctx.createLinearGradient(B.x, 0, B.x + 54, 0);
    lg.addColorStop(0, 'rgba(0,0,0,0.38)');
    lg.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = lg;
    ctx.fillRect(B.x, B.y, 54, BOARD_H);

    const rg = ctx.createLinearGradient(B.x + BOARD_W - 110, 0, B.x + BOARD_W, 0);
    rg.addColorStop(0, 'rgba(0,0,0,0)');
    rg.addColorStop(1, 'rgba(0,0,0,0.38)');
    ctx.fillStyle = rg;
    ctx.fillRect(B.x + BOARD_W - 110, B.y, 110, BOARD_H);

    const wg = ctx.createRadialGradient(
      B.x + BOARD_W / 2, B.y, 10,
      B.x + BOARD_W / 2, B.y, 440
    );
    wg.addColorStop(0, 'rgba(255,190,100,0.08)');
    wg.addColorStop(1, 'rgba(255,180,80,0)');
    ctx.fillStyle = wg;
    ctx.fillRect(B.x, B.y, BOARD_W, BOARD_H);

    ctx.strokeStyle = 'rgba(226,192,122,0.20)';
    ctx.lineWidth = 1;
    rr(ctx, B.x + 4, B.y + 4, BOARD_W - 8, BOARD_H - 8, 9);
    ctx.stroke();

    ctx.strokeStyle = 'rgba(230,194,118,0.62)';
    ctx.lineWidth = 2;
    const corners = [
      [B.x - 14, B.y - 14, 1, 1],
      [B.x + BOARD_W + 14, B.y - 14, -1, 1],
      [B.x - 14, B.y + BOARD_H + 14, 1, -1],
      [B.x + BOARD_W + 14, B.y + BOARD_H + 14, -1, -1]
    ];
    for (const [x, y, sx, sy] of corners) {
      ctx.beginPath();
      ctx.moveTo(x + sx * 20, y);
      ctx.lineTo(x, y);
      ctx.lineTo(x, y + sy * 20);
      ctx.stroke();
    }

    ctx.restore();
  }

  drawWorld(ctx, game, t) {
    for (const m of game.mowers) {
      drawMower(ctx, m.x, ROW_Y[m.row] + 10, t, m);
    }

    for (let r = 0; r < BOARD.rows; r++) {
      const plants = game.plants.filter((p) => p.r === r).sort((a, b) => a.x - b.x);
      for (const p of plants) {
        drawPlant(ctx, p.type, p.x, p.y, t, {
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
          eating: z.eating,
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
          dying: z.dying,
          death: z.dying ? Math.min(1, z.deathT / z.deathDur) : 0,
          deathDur: z.deathDur,
          vaultArc: z.vaultArc,
          def: z.def
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
        const groundY = ROW_Y[p.row] + 30;
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
      ctx.strokeStyle = p.big ? '#ffe9b0' : '#e0c88f';
      ctx.lineWidth = p.big ? 4 : 3;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(-9, 0);
      ctx.lineTo(8, 0);
      ctx.stroke();
      ctx.fillStyle = p.big ? '#d9a441' : '#b03a2c';
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

    if (game.phase === 'playing' && game.shovel && game.hover) {
      const { c, r } = game.hover;
      const pos = cellCenter(c, r);
      const occupied = !!game.cells[r][c];
      ctx.fillStyle = occupied ? 'rgba(200,60,45,0.16)' : 'rgba(230,200,120,0.05)';
      ctx.fillRect(
        pos.x - BOARD.cw / 2 + 2, pos.y - BOARD.ch / 2 + 2,
        BOARD.cw - 4, BOARD.ch - 4
      );
      ctx.strokeStyle = occupied ? 'rgba(235,110,80,0.9)' : 'rgba(240,200,120,0.35)';
      ctx.lineWidth = 2;
      ctx.setLineDash([6, 5]);
      ctx.strokeRect(
        pos.x - BOARD.cw / 2 + 3, pos.y - BOARD.ch / 2 + 3,
        BOARD.cw - 6, BOARD.ch - 6
      );
      ctx.setLineDash([]);
    }

    if (game.phase === 'playing' && game.selected >= 0 && game.hover) {
      const { c, r } = game.hover;
      const pos = cellCenter(c, r);
      const occupied = !!game.cells[r][c];
      ctx.fillStyle = occupied ? 'rgba(180,60,45,0.18)' : 'rgba(235,190,105,0.12)';
      ctx.fillRect(
        pos.x - BOARD.cw / 2 + 2, pos.y - BOARD.ch / 2 + 2,
        BOARD.cw - 4, BOARD.ch - 4
      );
      ctx.strokeStyle = occupied ? 'rgba(220,90,60,0.8)' : 'rgba(240,200,120,0.85)';
      ctx.lineWidth = 2;
      ctx.setLineDash([6, 5]);
      ctx.strokeRect(
        pos.x - BOARD.cw / 2 + 3, pos.y - BOARD.ch / 2 + 3,
        BOARD.cw - 6, BOARD.ch - 6
      );
      ctx.setLineDash([]);
      if (!occupied) {
        ctx.globalAlpha = 0.42;
        drawPlant(ctx, game.cards[game.selected].id, pos.x, pos.y, t, { noShadow: true });
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
