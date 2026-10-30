const mtof = (m) => 440 * Math.pow(2, (m - 69) / 12);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

const noiseCache = new WeakMap();

function getNoise(ctx) {
  if (!noiseCache.has(ctx)) {
    const len = Math.floor(ctx.sampleRate * 2);
    const buf = ctx.createBuffer(1, len, ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    noiseCache.set(ctx, buf);
  }
  return noiseCache.get(ctx);
}

function makeImpulse(ctx, seconds) {
  const len = Math.floor(ctx.sampleRate * seconds);
  const buf = ctx.createBuffer(2, len, ctx.sampleRate);
  for (let ch = 0; ch < 2; ch++) {
    const d = buf.getChannelData(ch);
    for (let i = 0; i < len; i++) {
      d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 2.6);
    }
  }
  return buf;
}

function withPan(ctx, node, dest, pan) {
  if (ctx.createStereoPanner) {
    const p = ctx.createStereoPanner();
    p.pan.value = clamp(pan || 0, -1, 1);
    node.connect(p);
    p.connect(dest);
  } else {
    node.connect(dest);
  }
}

function tone(ctx, dest, time, freq, dur, gain, type = 'sine', pan = 0, attack = 0.006, endFreq = null) {
  const o = ctx.createOscillator();
  o.type = type;
  o.frequency.setValueAtTime(Math.max(20, freq), time);
  if (endFreq) o.frequency.exponentialRampToValueAtTime(Math.max(20, endFreq), time + dur * 0.85);
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, time);
  g.gain.linearRampToValueAtTime(gain, time + Math.min(attack, dur * 0.4));
  g.gain.exponentialRampToValueAtTime(0.0001, time + dur);
  o.connect(g);
  withPan(ctx, g, dest, pan);
  o.start(time);
  o.stop(time + dur + 0.04);
}

function noiseBurst(ctx, dest, time, dur, gain, type = 'bandpass', freq = 1200, endFreq = freq, q = 0.8, pan = 0) {
  const src = ctx.createBufferSource();
  src.buffer = getNoise(ctx);
  src.loop = true;
  const f = ctx.createBiquadFilter();
  f.type = type;
  f.Q.value = q;
  f.frequency.setValueAtTime(Math.max(30, freq), time);
  f.frequency.exponentialRampToValueAtTime(Math.max(30, endFreq), time + dur * 0.9);
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, time);
  g.gain.linearRampToValueAtTime(gain, time + Math.min(0.005, dur * 0.3));
  g.gain.exponentialRampToValueAtTime(0.0001, time + dur);
  src.connect(f);
  f.connect(g);
  withPan(ctx, g, dest, pan);
  src.start(time, Math.random() * 1.5);
  src.stop(time + dur + 0.04);
}

function pluck(ctx, dest, time, freq, dur = 0.4, gain = 0.06, pan = 0) {
  const f = ctx.createBiquadFilter();
  f.type = 'lowpass';
  f.Q.value = 0.8;
  f.frequency.setValueAtTime(2600, time);
  f.frequency.exponentialRampToValueAtTime(600, time + dur);
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, time);
  g.gain.linearRampToValueAtTime(gain, time + 0.004);
  g.gain.exponentialRampToValueAtTime(0.0001, time + dur);
  const o1 = ctx.createOscillator();
  o1.type = 'triangle';
  o1.frequency.value = freq;
  const o2 = ctx.createOscillator();
  o2.type = 'sawtooth';
  o2.frequency.value = freq;
  o2.detune.value = 5;
  o1.connect(f);
  o2.connect(f);
  f.connect(g);
  withPan(ctx, g, dest, pan);
  o1.start(time);
  o2.start(time);
  o1.stop(time + dur + 0.03);
  o2.stop(time + dur + 0.03);
}

function bell(ctx, dest, time, freq, dur = 1.4, gain = 0.04, pan = 0) {
  const partials = [[1, 1], [2.01, 0.46], [2.98, 0.2], [4.12, 0.11]];
  for (let i = 0; i < partials.length; i++) {
    const [mul, amp] = partials[i];
    tone(ctx, dest, time + i * 0.004, freq * mul, dur * (1 - i * 0.12), gain * amp, 'sine', pan + (i % 2 ? 0.16 : -0.16), 0.004);
  }
}

