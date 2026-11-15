# Dynotch – specifikáció

> Állapot: **v0.6 elfogadva** · Utolsó módosítás: 2026-11-16
> Személyes használatra készülő macOS app, amely a MacBook notch-ot interaktív felületté alakítja.

## 0. Általános döntések

| # | Döntés | Indok |
|---|---|---|
| G-1 | **Háttér-app** (`LSUIElement`): nincs Dock-ikon és nincs főablak. Egyetlen felülete a notch, valamint a Beállítások ablak. | A notch az app „ablaka”. |
| G-2 | **App Sandbox kikapcsolva.** | A hangerő- és fényerőbillentyűk elfogásához (event tap) és a beépített kijelző fényerejének állításához (privát `DisplayServices`) kell. Személyes használatnál ez nem akadály. |
| G-3 | Minimum: **macOS 14**, Apple Silicon és Intel. | Már így van beállítva. |
| G-4 | Minden funkció **külön kapcsolható** a Beállításokban. Kikapcsolt funkció nem fut a háttérben. | |
| G-5 | A beállítások `UserDefaults`-ban tárolódnak, újraindítás után is megmaradnak. | |
| G-6 | **Stabil aláírás saját (önaláírt) tanúsítvánnyal** („Dynotch Self-Signed”). A CI ezzel ír alá. | A macOS az adatvédelmi engedélyeket (Naptár, Kisegítő hozzáférés) az aláíráshoz köti; stabil tanúsítvánnyal a frissítések után is megmaradnak. |

---

## 1. Notch ablak

### 1.1 Megjelenés és nyitás

| ID | Követelmény |
|---|---|
| N-1 | Becsukott állapotban a felület pontosan a fizikai notch helyén és méretében van, fekete, és nem látszik külön elemnek. |
| N-2 | **Hoverre nyílik:** amikor az egér a notch területére ér, a panel lefelé és oldalra animálva kinyílik. Kattintás nem kell hozzá. |
| N-3 | **Nyitva marad**, amíg az egér a kinyitott panel területén belül van (a notch-sávot is beleértve). |
| N-4 | **Bezárás késleltetéssel:** ha az egér elhagyja a panelt, a panel *Bezárási késleltetés* idő múlva csukódik be. Ha az egér közben visszatér, a bezárás elmarad. |
| N-5 | **Beállítás:** *Bezárási késleltetés*, 0–3 s, 0,1 s-os lépéssel, alapértéke 0,3 s. |
| N-6 | A panel minden Space-en és teljes képernyős appok felett is működik. |
| N-7 | A panel csak akkor kapja meg a billentyűzetfókuszt, ha szükséges, így nem veszi el a fókuszt az aktív apptól (non-activating panel). |
| N-8 | **Minden csatlakoztatott kijelzőn** van notch-panel, és mindegyikről ugyanúgy elérhető. Kijelző csatlakoztatásakor vagy leválasztásakor a panelek automatikusan újraépülnek. |
| N-9 | **Notch nélküli kijelzőn** egy látható, fekete **virtuális notch** jelenik meg a kijelző felső közepén (185 pt széles, menüsor magasságú), hogy látszódjon, hova kell vinni az egeret. |

> Javaslat (nem kötelező): *Nyitási késleltetés* beállítás (alapból 0 s), ha a véletlen nyitások zavarnak, például amikor a menüsor közepére mész az egérrel.

### 1.2 Felső menüsor (funkcióválasztó)

| ID | Követelmény |
|---|---|
| M-1 | A kinyitott panel tetején, a notch bal oldalán egy **kapszula alakú ikonsor** mutatja a funkciókat. Az aktív funkció ikonja világosabb, lekerekített hátteret kap. |
| M-2 | Egy ikonra kattintva megnyílik a hozzá tartozó funkció. Az aktív funkció ikonja kiemelve látszik. |
| M-3 | A menüsorban csak a bekapcsolt funkciók jelennek meg, a Beállításokban megadott sorrendben. |
| M-4 | Funkciók: *Home* (óra és dátum), *Naptár* (4. fejezet), *Értesítések* (4b. fejezet), *Számológép* (4c. fejezet), *Info* (verzió, kijelző és notch adatai). |
| M-5 | A menüsor jobb szélén egy kapszulában a **lakat** (SZ-8) és a **fogaskerék** (C-1) ül. A notch-tól jobbra eső többi hely állapotjelzéseknek van fenntartva (például hangerő- és fényerő HUD). |

