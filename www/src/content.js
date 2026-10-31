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
  },
  cat: {
    id: 'cat', name: '狐尾灯', role: '追魂', cost: 175, cooldown: 20, hp: 300, tint: '#d08a3e',
    spriteH: 90, homing: { interval: 1.6, damage: 15, speed: 300, count: 1 }
  },
  shell: {
    id: 'shell', name: '龟甲罩', role: '护罩', cost: 125, cooldown: 25, hp: 1400, tint: '#6f7d63',
    spriteH: 98, attach: true
  },
  lobber: {
    id: 'lobber', name: '汤圆仔', role: '抛射', cost: 125, cooldown: 12, hp: 300, tint: '#d8c39b',
    spriteH: 84, lob: { interval: 2.6, damage: 40, flight: 0.9 }
  },
  torch: {
    id: 'torch', name: '炭火盆', role: '增幅', cost: 150, cooldown: 20, hp: 300, tint: '#d26334',
    spriteH: 78, torch: { buff: 0.5 }
  },
  star: {
    id: 'star', name: '五路巡灯', role: '五路', cost: 175, cooldown: 22, hp: 300, tint: '#c9a84e',
    spriteH: 90, star: { interval: 2.6, damage: 12 }
  },
  needle: {
    id: 'needle', name: '透骨针', role: '破甲', cost: 125, cooldown: 18, hp: 300, tint: '#d8d2bf',
    spriteH: 82, needle: { interval: 1.7, damage: 14, speed: 720 }
  },
  judge: {
    id: 'judge', name: '钟馗像', role: '击退', cost: 150, cooldown: 20, hp: 900, tint: '#b04434',
    spriteH: 94, judge: { interval: 6.0, damage: 30, knockCells: 0.4, reach: 260 }
  }
};

