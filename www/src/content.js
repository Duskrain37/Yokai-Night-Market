export const PLANT_TYPES = {
  lantern: {
    id: 'lantern', name: '红灯笼', role: '产能', cost: 50, cooldown: 5, hp: 300, tint: '#c8402f',
    produce: { interval: 8, first: 5, value: 25 }
  },
  shooter: {
    id: 'shooter', name: '签筒', role: '射线', cost: 100, cooldown: 5, hp: 300, tint: '#c9a15c',
    shot: { interval: 1.4, damage: 20, speed: 520 }
  },
  wall: {
    id: 'wall', name: '石磨', role: '防御', cost: 50, cooldown: 20, hp: 3000, tint: '#8b877b'
  },
  bomb: {
    id: 'bomb', name: '爆竹', role: '灰烬', cost: 150, cooldown: 30, hp: 300, tint: '#c33a2c',
    bomb: { fuse: 1.2, radius: 150, damage: 1800 }
  },
  bell: {
    id: 'bell', name: '铜铃', role: '辅助', cost: 125, cooldown: 20, hp: 300, tint: '#c79a3b',
    pulse: { interval: 2.5, slow: 1.5 }
  },
  censer: {
    id: 'censer', name: '香炉', role: '范围', cost: 150, cooldown: 18, hp: 340, tint: '#8a6f4d',
    spriteH: 84, censer: { interval: 3.0, radius: 140 }
  },
  umbrella: {
    id: 'umbrella', name: '纸伞', role: '收妖', cost: 100, cooldown: 16, hp: 900, tint: '#b5493e',
    spriteH: 98, chomp: { reach: 74, chew: 6.0, largeDamage: 40, largeInterval: 2.0 }
  },
  lion: {
    id: 'lion', name: '醒狮', role: '近战', cost: 150, cooldown: 20, hp: 1200, tint: '#c9472f',
    spriteH: 92, melee: { reach: 110 }
  },
  mushroom: {
    id: 'mushroom', name: '坟头菇', role: '灰烬', cost: 25, cooldown: 20, hp: 300, tint: '#7d8a5c',
    spriteH: 76, mine: { arm: 14, damage: 1800 }
  }
};

export const PLANT_ORDER = [
  'lantern', 'shooter', 'wall', 'bomb', 'mushroom', 'bell', 'censer', 'umbrella', 'lion'
];

export const ZOMBIE_TIERS = {
  l: { id: 'l', label: '低阶', short: '低', color: '#7f9d7a' },
  m: { id: 'm', label: '中阶', short: '中', color: '#c99a4a' },
  h: { id: 'h', label: '高阶', short: '高', color: '#b5493e' }
};

export function zombieTierLabel(tier) {
  return ZOMBIE_TIERS[tier]?.label || '';
}

export const ZOMBIE_TYPES = {
  ghost: {
    id: 'ghost', name: '饿鬼', kind: '小僵尸', tier: 'l',
    hp: 90, shell: 0, speed: 21, dps: 35, scale: 1
  },
  paper: {
    id: 'paper', name: '纸人', kind: '特殊', tier: 'm',
    hp: 420, shell: 250, speed: 19, dps: 80, scale: 1.05
  },
  mountain: {
    id: 'mountain', name: '山魈', kind: '重型', tier: 'h', large: true,
    hp: 1800, shell: 0, speed: 16, dps: 180, scale: 1.28
  },
  tongue: {
    id: 'tongue', name: '长舌鬼', kind: '超小', tier: 'l',
    hp: 80, shell: 0, speed: 30, dps: 45, reach: 62, scale: 0.98
  },
  mourner: {
    id: 'mourner', name: '哭丧鬼', kind: '特殊', tier: 'm',
    hp: 620, shell: 0, speed: 16, dps: 75, scale: 1.06,
    aura: { radius: 150, interval: 4.5, haste: 1.35, duration: 2.6 }
  },
  sedan: {
    id: 'sedan', name: '抬轿鬼', kind: '重型', tier: 'h', large: true,
    hp: 520, shell: 950, speed: 14, dps: 120, scale: 1.0, spriteH: 104,
    split: { type: 'ghost', count: 2, hp: 0.6 }
  }
};

