const PREFIX = 'yaoguai-nightmarket.';
const SETTINGS_KEY = PREFIX + 'settings.v1';
const SAVE_KEY = PREFIX + 'save.v1';
const RECORDS_KEY = PREFIX + 'records.v1';
const PROGRESS_KEY = PREFIX + 'progress.v1';
const LOADOUT_KEY = PREFIX + 'loadout.v1';

function read(key) {
  try {
    const raw = window.localStorage.getItem(key);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function write(key, value) {
  try {
    window.localStorage.setItem(key, JSON.stringify(value));
    return true;
  } catch {
    return false;
  }
}

function remove(key) {
  try {
    window.localStorage.removeItem(key);
  } catch {
    // ignore
  }
}

export function loadSettings(defaults) {
  const payload = read(SETTINGS_KEY);
  if (!payload || payload.v !== 1 || !payload.settings) return { ...defaults };
  const s = payload.settings;
  const out = { ...defaults };
  if ([1, 1.5, 2, 3].includes(s.speed)) out.speed = s.speed;
  if (typeof s.autoCollect === 'boolean') out.autoCollect = s.autoCollect;
  if (s.collectDelay === 0 || s.collectDelay === 3) out.collectDelay = s.collectDelay;
  if (typeof s.quickWave === 'boolean') out.quickWave = s.quickWave;
  if (['off', 'bar', 'barText'].includes(s.healthBars)) out.healthBars = s.healthBars;
  if (['easy', 'normal', 'hard'].includes(s.difficulty)) out.difficulty = s.difficulty;
  if (typeof s.cheats === 'boolean') out.cheats = s.cheats;
  if (typeof s.sound === 'boolean') out.sound = s.sound;
  if (['auto', '720', '1080', '1600'].includes(s.resolution)) out.resolution = s.resolution;
  return out;
}

export function saveSettings(settings) {
  write(SETTINGS_KEY, { v: 1, settings });
}

export function saveRun(run) {
  const payload = { v: 1, savedAt: Date.now(), run };
  if (!write(SAVE_KEY, payload)) return null;
  return payload;
}

export function loadSave() {
  const payload = read(SAVE_KEY);
  if (!payload || payload.v !== 1 || !payload.run) return null;
  return payload;
}

export function clearSave() {
  remove(SAVE_KEY);
}

export function loadRecords(defaults) {
  const payload = read(RECORDS_KEY);
  if (!payload || payload.v !== 1 || !payload.records) return { ...defaults };
  const r = payload.records;
  const out = { ...defaults };
  if (Number.isFinite(r.bestWave)) out.bestWave = Math.max(0, Math.floor(r.bestWave));
  if (Number.isFinite(r.bestKills)) out.bestKills = Math.max(0, Math.floor(r.bestKills));
  if (Number.isFinite(r.wins)) out.wins = Math.max(0, Math.floor(r.wins));
  if (Number.isFinite(r.bestWinTime)) out.bestWinTime = Math.max(0, r.bestWinTime);
  return out;
}

export function saveRecords(records) {
  write(RECORDS_KEY, { v: 1, records });
}

export function loadProgress(defaults) {
  const payload = read(PROGRESS_KEY);
  if (!payload || payload.v !== 1 || !payload.progress) return { ...defaults };
  const p = payload.progress;
  const out = { ...defaults };
  if (Number.isFinite(p.selected)) {
    out.selected = Math.max(1, Math.min(10, Math.floor(p.selected)));
  }
  if (Array.isArray(p.cleared)) {
    out.cleared = p.cleared
      .filter((n) => Number.isFinite(n) && n >= 1 && n <= 10)
      .map((n) => Math.floor(n));
  }
  return out;
}

export function saveProgress(progress) {
  write(PROGRESS_KEY, { v: 1, progress });
}

export function loadLoadout(defaults) {
  const payload = read(LOADOUT_KEY);
  if (!payload || payload.v !== 1 || !Array.isArray(payload.loadout)) {
    return [...defaults];
  }
  return payload.loadout
    .filter((id) => typeof id === 'string')
    .slice(0, 10);
}

export function saveLoadout(loadout) {
  write(LOADOUT_KEY, {
    v: 1,
    loadout: Array.isArray(loadout) ? loadout.slice(0, 10) : []
  });
}
