# Dynotch – specifikáció

> Állapot: **v0.23 elfogadva** · Utolsó módosítás: 2026-11-16
> Személyes használatra készülő macOS app, amely a MacBook notch-ot interaktív felületté alakítja.

## 0. Általános döntések

| # | Döntés | Indok |
|---|---|---|
| G-1 | **Háttér-app** (`LSUIElement`): nincs Dock-ikon és nincs főablak. Egyetlen felülete a notch, valamint a Beállítások ablak. | A notch az app „ablaka”. |
| G-2 | **App Sandbox kikapcsolva.** | A hangerő- és fényerőbillentyűk elfogásához (event tap) és a beépített kijelző fényerejének állításához (privát `DisplayServices`) kell. Személyes használatnál ez nem akadály. |
| G-3 | Minimum: **macOS 14**, Apple Silicon és Intel. | Már így van beállítva. |
| G-4 | Minden funkció **külön kapcsolható** a Beállításokban. Kikapcsolt funkció nem fut a háttérben. | |
| G-5 | A beállítások `UserDefaults`-ban tárolódnak, újraindítás után is megmaradnak. | |
| G-7 | **Az app felülete angol.** A dátumok és időpontok a rendszer nyelvi és régióbeállítását követik. |
| G-8 | **App-ikon:** sötétkék, lekerekített négyzet, benne kék kijelző fekete notch-csal (`Design/AppIcon.svg`, ebből készül minden méret). |
| G-9 | **Szerkesztés-billentyűk:** a ⌘X/⌘C/⌘V/⌘A/⌘Z minden szövegmezőben működik (láthatatlan Szerkesztés menü), a Beeper-token mezője mellett „Paste” gomb is van. |
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
| M-4 | Funkciók: *Home* (óra és dátum), *Naptár* (4. fejezet), *Értesítések* (4b. fejezet), *Számológép* (4c. fejezet), *Jegyzetek* (4d. fejezet), *Emlékeztetők* (4e. fejezet), *Claude* (4g. fejezet), *Info* (verzió, kijelző és notch adatai). |
| M-7 | **Menüsor-ikonok:** a Számológép, Jegyzetek, Emlékeztetők és AI Usage funkciónak menüsor-ikonja is van. *Settings › Features* alatt funkciónként kikapcsolható („Menu bar”), ilyenkor csak a notchban érhető el. |
| M-8 | **Menüsor-buborék nyitás/zárás:** az ikonra kattintva kinyílik, újabb kattintásra bezáródik. Ha a lakat be van kapcsolva, az ikonra kattintás bezárja a buborékot és feloldja a lakatot; máshova kattintva a lakatolt buborék nyitva marad. |
| M-6 | **Átrendezés:** a menüsor ikonjait **⌘ lenyomva húzva** lehet átrendezni, egyetlen folyamatos húzással akár a sor egyik végéből a másikba; a húzott ikon követi az egeret és kicsit nagyobb, a többi elcsúszik előle. Az új sorrend azonnal érvényes, és megegyezik a *Beállítások › Funkciók* sorrendjével. Cmd nélkül a húzás nem rendez át. |
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
| H-7 | **Trackpad-visszajelzés** (Force Touch): a notch lenyílásakor, funkcióváltó swipe-nál és a napsávon napváltáskor. *Settings › General*-ban kikapcsolható. Csak akkor érezhető, ha az ujjad a trackpaden van. |
| C-5 | **Kilépés:** *Beállítások › Névjegy › Kilépés a Dynotch-ból*. Az appot újra elindítva (például a Finderből) a beállítások ablaka nyílik meg. |

---|---|
| C-1 | **Jobb klikk** a notch-on vagy a panelen: helyi menü jelenik meg *Beállítások…*, *Névjegy* és *Kilépés* pontokkal. |
| C-2 | **Bal kattintás** a notch-on nem csinál semmit, mert a panel hoverre nyílik. A panelen belüli gombok (például a menüsor ikonjai) kattintásra természetesen működnek. |
| C-3 | A Beállítások ablak egy normál macOS ablak. Megnyitásakor előtérbe jön, bezárásakor az app tovább fut a háttérben. |

---

## 2. Hangerő és fényerő kijelzés (HUD) – v0.18

### 2.1 Viselkedés

| ID | Követelmény |
|---|---|
| H-1 | Amikor a hangerő vagy a beépített kijelző fényereje változik, a notch **két oldalra kiszélesedik**, fekete sávként, a notch magasságában. |
| H-2 | **Bal oldalon** egy fix, fehér ikon: hangszóró (némításkor áthúzott) vagy nap. Szintenként nem cserélődik, nem villog. |
| H-3 | **Jobb oldalon** egy **fehér kör**, amely a tetejétől **az óramutató járásával megegyezően** mutatja a szintet, **közepén a szint számmal** (0–100). Ugyanez a kör (a szám a közepén) mutatja az AI session-fogyást is. A körök nem Retina kijelzőn is élesek. |
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

### 2.3 Hatókör (v0.18)

- Benne van: rendszerhangerő (alapértelmezett kimenet), némítás, a beépített kijelző fényereje.
- Nincs benne: külső monitor fényereje (DDC), billentyűzet-háttérfény, appokénti hangerő. Ha nincs aktív beépített kijelző (pl. csukott fedél), a fényerőgombokat a macOS kezeli.

---

## 3. Beállítások ablak

