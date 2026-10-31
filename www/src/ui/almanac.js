import { ALMANAC, almanacEntryRect } from '../layout.js';
import { ZOMBIE_TYPES, ZOMBIE_TIERS, zombieTierLabel } from '../content.js';
import {
  almanacEntries, plantBaseStats, zombieBaseStats
} from '../content/almanac.js';
import { PLANT_TYPES } from '../content.js';
import { UPGRADE_TREES, PLANT_EFFECTS, UPGRADE_COST_SCALE } from '../game/upgrade.js';
import { drawPlant, drawZombie } from '../render/art.js';

const KAI = '"KaiTi","STKaiti","Kaiti SC",serif';

const C = {
  cover: '#1f120d',
  coverLight: '#2c1a12',
  coverEdge: '#6a4a2c',
  paper: '#e9dcc0',
  paperDark: '#dccaa8',
  paperEdge: '#b38a56',
  ink: '#38291b',
  story: '#5a4630',
  muted: '#8a7454',
  faded: 'rgba(90,70,48,0.55)',
  gold: '#9a7326',
  goldLight: '#e2c07a',
  red: '#a83a2b',
  teal: '#2f6b67',
  green: '#4a6b45',
  orange: '#b5612a',
  heading: '#7a2c1e'
};

const body = (size = 14) => `400 ${size}px ${KAI}`;
const bold = (size = 14) => `700 ${size}px ${KAI}`;
const italic = (size = 13) => `italic 400 ${size}px ${KAI}`;

let contentCache = null;

function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}

const KEYWORDS = [
  '减速', '易伤', '灼烧', '增幅', '击退', '定身', '眩晕', '护具', '护罩', '本体',
  '大型', '一次性', '不可升阶', '灰烬', '抛物线', '跨行', '水面', '浮台', '索敌',
  '收妖', '吞噬', '反伤', '自愈', '耐久', '伤害', '香火', '冷却', '间隔', '持续',
  '速度', '啃食', '产量', '暴击', '范围', '纸壳', '费用', '灰烬类'
].join('|');

function colorize(text, baseFont, baseColor) {
  const re = new RegExp(
    `(\\d+(?:\\.\\d+)?(?:\\s?(?:%|秒|点|格|发|次|道|/\\s?秒))?|${KEYWORDS})`,
    'g'
  );
  const segments = [];
  let last = 0;
  for (const m of text.matchAll(re)) {
    if (m.index > last) {
      segments.push({ text: text.slice(last, m.index), color: baseColor, font: baseFont });
    }
    const token = m[0];
    segments.push({
      text: token,
      color: /^\d/.test(token) ? C.red : C.teal,
      font: baseFont
    });
    last = m.index + token.length;
  }
  if (last < text.length) {
    segments.push({ text: text.slice(last), color: baseColor, font: baseFont });
  }
  return segments;
}

function wrapRich(ctx, segments, maxWidth) {
  const lines = [];
  let line = [];
  let width = 0;
  for (const seg of segments) {
    ctx.font = seg.font;
    for (const ch of seg.text) {
      if (ch === '\n') {
        lines.push(line);
        line = [];
        width = 0;
        continue;
      }
      const w = ctx.measureText(ch).width;
      if (width + w > maxWidth) {
        lines.push(line);
        line = [];
        width = 0;
      }
      line.push({ ch, color: seg.color, font: seg.font });
      width += w;
    }
  }
  lines.push(line);
  return lines;
}

function callout(ctx, x, y, maxWidth, segments, opts = {}) {
  const lineHeight = opts.lineHeight || 24;
  const padY = opts.padY || 12;
  const padX = opts.padX || 16;
  const lines = wrapRich(ctx, segments, maxWidth - padX * 2);
  const height = lines.length * lineHeight + padY * 2 - 4;
  ctx.fillStyle = opts.bg || 'rgba(154,115,38,0.10)';
  rr(ctx, x, y, maxWidth, height, 6);
  ctx.fill();
  ctx.fillStyle = opts.accent || C.gold;
  ctx.fillRect(x, y + 6, 3, height - 12);
  let ty = y + padY;
  for (const line of lines) {
    let tx = x + padX;
    ctx.textBaseline = 'top';
    ctx.textAlign = 'left';
    for (const cell of line) {
      ctx.font = cell.font;
      ctx.fillStyle = cell.color;
      ctx.fillText(cell.ch, tx, ty);
      tx += ctx.measureText(cell.ch).width;
    }
    ty += lineHeight;
  }
  return y + height + (opts.gap ?? 12);
}

