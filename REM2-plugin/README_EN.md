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
related: ["[[plot-style]]", "[[figure-export]]", "[[frf-ms-design]]", "[[git-commit]]", "[[conventional-commit]]", "[[commit-message-storyteller]]", "[[lean-comments]]", "[[github-release]]"]
---

# REM2 Plugin

An **unofficial** plugin providing consistent scientific/engineering plot styling for MATLAB and measured-FRF controller design. It is NOT an official product of Yonsei University or the REM2 lab — it was built by a grad student who couldn't bear his juniors' daring figures and wanted to ease the pain, if only a little.

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
    frf-ms-design/
      SKILL.md                     ← FRF loop-shaping conventions (plant model, structure rule, ZOH)
      references/                  ← Excel format + workflow order
      scripts/                     ← read → fit → design → analyze → plot pipeline
      examples/                    ← example workbooks + blank template
    git-commit/                    ← Conventional Commits commit workflow (ported from awesome-copilot, body verbatim)
    conventional-commit/           ← Conventional Commits message XML template (ported from awesome-copilot)
    commit-message-storyteller/    ← narrative commit-message rules (ported from awesome-copilot)
      references/                  ← Conventional Commits per-type examples + anti-patterns
    lean-comments/                 ← minimal source-comment rules, language-agnostic (ported from awesome-copilot)
    github-release/                ← SemVer + Keep a Changelog release workflow (ported from awesome-copilot)
      references/                  ← semver-rules.md, commit-classification.md
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

Upload the per-skill zips under `dist/chatgpt/` (`plot-style.zip`, `figure-export.zip`, `frf-ms-design.zip`) — see [`../dist/chatgpt/README.md`](../dist/chatgpt/README.md) for the procedure.

## Included skills

| Skill           | Purpose                                                                                                                                                                                                                                                       | Status |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| `plot-style`    | Consistent scientific/engineering plot styling for MATLAB — common rules (one figure, one tab per plot) plus time-series / X–Y / 3-D / frequency-response modules, with runnable before/after examples                                                                                       | stable |
| `figure-export` | Journal-submission figure export — exact column-width sizing in cm, print-scale fonts, vector PDF via `exportgraphics`, grayscale-survivable curve discrimination (line styles + markers + grayscale check). IEEE Transactions (default) and Elsevier presets | stable |
| `frf-ms-design` | Measured SISO FRF Excel → s-domain plant fit with explicit time delay (`tfest`) → automatic lag / lead-lag loop shaping → margin and step-response prediction. MATLAB only (no Simulink); format errors fail fast and are resolved interactively with the user | stable |
| `git-commit` | Conventional Commits commits — analyzes the diff for type/scope, generates the message, stages and commits. Ported from github/awesome-copilot (MIT), body verbatim | stable |
| `conventional-commit` | Conventional Commits message structure (type/scope/description/body/footer), examples, and validation rules as an XML template. Ported from awesome-copilot | stable |
| `commit-message-storyteller` | Narrative Conventional Commits messages that explain *why* — writes the message only, never runs git. Ported from awesome-copilot | stable |
| `lean-comments` | Minimal source-code comments — keep only non-obvious information the code cannot recover, language-agnostic. Ported from awesome-copilot | stable |
| `github-release` | End-to-end release with `gh` + `git` — diff since last tag → SemVer bump → Keep a Changelog → release branch and PR. Ported from awesome-copilot | stable |

The skills trigger automatically when writing or modifying plotting code. When you explicitly request Python (matplotlib, etc.), the rules are translated to their closest equivalents. plot-style governs what is inside the axes (labels, legends, limits); figure-export governs physical size, fonts, and the export itself — the two compose. frf-ms-design triggers on measured-FRF controller design requests. The five Git-convention skills are ported from [github/awesome-copilot](https://github.com/github/awesome-copilot/tree/main/skills) with their bodies unchanged (MIT, LICENSE in each skill folder); only the frontmatter was adjusted for Claude Code and Codex compatibility.

## Notes

- Plugin skills use the standard Claude `name`/`description` frontmatter required for skill auto-discovery, separate from the lab vault frontmatter convention.
