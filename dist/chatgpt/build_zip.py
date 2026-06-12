#!/usr/bin/env python3
"""Build dist/chatgpt/<skill>.zip for each skill from the canonical source.

The ChatGPT workspace scanner needs `<skill>/SKILL.md` at the archive top
level with FORWARD-SLASH paths. Windows zip tools emit backslash separators,
which some extractors keep literally and then fail to find SKILL.md — so we
write arcnames explicitly here.

Rendered example PNGs/PDFs (examples/image_fig/) are excluded: they bloat the
package and ChatGPT cannot run MATLAB to use them anyway.

Usage:  python dist/chatgpt/build_zip.py
"""
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILLS_DIR = ROOT / "REM2-plugin" / "skills"
OUT_DIR = ROOT / "dist" / "chatgpt"
EXCLUDE_DIRS = {"image_fig"}

def build(skill: str) -> None:
    src = SKILLS_DIR / skill
    out = OUT_DIR / f"{skill}.zip"
    files = sorted(
        p for p in src.rglob("*")
        if p.is_file() and not (EXCLUDE_DIRS & set(p.relative_to(src).parts))
    )
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for p in files:
            arc = f"{skill}/" + p.relative_to(src).as_posix()  # forward slashes
            z.write(p, arc)
    print(f"wrote {out} ({out.stat().st_size} bytes, {len(files)} files)")
    for f in files:
        print(f"  {skill}/" + f.relative_to(src).as_posix())

def main() -> None:
    for skill_dir in sorted(SKILLS_DIR.iterdir()):
        if (skill_dir / "SKILL.md").is_file():
            build(skill_dir.name)

if __name__ == "__main__":
    main()
