import { PLANT_TYPES, ZOMBIE_TYPES, LEVEL } from '../content.js';
import { PLANT_EFFECTS } from '../game/upgrade.js';

export const ALMANAC_PLANTS = [
  {
    type: 'lantern',
    name: '红灯笼',
    epithet: '摊前第一盏',
    story: '收摊以后，别的物件都睡了，只有它还亮着。灯芯是摊主从河灯会上换来的，据说照过谁的回头路。它不爱说话，只在你数香火时晃一下，像在提醒：账可以慢点算，灯不能灭。',
    ability: '每隔 8 秒吐出一团香火，首次 5 秒；每团 25 点，落地后可收取。被啃时会用灯油烫伤对方。',
    quote: '灯亮着，摊子就还在。'
  },
  {
    type: 'shooter',
    name: '签筒',
    epithet: '手熟的黑签',
    story: '签筒原是算命摊上的旧物，签文被雨水泡烂了，只剩筒身还硬朗。它把剩下的竹签当暗器使，起初只为了吓野猫，后来发现对恶客也挺好使。每回甩签前都要抖三下，像在给自己壮胆。',
    ability: '朝本行前方射竹签，每 1.4 秒一发，单发 20 伤害。进化后可以连发、借邻行，或甩出双倍伤害的大签。',
    quote: '不求百发百中，只求你别过来。'
  },
  {
    type: 'wall',
    name: '石磨',
    epithet: '不肯挪窝的老石头',
    story: '石磨在夜市口蹲了很多年，磨过豆子、磨过辣椒，也磨过几个不长眼的小贼的鞋底。它不爱说话，磨齿一响，整条街就知道今晚有人要吃亏。摊主给它系过一条红绳，后来被它自己磨断了。',
    ability: '耐久 3000 的肉盾，替同行挡下啃食。进化后能反伤、把耐久堆到 7500，碎掉时还会崩出一圈石屑。',
    quote: '想过去？先问磨齿。'
  },
  {
    type: 'bomb',
    name: '爆竹',
    epithet: '一响就散的急脾气',
    story: '它本是年初一早上用的，被摊主忘在柜底，一忘就是一整年。再拿出来时，它已经憋坏了。引信一点，它先骂一句，再把整条街炸得亮堂堂。没人记得它炸完以后去了哪，大概是被自己吵没了。',
    ability: '一次性范围爆炸：引信 1.2 秒，半径约 1.7 格，造成 1800 伤害。灰烬类，不能升阶。',
    quote: '别劝，劝就是炸。'
  },
  {
    type: 'bell',
    name: '铜铃',
    epithet: '先声夺人',
    story: '铜铃挂在摊棚角上，平时只是摆设。直到有一晚，饿鬼踩着铃影过来，它突然自己响了。声音不大，却让整条街的恶客都慢了半拍。从那以后它有了差事：别人动手之前，先由它开口。',
    ability: '每 2.5 秒摇铃，减速本行前方敌人 50%，持续 3 秒。进化后摇得更快、减得更狠，还能用铃声伤人。',
    quote: '先听个响，再谈别的。'
  },
  {
    type: 'censer',
    name: '香炉',
    epithet: '账房檐下的老炉',
    story: '夜市账房门口有只三足铜炉，常年压着半本赊账簿。账房先生说，香灰里埋着往年没还清的名字，所以炉子总在半夜自己冒烟。它不记账，只把那些名字一圈圈熏开，像替谁把没说完的话说完。',
    ability: '每 3 秒喷出一圈香雾，灼伤周围敌人，基础 45 点。进化的方向是更大的烟圈、更重的火气，以及让被熏到的敌人慢下来。',
    quote: '账可以慢算，烟不能断。'
  },
  {
    type: 'umbrella',
    name: '纸伞',
    epithet: '守摊娘的旧伞',
    story: '这把油纸伞替摊娘挡过三年夜雨，伞面上画的海棠早褪了色。收摊后它总自己撑开，把邻近的摊子罩在影子里。有人说那是怕雨，也有人说，是怕谁被夜里的客人啃坏了。',
    ability: '撑伞护住相邻植物，使其所受啃食伤害降低 15%；每 5.5 秒回旋一次，把本行近处的敌人推开 46 像素。进化后可加深庇护、增强击退，并持续修复相邻植物。',
    quote: '伞下这寸地，归我管。'
  },
  {
    type: 'lion',
    name: '醒狮',
    epithet: '初一请来的狮头',
    story: '年初一舞狮队从摊前过，把这只旧狮头落在了货架底下。摊主嫌它占地方，几次想扔，最后都留了下来。入夜后它会自己抖毛，听见恶客的脚步就低头撞过去，撞完了还要甩甩鬃毛，像在等一声叫好。',
    ability: '高耐久近身守卫：敌人靠近到 110 像素内时，每 1.35 秒撞头一次，造成 60 伤害并小幅击退。进化后可眩晕敌人，并在命中时回复自身耐久。',
    quote: '狮子不咬人，狮子只撞。'
  }
];

