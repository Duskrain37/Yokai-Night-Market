import { PLANT_TYPES, ZOMBIE_TYPES, LEVELS, zombieTierLabel } from '../content.js';
import { PLANT_EFFECTS } from '../game/upgrade.js';

export const ALMANAC_PLANTS = [
  {
    type: 'lantern',
    name: '红灯笼',
    epithet: '摊前第一盏',
    story: '收摊以后，别的物件都睡了，只有它还亮着。灯芯是摊主从河灯会上换来的，据说照过谁的回头路。它不爱说话，只在你数香火时晃一下，像在提醒：账可以慢点算，灯不能灭。',
    ability: '每隔 8 秒吐出一团香火，首次 5 秒；每团 25 点，落地后可收取。进化出的红火会增幅身前友军，使其伤害提高 20%/25%。',
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
    ability: '耐久 3000 的肉盾，替同行挡下啃食。进化后可自愈、反伤；三路还能磨出碎石，像签筒一样射击，并让命中者易伤或击退。',
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
    type: 'mushroom',
    name: '坟头菇',
    epithet: '坟头土里长出来的',
    story: '夜市后巷的坟头土最养菇。它埋下去时不声不响，伞盖下压着两张旧符，像替谁守着最后一口气。等它鼓起来，谁踩上去，它就把攒了半宿的鬼火全喷出来，连自己一起烧没。',
    ability: '灰烬陷阱：埋下后需 14 秒长成；长成后恶客踏入即喷发鬼火，造成 1800 伤害并同归于尽。一次性，不能升阶。',
    quote: '别踩，下面埋着东西。'
  },
  {
    type: 'bell',
    name: '铜铃',
    epithet: '先声夺人',
    story: '铜铃挂在摊棚角上，平时只是摆设。直到有一晚，饿鬼踩着铃影过来，它突然自己响了。声音不大，却让整条街的恶客都慢了半拍。从那以后它有了差事：别人动手之前，先由它开口。',
    ability: '每 2.5 秒摇铃，减速本行前方敌人 25%，持续 1.5 秒。进化后可加快摇铃、让减速增到 40%，也能用铃声增幅友军攻速或杀伤敌人。',
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
    epithet: '收得下夜客，也收得下香火',
    story: '这把油纸伞替摊娘挡过三年夜雨，伞面上画的海棠早褪了色。后来夜市里多了一种说法：撑开它挡雨，收起它收妖。伞骨一合，饿鬼纸人就被卷进伞腹；再撑开时，只剩一团香火落在摊前。',
    ability: '耐久 900，约为普通植物的三倍。非大型恶客靠近即被收入伞中，随后收妖 6 秒；大型恶客撑不进伞，只能被伞骨击打，每次 40 伤害。进化可加快收妖、收妖后产香火，或减少收妖期间受到的伤害。',
    quote: '伞下这寸地，归我管。'
  },
  {
    type: 'lion',
    name: '醒狮',
    epithet: '初一请来的狮头',
    story: '年初一舞狮队从摊前过，把这只旧狮头落在了货架底下。摊主嫌它占地方，几次想扔，最后都留了下来。入夜后它会自己抖毛，听见恶客的脚步就低头撞过去，撞完了还要甩甩鬃毛，像在等一声叫好。',
    ability: '高耐久近身守卫：敌人靠近到 110 像素内时，每 1.35 秒撞头一次，造成 60 伤害并击退 0.2 格。进化后三路可增加击退距离与眩晕，并在命中时回复自身耐久。',
    quote: '狮子不咬人，狮子只撞。'
  },
  {
    type: 'cat',
    name: '狐尾灯',
    epithet: '追着最近那口气走',
    story: '夜市西头的旧灯架上挂着一截狐尾形状的灯芯。摊主说，那是只走丢的狐妖留下的最后一点火。它不照路，只照人：谁身上的阴气最重，尾火就朝谁飘过去，绕一圈再回来，像狐狸在确认猎物还在不在。',
    ability: '每隔 1.6 秒放出一团尾火，自动追向全场上距离最近的恶客，可跨行。每团 15 伤害；进化可增加尾火数量、伤害，三级尾火命中后还会再追一个目标。尾火附带的易伤与减速不叠加，只取最高值。',
    quote: '别回头，它已经看见你了。'
  },
  {
    type: 'shell',
    name: '龟甲罩',
    epithet: '老龟留下的半间屋',
    story: '河滩上捡来的老龟甲，壳口磨得发亮。摊主把它罩在怕风的物件上，后来发现恶客啃壳比啃摊子还费劲。壳里那株植物照常做事，只是从此多了一层沉默的屋顶。',
    ability: '只能罩在已种下的植物上，为其提供 1400 点护罩耐久。恶客会先啃龟甲，壳碎后里面的植物仍在。不能升阶，铲除时连壳一起收走。',
    quote: '壳在，摊就在。'
  },
  {
    type: 'lobber',
    name: '汤圆仔',
    epithet: '一碗会自己动手的宵夜',
    story: '甜品摊收工后，锅里总剩几颗汤圆。它们吸了夜市的水汽，慢慢长出小手小脚，最见不得街尾有恶客站着。汤圆仔不会走，只会把同伴一颗颗抛出去，弧线落得又准又黏。',
    ability: '每隔 2.6 秒向本行最右边的恶客抛出一颗汤圆，走抛物线，落地造成 40 伤害并优先砸护具。进化可加伤害、加快投掷，或让落点附带减速。',
    quote: '趁热，别躲。'
  },
  {
    type: 'torch',
    name: '炭火盆',
    epithet: '整条街的火都借它一口',
    story: '夜市收摊前，摊主会把各家的炭火并进这只旧铜盆。火苗不高，却认路：签筒的竹签、汤圆的糖壳、狐尾的尾火从旁边过，都会被它舔上一口，飞出去时带着一层暖光。',
    ability: '不主动攻击。只有穿过火盆火焰的友方射弹才会被增幅：伤害 +50%，进化可提高到 +80%/105%/130%，并让穿过的射弹附带灼烧或减速。多只火盆只取最高值，不叠加；没穿过的射弹不受影响。',
    quote: '火不分家，光借你一半。'
  },
  {
    type: 'star',
    name: '五路巡灯',
    epithet: '一盏灯巡五方',
    story: '庙会拆台时落下的五角巡灯，骨架是五根旧竹篾，灯面上画着五个方位。点起来以后，它不肯只照自己摊前，总要朝五个方向各送一道灯焰，像在替谁巡夜。',
    ability: '每隔 2.6 秒，检查正后、正上、正下、右上、右下五个方向；哪个方向有恶客，就朝哪个方向射出一道灯焰，每道 12 伤害。没有敌人的方向不会发灯。进化可加伤害、缩短间隔，或让灯焰附带易伤。',
    quote: '五个方向，都得亮着。'
  },
  {
    type: 'needle',
    name: '透骨针',
    epithet: '纸扎铺里最硬的一根',
    story: '纸扎铺的针线盒底压着一根黑铁针，缝过纸人，也缝过不该缝的东西。它不认纸壳、不认陶瓮，只认皮囊底下那口气。摊主说，针尖凉，是因为它走过的路都比别处深。',
    ability: '优先攻击本行带护具的恶客，射出的骨针无视护具，直接扣本体血量。每 1.7 秒一针，14 伤害；进化可加伤害、加快出针或附加易伤。',
    quote: '壳再厚，也隔不住一口气。'
  },
  {
    type: 'judge',
    name: '钟馗像',
    epithet: '挂在门后的那双眼',
    story: '旧货摊最里面挂着一幅钟馗像，画工不算好，眼睛却像一直睁着。夜市闹得最凶那晚，画里的人忽然抬了抬袖子，街口的恶客就退了三步。第二天摊主给它添了一炷香，再没摘下来。',
    ability: '每隔 6 秒睁眼，望向本行 260 像素内最近的恶客，造成 30 伤害并击退 0.4 格。进化可加击退距离、缩短显灵间隔或提高伤害。',
    quote: '这条街，看着我。'
  },
  {
    type: 'lily',
    name: '夜莲',
    epithet: '水面上借你一块落脚地',
    story: '暗河里漂着几片不肯沉的夜莲，叶脉里像藏着一线灯火。老摊主把灯灰撒下去，莲叶便停在水面不动，成了给别的植物落脚的一块浮台。',
    ability: '只能放在水面，作为其他植物的浮台；上面的植物正常生长与攻击。不可升阶。水面没有夜莲时，普通植物无法直接种下。',
    quote: '先有叶，再有花。'
  },
  {
    type: 'kelp',
    name: '缠魂藻',
    epithet: '这条臭水沟会自己收人',
    story: '臭水沟底缠着一团发青的水藻，平时像一堆烂绳。等恶客踩进水面，它才突然收紧，把对方拖进河泥里。拖完这一次，藻叶也散了。',
    ability: '只能种在水面；恶客进入 120 像素范围后，用 0.5 秒拖入水底并造成 1800 伤害，一次性消失。不可升阶。',
    quote: '水底下，有人拉你。'
  }
];

