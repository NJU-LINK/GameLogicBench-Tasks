extends "res://judge.gd"
#
# RECORD driver for combo_platform_guard — renders the AUTHORITATIVE judge simulation to video.
#
# Thin shell over judge.gd: flips _record_mode, implements _on_frame to paint each settled
# frame via game/view.gd, and defers all simulation/assertion logic to the parent.
#
# Run (windowed, under Xvfb + software GL):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N --press <axis> --controller res://logic/controller.gd \
#       --out /abs/result.json

const View = preload("res://view.gd")

var _view_spec: Dictionary = {}
var _view_body_pos: Vector2 = Vector2.ZERO
var _view_chasing: int = -1
var _view_t: float = 0.0

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	_view_spec = vs["spec"]
	if vs.get("body") != null:
		_view_body_pos = (vs["body"] as CharacterBody2D).position
	_view_chasing = int(vs.get("chasing", -1))
	_view_t = float(vs.get("t", 0.0))
	queue_redraw()

func _draw() -> void:
	if _view_spec.is_empty():
		return
	View.render(self, _level_root, _view_spec, {
		"body_pos": _view_body_pos, "t": _view_t, "chasing": _view_chasing})