function writeRich(ctx, segments, x, y, maxWidth, lineHeight) {
  ctx.textAlign = 'left';
  ctx.textBaseline = 'top';
  let cx = x;
  let cy = y;
  let used = false;
  for (const seg of segments) {
    ctx.font = seg.font;
    for (const ch of seg.text) {
      if (ch === '\n') {
        cy += lineHeight;
        cx = x;
        used = false;
        continue;
      }
      const w = ctx.measureText(ch).width;
      if (used && cx + w > x + maxWidth) {
        cy += lineHeight;
        cx = x;
        used = false;
      }
      ctx.fillStyle = seg.color;
      ctx.font = seg.font;
      ctx.fillText(ch, cx, cy);
      cx += w;
      used = true;
    }
  }
  return cy + lineHeight;
}

function writeText(ctx, text, x, y, maxWidth, opts = {}) {
  const font = opts.font || body(14);
  const color = opts.color || C.ink;
  const lineHeight = opts.lineHeight || 24;
  const segments = opts.colorize
    ? colorize(text, font, color)
    : [{ text, color, font }];
  return writeRich(ctx, segments, x, y, maxWidth, lineHeight);
}

function heading(ctx, text, x, y) {
  ctx.fillStyle = C.red;
  ctx.fillRect(x, y + 3, 4, 17);
  ctx.fillStyle = C.heading;
  ctx.font = bold(20);
  ctx.textAlign = 'left';
  ctx.textBaseline = 'top';
  ctx.fillText(text, x + 12, y);
  ctx.strokeStyle = 'rgba(140,100,58,0.28)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(x, y + 30);
  ctx.lineTo(x + 700, y + 30);
  ctx.stroke();
  return y + 40;
}

function quoteBlock(ctx, text, x, y, maxWidth) {
  const startY = y;
  const endY = writeRich(
    ctx,
    [{ text: '"' + text + '"', color: C.muted, font: italic(13) }],
    x + 14, y, maxWidth - 14, 21
  );
  ctx.fillStyle = 'rgba(181,138,86,0.55)';
  ctx.fillRect(x, startY + 1, 3, Math.max(12, endY - startY - 7));
  return endY + 8;
}

function statGrid(ctx, stats, x, y, maxWidth) {
  const cols = 3;
  const gap = 12;
  const cellW = (maxWidth - gap * (cols - 1)) / cols;
  const cellH = 52;
  const rowGap = 10;
  const colors = {
    cost: C.orange,
    hp: C.green,
    time: C.teal,
    atk: C.red,
    gold: C.gold,
    desc: C.ink,
    green: C.green,
    teal: C.teal,
    orange: C.orange,
    neutral: C.ink
  };
  stats.forEach((stat, i) => {
    const col = i % cols;
    const row = Math.floor(i / cols);
    const cx = x + col * (cellW + gap);
    const cy = y + row * (cellH + rowGap);
    ctx.fillStyle = 'rgba(255,250,236,0.42)';
    rr(ctx, cx, cy, cellW, cellH, 6);
    ctx.fill();
    ctx.strokeStyle = 'rgba(150,110,70,0.22)';
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';
    ctx.fillStyle = C.muted;
    ctx.font = body(11);
    ctx.fillText(stat.label, cx + 10, cy + 7);
    ctx.fillStyle = colors[stat.tone] || C.ink;
    ctx.font = bold(16);
    ctx.fillText(String(stat.value), cx + 10, cy + 24);
  });
  const rows = Math.ceil(stats.length / cols);
  return y + rows * (cellH + rowGap) + 4;
}

