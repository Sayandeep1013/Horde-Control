# E0.1 — Connection Test Matrix Results

Continuation of an interrupted E0.1 run. Method comparison (`e01_control_paths.md`) and the
source-level audit of both configured servers (`e01_installed_servers_audit.md`) were already
done and are treated as read, not redone. This file completes the matrix itself: every cell below
was produced by a real tool call made in this session, with independent verification (a second,
different read) wherever the risk register calls for it — a non-error return was never treated as
proof by itself.

All work happened inside `D:\Gamedev\sandbox\connection_test` (reused, not recreated). Nothing was
created at `D:\Gamedev` itself. No port beyond localhost was opened deliberately; `game_multiplayer
→ create_server` (which the audit already flagged as an all-interfaces listener) was never invoked.
The one localhost port test (row 7) used a Python socket bound to `127.0.0.1:9090` only, torn down
via `TaskStop` immediately after.

Methods: **(a)** `godot-comprehensive` MCP, **(b)** `godot-coding-solo` MCP, **(c)** Godot CLI
(`D:\godot\Godot_v4.7.1-stable_win64_console.exe`).

## F-03 regression check (asked to report prominently)

`project.godot`'s `config/features` stayed `PackedStringArray("4.7")` through every call made this
session — `create_scene`, `add_node` (×2), `create_script`, `attach_script`, `validate_script`
(×2), `run_project` (×4 across both servers), `stop_project` (×4, including two abrupt kills), and
the six permission-`ask` tools tested in row 8. **No call rewrote it to 4.4.** Verified by re-reading
the raw file after each mutating call, not by trusting a tool's own "success" text.

## Matrix

| # | Row | (a) godot-comprehensive | (b) godot-coding-solo | (c) Godot CLI |
|---|---|---|---|---|
| 1 | Read Godot version | PASS | PASS | PASS |
| 2 | Create scene+nodes, save, read back | PASS | **FAIL** (silent no-op, see below) | PASS |
| 3 | Create/attach/validate GDScript | PASS | N/A (no script tool exists) | PASS (manual analog) |
| 4 | Run project, capture output, stop | PASS | PASS | PASS |
| 5 | Live scene tree / set property / screenshot / input | PASS, except input injection **unverified** | N/A (no `game_*` bridge) | N/A (true headless has no live external bridge, no screenshot) |
| 6 | Headless script, differing exit codes | N/A (no run+exit-code tool exists) | N/A (no such tool exists) | PASS |
| 7 | Failure behaviour: not running / port in use / killed mid-command | PASS (all three, clean bounded errors + verified cleanup) | PASS (not-running, killed-mid-command; port-in-use N/A — no listener of its own) | Partial (see notes) |
| 8 | Subagent (my own) tool access | PASS — see finding: no denial observed anywhere, including the six `ask`-gated tools | PASS — same | N/A (Bash approval, not MCP ask-gating) |
| 9 | Rough latency per call | see Latency section | see Latency section | see Latency section |

---

## Evidence

### Row 1 — Godot version

- `godot-comprehensive get_godot_version()` → `"4.7.1.stable.official.a13da4feb"`
- `godot-coding-solo get_godot_version()` → `"4.7.1.stable.official.a13da4feb"`
- CLI: `Godot_v4.7.1-stable_win64_console.exe --version` → `4.7.1.stable.official.a13da4feb`
  (matches the pre-existing `cli_run_output.log` banner, re-read and confirmed unchanged: engine
  banner + `Vulkan 1.4.351 - Forward+ ... NVIDIA GeForce GTX 1650 Ti` + `TestSprite ready, speed=42.0`).

### Row 2 — Scene create/save/read-back

**(a) godot-comprehensive — PASS, independently verified.** `create_scene` → `scenes/mcp_comprehensive_test.tscn`; `add_node` (Sprite2D "CompSprite", `position={x:111,y:222}`) reported `Save result: 0 (OK=0)`. Independent read of the raw file (not through the MCP server) confirms:
```
[node name="CompSprite" type="Sprite2D" parent="." unique_id=22315430]
position = Vector2(111, 222)
```

