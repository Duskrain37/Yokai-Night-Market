export const VIEW = { w: 1280, h: 720 };

export const BOARD = { cols: 9, rows: 5, cw: 88, ch: 86, x: 238, y: 206 };
export const BOARD_W = BOARD.cols * BOARD.cw;
export const BOARD_H = BOARD.rows * BOARD.ch;

export const CARD_W = 62;
export const CARD_H = 96;
export const CARD_GAP = 4;
export const CARD_X = 216;
export const CARD_Y = 52;

export const BTN = {
  start: { x: 64, y: 402, w: 356, h: 92 },
  continueMenu: { x: 64, y: 508, w: 150, h: 44 },
  newRun: { x: 226, y: 508, w: 150, h: 44 },
  settingsMenu: { x: 382, y: 590, w: 88, h: 62 },
  overlay: { x: 540, y: 500, w: 200, h: 52 },
  toMenu: { x: 540, y: 562, w: 200, h: 38 },
  resume: { x: 430, y: 386, w: 200, h: 48 },
  pauseSettings: { x: 650, y: 386, w: 200, h: 48 },
  restart: { x: 430, y: 448, w: 200, h: 48 },
  backMenu: { x: 650, y: 448, w: 200, h: 48 },
  confirmYes: { x: 470, y: 404, w: 160, h: 44 },
  confirmNo: { x: 650, y: 404, w: 160, h: 44 },
  pauseAlmanac: { x: 540, y: 510, w: 200, h: 44 },
  tutorialMenu: { x: 276, y: 590, w: 88, h: 62 },
  almanacMenu: { x: 170, y: 590, w: 88, h: 62 },
  levelsMenu: { x: 64, y: 590, w: 88, h: 62 },
  pause: { x: 1176, y: 52, w: 52, h: 52 },
  shovel: { x: 752, y: 100, w: 52, h: 52 },
  quickWave: { x: 752, y: 42, w: 52, h: 52 },
  cheat: { x: 1112, y: 52, w: 52, h: 52 },
  settingsBack: { x: 540, y: 566, w: 200, h: 44 },
  cheatPanel: { x: 880, y: 112, w: 312, h: 244 },
  cheatAdd: { x: 896, y: 166, w: 280, h: 38 },
  cheatKill: { x: 896, y: 210, w: 280, h: 38 },
  cheatMowers: { x: 896, y: 254, w: 280, h: 38 },
  cheatWin: { x: 896, y: 298, w: 280, h: 38 }
};

export const SETTINGS = {
  panel: { x: 300, y: 28, w: 680, h: 662 },
  back: { x: 540, y: 626, w: 200, h: 44 },
  titleY: 76,
  labelX: 350,
  pillX: 620,
  pillW: 78,
  pillH: 32,
  pillGap: 8,
  rows: [
    {
      key: 'speed', y: 132, label: '战斗速度',
      note: '整个战局的时间流速', options: [
        { value: 1, label: '1x' },
        { value: 1.5, label: '1.5x' },
        { value: 2, label: '2x' },
        { value: 3, label: '3x' }
      ]
    },
    {
      key: 'resolution', y: 173, label: '渲染分辨率',
      note: '自适应最高 1920 宽，优先 60 帧；固定档按所选宽度', options: [
        { value: 'auto', label: '自适应' },
        { value: '720', label: '720p' },
        { value: '1080', label: '1080p' },
        { value: '1600', label: '1600p' }
      ]
    },
    {
      key: 'healthBars', y: 214, label: '血条显示模式',
      note: '恶客头顶的血条与数字', options: [
        { value: 'off', label: '不显示' },
        { value: 'bar', label: '显示血条' },
        { value: 'barText', label: '血条和血量' }
      ]
    },
    {
      key: 'autoCollect', y: 255, label: '自动拾取香火',
      note: '开启后无需点击香火', options: [
        { value: true, label: '开' },
        { value: false, label: '关' }
      ]
    },
    {
      key: 'collectDelay', y: 296, label: '拾取延迟',
      note: '香火落地后的收取等待', requires: 'autoCollect', options: [
        { value: 0, label: '0 秒' },
        { value: 3, label: '3 秒' }
      ]
    },
    {
      key: 'quickWave', y: 337, label: '快速召唤下一波',
      note: '开启后在铲子正上方出现唤波按钮', options: [
        { value: true, label: '开' },
        { value: false, label: '关' }
      ]
    },
    {
      key: 'difficulty', y: 378, label: '难度',
      note: '出怪与血量 1× / 1.25× / 1.5×，进入对局后锁定', lockInRun: true, options: [
        { value: 'easy', label: '简单' },
        { value: 'normal', label: '普通' },
        { value: 'hard', label: '困难' }
      ]
    },
    {
      key: 'cheats', y: 419, label: '作弊菜单',
      note: '局内也可开关；开启后局内出现作弊按钮', options: [
        { value: true, label: '开' },
        { value: false, label: '关' }
      ]
    },
    {
      key: 'sound', y: 460, label: '音效与音乐总开关',
      note: '关闭后全局静音', options: [
        { value: true, label: '开' },
        { value: false, label: '关' }
      ]
    },
    {
      key: 'musicStyle', y: 501, label: '音乐风格',
      note: '朴素：原程序化器乐；激昂：本地 AI 生成器乐', options: [
        { value: 'plain', label: '朴素' },
        { value: 'grand', label: '激昂' }
      ]
    },
    {
      key: 'musicVolume', y: 542, label: '音乐音量', type: 'range', min: 0, max: 100, step: 1,
      note: '拖动 0%—100%'
    },
    {
      key: 'sfxVolume', y: 583, label: '音效音量', type: 'range', min: 0, max: 100, step: 1,
      note: '拖动 0%—100%'
    }
  ]
};

