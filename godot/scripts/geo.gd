## 棋盘几何：逻辑坐标是「平面九列网格」，屏幕坐标是「伪 3D 舞台」。
##
## 模拟层（sim.gd）永远用平面坐标算距离、射程、索敌——数值与 v0.2.4 完全一致；
## 只是绘制与点选时把平面坐标投到一块有透视的台面上（远处窄、近处宽、单位随深度缩放），
## 战场因此像是摆在布景里，而不是贴在背景上。
##
## 投影参数：
##   深度 t ∈ [0, 1]：0 = 最远的一行（row 0），1 = 最近的一行（最后一行）。
##   y(t)          = lerp(FAR_Y, NEAR_Y, t)
##   台面半宽(t)    = lerp(FAR_HALF_W, NEAR_HALF_W, t)
##   单位缩放(t)    = lerp(FAR_SCALE, NEAR_SCALE, t)
class_name Geo
extends RefCounted

const VIEW = Vector2(1600.0, 900.0)
const COLS = 9

# ── 平面坐标（逻辑）─────────────────────────────────────────────────────────
const CELL_W = 104.0
const BOARD_W = COLS * CELL_W            # 936
const BOARD_X = (VIEW.x - BOARD_W) * 0.5 # 332
const BOARD_H = 480.0
const BOARD_Y = 232.0
const TOP_HUD = 104.0

const SPAWN_X = 1330.0
const BREACH_X = BOARD_X - 26.0
const MOWER_X = BOARD_X - 36.0
const RETREAT_MAX_X = 1400.0

# ── 舞台投影（只影响画面）──────────────────────────────────────────────────
## 三张底图都是「高角度俯瞰、轻微前缩」的画法（台面上下边几乎水平，只有一点近大远小），
## 所以舞台用**轻透视**：远边比近边窄约一成、单位远小近大。
## 每天的台面在画里位置不同，故用 STAGES 表按天配参数，进关时 set_stage() 切换。
const STAGE_DEFAULT = {
	"cx": (BOARD_X + BOARD_W * 0.5),
	"far_y": BOARD_Y, "near_y": BOARD_Y + BOARD_H,
	"far_half": BOARD_W * 0.5, "near_half": BOARD_W * 0.5,
	"far_scale": 1.0, "near_scale": 1.0,
}

## 按交付图量出来的台面：cx=台面中心，far/near_y=上下边，far/near_half=半宽
const STAGES = {
	"day1": {"cx": 858.0, "far_y": 208.0, "near_y": 782.0,
		"far_half": 512.0, "near_half": 590.0,
		"far_scale": 0.92, "near_scale": 1.05},
	"day2": {"cx": 806.0, "far_y": 192.0, "near_y": 768.0,
		"far_half": 498.0, "near_half": 590.0,
		"far_scale": 0.90, "near_scale": 1.06},
	# 第三天的图是"石台—水—石台—水—石台"五条等宽带，所以直接给每条的边界，
	# 不再用均匀等分：均匀等分会让水陆界线和画里的岸线错开。
	"day3": {"cx": 830.0, "far_y": 200.0, "near_y": 790.0,
		"far_half": 615.0, "near_half": 660.0,
		"far_scale": 1.0, "near_scale": 1.05,
		# 照画量出来的六条边界：石台—水—石台—水—石台
		"bands": [200.0, 303.0, 397.0, 522.0, 642.0, 790.0],
		"halves": [615.0, 622.0, 630.0, 640.0, 652.0, 660.0]},
}

static var STAGE_CX = (BOARD_X + BOARD_W * 0.5)
static var STAGE_FAR_Y = BOARD_Y
static var STAGE_NEAR_Y = BOARD_Y + BOARD_H
static var STAGE_FAR_HALF_W = BOARD_W * 0.5
static var STAGE_NEAR_HALF_W = BOARD_W * 0.5
static var STAGE_FAR_SCALE = 1.0
static var STAGE_NEAR_SCALE = 1.0
## 逐行的上下边界与半宽（空 = 用 far_y/near_y 均匀等分）
static var BANDS: Array = []
static var HALVES: Array = []


