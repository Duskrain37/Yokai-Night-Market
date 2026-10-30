const RED = '#c8402f';
const TEAL = '#4f8a86';
const GOLD = '#c79a3b';

export const UPGRADE_TREES = {
  shooter: [
    {
      id: 1, name: '连发', color: RED,
      tiers: [
        { name: '双发', desc: '一次攻击射出两支竹签', cost: 75 },
        { name: '四发', desc: '一次攻击射出四支竹签', cost: 150 },
        { name: '八发', desc: '一次攻击射出八支竹签', cost: 250 }
      ]
    },
    {
      id: 2, name: '邻行', color: TEAL,
      tiers: [
        { name: '借行', desc: '向相邻行补射一发半伤竹签，两侧相通时交替', cost: 75 },
        { name: '双邻', desc: '同时向上下两行各补射一发半伤竹签', cost: 150 },
        { name: '全力', desc: '邻行补射提升为全额伤害', cost: 250 }
      ]
    },
    {
      id: 3, name: '重弹', color: GOLD,
      tiers: [
        { name: '重弹', desc: '30% 概率射出一发双倍伤害的大竹签', cost: 75 },
        { name: '重型', desc: '大竹签概率提升到 60%', cost: 150 },
        { name: '霜重', desc: '大竹签命中后减速敌人 50%，持续 3 秒', cost: 250 }
      ]
    }
  ],
  lantern: [
    {
      id: 1, name: '香火', color: GOLD,
      tiers: [
        { name: '旺火', desc: '每次产出香火 25 → 35', cost: 75 },
        { name: '长明', desc: '每次产出香火提升到 50', cost: 150 },
        { name: '灯会', desc: '每次产出香火提升到 75', cost: 250 }
      ]
    },
    {
      id: 2, name: '灯油', color: RED,
      tiers: [
        { name: '挑芯', desc: '产出间隔 8 秒 → 7 秒', cost: 75 },
        { name: '双芯', desc: '产出间隔缩短到 6 秒', cost: 150 },
        { name: '火树', desc: '产出间隔缩短到 5 秒', cost: 250 }
      ]
    },
    {
      id: 3, name: '灯焰', color: '#b35a2e',
      tiers: [
        { name: '烫手', desc: '被啃时每秒反伤敌人 20', cost: 75 },
        { name: '火舌', desc: '反伤提升到 40/秒', cost: 150 },
        { name: '燎原', desc: '反伤提升到 60/秒', cost: 250 }
      ]
    }
  ],
  wall: [
    {
      id: 1, name: '厚壁', color: '#6f7d84',
      tiers: [
        { name: '加厚', desc: '耐久 3000 → 4000', cost: 75 },
        { name: '磐石', desc: '耐久提升到 5500', cost: 150 },
        { name: '山岳', desc: '耐久提升到 7500', cost: 250 }
      ]
    },
    {
      id: 2, name: '粗粝', color: '#9a5a3c',
      tiers: [
        { name: '磨齿', desc: '被啃时每秒反伤敌人 15', cost: 75 },
        { name: '重磨', desc: '反伤提升到 30/秒', cost: 150 },
        { name: '碾磨', desc: '反伤提升到 50/秒', cost: 250 }
      ]
    },
    {
      id: 3, name: '碎磨', color: GOLD,
      tiers: [
        { name: '碎石', desc: '破碎时对周围敌人造成 300 伤害', cost: 75 },
        { name: '崩石', desc: '破碎伤害提升到 600', cost: 150 },
        { name: '石雨', desc: '破碎伤害提升到 1000', cost: 250 }
      ]
    }
  ],
  bell: [
    {
      id: 1, name: '急铃', color: RED,
      tiers: [
        { name: '快摇', desc: '摇铃间隔 2.5 秒 → 2 秒', cost: 75 },
        { name: '连响', desc: '摇铃间隔缩短到 1.6 秒', cost: 150 },
        { name: '惊魂', desc: '摇铃间隔缩短到 1.2 秒', cost: 250 }
      ]
    },
    {
      id: 2, name: '回响', color: TEAL,
      tiers: [
        { name: '长音', desc: '减速持续 3 秒 → 4 秒', cost: 75 },
        { name: '沉音', desc: '减速持续 5 秒，效果提升到 60%', cost: 150 },
        { name: '定魂', desc: '减速效果提升到 70%', cost: 250 }
      ]
    },
    {
      id: 3, name: '余音', color: GOLD,
      tiers: [
        { name: '余音', desc: '摇铃时对前方敌人造成 15 伤害', cost: 75 },
        { name: '裂铃', desc: '摇铃伤害提升到 25', cost: 150 },
        { name: '摄魂', desc: '摇铃伤害 40，并延长减速 2 秒', cost: 250 }
      ]
    }
  ],
  censer: [
    {
      id: 1, name: '炉火', color: RED,
      tiers: [
        { name: '旺炉', desc: '每圈香雾伤害 45 → 70', cost: 75 },
        { name: '猛火', desc: '香雾伤害提升到 100', cost: 150 },
        { name: '熔金', desc: '香雾伤害提升到 140', cost: 250 }
      ]
    },
    {
      id: 2, name: '烟气', color: TEAL,
      tiers: [
        { name: '扩烟', desc: '香雾半径 140 → 160，能熏到更远的邻行', cost: 75 },
        { name: '浓烟', desc: '香雾半径扩大到 185', cost: 150 },
        { name: '满街', desc: '香雾半径扩大到 215', cost: 250 }
      ]
    },
    {
      id: 3, name: '安神', color: GOLD,
      tiers: [
        { name: '静气', desc: '被香雾熏到的敌人减速 25%，持续 2 秒', cost: 75 },
        { name: '宁神', desc: '减速提升到 35%，持续 2.5 秒', cost: 150 },
        { name: '定魄', desc: '减速提升到 45%，持续 3 秒', cost: 250 }
      ]
    }
  ],
  umbrella: [
    {
      id: 1, name: '伞骨', color: TEAL,
      tiers: [
        { name: '加固', desc: '相邻植物所受啃食伤害降低 15% → 30%', cost: 75 },
        { name: '密骨', desc: '庇护减伤提升到 40%', cost: 150 },
        { name: '铁骨', desc: '庇护减伤提升到 50%', cost: 250 }
      ]
    },
    {
      id: 2, name: '回旋', color: RED,
      tiers: [
        { name: '疾风', desc: '每 4.6 秒撑伞，把本行近处敌人推开 55 像素', cost: 75 },
        { name: '旋风', desc: '回旋间隔 3.8 秒，推开 70 像素', cost: 150 },
        { name: '罡风', desc: '回旋间隔 3 秒，推开 85 像素', cost: 250 }
      ]
    },
    {
      id: 3, name: '雨露', color: GOLD,
      tiers: [
        { name: '润物', desc: '相邻植物每秒回复 8 点耐久', cost: 75 },
        { name: '甘霖', desc: '修复提升到每秒 14 点', cost: 150 },
        { name: '回春', desc: '修复提升到每秒 22 点', cost: 250 }
      ]
    }
  ],
  lion: [
    {
      id: 1, name: '狮头', color: RED,
      tiers: [
        { name: '开脸', desc: '撞头伤害 60 → 90', cost: 75 },
        { name: '怒目', desc: '撞头伤害提升到 125', cost: 150 },
        { name: '吞煞', desc: '撞头伤害提升到 170', cost: 250 }
      ]
    },
    {
      id: 2, name: '步法', color: TEAL,
      tiers: [
        { name: '踩桩', desc: '攻击间隔 1.35 秒 → 1.15 秒，15% 概率撞晕 0.65 秒', cost: 75 },
        { name: '腾挪', desc: '攻击间隔缩短到 0.95 秒，眩晕概率 25%', cost: 150 },
        { name: '扑食', desc: '攻击间隔缩短到 0.75 秒，眩晕概率 35%', cost: 250 }
      ]
    },
    {
      id: 3, name: '采青', color: GOLD,
      tiers: [
        { name: '衔青', desc: '每次撞中敌人回复自身 25 耐久', cost: 75 },
        { name: '纳福', desc: '每次撞中回复 45 耐久', cost: 150 },
        { name: '瑞气', desc: '每次撞中回复 70 耐久', cost: 250 }
      ]
    }
  ]
};

