# 24 - Save System

**Version:** 0.2.0
**Status:** Working draft, written 2026-09-23 for the prototype's meta layer (document 18; decisions D109-D113). Numbers are Provisional Defaults whose authority is the master's Provisional Values Register row "Meta: Save profile".

**Owns:** the profile file format, atomic writes, backups, migration, and when saves happen. The Meta Wallet's rules are document 14's; this document only stores them.

---

## 1. One profile, one file

- The path is `user://profile.json` (on Windows, `%APPDATA%/Godot/app_userdata/Horde Control/profile.json`). JSON, UTF-8, human-readable.
- The top level holds `schema_version` (int, currently 1), `cores` (int), `lifetime_cores`, `tree_ranks` ({node_id: rank}), `records` ({best_wave, best_time_s, best_kills, runs, victories}), `settled_run_ids` (the last 16, for idempotent settlement), `first_hub_seen` (bool), and `saved_at_unix`.
- Unknown keys are preserved on rewrite, for forward compatibility inside a version.

## 2. Atomic write

Every save goes through one function:

1. Serialise to a string.
2. Write it to `profile.json.tmp`, flush, and close. Check the write succeeded.
3. If `profile.json` exists, copy it to `profile.json.bak`.
4. Rename `profile.json.tmp` to `profile.json`, replacing it (`DirAccess.rename`, which replaces on Windows through Godot's implementation; if the rename fails, fall back to removing the target and renaming again).
5. Any failure leaves the in-memory state untouched, sets a `last_save_failed` flag the Hub shows as a warning, and is retried at the next save point.

A write interrupted at any step leaves either the old `profile.json` or the new one complete, never a half-file under that name.

## 3. Load

1. Read `profile.json` and parse it. If it parses and validates (types and ranges correct, `schema_version` known), use it.
2. Otherwise try `profile.json.bak`.
3. Otherwise copy the unreadable file to `profile.corrupt.json`, start a fresh profile, and set `recovered_from_corruption`. The Hub tells the player once.
4. After a successful load, run the migration chain (section 5), then reconcile the tree: clamp each rank to the node's current max rank, drop unknown node ids, refund the Cores spent on anything removed, and ensure the root is owned.

## 4. When saves happen

- Run-End Settlement: before the run-end screen shows.
- Every skill-tree purchase and every respec.
- Window close in the Hub or on the title (a no-op if nothing is dirty).
- Nothing saves during a run except settlement. The prototype has no in-run Core drops, so there is nothing to bank mid-run. When field Cores arrive (vertical slice), the Register's "atomic write at most every 2 s while dirty" rule applies.

## 5. Migration

`schema_version` starts at 1. Each future version adds one function `migrate_N_to_N_plus_1(dict) -> dict` to an ordered table, and load applies them in sequence. A profile from a newer version than the game understands is not overwritten: the game loads it read-only and warns the player.

## 6. Tests (Acceptance Test Matrix rows Save atomicity test, Meta persistence test)

- Round trip: save, load, compare.
- Kill mid-write: simulate a failure after step 2 and again after step 3. On the next load the last complete profile survives.
- Corrupt file: garbage in `profile.json` loads `.bak`; garbage in both starts fresh and keeps `profile.corrupt.json`.
- Settlement idempotence: settling the same run id twice pays once.
- Reconcile: a profile holding a rank above the node's max, or an unknown node, is corrected and refunded.

Tests use a throwaway directory, never the real `user://profile.json`.
