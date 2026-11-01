## 棋盘几何：1600×900 画布上的九列棋盘，行数随关卡在 5—6 之间切换。
## 逻辑与绘制共用同一套坐标，避免线框、热区、单位落点三处各算一遍。
class_name Geo
extends RefCounted

const VIEW = Vector2(1600.0, 900.0)
const COLS = 9
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


static func cell_h(rows: int) -> float:
	return BOARD_H / float(rows)


static func row_y(row: int, rows: int) -> float:
	return BOARD_Y + row * cell_h(rows) + cell_h(rows) * 0.5


static func cell_center(col: int, row: int, rows: int) -> Vector2:
	return Vector2(BOARD_X + col * CELL_W + CELL_W * 0.5, row_y(row, rows))


static func cell_at(point: Vector2, rows: int) -> Vector2i:
	if point.x < BOARD_X or point.y < BOARD_Y:
		return Vector2i(-1, -1)
	if point.x >= BOARD_X + BOARD_W or point.y >= BOARD_Y + BOARD_H:
		return Vector2i(-1, -1)
	var col = int((point.x - BOARD_X) / CELL_W)
	var row = int((point.y - BOARD_Y) / cell_h(rows))
	if col < 0 or col >= COLS or row < 0 or row >= rows:
		return Vector2i(-1, -1)
	return Vector2i(col, row)


static func board_rect(rows: int) -> Rect2:
	return Rect2(BOARD_X, BOARD_Y, BOARD_W, BOARD_H * 1.0)


## 单位按脚底对齐格底：格高不同（5 行 96 / 6 行 80）时靠这一偏移统一。
static func foot_offset(rows: int) -> float:
	return cell_h(rows) * 0.44


static func unit_scale(rows: int) -> float:
	return 1.0 if rows <= 5 else 0.86
