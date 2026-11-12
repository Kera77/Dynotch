# Dynotch

Natív macOS alkalmazás (SwiftUI, macOS 14+).

- [Telepítés](#telepítés)
- [Fejlesztés](#fejlesztés)
- [CI/CD](#cicd)
- [Kiadás új verzióval](#kiadás-új-verzióval)

## Telepítés

Személyes használatra készül, Apple aláírás/notarizáció nélkül (ad-hoc aláírt build).
A legfrissebb kiadás telepítése `/Applications`-be:

```bash
make install              # legfrissebb
make install TAG=v0.1.0   # adott verzió
```

A script letölti a release-t, ellenőrzi a SHA256-ot, és eltávolítja a karantén jelzést,
így a Gatekeeper nem figyelmeztet. Ha mégis kézzel töltöd le a `.dmg`-t, első indításkor:
*System Settings → Privacy & Security → Open Anyway*.

## Fejlesztés

Követelmények: **Xcode 16+** és **Homebrew**.

```bash
make bootstrap   # xcodegen, swiftlint, gh telepítése (Brewfile)
make open        # Xcode projekt generálása project.yml-ből és megnyitása
make test        # unit tesztek
make lint        # SwiftLint (--strict, ugyanaz, mint a CI-ban)
make release     # lokális Release build -> dist/
```

Az `Dynotch.xcodeproj` **generált** fájl, nincs verziókezelve. Projektbeállítást (target,
bundle ID, build setting, verzió) a [`project.yml`](project.yml)-ben módosíts, majd `make generate`.

### Struktúra

```
Dynotch/Sources       Swift forrás
Dynotch/Resources     Assets, Info.plist, entitlements
DynotchTests          Swift Testing unit tesztek
scripts/              build / release / install / GitHub bootstrap scriptek
.github/workflows     CI és Release workflow
```

### Munkafolyamat

1. Új ág: `git checkout -b feature/valami`
2. Változtatás, `make lint test`
3. PR a `main`-re. A CI (SwiftLint + Build & Test) zöld kell legyen merge előtt.
4. Squash merge.

## CI/CD

| Workflow | Mikor fut | Mit csinál |
|---|---|---|
| [`ci.yml`](.github/workflows/ci.yml) | push a `main`-re, minden PR | SwiftLint, build, unit tesztek |
| [`release.yml`](.github/workflows/release.yml) | `vX.Y.Z` tag push / kézi indítás | Release build, `.zip` + `.dmg` + `SHA256SUMS.txt`, GitHub Release |
| Dependabot | hetente | GitHub Actions verziófrissítő PR-ok |

## Kiadás új verzióval

1. Frissítsd a [`CHANGELOG.md`](CHANGELOG.md)-t.
2. Tag és push:
   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```
3. A Release workflow a tagből veszi a verziót (`MARKETING_VERSION`), a build szám a
   workflow futás sorszáma. Pár perc múlva megjelenik a
   [Releases](https://github.com/Kera77/Dynotch/releases) oldalon. Telepítés: `make install`.

Próbabuild publikálás nélkül: *Actions → Release → Run workflow*, verzió megadásával; az
eredmény a futás artifactjai között lesz.