| Szakasz | Elemek |
|---|---|
| **Általános** | Indítás bejelentkezéskor · Fókusz követi az egeret, várakozás (0–500 ms) · Beállítások megnyitása (a notchban / külön ablakban) · Bezárási késleltetés (0–3 s) |
| **Funkciók** | Bekapcsolt funkciók listája, sorrendjük húzással állítható |
| **Értesítések** | Állapot és Teljes lemezelérés · Eltűnési idő (2–30 mp) · Appok ki/be · Útmutató a natív szalagcímek kikapcsolásához |
| **Naptár** | Hozzáférés állapota és engedélyezés · Közelgő esemény jelzése be/ki · Előjelzési idő (1–30 perc) |
| **HUD** (v0.18) | Hangerő/fényerő HUD be/ki · Rendszer HUD helyettesítése · HUD megjelenési ideje (alapból 1,5 s) · Accessibility engedély állapota |
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
| K-4 | Felül **napsáv**: bal oldalon a hónap rövid neve, mellette a napok vízszintes sora (a nap betűjele, a dátum, alatta pötty, ha van esemény). A mai nap kék és kiemelt, a hétvége pirosas. Egy napra kattintva az lesz kiválasztva. **A sáv fölött két ujjal vízszintesen húzva a kiválasztott nap lép** (kb. 60 pt-onként egy nap, lendülettel együtt; ujjak balra = előre), a sáv követi; itt a swipe nem vált funkciót. Ha egy funkcióváltó swipe érkezik meg a Naptárra, annak a mozdulatnak a maradéka (lendülettel együtt) nem léptet napot; ahhoz új mozdulat kell. A panel megnyitásakor mindig a mai nap van kiválasztva. |
| K-5 | A napsáv alatt a **kiválasztott nap eseményei**: cím, alatta pirossal a nap rövid neve és a kezdési idő (egész napos eseménynél „egész nap”). Elöl az egész napos események, utána kezdési idő szerint. A már véget ért események halványítva látszanak. Ha nincs esemény: „Mára nincs esemény”. |
| K-5b | A kiválasztott nap listája úgy görget, hogy **a folyamatban lévő vagy a következő meeting legyen felül** (megnyitáskor, napváltáskor, és amikor egy meeting véget ér). Ha minden meeting véget ért, a lista elejéről indul. |
| K-5c | A meeting neve alatti dátum és idő **kék**. |
| K-6 | **Csatlakozás gomb** (zöld kapszula), ha az eseményben Zoom-, Google Meet-, Teams- vagy Webex-link van (az esemény URL-jében, helyszínében vagy jegyzetében, az Outlook Safe Links linkeket is felismerve). A meeting **mindig az alapértelmezett böngészőben** nyílik meg, nem közvetlenül a meeting-appban. |

### 4.2b Teljes naptár nézet

| ID | Követelmény |
|---|---|
| K-10 | A napi nézet jobb felső sarkában (a napsáv végén) egy kis ikon a panelt **nagy méretre** nyitja (960 × 340 pt, kisebb kijelzőn a kijelzőhöz igazítva). A jobb felső sarokban lévő ikon visszavált. A panel **megjegyzi a legutóbbi nézetet**, és újranyitáskor (újraindítás után is) ugyanabban nyílik. |
| K-12b | A teljes nézet napirendjében ugyanaz a zöld **Join** gomb van, mint a napi nézetben. |
| K-11 | Bal oldalon **havi rács**: év és hónap, előző/következő hónap gombok, a hét a rendszer szerinti első nappal kezdődik, a mai nap kék körben, a napok alatt legfeljebb három pötty az események száma szerint. Egy napra kattintva az lesz kiválasztva. |
| K-12 | Jobb oldalon **napirend** a kiválasztott naptól 14 napra előre: a kiválasztott nap mindig látszik (üresen „Nincs esemény”), utána csak azok a napok, amelyeken van esemény. Soronként: kezdési idő és időtartam, a naptár színe, cím, Csatlakozás gomb. Az első nap fejlécében a hét száma is látszik. |
| K-13 | Esemény létrehozása nincs (K-1: csak olvasás). |

### 4.3 Közelgő esemény jelzés (becsukott notch)

| ID | Követelmény |
|---|---|
| K-7 | Ha egy (nem egész napos) esemény hamarosan kezdődik vagy éppen tart, a becsukott notch kiszélesedik, **aszimmetrikusan**: **bal oldalon** csak egyetlen ikonig (videó, ha bármelyik eseményben van meeting-link, egyébként naptár), **jobb oldalon** a kapszulákban lévő, másodpercre pontos **visszaszámlálókig**. A fizikai notch a helyén marad. A kapszula körvonala a **hátralévő időt** mutatja: teliről indul, és a tetejétől **az óramutató járásával megegyezően fogy el**. |
| K-8 | **Kezdés előtt** (*N* perccel, beállítás: 1–30 perc, alapból 10): a kezdésig hátralévő idő **sárgával**, a körvonal az előjelzési időből hátralévő részt mutatja. **Az utolsó 3 percben pirossal.** |
| K-8b | **A meeting alatt**: a meeting végéig hátralévő idő **világoskékkel**, a körvonal a meetingből hátralévő részt mutatja. A végén a jelzés eltűnik. |
| K-8c | **Több meeting egyszerre:** minden futó meeting és minden, az előjelzési időn belül kezdődő meeting **egymás mellett** látszik (legfeljebb 3): elöl a futók, utána a kezdődők, kezdési idő szerint. A notch annyival szélesebb, amennyi hely kell. A 24 óránál hosszabb események nem jelennek meg. |
| K-8d | **Hover:** egy visszaszámláló vagy a hozzá tartozó ikon fölé víve az egeret a notch kicsit lejjebb nyílik, és kiírja a **meeting nevét**, idejét és hogy „most tart” vagy „kezdődik”; a többi visszaszámláló halványabb. A notch-ra víve az egeret a panel a szokott módon kinyílik. |
| K-8e | A hover-feliratban **a jobb szélen egy X** gomb elrejti az adott meeting visszaszámlálóját; az a meetinghez többé nem jelenik meg (újraindítás után sem). A többi visszaszámláló gyorsan (0,16 mp) a helyére csúszik, a körvonalukkal együtt. |
| K-8f | **Bejelentés:** amikor egy meeting bekerül az előjelzési időbe (alapból 10 perccel a kezdés előtt), a notch magától lenyílik a meeting nevével, ugyanúgy, mint hovernél. **Nyitva marad, amíg két ujjal felfelé nem söpröd** (a lenyitott név fölött); ezután csak a visszaszámláló marad, a név akkor sem nyílik ki újra, ha az egér még ott van (csak ha elhagyta és visszatér). Minden meeting egyszer kerül bejelentésre. |
| K-8g | *Settings › Calendar*: az előjelzési idő **beírható** (szám a nyilak mellett), és nyilakkal is állítható (1–30 perc). |
| K-9 | A jelzés kikapcsolható (*Beállítások › Naptár*). A Naptár funkció kikapcsolásakor a jelzés sem jelenik meg. |

