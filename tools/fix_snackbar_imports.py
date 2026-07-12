#!/usr/bin/env python3
"""Fix snackbar_helper.dart import paths after migration."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "lib"
HELPER = ROOT / "src" / "utils" / "snackbar_helper.dart"


def correct_import(file_path: Path) -> str:
    if file_path.resolve() == HELPER.resolve():
        return ""
    rel = file_path.parent.relative_to(ROOT)
    if rel == Path("src/utils"):
        return "import 'snackbar_helper.dart';"
    # Count segments under src/ to reach src/
    parts = rel.parts
    if parts[0] != "src":
        raise ValueError(f"Unexpected path: {file_path}")
    ups = len(parts) - 1  # e.g. src/features/ai -> 2 ups to src
    prefix = "../" * ups
    return f"import '{prefix}utils/snackbar_helper.dart';"


def main() -> None:
    fixed = 0
    for path in sorted(ROOT.rglob("*.dart")):
        text = path.read_text(encoding="utf-8")
        if "snackbar_helper.dart" not in text:
            continue
        correct = correct_import(path)
        if not correct:
            continue
        new_text, n = re.subn(
            r"import\s+'[^']*snackbar_helper\.dart';",
            correct,
            text,
            count=1,
        )
        if n and new_text != text:
            path.write_text(new_text, encoding="utf-8")
            fixed += 1
            print(f"{path.relative_to(ROOT.parent)} -> {correct}")
    print(f"Fixed {fixed} import paths")


if __name__ == "__main__":
    main()