function tierStats(type, pathId, tier) {
  const e = PLANT_EFFECTS[type];
  if (type === 'shooter') {
    if (pathId === 1) return `弹数 ${e.volley[tier]}`;
    if (pathId === 2) {
      const sides = tier === 1 ? '单侧交替' : '上下双侧';
      return `邻行 ${sides} · 伤害 ${Math.round(e.adjacentFactor[tier] * 100)}%`;
    }
    let text = `暴击 ${Math.round(e.critChance[tier] * 100)}% · 大签伤害 200%`;
    if (e.critSlow[tier]) text += ` · 减速 50% ${e.critSlow[tier]} 秒`;
    return text;
  }
  if (type === 'lantern') {
    if (pathId === 1) return `单次产量 ${e.value[tier]}`;
    if (pathId === 2) return `产出间隔 ${e.interval[tier]} 秒`;
    const range = tier === 3 ? '整行' : `前方 ${e.buffRange[tier]} 格`;
    return `${range} · 友军伤害 +${Math.round(e.buffDamage[tier] * 100)}%`;
  }
  if (type === 'wall') {
    if (pathId === 1) {
      const extra = e.healWhileEaten[tier] ? ' · 被啃也恢复' : '';
      return `每秒恢复 ${e.heal[tier]} 生命${extra}`;
    }
    if (pathId === 2) return `被啃反伤 ${e.reflect[tier]} / 秒`;
    let text = `碎石 ${e.gravelDamage[tier]} 伤害 / ${e.gravelInterval} 秒`;
    if (e.vuln[tier]) text += ' · 10% 易伤 3 秒';
    if (e.knockCells[tier]) text += ` · 击退 ${e.knockCells[tier]} 格 / 大型双倍`;
    return text;
  }
  if (type === 'censer') {
    if (pathId === 1) return `香雾伤害 ${e.damage[tier]}`;
    if (pathId === 2) return `香雾半径 ${(e.radius[tier] / 88).toFixed(1)} 格`;
    return `减速 ${Math.round(e.slow[tier] * 100)}% · 持续 ${e.slowDuration[tier]} 秒`;
  }
  if (type === 'umbrella') {
    if (pathId === 1) return `收妖速度 +${Math.round(e.chewSpeed[tier] * 100)}%`;
    if (pathId === 2) return `收妖完成产 ${e.sun[tier]} 香火`;
    return `收妖期间减伤 ${Math.round(e.chewGuard[tier] * 100)}%`;
  }
  if (type === 'lion') {
    if (pathId === 1) {
      const extra = tier === 3 ? ' · 击退 +50%' : '';
      return `撞头伤害 ${e.damage[tier]}${extra}`;
    }
    if (pathId === 2) return `攻击间隔 ${e.interval[tier]} 秒 · 眩晕 ${Math.round(e.stunChance[tier] * 100)}%`;
    return `命中回复 ${e.heal[tier]} 耐久`;
  }
  if (type === 'cat') {
    if (pathId === 1) return `尾火数量 ${e.count[tier]}`;
    if (pathId === 2) {
      const extra = e.hits[tier] > 1 ? ' · 命中后再追一个' : '';
      return `尾火伤害 ${e.damage[tier]}${extra}`;
    }
    let text = `易伤 ${Math.round(e.vuln[tier] * 100)}% · 2 秒`;
    if (e.slow[tier]) text += ` · 减速 ${Math.round(e.slow[tier] * 100)}% 1.5 秒`;
    return text;
  }
  if (type === 'lobber') {
    if (pathId === 1) return `汤圆伤害 ${e.damage[tier]}`;
    if (pathId === 2) return `投掷间隔 ${e.interval[tier]} 秒`;
    return `落点减速 ${Math.round(e.slowFactor[tier] * 100)}% · 2 秒`;
  }
  if (type === 'torch') {
    if (pathId === 1) return `射弹伤害 +${Math.round(e.buff[tier] * 100)}%`;
    if (pathId === 2) return `灼烧 ${e.burn[tier]} / 秒 · ${e.burnDuration} 秒`;
    return `射弹减速 ${Math.round(e.slow[tier] * 100)}% · ${e.slowDuration} 秒`;
  }
  if (type === 'star') {
    if (pathId === 1) return `每道灯焰 ${e.damage[tier]}`;
    if (pathId === 2) return `发灯间隔 ${e.interval[tier]} 秒`;
    return `易伤 ${Math.round(e.vuln[tier] * 100)}% · ${e.vulnDuration} 秒`;
  }
  if (type === 'needle') {
    if (pathId === 1) return `穿甲伤害 ${e.damage[tier]}`;
    if (pathId === 2) return `出针间隔 ${e.interval[tier]} 秒`;
    return `易伤 ${Math.round(e.vuln[tier] * 100)}% · ${e.vulnDuration} 秒`;
  }
  if (type === 'judge') {
    if (pathId === 1) return `击退 ${e.knockCells[tier]} 格`;
    if (pathId === 2) return `显灵间隔 ${e.interval[tier]} 秒`;
    return `显灵伤害 ${e.damage[tier]}`;
  }
  if (pathId === 1) {
    const slow = Math.round(e.slow[tier] * 100);
    return `摇铃间隔 ${e.interval[tier]} 秒 · 减速 ${slow}%`;
  }
  if (pathId === 2) {
    const range = tier === 3 ? '整行' : '前方 1 格';
    const pct = Math.round(e.slow[1] * e.hasteFactor[tier] * 100);
    return `${range} · 友军攻速 +${pct}%`;
  }
  const range = tier === 1 ? '前方 4 格' : '整行';
  let text = `${range} · 伤害 ${e.damage[tier]}`;
  if (e.rootChance[tier]) text += ` · 20% 定身 ${e.rootDuration} 秒`;
  return text;
}
function pathSection(ctx, type, path, x, y, maxWidth) {
  const tint = path.color + '22';
  ctx.fillStyle = tint;
  rr(ctx, x, y, maxWidth, 28, 5);
  ctx.fill();
  ctx.fillStyle = path.color;
  ctx.fillRect(x, y, 3, 28);
  ctx.fillStyle = path.color;
  ctx.font = bold(15);
  ctx.textAlign = 'left';
  ctx.textBaseline = 'top';
  ctx.fillText(path.name, x + 12, y + 6);
  ctx.fillStyle = C.muted;
  ctx.font = body(11);
  ctx.textAlign = 'right';
  ctx.fillText(
    ['其一路', '其二路', '其三路'][path.id - 1],
    x + maxWidth - 10, y + 8
  );
  ctx.textAlign = 'left';
  y += 38;

  for (let i = 0; i < path.tiers.length; i++) {
    const tier = path.tiers[i];
    const lv = path.id + '-' + (i + 1);
    ctx.fillStyle = path.color;
    ctx.font = bold(13);
    ctx.textBaseline = 'top';
    ctx.textAlign = 'left';
    ctx.fillText(lv, x, y + 1);
    ctx.fillStyle = C.ink;
    ctx.font = bold(15);
    ctx.fillText(tier.name, x + 44, y - 1);

    ctx.font = bold(13);
    ctx.textAlign = 'right';
    ctx.fillStyle = C.orange;
    const scale = UPGRADE_COST_SCALE[type] ?? 1;
    const cost = Math.max(10, Math.round((tier.cost * scale) / 5) * 5);
    const costText = cost + ' 香火';
    ctx.fillText(costText, x + maxWidth, y + 1);
    const cw = ctx.measureText(costText).width;
    ctx.beginPath();
    ctx.arc(x + maxWidth - cw - 9, y + 8, 3.6, 0, Math.PI * 2);
    ctx.fill();
    ctx.textAlign = 'left';
    y += 24;

    y = writeRich(
      ctx,
      colorize(tier.desc, body(13), C.ink),
      x, y, maxWidth - 8, 20
    );

    ctx.font = body(11);
    ctx.fillStyle = C.muted;
    ctx.fillText('数值', x, y + 1);
    const statSegments = [
      { text: '数值  ', color: C.muted, font: body(11) },
      { text: tierStats(type, path.id, i + 1), color: C.teal, font: bold(12) }
    ];
    y = writeRich(ctx, statSegments, x, y, maxWidth - 8, 18);

    ctx.strokeStyle = 'rgba(140,100,58,0.18)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x, y + 2);
    ctx.lineTo(x + maxWidth, y + 2);
    ctx.stroke();
    y += 12;
  }

  return y + 12;
}

