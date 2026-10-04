#!/usr/bin/env python3
"""Fetch and build the embedded Tricky Addon Enhanced backend.

The backend (Tricky Addon Enhanced by Enginex0, GPLv3) is pinned in
.github/ta-enhanced.json by tag and commit. This script:

  1. verifies the upstream tag still points at the pinned commit,
  2. downloads the pinned raw files (resetprop-rs, prop.sh, install_func.sh,
     more-exclude.json, LICENSE) and verifies their sha256,
  3. downloads the source tree of the pinned commit (cached under .cache/),
  4. cross-compiles `ta-enhanced` for aarch64-linux-android with cargo-ndk,
  5. stages everything into module/taenh/ for packaging.

Usage: build-ta-enhanced.py [--skip] [--force]

  --skip    do nothing (used by build-module.ps1 -SkipTaEnhanced)
  --force   rebuild even if the staged binary matches the pinned commit

Environment: HTTP(S)_PROXY are honored; ANDROID_NDK_HOME or ANDROID_HOME
must point at an SDK with the patched NDK.
"""

import argparse
import glob
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PIN_FILE = os.path.join(ROOT, ".github", "ta-enhanced.json")
PATCH_DIR = os.path.join(ROOT, "patches", "ta-enhanced")
CACHE_DIR = os.path.join(ROOT, ".cache")
STAGE_DIR = os.path.join(ROOT, "module", "taenh")
STAGE_BIN_DIR = os.path.join(STAGE_DIR, "arm64-v8a")


def log(msg: str) -> None:
    print(f"[ta-enhanced] {msg}", flush=True)


def die(msg: str) -> None:
    print(f"[ta-enhanced] ERROR: {msg}", file=sys.stderr, flush=True)
    sys.exit(1)


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def download(url: str, dest: str, retries: int = 3) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "teesimulator-rs-build"})
    last_err = None
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp, open(dest, "wb") as f:
                shutil.copyfileobj(resp, f)
            return
        except Exception as exc:  # noqa: BLE001 - retry network errors
            last_err = exc
            log(f"download attempt {attempt}/{retries} failed: {exc}")
    die(f"failed to download {url}: {last_err}")