### 1.3 Váltás két ujjas swipe-pal

| ID | Követelmény |
|---|---|
| S-1 | Kinyitott panel felett **vízszintes két ujjas swipe** vált az előző vagy a következő funkcióra. |
| S-2 | Egy swipe-mozdulat pontosan egy váltást jelent, folyamatos görgetés nem lapoz tovább. |
| S-3 | Az első és az utolsó funkciónál a lista nem fordul körbe, egy rövid „rugózó” animáció jelzi a végét. |
| S-4 | A függőleges görgetést megkapja a funkció tartalma, például egy lista. |
| S-5 | **Váltási animáció:** a következő funkcióra váltva az aktuális balra csúszik ki, az új jobbról úszik be; az előzőre váltva fordítva. A kettő együtt mozog, mint egy lapozó. Ugyanez érvényes a menüsor ikonjaira kattintva. |

### 1.4 Utolsó funkció megjegyzése

| ID | Követelmény |
|---|---|
| L-1 | Bezárás után a panel mindig **a legutóbb aktív funkcióval** nyílik ki újra. |
| L-2 | Ez az app újraindítása után is megmarad. Ha a legutóbbi funkciót közben kikapcsoltad, az első elérhető funkció nyílik meg. |

### 1.5 Beállítások elérése és kattintás

| ID | Követelmény |
|---|---|
| C-1 | A menüsor **jobb szélén fogaskerék ikon** nyitja meg a beállításokat. Jobb klikkes menü nincs. |
| C-1b | A beállítások fülei **ikonok**; a fülsor mellett mindig ki van írva a kiválasztott fül neve, hoverre pedig annak a fülnek a neve, amelyik fölött az egér áll. |
| C-2 | Beállítás: **hol nyíljanak meg a beállítások**. *A notchban* (alapértelmezett): a panel a beállítások méretére nő (520 × 440 pt tartalom a menüsor alatt), és minden beállítás a notchban jelenik meg; a fogaskerékre vagy egy funkció ikonjára kattintva, illetve a panel bezárásakor visszatér a funkciókhoz. *Külön ablakban*: a panel becsukódik, és egy normál macOS ablak nyílik meg ugyanazzal a tartalommal. |
| C-3 | Amíg a beállítások a notchban látszanak, a swipe nem vált funkciót, és a panel lenyomott egérgomb mellett (például csúszka húzásakor) nem csukódik be. |
| C-4 | **Bal kattintás** a notch-on nem csinál semmit, mert a panel hoverre nyílik. |
| C-5 | **Kilépés:** *Beállítások › Névjegy › Kilépés a Dynotch-ból*. Az appot újra elindítva (például a Finderből) a beállítások ablaka nyílik meg. |

---|---|
| C-1 | **Jobb klikk** a notch-on vagy a panelen: helyi menü jelenik meg *Beállítások…*, *Névjegy* és *Kilépés* pontokkal. |
| C-2 | **Bal kattintás** a notch-on nem csinál semmit, mert a panel hoverre nyílik. A panelen belüli gombok (például a menüsor ikonjai) kattintásra természetesen működnek. |
| C-3 | A Beállítások ablak egy normál macOS ablak. Megnyitásakor előtérbe jön, bezárásakor az app tovább fut a háttérben. |

---

## 2. Hangerő és fényerő kijelzés (HUD)

### 2.1 Viselkedés

