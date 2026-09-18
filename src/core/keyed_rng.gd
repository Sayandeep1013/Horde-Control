class_name KeyedRng
extends RefCounted

## Keyed RNG helpers (MASTER_SDLC.md > Determinism where it matters; >
## Provisional Values Register > "Keyed RNG"). "Every system that rolls
## (drops, drafts, spawn positions, affixes) derives its
## RandomNumberGenerator seed by hashing the run seed with a fixed
## per-purpose key and, where relevant, a per-roll identifier, rather than
## sharing one stream" -- for example the k-th draft card hashes
## [run_seed, "draft", k]; a drop hashes [run_seed, "drop", spawn_serial];
## a spawn position hashes [run_seed, "spawn", spawn_serial].
##
## Deliberately does NOT use Godot's built-in hash() / String.hash(): this
## project needs a seed whose bit pattern is defined by this file, not by
## an unspecified engine-internal algorithm that could differ across a
## future engine bump, since a run's replay-ability depends on the SAME
## seed being derivable again later ("so a run can be replayed for the same
## rolls even though physics may drift"). FNV-1a, 32-bit, is hand-rolled
## below over a canonical joined string instead.
##
## No autoload: this is a stateless helper library (RefCounted, not Node),
## called as KeyedRng.rng_for([...]) from wherever a system needs a keyed
## roll. Every function here is a pure function of its arguments -- there
## is no shared, mutable stream two different callers could accidentally
## collide on.

const _FNV_OFFSET_BASIS_32: int = 0x811c9dc5
const _FNV_PRIME_32: int = 0x01000193
const _MASK_32: int = 0xFFFFFFFF

## Unit separator (0x1F): not an expected character in any run seed,
## purpose key, or roll id this project passes. Joining parts with it before
## hashing means [1, "23"] and [12, "3"] hash to different strings
## ("1\x1f23" vs "12\x1f3") instead of colliding on the naive concatenation
## "123" (tests/unit/keyed_rng_test.gd asserts this directly).
const _PART_SEPARATOR: String = ""


## Builds the deterministic 32-bit seed for one keyed roll. `parts` is the
## run seed followed by a fixed per-purpose key and, where relevant, a
## per-roll identifier -- e.g. [run_seed, "draft", k]. Every part is
## stringified with str() and joined with the separator above. Same parts,
## in the same order, always produce the same seed.
static func seed_for(parts: Array) -> int:
	var joined: String = ""
	for i in parts.size():
		if i > 0:
			joined += _PART_SEPARATOR
		joined += str(parts[i])
	return _fnv1a_32(joined)


## Returns a RandomNumberGenerator seeded deterministically from `parts`.
## Same parts -> same seed -> the identical roll sequence, every time, in
## one process or across N repetitions (Keyed RNG unit check, P1.1).
static func rng_for(parts: Array) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_for(parts)
	return rng


static func _fnv1a_32(text: String) -> int:
	var h: int = _FNV_OFFSET_BASIS_32
	var bytes: PackedByteArray = text.to_utf8_buffer()
	for b: int in bytes:
		h = (h ^ b) & _MASK_32
		h = (h * _FNV_PRIME_32) & _MASK_32
	return h
