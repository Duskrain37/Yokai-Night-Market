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

const waveCache = new WeakMap();

const PARTIALS = {
  reed: [1, 0.62, 0.46, 0.38, 0.3, 0.24, 0.18, 0.13, 0.09, 0.06, 0.04, 0.03],
  lowReed: [1, 0.52, 0.3, 0.18, 0.1, 0.06, 0.035, 0.02, 0.012, 0.007, 0.004, 0.002],
  flute: [1, 0.2, 0.1, 0.05, 0.025, 0.012, 0.008, 0.004, 0.003, 0.002, 0.001, 0],
  bowed: [1, 0.7, 0.5, 0.36, 0.26, 0.19, 0.14, 0.1, 0.07, 0.05, 0.035, 0.02],
  pluck: [1, 0.55, 0.34, 0.22, 0.14, 0.09, 0.06, 0.04, 0.025, 0.015, 0.01, 0.005]
};

function periodic(ctx, key) {
  let cache = waveCache.get(ctx);
  if (!cache) {
    cache = new Map();
    waveCache.set(ctx, cache);
  }
  if (cache.has(key)) return cache.get(key);
  const partials = PARTIALS[key] || PARTIALS.flute;
  const n = partials.length + 1;
  const real = new Float32Array(n);
  const imag = new Float32Array(n);
  for (let i = 0; i < partials.length; i++) imag[i + 1] = partials[i];
  const wave = ctx.createPeriodicWave(real, imag, { disableNormalization: false });
  cache.set(key, wave);
  return wave;
}

function envelope(ctx, time, dur, gain, attack = 0.01, hold = 0.85, release = 0.12) {
  const g = ctx.createGain();
  const atk = Math.min(attack, Math.max(0.012, dur * 0.45));
  const rel = Math.min(release, Math.max(0.03, dur * 0.3));
  const sus = Math.max(time + atk, time + dur - rel);
  g.gain.setValueAtTime(0.0001, time);
  g.gain.linearRampToValueAtTime(gain, time + atk);
  g.gain.setValueAtTime(gain * hold, sus);
  g.gain.exponentialRampToValueAtTime(0.0001, time + dur);
  return g;
}

function guqin(ctx, dest, time, freq, dur = 0.9, gain = 0.045, pan = 0, bend = 0) {
  const lp = ctx.createBiquadFilter();
  lp.type = 'lowpass';
  lp.Q.value = 0.85;
  lp.frequency.setValueAtTime(1800, time);
  lp.frequency.exponentialRampToValueAtTime(360, time + dur);
  const g = envelope(ctx, time, dur, gain, 0.005, 0.65, 0.1);
  const a = ctx.createOscillator();
  a.setPeriodicWave(periodic(ctx, 'pluck'));
  a.detune.value = -3;
  a.frequency.setValueAtTime(freq * (1 + bend + 0.006), time);
  a.frequency.exponentialRampToValueAtTime(freq * (1 + bend), time + 0.09);
  const b = ctx.createOscillator();
  b.setPeriodicWave(periodic(ctx, 'pluck'));
  b.detune.value = 5;
  b.frequency.setValueAtTime(freq * (1 + bend + 0.006), time);
  b.frequency.exponentialRampToValueAtTime(freq * (1 + bend), time + 0.09);
  a.connect(lp);
  b.connect(lp);
  lp.connect(g);
  withPan(ctx, g, dest, pan);
  a.start(time);
  b.start(time);
  a.stop(time + dur + 0.04);
  b.stop(time + dur + 0.04);
  noiseBurst(ctx, dest, time, 0.028, gain * 0.2, 'highpass', 2500, 1600, 0.8, pan);
}

function pipa(ctx, dest, time, freq, dur = 0.55, gain = 0.035, pan = 0) {
  const lp = ctx.createBiquadFilter();
  lp.type = 'lowpass';
  lp.Q.value = 0.9;
  lp.frequency.setValueAtTime(4200, time);
  lp.frequency.exponentialRampToValueAtTime(700, time + dur);
  const g = envelope(ctx, time, dur, gain, 0.003, 0.5, 0.08);
  const a = ctx.createOscillator();
  a.setPeriodicWave(periodic(ctx, 'pluck'));
  a.detune.value = -4;
  a.frequency.setValueAtTime(freq * 1.012, time);
  a.frequency.exponentialRampToValueAtTime(freq, time + 0.05);
  const b = ctx.createOscillator();
  b.setPeriodicWave(periodic(ctx, 'pluck'));
  b.detune.value = 6;
  b.frequency.setValueAtTime(freq * 1.012, time);
  b.frequency.exponentialRampToValueAtTime(freq, time + 0.05);
  a.connect(lp);
  b.connect(lp);
  lp.connect(g);
  withPan(ctx, g, dest, pan);
  a.start(time);
  b.start(time);
  a.stop(time + dur + 0.03);
  b.stop(time + dur + 0.03);
  noiseBurst(ctx, dest, time, 0.018, gain * 0.35, 'highpass', 3200, 2200, 0.7, pan);
}

