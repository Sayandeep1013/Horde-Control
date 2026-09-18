extends GdUnitTestSuite

## Registry query check (MASTER_SDLC.md > Acceptance Test Matrix > Technical
## Tests, P1.2): "A single EntityRegistry radius query over 300 entities
## completes in under 0.05 ms." (0.05 ms = 50 microseconds; every duration
## in this file is in whole microseconds via Time.get_ticks_usec(), which is
## wall-clock time -- correct for a PERFORMANCE measurement even though
## gameplay code itself must never read wall clock, see event_bus.gd.)
##
## METHOD (read this before reading the numbers): a single call is far below
## Time.get_ticks_usec()'s ~1us practical resolution and below OS scheduler
## noise, so one call proves nothing. Every test below runs WARMUP_ITERATIONS
## un-timed calls first (lets any one-time cost -- cold memory, first-call
## JIT-adjacent warmup the GDScript VM may do -- settle before anything is
## measured), then MEASURED_ITERATIONS timed calls, and reports mean, worst,
## p50, p99 and standard deviation over the full sample, not a single best
## or cherry-picked figure. The bound below is asserted against the MEAN,
## stated explicitly as a mean, not a worst case -- individual calls spike
## far above it (observed worst-case samples up to ~2ms once per several
## thousand calls, almost certainly OS scheduling jitter on a shared dev
## machine, not the algorithm), which is exactly why a single-call
## measurement would be meaningless in either direction.
##
## CLUSTERED VS UNIFORM (the honest, load-bearing result this file exists to
## report, per the P1.2 task brief: "a spatial structure that is fast on
## uniform data can degrade badly on clustered data, and 300 enemies
## converging on a Tower is the clustered case this game will actually
## produce"):
##   - test_uniform_distribution_meets_the_bound(): 300 entities scattered
##     uniformly across the real 4800x3200 arena (MASTER_SDLC.md >
##     Provisional Values Register > Arena & Camera > "Arena size"), queried
##     at the Tower's own targeting range (480 px, MASTER_SDLC.md > Tower
##     Targeting Rule). Meets the 0.05 ms bound with a comfortable margin --
##     see the measured figures in the test body and the P1.2 evidence
##     report.
##   - test_clustered_distribution_does_not_meet_the_bound(): 300 entities
##     clustered within 250 px of the Tower -- the Swarm Crush / Siege
##     convergence case, at the entity cap (docs/20 > Provisional Values
##     Register: enemy cap 300) -- queried at the same 480 px range, so
##     nearly the entire cap is a true positive. This is NOT asserted
##     against the 0.05 ms bound: it does not meet it, and neither does a
##     brute-force baseline with no spatial index at all, measured
##     separately during development (see the P1.2 evidence report,
##     "Timing method," for both numbers). Returning ~300 live Node2D
##     references through an interpreted GDScript loop costs what it costs;
##     no data structure choice made the true-positive-heavy case free. This
##     test instead asserts (a) the result set is still exactly correct
##     under clustering, and (b) a far looser sanity ceiling that would
##     still catch a genuine regression (an accidental O(n^2), an infinite
##     loop, a broken grid). The 0.05 ms gap on this specific worst case is
##     recorded as an open finding for the author/reviewers, not resolved
##     here and not hidden -- see the P1.2 evidence report,
##     "Contradictions and ambiguities."
##
## WRONG-SET GUARD (P1.2 task brief: "confirm the check would catch a query
## that returns the wrong set rather than merely being slow -- a fast query
## returning nothing would pass a pure timing test"): every test below
## computes its OWN expected result independently (a plain loop over the
## Node2D references this test created and their known positions, with no
## call into the registry's internals) and asserts SET equality against the
## registry's actual result BEFORE any timing loop runs. A query that
## returns everything, returns nothing, or returns the wrong entities would
## fail this assertion regardless of how fast or slow it ran.

const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")

const ENTITY_COUNT: int = 300
const WARMUP_ITERATIONS: int = 300
const MEASURED_ITERATIONS: int = 5000
const BOUND_USEC: float = 50.0 # 0.05 ms, MASTER_SDLC.md > Registry query check

# Real arena and Tower-range numbers (not invented for this test) --
# MASTER_SDLC.md > Provisional Values Register > Arena & Camera > "Arena
# size": "4800 x 3200 px ... Tower at centre"; > Tower Targeting Rule:
# "Provisional Default range: three times the Interaction Radius (480
# pixels in the prototype arena)".
const ARENA_HALF_WIDTH: float = 2400.0
const ARENA_HALF_HEIGHT: float = 1600.0
const QUERY_RADIUS: float = 480.0
const TOWER_ORIGIN: Vector2 = Vector2.ZERO

