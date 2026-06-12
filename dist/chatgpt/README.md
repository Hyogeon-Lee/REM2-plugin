# REM2 ChatGPT Workspace Skill Package

This directory contains the ChatGPT workspace skill distribution artifacts —
one zip per skill (`plot-style.zip`, `figure-export.zip`, `comment-style.zip`).

## Artifact

- Upload the zip of each skill you want to ChatGPT Skills.
- Each zip must contain `<skill>/SKILL.md` at the top level, with
  forward-slash paths (Windows zip tools emit backslash separators that some
  extractors keep literally — build with the script below, not Explorer).
- The zips are generated from `REM2-plugin/skills/<skill>/` by
  `build_zip.py`. Rendered example outputs (`examples/image_fig/`) are
  excluded — they bloat the package and ChatGPT cannot run MATLAB to use them.

## Upload

1. Open ChatGPT workspace skill management.
2. Select `Skills > New skill > Upload from your computer`.
3. Upload `dist/chatgpt/<skill>.zip`.
4. Wait for the scan to finish and confirm the skill is available.
5. Share or publish the skill according to workspace policy.

## Update

1. Edit the source skill in `REM2-plugin/skills/<skill>/`.
2. Run `python dist/chatgpt/build_zip.py` to recreate every zip.
3. Upload the new zip in ChatGPT workspace skill management.
4. Confirm the scan status and test the skill in ChatGPT.

The ChatGPT skill packages are derived artifacts. Keep the source of truth in
`REM2-plugin/skills/`.
