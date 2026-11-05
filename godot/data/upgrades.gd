## 升阶系统：13 株可升阶草木，每株三路、每路三级；两条路可开，只有一条能到三级。
##
## v0.4 真值：已批准的 2026-11-02 十株重设计；狐尾灯保留用户修订。
## 红灯笼、签筒、石磨与未批准替代阶保留现行值；修改须连同效果与文案一起验收。
## 设计不变量：
##  1. 实付费用一律 25 的整数倍，同一条路严格递增——不再有「原始费用 × 系数」的
##     换算，tiers[i]["cost"] 就是玩家要付的香火。
##  2. 满进化必须略亏：每株最强一路（连合法的第二路一起算）的收益增幅 / 费用增幅
##     小于 1 是一般目标；锁定巡天与用户狐尾灯是明确例外，不宣称所有组合均略亏。
##  3. 满阶给机制不给数字；条件性输出（多弹、多方向、溅射）按场上活跃目标数折算。
class_name Upgrades
extends RefCounted

const RED = "#d2492f"
const TEAL = "#4f8a86"
const GOLD = "#d0a044"

const TREES = {
	"sky-kite": [{"id": 1, "name": "散翼", "color": "#d2492f", "tiers": [{"name": "双影", "cost": 100, "desc": "同时瞄准本行距离最远的两名恶客。"}, {"name": "三影", "cost": 175, "desc": "同时瞄准本行距离最远的三名恶客。"}, {"name": "满翎", "cost": 325, "desc": "每轮抛出四弹，先瞄准距离最远的四名恶客。目标不足时，剩下的弹全投向最远的一名。"}]}, {"id": 2, "name": "重羽", "color": "#508e86", "tiers": [{"name": "坠瓦", "cost": 100, "desc": "抛弹伤害提高至68。"}, {"name": "坠铅", "cost": 175, "desc": "抛弹伤害提高至94。"}, {"name": "坠星", "cost": 350, "desc": "抛弹伤害提高至130。每轮有30%概率发射双倍伤害的大弹。"}]}, {"id": 3, "name": "缄音", "color": "#ba964f", "tiers": [{"name": "止风", "cost": 75, "desc": "命中使恶客移动速度降低15%，持续2秒。"}, {"name": "截风", "cost": 150, "desc": "命中使恶客移动速度降低30%，持续2秒。"}, {"name": "禁声", "cost": 300, "desc": "命中使恶客沉默2秒。期间无法施放召唤、催眠或芦管远射等特殊能力。"}]}],
	"wish-till": [{"id": 1, "name": "收账", "color": "#d2492f", "tiers": [{"name": "记名", "cost": 75, "desc": "本行每击退一名恶客，获得9香火。"}, {"name": "清单", "cost": 150, "desc": "本行每击退一名恶客，获得13香火。"}, {"name": "满簿", "cost": 275, "desc": "本行每击退一名恶客，获得20香火。每6秒还会产出50香火。"}]}, {"id": 2, "name": "催工", "color": "#508e86", "tiers": [{"name": "递筹", "cost": 75, "desc": "本行草木的攻击速度提高5%。"}, {"name": "拨珠", "cost": 150, "desc": "本行草木的攻击速度提高10%。"}, {"name": "飞筹", "cost": 275, "desc": "本行草木的攻击速度提高15%。每次由清账匣获得香火时，它还会发射一枚造成80伤害的筹弹，间隔至少0.4秒。"}]}, {"id": 3, "name": "招客", "color": "#ba964f", "tiers": [{"name": "厚匣", "cost": 100, "desc": "自身最大耐久提高200%。"}, {"name": "引路", "cost": 175, "desc": "每8秒可将相邻行一名非大型恶客引入本行。"}, {"name": "请入", "cost": 325, "desc": "每5秒可引来一名恶客，也能引来大型恶客。"}]}],
	"ember-cicada": [{"id": 1, "name": "烈壳", "color": "#d2492f", "tiers": [{"name": "添烬", "cost": 100, "desc": "火弹伤害提高至104，溅射伤害提高到直击的65%。"}, {"name": "厚烬", "cost": 200, "desc": "火弹伤害提高至126，溅射伤害提高到直击的80%。"}, {"name": "赤翅", "cost": 375, "desc": "火弹伤害提高至156。溅射伤害等于直击，半径扩大到0.5格。"}]}, {"id": 2, "name": "换壳", "color": "#508e86", "tiers": [{"name": "开翅", "cost": 100, "desc": "攻击间隔缩短至1.1秒，补充弹药用时缩短至4.4秒。"}, {"name": "疾翅", "cost": 200, "desc": "攻击间隔缩短至1秒，补充弹药用时缩短至4秒。"}, {"name": "连翅", "cost": 375, "desc": "攻击间隔缩短至0.5秒，弹药上限增加到6发。"}]}, {"id": 3, "name": "余烬", "color": "#ba964f", "tiers": [{"name": "沾火", "cost": 100, "desc": "溅射会点燃恶客，使其每秒受到20伤害，持续2秒。"}, {"name": "延火", "cost": 175, "desc": "点燃每秒造成40伤害，持续2.5秒。"}, {"name": "拾火", "cost": 325, "desc": "由本株火焰烧死的恶客会返还1发弹药，并让下一次攻击提前0.6秒。"}]}],
	"bell": [
		{
			"color": "#d2492f",
			"id": 1,
			"name": "回声",
			"tiers": [
				{
					"cost": 75,
					"desc": "主铃每2秒响一次，余音仍按原有节奏回响。",
					"name": "急铃"
				},
				{
					"cost": 150,
					"desc": "主铃改为每1.5秒响一次。",
					"name": "连铃"
				},
				{
					"cost": 300,
					"desc": "主铃改为每1.2秒响一次；连续被主铃命中的恶客会被减速40%。",
					"name": "催魂"
				}
			]
		},
		{
			"color": "#4f8a86",
			"id": 2,
			"name": "摄心",
			"tiers": [
				{
					"cost": 50,
					"desc": "每次摇铃有10%机会让恶客停步0.4秒，大型恶客不受影响；余音只会减速。",
					"name": "定音"
				},
				{
					"cost": 100,
					"desc": "每次摇铃必定让一名正在啃食的恶客停步0.4秒，其余恶客仍有10%机会停步。",
					"name": "夺魄"
				},
				{
					"cost": 225,
					"desc": "大型恶客也会停步0.2秒。恶客随后2.5秒内啃咬时，会承受相当于啃食伤害25%的反噬，每名恶客每秒最多35伤害。",
					"name": "魂断"
				}
			]
		},
		{
			"color": "#d0a044",
			"id": 3,
			"name": "引客",
			"tiers": [
				{
					"cost": 75,
					"desc": "让前方2格内最远的一名非大型恶客回头走0.5秒，每名恶客每4秒至多生效一次；已经开咬的不会因此松口。",
					"name": "回头"
				},
				{
					"cost": 125,
					"desc": "回头的恶客会带慢0.6格内至多两名同伴：减速20%，持续1.5秒。不会削弱已有的更强减速。",
					"name": "成群"
				},
				{
					"cost": 250,
					"desc": "被恶客摧毁时，全场普通恶客停步0.8秒，大型停步0.3秒。多只铜铃的这声绝响至少相隔8秒，主动铲除不会响。",
					"name": "满街铃"
				}
			]
		}
	],
	"cat": [
		{
			"color": "#d2492f",
			"id": 1,
			"name": "尾形",
			"tiers": [
				{
					"cost": 100,
					"desc": "出手间隔缩短0.2秒。",
					"name": "疾焰"
				},
				{
					"cost": 175,
					"desc": "出手间隔总共缩短0.4秒。",
					"name": "追焰"
				},
				{
					"cost": 350,
					"desc": "出手间隔总共缩短0.6秒；每次出手有10%机会连发10团狐火，此招每6秒最多触发一次。",
					"name": "十焰"
				}
			]
		},
		{
			"color": "#d0a044",
			"id": 2,
			"name": "尾数",
			"tiers": [
				{
					"cost": 100,
					"desc": "一次放出两团尾火，各追一个目标，每团造成24伤害。",
					"name": "双尾"
				},
				{
					"cost": 200,
					"desc": "放出三团，每团伤害提到 30。",
					"name": "三尾"
				},
				{
					"cost": 400,
					"desc": "每次放出四团狐火；每团命中一名恶客后，再追最近的另一名，各吃全额伤害。",
					"name": "回魂"
				}
			]
		},
		{
			"color": "#4f8a86",
			"id": 3,
			"name": "狐火",
			"tiers": [
				{
					"cost": 100,
					"desc": "被命中的敌人留下记号，友军打它 +5%，3.2 秒。",
					"name": "狐记"
				},
				{
					"cost": 175,
					"desc": "狐记的易伤提高到10%。",
					"name": "深印"
				},
				{
					"cost": 325,
					"desc": "记号叠到三层时，恶客停步0.6秒，大型为0.2秒；停步后2秒内易伤提高至20%，大型恶客停步后则提高至40%。",
					"name": "锁魂"
				}
			]
		}
	],
	"censer": [
		{"color": "#d2492f", "id": 1, "name": "烟气", "tiers": [{"name": "散烟", "cost": 75, "desc": "喷烟半径增至1.6格。"}, {"name": "漫庭", "cost": 150, "desc": "喷烟半径增至1.9格。"}, {"name": "满街", "cost": 275, "desc": "喷烟半径增至2.3格。"}]},
		{"color": "#508e86", "id": 2, "name": "香印", "tiers": [{"name": "盖印", "cost": 75, "desc": "喷烟命中留下3.2秒香印，受印恶客承受伤害提高8%。"}, {"name": "传印", "cost": 150, "desc": "香印易伤提高至13%；带印恶客倒下会把香印传给附近同伴。"}, {"name": "爆印", "cost": 350, "desc": "香印易伤提高至18%。喷烟击退带印恶客时，在0.8格内造成100伤害并盖印，一次爆印不会连爆。"}]},
		{"color": "#ba964f", "id": 3, "name": "炉温", "tiers": [{"name": "温炉", "cost": 75, "desc": "喷烟间隔缩短至2.65秒。"}, {"name": "旺炉", "cost": 175, "desc": "喷烟间隔缩短至2.3秒。"}, {"name": "连烟", "cost": 350, "desc": "喷烟间隔缩短至1.95秒。一次命中至少三名恶客时，0.3秒后补喷并重新计时；每4秒至多触发一次。"}]},
	],
	"judge": [
		{"color": "#d2492f", "id": 1, "name": "护命", "tiers": [{"name": "护符", "cost": 100, "desc": "庇护减伤提高至35%。"}, {"name": "伏煞", "cost": 200, "desc": "庇护减伤提高至50%。"}, {"name": "续命", "cost": 400, "desc": "每株受庇护草木第一次受到致命一击时保留1点耐久，且3秒内免疫伤害。"}]},
		{"color": "#508e86", "id": 2, "name": "镇街", "tiers": [{"name": "朱砂", "cost": 150, "desc": "每1.6秒向本行射出一枚38伤害的朱砂弹。"}, {"name": "守坊", "cost": 175, "desc": "庇护扩大为以自身为中心的3×3格。"}, {"name": "镇市", "cost": 325, "desc": "庇护扩大为以自身为中心的5×5格。"}]},
		{"color": "#ba964f", "id": 3, "name": "赐福", "tiers": [{"name": "点香", "cost": 100, "desc": "庇护内草木的伤害提高10%。"}, {"name": "添香", "cost": 200, "desc": "庇护内草木的伤害提高20%。"}, {"name": "灯明", "cost": 375, "desc": "庇护内草木的伤害提高25%，攻击速度提高10%。"}]},
	],
	"lantern": [
		{
			"color": "#d0a044",
			"id": 1,
			"name": "香火",
			"tiers": [
				{
					"cost": 25,
					"desc": "每次产出香火 25 → 35",
					"name": "旺火"
				},
				{
					"cost": 50,
					"desc": "每次产出香火提升到 50",
					"name": "长明"
				},
				{
					"cost": 125,
					"desc": "每次产出香火提升到 100",
					"name": "灯会"
				}
			]
		},
		{
			"color": "#d2492f",
			"id": 2,
			"name": "灯油",
			"tiers": [
				{
					"cost": 25,
					"desc": "产出间隔 8 秒 → 7 秒",
					"name": "挑芯"
				},
				{
					"cost": 50,
					"desc": "产出间隔缩短到 6 秒",
					"name": "双芯"
				},
				{
					"cost": 225,
					"desc": "产出间隔缩短到 5 秒，且每次产出香火时向前发射一枚伤害 110 的灯焰",
					"name": "火树"
				}
			]
		},
		{
			"color": "#e05a30",
			"id": 3,
			"name": "红火",
			"tiers": [
				{
					"cost": 25,
					"desc": "增幅前方 1 格友军，伤害 +20%",
					"name": "旺友"
				},
				{
					"cost": 50,
					"desc": "增幅范围扩展到前方 3 格，伤害 +20%",
					"name": "连旺"
				},
				{
					"cost": 75,
					"desc": "增幅整行友军，伤害 +25%",
					"name": "满街红火"
				}
			]
		}
	],
	"lion": [
		{
			"color": "#d2492f",
			"id": 1,
			"name": "狮头",
			"tiers": [
				{
					"cost": 100,
					"desc": "撞头伤害提高到80。",
					"name": "硬头"
				},
				{
					"cost": 200,
					"desc": "撞头伤害提高到110。",
					"name": "铜头"
				},
				{
					"cost": 375,
					"desc": "撞头伤害提高到140。每3秒至多重摔一次：普通恶客有30%概率被向后摔1格，带护具的必定触发。",
					"name": "重摔"
				}
			]
		},
		{
			"color": "#4f8a86",
			"id": 2,
			"name": "狮步",
			"tiers": [
				{
					"cost": 150,
					"desc": "醒狮跃起远撞，本行攻击距离增加到3格。",
					"name": "远跃"
				},
				{
					"cost": 275,
					"desc": "远撞可贯穿本行全程，仍只攻击本行。",
					"name": "通街"
				},
				{
					"cost": 475,
					"desc": "攻击速度降低20%；每次远撞击中本行所有恶客。",
					"name": "满街狮吼"
				}
			]
		},
		{
			"color": "#d0a044",
			"id": 3,
			"name": "采青",
			"tiers": [
				{
					"cost": 100,
					"desc": "撞头命中时恢复25耐久，每次撞头只恢复一次。",
					"name": "衔青"
				},
				{
					"cost": 150,
					"desc": "撞头命中时恢复50耐久。推开恶客时，还会为相邻草木喝彩，攻速提高5%，持续3秒，最多三层。",
					"name": "喝彩"
				},
				{
					"cost": 275,
					"desc": "撞头命中时，自己与前后一格的草木各恢复75耐久。被恶客击倒后仍可再舞3秒，然后退场。",
					"name": "最后一舞"
				}
			]
		}
	],
	"lobber": [
		{"color": "#d2492f", "id": 1, "name": "馅料", "tiers": [{"name": "实馅", "cost": 100, "desc": "汤圆直击伤害提高到70。"}, {"name": "满馅", "cost": 175, "desc": "汤圆直击伤害提高到100。"}, {"name": "滚烫", "cost": 350, "desc": "直击伤害提高到130。命中后自身伤害提高10%，持续5秒，最多叠5层；层数变化时刷新。"}]},
		{"color": "#508e86", "id": 2, "name": "抛法", "tiers": [{"name": "趁热", "cost": 75, "desc": "抛射间隔缩短至2.25秒。"}, {"name": "快手", "cost": 175, "desc": "抛射间隔缩短至1.9秒。"}, {"name": "双抛", "cost": 350, "desc": "抛射间隔缩短至1.55秒；有40%概率在0.4秒后再抛一颗，补射后重新计时。"}]},
		{"color": "#ba964f", "id": 3, "name": "汤底", "tiers": [{"name": "一摊", "cost": 50, "desc": "留下半径0.4格的热汤，持续3秒，减速15%，每秒烫10伤害。"}, {"name": "合流", "cost": 125, "desc": "热汤减速提高到25%。两摊相接会熬成半径0.6格、每秒烫18伤害的浓汤。"}, {"name": "沸汤", "cost": 300, "desc": "热汤每秒烫50伤害，普通恶客减速35%，大型恶客仍减速25%。"}]},
	],
	"needle": [
		{"color": "#d2492f", "id": 1, "name": "穿堂", "tiers": [{"name": "双穿", "cost": 75, "desc": "一针至多贯穿本行两名恶客，伤害不衰减。"}, {"name": "串影", "cost": 150, "desc": "一针至多贯穿本行三名恶客，伤害不衰减。"}, {"name": "一线", "cost": 300, "desc": "一针贯穿本行所有恶客，伤害不衰减。"}]},
		{"color": "#508e86", "id": 2, "name": "疾针", "tiers": [{"name": "连针", "cost": 75, "desc": "出针间隔缩短至1.5秒。"}, {"name": "急雨", "cost": 150, "desc": "出针间隔缩短至1.3秒。"}, {"name": "定影", "cost": 300, "desc": "出针间隔缩短至1.1秒；每第四针钉住第一名命中的恶客0.3秒，大型恶客为0.15秒。"}]},
		{"color": "#ba964f", "id": 3, "name": "开穴", "tiers": [{"name": "露隙", "cost": 100, "desc": "被扎中的恶客受到的伤害提高10%，持续2.5秒。"}, {"name": "挑筋", "cost": 175, "desc": "易伤提高至15%，持续2.5秒。"}, {"name": "解甲", "cost": 325, "desc": "本体易伤提高至20%，护具改为承受40%易伤，均持续2.5秒。"}]},
	],
	"dragon": [
		{"color": "#d2492f", "id": 1, "name": "探首", "tiers": [{"name": "前探", "cost": 75, "desc": "近攻范围扩大到本行前方3.5格。"}, {"name": "伸首", "cost": 175, "desc": "近攻范围扩大到本行前方4格。"}, {"name": "镇街", "cost": 350, "desc": "近攻范围扩大到本行前方5格。"}]},
		{"color": "#508e86", "id": 2, "name": "铳焰", "tiers": [{"name": "添炭", "cost": 125, "desc": "近攻每次造成20伤害。"}, {"name": "添铜", "cost": 225, "desc": "近攻每次造成26伤害。"}, {"name": "穿甲", "cost": 425, "desc": "近攻每次造成32伤害。命中带甲恶客时，本体与护具各受一份伤害。"}]},
		{"color": "#ba964f", "id": 3, "name": "仰首", "tiers": [{"name": "举铳", "cost": 175, "desc": "近处无人时换成仰射，向本行连抛三枚铜弹，每枚40伤害，相隔0.15秒。射完后等2秒。"}, {"name": "重弹", "cost": 275, "desc": "每枚铜弹有30%概率为二倍伤害，另有30%概率为三倍伤害。"}, {"name": "双口", "cost": 475, "desc": "近攻与仰射可以同时出手。近攻没有目标时，仰射攻速再提高40%。"}]},
	],
	"firework": [
		{"color": "#d2492f", "id": 1, "name": "连彩", "tiers": [{"name": "催火", "cost": 100, "desc": "抛射间隔缩短至3.1秒。"}, {"name": "叠彩", "cost": 175, "desc": "抛射间隔缩短至2.7秒。"}, {"name": "双响", "cost": 350, "desc": "抛射间隔缩短至2.3秒。每次抛射有30%概率在0.6秒后再抛一枚半伤烟花，从补射时重新计时。"}]},
		{"color": "#508e86", "id": 2, "name": "满堂", "tiers": [{"name": "添硝", "cost": 125, "desc": "烟花直击伤害提高至130，溅射伤害提高到直击的65%。"}, {"name": "重彩", "cost": 225, "desc": "烟花直击伤害提高至160，溅射伤害提高到直击的80%。"}, {"name": "满堂红", "cost": 425, "desc": "烟花直击伤害提高至220，溅射伤害等于直击，半径扩大至1.3格。"}]},
		{"color": "#ba964f", "id": 3, "name": "寻星", "tiers": [{"name": "流星", "cost": 150, "desc": "额外每1.6秒向最近的恶客发射一枚40伤害的追踪烟花，无溅射。"}, {"name": "伴月", "cost": 225, "desc": "追踪烟花伤害提高至80。"}, {"name": "星河", "cost": 425, "desc": "追踪烟花的伤害与溅射和普通烟花相同。"}]},
	],
	"shooter": [
		{
			"color": "#d2492f",
			"id": 1,
			"name": "连发",
			"tiers": [
				{
					"cost": 100,
					"desc": "一次攻击射出两支竹签",
					"name": "双发"
				},
				{
					"cost": 225,
					"desc": "一次攻击射出四支竹签",
					"name": "四发"
				},
				{
					"cost": 550,
					"desc": "每轮发射六支竹签，有10%概率改为十二支。场上每个练成六发的签筒，使所有签筒每轮多射一支，最多额外三支。",
					"name": "六发"
				}
			]
		},
		{
			"color": "#4f8a86",
			"id": 2,
			"name": "邻行",
			"tiers": [
				{
					"cost": 100,
					"desc": "向相邻行补射一发竹签，两侧相通时交替",
					"name": "借行"
				},
				{
					"cost": 150,
					"desc": "同时向上下两行各补射一发竹签",
					"name": "双邻"
				},
				{
					"cost": 300,
					"desc": "补射竹签总数提升为本行射出数量 −1，两侧分摊（每侧最低 1）",
					"name": "全力"
				}
			]
		},
		{
			"color": "#d0a044",
			"id": 3,
			"name": "重弹",
			"tiers": [
				{
					"cost": 125,
					"desc": "每支竹签有10%概率造成双倍伤害，另有10%概率使命中目标的移动速度降低20%，持续2秒。",
					"name": "重弹"
				},
				{
					"cost": 225,
					"desc": "双倍伤害竹签和减速竹签的概率各提高至20%。",
					"name": "重型"
				},
				{
					"cost": 400,
					"desc": "双倍伤害竹签和减速竹签的概率各提高至33%。",
					"name": "霜重"
				}
			]
		}
	],
	"star": [
		{
			"color": "#d0a044",
			"id": 1,
			"name": "照法",
			"tiers": [
				{
					"cost": 100,
					"desc": "所有灯焰的伤害提高15%。",
					"name": "添焰"
				},
				{
					"cost": 200,
					"desc": "所有灯焰的伤害提高20%。",
					"name": "燃灯"
				},
				{
					"cost": 375,
					"desc": "所有灯焰的伤害提高20%。亲手击退恶客时，伤害再提高10%，持续5秒，最多叠加三层。每次增加层数时重新计时。",
					"name": "长明"
				}
			]
		},
		{
			"color": "#4f8a86",
			"id": 2,
			"name": "旋法",
			"tiers": [
				{
					"cost": 100,
					"desc": "发灯速度提高25%。",
					"name": "快转"
				},
				{
					"cost": 200,
					"desc": "发灯速度总共提高50%。",
					"name": "连转"
				},
				{
					"cost": 400,
					"desc": "发灯速度总共提高100%；门神被惊动后再提高300%，持续10秒。",
					"name": "急巡"
				}
			]
		},
		{
			"color": "#d2492f",
			"id": 3,
			"name": "巡天",
			"tiers": [
				{
					"cost": 50,
					"desc": "只要有一个方向有敌人，五个方向都会发出灯焰",
					"name": "齐照"
				},
				{
					"cost": 75,
					"desc": "未命中的灯焰撞到地图边界后会自行追踪场上的敌人，但伤害减半",
					"name": "回焰"
				},
				{
					"cost": 125,
					"desc": "伤害不再减半，灯焰像狐尾灯一样自动追踪场上敌人",
					"name": "天网"
				}
			]
		}
	],
	"torch": [
		{
			"color": "#d2492f",
			"id": 1,
			"name": "火色",
			"tiers": [
				{
					"cost": 100,
					"desc": "穿过火盆的射弹伤害提高80%，并附带每秒5伤害的灼烧，持续2秒。",
					"name": "火箭"
				},
				{
					"cost": 200,
					"desc": "伤害增幅总共提高至110%；穿过的射弹最多掉两颗火星，每盆每秒至多两颗。",
					"name": "掉星"
				},
				{
					"cost": 400,
					"desc": "伤害增幅总共提高至130%、弹速提高50%；命中造成全额伤害，并对周围0.3格恶客溅射20%伤害。",
					"name": "不熄"
				}
			]
		},
		{
			"color": "#d0a044",
			"id": 2,
			"name": "余烬",
			"tiers": [
				{
					"cost": 25,
					"desc": "穿过的射弹命中附带 5 伤害/秒，持续 2 秒",
					"name": "火屑"
				},
				{
					"cost": 50,
					"desc": "灼烧提升到 9 伤害/秒",
					"name": "流火"
				},
				{
					"cost": 100,
					"desc": "射弹命中后爆炸，0.5 格内的敌人一起被灼烧，灼烧提升到 14 伤害/秒",
					"name": "燎原"
				}
			]
		},
		{
			"color": "#7f8d94",
			"id": 3,
			"name": "火胎",
			"tiers": [
				{
					"cost": 50,
					"desc": "耐久上限提高至750，进化时立刻补450耐久。",
					"name": "厚胎"
				},
				{
					"cost": 100,
					"desc": "被啃咬时，在啃咬者脚下留下半径0.35格的火油，烧2秒、每秒15伤害；每盆至少隔2秒再泼一次，多处火油不会叠加伤害。",
					"name": "泼油"
				},
				{
					"cost": 200,
					"desc": "被恶客啃塌时留下半径1.5格火墙，每秒60伤害、烧3秒，铲除不会留下火墙。存活时每秒反伤合计25；脱离啃咬3秒后，每秒恢复40耐久。",
					"name": "火墙"
				}
			]
		}
	],
	"umbrella": [
		{
			"color": "#d2492f",
			"id": 1,
			"name": "收放",
			"tiers": [
				{
					"cost": 100,
					"desc": "收妖所需时间缩短20%。",
					"name": "快收"
				},
				{
					"cost": 200,
					"desc": "收妖所需时间总共缩短40%。",
					"name": "疾收"
				},
				{
					"cost": 375,
					"desc": "收妖所需时间总共缩短50%；每次完成收妖射出一根140伤害的伞骨。",
					"name": "伞骨飞"
				}
			]
		},
		{
			"color": "#d0a044",
			"id": 2,
			"name": "愿力",
			"tiers": [
				{
					"cost": 100,
					"desc": "开始收妖时为自身附加150点护盾。",
					"name": "护伞"
				},
				{
					"cost": 200,
					"desc": "开始收妖时为自身附加的护盾提高至300点。",
					"name": "厚伞"
				},
				{
					"cost": 400,
					"desc": "护盾提高至450点，未被啃食时每秒恢复50点；每次完成收妖产出100灯火。",
					"name": "满愿"
				}
			]
		},
		{
			"color": "#4f8a86",
			"id": 3,
			"name": "伞骨",
			"tiers": [
				{
					"cost": 75,
					"desc": "多开一个收妖位，消化一名恶客需12秒，原来的收妖位仍需6秒；大型恶客仍只能被伞骨击打。",
					"name": "半开"
				},
				{
					"cost": 200,
					"desc": "只要伞里还有恶客，啃咬纸伞的每名敌人每秒受到30伤害，不设合计上限。",
					"name": "刺手"
				},
				{
					"cost": 400,
					"desc": "再开一个收妖位；两个副位各需12秒完成收妖，互不阻塞。",
					"name": "双开"
				}
			]
		}
	],
	"wall": [
		{
			"color": "#7f8d94",
			"id": 1,
			"name": "自愈",
			"tiers": [
				{
					"cost": 25,
					"desc": "未被啃食时每秒恢复 20 生命",
					"name": "渗养"
				},
				{
					"cost": 50,
					"desc": "未被啃食时每秒恢复 40 生命",
					"name": "石心"
				},
				{
					"cost": 75,
					"desc": "被啃食时也能每秒恢复 40 生命",
					"name": "不坏"
				}
			]
		},
		{
			"color": "#a86a48",
			"id": 2,
			"name": "粗粝",
			"tiers": [
				{
					"cost": 25,
					"desc": "被啃时每秒反伤敌人 15",
					"name": "磨齿"
				},
				{
					"cost": 50,
					"desc": "反伤提升到 30/秒",
					"name": "重磨"
				},
				{
					"cost": 75,
					"desc": "反伤提升到 50/秒；被摧毁时自爆，对 1 格内敌人造成 900 爆裂伤害",
					"name": "碾磨"
				}
			]
		},
		{
			"color": "#d0a044",
			"id": 3,
			"name": "碎石",
			"tiers": [
				{
					"cost": 25,
					"desc": "每 2.8 秒向本行前方射出一块碎石，伤害 20",
					"name": "磨石"
				},
				{
					"cost": 50,
					"desc": "碎石命中后，让目标接下来3秒受到的伤害提高10%。",
					"name": "石屑"
				},
				{
					"cost": 75,
					"desc": "碎石击退非大型单位 0.6 格；对大型单位改为伤害加倍",
					"name": "飞石"
				}
			]
		}
	]
}

