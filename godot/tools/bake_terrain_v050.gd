extends SceneTree

## Export paint-over guides aligned to the same projected cell coordinates as the game.
const FLOOR_LIMITS = [[485, 612, 739, 865, 991, 1117], [366, 505, 643, 778, 916, 1057, 1200, 1300],
	[180, 313, 444, 576, 711, 849, 990, 1125, 1265], [175, 308, 440, 576, 711, 849, 989, 1128, 1265],
	[363, 505, 643, 781, 920, 1063, 1205, 1300], [468, 604, 739, 872, 1005, 1141]]
const FLOOR_BANDS = [134, 228, 327, 427, 528, 628, 737]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		printerr("Pass island and cavern source filenames and an existing output directory after --")
		quit(1)
		return
	for index in 2:
		var image := Image.load_from_file(args[index])
		if image == null or image.is_empty():
			quit(2)
			return
		image.resize(1600, 900, Image.INTERPOLATE_LANCZOS)
		var day := "day4" if index == 0 else "day5"
		Geo.set_stage(day)
		var baked := _island(image) if index == 0 else _cavern(image)
		if baked.save_png(args[2].path_join("guide-%s.png" % day)) != OK:
			quit(3)
			return
	quit()


func _island(source: Image) -> Image:
	var image := source.duplicate() as Image
	var origin := Geo.screen_cell_polygon(0, 0, 6)[0]
	var finish := Geo.screen_cell_polygon(8, 5, 6)[2]
	var step := (finish - origin) / Vector2(9, 6)
	for y in range(int(origin.y) - 10, int(finish.y) + 10):
		var row := clampi(floori((y - origin.y) / step.y), 0, 5)
		var v := clampf((y - origin.y - row * step.y) / step.y, 0.0, 0.999)
		var left := int(Content.ISLAND_EDGE[row].size() / 2)
		var count := 9 - left * 2
		var left_edge := origin.x + left * step.x
		var right_edge := origin.x + (9 - left) * step.x
		var offsets: Array = FLOOR_LIMITS[row]
		var sy := roundi(lerpf(FLOOR_BANDS[row] + 3.0, FLOOR_BANDS[row + 1] - 4.0, v))
		var terrace := smoothstep(0.0, 10.0, minf(y - origin.y + 10, finish.y + 9 - y))
		for x in range(98, 1600):
			var original := source.get_pixel(x, y)
			var local := x - left_edge
			var col := clampi(floori(local / step.x), 0, count - 1)
			var u := clampf(fposmod(local, step.x) / step.x, 0.0, 0.999)
			var sample := col if col < offsets.size() - 1 else 2
			var sx := roundi(lerpf(float(offsets[sample]) + 3, float(offsets[sample + 1]) - 4, u))
			var edge := minf(x - left_edge, right_edge - x)
			var grain := sin(y * 0.37 + x * 0.047) * 2.4 + sin(y * 0.101 + x * 0.071) * 1.7
			var on_slab := smoothstep(-3.0, 5.0, edge + grain)
			var stone := source.get_pixel(sx, sy)
			var joint := minf(minf(u, 1.0 - u) * step.x, minf(v, 1.0 - v) * step.y) + grain
			stone = stone.darkened((1.0 - smoothstep(-1.0, 4.5, joint)) * 0.19)
			# A broad bedrock margin joins all six lanes, with the same shoreline hues on both sides.
			var rock_x := 1384 + posmod(x + int(27 * sin(y * .021)), 149)
			var rock_y := 255 + posmod(y - 255, 389)
			var rock := source.get_pixel(rock_x, rock_y).darkened(0.12)
			var land := rock.lerp(original, 0.29)
			var margin := smoothstep(0.0, 45.0, x - 98.0)
			image.set_pixel(x, y, original.lerp(land.lerp(stone, on_slab), terrace * margin))
	return image


func _cavern(source: Image) -> Image:
	var image := source.duplicate() as Image
	var origin := Geo.screen_cell_polygon(0, 0, 6)[0]
	var finish := Geo.screen_cell_polygon(8, 5, 6)[2]
	var step := (finish - origin) / Vector2(9, 6)
	for y in range(int(origin.y), int(finish.y)):
		var row := clampi(floori((y - origin.y) / step.y), 0, 5)
		for x in range(int(origin.x), int(finish.x)):
			var col := clampi(floori((x - origin.x) / step.x), 0, 8)
			var wet: bool = col in Content.CAVERN_WATER_CELLS[row]
			var pit: bool = col in Content.CAVERN_PITS[row]
			if not wet and not pit:
				continue
			var inside: Array = Content.CAVERN_WATER_CELLS if wet else Content.CAVERN_PITS
			var u := fposmod(x - origin.x, step.x)
			var v := fposmod(y - origin.y, step.y)
			var edge := 99.0
			if col - 1 not in inside[row]: edge = minf(edge, u)
			if col + 1 not in inside[row]: edge = minf(edge, step.x - u)
			if row == 0 or col not in inside[row - 1]: edge = minf(edge, v)
			if row == 5 or col not in inside[row + 1]: edge = minf(edge, step.y - v)
			edge += sin(x * .18 + y * .082) * 2.8 + sin(y * .21) * 1.8
			var base := source.get_pixel(x, y)
			var color := Color("#122529") if wet else Color("#080e16")
			if wet:
				var ripple := pow(maxf(0.0, sin(y * .30 + sin(x * .037) * 2.8)), 11.0)
				color = base.lerp(color, .71).lightened(ripple * (0.04 + 0.02 * sin(x * .02)))
			else:
				color = base.lerp(color, smoothstep(0.0, 37.0, edge) * .9 + .09)
			var shore := base.lightened((1.0 - smoothstep(3.0, 14.0, edge)) * 0.12)
			image.set_pixel(x, y, shore.lerp(color, smoothstep(1.0, 10.0, edge)))
	return image
