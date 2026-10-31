import { Game } from './game/game.js';
import { Renderer } from './render/renderer.js';
import { loadAssets } from './core/assets.js';
import { audio } from './audio/audio.js';

await loadAssets();
const loading = document.getElementById('loading');
if (loading) loading.classList.add('hidden');

const canvas = document.getElementById('game');
const game = new Game();
const renderer = new Renderer(canvas);
renderer.setResolution(game.settings.resolution || 'auto');
const input = { x: 640, y: 360, clicks: [], active: false };

let fullscreenRequested = false;
function requestFullscreen() {
  if (fullscreenRequested) return;
  const bridge = window.chrome && window.chrome.webview;
  if (!bridge || !bridge.postMessage) return;
  bridge.postMessage('display:fullscreen');
  fullscreenRequested = true;
}
requestFullscreen();

audio.setMusicStyle(game.settings.musicStyle || 'grand');
audio.setMusicVolume((game.settings.musicVolume ?? 70) / 100);
audio.setSfxVolume((game.settings.sfxVolume ?? 80) / 100);
audio.setTrack('menu');
audio.setMuted(game.settings.sound === false);
const unlockAudio = () => { audio.unlock(); };
window.addEventListener('pointerdown', unlockAudio, { once: true, capture: true });
window.addEventListener('keydown', unlockAudio, { once: true, capture: true });
audio.unlock();

canvas.addEventListener('pointermove', (e) => {
  const p = renderer.toLogical(e.clientX, e.clientY);
  input.x = p.x;
  input.y = p.y;
});

canvas.addEventListener('pointerdown', (e) => {
  e.preventDefault();
  const p = renderer.toLogical(e.clientX, e.clientY);
  input.x = p.x;
  input.y = p.y;
  input.active = true;
  input.clicks.push({ x: p.x, y: p.y, button: e.button });
});

canvas.addEventListener('pointerup', () => { input.active = false; });
canvas.addEventListener('pointerleave', () => { input.active = false; });
canvas.addEventListener('contextmenu', (e) => e.preventDefault());

canvas.addEventListener('wheel', (e) => {
  if (game.overlay !== 'almanac') return;
  e.preventDefault();
  game.scrollAlmanac(e.deltaY);
}, { passive: false });

window.addEventListener('keydown', (e) => {
  if (game.overlay === 'almanac') {
    if (e.code === 'ArrowDown') {
      e.preventDefault();
      game.scrollAlmanac(70);
      return;
    }
    if (e.code === 'ArrowUp') {
      e.preventDefault();
      game.scrollAlmanac(-70);
      return;
    }
    if (e.code === 'PageDown') {
      e.preventDefault();
      game.scrollAlmanac(300);
      return;
    }
    if (e.code === 'PageUp') {
      e.preventDefault();
      game.scrollAlmanac(-300);
      return;
    }
  }
  if (e.code === 'KeyB') {
    if (game.overlay === 'almanac') game.closeAlmanac();
    else game.openAlmanac();
    return;
  }
  if (e.code === 'KeyP') game.togglePause();
  else if (e.code === 'Escape') game.cancelSelection();
  else if (e.code === 'Enter' && game.phase === 'menu') {
    if (game.overlay === 'prep') {
      if (game.prep?.warning === 'empty') game.dismissPrepWarning();
      else if (!game.prep?.warning) game.confirmPrep();
    } else {
      game.menuPrimary();
    }
  }
});

let last = performance.now();
let acc = 0;
const STEP = 1 / 60;

function musicScene(g) {
  if (g.phase === 'menu' || g.phase === 'won' || g.phase === 'lost') return 'menu';
  const total = g.level?.waves?.length || g.waveTotal || 12;
  const idx = g.waveIndex || 0;
  if (idx >= total - 2) return 'final';
  if (idx >= Math.ceil(total / 2)) return 'hot';
  return 'battle';
}

function frame(now) {
  requestAnimationFrame(frame);

  let dt = (now - last) / 1000;
  last = now;
  if (dt > 0.1) dt = 0.1;
  if (dt < 0) dt = 0;

  let steps = 0;
  const simulating = game.phase === 'playing' && game.overlay !== 'cheat';
  if (!simulating) {
    game.update(Math.min(dt, 0.1), input);
    acc = 0;
  } else {
    acc += dt * (game.tutorial ? 1 : (game.settings.speed || 1));
    while (acc >= STEP && steps < 8) {
      game.update(STEP, input);
      acc -= STEP;
      steps += 1;
    }
    if (steps === 8) acc = 0;
  }

  audio.setMuted(game.settings.sound === false);
  audio.setTrack(musicScene(game));
  audio.setDuck('pause', game.phase === 'paused');
  audio.setDuck('cinema', game.overlay === 'prep' && !!game.prep && !game.prep.cinemaDone);
  renderer.setResolution(game.settings.resolution || 'auto');

  renderer.render(game, now / 1000);
}

requestAnimationFrame(frame);

setInterval(() => game.saveNow(), 5000);
window.addEventListener('pagehide', () => {
  game.saveNow();
  audio.setSuspended(true);
});
document.addEventListener('visibilitychange', () => {
  if (document.hidden) game.saveNow();
  audio.setSuspended(document.hidden);
});

window.__game = game;
window.__renderer = renderer;
window.__audio = audio;
window.__musicScene = musicScene;
