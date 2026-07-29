#!/usr/bin/env bash
#
# route.sh — pick the best Claude model tier for a task and run Claude Code on it.
#
# This controls the model at INVOCATION time (the `claude --model` flag). It cannot
# change the model of an already-running interactive session — for in-session routing,
# use the model-router plugin's subagents instead.
#
# Tiers (aliases always resolve to the latest model in each tier):
#   quick    -> haiku            mechanical / low-stakes / high-volume
#   standard -> sonnet, medium   everyday coding, moderate reasoning
#   deep     -> opus,   high     architecture / hard debugging / long-horizon
#
# Usage:
#   route.sh [options] "<task description>"
#
# Options:
#   -t, --tier <quick|standard|deep>   Skip auto-classification; force a tier.
#   -p, --print                        Run headless (claude -p) and print the answer.
#                                      Default is to LAUNCH an interactive session.
#   -n, --dry-run                      Print the chosen tier/model/effort and exit.
#       --classifier-model <alias>     Model used to auto-classify (default: haiku).
#   -h, --help                         Show this help.
#
# Everything after the last option (or after `--`) is the task/prompt.
#
# Examples:
#   route.sh "rename userId to accountId across the repo"        # -> quick, launches session
#   route.sh -p "summarize what changed in the last commit"      # -> headless answer
#   route.sh -t deep "design a caching layer for the API"        # forced tier
#   route.sh -n "add a null check in parse()"                    # just show the pick

set -euo pipefail

VERSION="0.1.0"
CLASSIFIER_MODEL="haiku"
FORCED_TIER=""
PRINT=0
DRY_RUN=0

# Colors only when stderr is a terminal (keeps piped/logged output clean).
if [[ -t 2 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  C_QUICK=$'\033[32m'; C_STANDARD=$'\033[34m'; C_DEEP=$'\033[35m'
else
  BOLD=""; DIM=""; RESET=""; C_QUICK=""; C_STANDARD=""; C_DEEP=""
fi

die() { printf '%sroute.sh:%s %s\n' "$BOLD" "$RESET" "$1" >&2; exit 1; }

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

# --- parse args ---------------------------------------------------------------
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--tier)             FORCED_TIER="${2:-}"; shift 2 ;;
    -p|--print)            PRINT=1; shift ;;
    -n|--dry-run)          DRY_RUN=1; shift ;;
    --classifier-model)    CLASSIFIER_MODEL="${2:-}"; shift 2 ;;
    -V|--version)          printf 'claude-route %s\n' "$VERSION"; exit 0 ;;
    -h|--help)             usage 0 ;;
    --)                    shift; ARGS+=("$@"); break ;;
    -*)                    die "unknown option: $1 (try --help)" ;;
    *)                     ARGS+=("$1"); shift ;;
  esac
done

# Resolve the claude binary. It's often a shell alias (not visible to scripts), so fall back
# to the standard local install path.
CLAUDE_BIN="$(command -v claude 2>/dev/null || true)"
[[ -z "$CLAUDE_BIN" && -x "$HOME/.claude/local/claude" ]] && CLAUDE_BIN="$HOME/.claude/local/claude"
need_claude() { [[ -n "$CLAUDE_BIN" ]] || die "cannot find the 'claude' CLI (set CLAUDE_BIN or add it to PATH)"; }

TASK="${ARGS[*]:-}"
[[ -n "$TASK" ]] || die "no task given (try --help)"

# --- classify -----------------------------------------------------------------
CLASSIFY_PROMPT='You are a router. Classify the coding task below into exactly one tier and reply with ONLY that single word (quick, standard, or deep), nothing else.

quick    = mechanical, deterministic, low-stakes, high-volume: formatting, mechanical renames, single string/enum edits, boilerplate, running a known command, simple lookups.
standard = well-specified everyday coding with moderate reasoning and bounded scope: implement a specified feature, write tests, a straightforward bug fix, a focused refactor.
deep     = architecture/design, cross-cutting or large refactors, hard or underspecified debugging, security-sensitive changes, code review of nontrivial diffs, long-horizon multi-step work.

When unsure between two tiers, pick the higher one.

Task: '

classify() {
  local out
  # --print = headless, text output. A cheap model does the routing.
  out="$(claude -p --model "$CLASSIFIER_MODEL" --output-format text \
          "${CLASSIFY_PROMPT}${TASK}" 2>/dev/null \
        | tr '[:upper:]' '[:lower:]' | grep -oE 'quick|standard|deep' | head -n1 || true)"
  if [[ -z "$out" ]]; then
    printf 'standard'   # safe middle default if the classifier is unclear
  else
    printf '%s' "$out"
  fi
}

if [[ -n "$FORCED_TIER" ]]; then
  case "$FORCED_TIER" in quick|standard|deep) TIER="$FORCED_TIER" ;; *) die "invalid --tier: $FORCED_TIER" ;; esac
else
  TIER="$(classify)"
fi

# --- map tier -> model + effort ----------------------------------------------
case "$TIER" in
  quick)    MODEL="haiku";  EFFORT="";       TC="$C_QUICK";    ICON="⚡" ;;   # Haiku takes no --effort
  standard) MODEL="sonnet"; EFFORT="medium"; TC="$C_STANDARD"; ICON="⚙" ;;
  deep)     MODEL="opus";   EFFORT="high";   TC="$C_DEEP";     ICON="◆" ;;
esac

line="${TC}${BOLD}${ICON} ${TIER}${RESET}  ${DIM}model${RESET} ${MODEL}"
[[ -n "$EFFORT" ]] && line+="  ${DIM}effort${RESET} ${EFFORT}"
printf '%s\n' "$line" >&2
[[ "$DRY_RUN" -eq 1 ]] && exit 0

# --- run ----------------------------------------------------------------------
CMD=(claude --model "$MODEL")
[[ -n "$EFFORT" ]] && CMD+=(--effort "$EFFORT")
[[ "$PRINT" -eq 1 ]] && CMD+=(--print)

exec "${CMD[@]}" "$TASK"
