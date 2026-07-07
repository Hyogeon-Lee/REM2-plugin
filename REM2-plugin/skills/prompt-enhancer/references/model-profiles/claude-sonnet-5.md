# Claude Sonnet 5 Model Profile

Use this profile for `--model sonnet-5`, `claude-sonnet-5`, or `sonnet`, together with `claude-general.md`.

Source guide: `references/source-guides/sonnet-5-prompting-guide.md`.

## Prompting priorities

Sonnet 5 is strong for coding and agentic tasks. It follows instructions literally, especially at lower effort. State scope explicitly when an instruction should apply to every section, all files, all sources, or the whole answer.

## Effort and thinking

Sonnet 5 defaults to high effort and adaptive thinking. For hardest coding and agentic tasks, use `xhigh`. Use `medium` for cost-sensitive work, and `low` only for scoped, latency-sensitive tasks.

If the target prompt is for an API harness, include max-token headroom for high, xhigh, or max effort because adaptive thinking can consume output budget.

Do not request manual extended thinking budgets. Do not ask the model to reveal chain-of-thought.

## Tool use

Sonnet 5 is more agentic by default and tends to use tools and self-verification more readily. Still, define tool rules clearly:

```text
Use tools when they are needed to inspect files, verify current facts, run tests, render artifacts, or ground claims. Do not use tools only to add nonessential detail.
```

If thinking is disabled in the target environment, add explicit tool-use triggers for search, code inspection, and validation.

## Verbosity and output

Sonnet 5 adapts length to complexity. Add length or audience constraints when output length matters:

```text
Lead with the conclusion. Keep the answer concise unless the user asks for detailed reasoning or the task requires a full audit trail.
```

## Parameter constraints

For Sonnet 5 API prompts, do not recommend non-default `temperature`, `top_p`, or `top_k`; steer variety through prompt instructions instead.

## Design prompts

For frontend or visual design, specify concrete directions or ask the target model to propose distinct directions before implementation. Avoid generic anti-pattern instructions without a concrete alternative.

## Code review prompts

If review coverage matters, tell the model to report findings before filtering. Include confidence and severity so a later stage can rank issues.
