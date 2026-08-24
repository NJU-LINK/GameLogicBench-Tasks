extends "res://judge.gd"
#
# RECORD driver for atom_jump_landing — renders the AUTHORITATIVE judge simulation to video.
#
# Thin shell over judge.gd: flips _record_mode, implements _on_frame to paint each settled
# frame via game/view.gd, and defers all simulation/assertion logic to the parent.
#
# Run (windowed, under Xvfb + software GL):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N --controller res://logic/controller.gd --out /abs/result.json

const View = preload("res://view.gd")

var _view_spec: Dictionary = {}
var _view_body_pos: Vector2 = Vector2.ZERO

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	_view_spec = vs["spec"]
	if vs.get("body") != null:
		_view_body_pos = (vs["body"] as CharacterBody2D).position
	queue_redraw()

func _draw() -> void:
	if _view_spec.is_empty():
		return
	View.render(self, _level_root, _view_spec, {"body_pos": _view_body_pos})
