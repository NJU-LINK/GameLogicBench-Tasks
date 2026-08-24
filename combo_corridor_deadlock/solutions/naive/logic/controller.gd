extends RefCounted
# naive（探针 tier1）：各单位独立 BFS（只避墙）朝目标走；若下一格当前被别的单位占据则原地等。
# 零跨单位协调、无让路概念——两单位在单宽走廊对穿时互相盯着对方占据的格子死等 -> 对称死锁。

const DIRS := {"up": Vector2i(0, -1), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}

func on_tick(state: Dictionary) -> Array:
	var gw := int(state["grid_w"])
	var gh := int(state["grid_h"])
	var wall_set := {}
	for w in state["walls"]:
		wall_set[w] = true
	var units: Array = state["units"]
	var occ := {}
	for u in units:
		occ[u["pos"]] = true

	var moves: Array = []
	for i in range(units.size()):
		var u: Dictionary = units[i]
		var pos: Vector2i = u["pos"]
		var goal: Vector2i = u["goal"]
		if pos == goal:
			moves.append("wait")
			continue
		var step := _bfs_first(pos, goal, wall_set, gw, gh)
		if step == Vector2i.ZERO:
			moves.append("wait")
			continue
		var nc: Vector2i = pos + step
		if occ.has(nc):        # 下一格被占（含别的单位）-> 保守等待
			moves.append("wait")
		else:
			moves.append(_name(step))
	return moves

func _bfs_first(start: Vector2i, goal: Vector2i, walls: Dictionary, gw: int, gh: int) -> Vector2i:
	if start == goal:
		return Vector2i.ZERO
	var came := {start: start}
	var q: Array = [start]
	var qi := 0
	while qi < q.size():
		var cur: Vector2i = q[qi]
		qi += 1
		if cur == goal:
			break
		for v in DIRS.values():
			var nb: Vector2i = cur + v
			if nb.x < 0 or nb.x >= gw or nb.y < 0 or nb.y >= gh:
				continue
			if walls.has(nb) or came.has(nb):
				continue
			came[nb] = cur
			q.append(nb)
	if not came.has(goal):
		return Vector2i.ZERO
	var node := goal
	while came[node] != start:
		node = came[node]
	return node - start

func _name(step: Vector2i) -> String:
	for k in DIRS:
		if DIRS[k] == step:
			return k
	return "wait"
