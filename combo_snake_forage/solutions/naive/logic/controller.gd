extends RefCounted
#
# NAIVE solution (== probe tier 1): reactive BFS shortest-path to the food.
#
# Every tick it runs a breadth-first search from the head to the food over the currently-free cells
# (body minus the tail, which vacates), and steps along the shortest path. If the food is
# unreachable this tick it falls back to any move that does not kill it immediately. There is NO
# lookahead: it never asks whether eating now seals it in later. This is the "re-read state and head
# straight for the goal" default -- it feeds fine while the snake is short and the arena is roomy
# (baseline), and coils the head into a self-closing pocket once the snake is long or the space is
# tight (self_trap on the armed scenarios).

const DIRS := {"up": Vector2i(0, -1), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}

func on_tick(state: Dictionary) -> String:
	var snake: Array = state["snake"]
	var head: Vector2i = snake[0]
	var food: Vector2i = state["food"]
	var gw := int(state["grid_w"])
	var gh := int(state["grid_h"])
	var dir_vec: Vector2i = state["dir"]

	var blocked := _blocked_set(snake)   # body minus tail
	var step := _bfs_first_step(head, food, blocked, gw, gh)
	if step == Vector2i.ZERO:
		step = _any_safe(head, dir_vec, blocked, gw, gh)
	return _to_name(step, dir_vec)

# Cells occupied after this tick if not eating (tail vacates).
func _blocked_set(snake: Array) -> Dictionary:
	var b := {}
	for i in range(snake.size() - 1):
		b[snake[i]] = true
	return b

# BFS from head to food; returns the FIRST step direction (Vector2i) or ZERO if unreachable.
func _bfs_first_step(head: Vector2i, food: Vector2i, blocked: Dictionary, gw: int, gh: int) -> Vector2i:
	if food.x < 0:
		return Vector2i.ZERO
	var came := {head: head}
	var q: Array = [head]
	var qi := 0
	while qi < q.size():
		var cur: Vector2i = q[qi]
		qi += 1
		if cur == food:
			break
		for v in DIRS.values():
			var nb: Vector2i = cur + v
			if nb.x < 0 or nb.x >= gw or nb.y < 0 or nb.y >= gh:
				continue
			if blocked.has(nb) or came.has(nb):
				continue
			came[nb] = cur
			q.append(nb)
	if not came.has(food):
		return Vector2i.ZERO
	var node := food
	while came[node] != head:
		node = came[node]
	return node - head

# Any neighbour that does not immediately die; prefers keeping the current heading.
func _any_safe(head: Vector2i, dir_vec: Vector2i, blocked: Dictionary, gw: int, gh: int) -> Vector2i:
	var order := [dir_vec, Vector2i(-dir_vec.y, dir_vec.x), Vector2i(dir_vec.y, -dir_vec.x), -dir_vec]
	for v in order:
		var nb: Vector2i = head + v
		if nb.x < 0 or nb.x >= gw or nb.y < 0 or nb.y >= gh:
			continue
		if blocked.has(nb):
			continue
		return v
	return dir_vec   # doomed

func _to_name(step: Vector2i, dir_vec: Vector2i) -> String:
	if step == Vector2i.ZERO:
		step = dir_vec
	for k in DIRS:
		if DIRS[k] == step:
			return k
	return "right"
