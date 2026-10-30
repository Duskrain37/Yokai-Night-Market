import { LEVELS, getLevel, PLANT_TYPES, PLANT_ORDER, ZOMBIE_TYPES } from '../content.js';
import {
  ALMANAC, BOARD, BOARD_W, BTN, LEVELS_UI, PREP, PREP_CINEMA, SETTINGS, VIEW,
  almanacEntryRect, cardRect, cellAt, cellCenter, inRect, levelCardRect,
  prepRosterRect, prepSlotRect, prepZombieRect, settingsPill, settingsRowEnabled
} from '../layout.js';
import { initUpgrades, pathsFor, pathStatus, petalAt, tierOf, PLANT_EFFECTS } from './upgrade.js';
import { almanacEntries } from '../content/almanac.js';
import * as storage from '../core/storage.js';
import { audio } from '../audio/audio.js';

const ROW_Y = Array.from({ length: BOARD.rows }, (_, r) =>
  BOARD.y + r * BOARD.ch + BOARD.ch / 2
);

const DIFFICULTY_MULT = {
  easy: { count: 1, hp: 1 },
  normal: { count: 1.25, hp: 1.25 },
  hard: { count: 1.5, hp: 1.5 }
};

const MAX_LOADOUT = 10;

function cleanLoadout(ids) {
  const out = [];
  if (!Array.isArray(ids)) return out;
  for (const id of ids) {
    if (typeof id !== 'string' || !PLANT_TYPES[id] || out.includes(id)) continue;
    out.push(id);
    if (out.length >= MAX_LOADOUT) break;
  }
  return out;
}

const DEFAULT_SETTINGS = {
  speed: 1,
  autoCollect: true,
  collectDelay: 0,
  quickWave: true,
  healthBars: 'bar',
  difficulty: 'easy',
  cheats: false,
  sound: true
};

const DEFAULT_RECORDS = {
  bestWave: 0,
  bestKills: 0,
  wins: 0,
  bestWinTime: null
};

const DEFAULT_PROGRESS = {
  selected: 1,
  cleared: []
};

export class Game {
  constructor() {
    this.phase = 'menu';
    this.mouse = { x: 640, y: 360 };
    this.settings = storage.loadSettings(DEFAULT_SETTINGS);
    this.records = storage.loadRecords(DEFAULT_RECORDS);
    this.progress = storage.loadProgress(DEFAULT_PROGRESS);
    this.selectedLevel = Math.max(1, Math.min(LEVELS.length, this.progress.selected || 1));
    this.level = getLevel(this.selectedLevel);
    this.runLevelId = this.level.id;
    this.levelThreat = this.level.threat;
    this.levelCountMul = Math.sqrt(this.level.threat);
    this.levelHpMul = Math.sqrt(this.level.threat);
    this.hasSave = false;
    this.saveMeta = null;
    this.menuNotice = null;
    this.overlay = null;
    this.overlayFrom = null;
    this.runDifficulty = 'easy';
    this.runCheats = false;
    this.confirmNew = false;
    this.almanacTab = 'plant';
    this.almanacIndex = 0;
    this.almanacScroll = 0;
    this.almanacMaxScroll = 0;
    this.almanacReturn = null;
    const savedLoadout = storage.loadLoadout(PLANT_ORDER);
    this.loadout = cleanLoadout(savedLoadout);
    if (!this.loadout.length && savedLoadout.length) this.loadout = [...PLANT_ORDER];
    this.prep = null;
    this.reset();
    this.refreshSaveInfo();
  }

  reset(cardIds = this.loadout) {
    this.time = 0;
    this.sun = this.level.startSun;
    this.plants = [];
    this.zombies = [];
    this.projectiles = [];
    this.orbs = [];
    this.particles = [];
    this.floaters = [];
    this.cells = Array.from({ length: BOARD.rows }, () => Array(BOARD.cols).fill(null));
    this.cards = cleanLoadout(cardIds).map((id) => ({ id, def: PLANT_TYPES[id], cd: 0 }));
    this.selected = -1;
    this.shovel = false;
    this.mowers = Array.from({ length: BOARD.rows }, (_, r) => ({
      row: r, ready: true, active: false, x: BOARD.x - 32
    }));
    this.waveIndex = 0;
    this.waveTotal = this.level.waves.length;
    this.spawnQueue = [];
    this.pendingSpawns = [];
    this.naturalTimer = 3;
    this.banner = null;
    this.shake = 0;
    this.kills = 0;
    this.result = null;
    this.hover = null;
    this.menu = null;
    this.overlay = null;
    this.overlayFrom = null;
    this.confirmBack = false;
    this.confirmNew = false;
    this.almanacScroll = 0;
  }

  startRun(levelId = this.selectedLevel, loadout = this.loadout) {
    const ids = cleanLoadout(loadout);
    if (!ids.length) return false;
    const level = getLevel(levelId);
    this.level = level;
    this.runLevelId = level.id;
    this.selectedLevel = level.id;
    this.levelThreat = level.threat;
    this.levelCountMul = Math.sqrt(level.threat);
    this.levelHpMul = Math.sqrt(level.threat);
    this.loadout = [...ids];
    this.runLoadout = [...ids];
    storage.saveLoadout(ids);
    this.reset(ids);
    this.phase = 'playing';
    this.prep = null;
    this.almanacReturn = null;
    this.runDifficulty = this.settings.difficulty;
    this.runCheats = this.settings.cheats;
    this.menuNotice = null;
    this.banner = {
      text: `${level.name} · ${level.tag} · 守住${level.waves.length}波`,
      t: 3,
      max: 3
    };
    this.persistProgress();
    this.clearSave();
    this.saveNow();
    audio.sfx('start');
    return true;
  }

  toMenu() {
    if (this.phase === 'playing' || this.phase === 'paused') this.saveNow();
    this.reset();
    this.phase = 'menu';
    this.menuNotice = null;
  }

  togglePause() {
    if (this.overlay) {
      this.closeOverlay();
      return;
    }
    if (this.confirmBack) {
      this.confirmBack = false;
      return;
    }
    if (this.phase === 'playing') {
      this.phase = 'paused';
      this.menu = null;
      this.shovel = false;
      this.overlay = null;
      this.overlayFrom = null;
      this.selected = -1;
      this.saveNow();
    } else if (this.phase === 'paused') {
      this.phase = 'playing';
    }
  }

  cancelSelection() {
    if (this.confirmNew) {
      this.confirmNew = false;
      return;
    }
    if (this.confirmBack) {
      this.confirmBack = false;
      return;
    }
    if (this.overlay === 'prep') {
      if (this.prep && !this.prep.cinemaDone) this.skipPrepCinematic();
      else if (this.prep?.warning) this.prep.warning = null;
      else this.closeOverlay();
      return;
    }
    if (this.overlay === 'almanac') {
      this.closeAlmanac();
      return;
    }
    if (this.overlay) {
      this.overlay = null;
      this.overlayFrom = null;
      return;
    }
    if (this.menu) {
      this.menu = null;
      return;
    }
    this.shovel = false;
    this.selected = -1;
  }

  openSettings(from) {
    this.overlay = 'settings';
    this.overlayFrom = from;
    this.menu = null;
    this.shovel = false;
    this.selected = -1;
    this.confirmBack = false;
    this.confirmNew = false;
  }

  closeOverlay() {
    this.overlay = null;
    this.overlayFrom = null;
  }

  persistProgress() {
    this.progress.selected = this.selectedLevel;
    storage.saveProgress(this.progress);
  }

  selectLevel(id) {
    const level = getLevel(id);
    this.selectedLevel = level.id;
    this.progress.selected = level.id;
    storage.saveProgress(this.progress);
  }

  openLevels() {
    if (this.phase !== 'menu') return;
    if (this.overlay || this.confirmBack || this.confirmNew) return;
    this.overlay = 'levels';
    this.overlayFrom = 'menu';
    this.menuNotice = null;
  }

  handleLevelsClick(x, y) {
    if (inRect(x, y, LEVELS_UI.back) || !inRect(x, y, LEVELS_UI.panel)) {
      this.closeOverlay();
      return;
    }
    for (let i = 0; i < LEVELS.length; i++) {
      if (inRect(x, y, levelCardRect(i))) {
        this.selectLevel(LEVELS[i].id);
        this.openPrep(LEVELS[i].id);
        return;
      }
    }
  }

  levelZombieInfo(level) {
    const map = new Map();
    for (let wi = 0; wi < level.waves.length; wi++) {
      for (const [type, count] of level.waves[wi].groups) {
        if (!ZOMBIE_TYPES[type]) continue;
        const entry = map.get(type) || { type, firstWave: wi + 1, base: 0 };
        entry.base += count;
        map.set(type, entry);
      }
    }
    return [...map.values()];
  }

  openPrep(levelId = this.selectedLevel) {
    if (this.confirmBack || this.confirmNew) return;
    const level = getLevel(levelId);
    this.phase = 'menu';
    this.level = level;
    this.selectedLevel = level.id;
    this.levelThreat = level.threat;
    this.levelCountMul = Math.sqrt(level.threat);
    this.levelHpMul = Math.sqrt(level.threat);
    this.progress.selected = level.id;
    storage.saveProgress(this.progress);
    this.overlay = 'prep';
    this.overlayFrom = null;
    this.menu = null;
    this.shovel = false;
    this.selected = -1;
    this.almanacReturn = null;
    this.menuNotice = null;
    this.prep = {
      levelId: level.id,
      selected: cleanLoadout(this.loadout),
      zombies: this.levelZombieInfo(level),
      warning: null,
      cinemaT: 0,
      cinemaDone: false,
      guard: 0
    };
    audio.sfx('cinemaStart');
  }

