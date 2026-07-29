#!/usr/bin/env bash
#
# model-router — UserPromptSubmit hook.
#
# Injects a directive that triggers the `pick-model` skill on every prompt, so the skill's
# full rubric (not a keyword guess) selects the tier and routes. Deps-free: it prints a fixed
# string — no LLM call, no node/jq, nothing to break.
#
# HARD LIMIT: a hook cannot switch the session model. The skill acts on the pick by delegating
# a self-contained sub-task to the matching quick/standard/deep subagent, or by recommending
# /model for the whole session.

set -euo pipefail

cat >/dev/null 2>&1 || true   # drain the event JSON on stdin; the directive is fixed

cat <<'EOF'
Before acting on this request, use the pick-model skill to select the best Claude model tier for it, then route accordingly: delegate a self-contained sub-task to the matching quick/standard/deep subagent, or recommend `/model` if it defines the whole session. Route quietly — do the selection without narrating it, and only surface it when you actually delegate or recommend a switch. Skip routing entirely for trivial requests (greetings, one-word replies, confirmations).
EOF
