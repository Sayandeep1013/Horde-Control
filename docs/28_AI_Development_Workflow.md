# 28 - AI Development Workflow

**Version:** 1.0.0  
**Status:** Working system document, raised from stub to 1.0.0 under task P0.5 (Phase 00). Stable status under MASTER_SDLC.md > Document Control additionally requires this document to be reviewed against the master with that review recorded in the master's own Change Log; that review has not happened, and this document does not claim stable status for itself.  
**Authority:** Binding for the Minimum Playable Prototype under the master's Provisional Defaults Policy. The master wins on intent; the master's Provisional Values Register wins on any numeric conflict.

Claude integration, MCP workflow, documentation workflow, coding workflow, automation pipeline, and AI collaboration standards.

**Owns:** the rule that documentation and implementation change in the same commit. Resolved below under "How the AI Collaborator Works Here" > "The same-commit rule."

---

## Godot Connection

Two Godot MCP servers are configured for this project, `godot-comprehensive` and `godot-coding-solo`, alongside direct use of the Godot 4.7.1 CLI. Task E0.1 (Phase 00) proved and chose among these methods in a throwaway sandbox at `sandbox/connection_test`, kept separate from the real project. This section records the connection test matrix, the chosen methods, and their known failure modes.

### Connection test matrix

Methods: **godot-comprehensive** (MCP), **godot-coding-solo** (MCP), **Godot CLI** (`D:\godot\Godot_v4.7.1-stable_win64_console.exe`). Results and evidence are taken from `scratchpad/e01_matrix_results.md`, produced by real tool calls in the sandbox, with independent read-back verification wherever a non-error return alone would not be evidence.

| # | Row | godot-comprehensive | godot-coding-solo | Godot CLI |
| --- | --- | --- | --- | --- |
| 1 | Read the Godot version | PASS - returned `4.7.1.stable.official.a13da4feb` | PASS - returned the same version string | PASS - `--version` matched the engine banner |
| 2 | Create a project, a scene, and nodes; save and read back | PASS - an independent re-read of the raw `.tscn` confirmed the written `position` | FAIL - success-shaped response (`Save result: 0 (OK=0)`) but the `position` property was silently never written to the saved file | PASS - CLI-authored scene, re-read confirmed the written `position` |
| 3 | Create, attach, and validate a GDScript | PASS - `attach_script` confirmed via `ExtResource` in the re-read scene file; `validate_script` correctly flagged a deliberately broken script at line 4 | N/A - no `create_script`/`attach_script`/`validate_script` tool exists in this server's tool surface, confirmed by a direct tool-schema search | PASS (manual analog) - `set_script` plus `ResourceSaver.save`, with `GDScript.reload()` substituting for a validate call; requires hand-written GDScript rather than a single tool call |
| 4 | Run the project, capture debug output, stop it | PASS - `get_debug_output` captured real output; `stop_project` cleaned up | PASS - run/poll/stop all clean; no `project.godot` mutation at any point | PASS - `cli_run_output.log` captured the engine banner and game output |
| 5 | Inspect the running scene tree, change a property live, take a screenshot, inject input | PASS, except: `game_key_press` reported success but a following `game_eval("return Input.is_key_pressed(KEY_SPACE)")` returned false both immediately and after a real ~1s gap; recorded as an unresolved discrepancy, not a confirmed bug, since the probe scene had no `_input` handler to cross-check against | N/A - no `game_*` bridge exists on this server | N/A - true `--headless` has no live external bridge and no screenshot path |
| 6 | Run a headless script and read its exit code | N/A - no tool on this server runs a script headlessly and surfaces a process exit code; searched its full tool surface directly | N/A - same; no such tool exists | PASS - `exit_success.gd` returned exit code 0, `exit_failure.gd` returned exit code 17 |
| 7 | Failure behaviour and recovery: not running, port in use, killed mid-command | PASS - all three scenarios produced clean, bounded errors; the injected autoload's cleanup still ran correctly even when the Godot process was force-killed externally | PASS for not-running and killed-mid-command, both clean and immediate with worded errors; port-in-use is N/A since this server opens no listener of its own | Partial - not-running is N/A (every CLI call is a fresh, stateless invocation); port-in-use is N/A (the CLI never binds 9090); killed-mid-command is N/A (no persistent process for the caller to lose track of) |
| 8 | Whether Sonnet and Opus subagents can call the same tools | PASS, with a finding: as the Sonnet subagent running the matrix, no denial was observed on any tool called, including the six tools then listed in `permissions.ask` (`delete_file`, `export_project`, `manage_docker_export`, `manage_ci_pipeline`, `game_http_request`, `game_websocket`) - each executed and failed only for ordinary application reasons | PASS - same result, no denial observed on any tool called | N/A - CLI invocation goes through Bash-command approval, a different permission axis from MCP tool `ask`-gating, and was never blocked this session |
| 9 | Rough latency per call | See note below: cold `get_godot_version` ~1.82s, warm sub-second; a live `game_eval` call once the TCP bridge is connected ~0.22s | See note below: cold `get_godot_version` ~3.73s, warm sub-second | See note below: a full headless launch-to-exit cycle ~0.40s, the fastest per-call option for one-shot headless work |