## 进关时按当天切换舞台
static func set_stage(key: String) -> void:
	var stage: Dictionary = STAGES.get(key, STAGE_DEFAULT)
	STAGE_CX = float(stage["cx"])
	STAGE_FAR_Y = float(stage["far_y"])
	STAGE_NEAR_Y = float(stage["near_y"])
	STAGE_FAR_HALF_W = float(stage["far_half"])
	STAGE_NEAR_HALF_W = float(stage["near_half"])
	STAGE_FAR_SCALE = float(stage["far_scale"])
	STAGE_NEAR_SCALE = float(stage["near_scale"])
	BANDS = Array(stage.get("bands", []))
	HALVES = Array(stage.get("halves", []))


static func cell_h(rows: int) -> float:
	return BOARD_H / float(rows)


static func row_y(row: int, rows: int) -> float:
	return BOARD_Y + row * cell_h(rows) + cell_h(rows) * 0.5


static func cell_center(col: int, row: int, rows: int) -> Vector2:
	return Vector2(BOARD_X + col * CELL_W + CELL_W * 0.5, row_y(row, rows))


# ── 投影 ────────────────────────────────────────────────────────────────────
static func depth_scale(t: float) -> float:
	return lerpf(STAGE_FAR_SCALE, STAGE_NEAR_SCALE, clampf(t, 0.0, 1.0))


static func half_width_at_depth(t: float) -> float:
	return lerpf(STAGE_FAR_HALF_W, STAGE_NEAR_HALF_W, clampf(t, 0.0, 1.0))


static func y_at_depth(t: float) -> float:
	return lerpf(STAGE_FAR_Y, STAGE_NEAR_Y, clampf(t, 0.0, 1.0))


static func row_depth(row: int, rows: int) -> float:
	return (float(row) + 0.5) / float(rows)


## 平面坐标 → 屏幕坐标（绘制用；逻辑层不要依赖它）。
static func to_screen(pos: Vector2, rows: int = 0) -> Vector2:
	var u = (pos.x - BOARD_X) / BOARD_W
	if rows > 0 and BANDS.size() == rows + 1:
		var cell = BOARD_H / float(rows)
		var f = clampf((pos.y - BOARD_Y) / cell, 0.0, float(rows))
		var idx = mini(int(f), rows - 1)
		var k = f - float(idx)
		var y = lerpf(float(BANDS[idx]), float(BANDS[idx + 1]), k)
		var half = lerpf(float(HALVES[idx]) if HALVES.size() == rows + 1 			else half_width_at_depth((float(idx) + 0.5) / rows),
			float(HALVES[idx + 1]) if HALVES.size() == rows + 1 			else half_width_at_depth((float(idx) + 1.5) / rows), k)
		return Vector2(STAGE_CX + (u * 2.0 - 1.0) * half, y)
	var t = clampf((pos.y - BOARD_Y) / BOARD_H, -0.4, 1.4)
	var half = half_width_at_depth(t)
	return Vector2(STAGE_CX + (u * 2.0 - 1.0) * half, y_at_depth(t))


## 屏幕坐标 → 平面坐标（只用于把点击换算回格子）。
static func to_flat(screen: Vector2, rows: int = 0) -> Vector2:
	if rows > 0 and BANDS.size() == rows + 1:
		# 逐行反解：先找到落在哪两条边界之间
		for i in rows:
			var y0 = float(BANDS[i])
			var y1 = float(BANDS[i + 1])
			if screen.y <= y1 or i == rows - 1:
				var k = clampf((screen.y - y0) / maxf(1.0, y1 - y0), 0.0, 1.0)
				var half = lerpf(float(HALVES[i]) if HALVES.size() == rows + 1 \
					else half_width_at_depth((float(i) + 0.5) / rows),
					float(HALVES[i + 1]) if HALVES.size() == rows + 1 \
					else half_width_at_depth((float(i) + 1.5) / rows), k)
				var uu = clampf(((screen.x - STAGE_CX) / half + 1.0) * 0.5, 0.0, 1.0)
				var cell = BOARD_H / float(rows)
				return Vector2(BOARD_X + uu * BOARD_W,
					BOARD_Y + (float(i) + k) * cell)
	return _to_flat_uniform(screen)


