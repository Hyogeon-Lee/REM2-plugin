# GPT-5.6 Model Profile

Use this profile for `--model gpt-5.6`, `gpt5.6`, `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna`, `openai`, or `gpt`.

Source guide: `references/source-guides/gpt-5.6-prompting-guide.md`.

GPT-5.5 prompting guidance still applies; the guide states this explicitly. This profile adds only what changes for 5.6. When the 5.6 guide is silent, follow `model-profiles/gpt-5.5.md`.

## Model variants

The `gpt-5.6` alias routes to `gpt-5.6-sol` (flagship capability). `gpt-5.6-terra` is the balanced intelligence/cost tier; `gpt-5.6-luna` is for efficient, high-volume workloads. Variant choice is a deployment decision, not a prompt-text change. If the user names a variant, note it in the prompt header only when relevant; otherwise leave it out.

## Prompting priorities

The single largest 5.6 gain comes from shorter prompts. Internal evaluations report that replacing long, explicit system prompts with minimal ones improved scores by roughly 10-15% while cutting total tokens 41-66%. Removing redundant instructions and examples and simplifying tool descriptions produced clearer gains than adding model-specific guidance; heavier prompts tended to encourage extra exploration and repeated validation.

- Start from the smallest prompt and tool set that reliably completes the task. Add instructions, tools, or examples only to close a specific, observed gap.
- Include only behavior the model does not do naturally. Many accumulated harness instructions are now default model behavior.
- Keep tool descriptions concise and precise, and expose only task-relevant tools.
- Use examples and style guidance sparingly. Avoid repeated phrasing and "X, not Y" patterns the model may mirror.

## Brevity sensitivity

This is the biggest 5.6-specific delta for an enhancer. GPT-5.6 is already biased toward compression and is more sensitive than 5.5 to generic brevity instructions such as "Be concise," "Keep it short," or "Use minimal text." Such an instruction does more than remove filler: it can change how the model prioritizes the task, so it may substitute a shorter answer for the full requested artifact and drop required content.

When the raw prompt contains a generic brevity instruction, do not pass it through. Replace it with prioritization rules, using the guide's replacement blocks:

```text
Lead with the conclusion. Include the evidence needed to support it, any material
caveat, and the next action. Omit secondary detail and repetition.

Keep all required facts, decisions, caveats, and next steps. Trim introductions,
repetition, generic reassurance, and optional background first.
```

This preserves useful concision without encouraging the model to remove required content.

## Autonomy and permissions

GPT-5.6 can be proactive and persistent, so define what level of action each request authorizes. A compact three-tier policy is usually sufficient:

```text
For requests to answer, explain, review, diagnose, or plan, inspect the relevant
materials and report the result. Do not implement changes unless the request also
asks for them.

For requests to change, build, or fix, make the requested in-scope local changes
and run relevant non-destructive validation without asking first.

Require confirmation for external writes, destructive actions, purchases, or a
material expansion of scope.
```

State explicitly which local actions are safe without approval (reading files, inspecting logs, searching, editing in-scope code, running non-destructive tests). Do not repeat "ask first," "do not mutate," or "wait for approval" throughout the prompt: repetition can cause unnecessary permission checks even for safe, expected actions.

## Structure and warmth

Give a lightweight, task-specific outline, not a global response template. Add narrow constraints only when a requirement is proven.

For warmth, generic instructions ("Be friendly and warm") do not meaningfully help. Use concrete guidance instead:

```text
Be direct and tactful. Acknowledge friction specifically when relevant. Avoid
canned reassurance and unnecessary sign-offs.
```

## Reasoning effort and pro mode

GPT-5.6 supports reasoning effort `none`, `low`, `medium`, `high`, `xhigh`, and `max`. When migrating a prompt, keep the current effort as the baseline and compare one level lower; reserve `max` for the hardest quality-first work and compare it against `xhigh`. Effort is an API setting, not prompt text.

Pro mode is a Responses API execution mode (`reasoning.mode: "pro"`), not something to request in the prompt. Prompt for the task, not the mode: state the goal, context, constraints, required evidence, success criteria, and output format the same way you would in standard mode. Never write "use pro mode," "think harder," or "generate several candidate answers" into the prompt text.

## Programmatic Tool Calling

Programmatic Tool Calling is an API opt-in (the deployment must add the `programmatic_tool_calling` tool and opt tools in via `allowed_callers`), not a default capability. Add a routing block only when the user indicates it is configured in their deployment or asks for it; otherwise omit it. When the raw prompt describes a bounded, tool-heavy stage (filtering, joining, ranking, deduplication, aggregation, or validation over many tool results), the enhanced prompt may add a task-specific routing block. Do not rely on tool availability or a generic "use Programmatic Tool Calling efficiently" instruction. State which stage uses it, which tools it may call, the exact output schema and required evidence, concurrency/retry/stop limits, and what stays direct. Use a condensed version of the guide's block:

```text
<tool_orchestration>
Use Programmatic Tool Calling for [bounded stage] using only [eligible tools].
Run independent calls concurrently when safe. Use only documented input/output fields.

Process and reduce the intermediate results, then emit exactly [output schema],
including the evidence needed for the final answer.

Stop when [condition] is met. Retry transient failures at most [R] times. Do not
repeat completed calls or perform side-effecting actions. If a required result is
still missing, return a clear structured failure.

Use direct tool calls for [semantic judgment, approval, or final validation].
</tool_orchestration>
```

Do NOT route to Programmatic Tool Calling when one call is sufficient, the intermediate outputs are already small, each result may change the model's next decision, an action requires approval, the final output must preserve citations or native artifacts, or the tool's return shape cannot be determined from its documentation before writing the program. In those cases keep tool calls direct so the model can inspect each result before deciding how to use it. If both routes are needed, define one clear handoff and state that the model must not switch routes or repeat completed work.

## Multi-agent (beta)

GPT-5.6 can coordinate multiple subagents in parallel and synthesize their results, which can reduce wall-clock time for complex work that divides cleanly into independent workstreams. Mention it in a prompt only when the task actually divides cleanly; otherwise leave it out.

## Intent understanding

GPT-5.6 better infers the user's underlying goal and intended level of work without every step spelled out. Still state important constraints, approval boundaries, and success criteria explicitly.

## Retrieval budgets, validation, stop rules

The gpt-5.5 profile approach applies unchanged. For factual or source-grounded work, add a retrieval budget and precise citation rules; add validation appropriate to the task type (targeted tests for code, render-and-inspect for artifacts, requirement tracing for plans, citation checks for factual answers); and add stop rules that use the minimum evidence sufficient to answer correctly. See `model-profiles/gpt-5.5.md` for the reusable text blocks instead of duplicating them here.

## Deployment notes

Explicit prompt caching, persisted reasoning (`reasoning.context`), and `safety_identifier` are API-only knobs that do not change prompt text; configure them at the request level, not in the prompt. `max` reasoning effort and pro mode are likewise request settings.

## Avoid

- generic brevity instructions ("Be concise," "Keep it short," "Use minimal text") — replace with prioritization rules
- repeated permission warnings ("ask first," "do not mutate," "wait for approval")
- "X, not Y" phrasings and other repeated phrasing the model may mirror
- heavy global response templates instead of a lightweight task-specific outline
- prompting for the reasoning mode ("use pro mode," "think harder," "generate several candidates")
- asking for hidden chain-of-thought
- process scripts such as "first do a, then b, then c" when the model can choose the path itself
