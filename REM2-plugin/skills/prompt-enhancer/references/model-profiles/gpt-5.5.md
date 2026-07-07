# GPT-5.5 Model Profile

Use this profile for `--model gpt-5.5`, `gpt5.5`, `openai`, or `gpt`.

Source guide: `references/source-guides/gpt-5.5-prompting-guide.md`.

## Prompting priorities

GPT-5.5 generally benefits from outcome-first prompts that define the target result, available evidence, constraints, output format, and stopping conditions. Avoid inherited process-heavy prompt stacks unless each step is necessary.

Prefer short sections:

```text
Role: ...

Goal: ...

Success criteria:
...

Constraints:
...

Evidence and tool rules:
...

Output:
...

Stop rules:
...
```

## Style and collaboration

Define personality only when it matters to the product or output. Separate personality from collaboration style:

- personality: tone, warmth, formality, polish
- collaboration: when to ask, when to infer, when to verify, how proactive to be

Default to concise, direct, task-oriented wording. Use `text.verbosity` guidance if the target environment supports it; otherwise state the desired verbosity in the prompt.

## Tool-heavy and long-running tasks

For tasks likely to use tools or take multiple steps, add a brief preamble rule when user experience benefits:

```text
Before tool calls for a multi-step task, send a short user-visible update that acknowledges the request and states the first step. Keep it to one or two sentences.
```

For workflows that replay assistant items, preserve phase values:

```text
If manually replaying assistant items, preserve assistant phase values exactly. Use phase: "commentary" for intermediate user-visible updates and phase: "final_answer" for the completed answer.
```

Use this only when relevant to Responses-style applications.

## Retrieval budgets and citations

For factual, current, or source-grounded tasks, add a retrieval budget. Example:

```text
Start with one broad search using short, discriminative keywords. Search again only if the top results do not answer the core question, a required fact is missing, the user asked for exhaustive coverage, or the answer would otherwise contain an important unsupported factual claim. Cite factual claims precisely. If evidence is missing, say so instead of guessing.
```

For creative drafting, distinguish sourced facts from creative language. Do not invent concrete names, metrics, roadmap claims, dates, or capabilities.

## Assumptions and self-checking

GPT-5.5 prompts benefit from explicit rigor requirements. For analytical, factual, or high-stakes tasks, add:

```text
State your assumptions explicitly before relying on them. Verify each key claim against the provided evidence or retrieved sources. Before finalizing, self-check the answer against the success criteria and fix any mismatch. If a claim cannot be verified, label it as unverified instead of asserting it.
```

## Validation

Add explicit checks when validation is possible:

- coding: targeted tests, type checks, lint, build, smoke test
- artifacts: render, inspect for clipping/spacing/missing content, revise
- plans: trace requirements to components, files, APIs, validation, failure behavior, privacy/security
- factual answers: check citations support each non-obvious claim

## Stop rules

Add stopping rules that minimize unnecessary loops without reducing accuracy:

```text
Use the minimum evidence sufficient to answer correctly. After each tool result, ask whether the core request can now be answered with useful evidence and citations. If yes, answer; do not keep searching to improve phrasing or add nonessential examples.
```

## Avoid

- excessive process scripts such as "first do a, then b, then c" when the model can choose the path
- generic boilerplate unrelated to the task
- asking for hidden chain-of-thought
- unsupported current facts
- inventing missing project context