export const ALMANAC_ZOMBIES = [
  {
    type: 'ghost',
    name: '饿鬼',
    epithet: '闻着香火来的',
    story: '子时过后，街口总会多出几道影子。它们不记得生前叫什么，只记得夜市的味道。饿鬼走得慢，啃东西也不快，但它们从不在乎——反正天还长，摊子总会打烊。',
    ability: '低阶恶客：血量 90，沿本行慢慢往前，停下啃食植物，啃食 35/秒。',
    counter: '前几波的主要杂兵；连发与范围清场都能轻松处理，别让它们磨到门口。',
    quote: '就一口，真的就一口。'
  },
  {
    type: 'paper',
    name: '纸人',
    epithet: '一戳就散，先拿张纸挡着',
    story: '纸人是白事铺里扎剩下的边角料，被野风吹到夜市，捡了张旧告示糊在身上，就当自己有了脸。它很爱惜那层纸壳，哪怕被竹签戳得叮当响，也要先把里头那口纸气撑住。',
    ability: '中阶恶客：纸壳 250 + 本体 420，速度比饿鬼稍慢。纸壳先碎，本体后倒。',
    counter: '先用连发撕壳，再用铜铃拖住；没有破壳前别只靠单发签筒。',
    quote: '别碰脸，脸是借来的。'
  },
  {
    type: 'mountain',
    name: '山魈',
    epithet: '不讲道理的大块头',
    story: '山魈是从城外山上下来的。据说今年山里的果子不好，它一路闻到夜市，就没打算回去。它个头大、脾气坏，啃石磨像啃豆腐，偶尔还会停下来看看摊主有没有藏酒。',
    ability: '高阶恶客：血量 1800，走得慢，但啃食伤害 180/秒，能正面啃穿石磨。',
    counter: '石磨和铜铃一起拖，再用多路签筒集火；单靠一株签筒顶不住。',
    quote: '果子呢？没有果子就啃摊子。'
  },
  {
    type: 'tongue',
    name: '长舌鬼',
    epithet: '舌头比脚先到',
    story: '长舌鬼生前是个爱传闲话的，死后舌头没缩回去，越长越红。它走路急，吃相更急，隔着半个摊子就把舌头探过来。摊主们说，听它嚼东西的动静，比听它说话还难受。',
    ability: '低阶快手：血量 80，移动速度 30，啃食 45/秒；啃食距离约 62 像素，会在更早的位置停下开咬。',
    counter: '在它够到之前用铜铃或香炉减速，再让签筒点掉；纸伞能把它收进伞腹，但别让它先啃到伞面。',
    quote: '我就舔一下，不咬。'
  },
  {
    type: 'mourner',
    name: '哭丧鬼',
    epithet: '一哭，整条街都急',
    story: '哭丧鬼原是白事铺请来的哭灵人，哭了一辈子别人的丧事，最后没人替她哭。她夜里沿着摊位慢慢走，哭声不大，却让周围的恶客都跟着心慌，脚步快得像是有人在后面催。',
    ability: '中阶辅助：血量 620，行走慢；每 4.5 秒哭号一次，使周围 150 像素内的恶客加速 35%，持续 2.6 秒。',
    counter: '优先点杀，别让她站在怪堆里；减速能抵消她带来的加速，范围伤害也容易顺带清掉。',
    quote: '别急，还没轮到你。'
  },
  {
    type: 'sedan',
    name: '抬轿鬼',
    epithet: '轿子没落，客人还在',
    story: '抬轿鬼抬着一顶褪色的红轿，轿帘后面坐着谁，没人看清过。它们走得不快，轿子却硬得很，像把一整场喜事都糊在了木头上。轿破的时候，里头的东西会自己下来走，一边走一边找原来的路。',
    ability: '高阶恶客：本体 520 耐久，另有 950 轿壳；攻击先打轿壳。轿壳破裂时，会从轿中跌出 2 只饿鬼，各继承 60% 血量。',
    counter: '先用签筒磨轿，再用爆竹或香炉一次收掉跌出来的饿鬼；铜铃能把整队拖在门口。透骨针可以绕过轿壳直接伤本体，但伤害不高，适合收尾。',
    quote: '起轿——别问去哪。'
  },
  {
    type: 'straw',
    name: '斗笠鬼',
    epithet: '破斗笠遮半张脸',
    story: '斗笠鬼生前是赶夜路的挑夫，死后还记着那顶破斗笠。斗笠压得很低，只露出半张嘴，走路一晃一晃，像担子还在肩上。谁要掀它的斗笠，它就先啃谁家的摊脚。',
    ability: '低阶恶客：本体 90 血量，斗笠护具 90；攻击先扣斗笠，再扣本体。速度 22，啃食 35/秒。',
    counter: '斗笠只是薄薄一层，连发签筒很快就能打掉；骨针可以跳过斗笠直接杀本体。',
    quote: '别掀，风大。'
  },
  {
    type: 'stonehat',
    name: '石帽鬼',
    epithet: '把碑帽戴在头上',
    story: '石帽鬼从乱葬岗来，头上扣着半块碑帽，压得脖子歪向一边。它走得不快，可那顶石帽替它挨过不少竹签。石帽碎了以后，它反倒走得更急，像终于卸下了什么。',
    ability: '中阶恶客：本体 240 血量，石帽护具 320；速度 18，啃食 75/秒。护具破碎后仍会继续前进。',
    counter: '先集中火力碎帽，再补刀；透骨针无视石帽，能省下破帽时间。',
    quote: '碑上没名字，帽子有。'
  },
  {
    type: 'bucket',
    name: '瓮头鬼',
    epithet: '陶瓮扣头，油盐不进',
    story: '瓮头鬼从酒坊废墟里捡来一只裂口陶瓮，扣在头上就再没摘过。瓮里闷着它自己的回声，敲起来嗡嗡响。它走得很慢，却极有耐心，像认定夜市欠它一笔旧账。',
    ability: '中阶重甲：本体 300 血量，陶瓮护具 620；速度 15，啃食 90/秒。陶瓮极硬，普通射弹要先磨掉护具。',
    counter: '用高伤害或易伤集火破瓮；透骨针绕过陶瓮，但单发伤害低，最好和签筒混编。',
    quote: '瓮里有酒吗？有，我。'
  },
  {
    type: 'vault',
    name: '跳幡鬼',
    epithet: '幡杆一撑，跳过第一摊',
    story: '跳幡鬼原是个送葬班子的学徒，死后还攥着那根引魂幡杆。它遇到第一株植物会撑幡跳过，落地后幡杆一扔，才老老实实开始啃。那一跳不高，却总让人措手不及。',
    ability: '中阶特殊：本体 280 血量，无护具；第一次遇到植物会撑幡跳过它，落地后速度从 30 降到 18。跳过时不啃食。',
    counter: '在它落点后方再补一株植物，或用铜铃在它起跳前减速；透骨针可以直接消耗它的本体。',
    quote: '借过，借过。'
  },
  {
    type: 'artisan',
    name: '纸扎匠',
    epithet: '给小鬼糊一身纸甲',
    story: '纸扎匠背着一整架糊好的纸甲，走起路来哗啦响。它不急着啃摊子，先给街上的小鬼一人发一副纸甲，像在替谁办一场迟到的差事。纸甲不值钱，却能让饿鬼多挨好几下。',
    ability: '高阶辅助：本体 1100 血量，无护具，体型大。每 7.5 秒给 240 像素内最多 2 只低阶恶客发 200 点纸甲；纸甲与已有护具不叠加，只取更厚的一层。',
    counter: '优先点杀纸扎匠，别让它反复发甲；透骨针可以直接伤它本体，狐尾灯也能跨行追它。',
    quote: '穿上，体面点走。'
  },
  {
    type: 'ironjudge',
    name: '铁面判官',
    epithet: '铁面之下，没有冤魂',
    story: '铁面判官从城隍庙的偏殿里走出来，脸上那副铁面具锈得看不出表情。它每一步都像在敲惊堂木，走过的地方，摊板会轻轻发颤。没人知道它要审谁，只知道它从不空手回去。',
    ability: '高阶重甲：本体 1000 血量，铁面护具 800，体型大；速度 12，啃食 150/秒。普通攻击要先破铁面，护具破碎后本体仍极硬。',
    counter: '铁面判官是硬仗：先用易伤与高伤射弹破面，再让透骨针收本体；铜铃和纸伞能拖住它的脚步。',
    quote: '跪下，报上名来。'
  }
];

