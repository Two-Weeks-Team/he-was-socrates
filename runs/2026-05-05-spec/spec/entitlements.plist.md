# Entitlements & Hardened Runtime — He Was Socrates

**Authored:** 2026-05-05T16:15+09:00 (KST)
**Bundle ID:** `com.twoweeks.hewassocrates`
**Min OS:** macOS 14.0 (Sonoma) — Apple Silicon arm64-only
**Hardened Runtime:** ENABLED
**Library Validation:** ENABLED (default with Hardened Runtime)

This document is the canonical entitlement and Info.plist usage-string contract. SPEC.md §11 references it. Addresses SC7-001, SC7-005, SC7-012, SC7-013.

---

## 1. Required entitlements (must be `true`)

| Key | Value | Rationale |
|---|---|---|
| `com.apple.security.app-sandbox` | true | App Sandbox required for MAS, recommended for DMG |
| `com.apple.security.device.audio-input` | true | Microphone for SFSpeechRecognizer |
| `com.apple.security.files.user-selected.read-write` | true | JSON export to user-chosen path via NSOpenPanel |

## 2. Conditional entitlements (verify need before adding)

| Key | Default for this app | Verification step before enabling |
|---|---|---|
| `com.apple.security.cs.allow-jit` | OMITTED | SPEC_AUTHOR + SC6 spike test confirms MLX-Swift on M-series does NOT need this (Metal compiles offline). Only add if test fails. |

## 3. PROHIBITED entitlements (must be ABSENT or false)

CI gate enforces:
```sh
codesign -d --entitlements :- ./HeWasSocrates.app | grep -E "(network\\.client|network\\.server|disable-library-validation|allow-unsigned-executable-memory|allow-dyld-environment-variables|device\\.camera|personal-information\\.(location|calendars|contacts|photos-library))" && exit 1
```

| Key | Why prohibited |
|---|---|
| `com.apple.security.network.client` | L20 / SC7-001: 0 byte egress invariant |
| `com.apple.security.network.server` | same |
| `com.apple.security.cs.disable-library-validation` | weakens code-signing trust |
| `com.apple.security.cs.allow-unsigned-executable-memory` | weakens trust |
| `com.apple.security.cs.allow-dyld-environment-variables` | weakens trust |
| `com.apple.security.device.camera` | no camera in MVP |
| `com.apple.security.personal-information.location` | not needed |
| `com.apple.security.personal-information.calendars` | not needed |
| `com.apple.security.personal-information.contacts` | not needed |
| `com.apple.security.personal-information.photos-library` | not needed |

## 4. Info.plist required keys

```xml
<key>CFBundleDevelopmentRegion</key>
<string>en</string>
<key>CFBundleLocalizations</key>
<array>
  <string>en</string>
  <string>ko</string>
</array>
<key>LSMinimumSystemVersion</key>
<string>14.0</string>
<key>LSApplicationCategoryType</key>
<string>public.app-category.education</string>

<!-- TCC usage strings (SC7-005) — both KO and EN required since
     CFBundleLocalizations declares both. Apple displays these
     in the TCC system prompt. They CANNOT be empty. -->

<key>NSMicrophoneUsageDescription</key>
<string>He Was Socrates listens to your wondering questions on this Mac only. No audio leaves your device.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>Speech is converted to text on this Mac only, using Apple's on-device Speech framework.</string>

<!-- Korean variants live in ko.lproj/InfoPlist.strings -->
```

`ko.lproj/InfoPlist.strings`:
```
"NSMicrophoneUsageDescription" = "소크라테스가 당신의 호기심 질문을 이 Mac에서만 듣습니다. 음성은 외부로 나가지 않습니다.";
"NSSpeechRecognitionUsageDescription" = "음성을 텍스트로 변환할 때 이 Mac의 Apple On-Device Speech 기능만 사용합니다.";
```

## 5. SFSpeechRecognizer hard-coded flag

```swift
let request = SFSpeechAudioBufferRecognitionRequest()
request.requiresOnDeviceRecognition = true   // NEVER false
request.shouldReportPartialResults = true
```

If on-device recognition is unavailable for the requested locale, we DO NOT silently fall back to network. We surface `STT.OnDeviceModelMissing.{ko_KR|en_US}` from the error catalog (per L20 + SC4-015).

## 6. Codesign + notarize recipe

```sh
# 1. Codesign with Hardened Runtime
codesign --force --deep --options runtime --timestamp \
  --sign "Developer ID Application: <Two-Weeks-Team Team ID>" \
  --entitlements HeWasSocrates.entitlements \
  HeWasSocrates.app

# 2. Verify
codesign --verify --deep --strict --verbose=4 HeWasSocrates.app
spctl -a -vv -t install HeWasSocrates.app

# 3. Notarize
ditto -c -k --keepParent HeWasSocrates.app HeWasSocrates.zip
xcrun notarytool submit HeWasSocrates.zip \
  --keychain-profile "AC_NOTARY" --wait

# 4. Staple
xcrun stapler staple HeWasSocrates.app

# 5. DMG (also signed + stapled)
create-dmg --volname "He Was Socrates" \
  --window-size 500 320 --icon-size 96 \
  HeWasSocrates.dmg HeWasSocrates.app
codesign --force --sign "Developer ID Application: <Team>" HeWasSocrates.dmg
xcrun notarytool submit HeWasSocrates.dmg --keychain-profile "AC_NOTARY" --wait
xcrun stapler staple HeWasSocrates.dmg
```

`AC_NOTARY` keychain profile holds the App-Specific Password (set with `xcrun notarytool store-credentials`). NEVER committed.

## 7. .gitignore additions (SC7-011)

```
# secrets
*.p12
*.cer
*.mobileprovision
*.p8
*.pem
AuthKey_*.p8
.env
.env.*
# notarization artifacts
*.zip
*.dmg
build/
DerivedData/
```

## 8. Pre-commit secret scan (SC7-011)

`.gitleaks.toml` (committed):

```toml
[[rules]]
id = "apple-app-specific-password"
description = "Apple App-Specific Password (16 chars, hyphenated quartets)"
regex = '''[a-z]{4}-[a-z]{4}-[a-z]{4}-[a-z]{4}'''

[[rules]]
id = "private-key-pem"
description = "PEM private key block"
regex = '''-----BEGIN ((RSA|EC|OPENSSH|PGP) )?PRIVATE KEY( BLOCK)?-----'''
```

Pre-commit hook runs `gitleaks detect --staged --config .gitleaks.toml`.

## 9. Cross-references

- L20 (entitlements decision), SC7-001 (sandbox), SC7-005 (Info.plist usage strings), SC7-006 (model integrity), SC7-011 (secrets), SC7-012 (codesign recipe), SC7-013 (TCC revocation), SC4-015 (on-device dictation requirement)
