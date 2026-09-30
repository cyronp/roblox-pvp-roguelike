"""Run upgrade logic with the official Luau CLI and small Roblox service fakes."""

import argparse
from pathlib import Path
import subprocess
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", default="luau", help="Path to the Luau CLI")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    fixtures, assertions = (root / "tests/Upgrades.spec.luau").read_text().split(
        "-- INSERT PROJECT MODULES HERE", 1
    )
    modules = [
        ("UpgradeConfig", "src/shared/UpgradeConfig.luau"),
        ("ExperienceConfig", "src/shared/ExperienceConfig.luau"),
        ("DamageStreakConfig", "src/shared/DamageStreakConfig.luau"),
        ("Upgrades", "src/server/Upgrades.luau"),
        ("Experience", "src/server/Experience.luau"),
        ("DamageStreak", "src/server/DamageStreak.luau"),
    ]
    source = fixtures
    for name, relative_path in modules:
        source += f'\nmodules.{name} = (function()\n'
        source += (root / relative_path).read_text()
        source += "\nend)()\n"
    source += assertions
    script_path = root / "tests" / f".upgrades-{uuid.uuid4().hex}.luau"
    try:
        script_path.write_text(source, encoding="utf-8")
        subprocess.run([args.luau, str(script_path)], check=True)
    finally:
        script_path.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
