#!/usr/bin/env python3
"""Fail if any tracked file or folder name can't be checked out on Windows.

Windows (and GitHub Desktop on Windows) refuses paths with < > : " | ? * or control
characters, names ending in a dot or space, reserved names (CON, PRN, AUX, NUL,
COM1-9, LPT1-9), very long paths, and two names that differ only by upper/lower case.
Run: python3 tools/windows_names_check.py   (vault note 18 §4, CLAUDE.md "Repo mechanics")
"""
import re
import subprocess
import sys

BAD_CHARS = re.compile(r'[<>:"|?*\\\x00-\x1f]')
RESERVED = {"CON", "PRN", "AUX", "NUL"} | {f"{p}{i}" for p in ("COM", "LPT") for i in range(1, 10)}
MAX_PATH = 200  # leaves room for the clone folder under Windows' 260-character limit


def problem(segment):
    if BAD_CHARS.search(segment):
        return "has a character Windows forbids (< > : \" | ? * \\)"
    if segment.endswith((".", " ")):
        return "ends in a dot or space"
    if segment.split(".")[0].strip().upper() in RESERVED:
        return "is a reserved Windows name"
    return None


def main():
    out = subprocess.run(["git", "ls-files", "-z"], capture_output=True, check=True).stdout
    paths = [p.decode("utf-8", "replace") for p in out.split(b"\0") if p]
    errors, seen = [], {}
    for path in paths:
        for seg in path.split("/"):
            why = problem(seg)
            if why:
                errors.append(f"{path}: '{seg}' {why}")
                break
        if len(path) > MAX_PATH:
            errors.append(f"{path}: path is {len(path)} characters (keep under {MAX_PATH})")
        key = path.lower()
        if key in seen and seen[key] != path:
            errors.append(f"{path}: same name as {seen[key]} apart from upper/lower case")
        seen[key] = path
    for e in errors:
        print("Windows-unsafe name:", e)
    if errors:
        print(f"\n{len(errors)} name(s) to fix. Use ' - ' instead of ':' and drop '?'.")
        return 1
    print(f"OK: all {len(paths)} paths are safe on Windows.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
