---
title: REM2-plugin
type: skill
language: none
category: claude-plugin
author: Hyogeon Lee
year: 2026
dependencies: [Claude Code, MATLAB MCP]
status: draft
tags: [plugin, skill, matlab, plotting]
related: ["[[plot-style]]"]
---

# REM2 Plugin

An **unofficial** plugin that applies consistent scientific/engineering plot styling to MATLAB code. It is NOT an official product of Yonsei University or the REM2 lab — it was built by a grad student who couldn't bear his juniors' daring figures and wanted to ease the pain, if only a little.

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
        time_series_example.m
        xy_plot_example.m
        three_d_plot_example.m
        frequency_response_example.m
        image_fig/                 ← PNGs the examples generate (before/after)
  README.md / README_EN.md
```

At the repository root, `.claude-plugin/marketplace.json` (Claude Code) and `.agents/plugins/marketplace.json` (Codex) register this plugin in each marketplace.

## Install

### Claude Code

```
/plugin marketplace add Hyogeon-Lee/REM2
/plugin install REM2@rem2-lab
```

Update: `/plugin marketplace update rem2-lab`

### Codex CLI

Add this repository through Codex's plugin marketplace command, then install `rem2-plugin`.

### ChatGPT (workspace skill)

Upload `dist/chatgpt/plot-style.zip` — see [`../dist/chatgpt/README.md`](../dist/chatgpt/README.md) for the procedure.

## Included skills

| Skill | Purpose | Status |
|---|---|---|
| `plot-style` | Consistent scientific/engineering plot styling for MATLAB — common rules plus time-series / X–Y / 3-D / frequency-response modules, with runnable before/after examples | stable |

The skill triggers automatically when writing or modifying plotting code. When you explicitly request Python (matplotlib, etc.), the rules are translated to their closest equivalents.

## Roadmap (next draft candidates)

- `matlab-analysis` — data analysis / signal processing scaffolds using the MATLAB MCP
- `em-design-maxwell` — ANSYS Maxwell/AEDT IronPython scripting
- `control-design` — TF/state-space, Bode/Nyquist/step tuning, PID/loop-shaping
- `manufacturing` — manufacturing workflow helpers

## Notes

- Plugin skills use the standard Claude `name`/`description` frontmatter required for skill auto-discovery, separate from the lab vault frontmatter convention.
