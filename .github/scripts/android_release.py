"""Validate release metadata and prepare Android signing without logging secrets."""

import argparse
import base64
import os
from pathlib import Path
import re
import subprocess
import sys


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def metadata(tag, run_number, prerelease=False):
    if not tag or tag.startswith("-"):
        raise ValueError("Specify an existing git tag, not a branch or commit.")
    subprocess.run(["git", "check-ref-format", f"refs/tags/{tag}"], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    commit = git("rev-parse", "--verify", f"refs/tags/{tag}^{{commit}}")
    pubspec = git("show", f"{commit}:pubspec.yaml")
    version = re.search(r"^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$", pubspec, re.M)
    if not version:
        raise ValueError("The tagged pubspec.yaml must contain a numeric x.y.z version.")
    semver_tag = re.fullmatch(r"v?(\d+\.\d+\.\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?", tag)
    build_name = semver_tag[1] if semver_tag else version[1]
    build_number = 1_000_000 + int(run_number)
    if int(run_number) <= 0 or build_number > 2_100_000_000:
        raise ValueError("Run number exceeds Android versionCode bounds.")
    return {"tag": tag, "commit": commit, "build_name": build_name,
            "build_number": str(build_number),
            "prerelease": str(prerelease or bool(semver_tag and semver_tag[2])).lower()}


def properties_escape(value):
    # java.util.Properties.load(InputStream) reads ISO-8859-1; use ASCII escapes.
    result = []
    for char in value:
        if char in "\\ :=#!":
            result.append("\\" + char)
        elif char in "\n\r\t\f":
            result.append({"\n": "\\n", "\r": "\\r", "\t": "\\t", "\f": "\\f"}[char])
        elif ord(char) < 32 or ord(char) > 126:
            encoded = char.encode("utf-16-be")
            result.extend(f"\\u{int.from_bytes(encoded[i:i+2], 'big'):04x}"
                          for i in range(0, len(encoded), 2))
        else:
            result.append(char)
    return "".join(result)


def signing(root, environ):
    names = ["ANDROID_KEYSTORE_BASE64", "ANDROID_KEYSTORE_PASSWORD",
             "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD"]
    missing = [name for name in names if not environ.get(name)]
    if missing:
        raise ValueError("Configure Repository Secrets: " + ", ".join(missing))
    try:
        keystore = base64.b64decode("".join(environ[names[0]].split()), validate=True)
    except (ValueError, UnicodeError) as error:
        raise ValueError("ANDROID_KEYSTORE_BASE64 is invalid Base64.") from error
    if not keystore:
        raise ValueError("ANDROID_KEYSTORE_BASE64 decodes to an empty file.")
    path = Path(root).resolve() / "android/app/release-signing.jks"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(keystore)
    path.chmod(0o600)
    values = {"storeFile": str(path), "storePassword": environ[names[1]],
              "keyAlias": environ[names[2]], "keyPassword": environ[names[3]]}
    properties = path.parent.parent / "key.properties"
    properties.write_text("".join(f"{key}={properties_escape(value)}\n"
                                  for key, value in values.items()), encoding="ascii")
    properties.chmod(0o600)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["metadata", "signing"])
    args = parser.parse_args()
    try:
        if args.command == "metadata":
            values = metadata(os.environ["RELEASE_TAG"], os.environ["GITHUB_RUN_NUMBER"],
                              os.environ.get("MANUAL_PRERELEASE") == "true")
            with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
                for key, value in values.items():
                    output.write(f"{key}={value}\n")
        else:
            signing(".", os.environ)
    except (ValueError, subprocess.CalledProcessError, KeyError) as error:
        # Only metadata / variable names are reported; never echo signing values.
        print(f"Release configuration error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