Latency detail (row 9): every method's first call in a session costs noticeably more than a warm repeat (Node/MCP-server warm-up for the two servers; OS file-cache warm-up for the Godot binary itself). Once warm, live `game_*` calls on `godot-comprehensive` are the fastest per-call option (~0.2s) because they do not spawn a new Godot process. Anything that spawns a fresh headless Godot process - raw CLI, or either server's headless scene/script operations - costs roughly 0.4-1.1s per call regardless of method, with both MCP servers adding measurable overhead (Node.js process, `execFileAsync`, argument marshalling, JSON round-trip) over the raw CLI's ~0.4s for equivalent headless work.

F-03 regression check, recorded prominently per the matrix report: `project.godot`'s `config/features` stayed `PackedStringArray("4.7")` through every call made during this matrix run - `create_scene`, `add_node` (twice), `create_script`, `attach_script`, `validate_script` (twice), `run_project` (four times across both servers), `stop_project` (four times, including two abrupt kills), and the six then-`ask`-gated tools in row 8. No call rewrote it to 4.4 during the matrix session; the earlier 4.4 write (F-03, see Known Limitations) came from the sandbox's original MCP-generated `project.godot`, not from any call made during this run.

### Chosen method

The connection method for this project is settled, not open for re-derivation by any agent reading this document:

- **PRIMARY for authoring**: `godot-comprehensive`'s non-runtime tools (scene and node creation, script creation and validation, project settings). It passed scene create/save/read-back and script create/attach/validate, both independently verified by reading the affected files back.
- **MANDATORY for anything needing a process exit code**: the Godot CLI directly (`Godot_v4.7.1-stable_win64_console.exe --headless`). Neither MCP server can run a headless script and return an exit code - confirmed against both servers' tool schemas, row 6 of the matrix. P0.7's gdUnit4 harness therefore must use the CLI.
- **SECONDARY, reduced trust**: `godot-coding-solo`. Its `add_node` reports success and logs `Save result: 0` while silently not writing the properties argument, verified by reading the saved `.tscn` back (row 2, finding F-07). Use it for version and run operations only; never trust its property writes.

### Known failure modes and workarounds

- **`add_node` property silence (godot-coding-solo, F-07)**: `add_node` returns a fully success-shaped response, including a logged property assignment and `Save result: 0 (OK=0)`, while the property is never written to the saved scene. Node and scene creation are reliable on this server; the `properties` argument is not. Workaround: pair any `godot-coding-solo` `add_node` call with an independent read-back of the saved file, or use `godot-comprehensive` for property-bearing node authoring.
- **`game_key_press` success not corroborated (godot-comprehensive, F-08)**: `game_key_press` reported `success:true` for a key-down, but an independent `game_eval("return Input.is_key_pressed(KEY_SPACE)")` returned false both immediately and after a real ~1s gap. Recorded as an unresolved discrepancy, not a confirmed bug, because the test scene's only script had no `_input`/`_unhandled_input` handler to cross-check against; it remains possible the synthesized event reached Godot's event queue without updating the physical key-state array `is_key_pressed` reads. Input injection is marked unverified in the matrix rather than passed, and this must be resolved before any later phase (scripted-bot input from Phase 03 onward) depends on it.
- **Port 9090 already in use (godot-comprehensive)**: a real listener bound to `127.0.0.1:9090` produced the in-engine error `Failed to listen on port 9090, error: 22` when `run_project` ran anyway; the game itself still launched and ran, but a dependent `game_*` call failed with a bounded 10-second timeout rather than hanging. Recovery: free the port and re-run; `stop_project` still tears down the orphaned game process normally.
- **Godot process killed externally mid-command (both servers)**: force-killing the live Godot process outside the tool layer was detected cleanly and immediately by both servers, each returning a clear "No active Godot process" style error rather than hanging. For `godot-comprehensive`, the injected autoload's cleanup (removing the `[autoload]` line and the `.gd` file from `project.godot`) still ran correctly under this abrupt kill, verified by an independent file read afterward.

