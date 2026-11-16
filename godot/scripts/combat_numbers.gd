## Presentation-only ledger: no combat RNG, damage, resources or simulation clock changes.
extends RefCounted
var mode := "medium"
var clock := 0.0
var entries: Array = []
var pending: Dictionary = {}
var finishes: Array = []
var recent_defeats: Array = []
var last_finish := -10.0
var last_punch := -10.0
var punch_requested := false
func clear() -> void:
	entries.clear();pending.clear();finishes.clear();recent_defeats.clear();clock=0
	last_finish=-10;last_punch=-10;punch_requested=false
func record(uid: String, at: Vector2, amount: float, healing: bool = false, continuous: bool = false, height: float = 100) -> void:
	if mode=="off" or amount<=.00001:return
	var key:=uid+(":heal" if healing else ":damage")
	if continuous:
		if not pending.has(key):pending[key]={"uid":uid,"at":at,"amount":0.0,"healing":healing,"started":clock,"height":height}
		pending[key].amount+=amount;pending[key].at=at;return
	_push(key,uid,at,amount,healing,height)
func _push(key: String,uid: String,at: Vector2,amount: float,healing: bool,height: float,continuous: bool = false) -> void:
	for entry in entries:
		if entry.key==key and clock-float(entry.last)<=(.3 if continuous else .055):
			entry.amount+=amount;entry.last=clock;entry.at=at;entry.age=minf(float(entry.age),.15);entry.pop=0.0;return
	entries.append({"key":key,"uid":uid,"at":at,"amount":amount,"healing":healing,"age":0.0,"pop":0.0,"last":clock,"life":1.1 if amount>=500 else .95,"height":height})
	if not healing and not continuous and amount>=500 and clock-last_punch>.25:
		punch_requested=true;last_punch=clock
	if entries.size()>180:entries.pop_front()
func defeated(at: Vector2) -> void:
	if mode=="off":return
	recent_defeats.append({"at":at,"time":clock})
	if recent_defeats.size()>128:recent_defeats.pop_front()
func _finish() -> void:
	recent_defeats=recent_defeats.filter(func(e):return clock-float(e.time)<=.75)
	var count:=recent_defeats.size()
	if count<3:return
	var tier:=1 if count<6 else 2 if count<10 else 3 if count<16 else 4
	# A burst can grow in place; it never creates one banner per victim.
	if clock-last_finish<.8 and not finishes.is_empty():
		var e:Dictionary=finishes.back()
		if count>int(e.count):e.count=count;e.tier=tier;e.age=minf(float(e.age),.2)
		return
	var center:=Vector2.ZERO
	for e in recent_defeats:center+=e.at
	center/=count
	finishes.append({"at":center,"count":count,"tier":tier,"age":0.0,"life":1.15})
	last_finish=clock
	if clock-last_punch>.25:punch_requested=true;last_punch=clock
	if finishes.size()>2:finishes.pop_front()
func update(dt: float) -> void:
	clock+=dt
	if mode=="off":entries.clear();pending.clear();finishes.clear();recent_defeats.clear();punch_requested=false;return
	for entry in entries:entry.age+=dt;entry.pop+=dt
	entries=entries.filter(func(e):return e.age<e.life)
	for key in pending.keys():
		var e:Dictionary=pending[key]
		if clock-float(e.started)>=.2:
			_push(key,e.uid,e.at,e.amount,e.healing,e.height,true);pending.erase(key)
	for finish in finishes:finish.age+=dt
	finishes=finishes.filter(func(e):return e.age<e.life)
	_finish()
static func strength(amount: float) -> float:
	return clampf(log(1.0+maxf(0,amount)/35.0)/log(60.0),0.0,1.0)
static func point_size(amount: float, base: int, healing: bool) -> int:
	return roundi(base*(1.0+strength(amount)*(0.48 if healing else 1.05)))
static func text(amount: float, _healing: bool) -> String:
	return str(roundi(amount)) if amount>=1 else String.num(amount,1)
