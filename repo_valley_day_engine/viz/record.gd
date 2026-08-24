extends "res://judge.gd"
#
# RECORD driver for repo_valley_day_engine -- renders the AUTHORITATIVE judge simulation to video.
# THIN SHELL over judge.gd (extends it): world construction, the chore script, day driving and the
# contract verdicts are all inherited -- there is exactly ONE simulation, the judged one. Only the
# bootstrap re-exec is skipped (_record_mode); the record pipeline pre-imports the project and Movie
# Maker pins the frame pacing. Each day the judge calls _on_frame(); here we draw the hex world +
# ledger via view.gd. (record is a degraded, display-only channel -- TASK_AUTHORING P2.5.)

const ViewScript = preload("res://view.gd")
var _view: Node2D = null

func _init() -> void:
	_record_mode = true

func _ensure_view() -> void:
	if _view != null:
		return
	var cam := Camera2D.new()
	cam.position = Vector2(320, 260)
	add_child(cam)
	cam.make_current()
	_view = Node2D.new()
	_view.set_script(ViewScript)
	add_child(_view)

func _on_frame(vs: Dictionary) -> void:
	_ensure_view()
	_view.call("set_info", vs)
