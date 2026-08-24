extends RefCounted
#
# NAIVE reference controller for atom_root_motion_3d (red-team best-effort).
# Passes BASELINE (a straight walk_fwd); FAILS every hidden scenario.
#
# It is a competent flat mover, but it treats the animation as cosmetic: it never reads the handed
# root-motion delta and never applies the animation's turn. It just drives the body forward at a
# hardcoded speed (tuned to the straight-walk clip) plus gravity. So the moment the game plays a clip
# that declares a DIFFERENT amount -- the slower turning clip, or the slow climb clip -- the body
# moves at the wrong rate (displacement_mismatch) and, without the animation's yaw, never follows the
# turn onto the offset goal (never_arrived). This is the "wrote movement, forgot it is animation-
# driven" incremental-engineering gap.

const FIXED_SPEED := 1.5

var _body: CharacterBody3D
var _dt := 1.0 / 60.0
var _gravity := 12.0

func setup(ctx: Dictionary) -> void:
	_body = ctx["body"]
	_dt = float(ctx.get("dt", _dt))
	_gravity = float(ctx.get("gravity", _gravity))

func tick(_state: Dictionary) -> void:
	var world_delta: Vector3 = _body.global_transform.basis * Vector3(FIXED_SPEED * _dt, 0, 0)
	var vel := world_delta / _dt
	if _body.is_on_floor():
		vel.y = 0.0
	else:
		vel.y = _body.velocity.y - _gravity * _dt
	_body.velocity = vel
	_body.move_and_slide()
