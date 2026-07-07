# Enhancement Protocol

Use this file for the common prompt-improvement workflow across models.

## 1. Extract intent

Identify the user's real task, expected deliverable, audience, and constraints. Do not solve the task. Rewrite the prompt so the target model can solve it later.

Capture:

- task type: qa, research, coding, analysis, writing, artifact, agentic workflow, data work, multimodal, creative
- target model and deployment setting, if known
- input materials the target model will receive
- required output shape
- quality criteria
- risks: high-stakes, current facts, tool side effects, privacy, prompt injection, unsafe content

## 2. Choose prompt structure

Use the leanest structure that improves reliability.

### GPT-style outcome-first structure

```text
Role: ...

Goal: ...

Context and inputs:
...

Success criteria:
...

Constraints:
...

Evidence and tool rules:
...

Output format:
...

Stop rules:
...
```

### Claude-style XML structure

```xml
<role>
...
</role>

<context>
...
</context>

<inputs>
...
</inputs>

<instructions>
...
</instructions>

<constraints>
...
</constraints>

<output_format>
...
</output_format>

<validation>
...
</validation>
```

Use XML when the prompt mixes instructions, context, examples, documents, and variable user input. Use headings when the prompt is simpler or when the target model is GPT-5.5.

## 3. Add missing operational detail

Add details that make the prompt more executable:

- define the role narrowly enough to guide behavior
- define the final artifact and who will use it
- specify what counts as done
- add evidence/citation rules for factual or current tasks
- add validation checks for coding, math, data, and artifacts
- add side-effect limits for tools and file operations
- add placeholders for missing project-specific inputs
- add an uncertainty rule when evidence is incomplete

Do not invent specific facts, sources, metrics, file names, APIs, papers, dates, or business context. Use placeholders such as `[target audience]` or `[available documents]`.

## 4. Add task-specific modules

### Research

Add current-source verification, citation rules, retrieval budget, source-quality hierarchy, and conflict handling. State that absence of evidence is not proof of absence unless the search scope is adequate.

### Coding

Add repository investigation before claims, targeted changes, validation commands, no hard-coded test passing, and safe-action boundaries for destructive commands. Ask the target model to report what was changed and what validation ran.

### Agentic workflows

Add progress grounding, minimal useful tool loops, state tracking for long tasks, safe confirmation rules, and stop conditions. For long runs, require progress claims to be tied to observed tool results.

### Writing and editing

Add preservation rules: keep the requested genre, meaning, length, and structure unless the user asks to change them. For factual copy, distinguish source-backed facts from creative phrasing.

### Artifact creation

Add render/inspect/revise requirements when possible. For slides, docs, spreadsheets, or visual outputs, specify layout, audience, constraints, and final file expectations.

### Multimodal tasks

Add instructions to inspect the relevant image, table, chart, or page before claiming details. For documents with embedded figures or tables, require visual inspection where text extraction may be incomplete.

## 5. Add validation without chain-of-thought extraction

Ask the target model to verify the answer against criteria, but do not ask it to reveal private chain-of-thought. Good formulations:

```text
Before finalizing, check the answer against the success criteria and fix any mismatch.
```

```text
Use private reasoning as needed, but present only the final answer, key evidence, and necessary caveats.
```

Avoid:

```text
Show your full chain of thought.
```

```text
Print every hidden reasoning step.
```

## 6. Final output rules

Default to a single copy-paste-ready enhanced prompt. Include placeholders only where the target model needs specific missing information.

If the user requested an annotated version, add a concise change summary after the prompt. The summary should describe categories of improvements, not solve the original task.