---

## 4b. Értesítések (v0.5)

### Adatforrás és engedély

| ID | Követelmény |
|---|---|
| E-1 | A Dynotch a macOS Értesítési központ helyi adatbázisából olvassa az új értesítéseket (másodpercenként ellenőriz). Ehhez **Teljes lemezelérés** engedély kell; nélküle az Értesítések funkció és a Beállítások egy gombot mutat, amely megnyitja a megfelelő Rendszerbeállítások oldalt. Csak az indítás után érkezett értesítések jelennek meg. |
| E-2 | Csak a kiválasztott appok értesítései jelennek meg. Alapból: **Beeper**, valamint a **Gmail** és a **Google Chat** Safari-webapp. A Beállításokban bármelyik telepített, értesítést küldő app ki- és bekapcsolható. |
| E-2c | **Rendszerértesítések** (alapból be, a Rendszerbeállítások ikonjával): bejelentkezési és háttérelemek („Login Items”, pl. „Dynotch can run in the background”), szoftverfrissítés, adatvédelmi engedélyek („Privacy & Security”), Rendszerbeállítások. |
| E-2b | **Webes értesítések** (Gmail, Google Chat): ha az értesítés egy böngészőből (Zen, Chrome, Firefox, Safari…) vagy a közös Safari „Web App” azonosítóval érkezik, a Dynotch az értesítésben szereplő oldal címéből (például `mail.google.com`, `chat.google.com`) megkeresi a telepített webappot, és annak a nevével, ikonjával és beállításával kezeli. A szöveg (cím, törzs) nem számít ebbe bele. |

### Megjelenés

| ID | Követelmény |
|---|---|
| E-3 | **Új értesítéskor** a becsukott notch finoman, csak egy kicsit lenyílik (30 pt-tal), és megmutatja az app ikonját és azt, **ki írt**; ha több új értesítés van, mellette „+N”. A tartalom itt nem látszik. Minden kijelzőn megjelenik. |
| E-4 | **Hoverre** a sáv egy kártyává nyílik, amelyen **csak annak a küldőnek (beszélgetésnek) az új üzenetei** látszanak, amelytől az értesítés jött (azonos app és cím). **A név egyszer szerepel felül** (ikon, név, app), alatta **a szövegek egymás alatt** időponttal, időrendben (6 felett görgethető). A kártya bezárásakor ezek látottnak számítanak; más küldők üzenetei újak maradnak. Az Értesítések funkció megnyitása mindent látottnak jelöl. A következő hoverre a panel a szokott módon nyílik (L-1). |
| E-5 | Az *Értesítések* funkció az indítás óta érkezett értesítéseket listázza (legfeljebb 50, a legújabb elöl): app ikon, feladó, app neve és időpont, szöveg. Egy értesítésre kattintva megnyílik az app. |
| E-6 | A lenyílt sáv a beállított idő után magától eltűnik (**2–30 mp**, alapból 6). |
| E-7 | **Gmail:** a feladó és a levél **tárgya** látszik, a levél szövege nem. **Beeper, Google Chat és más appok:** a feladó és az üzenet szövege. |
| E-7b | A forrást megnevező sorok (például „via chat.google.com”, „via WhatsApp”, vagy csak egy domain, mint „mail.google.com”) nem jelennek meg, sem az alcímben, sem a szövegben, egyik appnál sem. |
| E-8 | **Natív macOS értesítések:** a macOS nem engedi programból letiltani más appok szalagcímeit. Ezért a Dynotch (*Natív macOS szalagcímek elrejtése*, alapból be) minden olyan értesítésnél, amelyet a notchban megmutat, figyeli az Értesítési központ új ablakait (kisegítő értesítés), és amint a szalagcím megjelenik, bezárja (a cím, cím nélkül a szöveg eleje alapján); tartalékként 8 mp-ig 0,2 mp-enként is keresi. A szalagcím egy pillanatra felvillanhat. Ehhez **Kisegítő hozzáférés** kell. Teljesen láthatatlanná az appnál a szalagcím stílusát „Nincs”-re állítva lehet tenni. A notchban nem kezelt értesítésekhez nem nyúl. |
| E-11 | **Válasz a notchból:** csevegő appok (nem levél, nem rendszerértesítés) kártyája alján **szöveges mező**; Enter küld. **Beeper:** a Beeper Desktop API-n (token: *Settings › Notifications › Replies*). |
| E-11b | **Google Chat és más, API nélküli csevegők:** ha az értesítés rekordja tartalmazza a beszélgetés címét (chat.google.com / mail.google.com/chat), a Dynotch megnyitja azt abban az appban, amelyik az értesítést küldte (pl. Zen), megvárja, hogy előtérbe kerüljön és betöltsön, majd beilleszti a szöveget és Entert nyom (Kisegítő hozzáférés kell). Csak akkor gépel, ha közvetlenül előtte is az az app van előtérben; a vágólapot visszaállítja. Ha a cím nem ismert, nem küld semmit: a szöveget a vágólapra teszi és megnyitja az appot. Levélnél (Gmail) „Open … to reply” gomb marad. |
| E-12 | **Bezárás és törlés:** a lenyíló kártya fejlécében jobb oldalt **X** (bezárja a kártyát; az üzenetei látottnak számítanak) és **kuka** (minden értesítést töröl). Az Értesítések funkcióban soronként **X** (azt az egyet törli), felül **Clear all**. A macOS Értesítési központjából nem töröl. |
| E-9 | Hibakereséshez az app naplót ír ide (a szalagcímek bezárásáról is: `banner-dismiss.log`): `~/Library/Logs/Dynotch/notifications.log` (adatbázis szerkezete, appazonosítók, az utóbbi értesítések száma appanként) és `notification-records.log` (érkezett értesítésenként: azonosító, oldal, kinek tulajdonítva, megjelent-e). Értesítések tartalma egyikben sincs. |