  skipPrepCinematic() {
    if (!this.prep || this.prep.cinemaDone) return;
    this.prep.cinemaT = PREP_CINEMA.total;
    this.prep.cinemaDone = true;
    this.prep.guard = 0.3;
  }

  syncPrepLoadout() {
    if (!this.prep) return;
    const ids = cleanLoadout(this.prep.selected);
    this.prep.selected = ids;
    if (ids.length) {
      this.loadout = [...ids];
      storage.saveLoadout(ids);
    }
  }

  togglePrepPlant(id) {
    if (!this.prep || !PLANT_TYPES[id]) return;
    const selected = this.prep.selected;
    const at = selected.indexOf(id);
    if (at >= 0) selected.splice(at, 1);
    else if (selected.length < MAX_LOADOUT) selected.push(id);
    this.syncPrepLoadout();
    this.prep.warning = null;
  }

  confirmPrep() {
    if (!this.prep) return;
    if (!this.prep.cinemaDone) {
      this.skipPrepCinematic();
      return;
    }
    if (this.prep.guard > 0) return;
    const ids = cleanLoadout(this.prep.selected);
    this.prep.selected = ids;
    if (!ids.length) {
      this.prep.warning = 'empty';
      this.prep.warningT = 0;
      audio.sfx('alert');
      return;
    }
    this.loadout = [...ids];
    storage.saveLoadout(ids);
    if (!ids.some((id) => PLANT_TYPES[id]?.produce)) {
      this.prep.warning = 'noProducer';
      audio.sfx('alert');
      return;
    }
    this.startRun(this.prep.levelId, ids);
  }

  dismissPrepWarning() {
    if (!this.prep) return;
    this.prep.warning = null;
    this.prep.warningT = 0;
  }

  prepEntryAt(x, y) {
    if (!this.prep) return null;
    for (let i = 0; i < MAX_LOADOUT; i++) {
      const id = this.prep.selected[i];
      if (id && inRect(x, y, prepSlotRect(i))) {
        return { tab: 'plant', id };
      }
    }
    for (let i = 0; i < PLANT_ORDER.length; i++) {
      if (inRect(x, y, prepRosterRect(i))) {
        return { tab: 'plant', id: PLANT_ORDER[i] };
      }
    }
    for (let i = 0; i < this.prep.zombies.length; i++) {
      if (inRect(x, y, prepZombieRect(i))) {
        return { tab: 'zombie', id: this.prep.zombies[i].type };
      }
    }
    return null;
  }

  handlePrepClick(x, y, button) {
    if (!this.prep) return;
    const prep = this.prep;
    if (prep.warning) {
      if (prep.warning === 'noProducer') {
        if (inRect(x, y, PREP.warningYes)) {
          const ids = [...prep.selected];
          this.startRun(prep.levelId, ids);
        } else if (inRect(x, y, PREP.warningNo)) {
          prep.warning = null;
        }
      } else {
        this.dismissPrepWarning();
      }
      return;
    }
    if (button === 2) {
      const hit = this.prepEntryAt(x, y);
      if (!hit) return;
      const entries = almanacEntries(hit.tab);
      const index = entries.findIndex((entry) => entry.type === hit.id);
      if (index >= 0) this.openAlmanacAt(hit.tab, index, 'prep');
      return;
    }
    if (inRect(x, y, PREP.back) || !inRect(x, y, PREP.panel)) {
      this.closeOverlay();
      return;
    }
    if (inRect(x, y, PREP.confirm)) {
      this.confirmPrep();
      return;
    }
    for (let i = 0; i < MAX_LOADOUT; i++) {
      if (prep.selected[i] && inRect(x, y, prepSlotRect(i))) {
        prep.selected.splice(i, 1);
        this.syncPrepLoadout();
        return;
      }
    }
    for (let i = 0; i < PLANT_ORDER.length; i++) {
      if (inRect(x, y, prepRosterRect(i))) {
        this.togglePrepPlant(PLANT_ORDER[i]);
        return;
      }
    }
  }

  openAlmanacAt(tab, index, returnTo = null) {
    const key = tab === 'zombie' ? 'zombie' : 'plant';
    const entries = almanacEntries(key);
    if (!entries.length) return;
    this.overlay = 'almanac';
    this.overlayFrom = null;
    this.almanacReturn = returnTo;
    this.almanacTab = key;
    this.almanacIndex = Math.max(0, Math.min(entries.length - 1, index));
    this.almanacScroll = 0;
    this.menu = null;
    this.shovel = false;
    this.selected = -1;
  }

  closeAlmanac() {
    const back = this.almanacReturn;
    this.almanacReturn = null;
    if (back === 'prep' && this.prep) {
      this.overlay = 'prep';
      this.overlayFrom = null;
    } else {
      this.overlay = null;
      this.overlayFrom = null;
    }
  }

  openAlmanac() {
    if (this.overlay === 'almanac') return;
    if (this.overlay === 'settings' || this.overlay === 'cheat' || this.overlay === 'levels' || this.overlay === 'prep') return;
    if (this.confirmBack || this.confirmNew) return;
    if (this.phase === 'playing') this.togglePause();
    if (this.phase !== 'menu' && this.phase !== 'paused') return;
    this.overlay = 'almanac';
    this.overlayFrom = this.phase === 'menu' ? 'menu' : 'pause';
    this.almanacReturn = null;
    this.menu = null;
    this.shovel = false;
    this.selected = -1;
    const entries = almanacEntries(this.almanacTab);
    if (this.almanacIndex < 0 || this.almanacIndex >= entries.length) {
      this.almanacIndex = 0;
    }
    this.almanacScroll = 0;
  }

  scrollAlmanac(delta) {
    if (this.overlay !== 'almanac') return;
    const max = Math.max(0, this.almanacMaxScroll);
    this.almanacScroll = Math.max(0, Math.min(max, this.almanacScroll + delta));
  }

  handleAlmanacClick(x, y) {
    if (inRect(x, y, ALMANAC.close) || !inRect(x, y, ALMANAC.book)) {
      this.closeAlmanac();
      return;
    }
    for (const tab of ALMANAC.tabs) {
      if (inRect(x, y, tab.rect)) {
        this.almanacTab = tab.key;
        this.almanacIndex = 0;
        this.almanacScroll = 0;
        return;
      }
    }
    const entries = almanacEntries(this.almanacTab);
    for (let i = 0; i < entries.length; i++) {
      if (inRect(x, y, almanacEntryRect(i))) {
        this.almanacIndex = i;
        this.almanacScroll = 0;
        return;
      }
    }
    if (this.almanacMaxScroll > 0 && inRect(x, y, ALMANAC.scrollbar)) {
      const s = ALMANAC.scrollbar;
      const ratio = Math.max(0, Math.min(1, (y - s.y) / s.h));
      this.almanacScroll = Math.floor(this.almanacMaxScroll * ratio);
    }
  }

  menuPrimary() {
    if (this.phase !== 'menu' || this.overlay || this.confirmNew || this.confirmBack) return;
    if (this.hasSave) this.continueRun();
    else this.openPrep(this.selectedLevel);
  }

  isRunShape(run) {
    return !!(
      run &&
      typeof run === 'object' &&
      Array.isArray(run.plants) &&
      Array.isArray(run.zombies) &&
      Array.isArray(run.cards) &&
      Array.isArray(run.mowers) &&
      Array.isArray(run.spawnQueue)
    );
  }

  makeSaveMeta(payload) {
    const run = payload.run;
    const level = getLevel(Math.floor(Number(run.levelId) || 1));
    const total = level.waves.length;
    return {
      wave: Math.max(0, Math.min(total, Math.floor(Number(run.waveIndex) || 0))),
      total,
      levelId: level.id,
      levelName: level.name,
      levelTag: level.tag,
      threat: level.threat,
      sun: Math.max(0, Math.round(Number(run.sun) || 0)),
      time: Math.max(0, Number(run.time) || 0),
      difficulty: ['easy', 'normal', 'hard'].includes(run.runDifficulty)
        ? run.runDifficulty
        : 'easy',
      cheats: !!run.runCheats,
      savedAt: payload.savedAt || null
    };
  }

  refreshSaveInfo() {
    const payload = storage.loadSave();
    if (payload && this.isRunShape(payload.run)) {
      this.hasSave = true;
      this.saveMeta = this.makeSaveMeta(payload);
    } else {
      this.hasSave = false;
      this.saveMeta = null;
      if (payload) {
        storage.clearSave();
        this.menuNotice = '存档不可用，已清除';
      }
    }
  }

  saveNow() {
    storage.saveSettings(this.settings);
    if (this.phase !== 'playing' && this.phase !== 'paused') return;
    const payload = storage.saveRun(this.serializeRun());
    if (payload) {
      this.hasSave = true;
      this.saveMeta = this.makeSaveMeta(payload);
    }
  }

  clearSave() {
    storage.clearSave();
    this.hasSave = false;
    this.saveMeta = null;
  }

