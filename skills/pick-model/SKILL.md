---
name: pick-model
description: Use when deciding which Claude model a task should run on, when asked to pick/route/choose a model, or before starting a chunk of work whose cost-vs-quality tradeoff matters. Routes self-contained sub-work to the quick/standard/deep model-pinned subagents and advises on `/model` for the main session.
---

# Picking the best model for the task

Match the task to the cheapest model that will still do it well. Spending Opus on a
mechanical rename wastes money and time; spending Haiku on an architecture decision produces
a confident wrong answer. This skill picks the tier (and effort) and then acts on it.

## How model selection actually works here (read first)

You **cannot** switch the main session's model yourself — `/model` is a user action, and hooks
can't route models. The one lever you control is **subagents**: dispatch a self-contained
sub-task to a model-pinned subagent via the Task tool. So there are exactly two moves:

- **Delegate** — the work is a self-contained sub-task → dispatch the matching subagent
  (`quick` / `standard` / `deep`). This genuinely runs that sub-task on the chosen model.
- **Advise** — the *whole session's* work belongs on a different tier → tell the user which
  `/model <tier>` to run and why. You can't do it for them.

Default to **delegate** when the task is separable; **advise** when it defines the session.

## The tiers

Always use the **aliases** `haiku` / `sonnet` / `opus` (and subagents `quick` / `standard` /
`deep`) — an alias always resolves to the *latest* model in its tier, so you never pin a stale
version. The "Currently" column is informational and will drift; the routing logic never
depends on the exact version.

| Tier | alias · subagent | Currently | Relative cost | Use for |
|---|---|---|---|---|
| Quick | `haiku` · `quick` | Haiku 4.5 | $ (cheapest) | mechanical, deterministic, low-stakes, high-volume |
| Standard | `sonnet` · `standard` | Sonnet 5 | $$ | everyday coding, moderate reasoning, well-specified |
| Deep | `opus` · `deep` | Opus 4.8 | $$$ | architecture, hard/underspecified debugging, review, long-horizon |

`opus` is Claude Code's default main model. Route *down* to save cost/latency, or *up* when the
work genuinely needs it.

## Decision rubric

Score the task on these signals; the highest-firing signal wins.

**→ Quick (Haiku)** when the task is:
- purely mechanical: formatting, mechanical rename, single string/enum edit, boilerplate
- a known command to run + report output
- a simple lookup / "where is X" with an obvious answer
- high-volume and individually low-stakes (bulk apply the same trivial edit)

**→ Standard (Sonnet)** when the task is:
- everyday coding you could hold in your head: implement a *well-specified* feature, write
  tests, a straightforward bug fix, a focused single-concern refactor
- moderate reasoning, bounded scope, low blast radius

**→ Deep (Opus)** when the task involves any of:
- **design / architecture** or a cross-cutting change touching many files
- **hard or underspecified debugging** (root cause unknown, intermittent, "it's weird")
- **security-sensitive** or hard-to-reverse changes
- **code review** of nontrivial diffs
- **long-horizon autonomous** multi-step work, or a large context to reason over

### Tie-breakers (apply after the base pick)

- **High cost-of-error** (production, security, hard to undo) → bump up one tier.
- **Cost-sensitive + bulk + reversible** → start at Quick; escalate only on failure.
- **Latency-critical + low-stakes** → prefer Quick.
- **Genuinely unsure between two tiers** → pick the higher one *once*, and note it — a wrong
  cheap answer usually costs more than the tier difference.

## Effort (second lever, orthogonal to model)

Set effort on the subagent / recommend it alongside `/model`:

- **Quick / Haiku:** no effort setting (the current Haiku tier does not support `effort`).
- **Standard / Sonnet:** `medium` default; `high` when the task is reasoning-heavy but still
  Sonnet-appropriate.
- **Deep / Opus:** `high` default; `xhigh` (the ceiling) for coding/agentic work and the
  hardest reasoning — Claude Code's own default.

A cheaper model at higher effort often beats a pricier model at low effort — reach for the
effort lever before the model lever when the task is borderline.

## Act on the pick

1. **Self-contained sub-task → delegate.** Dispatch the matching subagent with the Task tool
   (`subagent_type: quick | standard | deep`). Give it the full task spec up front; for `deep`
   long-horizon work, state the goal and constraints in one shot. Relay its result.
2. **Whole-session direction → advise.** Say: *"This session is mostly &lt;kind of work&gt; —
   consider `/model &lt;tier&gt;`"* (+ effort). Don't nag; recommend once.
3. **Mixed session → stay on the default (Opus) and delegate the cheap parts down.** Keep hard
   reasoning on the main thread; fan mechanical/bulk sub-tasks out to `quick`/`standard`.

## Cautions

- Don't route *down* to save money on anything with high cost-of-error — a subtly wrong result
  is the expensive outcome.
- Don't route *up* reflexively — Opus on well-specified everyday coding is mostly wasted spend;
  Sonnet 5 is near-Opus on coding.
- Switching the main model mid-session invalidates the prompt cache. Prefer delegating a
  sub-task to a subagent over asking the user to `/model` back and forth.
- Re-evaluate when the task changes character (a "quick edit" that turns into a redesign should
  move up a tier).
