# E0.2 (steps 1–2): Godot skill package candidates for D:\Gamedev

Scope actually performed: research and security review only. Nothing was installed, no `/plugin`
command was run, and no file under `D:\Gamedev` was created or modified. All work happened in a
scratch clone directory under the session scratchpad
(`…\scratchpad\skills_research\<repo>`), which is outside the project and is not referenced by
anything in `D:\Gamedev`.

Context read first, per the task: `D:\Gamedev\NEXT_SESSION.md` Prompt 3 (task E0.2), the E0.1/E0.2
rows of `D:\Gamedev\MASTER_SDLC.md`'s Development Phase Map (Phase 0, lines ~3104–3126), and
`D:\Gamedev\docs\20_Technical_Architecture.md` § "Godot 4.x Implementation Standards" (lines 9–49).
Two things from that reading shape everything below:

- **`sandbox/connection_test` does not exist yet** — task E0.1 (Prompt 2) has not been run in this
  workspace, only `phases/README.md` and `phases/LESSONS.md` exist under `phases/`. E0.2 depends on
  E0.1. This report therefore covers E0.2 steps 1–2 (compare candidates; security-read every script
  and hook) plus enough of steps 3 and 5 to give a recommendation and a verification plan — it does
  **not** claim step 4 (verify against the sandbox) has happened, because the sandbox is not there
  to verify against.
- docs/20 pins: Godot 4.7.1 exclusively (boot-check via `Engine.get_version_info()`, export
  templates 4.7.1, `project.godot` recording 4.7); two Godot MCP servers (`godot-comprehensive`,
  `godot-coding-solo`) already provide editor/runtime control; an `EventBus` Autoload using
  **signals** for state changes, separately from typed **query** interfaces and typed **command**
  interfaces (three distinct communication styles, not just "an event bus"); a specific gameplay
  Scene Tree with container nodes `Entities`, `Projectiles`, `Pickups`, `Effects`, `Environment`,
  `Audio`; 16 named collision layers bound in `project.godot`; `Resource` (`.tres`) data contracts
  that are read-only at runtime. Any skill that pushes a *generic* competing convention here (a
  different autoload set, a different folder layout) needs to lose to docs/20, not replace it.

## How I searched

- Web search for the two named candidates by exact repo name/owner.
- Web search for `"godot" "claude skills"/"claude code skills" gdscript SKILL.md github 2026` and
  `awesome-claude-code-skills gamedev godot` to surface anything newer/better-maintained.
- Followed every distinct repo that turned up in those results, then re-verified maintenance facts
  (not just README claims) with `gh api repos/<owner>/<repo>` (`pushed_at`, `open_issues_count`,
  `license`, `archived`, `stargazers_count`) and `git log` on a local shallow clone of each repo
  (commit dates, frequency, file diffs).
- Cloned every repo with `git clone` into a scratch folder and read the actual files with the
  `Read`/`Grep`/`Bash` tools — I did **not** rely on README prose or the search snippets for the
  security review; every script and hook quoted below was opened and read in full.