  continueRun() {
    if (this.phase !== 'menu') return;
    const payload = storage.loadSave();
    if (!payload || !this.loadRun(payload.run)) {
      storage.clearSave();
      this.hasSave = false;
      this.saveMeta = null;
      this.menuNotice = '存档不可用，已清除';
      return;
    }
    this.hasSave = true;
    this.saveMeta = this.makeSaveMeta(payload);
    this.menuNotice = null;
  }

  updateRecords(won) {
    if (this.runCheats) return;
    const r = this.records;
    r.bestWave = Math.max(r.bestWave, Math.min(this.waveIndex, this.waveTotal));
    r.bestKills = Math.max(r.bestKills, this.kills);
    if (won) {
      r.wins = (r.wins || 0) + 1;
      if (r.bestWinTime == null || this.time < r.bestWinTime) {
        r.bestWinTime = this.time;
      }
      if (!this.progress.cleared.includes(this.runLevelId)) {
        this.progress.cleared.push(this.runLevelId);
      }
      this.progress.selected = this.runLevelId;
      storage.saveProgress(this.progress);
    }
    storage.saveRecords(r);
  }

  serializeRun() {
    const num = (v) => (Number.isFinite(v) ? v : 0);
    return {
      levelId: this.runLevelId,
      time: num(this.time),
      sun: Math.max(0, Math.round(num(this.sun))),
      kills: Math.max(0, Math.floor(num(this.kills))),
      waveIndex: Math.max(0, Math.min(this.waveIndex, this.level.waves.length)),
      naturalTimer: num(this.naturalTimer),
      runDifficulty: this.runDifficulty,
      runCheats: !!this.runCheats,
      cards: this.cards.map((c) => ({ id: c.id, cd: num(c.cd) })),
      plants: this.plants.filter((p) => !p.dead).map((p) => ({
        type: p.type,
        c: p.c,
        r: p.r,
        hp: num(p.hp),
        maxHp: num(p.maxHp),
        timer: num(p.timer),
        phase: num(p.phase),
        upgrades: { ...p.upgrades },
        adjFlip: num(p.adjFlip)
      })),
      zombies: this.zombies.filter((z) => !z.dead).map((z) => ({
        type: z.type,
        row: z.row,
        x: num(z.x),
        hp: num(z.hp),
        shell: num(z.shell),
        maxHp: num(z.maxHp),
        maxShell: num(z.maxShell),
        slowT: num(z.slowT),
        slowFactor: num(z.slowFactor),
        stunT: num(z.stunT),
        rageT: num(z.rageT),
        rageMult: num(z.rageMult, 1),
        auraT: num(z.auraT),
        breached: !!z.breached
      })),
      projectiles: this.projectiles.filter((p) => !p.dead).map((p) => ({
        x: num(p.x),
        y: num(p.y),
        row: p.row,
        speed: num(p.speed),
        damage: num(p.damage),
        big: !!p.big,
        slow: num(p.slow)
      })),
      orbs: this.orbs.filter((o) => !o.dead).map((o) => ({
        x: num(o.x),
        y: num(o.y),
        targetY: num(o.targetY),
        landed: !!o.landed,
        life: num(o.life),
        value: num(o.value),
        phase: num(o.phase),
        autoT: num(o.autoT)
      })),
      mowers: this.mowers.map((m) => ({
        row: m.row,
        ready: !!m.ready,
        active: !!m.active,
        x: num(m.x)
      })),
      spawnQueue: this.spawnQueue.map((e) => ({
        t: num(e.t),
        type: e.type,
        row: e.row
      }))
    };
  }

  loadRun(run) {
    if (!this.isRunShape(run)) return false;
    const num = (v, d = 0) => (Number.isFinite(v) ? v : d);
    const level = getLevel(Math.floor(num(run.levelId, 1)));
    this.level = level;
    this.runLevelId = level.id;
    this.selectedLevel = level.id;
    this.levelThreat = level.threat;
    this.levelCountMul = Math.sqrt(level.threat);
    this.levelHpMul = Math.sqrt(level.threat);

    this.reset();
    this.runDifficulty = ['easy', 'normal', 'hard'].includes(run.runDifficulty)
      ? run.runDifficulty
      : 'easy';
    this.runCheats = !!run.runCheats;
    this.time = Math.max(0, num(run.time));
    this.sun = Math.max(0, Math.round(num(run.sun, level.startSun)));
    this.kills = Math.max(0, Math.floor(num(run.kills)));
    this.waveIndex = Math.max(0, Math.min(Math.floor(num(run.waveIndex)), level.waves.length));
    this.naturalTimer = num(run.naturalTimer, 3);

    const savedCards = [];
    const cardSeen = new Set();
    for (const raw of run.cards) {
      if (!raw || typeof raw !== 'object') continue;
      const def = PLANT_TYPES[raw.id];
      if (!def || cardSeen.has(raw.id)) continue;
      cardSeen.add(raw.id);
      savedCards.push({
        id: raw.id,
        def,
        cd: Math.max(0, Math.min(def.cooldown, num(raw.cd)))
      });
      if (savedCards.length >= MAX_LOADOUT) break;
    }
    if (savedCards.length) {
      this.cards = savedCards;
    } else {
      const ids = cleanLoadout(this.loadout);
      const fallback = ids.length ? ids : [...PLANT_ORDER];
      this.cards = fallback.map((id) => ({ id, def: PLANT_TYPES[id], cd: 0 }));
    }
    if (this.cards.length) {
      this.loadout = this.cards.map((card) => card.id);
      storage.saveLoadout(this.loadout);
    }

    const seen = new Set();
    for (const raw of run.plants) {
      if (!raw || typeof raw !== 'object' || !PLANT_TYPES[raw.type]) continue;
      const c = Math.floor(num(raw.c, -1));
      const r = Math.floor(num(raw.r, -1));
      if (c < 0 || c >= BOARD.cols || r < 0 || r >= BOARD.rows) continue;
      const key = r + ',' + c;
      if (seen.has(key)) continue;
      const def = PLANT_TYPES[raw.type];
      const pos = cellCenter(c, r);
      const maxCap = raw.type === 'wall' ? 7500 : def.hp;
      const maxHp = Math.max(1, Math.min(maxCap, num(raw.maxHp, def.hp)));
      const p = {
        def, type: raw.type, c, r, x: pos.x, y: pos.y,
        hp: Math.max(1, Math.min(maxHp, num(raw.hp, maxHp))),
        maxHp,
        timer: Math.max(0, num(raw.timer)),
        phase: num(raw.phase),
        recoil: 0,
        pulse: 0,
        charge: 0,
        biteT: 0,
        dead: false,
        upgrades: initUpgrades(),
        adjFlip: Math.max(0, Math.floor(num(raw.adjFlip)))
      };
      if (raw.upgrades && typeof raw.upgrades === 'object') {
        for (const k of [1, 2, 3]) {
          p.upgrades[k] = Math.max(0, Math.min(3, Math.floor(num(raw.upgrades[k]))));
        }
      }
      this.plants.push(p);
      this.cells[r][c] = p;
      seen.add(key);
    }

    for (const raw of run.zombies) {
      if (!raw || typeof raw !== 'object' || !ZOMBIE_TYPES[raw.type]) continue;
      if (!(num(raw.hp, 1) > 0)) continue;
      const row = Math.floor(num(raw.row, -1));
      if (row < 0 || row >= BOARD.rows) continue;
      const def = ZOMBIE_TYPES[raw.type];
      const maxHp = Math.max(1, Math.round(num(raw.maxHp, def.hp + def.shell)));
      const hp = Math.max(1, Math.min(maxHp, Math.round(num(raw.hp, maxHp))));
      const shell = Math.max(0, Math.min(Math.max(0, maxHp - hp), Math.round(num(raw.shell))));
      this.zombies.push({
        def,
        type: raw.type,
        row,
        x: Math.max(-240, num(raw.x, 1300)),
        y: ROW_Y[row] + 6,
        hp,
        shell,
        maxHp,
        maxShell: Math.max(0, num(raw.maxShell, shell)),
        speed: def.speed,
        slowT: Math.max(0, num(raw.slowT)),
        slowFactor: Math.max(0.2, Math.min(1, num(raw.slowFactor, 0.5))),
        stunT: Math.max(0, num(raw.stunT)),
        rageT: Math.max(0, num(raw.rageT)),
        rageMult: Math.max(1, num(raw.rageMult, 1)),
        auraT: def.aura ? Math.max(0, num(raw.auraT, def.aura.interval)) : 0,
        auraPulse: 0,
        hurt: 0,
        eating: false,
        chomp: 0,
        anim: Math.random() * Math.PI * 2,
        phase: Math.random() * Math.PI * 2,
        breached: !!raw.breached,
        dead: false
      });
    }

    for (const raw of run.projectiles || []) {
      if (!raw || typeof raw !== 'object') continue;
      const row = Math.floor(num(raw.row, -1));
      if (row < 0 || row >= BOARD.rows) continue;
      this.projectiles.push({
        x: num(raw.x),
        y: num(raw.y),
        row,
        speed: Math.max(100, num(raw.speed, 520)),
        damage: Math.max(1, num(raw.damage, 20)),
        big: !!raw.big,
        slow: Math.max(0, num(raw.slow)),
        dead: false
      });
    }

    for (const raw of run.orbs || []) {
      if (!raw || typeof raw !== 'object') continue;
      const y = num(raw.y);
      this.orbs.push({
        x: num(raw.x),
        y,
        targetY: num(raw.targetY, y),
        landed: !!raw.landed,
        life: Math.max(0, num(raw.life, 9)),
        value: Math.max(0, num(raw.value, 25)),
        phase: num(raw.phase),
        autoT: num(raw.autoT),
        dead: false
      });
    }

    const mowerMap = new Map();
    for (const raw of run.mowers) {
      if (!raw || typeof raw !== 'object') continue;
      mowerMap.set(Math.floor(num(raw.row, -1)), raw);
    }
    for (const m of this.mowers) {
      const raw = mowerMap.get(m.row);
      if (!raw) continue;
      m.ready = !!raw.ready;
      m.active = !!raw.active;
      m.x = num(raw.x, BOARD.x - 32);
    }

    this.spawnQueue = (run.spawnQueue || [])
      .filter((e) => e && typeof e === 'object' && ZOMBIE_TYPES[e.type])
      .map((e) => ({
        t: num(e.t),
        type: e.type,
        row: Math.max(0, Math.min(BOARD.rows - 1, Math.floor(num(e.row))))
      }));

    this.phase = 'paused';
    this.menu = null;
    this.selected = -1;
    this.shovel = false;
    this.overlay = null;
    this.overlayFrom = null;
    this.confirmBack = false;
    this.confirmNew = false;
    this.banner = { text: '已读取存档 · 继续守夜', t: 2.4, max: 2.4 };
    this.progress.selected = this.runLevelId;
    storage.saveProgress(this.progress);
    return true;
  }

