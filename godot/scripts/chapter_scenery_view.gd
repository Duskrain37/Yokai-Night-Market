## Independent painted props projected onto the same coordinates as gameplay.
extends RefCounted
const Art = preload("res://ui/market_art.gd")
const LAMP_ACTORS = ["scenery-cloud-lamp", "scenery-pact-lamp", "scenery-lotus-lamp"]
const LAMP_CUTS = [
	[[0,42],[129,42],[146,33],[166,46],[184,63],[210,67],[215,82],[202,103],[202,153],[191,214],[191,240],[0,240]],
	[[190,37],[280,37],[280,233],[140,233],[134,196],[136,143],[139,104],[143,76],[161,61]],
	[[0,52],[95,52],[107,42],[122,44],[143,56],[162,65],[175,83],[172,112],[162,154],[151,190],[135,220],[120,240],[0,240]]
]
const LAMP_PIVOTS = [Vector2(146,38), Vector2(191,49), Vector2(111,49)]
const LAMP_PAPER = [Vector2(145,115), Vector2(186,120), Vector2(115,118)]
var frames = preload("res://scripts/actor_frames.gd").new()
var deck: Texture2D
var glow: GradientTexture2D
var lamp_layers: Array = []
var meshes: Dictionary = {}
func _init() -> void:
	frames.load_sheets("scenery-")
	if ResourceLoader.exists("res://assets/scenery/theatre-deck.png"):deck=load("res://assets/scenery/theatre-deck.png")
	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0,.25,.62,1])
	falloff.colors = PackedColorArray([Color.WHITE,Color(1,1,1,.73),Color(1,1,1,.22),Color(1,1,1,0)])
	glow = GradientTexture2D.new()
	glow.gradient = falloff
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(.5,.5)
	glow.fill_to = Vector2(1,.5)
	for pair in 3:
		var actor: String = LAMP_ACTORS[pair]
		var info: Dictionary = frames.catalog[actor]
		var frame: Dictionary = info.clips.dark[0]
		var texture: Texture2D = frames.key_sheet(actor)
		var cut := PackedVector2Array()
		for xy in LAMP_CUTS[pair]: cut.append(Vector2(xy[0],xy[1]))
		var full := PackedVector2Array([Vector2.ZERO,Vector2(280,0),Vector2(280,280),Vector2(0,280)])
		var base: Array[PackedVector2Array] = Geometry2D.clip_polygons(full,cut)
		var anchor := Vector2(frame.anchor[0],frame.anchor[1])
		lamp_layers.append({"texture":texture,"base":base,"lamp":cut,"anchor":anchor,"scale":172.0/float(info.body_px),"flip":info.facing=="right"})
func point(col: float,row: float) -> Vector2:
	return Geo.to_screen(Vector2(Geo.BOARD_X+col*Geo.CELL_W,Geo.BOARD_Y+row*Geo.cell_h(6)),6)

func cloud_signal(canvas: CanvasItem, sim, state: Dictionary, group: int, start: Vector2, drop: float) -> void:
	var direction: float = state.direction_a if group == 0 else state.direction_b
	if is_zero_approx(direction): return
	var ascending := direction > 0
	var color := Color("#a6e1d4") if ascending else Color("#edb976")
	var remaining: float = maxf(0, state.next_at-sim.time)
	var progress := float(state.progress) if state.moving else clampf(1.0-remaining/8.0,0,1)
	var strength := .5 + .5*sin(progress*PI) if state.moving else smoothstep(0,.28,progress)
	for band in 3:
		var phase := (band+.5)/3.0 if Art.reduced_motion else fposmod(sim.time*.34+band/3.0,1)
		var rise := (phase if ascending else 1.0-phase) * 34.0
		for segment in 5:
			var x := start.x+.40+segment*.8
			var foot := point(x, start.y+2.83)+Vector2(0,drop+12-rise)
			var extent := Vector2(112,26+7*band)
			canvas.draw_texture_rect(glow,Rect2(foot-extent*.5,extent),false,Color(color,.48*strength*sin(phase*PI)))
	var center := point(start.x+2, start.y+.30) + Vector2(0,drop)
	var plate := PackedVector2Array([center+Vector2(-73,-11),center+Vector2(-63,-22),center+Vector2(63,-22),center+Vector2(73,-11),center+Vector2(63,11),center+Vector2(-63,11)])
	canvas.draw_colored_polygon(plate,Color(.046,.080,.087,.95))
	plate.append(plate[0]); canvas.draw_polyline(plate,Color(color,.84),1.3,true)
	var indicator := center+Vector2(-53,-5)
	var arrow := PackedVector2Array([indicator+Vector2(-5,4*direction),indicator+Vector2(0,-5*direction),indicator+Vector2(5,4*direction)])
	canvas.draw_colored_polygon(arrow,color)
	var status := ("浮台上升" if ascending else "浮台下沉") if state.moving else ("升台" if ascending else "降台")+"  %d 秒" % ceili(remaining)
	canvas.draw_string(Ui.medium_font(),center+Vector2(-37,1),status,HORIZONTAL_ALIGNMENT_CENTER,102,15,color)
	var meter := progress if not state.moving else 1.0-progress
	canvas.draw_line(center+Vector2(-58,8),center+Vector2(-58+116*meter,8),Color(color,.7),1.6,true)