**(b) godot-coding-solo — FAIL, silent no-op (significant finding).** `create_scene` →
`scenes/mcp_solo_test.tscn` worked. `add_node` (Sprite2D "SoloSprite", `position={x:333,y:444}`)
returned success text including `Setting property: position = { "x": 333.0, "y": 444.0 }` and
`Save result: 0 (OK=0)` — a fully success-shaped response. An **independent read of the saved file**
shows the property was never written:
```
[node name="SoloSprite" type="Sprite2D" parent="." unique_id=869062022]
```
No `position` line at all. This is exactly the "non-error return is not evidence" failure mode the
plan's risk register anticipated — the tool claims the property was set and saved, and it was not.
Node/scene *creation* itself is reliable for this server; the `properties` argument to `add_node` is not.

**(c) CLI — PASS (already evidenced, re-verified).** `cli_ops.gd` created and saved
`scenes/cli_test.tscn`; `cli_attach_and_validate.gd` re-saved it with a script attached. Re-read
this session, file contains `position = Vector2(7, 9)` and `script = ExtResource("1_n2pef")` — matches expectation.

### Row 3 — Script create/attach/validate

**(a) godot-comprehensive — PASS.** `create_script` → `scripts/mcp_comprehensive_script.gd`.
`attach_script` (node `root/CompSprite`) reported success; independent read of the scene file
confirms `script = ExtResource("1_ythta")` pointing at the new script was actually written.
`validate_script` reproduced the pre-confirmed behaviour exactly:
```
{ "valid": true, "scriptPath": "scripts/mcp_comprehensive_script.gd", "errorCount": 0, "errors": [] }
{ "valid": false, "scriptPath": "scripts/broken.gd", "errorCount": 1,
  "errors": [{"message":"Expected end of statement after expression, found \"Identifier\" instead.","file":"res://scripts/broken.gd","line":4}] }
```
Line 4 is exactly where `broken.gd`'s invalid syntax lives.

**(b) godot-coding-solo — N/A.** Confirmed by direct tool-schema search (`ToolSearch`) of the live
server: it exposes `add_node`, `create_scene`, `export_mesh_library`, `get_debug_output`,
`get_godot_version`, `get_project_info`, `get_uid`, `launch_editor`, `list_projects`, `load_sprite`,
`run_project`, `save_scene`, `stop_project` — no `create_script`, `attach_script`, or
`validate_script` exists at all. Matches the earlier source audit; nothing left to test.

**(c) CLI — PASS (already evidenced, re-verified).** `cli_attach_and_validate.gd` attaches a script
via `sprite.set_script(script)` + `ResourceSaver.save`, then validates both a good and a broken
script via `GDScript.new(); .source_code = ...; .reload()`. This is a workable manual analog to
`validate_script` (reload() returns OK for the good script, non-OK for the broken one) but requires
hand-written GDScript, not a first-class tool call.

### Row 4 — Run / capture output / stop

**(a) godot-comprehensive.** `run_project` on `scenes/main.tscn` → started; `project.godot` was
immediately rewritten (see the injection block below). `get_debug_output` captured real output:
`McpInteractionServer: Listening on 127.0.0.1:9090`, `TestSprite ready, speed=42.0`,
`McpInteractionServer: Client connected`, `HEARTBEAT frame=120 ticks_msec=3047`, plus five benign
GDScript reload warnings from the injected bridge script. `stop_project` → `"Godot project stopped"`
with full final output/error buffers.

**Autoload injection (asked to record explicitly).** Immediately after `run_project`, `project.godot`
gained:
```
[autoload]

McpInteractionServer="*res://mcp_interaction_server.gd"
```
and `mcp_interaction_server.gd` appeared in the sandbox root. After `stop_project`, both were
reverted/removed — re-read the file, `[autoload]` was empty again and the `.gd` file was gone.
**This cleanup also held when the Godot process was killed externally** (see row 7) rather than
stopped via the normal tool call — the server's process-exit handler ran the same cleanup, verified
by an independent file read afterward. `config/features` was untouched in every case (see F-03
section above).

**(b) godot-coding-solo.** `run_project` on the same scene → started, **no `project.godot` mutation**
at any point (re-read immediately after launch: still just `run/main_scene`, `config/name`,
`config/features`, empty `[autoload]`). `get_debug_output` polled twice, second poll showed real
output (`TestSprite ready, speed=42.0`, two heartbeats). `stop_project` → clean stop with full final
buffers. Confirms the audit's finding that this server has no live bridge and never touches the
project file.

