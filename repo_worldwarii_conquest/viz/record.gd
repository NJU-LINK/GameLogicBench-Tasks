extends "res://judge.gd"
#
# viz/record.gd -- record layer (extends the judge; NEVER seen by the agent).
#
# Reuses the judge's exact campaign simulation (judge.gd::_run drives the turns) and renders a
# strategic-map SNAPSHOT per turn. The conquest layer is turn-based with no frame animation, so
# the judge already gates one `await get_tree().physics_frame` per turn behind `_record_mode`
# (zero cost on the judge path); Movie Maker captures one video frame per turn. This layer only
# adds the drawing -- the simulation, scenario and seed are the judge's.

const _CampaignManager := preload("res://scripts/scenario/campaign_manager.gd")
const _ConquestManager := preload("res://scripts/scenario/conquest_manager.gd")
const _ConquestSupply := preload("res://scripts/scenario/conquest_supply.gd")

var _board: Node2D


func _ready() -> void:
	_record_mode = true
	_board = _Board.new()
	add_child(_board)
	await _run()


func _on_frame(vs: Dictionary) -> void:
	var conquest := _ConquestManager.conquest_state(_state, _ctx["map_data"])
	var regions: Dictionary = conquest.get("regions", {})
	var supply := _ConquestSupply.status_by_region(regions)
	var snap: Array = []
	for rid in regions.keys():
		var r: Dictionary = regions[rid]
		snap.append({
			"id": String(rid), "x": int(r.get("x", 0)), "y": int(r.get("y", 0)),
			"owner": String(r.get("owner", "")), "strength": int(r.get("strength", 0)),
			"fort": int(r.get("fort_level", 0)),
			"garrison": (r.get("garrison", []) as Array).size(),
			"supply_source": bool(r.get("supply_source", false)),
			"supplied": bool(supply.get(String(rid), true)),
			"neighbors": (r.get("neighbors", []) as Array).duplicate(),
		})
	_board.set_snapshot(snap, int(vs.get("turn", 0)), String(_ctx.get("player", "")))


# ---- strategic-map renderer (vector; uses the engine's default font) ----
class _Board extends Node2D:
	const COLORS := {
		"germany": Color("#a86632"), "soviet": Color("#3f7f4a"),
		"allies": Color("#2f6fb0"), "neutral": Color("#6f7882"),
	}
	var _snap: Array = []
	var _turn: int = 0
	var _player: String = ""

	func set_snapshot(snap: Array, turn: int, player: String) -> void:
		_snap = snap
		_turn = turn
		_player = player
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 960, 600), Color("#14181f"))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(24, 40), "Conquest campaign — turn %d  (you: %s)" % [_turn, _player],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#e8e8e8"))
		if _snap.is_empty():
			return
		var ox := 120.0
		var oy := 110.0
		var sx := 150.0
		var sy := 130.0
		var pos := {}
		for r in _snap:
			pos[String(r["id"])] = Vector2(ox + float(int(r["x"])) * sx, oy + float(int(r["y"])) * sy)
		# edges
		for r in _snap:
			var p: Vector2 = pos[String(r["id"])]
			for nb in r["neighbors"]:
				if pos.has(String(nb)):
					draw_line(p, pos[String(nb)], Color(1, 1, 1, 0.12), 2.0)
		# regions
		for r in _snap:
			var p: Vector2 = pos[String(r["id"])]
			var col: Color = COLORS.get(String(r["owner"]), Color("#888888"))
			draw_circle(p, 34.0, col)
			if not bool(r["supplied"]):
				draw_arc(p, 40.0, 0, TAU, 32, Color("#d9534f"), 3.0)   # cut = red ring
			if bool(r["supply_source"]):
				draw_arc(p, 44.0, 0, TAU, 32, Color("#f0d060"), 3.0)   # supply source = gold ring
			draw_string(font, p + Vector2(-30, -44), String(r["id"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#dddddd"))
			draw_string(font, p + Vector2(-26, 6),
				"s%d f%d" % [int(r["strength"]), int(r["fort"])],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ffffff"))
			draw_string(font, p + Vector2(-26, 24), "g%d" % int(r["garrison"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c8e6c9"))
