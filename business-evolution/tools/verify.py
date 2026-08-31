#!/usr/bin/env python3
"""Run every offline check for +1 Business Evolution.

    python3 tools/verify.py [--luau /path/to/luau]

Three suites:
  1. tests/run.luau   — config sanity + the first-session pacing simulation
  2. tools/map_spec   — builds all six floors against a mock Roblox API
  3. tools/stack_spec — executes the real multiplier stack

None of these need Roblox Studio, so they can run in CI or before a push.
"""
import argparse
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
sys.path.insert(0, str(TOOLS))
import build_harness  # noqa: E402


def run(cmd, cwd):
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return result.returncode, result.stdout + result.stderr


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", default=shutil.which("luau"), help="path to the luau CLI")
    parser.add_argument("--quiet", action="store_true", help="only print failures and the summary")
    args = parser.parse_args()

    if not args.luau:
        sys.exit("luau CLI not found — install it or pass --luau /path/to/luau")

    suites = []

    # 1. The plain-require suite runs straight from tests/.
    suites.append(("config + pacing", [args.luau, "tests/run.luau"], ROOT))

    # 2 & 3. The harnessed suites need bundling first.
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="be-verify-"))
    for name, spec in (("map geometry", "map_spec.luau"), ("multiplier stack", "stack_spec.luau")):
        bundle = tmp / spec.replace("_spec.luau", "_harness.luau")
        bundle.write_text(build_harness.build((TOOLS / spec).read_text()))
        suites.append((name, [args.luau, str(bundle)], ROOT))

    failures = []
    for name, cmd, cwd in suites:
        code, output = run(cmd, cwd)
        status = "PASS" if code == 0 else "FAIL"
        print(f"\n=== {name}: {status} ===")
        if code != 0:
            failures.append(name)
            print(output)
        elif not args.quiet:
            print(output.rstrip())
        else:
            print(output.strip().splitlines()[-1])

    print("\n" + "=" * 50)
    if failures:
        print("FAILED: " + ", ".join(failures))
        return 1
    print(f"All {len(suites)} suites passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
