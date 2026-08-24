extends "res://judge.gd"
#
# RECORD driver for combo_dualgrid_terrain -- renders the AUTHORITATIVE judge simulation to video.
#
# A THIN SHELL over judge.gd (which it extends): the world build, the scenario handling, the terrain
# edits, the deliverable's appearance layer, the unit's movement and the verdict are all inherited --
# there is exactly ONE simulation, the judged one. This scene only flips on _record_mode and
# implements the _on_frame hook: the appearance layer is a real node in the judged scene and draws
# itself, and game/view.gd paints the survey overlay on top (terrain outlines, the cells edited this
# frame, the unit, its goal, the running readouts).
#
# Run (windowed, under Xvfb + software GL, one video frame per sim frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N --controller res://logic/controller.gd --out /abs/result.json

const View = preload("res://view.gd")
const SimCore2 = preload("res://sim_core.gd")

var _vs: Dictionary = {}

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	# the judged scene's layers draw underneath the overlay
	var root: Node2D = vs["level_root"]
	if root != null:
		root.z_index = -10
	_vs = {
		"frame": vs["frame"],
		"grid": SimCore2.grid_snapshot(vs["grid"]),
		"unit_pos": vs["unit_pos"],
		"goal_pos": vs["goal_pos"],
		"changed": (vs["changed"] as Array).duplicate(),
		"penetration": vs["penetration"],
		"mismatch": vs["mismatch"],
	}
	queue_redraw()

func _draw() -> void:
	if _vs.is_empty():
		return
	View.render(self, {}, _vs)
