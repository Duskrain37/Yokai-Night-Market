## Independent painted props projected onto the same coordinates as gameplay.
extends RefCounted
const Art = preload("res://ui/market_art.gd")
var frames = preload("res://scripts/actor_frames.gd").new()
var deck: Texture2D
var meshes: Dictionary = {}
func _init() -> void:
	frames.load_sheets("scenery-")
	if ResourceLoader.exists("res://assets/scenery/theatre-deck.png"):deck=load("res://assets/scenery/theatre-deck.png")
func point(col: float,row: float) -> Vector2:
	return Geo.to_screen(Vector2(Geo.BOARD_X+col*Geo.CELL_W,Geo.BOARD_Y+row*Geo.cell_h(6)),6)
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
			var ribbon:=PackedVector2Array()
			for i in 41:
				var f:=i/40.0;var blend:=smoothstep(0,1,f)
				ribbon.append(point(8-2*f,lerpf(source,target,blend)))
			canvas.draw_polyline(ribbon,Color(.30,.07,.045,.65),13,true)
			canvas.draw_polyline(ribbon,Color(.83,.52,.25,.65 if active else .32),7,true)
			canvas.draw_polyline(ribbon,Color(1,.83,.53,.6 if active else .28),1.2,true)
			if not Art.reduced_motion:
				for k in 3:
					var f:=fposmod(sim.time*.32+k/3.0,1)
					var at:=point(8-2*f,lerpf(source,target,smoothstep(0,1,f)))
					canvas.draw_arc(at,5,PI*.1,PI*1.8,16,Color(.98,.76,.40,.72),1.5,true)
		elif active and sim.chapter.event_mode=="haste":
			for k in 3:
				var f:float=(k+.5)/3.0 if Art.reduced_motion else fposmod(sim.time*.65+k/3.0,1)
				var path:=PackedVector2Array()
				for i in 17:path.append(point(8-2*f,pair*2+i/8.0))
				canvas.draw_polyline(path,Color(.95,.66,.32,sin(f*PI)*.37),3,true)
func market(canvas: CanvasItem,sim) -> void:
	var actors:=["cloud-lamp","pact-lamp","lotus-lamp"]
	for pair in 3:
		var state:Dictionary=sim.chapter.lamp_pose(pair)
		var at:=point(9.50,pair*2+1.86)
		var scale:float=Geo.scale_at_flat(Vector2(1100,Geo.row_y(pair*2+1,6)),6)
		if state.light>.01:
			for n in 6:
				canvas.draw_set_transform(point(8.30,pair*2+1.0),0,Vector2(1.65,.85))
				canvas.draw_circle(Vector2.ZERO,45+n*11,Color(.92,.54,.19,float(state.light)*.012))
				canvas.draw_set_transform(Vector2.ZERO)
			# Soft overlapping pools follow the lantern, no player buff or opaque lane rectangles.
			for n in 9:
				var radius:float=18+n*9
				canvas.draw_set_transform(at+Vector2(-40,-80)*scale,0,Vector2(1.3,.58))
				canvas.draw_circle(Vector2.ZERO,radius,Color(.96,.56,.18,float(state.light)*.010*(1-n/11.0)))
				canvas.draw_set_transform(Vector2.ZERO)
		frames.draw_pose(canvas,"scenery-"+actors[pair],state.clip,0 if Art.reduced_motion and state.clip in ["dark","lit","warning"] else state.key,at,172*scale,true,Color(.94,.91,.86,1))