---

### Csoportosítás (v0.22)

| # | Követelmény |
|---|-------------|
| E-5b | **Csoportosítás:** az Értesítések funkcióban az azonos alkalmazásból és küldőtől (vagy csevegésből) jött értesítések **egy csoportba** kerülnek; a csoport zárva a legfrissebb üzenetet és a darabszámot mutatja. **Kattintásra kinyílik:** minden üzenet időrendben, alatta **válaszmező** (csevegőappoknál; Enterre küld), levelezésnél és rendszerüzenetnél „Open <app>” gomb. Egyetlen csoport eleve nyitva van. |

## 4c. Számológép (v0.6)

| ID | Követelmény |
|---|---|
| SZ-1 | Új funkció a notchban, **+/−** ikonnal: egy jegyzetszerű szövegmező. A funkcióra váltva a panel megkapja a billentyűzetet, így azonnal lehet gépelni. Ha a panel hoverre nyílik meg a számológéppel, nem veszi el a fókuszt az éppen használt apptól; ilyenkor a szövegbe kattintva lehet gépelni. |
| SZ-2 | **Soronként számol:** bal oldalon a begépelt számítás, a sor jobb szélén **zölden az eredmény**, gépelés közben azonnal frissülve. Minden sor önálló, a sorok nem hatnak egymásra. |
| SZ-3 | Műveletek: `+ - * /` (a `×`, `x`, `÷` is), hatvány `^`, zárójelek, előjel, százalék (`200 + 10%` = 220, `200 * 15%` = 30). Tizedesjel pont vagy vessző; a számokban szóköz lehet ezres tagoló (`1 200,5`). |
| SZ-4 | Ha a sor nem számítás (szöveg, egyetlen szám, befejezetlen kifejezés, nullával osztás), nincs mellette eredmény. Az eredmény legfeljebb 8 tizedesjegy, tizedesvesszővel és szóközös ezres tagolással. |
| SZ-5 | A tartalom megmarad bezárás és újraindítás után is, és közös a notch (minden kijelző) és a menüsor panelje között. |
| SZ-6 | **Menüsor-ikon** (**+/−**), amíg a Számológép funkció be van kapcsolva. Kattintásra az ikon alatt egy **nyilas, lekerekített, sötétszürke buborék** nyílik le ugyanazzal a jegyzettel (fejléc nélkül); a nyíl az ikonra mutat. Újabb kattintásra, vagy máshova kattintva becsukódik. |
| SZ-6b | A buborék alján **állapotsor**: balra rövid állapotszöveg („Készen áll…”, „Kattintásra másol”, „Vágólapra másolva”), jobbra a számítások száma, a **lakat** gomb és a zöld **„Mind másolása”** gomb, amely minden számítást az eredményével együtt a vágólapra tesz (soronként `10*10 = 100`). |
| SZ-6c | A szövegmezőben működnek a szokásos billentyűparancsok (⌘C, ⌘X, ⌘V, ⌘A, ⌘Z, ⇧⌘Z), a notchban is. A beillesztés mindig sima szöveg. |
| SZ-7 | A menüsor panelje megkapja a billentyűzetet, de nem aktiválja a Dynotch-ot (az addig használt app ablaka elöl marad). |
| SZ-9 | **Másolás:** egy eredményre kattintva az a vágólapra kerül (ezres tagolás nélkül, például `1524,5`), és a sorban egy pillanatra „Másolva ✓” jelenik meg. Az eredmények fölött az egérmutató kézre vált. |
| SZ-8 | **Lakat ikon** a notch menüsorában és a menüsor paneljén: alapból szürke, bekattintva **zöld**. Bekattintva a panel **nyitva marad**, akkor is, ha az egér elhagyja (notch), illetve ha máshova kattintasz (menüsor panel). A két lakat független. A notch lakatja a panel bezárásakor (és újraindításkor) kikapcsol. |

---

## 4d. Jegyzetek (v0.7)