function dizi(ctx, dest, time, freq, dur = 1.4, gain = 0.03, pan = 0) {
  const lp = ctx.createBiquadFilter();
  lp.type = 'lowpass';
  lp.frequency.value = 2800;
  lp.Q.value = 0.6;
  const hp = ctx.createBiquadFilter();
  hp.type = 'highpass';
  hp.frequency.value = 230;
  const g = envelope(ctx, time, dur, gain, 0.1, 0.82, 0.18);
  const o = ctx.createOscillator();
  o.setPeriodicWave(periodic(ctx, 'flute'));
  o.frequency.setValueAtTime(freq * 0.992, time);
  o.frequency.linearRampToValueAtTime(freq, time + 0.12);
  const lfo = ctx.createOscillator();
  lfo.frequency.value = 5.1;
  const lfoGain = ctx.createGain();
  lfoGain.gain.setValueAtTime(0.0001, time);
  lfoGain.gain.linearRampToValueAtTime(freq * 0.006, time + 0.35);
  lfo.connect(lfoGain);
  lfoGain.connect(o.frequency);
  o.connect(hp);
  hp.connect(lp);
  lp.connect(g);
  withPan(ctx, g, dest, pan);
  o.start(time);
  lfo.start(time);
  o.stop(time + dur + 0.05);
  lfo.stop(time + dur + 0.05);
  noiseBurst(ctx, dest, time, Math.min(dur * 0.8, 0.9), gain * 0.24, 'bandpass', freq * 2.1, freq * 1.4, 0.65, pan);
  noiseBurst(ctx, dest, time, 0.05, gain * 0.16, 'highpass', 3000, 2200, 0.8, pan);
}

function xiao(ctx, dest, time, freq, dur = 1.6, gain = 0.026, pan = 0) {
  const lp = ctx.createBiquadFilter();
  lp.type = 'lowpass';
  lp.frequency.value = 1650;
  lp.Q.value = 0.55;
  const hp = ctx.createBiquadFilter();
  hp.type = 'highpass';
  hp.frequency.value = 150;
  const g = envelope(ctx, time, dur, gain, 0.16, 0.8, 0.2);
  const o = ctx.createOscillator();
  o.setPeriodicWave(periodic(ctx, 'flute'));
  o.frequency.setValueAtTime(freq * 0.99, time);
  o.frequency.linearRampToValueAtTime(freq, time + 0.2);
  const lfo = ctx.createOscillator();
  lfo.frequency.value = 4.2;
  const lfoGain = ctx.createGain();
  lfoGain.gain.setValueAtTime(0.0001, time);
  lfoGain.gain.linearRampToValueAtTime(freq * 0.007, time + 0.45);
  lfo.connect(lfoGain);
  lfoGain.connect(o.frequency);
  o.connect(hp);
  hp.connect(lp);
  lp.connect(g);
  withPan(ctx, g, dest, pan);
  o.start(time);
  lfo.start(time);
  o.stop(time + dur + 0.06);
  lfo.stop(time + dur + 0.06);
  noiseBurst(ctx, dest, time, Math.min(dur * 0.85, 1.1), gain * 0.3, 'bandpass', freq * 1.8, freq * 1.25, 0.55, pan);
  noiseBurst(ctx, dest, time, 0.07, gain * 0.12, 'bandpass', 2600, 1800, 0.7, pan);
}

