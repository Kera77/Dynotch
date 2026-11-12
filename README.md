# Dynotch

Natív macOS alkalmazás (SwiftUI, macOS 14+).

- [Telepítés](#telepítés)
- [Fejlesztés](#fejlesztés)
- [CI/CD](#cicd)
- [Kiadás új verzióval](#kiadás-új-verzióval)
- [Aláírás és Apple notarizáció](#aláírás-és-apple-notarizáció)

## Telepítés

Töltsd le a legfrissebb `Dynotch-X.Y.Z.dmg`-t a
[Releases](https://github.com/Kera77/Dynotch/releases) oldalról, nyisd meg, és húzd az appot
az **Applications** mappába.

> **Aláíratlan build esetén** (amíg a notarizáció nincs beállítva) a macOS figyelmeztet, hogy
> az app nem ellenőrizhető. Megnyitás: *System Settings → Privacy & Security → Open Anyway*,
> vagy terminálból: `xattr -dr com.apple.quarantine /Applications/Dynotch.app`.
> Notarizált buildnél ilyen üzenet nincs.

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
scripts/              build / release / GitHub és aláírás beállító scriptek
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
| [`release.yml`](.github/workflows/release.yml) | `vX.Y.Z` tag push / kézi indítás | Release build, aláírás + notarizáció (ha be van állítva), `.zip` + `.dmg` + `SHA256SUMS.txt`, GitHub Release |
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
   [Releases](https://github.com/Kera77/Dynotch/releases) oldalon.

Próbabuild publikálás nélkül: *Actions → Release → Run workflow*, verzió megadásával; az
eredmény a futás artifactjai között lesz.

## Aláírás és Apple notarizáció

A notarizáció azt jelenti, hogy az Apple automatikusan átvizsgálja az appot, és a Gatekeeper
figyelmeztetés nélkül engedi megnyitni a felhasználóknál. Ehhez **Developer ID** aláírás kell.
Ha az alábbi secretek be vannak állítva, a Release workflow automatikusan aláír, notarizál,
„staple”-öl és a végén ellenőrzi a Gatekeeper elfogadást (`spctl`). Ha nincsenek,
aláíratlan buildet készít.

### 1. Apple Developer Program tagság

Iratkozz fel: <https://developer.apple.com/programs/> (évi 99 USD). Jóváhagyás után
megkapod a **Team ID**-t (10 karakter): <https://developer.apple.com/account> → *Membership details*.

### 2. Developer ID Application tanúsítvány

Ehhez Xcode kell (vagy Keychain Access CSR-rel a developer portálon).

1. Xcode → *Settings → Accounts* → add hozzá az Apple ID-d.
2. Válaszd ki a csapatot → *Manage Certificates…* → **+** → **Developer ID Application**.
3. Ellenőrzés terminálban:
   ```bash
   security find-identity -v -p codesigning
   # 1) ABC123... "Developer ID Application: Név (TEAMID)"
   ```
   Az idézőjeles rész az **aláírási identitás**, ez kell majd.

> Csak az Account Holder szerepkör hozhat létre Developer ID tanúsítványt.

### 3. Exportálás `.p12`-be

1. Nyisd meg a **Keychain Access**-t → *login* → *My Certificates*.
2. Jobb klikk a „Developer ID Application: …” tételen (a privát kulccsal együtt) → **Export…**
3. Formátum: *Personal Information Exchange (.p12)*, adj meg erős jelszót.

A `.p12` fájlt ne tedd a repóba, és beállítás után biztonságos helyen tárold (pl. jelszókezelő).

### 4. App-specifikus jelszó a notarizációhoz

<https://account.apple.com> → *Sign-In and Security* → **App-Specific Passwords** → új jelszó
(pl. „Dynotch notarization”). Formátum: `xxxx-xxxx-xxxx-xxxx`.

### 5. Secretek feltöltése a GitHubra

A legegyszerűbb a mellékelt scripttel (interaktívan kéri az adatokat, semmit nem ír lemezre):

```bash
./scripts/setup-signing-secrets.sh ~/Downloads/DeveloperID.p12
```

Vagy kézzel: *Settings → Secrets and variables → Actions → New repository secret*:

| Secret | Tartalom |
|---|---|
| `DEVELOPER_ID_CERT_P12` | a `.p12` base64-ben: `base64 -i DeveloperID.p12 \| pbcopy` |
| `DEVELOPER_ID_CERT_PASSWORD` | a `.p12` jelszava |
| `DEVELOPER_ID_APPLICATION` | aláírási identitás, pl. `Developer ID Application: Név (TEAMID)` |
| `APPLE_TEAM_ID` | Team ID |
| `APPLE_ID` | Apple ID e-mail |
| `APPLE_APP_PASSWORD` | app-specifikus jelszó |

### 6. Notarizált kiadás

Adj ki egy új verziót a [fent leírt módon](#kiadás-új-verzióval). A Release workflow logjában
ezt kell látnod:

```
==> Notarizing app
  status: Accepted
==> Verifying Gatekeeper acceptance
Dynotch.app: accepted
source=Notarized Developer ID
```

Letöltött példány ellenőrzése bármely Macen:

```bash
spctl --assess --type execute -vv /Applications/Dynotch.app
# accepted, source=Notarized Developer ID
```

### Hibaelhárítás

| Hiba | Ok / megoldás |
|---|---|
| `no identity found` | A `DEVELOPER_ID_APPLICATION` nem pontosan egyezik a tanúsítvány nevével. |
| `status: Invalid` notarizációnál | Részletek: `xcrun notarytool log <submission-id> --apple-id … --team-id … --password …` |
| `HTTP 401` a notarytoolnál | Rossz app-specifikus jelszó vagy Apple ID, illetve lejárt a Developer Program tagság. |
| Lejárt tanúsítvány | A Developer ID 5 évig érvényes. Újítsd meg, exportáld, és futtasd újra a setup scriptet. |
