from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
PACKAGE_NAME = "com.atv.launcher"
WRITE_SECURE_SETTINGS = "android.permission.WRITE_SECURE_SETTINGS"


def discover_adb() -> Path | None:
    candidates: list[Path] = []
    seen: set[str] = set()

    def add_candidate(value: str | Path | None) -> None:
        if not value:
            return
        candidate = Path(value).expanduser()
        key = os.path.normcase(str(candidate))
        if key in seen:
            return
        seen.add(key)
        candidates.append(candidate)

    for name in ("adb", "adb.exe"):
        resolved = shutil.which(name)
        if resolved:
            add_candidate(resolved)

    for env_name in ("ANDROID_SDK_ROOT", "ANDROID_HOME"):
        root = os.environ.get(env_name)
        if root:
            add_candidate(Path(root) / "platform-tools" / "adb.exe")
            add_candidate(Path(root) / "platform-tools" / "adb")

    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return None


def locate_default_apk() -> Path:
    flutter_apk_dir = SCRIPT_DIR / "build" / "app" / "outputs" / "flutter-apk"
    if flutter_apk_dir.is_dir():
        candidates = sorted(flutter_apk_dir.glob("*armeabi-v7a*.apk")) or sorted(flutter_apk_dir.glob("*.apk"))
        if candidates:
            return candidates[0]
    raise FileNotFoundError(
        "Could not locate a built launcher APK. Pass --apk or build the project first."
    )


def adb_prefix(adb_path: Path, serial: str | None) -> list[str]:
    prefix = [str(adb_path)]
    if serial:
        prefix.extend(["-s", serial])
    return prefix


def run_command(command: list[str], timeout: int = 60) -> subprocess.CompletedProcess[str]:
    print("+", subprocess.list2cmdline(command))
    return subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )


def ensure_success(result: subprocess.CompletedProcess[str], step_name: str) -> None:
    output = ((result.stdout or "") + (result.stderr or "")).strip()
    if result.returncode == 0:
        if output:
            print(output)
        return
    raise RuntimeError(f"{step_name} failed:\n{output or '(no output)'}")


def best_effort(command: list[str], step_name: str, timeout: int = 30) -> None:
    result = run_command(command, timeout=timeout)
    output = ((result.stdout or "") + (result.stderr or "")).strip()
    if result.returncode == 0:
        if output:
            print(output)
        return
    print(f"[warn] {step_name} failed: {output or '(no output)'}")


def verify(adb_path: Path, serial: str | None) -> None:
    prefix = adb_prefix(adb_path, serial)
    checks = {
        "WRITE_SECURE_SETTINGS": prefix + ["shell", "dumpsys", "package", PACKAGE_NAME],
        "battery_whitelist": prefix + ["shell", "dumpsys", "deviceidle", "whitelist"],
        "appops": prefix + ["shell", "cmd", "appops", "get", PACKAGE_NAME],
        "adb_enabled": prefix + ["shell", "settings", "get", "global", "adb_enabled"],
        "adb_wifi_enabled": prefix + ["shell", "settings", "get", "global", "adb_wifi_enabled"],
    }

    print("\nVerification summary")
    print("--------------------")
    for label, command in checks.items():
        result = run_command(command, timeout=30)
        output = ((result.stdout or "") + (result.stderr or "")).strip()
        first_line = output.splitlines()[0] if output else "(no output)"
        print(f"{label}: {first_line}")

    dumpsys = run_command(prefix + ["shell", "dumpsys", "package", PACKAGE_NAME], timeout=30)
    if "android.permission.WRITE_SECURE_SETTINGS: granted=true" not in (dumpsys.stdout or ""):
        raise RuntimeError("WRITE_SECURE_SETTINGS was not verified in dumpsys output.")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Provision ATV Launcher on an Android TV device using one-time ADB grants."
    )
    parser.add_argument("--adb", help="Path to adb.exe")
    parser.add_argument("--serial", help="ADB device serial")
    parser.add_argument("--apk", help="Path to ATV Launcher APK")
    parser.add_argument("--skip-install", action="store_true", help="Skip APK install")
    parser.add_argument("--skip-adb-wifi", action="store_true", help="Do not toggle adb_wifi_enabled")
    parser.add_argument("--skip-verify", action="store_true", help="Skip final verification pass")
    args = parser.parse_args()

    adb_path = Path(args.adb) if args.adb else discover_adb()
    if not adb_path or not adb_path.is_file():
        print("adb was not found. Pass --adb with a valid adb.exe path.", file=sys.stderr)
        return 1

    apk_path = Path(args.apk) if args.apk else locate_default_apk()
    if not args.skip_install and not apk_path.is_file():
        print(f"APK was not found: {apk_path}", file=sys.stderr)
        return 1

    prefix = adb_prefix(adb_path, args.serial)

    try:
        if not args.skip_install:
            ensure_success(run_command(prefix + ["install", "-r", str(apk_path)], timeout=180), "APK install")

        ensure_success(
            run_command(prefix + ["shell", "pm", "grant", PACKAGE_NAME, WRITE_SECURE_SETTINGS], timeout=30),
            "WRITE_SECURE_SETTINGS grant",
        )

        best_effort(prefix + ["shell", "appops", "set", PACKAGE_NAME, "SYSTEM_ALERT_WINDOW", "allow"], "SYSTEM_ALERT_WINDOW appop")
        best_effort(prefix + ["shell", "appops", "set", PACKAGE_NAME, "WRITE_SETTINGS", "allow"], "WRITE_SETTINGS appop")
        best_effort(prefix + ["shell", "cmd", "deviceidle", "whitelist", f"+{PACKAGE_NAME}"], "Battery whitelist")
        best_effort(prefix + ["shell", "settings", "put", "global", "adb_enabled", "1"], "Enable ADB")

        if not args.skip_adb_wifi:
            best_effort(prefix + ["shell", "settings", "put", "global", "adb_wifi_enabled", "1"], "Enable ADB Wi-Fi")

        if not args.skip_verify:
            verify(adb_path, args.serial)

        print(f"\nProvisioning complete for {PACKAGE_NAME}.")
        return 0
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
