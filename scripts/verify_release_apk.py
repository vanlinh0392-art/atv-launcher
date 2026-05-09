#!/usr/bin/env python3
"""Verify official release APK artifacts before publishing them."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path
from typing import Any


OFFICIAL_RELEASE_ASSET_NAMES = {
    "atv-launcher-armeabi-v7a-release.apk",
    "atv-launcher-arm64-v8a-release.apk",
}
OFFICIAL_RELEASE_SIGNER_SHA256 = (
    "bb22b0a39ec267e89efe324e99680891e35a73f735b54b549abb7966d724d963"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify package/version/ABI for an official release APK.",
    )
    parser.add_argument("--apk", help="Path to the APK to verify.")
    parser.add_argument(
        "--expected-abi",
        choices=["armeabi-v7a", "arm64-v8a"],
        help="Expected ABI packaged inside the APK.",
    )
    parser.add_argument(
        "--expected-package",
        default="com.atv.launcher",
        help="Expected Android package name.",
    )
    parser.add_argument(
        "--expected-signer-sha256",
        default=OFFICIAL_RELEASE_SIGNER_SHA256,
        help="Expected APK signer certificate SHA-256 digest.",
    )
    parser.add_argument(
        "--pubspec",
        default="pubspec.yaml",
        help="Path to pubspec.yaml used to confirm versionName.",
    )
    parser.add_argument(
        "--scan-dir",
        help="Directory that should contain only the 2 official release assets.",
    )
    parser.add_argument(
        "--report",
        help="Optional path to write a JSON verification report.",
    )
    args = parser.parse_args()
    if not args.apk and not args.scan_dir:
      parser.error("At least one of --apk or --scan-dir is required.")
    return args


def main() -> int:
    args = parse_args()
    expected_version = read_pubspec_version(Path(args.pubspec))
    report: dict[str, Any] = {
        "expectedPackage": args.expected_package,
        "expectedVersion": expected_version,
    }
    failures: list[str] = []

    if args.apk:
        apk_report, apk_failures = verify_apk(
            apk_path=Path(args.apk),
            expected_abi=args.expected_abi,
            expected_package=args.expected_package,
            expected_signer_sha256=args.expected_signer_sha256,
            expected_version=expected_version,
        )
        report["apk"] = apk_report
        failures.extend(apk_failures)

    if args.scan_dir:
        scan_report, scan_failures = verify_official_release_directory(
            Path(args.scan_dir),
        )
        report["scanDir"] = scan_report
        failures.extend(scan_failures)

    if args.report:
        report_path = Path(args.report)
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(
            json.dumps(report, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

    print(json.dumps(report, indent=2, ensure_ascii=False))
    if failures:
        for failure in failures:
            print(f"ERROR: {failure}", file=sys.stderr)
        return 1
    return 0


def verify_apk(
    *,
    apk_path: Path,
    expected_abi: str | None,
    expected_package: str,
    expected_signer_sha256: str | None,
    expected_version: str,
) -> tuple[dict[str, Any], list[str]]:
    report: dict[str, Any] = {
        "path": str(apk_path),
        "exists": apk_path.is_file(),
    }
    failures: list[str] = []
    if not apk_path.is_file():
        failures.append(f"APK does not exist: {apk_path}")
        return report, failures

    report["sizeBytes"] = apk_path.stat().st_size
    report["sha256"] = sha256_file(apk_path)

    package_info = inspect_package_info(apk_path)
    report["packageInfo"] = package_info
    if package_info.get("packageName") != expected_package:
        failures.append(
            f"{apk_path.name} package mismatch: "
            f"expected {expected_package}, got {package_info.get('packageName')}",
        )
    if package_info.get("versionName") != expected_version:
        failures.append(
            f"{apk_path.name} version mismatch: "
            f"expected {expected_version}, got {package_info.get('versionName')}",
        )

    packaged_abis = inspect_packaged_abis(apk_path)
    report["packagedAbis"] = packaged_abis
    report["isUniversalLike"] = len(packaged_abis) > 1 or "universal" in apk_path.name.lower()
    if expected_abi:
        if packaged_abis != [expected_abi]:
            failures.append(
                f"{apk_path.name} packaged ABI mismatch: "
                f"expected only {expected_abi}, got {packaged_abis or '[]'}",
            )
        native_code = package_info.get("nativeCodeAbis") or []
        if native_code and native_code != [expected_abi]:
            failures.append(
                f"{apk_path.name} aapt native-code mismatch: "
                f"expected only {expected_abi}, got {native_code}",
            )

    signer_info = inspect_signer_info(apk_path)
    report["signerInfo"] = signer_info
    if expected_signer_sha256:
        actual_digest = (signer_info.get("sha256Digest") or "").lower()
        expected_digest = expected_signer_sha256.replace(":", "").lower()
        if actual_digest != expected_digest:
            failures.append(
                f"{apk_path.name} signer mismatch: expected SHA-256 "
                f"{expected_digest}, got {actual_digest or 'unknown'}",
            )

    return report, failures


def verify_official_release_directory(directory: Path) -> tuple[dict[str, Any], list[str]]:
    report: dict[str, Any] = {
        "path": str(directory),
        "exists": directory.is_dir(),
    }
    failures: list[str] = []
    if not directory.is_dir():
        failures.append(f"Release asset directory does not exist: {directory}")
        return report, failures

    apk_names = sorted(path.name for path in directory.glob("*.apk"))
    report["apkNames"] = apk_names
    unexpected = [name for name in apk_names if name not in OFFICIAL_RELEASE_ASSET_NAMES]
    missing = sorted(OFFICIAL_RELEASE_ASSET_NAMES.difference(apk_names))
    report["unexpectedApks"] = unexpected
    report["missingApks"] = missing
    report["containsUniversalAsset"] = any("universal" in name.lower() for name in apk_names)

    if unexpected:
        failures.append(
            f"Unexpected APK assets in official release directory: {unexpected}",
        )
    if missing:
        failures.append(
            f"Missing official release APK assets: {missing}",
        )
    if report["containsUniversalAsset"]:
        failures.append("Official release directory must not contain a universal APK asset.")
    return report, failures


def inspect_package_info(apk_path: Path) -> dict[str, Any]:
    aapt_path = find_aapt()
    if aapt_path is None:
        raise RuntimeError(
            "Could not find Android build-tools aapt. "
            "Set ANDROID_HOME/ANDROID_SDK_ROOT or add aapt to PATH.",
        )
    completed = subprocess.run(
        [str(aapt_path), "dump", "badging", str(apk_path)],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    output = completed.stdout
    package_match = re.search(
        r"package:\s+name='([^']+)'.*versionName='([^']+)'",
        output,
    )
    if not package_match:
        raise RuntimeError(f"Could not parse package info from aapt output for {apk_path}.")
    native_code_match = re.search(r"native-code:\s*(.*)", output)
    native_code_abis = (
        re.findall(r"'([^']+)'", native_code_match.group(1))
        if native_code_match
        else []
    )
    return {
        "tool": str(aapt_path),
        "packageName": package_match.group(1),
        "versionName": package_match.group(2),
        "nativeCodeAbis": native_code_abis,
    }


def inspect_packaged_abis(apk_path: Path) -> list[str]:
    abis = set()
    with zipfile.ZipFile(apk_path) as archive:
        for name in archive.namelist():
            parts = name.split("/")
            if len(parts) >= 3 and parts[0] == "lib" and parts[2].endswith(".so"):
                abis.add(parts[1])
    return sorted(abis)


def inspect_signer_info(apk_path: Path) -> dict[str, Any]:
    apksigner_commands = find_apksigner_commands()
    if not apksigner_commands:
        raise RuntimeError(
            "Could not find Android build-tools apksigner. "
            "Set ANDROID_HOME/ANDROID_SDK_ROOT or add apksigner to PATH.",
        )

    errors: list[str] = []
    output = ""
    tool = ""
    for command in apksigner_commands:
        completed = subprocess.run(
            command + ["verify", "--print-certs", str(apk_path)],
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        combined_output = "\n".join(
            part for part in [completed.stdout, completed.stderr] if part
        )
        if completed.returncode == 0 and "certificate SHA-256 digest" in combined_output:
            output = combined_output
            tool = " ".join(command)
            break
        errors.append(
            f"{' '.join(command)} exited {completed.returncode}: "
            f"{combined_output.strip()[:500]}",
        )
    else:
        raise RuntimeError(
            "Could not inspect APK signer certificate. Attempts: "
            + " | ".join(errors),
        )

    digest_match = re.search(
        r"Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F:]+)",
        output,
    )
    dn_match = re.search(r"Signer #1 certificate DN:\s*(.+)", output)
    return {
        "tool": tool,
        "dn": dn_match.group(1).strip() if dn_match else None,
        "sha256Digest": (
            digest_match.group(1).replace(":", "").lower()
            if digest_match
            else None
        ),
    }


def find_aapt() -> Path | None:
    direct = shutil.which("aapt")
    if direct:
        return Path(direct)

    sdk_root = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if not sdk_root:
        return None

    build_tools_dir = Path(sdk_root) / "build-tools"
    if not build_tools_dir.is_dir():
        return None

    candidates: list[Path] = []
    for child in build_tools_dir.iterdir():
        if not child.is_dir():
            continue
        candidates.append(child / "aapt")
        candidates.append(child / "aapt.exe")

    for candidate in sorted(candidates, reverse=True):
        if candidate.is_file():
            return candidate
    return None


def find_apksigner_commands() -> list[list[str]]:
    commands: list[list[str]] = []

    direct = shutil.which("apksigner")
    if direct:
        commands.append([str(Path(direct))])
    direct_bat = shutil.which("apksigner.bat")
    if direct_bat:
        commands.append([str(Path(direct_bat))])

    sdk_root = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if not sdk_root:
        return commands

    build_tools_dir = Path(sdk_root) / "build-tools"
    if not build_tools_dir.is_dir():
        return commands

    candidates: list[Path] = []
    for child in build_tools_dir.iterdir():
        if not child.is_dir():
            continue
        candidates.append(child / "apksigner")
        candidates.append(child / "apksigner.bat")
        candidates.append(child / "lib" / "apksigner.jar")

    for candidate in sorted(candidates, reverse=True):
        if not candidate.is_file():
            continue
        if candidate.suffix == ".jar":
            java = shutil.which("java")
            if java:
                commands.append(
                    [
                        str(Path(java)),
                        "-cp",
                        str(candidate),
                        "com.android.apksigner.ApkSignerTool",
                    ],
                )
        else:
            commands.append([str(candidate)])
    return commands


def read_pubspec_version(pubspec_path: Path) -> str:
    if not pubspec_path.is_file():
        raise FileNotFoundError(f"pubspec.yaml not found: {pubspec_path}")
    for line in pubspec_path.read_text(encoding="utf-8").splitlines():
        if line.startswith("version:"):
            raw_version = line.split(":", 1)[1].strip()
            return raw_version.split("+", 1)[0]
    raise RuntimeError(f"Could not read version from {pubspec_path}")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


if __name__ == "__main__":
    raise SystemExit(main())
