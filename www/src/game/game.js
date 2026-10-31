import { LEVELS, getLevel, PLANT_TYPES, PLANT_ORDER, ZOMBIE_TYPES, TUTORIAL_LEVEL } from '../content.js';
import {
  ALMANAC, BOARD, BOARD_W, BTN, LEVELS_UI, PREP, PREP_CINEMA, SETTINGS, TUTORIAL_UI, VIEW,
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
  sound: true,
  resolution: 'auto'
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
    this.tutorial = null;
    this.torch = { buff: 0, burn: 0, slow: 0, slowDuration: 1.5 };
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

  startTutorial() {
    this.level = TUTORIAL_LEVEL;
    this.runLevelId = TUTORIAL_LEVEL.id;
    this.levelThreat = 1;
    this.levelCountMul = 1;
    this.levelHpMul = 1;
    this.reset(['shooter']);
    this.phase = 'playing';
    this.prep = null;
    this.runDifficulty = 'easy';
    this.runCheats = false;
    this.overlay = null;
    this.overlayFrom = null;
    this.confirmBack = false;
    this.confirmNew = false;
    this.menuNotice = null;
    this.almanacReturn = null;
    this.banner = null;
    const lantern = this.placeFree('lantern', 0, 2);
    if (lantern) lantern.tutorialIdle = true;
    const ox = (lantern ? lantern.x : 282) + 78;
    const oy = (lantern ? lantern.y : 421) - 12;
    const orb = {
      x: ox, y: oy - 44, targetY: oy,
      landed: false, life: 9999, value: 25, phase: 0, tutorial: true
    };
    this.orbs.push(orb);
    this.tutorial = {
      step: 'collect',
      t: 0,
      orb,
      lantern,
      shooter: null,
      zombie: null,
      battleT: 0,
      doneT: 0
    };
    this.selected = -1;
    this.shovel = false;
    this.menu = null;
    audio.sfx('start');
  }

  exitTutorial() {
    if (!this.tutorial) return;
    this.tutorial = null;
    const level = getLevel(this.selectedLevel);
    this.level = level;
    this.runLevelId = level.id;
    this.levelThreat = level.threat;
    this.levelCountMul = Math.sqrt(level.threat);
    this.levelHpMul = Math.sqrt(level.threat);
    this.reset();
    this.phase = 'menu';
    this.menuNotice = null;
    this.refreshSaveInfo();
  }

  spawnTutorialZombie() {
    const tut = this.tutorial;
    if (!tut) return;
    const shooter = tut.shooter;
    const row = shooter ? shooter.r : 2;
    const sx = shooter ? shooter.x : 552;
    const x = Math.min(BOARD.x + BOARD_W - 12, Math.max(950, sx + 120));
    const z = this.spawnZombie('ghost', row, { x });
    if (!z) return;
    z.hp = 120;
    z.maxHp = 120;
    z.speed = 14;
    tut.zombie = z;
    this.banner = { text: '恶客上门 · 看签筒出手', t: 2.2, max: 2.2 };
    audio.sfx('wave');
  }

  updateTutorial(dt) {
    const tut = this.tutorial;
    if (!tut) return;
    tut.t += dt;
    if (tut.step === 'battle' && tut.battleT > 0) {
      tut.battleT -= dt;
      if (tut.battleT <= 0) this.spawnTutorialZombie();
    }
    if (tut.step === 'battle' && tut.zombie && tut.zombie.dead) {
      tut.step = 'finishing';
      tut.doneT = 0.9;
      this.floaters.push({
        x: tut.zombie.x, y: tut.zombie.y - 58, text: '干得漂亮',
        color: '#ffe1a1', life: 1.4, maxLife: 1.4, size: 22
      });
    }
    if (tut.step === 'finishing') {
      tut.doneT -= dt;
      if (tut.doneT <= 0) this.finishTutorial();
    }
  }

  finishTutorial() {
    if (!this.tutorial) return;
    this.tutorial.step = 'done';
    this.phase = 'won';
    this.result = { time: this.time, kills: this.kills, sun: this.sun, tutorial: true };
    this.banner = null;
    this.selected = -1;
    this.menu = null;
    this.shovel = false;
    this.overlay = null;
    this.overlayFrom = null;
    this.confirmBack = false;
    this.confirmNew = false;
    audio.sfx('win');
  }

  toMenu() {
    if (this.tutorial) {
      this.exitTutorial();
      return;
    }
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
    else this.openLevels();
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
    if (this.tutorial) return;
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
    if (this.tutorial || this.runCheats) return;
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
        adjFlip: num(p.adjFlip),
        armT: num(p.armT),
        armed: !!p.armed,
        chewT: num(p.chewT),
        chewMax: num(p.chewMax),
        shell: p.shell ? { hp: num(p.shell.hp), maxHp: num(p.shell.maxHp) } : null
      })),
      zombies: this.zombies.filter((z) => !z.dead && !z.dying).map((z) => ({
        type: z.type,
        row: z.row,
        x: num(z.x),
        hp: num(z.hp),
        maxHp: num(z.maxHp),
        armor: num(z.armor),
        maxArmor: num(z.maxArmor),
        armorType: z.armorType || null,
        armorName: z.armorName || null,
        speed: num(z.speed),
        slowT: num(z.slowT),
        slowFactor: num(z.slowFactor),
        stunT: num(z.stunT),
        burnT: num(z.burnT),
        burnDps: num(z.burnDps),
        rageT: num(z.rageT),
        rageMult: num(z.rageMult, 1),
        auraT: num(z.auraT),
        supportT: num(z.supportT),
        vaulted: !!z.vaulted,
        breached: !!z.breached
      })),
      projectiles: this.projectiles.filter((p) => !p.dead && !p.homing && !p.lob).map((p) => ({
        x: num(p.x),
        y: num(p.y),
        row: p.row,
        speed: num(p.speed),
        damage: num(p.damage),
        big: !!p.big,
        slowAmount: num(p.slowAmount),
        slowDuration: num(p.slowDuration),
        burn: num(p.burn),
        burnDuration: num(p.burnDuration),
        gravel: !!p.gravel,
        needle: !!p.needle,
        pierceArmor: !!p.pierceArmor,
        star: !!p.star,
        vuln: num(p.vuln),
        vulnDuration: num(p.vulnDuration),
        knock: num(p.knock)
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
      const maxCap = def.hp;
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
        buffDamage: 0,
        haste: 0,
        chewT: Math.max(0, num(raw.chewT)),
        chewMax: Math.max(0, num(raw.chewMax)),
        armT: Math.max(0, num(raw.armT)),
        armed: !!raw.armed,
        upgrades: initUpgrades(),
        adjFlip: Math.max(0, Math.floor(num(raw.adjFlip)))
      };
      if (raw.upgrades && typeof raw.upgrades === 'object') {
        for (const k of [1, 2, 3]) {
          p.upgrades[k] = Math.max(0, Math.min(3, Math.floor(num(raw.upgrades[k]))));
        }
      }
      if (raw.shell && typeof raw.shell === 'object') {
        const shellHp = Math.max(1, Math.min(PLANT_EFFECTS.shell.hp, Math.round(num(raw.shell.hp, PLANT_EFFECTS.shell.hp))));
        p.shell = {
          type: 'shell', def: PLANT_TYPES.shell,
          hp: shellHp,
          maxHp: Math.max(shellHp, Math.min(PLANT_EFFECTS.shell.hp, Math.round(num(raw.shell.maxHp, PLANT_EFFECTS.shell.hp)))),
          pulse: 0
        };
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
      const oldArmor = Number.isFinite(raw.armor) ? raw.armor : num(raw.shell);
      let maxHp = Math.max(1, Math.round(num(raw.maxHp, def.hp)));
      if (!Number.isFinite(raw.armor) && Number.isFinite(raw.shell)) {
        maxHp = Math.max(1, maxHp - oldArmor);
      }
      const hp = Math.max(1, Math.min(maxHp, Math.round(num(raw.hp, maxHp))));
      const maxArmor = Math.max(0, Math.round(num(raw.maxArmor, num(raw.maxShell, oldArmor))));
      const armor = Math.max(0, Math.min(maxArmor, Math.round(oldArmor)));
      const slowFactor = Math.max(0.1, Math.min(1, num(raw.slowFactor, 1)));
      this.zombies.push({
        def,
        type: raw.type,
        row,
        x: Math.max(-240, num(raw.x, 1300)),
        y: ROW_Y[row] + 6,
        hp,
        maxHp,
        armor,
        maxArmor,
        armorType: raw.armorType || def.armorType || null,
        armorName: raw.armorName || def.armorName || null,
        speed: Math.max(8, num(raw.speed, def.speed)),
        slowT: Math.max(0, num(raw.slowT)),
        slowAmount: 1 - slowFactor,
        slowFactor,
        stunT: Math.max(0, num(raw.stunT)),
        vulnT: 0,
        vuln: 0,
        burnT: Math.max(0, num(raw.burnT)),
        burnDps: Math.max(0, num(raw.burnDps)),
        rageT: Math.max(0, num(raw.rageT)),
        rageMult: Math.max(1, num(raw.rageMult, 1)),
        auraT: def.aura ? Math.max(0, num(raw.auraT, def.aura.interval)) : 0,
        auraPulse: 0,
        supportT: def.support ? Math.max(0, num(raw.supportT, def.support.interval)) : 0,
        supportPulse: 0,
        armorPulse: 0,
        hurt: 0,
        eating: false,
        chomp: 0,
        anim: Math.random() * Math.PI * 2,
        phase: Math.random() * Math.PI * 2,
        breached: !!raw.breached,
        dying: false,
        dead: false,
        deathT: 0,
        deathDur: def.large ? 1 : 0.5,
        vaulted: !!raw.vaulted,
        vaultT: 0,
        vaultFromX: 0,
        vaultToX: 0,
        vaultArc: 0
      });
      if (raw.vaulted && def.vault) this.zombies[this.zombies.length - 1].speed = def.vault.speedAfter;
    }

    for (const raw of run.projectiles || []) {
      if (!raw || typeof raw !== 'object') continue;
      const row = Math.floor(num(raw.row, -1));
      if (row < 0 || row >= BOARD.rows) continue;
      const oldSlow = num(raw.slow);
      this.projectiles.push({
        x: num(raw.x),
        y: num(raw.y),
        row,
        speed: Math.max(100, num(raw.speed, 520)),
        damage: Math.max(1, num(raw.damage, 20)),
        big: !!raw.big,
        slowAmount: raw.slowAmount != null ? Math.max(0, num(raw.slowAmount)) : (oldSlow > 0 ? 0.5 : 0),
        slowDuration: Math.max(0, num(raw.slowDuration, oldSlow > 0 ? oldSlow : 0)),
        burn: Math.max(0, num(raw.burn)),
        burnDuration: Math.max(0, num(raw.burnDuration, 2)),
        gravel: !!raw.gravel,
        needle: !!raw.needle,
        pierceArmor: !!raw.pierceArmor,
        star: !!raw.star,
        vuln: Math.max(0, num(raw.vuln)),
        vulnDuration: Math.max(0, num(raw.vulnDuration, 2)),
        knock: Math.max(0, num(raw.knock)),
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
    this.updateTutorial(dt);

    if (this.menu && this.menu.plant.dead) this.menu = null;

    if (
      !this.tutorial &&
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
        this.openLevels();
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
      if (inRect(x, y, BTN.tutorialMenu)) {
        this.startTutorial();
        return;
      }
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
        this.openLevels();
      } else if (inRect(x, y, BTN.settingsMenu)) {
        this.openSettings('menu');
      }
      return;
    }

    if (this.phase === 'won' || this.phase === 'lost') {
      if (this.tutorial && this.tutorial.step === 'done') {
        if (inRect(x, y, BTN.overlay)) this.startTutorial();
        else if (inRect(x, y, BTN.toMenu)) this.exitTutorial();
        return;
      }
      if (inRect(x, y, BTN.overlay)) this.openPrep(this.runLevelId);
      else if (inRect(x, y, BTN.toMenu)) this.toMenu();
      return;
    }

    if (this.phase === 'paused') {
      if (inRect(x, y, BTN.resume)) this.phase = 'playing';
      else if (inRect(x, y, BTN.pauseSettings)) this.openSettings('pause');
      else if (inRect(x, y, BTN.restart)) {
        if (this.tutorial) this.startTutorial();
        else this.openPrep(this.runLevelId);
      }
      else if (inRect(x, y, BTN.backMenu)) this.confirmBack = true;
      else if (inRect(x, y, BTN.pauseAlmanac)) this.openAlmanac();
      return;
    }

    if (this.tutorial && inRect(x, y, TUTORIAL_UI.skip)) {
      audio.sfx('click');
      this.exitTutorial();
      return;
    }

    if (inRect(x, y, BTN.pause)) {
      audio.sfx('click');
      this.togglePause();
      return;
    }

    if (!this.tutorial && inRect(x, y, BTN.shovel)) {
      audio.sfx('click');
      this.shovel = !this.shovel;
      this.selected = -1;
      this.menu = null;
      return;
    }

    if (!this.tutorial && this.settings.quickWave && inRect(x, y, BTN.quickWave)) {
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
        if (this.tutorial && this.tutorial.step === 'collect') {
          this.deny('先收下那团香火');
          return;
        }
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
        if (this.tutorial) {
          if (this.tutorial.step === 'plant') {
            this.deny('先种下签筒');
            return;
          }
          if (this.tutorial.step === 'upgrade' && plant !== this.tutorial.shooter) {
            this.deny('先给签筒升阶');
            return;
          }
        }
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
        if (this.aliveZombie(z) && z.x <= VIEW.w + 10) this.killZombie(z);
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
    if (this.tutorial) {
      if (this.tutorial.step !== 'plant') {
        return this.deny(this.tutorial.step === 'collect' ? '先收下那团香火' : '先跟着提示走');
      }
      if (card.id !== 'shooter') return this.deny('先种下签筒');
    }
    if (card.def.attach) {
      const host = this.cells[r][c];
      if (card.cd > 0) return this.deny('还没缓过手来');
      if (this.sun < card.def.cost) return this.deny('香火不够');
      if (!host) return this.deny('先种一株植物，再罩龟甲');
      if (host.shell) return this.deny('这里已经罩了龟甲');
      this.sun -= card.def.cost;
      card.cd = card.def.cooldown;
      this.attachShell(host);
      this.selected = -1;
      audio.sfx('place');
      return;
    }
    if (card.cd > 0) return this.deny('还没缓过手来');
    if (this.sun < card.def.cost) return this.deny('香火不够');
    if (this.cells[r][c]) return this.deny('这里已经摆了东西');
    this.sun -= card.def.cost;
    card.cd = card.def.cooldown;
    const placed = this.placeFree(card.id, c, r);
    this.selected = -1;
    if (this.tutorial && this.tutorial.step === 'plant' && placed) {
      this.tutorial.shooter = placed;
      this.tutorial.step = 'upgrade';
    }
    audio.sfx('place');
  }

  attachShell(host) {
    const hp = PLANT_EFFECTS.shell.hp;
    host.shell = {
      type: 'shell', def: PLANT_TYPES.shell,
      hp, maxHp: hp, pulse: 0.6
    };
    this.floaters.push({
      x: host.x, y: host.y - 60, text: '龟甲罩上了',
      color: '#cfe0b0', life: 1.2, maxLife: 1.2, size: 16
    });
    this.spark(host.x, host.y - 20, '#c8d6a4', 10);
  }

  damagePlant(p, amount) {
    if (!p || p.dead || amount <= 0) return;
    if (p.shell && p.shell.hp > 0) {
      p.shell.hp -= amount;
      p.shell.pulse = 0.25;
      if (p.shell.hp <= 0) {
        p.shell = null;
        audio.sfx('shell', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
        this.floaters.push({
          x: p.x, y: p.y - 54, text: '龟甲碎了',
          color: '#e8d6a8', life: 1.1, maxLife: 1.1, size: 15
        });
        for (let i = 0; i < 10; i++) {
          this.particles.push({
            x: p.x + (Math.random() - 0.5) * 30,
            y: p.y - 8 - Math.random() * 26,
            vx: (Math.random() - 0.5) * 130,
            vy: -40 - Math.random() * 100,
            life: 0.5 + Math.random() * 0.4, maxLife: 0.9,
            size: 3 + Math.random() * 4,
            color: i % 2 ? '#9e9a78' : '#d8cfae', kind: 'shard'
          });
        }
      }
      return;
    }
    p.hp -= amount;
    if (p.hp <= 0) this.killPlant(p);
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
    if (this.tutorial && (this.tutorial.step !== 'upgrade' || plant !== this.tutorial.shooter)) {
      this.deny('先给签筒升阶');
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

    this.floaters.push({
      x: plant.x, y: plant.y - 66,
      text: `${pathId}-${st.nextTier} ${st.name}`,
      color: '#ffe1a1', life: 1.4, maxLife: 1.4, size: 18
    });
    this.spark(plant.x, plant.y - 18, st.path.color, 12);
    this.shake = Math.max(this.shake, 3);
    this.refreshPlantBuffs();
    audio.sfx('upgrade');
    if (this.tutorial && this.tutorial.step === 'upgrade' && plant === this.tutorial.shooter) {
      this.tutorial.step = 'battle';
      this.tutorial.battleT = 1.0;
      this.menu = null;
    }
  }

  placeFree(type, c, r) {
    if (c < 0 || c >= BOARD.cols || r < 0 || r >= BOARD.rows) return null;
    if (this.cells[r][c]) return null;
    const def = PLANT_TYPES[type];
    if (!def || def.attach) return null;
    const pos = cellCenter(c, r);
    const p = {
      def, type, c, r, x: pos.x, y: pos.y,
      hp: def.hp, maxHp: def.hp, timer: 0,
      phase: Math.random() * Math.PI * 2,
      recoil: 0, pulse: 0, charge: 0, biteT: 0, dead: false,
      buffDamage: 0, haste: 0, chewT: 0, chewMax: 0, armT: 0, armed: false,
      upgrades: initUpgrades(),
      adjFlip: 0
    };
    if (def.produce) p.timer = def.produce.interval - def.produce.first;
    else if (def.shot) p.timer = def.shot.interval;
    this.plants.push(p);
    this.cells[r][c] = p;
    this.refreshPlantBuffs();
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
    if (this.tutorial && this.tutorial.step === 'collect' && orb === this.tutorial.orb) {
      this.tutorial.step = 'plant';
      this.tutorial.orb = null;
    }
  }

  updateEconomy(dt) {
    if (this.tutorial) return;
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
    const armor = Math.max(0, Math.round((def.armor || 0) * hpMul));
    const z = {
      def, type, row,
      x: Number.isFinite(opts.x) ? opts.x : 1290 + Math.random() * 90,
      y: ROW_Y[row] + 6,
      hp,
      maxHp: hp,
      armor,
      maxArmor: armor,
      armorType: def.armorType || null,
      armorName: def.armorName || null,
      speed: def.speed,
      slowT: 0,
      slowFactor: 1,
      stunT: 0,
      vulnT: 0,
      vuln: 0,
      burnT: 0,
      burnDps: 0,
      rageT: 0,
      rageMult: 1,
      auraT: def.aura ? 0.8 + Math.random() * def.aura.interval : 0,
      auraPulse: 0,
      supportT: def.support ? 1.5 + Math.random() * def.support.interval : 0,
      supportPulse: 0,
      armorPulse: 0,
      hurt: 0,
      eating: false,
      chomp: 0,
      anim: Math.random() * Math.PI * 2,
      phase: Math.random() * Math.PI * 2,
      breached: false,
      dying: false,
      dead: false,
      deathT: 0,
      deathDur: def.large ? 1 : 0.5,
      vaulted: false,
      vaultT: 0,
      vaultFromX: 0,
      vaultToX: 0,
      vaultArc: 0
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

  aliveZombie(z) {
    return !!z && !z.dead && !z.dying;
  }

  laneTarget(p) {
    for (const z of this.zombies) {
      if (this.aliveZombie(z) && z.row === p.r && z.x > p.x + 6) return z;
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
    const t = tierOf(p, 1);
    return {
      duration: PLANT_EFFECTS.bell.slowDuration,
      amount: PLANT_EFFECTS.bell.slow[t]
    };
  }

  bellDamage(p) {
    return PLANT_EFFECTS.bell.damage[tierOf(p, 3)];
  }

  isLarge(z) {
    return !!(z && z.def && z.def.large);
  }

  plantDamage(p, base) {
    return base * (1 + (p?.buffDamage || 0));
  }

  projectileDamage(p, base) {
    const lantern = p?.buffDamage || 0;
    const fire = this.torch?.buff || 0;
    return base * (1 + Math.max(lantern, fire));
  }

  plantHaste(p) {
    return p?.haste || 0;
  }

  refreshPlantBuffs() {
    for (const p of this.plants) {
      if (p.dead) continue;
      p.buffDamage = 0;
      p.haste = 0;
    }
    const torch = { buff: 0, burn: 0, slow: 0, slowDuration: 1.5 };
    for (const source of this.plants) {
      if (source.dead) continue;
      if (source.type === 'lantern') {
        const tier = tierOf(source, 3);
        if (tier <= 0) continue;
        const range = PLANT_EFFECTS.lantern.buffRange[tier];
        const value = PLANT_EFFECTS.lantern.buffDamage[tier];
        for (const target of this.plants) {
          if (target.dead || target === source || target.r !== source.r) continue;
          if (tier < 3 && (target.c <= source.c || target.c - source.c > range)) continue;
          target.buffDamage = Math.max(target.buffDamage, value);
        }
      } else if (source.type === 'bell') {
        const tier = tierOf(source, 2);
        if (tier <= 0) continue;
        const range = PLANT_EFFECTS.bell.hasteRange[tier];
        const slowPct = this.bellSlow(source).amount;
        const value = slowPct * PLANT_EFFECTS.bell.hasteFactor[tier];
        for (const target of this.plants) {
          if (target.dead || target === source || target.r !== source.r) continue;
          if (tier < 3 && (target.c <= source.c || target.c - source.c > range)) continue;
          target.haste = Math.max(target.haste, value);
        }
      } else if (source.type === 'torch') {
        const t1 = tierOf(source, 1);
        const t2 = tierOf(source, 2);
        const t3 = tierOf(source, 3);
        torch.buff = Math.max(torch.buff, PLANT_EFFECTS.torch.buff[t1]);
        torch.burn = Math.max(torch.burn, PLANT_EFFECTS.torch.burn[t2]);
        torch.slow = Math.max(torch.slow, PLANT_EFFECTS.torch.slow[t3]);
      }
    }
    this.torch = torch;
  }

  updatePlants(dt) {
    this.refreshPlantBuffs();
    for (const p of this.plants) {
      if (p.dead) continue;
      p.recoil = Math.max(0, p.recoil - dt * 3);
      p.pulse = Math.max(0, p.pulse - dt);
      p.biteT = Math.max(0, (p.biteT ?? 0) - dt);
      p.charge = 0;
      const def = p.def;

      if (def.produce && !p.tutorialIdle) {
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
        const interval = def.shot.interval / (1 + p.haste);
        if (target) {
          if (p.timer >= interval) {
            p.timer -= interval;
            p.recoil = 1;
            this.fireVolley(p);
          } else {
            p.charge = Math.min(1, p.timer / interval);
          }
        } else {
          p.timer = Math.min(p.timer, interval);
        }
      } else if (def.pulse) {
        const interval = this.bellInterval(p) / (1 + p.haste);
        p.timer += dt;
        if (p.timer >= interval) {
          let hitAny = false;
          const dmg = this.bellDamage(p);
          const slow = this.bellSlow(p);
          const damageRange = PLANT_EFFECTS.bell.damageRange[tierOf(p, 3)];
          const rootChance = PLANT_EFFECTS.bell.rootChance[tierOf(p, 3)];
          for (const z of this.zombies) {
            if (!this.aliveZombie(z) || z.row !== p.r || z.x <= p.x - 8) continue;
            this.applySlow(z, slow.duration, slow.amount);
            if (dmg > 0 && (damageRange >= 99 || z.x - p.x <= damageRange * BOARD.cw)) {
              this.damageZombie(z, this.plantDamage(p, dmg));
              if (rootChance > 0 && !this.isLarge(z) && Math.random() < rootChance) {
                this.applyStun(z, PLANT_EFFECTS.bell.rootDuration);
              }
            }
            hitAny = true;
          }
          if (hitAny) {
            p.timer = 0;
            p.pulse = 0.55;
            audio.sfx('bell', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
            this.particles.push({
              x: p.x, y: p.y - 6, vx: 0, vy: 0,
              life: 0.5, maxLife: 0.5, size: damageRange >= 99 ? 74 : damageRange > 1 ? 48 : 26,
              color: '#8fd0da', kind: 'ring'
            });
          } else {
            p.timer = Math.min(p.timer, interval);
          }
        }
      } else if (def.censer) {
        const interval = PLANT_EFFECTS.censer.interval / (1 + p.haste);
        p.timer += dt;
        p.charge = Math.min(1, p.timer / interval);
        if (p.timer >= interval) {
          p.timer -= interval;
          p.charge = 0;
          this.censerPulse(p);
        }
      } else if (def.chomp) {
        if (p.chewT > 0) {
          p.chewT = Math.max(0, p.chewT - dt);
          p.charge = p.chewMax > 0 ? 1 - p.chewT / p.chewMax : 0;
          if (p.chewT <= 0) {
            const sun = PLANT_EFFECTS.umbrella.sun[tierOf(p, 2)];
            if (sun > 0) {
              this.orbs.push({
                x: p.x + (Math.random() - 0.5) * 26,
                y: p.y - 24,
                targetY: p.y - 24,
                landed: true,
                life: 9,
                value: sun,
                phase: Math.random() * Math.PI * 2
              });
            }
            p.pulse = 0.5;
            p.charge = 0;
          }
        } else {
          p.timer += dt;
          const target = this.flytrapTarget(p);
          if (target) {
            const base = this.isLarge(target) ? PLANT_EFFECTS.umbrella.largeInterval : 0.35;
            const interval = base / (1 + p.haste);
            p.charge = Math.min(1, p.timer / interval);
            if (p.timer >= interval) {
              p.timer = 0;
              p.charge = 0;
              this.flytrapBite(p, target);
            }
          } else {
            p.timer = Math.min(p.timer, 0.35);
          }
        }
      } else if (def.melee) {
        p.timer += dt;
        const interval = PLANT_EFFECTS.lion.interval[tierOf(p, 2)] / (1 + p.haste);
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
      } else if (def.mine) {
        if (!p.armed) {
          p.armT += dt;
          if (p.armT >= def.mine.arm) {
            p.armed = true;
            p.pulse = 0.5;
          }
        } else {
          const target = this.mineTarget(p);
          if (target) this.mineExplode(p, target);
        }
      } else if (def.homing) {
        const interval = def.homing.interval / (1 + p.haste);
        p.timer += dt;
        const target = this.nearestAllTarget(p);
        if (target) {
          p.charge = Math.min(1, p.timer / interval);
          if (p.timer >= interval) {
            p.timer = 0;
            p.charge = 0;
            this.fireCat(p);
          }
        } else {
          p.timer = Math.min(p.timer, interval);
        }
      } else if (def.lob) {
        const interval = PLANT_EFFECTS.lobber.interval[tierOf(p, 2)] / (1 + p.haste);
        p.timer += dt;
        const target = this.rightmostLaneTarget(p);
        if (target) {
          p.charge = Math.min(1, p.timer / interval);
          if (p.timer >= interval) {
            p.timer = 0;
            p.charge = 0;
            this.fireLob(p, target);
          }
        } else {
          p.timer = Math.min(p.timer, interval);
        }
      } else if (def.star) {
        const interval = PLANT_EFFECTS.star.interval[tierOf(p, 2)] / (1 + p.haste);
        p.timer += dt;
        const hasTarget = this.zombies.some((z) => this.aliveZombie(z) && z.x > p.x);
        if (hasTarget) {
          p.charge = Math.min(1, p.timer / interval);
          if (p.timer >= interval) {
            p.timer = 0;
            p.charge = 0;
            this.fireStar(p);
          }
        } else {
          p.timer = Math.min(p.timer, interval);
        }
      } else if (def.needle) {
        const interval = PLANT_EFFECTS.needle.interval[tierOf(p, 2)] / (1 + p.haste);
        p.timer += dt;
        const target = this.needleTarget(p);
        if (target) {
          p.charge = Math.min(1, p.timer / interval);
          if (p.timer >= interval) {
            p.timer = 0;
            p.charge = 0;
            this.fireNeedle(p);
          }
        } else {
          p.timer = Math.min(p.timer, interval);
        }
      } else if (def.judge) {
        const interval = PLANT_EFFECTS.judge.interval[tierOf(p, 2)] / (1 + p.haste);
        p.timer += dt;
        const target = this.judgeTarget(p);
        if (target) {
          p.charge = Math.min(1, p.timer / interval);
          if (p.timer >= interval) {
            p.timer = 0;
            p.charge = 0;
            this.judgeStrike(p, target);
          }
        } else {
          p.timer = Math.min(p.timer, interval);
        }
      } else if (def.torch) {
        p.pulse = 0.18 + Math.sin((this.time + p.phase) * 3.2) * 0.08;
      } else if (p.type === 'wall') {
        this.updateWall(p, dt);
      } else if (def.bomb) {
        p.timer += dt;
        if (p.timer >= def.bomb.fuse) this.explode(p);
      }
    }
  }

  updateWall(p, dt) {
    const healTier = tierOf(p, 1);
    if (healTier > 0 && p.hp < p.maxHp && (healTier >= 3 || p.biteT <= 0)) {
      p.hp = Math.min(p.maxHp, p.hp + PLANT_EFFECTS.wall.heal[healTier] * dt);
      if (Math.random() < dt * 1.8) {
        this.particles.push({
          x: p.x + (Math.random() - 0.5) * 24,
          y: p.y - 4 - Math.random() * 18,
          vx: (Math.random() - 0.5) * 10,
          vy: -18 - Math.random() * 20,
          life: 0.5, maxLife: 0.5,
          size: 1.6 + Math.random() * 1.6,
          color: '#9fc7a4', kind: 'circle'
        });
      }
    }
    const tier = tierOf(p, 3);
    if (tier <= 0) return;
    p.timer += dt;
    const interval = PLANT_EFFECTS.wall.gravelInterval / (1 + p.haste);
    const target = this.laneTarget(p);
    if (target) {
      p.charge = Math.min(1, p.timer / interval);
      if (p.timer >= interval) {
        p.timer -= interval;
        p.charge = 0;
        this.fireGravel(p, tier);
      }
    } else {
      p.timer = Math.min(p.timer, interval);
    }
  }

  censerEffect(plant) {
    return {
      damage: PLANT_EFFECTS.censer.damage[tierOf(plant, 1)],
      radius: PLANT_EFFECTS.censer.radius[tierOf(plant, 2)],
      slowAmount: PLANT_EFFECTS.censer.slow[tierOf(plant, 3)],
      slowDuration: PLANT_EFFECTS.censer.slowDuration[tierOf(plant, 3)]
    };
  }

  censerPulse(p) {
    const fx = this.censerEffect(p);
    p.pulse = 0.7;
    audio.sfx('censer', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    let hitAny = false;
    for (const z of this.zombies) {
      if (!this.aliveZombie(z)) continue;
      if (Math.hypot(z.x - p.x, z.y - p.y) > fx.radius) continue;
      this.damageZombie(z, this.plantDamage(p, fx.damage));
      if (fx.slowAmount > 0) this.applySlow(z, fx.slowDuration, fx.slowAmount);
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

  plantGuard(target) {
    if (target.type === 'umbrella' && target.chewT > 0) {
      return PLANT_EFFECTS.umbrella.chewGuard[tierOf(target, 3)] || 0;
    }
    return 0;
  }

  flytrapTarget(p) {
    const reach = p.def.chomp.reach;
    let best = null;
    for (const z of this.zombies) {
      if (!this.aliveZombie(z) || z.row !== p.r) continue;
      if (z.x < p.x - 14 || z.x - p.x > reach) continue;
      if (!best || z.x < best.x) best = z;
    }
    return best;
  }

  flytrapBite(p, target) {
    audio.sfx('chomp', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    p.recoil = 1;
    p.pulse = 0.5;
    if (this.isLarge(target)) {
      this.damageZombie(target, this.plantDamage(p, p.def.chomp.largeDamage));
      this.spark(p.x + 22, p.y - 22, '#7a8f55', 5);
      return;
    }
    this.killZombie(target);
    const speed = PLANT_EFFECTS.umbrella.chewSpeed[tierOf(p, 1)] || 0;
    p.chewMax = p.def.chomp.chew * (1 - speed);
    p.chewT = p.chewMax;
    this.floaters.push({
      x: p.x, y: p.y - 74, text: '收了',
      color: '#cfe0a0', life: 1.0, maxLife: 1.0, size: 16
    });
  }

  mineTarget(p) {
    for (const z of this.zombies) {
      if (!this.aliveZombie(z) || z.row !== p.r) continue;
      if (z.x >= p.x - 16 && z.x - p.x <= 44) return z;
    }
    return null;
  }

  mineExplode(p, target) {
    p.dead = true;
    this.cells[p.r][p.c] = null;
    audio.sfx('explode', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    this.damageZombie(target, this.plantDamage(p, p.def.mine.damage));
    for (let i = 0; i < 22; i++) {
      const a = Math.random() * Math.PI * 2;
      const sp = 70 + Math.random() * 190;
      this.particles.push({
        x: p.x, y: p.y,
        vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 45,
        life: 0.4 + Math.random() * 0.4, maxLife: 0.8,
        size: 2.5 + Math.random() * 4,
        color: Math.random() < 0.5 ? '#b58a52' : '#e0c087',
        kind: 'shard'
      });
    }
    this.shake = Math.max(this.shake, 9);
  }

  fireGravel(p, tier) {
    audio.sfx('shoot', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    const vuln = PLANT_EFFECTS.wall.vuln[tier] || 0;
    const knock = PLANT_EFFECTS.wall.knockCells[tier] || 0;
    this.projectiles.push({
      x: p.x + 24,
      y: p.y - 10,
      row: p.r,
      speed: 430,
      damage: this.projectileDamage(p, PLANT_EFFECTS.wall.gravelDamage[tier]),
      big: false,
      slowAmount: this.torch.slow,
      slowDuration: 1.5,
      burn: this.torch.burn,
      burnDuration: 2,
      gravel: true,
      vuln,
      vulnDuration: PLANT_EFFECTS.wall.vulnDuration,
      knock,
      dead: false
    });
    p.recoil = 0.8;
  }

  nearestZombies(x, y, limit, exclude = null) {
    const candidates = [];
    for (const z of this.zombies) {
      if (!this.aliveZombie(z)) continue;
      if (exclude && exclude.has(z)) continue;
      candidates.push({ z, d: Math.hypot(z.x - x, z.y - y) });
    }
    candidates.sort((a, b) => a.d - b.d);
    return candidates.slice(0, limit).map((c) => c.z);
  }

  nearestAllTarget(p) {
    let best = null;
    let bestD = Infinity;
    for (const z of this.zombies) {
      if (!this.aliveZombie(z)) continue;
      const d = Math.hypot(z.x - p.x, z.y - p.y);
      if (d < bestD) {
        bestD = d;
        best = z;
      }
    }
    return best;
  }

  rightmostLaneTarget(p) {
    let best = null;
    for (const z of this.zombies) {
      if (!this.aliveZombie(z) || z.row !== p.r || z.x <= p.x + 6) continue;
      if (!best || z.x > best.x) best = z;
    }
    return best;
  }

  needleTarget(p) {
    let best = null;
    let bestArmored = null;
    for (const z of this.zombies) {
      if (!this.aliveZombie(z) || z.row !== p.r || z.x <= p.x + 6) continue;
      if (!best || z.x < best.x) best = z;
      if (z.armor > 0 && (!bestArmored || z.x < bestArmored.x)) bestArmored = z;
    }
    return bestArmored || best;
  }

  judgeTarget(p) {
    const reach = PLANT_EFFECTS.judge.reach;
    let best = null;
    for (const z of this.zombies) {
      if (!this.aliveZombie(z) || z.row !== p.r) continue;
      if (z.x < p.x - 12 || z.x - p.x > reach) continue;
      if (!best || z.x < best.x) best = z;
    }
    return best;
  }

  fireCat(p) {
    const t1 = tierOf(p, 1);
    const t2 = tierOf(p, 2);
    const t3 = tierOf(p, 3);
    const count = PLANT_EFFECTS.cat.count[t1] || 1;
    const targets = this.nearestZombies(p.x, p.y, count);
    if (!targets.length) return false;
    const damage = this.projectileDamage(p, PLANT_EFFECTS.cat.damage[t2]);
    const hits = PLANT_EFFECTS.cat.hits[t2] || 1;
    const vuln = PLANT_EFFECTS.cat.vuln[t3] || 0;
    const catSlow = PLANT_EFFECTS.cat.slow[t3] || 0;
    audio.sfx('shoot', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    for (let i = 0; i < count; i++) {
      const target = targets[i % targets.length];
      this.projectiles.push({
        homing: true,
        target,
        hitIds: [],
        hitsLeft: hits,
        x: p.x + 12,
        y: p.y - 22,
        row: target.row,
        speed: PLANT_EFFECTS.cat.speed,
        damage,
        vuln,
        vulnDuration: 2,
        slowAmount: Math.max(catSlow, this.torch.slow),
        slowDuration: 1.5,
        burn: this.torch.burn,
        burnDuration: 2,
        dead: false
      });
    }
    p.recoil = 0.7;
    return true;
  }

  fireLob(p, target) {
    const t1 = tierOf(p, 1);
    const t2 = tierOf(p, 2);
    const t3 = tierOf(p, 3);
    const damage = this.projectileDamage(p, PLANT_EFFECTS.lobber.damage[t1]);
    const lobSlow = PLANT_EFFECTS.lobber.slowFactor[t3] || 0;
    audio.sfx('shoot', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    this.projectiles.push({
      lob: true,
      target,
      row: p.r,
      x: p.x + 10,
      y: p.y - 22,
      sx: p.x + 10,
      sy: p.y - 22,
      tx: target.x,
      ty: target.y - 14,
      t: 0,
      flight: p.def.lob.flight,
      damage,
      vuln: 0,
      slowAmount: Math.max(lobSlow, this.torch.slow),
      slowDuration: 2,
      burn: this.torch.burn,
      burnDuration: 2,
      dead: false
    });
    p.recoil = 0.9;
  }

  fireStar(p) {
    const t1 = tierOf(p, 1);
    const t2 = tierOf(p, 2);
    const t3 = tierOf(p, 3);
    const damage = this.projectileDamage(p, PLANT_EFFECTS.star.damage[t1]);
    const vuln = PLANT_EFFECTS.star.vuln[t3] || 0;
    let any = false;
    for (let r = 0; r < BOARD.rows; r++) {
      const target = this.zombies.find((z) => this.aliveZombie(z) && z.row === r && z.x > p.x);
      if (!target) continue;
      any = true;
      this.projectiles.push({
        x: p.x + 20,
        y: ROW_Y[r] - 14,
        row: r,
        speed: 560,
        damage,
        star: true,
        vuln,
        vulnDuration: 2,
        slowAmount: this.torch.slow,
        slowDuration: 1.5,
        burn: this.torch.burn,
        burnDuration: 2,
        dead: false
      });
    }
    if (any) {
      audio.sfx('shoot', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
      p.recoil = 0.5;
    }
    return any;
  }

  fireNeedle(p) {
    const t1 = tierOf(p, 1);
    const t2 = tierOf(p, 2);
    const t3 = tierOf(p, 3);
    audio.sfx('shoot', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    this.projectiles.push({
      x: p.x + 22,
      y: p.y - 16,
      row: p.r,
      speed: p.def.needle.speed,
      damage: this.projectileDamage(p, PLANT_EFFECTS.needle.damage[t1]),
      needle: true,
      pierceArmor: true,
      vuln: PLANT_EFFECTS.needle.vuln[t3] || 0,
      vulnDuration: 2,
      slowAmount: this.torch.slow,
      slowDuration: 1.5,
      burn: this.torch.burn,
      burnDuration: 2,
      dead: false
    });
    p.recoil = 0.6;
    p.charge = 0;
  }

  judgeStrike(p, target) {
    const t1 = tierOf(p, 1);
    const t3 = tierOf(p, 3);
    const damage = this.plantDamage(p, PLANT_EFFECTS.judge.damage[t3]);
    const knock = PLANT_EFFECTS.judge.knockCells[t1] * BOARD.cw;
    audio.sfx('bell', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    this.damageZombie(target, damage);
    if (this.aliveZombie(target)) {
      target.x = Math.min(1360, target.x + knock);
    }
    this.particles.push({
      x: p.x, y: p.y - 30, vx: 0, vy: 0,
      life: 0.5, maxLife: 0.5, size: 54,
      color: 'rgba(214,116,76,0.55)', kind: 'ring'
    });
    this.spark(target.x, target.y - 14, '#f0c26e', 6);
    this.shake = Math.max(this.shake, 3);
    p.recoil = 1;
    p.pulse = 0.5;
  }

  applyBurn(z, duration, dps) {
    if (!this.aliveZombie(z) || duration <= 0 || dps <= 0) return;
    z.burnT = Math.max(z.burnT || 0, duration);
    z.burnDps = Math.max(z.burnDps || 0, dps);
  }

  applyProjectileStatuses(z, p) {
    if (p.vuln) this.applyVulnerable(z, p.vulnDuration || 2, p.vuln);
    if (p.burn) this.applyBurn(z, p.burnDuration || 2, p.burn);
    if (p.slowAmount) this.applySlow(z, p.slowDuration || 1.5, p.slowAmount);
  }

  applyVulnerable(z, duration, amount) {
    if (!this.aliveZombie(z) || duration <= 0 || amount <= 0) return;
    z.vulnT = Math.max(z.vulnT || 0, duration);
    z.vuln = Math.max(z.vuln || 0, amount);
  }

  lionTarget(p) {
    const reach = PLANT_EFFECTS.lion.reach;
    let best = null;
    for (const z of this.zombies) {
      if (!this.aliveZombie(z) || z.row !== p.r) continue;
      if (z.x < p.x - 12 || z.x - p.x > reach) continue;
      if (!best || z.x < best.x) best = z;
    }
    return best;
  }

  lionStrike(p, target) {
    audio.sfx('lion', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    const dmg = this.plantDamage(p, PLANT_EFFECTS.lion.damage[tierOf(p, 1)]);
    const stunChance = PLANT_EFFECTS.lion.stunChance[tierOf(p, 2)];
    const heal = PLANT_EFFECTS.lion.heal[tierOf(p, 3)];
    const knock = PLANT_EFFECTS.lion.knockCells * BOARD.cw *
      (PLANT_EFFECTS.lion.knockBonus[tierOf(p, 1)] || 1);
    this.damageZombie(target, dmg);
    if (!target.dead) {
      if (stunChance > 0 && Math.random() < stunChance) {
        this.applyStun(target, PLANT_EFFECTS.lion.stunDuration);
      }
      target.x = Math.min(1360, target.x + knock);
    }
    if (heal > 0) p.hp = Math.min(p.maxHp, p.hp + heal);
    p.recoil = 1;
    p.pulse = 0.35;
    this.spark(p.x + 18, p.y - 14, '#f0c26e', 5);
    this.shake = Math.max(this.shake, 1.6);
  }

  applyStun(z, duration) {
    if (!this.aliveZombie(z) || duration <= 0) return;
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
    const base = this.projectileDamage(p, def.shot.damage);
    audio.sfx('shoot', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    const count = PLANT_EFFECTS.shooter.volley[tierOf(p, 1)] || 1;
    const crit = PLANT_EFFECTS.shooter.critChance[tierOf(p, 3)] || 0;
    const critSlow = PLANT_EFFECTS.shooter.critSlow[tierOf(p, 3)] || 0;
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
        slowAmount: Math.max(critSlow > 0 ? 0.5 : 0, this.torch.slow),
        slowDuration: Math.max(critSlow, this.torch.slow > 0 ? 1.5 : 0),
        burn: this.torch.burn,
        burnDuration: 2,
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
      const dmg = this.projectileDamage(p, def.shot.damage) * (PLANT_EFFECTS.shooter.adjacentFactor[adjacent] ?? 0.5);
      for (const lane of lanes) {
        this.projectiles.push({
          x: p.x + 20,
          y: ROW_Y[lane] - 12,
          row: lane,
          speed: def.shot.speed,
          damage: dmg,
          big: false,
          slowAmount: this.torch.slow,
          slowDuration: 1.5,
          burn: this.torch.burn,
          burnDuration: 2,
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
      if (!this.aliveZombie(z)) continue;
      if (Math.hypot(z.x - p.x, z.y - p.y) <= radius) {
        this.damageZombie(z, this.plantDamage(p, p.def.bomb.damage));
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

  applySlow(z, duration, amount = 0.5) {
    if (!this.aliveZombie(z) || duration <= 0) return;
    const slow = Math.max(0, Math.min(0.9, amount));
    if (z.slowT <= 0) {
      z.slowAmount = slow;
      z.slowFactor = 1 - slow;
    } else if (slow > (z.slowAmount || 0)) {
      z.slowAmount = slow;
      z.slowFactor = 1 - slow;
    }
    z.slowT = Math.max(z.slowT, duration);
  }

  mournerWail(z) {
    const aura = z.def.aura;
    z.auraT = aura.interval;
    z.auraPulse = 0.85;
    let buffed = false;
    for (const other of this.zombies) {
      if (!this.aliveZombie(other) || other === z) continue;
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
      if (z.dying) {
        z.deathT += dt;
        if (z.deathT >= z.deathDur) {
          z.dead = true;
          z.dying = false;
        }
        continue;
      }
      if (z.hurt > 0) z.hurt = Math.max(0, z.hurt - dt);
      if (z.slowT > 0) {
        z.slowT = Math.max(0, z.slowT - dt);
        if (z.slowT <= 0) {
          z.slowAmount = 0;
          z.slowFactor = 1;
        }
      }
      if (z.vulnT > 0) {
        z.vulnT = Math.max(0, z.vulnT - dt);
        if (z.vulnT <= 0) z.vuln = 0;
      }
      if (z.burnT > 0) {
        z.burnT = Math.max(0, z.burnT - dt);
        this.damageZombie(z, (z.burnDps || 0) * dt, { silent: true });
        if (!this.aliveZombie(z)) continue;
        if (z.burnT <= 0) z.burnDps = 0;
      }
      if (z.rageT > 0) z.rageT = Math.max(0, z.rageT - dt);
      if (z.auraPulse > 0) z.auraPulse = Math.max(0, z.auraPulse - dt);
      if (z.supportPulse > 0) z.supportPulse = Math.max(0, z.supportPulse - dt);
      if (z.armorPulse > 0) z.armorPulse = Math.max(0, z.armorPulse - dt);

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
      if (z.def.support) {
        z.supportT = Math.max(0, (z.supportT ?? 0) - dt);
        if (z.supportT <= 0) this.artisanGrant(z);
      }

      if (z.vaultT > 0) {
        z.vaultT = Math.max(0, z.vaultT - dt);
        const dur = z.def.vault.duration;
        const k = 1 - z.vaultT / dur;
        z.x = z.vaultFromX + (z.vaultToX - z.vaultFromX) * k;
        z.vaultArc = Math.sin(Math.PI * Math.max(0, Math.min(1, k)));
        z.eating = false;
        if (z.vaultT <= 0) {
          z.vaulted = true;
          z.speed = z.def.vault.speedAfter;
          z.vaultArc = 0;
        }
        continue;
      }

      if (z.def.vault && !z.vaulted) {
        const plant = this.eatTarget(z);
        if (plant) {
          z.vaultFromX = z.x;
          z.vaultToX = Math.max(BOARD.x + 8, plant.x - 42);
          z.vaultT = z.def.vault.duration;
          z.vaultArc = 0;
          z.eating = false;
          this.floaters.push({
            x: z.x, y: z.y - 66, text: '跳幡！',
            color: '#f0d59a', life: 0.9, maxLife: 0.9, size: 15
          });
          continue;
        }
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
        const guard = this.plantGuard(target);
        this.damagePlant(target, z.def.dps * (1 - guard) * dt);

        if (target.type === 'wall') {
          const reflect = PLANT_EFFECTS.wall.reflect[tierOf(target, 2)];
          if (reflect > 0) this.damageZombie(z, this.plantDamage(target, reflect * dt));
        }
        if (Math.random() < dt * 4) {
          this.particles.push({
            x: target.x + (Math.random() - 0.5) * 20,
            y: target.y - 6,
            vx: (Math.random() - 0.5) * 40,
            vy: -30 - Math.random() * 40,
            life: 0.5, maxLife: 0.5,
            size: 2 + Math.random() * 2,
            color: target.shell ? '#c7cba8' : '#d9c08a', kind: 'circle'
          });
        }
      } else {
        z.eating = false;
        const mult = z.slowT > 0 ? (z.slowFactor ?? 1) : 1;
        const rage = z.rageT > 0 ? Math.max(1, z.rageMult ?? 1) : 1;
        z.x -= z.speed * mult * rage * dt;
        z.anim += dt * (mult < 1 ? 0.7 : 1) * rage;
        if (z.x < BOARD.x - 18 && !z.breached) this.breach(z);
      }
    }
  }

  artisanGrant(z) {
    const support = z.def.support;
    z.supportT = support.interval;
    z.supportPulse = 0.85;
    const hpMul = this.levelHpMul * this.difficultyMults().hp;
    const armorValue = Math.max(40, Math.round(support.armor * hpMul));
    const targets = this.zombies
      .filter((o) => this.aliveZombie(o) && o !== z && o.def.tier === 'l' &&
        Math.hypot(o.x - z.x, o.y - z.y) <= support.radius)
      .sort((a, b) => (a.armor > 0 ? 1 : 0) - (b.armor > 0 ? 1 : 0) || a.armor - b.armor)
      .slice(0, support.targets);
    for (const o of targets) {
      o.maxArmor = Math.max(o.maxArmor || 0, armorValue);
      o.armor = Math.min(o.maxArmor, Math.max(o.armor || 0, armorValue));
      o.armorType = 'charm';
      o.armorName = support.name;
      o.armorPulse = 0.9;
      this.floaters.push({
        x: o.x, y: o.y - 62, text: '纸甲',
        color: '#e5d6a4', life: 1.1, maxLife: 1.1, size: 14
      });
    }
    this.particles.push({
      x: z.x, y: z.y - 20, vx: 0, vy: 0,
      life: 0.65, maxLife: 0.65, size: 54,
      color: targets.length ? 'rgba(224,204,150,0.55)' : 'rgba(170,160,140,0.3)', kind: 'ring'
    });
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

  projectileCollision(p) {
    let hit = null;
    for (const z of this.zombies) {
      if (z.dead || z.row !== p.row) continue;
      if (p.x + 8 >= z.x - 24 && p.x - 8 <= z.x + 24) {
        if (!hit || z.x < hit.x) hit = z;
      }
    }
    return hit;
  }

  updateHoming(p, dt) {
    if (!this.aliveZombie(p.target)) {
      const next = this.nearestZombies(p.x, p.y, 1, new Set(p.hitIds || []));
      p.target = next[0] || null;
    }
    if (!p.target) {
      p.dead = true;
      return;
    }
    const tx = p.target.x;
    const ty = p.target.y - 24;
    const dx = tx - p.x;
    const dy = ty - p.y;
    const d = Math.hypot(dx, dy);
    if (d < 15) {
      const target = p.target;
      p.hitIds = p.hitIds || [];
      p.hitIds.push(target);
      this.damageZombie(target, p.damage);
      this.applyProjectileStatuses(target, p);
      this.spark(p.x, p.y, '#ffd08a', 5);
      p.hitsLeft = (p.hitsLeft || 1) - 1;
      if (p.hitsLeft > 0) {
        const next = this.nearestZombies(p.x, p.y, 1, new Set(p.hitIds));
        if (next[0]) {
          p.target = next[0];
          return;
        }
      }
      p.dead = true;
      return;
    }
    p.x += (dx / d) * p.speed * dt;
    p.y += (dy / d) * p.speed * dt;
    if (Math.random() < dt * 24) {
      this.particles.push({
        x: p.x, y: p.y, vx: (Math.random() - 0.5) * 16, vy: -12 - Math.random() * 16,
        life: 0.35, maxLife: 0.35, size: 1.8 + Math.random() * 1.4,
        color: '#ffb45e', kind: 'circle'
      });
    }
    for (const z of this.zombies) {
      if (!z.dying || Math.hypot(z.x - p.x, z.y - 24 - p.y) > 22) continue;
      p.dead = true;
      return;
    }
  }

  updateLob(p, dt) {
    if (this.aliveZombie(p.target)) {
      p.tx = p.target.x;
      p.ty = p.target.y - 14;
    }
    p.t += dt;
    const k = Math.min(1, p.t / p.flight);
    p.x = p.sx + (p.tx - p.sx) * k;
    const base = p.sy + (p.ty - p.sy) * k;
    p.y = base - 108 * 4 * k * (1 - k);
    if (k < 1) return;
    p.dead = true;
    let hit = null;
    for (const z of this.zombies) {
      if (!this.aliveZombie(z) || z.row !== p.row) continue;
      if (!hit || Math.abs(z.x - p.tx) < Math.abs(hit.x - p.tx)) hit = z;
    }
    if (!hit || Math.abs(hit.x - p.tx) > 54) {
      for (const z of this.zombies) {
        if (!z.dying || z.row !== p.row) continue;
        if (Math.abs(z.x - p.tx) <= 34) break;
      }
      this.spark(p.x, p.y, '#e8d6a8', 4);
      return;
    }
    this.damageZombie(hit, p.damage);
    this.applyProjectileStatuses(hit, p);
    this.spark(p.x, p.y, '#f0dca8', 7);
    this.particles.push({
      x: p.x, y: p.y + 8, vx: 0, vy: 0,
      life: 0.4, maxLife: 0.4, size: 18,
      color: 'rgba(230,210,170,0.5)', kind: 'ring'
    });
  }

  updateProjectiles(dt) {
    for (const p of this.projectiles) {
      if (p.dead) continue;
      if (p.homing) {
        this.updateHoming(p, dt);
        continue;
      }
      if (p.lob) {
        this.updateLob(p, dt);
        continue;
      }
      p.x += p.speed * dt;
      const hit = this.projectileCollision(p);
      if (hit) {
        p.dead = true;
        if (hit.dying) {
          this.spark(p.x, p.y, '#c9bda0', 3);
          continue;
        }
        const large = this.isLarge(hit);
        const dmg = p.knock && large ? p.damage * 2 : p.damage;
        this.damageZombie(hit, dmg, { armorPierce: !!p.pierceArmor });
        this.applyProjectileStatuses(hit, p);
        if (p.knock && !large && this.aliveZombie(hit)) {
          hit.x = Math.min(1360, hit.x + p.knock * BOARD.cw);
          this.particles.push({
            x: hit.x, y: hit.y + 8, vx: 0, vy: 0,
            life: 0.4, maxLife: 0.4, size: 18,
            color: 'rgba(200,180,140,0.65)', kind: 'ring'
          });
        }
        this.spark(
          p.x, p.y,
          p.needle ? '#f6f1de' : p.star ? '#ffe08a' : p.big ? '#ffe9a8' : p.gravel ? '#b9a98c' : '#f0dca8',
          p.big ? 8 : 3
        );
      } else if (p.x > 1340) {
        p.dead = true;
      }
    }
  }

  damageZombie(z, amount, opts = {}) {
    if (!this.aliveZombie(z)) return 0;
    const pan = Math.max(-1, Math.min(1, (z.x - 640) / 640));
    if (!opts.silent && amount >= 8) audio.sfx('hit', { type: z.type, pan });
    let dmg = amount;
    if (z.vulnT > 0 && z.vuln > 0) dmg *= 1 + z.vuln;
    let dealt = 0;
    if (!opts.armorPierce && z.armor > 0) {
      const absorbed = Math.min(z.armor, dmg);
      z.armor -= absorbed;
      dmg -= absorbed;
      dealt += absorbed;
      if (z.armor <= 0) this.breakArmor(z);
    }
    if (dmg > 0) {
      z.hp -= dmg;
      dealt += dmg;
    }
    z.hurt = 0.14;
    if (z.hp <= 0) this.killZombie(z);
    return dealt;
  }

  breakArmor(z) {
    const pan = Math.max(-1, Math.min(1, (z.x - 640) / 640));
    audio.sfx('shell', { pan });
    const colors = {
      paper: '#efe6cf', sedan: '#c77a55', straw: '#d7b26a',
      stonehat: '#a8a69a', urn: '#b07a4e', bucket: '#9aa4a6', mask: '#7d858a', charm: '#e5d6a4'
    };
    const color = colors[z.armorType] || '#efe6cf';
    for (let i = 0; i < 10; i++) {
      this.particles.push({
        x: z.x + (Math.random() - 0.5) * 28,
        y: z.y - 24 - Math.random() * 22,
        vx: (Math.random() - 0.5) * 140,
        vy: -40 - Math.random() * 100,
        life: 0.55, maxLife: 0.75,
        size: 3 + Math.random() * 5,
        color, kind: z.armorType === 'paper' || z.armorType === 'charm' ? 'shard' : 'circle'
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

  killZombie(z) {
    if (!this.aliveZombie(z)) return;
    z.dying = true;
    z.deathT = 0;
    z.hp = 0;
    z.eating = false;
    z.stunT = 0;
    z.breached = true;
    audio.sfx('zombieDie', { pan: Math.max(-1, Math.min(1, (z.x - 640) / 640)) });
    this.kills += 1;
    const color =
      z.type === 'mountain' ? '#5a4030'
        : z.type === 'paper' ? '#efe6cf'
          : z.type === 'mourner' ? '#d8d2c4'
            : z.type === 'sedan' ? '#a83a2e'
              : z.type === 'tongue' ? '#87a87d'
                : z.type === 'straw' ? '#c9a45e'
                  : z.type === 'stonehat' ? '#9a978b'
                    : z.type === 'bucket' ? '#8f999b'
                      : z.type === 'vault' ? '#a98252'
                        : z.type === 'artisan' ? '#e8ddc1'
                          : z.type === 'ironjudge' ? '#6f7679'
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
    if (z.def.large) this.shake = Math.max(this.shake, 5);
  }

  killPlant(p, silent = false) {
    if (p.dead) return;
    p.dead = true;
    p.shell = null;
    this.cells[p.r][p.c] = null;
    if (p.type !== 'wall' || silent) {
      audio.sfx('plantDown', { pan: Math.max(-1, Math.min(1, (p.x - 640) / 640)) });
    }
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
        if (this.aliveZombie(z) && z.row === m.row && Math.abs(z.x - m.x) < 56) {
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
        if (this.settings.autoCollect && !this.tutorial) {
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
      tutorial: this.tutorial ? {
        step: this.tutorial.step,
        shooter: !!this.tutorial.shooter,
        zombie: !!this.tutorial.zombie
      } : null,
      levelThreat: this.levelThreat,
      levelCountMul: this.levelCountMul,
      levelHpMul: this.levelHpMul,
      cleared: [...this.progress.cleared]
    };
  }
}
