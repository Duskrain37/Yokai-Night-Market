import { LEVELS_UI, levelCardRect } from '../layout.js';
import { LEVELS } from '../content.js';

const KAI = '"Microsoft YaHei UI","Microsoft YaHei","PingFang SC",sans-serif';
const DISPLAY = '"STKaiti","KaiTi","Kaiti SC",serif';

function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}

function threatColor(threat) {
  if (threat >= 4.2) return '#b5432f';
  if (threat >= 2.8) return '#b5612a';
  return '#c79a3b';
}

function drawButton(ctx, r, label, primary) {
  ctx.save();
  ctx.shadowColor = primary ? 'rgba(170,50,34,0.42)' : 'rgba(0,0,0,0.4)';
  ctx.shadowBlur = 16;
  ctx.shadowOffsetY = 5;
  const g = ctx.createLinearGradient(0, r.y, 0, r.y + r.h);
  if (primary) {
    g.addColorStop(0, '#d35a41');
    g.addColorStop(1, '#7a221c');
  } else {
    g.addColorStop(0, '#1b263a');
    g.addColorStop(1, '#0c121e');
  }
  ctx.fillStyle = g;
  rr(ctx, r.x, r.y, r.w, r.h, 11);
  ctx.fill();
  ctx.restore();
  ctx.strokeStyle = 'rgba(240,204,128,0.85)';
  ctx.lineWidth = 1.6;
  rr(ctx, r.x, r.y, r.w, r.h, 11);
  ctx.stroke();
  ctx.fillStyle = '#fff0cc';
  ctx.font = `700 ${primary ? 23 : 20}px ${KAI}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(label, r.x + r.w / 2, r.y + r.h / 2 + 1);
}

export function drawLevels(ctx, game) {
  const p = LEVELS_UI.panel;
  ctx.fillStyle = 'rgba(3,5,10,0.76)';
  ctx.fillRect(0, 0, 1280, 720);

  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.52)';
  ctx.shadowBlur = 32;
  ctx.shadowOffsetY = 10;
  const panelGrad = ctx.createLinearGradient(0, p.y, 0, p.y + p.h);
  panelGrad.addColorStop(0, 'rgba(19,28,46,0.98)');
  panelGrad.addColorStop(0.5, 'rgba(12,19,33,0.98)');
  panelGrad.addColorStop(1, 'rgba(9,14,25,0.98)');
  ctx.fillStyle = panelGrad;
  rr(ctx, p.x, p.y, p.w, p.h, 16);
  ctx.fill();
  ctx.restore();
  ctx.strokeStyle = 'rgba(226,192,122,0.6)';
  ctx.lineWidth = 1.6;
  rr(ctx, p.x, p.y, p.w, p.h, 16);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(255,240,200,0.1)';
  ctx.lineWidth = 1;
  rr(ctx, p.x + 6, p.y + 6, p.w - 12, p.h - 12, 12);
  ctx.stroke();
  ctx.fillStyle = 'rgba(255,222,150,0.32)';
  ctx.fillRect(p.x + 50, p.y + 1, p.w - 100, 1);

  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.font = `700 30px ${DISPLAY}`;
  ctx.fillStyle = '#f2e2bb';
  ctx.fillText('十夜', 640, LEVELS_UI.titleY);

  ctx.font = `400 12px ${KAI}`;
  ctx.fillStyle = 'rgba(235,218,184,0.5)';
  ctx.fillText('第 10 夜的综合难度约为第 1 夜的 5 倍；选一夜，回封面开张', 640, 176);

  for (let i = 0; i < LEVELS.length; i++) {
    const level = LEVELS[i];
    const card = levelCardRect(i);
    const selected = game.selectedLevel === level.id;
    const cleared = game.progress.cleared.includes(level.id);

    ctx.fillStyle = selected ? '#e9dcc0' : 'rgba(46,30,22,0.96)';
    rr(ctx, card.x, card.y, card.w, card.h, 8);
    ctx.fill();
    ctx.strokeStyle = selected ? '#e3b45e' : 'rgba(180,140,90,0.35)';
    ctx.lineWidth = selected ? 2.4 : 1.2;
    ctx.stroke();

    ctx.fillStyle = threatColor(level.threat);
    rr(ctx, card.x + 1, card.y + 1, card.w - 2, 5, 4);
    ctx.fill();

    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';
    ctx.fillStyle = selected ? 'rgba(90,70,48,0.45)' : 'rgba(232,211,162,0.35)';
    ctx.font = `700 27px ${KAI}`;
    ctx.fillText(String(level.id).padStart(2, '0'), card.x + 12, card.y + 14);

    ctx.fillStyle = selected ? '#3a2b1d' : '#efe0bd';
    ctx.font = `700 16px ${KAI}`;
    ctx.fillText(level.name, card.x + 12, card.y + 52);

    ctx.fillStyle = selected ? '#7a6347' : 'rgba(232,211,162,0.65)';
    ctx.font = `400 12px ${KAI}`;
    ctx.fillText(level.tag, card.x + 12, card.y + 76);

    ctx.fillStyle = selected ? '#8a6a26' : 'rgba(232,211,162,0.75)';
    ctx.font = `700 11px ${KAI}`;
    ctx.fillText(`综合 ${level.threat.toFixed(1)}×`, card.x + 12, card.y + 108);

    ctx.fillStyle = threatColor(level.threat);
    const barW = 58;
    ctx.fillRect(card.x + 12, card.y + 128, barW, 4);
    ctx.fillStyle = selected ? 'rgba(90,70,48,0.16)' : 'rgba(255,235,196,0.12)';
    ctx.fillRect(
      card.x + 12 + (barW * level.threat) / 5,
      card.y + 128,
      barW * (1 - level.threat / 5),
      4
    );

    if (cleared) {
      ctx.save();
      ctx.translate(card.x + card.w - 26, card.y + 26);
      ctx.rotate(-0.12);
      ctx.fillStyle = selected ? 'rgba(168,58,43,0.85)' : 'rgba(168,58,43,0.7)';
      rr(ctx, -18, -10, 36, 20, 4);
      ctx.fill();
      ctx.fillStyle = '#f4dfb0';
      ctx.font = `700 11px ${KAI}`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('已过', 0, 1);
      ctx.restore();
    }

    if (selected) {
      ctx.fillStyle = '#b53a2b';
      rr(ctx, card.x + card.w - 42, card.y + card.h - 24, 34, 17, 4);
      ctx.fill();
      ctx.fillStyle = '#f4dfb0';
      ctx.font = `700 9px ${KAI}`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('当前', card.x + card.w - 25, card.y + card.h - 15);
    }
  }

  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = 'rgba(235,218,184,0.42)';
  ctx.font = `400 11px ${KAI}`;
  ctx.fillText(
    `已过 ${game.progress.cleared.length} / ${LEVELS.length} 夜 · 点击关卡进入备战`,
    350, 540
  );

  drawButton(ctx, LEVELS_UI.back, '返回', true);
}
