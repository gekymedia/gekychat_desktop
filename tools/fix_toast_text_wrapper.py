#!/usr/bin/env python3
"""Fix toast calls that incorrectly wrap message in Text(...)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "lib"

METHODS = (
    "showSuccessToast",
    "showErrorToast",
    "showInfoToast",
    "showWarningToast",
    "showSuccessSnackbar",
    "showErrorSnackbar",
    "showInfoSnackbar",
    "showWarningSnackbar",
)


def find_matching_paren(text: str, open_idx: int) -> int:
    depth = 0
    in_string = False
    string_char = ""
    i = open_idx
    while i < len(text):
        ch = text[i]
        if in_string:
            if ch == "\\":
                i += 2
                continue
            if ch == string_char:
                in_string = False
        else:
            if ch in "\"'":
                in_string = True
                string_char = ch
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    return i
        i += 1
    return -1


def fix_content(content: str) -> tuple[str, int]:
    fixes = 0
    for method in METHODS:
        needle = f".{method}(Text("
        start = 0
        while True:
            idx = content.find(needle, start)
            if idx == -1:
                break
            text_open = idx + len(needle) - 1  # points at '(' of Text(
            inner_close = find_matching_paren(content, text_open)
            if inner_close == -1:
                start = idx + 1
                continue
            # Check closing paren for toast method
            toast_close = inner_close + 1
            if toast_close >= len(content) or content[toast_close] != ")":
                start = idx + 1
                continue
            inner = content[text_open + 1 : inner_close]
            replacement = f".{method}({inner})"
            content = content[:idx] + replacement + content[toast_close + 1 :]
            fixes += 1
            start = idx + len(replacement)
    return content, fixes


def main() -> int:
    total = 0
    for path in sorted(ROOT.rglob("*.dart")):
        original = path.read_text(encoding="utf-8")
        if "Toast(Text(" not in original and "Snackbar(Text(" not in original:
            continue
        updated, count = fix_content(original)
        if count:
            path.write_text(updated, encoding="utf-8")
            total += count
            print(f"  {path.relative_to(ROOT.parent)}: {count}")
    print(f"Fixed {total} toast(Text(...)) wrappers")
    return 0


if __name__ == "__main__":
    sys.exit(main())