- Repos found and cloned: `Randroids-Dojo/Godot-Claude-Skills` (deprecated — see below),
  `Randroids-Dojo/skills` (its replacement, discovered via the deprecation notice in the first
  repo's README), `alexmeckes/godot-claude-skills`, `gamedev-skills/awesome-gamedev-agent-skills`,
  `fenixnix/Godot-Skills`, `jame581/GodotPrompter`. One more repo turned up in search
  (`involvex/Claude-Godot-Skills`) — checked via `gh api` only: it is a fork of the old Randroids
  repo, 0 stars, last pushed 2026-02-03, not evaluated further.

---

## Candidate 1 — Randroids-Dojo (old repo, deprecated) / **Randroids-Dojo/skills → `plugins/godot`** (current)

Sources: [Randroids-Dojo/Godot-Claude-Skills](https://github.com/Randroids-Dojo/Godot-Claude-Skills)
(the repo named in the task), [Randroids-Dojo/skills](https://github.com/Randroids-Dojo/skills)
(its replacement), [Randroids-Dojo/PlayGodot](https://github.com/Randroids-Dojo/PlayGodot),
[Randroids-Dojo/godot](https://github.com/Randroids-Dojo/godot) (the automation fork).

**The repo named in the task is deprecated.** `Randroids-Dojo/Godot-Claude-Skills`'s `README.md`
opens with:

> "# DEPRECATED - Skill now lives in the [Randroid's Dojo](https://github.com/Randroids-Dojo/skills/tree/main/plugins/godot) marketplace"

Confirmed against the actual git history, not just the README claim: `git log -1` on the old repo
shows its true last commit at **2026-01-19** (`gh api` `pushed_at: 2026-01-19T15:57:16Z`), 34 commits
total, all in Dec 2025–Jan 2026. The successor, `Randroids-Dojo/skills`, was created 2026-01-19 and
was pushed **today** (`pushed_at: 2026-09-17T01:47:30Z`). I evaluated the current version, at
`plugins/godot/` in the new repo (plugin manifest version 1.3.0), since that is what installing
`Randroids-Dojo/Godot-Claude-Skills` today would actually give you nothing (it just points at the
new repo) — the exact commands below target the current repo.

### 1. Contents

- `plugins/godot/SKILL.md` — frontmatter `name: godot`, points to five reference files rather than
  inlining everything (a rewrite from the old repo's monolithic SKILL.md; the four helper scripts
  are byte-identical between old and new — I diffed them).
- `plugins/godot/references/gdunit4-quickstart.md`, `scene-runner.md`, `assertions.md`,
  `playgodot.md`, `ci-integration.md`, `deployment.md` — prose reference docs.
- `plugins/godot/scripts/run_tests.py`, `export_build.py`, `parse_results.py`,
  `validate_project.py` — four Python 3 CLI helpers, each read in full.
  - `run_tests.py` / `export_build.py` / `validate_project.py`: locate a `godot`/`godot4` binary
    (via `PATH`, `$GODOT`/`$GODOT4`, or a `which` lookup), then `subprocess.run([...godot,
    --headless, ...])` and pass through the exit code. No network access, no credential/token/SSH
    reads, no writes outside paths the caller passes on the command line (`--report`,`--output`).
  - `parse_results.py`: pure stdlib XML parsing of JUnit reports the caller points it at; formats
    summary/JSON/markdown to stdout. No I/O beyond the given directory.
  - None of the four scripts run automatically — each is a CLI tool the agent (or a human) invokes
    explicitly by name.
- `plugins/godot/.claude-plugin/plugin.json` — plugin manifest, MIT, version 1.3.0.
- No `hooks/` directory anywhere under `plugins/godot/`. **No hooks are registered by this skill.**
- No MCP server is bundled or required for the GdUnit4 half. The **PlayGodot** half (see below) is
  not an MCP server either — it is a separate Python library (`pip install playgodot`) that talks
  to Godot's native RemoteDebugger protocol on TCP port 6007, localhost only. I read the example
  project's own `addons/playgodot/server.gd` (only present in the old repo's `example-project/`,
  used to illustrate the pattern, not shipped as an installable addon) — it opens
  `TCPServer.new(); _server.listen(_port)` on `ws://localhost:%d` (default port 9999). Localhost
  only; not something the skill installs into a real project.
- The whole repo's marketplace (`Randroids-Dojo/skills`) bundles many unrelated plugins
  (`blender-production`, `unreal`, `randroid` — which *does* have a `hooks/` folder — `slipbox`,
  `spiral`, `task-tracking-dots`, `vibekit`, …). `/plugin install godot@skills` installs only the
  `godot` plugin, not the rest of the marketplace's plugins, so the unrelated `randroid` hooks are
  not part of this candidate's footprint; noted for transparency since `/plugin marketplace add`
  registers the whole marketplace.

### 2. Maintenance

- Old repo (`Godot-Claude-Skills`): last real commit 2026-01-19, 34 commits total, 0 open issues,
  44 stars, now a pointer-only stub. **This is the repo literally named in the task — it is stale
  and self-declared superseded.**
- New repo (`Randroids-Dojo/skills`): 0 open issues (6 closed, all resolved), 46 stars, pushed
  today. But the `plugins/godot/` path specifically was touched only 4 times in the last 12
  months (`git log --since="1 year ago" -- plugins/godot`): 2026-01-18 (added), 2026-01-25 (doc
  update), 2026-02-01 (cross-tool compatibility), and 2026-08-30 (the SKILL.md rewrite to a
  reference-pointer format). The underlying Godot-version-specific content (CI examples, version
  compatibility table) was **not** touched in the 2026-08-30 rewrite.
- No Godot version newer than 4.3 is named anywhere in the current content. The GdUnit4
  compatibility table in `references/gdunit4-quickstart.md` reads:

  > "| GdUnit4 Version | Godot Version |\n|-----------------|---------------|\n| 4.4.x | 4.3.x |\n| 4.3.x | 4.2.x |\n| 4.2.x | 4.1.x |"

  Every CI example in `references/ci-integration.md` and the old repo's `.github/workflows/ci.yml`
  pins `chickensoft-games/setup-godot@v2` with `version: 4.3.0`. **Nothing in this candidate has
  been updated for Godot 4.7.**

### 3. Licence

MIT (both repos; `LICENSE` read directly). Compatible with anything.

### 4. Godot 4.7 compatibility

- GdUnit4 half: uses the generic `godot` command name (not a hardcoded Linux/macOS path), so it is
  portable in principle, but every helper script's `find_godot()` shells out to Unix `which`:
  ```python
  candidates = ["godot", "godot4", os.environ.get("GODOT", ""), os.environ.get("GODOT4", "")]
  for candidate in candidates:
      if candidate and subprocess.run(["which", candidate], capture_output=True).returncode == 0:
          return candidate
  ```
  `which` is not a native Windows/PowerShell command; it only exists if Git for Windows' bash is on
  `PATH` (or the script is run from Git Bash). Run from native PowerShell/cmd with no `which.exe`
  on `PATH`, `subprocess.run(["which", ...])` raises `FileNotFoundError`, which is **unhandled** —
  the script crashes instead of falling back. Setting `$env:GODOT` to the full path of
  `D:\godot\Godot_v4.7.1-stable_win64_console.exe` does not fix this, because the candidate is
  still passed through `which`, not used directly. Workable only if invoked through Git Bash.
- PlayGodot half: **requires a custom-built Godot fork**, not the pinned stock executable. Quoting
  `references/playgodot.md` directly:

  > "**Custom Godot build** - [Randroids-Dojo/godot](https://github.com/Randroids-Dojo/godot) (automation branch)" … "Option 2: Build custom Godot fork from source … scons platform=windows target=editor -j8"

  Pre-built binaries are published only for Linux and macOS
  (`godot-automation-linux-x86_64.zip`, `godot-automation-macos-universal.zip` — checked the
  release asset names in `ci-integration.md` and the old repo's `ci.yml`); there is **no
  pre-built Windows binary**. Using PlayGodot on this project's machine means building Godot from
  source with SCons and a full C++ toolchain, producing a *different* Godot binary than
  `D:\godot\Godot_v4.7.1-stable_win64.exe` — which directly conflicts with docs/20's pin ("Godot
  4.7.1 is pinned by the 4.7.1 export templates and a boot check that `Engine.get_version_info()`
  reports 4.7.1 … this pin is changed only through document 20"). This is a hard incompatibility
  for PlayGodot specifically, not a minor friction point.

### 5. Security review

- The four Python scripts: no network calls beyond the local `godot` subprocess; no credential,
  token, SSH-key, or env-secret reads; no writes outside paths the caller supplies. Confirmed by
  reading all four files in full.
- No hooks anywhere in `plugins/godot/`.
- No curl-pipe-to-shell install step for the skill itself. `git clone ... addons/gdUnit4` (fetching
  the third-party GdUnit4 test framework) and `pip install playgodot` are explicit, documented,
  user/agent-typed commands, not something the skill runs on its own.
- Elevated-trust item worth naming even though it is not a classic "malicious pattern": PlayGodot's
  recommended path is to download and run a **third-party-modified build of the Godot engine
  itself** (a fork, not upstream Godot) from `Randroids-Dojo/godot`'s GitHub releases, or compile
  it from source. That is a meaningful supply-chain trust decision (running a modified game engine
  binary instead of the official one) — not disqualifying on its own, but it is exactly the kind of
  thing that should be a deliberate, documented choice, and it's moot here anyway because of the
  Windows/version-pin incompatibility above.
- Nothing here triggers the "recommend for rejection" bar (no non-localhost network call, no
  credential access, no writes outside the project, no curl-pipe-to-shell, no auto-run hook). The
  disqualifying issues are staleness and the PlayGodot/Windows conflict, not security.

### 6. Overlap with the configured MCP servers

`godot-comprehensive` and `godot-coding-solo` already do scene/node/script/project-settings editing,
running the project, and reading debug output. This skill adds nothing that overlaps those — its
value is (a) GdUnit4 test-authoring guidance plus ready-made CLI wrapper scripts for headless
running/parsing test results, and (b) PlayGodot, an alternative, MCP-independent way to drive a
*running game* (not the editor) via Python — which is not something either configured MCP server
does today. PlayGodot is the only genuinely new capability class here, and it's the part that's
incompatible with this project's pinned executable.

### 7. Fit with the plan (P0.7 / docs/20)

- GdUnit4 invocation matches the shape of P0.7 closely: `godot --headless --path . -s
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --run-tests` returns a real process exit code, and
  `run_tests.py`/`parse_results.py` turn that into a scriptable pass/fail with a parseable report.
  Swapping `godot` for the pinned `Godot_v4.7.1-stable_win64_console.exe` (needed on Windows to get
  a console/exit code rather than the windowed build) is a one-line substitution the designer/agent
  would need to make themselves — none of the candidates evaluated name that exe specifically.
- Caveat: the GdUnit4 CLI entry point named here (`addons/gdUnit4/bin/GdUnitCmdTool.gd
  --run-tests`) is the older GdUnit4 CLI shape; whichever GdUnit4 release actually gets installed
  for 4.7.1 needs to be checked against its own current CLI docs before trusting this path
  literally — the version-compatibility table above stops at Godot 4.3, so it doesn't cover 4.7.1
  at all.
- No conflict with docs/20's Scene Tree/autoload/folder-layout rules — this skill has no opinion on
  project structure, only on how to run tests and export builds.

---

## Candidate 2 — alexmeckes/godot-claude-skills

Source: [alexmeckes/godot-claude-skills](https://github.com/alexmeckes/godot-claude-skills),
issue [#2](https://github.com/alexmeckes/godot-claude-skills/issues/2), companion MCP
[alexmeckes/godot-mcp](https://github.com/alexmeckes/godot-mcp).

### 1. Contents

Five skills, no scripts, no hooks anywhere in the repo (confirmed — `find`/`grep` over the whole
clone found no `hooks/` directory and no code files at all, only Markdown):

- `skills/godot-code-gen/SKILL.md` — GDScript pattern reference (type hints, signals, tweens,
  state machines, autoloads). Pure prose/code-block reference, no executable content.
- `skills/godot-interactive/SKILL.md` — a persistent live-editor workflow built entirely around
  `godot-mcp` tool names (`godot_connect`, `godot_editor_get_scene_tree`,
  `godot_editor_add_node`, `godot_runtime_*`, …) and an "AI Bridge" editor plugin listening on
  `127.0.0.1:6550`.
- `skills/godot-live-edit/SKILL.md` — a lighter version of the same live-editor workflow, same
  tool names, same AI Bridge plugin/port assumption.
- `skills/godot-scene-design/SKILL.md`, `skills/godot-shader/SKILL.md` — scene/shader pattern
  references.
- `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` — plugin manifests.

### 2. Maintenance

`gh api`: created 2026-01-17, last pushed **2026-03-24** (~6 months stale as of 2026-09-17), 35
stars, **1 open issue**. 5 commits total. No Godot version beyond "4.x" is named anywhere; no
mention of 4.5/4.6/4.7 changes.

### 3. Licence

MIT.

### 4. Godot 4.7 compatibility

No hardcoded executable name or Linux/macOS path; the prose is generic Godot 4.x GDScript, so
nothing here actively breaks on 4.7.1. The bigger compatibility problem is architectural, not
version-specific (see §6/§7).

### 5. Security review

Clean — grepped the entire repo for network/credential/exec patterns
(`curl|wget|http://|token|secret|ssh|api_key|credential|.env`) and found **zero** matches outside
advisory prose. There is no executable content at all: no scripts, no hooks, nothing that could run
automatically. Nothing here triggers a rejection on security grounds.

However, the repo has a **known, unresolved functional defect** that materially affects
"verify the skill appears in the skill list" (E0.2's stated acceptance test). Open issue #2, filed
against this exact repo, reads:

> "Only `godot-interactive/SKILL.md` has the frontmatter block Claude Code requires to discover and list a skill … The other four skill files start directly with a `# Title` heading and have no frontmatter at all … Without `name`/`description` frontmatter, Claude Code's skill loader doesn't register these as invocable skills, so after installing the plugin only `godot-interactive` appears in the skill list even though all 5 are enabled."

I verified this myself by reading the raw files, not just trusting the issue: `godot-code-gen`,
`godot-live-edit`, and `godot-scene-design` (and `godot-shader`, checked via the same `head -3`
pass) all begin directly with `# <Title>` — no `---` frontmatter block, no `name:`/`description:`
fields. Only `godot-interactive/SKILL.md` has:
```
---
name: godot-interactive
description: Persistent `godot-mcp` and AI Bridge workflows for Godot 4.x projects. …
---
```
**4 of 5 skills in this pack will not appear in the skill list after installation**, and this has
been an open, unaddressed bug for 6 months.

### 6. Overlap with the configured MCP servers

This is the decisive fit problem. Every tool name this skill pack references
(`godot_connect`, `godot_editor_get_scene_tree`, `godot_editor_add_node`, `godot_runtime_*`, the
AI Bridge plugin on port 6550) belongs to a **different, third MCP server**
(`alexmeckes/godot-mcp`) that is not one of this project's two configured servers
(`godot-comprehensive`, `godot-coding-solo`). The README says as much: "Best used with
[godot-mcp](https://github.com/alexmeckes/godot-mcp) … This plugin provides the knowledge …
godot-mcp provides the tools." Installing this skill without also installing a third MCP server and
an "AI Bridge" GDScript plugin means the `godot-interactive`/`godot-live-edit` skills (3 of the 5,
and the only 2 that would even show up per the frontmatter bug) describe tool calls that don't
exist in this project's session. That is unrelated scope creep beyond the connection method E0.1 is
meant to fix on. The remaining `godot-code-gen`/`godot-scene-design`/`godot-shader` content is
engine-agnostic-enough prose that doesn't depend on any MCP server — but those three are exactly
the ones broken by the frontmatter bug.

### 7. Fit with the plan (P0.7 / docs/20)

No GdUnit4, GUT, or any test-harness content anywhere in this repo. It does not address P0.7 at
all. No folder-layout or autoload opinions, so no direct conflict with docs/20 there — but its core
live-editing skills assume tooling this project doesn't have.

---

## Candidate 3 — gamedev-skills/awesome-gamedev-agent-skills (found via search, not named in the task)

Source: [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills).

### 1. Contents

A 73-skill, multi-engine collection (Godot, Unity, Unreal, web engines, Roblox, disciplines,
genres, workflows), Godot-specific ones under `skills/godot/` — 14 skills, each `SKILL.md` +
`references/*.md`: `godot-2d-movement`, `godot-3d-essentials`, `godot-animation`, `godot-audio`,
`godot-csharp`, `godot-export`, `godot-gdscript`, `godot-multiplayer`, `godot-nodes-scenes`,
`godot-physics`, `godot-resources`, `godot-shaders`, `godot-signals-groups`, `godot-tilemap`,
`godot-ui-control`. Plus a `router/` (a SKILL.md that reads project files to pick the right
engine skill — not an auto-run mechanism, just another skill the agent reads) and repo-maintenance
scripts under `scripts/` (`check-site.py`, `generate-site.py`, `validate-skills.py`) that build and
validate the project's own documentation site/skill format — not part of what installs into a
consumer project, and not auto-run (no hooks reference them). No `hooks/` directory anywhere in the
repo (checked with `find . -iname "*hook*"`, zero hits).

### 2. Maintenance

`gh api`: created 2026-06-24 (young — about 3 months old), last pushed 2026-09-10 (~1 week before
today), **0 open issues**, **1,034 stars**. 94 commits total; the `skills/godot/` path was touched
11 times in the last year, most recently 2026-08-08.

### 3. Licence

**Apache-2.0** (confirmed from `LICENSE` header text, and `NOTICE`: "Copyright 2026 Abhishek Barali
and the awesome-gamedev-agent-skills contributors … licensed under the Apache License, Version
2.0"). The `NOTICE` also states all skills are original works authored from primary documentation,
not copied from other collections.

### 4. Godot 4.7 compatibility

The best of any candidate on this specific point. `skills/godot/godot-export/SKILL.md`'s
frontmatter and body explicitly target the current engine version:

> "description: > Export and build a Godot 4.7 project for distribution … Targets **Godot 4.7**."

It also carries version-specific detail most other candidates don't have, e.g. accurate coverage of
a 4.7 default-settings change:

> "**Godot 4.7+:** Projects **newly created** in Godot 4.7 already default `display/window/stretch/mode` to `canvas_items` and `display/window/stretch/aspect` to `expand`..."

CLI examples use the generic `godot` command (not a hardcoded Linux/macOS path or executable name),
so nothing here assumes a non-Windows layout.

### 5. Security review

Grepped `skills/godot` and `router` for network/exec/credential patterns
(`curl|wget|http://|subprocess|os\.system|eval\(|exec\(|requests\.|urllib|socket\.|token|secret|ssh|api_key|credential`)
— the only hits are advisory prose telling the reader *not* to store secrets:

> "don't store true secrets" (`godot-export/references/presets-and-cli.md`) and "**Don't put secrets in `.tres`** — they ship in plain text inside the export." (`godot-resources/SKILL.md`)

No scripts execute inside a consumer project, no hooks anywhere, no network calls, no credential
reads, no writes outside the project. Clean.

### 6. Overlap with the configured MCP servers

None functionally — same profile as the other pure-knowledge packs: reference/best-practice
content, no tool calls, no MCP server bundled or assumed.

### 7. Fit with the plan (P0.7 / docs/20)

**Gap: zero GdUnit4/test-harness content.** Grepped the whole repo for `gdunit|test harness|unit
test` — no matches anywhere in `skills/godot` or the README. This candidate does not help satisfy
P0.7 at all. No folder-layout/autoload opinions found in the Godot skills read, so no conflict with
docs/20 either way.

Install shape, for completeness: `npx skills add gamedev-skills/awesome-gamedev-agent-skills`
(cross-tool, not Claude-specific) or, Claude-Code-specific and scoped to just Godot:
`claude plugin marketplace add gamedev-skills/awesome-gamedev-agent-skills` then
`claude plugin install godot@awesome-gamedev-agent-skills` (a smaller bundle than the all-engines
`gamedev` plugin, per the repo's own README).

---

## Candidate 4 — fenixnix/Godot-Skills (found via search, not named in the task)

Source: [fenixnix/Godot-Skills](https://github.com/fenixnix/Godot-Skills).

### 1. Contents

11 small skills (`godot-class-name-checker`, `godot-clear-children`, `godot-console`,
`godot-gdscript-grammar`, `godot-global-variables`, `godot-knowledge`, `godot-packedscene`,
`godot-scene`, `godot-serialization-pattern`, `godot-singleton-pattern`, `godot-tscn-format`,
`godot-unix-timestamp-fix`). One script, `skills/godot-console/scripts/example.gd` — read in full:
a trivial `SceneTree`-extending demo script that prints the OS name, date, and
`Engine.get_version_info()`, then `quit()`. No network, no file I/O, no security concern. Several
SKILL.md files are written partly or fully in Chinese (`godot-knowledge/SKILL.md`), which will
reduce usefulness for an agent reasoning in English but is not a security or correctness issue.

### 2. Maintenance

`gh api`: created and last pushed the **same day**, 2026-03-15 — 2 commits total (`init` +
one description edit), never touched again in the 6 months since. 7 stars, 1 open issue.
Effectively an abandoned first-draft repo.

### 3. Licence

MIT.

### 4–7. Compatibility / security / overlap / fit

No test-harness content, no folder-layout opinions, no security issues (the one script is benign).
Not disqualified on security, but disqualified on maintenance and thinness relative to every other
candidate — see Reject section.

---

## Candidate 5 — jame581/GodotPrompter (found via search, not named in the task)

Source: [jame581/GodotPrompter](https://github.com/jame581/GodotPrompter),
[SECURITY.md](https://github.com/jame581/GodotPrompter/blob/master/SECURITY.md),
[CHANGELOG.md](https://github.com/jame581/GodotPrompter/blob/master/CHANGELOG.md).

### 1. Contents

By far the largest and most structured candidate. Relevant paths, all read directly:

- `skills/` — 55 domain skills (per its own manifest), each `SKILL.md` + `references/*.md`, e.g.
  `godot-testing`, `godot-project-setup`, `event-bus`, `resource-pattern`, `state-machine`,
  `export-pipeline`, `gdscript-patterns`, `physics-system`, `dependency-injection`,
  `addon-development`, plus non-Godot-specific game-systems skills (inventory, dialogue, save-load,
  multiplayer, XR, mobile). `skills/using-godot-prompter/SKILL.md` is the bootstrap skill whose
  `SESSION-CARD`-marked region the hook injects.
- `skills/godot-testing/SKILL.md`, `gdunit4-reference.md`, `gut-reference.md`,
  `references/running-tests.md`, `references/tdd-workflow.md`, `references/testing-patterns.md` —
  covers **both** GUT and gdUnit4 side by side (framework-selection table, RED-GREEN-REFACTOR
  workflow, CLI invocations for both, a copy-pasteable GitHub Actions workflow, an explicit
  "CI: … exits non-zero on failure" note).
- `hooks/hooks.json`, `hooks/hooks-cursor.json`, `hooks/run-hook.cmd`, `hooks/session-start` — a
  **SessionStart hook**, registered via `hooks/hooks.json`:
  ```json
  "SessionStart": [{ "matcher": "startup|resume|clear|compact",
    "hooks": [{ "type": "command",
      "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start", … }] }]
  ```
  This **runs automatically** on every session start/resume/`/clear`/compaction — read in full
  below under Security review.
- `.opencode/plugins/godot-prompter.js` — an OpenCode-only plugin (not loaded by Claude Code); reads
  its own `SKILL.md` file and prepends it to the first chat message. No network, no `fs` writes,
  no `exec`/`spawn` — read in full, confirmed.
- `.claude/settings.json` at the repo root registers a `PostToolUse` hook
  (`node scripts/hooks/validate-skill-on-edit.mjs` on Edit/Write) — **this is GodotPrompter's own
  contributor tooling for editing GodotPrompter itself**, scoped to that repo's dev workflow. It is
  not part of what `/plugin install` ships into a consumer project (the installable plugin content
  is `skills/`, `hooks/`, `agents/`, the manifests — `SECURITY.md` enumerates exactly this set, see
  below), so it does not land in `D:\Gamedev\.claude\settings.json`. Worth naming so it isn't
  mistaken for something the plugin installs elsewhere.
- `scripts/validate-skills.mjs`, `scripts/bump-version.mjs`, `scripts/count-tokens.mjs`,
  `scripts/fixtures/*` — again repo-maintenance/CI tooling for GodotPrompter's own release process,
  not something a consumer project runs.
- `.github/workflows/plugin-scan.yml` — CI-only (not shipped to consumers): runs a third-party
  plugin security scanner (`hashgraph-online/ai-plugin-scanner-action`, the check used by the
  `awesome-ai-plugins` listing) on every push/PR, `min_score: 80`, `fail_on_severity: high`.
- `.claude-plugin/plugin.json` / `marketplace.json` — MIT, version 1.13.3, marketplace name
  `godot-prompter-marketplace`, plugin name `godot-prompter`.

### 2. Maintenance

`gh api`: created 2026-04-03, **pushed 2026-09-16** (yesterday relative to today, 2026-09-17), 1
open issue, **731 stars**, not archived. 148 commits total; commits/month over the last year:
2026-05: 15, 06: 30, 07: 90, 08: 3, 09: 10 (still building as of the last commit, dated
"2026-09-16 … feat(validator): catch text the plugin scanner flags before a push"). By a wide
margin the most actively maintained candidate found. Names Godot 4.3+ as its floor and tracks
specific version deltas explicitly, e.g. `docs/superpowers/notes/2026-07-05-godot-4.7-deltas.md`
and `skills/3d-essentials/references/godot-4.7-additions.md` — content has been updated for/around
Godot 4.7, unlike every other candidate.

### 3. Licence

MIT.

### 4. Godot 4.7 compatibility

Generic `godot --headless ...` invocations throughout (no hardcoded platform path or executable
name), explicit 4.7-version-aware content (above), and the hook itself is unusually careful about
Windows specifically (see next section) — most Windows-aware of all candidates.

### 5. Security review — the SessionStart hook, read in full

This is the one candidate with something that runs **without explicit invocation**, so it gets the
closest read. I read `hooks/session-start` (296 lines) end to end, plus `hooks/run-hook.cmd`,
`hooks/hooks.json`, and `SECURITY.md`.

**What it does, verified against the code, not the docs:**
1. Fires only if `project.godot` is found within 4 levels up from CWD, or up to 3 levels down from
   the session root — otherwise it's a silent no-op (`[ -n "${PROJECT_ROOT:-}" ] || exit 0`).
2. **Reads** `project.godot`'s `config/features` line (regex/grep only) to report the Godot
   version/renderer/C# usage back to the agent as injected context.
3. **Reads** a small per-project state file at `~/.godot-prompter/state/<sha256-of-project-path>.json`
   (created outside `D:\Gamedev`, under the user's home directory) to check whether "mentor mode"
   is on, and whether the user previously declined an offer (see next point).
4. **Reads** the project's own instruction files (`CLAUDE.md`, `AGENTS.md`, `.claude/rules/`, etc.)
   only to check for a `## GodotPrompter` heading, to decide whether to *propose* — not perform —
   adding a short routing note.
5. The hook script itself performs **no writes**. It can tell the agent, in the injected context, a
   path under `~/.godot-prompter/state/` where the agent may *later* record "user declined the
   CLAUDE.md-section offer" or "mentor mode is on" — but only as a consequence of explicit user
   consent surfaced in that same turn ("Offer once, and only with the user's agreement… Do not add
   it silently."). This is a real "write outside the project directory" pathway even though it's
   consent-gated and limited to a tiny preference blob — flagging it per the task's instruction to
   flag anything writing outside the project directory, while noting the nuance that the *hook
   process* itself is read-only; the write, if it ever happens, is a follow-on agent action gated
   on user consent.
6. **No network call anywhere in the file** (grepped for `curl|wget|https?://` — the only URL hit
   is a code comment crediting the source of a technique, `https://github.com/obra/superpowers`,
   not a fetch). No credential/token/SSH-key reads — the string "token" appears only in
   `config/features` tokenizing logic (splitting the Godot features array), not an auth token.
7. Output is a single JSON blob (`hookSpecificOutput.additionalContext`) — the standard Claude Code
   SessionStart hook contract, not something unusual.

`SECURITY.md` independently discloses this exact scope:

> "`hooks/` — the SessionStart hook … It runs when a session starts, resumes, is cleared, or is compacted, and does nothing outside a Godot project. It writes no files. It reads: `project.godot` … the project's agent instructions files … a per-project state file under `~/.godot-prompter/state/`."

(Read literally, "It writes no files" describes the hook script's own behavior accurately — the
write path is the agent's, consent-gated, as above — worth the designer's attention as a minor
imprecision in otherwise unusually thorough self-disclosure, not a discrepancy that changes the
risk picture.)

**Verdict:** this is an auto-running hook, which the task asks me to flag, and I am flagging it —
but it is read-mostly, localhost-only (no network at all), touches no credentials, and its one
possible external write is a tiny, disclosed, consent-gated preference file outside the project
directory, not inside it. It does not meet the bar the task sets for automatic rejection (no
non-localhost network call, no credential/token/SSH read, no curl-pipe-to-shell, and its only
"write outside the project" path is documented, gated on explicit consent, and about a 200-byte
preference blob, not project data). Compared with every other candidate, GodotPrompter is also the
only one with a `SECURITY.md`, a documented vulnerability-reporting channel, and CI that runs an
independent third-party plugin scanner on every push (scoring the repo 100/100 after hardening its
own GitHub Actions permissions — `CHANGELOG.md`'s Unreleased section documents pinning Actions to
commit SHAs and scoping `contents: write` to only the release job, specifically because the
marketplace-push token had been over-scoped). That is a materially stronger trust posture than any
other candidate evaluated, all of which ship equivalent or greater automation risk (Randroids-Dojo's
PlayGodot downloads a modified engine binary; several repos' CI workflows push to Vercel with
secrets) with no equivalent disclosure or independent scan.

### 6. Overlap with the configured MCP servers

None — purely advisory content plus one disclosed, narrow hook. It assumes no MCP server and no
editor bridge of its own; it is written to be paired with whatever tool-calling capability the host
already has (explicitly lists `godot-comprehensive`-style and `godot-coding-solo`-style tool
patterns as acceptable substitutes in its cross-tool docs), so it layers cleanly on top of this
project's two already-configured servers without competing with them.

### 7. Fit with the plan (P0.7 / docs/20)

- `skills/godot-testing/` explicitly covers gdUnit4 with a CLI invocation shape
  (`godot --headless -s addons/gdUnit4/GdUnitRunner.gd -- --testsuites res://tests --report-dir
  ./reports`) that differs from the CLI shape Randroids-Dojo's skill uses
  (`-s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --run-tests`) — these are two different GdUnit4
  CLI entry points from different GdUnit4 releases. **Whichever GdUnit4 version actually gets
  installed for the 4.7.1 project needs its CLI shape checked against its own current
  documentation before P0.7 is implemented** — neither skill's invocation should be trusted
  blindly. GodotPrompter explicitly notes the exit-code contract ("exits non-zero on failure"),
  which is exactly what the Harness check row of the Acceptance Test Matrix needs. Unlike
  Randroids-Dojo, it does **not** ship ready-made Python wrapper scripts (`run_tests.py`,
  `parse_results.py`) — it's prose/checklists only, so scriptable JUnit-XML→JSON/markdown parsing
  would have to be written by hand if wanted.
- **Genuine conflict risk with docs/20, found and worth flagging specifically:** the checklist in
  `skills/godot-project-setup/SKILL.md` recommends scaffolding these autoloads by default:
  > "Autoloads registered: `GameManager`, `EventBus`, `AudioManager`, `SaveManager`"
  `EventBus` matches docs/20's "State changes are announced through an `EventBus` Autoload using
  Signals" — good alignment on that one piece — but docs/20 also requires two more communication
  styles this generic skill doesn't model (typed **query** interfaces, e.g.
  `EntityRegistry.get_enemies_in_radius(...)`, and typed **command** interfaces, e.g.
  `Health.apply_damage(...)`), and this project has no `GameManager`, `AudioManager`, or
  `SaveManager` in its plan — it has project-specific systems (`PauseAuthority`, `SimClock`,
  `Pool`, `CombatStats`, `Inventory`, the container-node Scene Tree). If an agent followed this
  skill's generic checklist literally when scaffolding P0.2's project skeleton, it would introduce
  autoloads and a folder layout (`assets/scenes/scripts/resources/addons` or an
  `entities/levels/systems` split) that docs/20 and P0.2 do not call for. This is not a bug in the
  skill — it's a generic best-practices skill correctly behaving generically — but the designer
  should make sure the agent treats docs/20 as authoritative over this skill's defaults whenever
  they conflict, same as any other generic-knowledge skill.

---

## Reject

- **`Randroids-Dojo/Godot-Claude-Skills`** (the exact repo named in the task) — self-deprecated;
  its own `README.md` says the skill now lives at `Randroids-Dojo/skills`. Installing the named
  repo today gets a stale, superseded pointer. Use `Randroids-Dojo/skills` → `plugins/godot`
  instead if this family is chosen (see Candidate 1 above; not selected as primary — see
  Recommendation).
- **`alexmeckes/godot-claude-skills`** — disqualifying finding: 4 of its 5 skills
  (`godot-code-gen`, `godot-live-edit`, `godot-scene-design`, `godot-shader`) ship without the YAML
  frontmatter Claude Code requires to register a skill, confirmed by reading the raw files and
  matching against the repo's own open issue #2, unresolved for 6 months. This directly fails
  E0.2's stated verification bar ("the chosen skill appears in the skill list after a restart") for
  80% of the pack's content. Its one working skill (`godot-interactive`) additionally assumes a
  third MCP server (`alexmeckes/godot-mcp`) and an "AI Bridge" editor plugin this project does not
  have configured. No test-harness content at all.
- **`fenixnix/Godot-Skills`** — disqualifying finding: a two-commit, single-day (2026-03-15) repo
  never touched again in 6 months, thin content, partly non-English SKILL.md files, no
  test-harness content. Not a security concern (the one script is a benign demo), just too thin and
  stale to recommend over the alternatives found.
- **`gamedev-skills/awesome-gamedev-agent-skills`** — no disqualifying security or licence finding
  (Apache-2.0, clean, well-maintained, best 4.7-currency of any candidate on its export skill) —
  rejected specifically **as an answer to E0.2's testing requirement**: disqualifying finding is
  zero GdUnit4/test-harness content anywhere in the repo, so on its own it does not help satisfy
  P0.7. Worth keeping in mind later purely for its Godot pattern-reference content
  (`godot-gdscript`, `godot-resources`, `godot-physics`, etc.), but not as the E0.2 pick.
- **PlayGodot specifically** (whichever family it's read from) — disqualifying finding: requires a
  custom-built fork of the Godot engine (`Randroids-Dojo/godot`, automation branch) with no
  pre-built Windows binary, which conflicts with docs/20's pin of the stock
  `Godot_v4.7.1-stable_win64.exe`/`_console.exe` 4.7.1 executables. Reject this specific piece even
  if the rest of a Randroids-Dojo install is otherwise kept.

---

## Recommendation

**Primary: `jame581/GodotPrompter`.** It is the only candidate that is simultaneously (a) actively
and recently maintained (pushed yesterday, 148 commits, explicit Godot-4.7-era content, unlike
every other candidate which tops out at Godot 4.3 references), (b) fully functional for skill
discovery (all `SKILL.md` files carry correct frontmatter — verified directly, unlike alexmeckes'
broken 4/5), (c) covers the P0.7 GdUnit4/GUT testing requirement directly with CI and exit-code
guidance, (d) does not require a third MCP server, a custom Godot build, or any capability this
project doesn't already have configured, and (e) is the only candidate with a disclosed, narrow,
localhost/local-filesystem-only automatic hook, backed by a `SECURITY.md`, a real vulnerability
disclosure channel, and CI that runs an independent third-party security scanner — a materially
stronger transparency posture than any alternative, none of which document their own automation
risk at all.

No complementary skill is recommended as a second full install — nothing found adds enough that's
genuinely distinct to justify a second plugin's footprint (extra skill-list noise, in
GodotPrompter's case a second, unrelated auto-run hook if it also had one). The one piece of
another candidate worth keeping in reserve, not as an installed skill but as optionally hand-copied
tooling: Randroids-Dojo's three CLI helper scripts
(`plugins/godot/scripts/run_tests.py`, `export_build.py`, `parse_results.py` from
`Randroids-Dojo/skills`, **not** the deprecated repo) are individually clean (no security findings,
see Candidate 1 §5) and give scriptable JUnit-XML → JSON/markdown parsing that GodotPrompter's
prose-only testing skill doesn't provide. If P0.7's CI wiring later wants that, copy just those
three files by hand (adjusting `find_godot()`'s `which`-based lookup, or running them via Git Bash)
rather than installing the whole Randroids-Dojo plugin — that avoids both the stale
Godot-4.3-pinned CI examples and the PlayGodot/custom-fork content bundled with it.

### Exact commands (designer types these — the agent never runs `/plugin`)

```
/plugin marketplace add jame581/GodotPrompter
/plugin install godot-prompter@godot-prompter-marketplace
```

(If Claude Code resolves the plugin name unambiguously without the marketplace suffix,
`/plugin install godot-prompter` also works — the manifest's marketplace name is
`godot-prompter-marketplace`, plugin name `godot-prompter`, version 1.13.3 as of this review.)

Do **not** run `/plugin marketplace add Randroids-Dojo/Godot-Claude-Skills` (the repo the task
named) — it is deprecated and now just points elsewhere. If the designer wants the GdUnit4 helper
scripts anyway, they are a plain-folder copy, not a marketplace install: copy
`plugins/godot/scripts/*.py` from a clone of `https://github.com/Randroids-Dojo/skills` into
wherever the project keeps its own tooling (no existing `scripts/` folder under `D:\Gamedev` yet,
since only `phases/README.md` and `phases/LESSONS.md` exist there today).

### Verification plan

Single task to prove the skill works, once the E0.1 sandbox exists at
`D:\Gamedev\sandbox\connection_test` (it does not exist yet in this workspace):

1. Install per the commands above, then fully restart Claude Code (a new session, not `/clear`,
   since the plugin's skill registration needs a restart to pick up).
2. Confirm discovery: open the skill list (or ask "what skills do you have available") and check
   that `godot-prompter:godot-testing`, `godot-prompter:using-godot-prompter`, and at least a
   handful of the other 55 skills are listed. This alone would have failed for 4/5 of the
   alexmeckes pack, so it's a meaningful check, not a formality.
3. Confirm the SessionStart hook fires correctly and narrowly: start a session with CWD inside
   `sandbox/connection_test` (which must contain a `project.godot` for the hook to do anything —
   the E0.1 sandbox project satisfies this). Ask Claude what Godot version/renderer it detected;
   the answer should match the sandbox's actual `config/features` line in `project.godot`, proving
   the hook's read path works and, by omission, that it did *not* fire outside a Godot project (test
   this negative case too: start a session with CWD outside any Godot project and confirm no
   `<GODOT-PROJECT-CONTEXT>` context appears).
4. Prove the testing-fit claim end to end: using the `godot-testing` skill's own guidance, add one
   trivial gdUnit4 (or GUT — whichever the sandbox already has installed from E0.1, if either)
   test to the sandbox project, then run it headless via the **pinned executable**:
   `D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path
   D:\Gamedev\sandbox\connection_test -s <the test runner path the skill names> --run-tests` (or
   the equivalent `-- --testsuites` form for whichever GdUnit4 CLI shape the installed version
   actually uses — check it against the installed addon rather than trusting either skill's
   invocation literally, per the §7 caveat above).
5. **Pass looks like:** the skill appears in the post-restart skill list; the SessionStart hook
   correctly reports the sandbox's Godot version only when CWD is inside the sandbox and stays
   silent outside it; the trivial test runs headless and exits 0; deliberately breaking the
   assertion once and re-running shows a non-zero exit code and a failure message in stdout. That
   four-part result (list, hook scope, pass exit code, fail exit code) is what should be recorded
   in `docs/28.md` and Phase 0's `EXECUTION_LOG.md` per E0.2's deliverable — not attempted here
   since it requires the E0.1 sandbox, which this workspace does not have yet.