function erhu(ctx, dest, time, freq, dur = 1.6, gain = 0.028, pan = 0) {
  const hp = ctx.createBiquadFilter();
  hp.type = 'highpass';
  hp.frequency.value = 170;
  const body = ctx.createBiquadFilter();
  body.type = 'peaking';
  body.frequency.value = 680;
  body.Q.value = 1.2;
  body.gain.value = 4;
  const lp = ctx.createBiquadFilter();
  lp.type = 'lowpass';
  lp.frequency.value = 2300;
  lp.Q.value = 0.7;
  const g = envelope(ctx, time, dur, gain, 0.13, 0.86, 0.18);
  const a = ctx.createOscillator();
  a.setPeriodicWave(periodic(ctx, 'bowed'));
  a.detune.value = -7;
  a.frequency.setValueAtTime(freq * 0.993, time);
  a.frequency.linearRampToValueAtTime(freq, time + 0.16);
  const b = ctx.createOscillator();
  b.setPeriodicWave(periodic(ctx, 'bowed'));
  b.detune.value = 7;
  b.frequency.setValueAtTime(freq * 0.993, time);
  b.frequency.linearRampToValueAtTime(freq, time + 0.16);
  const lfo = ctx.createOscillator();
  lfo.frequency.value = 5.0;
  const lfoGain = ctx.createGain();
  lfoGain.gain.setValueAtTime(0.0001, time);
  lfoGain.gain.linearRampToValueAtTime(freq * 0.007, time + 0.32);
  lfo.connect(lfoGain);
  lfoGain.connect(a.frequency);
  lfoGain.connect(b.frequency);
  a.connect(hp);
  b.connect(hp);
  hp.connect(body);
  body.connect(lp);
  lp.connect(g);
  withPan(ctx, g, dest, pan);
  a.start(time);
  b.start(time);
  lfo.start(time);
  a.stop(time + dur + 0.06);
  b.stop(time + dur + 0.06);
  lfo.stop(time + dur + 0.06);
  noiseBurst(ctx, dest, time, Math.min(dur * 0.7, 1.2), gain * 0.12, 'bandpass', 2400, 1700, 0.8, pan);
}

function sheng(ctx, dest, time, freq, dur = 1.2, gain = 0.028, pan = 0) {
  const hp = ctx.createBiquadFilter();
  hp.type = 'highpass';
  hp.frequency.value = 220;
  const body = ctx.createBiquadFilter();
  body.type = 'peaking';
  body.frequency.value = 1500;
  body.Q.value = 1.1;
  body.gain.value = 3;
  const lp = ctx.createBiquadFilter();
  lp.type = 'lowpass';
  lp.frequency.value = 3400;
  lp.Q.value = 0.65;
  const g = envelope(ctx, time, dur, gain, 0.075, 0.83, 0.14);
  const a = ctx.createOscillator();
  a.setPeriodicWave(periodic(ctx, 'reed'));
  a.detune.value = -5;
  a.frequency.setValueAtTime(freq * 0.996, time);
  a.frequency.linearRampToValueAtTime(freq, time + 0.08);
  const b = ctx.createOscillator();
  b.setPeriodicWave(periodic(ctx, 'reed'));
  b.detune.value = 6;
  b.frequency.setValueAtTime(freq * 0.996, time);
  b.frequency.linearRampToValueAtTime(freq, time + 0.08);
  a.connect(hp);
  b.connect(hp);
  hp.connect(body);
  body.connect(lp);
  lp.connect(g);
  withPan(ctx, g, dest, pan);
  a.start(time);
  b.start(time);
  a.stop(time + dur + 0.05);
  b.stop(time + dur + 0.05);
  noiseBurst(ctx, dest, time, Math.min(dur * 0.75, 0.8), gain * 0.18, 'bandpass', freq * 3.0, freq * 2.1, 0.6, pan);
}

function lowReed(ctx, dest, time, freq, dur = 2.0, gain = 0.045, pan = 0) {
  const hp = ctx.createBiquadFilter();
  hp.type = 'highpass';
  hp.frequency.value = 38;
  const body = ctx.createBiquadFilter();
  body.type = 'peaking';
  body.frequency.value = 150;
  body.Q.value = 1.1;
  body.gain.value = 3;
  const lp = ctx.createBiquadFilter();
  lp.type = 'lowpass';
  lp.frequency.value = 420;
  lp.Q.value = 0.6;
  const g = envelope(ctx, time, dur, gain, 0.1, 0.88, 0.2);
  const a = ctx.createOscillator();
  a.setPeriodicWave(periodic(ctx, 'lowReed'));
  a.detune.value = -6;
  const b = ctx.createOscillator();
  b.setPeriodicWave(periodic(ctx, 'lowReed'));
  b.detune.value = 7;
  a.frequency.value = freq;
  b.frequency.value = freq;
  a.connect(hp);
  b.connect(hp);
  hp.connect(body);
  body.connect(lp);
  lp.connect(g);
  withPan(ctx, g, dest, pan);
  a.start(time);
  b.start(time);
  a.stop(time + dur + 0.06);
  b.stop(time + dur + 0.06);
  noiseBurst(ctx, dest, time, Math.min(dur * 0.8, 1.2), gain * 0.16, 'lowpass', 520, 190, 0.6, pan);
}

function windGust(ctx, dest, time, dur = 2.4, gain = 0.018, pan = 0) {
  noiseBurst(ctx, dest, time, dur, gain, 'bandpass', 480, 760, 0.55, pan);
}

function heartbeat(ctx, dest, time, gain = 0.04, pan = 0) {
  taiko(ctx, dest, time, gain, pan, 0.58);
  taiko(ctx, dest, time + 0.18, gain * 0.55, pan, 0.52);
}

