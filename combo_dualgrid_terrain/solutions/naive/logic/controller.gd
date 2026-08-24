extends RefCounted
#
# NAIVE reference solution (red team) -- must PASS the previewed kind of site and FAIL the rest.
#
# It is the straightforward first pass at both jobs, with the three mistakes that go with it:
#
#   1. the opening appearance is laid out over the whole appearance grid (correct), but the INCREMENTAL
#      update reuses the terrain grid's bounds check, so a terrain cell on the border ring never gets
#      its outermost appearance cells refreshed;
#   2. the two combinations where only diagonally opposite corners are solid are folded into
#      "all four solid" -- they never came up on the previewed site;
#   3. the unit is simply pointed at its goal every frame at the largest allowed step. Solid rock is
#      the world's business: bodies do not walk through walls, so there is nothing to check.

var _display: TileMapLayer
var _w := 0
var _h := 0

func setup(state: Dictionary) -> void:
	_display = state["display"]
	var size: Vector2i = state["grid_size"]
	_w = size.x
	_h = size.y
	var grid: Array = state["grid"]
	for j in range(_h + 1):
		for i in range(_w + 1):
			_paint(grid, i, j)

func tick(state: Dictionary) -> Vector2:
	var grid: Array = state["grid"]
	for c in state["changed"]:
		var cell: Vector2i = c
		for d in [cell, Vector2i(cell.x + 1, cell.y), Vector2i(cell.x, cell.y + 1),
				Vector2i(cell.x + 1, cell.y + 1)]:
			if d.x >= _w or d.y >= _h:
				continue
			_paint(grid, d.x, d.y)
	var to_goal: Vector2 = state["goal_pos"] - state["self_pos"]
	var step: float = minf(float(state["max_step"]), to_goal.length())
	if step <= 0.0:
		return Vector2.ZERO
	return to_goal.normalized() * step

func _solid(grid: Array, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return 0
	return int(grid[y][x])

func _paint(grid: Array, i: int, j: int) -> void:
	var m := (_solid(grid, i - 1, j - 1) | (_solid(grid, i, j - 1) << 1)
		| (_solid(grid, i - 1, j) << 2) | (_solid(grid, i, j) << 3))
	if m == 6 or m == 9:
		m = 15
	_display.set_cell(Vector2i(i, j), 0, Vector2i(m % 4, int(m / 4)))