function padNote(ctx, dest, time, freq, dur, gain, pan = 0) {
  const f = ctx.createBiquadFilter();
  f.type = 'lowpass';
  f.frequency.value = 720;
  f.Q.value = 0.4;
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, time);
  g.gain.linearRampToValueAtTime(gain, time + Math.min(0.5, dur * 0.22));
  g.gain.setValueAtTime(gain, time + dur * 0.72);
  g.gain.exponentialRampToValueAtTime(0.0001, time + dur);
  const a = ctx.createOscillator();
  a.type = 'sawtooth';
  a.frequency.value = freq;
  a.detune.value = -6;
  const b = ctx.createOscillator();
  b.type = 'sawtooth';
  b.frequency.value = freq;
  b.detune.value = 7;
  a.connect(f);
  b.connect(f);
  f.connect(g);
  withPan(ctx, g, dest, pan);
  a.start(time);
  b.start(time);
  a.stop(time + dur + 0.05);
  b.stop(time + dur + 0.05);
}

function bassNote(ctx, dest, time, freq, dur = 0.4, gain = 0.06, pan = 0) {
  const f = ctx.createBiquadFilter();
  f.type = 'lowpass';
  f.frequency.value = 280;
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, time);
  g.gain.linearRampToValueAtTime(gain, time + 0.008);
  g.gain.exponentialRampToValueAtTime(0.0001, time + dur);
  const o = ctx.createOscillator();
  o.type = 'sine';
  o.frequency.value = freq;
  const o2 = ctx.createOscillator();
  o2.type = 'triangle';
  o2.frequency.value = freq;
  o2.detune.value = -4;
  o.connect(f);
  o2.connect(f);
  f.connect(g);
  withPan(ctx, g, dest, pan);
  o.start(time);
  o2.start(time);
  o.stop(time + dur + 0.03);
  o2.stop(time + dur + 0.03);
}

function taiko(ctx, dest, time, gain = 0.08, pan = 0, pitch = 1) {
  const o = ctx.createOscillator();
  o.type = 'sine';
  o.frequency.setValueAtTime(118 * pitch, time);
  o.frequency.exponentialRampToValueAtTime(42 * pitch, time + 0.24);
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, time);
  g.gain.linearRampToValueAtTime(gain, time + 0.005);
  g.gain.exponentialRampToValueAtTime(0.0001, time + 0.36);
  o.connect(g);
  withPan(ctx, g, dest, pan);
  o.start(time);
  o.stop(time + 0.4);
  noiseBurst(ctx, dest, time, 0.07, gain * 0.28, 'lowpass', 420, 180, 0.7, pan);
}

function rim(ctx, dest, time, gain = 0.03, pan = 0) {
  tone(ctx, dest, time, 1760, 0.035, gain, 'triangle', pan, 0.002, 1450);
  noiseBurst(ctx, dest, time, 0.035, gain * 0.45, 'highpass', 2200, 1800, 0.8, pan);
}

function shaker(ctx, dest, time, gain = 0.014, pan = 0) {
  noiseBurst(ctx, dest, time, 0.055, gain, 'highpass', 5200, 7200, 0.7, pan);
}

function gong(ctx, dest, time, gain = 0.05, pan = 0) {
  tone(ctx, dest, time, 82, 2.2, gain, 'sine', pan, 0.01, 70);
  tone(ctx, dest, time + 0.01, 123, 1.8, gain * 0.55, 'sine', pan + 0.2, 0.01, 108);
  tone(ctx, dest, time + 0.02, 171, 1.4, gain * 0.3, 'sine', pan - 0.2, 0.01, 150);
  noiseBurst(ctx, dest, time, 1.2, gain * 0.3, 'lowpass', 800, 220, 0.6, pan);
}

function brassStab(ctx, dest, time, freq, dur = 0.22, gain = 0.035, pan = 0) {
  const f = ctx.createBiquadFilter();
  f.type = 'lowpass';
  f.frequency.setValueAtTime(1500, time);
  f.frequency.exponentialRampToValueAtTime(500, time + dur);
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, time);
  g.gain.linearRampToValueAtTime(gain, time + 0.012);
  g.gain.exponentialRampToValueAtTime(0.0001, time + dur);
  const a = ctx.createOscillator();
  a.type = 'sawtooth';
  a.frequency.value = freq;
  a.detune.value = -5;
  const b = ctx.createOscillator();
  b.type = 'square';
  b.frequency.value = freq;
  b.detune.value = 5;
  a.connect(f);
  b.connect(f);
  f.connect(g);
  withPan(ctx, g, dest, pan);
  a.start(time);
  b.start(time);
  a.stop(time + dur + 0.03);
  b.stop(time + dur + 0.03);
}