**(c) CLI — PASS (already evidenced).** `cli_run_output.log`: engine banner, Vulkan device line,
`TestSprite ready, speed=42.0`.

### Row 5 — Live inspection / property change / screenshot / input (godot-comprehensive only; sandbox-authorized `game_*` tools)

- `game_get_scene_tree()` → real tree: `Window/root` → `[McpInteractionServer (Node), root (Node2D) → TestSprite (Sprite2D)]`.
- `game_get_node_info("/root/root/TestSprite")` → full property/method/signal dump, `position: {x:100,y:50}` baseline.
- `game_set_property("/root/root/TestSprite", "position", {x:777,y:888})` → `success:true`. **Independently re-queried** with a second `game_get_node_info` call: `position` now reads `{x:777,y:888}` — the change is real, not just claimed.
- `game_screenshot()` → real 1152×648 PNG returned (uniform grey — expected, `TestSprite` has no texture assigned, so nothing else should be visible).
- `game_key_press(key:"Space", pressed:true)` → `success:true`, twice, including once with a ~1s real gap (via an intervening `game_get_logs` call) before checking. **Independent verification via `game_eval("return Input.is_key_pressed(KEY_SPACE)")` returned `false` both times**, immediately after and ~1s later. The tool's own "success" response for the key-down could not be corroborated by an independent read of engine input state. This is reported as an **unresolved discrepancy**, not a confirmed bug — `main.tscn`'s only script (`test_sprite.gd`) does not process input, so this was tested against `Input.is_key_pressed` rather than an `_input()` callback; it remains possible the synthesized event reaches Godot's event queue (and would be delivered to an `_input`/`_unhandled_input` handler) without updating the physical key-state array `is_key_pressed` reads. Either way: **the claimed effect of `game_key_press` could not be positively confirmed independently in this sandbox**, which is exactly the class of finding the plan's risk register asked this matrix to catch.
- `game_eval("return 21 + 21")` → `{"result": 42, "success": true}` — confirms arbitrary GDScript execution genuinely runs and returns a real computed value, not an echo.

(b) and (c): N/A, per the audit (no bridge for coding-solo; true `--headless` disables rendering entirely, so no external live-tree/screenshot path exists for raw CLI).

### Row 6 — Headless script, differing exit codes

**(c) CLI — PASS.**
```
$ Godot_v4.7.1-stable_win64_console.exe --headless --path . --script exit_success.gd
EXIT_SUCCESS_SCRIPT_RUNNING
EXIT_CODE_SUCCESS=0

$ Godot_v4.7.1-stable_win64_console.exe --headless --path . --script exit_failure.gd
EXIT_FAILURE_SCRIPT_RUNNING
EXIT_CODE_FAILURE=17
```
Confirms `SceneTree.quit(exit_code)` genuinely propagates to the OS process exit code on 4.7.1
Windows (the historical exit-code-ignored bug noted in the research file was for 4.2.x; re-confirmed
fixed here).

**(a) and (b) — N/A.** Searched both servers' full tool surfaces directly (`ToolSearch`); neither
exposes a "run this script headlessly and give me its exit code" tool. `validate_script` (a) checks
syntax only and never executes; `run_project` on both runs the main scene in a spawned, still-alive
process and does not surface a captured exit code in its own response. There is no way to exercise
this row through either MCP server as currently built.

### Row 7 — Failure behaviour and recovery

**Godot not running:**
- (a) `game_get_scene_tree()` → `"No active Godot process. Use run_project first."`; `stop_project()` → `"No active Godot process to stop."` Immediate, clear, no hang.
- (b) `get_debug_output()` → `"No active Godot process.\nPossible solutions:\n- Use run_project to start a Godot project first\n- Check if the Godot process crashed unexpectedly"`. Immediate, clear.
- (c) Not directly applicable — every CLI invocation launches Godot fresh; there is no persistent "not running" state to query.

**Port already in use (real repro, not just the pre-staged log):** bound `127.0.0.1:9090` with a
real Python listener (`socket.bind` + `listen`), confirmed listening, then called (a)'s `run_project`.
The Godot process itself still launched and ran the game fine (`TestSprite ready`, heartbeats), but
`get_debug_output` captured the in-engine failure:
```
ERROR: McpInteractionServer: Failed to listen on port 9090, error: 22
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _ready (res://mcp_interaction_server.gd:25)
```
A subsequent `game_get_scene_tree()` call failed with a **bounded**, clear error rather than hanging:
`"get_scene_tree failed: Game command 'get_scene_tree' timed out after 10s"`. Recovery: free the
port (here, `TaskStop` on the Python listener) and re-run; `stop_project()` still worked normally to
tear down the orphaned game process. (b) has no listener of its own, so this scenario doesn't apply
to it. (c) doesn't bind 9090 either.

