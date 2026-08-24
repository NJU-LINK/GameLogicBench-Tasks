extends RefCounted
#
# NAIVE reference solution for combo_magnus_roll_3d -- the straightforward first pass, with the four
# mistakes that go with it. Every one of them is invisible on the previewed round (flat turf, a steady
# breeze, uniform short grass, one shot played at a ball standing still):
#
#   1. the air flow is read ONCE, on the frame the shot is played, and the whole flight is integrated
#      against that snapshot (the "work out the ball's arc when it is struck" habit);
#   2. the turf's resistance is read ONCE, at the first contact, and used for the whole roll-out;
#   3. once the ball is barely moving the last of its speed is DAMPED away a fraction at a time
#      ("it will settle by itself"), instead of comparing this frame's resistance impulse with the
#      ball's own momentum. On level turf the damping does bring it to a dead stop, so the round the
#      author previewed looks right;
#   4. a shot SETS the ball's velocity from the impulse instead of adding to it -- indistinguishable
#      from the right answer as long as the ball is standing still when it is struck.

const SLEEP_SPEED := 0.15            # (3) below this the ball is "basically stopped"
const SETTLE_DAMP := 0.1             # (3) and the leftover speed is bled off a tenth at a time

var _vel := Vector3.ZERO
var _spin := Vector3.ZERO
var _phase := "REST"
var _normal := Vector3.UP
var _wind := Vector3.ZERO            # (1) snapshot taken when the shot is played
var _resist := -1.0                  # (2) snapshot taken at the first contact


func on_tick(s: Dictionary) -> Dictionary:
	var dt := float(s["dt"])
	var r := float(s["radius"])

	if s["shot"] != null:
		# (4) a fresh shot, so start the ball's motion from the impulse
		_vel = (s["shot"]["impulse"] as Vector3) / float(s["mass"])
		_spin = s["shot"]["spin"] as Vector3
		_phase = "FLIGHT"
		_wind = s["wind"]            # (1) the air over the tee, kept for the whole flight

	if s["contact"] != null:
		var n: Vector3 = s["contact"]["normal"]
		_normal = n
		if _resist < 0.0:
			_resist = float(s["surface_resist"])     # (2) the turf we first came down on
		var vn := n * _vel.dot(n)
		var vt := _vel - vn
		if _phase == "FLIGHT":
			if absf(_vel.dot(n)) < float(s["roll_speed"]):
				_phase = "ROLL"
				_vel = vt
				_spin = n.cross(_vel) / r
			else:
				var v_contact := _vel + _spin.cross(-n * r)
				var v_contact_t := v_contact - n * v_contact.dot(n)
				_vel = vt - v_contact_t * float(s["spin_tan"]) - vn * float(s["restitution"])
				_spin *= float(s["spin_damp"])
		elif _phase == "ROLL":
			_vel = vt

	if _phase == "FLIGHT":
		var v_rel := _vel - _wind
		var f: Vector3 = float(s["k_magnus"]) * _spin.cross(v_rel)
		if v_rel.length() > 0.0:
			f += -float(s["k_drag"]) * v_rel.length() * v_rel
		_vel += ((s["gravity"] as Vector3) + f / float(s["mass"])) * dt
	elif _phase == "ROLL":
		var g: Vector3 = s["gravity"]
		_vel += (g - _normal * g.dot(_normal)) * dt
		_vel -= _normal * _vel.dot(_normal)
		# (3) it is barely moving, damp the rest of the speed away
		if _vel.length() < SLEEP_SPEED:
			_vel *= SETTLE_DAMP
		else:
			var res := _resist if _resist > 0.0 else float(s["surface_resist"])
			_vel -= _vel.normalized() * (res / float(s["mass"])) * dt
		_spin = _normal.cross(_vel) / r

	return {"velocity": _vel, "spin": _spin}
