## Presentation-only ledger; aggregates fast ticks without changing combat or RNG.
extends RefCounted
var mode := "medium"
var clock := 0.0
var entries: Array = []
var pending: Dictionary = {}
func clear() -> void:
	entries.clear();pending.clear();clock=0
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
			entry.amount+=amount;entry.last=clock;entry.at=at;entry.age=minf(float(entry.age),.15);return
	entries.append({"key":key,"uid":uid,"at":at,"amount":amount,"healing":healing,"age":0.0,"last":clock,"life":.95,"height":height})
	if entries.size()>180:entries.pop_front()
func update(dt: float) -> void:
	clock+=dt
	if mode=="off":entries.clear();pending.clear();return
	for entry in entries:entry.age+=dt
	entries=entries.filter(func(e):return e.age<e.life)
	for key in pending.keys():
		var e:Dictionary=pending[key]
		if clock-float(e.started)>=.2:
			_push(key,e.uid,e.at,e.amount,e.healing,e.height,true);pending.erase(key)
static func text(amount: float, healing: bool) -> String:
	var value:=str(roundi(amount)) if amount>=1 else String.num(amount,1)
	return ("+" if healing else "−")+value
