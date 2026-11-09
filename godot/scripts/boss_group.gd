## Composite encounter: the legacy facade forwards to independently simulated members.
## Each proxy owns an encounter_slot; damage, CC and prop breaks never leak to its sibling.
extends RefCounted
const Encounter = preload("res://scripts/boss_encounter.gd")
var encounters: Array=[]
func members() -> Array:return encounters
func begin(owner,id: String,last_batch: int=-1,preserve_queue:=false) -> void:
	for index in 2:
		var encounter=Encounter.new()
		encounter.encounter_slot=index
		encounters.append(encounter)
		encounter.begin(owner,id,last_batch,preserve_queue if index==0 else true)
		encounter.set_body_row(0 if index==0 else owner.rows-2)
	owner.banner={"text":"双影压境 · "+String(encounters[0].config.name),"t":3.6,"max":3.6,"ceremony":true,"subtitle":"两位恶首，各守两行"}
func alive() -> bool:
	for encounter in encounters:
		if encounter.alive():return true
	return false
func finished() -> bool:return not alive()
func tick(dt: float) -> void:
	for encounter in encounters:encounter.tick(dt)
func owner_of(proxy):
	var slot:=int(proxy.boss_meta.get("encounter_slot",0))
	for encounter in encounters:
		if encounter.encounter_slot==slot:return encounter
	return encounters[0]
func damage(proxy,amount: float,source: String="",continuous:=false) -> float:
	if proxy!=null:return owner_of(proxy).damage(proxy,amount,source,continuous)
	var total:=0.0
	for encounter in encounters:total+=encounter.damage(null,amount,source,continuous)
	return total
func control(seconds: float,proxy=null) -> void:
	if proxy!=null:owner_of(proxy).control(seconds)
	else:
		for encounter in encounters:encounter.control(seconds)
func break_prop(proxy) -> void:owner_of(proxy).break_prop(proxy)
func serialize() -> Dictionary:
	var saved: Array=[]
	for encounter in encounters:saved.append(encounter.serialize())
	return {"members":saved}
func restore(owner,data: Dictionary) -> void:
	for saved in data.get("members",[]):
		var encounter=Encounter.new()
		encounters.append(encounter)
		encounter.restore(owner,saved)
func _get(property: StringName):
	if encounters.is_empty():return null
	if property in [&"hp",&"max_hp",&"total_damage",&"destruction_used",&"add_count",&"major_count"]:
		var total:=0.0
		for encounter in encounters:total+=float(encounter.get(property))
		return total
	if property==&"died_at":
		var latest:=-1.0
		for encounter in encounters:latest=maxf(latest,encounter.died_at)
		return latest
	if property in [&"body_targets",&"props",&"effects",&"repair_marks"]:
		var combined: Array=[]
		for encounter in encounters:combined.append_array(encounter.get(property))
		return combined
	return encounters[0].get(property)
func _set(property: StringName,value) -> bool:
	if encounters.is_empty():return false
	if property==&"damage_token":
		for encounter in encounters:encounter.damage_token=value
	else:
		encounters[0].set(property,int(value) if encounters[0].get(property) is int else value)
	return true