function riser(ctx, dest, time, dur = 0.8, gain = 0.08, pan = 0) {
  noiseBurst(ctx, dest, time, dur, gain, 'bandpass', 240, 4200, 1.2, pan);
}

const MENU_CHORDS = [
  [50, 53, 57],
  [46, 50, 53],
  [41, 45, 48],
  [48, 52, 55],
  [50, 53, 57],
  [43, 46, 50],
  [46, 50, 53],
  [45, 48, 52]
];

const MENU_MEL = [
  [[0, 74], [3, 77], [6, 81], [8, 79], [11, 77], [14, 74]],
  [[0, 77], [4, 81], [8, 84], [12, 81], [14, 79]],
  [[0, 77], [3, 81], [6, 84], [8, 86], [11, 84], [14, 81]],
  [[0, 79], [4, 77], [8, 74], [12, 72], [14, 74]],
  [[0, 74], [3, 77], [6, 81], [8, 84], [11, 81], [14, 79]],
  [[0, 77], [4, 79], [8, 81], [12, 79], [14, 77]],
  [[0, 74], [4, 77], [8, 81], [12, 84], [14, 86]],
  [[0, 81], [4, 79], [8, 77], [12, 74], [14, 72]]
].map((list) => Object.fromEntries(list));

const BATTLE_CHORDS = [
  [50, 53, 57],
  [46, 50, 53],
  [41, 45, 48],
  [48, 52, 55],
  [50, 53, 57],
  [46, 50, 53],
  [43, 46, 50],
  [45, 48, 52]
];

const BATTLE_MEL = [
  [[0, 74], [2, 77], [4, 81], [6, 79], [8, 77], [10, 74], [12, 77], [14, 81]],
  [[0, 77], [2, 81], [4, 84], [6, 81], [8, 79], [10, 77], [12, 74], [14, 77]],
  [[0, 72], [2, 77], [4, 81], [6, 84], [8, 81], [10, 79], [12, 77], [14, 74]],
  [[0, 79], [2, 81], [4, 79], [6, 77], [8, 74], [10, 72], [12, 74], [14, 77]],
  [[0, 74], [2, 77], [4, 81], [6, 84], [8, 81], [10, 79], [12, 77], [14, 74]],
  [[0, 77], [2, 79], [4, 81], [6, 84], [8, 86], [10, 84], [12, 81], [14, 79]],
  [[0, 74], [2, 77], [4, 79], [6, 81], [8, 79], [10, 77], [12, 74], [14, 72]],
  [[0, 81], [2, 84], [4, 86], [6, 84], [8, 81], [10, 79], [12, 77], [14, 74]]
].map((list) => Object.fromEntries(list));

const HOT_CHORDS = [
  [50, 53, 57],
  [46, 50, 53],
  [41, 45, 48],
  [45, 49, 52],
  [50, 53, 57],
  [46, 50, 53],
  [43, 46, 50],
  [45, 49, 52]
];

const FINAL_CHORDS = [
  [50, 53, 57],
  [51, 54, 58],
  [46, 50, 53],
  [45, 49, 52],
  [50, 53, 57],
  [51, 54, 58],
  [43, 46, 50],
  [45, 49, 52]
];

