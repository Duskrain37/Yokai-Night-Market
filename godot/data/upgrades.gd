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
	"bell": [
		{
			"color": "#d2492f",
			"id": 1,
			"name": "回声",
			"tiers": [
				{
					"cost": 50,
					"desc": "摇铃后0.6秒再响一声，让恶客继续放慢脚步；余音不会引发定身或回头。",
					"name": "余音"
				},
				{
					"cost": 100,
					"desc": "余音减速持续1.2秒，并波及相邻两行各半格内的恶客。",
					"name": "绕梁"
				},
				{
					"cost": 175,
					"desc": "改为在0.5、1.0、1.5秒后各响一声。末声将本行最靠近防线的一名非大型恶客推回0.3格。",
					"name": "三叠"
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
					"desc": "尾火绕目标半圈再命中，绕过的路径擦伤 8。",
					"name": "绕"
				},
				{
					"cost": 150,
					"desc": "绕圈半径变大，擦伤提到 20，路径上两个敌人都擦得到。",
					"name": "大绕"
				},
				{
					"cost": 225,
					"desc": "多团尾火不再各追一个目标，而是排成一条线打同一个，最后一团伤害翻倍。",
					"name": "一串"
				}
			]
		},
		{
			"color": "#d0a044",
			"id": 2,
			"name": "尾数",
			"tiers": [
				{
					"cost": 75,
					"desc": "一次放出两团尾火，各追一个目标，每团造成24伤害。",
					"name": "双尾"
				},
				{
					"cost": 125,
					"desc": "放出三团，每团伤害提到 30。",
					"name": "三尾"
				},
				{
					"cost": 200,
					"desc": "每团尾火咬死一个目标后还能再追一名，各吃全额。一火不浪费。",
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
					"cost": 150,
					"desc": "第二发尾火命中带记号者会引爆，40 点范围伤害。",
					"name": "点火"
				},
				{
					"cost": 250,
					"desc": "记号叠到三层时，恶客停步0.6秒，大型为0.2秒；接下来2秒内，它受到的伤害提高20%。",
					"name": "锁魂"
				}
			]
		}
	],
	"censer": [
		{
			"color": "#d2492f",
			"id": 1,
			"name": "烟气",
			"tiers": [
				{
					"cost": 50,
					"desc": "烟雾向前多伸半格，向后少伸0.2格，两侧范围不变；一次喷烟只伤同一名恶客一次。",
					"name": "顺风"
				},
				{
					"cost": 100,
					"desc": "喷烟后0.8秒回风再熏一次，造成18伤害；这一来一回对同一名恶客至多留下一层香印。",
					"name": "回风"
				},
				{
					"cost": 225,
					"desc": "烟雾经过处留下2秒烟径，再熏18伤害；同一名恶客每6秒至多受一次烟径伤害，烟径不留香印。",
					"name": "烟径"
				}
			]
		},
		{
			"color": "#4f8a86",
			"id": 2,
			"name": "香印",
			"tiers": [
				{
					"cost": 75,
					"desc": "烟雾命中留下3.2秒香印，友军对它造成的伤害提高8%；多层香印不会叠高这项加成。",
					"name": "盖印"
				},
				{
					"cost": 150,
					"desc": "带印恶客倒下后，把一层香印传给1格内至多两名同伴，再向外传一次便会散尽；传出的香印只保留剩余时间。",
					"name": "传印"
				},
				{
					"cost": 275,
					"desc": "集齐三层香印便会引爆并清空香印：造成相当于已损失生命20%的伤害，最多200，先伤护具；同一名恶客每9秒至多引爆一次。",
					"name": "三印合一"
				}
			]
		},
		{
			"color": "#d0a044",
			"id": 3,
			"name": "炉温",
			"tiers": [
				{
					"cost": 50,
					"desc": "场上每有5名活着的恶客，喷烟伤害提高6%，最多提高24%。",
					"name": "旺客"
				},
				{
					"cost": 100,
					"desc": "一圈烟同时熏到至少3名恶客时，这圈烟伤害提高25%；与旺客的加成只取更高的一项。",
					"name": "众口"
				},
				{
					"cost": 200,
					"desc": "倒塌或铲除后留下香灰，每6秒喷一次18伤害的灰烟，范围与未进化时相同。灰烟不会留下香印；再次铲除可清走香灰。",
					"name": "冷炉"
				}
			]
		}
	],
	"judge": [
		{
			"color": "#d2492f",
			"id": 1,
			"name": "镇宅",
			"tiers": [
				{
					"cost": 75,
					"desc": "被打退的恶客若撞上身后第一名同伴，会让那名同伴承受30伤害；一次显灵只撞倒一个。",
					"name": "带人"
				},
				{
					"cost": 125,
					"desc": "相撞双方倒地0.3秒，大型倒地0.15秒；同一名恶客至少隔3秒才会再次被撞倒。",
					"name": "相撞"
				},
				{
					"cost": 225,
					"desc": "击退距离提高到0.9格，大型为0.2格。撞到来路边缘时再停步0.6秒，大型为0.2秒；同一名恶客每5.5秒至多被这样拦下一次。",
					"name": "巡街"
				}
			]
		},
		{
			"color": "#4f8a86",
			"id": 2,
			"name": "请神",
			"tiers": [
				{
					"cost": 75,
					"desc": "每次显灵点中一名恶客，造成双倍伤害。范围内还有其他恶客时，下一次会换一个点名。",
					"name": "点名"
				},
				{
					"cost": 150,
					"desc": "优先点中攻击范围内队伍最靠后的恶客，不再紧盯走在最前面的。",
					"name": "点后"
				},
				{
					"cost": 250,
					"desc": "显灵间隔缩短至3.5秒；同时压住全场一名获得助力的高阶恶客，让它3秒内无法享受助力。同一名恶客每7秒至多受一次，护具仍会保留。",
					"name": "显灵"
				}
			]
		},
		{
			"color": "#d0a044",
			"id": 3,
			"name": "判官笔",
			"tiers": [
				{
					"cost": 100,
					"desc": "每次命中留下12秒死印；集齐三层就让非大型恶客当场倒下，大型则额外失去80生命。同一名恶客每11秒至多生效一次。",
					"name": "死印"
				},
				{
					"cost": 200,
					"desc": "带印恶客靠近同伴时，把一层死印分给0.35格内至多两名同伴，每5.5秒至多一次；分出的死印不会继续传播。",
					"name": "连坐"
				},
				{
					"cost": 275,
					"desc": "显灵伤害提高至100，并有20%机会让一名恶客停步0.5秒，大型为0.2秒。成功定住它时才会揭掉护具，同一名恶客每11秒至多揭甲一次。",
					"name": "判死"
				}
			]
		}
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
					"desc": "撞头有15%机会把一名非大型恶客摔回1格，不能与普通撞头的击退距离相加；同一名恶客每4秒至多重摔一次。",
					"name": "叼"
				},
				{
					"cost": 150,
					"desc": "遇到带护具的非大型恶客必定重摔，并多削100护具；大型不摔，但每4秒也能削去100护具。",
					"name": "砸甲"
				},
				{
					"cost": 250,
					"desc": "撞头击倒恶客时，将打掉的生命化作蓄力：每次最多储存50，合计最多200，下次撞头一次放出。额外的蓄力伤害不会再积蓄力。",
					"name": "吞煞"
				}
			]
		},
		{
			"color": "#4f8a86",
			"id": 2,
			"name": "狮步",
			"tiers": [
				{
					"cost": 100,
					"desc": "撞头时向前探半格，把目标向自己带近0.2格，再退回原位；同一名恶客每3秒至多被带近一次。",
					"name": "抢步"
				},
				{
					"cost": 150,
					"desc": "不再带近目标，改为推回0.3格；前探时踩伤路径上至多两名恶客，各30伤害。大型仍只退0.2格。",
					"name": "跨街"
				},
				{
					"cost": 225,
					"desc": "撞头后蹲守0.8秒，撞上身体的至多两名恶客各受60伤害；这样的蹲守伤害至少相隔3秒。",
					"name": "踩街"
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
					"desc": "推开恶客时，为相邻两格内的草木喝彩：攻速提高5%，持续3秒，最多三层。多只醒狮也只攒三层，与其他加速只取最强的一项。",
					"name": "喝彩"
				},
				{
					"cost": 275,
					"desc": "被恶客击倒后再舞3秒，每0.75秒撞一次头，命中时暂回100耐久；三秒后仍会退场，治疗也留不住它。每株只舞一次，主动铲除不会起舞。",
					"name": "最后一舞"
				}
			]
		}
	],
	"lobber": [
		{
			"color": "#d2492f",
			"id": 1,
			"name": "馅料",
			"tiers": [
				{
					"cost": 75,
					"desc": "场上每有4名活着的恶客，汤圆砸中的伤害提高8%，最多提高40%；不会加强留下的热汤与贴馅。",
					"name": "数馅"
				},
				{
					"cost": 150,
					"desc": "命中护具时多削40；若因此击碎护具，会留下4秒残片，让普通恶客绊住0.2秒，大型则减速10%达0.5秒。同一名恶客每4秒至多掉一次残片。",
					"name": "砸飞"
				},
				{
					"cost": 275,
					"desc": "命中大型恶客时贴上一颗馅，2秒后炸掉其最大生命的8%，最多160伤害；同一名恶客每4秒至多贴一颗，未炸完不会再贴。",
					"name": "贴馅"
				}
			]
		},
		{
			"color": "#4f8a86",
			"id": 2,
			"name": "抛法",
			"tiers": [
				{
					"cost": 75,
					"desc": "改为抛向本行半格内敌人最密集的位置，密集程度相同时，优先照顾离防线更近的那一群。",
					"name": "拣密"
				},
				{
					"cost": 125,
					"desc": "每2.6秒连抛两颗40伤害的汤圆，相隔0.15秒；第二颗偏向落点半格内有敌人的一侧。",
					"name": "连抛"
				},
				{
					"cost": 250,
					"desc": "每第四轮把第一颗换成100伤害的大汤，另波及1.2格内至多三名恶客，各受40%伤害；第二颗仍是普通汤圆。",
					"name": "三更"
				}
			]
		},
		{
			"color": "#d0a044",
			"id": 3,
			"name": "汤底",
			"tiers": [
				{
					"cost": 50,
					"desc": "落点留下半径0.4格的热汤，持续3秒：减速20%，每秒烫10伤害。多摊汤不会叠加烫伤。",
					"name": "一摊"
				},
				{
					"cost": 125,
					"desc": "两摊相接会熬成半径0.6格的浓汤，持续3秒，每秒伤害18、减速25%，同时最多烫三名恶客。再添汤只能续时，不会继续扩大。",
					"name": "合流"
				},
				{
					"cost": 225,
					"desc": "浓汤减速提高到35%；在汤里啃食的恶客另受每秒12伤害，仍至多同时烫三名，多摊汤不会叠加。",
					"name": "封口"
				}
			]
		}
	],
	"needle": [
		{
			"color": "#d2492f",
			"id": 1,
			"name": "针形",
			"tiers": [
				{
					"cost": 50,
					"desc": "一针穿过两名恶客，分别造成18与10.8伤害；不会绕回来扎同一名恶客。",
					"name": "穿堂"
				},
				{
					"cost": 100,
					"desc": "一针最多穿过三名恶客，分别造成18、10.8、10.8伤害。",
					"name": "双穿"
				},
				{
					"cost": 225,
					"desc": "穿过的三名恶客都受18生命伤害，并各削40护具；向旁边补出的针不能额外削甲。",
					"name": "排针"
				}
			]
		},
		{
			"color": "#4f8a86",
			"id": 2,
			"name": "针路",
			"tiers": [
				{
					"cost": 50,
					"desc": "命中后向0.6格内至多三名未被这一轮扎过的恶客补针，各受40%伤害；补针不会继续贯穿或分出新针。",
					"name": "三向"
				},
				{
					"cost": 100,
					"desc": "补针伤害提高至18，同一轮仍不会反复扎同一名恶客。",
					"name": "齐落"
				},
				{
					"cost": 250,
					"desc": "每秒出针，每第四次出针会把最先扎中的恶客钉住0.3秒，大型为0.15秒；旁边的补针不会钉人。",
					"name": "无影"
				}
			]
		},
		{
			"color": "#d0a044",
			"id": 3,
			"name": "针眼",
			"tiers": [
				{
					"cost": 50,
					"desc": "命中的恶客在2.2秒内受到的伤害提高8%；与其他同类加成只取最高的一项。",
					"name": "记穴"
				},
				{
					"cost": 100,
					"desc": "这项伤害加成同时影响0.6格内至多两名同伴，但不会从它们身上继续扩散。",
					"name": "同穴"
				},
				{
					"cost": 200,
					"desc": "伤害加成提高至20%。每轮可留一根针，每名恶客最多三根、保留12秒；每向前走满1格便拔掉一根、失去25生命，被打退的路不算。",
					"name": "钉住"
				}
			]
		}
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
					"cost": 250,
					"desc": "一次攻击射出六支竹签，10% 概率改为射出十二支",
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
					"cost": 75,
					"desc": "10% 概率射出一发双倍伤害的大竹签",
					"name": "重弹"
				},
				{
					"cost": 150,
					"desc": "大竹签概率提升到 20%",
					"name": "重型"
				},
				{
					"cost": 200,
					"desc": "大竹签概率提升到 25%，命中后减速敌人 50%，持续 2 秒",
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
					"cost": 75,
					"desc": "加强敌人最多的那个方向，灯焰伤害提高50%；每轮只加强一个方向。",
					"name": "侧照"
				},
				{
					"cost": 125,
					"desc": "同一轮中，同一名恶客从第二道灯焰起受到的伤害提高25%；折返的灯焰不会额外叠高这项加成。",
					"name": "聚照"
				},
				{
					"cost": 225,
					"desc": "命中处留下半径0.35格、持续1秒的余光，穿过的友军攻击伤害提高15%；与红灯笼、炭火盆只取最强的一项。",
					"name": "满城"
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
					"desc": "场上有友军留下的烟径、火焰或热汤时，发灯间隔缩短10%；多处烟火不会进一步加速，冷炉灰烟不算。",
					"name": "借风"
				},
				{
					"cost": 125,
					"desc": "发灯间隔缩短到 1.2 秒",
					"name": "连转"
				},
				{
					"cost": 250,
					"desc": "发灯间隔最多缩短到1.2秒，不再重复加快；每轮一道灯焰变成三倍伤害的重灯，轮流照向各方。重灯推回普通恶客0.3格，同一名恶客每3秒至多一次。",
					"name": "灯轮"
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
					"cost": 50,
					"desc": "穿过火盆的攻击附带每秒5伤害的灼烧，持续2秒，伤害加成仍为50%；多处灼烧不会叠加。",
					"name": "火箭"
				},
				{
					"cost": 100,
					"desc": "穿过的攻击最多掉两颗火星，半径0.25格，烧1秒、每秒10伤害；每盆每秒至多两颗，火星不会叠加烫伤。伤害加成仍为50%。",
					"name": "掉星"
				},
				{
					"cost": 275,
					"desc": "穿过火盆的攻击伤害提高130%、飞行加快50%，直接穿过护具伤及本体；灼烧、火星和溅开的余火不能穿甲。",
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
					"cost": 50,
					"desc": "开始收妖时，将前方1格内一名非大型恶客吸近0.4格，每6秒至多吸一次。",
					"name": "吸"
				},
				{
					"cost": 100,
					"desc": "恶客被吸到伞口时，额外受到40伤害，每次吸引只伤一次。",
					"name": "撞骨"
				},
				{
					"cost": 200,
					"desc": "收妖完成后射出一根40伤害的伞骨，钉住第一名非大型恶客0.3秒；无论从哪个收妖位放出，至少隔4秒再射一根。",
					"name": "一伞收"
				}
			]
		},
		{
			"color": "#d0a044",
			"id": 2,
			"name": "愿力",
			"tiers": [
				{
					"cost": 50,
					"desc": "收妖完成后，为本行身后最近的一株草木挂上200耐久的愿盾，保留8秒，一把伞只留一面盾。同时收下50香火，至少隔6秒再收一次；第二个收妖位不产香火。",
					"name": "愿伞"
				},
				{
					"cost": 100,
					"desc": "愿盾改为保护本行最靠前的同伴，盾在时少受25%伤害；与其他减伤只取最强的一项。",
					"name": "让伞"
				},
				{
					"cost": 250,
					"desc": "收下中阶或更高阶恶客时得到100香火；再将收妖时剩余护具的30%化入愿盾，盾最多500耐久。第二个收妖位不增加香火或护盾。",
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
					"cost": 50,
					"desc": "多开一个收妖位，消化一名恶客需15秒，原来的收妖位仍需6秒；大型恶客仍只能被伞骨击打。",
					"name": "半开"
				},
				{
					"cost": 125,
					"desc": "只要伞里还有恶客，啃咬纸伞的敌人就会每秒受到30伤害，整把伞每秒合计至多反伤60。",
					"name": "刺手"
				},
				{
					"cost": 225,
					"desc": "最多三次死里逃生：留下剩余耐久上限的30%，但每次上限永久减少200，最低300；并反弹挡下伤害的一半、最多150。两次保命至少相隔2秒。",
					"name": "不破"
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
	"shooter": {
		"volley": [1, 2, 4, 6],
		"volley_bonus": [0, 0, 0, 12],
		"volley_bonus_chance": [0.0, 0.0, 0.0, 0.1],
		"adjacent_sides": [0, 1, 2, 2],
		"adjacent_split": [false, false, false, true],
		"crit_chance": [0.0, 0.1, 0.2, 0.25],
		"crit_slow": [0.0, 0.0, 0.0, 2.0],
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
		"echo_offsets": [[], [0.6], [0.6], [0.5, 1, 1.5]],
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
		"ash_damage": [0, 0, 0, 18],
		"ash_inherits": [0.0, 0.0, 0.0, false],
		"ash_interval": [0, 0, 0, 6],
		"ash_radius": [0.0, 0.0, 0.0, 1.3461538461538463],
		"crowd_bonus": [0.0, 0.06, 0.06, 0.06],
		"crowd_cap": [0.0, 0.24, 0.24, 0.24],
		"crowd_step": [0, 5, 5, 5],
		"execute_cap": [0, 0, 0, 200],
		"execute_icd": [0, 0, 0, 9],
		"forward_bonus": [0.0, 0.5, 0.5, 0.5],
		"lost_hp_ratio": [0.0, 0.0, 0.0, 0.2],
		"mark_duration": [0.0, 3.2, 3.2, 3.2],
		"marks_per_cycle": [0, 0, 1, 1],
		"multi_bonus": [0.0, 0.0, 0.25, 0.25],
		"multi_threshold": [0, 0, 3, 3],
		"rear_reduction": [0.0, 0.2, 0.2, 0.2],
		"return_damage": [0, 0, 18, 18],
		"return_delay": [0.0, 0.0, 0.8, 0.8],
		"spread_hops": [0, 0, 2, 2],
		"spread_radius": [0, 0, 1, 1],
		"spread_targets": [0, 0, 2, 2],
		"trail_damage": [0, 0, 0, 18],
		"trail_duration": [0, 0, 0, 2],
		"trail_hit_icd": [0, 0, 0, 6],
		"vuln": [0.0, 0.08, 0.08, 0.08],
	},
	"umbrella": {
		"armor_transfer_ratio": [0.0, 0.0, 0.0, 0.3],
		"bone_damage": [0, 0, 0, 40],
		"bone_icd": [0, 0, 0, 4],
		"bone_root": [0.0, 0.0, 0.0, 0.3],
		"capture_income": [0, 50, 50, 50],
		"chew_reflect_dps": [0, 0, 30, 30],
		"death_saves": [0, 0, 0, 3],
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
		"secondary_duration": [0, 15, 15, 15],
		"secondary_slots": [0, 1, 1, 1],
		"target": [0.0, 0.0, "frontmost_ally", "frontmost_ally"],
		"total_reflect_cap": [0, 0, 60, 60],
		"wish_cap": [0, 1, 1, 1],
		"wish_duration": [0, 8, 8, 8],
		"wish_guard": [0.0, 0.0, 0.25, 0.25],
		"wish_hp": [0, 200, 200, 200],
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
		"heal_per_attack": [0, 25, 25, 25],
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
		"throw_chance": [0.0, 0.15, 0.15, 0.15],
		"throw_icd": [0, 4, 4, 4],
	},
	"cat": {
		"count": [0, 2, 3, 3],
		"explosion_damage": [0, 0, 40, 40],
		"explosion_icd": [0.0, 0.0, 3.2, 3.2],
		"explosion_radius": [0.0, 0.0, 0.5, 0.5],
		"explosion_targets": [0, 0, 3, 3],
		"graze_damage": [0, 8, 20, 20],
		"graze_targets": [0, 1, 2, 2],
		"hits": [1, 1, 1, 2],
		"large_root": [0.0, 0.0, 0.0, 0.2],
		"last_multiplier": [0, 0, 0, 2],
		"mark_duration": [0.0, 3.2, 3.2, 3.2],
		"mark_vuln": [0.0, 0.05, 0.05, 0.05],
		"marks_per_volley": [0, 1, 1, 1],
		"orbit_radius": [0.0, 0.25, 0.45, 0.45],
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
		"armor_chip": [0, 0, 40, 40],
		"attach_delay": [0, 0, 0, 2],
		"attach_icd": [0, 0, 0, 4],
		"bomb_cap": [0, 0, 0, 160],
		"crowd_bonus": [0.0, 0.08, 0.08, 0.08],
		"crowd_cap": [0.0, 0.4, 0.4, 0.4],
		"crowd_step": [0, 4, 4, 4],
		"debris_duration": [0, 0, 4, 4],
		"debris_icd": [0, 0, 4, 4],
		"eater_pool_dps": [0, 0, 0, 12],
		"large_slow": [0.0, 0.0, 0.1, 0.1],
		"max_hp_ratio": [0.0, 0.0, 0.0, 0.08],
		"merge_limit": [0, 0, 2, 2],
		"merged_dps": [0, 0, 18, 18],
		"merged_radius": [0.0, 0.0, 0.6, 0.6],
		"merged_slow": [0.0, 0.0, 0.25, 0.35],
		"offset_cells": [0.0, 0.0, 0.5, 0.5],
		"pending_cap": [0, 0, 0, 1],
		"pool_dps": [0, 10, 10, 10],
		"pool_duration": [0, 3, 3, 3],
		"pool_radius": [0.0, 0.4, 0.4, 0.4],
		"pool_slow": [0.0, 0.2, 0.2, 0.2],
		"pool_target_cap": [0, 0, 3, 3],
		"special_damage": [0, 0, 0, 100],
		"special_every": [0, 0, 0, 4],
		"splash_extra_targets": [0, 0, 0, 3],
		"splash_radius": [0.0, 0.0, 0.0, 1.2],
		"splash_ratio": [0.0, 0.0, 0.0, 0.4],
		"target_radius": [0.0, 0.5, 0.5, 0.5],
		"target_scope": [0.0, "own_lane", "own_lane", "own_lane"],
		"trip": [0.0, 0.0, 0.2, 0.2],
		"volley": [0, 0, 2, 2],
		"volley_gap": [0.0, 0.0, 0.15, 0.15],
	},
	"torch": {
		"buff": [0.5, 0.5, 0.5, 1.3],
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
		"pierce_main": [0.0, 0.0, 0.0, true],
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
		"all_dirs": [false, true, true, true],
		"converge_bonus": [0.0, 0.0, 0.25, 0.25],
		"focus_beams": [0, 1, 1, 1],
		"focus_bonus": [0.0, 0.5, 0.5, 0.5],
		"glow_buff": [0.0, 0.0, 0.0, 0.15],
		"glow_duration": [0, 0, 0, 1],
		"glow_radius": [0.0, 0.0, 0.0, 0.35],
		"ground_interval_factor": [0.0, 0.9, 0.9, 0.9],
		"heavy_knock": [0.0, 0.0, 0.0, 0.3],
		"heavy_knock_icd": [0, 0, 0, 3],
		"heavy_multiplier": [0, 0, 0, 3],
		"heavy_per_volley": [0, 0, 0, 1],
		"interval_floor": [0.0, 0.0, 0.0, 1.2],
		"interval_keep": [0.0, 0.0, 1.2, 1.2],
		"seek": [false, false, true, true],
		"seek_factor": [0.0, 0.0, 0.5, 1.0],
	},
	"needle": {
		"armor_strip": [0, 0, 0, 40],
		"backward_counts": [0.0, 0.0, 0.0, false],
		"interval": [1.7, 0, 0, 1],
		"large_pin": [0.0, 0.0, 0.0, 0.15],
		"move_threshold": [0, 0, 0, 1],
		"nail_cap": [0, 0, 0, 3],
		"nail_damage": [0, 0, 0, 25],
		"nail_life": [0, 0, 0, 12],
		"pierce_factors": [[], [1, 0.6], [1, 0.6, 0.6], [1, 1, 1]],
		"pierce_targets": [0, 2, 3, 3],
		"pin_duration": [0.0, 0.0, 0.0, 0.3],
		"pin_every": [0, 0, 0, 4],
		"secondary_reentrant": [0.0, false, false, false],
		"secondary_strip": [0.0, 0.0, 0.0, false],
		"share_radius": [0.0, 0.0, 0.6, 0.6],
		"share_recursive": [0.0, 0.0, false, false],
		"share_targets": [0, 0, 2, 2],
		"split_factor": [0.0, 0.4, 1, 1],
		"split_radius": [0.0, 0.6, 0.6, 0.6],
		"split_targets": [0, 3, 3, 3],
		"vuln": [0.0, 0.08, 0.08, 0.2],
		"vuln_duration": [0.0, 2.2, 2.2, 2.2],
	},
	"judge": {
		"collision_cap": [0, 1, 1, 1],
		"collision_damage": [0, 30, 30, 30],
		"collision_icd": [0, 0, 3, 3],
		"collision_root": [0.0, 0.0, 0.3, 0.3],
		"collision_root_large": [0.0, 0.0, 0.15, 0.15],
		"contact_radius": [0.0, 0.0, 0.35, 0.35],
		"contact_targets": [0, 0, 2, 2],
		"damage": [0, 0, 0, 100],
		"death_mark_duration": [0, 12, 12, 12],
		"execute_icd": [0, 11, 11, 11],
		"execute_stacks": [0, 3, 3, 3],
		"interval": [0.0, 0.0, 0.0, 3.5],
		"knock": [0.0, 0.0, 0.0, 0.9],
		"large_knock": [0.0, 0.0, 0.0, 0.2],
		"large_proc_damage": [0, 80, 80, 80],
		"large_wall_root": [0.0, 0.0, 0.0, 0.2],
		"named_multiplier": [0, 2, 2, 2],
		"named_targets": [0, 1, 1, 1],
		"root_chance": [0.0, 0.0, 0.0, 0.2],
		"root_duration": [0.0, 0.0, 0.0, 0.5],
		"root_large": [0.0, 0.0, 0.0, 0.2],
		"spread_icd": [0.0, 0.0, 5.5, 5.5],
		"spread_recursive": [0.0, 0.0, false, false],
		"strip_icd": [0, 0, 0, 11],
		"strip_on_success": [0.0, 0.0, 0.0, true],
		"suppress_duration": [0, 0, 0, 3],
		"suppress_icd": [0, 0, 0, 7],
		"suppress_target": [0.0, 0.0, 0.0, "buffed_highest_tier"],
		"target": [0.0, 0.0, "rightmost_in_range", "rightmost_in_range"],
		"wall": [0.0, 0.0, 0.0, "right_spawn_boundary"],
		"wall_icd": [0.0, 0.0, 0.0, 5.5],
		"wall_root": [0.0, 0.0, 0.0, 0.6],
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