| ID | Követelmény |
|---|---|
| H-1 | Amikor a hangerő vagy a beépített kijelző fényereje változik, a notch **két oldalra kiszélesedik**, fekete sávként, a notch magasságában. |
| H-2 | **Bal oldalon** az ikon látszik: hangszóró (a szinttől függően 0–3 hullámmal, némításkor áthúzva) vagy nap (fényerő). |
| H-3 | **Jobb oldalon** egy **kör alakú jelző** mutatja a szintet 0–100%-ig. A körív animálva követi a változást. |
| H-4 | A HUD az utolsó változás után 1,5 s-mal visszahúzódik. Ha közben újabb változás jön, az időzítés újraindul. |
| H-5 | Ha a panel éppen nyitva van, a HUD a menüsorban, a notch két oldalán ugyanígy megjelenik, és nem zárja be a panelt. |
| H-6 | Hangerőt csak akkor mutat, ha a kimeneti eszköz állítható (például HDMI-kimeneten nem). |

### 2.2 Az Apple-féle HUD helyettesítése

| ID | Követelmény |
|---|---|
| A-1 | Beállítás: **„Rendszer HUD helyettesítése”** (alapból be). |
| A-2 | Bekapcsolva a Dynotch elfogja a hangerő- (F10/F11/F12) és fényerőbillentyűket (F1/F2), maga állítja a szintet, és **az Apple HUD nem jelenik meg**. |
| A-3 | A lépésköz megegyezik a macOS-ével (1/16). **Option+Shift** mellett 1/64-es finom lépés, ahogy a rendszerben. |
| A-4 | Ha a hangerő máshonnan változik (Vezérlőközpont, AirPods, egy app), a Dynotch HUD akkor is megjelenik. |
| A-5 | Kikapcsolt beállításnál, illetve ha a Dynotch kilép vagy összeomlik, a billentyűk a megszokott módon működnek, Apple HUD-dal. |
| A-6 | A billentyűk elfogásához **Kisegítő hozzáférés (Accessibility)** engedély kell. Ha hiányzik, a Beállítások ezt jelzi, és egy gombbal megnyitja a megfelelő Rendszerbeállítások oldalt. |

### 2.3 Hatókör (v0.7)

- Benne van: rendszerhangerő (alapértelmezett kimenet), némítás, a beépített kijelző fényereje.
- Nincs benne: külső monitor fényereje (DDC), billentyűzet-háttérfény, appokénti hangerő.

---

## 3. Beállítások ablak

| Szakasz | Elemek |
|---|---|
| **Általános** | Indítás bejelentkezéskor · Beállítások megnyitása (a notchban / külön ablakban) · Bezárási késleltetés (0–3 s) |
| **Funkciók** | Bekapcsolt funkciók listája, sorrendjük húzással állítható |
| **Értesítések** | Állapot és Teljes lemezelérés · Eltűnési idő (2–30 mp) · Appok ki/be · Útmutató a natív szalagcímek kikapcsolásához |
| **Naptár** | Hozzáférés állapota és engedélyezés · Közelgő esemény jelzése be/ki · Előjelzési idő (1–30 perc) |
| **HUD** (v0.7) | Hangerő/fényerő HUD be/ki · Rendszer HUD helyettesítése · HUD megjelenési ideje (alapból 1,5 s) · Accessibility engedély állapota |
| **Névjegy** | Verzió, build, GitHub-repó linkje, Kilépés |

---

## 4. Naptár (v0.3)

### 4.1 Adatforrás és engedély

| ID | Követelmény |
|---|---|
| K-1 | A Dynotch a **macOS Naptár** összes naptárát olvassa (EventKit): az iCloud és az alapértelmezett Apple-naptárt, valamint a Google-naptárt, ha a fiók a *Rendszerbeállítások › Internetes fiókok* alatt hozzá van adva. Csak olvas, eseményt nem hoz létre. |
| K-2 | Első indításkor (ha a Naptár funkció be van kapcsolva) a macOS engedélyt kér. Engedély nélkül a Naptár funkció és a Beállítások egy gombot mutat, amely kérést indít, vagy ha korábban elutasítottad, megnyitja a megfelelő Rendszerbeállítások oldalt. |
| K-3 | A lista frissül, ha a naptár megváltozik (más eszközről szinkronizált változás is), amikor a panel kinyílik, valamint legalább 5 percenként. |