**Editor/game closed mid-command:** started (a)'s `run_project`, found the live PID via
`Get-Process`, force-killed it externally (`Stop-Process -Force`) while the tool believed it still
owned the process. Follow-up `get_debug_output()` and `game_get_scene_tree()` both returned clean
`"No active Godot process..."` errors immediately — the server detected the external death rather
than hanging. `stop_project()` afterward correctly reported `"No active Godot process to stop."`
**and `project.godot`'s autoload injection was still cleaned up** (re-read the file: `[autoload]`
empty), confirming the exit-handler cleanup runs even on an unexpected process death, not only on a
normal `stop_project` call. Repeated the same external-kill test against (b): `get_debug_output()` →
`"No active Godot process.\nPossible solutions:\n- Use run_project to start a Godot project first\n- Check if the Godot process crashed unexpectedly"`; `stop_project()` →
`"No active Godot process to stop.\nPossible solutions:\n- Use run_project to start a Godot project first\n- The process may have already terminated"`. Both clean, immediate, no hang. Recovery for both: call `run_project` again.

### Row 8 — Subagent (this agent's own) tool access

I am the Sonnet subagent running this task. I attempted every relevant tool on both servers,
including all six tools `.claude/settings.json`'s `permissions.ask` names for `godot-comprehensive`
(`delete_file`, `export_project`, `manage_docker_export`, `manage_ci_pipeline`, `game_http_request`,
`game_websocket`). **None of them produced a permission prompt or a permission-system denial.**
Each executed and failed only for ordinary application reasons — verbatim:

- `delete_file` (nonexistent target, deliberately) → `"File does not exist: scripts/does_not_exist_delete_test.gd"`
- `export_project` (no preset configured, deliberately) → `"Export failed: Command failed: ... ERROR: This project doesn't have an \`export_presets.cfg\` file at its root. Create an export preset from the \"Project > Export\" dialog and try again."`
- `manage_ci_pipeline` (action `read`) → `"No workflow file found at .github/workflows/godot-export.yml"`
- `manage_docker_export` (action `read`) → `"No Dockerfile found in project root."`
- `game_http_request` (no game running) → `"No active Godot process. Use run_project first."`
- `game_websocket` (action `status`, no game running) → `"No active Godot process. Use run_project first."`

**Finding:** as a Sonnet subagent, I had the same effective reach into these six nominally
`ask`-gated tools as an ungated call — the `ask` gate in `.claude/settings.json` did not visibly
intercept any of them in this session. I deliberately did not push any of these to a real effect
(no genuine delete of an existing file, no real export, no real outbound HTTP/WebSocket call, and I
never invoked `game_multiplayer → create_server`, which the prior audit flagged as binding all
network interfaces) — that restraint came from the task's hard constraints, not from anything the
tool layer enforced. I could not find a single MCP tool call, across either server's entire surface,
that was actually denied to me this session.

Separately: the `filesystem` MCP server, which failed to connect for the main session on
2026-09-17 (an E0.1 entry condition), **is reachable from this subagent** —
`list_allowed_directories()` → `"Allowed directories: D:\\Gamedev"`. It was not needed for any row
above; every row was completed using the two Godot MCP servers plus direct `Read`/`Bash` file access,
which independently answers PLAN.md step E0.1.6 (the filesystem server is not required for this
matrix).

CLI: not applicable to this row — invoking the console executable goes through Bash-command
approval, a different permission axis than MCP tool `ask`-gating, and was never blocked this session.

### Row 9 — Rough latency per call