export function almanacEntries(tab) {
  return tab === 'zombie' ? ALMANAC_ZOMBIES : ALMANAC_PLANTS;
}

function firstAppearanceOf(type) {
  for (const level of LEVELS) {
    for (let i = 0; i < level.waves.length; i++) {
      for (const [ztype, count] of level.waves[i].groups) {
        if (ztype === type && count > 0) {
          return `第${level.id}关·第${i + 1}波`;
        }
      }
    }
  }
  return '';
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
      { label: '攻击', value: '无（进化后碎石）', tone: 'neutral' },
      { label: '定位', value: '肉盾', tone: 'green' },
      { label: '占格', value: '1 格', tone: 'neutral' }
    );
  } else if (type === 'mushroom') {
    stats.push(
      { label: '长成时间', value: `${d.mine.arm} 秒`, tone: 'time' },
      { label: '鬼火伤害', value: String(d.mine.damage), tone: 'atk' },
      { label: '类别', value: '灰烬 · 一次性', tone: 'cost' },
      { label: '触发', value: '踩中即爆', tone: 'green' }
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
      { label: '减速', value: '25%', tone: 'teal' },
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
      { label: '吞噬', value: '非大型即死', tone: 'green' },
      { label: '咀嚼', value: `${d.chomp.chew} 秒`, tone: 'time' },
      { label: '对大型', value: `${d.chomp.largeDamage} 伤害`, tone: 'atk' }
    );
  } else if (type === 'lion') {
    stats.push(
      { label: '撞头伤害', value: String(PLANT_EFFECTS.lion.damage[0]), tone: 'atk' },
      { label: '攻击间隔', value: `${PLANT_EFFECTS.lion.interval[0]} 秒`, tone: 'time' },
      { label: '攻击距离', value: String(PLANT_EFFECTS.lion.reach), tone: 'neutral' },
      { label: '击退', value: `${PLANT_EFFECTS.lion.knockCells} 格`, tone: 'teal' }
    );
  } else if (type === 'cat') {
    stats.push(
      { label: '攻击间隔', value: `${d.homing.interval} 秒`, tone: 'time' },
      { label: '尾火伤害', value: String(d.homing.damage), tone: 'atk' },
      { label: '索敌', value: '全场绝对最近', tone: 'teal' },
      { label: '特性', value: '跨行追踪', tone: 'green' }
    );
  } else if (type === 'shell') {
    stats.push(
      { label: '护罩耐久', value: String(PLANT_EFFECTS.shell.hp), tone: 'hp' },
      { label: '占格', value: '罩在植物上', tone: 'neutral' },
      { label: '类别', value: '护罩 · 不可升阶', tone: 'cost' }
    );
  } else if (type === 'lobber') {
    stats.push(
      { label: '攻击间隔', value: `${d.lob.interval} 秒`, tone: 'time' },
      { label: '汤圆伤害', value: String(d.lob.damage), tone: 'atk' },
      { label: '目标', value: '本行最右', tone: 'teal' },
      { label: '轨迹', value: '抛物线', tone: 'green' }
    );
  } else if (type === 'torch') {
    stats.push(
      { label: '射弹增幅', value: '+50% 伤害', tone: 'atk' },
      { label: '范围', value: '穿过火盆的射弹', tone: 'neutral' },
      { label: '规则', value: '同类不叠加', tone: 'teal' }
    );
  } else if (type === 'star') {
    stats.push(
      { label: '发灯间隔', value: `${d.star.interval} 秒`, tone: 'time' },
      { label: '每道伤害', value: String(d.star.damage), tone: 'atk' },
      { label: '范围', value: '五个方向各一道', tone: 'teal' }
    );
  } else if (type === 'needle') {
    stats.push(
      { label: '出针间隔', value: `${d.needle.interval} 秒`, tone: 'time' },
      { label: '本体伤害', value: String(d.needle.damage), tone: 'atk' },
      { label: '特性', value: '无视护具', tone: 'green' }
    );
  } else if (type === 'judge') {
    stats.push(
      { label: '显灵间隔', value: `${d.judge.interval} 秒`, tone: 'time' },
      { label: '显灵伤害', value: String(d.judge.damage), tone: 'atk' },
      { label: '范围', value: `${d.judge.reach} 像素`, tone: 'neutral' },
      { label: '击退', value: `${d.judge.knockCells} 格`, tone: 'teal' }
    );
  } else if (type === 'lily') {
    stats.push(
      { label: '种植水面', value: '必须', tone: 'teal' },
      { label: '作用', value: '承载一株植物', tone: 'neutral' },
      { label: '升阶', value: '不可升阶', tone: 'neutral' }
    );
  } else if (type === 'kelp') {
    stats.push(
      { label: '种植水面', value: '必须', tone: 'teal' },
      { label: '拖拽时间', value: `${d.tangle.drag} 秒`, tone: 'time' },
      { label: '伤害', value: String(d.tangle.damage), tone: 'atk' },
      { label: '使用', value: '一次性', tone: 'neutral' }
    );
  }
  return stats;
}

