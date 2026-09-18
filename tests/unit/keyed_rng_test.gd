extends GdUnitTestSuite

## Keyed RNG unit check (MASTER_SDLC.md > Acceptance Test Matrix > Technical
## Tests, P1.1; > Determinism where it matters for the hashing rule
## itself). "With the same run seed, keyed rolls ... reproduce identically
## in isolation across 10 of 10 repetitions." Also asserts that DIFFERENT
## keys diverge: the master's own test description warns that "a generator
## returning a constant would pass a same-key test" -- only the divergence
## assertions below would catch that degenerate implementation.

const REPETITIONS: int = 10
const ROLLS_PER_SEQUENCE: int = 25


func _roll_sequence(parts: Array) -> Array[float]:
	var rng: RandomNumberGenerator = KeyedRng.rng_for(parts)
	var out: Array[float] = []
	for i in ROLLS_PER_SEQUENCE:
		out.append(rng.randf())
	return out


func test_same_key_reproduces_identically_10_of_10() -> void:
	var parts: Array = [424242, "draft", 2]
	var reference: Array[float] = _roll_sequence(parts)
	for rep in REPETITIONS:
		var seq: Array[float] = _roll_sequence(parts)
		assert_array(seq).append_failure_message(
			"repetition %d of %d diverged from the reference sequence for the same key" % [rep + 1, REPETITIONS]
		).is_equal(reference)


func test_seed_is_deterministic_across_calls() -> void:
	var parts: Array = [1, "spawn", 42]
	var seed_a: int = KeyedRng.seed_for(parts)
	var seed_b: int = KeyedRng.seed_for(parts)
	assert_int(seed_b).is_equal(seed_a)


func test_different_run_seed_diverges() -> void:
	var seq_a: Array[float] = _roll_sequence([1, "draft", 3])
	var seq_b: Array[float] = _roll_sequence([2, "draft", 3])
	assert_array(seq_b).is_not_equal(seq_a)


func test_different_purpose_key_diverges() -> void:
	var seq_a: Array[float] = _roll_sequence([1, "draft", 3])
	var seq_b: Array[float] = _roll_sequence([1, "drop", 3])
	assert_array(seq_b).is_not_equal(seq_a)


func test_different_roll_id_diverges() -> void:
	var seq_a: Array[float] = _roll_sequence([1, "spawn", 7])
	var seq_b: Array[float] = _roll_sequence([1, "spawn", 8])
	assert_array(seq_b).is_not_equal(seq_a)


func test_part_boundary_does_not_collide() -> void:
	# [1, "23"] and [12, "3"] must not hash the same despite both naively
	# concatenating to "123" -- proves the separator byte in KeyedRng is
	# doing its job.
	var seq_a: Array[float] = _roll_sequence([1, "23"])
	var seq_b: Array[float] = _roll_sequence([12, "3"])
	assert_array(seq_b).is_not_equal(seq_a)
