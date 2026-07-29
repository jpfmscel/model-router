# model-router (Claude Code plugin — draft)

Routes each task to the cheapest Claude model that will still do it well, and — because a
plugin **cannot** switch the main session's model — does it the one way that actually works:
by delegating self-contained sub-work to **model-pinned subagents**, and advising you on
`/model` for the main thread.

## What's in it

```
model-router/
├── .claude-plugin/plugin.json     manifest
├── skills/pick-model/SKILL.md     the decision rubric (task signals → tier + effort)
├── agents/
│   ├── quick.md                   model: haiku   — mechanical / low-stakes / high-volume
│   ├── standard.md                model: sonnet  (effort medium) — everyday coding
│   └── deep.md                    model: opus    (effort high)   — hard / long-horizon
└── commands/pick-model.md         /pick-model <task> — classify + offer to delegate
```

Model tiers use the **aliases** `haiku` / `sonnet` / `opus`, which always resolve to the latest
model in each tier — nothing is pinned to a version. Effort caps at `xhigh`. (Fast mode is
intentionally out of scope.)

## The four model-selection layers

Model selection in Claude Code is layered from coarse (one setting for everything) to fine
(per sub-task). Use the coarsest one that gives you what you want.

| Scope | Where | Effect |
|---|---|---|
| **Global default** | `~/.claude/settings.json` → `"model"` | one model for *all* new sessions. Set via `/model` → "save as default", or edit the file. |
| **Per-project default** | `<repo>/.claude/settings.json` → `"model"` | coarse routing by repo |
| **Per-launch** | `claude --model <alias>` or [`bin/route.sh`](bin/route.sh) | pick when you start a session / run a headless task |
| **In-session sub-work** | this plugin's `quick`/`standard`/`deep` subagents | route delegated work without touching the main session |

Precedence (highest wins): `--model` flag → `--settings` → project `settings.json` → user
`settings.json` → built-in default.

**A single global default is not routing** — it picks one model for everything. For *per-task*
selection you need the per-launch script (`--model`) or the in-session subagents. If you just
want "always use X", set the global `model` key and you're done — you don't need this plugin.

## bin/route.sh — the per-launch router (headless / scripting)

`bin/route.sh` classifies a task (cheaply, with `haiku`) and then launches Claude Code on the
chosen tier via `claude --model` (+ `--effort`). It controls the model **at invocation time**;
it cannot change a session that's already running — that's what the subagents are for.

```sh
bin/route.sh "rename userId to accountId across the repo"    # -> quick, launches a session
bin/route.sh -p "summarize the last commit"                  # -> headless answer, printed
bin/route.sh -t deep "design a caching layer for the API"    # force a tier
bin/route.sh -n "add a null check in parse()"                # dry-run: just show the pick
```

Flags: `-t/--tier`, `-p/--print` (headless), `-n/--dry-run`, `--classifier-model`, `-h/--help`.

## How it behaves

- **Self-contained sub-task** → Claude dispatches the matching subagent (`quick`/`standard`/
  `deep`), so that sub-task genuinely runs on the chosen model. The subagent descriptions are
  written so Claude auto-delegates by task type.
- **Whole-session direction** → the skill recommends the `/model <tier>` to run (it can't switch
  the main model for you).
- **On demand** → `/pick-model <task>` prints the pick + rationale and offers to delegate.

## The routing rubric (short version)

| Signals | Tier |
|---|---|
| mechanical, deterministic, low-stakes, high-volume | `quick` (haiku) |
| well-specified everyday coding, moderate reasoning, bounded scope | `standard` (sonnet, effort medium) |
| architecture, cross-cutting, hard/underspecified debugging, security, review, long-horizon | `deep` (opus, effort high→xhigh) |

Tie-breakers: high cost-of-error bumps **up** a tier; cost-sensitive + reversible + bulk starts
**down** and escalates on failure; when genuinely unsure, pick the higher tier once. Reach for
the **effort** lever before the model lever on borderline tasks. Full rubric in
[`skills/pick-model/SKILL.md`](skills/pick-model/SKILL.md).

## Install

**As a plugin** (keeps the pieces together): make this directory discoverable as a Claude Code
plugin — add it to a plugin marketplace you control, or drop it where your Claude Code plugin
config points. Then enable `model-router`. See `/plugin` in Claude Code for the current install
flow.

**Or drop the pieces in directly** (no plugin wrapper needed — they work standalone):

```sh
mkdir -p ~/.claude/skills ~/.claude/agents ~/.claude/commands
cp -r skills/pick-model      ~/.claude/skills/
cp    agents/*.md            ~/.claude/agents/
cp    commands/pick-model.md ~/.claude/commands/
```

Scope to one project instead by copying into that repo's `.claude/{skills,agents,commands}/`.

## Verify

- `/pick-model rename a variable across three files` → should recommend **quick**.
- `/pick-model design a caching layer for the API` → should recommend **deep**.
- Ask Claude to do a mechanical bulk edit → it should offer to delegate to the `quick` subagent.

## Notes / limitations

- No mechanism can change the **main** session model from inside a plugin — that's a user
  `/model` action by design. This plugin gets real routing only for delegated sub-work.
- Switching the main model mid-session invalidates the prompt cache — prefer delegating a
  sub-task over `/model` ping-pong.
- The `quick` tier omits `effort` (the current Haiku tier doesn't support it); `standard` and
  `deep` set `medium` / `high` and cap at `xhigh`.