function bell(ctx, dest, time, freq, dur = 1.4, gain = 0.04, pan = 0) {
  const partials = [[1, 1], [2.01, 0.46], [2.98, 0.2], [4.12, 0.11]];
  for (let i = 0; i < partials.length; i++) {
    const [mul, amp] = partials[i];
    tone(ctx, dest, time + i * 0.004, freq * mul, dur * (1 - i * 0.12), gain * amp, 'sine', pan + (i % 2 ? 0.16 : -0.16), 0.004);
  }
}

function taiko(ctx, dest, time, gain = 0.08, pan = 0, pitch = 1) {
  const a = ctx.createOscillator();
  a.type = 'sine';
  a.frequency.setValueAtTime(112 * pitch, time);
  a.frequency.exponentialRampToValueAtTime(46 * pitch, time + 0.22);
  const b = ctx.createOscillator();
  b.type = 'sine';
  b.frequency.setValueAtTime(172 * pitch, time);
  b.frequency.exponentialRampToValueAtTime(92 * pitch, time + 0.12);
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, time);
  g.gain.linearRampToValueAtTime(gain, time + 0.005);
  g.gain.exponentialRampToValueAtTime(0.0001, time + 0.38);
  const gb = ctx.createGain();
  gb.gain.value = 0.32;
  a.connect(g);
  b.connect(gb);
  gb.connect(g);
  withPan(ctx, g, dest, pan);
  a.start(time);
  b.start(time);
  a.stop(time + 0.42);
  b.stop(time + 0.42);
  noiseBurst(ctx, dest, time, 0.08, gain * 0.3, 'lowpass', 520, 170, 0.7, pan);
}

