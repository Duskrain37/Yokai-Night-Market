const ASSET_PATHS = {
  backgrounds: {
    menu: './assets/bg/menu.jpg',
    board: './assets/bg/board.jpg'
  },
  plants: {
    lantern: './assets/sprites/lantern.png',
    shooter: './assets/sprites/shooter.png',
    wall: './assets/sprites/wall.png',
    bomb: './assets/sprites/bomb.png',
    bell: './assets/sprites/bell.png',
    censer: './assets/sprites/censer.png',
    umbrella: './assets/sprites/umbrella.png',
    lion: './assets/sprites/lion.png',
    mushroom: './assets/sprites/mushroom.png',
    cat: './assets/sprites/cat.png',
    lobber: './assets/sprites/lobber.png',
    torch: './assets/sprites/torch.png',
    star: './assets/sprites/star.png',
    needle: './assets/sprites/needle.png',
    judge: './assets/sprites/judge.png'
  },
  zombies: {
    ghost: './assets/sprites/ghost.png',
    paper: './assets/sprites/paper.png',
    mountain: './assets/sprites/mountain.png',
    tongue: './assets/sprites/tongue.png',
    mourner: './assets/sprites/mourner.png',
    sedan: './assets/sprites/sedan.png',
    straw: './assets/sprites/straw.png',
    stonehat: './assets/sprites/stonehat.png',
    bucket: './assets/sprites/bucket.png',
    vault: './assets/sprites/vault.png',
    artisan: './assets/sprites/artisan.png',
    ironjudge: './assets/sprites/ironjudge.png'
  },
  guardian: './assets/sprites/guardian.png'
};

export const assets = {
  backgrounds: {},
  plants: {},
  zombies: {},
  guardian: null,
  loaded: false
};

function loadImage(src) {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);
    img.src = src;
  });
}

export async function loadAssets() {
  const tasks = [];
  for (const [key, src] of Object.entries(ASSET_PATHS.backgrounds)) {
    tasks.push(loadImage(src).then((img) => {
      if (img) assets.backgrounds[key] = img;
    }));
  }
  for (const [key, src] of Object.entries(ASSET_PATHS.plants)) {
    tasks.push(loadImage(src).then((img) => {
      if (img) assets.plants[key] = img;
    }));
  }
  for (const [key, src] of Object.entries(ASSET_PATHS.zombies)) {
    tasks.push(loadImage(src).then((img) => {
      if (img) assets.zombies[key] = img;
    }));
  }
  tasks.push(loadImage(ASSET_PATHS.guardian).then((img) => {
    if (img) assets.guardian = img;
  }));
  await Promise.all(tasks);
  assets.loaded = true;
  return assets;
}