const TRACKS = {
  menu: {
    bpm: 74,
    bars: 8,
    volume: 0.82,
    step(ctx, out, i, time) {
      const beat = 60 / this.bpm;
      const bar = Math.floor(i / 16) % this.bars;
      const s = i % 16;
      const chord = MENU_CHORDS[bar];
      if (s === 0) {
        chord.forEach((m, k) => padNote(ctx, out, time, mtof(m + 12), beat * 4.2, 0.022, k % 2 ? 0.22 : -0.22));
        bassNote(ctx, out, time, mtof(chord[0] - 12), beat * 2.4, 0.07);
        taiko(ctx, out, time, 0.03, -0.12, 0.78);
      }
      if (s === 8) {
        bassNote(ctx, out, time, mtof(chord[0] - 5), beat * 1.4, 0.042);
        taiko(ctx, out, time, 0.018, 0.08, 0.72);
      }
      if (s === 4 || s === 12) shaker(ctx, out, time, 0.012, s === 4 ? -0.3 : 0.3);
      const n = MENU_MEL[bar][s];
      if (n) pluck(ctx, out, time, mtof(n), 0.48, 0.055, s % 2 ? 0.14 : -0.14);
      if (s === 0 && bar % 4 === 0) bell(ctx, out, time, mtof(chord[2] + 24), 1.7, 0.024, 0.3);
    }
  },
  battle: {
    bpm: 112,
    bars: 8,
    volume: 0.9,
    step(ctx, out, i, time) {
      const beat = 60 / this.bpm;
      const bar = Math.floor(i / 16) % this.bars;
      const s = i % 16;
      const chord = BATTLE_CHORDS[bar];
      if (s === 0) {
        chord.forEach((m, k) => padNote(ctx, out, time, mtof(m + 12), beat * 3.9, 0.021, k % 2 ? 0.25 : -0.25));
        taiko(ctx, out, time, 0.075, -0.1, 0.92);
      }
      if (s === 6 || s === 14) taiko(ctx, out, time, 0.05, 0.12, 0.78);
      if (s === 8) taiko(ctx, out, time, 0.055, 0.05, 0.88);
      if (s === 4 || s === 12) rim(ctx, out, time, 0.03, s === 4 ? -0.28 : 0.28);
      if (s % 2 === 0) shaker(ctx, out, time, 0.012, s % 4 ? 0.22 : -0.22);
      if (s === 0 || s === 3 || s === 6 || s === 8 || s === 11 || s === 14) {
        const lift = s === 6 || s === 14 ? 7 : 0;
        bassNote(ctx, out, time, mtof(chord[0] - 12 + lift), 0.23, 0.055);
      }
      const n = BATTLE_MEL[bar][s];
      if (n) pluck(ctx, out, time, mtof(n), 0.3, 0.05, s % 4 ? 0.12 : -0.12);
      if (s === 0 && bar % 4 === 0) bell(ctx, out, time, mtof(chord[2] + 24), 1.2, 0.022, 0.25);
    }
  },
  hot: {
    bpm: 136,
    bars: 8,
    volume: 0.98,
    step(ctx, out, i, time) {
      const beat = 60 / this.bpm;
      const bar = Math.floor(i / 16) % this.bars;
      const s = i % 16;
      const chord = HOT_CHORDS[bar];
      if (s === 0) {
        chord.forEach((m, k) => padNote(ctx, out, time, mtof(m + 12), beat * 3.8, 0.024, k % 2 ? 0.28 : -0.28));
        gong(ctx, out, time, bar % 4 === 0 ? 0.032 : 0.018, -0.1);
      }
      if (s === 0 || s === 4 || s === 8 || s === 12) taiko(ctx, out, time, 0.09, s % 8 ? 0.12 : -0.12, 1.02);
      if (s === 6 || s === 14) taiko(ctx, out, time, 0.045, 0.2, 0.82);
      if (s === 2 || s === 6 || s === 10) rim(ctx, out, time, 0.035, s === 6 ? 0.25 : -0.25);
      if (s % 2 === 0) shaker(ctx, out, time, 0.015, s % 4 ? 0.28 : -0.28);
      if (s % 2 === 0) {
        const idx = (s / 2 + bar) % chord.length;
        bassNote(ctx, out, time, mtof(chord[0] - 12 + (s % 8 === 0 ? 0 : 12)), 0.18, 0.06);
        pluck(ctx, out, time, mtof(chord[idx] + 24), 0.2, 0.04, s % 4 ? 0.18 : -0.18);
      }
      if (s === 0 || s === 7 || s === 10) bell(ctx, out, time, mtof(chord[2] + 24), 0.7, 0.018, 0.2);
      if (s === 15) brassStab(ctx, out, time, mtof(chord[0] + 12), 0.16, 0.026, -0.1);
    }
  },
  final: {
    bpm: 152,
    bars: 8,
    volume: 1.02,
    step(ctx, out, i, time) {
      const beat = 60 / this.bpm;
      const bar = Math.floor(i / 16) % this.bars;
      const s = i % 16;
      const chord = FINAL_CHORDS[bar];
      if (s === 0) {
        bassNote(ctx, out, time, mtof(chord[0] - 24), beat * 4.1, 0.085);
        chord.forEach((m, k) => padNote(ctx, out, time, mtof(m + 12), beat * 3.9, 0.02, k % 2 ? 0.3 : -0.3));
        gong(ctx, out, time, bar % 4 === 0 ? 0.055 : 0.025, 0.1);
        noiseBurst(ctx, out, time, 0.5, 0.045, 'highpass', 2600, 1800, 0.7, -0.2);
      }
      if (s === 0 || s === 4 || s === 8 || s === 12) taiko(ctx, out, time, 0.12, s % 8 ? 0.14 : -0.14, 1.02);
      if (s === 6 || s === 14) taiko(ctx, out, time, 0.065, 0.2, 0.8);
      if (s === 2 || s === 10) rim(ctx, out, time, 0.04, -0.25);
      if (s % 2 === 0) shaker(ctx, out, time, 0.018, s % 4 ? 0.3 : -0.3);
      if (s === 0 || s === 6 || s === 8 || s === 14) {
        brassStab(ctx, out, time, mtof(chord[0] + 12), 0.26, 0.04, -0.15);
        brassStab(ctx, out, time + 0.012, mtof(chord[1] + 12), 0.24, 0.028, 0.15);
      }
      if (s % 2 === 0) {
        const idx = (s / 2 + bar * 2) % chord.length;
        bassNote(ctx, out, time, mtof(chord[0] - 12 + (s % 8 === 0 ? 0 : 7)), 0.14, 0.05);
        pluck(ctx, out, time, mtof(chord[idx] + 24 + 12), 0.16, 0.045, s % 4 ? 0.22 : -0.22);
      }
      if (s === 0 && bar % 2 === 0) bell(ctx, out, time, mtof(chord[2] + 24), 1.1, 0.026, 0.3);
    }
  }
};

