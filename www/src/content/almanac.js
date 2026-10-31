import { PLANT_TYPES, ZOMBIE_TYPES, LEVELS, zombieTierLabel } from '../content.js';
import { PLANT_EFFECTS } from '../game/upgrade.js';

const CELL_PX = 88;

function inCells(px) {
  const cells = px / CELL_PX;
  return `${cells.toFixed(1).replace(/\.0$/, '')} 格`;
}

export const ALMANAC_PLANTS = [
  {
    type: 'lantern',
    name: '红灯笼',
    epithet: '摊前第一盏',
    story: '收摊以后，别的物件都睡了，只有它还亮着。灯芯是摊主从河灯会上换来的，据说照过谁的回头路。它不爱说话，只在你数香火时晃一下，像在提醒：账可以慢点算，灯不能灭。',
    ability: '产能：每 8 秒吐出一团 25 香火，首次 5 秒，落地后可收取。进化：一路提高产量（最高 75），一路缩短间隔（最低 5 秒），一路让灯火增幅身前友军（伤害 +20%，满阶 +25%）。增幅多盏只取最高值，不叠加。',
    quote: '灯亮着，摊子就还在。'
  },
  {
    type: 'shooter',
    name: '签筒',
    epithet: '手熟的黑签',
    story: '签筒原是算命摊上的旧物，签文被雨水泡烂了，只剩筒身还硬朗。它把剩下的竹签当暗器使，起初只为了吓野猫，后来发现对恶客也挺好使。每回甩签前都要抖三下，像在给自己壮胆。',
    ability: '本行输出：每 1.4 秒朝前方射出一发竹签，单发 20 伤害。进化：一路连发（最高六发），一路借射上下邻行（半伤到满伤），一路甩出双倍伤害的大签（最高 30% 概率，命中附带减速）。',
    quote: '不求百发百中，只求你别过来。'
  },
  {
    type: 'wall',
    name: '石磨',
    epithet: '不肯挪窝的老石头',
    story: '石磨在夜市口蹲了很多年，磨过豆子、磨过辣椒，也磨过几个不长眼的小贼的鞋底。它不爱说话，磨齿一响，整条街就知道今晚有人要吃亏。摊主给它系过一条红绳，后来被它自己磨断了。',
    ability: '肉盾：耐久 3000，替同行挡下啃食。进化：一路自愈（最高 40/秒，满阶被啃也能回），一路反伤（最高 50/秒），一路磨出碎石射击（20 伤害、命中易伤；满阶把非大型恶客击退 0.4 格，对大型改为双倍伤害）。',
    quote: '想过去？先问磨齿。'
  },
  {
    type: 'bomb',
    name: '爆竹',
    epithet: '一响就散的急脾气',
    story: '它本是年初一早上用的，被摊主忘在柜底，一忘就是一整年。再拿出来时，它已经憋坏了。引信一点，它先骂一句，再把整条街炸得亮堂堂。没人记得它炸完以后去了哪，大概是被自己吵没了。',
    ability: '灰烬类 · 一次性：点燃后引信 1.2 秒，在约 1.7 格半径内造成 1800 伤害。不可升阶。',
    quote: '别劝，劝就是炸。'
  },
  {
    type: 'mushroom',
    name: '坟头菇',
    epithet: '坟头土里长出来的',
    story: '夜市后巷的坟头土最养菇。它埋下去时不声不响，伞盖下压着两张旧符，像替谁守着最后一口气。等它鼓起来，谁踩上去，它就把攒了半宿的鬼火全喷出来，连自己一起烧没。',
    ability: '灰烬类 · 一次性陷阱：埋下后 14 秒长成，恶客踩中即喷发鬼火，造成 1800 伤害并同归于尽。不可升阶。',
    quote: '别踩，下面埋着东西。'
  },
  {
    type: 'bell',
    name: '铜铃',
    epithet: '先声夺人',
    story: '铜铃挂在摊棚角上，平时只是摆设。直到有一晚，饿鬼踩着铃影过来，它突然自己响了。声音不大，却让整条街的恶客都慢了半拍。从那以后它有了差事：别人动手之前，先由它开口。',
    ability: '控制与辅助：每 2.5 秒摇铃，使本行前方恶客减速 25%、持续 1.5 秒。进化：一路加快摇铃并把减速提到 40%，一路用铃声增幅友军攻速，一路让铃浪造成伤害（40 点）乃至定身。减速只取最强值，不叠加。',
    quote: '先听个响，再谈别的。'
  },
  {
    type: 'censer',
    name: '香炉',
    epithet: '账房檐下的老炉',
    story: '夜市账房门口有只三足铜炉，常年压着半本赊账簿。账房先生说，香灰里埋着往年没还清的名字，所以炉子总在半夜自己冒烟。它不记账，只把那些名字一圈圈熏开，像替谁把没说完的话说完。',
    ability: '范围输出：每 3 秒喷出一圈香雾，对圈内恶客造成 45 伤害。进化：一路加伤害（最高 140），一路把烟圈从约 1.6 格扩到 2.4 格，一路让被熏到的恶客减速（最高 45%、持续 3 秒）。',
    quote: '账可以慢算，烟不能断。'
  },
  {
    type: 'umbrella',
    name: '纸伞',
    epithet: '收得下夜客，也收得下香火',
    story: '这把油纸伞替摊娘挡过三年夜雨，伞面上画的海棠早褪了色。后来夜市里多了一种说法：撑开它挡雨，收起它收妖。伞骨一合，饿鬼纸人就被卷进伞腹；再撑开时，只剩一团香火落在摊前。',
    ability: '收妖 · 肉盾：耐久 900，非大型恶客靠近即被收入伞中，6 秒收化；大型恶客撑不进伞，只能被伞骨击打，每次 40 伤害。进化：一路加快收妖，一路收妖后产香火（最高 225），一路减少收妖期间受到的伤害（最高 75%）。',
    quote: '伞下这寸地，归我管。'
  },
  {
    type: 'lion',
    name: '醒狮',
    epithet: '初一请来的狮头',
    story: '年初一舞狮队从摊前过，把这只旧狮头落在了货架底下。摊主嫌它占地方，几次想扔，最后都留了下来。入夜后它会自己抖毛，听见恶客的脚步就低头撞过去，撞完了还要甩甩鬃毛，像在等一声叫好。',
    ability: '近战守卫：恶客靠近到约 1.3 格内时，每 1.5 秒撞头一次，造成 50 伤害并击退 0.2 格。进化：一路加伤害与击退（最高 130），一路加快撞击并有 25% 撞晕，一路命中回耐久（最高 70）。',
    quote: '狮子不咬人，狮子只撞。'
  },
  {
    type: 'cat',
    name: '狐尾灯',
    epithet: '追着最近那口气走',
    story: '夜市西头的旧灯架上挂着一截狐尾形状的灯芯。摊主说，那是只走丢的狐妖留下的最后一点火。它不照路，只照人：谁身上的阴气最重，尾火就朝谁飘过去，绕一圈再回来，像狐狸在确认猎物还在不在。',
    ability: '跨行追踪：每 1.6 秒放出一团尾火，自动追向全场最近的恶客，每团 24 伤害。进化：一路增加尾火数量（最高四团），一路提伤害并让尾火再追一个目标，一路附加易伤与减速。易伤、减速只取最强值，不叠加。',
    quote: '别回头，它已经看见你了。'
  },
  {
    type: 'shell',
    name: '龟甲罩',
    epithet: '老龟留下的半间屋',
    story: '河滩上捡来的老龟甲，壳口磨得发亮。摊主把它罩在怕风的物件上，后来发现恶客啃壳比啃摊子还费劲。壳里那株植物照常做事，只是从此多了一层沉默的屋顶。',
    ability: '护罩：只能罩在已种下的植物上，提供 1400 点护罩耐久；恶客先啃龟甲，壳碎后里面的植物仍在。不可升阶；用铲子可单独拆下龟甲，不伤宿主。',
    quote: '壳在，摊就在。'
  },
  {
    type: 'lobber',
    name: '汤圆仔',
    epithet: '一碗会自己动手的宵夜',
    story: '甜品摊收工后，锅里总剩几颗汤圆。它们吸了夜市的水汽，慢慢长出小手小脚，最见不得街尾有恶客站着。汤圆仔不会走，只会把同伴一颗颗抛出去，弧线落得又准又黏。',
    ability: '后排打击：每 2.6 秒向本行最右侧的恶客抛出一颗汤圆，走抛物线越过前排，落地造成 40 伤害并优先砸护具。进化：一路加伤害（最高 100），一路加快投掷，一路让落点附带减速（最高 40%）。',
    quote: '趁热，别躲。'
  },
  {
    type: 'torch',
    name: '炭火盆',
    epithet: '整条街的火都借它一口',
    story: '夜市收摊前，摊主会把各家的炭火并进这只旧铜盆。火苗不高，却认路：签筒的竹签、汤圆的糖壳、狐尾的尾火从旁边过，都会被它舔上一口，飞出去时带着一层暖光。',
    ability: '增幅：不主动攻击，只有穿过火盆火焰的友方射弹才会被增幅，伤害 +50%。进化：一路把增幅提到 +80%／+105%／+130%，一路为穿过的射弹附加灼烧，一路附加减速。多盆只取最高值，不叠加；没穿过的射弹不受影响。',
    quote: '火不分家，光借你一半。'
  },
  {
    type: 'star',
    name: '五路巡灯',
    epithet: '一盏灯巡五方',
    story: '庙会拆台时落下的五角巡灯，骨架是五根旧竹篾，灯面上画着五个方位。点起来以后，它不肯只照自己摊前，总要朝五个方向各送一道灯焰，像在替谁巡夜。',
    ability: '多方向：每 2.6 秒检查正后、正上、正下、右上、右下五个方向，哪个方向有恶客就射出一道 16 伤害的灯焰，没有敌人的方向不发灯。进化：一路加伤害（最高 32），一路加快转灯，一路附加易伤。',
    quote: '五个方向，都得亮着。'
  },
  {
    type: 'needle',
    name: '透骨针',
    epithet: '纸扎铺里最硬的一根',
    story: '纸扎铺的针线盒底压着一根黑铁针，缝过纸人，也缝过不该缝的东西。它不认纸壳、不认陶瓮，只认皮囊底下那口气。摊主说，针尖凉，是因为它走过的路都比别处深。',
    ability: '破甲：优先攻击本行带护具的恶客，骨针无视护具直接扣本体血量，每 1.7 秒一针、18 伤害。进化：一路加伤害（最高 36），一路加快出针，一路附加易伤。',
    quote: '壳再厚，也隔不住一口气。'
  },
  {
    type: 'judge',
    name: '钟馗像',
    epithet: '挂在门后的那双眼',
    story: '旧货摊最里面挂着一幅钟馗像，画工不算好，眼睛却像一直睁着。夜市闹得最凶那晚，画里的人忽然抬了抬袖子，街口的恶客就退了三步。第二天摊主给它添了一炷香，再没摘下来。',
    ability: '控制：每 5.5 秒睁眼，望向本行约 3 格内最近的恶客，造成 40 伤害并把它顶回去 0.4 格。进化：一路加击退（最高 0.9 格），一路缩短显灵间隔（最低 3.5 秒），一路提高伤害（最高 72）。一次只盯一只，大型恶客也会被顶退。',
    quote: '这条街，看着我。'
  },
  {
    type: 'lily',
    name: '夜莲',
    epithet: '水面上借你一块落脚地',
    story: '暗河里漂着几片不肯沉的夜莲，叶脉里像藏着一线灯火。摊主把灯灰撒下去，莲叶便停在水面不动，成了给别的植物落脚的一块浮台。',
    ability: '浮台：只能放在水面，为其他植物提供一块落脚地，上面的植物正常生长与攻击。不可升阶；水面没有夜莲时，普通植物无法直接种下。',
    quote: '先有叶，再有花。'
  },
  {
    type: 'kelp',
    name: '缠魂藻',
    epithet: '这条臭水沟会自己收人',
    story: '臭水沟底缠着一团发青的水藻，平时像一堆烂绳。等恶客踩进水面，它才突然收紧，把对方拖进河泥里。拖完这一次，藻叶也散了。',
    ability: '灰烬类 · 一次性：只能种在水面，恶客进入约 1.4 格范围后用 0.5 秒把它拖入水底，造成 1800 伤害，随后自己散掉。不可升阶。',
    quote: '水底下，有人拉你。'
  }
];