### 4.2 Napi nézet (lenyitott panel)

| ID | Követelmény |
|---|---|
| K-4 | Felül **napsáv**: bal oldalon a hónap rövid neve, mellette a napok vízszintes sora (a nap betűjele, a dátum, alatta pötty, ha van esemény). A mai nap kék és kiemelt, a hétvége pirosas. Egy napra kattintva az lesz kiválasztva; a sáv fölött két ujjal vízszintesen húzva a napok görgethetők (itt a swipe nem vált funkciót). A panel megnyitásakor mindig a mai nap van kiválasztva. |
| K-5 | A napsáv alatt a **kiválasztott nap eseményei**: cím, alatta pirossal a nap rövid neve és a kezdési idő (egész napos eseménynél „egész nap”). Elöl az egész napos események, utána kezdési idő szerint. A már véget ért események halványítva látszanak. Ha nincs esemény: „Mára nincs esemény”. |
| K-6 | **Csatlakozás gomb** (zöld kapszula), ha az eseményben Zoom-, Google Meet-, Teams- vagy Webex-link van (az esemény URL-jében, helyszínében vagy jegyzetében, az Outlook Safe Links linkeket is felismerve). A meeting **mindig az alapértelmezett böngészőben** nyílik meg, nem közvetlenül a meeting-appban. |

### 4.2b Teljes naptár nézet

| ID | Követelmény |
|---|---|
| K-10 | A napi nézet jobb felső sarkában (a napsáv végén) egy kis ikon a panelt **nagy méretre** nyitja (960 × 340 pt, kisebb kijelzőn a kijelzőhöz igazítva). A jobb felső sarokban lévő ikon visszavált. A panel **megjegyzi a legutóbbi nézetet**, és újranyitáskor (újraindítás után is) ugyanabban nyílik. |
| K-11 | Bal oldalon **havi rács**: év és hónap, előző/következő hónap gombok, a hét a rendszer szerinti első nappal kezdődik, a mai nap kék körben, a napok alatt legfeljebb három pötty az események száma szerint. Egy napra kattintva az lesz kiválasztva. |
| K-12 | Jobb oldalon **napirend** a kiválasztott naptól 14 napra előre: a kiválasztott nap mindig látszik (üresen „Nincs esemény”), utána csak azok a napok, amelyeken van esemény. Soronként: kezdési idő és időtartam, a naptár színe, cím, Csatlakozás gomb. Az első nap fejlécében a hét száma is látszik. |
| K-13 | Esemény létrehozása nincs (K-1: csak olvasás). |

### 4.3 Közelgő esemény jelzés (becsukott notch)

| ID | Követelmény |
|---|---|
| K-7 | Ha egy (nem egész napos) esemény hamarosan kezdődik vagy éppen tart, a becsukott notch két oldalra kiszélesedik: **bal oldalon** egy ikon (videó, ha van meeting-link, egyébként naptár), **jobb oldalon** egy kapszulában másodpercre pontos **visszaszámláló**, amelynek körvonala az idő múlásával arányosan töltődik. |
| K-8 | **Kezdés előtt** (*N* perccel, beállítás: 1–30 perc, alapból 10): a kezdésig hátralévő idő **sárgával**, a körvonal az előjelzési idő eltelt részét mutatja. **Az utolsó 3 percben pirossal.** |
| K-8b | **A meeting alatt**: a meeting végéig hátralévő idő **világoskékkel**, a körvonal a meeting eltelt részét mutatja. A végén a jelzés eltűnik. |
| K-8c | Ha egy meeting tart és közben egy másik az előjelzési időn belül kezdődik, a hamarosan kezdődő látszik. A 24 óránál hosszabb események nem jelennek meg a jelzésben. |
| K-9 | A jelzés kikapcsolható (*Beállítások › Naptár*). A Naptár funkció kikapcsolásakor a jelzés sem jelenik meg. |