class AudioEngine {
  constructor() {
    this.ctx = null;
    this.master = null;
    this.comp = null;
    this.analyser = null;
    this.musicIn = null;
    this.musicFilter = null;
    this.musicGain = null;
    this.sfxGain = null;
    this.track = 'menu';
    this.step = 0;
    this.nextTime = 0;
    this.timer = null;
    this.started = false;
    this.trackToken = 0;
    this.duck = new Set();
    this.last = Object.create(null);
    this.lastHit = 0;
    this.lastEat = 0;
    this.lastClick = 0;
    this.muted = false;
  }

  setMuted(muted) {
    const next = !!muted;
    if (next === this.muted) return;
    this.muted = next;
    if (this.master && this.ctx) {
      const now = this.ctx.currentTime;
      this.master.gain.cancelScheduledValues(now);
      this.master.gain.setTargetAtTime(next ? 0.0001 : 0.86, now, 0.05);
    }
  }

  init() {
    if (this.ctx) return;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    const ctx = new AC();
    this.ctx = ctx;
    this.master = ctx.createGain();
    this.master.gain.value = this.muted ? 0.0001 : 0.86;
    this.comp = ctx.createDynamicsCompressor();
    this.comp.threshold.value = -18;
    this.comp.knee.value = 14;
    this.comp.ratio.value = 4;
    this.comp.attack.value = 0.004;
    this.comp.release.value = 0.22;
    this.master.connect(this.comp);
    this.comp.connect(ctx.destination);
    this.analyser = ctx.createAnalyser();
    this.analyser.fftSize = 512;
    this.comp.connect(this.analyser);

    this.sfxGain = ctx.createGain();
    this.sfxGain.gain.value = 0.8;
    this.sfxGain.connect(this.master);

    this.musicIn = ctx.createGain();
    this.musicFilter = ctx.createBiquadFilter();
    this.musicFilter.type = 'lowpass';
    this.musicFilter.frequency.value = 12000;
    this.musicFilter.Q.value = 0.4;
    this.musicGain = ctx.createGain();
    this.musicGain.gain.value = 0.0001;
    const dry = ctx.createGain();
    dry.gain.value = 0.86;
    this.musicIn.connect(dry);
    dry.connect(this.musicFilter);
    const send = ctx.createGain();
    send.gain.value = 0.16;
    const conv = ctx.createConvolver();
    conv.buffer = makeImpulse(ctx, 2.4);
    this.musicIn.connect(send);
    send.connect(conv);
    conv.connect(this.musicFilter);
    this.musicFilter.connect(this.musicGain);
    this.musicGain.connect(this.master);

    this.step = 0;
    this.nextTime = ctx.currentTime + 0.12;
    this.started = true;
    this.timer = setInterval(() => this.tick(), 90);
    this.applyMusicGain(1.2);
  }