| ID | Követelmény |
|---|---|
| J-1 | Új funkció a notchban (**jegyzet** ikon). A panel nagy méretben nyílik (mint a teljes naptár), és megkapja a billentyűzetet (hoverre nyitva nem veszi el a fókuszt, ld. SZ-1). |
| J-2 | **Adatforrás az Apple Jegyzetek**, szkriptelésen (JavaScript for Automation) keresztül. Az első használatkor a macOS engedélyt kér („A Dynotch szeretné vezérelni a Jegyzetek appot”). Engedély nélkül a funkció útmutatót és egy gombot mutat a *Rendszerbeállítások › Adatvédelem › Automatizálás* oldalhoz. A Dynotch csak akkor szól a Jegyzeteknek, amikor a Jegyzetek funkció látszik. |
| J-3 | **Oldalsáv:** felül mappaválasztó (fiókonként csoportosítva, a *Nemrég törölt* mappa nélkül), alatta az *Új jegyzet* piszkozat, majd a kiválasztott mappa jegyzetei a legutóbb módosítottal kezdve (cím és relatív idő). A kiválasztott mappa és jegyzet megmarad újraindítás után is. |
| J-4 | **Piszkozat:** helyi jegyzet, amely csak a Dynotch-ban van meg (újraindítás után is). A **„Mentés a Jegyzetekbe”** gomb új jegyzetként menti a kiválasztott mappába; az első sor lesz a címe. Mentés után a piszkozat kiürül, és az új jegyzet nyílik meg. |
| J-5 | **Meglévő jegyzet szerkesztése:** a szöveg sima szövegként látszik. Gépelés után 1,5 mp szünettel **automatikusan mentődik a Jegyzetekbe**; másik jegyzetre vagy mappára váltáskor azonnal. Az állapotsor mutatja: „Módosítva…”, „Mentés…”, „Mentve a Jegyzetekbe · 10:42”. |
| J-6 | **Listás és formázott tartalmú jegyzetek védelme:** a mentés a jegyzet teljes tartalmát újraírja. Csak olvasható az a jegyzet, amelyben lista vagy **teendőlista (checklist)**, táblázat, kép, link vagy melléklet van, és a jelszóval védett jegyzet is. A teendőlisták pipáit a Jegyzetek szkriptelhető felülete nem adja ki és nem engedi írni, ezért a Dynotch nem tud teendőlistát létrehozni vagy szinkronizálni; ezek jegyzetei csak olvashatók. |
| J-10 | **Formázás:** a szerkesztő felett eszköztár: *Aa* (Title, Heading, Subheading, Body), **B**, *I*, U, S. Félkövér, dőlt, aláhúzott, áthúzott szöveg és a címméretek a Jegyzetekbe is mentődnek (`<b>`, `<i>`, `<u>`, `<strike>`, betűméret). Más formázás (szín, betűtípus) mentéskor elveszik. |
| J-11 | **Billentyűparancsok** (mint az Apple Jegyzetekben): ⌘B félkövér, ⌘I dőlt, ⌘U aláhúzott, ⇧⌘X áthúzott, ⇧⌘T cím, ⇧⌘H címsor, ⇧⌘J alcím, ⇧⌘B törzsszöveg. |
| J-7 | **Ütközés:** ha a jegyzet a betöltése óta megváltozott a Jegyzetekben (például iPhone-on), a mentés nem írja felül; az állapotsor jelzi, és két gombot ad: *Újratöltés* (a helyi módosítás elvetése) és *Felülírás*. |
| J-8 | **Menüsor-ikon** (jegyzet ikon), amíg a funkció be van kapcsolva: a számológéphez hasonló nyilas buborék (680 × 440 pt) ugyanazzal az oldalsávval és szerkesztővel, alul **lakattal**. Másolás funkció itt nincs. A notch és a menüsor ugyanazt a jegyzetet mutatja. |
| J-9 | *Megnyitás a Jegyzetekben* gomb: a kiválasztott jegyzetet megnyitja a Jegyzetek appban. |

---

## 4e. Emlékeztetők (v0.8)

| ID | Követelmény |
|---|---|
| R-1 | **Adatforrás az Apple Emlékeztetők** (EventKit). Az engedélyt az app akkor kéri, amikor az Emlékeztetők először látszanak. A nézet minden megnyitáskor, és amíg nincs engedély, 2 mp-enként újraellenőrzi az engedélyt, így a Rendszerbeállításokban utólag megadott engedély is azonnal érvényes. Engedély nélkül gomb a megfelelő Rendszerbeállítások oldalhoz. Más eszközről érkező változásoknál a lista frissül. |
| R-2 | **Notch:** új funkció (*checklist* ikon), nagy panelen, két oszlopban: bal oldalon a gyors bevitel és a közelgő emlékeztetők, jobb oldalon a kiválasztott lista feladatai. A panel megkapja a billentyűzetet. **Menüsor:** külön ikon és nyilas buborék (400 × 520 pt), egy oszlopban, alul lakattal. |
| R-3 | **Gyors bevitel:** „Írj be egy emlékeztetőt, majd Enter”. A szövegből felismeri a dátumot és időt (pl. „holnap 14:00”, „Friday”, „2026-11-20 14:30”), és a „@Lista” szót (név eleje, kis-/nagybetű mindegy), ami a listát választja. A felismert dátum a beállítástól függően kikerül a címből; a cím sosem lesz üres, a végén maradt kötőszó („on”, „at”…) is lekerül. |
| R-4 | **Kék lista-gomb** a mező mellett: a listák (pipa a kiválasztotton) és két beállítás: *Ha nincs dátum: határidő ma*, *Felismert dátum törlése a címből*. A kiválasztott lista megmarad. |
| R-5 | **Közelgő emlékeztetők** (piros cím): minden lista nyitott emlékeztetője, amely 7 napon belül esedékes vagy lejárt; a lejárt pirosan („Lejárt · tegnap”). Jobbra rendezés: *Határidő*, *Prioritás*, *Cím* (a feladatlistára is vonatkozik). |
| R-6 | **Feladatok** (a lista színével): a kiválasztott lista nyitott feladatai. A **kör alakú jelölőnégyzetre** kattintva a feladat kipipálódik (kitöltött kör, áthúzott cím), és 0,7 mp múlva **késznek** mentődik az Emlékeztetőkbe, majd eltűnik; addig újra kattintva visszavonható. A szűrő gombbal az elmúlt 7 nap kész feladatai is látszanak, és visszaállíthatók. |
| R-7 | A **menüsor-ikon mellett** a kiválasztott lista nyitott feladatainak **száma** látszik (engedély nélkül nincs szám). |
| R-8 | Alsó sor: szűrő (kész feladatok), a nyitott feladatok száma vagy hibaüzenet, lakat (menüsor), *Megnyitás az Emlékeztetők appban*. A kézi sorrend (amit az Emlékeztetők appban húzással állítasz) nem érhető el, ezért alapból határidő, azonos határidőnél cím szerinti a sorrend. |

