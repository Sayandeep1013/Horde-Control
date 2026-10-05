extends GdUnitTestSuite

## D124 (review P0-3): the run seed is random per run, with an override for
## tests/harnesses (injected export, or a `--seed=N` user arg).

const PrototypeScene: PackedScene = preload("res://scenes/prototype.tscn")


func test_injected_seed_wins_over_args_and_randomness() -> void:
	assert_int(PrototypeIntegration.resolve_run_seed(4242, PackedStringArray(["--seed=9"]))).is_equal(4242)
	assert_int(PrototypeIntegration.resolve_run_seed(0, PackedStringArray())).is_equal(0)


func test_seed_user_arg_is_used_when_nothing_injected() -> void:
	assert_int(PrototypeIntegration.resolve_run_seed(PrototypeIntegration.RUN_SEED_UNSET, PackedStringArray(["--other", "--seed=777"]))).is_equal(777)


func test_bad_seed_arg_falls_back_to_random() -> void:
	var seed_value: int = PrototypeIntegration.resolve_run_seed(PrototypeIntegration.RUN_SEED_UNSET, PackedStringArray(["--seed=abc"]))
	assert_int(seed_value).is_greater_equal(0)


func test_unset_seed_is_random_not_the_old_constant() -> void:
	var seen: Dictionary = {}
	for i in 8:
		seen[PrototypeIntegration.resolve_run_seed(PrototypeIntegration.RUN_SEED_UNSET, PackedStringArray())] = true
	assert_bool(seen.has(20260920) and seen.size() == 1).append_failure_message("seed is still the fixed constant").is_false()
	assert_int(seen.size()).is_greater(1)


func test_assembled_scene_exposes_and_propagates_the_resolved_seed() -> void:
	var proto: Node = auto_free(PrototypeScene.instantiate())
	proto.run_seed = 31337
	add_child(proto)
	assert_int(proto.get_run_seed()).is_equal(31337)
	assert_int(proto.get_node("Main/WaveDirector").run_seed).is_equal(31337)
	assert_int(proto.get_node("DraftInstance").run_seed).is_equal(31337)


func test_assembled_scene_without_injection_resolves_a_non_negative_seed() -> void:
	var proto: Node = auto_free(PrototypeScene.instantiate())
	add_child(proto)
	assert_int(proto.get_run_seed()).is_greater_equal(0)
	assert_int(proto.get_node("Main/WaveDirector").run_seed).is_equal(proto.get_run_seed())
