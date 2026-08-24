extends "res://judge.gd"
#
# RECORD driver for repo_rts_engagement_chain -- renders the AUTHORITATIVE judge simulation to
# video.
#
# THIN SHELL over judge.gd (which it extends): scenario setup, the commander (spawn the armed
# attacker + enemy victims, drive the re-order / detour / teleport / intruder / flee through the
# game's own verbs), the attack-clock / commitment / pursuit assertions, the verdict and result
# writing are all inherited -- there is exactly ONE simulation, the judged one. The rendered
# picture is the game's own: the judge instantiates the real Match.tscn (3D PlainAndSimple map,
# the IsometricCamera3D, the Kenney tank/helicopter/turret/worker models with the projectile
# tracers), so nothing needs dressing -- a windowed run shows the real RTS world fighting through
# the engine under test. The only difference from a judged run is skipping the headless bootstrap
# re-exec (_record_mode) -- the record pipeline pre-imports the project and Movie Maker pins the
# frame pacing the bootstrap's --fixed-fps 60 otherwise provides. Engine.time_scale = 5 is
# inherited, so the video shows the same 5x-compressed motion the judged simulation runs.
#
# NOTE (record is a degraded, display-only channel -- TASK_AUTHORING P2.5): the mp4 must be
# produced and readable; cross-check MISMATCH is logged, not gated. This driver runs the judged
# simulation, so the picture is faithful to the verdict by construction.

func _init() -> void:
	_record_mode = true


func _on_frame(_vs: Dictionary) -> void:
	# The 3D world renders itself (real Match scene + camera + models). Nothing to draw here; the
	# hook exists so the judge's per-frame recording branch fires and Movie Maker captures each
	# frame.
	pass
