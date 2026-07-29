#!/usr/bin/env bash
#
# model-router — UserPromptSubmit hook: inject a per-prompt routing hint.
#
# HARD LIMIT: a hook cannot switch the session model (Claude Code exposes no such lever).
# This only *advises* — it nudges the agent to delegate a sub-task to the matching subagent,
# or to run /model for the whole session. Actual model change still happens via those.
#
# Design: a cheap keyword heuristic. No LLM call (that would add latency + tokens to every
# prompt and could recurse), no external deps (no node/jq — so it can't break like a
# node-PATH hook). Stays silent on the default tier to avoid per-prompt noise.

set -euo pipefail

# UserPromptSubmit passes the event as JSON on stdin; keyword-scan the raw blob (the only
# tier-ish words live in the user's prompt, not in the JSON keys).
input="$(cat 2>/dev/null || true)"
p="$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')"

tier="standard"; alias="sonnet"
if printf '%s' "$p" | grep -qE 'architect|design |redesign|refactor|debug|root cause|why (is|does|did)|failing|flaky|intermittent|security|vulnerab|\breview\b|cross-cutting|migrat|performance|race condition|deadlock|long-horizon|end.to.end'; then
  tier="deep"; alias="opus"
elif printf '%s' "$p" | grep -qE 'rename|reformat|format |lint|typo|whitespace|boilerplate|bump |comment|run the |list all|where is|find all|one.?liner'; then
  tier="quick"; alias="haiku"
fi

# Default tier = the main session's model already; emitting a hint would just be noise.
[[ "$tier" == "standard" ]] && exit 0

printf '[model-router] This looks like a "%s" task. If it is self-contained, delegate it to the `%s` subagent (model %s). If it defines the whole session, consider `/model %s`. (A hook cannot switch the model — this is a routing hint, not a change.)\n' \
  "$tier" "$tier" "$alias" "$alias"