export const ALMANAC_ZOMBIES = [
  {
    type: 'ghost',
    name: '饿鬼',
    epithet: '闻着香火来的',
    story: '子时过后，街口总会多出几道影子。它们不记得生前叫什么，只记得夜市的味道。饿鬼走得慢，啃东西也不快，但它们从不在乎——反正天还长，摊子总会打烊。',
    ability: '最普通的恶客，沿本行慢慢往前，停下啃食植物，啃食 70/秒。',
    counter: '怕连发与范围清场；别让它磨到门口。',
    quote: '就一口，真的就一口。'
  },
  {
    type: 'paper',
    name: '纸人',
    epithet: '一戳就散，先拿张纸挡着',
    story: '纸人是白事铺里扎剩下的边角料，被野风吹到夜市，捡了张旧告示糊在身上，就当自己有了脸。它很爱惜那层纸壳，哪怕被竹签戳得叮当响，也要先把里头那口纸气撑住。',
    ability: '纸壳 250 + 本体 200，速度与饿鬼相同。纸壳先碎，本体后倒。',
    counter: '先用连发撕壳，再用铜铃拖住。',
    quote: '别碰脸，脸是借来的。'
  },
  {
    type: 'mountain',
    name: '山魈',
    epithet: '不讲道理的大块头',
    story: '山魈是从城外山上下来的。据说今年山里的果子不好，它一路闻到夜市，就没打算回去。它个头大、脾气坏，啃石磨像啃豆腐，偶尔还会停下来看看摊主有没有藏酒。',
    ability: '重型恶客：血量 900，走得稍慢，但啃食伤害 120/秒。',
    counter: '石磨和铜铃一起拖，单靠一株签筒顶不住。',
    quote: '果子呢？没有果子就啃摊子。'
  },
  {
    type: 'tongue',
    name: '长舌鬼',
    epithet: '舌头比脚先到',
    story: '长舌鬼生前是个爱传闲话的，死后舌头没缩回去，越长越红。它走路急，吃相更急，隔着半个摊子就把舌头探过来。摊主们说，听它嚼东西的动静，比听它说话还难受。',
    ability: '走得快，血量偏低；啃食距离比普通恶客远，约 62 像素，会在更早的位置停下开咬。',
    counter: '在它够到之前用铜铃或香炉减速，再让签筒点掉；纸伞的击退能把它推回攻击距离外。',
    quote: '我就舔一下，不咬。'
  },
  {
    type: 'mourner',
    name: '哭丧鬼',
    epithet: '一哭，整条街都急',
    story: '哭丧鬼原是白事铺请来的哭灵人，哭了一辈子别人的丧事，最后没人替她哭。她夜里沿着摊位慢慢走，哭声不大，却让周围的恶客都跟着心慌，脚步快得像是有人在后面催。',
    ability: '行走慢、血量中等；每 4.5 秒哭号一次，使周围 150 像素内的恶客加速 35%，持续 2.6 秒。',
    counter: '优先点杀，别让她站在怪堆里；减速能抵消她带来的加速，范围伤害也容易顺带清掉。',
    quote: '别急，还没轮到你。'
  },
  {
    type: 'sedan',
    name: '抬轿鬼',
    epithet: '轿子没落，客人还在',
    story: '抬轿鬼抬着一顶褪色的红轿，轿帘后面坐着谁，没人看清过。它们走得不快，轿子却硬得很，像把一整场喜事都糊在了木头上。轿破的时候，里头的东西会自己下来走，一边走一边找原来的路。',
    ability: '重型恶客：本体 420 耐久，另有 720 轿壳；轿壳破裂时，会从轿中跌出 2 只饿鬼，各继承 60% 血量。',
    counter: '先用签筒磨轿，再用爆竹或香炉一次收掉跌出来的饿鬼；铜铃能把整队拖在门口。',
    quote: '起轿——别问去哪。'
  }
];

export function almanacEntries(tab) {
  return tab === 'zombie' ? ALMANAC_ZOMBIES : ALMANAC_PLANTS;
}

export function firstWaveOf(type) {
  for (let i = 0; i < LEVEL.waves.length; i++) {
    for (const [ztype, count] of LEVEL.waves[i].groups) {
      if (ztype === type && count > 0) return i + 1;
    }
  }
  return 0;
}