function footerNote(ctx, y) {
  ctx.fillStyle = C.muted;
  ctx.font = body(11);
  ctx.textAlign = 'center';
  ctx.textBaseline = 'top';
  ctx.fillText('—— 账目如上，夜里有变再改 ——', 350, y + 8);
  ctx.textAlign = 'left';
  return y + 30;
}

function buildPlantContent(ctx, entry) {
  let y = 0;
  y = heading(ctx, '来历', 0, y);
  y = writeText(ctx, entry.story, 0, y + 2, 700, {
    font: body(14), color: C.story, lineHeight: 24
  });
  y = quoteBlock(ctx, entry.quote, 0, y + 4, 700) + 8;

  y = heading(ctx, '本事', 0, y);
  y = writeText(ctx, entry.ability, 0, y + 2, 700, {
    font: body(14), color: C.ink, lineHeight: 24, colorize: true
  }) + 12;

  y = heading(ctx, '底细', 0, y);
  y = statGrid(ctx, plantBaseStats(entry.type), 0, y + 2, 700) + 10;

  y = heading(ctx, '进化', 0, y);
  const tree = UPGRADE_TREES[entry.type];
  if (!tree) {
    const notes = {
      mushroom: '坟头菇是埋进土里的灰烬陷阱，长成后只等那一脚。它没有第二条路可走，炸完便连菇带土一起散了。',
      shell: '龟甲罩只是一层护罩，罩上去便替里面的植物挡风挡咬。它自己不会长，也不会进阶，壳碎之后便算尽了职。',
      lily: '夜莲只是一块浮台，漂在水面上替同行落脚。它不走阶，也不还手，水面上的位置全靠它托着。',
      kelp: '缠魂藻只有一拽的力气：拖下去一个，藻叶便散在泥里。它没有第二条路可走，也不会有。',
      bomb: '爆竹是一响就散的灰烬之物，点着了就只能等它炸完，没有第二条路可走。'
    };
    y = writeText(
      ctx,
      notes[entry.type] || notes.bomb,
      0, y + 2, 700,
      { font: body(14), color: C.story, lineHeight: 24 }
    );
    return footerNote(ctx, y + 10);
  }
  const notes = [
    { text: '每座最多开 ', color: C.ink, font: body(12.5) },
    { text: '两路', color: C.red, font: bold(12.5) },
    { text: '；每路逐级；最多只有一路走到 ', color: C.ink, font: body(12.5) },
    { text: '三级', color: C.red, font: bold(12.5) },
    { text: '。先想清楚再落手。', color: C.ink, font: body(12.5) }
  ];
  const noteY = y;
  y = callout(ctx, 0, noteY, 700, notes, {
    bg: 'rgba(154,115,38,0.10)',
    accent: C.gold,
    lineHeight: 20,
    padY: 9,
    padX: 14,
    gap: 16
  });

  for (const path of tree) {
    y = pathSection(ctx, entry.type, path, 0, y, 700);
  }

  return footerNote(ctx, y);
}