export function zombieBaseStats(type) {
  const d = ZOMBIE_TYPES[type];
  const tierTone = d.tier === 'h' ? 'atk' : d.tier === 'm' ? 'gold' : 'teal';
  const armorName = d.armorName || '护具';
  const stats = [
    { label: '阶级', value: zombieTierLabel(d.tier), tone: tierTone },
    { label: '本体血量', value: String(d.hp), tone: 'hp' },
    { label: '护具', value: d.armor > 0 ? `${armorName} ${d.armor}` : '无', tone: d.armor > 0 ? 'gold' : 'neutral' },
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
  } else if (type === 'vault') {
    stats.push({ label: '跳幡', value: `跳过首株 · 落地速度 ${d.vault.speedAfter}`, tone: 'green' });
  } else if (type === 'artisan') {
    stats.push({ label: '发甲间隔', value: `${d.support.interval} 秒`, tone: 'time' });
    stats.push({ label: '发甲', value: `${d.support.armor} 护具 · 最多 ${d.support.targets} 只低阶`, tone: 'gold' });
    stats.push({ label: '发甲半径', value: String(d.support.radius), tone: 'neutral' });
  } else if (type === 'ironjudge') {
    stats.push({ label: '体型', value: '大型 · 尸体停留 1 秒', tone: 'atk' });
  }
  const appearance = firstAppearanceOf(type);
  if (appearance) stats.push({ label: '初遇', value: appearance, tone: 'teal' });
  const traits = {
    ghost: '数量多', paper: '纸壳护具', mountain: '重型',
    tongue: '快手', mourner: '助威', sedan: '破轿分身',
    straw: '斗笠护具', stonehat: '石帽护具', bucket: '陶瓮重甲',
    vault: '跳幡跳过首株', artisan: '分发纸甲', ironjudge: '铁面重甲'
  };
  stats.push({
    label: '特性',
    value: traits[type] || '数量多',
    tone: 'green'
  });
  return stats;
}