# Swarm Crush / Siege convergence radius: comfortably inside QUERY_RADIUS so
# nearly the full entity cap is a true positive for the query below.
const CLUSTER_RADIUS: float = 250.0

# A far looser sanity ceiling for the clustered case (see header comment):
# not the acceptance bound, just large enough that a genuine algorithmic
# regression (e.g. an accidental O(n^2)) would still be caught.
const CLUSTERED_SANITY_CEILING_USEC: float = 1000.0

const SEED: int = 918273645

var _registry: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	add_child(_registry)


func _spawn_uniform(rng: RandomNumberGenerator) -> Node2D:
	var n: Node2D = auto_free(Node2D.new()) as Node2D
	n.global_position = Vector2(
		rng.randf_range(-ARENA_HALF_WIDTH, ARENA_HALF_WIDTH),
		rng.randf_range(-ARENA_HALF_HEIGHT, ARENA_HALF_HEIGHT)
	)
	return n


func _spawn_clustered(rng: RandomNumberGenerator) -> Node2D:
	var n: Node2D = auto_free(Node2D.new()) as Node2D
	var angle: float = rng.randf_range(0.0, TAU)
	var dist: float = rng.randf_range(0.0, CLUSTER_RADIUS)
	n.global_position = Vector2(cos(angle), sin(angle)) * dist
	return n


## Independent reference computation -- no call into the registry -- for the
## wrong-set guard described in the header comment.
func _expected_set(nodes: Array[Node2D], origin: Vector2, radius: float) -> Dictionary:
	var expected: Dictionary = {} # Node2D -> true
	var r2: float = radius * radius
	for n in nodes:
		if origin.distance_squared_to(n.global_position) <= r2:
			expected[n] = true
	return expected


func _assert_matches_expected_set(actual: Array[Node2D], nodes: Array[Node2D], origin: Vector2, radius: float, label: String) -> void:
	var expected: Dictionary = _expected_set(nodes, origin, radius)
	assert_int(actual.size()).append_failure_message(
		"%s: registry returned %d entities, an independent brute-force reference over the same %d spawned nodes expects %d" % [label, actual.size(), nodes.size(), expected.size()]
	).is_equal(expected.size())
	for e in actual:
		assert_bool(expected.has(e)).append_failure_message(
			"%s: registry returned an entity the reference computation says is NOT within radius %.1f of %s" % [label, radius, str(origin)]
		).is_true()


func _measure(origin: Vector2, radius: float) -> Dictionary:
	for i in WARMUP_ITERATIONS:
		_registry.get_enemies_in_radius(origin, radius)

	var samples: PackedFloat64Array = PackedFloat64Array()
	samples.resize(MEASURED_ITERATIONS)
	for i in MEASURED_ITERATIONS:
		var start_usec: int = Time.get_ticks_usec()
		var _result: Array[Node2D] = _registry.get_enemies_in_radius(origin, radius)
		samples[i] = float(Time.get_ticks_usec() - start_usec)

	var total: float = 0.0
	var worst: float = 0.0
	var best: float = INF
	for s in samples:
		total += s
		worst = maxf(worst, s)
		best = minf(best, s)
	var mean: float = total / samples.size()

	var variance_sum: float = 0.0
	for s in samples:
		variance_sum += (s - mean) * (s - mean)
	var stddev: float = sqrt(variance_sum / samples.size())

	var sorted_samples: PackedFloat64Array = samples.duplicate()
	sorted_samples.sort()
	var p50: float = sorted_samples[int(sorted_samples.size() * 0.50)]
	var p99: float = sorted_samples[int(sorted_samples.size() * 0.99)]

	return {
		"mean": mean, "worst": worst, "best": best, "stddev": stddev,
		"p50": p50, "p99": p99, "iterations": samples.size(), "warmup": WARMUP_ITERATIONS,
	}


func _format_stats(label: String, stats: Dictionary) -> String:
	return "%s: mean=%.2fus worst=%.2fus best=%.2fus stddev=%.2fus p50=%.2fus p99=%.2fus (n=%d, warmup=%d)" % [
		label, stats["mean"], stats["worst"], stats["best"], stats["stddev"], stats["p50"], stats["p99"], stats["iterations"], stats["warmup"],
	]


