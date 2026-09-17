# Lessons Carried Between Phases

Patterns that must inform later phases: recurring failure types, estimates that ran over, tests that turned out unpassable, tools that misbehaved.

| Date | Phase | Lesson | Applies to |
| --- | --- | --- | --- |
| 2026-09-18 | 00 | Prove a tooling config change works BEFORE applying it. Pinning both MCP servers to commit-pinned git specs looked correct and cost a whole session of dead tooling, because npx on this machine cannot install any git spec. The second attempt piped a real MCP initialize request into each built server first, then changed the config | Any phase that changes MCP config, engine version, addon versions, or the test harness |
| 2026-09-18 | 00 | npx cannot install commit-pinned git specs here (GitFetcher/Arborist error), and packages whose build/ is gitignored expose their binary only through the npm tarball. Pin by cloning at the commit and building locally, then run the built entry point with node | P0.5/docs/28, and any later tool pinning |
| 2026-09-18 | 00 | Everything under the Godot project root is a resource. The first export packed the built MCP servers into the game - 11.2 MB pck for an empty scene. .gdignore in a subtree makes the engine skip it entirely; export filters are the weaker fix | Every phase that exports a build, and anything that adds tooling under the project root |
| 2026-09-18 | 00 | Tools that generate Godot config cannot be trusted on version fields: the MCP generator writes config/features 4.4 regardless of the running engine, and that stray value also made a skill pack instruct every agent to target 4.4. Author project.godot by hand and assert the recorded value in a test | P0.6, P1.x, and any task that writes project settings |
| 2026-09-18 | 00 | A passing acceptance test proves nothing until it has been made to fail. The Settings check was deliberately broken twice (a layer name, then the features array) to confirm it reports the right failure and exits non-zero | Every task whose exit criterion names an acceptance test |
| 2026-09-18 | 00 | Spot-check subagent output rather than accepting the report. Reading 3 of 26 generated stubs found a rendering defect (F-01) that the agent's own summary described as complete | Every phase that delegates bulk writing or implementation to subagents |
| 2026-09-18 | 00 | Long-running subagents can stop without writing their report. Their working artifacts are still on disk and worth salvaging before re-running: the interrupted E0.1 agent had already proven the CLI rows and disproved the 4.7.1 headless stall bug | Any phase delegating long evidence-gathering runs |

Phase 00 is in progress; the rows above were captured as they occurred rather than at phase close, so they are available to phases 01 and 02 immediately.