static func _to_flat_uniform(screen: Vector2) -> Vector2:
	var t = clampf((screen.y - STAGE_FAR_Y) / (STAGE_NEAR_Y - STAGE_FAR_Y), 0.0, 0.9995)
	var half = half_width_at_depth(t)
	var u = clampf(((screen.x - STAGE_CX) / half + 1.0) * 0.5, 0.0, 0.9995)
	return Vector2(BOARD_X + u * BOARD_W, BOARD_Y + t * BOARD_H)


static func scale_at_flat(pos: Vector2, rows: int = 0) -> float:
	if rows > 0 and BANDS.size() == rows + 1:
		var cell = BOARD_H / float(rows)
		var idx = clampi(int((pos.y - BOARD_Y) / cell), 0, rows - 1)
		var band_h = float(BANDS[idx + 1]) - float(BANDS[idx])
		return depth_scale((pos.y - BOARD_Y) / BOARD_H) * (band_h / cell) * 0.92
	return depth_scale((pos.y - BOARD_Y) / BOARD_H)


static func screen_cell_center(col: int, row: int, rows: int) -> Vector2:
	return to_screen(cell_center(col, row, rows), rows)


static func screen_cell_polygon(col: int, row: int, rows: int) -> PackedVector2Array:
	var center=cell_center(col,row,rows)
	var half=Vector2(CELL_W*0.5,cell_h(rows)*0.5)
	return PackedVector2Array([to_screen(center-half,rows),
		to_screen(center+Vector2(half.x,-half.y),rows),to_screen(center+half,rows),
		to_screen(center+Vector2(-half.x,half.y),rows)])


static func screen_cell_at(point: Vector2, rows: int) -> Vector2i:
	var flat = to_flat(point, rows)
	var col = int((flat.x - BOARD_X) / CELL_W)
	var row = clampi(int((flat.y - BOARD_Y) / cell_h(rows)), 0, rows - 1)
	if col < 0 or col >= COLS:
		return Vector2i(-1, -1)
	return Vector2i(col, row)


## 平面里的圆 → 屏幕上的椭圆半径（透视压扁）。
static func range_ellipse(center_flat: Vector2, radius: float) -> Vector2:
	var t = clampf((center_flat.y - BOARD_Y) / BOARD_H, 0.0, 1.0)
	var sx = half_width_at_depth(t) * 2.0 / BOARD_W
	return Vector2(radius * sx, radius * sx * 0.54)


## 台面四角：远左、远右、近右、近左。
static func stage_corners() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(STAGE_CX - STAGE_FAR_HALF_W, STAGE_FAR_Y),
		Vector2(STAGE_CX + STAGE_FAR_HALF_W, STAGE_FAR_Y),
		Vector2(STAGE_CX + STAGE_NEAR_HALF_W, STAGE_NEAR_Y),
		Vector2(STAGE_CX - STAGE_NEAR_HALF_W, STAGE_NEAR_Y),
	])


static func board_rect(rows: int) -> Rect2:
	return Rect2(BOARD_X, BOARD_Y, BOARD_W, BOARD_H * 1.0)


## 单位按脚底对齐格底：格高不同（5 行 96 / 6 行 80）时靠这一偏移统一。
static func foot_offset(rows: int) -> float:
	return cell_h(rows) * 0.44


static func unit_scale(rows: int) -> float:
	return 1.0 if rows <= 5 else 0.86
