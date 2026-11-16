# Dynotch

Natív macOS alkalmazás (SwiftUI, macOS 14+).

- [Telepítés](#telepítés)
- [Fejlesztés](#fejlesztés)
- [CI/CD](#cicd)
- [Kiadás új verzióval](#kiadás-új-verzióval)

## Telepítés

Személyes használatra készül, Apple aláírás/notarizáció nélkül. A kiadásokat egy saját (önaláírt) tanúsítvány írja alá, így a macOS-engedélyek (pl. Naptár) frissítés után is megmaradnak.
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
Dynotch/Resources     Assets (app-ikon: Design/AppIcon.svg-ből), Info.plist, entitlements
DynotchTests          Swift Testing unit tesztek
scripts/              build / release / install / GitHub bootstrap scriptek
.github/workflows     CI és Release workflow
```

### Munkafolyamat

1. Új ág: `git checkout -b feature/valami`
2. Változtatás, `make lint test`
3. PR a `main`-re. A CI (SwiftLint + Build & Test) zöld kell legyen merge előtt.
4. Squash merge.

## Aláíró tanúsítvány

A Release workflow a `SIGNING_CERT_P12` és `SIGNING_CERT_PASSWORD` repo secretekből importálja a
„Dynotch Self-Signed” tanúsítványt. Biztonsági másolat: `~/.dynotch-signing/` (nincs a repóban).
Ha elveszik, új tanúsítványt kell generálni; ilyenkor az engedélyeket egyszer újra meg kell adni.

## CI/CD

| Workflow | Mikor fut | Mit csinál |
|---|---|---|
| [`ci.yml`](.github/workflows/ci.yml) | push a `main`-re, minden PR | SwiftLint, build, unit tesztek |
| [`release.yml`](.github/workflows/release.yml) | `vX.Y.Z` tag push / kézi indítás | Release build, `.zip` + `.dmg` + `SHA256SUMS.txt`, GitHub Release |
| [`preflight.yml`](.github/workflows/preflight.yml) | push a `preflight` ágra | Lint, build, teszt a `main` előtt; hibánál sem jelez sikertelen futást (nincs e-mail) |
| Dependabot | hetente | GitHub Actions verziófrissítő PR-ok |

### Előzetes ellenőrzés Xcode nélkül

Ha a gépen nincs Xcode, a commitot a `main` előtt a GitHubon lehet ellenőrizni:

```bash
./scripts/preflight.sh && git push origin main
```

A script a `preflight` ágra tolja a commitot, megvárja a Preflight workflow-t, és kiírja a hibákat.
Így a `main` ágon nem bukik el a CI, és nem jön róla e-mail.

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

## Licenc

[MIT](LICENSE) – szabadon használható, módosítható és terjeszthető, a szerzői jogi megjegyzés megtartásával.
