# Source-level audit: `godot-coding-solo` and `godot-comprehensive` MCP servers

Read-only reconnaissance. Nothing under `D:\Gamedev` was modified, no server was run, no Godot command was executed. All code below was read directly from the local npx cache unless a line explicitly says otherwise.

**Where each package was found (of the 9 hashed `_npx` directories listed):**

| Server | npx cache dir | Package path |
|---|---|---|
| `godot-coding-solo` | `0994aa1160b7c851` | `node_modules/@coding-solo/godot-mcp/` |
| `godot-comprehensive` | `b49f665d8ba37522` | `node_modules/@tugcantopaloglu/godot-mcp/` |

The other 7 hashed directories (`15c61037b1978c83`, `1e7f6d9597241db0`, `32026684e21afda6`, `69f9afb961c37556`, `9833c18b2d85bc59`, `a3241bba59c344f5`, `da5c1b6ea715e8b4`) contain unrelated packages (chrome-devtools-mcp, playwright, miniflare/wrangler toolchain, an unrelated MCP SDK/hono server, another large bundler toolchain) — none contain `@coding-solo/godot-mcp` or a `tugcantopaloglu` package. Confirmed by listing top-level `node_modules/` entries in each.

Both cached packages contain only the **packed build output** (`build/`, `LICENSE`, `README.md`, `package.json`) — not the TypeScript source (`src/`) or the build scripts. This is expected: npm applies the `"files": ["build"]` allowlist from each package's `package.json` even for the git-installed one, after running its `prepare` script. Nothing was fetched from upstream for this report; everything cited is from the local cache, including both READMEs.

---

## Verdict

**`godot-coding-solo` (`@coding-solo/godot-mcp@0.1.1`): safe to use as configured, with one condition.** It only shells out to the Godot binary (`--headless --script`, `-e`, `-d`) with argument arrays (no shell string interpolation), never opens a network listener itself, has no runtime/addon bridge, and never writes outside the target project directory that the caller passes in. The one real gap is that headless operations (`create_scene`, `add_node`, `save_scene`, etc.) run through `execFileAsync` with **no timeout**, so a hung Godot process hangs the tool call indefinitely with no server-side recovery. Condition: be aware that any directory containing a `project.godot` file can be targeted (there is no `D:\Gamedev`-only sandbox), and know that a stuck headless op requires killing the process manually.

**`godot-comprehensive` (`@tugcantopaloglu/godot-mcp` at commit `fcbc29e03297900b9a1fcc6c7cbae116fe9d532a`, i.e. today's HEAD): safe with named conditions, not "safe as configured" without understanding what it does automatically.** It auto-writes a GDScript autoload (`mcp_interaction_server.gd`) plus an `[autoload]` line into `project.godot` **every time `run_project` is called**, with no separate consent step, and removes it again on stop/exit (best-effort). That autoload opens a plaintext, unauthenticated TCP listener bound to `127.0.0.1:9090` inside the running game, which accepts a `game_eval` command that compiles and executes **arbitrary GDScript at runtime** — by design, clearly named, but equivalent to code execution under the account running Godot (GDScript has full `FileAccess`/`OS` access). It also exposes `game_http_request` (arbitrary outbound HTTP from inside the game) and `game_websocket` (arbitrary outbound WS) as explicit, opt-in tools, and a `game_multiplayer` → `create_server` action that opens an ENet listener with **no interface restriction** (Godot's `ENetMultiplayerPeer.create_server()` has no bind-address parameter, so it listens on all interfaces, not just localhost) if that specific tool is invoked. None of this fires unless the corresponding tool is called, except the autoload injection and the 127.0.0.1:9090 listener, which fire automatically on every `run_project`. Conditions: understand that `run_project` mutates `project.godot`/adds a `.gd` file automatically; never invoke `game_eval`/`game_multiplayer`/`game_http_request`/`game_websocket` on projects or networks you don't fully trust the caller's intent for; pin the commit (see Pinning below) since the config uses an unpinned `github:` spec.

---

## Question | godot-coding-solo | godot-comprehensive

