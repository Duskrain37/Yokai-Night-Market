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
    pulse: { interval: 2.5, slow: 3 }
  },
  censer: {
    id: 'censer', name: '香炉', role: '范围', cost: 150, cooldown: 18, hp: 340, tint: '#8a6f4d',
    spriteH: 84, censer: { interval: 3.0, radius: 140 }
  },
  umbrella: {
    id: 'umbrella', name: '纸伞', role: '辅助', cost: 100, cooldown: 16, hp: 480, tint: '#b5493e',
    spriteH: 90, umbrella: { interval: 5.5, knock: 46, reach: 150 }
  },
  lion: {
    id: 'lion', name: '醒狮', role: '近战', cost: 150, cooldown: 20, hp: 1200, tint: '#c9472f',
    spriteH: 92, melee: { reach: 110 }
  }
};

export const PLANT_ORDER = [
  'lantern', 'shooter', 'wall', 'bomb', 'bell', 'censer', 'umbrella', 'lion'
];

export const ZOMBIE_TYPES = {
  ghost: { id: 'ghost', name: '饿鬼', kind: '小僵尸', hp: 200, shell: 0, speed: 20, dps: 70, scale: 1 },
  paper: { id: 'paper', name: '纸人', kind: '特殊', hp: 200, shell: 250, speed: 20, dps: 70, scale: 1.05 },
  mountain: { id: 'mountain', name: '山魈', kind: '重型', hp: 900, shell: 0, speed: 17, dps: 120, scale: 1.28 },
  tongue: {
    id: 'tongue', name: '长舌鬼', kind: '超小', hp: 150, shell: 0, speed: 30, dps: 80,
    reach: 62, scale: 0.98
  },
  mourner: {
    id: 'mourner', name: '哭丧鬼', kind: '特殊', hp: 320, shell: 0, speed: 16, dps: 65,
    scale: 1.06, aura: { radius: 150, interval: 4.5, haste: 1.35, duration: 2.6 }
  },
  sedan: {
    id: 'sedan', name: '抬轿鬼', kind: '重型', hp: 420, shell: 720, speed: 14.5, dps: 85,
    scale: 1.0, spriteH: 104, split: { type: 'ghost', count: 2, hp: 0.6 }
  }
};

export const BASE_WAVES = [
  { t: 16, flag: false, groups: [['ghost', 1]] },
  { t: 34, flag: false, groups: [['ghost', 2]] },
  { t: 52, flag: false, groups: [['ghost', 2], ['paper', 1]] },
  { t: 70, flag: false, groups: [['ghost', 3], ['tongue', 1]] },
  { t: 88, flag: false, groups: [['ghost', 2], ['paper', 2], ['tongue', 1]] },
  { t: 108, flag: true, groups: [['ghost', 5], ['paper', 2], ['tongue', 2]] },
  { t: 128, flag: false, groups: [['ghost', 3], ['paper', 2], ['mountain', 1], ['tongue', 1]] },
  { t: 148, flag: false, groups: [['ghost', 4], ['paper', 2], ['tongue', 1], ['mourner', 1]] },
  { t: 168, flag: false, groups: [['ghost', 3], ['paper', 2], ['mountain', 1], ['sedan', 1]] },
  { t: 188, flag: true, groups: [['ghost', 6], ['paper', 3], ['tongue', 3], ['mourner', 1]] },
  { t: 208, flag: false, groups: [['ghost', 5], ['paper', 3], ['mountain', 2], ['tongue', 2], ['sedan', 1]] },
  { t: 228, flag: true, groups: [['ghost', 8], ['paper', 4], ['mountain', 2], ['tongue', 4], ['mourner', 2], ['sedan', 1]] }
];

const LEVEL_INFO = [
  { name: '第一夜', tag: '开张', threat: 1.0 },
  { name: '第二夜', tag: '熟客', threat: 1.444 },
  { name: '第三夜', tag: '起风', threat: 1.889 },
  { name: '第四夜', tag: '灯多', threat: 2.333 },
  { name: '第五夜', tag: '山雨', threat: 2.778 },
  { name: '第六夜', tag: '满街', threat: 3.222 },
  { name: '第七夜', tag: '问路', threat: 3.667 },
  { name: '第八夜', tag: '不眠', threat: 4.111 },
  { name: '第九夜', tag: '月近', threat: 4.556 },
  { name: '第十夜', tag: '天亮前', threat: 5.0 }
];

export const LEVELS = LEVEL_INFO.map((info, i) => ({
  id: i + 1,
  name: info.name,
  tag: info.tag,
  threat: info.threat,
  startSun: 100,
  waves: BASE_WAVES
}));

export function getLevel(id) {
  return LEVELS.find((level) => level.id === id) || LEVELS[0];
}

export const LEVEL = LEVELS[0];