const EFFECTS = {
	"sky-kite": {"targets": [1, 2, 3, 4], "damage": [42, 68, 94, 130], "crit_chance": [0, 0, 0, 0.3], "slow": [0, 0.15, 0.3, 0.3], "silence": [0, 0, 0, 2]},
	"wish-till": {"income": [5, 9, 13, 20], "haste": [0, 0.05, 0.1, 0.15], "pull_interval": [0, 0, 8, 5]},
	"ember-cicada": {"damage": [82, 104, 126, 156], "splash": [0.5, 0.65, 0.8, 1], "radius": [0.3, 0.3, 0.3, 0.5], "interval": [1.2, 1.1, 1, 0.5], "reload": [4.8, 4.4, 4, 4], "ammo": [4, 4, 4, 6], "burn": [0, 20, 40, 40], "burn_duration": [0, 2, 2.5, 2.5]},
	"shooter": {
		"volley": [1, 2, 4, 6],
		"volley_bonus": [0, 0, 0, 12],
		"volley_bonus_chance": [0.0, 0.0, 0.0, 0.1],
		"adjacent_sides": [0, 1, 2, 2],
		"adjacent_split": [false, false, false, true],
		"crit_chance": [0.0, 0.1, 0.2, 0.33],
	},
	"lantern": {
		"value": [25, 35, 50, 100],
		"interval": [8.0, 7.0, 6.0, 5.0],
		"produce_shot": [0.0, 0.0, 0.0, 110.0],
		"buff_range": [0, 1, 3, 99],
		"buff_damage": [0.0, 0.2, 0.2, 0.25],
	},
	"wall": {
		"heal": [0.0, 20.0, 40.0, 40.0],
		"heal_while_eaten": [false, false, false, true],
		"reflect": [0.0, 15.0, 30.0, 50.0],
		"bomb_damage": [0.0, 0.0, 0.0, 900.0],
		"bomb_radius": [0.0, 0.0, 0.0, 88.0],
		"gravel": [0, 1, 1, 1],
		"gravel_damage": [0.0, 20.0, 20.0, 20.0],
		"gravel_interval": 2.8,
		"vuln": [0.0, 0.0, 0.1, 0.1],
		"vuln_duration": 3.0,
		"knock_cells": [0.0, 0.0, 0.0, 0.6],
	},
	"bell": {
		"main_interval": [0.0, 2.0, 1.5, 1.2],
		"repeat_slow": [0.0, 0.0, 0.0, 0.4],
		"adjacent_radius": [0.0, 0.0, 0.5, 0.5],
		"backlash_dps_cap": [0, 0, 0, 35],
		"backlash_duration": [0.0, 0.0, 0.0, 2.5],
		"backlash_ratio": [0.0, 0.0, 0.0, 0.25],
		"companion_duration": [0.0, 0.0, 1.5, 1.5],
		"companion_radius": [0.0, 0.0, 0.6, 0.6],
		"companion_slow": [0.0, 0.0, 0.2, 0.2],
		"companion_targets": [0, 0, 2, 2],
		"death_root": [0.0, 0.0, 0.0, 0.8],
		"death_root_large": [0.0, 0.0, 0.0, 0.3],
		"eater_root_chance": [0, 0, 1, 1],
		"eater_target_cap": [0, 0, 1, 1],
		"echo_duration": [0.0, 1.0, 1.2, 1.2],
		"echo_offsets": [[], [0.6], [0.6], [0.6]],
		"global_death_icd": [0, 0, 0, 8],
		"knock_cells": [0.0, 0.0, 0.0, 0.3],
		"knock_targets": [0, 0, 0, 1],
		"large_root_duration": [0.0, 0.0, 0.0, 0.2],
		"range_cells": [0, 2, 2, 2],
		"reverse_duration": [0.0, 0.5, 0.5, 0.5],
		"reverse_icd": [0, 4, 4, 4],
		"root_chance": [0.0, 0.1, 0.1, 0.1],
		"root_duration": [0.0, 0.4, 0.4, 0.4],
	},
	"censer": {
		"radius": [0.0, 1.6, 1.9, 2.3],
		"interval": [3.0, 2.65, 2.3, 1.95],
		"mark_duration": [0.0, 3.2, 3.2, 3.2],
		"vuln": [0.0, 0.08, 0.13, 0.18],
		"spread_hops": [0, 0, 2, 2],
		"spread_radius": [0, 0, 1, 1],
		"spread_targets": [0, 0, 2, 2],
		"ash_damage": [0, 0, 0, 18],
		"ash_interval": [0, 0, 0, 6],
		"ash_radius": [0.0, 0.0, 0.0, 1.3461538461538463],
	},
	"umbrella": {
		"chew_reduction": [0.0, 0.2, 0.4, 0.5],
		"armor_transfer_ratio": [0.0, 0.0, 0.0, 0.3],
		"bone_damage": [0, 0, 0, 140],
		"bone_icd": [0, 0, 0, 0],
		"bone_root": [0.0, 0.0, 0.0, 0.3],
		"capture_income": [0, 0, 0, 100],
		"chew_reflect_dps": [0, 0, 30, 30],
		"death_saves": [0, 0, 0, 0],
		"hp_max_floor": [0, 0, 0, 300],
		"hp_max_loss": [0, 0, 0, 200],
		"income_icd": [0, 6, 6, 6],
		"mid_income": [0, 0, 0, 100],
		"pull_cells": [0.0, 0.4, 0.4, 0.4],
		"pull_damage": [0, 0, 40, 40],
		"pull_icd": [0, 6, 6, 6],
		"pull_range": [0, 1, 1, 1],
		"reflect_cap": [0, 0, 0, 150],
		"reflect_ratio": [0.0, 0.0, 0.0, 0.5],
		"restore_ratio": [0.0, 0.0, 0.0, 0.3],
		"save_icd": [0, 0, 0, 2],
		"secondary_duration": [0, 12, 12, 12],
		"secondary_slots": [0, 1, 1, 2],
		"target": [0.0, 0.0, "frontmost_ally", "frontmost_ally"],
		"total_reflect_cap": [0, 0, 0, 0],
		"wish_cap": [0, 1, 1, 1],
		"wish_duration": [0, 8, 8, 8],
		"wish_guard": [0.0, 0.0, 0.25, 0.25],
		"wish_hp": [0, 150, 300, 450],
		"wish_regen": [0, 0, 0, 50],
		"wish_total_cap": [0, 0, 0, 500],
	},
	"lion": {
		"armor_strip": [0, 0, 100, 100],
		"brace_damage": [0, 0, 0, 60],
		"brace_duration": [0.0, 0.0, 0.0, 0.8],
		"brace_icd": [0, 0, 0, 3],
		"brace_targets": [0, 0, 0, 2],
		"changes_grid": [0.0, false, false, false],
		"charge_cap": [0, 0, 0, 200],
		"charge_per_kill_cap": [0, 0, 0, 50],
		"charge_reentrant": [0.0, 0.0, 0.0, false],
		"haste_duration": [0, 0, 3, 3],
		"haste_per_stack": [0.0, 0.0, 0.05, 0.05],
		"haste_range": [0, 0, 1, 1],
		"haste_stacks": [0, 0, 3, 3],
		"head_damage": [0, 80, 110, 140],
		"heal_per_attack": [0, 25, 50, 75],
		"knock_cells": [0.0, 0.0, 0.3, 0.3],
		"large_throw": [0.0, 0.0, false, false],
		"last_dance_heal": [0, 0, 0, 100],
		"last_dance_interval": [0.0, 0.0, 0.0, 0.75],
		"last_dance_seconds": [0, 0, 0, 3],
		"lunge_cells": [0.0, 0.5, 0.5, 0.5],
		"pull_cells": [0.0, 0.2, 0.2, 0.2],
		"pull_icd": [0, 3, 3, 3],
		"revives": [0.0, 0.0, 0.0, false],
		"step_damage": [0, 0, 30, 30],
		"step_target_cap": [0, 0, 2, 2],
		"throw_cells": [0, 1, 1, 1],
		"throw_chance": [0.0, 0.0, 0.0, 0.30],
		"throw_icd": [0, 0, 0, 3],
	},
	"cat": {
		"count": [0, 2, 3, 4],
		"explosion_damage": [0, 0, 0, 0],
		"explosion_icd": [0.0, 0.0, 3.2, 3.2],
		"explosion_radius": [0.0, 0.0, 0.5, 0.5],
		"explosion_targets": [0, 0, 3, 3],
		"graze_damage": [0, 8, 20, 20],
		"graze_targets": [0, 1, 2, 2],
		"hits": [1, 1, 1, 2],
		"large_root": [0.0, 0.0, 0.0, 0.2],
		"last_multiplier": [0, 0, 0, 2],
		"mark_duration": [0.0, 3.2, 3.2, 3.2],
		"mark_vuln": [0.0, 0.05, 0.10, 0.10],
		"marks_per_volley": [0, 1, 1, 1],
		"interval_reduction": [0.0, 0.2, 0.4, 0.6],
		"ten_flames_chance": [0.0, 0.0, 0.0, 0.1],
		"ten_flames_cooldown": 6.0,
		"proc_icd": [0.0, 0.0, 0.0, 6.4],
		"reveal_duration": [0, 0, 0, 2],
		"root": [0.0, 0.0, 0.0, 0.6],
		"tail_count": [0, 0, 0, 2],
		"tail_damage": [0, 0, 0, 12],
		"tail_gap": [0.0, 0.0, 0.0, 0.12],
		"volley_damage": [0.0, 0.0, 30.0, 30.0],
		"vuln": [0.0, 0.0, 0.0, 0.2],
	},
	"lobber": {
		"damage": [40, 70, 100, 130],
		"interval": [2.6, 2.25, 1.9, 1.55],
		"pool_radius": [0.0, 0.4, 0.4, 0.4],
		"pool_duration": [0, 3, 3, 3],
		"pool_dps": [0, 10, 10, 50],
		"pool_slow": [0.0, 0.15, 0.25, 0.35],
		"merged_radius": [0.0, 0.0, 0.6, 0.6],
		"merged_dps": [0, 0, 18, 50],
	},
	"dragon": {
		"near_range": [3.0, 3.5, 4.0, 5.0],
		"near_damage": [14, 20, 26, 32],
	},
	"torch": {
		"buff": [0.5, 0.8, 1.1, 1.3],
		"splash_ratio": [0.0, 0.0, 0.0, 0.2],
		"splash_radius": [0.0, 0.0, 0.0, 0.3],
		"burn_dps": [0, 5, 5, 5],
		"burn_duration": [0, 2, 2, 2],
		"ember": [0.0, 5.0, 9.0, 14.0],
		"ember_duration": [0.0, 2.0, 2.0, 2.0],
		"explode_radius": [0.0, 0.0, 0.0, 44.0],
		"heal_delay": [0, 0, 0, 3],
		"heal_dps": [0, 0, 0, 40],
		"max_hp": [0, 750, 750, 750],
		"oil_dps": [0, 0, 15, 15],
		"oil_duration": [0, 0, 2, 2],
		"oil_icd": [0, 0, 2, 2],
		"oil_radius": [0.0, 0.0, 0.35, 0.35],
		"pierce_main": [0.0, 0.0, 0.0, false],
		"reflect_total_dps": [0, 0, 0, 25],
		"secondary_inherits": [0.0, 0.0, 0.0, false],
		"shot_speed": [0.0, 0.0, 0.0, 0.5],
		"spark_dps": [0, 0, 10, 10],
		"spark_duration": [0, 0, 1, 1],
		"spark_radius": [0.0, 0.0, 0.25, 0.25],
		"sparks_per_projectile": [0, 0, 2, 2],
		"sparks_per_second_cap": [0, 0, 2, 2],
		"wall_dps": [0, 0, 0, 60],
		"wall_duration": [0, 0, 0, 3],
		"wall_radius": [0.0, 0.0, 0.0, 1.5],
	},
	"star": {
		"damage_bonus": [0.0, 0.15, 0.20, 0.20],
		"speed_bonus": [0.0, 0.25, 0.5, 1.0],
		"guardian_speed_bonus": [0.0, 0.0, 0.0, 3.0],
		"all_dirs": [false, true, true, true],
		"converge_bonus": [0.0, 0.0, 0.0, 0.0],
		"focus_beams": [0, 0, 0, 0],
		"focus_bonus": [0.0, 0.5, 0.5, 0.5],
		"glow_buff": [0.0, 0.0, 0.0, 0.15],
		"glow_duration": [0, 0, 0, 1],
		"glow_radius": [0.0, 0.0, 0.0, 0.0],
		"ground_interval_factor": [0.0, 0.0, 0.0, 0.0],
		"heavy_knock": [0.0, 0.0, 0.0, 0.3],
		"heavy_knock_icd": [0, 0, 0, 3],
		"heavy_multiplier": [0, 0, 0, 3],
		"heavy_per_volley": [0, 0, 0, 0],
		"interval_floor": [0.0, 0.0, 0.0, 0.0],
		"interval_keep": [0.0, 0.0, 0.0, 0.0],
		"seek": [false, false, true, true],
		"seek_factor": [0.0, 0.0, 0.5, 1.0],
	},
	"needle": {
		"interval": [1.7, 1.5, 1.3, 1.1],
		"pierce_targets": [1, 2, 3, 0],
		"vuln": [0.0, 0.10, 0.15, 0.20],
	},
	"firework": {
		"interval": [3.5, 3.1, 2.7, 2.3],
		"damage": [100, 130, 160, 220],
		"radius": [0.8, 0.8, 0.8, 1.3],
		"splash": [0.50, 0.65, 0.80, 1.0],
	},
	"judge": {
		"reduction": [0.20, 0.35, 0.50, 0.50],
		"damage_buff": [0.0, 0.10, 0.20, 0.25],
		"haste": [0.0, 0.0, 0.0, 0.10],
	},
	"shell": {"hp": 1400.0},
}