export function initUpgrades() {
  return { 1: 0, 2: 0, 3: 0 };
}

export function pathsFor(plant) {
  return UPGRADE_TREES[plant.type] || [];
}

export function tierOf(plant, pathId) {
  return plant.upgrades?.[pathId] ?? 0;
}

function openedPaths(plant) {
  return pathsFor(plant).filter((p) => tierOf(plant, p.id) > 0).length;
}

function otherPathHasTier3(plant, pathId) {
  return pathsFor(plant).some(
    (p) => p.id !== pathId && tierOf(plant, p.id) >= 3
  );
}

export function pathStatus(plant, pathId) {
  const path = pathsFor(plant).find((p) => p.id === pathId);
  if (!path) {
    return { ok: false, kind: 'none', path: null, tier: 0, reason: '此物无法升阶' };
  }
  const tier = tierOf(plant, pathId);

  if (tier >= 3) {
    return { ok: false, kind: 'maxed', path, tier, reason: `${path.name}已修到三级` };
  }
  if (tier === 0 && openedPaths(plant) >= 2) {
    return { ok: false, kind: 'locked', path, tier, reason: '已选两路，第三路关闭' };
  }
  if (tier === 2 && otherPathHasTier3(plant, pathId)) {
    return { ok: false, kind: 'locked3', path, tier, reason: '另一路已到三级，此路三级关闭' };
  }

  const next = path.tiers[tier];
  return {
    ok: true,
    kind: 'next',
    path,
    tier,
    nextTier: tier + 1,
    cost: next.cost,
    name: next.name,
    desc: next.desc
  };
}

