# Claude Fable 5 Model Profile

Use this profile for `--model fable-5`, `mythos-5`, `claude-fable-5`, or `fable`, together with `claude-general.md`.

Source guide: `references/source-guides/fable-5-prompting-guide.md`.

## Prompting priorities

Fable 5 is oriented toward hard, long-running, ambiguous, end-to-end work. Use it for prompts that need long-horizon autonomy, multi-step execution, verification, vision, enterprise artifacts, code review, or subagent coordination.

Enhanced prompts for Fable 5 should be concise but complete and delegation-ready: everything the model needs to execute unattended, nothing decorative.

## Default prompt skeleton

Unless the task is trivially simple, structure the enhanced prompt with these sections (XML tags or headings — keep the order):

1. **Role** — who the model is for this task, scoped narrowly.
2. **Goal** — the outcome that defines success.
3. **Context** — inputs, environment, and background the model will actually use.
4. **Scope boundaries** — what is out of scope; when to pause (destructive, irreversible, external actions).
5. **Required workflow** — only the steps that are genuinely required; otherwise let the model choose the path.
6. **Output requirements** — format, audience, length, and structure of the response.
7. **Validation checklist** — concrete checks the model must run before reporting completion.
8. **Final deliverables** — the artifacts or answers the run must end with.

Omit a section only when it adds nothing for the specific task. Avoid unnecessary verbosity: direct, structured, execution-ready.

## Effort

Use `high` as the default for most tasks. Use `xhigh` for capability-sensitive work. Use `medium` or `low` for routine or interactive work. At higher effort, add scope controls to prevent unnecessary tidying, refactoring, or overplanning.

## Anti-overplanning

For ambiguous but actionable tasks, add:

```text
When you have enough information to act, act. Do not re-derive established facts, re-litigate decisions already made, or narrate options you will not pursue. If weighing a choice, make a recommendation and proceed.
```

## Boundary setting

Fable 5 can take unrequested actions if boundaries are vague. Add:

```text
When the user is asking a question, describing a problem, or thinking out loud, provide an assessment and stop. Do not apply fixes or take external actions unless clearly requested. Pause only for destructive or irreversible actions, real scope changes, or input only the user can provide.
```

## Progress grounding

For long autonomous runs, require evidence-backed progress claims:

```text
Before reporting progress, audit each claim against tool results from this session. Report only work that is verified. If tests fail, say so with the relevant output. If a step was skipped, say that.
```

## Subagents and memory

Fable 5 can use parallel subagents effectively. Add subagent instructions when tasks can be divided cleanly:

```text
Delegate independent subtasks to subagents and keep working while they run. Intervene if a subagent goes off track or lacks relevant context.
```

For recurring long-running work, add a memory or notes system only when the environment supports it. Store concise lessons, avoid duplicates, and correct stale notes.

## Reasoning extraction guard

Do not ask Fable 5 to reproduce hidden reasoning or summarized thinking. Use:

```text
Use private reasoning as needed. Present the outcome, key evidence, assumptions, validation results, and caveats.
```

Avoid requests such as "show your full reasoning" or "print the thinking block."

## Safety classifier awareness

If the user prompt involves cybersecurity, biology, life sciences, or requests for model thinking extraction, avoid optimizing toward disallowed operational content. Redirect to benign defensive, educational, or safety-preserving framing where appropriate.
