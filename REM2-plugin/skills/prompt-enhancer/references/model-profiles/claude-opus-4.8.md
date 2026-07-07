# Claude Opus 4.8 Model Profile

Use this profile for `--model opus-4.8`, `claude-opus-4.8`, or `opus`, together with `claude-general.md`.

Source guide: `references/source-guides/opus-4.8-prompting-guide.md`.

## Prompting priorities

Opus 4.8 is strong for long-horizon agentic work, knowledge work, vision, memory tasks, coding, and design. It follows instructions literally, especially at lower effort. State the scope of instructions explicitly.

## Effort and thinking

When the enhanced prompt is intended for an API or agent harness, include effort guidance if relevant:

- use `xhigh` for coding and agentic use cases
- use at least `high` for intelligence-sensitive work
- use `medium` or `low` for scoped, latency-sensitive work
- raise effort before adding elaborate reasoning instructions if the model is under-thinking

Opus 4.8 has adaptive thinking off unless configured. If the task requires multi-step reasoning, the enhanced prompt can say:

```text
This task requires multi-step reasoning. Use adaptive thinking if available, and reason carefully before finalizing. Present only the final answer, evidence, and caveats.
```

## Verbosity

Opus 4.8 calibrates response length to task complexity. If the user needs a predictable length, include explicit verbosity guidance:

```text
Provide concise, focused responses. Skip non-essential context and keep examples minimal unless they change the decision.
```

## Tool use

Opus 4.8 may favor reasoning over tools. For source-grounded, coding, or repository tasks, explicitly require tool use where needed:

```text
Do not speculate about files, APIs, current facts, or source documents. Inspect the relevant source before making claims.
```

For coding:

```text
Read the relevant files before proposing changes. Make the minimal targeted change. Run the most relevant validation available and report the result.
```

## Long-context and staged implementation

Opus 4.8 handles long-context, repository-scale work well. For large inputs, place longform documents or code near the top of the prompt and the instructions after them. For repository tasks, require inspection before claims and stage the work:

```text
Work in stages: (1) inspect the relevant parts of the repository and summarize what constrains the change, (2) state the implementation plan, (3) implement in reviewable increments, (4) validate each increment before moving on. Keep naming, style, and architecture consistent with the existing codebase across all edits.
```

## Subagents

Opus 4.8 tends to spawn fewer subagents by default. Add explicit guidance when parallel work is useful:

```text
Use subagents when fanning out across independent files, hypotheses, or research threads. Work directly for single-file edits or tasks that require one continuous context.
```

## Design prompts

When enhancing frontend or visual-design prompts, avoid generic instructions. Specify a concrete visual direction: palette, typography, spacing, motion, layout, and constraints. If the user wants variety, ask the target model to propose distinct directions before building.

## Code review prompts

If the task is code review, avoid vague filters such as "only important bugs." Prefer:

```text
Report every issue that could cause incorrect behavior, a test failure, data loss, security risk, or misleading result. Include confidence and severity. Omit pure style nits unless they obscure correctness.
```
