extends "res://judge.gd"
#
# RECORD driver for combo_anim_events -- renders the judge's OBSERVED run (the delivered dispatcher
# driven against the real AnimationPlayer clock) to video. Thin shell over judge.gd: the whole
# timeline, scenario handling, comparison and result writing are inherited. It only flips on
# _record_mode and implements _on_frame, handing each frame's clock snapshot to game/view.gd so
# Movie Maker captures the animation timeline with the real preview visuals. It still writes the
# judge verdict + GEB_RESULT for the (informational) cross-check.
#
# Run (windowed, Xvfb + software GL, one video frame per step):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N [--press axis:tier] --controller res://logic/controller.gd \
#       --out /abs/result.json

const View = preload("res://view.gd")

var _view_spec: Dictionary = {}
var _view_vs: Dictionary = {}

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	_view_spec = vs["spec"]
	_view_vs = vs["snap"]
	queue_redraw()

func _draw() -> void:
	if _view_spec.is_empty():
		return
	View.render(self, _view_spec, _view_vs)
