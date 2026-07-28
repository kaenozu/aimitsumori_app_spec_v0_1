#!/usr/bin/env python3
"""Generate a non-secret audit manifest for an Android App Bundle release."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path

_VERSION_PATTERN = re.compile(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$")
_APPLICATION_ID_PATTERN = re.compile(
    r'^\s*applicationId\s*=\s*"([A-Za-z][A-Za-z0-9_.]*)"\s*$'
)
_FINGERPRINT_PATTERN = re.compile(r"^[0-9A-F]{64}$")
_COMMIT_PATTERN = re.compile(r"^[0-9a-fA-F]{40}$")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _parse_version(pubspec_path: Path) -> tuple[str, int]:
    for line in pubspec_path.read_text(encoding="utf-8").splitlines():
        match = _VERSION_PATTERN.fullmatch(line)
        if match:
            return match.group(1), int(match.group(2))
    raise ValueError(
        f"{pubspec_path} must contain a version in x.y.z+build format"
    )


def _parse_application_id(gradle_path: Path) -> str:
    matches = []
    for line in gradle_path.read_text(encoding="utf-8").splitlines():
        match = _APPLICATION_ID_PATTERN.fullmatch(line)
        if match:
            matches.append(match.group(1))
    if len(matches) != 1:
        raise ValueError(
            f"{gradle_path} must contain exactly one literal applicationId"
        )
    return matches[0]


def _normalize_fingerprint(value: str) -> str:
    compact = value.replace(":", "").upper()
    if not _FINGERPRINT_PATTERN.fullmatch(compact):
        raise ValueError("signer certificate SHA-256 must contain 64 hexadecimal digits")
    return ":".join(compact[index : index + 2] for index in range(0, 64, 2))


def _generated_at(value: str | None) -> str:
    if value is None:
        return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("generated-at-utc must include a UTC offset")
    return parsed.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def generate_manifest(args: argparse.Namespace) -> dict[str, object]:
    aab_path = Path(args.aab)
    pubspec_path = Path(args.pubspec)
    gradle_path = Path(args.gradle)

    if not aab_path.is_file() or aab_path.stat().st_size == 0:
        raise ValueError(f"AAB does not exist or is empty: {aab_path}")
    if not _COMMIT_PATTERN.fullmatch(args.commit_sha):
        raise ValueError("commit SHA must contain exactly 40 hexadecimal digits")

    version_name, version_code = _parse_version(pubspec_path)
    application_id = _parse_application_id(gradle_path)

    return {
        "schemaVersion": 1,
        "generatedAtUtc": _generated_at(args.generated_at_utc),
        "repository": args.repository,
        "ref": args.ref,
        "commitSha": args.commit_sha.lower(),
        "versionName": version_name,
        "versionCode": version_code,
        "applicationId": application_id,
        "aab": {
            "fileName": aab_path.name,
            "sizeBytes": aab_path.stat().st_size,
            "sha256": _sha256(aab_path),
        },
        "signing": {
            "certificateSha256": _normalize_fingerprint(
                args.signer_certificate_sha256
            )
        },
    }


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--aab", required=True)
    parser.add_argument("--pubspec", default="pubspec.yaml")
    parser.add_argument("--gradle", default="android/app/build.gradle.kts")
    parser.add_argument("--output", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--ref", required=True)
    parser.add_argument("--commit-sha", required=True)
    parser.add_argument("--signer-certificate-sha256", required=True)
    parser.add_argument("--generated-at-utc")
    return parser


def main() -> int:
    parser = _build_parser()
    args = parser.parse_args()
    try:
        manifest = generate_manifest(args)
    except (OSError, ValueError) as error:
        parser.error(str(error))

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