  async unlock() {
    this.init();
    if (!this.ctx) return;
    if (this.ctx.state === 'suspended') {
      try {
        await this.ctx.resume();
      } catch {
        return;
      }
    }
    if (this.ctx.state === 'running') this.applyMusicGain(0.8);
  }

  setSuspended(suspended) {
    if (!this.ctx) return;
    if (suspended) {
      this.ctx.suspend().catch(() => {});
    } else {
      this.ctx.resume().then(() => {
        this.nextTime = this.ctx.currentTime + 0.12;
      }).catch(() => {});
    }
  }

  trackBase() {
    return (TRACKS[this.track]?.volume ?? 0.6) * 1.05;
  }

  applyMusicGain(fade = 0.4) {
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    const ducked = this.duck.size > 0;
    const target = this.trackBase() * (ducked ? 0.24 : 1);
    this.musicGain.gain.cancelScheduledValues(now);
    this.musicGain.gain.setTargetAtTime(target, now, Math.max(0.03, fade / 3));
    this.musicFilter.frequency.cancelScheduledValues(now);
    this.musicFilter.frequency.setTargetAtTime(ducked ? 620 : 12000, now, 0.18);
  }

  setDuck(source, on) {
    if (typeof source !== 'string') return;
    const has = this.duck.has(source);
    if (on && !has) {
      this.duck.add(source);
      this.applyMusicGain(0.3);
    } else if (!on && has) {
      this.duck.delete(source);
      this.applyMusicGain(0.5);
    }
  }

  setTrack(id) {
    if (!TRACKS[id] || id === this.track) return;
    this.track = id;
    this.step = 0;
    this.trackToken += 1;
    const token = this.trackToken;
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    this.nextTime = now + 0.25;
    this.musicGain.gain.cancelScheduledValues(now);
    this.musicGain.gain.setTargetAtTime(0.0001, now, 0.07);
    setTimeout(() => {
      if (token !== this.trackToken || !this.ctx) return;
      this.step = 0;
      this.nextTime = this.ctx.currentTime + 0.05;
      this.applyMusicGain(0.55);
    }, 250);
  }

  tick() {
    if (!this.ctx || this.ctx.state !== 'running' || !this.started) return;
    const now = this.ctx.currentTime;
    const track = TRACKS[this.track];
    if (!track) return;
    if (this.nextTime < now - 0.35) this.nextTime = now + 0.04;
    const stepDur = 60 / track.bpm / 4;
    let guard = 0;
    while (this.nextTime < now + 0.28 && guard < 64) {
      track.step(this.ctx, this.musicIn, this.step, this.nextTime);
      this.step = (this.step + 1) % (track.bars * 16);
      this.nextTime += stepDur;
      guard += 1;
    }
  }