export function plantBaseStats(type) {
  const d = PLANT_TYPES[type];
  const stats = [
    { label: '香火', value: String(d.cost), tone: 'cost' },
    { label: '耐久', value: String(d.hp), tone: 'hp' },
    { label: '冷却', value: `${d.cooldown} 秒`, tone: 'time' }
  ];
  if (type === 'lantern') {
    stats.push(
      { label: '首次产出', value: `${d.produce.first} 秒`, tone: 'time' },
      { label: '单次产量', value: String(d.produce.value), tone: 'gold' },
      { label: '产出间隔', value: `${d.produce.interval} 秒`, tone: 'time' }
    );
  } else if (type === 'shooter') {
    stats.push(
      { label: '攻速', value: `${d.shot.interval} 秒 / 发`, tone: 'time' },
      { label: '单发伤害', value: String(d.shot.damage), tone: 'atk' },
      { label: '射程', value: '本行前方', tone: 'neutral' }
    );
  } else if (type === 'wall') {
    stats.push(
      { label: '攻击', value: '无', tone: 'neutral' },
      { label: '定位', value: '肉盾', tone: 'green' },
      { label: '占格', value: '1 格', tone: 'neutral' }
    );
  } else if (type === 'bomb') {
    stats.push(
      { label: '引信', value: `${d.bomb.fuse} 秒`, tone: 'time' },
      { label: '半径', value: String(d.bomb.radius), tone: 'neutral' },
      { label: '爆炸伤害', value: String(d.bomb.damage), tone: 'atk' },
      { label: '类别', value: '灰烬 · 一次性', tone: 'cost' }
    );
  } else if (type === 'bell') {
    stats.push(
      { label: '摇铃间隔', value: `${d.pulse.interval} 秒`, tone: 'time' },
      { label: '减速', value: '50%', tone: 'teal' },
      { label: '持续', value: `${d.pulse.slow} 秒`, tone: 'time' },
      { label: '范围', value: '本行前方', tone: 'neutral' }
    );
  } else if (type === 'censer') {
    stats.push(
      { label: '香雾伤害', value: String(PLANT_EFFECTS.censer.damage[0]), tone: 'atk' },
      { label: '香雾半径', value: String(PLANT_EFFECTS.censer.radius[0]), tone: 'neutral' },
      { label: '喷烟间隔', value: `${PLANT_EFFECTS.censer.interval} 秒`, tone: 'time' }
    );
  } else if (type === 'umbrella') {
    stats.push(
      { label: '庇护减伤', value: `${Math.round(PLANT_EFFECTS.umbrella.guard[0] * 100)}%`, tone: 'teal' },
      { label: '回旋间隔', value: `${PLANT_EFFECTS.umbrella.blowInterval[0]} 秒`, tone: 'time' },
      { label: '推开距离', value: `${PLANT_EFFECTS.umbrella.blowDist[0]} 像素`, tone: 'neutral' }
    );
  } else if (type === 'lion') {
    stats.push(
      { label: '撞头伤害', value: String(PLANT_EFFECTS.lion.damage[0]), tone: 'atk' },
      { label: '攻击间隔', value: `${PLANT_EFFECTS.lion.interval[0]} 秒`, tone: 'time' },
      { label: '攻击距离', value: String(PLANT_EFFECTS.lion.reach), tone: 'neutral' },
      { label: '击退', value: `${PLANT_EFFECTS.lion.knock} 像素`, tone: 'teal' }
    );
  }
  return stats;
}

export function zombieBaseStats(type) {
  const d = ZOMBIE_TYPES[type];
  const stats = [
    { label: '血量', value: String(d.hp), tone: 'hp' },
    { label: '护甲', value: d.shell > 0 ? `${type === 'sedan' ? '轿壳' : '纸壳'} ${d.shell}` : '无', tone: d.shell > 0 ? 'gold' : 'neutral' },
    { label: '速度', value: String(d.speed), tone: 'time' },
    { label: '啃食', value: `${d.dps} / 秒`, tone: 'atk' }
  ];
  if (type === 'tongue') {
    stats.push({ label: '啃食距离', value: String(d.reach), tone: 'teal' });
  } else if (type === 'mourner') {
    stats.push({ label: '哭号半径', value: String(d.aura.radius), tone: 'neutral' });
    stats.push({ label: '加速', value: `+${Math.round((d.aura.haste - 1) * 100)}% / ${d.aura.duration} 秒`, tone: 'orange' });
  } else if (type === 'sedan') {
    stats.push({ label: '破轿', value: `${d.split.count} 只饿鬼 · ${Math.round(d.split.hp * 100)}%`, tone: 'green' });
  }
  const wave = firstWaveOf(type);
  if (wave) stats.push({ label: '初遇', value: `第 ${wave} 波`, tone: 'teal' });
  const traits = {
    ghost: '数量多', paper: '双层血', mountain: '重型',
    tongue: '快手', mourner: '助威', sedan: '破轿分身'
  };
  stats.push({
    label: '特性',
    value: traits[type] || '数量多',
    tone: 'green'
  });
  return stats;
}