export function settingsRangeRect(row) {
  return { x: SETTINGS.pillX, y: row.y - 7, w: 280, h: 14 };
}

export function cardRect(i, count = 8) {
  const tight = count > 8;
  const w = tight ? 50 : CARD_W;
  const gap = tight ? 3 : CARD_GAP;
  return { x: CARD_X + i * (w + gap), y: CARD_Y, w, h: CARD_H };
}

export function cellCenter(c, r) {
  return {
    x: BOARD.x + c * BOARD.cw + BOARD.cw / 2,
    y: BOARD.y + r * BOARD.ch + BOARD.ch / 2
  };
}

export function cellAt(x, y) {
  if (x < BOARD.x || y < BOARD.y || x >= BOARD.x + BOARD_W || y >= BOARD.y + BOARD_H) {
    return null;
  }
  const c = Math.floor((x - BOARD.x) / BOARD.cw);
  const r = Math.floor((y - BOARD.y) / BOARD.ch);
  return { c, r };
}

export function inRect(x, y, rect) {
  return x >= rect.x && x <= rect.x + rect.w && y >= rect.y && y <= rect.y + rect.h;
}

export function settingsPill(row, index) {
  return {
    x: SETTINGS.pillX + index * (SETTINGS.pillW + SETTINGS.pillGap),
    y: row.y - SETTINGS.pillH / 2,
    w: SETTINGS.pillW,
    h: SETTINGS.pillH,
    option: row.options[index]
  };
}

export function settingsRowEnabled(row, fromMenu) {
  if (row.lockInRun && !fromMenu) return false;
  return true;
}

export const ALMANAC = {
  book: { x: 90, y: 40, w: 1100, h: 640 },
  close: { x: 1112, y: 52, w: 64, h: 34 },
  tabs: [
    { key: 'plant', label: '草木志', rect: { x: 120, y: 112, w: 104, h: 34 } },
    { key: 'zombie', label: '恶客录', rect: { x: 232, y: 112, w: 104, h: 34 } }
  ],
  list: { x: 112, y: 166, w: 232, rowH: 36, gap: 4, cols: 2, colW: 110, gapX: 6 },
  right: { x: 374, y: 92, w: 796, h: 566 },
  content: { x: 398, y: 196, w: 700, h: 444 },
  scrollbar: { x: 1112, y: 196, w: 10, h: 444 }
};

export function almanacEntryRect(i) {
  const list = ALMANAC.list;
  const col = i % list.cols;
  const row = Math.floor(i / list.cols);
  return {
    x: list.x + col * (list.colW + list.gapX),
    y: list.y + row * (list.rowH + list.gap),
    w: list.colW,
    h: list.rowH
  };
}

export const LEVELS_UI = {
  back: { x: 54, y: 46, w: 112, h: 40 },
  titleY: 68,
  subtitleY: 96,
  island: { x: 208, y: 166, w: 800, h: 400 },
  card: { x: 1012, y: 44, w: 232, h: 156 },
  rail: { x: 1048, y: 216, w: 196, h: 76, gap: 12 },
  info: { x: 48, y: 604, w: 520, h: 82 },
  enter: { x: 416, y: 622, w: 136, h: 46 },
  legendY: 692,
  route: [[0.1, 0.82], [0.32, 0.56], [0.55, 0.52], [0.74, 0.32], [0.89, 0.18]]
};