  sfx(name, opts = {}) {
    if (this.muted || !this.ctx || this.ctx.state !== 'running') return;
    const now = this.ctx.currentTime;
    const time = now + 0.005;
    const pan = clamp(opts.pan ?? 0, -1, 1);
    const out = this.sfxGain;
    const gate = {
      click: 0.03,
      hit: 0.045,
      eat: 0.11,
      collect: 0.02,
      zombieDie: 0.035
    }[name] || 0;
    if (gate && now - (this.last[name] || 0) < gate) return;
    if (gate) this.last[name] = now;

    switch (name) {
      case 'click':
        tone(this.ctx, out, time, 980, 0.045, 0.06, 'sine', pan, 0.002, 720);
        noiseBurst(this.ctx, out, time, 0.025, 0.03, 'highpass', 2600, 2200, 0.8, pan);
        break;
      case 'place':
        tone(this.ctx, out, time, 170, 0.16, 0.09, 'sine', pan, 0.004, 72);
        noiseBurst(this.ctx, out, time, 0.12, 0.04, 'lowpass', 680, 260, 0.8, pan);
        break;
      case 'collect':
        bell(this.ctx, out, time, 1180, 0.3, 0.022, pan);
        tone(this.ctx, out, time + 0.02, 1770, 0.18, 0.012, 'sine', pan);
        break;
      case 'upgrade':
        bell(this.ctx, out, time, 880, 0.5, 0.03, pan);
        bell(this.ctx, out, time + 0.09, 1320, 0.45, 0.022, pan);
        break;
      case 'shoot':
        noiseBurst(this.ctx, out, time, 0.07, 0.04, 'bandpass', 1600, 520, 1.1, pan);
        tone(this.ctx, out, time, 540, 0.07, 0.03, 'triangle', pan, 0.002, 240);
        break;
      case 'produce':
        bell(this.ctx, out, time, 760, 0.35, 0.025, pan);
        bell(this.ctx, out, time + 0.04, 1140, 0.3, 0.016, pan);
        break;
      case 'bell':
        bell(this.ctx, out, time, 660, 0.6, 0.032, pan);
        bell(this.ctx, out, time + 0.015, 990, 0.55, 0.02, pan);
        noiseBurst(this.ctx, out, time, 0.04, 0.025, 'highpass', 3000, 2400, 1, pan);
        break;
      case 'censer':
        noiseBurst(this.ctx, out, time, 0.5, 0.055, 'lowpass', 950, 240, 0.8, pan);
        tone(this.ctx, out, time, 92, 0.4, 0.035, 'sine', pan, 0.02, 66);
        break;
      case 'umbrella':
        noiseBurst(this.ctx, out, time, 0.2, 0.04, 'bandpass', 2100, 900, 1.2, pan);
        tone(this.ctx, out, time, 520, 0.13, 0.018, 'triangle', pan, 0.003, 760);
        break;
      case 'lion':
        taiko(this.ctx, out, time, 0.075, pan, 0.75);
        tone(this.ctx, out, time, 118, 0.18, 0.035, 'sawtooth', pan, 0.004, 61);
        noiseBurst(this.ctx, out, time, 0.14, 0.035, 'lowpass', 560, 230, 0.7, pan);
        break;
      case 'explode':
        noiseBurst(this.ctx, out, time, 0.7, 0.2, 'lowpass', 1800, 70, 0.65, pan);
        tone(this.ctx, out, time, 72, 0.6, 0.14, 'sine', pan, 0.003, 30);
        noiseBurst(this.ctx, out, time + 0.03, 0.25, 0.06, 'highpass', 1800, 700, 0.8, pan);
        break;
      case 'wall':
        noiseBurst(this.ctx, out, time, 0.3, 0.08, 'lowpass', 520, 140, 0.8, pan);
        tone(this.ctx, out, time, 82, 0.3, 0.07, 'sine', pan, 0.004, 38);
        break;
      case 'shell':
        noiseBurst(this.ctx, out, time, 0.2, 0.055, 'highpass', 1200, 2600, 0.8, pan);
        bell(this.ctx, out, time, 1800, 0.22, 0.018, pan);
        break;
      case 'hit': {
        const type = opts.type || 'ghost';
        if (type === 'paper') {
          noiseBurst(this.ctx, out, time, 0.065, 0.045, 'highpass', 1900, 3000, 0.9, pan);
          tone(this.ctx, out, time, 340, 0.05, 0.018, 'triangle', pan, 0.002, 220);
        } else if (type === 'mountain' || type === 'sedan') {
          tone(this.ctx, out, time, 135, 0.1, 0.045, 'sine', pan, 0.003, 58);
          noiseBurst(this.ctx, out, time, 0.06, 0.03, 'lowpass', 620, 220, 0.8, pan);
        } else if (type === 'mourner') {
          tone(this.ctx, out, time, 880, 0.13, 0.022, 'sine', pan, 0.004, 320);
          noiseBurst(this.ctx, out, time, 0.08, 0.025, 'bandpass', 1200, 700, 1.1, pan);
        } else {
          noiseBurst(this.ctx, out, time, 0.055, 0.035, 'bandpass', 900, 480, 0.9, pan);
          tone(this.ctx, out, time, 215, 0.07, 0.02, 'triangle', pan, 0.002, 140);
        }
        break;
      }
      case 'zombieDie':
        tone(this.ctx, out, time, 230, 0.3, 0.035, 'sawtooth', pan, 0.004, 65);
        noiseBurst(this.ctx, out, time, 0.22, 0.035, 'lowpass', 500, 140, 0.7, pan);
        break;
      case 'eat':
        if (opts.plant === 'wall') {
          noiseBurst(this.ctx, out, time, 0.085, 0.055, 'lowpass', 800, 320, 0.7, pan);
        } else {
          noiseBurst(this.ctx, out, time, 0.07, 0.04, 'bandpass', 1400, 700, 1, pan);
          tone(this.ctx, out, time, 135, 0.055, 0.024, 'triangle', pan, 0.002, 92);
        }
        break;
      case 'deny':
        tone(this.ctx, out, time, 160, 0.11, 0.035, 'square', pan, 0.002, 118);
        tone(this.ctx, out, time + 0.08, 138, 0.12, 0.022, 'square', pan, 0.002, 96);
        break;
      case 'alert':
        bell(this.ctx, out, time, 330, 0.9, 0.045, pan);
        bell(this.ctx, out, time + 0.02, 220, 1.1, 0.04, pan);
        noiseBurst(this.ctx, out, time, 0.3, 0.025, 'lowpass', 900, 260, 0.7, pan);
        break;
      case 'wave':
        tone(this.ctx, out, time, 116, 0.5, 0.04, 'sawtooth', pan, 0.02, 82);
        tone(this.ctx, out, time + 0.01, 174, 0.42, 0.018, 'triangle', pan, 0.02, 120);
        taiko(this.ctx, out, time, 0.045, pan, 0.75);
        break;
      case 'cinemaStart':
        gong(this.ctx, out, time, 0.03, pan);
        riser(this.ctx, out, time + 0.1, 0.7, 0.035, pan);
        break;
      case 'reveal':
        riser(this.ctx, out, time, 0.9, 0.06, pan);
        gong(this.ctx, out, time + 0.15, 0.035, pan);
        break;
      case 'start':
        tone(this.ctx, out, time, 110, 0.5, 0.045, 'sawtooth', pan, 0.02, 165);
        gong(this.ctx, out, time, 0.025, pan);
        break;
      case 'win':
        [74, 77, 81, 84, 86].forEach((m, i) => pluck(this.ctx, out, time + i * 0.12, mtof(m), 0.6, 0.05, (i % 2 ? 0.2 : -0.2)));
        bell(this.ctx, out, time + 0.62, mtof(86), 1.3, 0.035, 0.1);
        break;
      case 'lose':
        gong(this.ctx, out, time, 0.05, pan);
        tone(this.ctx, out, time + 0.1, mtof(45), 1.6, 0.03, 'sine', pan, 0.01, mtof(33));
        break;
      case 'mower':
        noiseBurst(this.ctx, out, time, 0.4, 0.06, 'bandpass', 1800, 420, 1, pan);
        bell(this.ctx, out, time + 0.05, 780, 0.5, 0.025, pan);
        break;
      case 'plantDown':
        noiseBurst(this.ctx, out, time, 0.2, 0.04, 'lowpass', 1100, 280, 0.8, pan);
        tone(this.ctx, out, time, 180, 0.18, 0.025, 'triangle', pan, 0.003, 70);
        break;
      default:
        break;
    }
  }

