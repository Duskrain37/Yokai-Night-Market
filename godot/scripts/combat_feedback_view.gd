## Painted feedback over the number layer. Settings affect presentation only.
extends RefCounted
const Ledger = preload("res://scripts/combat_numbers.gd")
const Art = preload("res://ui/market_art.gd")
var frames = preload("res://scripts/actor_frames.gd").new()
func _init() -> void:frames.load_sheets("scenery-")
func draw(canvas: CanvasItem, sim) -> void:
	if sim==null or sim.vital_numbers.mode=="off":return
	var font:=Ui.medium_font()
	var base:int={"small":17,"medium":23,"large":30}.get(sim.vital_numbers.mode,23)
	var used:Array[Rect2]=[]
	var calm:bool=Art.reduced_motion
	for e in sim.vital_numbers.entries:
		var progress:float=clampf(float(e.age)/float(e.life),0,1)
		var power:=Ledger.strength(e.amount)
		var pop:float=clampf(float(e.pop)/.24,0,1)
		var kick:float=(sin(pop*PI)*(.18+power*.38)) if not calm else 0.0
		var size:=roundi(Ledger.point_size(e.amount,base,e.healing)*(1+kick))
		var at:Vector2=Geo.to_screen(e.at,sim.rows)
		at.y-=float(e.height)*Geo.unit_scale(sim.rows)*Geo.scale_at_flat(e.at,sim.rows)*.92
		at+=Vector2(30 if e.healing else -20,-progress*(19 if calm else 40)-kick*12)
		var value:=Ledger.text(e.amount,e.healing)
		var color:=Color("#98eca4") if e.healing else Color("#ffcf46")
		color.a=minf(1,(1-progress)*3)
		var width:float=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		var pos:Vector2=at-Vector2(width*.5,0)
		pos.x=clampf(pos.x,12,maxf(12,Geo.canvas_size.x-width-12));pos.y=maxf(size+12,pos.y)
		var bounds:=Rect2(pos-Vector2(9,size),Vector2(width+18,size+7))
		for attempt in 4:
			if not used.any(func(rect):return rect.intersects(bounds)):break
			if pos.y-size-16<20:break
			pos.y-=size*.72+5;bounds.position.y=pos.y-size
		used.append(bounds)
		if not e.healing and e.amount>=250 and e.pop<.5:
			var t:float=clampf(float(e.pop)/.5,0,1)
			frames.draw_pose(canvas,"scenery-impact-ink","heavy",1.5 if calm else t*3.875,pos+Vector2(width*.5,-size*.34),size*(1.5+power),false,Color(1,.85,.5,(1-t)*.62))
		# Dark lacquer edge, warm ochre offset, then one readable yellow/green face.
		canvas.draw_string_outline(font,pos+Vector2(1,3),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,5,Color(.10,.045,.018,color.a*.90))
		canvas.draw_string(font,pos+Vector2(1,2),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(.20,.32,.08,color.a*.65) if e.healing else Color(.60,.24,.025,color.a*.85))
		canvas.draw_string_outline(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,3,Color(.045,.045,.025,color.a))
		canvas.draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
	for e in sim.vital_numbers.finishes:
		var t:float=clampf(float(e.age)/float(e.life),0,1)
		var at:Vector2=Geo.to_screen(e.at,sim.rows)+Vector2(0,-100-(0 if calm else t*35))
		at.x=clampf(at.x,180,Geo.canvas_size.x-180);at.y=clampf(at.y,160,Geo.canvas_size.y-80)
		var fade:float=minf(1,(1-t)*4)
		var text:="连退 %d" % int(e.count)
		var size:=27+int(e.tier)*3
		var width:float=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		for offset in [Vector2(0,-45),Vector2(0,45),Vector2(-180,-45),Vector2(180,-45),Vector2(-180,35),Vector2(180,35)]:
			var candidate:Vector2=at+offset
			candidate.x=clampf(candidate.x,180,Geo.canvas_size.x-180);candidate.y=clampf(candidate.y,180,Geo.canvas_size.y-80)
			var rect:=Rect2(candidate-Vector2(width*.5+10,size+8),Vector2(width+20,size+20))
			if not used.any(func(r):return r.intersects(rect)):
				at=candidate;used.append(rect);break
		frames.draw_pose(canvas,"scenery-impact-ink","crowd",1.5 if calm else minf(3.875,t*4),at,100+int(e.tier)*17,false,Color(1,.92,.69,fade*.85))
		canvas.draw_string_outline(font,at-Vector2(width*.5,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,5,Color(.10,.035,.015,fade))
		canvas.draw_string(font,at-Vector2(width*.5,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(1,.84,.37,fade))
