import base64
from contextlib import contextmanager
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from android_release import metadata, properties_escape, signing


@contextmanager
def working_directory(path):
    previous = os.getcwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(previous)


class ReleaseMetadataTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Release Test")
        self.git("config", "user.email", "test@example.invalid")
        (self.root / "pubspec.yaml").write_text("name: example\nversion: 4.2.11+4211\n")
        self.git("add", ".")
        self.git("commit", "-qm", "Tagged source")
        self.commit = self.git("rev-parse", "HEAD")
        self.git("tag", "v4.2.12")
        self.git("tag", "-a", "v4.2.13-beta.1", "-m", "Prerelease")
        self.git("tag", "nightly/2026-10-07")
        self.git("branch", "branch-only")
        (self.root / "pubspec.yaml").write_text("version: 9.9.9+9999\n")
        self.git("add", ".")
        self.git("commit", "-qm", "Unreleased source")

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, text=True).strip()

    def resolve(self, tag, run=12, prerelease=False):
        with working_directory(self.root):
            return metadata(tag, run, prerelease)

    def test_lightweight_tag_builds_tagged_commit(self):
        result = self.resolve("v4.2.12")
        self.assertEqual(result["commit"], self.commit)
        self.assertEqual(result["build_name"], "4.2.12")
        self.assertEqual(result["build_number"], "1000012")
        self.assertEqual(result["prerelease"], "false")

    def test_annotated_prerelease_tag(self):
        result = self.resolve("v4.2.13-beta.1")
        self.assertEqual(result["commit"], self.commit)
        self.assertEqual(result["prerelease"], "true")
        self.assertEqual(result["build_name"], "4.2.13")

    def test_other_tag_reads_tagged_pubspec_not_current_head(self):
        self.assertEqual(self.resolve("nightly/2026-10-07")["build_name"], "4.2.11")

    def test_manual_prerelease(self):
        self.assertEqual(self.resolve("v4.2.12", prerelease=True)["prerelease"], "true")

    def test_only_existing_tags_allowed(self):
        for tag in ["branch-only", self.commit, "v0.0.0", "bad\ntag", "--help", ""]:
            with self.subTest(tag=tag):
                with self.assertRaises((ValueError, subprocess.CalledProcessError)):
                    self.resolve(tag)

    def test_version_codes_increase_and_reruns_stable(self):
        self.assertEqual(self.resolve("v4.2.12", 12), self.resolve("v4.2.12", 12))
        self.assertGreater(int(self.resolve("v4.2.12", 13)["build_number"]),
                           int(self.resolve("v4.2.12", 12)["build_number"]))

    def test_android_version_code_bounds(self):
        for number in [0, -1, 2_099_000_001]:
            with self.assertRaises(ValueError):
                self.resolve("v4.2.12", number)


class SigningTest(unittest.TestCase):
    def secrets(self):
        return {"ANDROID_KEYSTORE_BASE64": base64.b64encode(b"test-keystore").decode(),
                "ANDROID_KEYSTORE_PASSWORD": " leading:=\\password\n密钥🔑",
                "ANDROID_KEY_ALIAS": "release", "ANDROID_KEY_PASSWORD": "password"}

    def test_missing_secrets_fail_without_writing_files(self):
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaisesRegex(ValueError, "ANDROID_KEYSTORE_BASE64"):
                signing(root, {})
            self.assertFalse((Path(root) / "android").exists())

    def test_invalid_base64_does_not_expose_secret(self):
        secrets = self.secrets()
        secrets["ANDROID_KEYSTORE_BASE64"] = "secret-is-not-base64"
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaises(ValueError) as result:
                signing(root, secrets)
            self.assertNotIn(secrets["ANDROID_KEYSTORE_BASE64"], str(result.exception))

    def test_wrapped_base64_and_private_file_permissions(self):
        secrets = self.secrets()
        secrets["ANDROID_KEYSTORE_BASE64"] = "\n" + secrets["ANDROID_KEYSTORE_BASE64"] + "\n"
        with tempfile.TemporaryDirectory() as root:
            signing(root, secrets)
            key = Path(root) / "android/app/release-signing.jks"
            properties = Path(root) / "android/key.properties"
            self.assertEqual(key.read_bytes(), b"test-keystore")
            self.assertEqual(key.stat().st_mode & 0o777, 0o600)
            self.assertEqual(properties.stat().st_mode & 0o777, 0o600)
            self.assertIn("storePassword=" + properties_escape(secrets["ANDROID_KEYSTORE_PASSWORD"]),
                          properties.read_text())

    def test_java_properties_preserve_special_characters(self):
        # Test the actual Java Properties parser used by Gradle.
        with tempfile.TemporaryDirectory() as root:
            signing(root, self.secrets())
            java = Path(root) / "ReadProperties.java"
            java.write_text('''import java.io.*;
import java.util.*;
import java.nio.charset.StandardCharsets;
class ReadProperties {
  public static void main(String[] args) throws Exception {
    Properties p = new Properties();
    try (InputStream in = new FileInputStream(args[0])) { p.load(in); }
    System.out.print(Base64.getEncoder().encodeToString(
      p.getProperty("storePassword").getBytes(StandardCharsets.UTF_8)));
  }
}''')
            result = subprocess.check_output(["java", str(java),
                                              str(Path(root) / "android/key.properties")], text=True)
            self.assertEqual(base64.b64decode(result).decode(), self.secrets()["ANDROID_KEYSTORE_PASSWORD"])


if __name__ == "__main__":
    unittest.main()
