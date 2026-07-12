#!/usr/bin/env python3
"""Migrate Material SnackBar usages to custom toast helpers (desktop)."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "lib"

SKIP_FILES = {"snackbar_helper.dart"}

ERROR_KEYWORDS = (
    "failed",
    "error",
    "could not",
    "couldn't",
    "unable",
    "invalid",
    "denied",
    "not available",
    "capture failed",
    "search failed",
    "no contact",
)

SUCCESS_KEYWORDS = (
    "success",
    "successfully",
    " updated",
    "saved",
    "copied",
    " sent",
    "deleted",
    "created",
    "marked",
    "added",
    "removed",
    "unarchived",
    "blocked",
    "linked",
    "logged out",
    "muted",
    "archived",
    "downloaded",
    "reported",
    "submitted",
    "donated",
    "pinned",
    "cleared",
)


def snackbar_import_for(path: Path) -> str:
    rel = path.relative_to(ROOT)
    ups = len(rel.parent.parts) - 1  # segments under lib/ to reach src/
    if rel.parent == Path("src/utils"):
        return "import 'snackbar_helper.dart';"
    prefix = "../" * ups
    return f"import '{prefix}utils/snackbar_helper.dart';"


def classify(text_expr: str, snackbar_body: str) -> str:
    has_red = "backgroundColor:" in snackbar_body and "red" in snackbar_body.lower()
    if has_red:
        return "showErrorToast"
    lower = text_expr.lower()
    if any(k in lower for k in ERROR_KEYWORDS):
        return "showErrorToast"
    if any(k in lower for k in SUCCESS_KEYWORDS):
        return "showSuccessToast"
    if "please" in lower or "select at least" in lower or "queued" in lower:
        return "showInfoToast"
    return "showInfoToast"


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


def extract_text_expr(snackbar_body: str) -> str | None:
    m = re.search(r"content:\s*((?:const\s+)?Text\()", snackbar_body)
    if not m:
        return None
    text_open = snackbar_body.find("(", m.start())
    text_close = find_matching_paren(snackbar_body, text_open)
    if text_close == -1:
        return None
    return snackbar_body[m.start() : text_close + 1].replace("content:", "", 1).strip()


def migrate_content(content: str) -> tuple[str, int]:
    replacements = 0
    start = 0

    while True:
        idx = content.find("showSnackBar", start)
        if idx == -1:
            break

        messenger_start = content.rfind("ScaffoldMessenger", 0, idx)
        if messenger_start == -1:
            start = idx + 1
            continue

        sb_open = content.find("(", idx)
        if sb_open == -1:
            start = idx + 1
            continue
        sb_close = find_matching_paren(content, sb_open)
        if sb_close == -1:
            start = idx + 1
            continue

        snackbar_arg = content[sb_open + 1 : sb_close].strip()
        snackbar_type = snackbar_arg
        if snackbar_type.startswith("const "):
            snackbar_type = snackbar_type[6:].strip()
        if not snackbar_type.startswith("SnackBar"):
            start = idx + 1
            continue

        snackbar_open = snackbar_arg.find("(")
        snackbar_close = find_matching_paren(snackbar_arg, snackbar_open)
        if snackbar_close == -1:
            start = idx + 1
            continue

        snackbar_body = snackbar_arg[snackbar_open + 1 : snackbar_close]
        text_expr = extract_text_expr(snackbar_arg)
        if not text_expr:
            start = idx + 1
            continue

        ctx_match = re.search(
            r"ScaffoldMessenger\.(?:of|maybeOf)\(([\s\S]*?)\)",
            content[messenger_start:idx],
        )
        if not ctx_match:
            start = idx + 1
            continue
        ctx_expr = ctx_match.group(1).replace("\n", " ").strip()
        ctx_expr = re.sub(r"\s+", " ", ctx_expr)

        method = classify(text_expr, snackbar_body)
        action_match = re.search(
            r"action:\s*SnackBarAction\s*\(",
            snackbar_body,
        )
        action_suffix = ""
        if action_match:
            action_open = snackbar_body.find("(", action_match.start())
            action_close = find_matching_paren(snackbar_body, action_open)
            if action_close != -1:
                action_suffix = f", action: {snackbar_body[action_match.start():action_close + 1].replace('action:', '', 1).strip()}"
        replacement = f"{ctx_expr}.{method}({text_expr}{action_suffix});"

        line_start = content.rfind("\n", 0, messenger_start) + 1
        indent = content[line_start:messenger_start]

        end = sb_close + 1
        while end < len(content) and content[end] in " \t":
            end += 1
        if end < len(content) and content[end] == ";":
            end += 1
        if end < len(content) and content[end] == "\n":
            end += 1

        content = content[:messenger_start] + indent + replacement + content[end:]
        replacements += 1
        start = messenger_start + len(indent + replacement)

    return content, replacements


def ensure_import(content: str, import_line: str) -> str:
    if "snackbar_helper.dart" in content:
        return content
    lines = content.splitlines(keepends=True)
    last_import = -1
    for i, line in enumerate(lines):
        if line.startswith("import "):
            last_import = i
    if last_import == -1:
        return import_line + "\n" + content
    lines.insert(last_import + 1, import_line + "\n")
    return "".join(lines)


def process_file(path: Path) -> int:
    original = path.read_text(encoding="utf-8")
    updated, count = migrate_content(original)
    if count == 0:
        return 0
    updated = ensure_import(updated, snackbar_import_for(path))
    path.write_text(updated, encoding="utf-8")
    return count


def main() -> int:
    total_files = 0
    total_replacements = 0
    remaining: list[str] = []

    for path in sorted(ROOT.rglob("*.dart")):
        if path.name in SKIP_FILES:
            continue
        text = path.read_text(encoding="utf-8")
        if "showSnackBar" not in text:
            continue
        count = process_file(path)
        if count:
            total_files += 1
            total_replacements += count
        if "showSnackBar" in path.read_text(encoding="utf-8"):
            remaining.append(str(path.relative_to(ROOT.parent)))

    print(f"Migrated {total_replacements} call sites in {total_files} files")
    if remaining:
        print(f"Remaining files with showSnackBar ({len(remaining)}):")
        for f in remaining:
            n = Path(ROOT.parent / f).read_text(encoding="utf-8").count("showSnackBar")
            print(f"  {f} ({n})")
    return 0 if not remaining else 1


if __name__ == "__main__":
    sys.exit(main())
