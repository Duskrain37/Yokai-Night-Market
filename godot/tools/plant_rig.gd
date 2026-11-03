## Shared native 2D skeleton. Pivots are fractions of the visible sprite.
extends Node2D

const PROFILES = {
	"upright": {"pivots": [Vector2(.50,.69), Vector2(.51,.31), Vector2(.27,.53), Vector2(.74,.53)], "force": 1.0},
	"canopy": {"pivots": [Vector2(.50,.72), Vector2(.50,.42), Vector2(.24,.28), Vector2(.76,.28)], "force": 1.12},
	"vessel": {"pivots": [Vector2(.50,.78), Vector2(.50,.32), Vector2(.28,.59), Vector2(.72,.59)], "force": .7},
	"lantern": {"pivots": [Vector2(.50,.76), Vector2(.50,.34), Vector2(.30,.48), Vector2(.71,.46)], "force": 1.05},
	"quadruped": {"pivots": [Vector2(.47,.74), Vector2(.69,.39), Vector2(.29,.73), Vector2(.74,.74)], "force": 1.3},
}
const BY_TYPE = {
	"lantern": "lantern", "shooter": "upright", "wall": "vessel", "bell": "lantern",
	"censer": "vessel", "umbrella": "canopy", "lion": "quadruped", "cat": "lantern",
	"lobber": "upright", "torch": "vessel", "star": "lantern", "needle": "upright",
	"judge": "upright",
}
const BONE_NAMES = ["Root", "Body", "Crown", "Left", "Right"]
const GRID = 12

var bones: Array[Bone2D] = []
var source_size := Vector2.ZERO
var force := 1.0


func fit(texture: Texture2D, rect: Rect2, profile: String) -> void:
	var shape: Dictionary = PROFILES[profile]
	force = float(shape["force"])
	source_size = rect.size
	var skeleton := Skeleton2D.new()
	skeleton.name = "Skeleton2D"
	add_child(skeleton)
	bones.append(_bone(skeleton, BONE_NAMES[0], rect.size * Vector2(0.50, 1.0)))
	var pivots: Array = shape["pivots"]
	for i in pivots.size():
		var parent: Bone2D = bones[0] if i == 0 else bones[1]
		var origin: Vector2 = rect.size * Vector2(pivots[i])
		var parent_origin: Vector2 = rect.size * (Vector2(0.50, 1.0) if i == 0 else Vector2(pivots[0]))
		bones.append(_bone(parent, BONE_NAMES[i + 1], origin - parent_origin))
	var skin := Polygon2D.new()
	skin.name = "Skin"
	skin.texture = texture
	add_child(skin)
	skin.skeleton = skin.get_path_to(skeleton)
	_mesh(skin, skeleton, rect, pivots)


func _bone(parent: Node2D, label: String, local_pos: Vector2) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = label
	bone.set_autocalculate_length_and_angle(false)
	bone.position = local_pos
	bone.rest = bone.transform
	parent.add_child(bone)
	return bone


func _mesh(skin: Polygon2D, skeleton: Skeleton2D, rect: Rect2, pivots: Array) -> void:
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var triangles: Array[PackedInt32Array] = []
	var weights: Array[PackedFloat32Array] = []
	for bone in bones:
		weights.append(PackedFloat32Array())
	for y in range(GRID + 1):
		for x in range(GRID + 1):
			var point := Vector2(x, y) / GRID
			var at := point * rect.size
			vertices.append(at)
			uv.append(at + rect.position)
			var root := smoothstep(.77, .98, point.y)
			var crown := (1.0 - smoothstep(.10, .43, absf(point.y - float(pivots[1].y)))) * .68
			var left := (1.0 - smoothstep(.08, .46, point.distance_to(pivots[2]))) * .65
			var right := (1.0 - smoothstep(.08, .46, point.distance_to(pivots[3]))) * .65
			var total := 1.0 + crown + left + right
			var mobile := (1.0 - root) / total
			var influence := [root, mobile, crown * mobile, left * mobile, right * mobile]
			for i in bones.size():
				weights[i].append(float(influence[i]))
			if x < GRID and y < GRID:
				var a := y * (GRID + 1) + x
				var b := a + GRID + 1
				triangles.append(PackedInt32Array([a, a + 1, b + 1]))
				triangles.append(PackedInt32Array([a, b + 1, b]))
	skin.polygon = vertices
	skin.uv = uv
	skin.polygons = triangles
	for i in bones.size():
		skin.add_bone(skeleton.get_path_to(bones[i]), weights[i])


func pose(clip: String, index: int) -> void:
	for bone in bones:
		bone.apply_rest()
	var body: Bone2D = bones[1]
	var crown: Bone2D = bones[2]
	var left: Bone2D = bones[3]
	var right: Bone2D = bones[4]
	if clip == "idle":
		var breath := sin(float(index) / 4.0 * TAU)
		body.position.y -= source_size.y * .021 * breath
		body.rotation = .032 * breath * force
		crown.rotation = -.052 * breath
		left.rotation = .085 * breath
		right.rotation = -.095 * breath
		return
	var turn: float = [-.13, .24, .12, .015][index]
	var shift: float = [-.05, .115, .042, 0.0][index]
	body.rotation = turn * force
	body.position.x += source_size.x * shift * force
	body.scale = Vector2(1.0 + absf(turn) * .35, 1.0 - absf(turn) * .35)
	crown.rotation = turn * .62
	left.rotation = turn * 1.8
	right.rotation = turn * 2.5
