extends RefCounted
#
# NAIVE reference move engine — the intuitive "grid navigation" reading of the puzzle, written as a
# real, coherent engine (not a strawman). Its whole mental model is: "a move steps THE hopper ONE
# cell in the direction; if that cell holds a fresh dot, collect it; the puzzle is won when every
# dot is collected and every hopper stands on a goal." It even detects the win correctly. Every
# defect flows from the ONE assumption that a move is a single cell step:
#   * ONE STEP, never SLIDES to the first un-collected dot and never HOPS OVER a collected one — the
#     real engine slides all the way and hops over collected dots and empty cells    -> hop_slide
#   * NO undo — a direction that leads back over the trail is just another one-cell step; it never
#     rewinds the last move or restores the dot it had collected                      -> undo_rewind
#   * NO goal freeze — stepping onto the goal early is just another step and it keeps walking; the
#     real engine locks that hopper in place (stuck) until an undo releases it         -> goal_freeze
#   * only ever steers players[0] — the real engine drives EVERY hopper with the one shared direction
#                                                                                      -> two_player_sync
# On the baseline (a single hopper, a clean adjacent line of dots ending at the goal, no undo, no
# early goal) every hop IS a single step and none of the bugs can fire, so the baseline matches.

func move(state: PuzzleState, dir: Vector2) -> int:
	if dir == Vector2.ZERO:
		return PuzzleState.MoveResult.zero
	if (state.players as Array).is_empty():
		return PuzzleState.MoveResult.stuck
	# BUG: only the first hopper is ever steered (ignores every other hopper).
	var p: PuzzleState.Player = state.players[0]
	var nxt: Vector2 = p.coord + dir              # BUG: one cell, never slides to the first dot
	if not state.coord_in_grid(nxt):
		return PuzzleState.MoveResult.stuck
	var c: PuzzleState.Cell = state.cell_at_coord(nxt)
	if c == null or c.has_player():
		return PuzzleState.MoveResult.stuck
	# step one cell (BUG: no undo handling; BUG: no goal freeze — never sets stuck)
	p.move_history.push_front(p.coord)
	state.mark_player(nxt)
	state.drop_player(p.coord)
	if c.has_dot():
		state.mark_dotted(nxt)                    # collect a fresh dot only
	p.coord = nxt
	if check_win(state):
		state.win = true
	return PuzzleState.MoveResult.moved

func check_win(state: PuzzleState) -> bool:
	if state.require_all_players_at_goal():
		var goals: Array = state.all_cells().filter(func(c: PuzzleState.Cell) -> bool: return c.has_goal())
		if not goals.all(func(c: PuzzleState.Cell) -> bool: return c.has_player()):
			return false
	if state.require_all_dots():
		if not state.all_cells().all(func(c: PuzzleState.Cell) -> bool: return not c.has_dot()):
			return false
	return true
