# Integration layout (`alwaysstrong` branch)

This branch packages **AlwaysStrong** around the engine from
[`MashiroSann/TEESimulator-RS`](https://github.com/MashiroSann/TEESimulator-RS).
It is deliberately not a merge of the two source trees:

| Part | Comes from |
|---|---|
| Module scripts, automation (keybox / fingerprint / patch / props), `webroot` UI, native `aswatcher` / `asfetch` | AlwaysStrong (`module/`, `module-variants/`, `attest/`, `native/`, `build.sh`) |
| `classes.dex`, `lib/<abi>/*.so`, default `keybox.xml` | a pinned TEESimulator-RS release zip |

The standalone TEESimulator-RS WebUI and its Enhanced automation backend are **not**
packaged: AlwaysStrong owns the panel and the refresh loops, so shipping a second
UI/daemon would only duplicate them.

## Engine pin

`build.sh` carries the whole pin:

```sh
TEE_REPO_DEFAULT="MashiroSann/TEESimulator-RS"
TEE_TAG_DEFAULT="v6.0.1-367"
TEE_ASSET_DEFAULT="TEESimulator-RS-v6.0.1-367-Release-NoEnhanced.zip"
```

`--tee`, `--tee-asset` and `--tee-repo` override it for one build;
`--tee-file PATH` uses a local engine zip and skips the download.

The NoEnhanced asset is intentional: it is the same keystore engine as the
Enhanced build without `ta-enhanced`, so it does not compete with AlwaysStrong's
own keybox rotation, patch sync and description updates. The published engine
zip is arm64-v8a only.

## Build

```sh
./build.sh                 # all three lines (default / -inject / -nopif)
./build.sh --variant fork  # one line
```

Outputs land in `out/`. On this branch the build runs on GitHub Actions:

- `.github/workflows/build.yml` — every push to `alwaysstrong`; three zip
  artifacts named `AlwaysStrong`, `AlwaysStrong-inject`, `AlwaysStrong-nopif`.
- `.github/workflows/release.yml` — tag `v1.*`, or dispatch with a tag. Publishes
  the three zips and repoints `update.json` / `update-inject.json` /
  `update-nopif.json` at the release.

## Bumping the engine

1. Publish the new engine release on `main` (the usual `v6.0.1-*` release).
2. On `alwaysstrong`, update `TEE_TAG_DEFAULT` + `TEE_ASSET_DEFAULT` (or run
   `scripts/update-upstream.sh --apply`, which now reads this repository and
   filters for `Release-NoEnhanced`).
3. Bump `version` / `versionCode` in `module/module.prop`, add a `CHANGELOG.md`
   section, commit, push.
4. Tag `v1.x` when it should reach installed modules.
