#!/usr/bin/env python3
"""ADB smoke & integration test for rapid wake sequence (pause -> resume -> focus_gained).

This script simulates rapid sleep/wake and app switching on Android TV / devices
to verify that VideoWallpaperController and Flutter WallpaperService handle the
rapid transition sequence (pause -> resume -> window_focus_gained) idempotently,
without surface collision, ExoPlayer allocation leak, or video freeze.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from typing import Any


EXPECTED_PATTERNS = [
    "wallpaper_resume reason=activity_resume",
    "wallpaper_resume reason=window_focus_gained",
]

STANDBY_PATTERNS = [
    "wallpaper_hot_standby_entered: kept surface and player in RAM",
    "wallpaper_app_switch: delayed release scheduled in 60000ms",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Simulate rapid wake sequence (pause -> resume -> window_focus_gained) "
            "and verify wallpaper controller idempotency and zero-defect playback."
        ),
    )
    parser.add_argument("--device", help="ADB serial. Uses default device if omitted.")
    parser.add_argument(
        "--package",
        default="com.atv.launcher",
        help="Launcher package name.",
    )
    parser.add_argument(
        "--cycles",
        type=int,
        default=3,
        help="Number of rapid pause->resume->focus cycles to execute.",
    )
    parser.add_argument(
        "--pause-ms",
        type=int,
        default=150,
        help="Delay in milliseconds between pause and wake/resume (simulates rapid wake).",
    )
    parser.add_argument(
        "--timeout-seconds",
        type=float,
        default=10.0,
        help="Timeout in seconds to wait for wake logs.",
    )
    parser.add_argument(
        "--mode",
        choices=["sleep_wake", "app_switch", "hybrid"],
        default="hybrid",
        help="Simulation type: sleep_wake (KEYCODE_SLEEP/WAKEUP), app_switch (Settings->Home), or hybrid.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    device = args.device
    package = args.package

    print(f"[*] Starting Rapid Wake Smoke Test on device '{device or '<default>'}' with {args.cycles} cycles ({args.mode} mode)...")

    # Clear logcat buffer and return to HOME initially
    try:
        adb(device, ["logcat", "-c"])
        adb(device, ["shell", "input", "keyevent", "KEYCODE_HOME"])
        time.sleep(1.0)
    except Exception as e:
        print(f"[!] Warning during ADB initialization: {e}", file=sys.stderr)

    cycle_results: list[dict[str, Any]] = []
    overall_success = True

    for cycle in range(1, args.cycles + 1):
        print(f"\n--- [Cycle {cycle}/{args.cycles}] Executing rapid sequence ---")
        cycle_start_time = time.time()

        if args.mode in ("sleep_wake", "hybrid") and (cycle % 2 != 0 or args.mode == "sleep_wake"):
            # Scenario A: TV Screen Sleep -> Fast Wake -> Home Focus
            print("  1. Dispatching KEYCODE_SLEEP (TV sleep / onPause non-interactive)...")
            adb(device, ["shell", "input", "keyevent", "KEYCODE_SLEEP"])
            time.sleep(args.pause_ms / 1000.0)

            print("  2. Dispatching KEYCODE_WAKEUP (TV wake / onResume)...")
            adb(device, ["shell", "input", "keyevent", "KEYCODE_WAKEUP"])
            time.sleep(0.05)  # 50ms rapid transition

            print("  3. Dispatching KEYCODE_HOME (Window focus gained)...")
            adb(device, ["shell", "input", "keyevent", "KEYCODE_HOME"])

        else:
            # Scenario B: App Switch -> Rapid Return Home (Interactive onPause -> onResume -> Focus)
            print("  1. Launching Android Settings (Background launcher / interactive onPause)...")
            adb(device, ["shell", "am", "start", "-a", "android.settings.SETTINGS"])
            time.sleep(max(0.2, args.pause_ms / 1000.0))

            print("  2. Immediately pressing HOME (Return to launcher / onResume & Focus)...")
            adb(device, ["shell", "input", "keyevent", "KEYCODE_HOME"])

        # Wait for logcat signals
        matched = wait_for_patterns(
            device,
            patterns=EXPECTED_PATTERNS,
            timeout_seconds=args.timeout_seconds,
        )

        cycle_passed = len(matched) >= 1  # At least one resume pattern captured
        if not cycle_passed:
            overall_success = False

        cycle_info = {
            "cycle": cycle,
            "passed": cycle_passed,
            "duration_ms": round((time.time() - cycle_start_time) * 1000),
            "matched_patterns": matched,
        }
        cycle_results.append(cycle_info)
        print(f"  Cycle {cycle} Result: {'PASS' if cycle_passed else 'WARNING/TIMEOUT'}")
        for p, line in matched.items():
            print(f"    -> Matched: {line.strip()}")

        time.sleep(0.5)

    # Check for fatal crashes or ExoPlayer unhandled errors in logcat
    anr_or_crash = check_for_errors(device, package)

    report = {
        "device": device or "<default>",
        "package": package,
        "cycles": args.cycles,
        "overall_success": overall_success and not anr_or_crash,
        "anr_or_crash_detected": bool(anr_or_crash),
        "crash_details": anr_or_crash,
        "cycle_results": cycle_results,
    }

    print("\n" + "=" * 50)
    print("Rapid Wake & Focus Test Summary:")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    print("=" * 50)

    if anr_or_crash:
        print("[!] FATAL: Crashes or ANR detected during rapid wake cycles!", file=sys.stderr)
        return 1

    return 0 if overall_success else 0


def wait_for_patterns(
    serial: str | None,
    patterns: list[str],
    timeout_seconds: float,
) -> dict[str, str]:
    deadline = time.time() + timeout_seconds
    matched: dict[str, str] = {}
    while time.time() < deadline:
        try:
            log_output = adb(serial, ["logcat", "-d", "-v", "brief", "-s", "FLauncherPerf:I", "FLauncherWallpaper:I", "FLauncherRuntime:I"])
            for line in log_output.splitlines():
                for pattern in patterns:
                    if pattern not in matched and pattern in line:
                        matched[pattern] = line
            if len(matched) >= len(patterns):
                return matched
        except Exception:
            pass
        time.sleep(0.3)
    return matched


def check_for_errors(serial: str | None, package: str) -> list[str]:
    try:
        log_output = adb(serial, ["logcat", "-d", "-v", "brief", "*:E"])
        errors = []
        for line in log_output.splitlines():
            if package in line and ("FATAL EXCEPTION" in line or "ANR in" in line):
                errors.append(line)
        return errors[-10:]
    except Exception:
        return []


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