export const ALMANAC_ZOMBIES = [
  {
    type: 'ghost',
    name: '饿鬼',
    epithet: '闻着香火来的',
    story: '子时过后，街口总会多出几道影子。它们不记得生前叫什么，只记得夜市的味道。饿鬼走得慢，啃东西也不快，但它们从不在乎——反正天还长，摊子总会打烊。',
    ability: '低阶杂兵：本体 90，无护具；速度 21，啃食 35/秒。数量最多，沿本行往前，停下就开咬。',
    counter: '前几波的主要杂兵；连发与范围清场都能轻松处理，别让它们磨到门口。',
    quote: '就一口，真的就一口。'
  },
  {
    type: 'paper',
    name: '纸人',
    epithet: '一戳就散，先拿张纸挡着',
    story: '纸人是白事铺里扎剩下的边角料，被野风吹到夜市，捡了张旧告示糊在身上，就当自己有了脸。它很爱惜那层纸壳，哪怕被竹签戳得叮当响，也要先把里头那口纸气撑住。',
    ability: '中阶护具：本体 420，纸壳 250；速度 19，啃食 80/秒。攻击先撕纸壳，壳碎后本体才倒。',
    counter: '先用连发撕壳，再用铜铃拖住；没破壳前别只靠单发签筒。',
    quote: '别碰脸，脸是借来的。'
  },
  {
    type: 'mountain',
    name: '山魈',
    epithet: '不讲道理的大块头',
    story: '山魈是从城外山上下来的。据说今年山里的果子不好，它一路闻到夜市，就没打算回去。它个头大、脾气坏，啃石磨像啃豆腐，偶尔还会停下来看看摊主有没有藏酒。',
    ability: '高阶重型：本体 1800，无护具；速度 16，啃食 180/秒。体型大，能正面啃穿石磨，尸体停留 1 秒。',
    counter: '石磨和铜铃一起拖，再用多路签筒集火；单靠一株签筒顶不住。',
    quote: '果子呢？没有果子就啃摊子。'
  },
  {
    type: 'tongue',
    name: '长舌鬼',
    epithet: '舌头比脚先到',
    story: '长舌鬼生前是个爱传闲话的，死后舌头没缩回去，越长越红。它走路急，吃相更急，隔着半个摊子就把舌头探过来。摊主们说，听它嚼东西的动静，比听它说话还难受。',
    ability: '低阶快手：本体 80，无护具；速度 30，啃食 45/秒。约 0.7 格外就会停下开咬，比别的低阶更早动手。',
    counter: '在它够到之前用铜铃或香炉减速，再让签筒点掉；纸伞能把它收进伞腹，但别让它先啃到伞面。',
    quote: '我就舔一下，不咬。'
  },
  {
    type: 'mourner',
    name: '哭丧鬼',
    epithet: '一哭，整条街都急',
    story: '哭丧鬼原是白事铺请来的哭灵人，哭了一辈子别人的丧事，最后没人替她哭。她夜里沿着摊位慢慢走，哭声不大，却让周围的恶客都跟着心慌，脚步快得像是有人在后面催。',
    ability: '中阶辅助：本体 620，无护具；速度 16，啃食 75/秒。每 4.5 秒哭号一次，让约 1.7 格内的恶客加速 35%、持续 2.6 秒。',
    counter: '优先点杀，别让她站在怪堆里；减速能抵消她带来的加速，范围伤害也容易顺带清掉。',
    quote: '别急，还没轮到你。'
  },
  {
    type: 'sedan',
    name: '抬轿鬼',
    epithet: '轿子没落，客人还在',
    story: '抬轿鬼抬着一顶褪色的红轿，轿帘后面坐着谁，没人看清过。它们走得不快，轿子却硬得很，像把一整场喜事都糊在了木头上。轿破的时候，里头的东西会自己下来走，一边走一边找原来的路。',
    ability: '高阶护具：本体 520，轿壳 950；速度 14，啃食 120/秒。攻击先打轿壳；轿壳破裂时跌出 2 只饿鬼，各带 60% 血量。',
    counter: '先用签筒磨轿，再用爆竹或香炉一次收掉跌出来的饿鬼；铜铃能把整队拖在门口。透骨针可以绕过轿壳直接伤本体，适合收尾。',
    quote: '起轿——别问去哪。'
  },
  {
    type: 'straw',
    name: '斗笠鬼',
    epithet: '破斗笠遮半张脸',
    story: '斗笠鬼生前是赶夜路的挑夫，死后还记着那顶破斗笠。斗笠压得很低，只露出半张嘴，走路一晃一晃，像担子还在肩上。谁要掀它的斗笠，它就先啃谁家的摊脚。',
    ability: '低阶护具：本体 90，斗笠 90；速度 22，啃食 35/秒。斗笠很薄，破掉后本体照常前进。',
    counter: '连发签筒很快就能打掉斗笠；透骨针可以跳过斗笠直接杀本体。',
    quote: '别掀，风大。'
  },
  {
    type: 'stonehat',
    name: '石帽鬼',
    epithet: '把碑帽戴在头上',
    story: '石帽鬼从乱葬岗来，头上扣着半块碑帽，压得脖子歪向一边。它走得不快，可那顶石帽替它挨过不少竹签。石帽碎了以后，它反倒走得更急，像终于卸下了什么。',
    ability: '中阶护具：本体 240，石帽 320；速度 18，啃食 75/秒。护具破碎后仍会继续前进。',
    counter: '先集中火力碎帽，再补刀；透骨针无视石帽，能省下破帽时间。',
    quote: '碑上没名字，帽子有。'
  },
  {
    type: 'bucket',
    name: '瓮头鬼',
    epithet: '陶瓮扣头，油盐不进',
    story: '瓮头鬼从酒坊废墟里捡来一只裂口陶瓮，扣在头上就再没摘过。瓮里闷着它自己的回声，敲起来嗡嗡响。它走得很慢，却极有耐心，像认定夜市欠它一笔旧账。',
    ability: '中阶重甲：本体 300，陶瓮 620；速度 15，啃食 90/秒。陶瓮极硬，普通射弹要先磨掉护具。',
    counter: '用高伤害或易伤集火破瓮；透骨针绕过陶瓮，最好和签筒混编。',
    quote: '瓮里有酒吗？有，我。'
  },
  {
    type: 'vault',
    name: '跳幡鬼',
    epithet: '幡杆一撑，跳过第一摊',
    story: '跳幡鬼原是个送葬班子的学徒，死后还攥着那根引魂幡杆。它遇到第一株植物会撑幡跳过，落地后幡杆一扔，才老老实实开始啃。那一跳不高，却总让人措手不及。',
    ability: '中阶特殊：本体 280，无护具；速度 30，啃食 60/秒。第一次遇到植物会撑幡跳过它，落地后速度降到 18，跳过时不啃食。',
    counter: '在它落点后方再补一株植物，或用铜铃在它起跳前减速；透骨针可以直接消耗它的本体。',
    quote: '借过，借过。'
  },
  {
    type: 'artisan',
    name: '纸扎匠',
    epithet: '给小鬼糊一身纸甲',
    story: '纸扎匠背着一整架糊好的纸甲，走起路来哗啦响。它不急着啃摊子，先给街上的小鬼一人发一副纸甲，像在替谁办一场迟到的差事。纸甲不值钱，却能让饿鬼多挨好几下。',
    ability: '高阶辅助：本体 1100，无护具，体型大；速度 14，啃食 90/秒。每 7.5 秒给约 2.7 格内最多 2 只低阶恶客发 200 点纸甲；纸甲与已有护具不叠加，只取更厚的一层。',
    counter: '优先点杀纸扎匠，别让它反复发甲；透骨针可以直接伤它本体，狐尾灯也能跨行追它。',
    quote: '穿上，体面点走。'
  },
  {
    type: 'ironjudge',
    name: '铁面判官',
    epithet: '铁面之下，没有冤魂',
    story: '铁面判官从城隍庙的偏殿里走出来，脸上那副铁面具锈得看不出表情。它每一步都像在敲惊堂木，走过的地方，摊板会轻轻发颤。没人知道它要审谁，只知道它从不空手回去。',
    ability: '高阶重甲：本体 1000，铁面 800，体型大；速度 12，啃食 150/秒。要先破铁面，破面后本体仍极硬，尸体停留 1 秒。',
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
          return `${level.dayName}·${level.name} 第${i + 1}波`;
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
      { label: '单次产量', value: String(d.produce.value), tone: 'gold' },
      { label: '产出间隔', value: `${d.produce.interval} 秒`, tone: 'time' },
      { label: '首次产出', value: `${d.produce.first} 秒`, tone: 'time' },
      { label: '特性', value: '增幅取最高', tone: 'desc' }
    );
  } else if (type === 'shooter') {
    stats.push(
      { label: '单发伤害', value: String(d.shot.damage), tone: 'atk' },
      { label: '攻击间隔', value: `${d.shot.interval} 秒`, tone: 'time' },
      { label: '范围', value: '本行前方', tone: 'desc' },
      { label: '定位', value: '主力输出', tone: 'desc' }
    );
  } else if (type === 'wall') {
    stats.push(
      { label: '攻击', value: '无 · 进化后碎石', tone: 'desc' },
      { label: '定位', value: '肉盾', tone: 'desc' },
      { label: '占格', value: '1 格', tone: 'desc' }
    );
  } else if (type === 'mushroom') {
    stats.push(
      { label: '鬼火伤害', value: String(d.mine.damage), tone: 'atk' },
      { label: '长成时间', value: `${d.mine.arm} 秒`, tone: 'time' },
      { label: '类别', value: '灰烬 · 一次性', tone: 'cost' },
      { label: '特性', value: '踩中即爆', tone: 'desc' }
    );
  } else if (type === 'bomb') {
    stats.push(
      { label: '爆炸伤害', value: String(d.bomb.damage), tone: 'atk' },
      { label: '引信', value: `${d.bomb.fuse} 秒`, tone: 'time' },
      { label: '范围', value: inCells(d.bomb.radius), tone: 'desc' },
      { label: '类别', value: '灰烬 · 一次性', tone: 'cost' }
    );
  } else if (type === 'bell') {
    stats.push(
      { label: '减速', value: '25%', tone: 'time' },
      { label: '持续', value: `${d.pulse.slow} 秒`, tone: 'time' },
      { label: '摇铃间隔', value: `${d.pulse.interval} 秒`, tone: 'time' },
      { label: '范围', value: '本行前方', tone: 'desc' }
    );
  } else if (type === 'censer') {
    stats.push(
      { label: '香雾伤害', value: String(PLANT_EFFECTS.censer.damage[0]), tone: 'atk' },
      { label: '喷烟间隔', value: `${PLANT_EFFECTS.censer.interval} 秒`, tone: 'time' },
      { label: '范围', value: inCells(PLANT_EFFECTS.censer.radius[0]), tone: 'desc' }
    );
  } else if (type === 'umbrella') {
    stats.push(
      { label: '收妖', value: `${d.chomp.chew} 秒`, tone: 'time' },
      { label: '对大型', value: `${d.chomp.largeDamage} 伤害`, tone: 'atk' },
      { label: '范围', value: inCells(d.chomp.reach), tone: 'desc' },
      { label: '特性', value: '非大型即收', tone: 'desc' }
    );
  } else if (type === 'lion') {
    stats.push(
      { label: '撞头伤害', value: String(PLANT_EFFECTS.lion.damage[0]), tone: 'atk' },
      { label: '攻击间隔', value: `${PLANT_EFFECTS.lion.interval[0]} 秒`, tone: 'time' },
      { label: '范围', value: inCells(PLANT_EFFECTS.lion.reach), tone: 'desc' },
      { label: '击退', value: `${PLANT_EFFECTS.lion.knockCells} 格`, tone: 'time' }
    );
  } else if (type === 'cat') {
    stats.push(
      { label: '尾火伤害', value: String(d.homing.damage), tone: 'atk' },
      { label: '攻击间隔', value: `${d.homing.interval} 秒`, tone: 'time' },
      { label: '索敌', value: '全场最近', tone: 'desc' },
      { label: '特性', value: '跨行追踪', tone: 'desc' }
    );
  } else if (type === 'shell') {
    stats.push(
      { label: '护罩耐久', value: String(PLANT_EFFECTS.shell.hp), tone: 'hp' },
      { label: '占格', value: '罩在植物上', tone: 'desc' },
      { label: '类别', value: '护罩 · 不可升阶', tone: 'cost' },
      { label: '特性', value: '可单独拆下', tone: 'desc' }
    );
  } else if (type === 'lobber') {
    stats.push(
      { label: '汤圆伤害', value: String(d.lob.damage), tone: 'atk' },
      { label: '攻击间隔', value: `${d.lob.interval} 秒`, tone: 'time' },
      { label: '目标', value: '本行最右', tone: 'desc' },
      { label: '轨迹', value: '抛物线', tone: 'desc' }
    );
  } else if (type === 'torch') {
    stats.push(
      { label: '射弹增幅', value: '+50% 伤害', tone: 'atk' },
      { label: '范围', value: '穿过火盆的射弹', tone: 'desc' },
      { label: '类别', value: '增幅 · 不攻击', tone: 'cost' },
      { label: '特性', value: '同类取最高', tone: 'desc' }
    );
  } else if (type === 'star') {
    stats.push(
      { label: '每道伤害', value: String(d.star.damage), tone: 'atk' },
      { label: '发灯间隔', value: `${d.star.interval} 秒`, tone: 'time' },
      { label: '范围', value: '五向各一道', tone: 'desc' }
    );
  } else if (type === 'needle') {
    stats.push(
      { label: '本体伤害', value: String(d.needle.damage), tone: 'atk' },
      { label: '出针间隔', value: `${d.needle.interval} 秒`, tone: 'time' },
      { label: '目标', value: '优先带护具', tone: 'desc' },
      { label: '特性', value: '无视护具', tone: 'desc' }
    );
  } else if (type === 'judge') {
    stats.push(
      { label: '显灵伤害', value: String(d.judge.damage), tone: 'atk' },
      { label: '显灵间隔', value: `${d.judge.interval} 秒`, tone: 'time' },
      { label: '范围', value: inCells(d.judge.reach), tone: 'desc' },
      { label: '击退', value: `${d.judge.knockCells} 格`, tone: 'time' }
    );
  } else if (type === 'lily') {
    stats.push(
      { label: '水面', value: '必须', tone: 'desc' },
      { label: '作用', value: '承载一株植物', tone: 'desc' },
      { label: '类别', value: '浮台 · 不可升阶', tone: 'cost' }
    );
  } else if (type === 'kelp') {
    stats.push(
      { label: '拖拽伤害', value: String(d.tangle.damage), tone: 'atk' },
      { label: '拖拽时间', value: `${d.tangle.drag} 秒`, tone: 'time' },
      { label: '范围', value: inCells(d.tangle.range), tone: 'desc' },
      { label: '类别', value: '灰烬 · 一次性', tone: 'cost' }
    );
  }
  return stats;
}