function buildZombieContent(ctx, entry) {
  let y = 0;
  y = heading(ctx, '来历', 0, y);
  y = writeText(ctx, entry.story, 0, y + 2, 700, {
    font: body(14), color: C.story, lineHeight: 24
  });
  y = quoteBlock(ctx, entry.quote, 0, y + 4, 700) + 8;

  y = heading(ctx, '本事', 0, y);
  y = writeText(ctx, entry.ability, 0, y + 2, 700, {
    font: body(14), color: C.ink, lineHeight: 24, colorize: true
  }) + 12;

  y = heading(ctx, '底细', 0, y);
  y = statGrid(ctx, zombieBaseStats(entry.type), 0, y + 2, 700) + 10;

  y = heading(ctx, '对策', 0, y);
  const counterSegments = colorize(entry.counter, body(14), C.story);
  y = callout(ctx, 0, y, 700, counterSegments, {
    bg: 'rgba(47,107,103,0.10)',
    accent: C.teal,
    lineHeight: 24,
    padY: 12,
    padX: 16,
    gap: 12
  });

  return footerNote(ctx, y);
}

function ensureContent(tab, index, scale = 1) {
  const safeScale = Math.min(3, Math.max(1, scale));
  const key = `${tab}:${index}:${safeScale}`;
  if (contentCache && contentCache.key === key) return contentCache;

  const entry = almanacEntries(tab)[index];
  const canvas = document.createElement('canvas');
  canvas.width = Math.ceil(700 * safeScale);
  canvas.height = Math.ceil(2400 * safeScale);
  const ctx = canvas.getContext('2d');
  ctx.scale(safeScale, safeScale);
  ctx.textAlign = 'left';
  ctx.textBaseline = 'top';
  const height = tab === 'plant'
    ? buildPlantContent(ctx, entry)
    : buildZombieContent(ctx, entry);
  contentCache = {
    key,
    scale: safeScale,
    canvas,
    height: Math.max(1, Math.min(2400, Math.ceil(height)))
  };
  return contentCache;
}