  update(dt, input) {
    this.mouse = { x: input.x, y: input.y };
    this.hover = cellAt(input.x, input.y);
    for (const click of input.clicks) this.handleClick(click);
    input.clicks.length = 0;

    if (this.overlay === 'prep' && this.prep && !this.prep.cinemaDone) {
      const before = this.prep.cinemaT;
      this.prep.cinemaT = Math.min(PREP_CINEMA.total, this.prep.cinemaT + dt);
      if (before < PREP_CINEMA.revealStart && this.prep.cinemaT >= PREP_CINEMA.revealStart) {
        audio.sfx('reveal');
      }
      if (this.prep.cinemaT >= PREP_CINEMA.total) {
        this.prep.cinemaDone = true;
        this.prep.guard = 0;
      }
    }
    if (this.overlay === 'prep' && this.prep && this.prep.guard > 0) {
      this.prep.guard = Math.max(0, this.prep.guard - dt);
    }
    if (
      this.overlay === 'prep' && this.prep && this.prep.cinemaDone &&
      this.prep.warning === 'empty'
    ) {
      this.prep.warningT = (this.prep.warningT ?? 0) + dt;
      if (this.prep.warningT >= 2.4) this.dismissPrepWarning();
    }

    if (this.phase !== 'playing') return;
    if (this.overlay === 'cheat') return;

    this.time += dt;
    if (this.shake > 0) this.shake = Math.max(0, this.shake - dt * 34);
    for (const card of this.cards) {
      if (card.cd > 0) card.cd = Math.max(0, card.cd - dt);
    }
    if (this.banner) {
      this.banner.t -= dt;
      if (this.banner.t <= 0) this.banner = null;
    }

    this.updateEconomy(dt);
    this.updateWaves();
    this.updatePlants(dt);
    this.updateZombies(dt);
    this.updateProjectiles(dt);
    this.updateMowers(dt);
    this.updateOrbs(dt);
    this.updateParticles(dt);
    this.updateFloaters(dt);
    this.flushPendingSpawns();
    this.cleanup();

    if (this.menu && this.menu.plant.dead) this.menu = null;

    if (
      this.phase === 'playing' &&
      this.waveIndex >= this.level.waves.length &&
      this.spawnQueue.length === 0 &&
      this.zombies.length === 0
    ) {
      this.win();
    }
  }

  handleClick(click) {
    const { x, y, button } = click;
    if (this.overlay === 'prep' && this.prep && !this.prep.cinemaDone) {
      audio.sfx('click');
      this.skipPrepCinematic();
      return;
    }
    if (this.overlay === 'prep' && this.prep && this.prep.guard > 0) return;
    if (button === 2) {
      if (this.overlay === 'prep') {
        this.handlePrepClick(x, y, 2);
        return;
      }
      if (this.overlay === 'almanac') {
        this.closeAlmanac();
        return;
      }
      this.overlay = null;
      this.overlayFrom = null;
      this.menu = null;
      this.shovel = false;
      this.selected = -1;
      this.confirmBack = false;
      this.confirmNew = false;
      return;
    }

    if (this.phase !== 'playing' || this.overlay) audio.sfx('click');

    if (this.overlay === 'prep') {
      this.handlePrepClick(x, y, button);
      return;
    }
    if (this.overlay === 'settings') {
      this.handleSettingsClick(x, y);
      return;
    }
    if (this.overlay === 'cheat') {
      this.handleCheatClick(x, y);
      return;
    }
    if (this.overlay === 'almanac') {
      this.handleAlmanacClick(x, y);
      return;
    }
    if (this.overlay === 'levels') {
      this.handleLevelsClick(x, y);
      return;
    }

    if (this.confirmNew) {
      if (inRect(x, y, BTN.confirmYes)) {
        this.confirmNew = false;
        this.openPrep(this.selectedLevel);
      } else {
        this.confirmNew = false;
      }
      return;
    }

    if (this.confirmBack) {
      if (inRect(x, y, BTN.confirmYes)) {
        this.confirmBack = false;
        this.toMenu();
      } else {
        this.confirmBack = false;
      }
      return;
    }

    if (this.phase === 'menu') {
      if (inRect(x, y, BTN.levelsMenu)) {
        this.openLevels();
        return;
      }
      if (inRect(x, y, BTN.almanacMenu)) {
        this.openAlmanac();
        return;
      }
      if (this.hasSave) {
        if (inRect(x, y, BTN.start)) this.continueRun();
        else if (inRect(x, y, BTN.newRun)) this.confirmNew = true;
        else if (inRect(x, y, BTN.settingsMenuWide)) this.openSettings('menu');
      } else if (inRect(x, y, BTN.start)) {
        this.openPrep(this.selectedLevel);
      } else if (inRect(x, y, BTN.settingsMenu)) {
        this.openSettings('menu');
      }
      return;
    }

    if (this.phase === 'won' || this.phase === 'lost') {
      if (inRect(x, y, BTN.overlay)) this.openPrep(this.runLevelId);
      else if (inRect(x, y, BTN.toMenu)) this.toMenu();
      return;
    }

    if (this.phase === 'paused') {
      if (inRect(x, y, BTN.resume)) this.phase = 'playing';
      else if (inRect(x, y, BTN.pauseSettings)) this.openSettings('pause');
      else if (inRect(x, y, BTN.restart)) this.openPrep(this.runLevelId);
      else if (inRect(x, y, BTN.backMenu)) this.confirmBack = true;
      else if (inRect(x, y, BTN.pauseAlmanac)) this.openAlmanac();
      return;
    }

    if (inRect(x, y, BTN.pause)) {
      audio.sfx('click');
      this.togglePause();
      return;
    }

    if (inRect(x, y, BTN.shovel)) {
      audio.sfx('click');
      this.shovel = !this.shovel;
      this.selected = -1;
      this.menu = null;
      return;
    }

    if (this.settings.quickWave && inRect(x, y, BTN.quickWave)) {
      audio.sfx('click');
      this.summonNextWave();
      return;
    }

    if (this.runCheats && inRect(x, y, BTN.cheat)) {
      audio.sfx('click');
      this.overlay = 'cheat';
      this.overlayFrom = null;
      this.menu = null;
      this.shovel = false;
      this.selected = -1;
      return;
    }

    if (this.menu) {
      const plant = this.menu.plant;
      if (!plant || plant.dead) {
        this.menu = null;
      } else {
        const petal = petalAt(plant, x, y);
        if (petal) {
          this.tryUpgrade(petal.path.id);
          return;
        }
        this.menu = null;
        const onCard = this.cards.some((_, i) => inRect(x, y, cardRect(i, this.cards.length)));
        if (!onCard) return;
      }
    }

    for (let i = 0; i < this.cards.length; i++) {
      if (inRect(x, y, cardRect(i, this.cards.length))) {
        audio.sfx('click');
        this.selected = this.selected === i ? -1 : i;
        this.shovel = false;
        return;
      }
    }

    const orb = this.pickOrb(x, y);
    if (orb) {
      this.collectOrb(orb);
      return;
    }

    if (this.shovel) {
      const cell = cellAt(x, y);
      if (cell) {
        const plant = this.cells[cell.r][cell.c];
        if (plant) this.killPlant(plant, true);
      }
      this.shovel = false;
      return;
    }

    if (this.selected >= 0) {
      const cell = cellAt(x, y);
      if (!cell) {
        this.selected = -1;
        return;
      }
      this.tryPlace(this.selected, cell.c, cell.r);
      return;
    }

    const cell = cellAt(x, y);
    if (cell) {
      const plant = this.cells[cell.r][cell.c];
      if (plant) {
        audio.sfx('click');
        if (pathsFor(plant).length > 0) this.menu = { plant };
        else if (plant.type === 'bomb') this.deny('爆竹是一次性的，无法升阶');
        else this.deny('此物无法升阶');
      }
    }
  }

