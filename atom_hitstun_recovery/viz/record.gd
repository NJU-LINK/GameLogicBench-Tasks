extends "res://judge.gd"
#
# RECORD driver for atom_hitstun_recovery — renders the AUTHORITATIVE judge drive-loop to video.
#
# A THIN SHELL over judge.gd (which it extends): the drive loop, scenario timeline, the reference
# recompute, the assertions and the result writing are all inherited — there is exactly ONE
# simulation, the judged one. This scene flips on _record_mode and implements _on_frame: each driven
# frame's state is drawn — the base picture through game/view.gd, plus the pause bands, the
# reference state and a FROZEN marker overlaid HERE (these are the hidden-scenario visuals, kept out
# of the agent-visible game/ tree). It still writes result.json + prints GEB_RESULT so the recording
# can be cross-checked against the official judge verdict.
#
# Run (windowed, under Xvfb + software GL, Movie Maker capturing one video frame per sim frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario baseline --seed N --controller res://logic/controller.gd --out /abs/result.json

const View = preload("res://view.gd")

var _vs: Dictionary = {}
var _last_apply := -1000
var _last_expire := -1000

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	_vs = vs
	if not vs["applied"].is_empty():
		_last_apply = int(vs["frame"])
	if not vs["expired"].is_empty():
		_last_expire = int(vs["frame"])
	queue_redraw()

func _draw() -> void:
	if _vs.is_empty():
		return
	var spec: Dictionary = _vs["spec"]
	var frame: int = int(_vs["frame"])
	var run_frames: int = int(_vs["run_frames"])

	# base picture painted with the MODULE's judged state
	View.render(self, spec, {
		"frame": frame, "run_frames": run_frames,
		"actionable": bool(_vs["mod_actionable"]), "remaining": float(_vs["mod_remaining"]),
		"last_apply_frame": _last_apply, "last_expire_frame": _last_expire,
	})

	var font := ThemeDB.fallback_font
	var x0 := 40.0
	var x1 := 600.0
	var ty := 360.0
	var span := x1 - x0

	# pause windows (gray bands) overlaid on the timeline
	for p in spec["pauses"]:
		var s := int(p["start"])
		var l := int(p["len"])
		var px := x0 + span * float(s) / float(run_frames)
		var pw := span * float(l) / float(run_frames)
		self.draw_rect(Rect2(px, ty - 16, pw, 32), Color(0.4, 0.5, 0.9, 0.35))

	# FROZEN marker while the game time is not advancing
	if bool(_vs["paused"]) and font != null:
		self.draw_string(font, Vector2(230, 120), "[ FROZEN ]",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.6, 0.75, 1.0))

	# reference (authoritative) state, small, for visual comparison against the module disc
	var ref_col := Color(0.35, 0.8, 0.45) if bool(_vs["auth_actionable"]) else Color(0.95, 0.6, 0.2)
	self.draw_circle(Vector2(540, 90), 16.0, ref_col)
	if font != null:
		self.draw_string(font, Vector2(468, 130), "reference",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.7, 0.78))
