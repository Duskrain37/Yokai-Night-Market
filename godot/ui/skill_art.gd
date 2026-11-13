## Bespoke pictorial skill badges. Font glyphs never substitute for the artwork.
extends RefCounted
static var _textures:Dictionary={}
static func texture(path: String) -> Texture2D:
	if not _textures.has(path):_textures[path]=load(path) if not path.is_empty() else null
	return _textures[path]
static func draw(canvas: CanvasItem, rect: Rect2, status: Dictionary, clock: float, glow: bool = true) -> void:
	var at:=rect.get_center();var radius:=rect.size.x*.5
	var ready:=bool(status.get("ready",false));var left:=float(status.get("left",0))
	if ready and glow:
		var beat:=.5+.5*sin(clock*4.5)
		canvas.draw_circle(at,radius+5+beat*2,Color(1,.75,.3,.12+beat*.10))
		canvas.draw_arc(at,radius+3,-PI/2,TAU-PI/2,40,Color(1,.86,.52,.8),2,true)
	var tex:=texture(String(status.get("icon","")))
	if tex!=null:canvas.draw_texture_rect(tex,rect,false,Color.WHITE if ready else Color(.72,.77,.77,.9))
	if left>0:
		var remaining:=clampf(left/maxf(.01,float(status.get("cooldown",1))),0,1)
		var points:=PackedVector2Array([at])
		var start:float=-PI/2+TAU*(1.0-remaining)
		for i in 49:points.append(at+Vector2.from_angle(lerpf(start,TAU-PI/2,i/48.0))*radius)
		canvas.draw_colored_polygon(points,Color(.025,.055,.065,.74))
		canvas.draw_arc(at,radius,-PI/2,start,48,Color("#f6d98b"),2.2,true)
	elif not ready:canvas.draw_circle(at,radius,Color(.04,.07,.08,.35))
