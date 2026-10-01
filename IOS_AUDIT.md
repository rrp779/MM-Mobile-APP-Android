# iOS Release Job Audit Report

**Repository:** `rrp779/MM-Mobile-APP-Android`  
**Target Job:** `release-ios` in [`.github/workflows/shorebird_release.yml`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/.github/workflows/shorebird_release.yml#L66-L95)  
**Date:** 2026-10-01  
**Mode:** Read-Only Audit  

---

## 1. Executive Summary

The iOS release job has been updated to use `--flutter-version=3.41.6 --no-codesign --verbose`. While the core version mismatch has been resolved (matching Android), building iOS releases in CI has specific Xcode, CocoaPods, and Apple signing constraints that must be handled.

---

## 2. Ranked List of Likely Failure Points

### Rank 1: `IPHONEOS_DEPLOYMENT_TARGET` Mismatch between Xcode and Podfile
* **Status:** **CONFIRMED**
* **Locations:**
  * [`ios/Podfile:1`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/ios/Podfile#L1): `platform :ios, '14.0'`
  * [`ios/Runner.xcodeproj/project.pbxproj:485, 618, 669`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/ios/Runner.xcodeproj/project.pbxproj#L485): `IPHONEOS_DEPLOYMENT_TARGET = 13.0;`
* **Analysis:** The Xcode project target is set to iOS `13.0`, whereas CocoaPods defines minimum platform `14.0`. This discrepancy can cause CocoaPods configuration warnings and compilation failures when transitive Firebase/Google pods attempt to compile against iOS 13 headers.
* **Proposed Diff for `ios/Runner.xcodeproj/project.pbxproj`:**
  ```diff
  --- a/ios/Runner.xcodeproj/project.pbxproj
  +++ b/ios/Runner.xcodeproj/project.pbxproj
  @@ -485,3 +485,3 @@
  -				IPHONEOS_DEPLOYMENT_TARGET = 13.0;
  +				IPHONEOS_DEPLOYMENT_TARGET = 14.0;
  @@ -618,3 +618,3 @@
  -				IPHONEOS_DEPLOYMENT_TARGET = 13.0;
  +				IPHONEOS_DEPLOYMENT_TARGET = 14.0;
  @@ -669,3 +669,3 @@
  -				IPHONEOS_DEPLOYMENT_TARGET = 13.0;
  +				IPHONEOS_DEPLOYMENT_TARGET = 14.0;
  ```

---

### Rank 2: Pod Target Deployment Target Override Missing in `post_install`
* **Status:** **CONFIRMED**
* **Location:** [`ios/Podfile:38-42`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/ios/Podfile#L38-L42)
* **Analysis:** Certain pods (e.g., `razorpay_flutter.podspec` line 18 specifies iOS `10.0`) define legacy deployment targets that trigger warnings or build errors on newer Xcode versions. Enforcing iOS `14.0` across all Pod targets ensures consistency.
* **Proposed Diff for `ios/Podfile`:**
  ```diff
  --- a/ios/Podfile
  +++ b/ios/Podfile
  @@ -38,5 +38,10 @@
   post_install do |installer|
     installer.pods_project.targets.each do |target|
       flutter_additional_ios_build_settings(target)
  +    target.build_configurations.each do |config|
  +      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
  +    end
     end
   end
  ```

---

### Rank 3: `--no-codesign` Produces `.xcarchive`, NOT a Distributable `.ipa`
* **Status:** **CONFIRMED**
* **Locations:**
  * [`.github/workflows/shorebird_release.yml:84`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/.github/workflows/shorebird_release.yml#L84): `shorebird release ios --flutter-version=3.41.6 --no-codesign --verbose`
  * [`.github/workflows/shorebird_release.yml:91-94`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/.github/workflows/shorebird_release.yml#L91-L94): `build/ios/archive/*.xcarchive`, `build/ios/ipa/*.ipa`
* **Analysis:**
  * Building with `--no-codesign` generates an unsigned `.xcarchive` (`build/ios/archive/Runner.xcarchive`).
  * Shorebird registers the release in the Shorebird Console, but the resulting artifact **cannot be directly installed on physical iOS devices or uploaded to TestFlight / App Store**.
  * The artifact upload step safely handles this via `if-no-files-found: warn`.

---

### Rank 4: Missing Push Notification & Associated Domains Entitlements for Signed Builds
* **Status:** **SUSPECTED**
* **Location:** `ios/Runner/` (No `.entitlements` file present)
* **Analysis:** [`ios/Runner/Info.plist:58-61`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/ios/Runner/Info.plist#L58-L61) configures `UIBackgroundModes` for `remote-notification` (Firebase Messaging) and deep links (`app_links`). Once code signing is added for production distribution, an entitlements file (`Runner.entitlements`) with APS Environment and Associated Domains is required by Xcode.

---

## 3. Configuration Audit Checklist

| Item | Found Setting | Assessment |
| :--- | :--- | :--- |
| **Runner Label** | `runs-on: macos-14` | Supported (Apple Silicon M1, Xcode 15.4 / 16.0). Compatible with Flutter 3.41.6. |
| **Java Setup** | Omitted | Correct (Java is not required for iOS builds). |
| **GoogleService-Info.plist** | Present & Tracked in Git ([`ios/Runner/GoogleService-Info.plist`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/ios/Runner/GoogleService-Info.plist)) | Confirmed valid. |
| **Podfile.lock** | Present & Tracked in Git ([`ios/Podfile.lock`](file:///c:/Users/V-Team/Makeup%20Mystery/MM-Mobile-APP-Android/ios/Podfile.lock)) | Confirmed tracked. |
| **Bundle Identifier** | `com.makeupmystery.india` | Matches Android namespace. |
| **Development Team** | `NXDLAQQJ9V` | Configured in `project.pbxproj`. |

---

## 4. Manual Steps for You (When Ready for Signed iOS Distribution)

1. **Test Unsigned CI Release:**
   * Run the `Shorebird Release` workflow selecting platform `ios` on branch `fix/shorebird-release-and-signing` to verify the unsigned archive builds cleanly on `macos-14`.

2. **Transitioning to Signed Builds for TestFlight / App Store:**
   To generate a signed `.ipa` in CI in the future, add Apple signing credentials to GitHub secrets:
   * `APPLE_CERTIFICATE_BASE64`: Exported Distribution Certificate (`.p12`) encoded in base64.
   * `APPLE_CERTIFICATE_PASSWORD`: Password for the `.p12` file.
   * `APPLE_PROVISIONING_PROFILE_BASE64`: Distribution Provisioning Profile (`.mobileprovision`) in base64.
   * `KEYCHAIN_PASSWORD`: Temporary string to create/lock the runner's ephemeral keychain.
