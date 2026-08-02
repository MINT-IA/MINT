from __future__ import annotations

import hashlib
import os
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks.mint_next_artifact_manifest import archive_entries, reconstruct, validate_manifest


class ArtifactManifestTest(unittest.TestCase):
    def fixture(self) -> tuple[tempfile.TemporaryDirectory[str], Path, Path, Path]:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        repo = Path(temporary.name)
        artifact = repo / "artifact"
        artifact.mkdir()
        current = artifact / "lib/value.txt"
        current.parent.mkdir()
        current.write_bytes(b"accepted bytes\n")
        digest = hashlib.sha256(current.read_bytes()).hexdigest()
        manifest = repo / "manifest.yaml"
        manifest.write_text(
            yaml.safe_dump(
                {
                    "schema_version": 1,
                    "artifact_id": "fixture",
                    "accepted_commit": "1" * 40,
                    "accepted_tree": "2" * 40,
                    "root": "artifact",
                    "closure": {"tracked_files": 1, "excluded": ["build/"]},
                    "toolchain_inputs": ["lib/value.txt"],
                    "provenance": {
                        "creation_binding": "git_ls_tree",
                        "offline_verification": "content_only_manifest_digest_must_be_anchored_externally",
                    },
                    "entries": [
                        {
                            "path": "lib/value.txt",
                            "mode": "100644",
                            "size": len(current.read_bytes()),
                            "sha256": digest,
                            "role": "source",
                        }
                    ],
                },
                sort_keys=False,
            ),
            encoding="utf-8",
        )
        cas = repo / "cas"
        cas.mkdir()
        return temporary, repo, manifest, cas

    def mutate(self, manifest: Path, callback) -> None:
        raw = yaml.safe_load(manifest.read_text(encoding="utf-8"))
        callback(raw)
        manifest.write_text(yaml.safe_dump(raw, sort_keys=False), encoding="utf-8")

    def test_current_bytes_pass_without_cas(self) -> None:
        _, repo, manifest, cas = self.fixture()
        _, errors = validate_manifest(manifest, repo_root=repo, cas_root=cas)
        self.assertEqual(errors, [])

    def test_changed_current_requires_archived_bytes(self) -> None:
        _, repo, manifest, cas = self.fixture()
        current = repo / "artifact/lib/value.txt"
        accepted = current.read_bytes()
        digest = hashlib.sha256(accepted).hexdigest()
        current.write_text("new batch", encoding="utf-8")
        _, errors = validate_manifest(manifest, repo_root=repo, cas_root=cas)
        self.assertTrue(any("bytes unavailable" in error for error in errors))
        (cas / digest).write_bytes(accepted)
        _, errors = validate_manifest(manifest, repo_root=repo, cas_root=cas)
        self.assertEqual(errors, [])

    def test_rejects_unsafe_duplicate_case_and_unsorted_paths(self) -> None:
        _, repo, manifest, cas = self.fixture()
        raw = yaml.safe_load(manifest.read_text(encoding="utf-8"))
        first = raw["entries"][0]
        raw["entries"] = [
            {**first, "path": "z.txt"},
            {**first, "path": "A.txt"},
            {**first, "path": "a.txt"},
            {**first, "path": "../escape"},
        ]
        manifest.write_text(yaml.safe_dump(raw, sort_keys=False), encoding="utf-8")
        _, errors = validate_manifest(manifest, repo_root=repo, cas_root=cas)
        joined = "\n".join(errors)
        self.assertIn("unsafe path", joined)
        self.assertIn("case-colliding", joined)
        self.assertIn("not canonically sorted", joined)

    def test_rejects_hash_size_mode_and_role_drift(self) -> None:
        _, repo, manifest, cas = self.fixture()
        self.mutate(
            manifest,
            lambda raw: raw["entries"][0].update(
                sha256="f" * 64,
                size=999,
                mode="120000",
                role="mystery",
            ),
        )
        _, errors = validate_manifest(manifest, repo_root=repo, cas_root=cas)
        joined = "\n".join(errors)
        self.assertIn("unsupported mode", joined)
        self.assertIn("invalid role", joined)

    def test_rejects_well_formed_but_wrong_hash_and_size(self) -> None:
        _, repo, manifest, cas = self.fixture()
        self.mutate(
            manifest,
            lambda raw: raw["entries"][0].update(sha256="f" * 64, size=999),
        )
        _, errors = validate_manifest(manifest, repo_root=repo, cas_root=cas)
        self.assertTrue(any("bytes unavailable" in error for error in errors))

    def test_rejects_mode_drift_and_partial_closure_claim(self) -> None:
        _, repo, manifest, cas = self.fixture()
        current = repo / "artifact/lib/value.txt"
        os.chmod(current, 0o654)
        _, errors = validate_manifest(manifest, repo_root=repo, cas_root=cas)
        self.assertTrue(any("mode drift" in error for error in errors))
        os.chmod(current, 0o644)
        self.mutate(manifest, lambda raw: raw["closure"].update(tracked_files=2))
        _, errors = validate_manifest(manifest, repo_root=repo, cas_root=cas)
        self.assertIn("artifact manifest closure count does not match entries", errors)

    def test_rejects_symlink_even_when_target_matches(self) -> None:
        _, repo, manifest, cas = self.fixture()
        current = repo / "artifact/lib/value.txt"
        target = repo / "accepted.txt"
        target.write_bytes(current.read_bytes())
        current.unlink()
        current.symlink_to(target)
        _, errors = validate_manifest(manifest, repo_root=repo, cas_root=cas)
        self.assertTrue(any("symlink" in error for error in errors))

    def test_rejects_symlinked_parent_and_cas_outside_repo(self) -> None:
        _, repo, manifest, cas = self.fixture()
        artifact = repo / "artifact"
        accepted = artifact / "lib/value.txt"
        external = repo / "external"
        external.mkdir()
        (external / "value.txt").write_bytes(accepted.read_bytes())
        accepted.unlink()
        (artifact / "lib").rmdir()
        (artifact / "lib").symlink_to(external, target_is_directory=True)
        _, errors = validate_manifest(manifest, repo_root=repo, cas_root=cas)
        self.assertTrue(any("contains symlink" in error for error in errors))
        outside = Path(tempfile.mkdtemp())
        self.addCleanup(lambda: outside.rmdir())
        _, errors = validate_manifest(manifest, repo_root=repo, cas_root=outside)
        self.assertIn("artifact CAS root escapes repository", errors)

    def test_rejects_duplicate_yaml_keys(self) -> None:
        _, repo, manifest, cas = self.fixture()
        manifest.write_text(
            "schema_version: 1\nschema_version: 1\nartifact_id: duplicate\n",
            encoding="utf-8",
        )
        _, errors = validate_manifest(manifest, repo_root=repo, cas_root=cas)
        self.assertTrue(any("duplicate YAML key" in error for error in errors))

    def test_reconstructs_from_mixed_current_and_cas(self) -> None:
        _, repo, manifest, cas = self.fixture()
        current = repo / "artifact/lib/value.txt"
        accepted = current.read_bytes()
        digest = hashlib.sha256(accepted).hexdigest()
        current.write_text("new batch", encoding="utf-8")
        archived = cas / digest
        archived.write_bytes(accepted)
        os.chmod(archived, 0o644)
        destination = repo / "rebuilt"
        self.assertEqual(
            reconstruct(manifest, destination, repo_root=repo, cas_root=cas),
            [],
        )
        self.assertEqual((destination / "lib/value.txt").read_bytes(), accepted)

    def test_archive_command_copies_only_accepted_current_bytes(self) -> None:
        _, repo, manifest, cas = self.fixture()
        self.assertEqual(
            archive_entries(
                manifest,
                ["lib/value.txt"],
                repo_root=repo,
                cas_root=cas,
            ),
            [],
        )
        digest = yaml.safe_load(manifest.read_text())["entries"][0]["sha256"]
        self.assertTrue((cas / digest).is_file())
        (repo / "artifact/lib/value.txt").write_text("changed", encoding="utf-8")
        self.assertTrue(
            any(
                "archive source" in error
                for error in archive_entries(
                    manifest,
                    ["lib/value.txt"],
                    repo_root=repo,
                    cas_root=cas,
                )
            )
        )

    def test_executable_entry_uses_manifest_mode_with_content_only_cas(self) -> None:
        _, repo, manifest, cas = self.fixture()
        current = repo / "artifact/lib/value.txt"
        os.chmod(current, 0o755)
        self.mutate(manifest, lambda raw: raw["entries"][0].update(mode="100755"))
        self.assertEqual(
            archive_entries(manifest, ["lib/value.txt"], repo_root=repo, cas_root=cas),
            [],
        )
        digest = yaml.safe_load(manifest.read_text())["entries"][0]["sha256"]
        self.assertEqual(os.stat(cas / digest).st_mode & 0o777, 0o644)
        current.unlink()
        _, errors = validate_manifest(manifest, repo_root=repo, cas_root=cas)
        self.assertEqual(errors, [])
        destination = repo / "rebuilt-executable"
        self.assertEqual(
            reconstruct(manifest, destination, repo_root=repo, cas_root=cas),
            [],
        )
        self.assertEqual(os.stat(destination / "lib/value.txt").st_mode & 0o777, 0o755)


if __name__ == "__main__":
    unittest.main()