func deck_mesh(pair: int) -> ArrayMesh:
	var key: String=str([pair,Geo.canvas_size,Geo.STAGE_FAR_Y,Geo.STAGE_NEAR_Y])
	if meshes.has(key):return meshes[key]
	var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
	const N:=12
	for y in N+1:
		var sy:=y/float(N)
		# Source is already painted in perspective. Undo that plane before projecting.
		var v:float=(sy-.25)/.53
		var left:float=lerpf(.13,.065,v);var right:float=lerpf(.87,.93,v)
		for x in N+1:
			var sx:=x/float(N);var u:float=(sx-left)/(right-left)
			var world_u:float=(6+u*2)/9.0;var world_t:float=(pair*2+v*2)/6.0
			var half:float=lerpf(Geo.STAGE_FAR_HALF_W,Geo.STAGE_NEAR_HALF_W,world_t)
			vertices.append(Vector3(Geo.STAGE_CX+(world_u*2-1)*half,lerpf(Geo.STAGE_FAR_Y,Geo.STAGE_NEAR_Y,world_t),0));uv.append(Vector2(sx,sy))
	for y in N:
		for x in N:
			var a:=y*(N+1)+x
			indices.append_array(PackedInt32Array([a,a+1,a+N+2,a,a+N+2,a+N+1]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);meshes.clear() if meshes.size()>16 else null
	meshes[key]=mesh;return mesh
func theatre(canvas: CanvasItem,sim) -> void:
	var elapsed:float=sim.time-sim.chapter.event_start
	var active:bool=sim.chapter.event_active()
	var warning:bool=elapsed>=0 and elapsed<6
	for pair in 3:
		if deck!=null:canvas.draw_mesh(deck_mesh(pair),deck,Transform2D.IDENTITY,Color(.90,.83,.72,.91))
		# Permanent cinnabar inlays bound both transit-only columns without square UI boxes.
		for col in [6.04,7.96]:
			var path:=PackedVector2Array()
			for i in 17:path.append(point(col+sin(i*.7+pair)*.015,pair*2+i/8.0))
			canvas.draw_polyline(path,Color(.24,.095,.07,.8),5,true)
			canvas.draw_polyline(path,Color(.76,.49,.23,.52),1.3,true)
		var clip:="idle"
		if active or warning:clip=("guide_up" if sim.chapter.guide_up else "guide_down") if sim.chapter.event_mode=="guide" else "haste"
		var tempo:float=2.4 if active else 1.2
		var pose:float=fposmod(sim.time*tempo+pair*.35,4)
		if Art.reduced_motion:pose=0
		# The trio stands to the side of the travelled diagonal, below guests in depth order.
		frames.draw_pose(canvas,"scenery-troupe",clip,pose,point(7.62,pair*2+1.88),82,false,Color(.90,.85,.76,1))
		if (active or warning) and sim.chapter.event_mode=="guide":
			var source:float=pair*2+(1.5 if sim.chapter.guide_up else .5)
			var target:float=pair*2+(.5 if sim.chapter.guide_up else 1.5)
			_guide_silk(canvas,source,target,elapsed,active)
		elif active and sim.chapter.event_mode=="haste":
			for k in 3:
				var f:float=(k+.5)/3.0 if Art.reduced_motion else fposmod(sim.time*.65+k/3.0,1)
				var path:=PackedVector2Array()
				for i in 17:path.append(point(8-2*f,pair*2+i/8.0))
				canvas.draw_polyline(path,Color(.95,.66,.32,sin(f*PI)*.37),3,true)

func _guide_silk(canvas: CanvasItem, source: float, target: float, elapsed: float, active: bool) -> void:
	var length := 1.0 if active or Art.reduced_motion else smoothstep(0,2.4,elapsed)
	if length < .01: return
	var pins := PackedVector2Array()
	var low := PackedVector2Array()
	var high := PackedVector2Array()
	var shadow := PackedVector2Array()
	var far_shadow := PackedVector2Array()
	var colors := PackedColorArray()
	var alpha := 1.0 if active else .64
	for i in 33:
		var fraction := length*i/32.0
		var at := point(8-2*fraction,lerpf(source,target,smoothstep(0,1,fraction)))
		var before := point(8-2*(fraction-.01),lerpf(source,target,smoothstep(0,1,fraction-.01)))
		var normal := (at-before).normalized().orthogonal()
		var shimmer := .5 if Art.reduced_motion else .5+.5*cos(fraction*22-elapsed*5.5)
		var taper := 4.0+6.0*sin(fraction*PI)
		var drift := normal*(shimmer-0.5)*1.6
		pins.append(at+drift)
		low.append(at+normal*taper+drift)
		high.append(at-normal*taper+drift)
		shadow.append(at+Vector2(1,4)+normal*(taper+1))
		far_shadow.append(at+Vector2(1,4)-normal*(taper+1))
		colors.append(Color(.32+.22*shimmer,.09+.08*shimmer,.065+.038*shimmer,.87*alpha))
	far_shadow.reverse();shadow.append_array(far_shadow)
	canvas.draw_colored_polygon(shadow,Color(.06,.024,.017,.61*alpha))
	var edge := high.duplicate();edge.reverse()
	var silk := low.duplicate();silk.append_array(edge)
	var reverse_colors := colors.duplicate();reverse_colors.reverse();colors.append_array(reverse_colors)
	canvas.draw_polygon(silk,colors)
	canvas.draw_polyline(low,Color(.79,.49,.23,.86*alpha),1.8,true)
	canvas.draw_polyline(high,Color(.91,.66,.35,.88*alpha),1.3,true)
	for i in range(3,32,5):
		var back := pins[i-2]
		var cross := (low[i]-high[i])*.25
		canvas.draw_polyline(PackedVector2Array([back-cross,pins[i],back+cross]),Color(1,.79,.47,.67*alpha),1.5,true)
	if not Art.reduced_motion:
		var lead := fposmod(elapsed*9,32.0) if active else 31.0
		var center := pins[int(lead)]
		canvas.draw_texture_rect(glow,Rect2(center-Vector2(24,15),Vector2(48,30)),false,Color(.94,.58,.23,.58))

func _draw_lamp_piece(canvas: CanvasItem, points: PackedVector2Array, layer: Dictionary, offset: Vector2, tint: Color) -> void:
	var uv := PackedVector2Array()
	var dimensions: Vector2 = layer.texture.get_size()
	for vertex in points: uv.append((vertex+offset)/dimensions)
	canvas.draw_polygon(points,PackedColorArray([tint]),uv,layer.texture)

func market(canvas: CanvasItem,sim) -> void:
	for pair in 3:
		var state:Dictionary=sim.chapter.lamp_pose(pair)
		var at:=point(9.50,pair*2+1.86)
		var scale:float=Geo.scale_at_flat(Vector2(1100,Geo.row_y(pair*2+1,6)),6)
		var layer: Dictionary = lamp_layers[pair]
		var anchor: Vector2 = layer.anchor
		var pivot: Vector2 = LAMP_PIVOTS[pair]
		var size: float = layer.scale*scale
		var sx := -size if bool(layer.flip) else size
		var light := clampf(float(state.light),0,1)
		var angle := 0.0
		if not Art.reduced_motion:
			var swing := .025 if state.clip == "dark" else (.084 if state.clip == "warning" else .041)
			angle = sin(sim.time*2.5+pair*1.2)*swing
		var paper: Vector2 = LAMP_PAPER[pair]
		var hinge := at+(pivot-anchor)*Vector2(sx,size)
		var flame := hinge+((paper-pivot)*Vector2(sx,size)).rotated(angle)
		if light > .01:
			var pool := point(8.64,pair*2+1.0)-Vector2(128,45)
			canvas.draw_texture_rect(glow,Rect2(pool,Vector2(256,90)),false,Color(.95,.43,.13,light*.24))
			canvas.draw_texture_rect(glow,Rect2(flame-Vector2(68,63),Vector2(136,126)),false,Color(1,.53,.19,light*.26))
		canvas.draw_set_transform(at-anchor*Vector2(sx,size),0,Vector2(sx,size))
		for piece in layer.base:
			_draw_lamp_piece(canvas,piece,layer,Vector2.ZERO,Color(.94,.91,.86))
		canvas.draw_set_transform(hinge-(pivot*Vector2(sx,size)).rotated(angle),angle,Vector2(sx,size))
		_draw_lamp_piece(canvas,layer.lamp,layer,Vector2.ZERO,Color(.94+light*.25,.91+light*.13,.86))
		if light > .01:
			canvas.draw_texture_rect(glow,Rect2(paper-Vector2(47,37),Vector2(94,84)),false,Color(1,.57,.17,light*.73))
			canvas.draw_texture_rect(glow,Rect2(paper+Vector2(-17,2),Vector2(34,41)),false,Color(1,.85,.44,light*.86))
		canvas.draw_set_transform(Vector2.ZERO)