### Sandbox-only rule

`godot-comprehensive`'s `run_project` and every `game_*` tool are used only against `sandbox/connection_test`, never the real project (author decision). `run_project` injects a GDScript autoload (`McpInteractionServer`) into `project.godot` on every call, not opt-in, and opens a `127.0.0.1:9090` listener exposing `game_eval`, which compiles and executes arbitrary GDScript at runtime - architecturally equivalent to code execution under the account running Godot, since GDScript's `FileAccess`/`OS` APIs are not confined to the project directory. Its authoring tools (scene, node, script, project-settings work) do not inject anything and stay available for the real project. Mitigating evidence: the autoload injection's cleanup ran correctly even when the Godot process was force-killed rather than stopped normally (see above), so the injection does not reliably persist past the session that created it.

---

## Pinned Tool Versions

- **godot-coding-solo**: commit `1209744fad78f3998f98c7394fd0f6ef50da5281`, which carries the RCE fix "prevent arbitrary GDScript instantiation via add_node/create_scene" (PR #99). This fix was never published to npm; npm's only published version, `0.1.1`, predates it (published 2026-02-03, six commits before the fix landed).
- **godot-comprehensive**: commit `fcbc29e03297900b9a1fcc6c7cbae116fe9d532a`.
- Both are cloned and **built locally** under `tools/mcp/` (gitignored) and run as `node <path>/build/index.js`, because `npx` on this machine cannot install commit-pinned git specs: it fails with `GitFetcher requires an Arborist constructor to pack a tarball` (npm 10.9.3), reproduced directly against both pinned specs (finding F-04). `Coding-Solo/godot-mcp` gitignores `build/` and ships `bin -> ./build/index.js` only inside the npm tarball, so a git install must compile `build/index.js` via the package's `prepare` script, which a broken `npx` git-fetch never reaches.

### Rebuild steps

Anyone rebuilding either server from scratch follows this order, confirming each step before moving on rather than assuming success:

1. `git clone` the server's repository into `tools/mcp/<name>/` (`godot-coding-solo` from `Coding-Solo/godot-mcp`; `godot-comprehensive` from `tugcantopaloglu/godot-mcp`).
2. `git checkout <pinned-sha>` - the exact commit named above for that server.
3. `npm install`, which runs the package's `prepare` script and compiles TypeScript into `build/`.
4. Confirm `build/index.js` exists on disk before trusting the build.
5. Verify with an MCP `initialize` probe **before changing any config**: pipe a real MCP `initialize` request into `node build/index.js` over stdio and confirm a valid `protocolVersion` response comes back. Do not edit the MCP config on the strength of a successful build alone; prove the built server actually speaks MCP first.
6. Only then point the MCP config (outside this repository, e.g. `.claude.json`) at `command: node` with the absolute path to that server's `build/index.js`, preserving `GODOT_PATH` and every other configured server entry, and back up the config file before editing it.
7. Restart Claude Code - the pin takes effect only on restart - then re-verify with a live `get_godot_version` call and, if possible, by inspecting the running process's command line to confirm it points at the local build rather than any cached `npx` install.

### CRITICAL note for rebuilders: `.gdignore`

`tools/` and `sandbox/` each need an empty `.gdignore` file, because Godot treats everything under the project root as a resource and will otherwise pack the MCP servers - including their GDScript - into the exported game. Finding F-05: the first Windows release export of an empty scene packed `res://tools/mcp/...` into the game, producing an 11,229,568 byte (11.2 MB) `.pck`; adding `.gdignore` to both directories and re-exporting reduced it to 22 KB, and a byte search of the resulting pack found no MCP server code. Both `.gdignore` files live inside gitignored directories, so they are **not** in the repository and must be recreated by hand alongside any server rebuild.

### Godot skill pack

`godot-prompter` 1.13.3 (MIT), git sha `ff3b514ffa08804b88d3d9d2465843734a4022d9`, project-scoped to this repository. Its session card misreported the project as targeting Godot 4.4, because it read the only `project.godot` on disk at the time - the sandbox file the MCP server had generated with `config/features=PackedStringArray("4.4")` (F-03's wider blast radius: a throwaway test artifact mis-instructing the whole toolchain on a project pinned to 4.7.1). CLAUDE.md now states the Godot 4.7.1 target explicitly, so no agent inherits that misreading from the plugin.

---

## Known Limitations

- **Subagents are not fully gated by `.claude/settings.json`'s `permissions.ask` list (F-06, partially fixed)**: a Sonnet subagent called all six tools originally listed under `permissions.ask` for `godot-comprehensive` - `delete_file`, `export_project`, `manage_docker_export`, `manage_ci_pipeline`, `game_http_request`, `game_websocket` - with no prompt and no denial, each failing only for ordinary application reasons (for example, no export preset configured). The author responded by moving the four tools no phase in current scope needs - `manage_docker_export`, `manage_ci_pipeline`, `game_http_request`, `game_websocket` - from `ask` to `deny` in `.claude/settings.json`; those four tools were confirmed to disappear from the session afterward. `delete_file` and `export_project` remain on `ask`, because later tasks need them, and per the same matrix evidence the `ask` gate does not visibly intercept a subagent call - so both stay reachable by a Sonnet subagent without a human prompt. This is stated plainly as a residual limitation, not as fixed: the sandbox-only rule for `godot-comprehensive`'s `run_project` and every `game_*` tool is enforced by instruction (CLAUDE.md and explicit constraints in delegation prompts), not by the tool layer, for these two remaining tools. The finding and its partial mitigation are recorded in the Phase 00 ledger as F-06; the `ask`-vs-`deny` split may be hardened further separately.
- **Generated project config cannot be trusted on version fields (F-03, fixed)**: an MCP-generated `project.godot` declared `config/features=PackedStringArray("4.4")` regardless of the running 4.7.1 engine. `project.godot` for the real project is authored by hand, not generated, and `tests/settings_check.gd` asserts the recorded `config/features` value rather than trusting the running engine alone. The 4.4 write did not reproduce during the later connection-test matrix run (config/features stayed 4.7 through roughly twenty mutating calls and two abrupt process kills, see the F-03 regression check above), so the exact trigger for the original write is not fully characterised.

---

## How the AI Collaborator Works Here

Sonnet subagents write documents and implementation; Opus runs critical agents and phase reviewers. At the review gate, both kinds of Opus reviewer receive `PLAN.md`, `LEDGER.md`, and the artifacts produced - they never see the implementer's reasoning, only what it produced and what the plan required.

### The same-commit rule

This document owns the rule that every commit changing a system's implementation also changes that system's document, per the Documentation Structure entry for document 28. Stated as an enforceable rule: no commit may change GDScript, scenes, resources, or project settings belonging to a system without also updating the document that owns that system in the same commit. This is checked at each phase's review gate (`phases/README.md`'s loop rule (c)), where the phase reviewer and the per-task critical agents compare the commit history against the documents each task's Owner-doc column names; a commit that changes implementation with no matching documentation change in the same commit is a finding against that phase, not a silent pass.

### The review cadence

Execution follows the five-step supervised review loop defined in `phases/README.md` ("Loop rules"): pre-implementation (read prior phases' logs and carry forward applicable lessons), implementation (execute the phase plan, logging every action), review gate (per-task critical agents and one phase reviewer, all Opus, scoring against real evidence), fix and repeat (gather findings into the phase ledger, fix, re-review until the phase's bar is met or three iterations fail it), and close (update lessons and status, fold documentation and register changes back into the master and its docs, add a Change Log row). This document does not restate the loop's detail; `phases/README.md` is authoritative for it.

### The Gate Approval rule

Per MASTER_SDLC.md > Document Control > Gate Approval: only the human designer writes a gate row into the master's Change Log naming the gate and the date. An AI collaborator may propose that row's text but must never write it into the Change Log itself. No agent - Sonnet or Opus, implementer or reviewer - may write that a gate is passed, satisfied, met, or ready; that determination belongs to the designer and, ahead of the designer's decision, to the reviewers scoring evidence against the plan. A gate row does not change the master document's version number.

### Spot-check delegated output

Subagent reports are not accepted at face value. Phase 00's own record demonstrates why: an orchestrator spot-check of P0.3's output (26 generated documentation stubs, not taken on the subagent's word) found that all 26 omitted the trailing two-space line break after `**Version:**` that the five pre-existing drafts carried, a defect the subagent's own success report had not surfaced (finding F-01, fixed with a scripted pass verified file-by-file afterward). The same discipline applies to acceptance checks: every check that can pass must first be proven able to fail, rather than trusted on a single successful run. `tests/settings_check.gd` was proven falsifiable twice before being trusted - breaking a collision layer name produced a named failure and exit code 1, and setting `config/features` back to 4.4 reproduced the F-03 failure message - with the file restored and re-verified passing after each. `validate_script` was proven the same way during the connection-test matrix: run against a deliberately broken script, it returned `{"valid": false, "errorCount": 1}` with the exact line of the injected syntax error, rather than being trusted only on its passing runs against correct scripts.