export const PLANT_ORDER = [
  'lantern', 'shooter', 'wall', 'bomb', 'bell', 'censer', 'umbrella', 'lion',
  'mushroom', 'cat', 'shell', 'lobber', 'torch', 'star', 'needle', 'judge'
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
    hp: 90, armor: 0, speed: 21, dps: 35, scale: 1, deathStyle: 'ghost'
  },
  paper: {
    id: 'paper', name: '纸人', kind: '特殊', tier: 'm',
    hp: 420, armor: 250, armorType: 'paper', armorName: '纸壳',
    speed: 19, dps: 80, scale: 1.05, deathStyle: 'paper'
  },
  mountain: {
    id: 'mountain', name: '山魈', kind: '重型', tier: 'h', large: true,
    hp: 1800, armor: 0, speed: 16, dps: 180, scale: 1.28, deathStyle: 'mountain'
  },
  tongue: {
    id: 'tongue', name: '长舌鬼', kind: '超小', tier: 'l',
    hp: 80, armor: 0, speed: 30, dps: 45, reach: 62, scale: 0.98, deathStyle: 'tongue'
  },
  mourner: {
    id: 'mourner', name: '哭丧鬼', kind: '特殊', tier: 'm',
    hp: 620, armor: 0, speed: 16, dps: 75, scale: 1.06, deathStyle: 'mourner',
    aura: { radius: 150, interval: 4.5, haste: 1.35, duration: 2.6 }
  },
  sedan: {
    id: 'sedan', name: '抬轿鬼', kind: '重型', tier: 'h', large: true,
    hp: 520, armor: 950, armorType: 'sedan', armorName: '轿壳',
    speed: 14, dps: 120, scale: 1.0, spriteH: 104, deathStyle: 'sedan',
    split: { type: 'ghost', count: 2, hp: 0.6 }
  },
  straw: {
    id: 'straw', name: '斗笠鬼', kind: '小僵尸', tier: 'l',
    hp: 90, armor: 90, armorType: 'straw', armorName: '斗笠',
    speed: 22, dps: 35, scale: 0.95, spriteH: 84, deathStyle: 'straw'
  },
  stonehat: {
    id: 'stonehat', name: '石帽鬼', kind: '护甲', tier: 'm',
    hp: 240, armor: 320, armorType: 'stonehat', armorName: '石帽',
    speed: 18, dps: 75, scale: 1.02, spriteH: 104, deathStyle: 'stonehat'
  },
  bucket: {
    id: 'bucket', name: '瓮头鬼', kind: '重甲', tier: 'm',
    hp: 300, armor: 620, armorType: 'urn', armorName: '陶瓮',
    speed: 15, dps: 90, scale: 1.06, spriteH: 104, deathStyle: 'bucket'
  },
  vault: {
    id: 'vault', name: '跳幡鬼', kind: '特殊', tier: 'm',
    hp: 280, armor: 0, speed: 30, dps: 60, scale: 1.0, spriteH: 104, deathStyle: 'vault',
    vault: { speedAfter: 18, duration: 0.55, distance: 0.9 }
  },
  artisan: {
    id: 'artisan', name: '纸扎匠', kind: '辅助', tier: 'h', large: true,
    hp: 1100, armor: 0, speed: 14, dps: 90, scale: 1.04, spriteH: 118, deathStyle: 'artisan',
    support: { interval: 7.5, radius: 240, armor: 200, targets: 2, name: '纸甲' }
  },
  ironjudge: {
    id: 'ironjudge', name: '铁面判官', kind: '重甲', tier: 'h', large: true,
    hp: 1000, armor: 800, armorType: 'mask', armorName: '铁面',
    speed: 12, dps: 150, scale: 1.12, spriteH: 124, deathStyle: 'ironjudge'
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
    const straw = count - tongue >= 2
      ? Math.min(count - tongue, Math.max(1, Math.floor(count * 0.2)))
      : (wi % 5 === 4 ? 1 : 0);
    if (count - tongue - straw > 0) groups.push(['ghost', count - tongue - straw]);
    if (tongue > 0) groups.push(['tongue', tongue]);
    if (straw > 0) groups.push(['straw', straw]);
  } else if (tier === 'm') {
    let rest = count;
    let mourner = 0;
    let bucket = 0;
    let vault = 0;
    let stonehat = 0;
    if (wi >= 7 && rest >= 2) {
      mourner = Math.min(rest - 1, Math.max(1, Math.floor(count * 0.2)));
      rest -= mourner;
    }
    if (wi >= 6 && rest >= 2) {
      bucket = Math.min(rest - 1, Math.max(1, Math.floor(count * 0.25)));
      rest -= bucket;
    }
    if (wi >= 5 && rest >= 2) {
      vault = Math.min(rest - 1, Math.max(1, Math.floor(count * 0.25)));
      rest -= vault;
    }
    if (wi >= 3 && rest >= 1) {
      stonehat = Math.min(rest, Math.max(1, Math.floor(count * 0.3)));
      rest -= stonehat;
    }
    if (rest > 0) groups.push(['paper', rest]);
    if (stonehat > 0) groups.push(['stonehat', stonehat]);
    if (bucket > 0) groups.push(['bucket', bucket]);
    if (vault > 0) groups.push(['vault', vault]);
    if (mourner > 0) groups.push(['mourner', mourner]);
  } else {
    let rest = count;
    const pool = [];
    if (wi >= 6) pool.push('sedan');
    if (wi >= 8) pool.push('artisan');
    if (wi >= 9) pool.push('ironjudge');
    const specialCount = Math.min(Math.max(0, count - 1), pool.length);
    const start = pool.length ? wi % pool.length : 0;
    const specials = [];
    for (let i = 0; i < specialCount; i++) specials.push(pool[(start + i) % pool.length]);
    rest -= specialCount;
    for (const type of specials) {
      if (type === 'sedan') groups.push(['sedan', 1]);
      else if (type === 'artisan') groups.push(['artisan', 1]);
      else if (type === 'ironjudge') groups.push(['ironjudge', 1]);
    }
    if (rest > 0) groups.push(['mountain', rest]);
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

export const TUTORIAL_LEVEL = {
  id: 0,
  name: '新手教程',
  tag: '第一课',
  threat: 1,
  startSun: 200,
  waves: []
};

export function getLevel(id) {
  return LEVELS.find((level) => level.id === id) || LEVELS[0];
}

