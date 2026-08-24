extends "res://judge.gd"
#
# RECORD driver for combo_sweep_collision — renders the AUTHORITATIVE judge simulation to video.
#
# A THIN SHELL over judge.gd (which it extends): the world build, the scenario handling, the real
# PhysicsServer2D walls + mover, the reference recompute and the verdict are all inherited — there is
# exactly ONE simulation, the judged one. This scene only flips on _record_mode and implements the
# _on_frame hook: each simulated frame is handed to game/view.gd (the same vector visuals the F5
# preview draws) and rendered, so Movie Maker captures the judged run — the mover sweeping into walls,
# depenetrating, sliding along surfaces.
#
# Run (windowed, under Xvfb + software GL, one video frame per sim frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N --controller res://logic/controller.gd --out /abs/result.json

const View = preload("res://view.gd")

var _vs: Dictionary = {}
var _dims: Dictionary = {}

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	_dims = {"world_w": vs["world_w"], "world_h": vs["world_h"]}
	_vs = {
		"pos": vs["pos"], "moving": vs["moving"], "walls": vs["walls"],
		"radius": vs["radius"],
	}
	queue_redraw()

func _draw() -> void:
	if _vs.is_empty():
		return
	View.render(self, _dims, _vs)
