# Dynotch

Natív macOS alkalmazás (SwiftUI, macOS 14+).

## Fejlesztés

Követelmények: Xcode 16+ és Homebrew.

```bash
make bootstrap   # xcodegen, swiftlint, gh telepítése
make open        # Xcode projekt generálása (project.yml-ből) és megnyitása
make test        # unit tesztek
make lint        # SwiftLint
```

Az `.xcodeproj` **generált** fájl, nincs verziókezelve – a projektbeállításokat a
[`project.yml`](project.yml)-ben kell módosítani, majd `make generate`.

## Struktúra

```
Dynotch/Sources      Swift forrás
Dynotch/Resources    Assets, Info.plist, entitlements
DynotchTests         Swift Testing unit tesztek
scripts/             build / release / GitHub bootstrap scriptek
.github/workflows    CI (lint + build + test) és Release
```

## CI/CD

- **CI** (`ci.yml`): minden push-ra és PR-ra SwiftLint + build + teszt (macOS runner).
- **Release** (`release.yml`): `vX.Y.Z` tag push-ra Release build, `.zip` + `.dmg`,
  GitHub Release automatikus release notes-szal.

```bash
git tag v0.1.0 && git push origin v0.1.0
```

### Aláírás és notarizáció (opcionális)

Secrets nélkül a release **aláíratlan** build. Developer ID-val aláírt, notarizált
buildhez állítsd be a repo secrets-et (Settings → Secrets and variables → Actions):

| Secret | Tartalom |
|---|---|
| `DEVELOPER_ID_CERT_P12` | Developer ID Application tanúsítvány `.p12`, base64-ben (`base64 -i cert.p12 \| pbcopy`) |
| `DEVELOPER_ID_CERT_PASSWORD` | a `.p12` jelszava |
| `DEVELOPER_ID_APPLICATION` | pl. `Developer ID Application: Név (TEAMID)` |
| `APPLE_TEAM_ID` | Apple Team ID |
| `APPLE_ID` | Apple ID e-mail (notarizációhoz) |
| `APPLE_APP_PASSWORD` | app-specifikus jelszó (appleid.apple.com) |