| # | Question | `godot-coding-solo` | `godot-comprehensive` |
|---|---|---|---|
| 1 | Exact version / pin | `package.json`: `"version": "0.1.1"`. Registry-published, immutable tarball (integrity `sha512-tSwmKN5D...` per the npx lockfile). Pin: **`@coding-solo/godot-mcp@0.1.1`** | `package.json` carries `"version": "3.1.0"`, but this is a self-reported repo version, not an npm-registry semver — GitHub installs aren't registry-versioned/immutable by tag. The npx lockfile records the exact resolved commit: `"resolved": "git+ssh://git@github.com/tugcantopaloglu/godot-mcp.git#fcbc29e03297900b9a1fcc6c7cbae116fe9d532a"`, which matches the commit stated as today's HEAD. The commit SHA is the only stable pin. Pin: **`github:tugcantopaloglu/godot-mcp#fcbc29e03297900b9a1fcc6c7cbae116fe9d532a`** |
| 2 | How does it drive Godot | Command-line only: `spawn(godotPath, ['-e','--path',projectPath])` for editor launch, `spawn(godotPath, ['-d','--path',projectPath,...scene])` for run, and `execFileAsync(godotPath, ['--headless','--path',projectPath,'--script',operationsScript, op, json])` for headless scene/node ops. No sockets, no ports, nothing bound or connected over the network. | Both: same CLI pattern (`-e`, `-d`/`--headless`, `--path`, `--script`) for editor/run/headless ops, **plus** a TCP client that connects to `127.0.0.1:9090` (host hardcoded to loopback) to talk to a listener that runs *inside* the launched game. The listener itself (`mcp_interaction_server.gd`, injected as an autoload) calls `_server.listen(PORT, "127.0.0.1")` — also loopback-only, not `0.0.0.0`. Exception: the opt-in `game_multiplayer`→`create_server` tool opens a separate ENet UDP listener with no bind-address argument (binds all interfaces) if explicitly invoked. |
| 3 | Requires an editor/runtime addon | No. No `game_*` tools exist in this package's tool list at all; there is nothing to install. | Yes, for every `game_*` tool. The addon is `mcp_interaction_server.gd`, copied to **the project root** (`<projectPath>/mcp_interaction_server.gd`) and registered as an autoload named `McpInteractionServer` in `project.godot`. It is written **automatically, not only on request** — `injectInteractionServer()` runs unconditionally inside `handleRunProject()` before every `run_project` call. If an autoload of that name already exists it leaves the project alone (just restores the script file if missing); otherwise it injects the `[autoload]` line and deletes/reverts it again in `removeInteractionServer()` on process exit/stop (only if the server itself injected it — a pre-existing autoload is left untouched). The README documents this as a manual copy-in step, but the shipped `build/index.js` in fact does it automatically. |
| 4 | Outbound network (hidden) | Not found in the code read. `axios` is a declared dependency in `package.json` but is never imported/used in `build/index.js` — dead dependency, no HTTP client instantiated anywhere. No `fetch`, no `http`/`https` module usage. | Same: `axios` declared but never imported/used; no telemetry or update-check call sites found anywhere in `build/index.js` or the `.gd` scripts. `game_http_request` (`_cmd_http_request` in `mcp_interaction_server.gd`, using Godot's `HTTPRequest`) and `game_websocket` (`WebSocketPeer.connect_to_url`) are explicit, caller-invoked tools that make outbound requests to whatever URL the caller supplies — this is a named feature, not hidden telemetry, exactly as flagged in the task. `manage_docker_export`/`manage_ci_pipeline` write Dockerfile/workflow *text* containing `wget https://github.com/...` — that's a template written to a file, not a network call the MCP server itself makes. |
| 5 | Reads credentials/secrets/files outside project | Not found in the code read. `process.env` reads are limited to `DEBUG`, `GODOT_PATH`, and (for auto-detection) `HOME`/`USERPROFILE` used only to build candidate Godot-binary paths. No `.ssh`, no credential files, no arbitrary-path reads: this package has no `readFileSync`/file-content-read API at all (only `readdirSync` for directory listing and `existsSync`). | `process.env` reads: same set, plus `GODOT_MCP_ALLOWED_DIRS` (unset in this project's config). `read_file`/`write_file`/`delete_file` join a caller-supplied `filePath` onto a caller-supplied `projectPath` via `validatePath()` — which **only rejects paths containing `".."`**; it does not restrict `projectPath` to `D:\Gamedev` or anywhere else unless `GODOT_MCP_ALLOWED_DIRS` is set (it isn't, in this config — `isPathWithinAllowedRoots()` returns `true` for everything when the list is empty, and that check is wired into `handleRunProject` only, not into `read_file`/`write_file`/`create_project`/etc.). So any of these tools can target **any directory on disk that contains a `project.godot` file** — not limited to the Gamedev project — though `path.join` still blocks classic `..`-escape from within that directory. The much larger exposure is `game_eval`: it compiles and runs arbitrary GDScript inside the live game process, and GDScript's `FileAccess`/`OS` APIs are not sandboxed to the project folder, so a caller using `game_eval` can read/write anything the OS user account can reach — this is architecturally equivalent to full code execution, not merely a project-file reader. |
| 6 | Writes outside project directory | Not found in the code read. This package has no `writeFileSync`/file-write API at all — `fs` imports are limited to `existsSync, readdirSync`. All actual project mutation happens inside the spawned Godot process via `godot_operations.gd`, which only touches `res://`-relative (i.e., project-relative) paths. No temp files, no global config, no logs written to disk; debug logging goes to `console.error` (stderr) only. | All `writeFileSync` call sites in `build/index.js` write to paths built from the caller-supplied `projectPath` (project.godot, scene/script/resource files, `mcp_interaction_server.gd`, export/CI/Docker templates) — no writes to OS temp dirs or global config found. Debug logging is `console.error` (stderr) only, no file logging. The one process-adjacent write is the autoload injection into the target project itself (see Q3) — outside this MCP server's own installation directory, but inside whatever project the caller points at. |
| 7 | Failure behaviour | `run_project`/`launch_editor` use `spawn()` and return success text as soon as the child process object is created, before confirming the process actually started; a genuine spawn failure surfaces asynchronously via `process.on('error', ...)` → `console.error` only (not reflected back into the already-sent tool response). Missing project or missing/invalid Godot path *are* caught synchronously and return a clear `createErrorResponse` with suggested fixes (e.g. "Ensure Godot is installed correctly", "Set GODOT_PATH..."). Headless ops (`executeOperation`, used by `create_scene`/`add_node`/`save_scene`/etc.) call `execFileAsync(this.godotPath, args)` with **no `timeout` option** — if Godot hangs, the tool call hangs indefinitely; only the Godot-path validity check (`isValidGodotPath`, `--version`) has an explicit `{ timeout: 10000 }`. | Same up-front validation (`createErrorResponse` for missing project/path) and the same **un-timed** `execFileAsync` for headless ops (`executeOperation`, line ~543) — a hang there hangs the tool call. Two things are notably *better* here: (a) `export_project` explicitly sets `{ timeout: 120000 }`; (b) the TCP game-interaction path has real, bounded failure handling — `connectToGame()` retries 10× at 500 ms (≈5 s total) after an initial 2 s delay and simply logs `"Failed to connect to game interaction server after 10 attempts"` to stderr if the game/addon never comes up (this does not fail the `run_project` call itself, which already returned "started" text); `sendGameCommand()` wraps every game command in a `setTimeout` that rejects with `` `Game command '${command}' timed out after ${timeoutMs/1000}s` `` (default 10 s; `game_eval` uses 30 s); and `gameCommand()` checks `this.activeProcess`/`this.gameConnection.connected` up front and returns a clear `"No active Godot process. Use run_project first."` / `"Not connected to game interaction server."` error instead of hanging if the game isn't running. The in-game listener itself also has a 120 s `BUSY_TIMEOUT` that force-resets a stuck command flag (`mcp_interaction_server.gd` line 14, 34-41). |
| 8 | Flags for a reviewer | `execFileAsync`/`spawn` always use argument arrays (`['--headless','--path',projectPath,...]`), never a shell string — no shell-injection pattern found. `validatePath()` is a bare `!path.includes('..')` check; weak, but this package has no file-read/write API for it to gate, only project-path arguments that end up as `spawn`/`execFile` args (not shell-interpolated). No eval, no disabled TLS, no `postinstall` script (`package.json` scripts: `build`, `inspector`, `prepare`, `watch` only). | **`game_eval` is explicit, labeled, arbitrary-code-execution-at-runtime** (`mcp_interaction_server.gd` comment: `"# --- Eval: Execute arbitrary GDScript at runtime ---"`) — flag this as the single highest-impact capability in the package; it is gated only by "is the `game_*` bridge connected," not by any allowlist. `validatePath()` is the same weak `!path.includes('..')` check as the other package, but here it *does* gate a real file-read/write/delete API (`read_file`/`write_file`/`delete_file`/`create_directory`), and the only stronger gate (`GODOT_MCP_ALLOWED_DIRS`) is applied solely to `run_project`, not to those file tools — flag the inconsistent scope of that allowlist. `game_multiplayer`→`create_server` opens a listener on all interfaces with a caller-chosen port (default 7000) if invoked — flag as a real remote-exposure surface distinct from the otherwise-loopback-only design. All process invocations use argument arrays, not shell strings — no shell-injection pattern found. No disabled TLS verification found. No `postinstall` script (`package.json` scripts: `build`, `inspector`, `prepare`, `watch`, `test`, `test:watch`); `prepare` triggers `tsc && node scripts/build.js` automatically on install for this git dependency, which is standard npm git-dependency behavior, not a hidden mechanism, though `scripts/build.js` itself is not present in the packed/cached `build/` output to inspect (not found in the code read — the packed tree only ships `build/`, `LICENSE`, `README.md`, `package.json`). |

---

## Evidence

### 1. Package locations and identity

- `C:\Users\sayan\AppData\Local\npm-cache\_npx\0994aa1160b7c851\node_modules\@coding-solo\godot-mcp\package.json`:
  `"name": "@coding-solo/godot-mcp"`, `"version": "0.1.1"`, `"bin": {"godot-mcp": "./build/index.js"}`, deps `"@modelcontextprotocol/sdk": "0.6.0"`, `"axios": "^1.7.9"`, `"fs-extra": "^11.2.0"`.
- `C:\Users\sayan\AppData\Local\npm-cache\_npx\0994aa1160b7c851\node_modules\.package-lock.json`:
  `"node_modules/@coding-solo/godot-mcp": { "version": "0.1.1", "resolved": "https://registry.npmjs.org/@coding-solo/godot-mcp/-/godot-mcp-0.1.1.tgz", "integrity": "sha512-tSwmKN5D3JWGfnyPFxijxjdsT+GKIQrf9g6zYNefLvOVYx2UTC9PhyFFHc9vphtjyFrtjYf1n5Vq1zRNN3UXBA==" }`
- `C:\Users\sayan\AppData\Local\npm-cache\_npx\b49f665d8ba37522\node_modules\@tugcantopaloglu\godot-mcp\package.json`:
  `"name": "@tugcantopaloglu/godot-mcp"`, `"version": "3.1.0"`, `"description": "MCP server for full Godot 4.x engine control with 157 tools for AI-driven game development"`, deps `"@modelcontextprotocol/sdk": "1.26.0"`, `"axios": "^1.16.0"`, `"fs-extra": "^11.2.0"`.
- `C:\Users\sayan\AppData\Local\npm-cache\_npx\b49f665d8ba37522\node_modules\.package-lock.json`:
  `"node_modules/@tugcantopaloglu/godot-mcp": { "version": "3.1.0", "resolved": "git+ssh://git@github.com/tugcantopaloglu/godot-mcp.git#fcbc29e03297900b9a1fcc6c7cbae116fe9d532a" }` — matches the commit given as today's GitHub HEAD.
- Both cached trees contain only `build/`, `LICENSE`, `README.md`, `package.json` (no `src/`), consistent with npm's `"files": ["build"]` allowlist applying even to the git install.

### 2. Process invocation (both)

`build/index.js` (coding-solo) line 12: `import { spawn, execFile } from 'child_process';`
Line 873: `const process = spawn(this.godotPath, ['-e', '--path', args.projectPath], { stdio: 'pipe' });` (editor launch)
Line 930: `const process = spawn(this.godotPath, cmdArgs, { stdio: 'pipe' });` where `cmdArgs = ['-d', '--path', args.projectPath, ...optional scene]` (run project)
Line ~397-410 (`executeOperation`): builds `['--headless','--path',projectPath,'--script',this.operationsScriptPath, operation, paramsJson]`, optionally `--debug-godot`, then `await execFileAsync(this.godotPath, args)`.

`build/index.js` (comprehensive) — identical patterns at lines 3525 (`spawn(..., ['-e','--path',...])`), 3584 (`spawn(..., cmdArgs)` where `cmdArgs=['-d','--path',projectPath,...]`), and `executeOperation` (~line 543) using the same `--headless --script godot_operations.gd <op> <json>` pattern; `export_project` additionally uses `['--headless','--path',projectPath, exportFlag, presetName, outputPath]` with `execFileAsync(..., { timeout: 120000 })` (line 5249).

### 3. TCP bridge (comprehensive only)

`build/index.js` lines 14, 63-64:
```
import { createConnection } from 'net';
...
INTERACTION_PORT = 9090;
AUTOLOAD_NAME = 'McpInteractionServer';
```
Line 344: `const socket = createConnection({ host: '127.0.0.1', port: this.INTERACTION_PORT }, () => { ... });` — client-side connect, loopback only.

`build/scripts/mcp_interaction_server.gd` lines 13, 22-27:
```
const PORT: int = 9090
...
_server = TCPServer.new()
var err: int = _server.listen(PORT, "127.0.0.1")
if err != OK:
    push_error("McpInteractionServer: Failed to listen on port %d, error: %d" % [PORT, err])
    return
print("McpInteractionServer: Listening on 127.0.0.1:%d" % PORT)
```
README (`@tugcantopaloglu/godot-mcp/README.md` line 552, 566-568) confirms: `"The server listens on 127.0.0.1:9090 and accepts JSON commands over TCP when the game is running."` and describes the "two communication channels" (Headless CLI, TCP Socket) architecture.

### 4. Automatic addon injection (comprehensive only)

`build/index.js` lines 265-295 (`injectInteractionServer`):
```
injectInteractionServer(projectPath) {
    const projectFile = join(projectPath, 'project.godot');
    const destScript = join(projectPath, 'mcp_interaction_server.gd');
    const existingContent = readFileSync(projectFile, 'utf8');
    if (existingContent.includes(this.AUTOLOAD_NAME)) {
        this.gameConnection.interactionServerInjectedByUs = false;
        if (!existsSync(destScript)) { copyFileSync(this.interactionScriptPath, destScript); ... }
        return;
    }
    this.gameConnection.interactionServerInjectedByUs = true;
    copyFileSync(this.interactionScriptPath, destScript);
    ...
    const autoloadLine = `${this.AUTOLOAD_NAME}="*res://mcp_interaction_server.gd"`;
    if (content.includes('[autoload]')) { content = content.replace('[autoload]', `[autoload]\n\n${autoloadLine}`); }
    else { content += `\n[autoload]\n\n${autoloadLine}\n`; }
    writeFileSync(projectFile, content, 'utf8');
}
```
Called unconditionally at line 3577 inside `handleRunProject`: `this.injectInteractionServer(args.projectPath);` — i.e. on *every* `run_project` call, not gated behind a separate "install addon" tool. Reversed in `removeInteractionServer()` (lines 299-327) on `stop_project` and on process `exit`, but only `if (this.gameConnection.interactionServerInjectedByUs)` — a pre-existing user-managed autoload of the same name is left alone.

README line 546-550 documents this as if it were a manual step ("Copy `build/scripts/mcp_interaction_server.gd` to your project's scripts folder... In Godot: Project > Project Settings > Autoload...") — the shipped code in fact automates it.

### 5. `game_eval` — arbitrary runtime code execution (comprehensive only)

`build/scripts/mcp_interaction_server.gd` lines 553-590:
```
# --- Eval: Execute arbitrary GDScript at runtime ---
func _cmd_eval(params: Dictionary) -> void:
    var code: String = params.get("code", "")
    ...
    var script_source: String = """extends Node
func execute():
    var __result = null
    __result = await _run()
    return __result
func _run():
%s
""" % [_indent_code(code)]
    var script: GDScript = GDScript.new()
    script.source_code = script_source
    var err: int = script.reload()
    ...
    var temp_node: Node = Node.new()
    temp_node.set_script(script)
    temp_node.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(temp_node)
    var result: Variant = null
    if temp_node.has_method("execute"):
        result = await temp_node.execute()
```
Bound to the tool at `build/index.js` line 4253: `return this.gameCommand('eval', args, a => ({ code: a.code }), 30000);`

### 6. Explicit outbound-network tools (comprehensive only; not hidden telemetry)

`build/scripts/mcp_interaction_server.gd` lines 2733-2760 (`_cmd_http_request`, uses Godot's `HTTPRequest`, arbitrary caller-supplied `url`/`method`/`headers`/`body`) and lines 2763-2801 (`_cmd_websocket`, `WebSocketPeer.connect_to_url(url)` — client connect/send/disconnect/status only, no server mode). Tool schemas at `build/index.js` lines 2081-2106.

### 7. `game_multiplayer` create_server — all-interfaces listener (comprehensive only)

`build/scripts/mcp_interaction_server.gd` lines 2803-2815:
```
func _cmd_multiplayer(params: Dictionary) -> void:
    var action: String = params.get("action", "")
    match action:
        "create_server":
            var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
            var port: int = int(params.get("port", 7000))
            var max_cl: int = int(params.get("max_clients", 32))
            var err: int = peer.create_server(port, max_cl)
            ...
            multiplayer.multiplayer_peer = peer
```
`ENetMultiplayerPeer.create_server()` takes no bind-address argument in the Godot 4 API, so it listens on all interfaces, unlike the hardcoded-loopback MCP interaction server. Only reachable if a caller explicitly invokes `game_multiplayer` with `action: "create_server"`.

### 8. Weak path validation / scope of `GODOT_MCP_ALLOWED_DIRS` (comprehensive)

`build/index.js` lines 22-35:
```
const ALLOWED_PROJECT_ROOTS = (process.env.GODOT_MCP_ALLOWED_DIRS || '')
    .split(process.platform === 'win32' ? /[;,]/ : /[:,]/)
    .map(p => p.trim()).filter(p => p.length > 0).map(p => resolve(p));
function isPathWithinAllowedRoots(target) {
    if (ALLOWED_PROJECT_ROOTS.length === 0) return true;
    ...
}
```
`isPathWithinAllowedRoots` is called only once in the whole file, at line 3558, inside `handleRunProject`. `README.md` line 560: `"GODOT_MCP_ALLOWED_DIRS | Optional. Restrict run_project to projects under these roots (;, ,, or : separated). When unset, any project path is allowed."` The project's configured env for this server (per the task) sets only `GODOT_PATH`, so `GODOT_MCP_ALLOWED_DIRS` is unset and this gate is inert everywhere, including on `run_project`.

`build/utils.js` line 189-194 (shared by both packages' equivalent files):
```
export function validatePath(path) {
    if (!path || path.includes('..')) { return false; }
    return true;
}
```
This is the only gate applied to `read_file`/`write_file`/`delete_file`/`create_directory`/etc. (`build/index.js` lines 4622-4691).

### 9. No axios / no hidden HTTP calls in the Node process (both)

```
$ grep -n "axios" build/utils.js build/index.js   # both packages
(no output — declared as a dependency, never imported or used)
```

### 10. Failure/timeout handling (comprehensive)

`build/index.js` lines 331-393 (`connectToGame` — 2 s initial delay, then 10 retries × 500 ms against `127.0.0.1:9090`, logs `"[SERVER] Failed to connect to game interaction server after 10 attempts"` and returns without throwing if all attempts fail); lines 434-451 (`sendGameCommand` — per-call `setTimeout(..., timeoutMs)` rejecting with `` `Game command '${command}' timed out after ${timeoutMs/1000}s` ``, default `timeoutMs=10000`); lines 469-484 (`gameCommand` — returns `createErrorResponse('No active Godot process. Use run_project first.')` / `createErrorResponse('Not connected to game interaction server.')` up front instead of attempting a doomed call). `mcp_interaction_server.gd` lines 10-14, 34-41 (`BUSY_TIMEOUT: float = 120.0`, force-resets a stuck in-flight command).

Un-timed headless op call, both packages: coding-solo `build/index.js` line 410 `const { stdout, stderr } = await execFileAsync(this.godotPath, args);` (no options object); comprehensive `build/index.js` ~line 543, same call shape. Contrast with `export_project`'s explicit `{ timeout: 120000 }` at comprehensive line 5249, and the Godot-path validity check's `{ timeout: 10000 }` at coding-solo line 1192-1193.

---

## Pinning

To make either server reproducible/pinned in `.claude.json`, change the `command`/`args` to:

- `godot-coding-solo`: use **`@coding-solo/godot-mcp@0.1.1`** in place of `@coding-solo/godot-mcp@latest`, e.g. `npx --yes @coding-solo/godot-mcp@0.1.1`. This is an immutable, registry-published tarball (integrity hash above), so this pin is fully reproducible.
- `godot-comprehensive`: use **`github:tugcantopaloglu/godot-mcp#fcbc29e03297900b9a1fcc6c7cbae116fe9d532a`** in place of `github:tugcantopaloglu/godot-mcp`, e.g. `npx --yes github:tugcantopaloglu/godot-mcp#fcbc29e03297900b9a1fcc6c7cbae116fe9d532a`. The bare `github:` spec (as currently configured) re-resolves to whatever commit is HEAD at the moment `npx` runs; with no pin, code audited today can silently differ from code executed on a later date. The `package.json` `"version": "3.1.0"` field is not a safe substitute for a pin, since GitHub installs are not registry-versioned/immutable the way `@coding-solo/godot-mcp@0.1.1` is.

---

## Open risks

1. **Unpinned GitHub install for `godot-comprehensive`.** The configured `github:tugcantopaloglu/godot-mcp` spec has no ref; every fresh `npx --yes` invocation re-resolves to whatever the upstream `main` branch's HEAD is at that moment, so the exact code that runs can change without warning between sessions. Pin it (see above).
2. **`game_eval` is full arbitrary-code execution scoped only by "can the TCP bridge reach the running game."** It is explicitly named and documented in-code, but it is worth the reviewer explicitly acknowledging this is not a sandboxed scripting surface — GDScript's `FileAccess`/`OS`/`DirAccess` APIs are not confined to the project directory, so anything that can send a `game_eval` command can read/write/execute broadly under the OS account running Godot.
3. **`project.godot` is mutated automatically on every `run_project` call** by `godot-comprehensive` (autoload injection), with no separate opt-in step and no confirmation prompt distinct from the `run_project` call itself. Reviewers who expect `run_project` to be a read-only/ephemeral action should know it edits a tracked project file (reverted on `stop_project`/exit, best-effort, only if it made the change).
4. **`GODOT_MCP_ALLOWED_DIRS` is unset in this project's MCP config and, even if set, only gates `run_project`** — not `read_file`/`write_file`/`delete_file`/`create_project`/etc. Effectively, any of those tools can address any directory on the machine that contains (or, for `create_project`, will contain) a `project.godot` file; only classic `..` traversal is blocked, not absolute paths to other projects. This is a real gap between the README's implied protection and the code's actual enforcement scope.
5. **`game_multiplayer` → `create_server` opens a listener on all network interfaces**, not just loopback, if that specific tool is invoked with an attacker- or agent-chosen port. This is the one place either server's default network posture is not loopback-only.
6. **Headless GDScript operations run with no client-side timeout** in both packages (`executeOperation` → bare `execFileAsync`). A hang in Godot (bad script, stuck dialog, corrupted project) hangs the MCP tool call indefinitely; recovery requires an operator to kill the process out of band (`stop_project` won't help if the call itself never returns).
7. **`scripts/build.js` (the `prepare`-lifecycle build step for the git-installed package) was not present in either cached tree to inspect** — only the packed `build/` output was available locally. Not found in the code read; flagged rather than assumed safe.
8. **Dead `axios` dependency in both `package.json` files** is harmless as found (never imported), but its presence with no use is worth noting if a future version silently starts using it, since neither current build performs any actual HTTP call from the Node.js process.
