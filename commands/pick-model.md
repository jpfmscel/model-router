---
description: Classify a task and route it to the best Claude model tier (quick/standard/deep).
argument-hint: <describe the task, or leave blank to use the current task>
---

Use the `pick-model` skill to choose the best model tier for this task:

**Task:** $ARGUMENTS

(If the task is blank, classify the work currently in progress.)

Then:

1. State the pick as one line: **`<tier>` (`<model>`, effort `<level>`) — `<one-sentence rationale>`**.
2. If the task is a self-contained sub-task, offer to delegate it to the matching subagent
   (`quick` / `standard` / `deep`) and do so on confirmation.
3. If it defines the whole session, recommend the `/model <tier>` the user should run — you
   cannot switch the main model yourself.

Keep it terse: the pick and the rationale, not a lecture.