static func paths_for(type: String) -> Array:
	return TREES.get(type, [])


static func init_upgrades() -> Dictionary:
	return {1: 0, 2: 0, 3: 0}


static func effect(type: String, key: String, tier: int) -> Variant:
	var row: Dictionary = EFFECTS.get(type, {})
	var values: Variant = row.get(key)
	if values is Array:
		return values[clampi(tier, 0, values.size() - 1)]
	return values


static func opened_paths(upgrades: Dictionary, type: String) -> int:
	var count = 0
	for path in paths_for(type):
		if int(upgrades.get(path["id"], 0)) > 0:
			count += 1
	return count


static func other_path_has_tier3(upgrades: Dictionary, type: String, path_id: int) -> bool:
	for path in paths_for(type):
		if int(path["id"]) != path_id and int(upgrades.get(path["id"], 0)) >= 3:
			return true
	return false


## 已经点到第三阶的那条路（一株草木只能有一条路到顶），没有则返回 0。
## 三阶换建模：立绘与光色都按这条"毕业路"走。
static func capstone(upgrades: Dictionary) -> int:
	for path_id in [1, 2, 3]:
		if int(upgrades.get(path_id, 0)) >= 3:
			return path_id
	return 0


## 返回 {ok, kind, path, tier, next_tier, cost, name, desc, reason}
static func path_status(type: String, upgrades: Dictionary, path_id: int) -> Dictionary:
	var path = {}
	for candidate in paths_for(type):
		if int(candidate["id"]) == path_id:
			path = candidate
			break
	if path.is_empty():
		return {"ok": false, "kind": "none", "path": {}, "tier": 0,
			"reason": "此物无法升阶"}
	var tier = int(upgrades.get(path_id, 0))
	if tier >= 3:
		return {"ok": false, "kind": "maxed", "path": path, "tier": tier,
			"reason": "%s已修到三级" % path["name"]}
	if tier == 0 and opened_paths(upgrades, type) >= 2:
		return {"ok": false, "kind": "locked", "path": path, "tier": tier,
			"reason": "已选两路，第三路关闭"}
	if tier == 2 and other_path_has_tier3(upgrades, type, path_id):
		return {"ok": false, "kind": "locked3", "path": path, "tier": tier,
			"reason": "另一路已到三级，此路三级关闭"}
	var next: Dictionary = path["tiers"][tier]
	return {
		"ok": true, "kind": "next", "path": path, "tier": tier,
		"next_tier": tier + 1,
		"cost": int(next["cost"]),
		"name": next["name"], "desc": next["desc"],
		"reason": "",
	}


## 某一路在某级的费用。费用是表里的绝对值，不再乘系数。
static func tier_cost(type: String, path_id: int, tier: int) -> int:
	for path in paths_for(type):
		if int(path["id"]) != path_id:
			continue
		if tier < 1 or tier > path["tiers"].size():
			return 0
		return int(path["tiers"][tier - 1]["cost"])
	return 0