function drawBook(ctx) {
  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.55)';
  ctx.shadowBlur = 22;
  ctx.fillStyle = C.cover;
  rr(ctx, ALMANAC.book.x, ALMANAC.book.y, ALMANAC.book.w, ALMANAC.book.h, 12);
  ctx.fill();
  ctx.restore();

  ctx.strokeStyle = C.coverEdge;
  ctx.lineWidth = 2;
  rr(ctx, ALMANAC.book.x + 1, ALMANAC.book.y + 1, ALMANAC.book.w - 2, ALMANAC.book.h - 2, 11);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(226,192,122,0.25)';
  ctx.lineWidth = 1;
  rr(ctx, ALMANAC.book.x + 8, ALMANAC.book.y + 8, ALMANAC.book.w - 16, ALMANAC.book.h - 16, 8);
  ctx.stroke();

  // 左页
  ctx.fillStyle = '#23140e';
  rr(ctx, 104, 92, 252, 576, 6);
  ctx.fill();
  ctx.strokeStyle = 'rgba(150,110,70,0.45)';
  ctx.stroke();

  // 书脊
  const spine = ctx.createLinearGradient(356, 0, 374, 0);
  spine.addColorStop(0, '#1b0f0b');
  spine.addColorStop(0.5, '#3a2417');
  spine.addColorStop(1, '#1b0f0b');
  ctx.fillStyle = spine;
  ctx.fillRect(356, 92, 18, 576);
  for (let y = 118; y < 650; y += 26) {
    ctx.fillStyle = 'rgba(210,174,110,0.35)';
    ctx.beginPath();
    ctx.arc(365, y, 1.6, 0, Math.PI * 2);
    ctx.fill();
  }

  // 右页
  ctx.fillStyle = C.paper;
  rr(ctx, ALMANAC.right.x, ALMANAC.right.y, ALMANAC.right.w, ALMANAC.right.h, 6);
  ctx.fill();
  ctx.strokeStyle = C.paperEdge;
  ctx.lineWidth = 1.5;
  ctx.stroke();
  ctx.strokeStyle = 'rgba(150,110,70,0.22)';
  ctx.lineWidth = 1;
  rr(ctx, ALMANAC.right.x + 8, ALMANAC.right.y + 8, ALMANAC.right.w - 16, ALMANAC.right.h - 16, 4);
  ctx.stroke();

  // 页边红线
  ctx.strokeStyle = 'rgba(168,58,43,0.2)';
  ctx.beginPath();
  ctx.moveTo(389, 104);
  ctx.lineTo(389, 650);
  ctx.stroke();

  // 书角
  ctx.strokeStyle = 'rgba(226,192,122,0.6)';
  ctx.lineWidth = 2;
  const corners = [
    [104, 92, 1, 1], [356, 92, -1, 1],
    [104, 668, 1, -1], [356, 668, -1, -1]
  ];
  for (const [x, y, sx, sy] of corners) {
    ctx.beginPath();
    ctx.moveTo(x + sx * 14, y);
    ctx.lineTo(x, y);
    ctx.lineTo(x, y + sy * 14);
    ctx.stroke();
  }
}