## THE Registry query check. 300 entities scattered across the real arena;
## query at the Tower's own targeting range. Asserted against the 0.05 ms
## bound on the MEAN over MEASURED_ITERATIONS calls, after WARMUP_ITERATIONS
## un-timed calls -- see header comment "METHOD".
func test_uniform_distribution_meets_the_bound() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var nodes: Array[Node2D] = []
	for i in ENTITY_COUNT:
		var n: Node2D = _spawn_uniform(rng)
		nodes.append(n)
		assert_bool(_registry.register_entity(n, n.global_position, [&"enemy"])).is_true()

	var actual: Array[Node2D] = _registry.get_enemies_in_radius(TOWER_ORIGIN, QUERY_RADIUS)
	_assert_matches_expected_set(actual, nodes, TOWER_ORIGIN, QUERY_RADIUS, "uniform")

	var stats: Dictionary = _measure(TOWER_ORIGIN, QUERY_RADIUS)
	print("Registry query check (uniform): ", _format_stats("uniform", stats))
	assert_float(stats["mean"]).append_failure_message(
		_format_stats("uniform", stats) + " -- mean exceeds the 0.05 ms (50us) bound"
	).is_less(BOUND_USEC)


## Clustered / Swarm Crush case: NOT asserted against the 0.05 ms bound (see
## header comment "CLUSTERED VS UNIFORM"). Still a real, falsifiable test:
## the result set must still be exactly correct, and total time must stay
## under a far looser sanity ceiling that a genuine regression would still
## trip.
func test_clustered_distribution_does_not_meet_the_bound() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var nodes: Array[Node2D] = []
	for i in ENTITY_COUNT:
		var n: Node2D = _spawn_clustered(rng)
		nodes.append(n)
		assert_bool(_registry.register_entity(n, n.global_position, [&"enemy"])).is_true()

	var actual: Array[Node2D] = _registry.get_enemies_in_radius(TOWER_ORIGIN, QUERY_RADIUS)
	_assert_matches_expected_set(actual, nodes, TOWER_ORIGIN, QUERY_RADIUS, "clustered")

	var stats: Dictionary = _measure(TOWER_ORIGIN, QUERY_RADIUS)
	print("Registry query check (clustered, informational only): ", _format_stats("clustered", stats))
	if stats["mean"] < BOUND_USEC:
		print("NOTE: clustered mean unexpectedly met the 0.05 ms bound on this run -- update the P1.2 evidence report if this reproduces")
	assert_float(stats["mean"]).append_failure_message(
		_format_stats("clustered", stats) + " -- exceeds even the informational sanity ceiling, not just the acceptance bound"
	).is_less(CLUSTERED_SANITY_CEILING_USEC)


## Wrong-set guard, isolated from the 300-entity timing tests above: a small,
## hand-checkable scenario so a broken radius filter (returns everything) or
## a broken tag filter (returns nothing, or the wrong tag's entities) is
## caught by inspection as much as by assertion. Deliberately does not touch
## timing at all -- "a fast query returning nothing would pass a pure timing
## test" is exactly the failure mode this test exists to catch instead.
func test_wrong_set_guard_small_hand_checkable_scenario() -> void:
	var inside: Node2D = auto_free(Node2D.new()) as Node2D
	inside.global_position = Vector2(30, 0)
	var outside: Node2D = auto_free(Node2D.new()) as Node2D
	outside.global_position = Vector2(500, 0)
	var wrong_tag: Node2D = auto_free(Node2D.new()) as Node2D
	wrong_tag.global_position = Vector2(10, 0)

	_registry.register_entity(inside, inside.global_position, [&"enemy"])
	_registry.register_entity(outside, outside.global_position, [&"enemy"])
	_registry.register_entity(wrong_tag, wrong_tag.global_position, [&"pickup"])

	var result: Array[Node2D] = _registry.get_enemies_in_radius(Vector2.ZERO, 100.0)
	assert_int(result.size()).append_failure_message(
		"expected exactly 1 entity (inside radius, tagged enemy); got %d: %s" % [result.size(), str(result)]
	).is_equal(1)
	assert_bool(result.has(inside)).is_true()
	assert_bool(result.has(outside)).is_false() # radius filter must exclude this
	assert_bool(result.has(wrong_tag)).is_false() # tag filter must exclude this