// 每关 12 波；前 3 关、4-8 关、最后 2 关各用一套阶段构成。
const WAVE_PLANS = {
  early: [
    { l: 1 }, { l: 2 }, { l: 2 }, { l: 3 }, { l: 3 }, { l: 4, flag: true },
    { l: 4, m: 1 }, { l: 4, m: 1 }, { l: 5, m: 1 }, { l: 6, m: 2, flag: true },
    { l: 6, m: 2 }, { l: 7, m: 3, flag: true }
  ],
  mid: [
    { l: 2 }, { l: 3 }, { l: 3 }, { l: 4 },
    { l: 4, m: 2 }, { l: 5, m: 3, flag: true }, { l: 5, m: 3 }, { l: 6, m: 4 },
    { l: 5, m: 3, h: 1 }, { l: 6, m: 4, h: 1, flag: true }, { l: 7, m: 5, h: 2 }, { l: 8, m: 6, h: 3, flag: true }
  ],
  late: [
    { l: 2, m: 1 }, { l: 2, m: 1 }, { l: 3, m: 1 }, { l: 3, m: 2 },
    { l: 3, m: 2, h: 1 }, { l: 4, m: 3, h: 1, flag: true }, { l: 4, m: 3, h: 2 }, { l: 5, m: 4, h: 2 },
    { m: 3, h: 2 }, { m: 4, h: 2, flag: true }, { m: 4, h: 3 }, { m: 5, h: 3, flag: true }
  ]
};

function addTierGroup(groups, tier, count, wi, levelId) {
  if (!count) return;
  if (tier === 'l') {
    if (wi < 3) {
      groups.push(['ghost', count]);
      return;
    }
    const tongue = count >= 2
      ? Math.min(count, Math.floor(count * 0.35))
      : (wi % 4 === 3 ? 1 : 0);
    if (count - tongue > 0) groups.push(['ghost', count - tongue]);
    if (tongue > 0) groups.push(['tongue', tongue]);
  } else if (tier === 'm') {
    let mourner = 0;
    if (wi >= 7 && count >= 2) mourner = Math.min(count, Math.max(1, Math.floor(count * 0.3)));
    else if (wi >= 10 && count === 1 && (levelId + wi) % 2 === 0) mourner = 1;
    if (count - mourner > 0) groups.push(['paper', count - mourner]);
    if (mourner > 0) groups.push(['mourner', mourner]);
  } else {
    let sedan = 0;
    if (wi >= 8 && count >= 2) sedan = Math.min(count, Math.max(1, Math.floor(count * 0.35)));
    if (count - sedan > 0) groups.push(['mountain', count - sedan]);
    if (sedan > 0) groups.push(['sedan', sedan]);
  }
}

function buildWaves(band, levelId) {
  const plan = WAVE_PLANS[band] || WAVE_PLANS.early;
  return plan.map((wave, wi) => {
    const groups = [];
    for (const tier of ['l', 'm', 'h']) addTierGroup(groups, tier, wave[tier] || 0, wi, levelId);
    return {
      t: 16 + wi * 18,
      flag: !!wave.flag,
      groups
    };
  });
}

const LEVEL_INFO = [
  { name: '第一夜', tag: '开张', threat: 1.0, band: 'early' },
  { name: '第二夜', tag: '熟客', threat: 1.444, band: 'early' },
  { name: '第三夜', tag: '起风', threat: 1.889, band: 'early' },
  { name: '第四夜', tag: '灯多', threat: 2.333, band: 'mid' },
  { name: '第五夜', tag: '山雨', threat: 2.778, band: 'mid' },
  { name: '第六夜', tag: '满街', threat: 3.222, band: 'mid' },
  { name: '第七夜', tag: '问路', threat: 3.667, band: 'mid' },
  { name: '第八夜', tag: '不眠', threat: 4.111, band: 'mid' },
  { name: '第九夜', tag: '月近', threat: 4.556, band: 'late' },
  { name: '第十夜', tag: '天亮前', threat: 5.0, band: 'late' }
];

export const LEVELS = LEVEL_INFO.map((info, i) => ({
  id: i + 1,
  name: info.name,
  tag: info.tag,
  threat: info.threat,
  band: info.band,
  startSun: 100,
  waves: buildWaves(info.band, i + 1)
}));

export function getLevel(id) {
  return LEVELS.find((level) => level.id === id) || LEVELS[0];
}