function drawTop(ctx, game) {
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.font = bold(26);
  ctx.fillStyle = C.goldLight;
  ctx.fillText('妖怪图鉴', 122, 68);

  ctx.fillStyle = C.red;
  rr(ctx, 272, 52, 30, 30, 4);
  ctx.fill();
  ctx.strokeStyle = 'rgba(226,192,122,0.6)';
  ctx.stroke();
  ctx.fillStyle = '#f0d9a4';
  ctx.font = bold(15);
  ctx.textAlign = 'center';
  ctx.fillText('夜', 287, 68);
  ctx.textAlign = 'left';

  const b = ALMANAC.close;
  ctx.fillStyle = 'rgba(255,235,196,0.08)';
  rr(ctx, b.x, b.y, b.w, b.h, 6);
  ctx.fill();
  ctx.strokeStyle = 'rgba(226,192,122,0.45)';
  ctx.lineWidth = 1;
  ctx.stroke();
  ctx.fillStyle = C.goldLight;
  ctx.font = bold(13);
  ctx.textAlign = 'center';
  ctx.fillText('返回', b.x + b.w / 2, b.y + b.h / 2 + 1);
  ctx.textAlign = 'left';
}

function drawTabs(ctx, game) {
  for (const tab of ALMANAC.tabs) {
    const selected = game.almanacTab === tab.key;
    const r = tab.rect;
    ctx.fillStyle = selected ? C.paper : 'rgba(255,235,196,0.06)';
    rr(ctx, r.x, r.y, r.w, r.h, 6);
    ctx.fill();
    ctx.strokeStyle = selected ? C.paperEdge : 'rgba(226,192,122,0.28)';
    ctx.lineWidth = 1.2;
    ctx.stroke();
    ctx.fillStyle = selected ? C.ink : 'rgba(226,192,122,0.7)';
    ctx.font = bold(14);
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(tab.label, r.x + r.w / 2, r.y + r.h / 2 + 1);
  }
  ctx.textAlign = 'left';
}

function drawList(ctx, game, entries) {
  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i];
    const r = almanacEntryRect(i);
    const selected = i === game.almanacIndex;
    if (selected) {
      ctx.fillStyle = C.paper;
      rr(ctx, r.x, r.y, r.w, r.h, 5);
      ctx.fill();
      ctx.strokeStyle = C.paperEdge;
      ctx.lineWidth = 1.4;
      ctx.stroke();
    }

    if (game.almanacTab === 'plant') {
      drawPlant(ctx, entry.type, r.x + 20, r.y + 24, 0, {
        scale: 0.2,
        noShadow: true,
        armed: true,
        arm: 1
      });
    } else {
      drawZombie(ctx, entry.type, r.x + 20, r.y + 21, 0, {
        def: ZOMBIE_TYPES[entry.type],
        scale: 0.18
      });
    }

    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = selected ? C.ink : C.goldLight;
    ctx.font = bold(12);
    ctx.fillText(entry.name, r.x + 37, r.y + 12);
    ctx.fillStyle = selected ? C.muted : 'rgba(226,192,122,0.55)';
    ctx.font = body(9);
    const sub = game.almanacTab === 'plant'
      ? (PLANT_TYPES[entry.type]?.role || '')
      : zombieTierLabel(ZOMBIE_TYPES[entry.type]?.tier);
    ctx.fillText(sub, r.x + 37, r.y + 25);
  }
}

function entryHeader(ctx, game, entry) {
  const isPlant = game.almanacTab === 'plant';
  const tagX = ALMANAC.content.x;
  const tagY = 104;
  const tierMeta = isPlant ? null : (ZOMBIE_TIERS[ZOMBIE_TYPES[entry.type]?.tier] || ZOMBIE_TIERS.l);
  ctx.fillStyle = isPlant ? 'rgba(47,107,103,0.16)' : 'rgba(168,58,43,0.14)';
  rr(ctx, tagX, tagY, 42, 22, 4);
  ctx.fill();
  ctx.fillStyle = isPlant ? C.teal : tierMeta.color;
  ctx.font = bold(11);
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(isPlant ? '草木' : zombieTierLabel(ZOMBIE_TYPES[entry.type]?.tier), tagX + 21, tagY + 12);

  ctx.textAlign = 'left';
  ctx.fillStyle = C.ink;
  ctx.font = bold(31);
  ctx.fillText(entry.name, tagX + 54, tagY + 8);

  ctx.fillStyle = C.muted;
  ctx.font = italic(13);
  ctx.fillText(entry.epithet, tagX + 54, tagY + 46);

  const iconX = 1044;
  const iconY = 150;
  if (isPlant) {
    drawPlant(ctx, entry.type, iconX, iconY, 0, { scale: 0.9, armed: true, arm: 1 });
  } else {
    drawZombie(ctx, entry.type, iconX, iconY + 6, 0, {
      def: ZOMBIE_TYPES[entry.type],
      scale: 0.72
    });
  }

  ctx.strokeStyle = 'rgba(140,100,58,0.3)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(ALMANAC.content.x, 188);
  ctx.lineTo(ALMANAC.content.x + ALMANAC.content.w, 188);
  ctx.stroke();
}