  async renderPreviewStats(trackId = 'menu', seconds = 6) {
    const AC = window.OfflineAudioContext || window.webkitOfflineAudioContext;
    if (!AC || !TRACKS[trackId]) return null;
    const sr = 44100;
    const ctx = new AC(2, Math.floor(sr * seconds), sr);
    const out = ctx.createGain();
    out.gain.value = 0.7;
    out.connect(ctx.destination);
    const track = TRACKS[trackId];
    const stepDur = 60 / track.bpm / 4;
    const total = track.bars * 16;
    const steps = Math.ceil(seconds / stepDur);
    for (let i = 0; i < steps; i++) {
      track.step(ctx, out, i % total, 0.05 + i * stepDur);
    }
    const buffer = await ctx.startRendering();
    let peak = 0;
    let sum = 0;
    let count = 0;
    for (let ch = 0; ch < buffer.numberOfChannels; ch++) {
      const d = buffer.getChannelData(ch);
      for (let i = 0; i < d.length; i++) {
        const v = d[i];
        if (Math.abs(v) > peak) peak = Math.abs(v);
        sum += v * v;
        count += 1;
      }
    }
    return {
      track: trackId,
      seconds,
      peak: +peak.toFixed(3),
      rms: +Math.sqrt(sum / count).toFixed(4)
    };
  }

  readRms() {
    if (!this.analyser) return 0;
    const arr = new Float32Array(this.analyser.fftSize);
    this.analyser.getFloatTimeDomainData(arr);
    let sum = 0;
    for (let i = 0; i < arr.length; i++) sum += arr[i] * arr[i];
    return Math.sqrt(sum / arr.length);
  }

  debug() {
    return {
      state: this.ctx ? this.ctx.state : 'none',
      track: this.track,
      step: this.step,
      duck: [...this.duck],
      gain: this.musicGain ? +this.musicGain.gain.value.toFixed(3) : 0,
      rms: +this.readRms().toFixed(4)
    };
  }
}

export const audio = new AudioEngine();
