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
  start: { x: 540, y: 458, w: 200, h: 56 },
  settingsMenu: { x: 540, y: 526, w: 200, h: 44 },
  newRun: { x: 420, y: 526, w: 190, h: 44 },
  settingsMenuWide: { x: 630, y: 526, w: 190, h: 44 },
  overlay: { x: 540, y: 500, w: 200, h: 52 },
  toMenu: { x: 540, y: 562, w: 200, h: 38 },
  resume: { x: 430, y: 386, w: 200, h: 48 },
  pauseSettings: { x: 650, y: 386, w: 200, h: 48 },
  restart: { x: 430, y: 448, w: 200, h: 48 },
  backMenu: { x: 650, y: 448, w: 200, h: 48 },
  confirmYes: { x: 470, y: 404, w: 160, h: 44 },
  confirmNo: { x: 650, y: 404, w: 160, h: 44 },
  pauseAlmanac: { x: 540, y: 510, w: 200, h: 44 },
  almanacMenu: { x: 1090, y: 60, w: 130, h: 42 },
  levelsMenu: { x: 940, y: 60, w: 130, h: 42 },
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
  panel: { x: 300, y: 60, w: 680, h: 650 },
  back: { x: 540, y: 610, w: 200, h: 44 },
  titleY: 112,
  labelX: 350,
  pillX: 620,
  pillW: 80,
  pillH: 36,
  pillGap: 8,
  rows: [
    {
      key: 'speed', y: 156, label: '战斗速度',
      note: '整个战局的时间流速', options: [
        { value: 1, label: '1x' },
        { value: 1.5, label: '1.5x' },
        { value: 2, label: '2x' },
        { value: 3, label: '3x' }
      ]
    },
    {
      key: 'healthBars', y: 212, label: '血条显示模式',
      note: '恶客头顶的血条与数字', options: [
        { value: 'off', label: '不显示' },
        { value: 'bar', label: '显示血条' },
        { value: 'barText', label: '血条和血量' }
      ]
    },
    {
      key: 'autoCollect', y: 268, label: '自动拾取香火',
      note: '开启后无需点击香火', options: [
        { value: true, label: '开' },
        { value: false, label: '关' }
      ]
    },
    {
      key: 'collectDelay', y: 324, label: '拾取延迟',
      note: '香火落地后的收取等待', requires: 'autoCollect', options: [
        { value: 0, label: '0 秒' },
        { value: 3, label: '3 秒' }
      ]
    },
    {
      key: 'quickWave', y: 380, label: '快速召唤下一波',
      note: '开启后在铲子正上方出现唤波按钮', options: [
        { value: true, label: '开' },
        { value: false, label: '关' }
      ]
    },
    {
      key: 'difficulty', y: 436, label: '难度',
      note: '出怪与血量 1× / 1.25× / 1.5×，进入对局后锁定', lockInRun: true, options: [
        { value: 'easy', label: '简单' },
        { value: 'normal', label: '普通' },
        { value: 'hard', label: '困难' }
      ]
    },
    {
      key: 'cheats', y: 492, label: '作弊菜单',
      note: '仅局外可改，开启后局内出现作弊按钮', lockInRun: true, options: [
        { value: true, label: '开' },
        { value: false, label: '关' }
      ]
    },
    {
      key: 'sound', y: 548, label: '音效与音乐',
      note: '关闭后全局静音', options: [
        { value: true, label: '开' },
        { value: false, label: '关' }
      ]
    }
  ]
};

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
  list: { x: 112, y: 166, w: 232, rowH: 52, gap: 5 },
  right: { x: 374, y: 92, w: 796, h: 566 },
  content: { x: 398, y: 196, w: 700, h: 444 },
  scrollbar: { x: 1112, y: 196, w: 10, h: 444 }
};

export function almanacEntryRect(i) {
  return {
    x: ALMANAC.list.x,
    y: ALMANAC.list.y + i * (ALMANAC.list.rowH + ALMANAC.list.gap),
    w: ALMANAC.list.w,
    h: ALMANAC.list.rowH
  };
}

export const LEVELS_UI = {
  panel: { x: 300, y: 96, w: 680, h: 540 },
  back: { x: 540, y: 566, w: 200, h: 44 },
  titleY: 142,
  grid: { x: 330, y: 200, cols: 5, rows: 2, cardW: 116, cardH: 150, gapX: 12, gapY: 16 }
};

export function levelCardRect(i) {
  const g = LEVELS_UI.grid;
  const col = i % g.cols;
  const row = Math.floor(i / g.cols);
  return {
    x: g.x + col * (g.cardW + g.gapX),
    y: g.y + row * (g.cardH + g.gapY),
    w: g.cardW,
    h: g.cardH
  };
}

export const PREP_CINEMA = {
  total: 5.8,
  panStart: 1.5,
  revealStart: 2.25,
  fadeStart: 5.05
};

export const PREP = {
  panel: { x: 70, y: 34, w: 1140, h: 652 },
  back: { x: 462, y: 606, w: 150, h: 46 },
  confirm: { x: 636, y: 606, w: 182, h: 46 },
  threatBar: { x: 104, y: 150, w: 300, h: 12 },
  roster: { x: 294, y: 270, cols: 8, cardW: 78, cardH: 104, gap: 10 },
  slots: { x: 294, y: 430, cols: 10, cardW: 62, cardH: 86, gap: 8 },
  zombies: { x: 700, y: 148, cols: 6, cellW: 68, cellH: 90, gap: 14 },
  warning: { x: 390, y: 196, w: 500, h: 280 },
  warningYes: { x: 418, y: 402, w: 200, h: 46 },
  warningNo: { x: 662, y: 402, w: 200, h: 46 },
  warningOnly: { x: 540, y: 402, w: 200, h: 46 }
};

export function prepRosterRect(i) {
  const g = PREP.roster;
  return {
    x: g.x + i * (g.cardW + g.gap),
    y: g.y,
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
  return {
    x: g.x + i * (g.cellW + g.gap),
    y: g.y,
    w: g.cellW,
    h: g.cellH
  };
}