---

## 4f. Fókusz követi az egeret (v0.9)

Az [AutoRaise](https://github.com/sbmpost/AutoRaise) „focus without raise” működése, csak ez az egy funkció.

| ID | Követelmény |
|---|---|
| F-1 | Ha az egér egy másik app ablaka fölött áll, **az az app kapja a fókuszt** (billentyűzetet), és a mutatott ablaka lesz a kulcsablak. **Az ablak soha, semmilyen körülmények között nem kerül előre**: ha a böngészőt részben eltakarja a Jegyzetek, a böngészőre víve az egeret a böngésző kap fókuszt, a Jegyzetek ablaka elöl marad. |
| F-2 | Csak normál ablakra vált. Ha az egér alatt legfelül menü, a Dock, a menüsor, lebegő ablak vagy semmi (asztal) van, nem történik semmi. A Dynotch saját, többnyire átlátszó ablakain „átnéz”. |
| F-3 | A váltás akkor történik, amikor az egér *N* ideig nyugalomban van (beállítás: 0–500 ms, alapból 100 ms). |
| F-4 | Nem vált, amíg egérgomb le van nyomva (húzás, kijelölés), és amíg egy Dynotch-panel fogadja a billentyűzetet (számológép, jegyzet, emlékeztető bevitel, beállítások), hogy a gépelés ne szakadjon meg. |
| F-5 | Ugyanazon appon belüli ablakváltáshoz **Kisegítő hozzáférés** kell (a jelenleg fókuszban lévő ablak azonosítása). Appok között enélkül is működik. |
| F-7 | *Settings › Focus* fül: be/ki, várakozás, és rövid leírás arról, mit csinál a funkció. |
| F-6 | *Beállítások › Általános*: be/ki (alapból be), várakozási idő. Technika: a WindowServer nem nyilvános `_SLPSSetFrontProcessWithOptions` és `SLPSPostEventRecordTo` hívásai futásidőben betöltve; ha egy macOS-verzióban hiányoznak, a funkció kikapcsol, és a napló (`focus.log`) jelzi. |

---

## 4g. AI Usage – Claude-fogyasztás (v0.10)

| ID | Követelmény |
|---|---|
| CL-1 | **Adatforrás:** a Claude-előfizetés keretei, ugyanonnan, ahonnan a Claude Code `/usage` parancsa olvassa (`api.anthropic.com/api/oauth/usage`), a **Claude Code bejelentkezésével**. A tokent a „Claude Code-credentials” kulcskarika-elemből a `/usr/bin/security` eszközzel olvassa (ugyanazzal, amellyel a Claude Code tárolja), így a macOS nem kér jelszót; a tokent memóriában tartja, és csak lejáratkor vagy elutasításkor olvassa újra. A tokent a Dynotch nem frissíti és nem menti. |
| CL-2 | Keretek: **Munkamenet (5 óra)**, **Heti (7 nap)**, és a válaszban szereplő **modellenkénti heti keretek** (pl. „Fable limit”, „Opus limit”). |
| CL-3 | **Nézet** (*AI Usage* funkció a notchban és menüsor-buborék, a mellékelt kép szerint): „AI USAGE” fejléc, frissítés ideje és gombja; keretenként cím, százalék, sáv (70%-tól narancs, 90%-tól piros), alatta „Resets today 14:30”. A keretek listáját a válasz `limits` mezőjéből veszi (Session, Weekly, modellre szűkített heti keret „Fable limit” néven, ha a válasz nem nevezi meg). A notch-panel pont olyan magas, hogy görgetés nélkül minden keret látsszon. |
| CL-4 | Frissítés 5 percenként (amíg a funkció be van kapcsolva), megnyitáskor ha 1 percnél régebbi, és gombbal. |
| CL-5 | **Értesítés a notchban 70% felett**, majd minden további 10%-nál újra (80, 90, 100), keretenként és visszaállási időszakonként egyszer. Kikapcsolható. |
| CL-5b | **A munkamenet visszaállásakor** értesítés a notchban („AI session reset”). Visszaállásnak számít, ha az előző visszaállási idő elmúlt, vagy a fogyás legalább 20 százalékponttal visszaesett. A visszaállási idő puszta elmozdulása (gördülő ablak) nem számít új időszaknak, ezért a 70%/…/100% figyelmeztetés lépcsőnként csak egyszer jön. |
| CL-6 | **Jelző a notch mellett** (mint a meeting-visszaszámláló), **csak a munkamenet-keretre (Session) és csak 70% felett** (vagy kitűzve): bal oldalon a **fehér** Claude-ikon, jobb oldalon egy kör, amely a session fogyásával telik. **Színek szint szerint** (mint az AI Usage nézetben): 0–70% kék, 70–90% narancs, 90–100% piros. Más keret nem jelenik meg a notch mellett. **Hoverre** a session használt %-a, hátralévő %-a és visszaállása; **jobb oldalt X**: a jelző eltűnik, amíg a session el nem éri a következő 10%-ot (vagy vissza nem áll). Kikapcsolható. A teljes nézet (notch funkció, menüsor) továbbra is minden keretet mutat. |
| CL-6b | Az AI Usage nézet fejlécében **„Show at notch”** gomb: bekapcsolva a session-kör 70% alatt is a notch mellett marad. Az X kikapcsolja. |
| CL-7 | Hibakezelés: nincs bejelentkezés vagy elutasított kulcskarika-hozzáférés, lejárt token, hálózati hiba; mindegyik saját üzenettel és Frissítés gombbal. Napló: `claude-usage.log` (HTTP-állapot és a válasz kulcsai, token és értékek nélkül). |

---

## 4h. App-jelvények – olvasatlan értesítések száma (v0.20)

A Badgeify mintájára: a kiválasztott alkalmazások olvasatlan értesítéseinek száma a notch mellett.

| # | Követelmény |
|---|-------------|
| B-1 | **Beállítások › App badges** fül: a gépen lévő összes alkalmazás (Applications mappák) kereshető listából hozzáadható; a hozzáadott appok egyenként **ki- és bekapcsolhatók**, eltávolíthatók. |
| B-2 | **Adatforrás:** az app Dock-ikonján lévő jelvény (szám), a Dock Accessibility-felületéről, 2 másodpercenként. Kisegítő lehetőségek (Accessibility) engedély kell hozzá; ha nincs, a fül jelzi. |
| B-3 | **Ikon** appenként választható: az app saját ikonja, **előre megadott ikonok** (chat, mail, csengő, telefon, videó, naptár, feladatok, emberek, web, kód, zene, csillag, Claude, valamint fehér **Beeper, Google Chat és Gmail** jel), vagy **saját kép feltöltése**. Ismert app-típusoknál (levelező, chat, Claude) a kezdő ikon a megfelelő fehér jel. |
| B-4 | **Megjelenés a becsukott notchon:** bal oldalt, a meglévő ikonok (meeting, Claude) után kifelé; köztük **finom függőleges elválasztó vonal**. Appenként ikon + mellette az olvasatlanok száma (99 felett „99+”). Ha nincs olvasatlan (a jelvény eltűnt), az app **nem jelenik meg**. |
| B-5 | **Új értesítésnél** (a szám nő vagy megjelenik) az ikon **5 percig finoman pulzál**; újabb értesítésnél a pulzálás elölről kezdődik. Ha az egér az ikonra kerül, a pulzálás **abbamarad** (a következő értesítésig). Az app indulásakor már meglévő jelvény nem számít újnak. |
| B-6 | **Kattintás** az ikonra lenyitja a notchot az Értesítések funkcióval, és csak **az adott app még meg nem nyitott értesítéseit** mutatja (a legfrissebbeket, annyit, amennyit a jelvény számol); „All” gombbal vissza a teljes listára, „Open <app>” gombbal megnyitható az alkalmazás. Ha az Értesítések funkció ki van kapcsolva, a kattintás az appot nyitja meg. |
| B-7 | **Sorrend** fogd-és-vidd módszerrel módosítható a notchon (az ikonok húzásával) és a beállítások listájában is. |

## 4i. Billentyűzetzár (v0.21)

| # | Követelmény |
|---|-------------|
| KL-1 | A lenyitott notch jobb felső sorában, a beállítások (fogaskerék) mellett **billentyűzet ikonú gomb**: kikapcsolva szürke, bekapcsolva kék. |
| KL-2 | Bekapcsolva **minden billentyűleütést letilt** (betűk, módosítók, médiabillentyűk), hogy a billentyűzet bekapcsolt gép mellett is takarítható legyen. Kisegítő lehetőségek engedély kell hozzá. |
| KL-3 | Kikapcsolni csak egérrel/trackpaddel lehet, ugyanazzal a gombbal. Az app újraindítása után mindig kikapcsolt. |

## 4j. Bejövő hívások (v0.21)

| # | Követelmény |
|---|-------------|
| P-1b | A hívó nevét a banner saját szövegéből veszi (a banner és az Értesítési központ saját elnevezései nélkül); a **képet** és – ha a banner csak számot mutat – a nevet a Névjegyekből (engedély kell). Ha az SMS nem küldhető el, a mező alatt látszik az ok. |
| P-1 | A bejövő (iPhone-ról átirányított vagy FaceTime) hívás **a notchban jelenik meg**: kör alakú monogram, a hívás eredete („from iPhone”) és a hívó neve vagy száma. A hívást az app a macOS saját hívásbanneréből ismeri fel (Accessibility), mert macOS-en nincs hívás-API. Kikapcsolható (Beállítások › General). |
| P-2 | **Felvétel** (zöld) és **elutasítás** (piros) gomb: a macOS-banner megfelelő gombját nyomja meg. A hívás végén (felvétel, elutasítás, a hívó leteszi) a kártya eltűnik. |
| P-3 | Harmadik gomb: **üzenet**. Kattintásra beviteli mező jelenik meg; **Enterre** SMS-t (ha nincs SMS-továbbítás, iMessage-et) küld a hívónak a Messages appon keresztül, majd elutasítja a hívást. A számot a banner szövegéből, név esetén a Névjegyekből veszi (engedély kell). |
| P-4 | Hívás közben a kártya elsőbbséget élvez a notch többi jelzésével szemben; a notch hoverre nem nyílik le. |

## 4k. Teendőlista a jegyzetekben (v0.23)

| # | Követelmény |
|---|-------------|
| J-12 | **Teendőlista:** az eszköztár gombja vagy a ⇧⌘L a kijelölt sorokat teendővé alakítja (és vissza). Egy teendő a sor elején álló kör: ○ nyitott, ◉ (narancs) kész; a kész sor szövege halványabb. **Kattintás a körre** kipipálja / visszavonja; a kipipált elem **a lista aljára kerül**, a visszavont a nyitottak végére. Enter új teendőt kezd, üres teendőn Enter kilép a listából. |
| J-12b | Az Apple Notes a saját (natív) listáit és pipáit más appnak nem adja ki és nem engedi írni, ezért a teendők az Apple Notes-ban ○ / ◉ kezdetű sima sorokként látszanak. A natív listát tartalmazó jegyzet csak olvasható marad, de a **„Make editable”** gombbal a listaelemek nyitott teendővé alakíthatók (a natív pipák állapota nem olvasható ki); az Apple Notes az első módosításkor kapja meg az új formát. |

## 4l. Gyorsbillentyűk (v0.23)

| # | Követelmény |
|---|-------------|
| SC-1 | **Beállítások › Features:** minden modul mellé rögzíthető egy globális gyorsbillentyű (pl. ⌥1 → Jegyzetek; ⌘, ⌥ vagy ⌃ kötelező; Esc megszakít, Delete töröl). A gyorsbillentyű lenyitja a notchot az adott modullal azon a kijelzőn, ahol az egér van; újra megnyomva bezárja. Billentyűs moduloknál a fókusz rögtön a panelre kerül. Rögzítés nélkül a panel addig marad nyitva, amíg az egér rá nem megy, majd el nem hagyja. |
| SC-2 | Kapcsoló: **gyorsbillentyűs megnyitáskor a notch rögzítése** automatikusan bekapcsol (nem záródik be). |

## 4m. „Claude befejezte” jelzés (v0.23)

| # | Követelmény |
|---|-------------|
| CN-1 | Amikor a Claude Code befejez egy feladatot, a becsukott notch alatt megjelenik egy sor: fehér Claude-ikon, „Claude finished”, a projekt neve és az időpont. **Csak kétujjas felfelé swipe-ra tűnik el.** Ha egy jelző részletei (hover, meeting-bejelentés) nyitva vannak, azok látszanak helyette. |
| CN-2 | Működés: a Beállítások › General kapcsolója egy „Stop” hookot ír a `~/.claude/settings.json` fájlba (biztonsági másolattal), amely a `dynotch://claude-finished?project=…` hivatkozást nyitja meg. Kikapcsolva a hook törlődik. |

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
| Jegyzetek | `osascript -l JavaScript` soros háttérsoron; a jegyzet törzse HTML, a szerkesztő a `plaintext` tulajdonságot mutatja, mentéskor soronként `<div>` |
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
| **v0.7** | Jegyzetek: Apple Jegyzetek szerkesztése a notchban és a menüsorban |
| **v0.8** | Emlékeztetők a notchban és a menüsorban; natív szalagcímek bezárása eseményre; napok léptetése a napsávon |
| **v0.9** | Fókusz követi az egeret (előrehozás nélkül); Emlékeztetők engedélyének javítása |
| **v0.10** | Claude-fogyasztás (notch, menüsor-karika, értesítés 70% felett); naptár: kevésbé érzékeny napsáv, lista a következő meetingnél |
| **v0.11** | Claude-jelző a notch mellett; a teljes felület angolul |
| **v0.12** | AI Usage: kör a notch mellett, nagyobb ikonok, jelszókérés megszüntetése; menüsor-ikonok funkciónként; menüsor-buborék zárása kattintásra |
| **v0.13** | Értesítések: minden új értesítés egymás alatt, válasz Beeper-üzenetekre a notchból |
| **v0.14** | Értesítések küldőnként egy kártyán; session-visszaállás értesítés; figyelmeztetések csak új lépcsőnél; keskenyebb Jegyzetek/Emlékeztetők panel |
| **v0.15** | Meeting-bejelentés a notchban (felfelé söpréssel zárható); AI-jelző csak session, 70% felett |
| **v0.16** | Válasz Google Chatre gépeléssel; rendszerértesítések; Focus beállításfül; trackpad-visszajelzés |
| **v0.17** | App-ikon; értesítések bezárása/törlése; kék meeting-dátum, egységes Join; napsáv-swipe csak új mozdulattal |
| **v0.18** | Hangerő/fényerő HUD a notch mellett, a macOS-kijelző helyett; AI session gomb; beírható előjelzés; beillesztés |
| **v0.19** | Jegyzet-formázás és billentyűparancsok; számos, éles kör; villogásmentes HUD-ikon; bejelentés bezárásának javítása |
| **v0.23** | Teendőlista a jegyzetekben; modulonkénti gyorsbillentyűk; „Claude befejezte” jelzés; hívó neve és képe |
| **v0.22** | Értesítések küldőnként csoportosítva, kattintásra kinyíló csoport válaszmezővel; jelvény-kattintás az app értesítéseit mutatja; hívásfelismerés javítása |
| **v0.21** | Bejövő hívások a notchban (felvétel, elutasítás, SMS); billentyűzetzár; Beeper/Google Chat/Gmail jelvényikonok; hoverre megálló pulzálás |
| **v0.20** | App-jelvények (olvasatlan értesítések száma a notch mellett); fehér Claude-ikon, szint szerinti színek |
| **v0.20+** | További funkciók (például Most játszott zene, Fájlpolc, Időzítő), külön specifikálva |
