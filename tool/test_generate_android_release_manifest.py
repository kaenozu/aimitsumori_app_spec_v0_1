#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("generate_android_release_manifest.py")
VALID_COMMIT = "0123456789abcdef0123456789abcdef01234567"
VALID_FINGERPRINT = ":".join(["AB"] * 32)


class GenerateAndroidReleaseManifestTest(unittest.TestCase):
    def _run(
        self,
        root: Path,
        *,
        version: str = "0.1.1+2",
        application_id: str = "com.kaenozu.aimitsumori_app",
        fingerprint: str = VALID_FINGERPRINT,
        release_ref: str = "v0.1.1",
    ) -> subprocess.CompletedProcess[str]:
        aab = root / "app-release.aab"
        pubspec = root / "pubspec.yaml"
        gradle = root / "build.gradle.kts"
        output = root / "release-manifest.json"

        aab.write_bytes(b"test-aab-content")
        pubspec.write_text(f"name: test\nversion: {version}\n", encoding="utf-8")
        gradle.write_text(
            f'android {{\n  defaultConfig {{\n    applicationId = "{application_id}"\n  }}\n}}\n',
            encoding="utf-8",
        )

        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--aab",
                str(aab),
                "--pubspec",
                str(pubspec),
                "--gradle",
                str(gradle),
                "--output",
                str(output),
                "--repository",
                "kaenozu/aimitsumori_app_spec_v0_1",
                "--ref",
                release_ref,
                "--commit-sha",
                VALID_COMMIT,
                "--signer-certificate-sha256",
                fingerprint,
                "--generated-at-utc",
                "2026-07-28T00:00:00Z",
                "--require-version-tag",
            ],
            text=True,
            capture_output=True,
            check=False,
        )

    def test_writes_expected_manifest_without_secrets(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            result = self._run(root)

            self.assertEqual(result.returncode, 0, result.stderr)
            manifest = json.loads((root / "release-manifest.json").read_text())
            self.assertEqual(manifest["ref"], "v0.1.1")
            self.assertEqual(manifest["versionName"], "0.1.1")
            self.assertEqual(manifest["versionCode"], 2)
            self.assertEqual(
                manifest["applicationId"], "com.kaenozu.aimitsumori_app"
            )
            self.assertEqual(manifest["commitSha"], VALID_COMMIT)
            self.assertEqual(
                manifest["aab"]["sha256"],
                hashlib.sha256(b"test-aab-content").hexdigest(),
            )
            self.assertEqual(
                manifest["signing"]["certificateSha256"], VALID_FINGERPRINT
            )
            serialized = json.dumps(manifest)
            self.assertNotIn("password", serialized.lower())
            self.assertNotIn("keystore", serialized.lower())

    def test_rejects_version_without_build_number(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = self._run(Path(directory), version="0.1.1")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("x.y.z+build", result.stderr)

    def test_rejects_invalid_signer_fingerprint(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = self._run(Path(directory), fingerprint="not-a-fingerprint")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("64 hexadecimal digits", result.stderr)

    def test_rejects_release_ref_that_does_not_match_version(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = self._run(Path(directory), release_ref="main")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("must match pubspec version tag v0.1.1", result.stderr)

    def test_repository_pubspec_version_has_changelog_entry(self) -> None:
        root = Path(__file__).resolve().parents[1]
        pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
        match = re.search(
            r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+\s*$",
            pubspec,
            re.MULTILINE,
        )
        self.assertIsNotNone(
            match, "pubspec.yaml version must use x.y.z+build format"
        )
        release_version = match.group(1)
        changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
        self.assertIn(
            f"## [{release_version}]",
            changelog,
            f"CHANGELOG.md must contain a release entry for {release_version}",
        )


if __name__ == "__main__":
    unittest.main()