---

## 4b. Értesítések (v0.5)

### Adatforrás és engedély

| ID | Követelmény |
|---|---|
| E-1 | A Dynotch a macOS Értesítési központ helyi adatbázisából olvassa az új értesítéseket (másodpercenként ellenőriz). Ehhez **Teljes lemezelérés** engedély kell; nélküle az Értesítések funkció és a Beállítások egy gombot mutat, amely megnyitja a megfelelő Rendszerbeállítások oldalt. Csak az indítás után érkezett értesítések jelennek meg. |
| E-2 | Csak a kiválasztott appok értesítései jelennek meg. Alapból: **Beeper**, valamint a **Gmail** és a **Google Chat** Safari-webapp. A Beállításokban bármelyik telepített, értesítést küldő app ki- és bekapcsolható. |

### Megjelenés

| ID | Követelmény |
|---|---|
| E-3 | **Új értesítéskor** a becsukott notch finoman, csak egy kicsit lenyílik (30 pt-tal), és megmutatja az app ikonját és azt, **ki írt**. A tartalom itt nem látszik. Minden kijelzőn megjelenik. |
| E-4 | **Hoverre** (a notch-ra vagy a lenyílt sávra víve az egeret) a panel kinyílik az *Értesítések* funkcióval, benne az értesítés **tartalmával**. Ez nem írja felül, hogy legközelebb melyik funkció nyílik meg (L-1). |
| E-5 | Az *Értesítések* funkció az indítás óta érkezett értesítéseket listázza (legfeljebb 50, a legújabb elöl): app ikon, feladó, app neve és időpont, szöveg. Egy értesítésre kattintva megnyílik az app. |
| E-6 | A lenyílt sáv a beállított idő után magától eltűnik (**2–30 mp**, alapból 6). |
| E-7 | **Gmail:** a feladó és a levél **tárgya** látszik, a levél szövege nem. **Beeper, Google Chat és más appok:** a feladó és az üzenet szövege. |
| E-8 | **Natív macOS értesítések:** a macOS nem engedi programból kikapcsolni más appok szalagcímeit. A Beállítások útmutatót és gombot ad: az érintett appoknál a szalagcím stílusát „Nincs”-re kell állítani, az „Értesítési központban” kapcsolót bekapcsolva hagyva. Így a macOS nem mutat szalagcímet, a Dynotch viszont megkapja az értesítést. |
| E-9 | Hibakereséshez az app naplót ír ide: `~/Library/Logs/Dynotch/notifications.log`. Ebben csak az adatbázis szerkezete és az appazonosítók szerepelnek, értesítések tartalma nem. |

---

## 4c. Számológép (v0.6)

