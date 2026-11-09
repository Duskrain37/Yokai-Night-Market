extends RefCounted
const ENTRIES=[
	{"id":"street-bamboo","name":"灯下竹声","level":1,"seed":540101,"cards":["lantern","shooter","wall"],"note":"三样旧摊物，也能把第一夜守得妥当。"},
	{"id":"street-needle","name":"一针穿夜","level":2,"seed":540202,"cards":["lantern","needle","wall"],"note":"透骨针打得准，石磨还得摆得稳。"},
	{"id":"street-soup","name":"热汤长街","level":3,"seed":540303,"cards":["lantern","lobber","wall"],"note":"先把灯火养起来，再让热汤招呼来客。"}
]
static func find(id: String) -> Dictionary:
	for entry in ENTRIES:
		if entry.id==id:return entry
	return {}
