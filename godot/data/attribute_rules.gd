## Attribute effects: bonuses add across origins, penalties multiply across origins.
## One origin keeps its strongest active value; weaker refreshes cannot extend it.
extends RefCounted

static func put(effects: Dictionary, kind: String, source: String, amount: float, duration: float, now: float) -> void:
	if duration <= 0 or amount <= 0: return
	var key := source + ":" + kind
	var old: Dictionary = effects.get(key, {})
	var current := float(old.get("amount", 0)) if float(old.get("until", 0)) > now else 0.0
	if amount > current + .00001:
		effects[key] = {"kind": kind, "source": source, "amount": amount, "until": now + duration}
	elif is_equal_approx(amount, current):
		old.until = maxf(float(old.get("until", 0)), now + duration)

static func prune(effects: Dictionary, now: float) -> void:
	for key in effects.keys():
		if float(effects[key].get("until", 0)) <= now: effects.erase(key)

static func remaining(effects: Dictionary, kind: String, now: float) -> float:
	var left := 0.0
	for effect in effects.values():
		if String(effect.get("kind", "")) == kind: left = maxf(left, float(effect.get("until", 0)) - now)
	return left

static func penalty(effects: Dictionary, kind: String, now: float) -> float:
	var factor := 1.0
	for effect in effects.values():
		if String(effect.get("kind", "")) == kind and float(effect.get("until", 0)) > now:
			factor *= 1.0 - clampf(float(effect.amount), 0, .95)
	return factor

static func bonus(effects: Dictionary, kind: String, now: float) -> float:
	var total := 0.0
	for effect in effects.values():
		if String(effect.get("kind", "")) == kind and float(effect.get("until", 0)) > now: total += float(effect.amount)
	return 1.0 + total

static func explanation() -> String:
	return "增益异源相加，减益异源乘算，同来源只生效当前最高值。\n\n实际属性 = 基础属性 ×（1 + 各来源增益之和）×（1 − 减益甲）×（1 − 减益乙）……\n\n例：基础移速20，加速20%与30%，减速20%与25%。实际移速 = 20 × 1.5 × 0.8 × 0.75 = 18。\n\n例：基础伤害100，增伤20%与30%，减伤20%与25%。实际伤害 = 100 × 1.5 × 0.8 × 0.75 = 90。攻速使用同一公式；攻击间隔 = 基础间隔 ÷ 实际攻速倍率。\n\n同来源重复减速20%和30%只取30%；较弱效果不延长较强效果，等强效果可刷新。不同来源易伤分别相乘，例如20%与30%易伤使承伤变为1.2 × 1.3 = 1.56倍。\n\n生产间隔只受明确写明的生产加成影响；硬控、沉默和周期伤害按各自时长与规则处理。"
