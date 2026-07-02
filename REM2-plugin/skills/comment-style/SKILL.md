---
name: comment-style
description: write or normalize code comments in a consistent, concise format — matlab by default, nearest equivalent when the user names another language. comments are english by default (korean only on explicit request), minimal, and only on algorithm-critical parts: units, magic numbers, equation sources, assumptions, sign/coordinate conventions. use whenever the user asks to add comments, clean up / unify / de-clutter comments, document code inline, or says 주석 — and when writing new matlab code that needs comments. never changes code logic. not for file headers / H1 lines / help blocks, README files, or prose documentation.
---

# Comment Style

## Priority

User instructions override every default here. Comments only: never change code logic, never rename variables, never reorder statements. Return the complete updated file (not a diff). Default language is MATLAB.

## Core principle — comment the why, not the what

A comment earns its place only when it says something the code cannot. If a comment restates the code (`i = i + 1; % increment i`), delete it. Narration ("First we compute...", "Now we loop over...") is noise — the reader can read code. Err on the side of fewer comments: a sparse, accurate comment set gets read and trusted; a dense one gets skimmed and ignored.

## What deserves a comment

Only these, and only when not already obvious from variable names:

1. **Units / physical meaning** at variable definition — `% air-gap flux density (T)`
2. **Magic numbers** — source or justification of the constant
3. **Equation / algorithm source** — `% Ref: Gieras (2010), Eq. 5.12`
4. **Assumptions, preconditions, valid ranges** — `% valid for g << rotor radius`
5. **Sign / coordinate / index conventions** — `% theta = 0 at d-axis, CCW positive`
6. **The key step of an algorithm** — one line on *why this approach*, at the single most critical point, not at every step

Everything else: no comment.

## Format

- **English by default.** Korean only when the user explicitly requests it — or when the `plot-style` / `figure-export` skill governs the code (their convention is Korean code comments; this skill's selection and format rules still apply). Identifiers, units, and technical terms stay English either way.
- One short phrase per comment, not a full sentence. No trailing period.
- Units in **parentheses**: `(T)`, `(mm)`, `(rad/s)` — never brackets.
- Inline comment for a single line (`x = ...;   % ...`); own-line comment above the block for a multi-line step.
- Within a contiguous block, align inline comments to a common column when it reads cleaner.

## Never

- Restate the code
- Change-history / author / date comments
- Decorative banners (`% ======== ... ========`)
- Explain commented-out dead code — flag it to the user instead
- Delete or move pragma comments — `%#ok<...>`, `%#codegen`, `%#function`, `%#exclude` are directives to tooling, not comments
- Remove existing `TODO`/`FIXME` markers unless the user asks
- Exceed roughly one comment per 4–5 lines of code — above that density, cut back to the critical ones

## MATLAB specifics

- **Never add or reformat a file header, H1 line, or help block.** Header format is handled by a separate formatter and may change. If the user explicitly asks for help text, ask which format before writing any.
- Deciding what counts as the help block is mechanical: if the first comment line after the `function` line is an H1 (function name + one-line summary), the entire contiguous comment block from there **is** the help block — leave it untouched, `help` prints it verbatim. Only when no H1 exists do the body rules apply to those leading lines (narration and restatement get deleted).
- Use `%%` section comments to structure scripts; short noun-phrase titles (`%% Parameter setup`), no sentence titles.
- When an `arguments` block exists, do not duplicate its type/size/default info in comments.
- In `classdef` files, comments attached to `classdef`, `properties` blocks, and individual property lines are surfaced by `help`/`doc` as class/property help — preserve them as-is. Apply the body rules only inside method bodies.

## Other languages

Rules translate directly when the user names another language: `#` for Python, `//` for C/C++, etc. Same selection criteria, same conciseness, same English default.

## Example

Before (over-commented):

```matlab
% calculate the angle for each slot
theta = 2*pi*(k-1)/numSlots; % angle calculation
% now we compute the flux using the cosine
flux(k) = Bg * A * cos(p*theta); % flux computation
```

After:

```matlab
theta = 2*pi*(k-1)/numSlots;         % slot angular position (rad)
flux(k) = Bg * A * cos(p*theta);
```

The flux line needs no comment — the names already say it. See `examples/before_after_example.m` for a full-function example.

## Self-check (one pass)

After editing, verify once:

1. Any comment that restates the code → delete
2. Any "What deserves a comment" item missing at a critical point → add one line
3. The diff touches comments (and comment-driven whitespace) only — zero logic changes
4. MATLAB + MCP available → run `check_matlab_code` to confirm the file still parses