| ID | Követelmény |
|---|---|
| SZ-1 | Új funkció a notchban, **+/−** ikonnal: egy jegyzetszerű szövegmező. A funkcióra váltva a panel megkapja a billentyűzetet, így azonnal lehet gépelni. Ha a panel hoverre nyílik meg a számológéppel, nem veszi el a fókuszt az éppen használt apptól; ilyenkor a szövegbe kattintva lehet gépelni. |
| SZ-2 | **Soronként számol:** bal oldalon a begépelt számítás, a sor jobb szélén **zölden az eredmény**, gépelés közben azonnal frissülve. Minden sor önálló, a sorok nem hatnak egymásra. |
| SZ-3 | Műveletek: `+ - * /` (a `×`, `x`, `÷` is), hatvány `^`, zárójelek, előjel, százalék (`200 + 10%` = 220, `200 * 15%` = 30). Tizedesjel pont vagy vessző; a számokban szóköz lehet ezres tagoló (`1 200,5`). |
| SZ-4 | Ha a sor nem számítás (szöveg, egyetlen szám, befejezetlen kifejezés, nullával osztás), nincs mellette eredmény. Az eredmény legfeljebb 8 tizedesjegy, tizedesvesszővel és szóközös ezres tagolással. |
| SZ-5 | A tartalom megmarad bezárás és újraindítás után is, és közös a notch (minden kijelző) és a menüsor panelje között. |
| SZ-6 | **Menüsor-ikon** (**+/−**), amíg a Számológép funkció be van kapcsolva. Kattintásra az ikon alatt egy notch-szerű fekete panel nyílik le ugyanazzal a jegyzettel; újabb kattintásra, vagy máshova kattintva becsukódik. |
| SZ-7 | A menüsor panelje megkapja a billentyűzetet, de nem aktiválja a Dynotch-ot (az addig használt app ablaka elöl marad). |
| SZ-9 | **Másolás:** egy eredményre kattintva az a vágólapra kerül (ezres tagolás nélkül, például `1524,5`), és a sorban egy pillanatra „Másolva ✓” jelenik meg. Az eredmények fölött az egérmutató kézre vált. |
| SZ-8 | **Lakat ikon** a notch menüsorában és a menüsor paneljén: alapból szürke, bekattintva **zöld**. Bekattintva a panel **nyitva marad**, akkor is, ha az egér elhagyja (notch), illetve ha máshova kattintasz (menüsor panel). A két lakat független. A notch lakatja a panel bezárásakor (és újraindításkor) kikapcsol. |

---

## 5. Nyitott kérdések

Jelenleg nincs.

---

## 6. Technikai megközelítés (tájékoztató)

| Terület | Megoldás |
|---|---|
| Notch-pozíció és méret | `NSScreen.safeAreaInsets.top` és `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` |
| Ablak | Szegély nélküli `NSPanel` (`.nonactivatingPanel`), szintje a menüsor felett (`.statusBar + 1`), `canJoinAllSpaces` és `fullScreenAuxiliary`, SwiftUI tartalommal |
| Hover | Kurzorkövetés (`NSTrackingArea`) a panelen, plusz egy globális egérmozgás-figyelő becsukott állapotban, mert a notch-sáv nagyon vékony |
| Swipe | `scrollWheel` események `phase` és `momentumPhase` alapján, vízszintes elmozdulási küszöbbel |
| Billentyűk elfogása | `CGEventTap` az `NX_SYSDEFINED` (media key) eseményekre; a fogyasztott eseményt nem engedi tovább, így az Apple HUD nem jelenik meg |
| Hangerő | CoreAudio: `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` és mute, property listener a külső változásokra |
| Fényerő | `DisplayServicesGetBrightness` / `SetBrightness` (privát framework, dinamikusan betöltve) |
| Értesítések | Az Értesítési központ SQLite-adatbázisa csak olvasásra megnyitva (`~/Library/Group Containers/group.com.apple.usernoted/db2/db`), a rekordok bináris plist-ek |
| Naptár | EventKit (`EKEventStore`, `requestFullAccessToEvents`), `EKEventStoreChanged` értesítés; meeting-link felismerés `NSDataDetector`-ral |

---

## 7. Ütemterv

| Verzió | Tartalom |
|---|---|
| **v0.2** | Háttér-app, notch-panel (hover, késleltetett bezárás), menüsor helyőrző funkcióval, swipe, utolsó funkció megjegyzése, jobb klikk menü, Beállítások ablak |
| **v0.3** | Naptár: lista, Csatlakozás gomb, közelgő esemény jelzés; stabil aláírás |
| **v0.4** | Panel minden kijelzőn, látható virtuális notch; naptár napsávval és teljes havi nézettel; kapszula menü |
| **v0.5** | Értesítések a notchban (Beeper, Gmail, Google Chat) |
| **v0.6** | Számológép a notchban és a menüsorban, lakat (nyitva tartás), ikonos beállításfülek |
| **v0.7** | Hangerő/fényerő HUD és a rendszer HUD helyettesítése |
| **v0.8+** | További funkciók (például Most játszott zene, Fájlpolc, Időzítő), külön specifikálva |
