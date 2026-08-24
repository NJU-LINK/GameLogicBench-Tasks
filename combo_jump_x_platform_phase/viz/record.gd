extends "res://judge.gd"
#
# RECORD driver — renders the AUTHORITATIVE judge simulation to video. Thin shell over judge.gd:
# flips _record_mode, implements _on_frame to paint each settled frame via game/view.gd, defers all
# simulation/assertion logic to the parent.
#
# Run (windowed, under Xvfb + software GL):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N --press <axis[,axis]> --controller res://logic/controller.gd --out /abs/result.json

const View = preload("res://view.gd")

var _view_spec: Dictionary = {}
var _view_body_pos: Vector2 = Vector2.ZERO
var _view_platform: AnimatableBody2D = null

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	_view_spec = vs["spec"]
	if vs.get("body") != null:
		_view_body_pos = (vs["body"] as CharacterBody2D).position
	if vs.get("platform") != null:
		_view_platform = vs["platform"] as AnimatableBody2D
	queue_redraw()

func _draw() -> void:
	if _view_spec.is_empty():
		return
	View.render(self, _level_root, _view_platform, _view_spec, {"body_pos": _view_body_pos})