def verify_tag_commit(repo: str, tag: str, commit: str) -> None:
    url = f"https://github.com/{repo}.git"
    try:
        out = subprocess.run(
            ["git", "ls-remote", url, f"refs/tags/{tag}", f"refs/tags/{tag}^{{}}"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        die(f"git ls-remote failed for {url}: {exc}")
    found = None
    for line in out.splitlines():
        sha, ref = line.split("\t", 1)
        if ref.endswith("^{}"):
            found = sha  # peeled annotated tag wins
        elif found is None:
            found = sha
    if found != commit:
        die(f"tag {tag} points at {found}, expected {commit} - refusing to build")


def find_ndk() -> str:
    ndk = os.environ.get("ANDROID_NDK_HOME") or os.environ.get("ANDROID_NDK_ROOT")
    if ndk and os.path.isdir(ndk):
        return ndk
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if sdk and os.path.isdir(os.path.join(sdk, "ndk")):
        versions = []
        for name in os.listdir(os.path.join(sdk, "ndk")):
            path = os.path.join(sdk, "ndk", name)
            if os.path.isfile(os.path.join(path, "source.properties")):
                versions.append((name, path))
        if versions:
            versions.sort(key=lambda item: item[0])
            return versions[-1][1]
    die("no Android NDK found (set ANDROID_NDK_HOME or ANDROID_HOME)")
    return ""  # unreachable


def patch_files() -> list:
    return sorted(glob.glob(os.path.join(PATCH_DIR, "*.patch")))


def patch_fingerprint() -> str:
    files = patch_files()
    if not files:
        return "nopatch"
    digest = hashlib.sha256()
    for path in files:
        with open(path, "rb") as f:
            digest.update(f.read())
    return digest.hexdigest()[:16]


def apply_patches(src_dir: str) -> None:
    for path in patch_files():
        name = os.path.basename(path)
        reverse = subprocess.run(
            ["git", "apply", "--reverse", "--check", path],
            cwd=src_dir,
            capture_output=True,
            text=True,
        )
        if reverse.returncode == 0:
            continue  # already applied
        check = subprocess.run(
            ["git", "apply", "--check", path],
            cwd=src_dir,
            capture_output=True,
            text=True,
        )
        if check.returncode != 0:
            die(f"{name} does not apply: {check.stderr.strip()}")
        applied = subprocess.run(["git", "apply", path], cwd=src_dir)
        if applied.returncode != 0:
            die(f"{name} failed to apply")
        log(f"applied {name}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip", action="store_true")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    if args.skip:
        log("skipped (--skip)")
        return

    with open(PIN_FILE, encoding="utf-8") as f:
        pin = json.load(f)

    repo = pin["repo"]
    tag = pin["tag"]
    commit = pin["commit"]
    raw_files = pin["rawFiles"]

    marker = os.path.join(STAGE_DIR, ".pin")
    staged_bin = os.path.join(STAGE_BIN_DIR, "ta-enhanced")
    marker_expected = f"{commit} {patch_fingerprint()}"
    if not args.force and os.path.isfile(staged_bin) and os.path.isfile(marker):
        with open(marker, encoding="utf-8") as f:
            if f.read().strip() == marker_expected:
                log(f"backend already staged for {tag} ({commit[:7]})")
                return

    verify_tag_commit(repo, tag, commit)

    os.makedirs(STAGE_BIN_DIR, exist_ok=True)
    os.makedirs(CACHE_DIR, exist_ok=True)

    # --- raw files ---------------------------------------------------------
    destinations = {
        "bin/arm64-v8a/resetprop-rs": os.path.join(STAGE_BIN_DIR, "resetprop-rs"),
        "prop.sh": os.path.join(STAGE_DIR, "prop.sh"),
        "install_func.sh": os.path.join(STAGE_DIR, "install_func.sh"),
        "more-exclude.json": os.path.join(STAGE_DIR, "more-exclude.json"),
        "LICENSE": os.path.join(STAGE_DIR, "LICENSE"),
    }
    for path, expected in raw_files.items():
        dest = destinations[path]
        if not os.path.isfile(dest) or sha256_file(dest) != expected or args.force:
            log(f"fetching {path}")
            url = f"https://raw.githubusercontent.com/{repo}/{commit}/{path}"
            download(url, dest)
        actual = sha256_file(dest)
        if actual != expected:
            die(f"sha256 mismatch for {path}: {actual} != {expected}")

    # --- source tree -------------------------------------------------------
    src_dir = os.path.join(CACHE_DIR, f"tae-src-{commit}")
    cargo_toml = os.path.join(src_dir, "rust", "Cargo.toml")
    fp_file = os.path.join(src_dir, ".tae-patch-fp")
    current_fp = patch_fingerprint()
    cached_fp = ""
    if os.path.isfile(fp_file):
        with open(fp_file, encoding="utf-8") as f:
            cached_fp = f.read().strip()
    src_ok = os.path.isfile(cargo_toml) and cached_fp == current_fp
    if args.force or not src_ok:
        if os.path.isdir(src_dir):
            shutil.rmtree(src_dir, ignore_errors=True)
        os.makedirs(src_dir, exist_ok=True)
        tarball = os.path.join(CACHE_DIR, f"tae-src-{commit}.tar.gz")
        if not os.path.isfile(tarball):
            log(f"downloading source archive for {commit[:7]}")
            download(f"https://github.com/{repo}/archive/{commit}.tar.gz", tarball)
        with tarfile.open(tarball, "r:gz") as tar:
            members = tar.getmembers()
            top = members[0].name.split("/")[0]
            for member in members:
                if not member.name.startswith(top + "/"):
                    continue
                member.name = member.name[len(top) + 1 :]
                if member.name:
                    tar.extract(member, src_dir, filter="data")
        if not os.path.isfile(cargo_toml):
            die("source extraction incomplete (rust/Cargo.toml missing)")
        apply_patches(src_dir)
        with open(fp_file, "w", encoding="utf-8") as f:
            f.write(current_fp + "\n")

    # --- build -------------------------------------------------------------
    abi = pin["abi"]
    os.environ.setdefault("ANDROID_NDK_HOME", find_ndk())
    env = dict(os.environ)
    log(f"building ta-enhanced for {abi} (NDK: {env['ANDROID_NDK_HOME']})")
    cargo = ["cargo", "ndk", "-t", abi, "build", "--release"]
    result = subprocess.run(cargo, cwd=os.path.join(src_dir, "rust"), env=env)
    if result.returncode != 0:
        die("cargo-ndk build failed")

    built = os.path.join(
        src_dir, "rust", "target", pin["cargo_target"], "release", "ta-enhanced"
    )
    if not os.path.isfile(built):
        die(f"built binary missing at {built}")
    shutil.copy2(built, staged_bin)
    if platform.system() != "Windows":
        os.chmod(staged_bin, 0o755)
    for name in ("resetprop-rs",):
        path = os.path.join(STAGE_BIN_DIR, name)
        if platform.system() != "Windows":
            os.chmod(path, 0o755)

    with open(marker, "w", encoding="utf-8") as f:
        f.write(marker_expected + "\n")

    log(f"staged {tag} ({commit[:7]}) -> module/taenh/")
    log(f"  ta-enhanced : {os.path.getsize(staged_bin)} bytes")
    log(f"  resetprop-rs: {os.path.getsize(os.path.join(STAGE_BIN_DIR, 'resetprop-rs'))} bytes")


if __name__ == "__main__":
    main()