export function levelDayIsleRect(i) {
  const r = LEVELS_UI.rail;
  return { x: r.x, y: r.y + i * (r.h + r.gap), w: r.w, h: r.h };
}

export function levelNodePoint(i) {
  const isle = LEVELS_UI.island;
  const p = LEVELS_UI.route[i] || LEVELS_UI.route[0];
  return { x: isle.x + isle.w * p[0], y: isle.y + isle.h * p[1] };
}

export function levelNodeRect(i) {
  const p = levelNodePoint(i);
  return { x: p.x - 27, y: p.y - 30, w: 54, h: 60 };
}

export const PREP_CINEMA = {
  total: 5.8,
  panStart: 1.5,
  revealStart: 2.25,
  fadeStart: 5.05
};

export const TUTORIAL_UI = {
  panel: { x: 238, y: 646, w: 792, h: 56 },
  skip: { x: 946, y: 654, w: 74, h: 40 }
};

export const TRAINING_UI = {
  panel: { x: 360, y: 176, w: 560, h: 360 },
  tutorial: { x: 420, y: 274, w: 440, h: 82 },
  sandbox: { x: 420, y: 374, w: 440, h: 82 },
  back: { x: 540, y: 484, w: 200, h: 38 }
};

export const TRAIN_CHEAT = {
  panel: { x: 210, y: 70, w: 860, h: 590 },
  tabs: { x: 760, y: 94, w: 120, h: 36, gap: 8 },
  rows: { x: 250, y: 158, w: 380, h: 42, gap: 8 },
  spawnGrid: { x: 250, y: 152, cols: 4, rows: 3, cellW: 168, cellH: 108, gapX: 10, gapY: 8 },
  countPills: { x: 250, y: 514, w: 70, h: 36, gap: 8 },
  lanePills: { x: 250, y: 562, w: 62, h: 36, gap: 7 },
  summon: { x: 834, y: 530, w: 200, h: 50 }
};

export function trainSpawnCellRect(i) {
  const g = TRAIN_CHEAT.spawnGrid;
  const col = i % g.cols;
  const row = Math.floor(i / g.cols);
  return {
    x: g.x + col * (g.cellW + g.gapX),
    y: g.y + row * (g.cellH + g.gapY),
    w: g.cellW,
    h: g.cellH
  };
}

export const PREP = {
  panel: { x: 70, y: 34, w: 1140, h: 652 },
  back: { x: 462, y: 606, w: 150, h: 46 },
  confirm: { x: 636, y: 606, w: 182, h: 46 },
  threatBar: { x: 104, y: 150, w: 300, h: 12 },
  roster: { x: 294, y: 266, cols: 9, rows: 2, cardW: 58, cardH: 78, gap: 4, gapY: 4 },
  slots: { x: 294, y: 458, cols: 10, cardW: 62, cardH: 86, gap: 8 },
  zombies: { x: 872, y: 148, cols: 4, rows: 3, cellW: 68, cellH: 86, gap: 14, gapY: 4 },
  warning: { x: 390, y: 196, w: 500, h: 280 },
  warningYes: { x: 418, y: 402, w: 200, h: 46 },
  warningNo: { x: 662, y: 402, w: 200, h: 46 },
  warningOnly: { x: 540, y: 402, w: 200, h: 46 }
};

export function prepRosterRect(i) {
  const g = PREP.roster;
  const col = i % g.cols;
  const row = Math.floor(i / g.cols);
  return {
    x: g.x + col * (g.cardW + g.gap),
    y: g.y + row * (g.cardH + g.gapY),
    w: g.cardW,
    h: g.cardH
  };
}

export function prepSlotRect(i) {
  const g = PREP.slots;
  return {
    x: g.x + i * (g.cardW + g.gap),
    y: g.y,
    w: g.cardW,
    h: g.cardH
  };
}

export function prepZombieRect(i) {
  const g = PREP.zombies;
  const col = i % g.cols;
  const row = Math.floor(i / g.cols);
  return {
    x: g.x + col * (g.cellW + g.gap),
    y: g.y + row * (g.cellH + g.gapY),
    w: g.cellW,
    h: g.cellH
  };
}
