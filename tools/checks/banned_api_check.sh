#!/usr/bin/env bash
#
# Banned-API grep check (P1.1; MASTER_SDLC.md > Global Simulation Authority,
# paragraph 1; phases/PHASE_02_Technical_Foundations/PLAN.md > P1.1: "a grep
# check banning get_tree().create_tween() and create_timer() calls under
# the gameplay root").
#
# BANNED everywhere under the gameplay root: get_tree().create_tween() and
# get_tree().create_timer(). Neither scales with SimClock.time_scale nor
# reliably pauses with the gameplay tree (Global Simulation Authority,
# paragraph 1: "none of them scale with SimClock.time_scale or reliably
# pause with the gameplay tree").
#
# NOT banned by this check: Node.create_tween() -- i.e. a bare
# create_tween() call, on self or on some other Node, never routed through
# get_tree(). The master permits this explicitly, but ONLY for cosmetic
# animation ("Node.create_tween() is permitted for cosmetic animation only,
# since a tween bound to a paused node pauses with it"). Whether a given
# bare create_tween() call is cosmetic or is secretly driving gameplay
# timing is a semantic judgement a grep cannot make -- this check therefore
# encodes only the TEXTUAL distinction the master itself draws (SceneTree-
# anchored calls vs. the bare Node method), and leaves the cosmetic-vs-
# gameplay judgement call to the godot-code-review skill and human/reviewer
# review. This is recorded explicitly so nobody mistakes "this check is
# green" for "every create_tween() call here is definitely cosmetic."
#
# There is no Node-level equivalent of create_timer() (SceneTreeTimer only
# ever comes from SceneTree.create_timer()), so get_tree().create_timer()
# is unconditionally banned under the gameplay root with no cosmetic
# exception to carve out.
#
# Pure UI is exempt entirely (master: "All of these remain permitted in
# pure UI, which is not bound by SimClock"), so this check does not scan
# src/ui/ or scenes/ui/ (or any deeper .../ui/... path segment).
#
# "The gameplay root" is operationalised here as every .gd file under src/
# and scenes/ except anything under a ui/ directory -- the scene-tree
# container layout docs/20 > Scene Tree describes (Entities, Projectiles,
# Pickups, Effects, Environment, Audio) does not exist yet as of P1.1
# (scenes/main.tscn is a bare Node2D; P1.3 builds it), so this check cannot
# walk that node hierarchy. Source-directory scope is the closest static
# equivalent available now, and it widens automatically as later phases add
# gameplay directories (src/enemy, src/tower, ...) -- see the P1.1 evidence
# report for this call-out as an interpretation, not a restatement of
# something the documents state directly.
#
# Exit 0: zero banned calls found under an existing, non-empty scan scope.
# Exit 1: at least one banned call found (each printed as file:line:text).
# Exit 2: nothing to scan at all -- neither src/ nor scenes/ exists. This
# is a misconfiguration and must never be read as a silent pass (Phase 01
# lesson: a check that cannot fail is worse than no check).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 2

ROOTS=(src scenes)
PATTERN='get_tree\(\)[[:space:]]*\.[[:space:]]*create_tween[[:space:]]*\(|get_tree\(\)[[:space:]]*\.[[:space:]]*create_timer[[:space:]]*\('

existing_roots=()
for r in "${ROOTS[@]}"; do
	if [ -d "$r" ]; then
		existing_roots+=("$r")
	fi
done

if [ "${#existing_roots[@]}" -eq 0 ]; then
	echo "Banned-API check: NOTHING SCANNED -- none of (${ROOTS[*]}) exist under $PROJECT_ROOT. This is a misconfiguration, not a pass." >&2
	exit 2
fi

# Comments are stripped before matching (Phase 03 LEDGER F03-07). The check is
# about CALLS, not about text. A codebase that documents its own rules will
# quote the banned call in a comment - `src/tower/tower_visuals.gd` did exactly
# that, explaining which tween API to use and why, and turned a P1.1 exit
# criterion red. Rewording every such comment is a workaround that pushes the
# cost onto every future author; not reading comments is the fix.
#
# The strip is deliberately simple: drop from the first `#` to end of line. A
# `#` inside a string literal would also be dropped, which can only ever cause
# a FALSE NEGATIVE on a line that both contains a string with a `#` and makes a
# real banned call after it. That combination is vanishingly unlikely, and the
# failure direction is stated here rather than left for someone to discover.
strip_comments() { sed 's/#.*$//'; }

matches="$(grep -rnE --include='*.gd' "$PATTERN" "${existing_roots[@]}" 2>/dev/null   | grep -Ev '(^|/)ui/'   | while IFS= read -r line; do
      # line is path:lineno:text -- re-test only the text, comments stripped.
      text="${line#*:}"; text="${text#*:}"
      if printf '%s' "$text" | strip_comments | grep -qE "$PATTERN"; then
        printf '%s
' "$line"
      fi
    done)"

if [ -n "$matches" ]; then
	echo "Banned-API check: FAIL" >&2
	echo "$matches" >&2
	count="$(printf '%s\n' "$matches" | wc -l)"
	echo "Banned-API check: $count banned call(s) found under the gameplay root (${existing_roots[*]}, excluding ui/ directories)." >&2
	exit 1
fi

echo "Banned-API check: PASS (0 banned calls under ${existing_roots[*]}, excluding ui/ directories)"
exit 0