function rim(ctx, dest, time, gain = 0.03, pan = 0) {
  noiseBurst(ctx, dest, time, 0.035, gain * 0.8, 'bandpass', 2200, 1500, 5.5, pan);
  noiseBurst(ctx, dest, time + 0.008, 0.028, gain * 0.55, 'bandpass', 980, 760, 7, pan);
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

function riser(ctx, dest, time, dur = 0.8, gain = 0.08, pan = 0) {
  noiseBurst(ctx, dest, time, dur, gain, 'bandpass', 240, 4200, 1.2, pan);
}

const ROOTS = [38, 34, 38, 33, 38, 34, 43, 33];
const CHORDS = [
  [50, 53, 57],
  [46, 50, 53],
  [50, 53, 57],
  [45, 48, 52],
  [50, 53, 57],
  [46, 50, 53],
  [43, 46, 50],
  [45, 48, 52]
];

const MENU_MOTIF = [
  { 0: 62, 5: 65, 8: 64, 10: 62, 13: 57 },
  { 0: 58, 4: 57, 8: 53, 12: 52, 15: 53 },
  { 0: 62, 4: 67, 8: 65, 12: 63 },
  { 0: 57, 6: 60, 10: 59, 14: 57 },
  { 0: 62, 4: 69, 8: 67, 12: 65, 14: 64 },
  { 0: 63, 4: 62, 8: 58, 12: 57 },
  { 0: 55, 4: 58, 8: 62, 12: 65 },
  { 0: 64, 4: 65, 8: 63, 12: 62, 14: 60 }
];

const DIZI_MENU = [null, 64, 57, 62, null, 60, 55, 57];

const BATTLE_ARP = [
  [62, 65, 57, 60, 57, 55, 53, 50],
  [58, 62, 53, 57, 53, 51, 50, 46],
  [62, 65, 69, 65, 64, 62, 60, 57],
  [57, 60, 64, 67, 64, 62, 60, 57],
  [62, 65, 69, 72, 69, 67, 65, 62],
  [58, 62, 65, 69, 65, 63, 62, 58],
  [55, 58, 62, 65, 62, 60, 58, 55],
  [57, 60, 64, 67, 69, 67, 64, 60]
];

const BATTLE_ERHU = [null, 57, null, 60, null, 58, null, 64];
const BATTLE_DIZI = [null, null, 69, null, null, null, 65, null];
const HOT_ERHU = [69, 70, 67, 69, 72, 70, 67, 69];
const HOT_DIZI = [null, 74, null, 72, null, 75, null, 70];
const FINAL_ARP = BATTLE_ARP.map((row) => row.map((n) => n - 12));
const FINAL_ERHU = [74, 75, 72, 74, 77, 75, 72, 70];
const FINAL_DIZI = [null, 79, null, 77, null, 75, null, 72];

const MUSIC_FILES = {
  menu: './assets/music/menu.ogg',
  battle: './assets/music/battle.ogg',
  hot: './assets/music/hot.ogg',
  final: './assets/music/final.ogg'
};

const MUSIC_VOLUMES = {
  menu: 0.7,
  battle: 0.82,
  hot: 0.98,
  final: 1
};

const TRACKS = {
  menu: {
    bpm: 66,
    bars: 8,
    volume: 0.8,
    step(ctx, out, i, time) {
      const beat = 60 / this.bpm;
      const bar = Math.floor(i / 16) % this.bars;
      const s = i % 16;
      const root = ROOTS[bar];
      const chord = CHORDS[bar];
      if (s === 0) {
        lowReed(ctx, out, time, mtof(root), beat * 4.2, 0.046, -0.12);
        sheng(ctx, out, time, mtof(chord[0]), beat * 3.9, 0.011, -0.28);
        sheng(ctx, out, time + 0.03, mtof(chord[2] + 12), beat * 3.9, 0.008, 0.28);
        if (bar % 2 === 0) heartbeat(ctx, out, time, 0.015, -0.2);
        if (bar === 0) bell(ctx, out, time, mtof(74), 1.8, 0.016, 0.25);
        if (bar === 2 || bar === 6) windGust(ctx, out, time, 2.6, 0.012, bar === 2 ? -0.4 : 0.4);
        if (bar === 4) pipa(ctx, out, time, mtof(69), 0.9, 0.012, 0.2);
      }
      if (s === 8) lowReed(ctx, out, time, mtof(root + 7), beat * 1.5, 0.022, 0.1);
      if (s === 12) pipa(ctx, out, time, mtof(MENU_MOTIF[bar][0] + 12), 0.55, 0.01, -0.24);
      const n = MENU_MOTIF[bar][s];
      if (n) guqin(ctx, out, time, mtof(n), 0.85, 0.038, s % 3 ? 0.14 : -0.14, s === 0 ? 0.008 : 0);
      if (s === 0) {
        const x = DIZI_MENU[bar] || 62;
        xiao(ctx, out, time, mtof(x), beat * 3, 0.019, bar % 2 ? 0.2 : -0.2);
      }
      if (bar === 7 && s === 10) erhu(ctx, out, time, mtof(75), beat * 2.2, 0.012, 0.24);
    }
  },
  battle: {
    bpm: 100,
    bars: 8,
    volume: 0.9,
    step(ctx, out, i, time) {
      const beat = 60 / this.bpm;
      const bar = Math.floor(i / 16) % this.bars;
      const s = i % 16;
      const root = ROOTS[bar];
      const chord = CHORDS[bar];
      if (s === 0) {
        lowReed(ctx, out, time, mtof(root), beat * 4.1, 0.052, -0.1);
        sheng(ctx, out, time, mtof(chord[0]), beat * 3.8, 0.01, -0.22);
        sheng(ctx, out, time + 0.02, mtof(chord[2] + 12), beat * 3.8, 0.007, 0.22);
        taiko(ctx, out, time, 0.07, -0.1, 0.9);
        if (bar % 2 === 0) heartbeat(ctx, out, time, 0.026, -0.18);
        if (bar === 0 || bar === 4) gong(ctx, out, time, 0.018, -0.15);
        if (bar === 4) pipa(ctx, out, time, mtof(69), 0.8, 0.012, 0.26);
      }
      if (s === 8) {
        lowReed(ctx, out, time, mtof(root + 7), beat * 1.4, 0.026, 0.1);
        taiko(ctx, out, time, 0.035, 0.08, 0.84);
      }
      if (s === 6 || s === 14) taiko(ctx, out, time, 0.04, 0.12, 0.78);
      if (s === 3 || s === 11) taiko(ctx, out, time, 0.025, -0.16, 0.72);
      if (s === 4 || s === 12) rim(ctx, out, time, 0.022, s === 4 ? -0.26 : 0.26);
      if (s % 2 === 0) {
        guqin(ctx, out, time, mtof(BATTLE_ARP[bar][s / 2]), 0.32, 0.034, s % 4 ? 0.14 : -0.14);
      }
      if (s === 0) {
        const eh = BATTLE_ERHU[bar];
        if (eh) erhu(ctx, out, time, mtof(eh), beat * 2.8, 0.022, bar % 2 ? 0.2 : -0.2);
        const dz = BATTLE_DIZI[bar];
        if (dz) xiao(ctx, out, time, mtof(dz), beat * 2.2, 0.017, bar % 2 ? 0.22 : -0.22);
      }
      if (bar === 7 && s === 10) xiao(ctx, out, time, mtof(75), beat * 1.8, 0.01, 0.24);
    }
  },
  hot: {
    bpm: 124,
    bars: 8,
    volume: 0.98,
    step(ctx, out, i, time) {
      const beat = 60 / this.bpm;
      const bar = Math.floor(i / 16) % this.bars;
      const s = i % 16;
      const root = ROOTS[bar];
      const chord = CHORDS[bar];
      if (s === 0) {
        lowReed(ctx, out, time, mtof(root), beat * 4.05, 0.058, -0.1);
        sheng(ctx, out, time, mtof(chord[0]), beat * 3.7, 0.012, -0.25);
        sheng(ctx, out, time + 0.02, mtof(chord[2] + 12), beat * 3.7, 0.008, 0.25);
        heartbeat(ctx, out, time, 0.032, -0.16);
        if (bar === 0 || bar === 4) gong(ctx, out, time, 0.025, -0.12);
      }
      if (s === 0 || s === 3 || s === 6 || s === 8 || s === 11 || s === 14) {
        taiko(ctx, out, time, 0.07, s % 4 ? 0.1 : -0.12, 1.0);
      }
      if (s === 4 || s === 12) rim(ctx, out, time, 0.03, s === 4 ? -0.28 : 0.28);
      if (s === 4 || s === 12) pipa(ctx, out, time, mtof(BATTLE_ARP[bar][2]), 0.45, 0.018, s === 4 ? -0.24 : 0.24);
      if (s % 2 === 0) {
        guqin(ctx, out, time, mtof(BATTLE_ARP[bar][s / 2]), 0.24, 0.04, s % 4 ? 0.18 : -0.18);
        if (s % 4 === 2) {
          guqin(ctx, out, time + 0.015, mtof(BATTLE_ARP[bar][s / 2] + 12), 0.2, 0.018, 0.24);
        }
      }
      if (s === 0) erhu(ctx, out, time, mtof(HOT_ERHU[bar]), beat * 2.6, 0.027, bar % 2 ? 0.2 : -0.2);
      if (s === 8) {
        const dz = HOT_DIZI[bar];
        if (dz) dizi(ctx, out, time, mtof(dz), beat * 1.6, 0.018, bar % 2 ? 0.24 : -0.24);
      }
      if ((bar === 3 || bar === 7) && s === 10) xiao(ctx, out, time, mtof(75), beat * 1.4, 0.01, 0.28);
    }
  },
  final: {
    bpm: 142,
    bars: 8,
    volume: 1.04,
    step(ctx, out, i, time) {
      const beat = 60 / this.bpm;
      const bar = Math.floor(i / 16) % this.bars;
      const s = i % 16;
      const root = ROOTS[bar];
      const chord = CHORDS[bar];
      if (s === 0) {
        lowReed(ctx, out, time, mtof(root), beat * 4.05, 0.066, -0.12);
        lowReed(ctx, out, time + 0.02, mtof(root + 12), beat * 4.05, 0.022, 0.12);
        sheng(ctx, out, time, mtof(chord[0] + 12), beat * 3.8, 0.013, -0.28);
        sheng(ctx, out, time + 0.02, mtof(chord[2] + 12), beat * 3.8, 0.009, 0.28);
        heartbeat(ctx, out, time, 0.042, -0.14);
        if (bar === 0 || bar === 4) gong(ctx, out, time, 0.04, 0.08);
        if (bar === 0) bell(ctx, out, time, mtof(74), 1.6, 0.018, 0.3);
        sheng(ctx, out, time, mtof(root + 12), 0.24, 0.03, -0.16);
        sheng(ctx, out, time + 0.03, mtof(root + 18), 0.22, 0.02, 0.16);
      }
      if (s === 0 || s === 4 || s === 8 || s === 12) taiko(ctx, out, time, 0.105, s % 8 ? 0.14 : -0.14, 1.0);
      if (s === 6 || s === 14) taiko(ctx, out, time, 0.055, 0.2, 0.8);
      if (s === 2 || s === 10) rim(ctx, out, time, 0.032, -0.24);
      if (s % 2 === 0) guqin(ctx, out, time, mtof(FINAL_ARP[bar][s / 2]), 0.26, 0.044, s % 4 ? 0.2 : -0.2);
      if (s === 0) erhu(ctx, out, time, mtof(FINAL_ERHU[bar]), beat * 3, 0.032, bar % 2 ? 0.22 : -0.22);
      if (s === 8) {
        const dz = FINAL_DIZI[bar];
        if (dz) dizi(ctx, out, time, mtof(dz), beat * 1.8, 0.02, bar % 2 ? 0.24 : -0.24);
      }
      if (bar === 7 && s === 12) xiao(ctx, out, time, mtof(75), beat * 1.6, 0.012, 0.3);
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
    this.musicMode = 'file';
    this.musicStyle = 'grand';
    this.musicVolume = 0.7;
    this.sfxVolume = 0.8;
    this.musicBuffers = new Map();
    this.musicLoads = new Map();
    this.musicActive = null;
    this.musicPending = null;
    this.musicPreloaded = false;
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

  setMusicStyle(style) {
    if (style !== 'plain' && style !== 'grand') return;
    if (style === this.musicStyle) return;
    this.musicStyle = style;
    this.trackToken += 1;
    if (!this.ctx) return;
    this.stopActiveMusic(0.35);
    if (style === 'plain') this.startProcedural(this.track);
    else this.startMusicFile(this.track, this.trackToken);
  }

  setMusicVolume(volume) {
    this.musicVolume = Math.max(0, Math.min(1, Number(volume) || 0));
    this.applyMusicGain(0.35);
  }

  setSfxVolume(volume) {
    this.sfxVolume = Math.max(0, Math.min(1, Number(volume) || 0));
    if (this.sfxGain && this.ctx) {
      this.sfxGain.gain.setTargetAtTime(this.sfxVolume, this.ctx.currentTime, 0.05);
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
    this.sfxGain.gain.value = this.sfxVolume;
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
    if (this.musicStyle === 'plain') this.startProcedural(this.track);
    else this.startMusicFile(this.track, this.trackToken);
    this.preloadMusicFiles();
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
    return (MUSIC_VOLUMES[this.track] ?? TRACKS[this.track]?.volume ?? 0.6) * 1.05;
  }

  loadMusicBuffer(id) {
    if (this.musicBuffers.has(id)) return Promise.resolve(this.musicBuffers.get(id));
    if (this.musicLoads.has(id)) return this.musicLoads.get(id);
    const src = MUSIC_FILES[id];
    if (!src || !this.ctx) return Promise.reject(new Error('music unavailable'));
    const task = fetch(src)
      .then((res) => {
        if (!res.ok) throw new Error(`music ${res.status}`);
        return res.arrayBuffer();
      })
      .then((data) => this.ctx.decodeAudioData(data))
      .then((buffer) => {
        this.musicBuffers.set(id, buffer);
        this.musicLoads.delete(id);
        return buffer;
      })
      .catch((err) => {
        this.musicLoads.delete(id);
        throw err;
      });
    this.musicLoads.set(id, task);
    return task;
  }

  preloadMusicFiles() {
    if (this.musicPreloaded || !this.ctx) return;
    this.musicPreloaded = true;
    for (const id of Object.keys(MUSIC_FILES)) {
      this.loadMusicBuffer(id).catch(() => {});
    }
  }

  startMusicFile(id, token) {
    if (!this.ctx || !MUSIC_FILES[id]) {
      this.startProcedural(id);
      return;
    }
    const key = `${id}:${token}`;
    if (this.musicPending === key) return;
    this.musicPending = key;
    this.loadMusicBuffer(id).then((buffer) => {
      if (this.musicPending === key) this.musicPending = null;
      if (token !== this.trackToken || id !== this.track || !this.ctx) return;
      this.playMusicBuffer(id, buffer);
    }).catch(() => {
      if (this.musicPending === key) this.musicPending = null;
      if (token !== this.trackToken || id !== this.track) return;
      this.startProcedural(id);
    });
  }

  playMusicBuffer(id, buffer) {
    this.stopActiveMusic(0.5);
    const source = this.ctx.createBufferSource();
    source.buffer = buffer;
    source.loop = true;
    const gain = this.ctx.createGain();
    const now = this.ctx.currentTime;
    gain.gain.setValueAtTime(0.0001, now);
    source.connect(gain);
    gain.connect(this.musicIn);
    source.start(now);
    gain.gain.linearRampToValueAtTime(1, now + 0.9);
    this.musicActive = { source, gain, id };
    this.musicMode = 'file';
    this.applyMusicGain(0.55);
  }

  stopActiveMusic(fade = 0.55) {
    const active = this.musicActive;
    if (!active || !this.ctx) return;
    this.musicActive = null;
    const now = this.ctx.currentTime;
    const gain = active.gain.gain;
    gain.cancelScheduledValues(now);
    gain.setValueAtTime(Math.max(0.0001, gain.value), now);
    gain.exponentialRampToValueAtTime(0.0001, now + fade);
    try {
      active.source.stop(now + fade + 0.08);
    } catch {}
  }

  startProcedural(id) {
    if (!this.ctx || !TRACKS[id]) return;
    this.stopActiveMusic(0.25);
    this.musicMode = 'procedural';
    this.track = id;
    this.step = 0;
    this.nextTime = this.ctx.currentTime + 0.08;
    this.applyMusicGain(0.55);
  }

  applyMusicGain(fade = 0.4) {
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    const ducked = this.duck.size > 0;
    const target = this.trackBase() * this.musicVolume * (ducked ? 0.24 : 1);
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
    if (!MUSIC_FILES[id] && !TRACKS[id]) return;
    if (id === this.track) {
      if (this.ctx && this.musicMode === 'file' && !this.musicActive) {
        this.startMusicFile(id, this.trackToken);
      }
      return;
    }
    this.track = id;
    this.step = 0;
    this.trackToken += 1;
    if (!this.ctx) return;
    this.stopActiveMusic(0.55);
    if (this.musicStyle === 'plain') this.startProcedural(id);
    else this.startMusicFile(id, this.trackToken);
  }

  tick() {
    if (this.musicMode !== 'procedural') return;
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
      zombieDie: 0.035,
      catShot: 0.045,
      lobShot: 0.05,
      starShot: 0.05,
      needleShot: 0.035,
      gravelShot: 0.05,
      judgeStrike: 0.08,
      flytrap: 0.06,
      mine: 0.08
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
      case 'catShot':
        tone(this.ctx, out, time, 760, 0.16, 0.02, 'sine', pan, 0.004, 1240);
        tone(this.ctx, out, time + 0.02, 1140, 0.2, 0.011, 'sine', pan, 0.005, 760);
        noiseBurst(this.ctx, out, time, 0.13, 0.016, 'highpass', 2200, 1100, 1.3, pan);
        break;
      case 'lobShot':
        noiseBurst(this.ctx, out, time, 0.2, 0.026, 'bandpass', 420, 900, 1.4, pan);
        tone(this.ctx, out, time, 190, 0.18, 0.022, 'triangle', pan, 0.006, 108);
        tone(this.ctx, out, time + 0.24, 92, 0.14, 0.02, 'sine', pan, 0.002, 64);
        break;
      case 'starShot':
        bell(this.ctx, out, time, 1320, 0.28, 0.017, pan);
        bell(this.ctx, out, time + 0.035, 1760, 0.24, 0.011, pan);
        tone(this.ctx, out, time, 880, 0.2, 0.01, 'sine', pan, 0.003, 1320);
        break;
      case 'needleShot':
        noiseBurst(this.ctx, out, time, 0.08, 0.032, 'highpass', 5200, 2800, 1.7, pan);
        tone(this.ctx, out, time, 1850, 0.055, 0.014, 'triangle', pan, 0.001, 920);
        break;
      case 'gravelShot':
        noiseBurst(this.ctx, out, time, 0.12, 0.036, 'bandpass', 900, 300, 0.9, pan);
        tone(this.ctx, out, time, 140, 0.1, 0.024, 'triangle', pan, 0.002, 66);
        break;
      case 'judgeStrike':
        gong(this.ctx, out, time, 0.032, pan);
        tone(this.ctx, out, time, 68, 0.44, 0.065, 'sine', pan, 0.004, 36);
        noiseBurst(this.ctx, out, time, 0.22, 0.04, 'lowpass', 460, 120, 0.8, pan);
        tone(this.ctx, out, time + 0.015, 430, 0.32, 0.014, 'triangle', pan, 0.004, 205);
        break;
      case 'flytrap':
        noiseBurst(this.ctx, out, time, 0.13, 0.05, 'lowpass', 900, 180, 0.9, pan);
        tone(this.ctx, out, time, 175, 0.14, 0.035, 'triangle', pan, 0.002, 72);
        noiseBurst(this.ctx, out, time + 0.015, 0.05, 0.03, 'highpass', 2400, 1600, 1.2, pan);
        break;
      case 'mine':
        noiseBurst(this.ctx, out, time, 0.3, 0.07, 'lowpass', 700, 130, 0.8, pan);
        tone(this.ctx, out, time, 105, 0.24, 0.05, 'sine', pan, 0.003, 42);
        noiseBurst(this.ctx, out, time + 0.04, 0.1, 0.025, 'bandpass', 1500, 600, 1.1, pan);
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
      case 'chomp':
        noiseBurst(this.ctx, out, time, 0.12, 0.05, 'lowpass', 900, 220, 0.8, pan);
        tone(this.ctx, out, time, 150, 0.16, 0.04, 'triangle', pan, 0.003, 58);
        noiseBurst(this.ctx, out, time + 0.08, 0.08, 0.03, 'bandpass', 1400, 700, 1, pan);
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
      mode: this.musicMode,
      activeFile: this.musicActive?.id || null,
      fileDuration: this.musicActive?.source?.buffer ? +this.musicActive.source.buffer.duration.toFixed(2) : 0,
      loaded: [...this.musicBuffers.keys()],
      duck: [...this.duck],
      gain: this.musicGain ? +this.musicGain.gain.value.toFixed(3) : 0,
      rms: +this.readRms().toFixed(4)
    };
  }
}

export const audio = new AudioEngine();