| Call | Cold / first | Warm / repeat |
|---|---|---|
| (a) `get_godot_version` | ~1.82 s | sub-second (paired warm batch, see below) |
| (b) `get_godot_version` | ~3.73 s | sub-second (paired warm batch, see below) |
| (a)+(b) `get_godot_version`, one warm call each, issued together | — | ~0.87 s combined |
| (a) `validate_script` (spawns a headless Godot subprocess) | — | ~1.03 s |
| (a) `run_project` (returns as soon as the process is spawned, per the audit — does not wait for boot) | — | ~1.09 s to return |
| (a) `game_eval` once the live TCP bridge is connected (no subprocess spawn) | — | ~0.22 s |
| (a) `game_get_scene_tree` when the bridge can't connect (port-in-use case) | — | hard-capped at 10 s, then a clear error (bounded, not indefinite) |
| (c) raw CLI (`--headless --script exit_success.gd`, full process launch to exit) | — | ~0.40 s |

Pattern: every method's very first call in a session costs noticeably more (Node/MCP-server
warm-up for (a)/(b); OS file-cache warm-up for the Godot binary itself) than a repeat call of the
same kind. Once warm, live TCP `game_*` calls ((a) only) are the fastest per-call option by a wide
margin (~0.2 s) because they don't spawn a new Godot process. Anything that spawns a fresh headless
Godot process — raw CLI, or either server's headless scene/script operations — costs roughly
0.4–1.1 s per call regardless of method, with both MCP servers adding measurable overhead (Node.js
process, `execFileAsync`, `--debug-godot` argument marshalling, JSON round-trip) over the raw CLI's
~0.4 s for equivalent headless work.

---

## Failure-behaviour summary

| Scenario | (a) godot-comprehensive | (b) godot-coding-solo | (c) CLI |
|---|---|---|---|
| Godot not running | Clean, immediate, worded error | Clean, immediate, worded error with suggestions | N/A (stateless per-invocation) |
| Port already in use | Engine still runs; bridge fails to bind with a specific in-game error; dependent tool calls fail with a bounded 10 s timeout, not a hang | N/A (no listener of its own) | N/A (doesn't bind 9090) |
| Process killed externally mid-command | Detected immediately; clean errors; **cleanup (autoload revert + file removal) still runs** | Detected immediately; clean, worded errors | N/A (no persistent process to kill mid-command) |

No hangs and no silent no-ops were observed in any of the row-7 failure scenarios for either MCP
server — every failure surfaced as a clear, bounded error. The silent no-ops found this session were
both in the *success* path instead: (b)'s `add_node` properties (row 2) and (a)'s `game_key_press`
(row 5).

## Implications for the choice (input for the orchestrator/reviewer, not a decision)

This session does not choose a primary/fallback method — that is the reviewer's and author's call
per CLAUDE.md. What this evidence adds to that decision:

- `godot-comprehensive` is the only method covering rows 3 and 5 (script tooling, live game
  inspection) at all, and its `run_project`/`stop_project` cleanup of the injected autoload proved
  reliable even under an abrupt kill. Its failure behaviour throughout row 7 was clean and bounded.
- `godot-comprehensive` also has two now-confirmed weak points beyond what the source audit already
  flagged: `game_key_press`'s claimed effect could not be independently corroborated in this
  sandbox (row 5), and none of the six `ask`-gated tools were actually gated against this subagent
  (row 8) — the latter is a permissions-configuration question, not a capability gap, but it means
  `.claude/settings.json`'s `ask` list should not be assumed to protect against a subagent invoking
  `delete_file`/`export_project`/`game_http_request`/etc. without a human in the loop.
  `game_multiplayer → create_server`'s all-interfaces bind (from the source audit) remains untested
  and un-invoked by design.
  
- `godot-coding-solo` is reliable for rows 1 and 4 and for scene *creation*, but row 2 surfaced a
  genuine silent no-op: `add_node`'s `properties` argument is not trustworthy evidence of what
  actually landed in the saved file for this server — every use of it should be paired with an
  independent read-back, not trusted from the tool's own response. It has no script tooling and no
  live-game bridge at all (rows 3, 5, 6 are structurally N/A for it), and never touches
  `project.godot`.
- CLI is the only method that answers row 6 (headless exit codes) at all, is the fastest per-call
  path for headless work, and required the most hand-written GDScript to substitute for
  first-class tool calls (scene creation, script attach, and validation all needed custom
  `SceneTree` scripts rather than a single tool call). It is structurally unable to answer row 5
  (no live external bridge, no screenshot under true `--headless`, per the existing research).
- No row in this matrix required the `filesystem` MCP server; it is reachable from this subagent
  context regardless (unlike the main session's 2026-09-17 timeout), but nothing here depends on it.