  handleSettingsClick(x, y) {
    if (inRect(x, y, SETTINGS.back)) {
      this.closeOverlay();
      return;
    }

    for (const row of SETTINGS.rows) {
      for (let i = 0; i < row.options.length; i++) {
        const pill = settingsPill(row, i);
        if (!inRect(x, y, pill)) continue;
        const enabled =
          settingsRowEnabled(row, this.overlayFrom === 'menu') &&
          (!row.requires || !!this.settings[row.requires]);
        if (enabled) {
          this.settings[row.key] = pill.option.value;
          storage.saveSettings(this.settings);
          if (row.key === 'sound') audio.setMuted(!pill.option.value);
        }
        return;
      }
    }

    if (!inRect(x, y, SETTINGS.panel)) this.closeOverlay();
  }

  handleCheatClick(x, y) {
    if (!inRect(x, y, BTN.cheatPanel)) {
      this.closeOverlay();
      return;
    }
    if (inRect(x, y, BTN.cheatAdd)) {
      this.sun += 500;
      this.floaters.push({
        x: 640, y: 300, text: '+500 香火',
        color: '#ffe1a1', life: 1.6, maxLife: 1.6, size: 22
      });
      this.spark(640, 310, '#ffd98a', 12);
      return;
    }
    if (inRect(x, y, BTN.cheatKill)) {
      for (const z of this.zombies) {
        if (!z.dead && z.x <= VIEW.w + 10) this.killZombie(z);
      }
      this.cleanup();
      this.shake = Math.max(this.shake, 8);
      return;
    }
    if (inRect(x, y, BTN.cheatMowers)) {
      for (const m of this.mowers) {
        m.ready = true;
        m.active = false;
        m.x = BOARD.x - 32;
      }
      this.floaters.push({
        x: 640, y: 300, text: '门神归位',
        color: '#ffe1a1', life: 1.4, maxLife: 1.4, size: 20
      });
      return;
    }
    if (inRect(x, y, BTN.cheatWin)) {
      this.win();
    }
  }

  tryPlace(index, c, r) {
    const card = this.cards[index];
    if (!card) return;
    if (card.cd > 0) return this.deny('还没缓过手来');
    if (this.sun < card.def.cost) return this.deny('香火不够');
    if (this.cells[r][c]) return this.deny('这里已经摆了东西');
    this.sun -= card.def.cost;
    card.cd = card.def.cooldown;
    this.placeFree(card.id, c, r);
    this.selected = -1;
    audio.sfx('place');
  }

  deny(text) {
    this.floaters.push({
      x: this.mouse.x, y: this.mouse.y - 10, text,
      color: '#ff9d7a', life: 1.1, maxLife: 1.1, size: 16
    });
    audio.sfx('deny');
  }

  tryUpgrade(pathId) {
    const plant = this.menu ? this.menu.plant : null;
    if (!plant || plant.dead) {
      this.menu = null;
      return;
    }
    const st = pathStatus(plant, pathId);
    if (!st.ok) {
      this.deny(st.reason);
      return;
    }
    if (this.sun < st.cost) {
      this.deny('香火不够');
      return;
    }
    this.sun -= st.cost;
    plant.upgrades[pathId] = st.nextTier;

    if (plant.type === 'wall' && pathId === 1) {
      const nextMax = PLANT_EFFECTS.wall.hp[st.nextTier];
      plant.hp += nextMax - plant.maxHp;
      plant.maxHp = nextMax;
    }

    this.floaters.push({
      x: plant.x, y: plant.y - 66,
      text: `${pathId}-${st.nextTier} ${st.name}`,
      color: '#ffe1a1', life: 1.4, maxLife: 1.4, size: 18
    });
    this.spark(plant.x, plant.y - 18, st.path.color, 12);
    this.shake = Math.max(this.shake, 3);
    audio.sfx('upgrade');
  }

  placeFree(type, c, r) {
    if (c < 0 || c >= BOARD.cols || r < 0 || r >= BOARD.rows) return null;
    if (this.cells[r][c]) return null;
    const def = PLANT_TYPES[type];
    if (!def) return null;
    const pos = cellCenter(c, r);
    const p = {
      def, type, c, r, x: pos.x, y: pos.y,
      hp: def.hp, maxHp: def.hp, timer: 0,
      phase: Math.random() * Math.PI * 2,
      recoil: 0, pulse: 0, charge: 0, biteT: 0, dead: false,
      upgrades: initUpgrades(),
      adjFlip: 0
    };
    if (def.produce) p.timer = def.produce.interval - def.produce.first;
    else if (def.shot) p.timer = def.shot.interval;
    if (type === 'wall') {
      p.maxHp = PLANT_EFFECTS.wall.hp[tierOf(p, 1)];
      p.hp = p.maxHp;
    }
    this.plants.push(p);
    this.cells[r][c] = p;
    return p;
  }

  pickOrb(x, y) {
    let best = null;
    let bestD = 44;
    for (const o of this.orbs) {
      if (o.dead) continue;
      const d = Math.hypot(o.x - x, o.y - y);
      if (d < bestD) {
        bestD = d;
        best = o;
      }
    }
    return best;
  }

  collectOrb(orb) {
    if (!orb || orb.dead) return;
    orb.dead = true;
    this.sun += orb.value;
    this.floaters.push({
      x: orb.x, y: orb.y - 12, text: '+' + orb.value,
      color: '#ffd98a', life: 0.9, maxLife: 0.9, size: 18
    });
    this.spark(orb.x, orb.y, '#ffcf7a', 6);
    audio.sfx('collect');
  }

  updateEconomy(dt) {
    this.naturalTimer -= dt;
    if (this.naturalTimer <= 0) {
      this.naturalTimer = 8 + Math.random() * 2;
      this.orbs.push({
        x: BOARD.x + 50 + Math.random() * (BOARD_W - 100),
        y: -24,
        targetY: BOARD.y + 70 + Math.random() * (BOARD.ch * BOARD.rows - 120),
        landed: false,
        life: 10,
        value: 25,
        phase: Math.random() * Math.PI * 2
      });
    }
  }

  difficultyMults() {
    return DIFFICULTY_MULT[this.runDifficulty] || DIFFICULTY_MULT.easy;
  }

  queueWave(wave) {
    audio.sfx(wave.flag ? 'alert' : 'wave');
    const diff = this.difficultyMults();
    const mult = this.levelCountMul * diff.count;
    let k = 0;
    for (const [type, count] of wave.groups) {
      const n = Math.max(1, Math.round(count * mult));
      for (let i = 0; i < n; i++) {
        this.spawnQueue.push({
          t: this.time + k * 0.38 + Math.random() * 0.25,
          type,
          row: Math.floor(Math.random() * BOARD.rows)
        });
        k += 1;
      }
    }
    if (wave.flag) {
      this.banner = { text: '一大波恶客正在靠近', t: 3.4, max: 3.4 };
      this.shake = Math.max(this.shake, 5);
    }
  }

  updateWaves() {
    const waves = this.level.waves;
    while (this.waveIndex < waves.length && this.time >= waves[this.waveIndex].t) {
      const wave = waves[this.waveIndex];
      this.waveIndex += 1;
      this.queueWave(wave);
    }
    for (const e of this.spawnQueue) {
      if (this.time >= e.t) this.spawnZombie(e.type, e.row);
    }
    this.spawnQueue = this.spawnQueue.filter((e) => this.time < e.t);
  }

  summonNextWave() {
    if (this.phase !== 'playing') return;
    const waves = this.level.waves;
    if (this.waveIndex >= waves.length) {
      this.floaters.push({
        x: this.mouse.x, y: this.mouse.y - 10, text: '已无后续波次',
        color: '#ff9d7a', life: 1.1, maxLife: 1.1, size: 16
      });
      return;
    }
    const wave = waves[this.waveIndex];
    this.waveIndex += 1;
    this.queueWave(wave);
    this.shake = Math.max(this.shake, 4);
  }

  spawnZombie(type, row, opts = {}) {
    const def = ZOMBIE_TYPES[type];
    if (!def) return null;
    const diff = this.difficultyMults();
    const hpMul = this.levelHpMul * diff.hp;
    const hpFactor = Number.isFinite(opts.hpFactor) ? opts.hpFactor : 1;
    const hp = Math.max(1, Math.round(def.hp * hpMul * hpFactor));
    const shell = Math.max(0, Math.round(def.shell * hpMul));
    const z = {
      def, type, row,
      x: Number.isFinite(opts.x) ? opts.x : 1290 + Math.random() * 90,
      y: ROW_Y[row] + 6,
      hp,
      shell,
      maxHp: hp + shell,
      maxShell: shell,
      speed: def.speed,
      slowT: 0,
      slowFactor: 0.5,
      stunT: 0,
      rageT: 0,
      rageMult: 1,
      auraT: def.aura ? 0.8 + Math.random() * def.aura.interval : 0,
      auraPulse: 0,
      hurt: 0,
      eating: false,
      chomp: 0,
      anim: Math.random() * Math.PI * 2,
      phase: Math.random() * Math.PI * 2,
      breached: false,
      dead: false
    };
    this.zombies.push(z);
    return z;
  }

