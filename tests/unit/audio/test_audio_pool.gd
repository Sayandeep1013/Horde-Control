extends GdUnitTestSuite

## P1.6 - Audio priority check (MASTER_SDLC.md > Acceptance Test Matrix >
## Technical Tests; PLAN.md > P1.6 exit criterion: "Priority cue steals a
## voice and remains audible in 5 of 5 trials").
##
## Follows docs/20_Technical_Architecture.md > "Audio Mixing & Dynamic
## Ducking" > "Voice Limit". Headless has no audio device (see
## phases/PHASE_02_Technical_Foundations/evidence/p16_report.md > "What
## headless testing cannot verify"), so these tests exercise the pool's
## voice-allocation logic and bookkeeping - where docs/20's stealing rule
## actually lives - plus, for the "remains audible" half of the named
## check, the engine's own playback-state flag
## (`AudioStreamPlayer2D.is_playing()`), which the Dummy audio driver
## headless still tracks correctly with no output device attached. That
## flag proves the engine considers the stolen voice actively playing the
## new stream; it is not proof a human would hear correct audio (levels,
## bus routing, real mixing) - only hardware playback can prove that.

func _make_pool() -> AudioPool:
	var pool := AudioPool.new()
	add_child(pool)
	auto_free(pool)
	return pool


## A short, non-empty stream so is_playing() can be observed as true
## immediately after play(), without needing an audio device.
static func _make_silent_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var sample_count := int(22050 * 0.25)
	var data := PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		data[i] = 128
	stream.data = data
	return stream


func test_pool_has_32_voices_all_initially_free() -> void:
	var pool := _make_pool()
	assert_int(pool.get_voice_count()).is_equal(32)
	for i in range(32):
		assert_bool(pool.get_voice_in_use(i)).is_false()


func test_free_voices_are_used_before_anything_is_stolen() -> void:
	var pool := _make_pool()
	var used_indices := {}
	for i in range(32):
		var idx: int = pool.allocate_voice(0, false)
		assert_bool(used_indices.has(idx)).is_false()
		used_indices[idx] = true
	assert_int(used_indices.size()).is_equal(32)
	assert_int(pool.get_active_priority_count()).is_equal(0)


## Deliberately makes the lowest-priority voice neither the oldest nor the
## newest allocation, so a passing result cannot be explained by an
## "oldest wins" bug standing in for "lowest priority wins".
func test_general_steal_picks_lowest_priority_voice_first() -> void:
	var pool := _make_pool()
	var target_index := -1
	for i in range(32):
		var priority := 10 + i # ascending; all higher than the deliberate target
		if i == 17:
			priority = -5 # the one deliberately-lowest-priority voice
		var idx: int = pool.allocate_voice(priority, false)
		if i == 17:
			target_index = idx
	assert_int(target_index).is_not_equal(-1)

	var stolen_index: int = pool.allocate_voice(999, false)
	assert_int(stolen_index).is_equal(target_index)
	assert_int(pool.get_voice_priority(stolen_index)).is_equal(999)


func test_general_steal_tie_is_broken_by_oldest() -> void:
	var pool := _make_pool()
	var older_tied_index: int = pool.allocate_voice(1, false) # allocated first -> oldest
	for i in range(29):
		pool.allocate_voice(50, false) # clearly-higher-priority filler
	var newer_tied_index: int = pool.allocate_voice(1, false) # same priority, later
	pool.allocate_voice(50, false) # 32nd voice, pool now full

	var stolen_index: int = pool.allocate_voice(999, false)
	assert_int(stolen_index).is_equal(older_tied_index)
	assert_int(stolen_index).is_not_equal(newer_tied_index)


func test_priority_cap_never_exceeds_8() -> void:
	var pool := _make_pool()
	for i in range(20):
		pool.allocate_voice(i, true)
		assert_int(pool.get_active_priority_count()).is_less_equal(8)
	assert_int(pool.get_active_priority_count()).is_equal(8)


## Once the 8 priority slots are full, the 9th priority request must steal
## the OLDEST priority voice, never the lowest-priority one - even when a
## much-lower-priority priority voice exists among the other 7.
func test_priority_cap_steals_oldest_priority_voice_not_lowest_priority() -> void:
	var pool := _make_pool()
	var oldest_priority_index: int = pool.allocate_voice(100, true) # high priority, but oldest
	for i in range(7):
		pool.allocate_voice(1, true) # low priority, but newer - fills the remaining 7 slots
	assert_int(pool.get_active_priority_count()).is_equal(8)

	var stolen_index: int = pool.allocate_voice(50, true)
	assert_int(stolen_index).is_equal(oldest_priority_index)
	assert_int(pool.get_active_priority_count()).is_equal(8)


func test_released_voice_no_longer_counts_as_active_priority() -> void:
	var pool := _make_pool()
	var idx: int = pool.allocate_voice(10, true)
	assert_int(pool.get_active_priority_count()).is_equal(1)
	pool.release_voice(idx)
	assert_int(pool.get_active_priority_count()).is_equal(0)
	assert_bool(pool.get_voice_in_use(idx)).is_false()


## The named acceptance test: 5 independent trials, each one fills every
## voice with ordinary SFX first (guaranteeing the priority request below
## must steal), then confirms the priority cue both wins the correct voice
## and is left in the engine's actively-playing state.
func test_priority_cue_steals_voice_and_remains_audible_5_of_5() -> void:
	var stream := _make_silent_stream()
	for trial in range(5):
		var pool := _make_pool()
		for i in range(32):
			pool.play(stream, Vector2.ZERO, 0, false, "SFX")

		var priority_player := pool.play(stream, Vector2(trial, 0.0), 100, true, "SFX_Priority")

		assert_object(priority_player).is_not_null()
		assert_str(priority_player.bus).is_equal("SFX_Priority")
		assert_bool(priority_player.is_playing()).is_true()
		assert_int(pool.get_active_priority_count()).is_equal(1)