function drawContent(ctx, game, cache, scroll) {
  const c = ALMANAC.content;
  const scale = cache.scale || 1;
  ctx.save();
  ctx.beginPath();
  ctx.rect(c.x, c.y, c.w, c.h);
  ctx.clip();
  ctx.drawImage(
    cache.canvas,
    0, Math.round(scroll * scale), Math.round(c.w * scale), Math.round(c.h * scale),
    c.x, c.y, c.w, c.h
  );

  const topFade = ctx.createLinearGradient(0, c.y, 0, c.y + 18);
  topFade.addColorStop(0, 'rgba(233,220,192,0.92)');
  topFade.addColorStop(1, 'rgba(233,220,192,0)');
  ctx.fillStyle = topFade;
  ctx.fillRect(c.x, c.y, c.w, 18);

  const bottomFade = ctx.createLinearGradient(0, c.y + c.h - 22, 0, c.y + c.h);
  bottomFade.addColorStop(0, 'rgba(233,220,192,0)');
  bottomFade.addColorStop(1, 'rgba(233,220,192,0.92)');
  ctx.fillStyle = bottomFade;
  ctx.fillRect(c.x, c.y + c.h - 22, c.w, 22);
  ctx.restore();
}

function drawScrollbar(ctx, game, height) {
  const s = ALMANAC.scrollbar;
  const max = Math.max(0, height - ALMANAC.content.h);
  ctx.fillStyle = 'rgba(120,90,60,0.16)';
  rr(ctx, s.x, s.y, s.w, s.h, 4);
  ctx.fill();
  if (max <= 0) return;

  const thumbH = Math.max(28, s.h * (ALMANAC.content.h / height));
  const ratio = game.almanacScroll / max;
  const thumbY = s.y + (s.h - thumbH) * ratio;
  ctx.fillStyle = 'rgba(181,138,86,0.75)';
  rr(ctx, s.x, thumbY, s.w, thumbH, 4);
  ctx.fill();
}

export function drawAlmanac(ctx, game) {
  const tab = game.almanacTab === 'zombie' ? 'zombie' : 'plant';
  const entries = almanacEntries(tab);
  if (game.almanacIndex < 0 || game.almanacIndex >= entries.length) {
    game.almanacIndex = 0;
  }
  const entry = entries[game.almanacIndex];

  ctx.fillStyle = 'rgba(4,3,6,0.72)';
  ctx.fillRect(0, 0, 1280, 720);

  drawBook(ctx);
  drawTop(ctx, game);
  drawTabs(ctx, game);
  drawList(ctx, game, entries);
  entryHeader(ctx, game, entry);

  const cache = ensureContent(tab, game.almanacIndex, ctx.getTransform().a || 1);
  game.almanacMaxScroll = Math.max(0, cache.height - ALMANAC.content.h);
  game.almanacScroll = Math.max(0, Math.min(game.almanacMaxScroll, game.almanacScroll));
  const scroll = game.almanacScroll;
  drawContent(ctx, game, cache, scroll);
  drawScrollbar(ctx, game, cache.height);

  ctx.fillStyle = C.muted;
  ctx.font = body(11);
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillText('滚轮 / ↑↓ 翻阅 · Esc 返回', 120, 652);
  ctx.fillStyle = 'rgba(90,70,48,0.5)';
  ctx.textAlign = 'right';
  ctx.fillText(
    `${tab === 'plant' ? '草木志' : '恶客录'} · ${game.almanacIndex + 1}/${entries.length} · 第 ${game.almanacIndex + 1} 篇`,
    1098, 650
  );
  ctx.textAlign = 'left';
}