  flushPendingSpawns() {
    if (!this.pendingSpawns.length) return;
    const list = this.pendingSpawns;
    this.pendingSpawns = [];
    for (const e of list) {
      this.spawnZombie(e.type, e.row, { x: e.x, hpFactor: e.hpFactor });
    }
  }

  laneTarget(p) {
    for (const z of this.zombies) {
      if (!z.dead && z.row === p.r && z.x > p.x + 6) return z;
    }
    return null;
  }

  lanternValue(p) {
    return PLANT_EFFECTS.lantern.value[tierOf(p, 1)];
  }

  lanternInterval(p) {
    return PLANT_EFFECTS.lantern.interval[tierOf(p, 2)];
  }

  bellInterval(p) {
    return PLANT_EFFECTS.bell.interval[tierOf(p, 1)];
  }

  bellSlow(p) {
    const t = tierOf(p, 2);
    return {
      duration: PLANT_EFFECTS.bell.slowDuration[t],
      factor: PLANT_EFFECTS.bell.slowFactor[t]
    };
  }

  bellDamage(p) {
    return PLANT_EFFECTS.bell.damage[tierOf(p, 3)];
  }

  updatePlants(dt) {
    for (const p of this.plants) {
      if (p.dead) continue;
      p.recoil = Math.max(0, p.recoil - dt * 3);
      p.pulse = Math.max(0, p.pulse - dt);
      p.biteT = Math.max(0, (p.biteT ?? 0) - dt);
      p.charge = 0;
      const def = p.def;

      if (def.produce) {
        const interval = this.lanternInterval(p);
        p.timer += dt;
        if (p.timer >= interval) {
          p.timer -= interval;
          p.pulse = 0.45;
          audio.sfx('produce', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
          this.orbs.push({
            x: p.x + (Math.random() - 0.5) * 44,
            y: p.y - 30,
            targetY: p.y - 30,
            landed: true,
            life: 9,
            value: this.lanternValue(p),
            phase: Math.random() * Math.PI * 2
          });
        }
      } else if (def.shot) {
        p.timer += dt;
        const target = this.laneTarget(p);
        if (target) {
          if (p.timer >= def.shot.interval) {
            p.timer -= def.shot.interval;
            p.recoil = 1;
            this.fireVolley(p);
          } else {
            p.charge = Math.min(1, p.timer / def.shot.interval);
          }
        } else {
          p.timer = Math.min(p.timer, def.shot.interval);
        }
      } else if (def.pulse) {
        const interval = this.bellInterval(p);
        p.timer += dt;
        if (p.timer >= interval) {
          let hitAny = false;
          const dmg = this.bellDamage(p);
          const slow = this.bellSlow(p);
          for (const z of this.zombies) {
            if (z.dead || z.row !== p.r || z.x <= p.x - 8) continue;
            this.applySlow(z, slow.duration, slow.factor);
            const extend = PLANT_EFFECTS.bell.slowExtend[tierOf(p, 3)];
            if (extend) z.slowT = Math.min(10, z.slowT + extend);
            if (dmg > 0) this.damageZombie(z, dmg);
            hitAny = true;
          }
          if (hitAny) {
            p.timer = 0;
            p.pulse = 0.55;
            audio.sfx('bell', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
            this.particles.push({
              x: p.x, y: p.y - 6, vx: 0, vy: 0,
              life: 0.5, maxLife: 0.5, size: 26,
              color: '#8fd0da', kind: 'ring'
            });
          } else {
            p.timer = Math.min(p.timer, interval);
          }
        }
      } else if (def.censer) {
        p.timer += dt;
        p.charge = Math.min(1, p.timer / PLANT_EFFECTS.censer.interval);
        if (p.timer >= PLANT_EFFECTS.censer.interval) {
          p.timer -= PLANT_EFFECTS.censer.interval;
          p.charge = 0;
          this.censerPulse(p);
        }
      } else if (def.umbrella) {
        p.timer += dt;
        const interval = PLANT_EFFECTS.umbrella.blowInterval[tierOf(p, 2)];
        if (p.timer >= interval) {
          p.timer -= interval;
          this.umbrellaBlow(p);
        }
        const regen = PLANT_EFFECTS.umbrella.regen[tierOf(p, 3)];
        if (regen > 0) this.umbrellaHeal(p, regen * dt);
      } else if (def.melee) {
        p.timer += dt;
        const interval = PLANT_EFFECTS.lion.interval[tierOf(p, 2)];
        const target = this.lionTarget(p);
        if (target) {
          p.charge = Math.min(1, p.timer / interval);
          if (p.timer >= interval) {
            p.timer = 0;
            p.charge = 0;
            this.lionStrike(p, target);
          }
        } else {
          p.timer = Math.min(p.timer, interval);
        }
      } else if (def.bomb) {
        p.timer += dt;
        if (p.timer >= def.bomb.fuse) this.explode(p);
      }
    }
  }

  censerEffect(plant) {
    return {
      damage: PLANT_EFFECTS.censer.damage[tierOf(plant, 1)],
      radius: PLANT_EFFECTS.censer.radius[tierOf(plant, 2)],
      slowFactor: PLANT_EFFECTS.censer.slowFactor[tierOf(plant, 3)],
      slowDuration: PLANT_EFFECTS.censer.slowDuration[tierOf(plant, 3)]
    };
  }

  censerPulse(p) {
    const fx = this.censerEffect(p);
    p.pulse = 0.7;
    audio.sfx('censer', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    let hitAny = false;
    for (const z of this.zombies) {
      if (z.dead) continue;
      if (Math.hypot(z.x - p.x, z.y - p.y) > fx.radius) continue;
      this.damageZombie(z, fx.damage);
      if (fx.slowFactor > 0) this.applySlow(z, fx.slowDuration, fx.slowFactor);
      hitAny = true;
    }
    this.particles.push({
      x: p.x, y: p.y - 4, vx: 0, vy: 0,
      life: 0.6, maxLife: 0.6, size: Math.max(30, fx.radius - 26),
      color: 'rgba(214,198,164,0.42)', kind: 'ring'
    });
    for (let i = 0; i < 7; i++) {
      const a = Math.random() * Math.PI * 2;
      this.particles.push({
        x: p.x + Math.cos(a) * (14 + Math.random() * 20),
        y: p.y - 12 + Math.sin(a) * 10,
        vx: Math.cos(a) * 16,
        vy: -24 - Math.random() * 22,
        life: 0.6 + Math.random() * 0.5, maxLife: 1.1,
        size: 3 + Math.random() * 4,
        color: hitAny ? '#c9b28c' : '#b9aa90', kind: 'circle'
      });
    }
    if (hitAny) this.shake = Math.max(this.shake, 2);
  }

  umbrellaGuard(target) {
    let guard = 0;
    for (const p of this.plants) {
      if (p.dead || p.type !== 'umbrella' || p === target) continue;
      if (Math.abs(p.c - target.c) > 1 || Math.abs(p.r - target.r) > 1) continue;
      guard = Math.max(guard, PLANT_EFFECTS.umbrella.guard[tierOf(p, 1)]);
    }
    return guard;
  }

  umbrellaBlow(p) {
    audio.sfx('umbrella', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    const dist = PLANT_EFFECTS.umbrella.blowDist[tierOf(p, 2)];
    const reach = p.def.umbrella.reach;
    let hitAny = false;
    for (const z of this.zombies) {
      if (z.dead || z.row !== p.r) continue;
      if (z.x < p.x - 12 || z.x > p.x + reach) continue;
      z.x = Math.min(1360, z.x + dist);
      hitAny = true;
    }
    p.pulse = 0.6;
    this.particles.push({
      x: p.x, y: p.y - 2, vx: 0, vy: 0,
      life: 0.5, maxLife: 0.5, size: 20,
      color: 'rgba(220,150,130,0.75)', kind: 'ring'
    });
    if (hitAny) {
      for (let i = 0; i < 6; i++) {
        this.particles.push({
          x: p.x + 18 + i * 8, y: p.y - 18 + (i % 2) * 8,
          vx: 80 + Math.random() * 40, vy: -10 + Math.random() * 20,
          life: 0.4, maxLife: 0.4,
          size: 2 + Math.random() * 2,
          color: '#e0b49a', kind: 'circle'
        });
      }
    }
  }

  umbrellaHeal(p, amount) {
    for (const other of this.plants) {
      if (other.dead || other === p) continue;
      if (Math.abs(p.c - other.c) > 1 || Math.abs(p.r - other.r) > 1) continue;
      if (other.hp >= other.maxHp) continue;
      other.hp = Math.min(other.maxHp, other.hp + amount);
      if (Math.random() < 0.035) {
        this.particles.push({
          x: other.x + (Math.random() - 0.5) * 18,
          y: other.y - 2,
          vx: (Math.random() - 0.5) * 16,
          vy: -28 - Math.random() * 18,
          life: 0.5, maxLife: 0.5,
          size: 2.2, color: '#8fbf9a', kind: 'circle'
        });
      }
    }
  }

  lionTarget(p) {
    const reach = PLANT_EFFECTS.lion.reach;
    let best = null;
    for (const z of this.zombies) {
      if (z.dead || z.row !== p.r) continue;
      if (z.x < p.x - 12 || z.x - p.x > reach) continue;
      if (!best || z.x < best.x) best = z;
    }
    return best;
  }

  lionStrike(p, target) {
    audio.sfx('lion', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    const dmg = PLANT_EFFECTS.lion.damage[tierOf(p, 1)];
    const stunChance = PLANT_EFFECTS.lion.stunChance[tierOf(p, 2)];
    const heal = PLANT_EFFECTS.lion.heal[tierOf(p, 3)];
    this.damageZombie(target, dmg);
    if (!target.dead) {
      if (stunChance > 0 && Math.random() < stunChance) {
        this.applyStun(target, PLANT_EFFECTS.lion.stunDuration);
      }
      target.x = Math.min(1360, target.x + PLANT_EFFECTS.lion.knock);
    }
    if (heal > 0) p.hp = Math.min(p.maxHp, p.hp + heal);
    p.recoil = 1;
    p.pulse = 0.35;
    this.spark(p.x + 18, p.y - 14, '#f0c26e', 5);
    this.shake = Math.max(this.shake, 1.6);
  }

  applyStun(z, duration) {
    if (z.dead || duration <= 0) return;
    z.stunT = Math.max(z.stunT ?? 0, duration);
    z.eating = false;
    for (let i = 0; i < 4; i++) {
      this.particles.push({
        x: z.x + (Math.random() - 0.5) * 22,
        y: z.y - 54 + (Math.random() - 0.5) * 12,
        vx: (Math.random() - 0.5) * 50,
        vy: -20 - Math.random() * 40,
        life: 0.5, maxLife: 0.5,
        size: 2 + Math.random() * 2,
        color: '#ffe09a', kind: 'circle'
      });
    }
  }

  fireVolley(p) {
    const def = p.def;
    const base = def.shot.damage;
    audio.sfx('shoot', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    const count = PLANT_EFFECTS.shooter.volley[tierOf(p, 1)] || 1;
    const crit = PLANT_EFFECTS.shooter.critChance[tierOf(p, 3)] || 0;
    const slow = PLANT_EFFECTS.shooter.critSlow[tierOf(p, 3)] || 0;
    const adjacent = tierOf(p, 2);

    for (let i = 0; i < count; i++) {
      const big = i === 0 && Math.random() < crit;
      this.projectiles.push({
        x: p.x + 20 + i * 18,
        y: p.y - 12 + (i % 2 === 0 ? -2 : 2),
        row: p.r,
        speed: def.shot.speed,
        damage: big ? base * 2 : base,
        big,
        slow,
        dead: false
      });
    }

    if (adjacent > 0) {
      let lanes = [];
      if (p.r > 0) lanes.push(p.r - 1);
      if (p.r < BOARD.rows - 1) lanes.push(p.r + 1);
      if (adjacent === 1 && lanes.length > 1) {
        p.adjFlip = (p.adjFlip ?? 0) + 1;
        lanes = [lanes[p.adjFlip % 2]];
      }
      const dmg = base * (PLANT_EFFECTS.shooter.adjacentFactor[adjacent] ?? 0.5);
      for (const lane of lanes) {
        this.projectiles.push({
          x: p.x + 20,
          y: ROW_Y[lane] - 12,
          row: lane,
          speed: def.shot.speed,
          damage: dmg,
          big: false,
          slow: 0,
          dead: false
        });
      }
    }
  }

  explode(p) {
    p.dead = true;
    this.cells[p.r][p.c] = null;
    audio.sfx('explode', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    const radius = p.def.bomb.radius;
    for (const z of this.zombies) {
      if (z.dead) continue;
      if (Math.hypot(z.x - p.x, z.y - p.y) <= radius) {
        this.damageZombie(z, p.def.bomb.damage);
      }
    }
    for (let i = 0; i < 30; i++) {
      const a = Math.random() * Math.PI * 2;
      const sp = 80 + Math.random() * 260;
      this.particles.push({
        x: p.x, y: p.y,
        vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 60,
        life: 0.45 + Math.random() * 0.45, maxLife: 0.9,
        size: 3 + Math.random() * 5,
        color: Math.random() < 0.5 ? '#ff8b3d' : '#ffd36b',
        kind: 'circle'
      });
    }
    this.shake = Math.max(this.shake, 14);
  }

  wallBlast(p) {
    const dmg = PLANT_EFFECTS.wall.blast[tierOf(p, 3)];
    if (!dmg) return;
    audio.sfx('wall', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    for (const z of this.zombies) {
      if (z.dead) continue;
      if (Math.hypot(z.x - p.x, z.y - p.y) <= 160) {
        this.damageZombie(z, dmg);
      }
    }
    for (let i = 0; i < 22; i++) {
      const a = Math.random() * Math.PI * 2;
      const sp = 60 + Math.random() * 220;
      this.particles.push({
        x: p.x, y: p.y,
        vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 40,
        life: 0.4 + Math.random() * 0.5, maxLife: 0.9,
        size: 3 + Math.random() * 5,
        color: ['#a5a092', '#8b877b', '#d8c79a'][i % 3],
        kind: 'shard'
      });
    }
    this.shake = Math.max(this.shake, 10);
  }

  eatTarget(z) {
    const reach = z.def.reach ?? 38;
    let best = null;
    for (const p of this.plants) {
      if (p.dead || p.r !== z.row) continue;
      if (p.x <= z.x + 2 && z.x - p.x <= reach) {
        if (!best || p.x > best.x) best = p;
      }
    }
    return best;
  }

  applySlow(z, duration, factor = 0.5) {
    if (z.dead || duration <= 0) return;
    if (z.slowT <= 0) z.slowFactor = factor;
    else z.slowFactor = Math.min(z.slowFactor ?? factor, factor);
    z.slowT = Math.max(z.slowT, duration);
  }

  mournerWail(z) {
    const aura = z.def.aura;
    z.auraT = aura.interval;
    z.auraPulse = 0.85;
    let buffed = false;
    for (const other of this.zombies) {
      if (other.dead || other === z) continue;
      if (Math.hypot(other.x - z.x, other.y - z.y) > aura.radius) continue;
      other.rageT = Math.max(other.rageT ?? 0, aura.duration);
      other.rageMult = Math.max(other.rageMult ?? 1, aura.haste);
      buffed = true;
    }
    this.particles.push({
      x: z.x, y: z.y - 6, vx: 0, vy: 0,
      life: 0.7, maxLife: 0.7, size: Math.max(30, aura.radius - 26),
      color: buffed ? 'rgba(196,126,102,0.4)' : 'rgba(150,130,120,0.32)', kind: 'ring'
    });
  }

  updateZombies(dt) {
    for (const z of this.zombies) {
      if (z.dead) continue;
      if (z.hurt > 0) z.hurt = Math.max(0, z.hurt - dt);
      if (z.slowT > 0) z.slowT = Math.max(0, z.slowT - dt);
      if (z.rageT > 0) z.rageT = Math.max(0, z.rageT - dt);
      if (z.auraPulse > 0) z.auraPulse = Math.max(0, z.auraPulse - dt);

      if (z.stunT > 0) {
        z.stunT = Math.max(0, z.stunT - dt);
        z.eating = false;
        if (Math.random() < dt * 2.5) {
          this.particles.push({
            x: z.x + (Math.random() - 0.5) * 20,
            y: z.y - 48 + (Math.random() - 0.5) * 10,
            vx: 8,
            vy: -18,
            life: 0.4, maxLife: 0.4,
            size: 1.8, color: '#ffe09a', kind: 'circle'
          });
        }
        continue;
      }

      if (z.def.aura) {
        z.auraT = Math.max(0, (z.auraT ?? 0) - dt);
        if (z.auraT <= 0) this.mournerWail(z);
      }

      const target = this.eatTarget(z);
      if (target) {
        z.eating = true;
        z.chomp += dt;
        z.eatSndT = (z.eatSndT ?? 0) - dt;
        if (z.eatSndT <= 0) {
          audio.sfx('eat', {
            plant: target.type,
            pan: Math.max(-1, Math.min(1, (z.x - 640) / 640))
          });
          z.eatSndT = 0.34 + Math.random() * 0.16;
        }
        target.biteT = 0.2;
        const guard = this.umbrellaGuard(target);
        target.hp -= z.def.dps * (1 - guard) * dt;

        if (target.type === 'lantern') {
          const reflect = PLANT_EFFECTS.lantern.reflect[tierOf(target, 3)];
          if (reflect > 0) this.damageZombie(z, reflect * dt);
        } else if (target.type === 'wall') {
          const reflect = PLANT_EFFECTS.wall.reflect[tierOf(target, 2)];
          if (reflect > 0) this.damageZombie(z, reflect * dt);
        }

        if (target.hp <= 0) this.killPlant(target);
        if (Math.random() < dt * 4) {
          this.particles.push({
            x: target.x + (Math.random() - 0.5) * 20,
            y: target.y - 6,
            vx: (Math.random() - 0.5) * 40,
            vy: -30 - Math.random() * 40,
            life: 0.5, maxLife: 0.5,
            size: 2 + Math.random() * 2,
            color: '#d9c08a', kind: 'circle'
          });
        }
      } else {
        z.eating = false;
        const mult = z.slowT > 0 ? (z.slowFactor ?? 0.5) : 1;
        const rage = z.rageT > 0 ? Math.max(1, z.rageMult ?? 1) : 1;
        z.x -= z.speed * mult * rage * dt;
        z.anim += dt * (mult < 1 ? 0.7 : 1) * rage;
        if (z.x < BOARD.x - 18 && !z.breached) this.breach(z);
      }
    }
  }

  breach(z) {
    z.breached = true;
    const mower = this.mowers[z.row];
    if (mower.ready) {
      mower.ready = false;
      mower.active = true;
      mower.x = BOARD.x - 32;
      audio.sfx('mower', { pan: -0.9 });
      this.shake = Math.max(this.shake, 8);
      this.floaters.push({
        x: BOARD.x + 60, y: ROW_Y[z.row] - 40,
        text: '门神显灵！', color: '#ffd98a',
        life: 1.4, maxLife: 1.4, size: 18
      });
    } else {
      this.lose();
    }
  }

  updateProjectiles(dt) {
    for (const p of this.projectiles) {
      if (p.dead) continue;
      p.x += p.speed * dt;
      let hit = null;
      for (const z of this.zombies) {
        if (z.dead || z.row !== p.row) continue;
        if (p.x + 8 >= z.x - 24 && p.x - 8 <= z.x + 24) {
          if (!hit || z.x < hit.x) hit = z;
        }
      }
      if (hit) {
        p.dead = true;
        this.damageZombie(hit, p.damage);
        if (p.slow) this.applySlow(hit, p.slow, 0.5);
        this.spark(p.x, p.y, p.big ? '#ffe9a8' : '#f0dca8', p.big ? 8 : 3);
      } else if (p.x > 1340) {
        p.dead = true;
      }
    }
  }

  damageZombie(z, amount) {
    if (z.dead) return;
    const pan = Math.max(-1, Math.min(1, (z.x - 640) / 640));
    if (amount >= 8) audio.sfx('hit', { type: z.type, pan });
    const hadShell = z.shell > 0;
    let dmg = amount;
    if (z.shell > 0) {
      const absorbed = Math.min(z.shell, dmg);
      z.shell -= absorbed;
      dmg -= absorbed;
      if (z.shell <= 0) {
        if (hadShell) audio.sfx('shell', { pan });
        for (let i = 0; i < 8; i++) {
          this.particles.push({
            x: z.x + (Math.random() - 0.5) * 24,
            y: z.y - 20 - Math.random() * 20,
            vx: (Math.random() - 0.5) * 120,
            vy: -40 - Math.random() * 90,
            life: 0.6, maxLife: 0.6,
            size: 4 + Math.random() * 4,
            color: '#efe6cf', kind: 'shard'
          });
        }
        if (z.def.split && !z.splitDone) {
          z.splitDone = true;
          const split = z.def.split;
          for (let i = 0; i < split.count; i++) {
            this.pendingSpawns.push({
              type: split.type,
              row: z.row,
              x: z.x + (i - (split.count - 1) / 2) * 20,
              hpFactor: split.hp
            });
          }
          this.floaters.push({
            x: z.x, y: z.y - 76, text: '轿子散了！',
            color: '#ffd0a0', life: 1.4, maxLife: 1.4, size: 17
          });
          this.shake = Math.max(this.shake, 6);
        }
      }
    }
    z.hp -= dmg;
    z.hurt = 0.14;
    if (z.hp <= 0) this.killZombie(z);
  }

  killZombie(z) {
    if (z.dead) return;
    z.dead = true;
    audio.sfx('zombieDie', { pan: Math.max(-1, Math.min(1, (z.x - 640) / 640)) });
    this.kills += 1;
    const color =
      z.type === 'mountain' ? '#5a4030'
        : z.type === 'paper' ? '#efe6cf'
          : z.type === 'mourner' ? '#d8d2c4'
            : z.type === 'sedan' ? '#a83a2e'
              : z.type === 'tongue' ? '#87a87d'
                : '#9fb3a2';
    for (let i = 0; i < 10; i++) {
      this.particles.push({
        x: z.x + (Math.random() - 0.5) * 26,
        y: z.y - 10 - Math.random() * 30,
        vx: (Math.random() - 0.5) * 140,
        vy: -30 - Math.random() * 120,
        life: 0.5 + Math.random() * 0.4, maxLife: 0.9,
        size: 3 + Math.random() * 4,
        color, kind: 'shard'
      });
    }
  }

  killPlant(p, silent = false) {
    if (p.dead) return;
    p.dead = true;
    this.cells[p.r][p.c] = null;
    if (p.type !== 'wall' || silent) {
      audio.sfx('plantDown', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    }
    if (!silent && p.type === 'wall') this.wallBlast(p);
    for (let i = 0; i < 8; i++) {
      this.particles.push({
        x: p.x + (Math.random() - 0.5) * 24,
        y: p.y - 8,
        vx: (Math.random() - 0.5) * 120,
        vy: -40 - Math.random() * 100,
        life: 0.5, maxLife: 0.5,
        size: 3 + Math.random() * 3,
        color: '#c9a15c', kind: 'shard'
      });
    }
  }

  updateMowers(dt) {
    for (const m of this.mowers) {
      if (!m.active) continue;
      m.x += 640 * dt;
      for (const z of this.zombies) {
        if (!z.dead && z.row === m.row && Math.abs(z.x - m.x) < 56) {
          this.killZombie(z);
        }
      }
      if (m.x > 1360) m.active = false;
    }
  }

  updateOrbs(dt) {
    for (const o of this.orbs) {
      if (o.dead) continue;
      if (!o.landed) {
        o.y += 130 * dt;
        if (o.y >= o.targetY) {
          o.y = o.targetY;
          o.landed = true;
          o.life = 10;
        }
      } else {
        o.life -= dt;
        if (this.settings.autoCollect) {
          o.autoT = (o.autoT ?? 0) + dt;
          if (o.autoT >= this.settings.collectDelay) {
            this.collectOrb(o);
            continue;
          }
        }
        if (o.life <= 0) o.dead = true;
      }
    }
  }

  updateParticles(dt) {
    for (const p of this.particles) {
      if (p.kind === 'ring') {
        p.life -= dt;
        continue;
      }
      p.vy += (p.kind === 'shard' ? 260 : 180) * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
    }
  }

  updateFloaters(dt) {
    for (const f of this.floaters) {
      f.y -= 26 * dt;
      f.life -= dt;
    }
  }

  spark(x, y, color, n) {
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2;
      const sp = 40 + Math.random() * 90;
      this.particles.push({
        x, y,
        vx: Math.cos(a) * sp,
        vy: Math.sin(a) * sp - 30,
        life: 0.3 + Math.random() * 0.25,
        maxLife: 0.55,
        size: 1.5 + Math.random() * 2,
        color, kind: 'circle'
      });
    }
  }

  cleanup() {
    this.plants = this.plants.filter((p) => !p.dead);
    this.zombies = this.zombies.filter((z) => !z.dead);
    this.projectiles = this.projectiles.filter((p) => !p.dead);
    this.orbs = this.orbs.filter((o) => !o.dead);
    this.particles = this.particles.filter((p) => p.life > 0);
    this.floaters = this.floaters.filter((f) => f.life > 0);
  }

  win() {
    if (this.phase !== 'playing') return;
    this.updateRecords(true);
    this.clearSave();
    audio.sfx('win');
    this.phase = 'won';
    this.result = { time: this.time, kills: this.kills, sun: this.sun };
    this.selected = -1;
    this.menu = null;
    this.shovel = false;
    this.overlay = null;
    this.overlayFrom = null;
    this.confirmBack = false;
    this.confirmNew = false;
  }

  lose() {
    if (this.phase !== 'playing') return;
    this.updateRecords(false);
    this.clearSave();
    audio.sfx('lose');
    this.phase = 'lost';
    this.result = { time: this.time, kills: this.kills, sun: this.sun };
    this.selected = -1;
    this.menu = null;
    this.shovel = false;
    this.overlay = null;
    this.overlayFrom = null;
    this.confirmBack = false;
    this.confirmNew = false;
  }

  debugPlace(type, c, r) {
    return this.placeFree(type, c, r);
  }

  debugSun(n) {
    this.sun = n;
  }

  snapshot() {
    return {
      phase: this.phase,
      sun: this.sun,
      time: +this.time.toFixed(1),
      plants: this.plants.length,
      zombies: this.zombies.length,
      wave: this.waveIndex,
      kills: this.kills,
      mowers: this.mowers.map((m) => m.ready),
      settings: { ...this.settings },
      runDifficulty: this.runDifficulty,
      runCheats: this.runCheats,
      overlay: this.overlay,
      shovel: this.shovel,
      hasSave: this.hasSave,
      saveMeta: this.saveMeta ? { ...this.saveMeta } : null,
      records: { ...this.records },
      confirmNew: this.confirmNew,
      menuNotice: this.menuNotice,
      loadout: [...this.loadout],
      prep: this.prep ? {
        levelId: this.prep.levelId,
        selected: [...this.prep.selected],
        warning: this.prep.warning,
        zombies: this.prep.zombies.map((z) => z.type),
        cinemaT: +this.prep.cinemaT.toFixed(2),
        cinemaDone: this.prep.cinemaDone
      } : null,
      almanac: {
        tab: this.almanacTab,
        index: this.almanacIndex,
        scroll: this.almanacScroll,
        max: this.almanacMaxScroll
      },
      runLevelId: this.runLevelId,
      selectedLevel: this.selectedLevel,
      levelName: this.level.name,
      levelThreat: this.levelThreat,
      levelCountMul: this.levelCountMul,
      levelHpMul: this.levelHpMul,
      cleared: [...this.progress.cleared]
    };
  }
}
