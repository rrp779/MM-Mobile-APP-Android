# Summary of Changes

## 1. Pinned Compatible Flutter Version (3.41.6) in CI
* **Issue:** The release pipeline previously specified `--flutter-version=3.29.0`, which conflicted with `pubspec.lock` (requiring Flutter `>=3.32.0` / Dart `>=3.9.0-0`) and the project's Android Gradle Plugin configuration (AGP `8.11.1`, Kotlin `2.2.20`, Gradle `8.13`, `compileSdk 36`).
* **Change:** Updated `.github/workflows/shorebird_release.yml` to pin Flutter `3.41.6` for both Android and iOS release commands.

## 2. Temporary Gradle Diagnostic Step
* **Change:** Added a pre-build step in `shorebird_release.yml`:
  ```yaml
  # TEMP: remove once the release passes
  - name: "TEMP: Gradle diagnostics"
    run: shorebird flutter build appbundle --release --verbose
  ```
  This surfaces detailed Gradle build output directly in the GitHub Actions console if any compilation issues occur prior to artifact packaging.

## 3. Moved Signing Credentials Out of Version Control
* **Issue:** `android/app/upload-keystore.jks` and `android/key.properties` were committed to Git, posing a security vulnerability.
* **Change:**
  * Removed tracking from Git with `git rm --cached` while preserving local files on disk.
  * Updated `.gitignore` to explicitly ignore `*.jks`, `*.keystore`, `android/app/*.jks`, `android/app/*.keystore`, and `android/key.properties`.
  * Added a non-echoing reconstitution step in `.github/workflows/shorebird_release.yml` and `.github/workflows/shorebird_patch.yml` to decode `upload-keystore.jks` and write `android/key.properties` from GitHub repository secrets before building.

## 4. Kept Production Version Unchanged
* Maintained `version: 1.0.28+35` in `pubspec.yaml` without bumping.
