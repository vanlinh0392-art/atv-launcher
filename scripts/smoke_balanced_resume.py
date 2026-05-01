#!/usr/bin/env python3
"""ADB smoke-check for Balanced wallpaper resume on return to HOME."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from typing import Any


DEFAULT_PATTERN = "FLauncherRuntime wallpaper_rearm reason=app_resumed"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Background the launcher with Android Settings, return HOME, "
            "and verify the Balanced video rearm log appears."
        ),
    )
    parser.add_argument("--device", help="ADB serial. Uses the default device if omitted.")
    parser.add_argument(
        "--package",
        default="com.atv.launcher",
        help="Launcher package name.",
    )
    parser.add_argument(
        "--pattern",
        action="append",
        help=(
            "Log substring that must appear after the HOME return. "
            "Defaults to the Balanced rearm runtime log."
        ),
    )
    parser.add_argument(
        "--timeout-seconds",
        type=float,
        default=8.0,
        help="How long to wait for the expected log pattern.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    patterns = args.pattern or [DEFAULT_PATTERN]

    adb(args.device, ["logcat", "-c"])
    adb(args.device, ["shell", "input", "keyevent", "KEYCODE_HOME"])
    time.sleep(1.5)
    adb(args.device, ["shell", "am", "start", "-a", "android.settings.SETTINGS"])
    time.sleep(2.0)
    adb(args.device, ["shell", "input", "keyevent", "KEYCODE_HOME"])

    matched_lines = wait_for_patterns(args.device, patterns, args.timeout_seconds)
    report: dict[str, Any] = {
        "device": args.device or "<default>",
        "package": args.package,
        "patterns": patterns,
        "matchedLines": matched_lines,
    }
    print(json.dumps(report, indent=2, ensure_ascii=False))

    missing_patterns = [pattern for pattern in patterns if pattern not in matched_lines]
    if missing_patterns:
        print(
            "ERROR: Balanced resume smoke check did not observe all expected logs. "
            "Make sure the device is configured with Balanced mode and a video wallpaper.",
            file=sys.stderr,
        )
        dump_logcat(args.device)
        return 1
    return 0


def wait_for_patterns(
    serial: str | None,
    patterns: list[str],
    timeout_seconds: float,
) -> dict[str, str]:
    deadline = time.time() + timeout_seconds
    matched: dict[str, str] = {}
    while time.time() < deadline:
        log_output = adb(serial, ["logcat", "-d", "-v", "brief"])
        for line in log_output.splitlines():
            for pattern in patterns:
                if pattern in matched:
                    continue
                if pattern in line:
                    matched[pattern] = line
        if len(matched) == len(patterns):
            return matched
        time.sleep(0.6)
    return matched


def dump_logcat(serial: str | None) -> None:
    log_output = adb(serial, ["logcat", "-d", "-v", "brief"])
    print("--- logcat tail ---", file=sys.stderr)
    for line in log_output.splitlines()[-120:]:
        print(line, file=sys.stderr)


def adb(serial: str | None, command: list[str]) -> str:
    full_command = ["adb"]
    if serial:
        full_command.extend(["-s", serial])
    full_command.extend(command)
    completed = subprocess.run(
        full_command,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return completed.stdout


if __name__ == "__main__":
    raise SystemExit(main())
