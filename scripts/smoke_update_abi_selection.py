#!/usr/bin/env python3
"""Smoke-check which official update asset a device should receive."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_GITHUB_OWNER = os.environ.get(
    "LAUNCHER_UPDATE_GITHUB_OWNER",
    "vanlinh0392-art",
)
DEFAULT_GITHUB_REPO = os.environ.get("LAUNCHER_UPDATE_GITHUB_REPO", "atv-launcher")
DEFAULT_UPDATE_CHANNEL = os.environ.get(
    "LAUNCHER_UPDATE_CHANNEL",
    "atv-launcher-official",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Resolve the expected official APK asset for a device ABI.",
    )
    parser.add_argument("--device", help="ADB serial. Uses the default device if omitted.")
    parser.add_argument(
        "--device-abis",
        help="Comma-separated ABI list to verify without querying a live device.",
    )
    parser.add_argument(
        "--asset-dir",
        default="build/release-assets",
        help="Local directory containing official APK assets.",
    )
    parser.add_argument(
        "--fetch-github",
        action="store_true",
        help="Fetch the latest official GitHub release instead of reading local assets.",
    )
    parser.add_argument(
        "--github-owner",
        default=DEFAULT_GITHUB_OWNER,
        help="GitHub owner to query when --fetch-github is used.",
    )
    parser.add_argument(
        "--github-repo",
        default=DEFAULT_GITHUB_REPO,
        help="GitHub repository to query when --fetch-github is used.",
    )
    parser.add_argument(
        "--update-channel",
        default=DEFAULT_UPDATE_CHANNEL,
        help="Official updater channel marker expected in the release body.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    device_abis = (
        normalize_abis(args.device_abis.split(","))
        if args.device_abis
        else get_device_abis(args.device)
    )
    assets = (
        load_assets_from_github(args.github_owner, args.github_repo, args.update_channel)
        if args.fetch_github
        else load_assets_from_directory(Path(args.asset_dir))
    )
    selected = preferred_asset_for(device_abis, assets)

    report: dict[str, Any] = {
        "device": args.device or "<default>",
        "deviceAbis": device_abis,
        "assetSource": "github" if args.fetch_github else str(Path(args.asset_dir)),
        "availableAssets": [asset["name"] for asset in assets],
        "selectedAsset": selected["name"] if selected else None,
    }
    print(json.dumps(report, indent=2, ensure_ascii=False))

    if not assets:
        print("ERROR: No official APK assets were available for selection.", file=sys.stderr)
        return 1
    if selected is None:
        print("ERROR: Could not resolve a suitable asset for the device ABI.", file=sys.stderr)
        return 1
    return 0


def get_device_abis(serial: str | None) -> list[str]:
    abilist = adb_shell(serial, ["getprop", "ro.product.cpu.abilist"]).strip()
    if abilist:
        return normalize_abis(abilist.split(","))
    cpu_abi = adb_shell(serial, ["getprop", "ro.product.cpu.abi"]).strip()
    return normalize_abis([cpu_abi] if cpu_abi else [])


def adb_shell(serial: str | None, command: list[str]) -> str:
    adb = ["adb"]
    if serial:
        adb.extend(["-s", serial])
    adb.extend(["shell", *command])
    completed = subprocess.run(
        adb,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return completed.stdout


def normalize_abis(values: list[str]) -> list[str]:
    normalized: list[str] = []
    for value in values:
        candidate = value.strip().lower()
        if not candidate or candidate in normalized:
            continue
        normalized.append(candidate)
    return normalized


def load_assets_from_directory(directory: Path) -> list[dict[str, Any]]:
    if not directory.is_dir():
        return []
    return [
        {"name": path.name}
        for path in sorted(directory.glob("*.apk"))
    ]


def load_assets_from_github(
    github_owner: str,
    github_repo: str,
    update_channel: str,
) -> list[dict[str, Any]]:
    url = (
        f"https://api.github.com/repos/{github_owner}/{github_repo}/releases"
        "?per_page=20"
    )
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "ATVLauncher-SmokeCheck",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        releases = json.loads(response.read().decode("utf-8"))

    for release in releases:
        if not is_official_release(release, update_channel):
            continue
        assets = release.get("assets") or []
        return [
            {"name": asset.get("name", "")}
            for asset in assets
            if str(asset.get("name", "")).lower().endswith(".apk")
        ]
    return []


def is_official_release(release: dict[str, Any], update_channel: str) -> bool:
    if release.get("draft") or release.get("prerelease"):
        return False
    tag_name = str(release.get("tag_name", "")).lower()
    name = str(release.get("name", "")).lower()
    body = str(release.get("body", "")).replace("`", "").lower()
    if not tag_name.endswith("-release"):
        return False
    if "atv launcher" not in name:
        return False
    return f"updater-channel: {update_channel}".lower() in body


def preferred_asset_for(
    device_abis: list[str],
    assets: list[dict[str, Any]],
) -> dict[str, Any] | None:
    if not assets:
        return None

    profile = resolve_device_profile(device_abis)
    ranked = sorted(
        assets,
        key=lambda asset: (
            -device_aware_priority(asset["name"], profile),
            generic_rank(asset["name"]),
        ),
    )
    selected = ranked[0]
    if profile == "unknown":
        return selected
    return selected if device_aware_priority(selected["name"], profile) > 0 else None


def resolve_device_profile(device_abis: list[str]) -> str:
    if any(abi in {"arm64-v8a", "aarch64"} for abi in device_abis):
        return "arm64"
    if any(abi in {"armeabi-v7a", "armeabi"} for abi in device_abis):
        return "armv7"
    return "unknown"


def device_aware_priority(asset_name: str, profile: str) -> int:
    abi = resolve_asset_abi(asset_name)
    if profile == "arm64":
        return {"arm64": 3, "armv7": 2, "universal": 1}.get(abi, 0)
    if profile == "armv7":
        return {"armv7": 3, "universal": 2}.get(abi, 0)
    return 0


def generic_rank(asset_name: str) -> tuple[int, int, int, str]:
    name = asset_name.lower()
    release_priority = 2 if "release" in name else 1 if name.endswith(".apk") else 0
    architecture_priority = 3 if ("armeabi" in name or "v7a" in name) else 2 if ("arm64" in name or "aarch64" in name) else 1 if "arm" in name else 0
    universal_penalty = 1 if "universal" in name else 0
    return (-release_priority, -architecture_priority, universal_penalty, name)


def resolve_asset_abi(asset_name: str) -> str:
    name = asset_name.lower()
    if "universal" in name:
        return "universal"
    if "arm64" in name or "aarch64" in name:
        return "arm64"
    if "armeabi" in name or "v7a" in name:
        return "armv7"
    return "unknown"


if __name__ == "__main__":
    raise SystemExit(main())
