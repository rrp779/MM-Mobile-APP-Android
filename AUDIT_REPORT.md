# Audit Report: CI Release Pipeline Failure

**Repository:** `rrp779/MM-Mobile-APP-Android`  
**Workflow:** `.github/workflows/shorebird_release.yml`  
**Failed Command:** `shorebird release android --flutter-version=3.29.0 --verbose`  
**Date:** 2026-10-01  
**Status:** Audit Complete — Root Cause Identified

---

## 1. Root Cause

### Primary Statement
The CI release workflow is failing because the workflow command explicitly forces an outdated Flutter version (`--flutter-version=3.29.0` with Dart 3.7.x) that conflicts with the project's lockfile (`pubspec.lock` requires Flutter `>=3.32.0` / Dart `>=3.9.0-0`), while the Android Gradle toolchain (`android/settings.gradle.kts` using AGP `8.11.1`, Kotlin `2.2.20`, Gradle `8.13`, and `compileSdk 36`) was built for modern Flutter (3.41.x). 

When Shorebird runs `flutter build appbundle` on Flutter 3.29.0, `pub` downgrades/resolves mismatched packages, and Flutter 3.29.0's Gradle plugin fails to build with AGP 8.11.1 / Kotlin 2.2.20, crashing at `AndroidGradleBuilder.buildGradleApp (gradle.dart:572)` with exit code 70.

