extends GdUnitTestSuite

## Damage Numbers setting gate (task brief: "gate ... static spawn()").
## `DamageNumberFx` is a static, process-lifetime pool shared across every
## suite in this headless run (see that file's own header, "Scene reload
## safety") -- `clear_for_test()` resets it before and after this file's own
## tests so neither direction leaks. `GameSettings` state is memory-only here
## (`_for_test` setters) -- nothing is saved to disk.

func before_test() -> void:
	GameSettings.reset_state_for_test()
	DamageNumberFx.clear_for_test()


func after_test() -> void:
	GameSettings.reset_state_for_test()
	DamageNumberFx.clear_for_test()


func _make_container() -> Node:
	var n: Node = Node.new()
	add_child(n)
	auto_free(n)
	return n


func test_damage_numbers_enabled_by_default_spawns_a_label() -> void:
	var container: Node = _make_container()
	DamageNumberFx.spawn(container, Vector2.ZERO, 5.0)
	assert_int(container.get_child_count()).append_failure_message("spawn() must add a pooled label under the container while Damage Numbers is enabled").is_greater(0)


func test_damage_numbers_disabled_spawns_nothing() -> void:
	GameSettings.set_damage_numbers_enabled_for_test(false)
	var container: Node = _make_container()
	DamageNumberFx.spawn(container, Vector2.ZERO, 5.0)
	assert_int(container.get_child_count()).append_failure_message("spawn() must be a no-op while Damage Numbers is disabled").is_equal(0)


## FALSIFICATION (named in the report): temporarily removed the `if not
## GameSettings.are_damage_numbers_enabled(): return` guard from `spawn()` --
## this test failed (a label was spawned regardless of the setting).
## Reverted after confirming the failure.
func test_re_enabling_after_a_disabled_call_still_spawns() -> void:
	GameSettings.set_damage_numbers_enabled_for_test(false)
	var container: Node = _make_container()
	DamageNumberFx.spawn(container, Vector2.ZERO, 5.0)
	assert_int(container.get_child_count()).is_equal(0)

	GameSettings.set_damage_numbers_enabled_for_test(true)
	DamageNumberFx.spawn(container, Vector2.ZERO, 5.0)
	assert_int(container.get_child_count()).is_greater(0)
