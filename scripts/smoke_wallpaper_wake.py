#!/usr/bin/env python3
"""ADB smoke-check for video wallpaper rearm after TV sleep/wake."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from typing import Any


DEFAULT_PATTERNS = [
    "wallpaper_wake_rearm reason=android.intent.action.SCREEN_ON",
    "wallpaper_wake_rearm reason=android.intent.action.USER_PRESENT",
    "wallpaper_wake_rearm reason=android.intent.action.DREAMING_STOPPED",
    "wallpaper_wake_rearm reason=com.xiaomi.mitv.ACTION_SCREEN_ON",
    "wallpaper_wake_rearm reason=com.xiaomi.tv.ACTION_OPEN_CLOSE_SCREEN_SAVER",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Put the TV to sleep, wake it, and verify native video wallpaper "
            "wake rearm is logged. Device must already be on HOME with a video "
            "wallpaper and auto-resume enabled."
        ),
    )
    parser.add_argument("--device", help="ADB serial. Uses default device if omitted.")
    parser.add_argument(
        "--timeout-seconds",
        type=float,
        default=12.0,
        help="How long to wait for a wake rearm log after wake.",
    )
    parser.add_argument(
        "--sleep-seconds",
        type=float,
        default=3.0,
        help="How long to keep the TV sleeping before wake.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    adb(args.device, ["logcat", "-c"])
    adb(args.device, ["shell", "input", "keyevent", "KEYCODE_HOME"])
    time.sleep(1.5)
    adb(args.device, ["shell", "input", "keyevent", "KEYCODE_SLEEP"])
    time.sleep(args.sleep_seconds)
    adb(args.device, ["shell", "input", "keyevent", "KEYCODE_WAKEUP"])

    matched = wait_for_any_pattern(
        args.device,
        DEFAULT_PATTERNS,
        args.timeout_seconds,
    )
    report: dict[str, Any] = {
        "device": args.device or "<default>",
        "acceptedPatterns": DEFAULT_PATTERNS,
        "matchedLine": matched,
    }
    print(json.dumps(report, indent=2, ensure_ascii=False))

    if not matched:
        print(
            "ERROR: Did not observe native video wallpaper wake rearm. "
            "Make sure HOME is visible and video wallpaper auto-resume is enabled.",
            file=sys.stderr,
        )
        dump_logcat(args.device)
        return 1
    return 0


def wait_for_any_pattern(
    serial: str | None,
    patterns: list[str],
    timeout_seconds: float,
) -> str:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        log_output = adb(serial, ["logcat", "-d", "-v", "brief"])
        for line in log_output.splitlines():
            if any(pattern in line for pattern in patterns):
                return line
        time.sleep(0.6)
    return ""


def dump_logcat(serial: str | None) -> None:
    log_output = adb(serial, ["logcat", "-d", "-v", "brief"])
    print("--- logcat tail ---", file=sys.stderr)
    for line in log_output.splitlines()[-160:]:
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