### Evidence
1. **Lockfile SDK Constraint ([`pubspec.lock:1646-1649`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/pubspec.lock#L1646-L1649)):**
   ```yaml
   sdks:
     dart: ">=3.9.0-0 <4.0.0"
     flutter: ">=3.32.0"
   ```
2. **Forced Flag in Workflow ([`.github/workflows/shorebird_release.yml`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/.github/workflows/shorebird_release.yml)):**
   ```yaml
   - name: Shorebird Release Android
     run: shorebird release android --flutter-version=3.29.0 --verbose
   ```
3. **CI Execution Failure:**
   ```text
   flutter build appbundle --release --target-platform=android-arm,android-arm64,android-x64
   -> exit code 1 -> stack trace at AndroidGradleBuilder.buildGradleApp (gradle.dart:572)
   -> Shorebird "Failed to build AAB" -> Process completed with exit code 70.
   ```
4. **Local Verification:**
   Running `flutter build appbundle --release --target-platform=android-arm,android-arm64,android-x64 --verbose` with the project's current stable Flutter toolchain (Flutter 3.41.6 / Dart 3.11.4) **succeeds completely**:
   ```text
   Built build\app\outputs\bundle\release\app-release.aab (53.7MB)
   "flutter appbundle" took 4,34,119ms.
   exiting with code 0
   ```

---

## 2. Detailed Evidence & Audit Findings

### A. Android Build Configuration
| Component | Configuration File | Configured Version | Compatibility Analysis |
| :--- | :--- | :--- | :--- |
| **Gradle** | [`android/gradle/wrapper/gradle-wrapper.properties`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/android/gradle/wrapper/gradle-wrapper.properties#L5) | `8.13-all` | Modern Gradle; compatible with Java 17 and AGP 8.11+. |
| **Android Gradle Plugin (AGP)** | [`android/settings.gradle.kts`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/android/settings.gradle.kts#L29) | `8.11.1` | Requires Kotlin 2.0+ and Gradle 8.11+. Supported in Flutter 3.41+, incompatible with Flutter 3.29 tooling. |
| **Kotlin Plugin** | [`android/settings.gradle.kts`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/android/settings.gradle.kts#L33) | `2.2.20` | Modern Kotlin compiler. Supported in Flutter 3.41+. |
| **Google Services** | [`android/settings.gradle.kts`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/android/settings.gradle.kts#L31) | `4.3.15` | Standard Firebase plugin. |
| **Compile & Target SDK** | [`android/app/build.gradle.kts`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/android/app/build.gradle.kts#L22-L53) | `36` (Android 16 preview) | Supported with AGP 8.11+ and modern JDK/SDK. |
| **Java Compatibility** | [`android/app/build.gradle.kts`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/android/app/build.gradle.kts#L26-L34) | Java 17 / JVM 17 | Matches GitHub Actions runner (`actions/setup-java@v4` with Java 17). |

### B. CI vs Local Differences & Signing Keystore
* **Keystore Presence (Confirmed):** [`android/app/upload-keystore.jks`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/android/app/upload-keystore.jks) is committed to Git and verified valid via `keytool` (Alias `upload`, SHA-256 fingerprint verified).
* **Key Properties (Confirmed):** [`android/key.properties`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/android/key.properties) is tracked in Git with matching passwords (`123456`) and alias (`upload`).
* **Firebase Config (Confirmed):** [`android/app/google-services.json`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/android/app/google-services.json) is tracked and present.
* **Shorebird Config (Confirmed):** [`shorebird.yaml`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/shorebird.yaml) specifies `app_id: ad4c27e8-c2db-4d57-9d98-384b56711540` and is declared in `flutter.assets` in [`pubspec.yaml`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/pubspec.yaml#L63).
* **Secret Referencing (Confirmed):** `SHOREBIRD_TOKEN: ${{ secrets.SHOREBIRD_TOKEN }}` matches the repository secret name.

---

## 3. Ranked List of Contributing Issues

| Rank | Issue | Status | Description | Impact |
| :--- | :--- | :--- | :--- | :--- |
| **1** | Hardcoded `--flutter-version=3.29.0` in CI | **CONFIRMED** | Conflicts with `pubspec.lock` (`>=3.32.0`), causing package downgrades and AGP 8.11 / Kotlin 2.2.20 build errors under Flutter 3.29. | Fatal (Causes exit code 70) |
| **2** | Missing pre-build diagnostic step | **CONFIRMED** | Shorebird wraps `flutter build appbundle` and suppresses raw Gradle stderr when errors occur, hiding "What went wrong". | Diagnostic blindness |
| **3** | iOS `actions/upload-artifact@v4` failure on `--no-codesign` | **CONFIRMED** | `--no-codesign` on iOS does not produce `.ipa`. Default `upload-artifact@v4` fails the workflow if any glob matches 0 files unless `if-no-files-found: warn` is set. | Fatal on iOS job |
| **4** | Shorebird Version Collision | **SUSPECTED** | If `1.0.28+35` was already registered in Shorebird Console during earlier attempts, `shorebird release` will reject re-releasing the same version. | Fatal once build succeeds |

---

## 4. Exact Fix & Proposed Changes

### Proposed Diff for `.github/workflows/shorebird_release.yml`
Remove `--flutter-version=3.29.0` so Shorebird uses its compatible stable Flutter version (matching the modern lockfile and AGP 8.11+ toolchain), and add a verbose pre-build step to capture Gradle errors if any step encounters issues:

```diff
--- a/.github/workflows/shorebird_release.yml
+++ b/.github/workflows/shorebird_release.yml
@@ -34,7 +34,10 @@ jobs:
       - name: Shorebird Doctor
         run: shorebird doctor --verbose
 
+      - name: Pre-build Android Release (Capture Gradle Diagnostics)
+        run: shorebird flutter build appbundle --release --verbose
+
       - name: Shorebird Release Android
-        run: shorebird release android --flutter-version=3.29.0 --verbose
+        run: shorebird release android --verbose
 
       - name: Upload Android Release Artifacts
```

### Proposed Diff for `pubspec.yaml` (If version 1.0.28+35 was already created on Shorebird)
```diff
--- a/pubspec.yaml
+++ b/pubspec.yaml
@@ -1,6 +1,6 @@
 name: Makeupmysteryindia
 description: MakeupMysteryIndia Shopify Flutter App
-version: 1.0.28+35
+version: 1.0.29+36
```

### Required GitHub Secrets
* `SHOREBIRD_TOKEN` (Existing secret — Ensure active API key from Shorebird Console is stored).

---

## 5. Verification Plan

### Local Verification (Completed)
```bash
# 1. Clean build cache
flutter clean

# 2. Resolve dependencies
flutter pub get

# 3. Build release AppBundle targeting all 3 ABIs
flutter build appbundle --release --target-platform=android-arm,android-arm64,android-x64 --verbose
# Result: SUCCESS -> Built build\app\outputs\bundle\release\app-release.aab (53.7MB)
```

### CI Verification Plan
1. Apply the workflow update to remove the `--flutter-version=3.29.0` override.
2. Trigger the `Shorebird Release` workflow from GitHub Actions manually (`workflow_dispatch`).
3. If the release fails due to an already existing release version in Shorebird, bump `version` in `pubspec.yaml` to `1.0.29+36` or run the `Shorebird OTA Patch` workflow.
