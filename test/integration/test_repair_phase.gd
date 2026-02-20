extends GutTest

var _gm: GameManager

func before_each():
_gm = GameManager.new()
add_child(_gm)

_gm.test_force_online = true
_gm.my_side_id = 1
var seed_val = 12345
_gm.setup_game(seed_val, "Surprise Attack!")
await get_tree().process_frame

func after_each():
if is_instance_valid(_gm):
_gm.queue_free()

func test_repair_phase_triggered_on_third_turn():
_gm.turn_count = 3
_gm.current_phase = _gm.Phase.END
_gm._end_round_cycle()

assert_eq(_gm.current_phase, _gm.Phase.REPAIR, "Phase should transition to REPAIR on turn 3.")
assert_eq(_gm.repair_subphase, 1, "Should start with Side 1 mapping DCR.")

func test_repair_phase_advances_turn_after_completion():
_gm.turn_count = 3
_gm.current_phase = _gm.Phase.REPAIR
_gm.repair_subphase = 3 # Simulation of _execute_all_repairs completion state.

var ship = _gm.ships[0]
ship.hull = ship.max_hull - 5
_gm.repair_allocations[ship.name] = {"hull": 100}

# Force execution
await _gm._execute_all_repairs()

assert_eq(_gm.turn_count, 4, "Turn count should advance to 4 after repair.")
assert_eq(_gm.current_phase, _gm.Phase.MOVEMENT, "Phase should reset correctly to MOVEMENT after repairs.")

