---
title: REM2-plugin
type: skill
language: none
category: [claude-plugin, codex-plugin]
author: Hyogeon Lee
year: 2026
dependencies: [Claude Code, Codex CLI, MATLAB MCP]
status: draft
tags: [plugin, skill, matlab, plotting]
related: ["[[plot-style]]", "[[figure-export]]", "[[comment-style]]", "[[frf-ms-design]]", "[[prompt-enhancer]]"]
---

# REM2 Plugin

An **unofficial** plugin providing consistent scientific/engineering plot styling for MATLAB, measured-FRF controller design, and model-specific prompt enhancement. It is NOT an official product of Yonsei University or the REM2 lab — it was built by a grad student who couldn't bear his juniors' daring figures and wanted to ease the pain, if only a little.

Claude Code and Codex CLI share the same skill source. 한국어 버전: [`README.md`](README.md)

## Structure

```
REM2-plugin/
  .claude-plugin/plugin.json       ← Claude Code manifest
  .codex-plugin/plugin.json        ← Codex manifest
  skills/
    plot-style/
      SKILL.md                     ← always-loaded common rules + case dispatch
      references/                  ← per-case rule modules (loaded on demand)
        time-series.md
        xy-plot.md
        3d-plot.md
        frequency-response.md
      examples/                    ← runnable MATLAB examples per case (before/after)
      evals/                       ← trigger / rule-application eval cases (+ inputs/)
    figure-export/
      SKILL.md                     ← journal-submission common rules + preset dispatch
      references/                  ← journal presets (ieee.md — default, elsevier.md)
      examples/                    ← single-panel + multi-panel (tiledlayout) examples
      evals/
    comment-style/
      SKILL.md                     ← concise comment rules (single-file skill, no references/)
      examples/                    ← before/after example
      evals/                       ← eval cases + inputs/ fixtures
    frf-ms-design/
      SKILL.md                     ← FRF loop-shaping conventions (plant model, structure rule, ZOH)
      references/                  ← Excel format + workflow order
      scripts/                     ← read → fit → design → analyze → plot pipeline
      examples/                    ← example workbooks + blank template
    prompt-enhancer/
      SKILL.md                     ← core invariant (transform only) + workflow + output rules
      agents/                      ← openai.yaml — OpenAI/Codex interface metadata
      references/                  ← command syntax, enhancement protocol, injection safety, model profiles, examples
        model-profiles/            ← fable-5 / gpt-5.5 / opus-4.8 / sonnet-5 / claude-general
        source-guides/             ← bundled copies of the official prompting guides used for design
      scripts/                     ← optional offline scaffold generator (never auto-run)
      evals/                       ← injection-resistance / no-execution / format eval cases
  README.md / README_EN.md
```

At the repository root, `.claude-plugin/marketplace.json` (Claude Code) and `.agents/plugins/marketplace.json` (Codex) register this plugin in each marketplace.

## Install

### Claude Code

```
/plugin marketplace add Hyogeon-Lee/REM2
/plugin install rem2@rem2-lab
```

Update: `/plugin marketplace update rem2-lab`

### Codex CLI

```
codex plugin marketplace add Hyogeon-Lee/REM2
codex /plugins
```

In the plugin directory (TUI) opened by `codex /plugins`, switch to the `rem2-lab` tab and install `rem2-plugin`. Refresh with `codex plugin marketplace upgrade rem2-lab`.

### ChatGPT (workspace skill)

Upload the per-skill zips under `dist/chatgpt/` (`plot-style.zip`, `figure-export.zip`, `comment-style.zip`, `frf-ms-design.zip`, `prompt-enhancer.zip`) — see [`../dist/chatgpt/README.md`](../dist/chatgpt/README.md) for the procedure.

## Included skills

| Skill           | Purpose                                                                                                                                                                                                                                                       | Status |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| `plot-style`    | Consistent scientific/engineering plot styling for MATLAB — common rules plus time-series / X–Y / 3-D / frequency-response modules, with runnable before/after examples                                                                                       | stable |
| `figure-export` | Journal-submission figure export — exact column-width sizing in cm, print-scale fonts, vector PDF via `exportgraphics`, grayscale-survivable curve discrimination (line styles + markers + grayscale check). IEEE Transactions (default) and Elsevier presets | stable |
| `comment-style` | Concise code-comment rules — algorithm-critical parts only: units, magic numbers, equation sources, sign conventions. English by default (Korean for code governed by the plotting skills)                                                                    | stable |
| `frf-ms-design` | Measured SISO FRF Excel → s-domain plant fit with explicit time delay (`tfest`) → automatic lag / lead-lag loop shaping → margin and step-response prediction. MATLAB only (no Simulink); format errors fail fast and are resolved interactively with the user | stable |
| `prompt-enhancer` | Rewrites rough prompts into model-specific, copy-paste-ready prompts (Fable 5 / GPT-5.5 / Opus 4.8 / Sonnet 5) — treats the raw prompt as untrusted data, never executes the task inside it, and reports neutralized injection attempts | stable |

The skills trigger automatically when writing or modifying plotting code. When you explicitly request Python (matplotlib, etc.), the rules are translated to their closest equivalents. plot-style governs what is inside the axes (labels, legends, limits); figure-export governs physical size, fonts, and the export itself — the two compose. frf-ms-design triggers on measured-FRF controller design requests; prompt-enhancer triggers on prompt-improvement requests or the `prompt-enhance --model <model>` command syntax.

## Notes

- Plugin skills use the standard Claude `name`/`description` frontmatter required for skill auto-discovery, separate from the lab vault frontmatter convention.
