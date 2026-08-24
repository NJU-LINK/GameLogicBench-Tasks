extends "res://judge.gd"
#
# RECORD driver for atom_hitbox — renders the AUTHORITATIVE judge simulation to video.
#
# A THIN SHELL over judge.gd (which it extends): the physics-stepped simulation loop, the scenario
# handling, the real Area2D blade + its body_entered / body_exited signals, the registration ledger,
# and the result writing are all inherited — there is exactly ONE simulation, the judged one. This
# scene only flips on _record_mode and implements the _on_frame hook: each simulated frame is handed
# to game/view.gd (the same vector visuals the F5 preview draws) and rendered, so Movie Maker
# captures the judged run — the blade sweeping, targets lighting up as they take their hit.
#
# Run (windowed, under Xvfb + software GL, one video frame per sim frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N --controller res://logic/controller.gd --out /abs/result.json

const View = preload("res://view.gd")

var _view_spec: Dictionary = {}
var _vstate: Dictionary = {}

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	_view_spec = vs["spec"]
	_vstate = {
		"hitbox_pos": vs["hitbox_pos"], "hitbox_size": vs["hitbox_size"],
		"active": vs["active"], "swing": vs["swing"], "targets": vs["targets"],
	}
	queue_redraw()

func _draw() -> void:
	if _view_spec.is_empty():
		return
	View.render(self, _view_spec, _vstate)