export function getFan(plant) {
  const paths = pathsFor(plant);
  if (paths.length === 0) return null;
  const dir = plant.r >= 2 ? -1 : 1;
  const radius = 92;
  const angles = dir === -1 ? [-150, -90, -30] : [150, 90, 30];
  const petals = paths.map((path, i) => {
    const rad = (angles[i] * Math.PI) / 180;
    return {
      path,
      x: plant.x + Math.cos(rad) * radius,
      y: plant.y + Math.sin(rad) * radius,
      w: 70,
      h: 78
    };
  });
  return { dir, radius, petals, cx: plant.x, cy: plant.y };
}

export function petalAt(plant, mx, my) {
  const fan = getFan(plant);
  if (!fan) return null;
  for (const petal of fan.petals) {
    if (
      mx >= petal.x - petal.w / 2 &&
      mx <= petal.x + petal.w / 2 &&
      my >= petal.y - petal.h / 2 &&
      my <= petal.y + petal.h / 2
    ) {
      return petal;
    }
  }
  return null;
}

export function upgradeDots(plant) {
  const dots = [];
  for (const path of pathsFor(plant)) {
    const tier = tierOf(plant, path.id);
    for (let i = 0; i < tier; i++) dots.push(path.color);
  }
  return dots;
}

export const PLANT_EFFECTS = {
  shooter: {
    volley: [1, 2, 4, 8],
    adjacentSides: [0, 1, 2, 2],
    adjacentFactor: [0, 0.5, 0.5, 1],
    critChance: [0, 0.3, 0.6, 0.6],
    critSlow: [0, 0, 0, 3]
  },
  lantern: {
    value: [25, 35, 50, 75],
    interval: [8, 7, 6, 5],
    reflect: [0, 20, 40, 60]
  },
  wall: {
    hp: [3000, 4000, 5500, 7500],
    reflect: [0, 15, 30, 50],
    blast: [0, 300, 600, 1000]
  },
  bell: {
    interval: [2.5, 2.0, 1.6, 1.2],
    slowDuration: [3, 4, 5, 5],
    slowFactor: [0.5, 0.5, 0.4, 0.3],
    damage: [0, 15, 25, 40],
    slowExtend: [0, 0, 0, 2]
  },
  censer: {
    interval: 3.0,
    damage: [45, 70, 100, 140],
    radius: [140, 160, 185, 215],
    slowFactor: [0, 0.25, 0.35, 0.45],
    slowDuration: [0, 2, 2.5, 3]
  },
  umbrella: {
    guard: [0.15, 0.3, 0.4, 0.5],
    blowInterval: [5.5, 4.6, 3.8, 3.0],
    blowDist: [46, 55, 70, 85],
    regen: [0, 8, 14, 22]
  },
  lion: {
    damage: [60, 90, 125, 170],
    interval: [1.35, 1.15, 0.95, 0.75],
    stunChance: [0, 0.15, 0.25, 0.35],
    stunDuration: 0.65,
    heal: [0, 25, 45, 70],
    reach: 110,
    knock: 18
  }
};
