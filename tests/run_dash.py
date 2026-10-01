"""Run dash rules and server lifecycle checks with small Roblox service fakes."""

import argparse
from pathlib import Path
import subprocess
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", default="luau", help="Path to the Luau CLI")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    fixtures, assertions = (root / "tests/Dash.spec.luau").read_text().split(
        "-- INSERT PROJECT MODULES HERE", 1
    )
    source = fixtures
    for name, relative_path in [
        ("DashConfig", "src/shared/DashConfig.luau"),
        ("DashCharges", "src/server/DashCharges.luau"),
        ("DashServer", "src/server/Dash.server.luau"),
    ]:
        source += f"\nmodules.{name} = (function()\n"
        source += (root / relative_path).read_text()
        source += "\nend)()\n"
    source += assertions
    script_path = root / "tests" / f".dash-{uuid.uuid4().hex}.luau"
    try:
        script_path.write_text(source, encoding="utf-8")
        subprocess.run([args.luau, str(script_path)], check=True)
    finally:
        script_path.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