export function zombieBaseStats(type) {
  const d = ZOMBIE_TYPES[type];
  const tierTone = d.tier === 'h' ? 'atk' : d.tier === 'm' ? 'gold' : 'time';
  const stats = [
    { label: '阶级', value: zombieTierLabel(d.tier), tone: tierTone },
    { label: '本体血量', value: String(d.hp), tone: 'hp' },
    {
      label: '护具',
      value: d.armor > 0 ? `${d.armorName} ${d.armor}` : '无',
      tone: d.armor > 0 ? 'hp' : 'desc'
    },
    { label: '速度', value: String(d.speed), tone: 'time' },
    { label: '啃食', value: `${d.dps} / 秒`, tone: 'atk' }
  ];
  if (type === 'tongue') {
    stats.push({ label: '啃食距离', value: inCells(d.reach), tone: 'desc' });
  } else if (type === 'mourner') {
    stats.push({ label: '哭号范围', value: inCells(d.aura.radius), tone: 'desc' });
    stats.push({
      label: '加速',
      value: `+${Math.round((d.aura.haste - 1) * 100)}% / ${d.aura.duration} 秒`,
      tone: 'time'
    });
  } else if (type === 'sedan') {
    stats.push({
      label: '破轿',
      value: `${d.split.count} 只饿鬼 · ${Math.round(d.split.hp * 100)}% 血量`,
      tone: 'desc'
    });
  } else if (type === 'vault') {
    stats.push({ label: '跳幡', value: `跳过首株 · 落地 ${d.vault.speedAfter}`, tone: 'desc' });
  } else if (type === 'artisan') {
    stats.push({ label: '发甲间隔', value: `${d.support.interval} 秒`, tone: 'time' });
    stats.push({
      label: '纸甲',
      value: `${d.support.armor} 点 · 最多 ${d.support.targets} 只`,
      tone: 'gold'
    });
    stats.push({ label: '发甲范围', value: inCells(d.support.radius), tone: 'desc' });
  }
  if (d.large) {
    stats.push({ label: '体型', value: '大型 · 尸体停留 1 秒', tone: 'desc' });
  }
  const appearance = firstAppearanceOf(type);
  if (appearance) stats.push({ label: '初遇', value: appearance, tone: 'desc' });
  const traits = {
    ghost: '数量多', paper: '纸壳护具', mountain: '重型啃穿',
    tongue: '快手远嘴', mourner: '助威加速', sedan: '破轿分身',
    straw: '斗笠护具', stonehat: '石帽护具', bucket: '陶瓮重甲',
    vault: '跳过首株', artisan: '分发纸甲', ironjudge: '铁面重甲'
  };
  stats.push({ label: '特性', value: traits[type] || '数量多', tone: 'desc' });
  return stats;
}
