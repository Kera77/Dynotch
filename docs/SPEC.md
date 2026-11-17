# Dynotch – specifikáció

> Állapot: **v0.43 elfogadva** · Utolsó módosítás: 2026-11-18
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
| N-10 | **Space-váltás (v0.30):** amikor a kétujjas/háromujjas Space-váltó swipe **elindul**, a becsukott notch mellett álló jelzők **behúzódnak a notchba** (a fekete terület a notch méretére szűkül, a tartalom elhalványul és elmosódik); a behúzódás mindig végigér (0,16 s); az ujj felemelése után (ami kb. 0,1 s-mal a swipe indulása után történik, miközben a Space-ek még kb. 0,4 s-ig csúsznak) rövid kitartás, majd gyors rugóval **szétnyílnak**, így mire a csúszás megáll, a notch már normál állapotban van. (v0.31: időzítés javítva, korábban a túl korai szétnyílás miatt nem látszott.) A swipe-ot a rendszer Dock-vezérlő eseményéből ismeri fel (csak figyel, nem módosítja); ha a vége elveszne, 2,5 s után vagy a Space-váltáskor magától szétnyílik. Külön Space-ekkel rendelkező kijelzőknél csak az egér alatti kijelzőn. „Mozgás csökkentése” esetén nincs animáció. |
| N-11 | (v0.33) **Lekerekített notch (Dynamic Island-szerű):** a becsukott notch alsó sarkai lekerekednek – egy sornyi tartalomnál (üresen, jelzőkkel, jelvényekkel, hangerő/fényerő) a notch magasságának felével, így a végei teljesen kerekek; magasabb tartalomnál (értesítés, hívás, meeting részletei, lelógó sor) 22 pt-tal. Lenyitáskor a sugár a méretváltozással együtt, ugyanazzal a rugóval áll vissza a panel szokásos (24 pt, előnézetnél 18 pt) sarkára, így a nagy panel „kiegyenesedik”. Ki-be kapcsolható: *Beállítások › General › Rounded notch* (alapból be); kikapcsolva a korábbi sarkok maradnak. (v0.34) **Teljes kapszula:** a felső sarkok is kerekek, ugyanazzal a sugárral. Hogy a felső lekerekítés ne vágjon bele a fizikai notchba, a fekete rész mindkét oldalon legalább egy sugárnyival túlnyúlik a notchon (üresen ezért szélesebb a fizikai notchnál; ha csak az egyik oldalon áll tartalom, a másikon kap ennyi helyet); a tartalom a helyén marad. Lenyitáskor a felső sarkok kiegyenesednek, a panel teteje ismét a képernyő széléhez simul. (v0.35) **Csak az alapállapot kapszula:** az egysoros becsukott notch (üresen, jelzőkkel, jelvényekkel, hangerő/fényerő mellett). Amint bármi lelóg vagy megnő – értesítés, hívás, meeting részletei, lelógó sor, előnézet, lenyitás –, a notch ugyanazzal a rugóval kiegyenesedik (felül szögletes, alul a korábbi sarkok), és utána vissza. |
| N-12 | (v0.34) **Teljes képernyős appoknál rejtve:** ha az adott kijelzőn egy app ablaka a teljes képernyőt (a menüsor sávját is) lefedi, a becsukott notch mellett **semmi nem látszik** – se jelzők, se jelvények, se értesítések, se lelógó sor (a notch fekete része sem). Csak egy bejövő hívás és a hangerő/fényerő jelenik meg. A notch akkor nyílik le, ha az egér **a képernyő legfelső szélére**, a notch szélességén belülre ér (a szokásos hover-zóna itt nem nyit). Felismerés: másodpercenként és Space-váltáskor az ablakok kereteiből (a tartalmukat nem nézi). Ki-be kapcsolható: *Settings › General › Hide the notch over full-screen apps* (alapból be). |
| N-13 | (v0.37) **Csak a tartalmas oldal kerek:** *Settings › General › Round only the sides with something shown* (alapból ki; csak a lekerekített notch mellett állítható). Bekapcsolva a kapszula csak azon az oldalon kerek (és nyúlik túl a notchon), ahol a notch mellett valami látszik (jelző, jelvény, hangerő); a másik oldal a notch saját szélét követi (felül szögletes, alul a szokásos kis sarok). Üres notchnál egyik oldal sem kerek. |
| N-14 | (v0.40) **Nincs lassú első nyitás:** az app kikapcsolja magának az App Nap-et (a macOS a sokáig tétlen háttérappokat lelassítja, és az első hover a felébredésre várt). A gép tétlen alvását nem akadályozza. |
| N-15 | (v0.43) **Billentyűzet a notchban:** Esc becsukja; ←/→ modult vált, ha nem gépelünk és nem a beállítások látszanak; ⌘1–⌘9 a sorrend szerinti modult nyitja. |
| N-16 | (v0.43) **Gyorsabb notch:** csak a látható modul és a két szomszédja (a swipe-hoz) épül fel; a nagy szolgáltatásokat csak a saját nézeteik figyelik; az időzítők 20% tűréssel futnak (kevesebb ébresztés). |
| N-17 | (v0.43) Modulváltáskor és egy értesítés bezárása után a tartalom **nem marad homályos**: átúszik és kicsit elmozdul, nem méreteződik. |
| N-18 | (v0.43) **Pill mód** (külső kijelző): a lenyitott pill felső sora középen van, fent és lent 3 pt réssel; a felső sarkok legfeljebb 12 pt-esek, így nem vágják le a sort. |

> Javaslat (nem kötelező): *Nyitási késleltetés* beállítás (alapból 0 s), ha a véletlen nyitások zavarnak, például amikor a menüsor közepére mész az egérrel.

### 1.2 Felső menüsor (funkcióválasztó)

| ID | Követelmény |
|---|---|
| M-1 | A kinyitott panel tetején, a notch bal oldalán egy **kapszula alakú ikonsor** mutatja a funkciókat. Az aktív funkció ikonja világosabb, lekerekített hátteret kap. (v0.42) A kiválasztott ikon kiemelése (és a fogaskeréké, valamint a beállítások fülsoráé) **kapszula alakú**, mint a háttér. |
| M-2 | Egy ikonra kattintva megnyílik a hozzá tartozó funkció. Az aktív funkció ikonja kiemelve látszik. |
| M-3 | A menüsorban csak a bekapcsolt funkciók jelennek meg, a Beállításokban megadott sorrendben. |
| M-4 | Funkciók: *Home* (óra és dátum), *Naptár* (4. fejezet), *Értesítések* (4b. fejezet), *Számológép* (4c. fejezet), *Jegyzetek* (4d. fejezet), *Emlékeztetők* (4e. fejezet), *Claude* (4g. fejezet), *Info* (verzió, kijelző és notch adatai). |
| M-7 | **Menüsor-ikonok:** a Számológép, Jegyzetek, Emlékeztetők és AI Usage funkciónak menüsor-ikonja is van. *Settings › Features* alatt funkciónként kikapcsolható („Menu bar”), ilyenkor csak a notchban érhető el. |
| M-8 | **Menüsor-buborék nyitás/zárás:** az ikonra kattintva kinyílik, újabb kattintásra bezáródik. Ha a lakat be van kapcsolva, az ikonra kattintás bezárja a buborékot és feloldja a lakatot; máshova kattintva a lakatolt buborék nyitva marad. |
| M-6 | **Átrendezés:** a menüsor ikonjait **⌘ lenyomva húzva** lehet átrendezni, egyetlen folyamatos húzással akár a sor egyik végéből a másikba; a húzott ikon követi az egeret és kicsit nagyobb, a többi elcsúszik előle. Az új sorrend azonnal érvényes, és megegyezik a *Beállítások › Funkciók* sorrendjével. Cmd nélkül a húzás nem rendez át. |
| M-5 | A menüsor jobb szélén egy kapszulában a **lakat** (SZ-8) és a **fogaskerék** (C-1) ül. A notch-tól jobbra eső többi hely állapotjelzéseknek van fenntartva (például hangerő- és fényerő HUD). |
| M-9 | (v0.28) A felső sorban **csak annyi modulikon látszik, amennyi a notch bal oldalán elfér** (notchos kijelzőn semmi nem kerül a notch mögé). Ha az egér az ikonokon van, a **kétujjas vízszintes swipe csak az ikonokat lépteti** (modult nem vált); **kattintás vált modult**. Ha a modul swipe-pal (a tartalom fölött) vált, az ikonja magától láthatóvá válik. |
| M-10 | (v0.29) A beállítások **Features** füle **Modules** nevet kapott; a sorok **fogd-és-vidd** módszerrel átrendezhetők (bal oldali fogantyú, a sor húzás közben a helyére csúszik). A „Pin” jelölő csak gyorsbillentyűvel rendelkező modulnál lehet bejelölve; gyorsbillentyű nélkül üresen, letiltva látszik. |

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
| C-6 | (v0.37, v0.40-ben módosítva) Ha a beállítások a notchban nyílnak meg, a notch **nyitva marad az első kattintásig a notchon kívül** (akkor is, ha az egér közben elhagyja), és arra a kattintásra bezáródik. Nem rögzíti (a lakat nem kapcsol be). Modul választásakor vagy a fogaskerékre kattintva a szokásos viselkedés tér vissza. |
| C-4 | **Bal kattintás** a notch-on nem csinál semmit, mert a panel hoverre nyílik. |
| H-7 | **Trackpad-visszajelzés** (Force Touch): a notch lenyílásakor, funkcióváltó swipe-nál és a napsávon napváltáskor. *Settings › General*-ban kikapcsolható. Csak akkor érezhető, ha az ujjad a trackpaden van. |
| C-5b | (v0.31) A Notifications fülön a keresőmező az „Apps” szakasz fejlécében van (sorként nem lehetett belekattintani). (v0.33) A fejlécben sem lehetett, ezért a fül tetején, az űrlap fölött áll (mint az App badges fülön), és az appokat és a weboldalakat is szűri; az űrlapon belüli szövegmezők (szabály neve, Beeper-token) kattintásra programból is fókuszt kapnak. |
| C-5 | **Kilépés:** *Beállítások › Névjegy › Kilépés a Dynotch-ból*. Az appot újra elindítva (például a Finderből) a beállítások ablaka nyílik meg. |
| C-7 | (v0.43) *Névjegy › Copy Diagnostics*: verzió, bekapcsolt modulok, engedélyek és a naplók vége a vágólapra, hibabejelentéshez. Üzenettartalom nincs benne. |
| C-8 | (v0.43) **Permissions fül:** minden engedély (Teljes lemezelérés, Accessibility, Naptár, Emlékeztetők, Kontaktok, Bluetooth) egy helyen, mire kell; megadva pipa, különben gomb a Rendszerbeállítások megfelelő oldalára. |
| C-9 | (v0.43) A beállítások szakaszai **bal oldali listában**, kereséssel (kulcsszavakra is talál); a C-1b fülnév-kiírását váltja. |

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
| **Általános** | Indítás bejelentkezéskor · HUD · Hívások (Telefon app a Dockban, P-5) · Haptika · AI usage · Claude-jelzések · Bezárási késleltetés (0–3 s) |
| **Megjelenés** (v0.39) | Design (D-1) · Beállítások megnyitása (a notchban / külön ablakban) · Lekerekített notch (N-11), csak a tartalmas oldal (N-13) · Rejtés teljes képernyős appoknál (N-12) · Előnézet hoverre (PV) |
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
| K-8h | (v0.40) A meeting-visszaszámláló (előjelzés és „folyamatban”) **hover-sorában** a név és az idő mellett, az **X-től balra** a **Join** gomb is ott van, ha a meetingnek van linkje; a meetinget nyitja meg. |
| K-9 | A jelzés kikapcsolható (*Beállítások › Naptár*). A Naptár funkció kikapcsolásakor a jelzés sem jelenik meg. |
| K-14 | (v0.43) **Napi idővonal** a napi nézetben: az események színes sávként 8–20 óra között (korábbi/későbbi eseménynél szélesebb), „most” vonal, a következő linkes megbeszélés kiemelve, kattintásra csatlakozik. |

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

### Elintézett értesítések (v0.24)

| # | Követelmény |
|---|-------------|
| E-2d | (v0.26) **Minden rendszerértesítés** megjelenik (nem csak a szoftverfrissítés): rendszerértesítésnek számít minden ismert rendszerforrás és minden olyan `com.apple.` azonosítójú szolgáltatás, amelynek nincs saját alkalmazása. A beállításokban egyetlen **„System Settings”** kapcsoló vezérli mindet, és a notchban is ezen a néven látszanak. |
| E-11c | (v0.29) Ha a válaszmezőbe kattintok (értesítéskártya vagy Értesítések modul), **a notch rögzül**, így gépelés közben nem záródik be. |
| E-15 | (v0.32) **Weboldalak külön forrásként:** ha egy böngésző (pl. Zen) olyan oldal értesítését mutatja, amelyhez nincs telepített webapp, az oldal **saját forrás** lesz (pl. „Google Calendar”), a böngésző ikonjával; az első értesítésével magától megjelenik a Beállítások › Notifications **Websites** szakaszában. Alapból úgy van be- vagy kikapcsolva, mint a böngésző, kivéve a Gmailt és a Google Chatet (alapból be). Megnyitáskor az oldalt nyitja meg abban a böngészőben. |
| E-15b | (v0.33) A weboldal-források nem csak a következő értesítésükkel jelennek meg: a Dynotch a Notification Centerben még meglévő böngészős értesítésekből (csak az oldal címét nézve, a szöveget nem) is felveszi az oldalakat, amikor megnyitja az adatbázist, és amikor a Beállítások › Notifications fül megnyílik. A telepített webapphoz tartozó oldalak (E-2b) továbbra is a webapphoz kerülnek. |
| E-16 | (v0.32) **Saját szabályok forrásonként** (appok, rendszerértesítések, weboldalak): a sor melletti nyíllal lenyíló beállítások – **név** (a notchban és a listákban ez látszik), **macOS-banner** (alapértelmezés / elrejtés / megjelenítés), **válaszmező** (automatikus / mindig / soha). Egyedi szabállyal rendelkező forrásnál egy kis jel látszik. A keresés az oldal címére is szűr. |
| E-16b | (v0.38) A **válaszmező alapból ki van kapcsolva** minden forrásnál (csevegő appoknál is); csak az a forrás kapja meg, amelynek szabályában „Show” áll. A választó első lehetősége „Default (off)”. |
| E-17 | (v0.40) **Válasz egy sorra:** ha a forrásnál be van kapcsolva a válaszmező, az értesítéskártya egy-egy üzenetsorára vitt egérnél a sor végén válasz nyíl jelenik meg; rákattintva a mező fölött az idézett sor látszik („Answer this line…”), X-szel visszavonható. Elküldve a válasz kék buborékként a sor alá kerül, a **notch nyitva marad**, és jöhet a következő sor. Beeperen a válasz az adott üzenetre megy (a csevegés utolsó 30 üzenete közül szöveg alapján keresi meg; ha nincs meg, sima üzenet); más appoknál sima üzenetként. Az **egész beszélgetésre** adott válasz Enter után továbbra is bezárja a kártyát. |
| E-18 | (v0.40) **Emoji:** a válaszmező mellett mosolygó ikon; rávitt egérre megnyílik a macOS emoji-választója, a kiválasztott emoji a mezőbe kerül. A beírt emotikonok emojivá válnak, ha önálló szóként állnak (gépelés közben a szóköz után, küldéskor a végén is): `:)` 🙂, `:D` 😄, `xD` 😆, `:(` 🙁, `:'(` 😢, `;)` 😉, `:P` 😛, `:O` 😮, `:*` 😘, `<3` ❤️, `:|` 😐, `B-)` 😎, `^^` 😊, `:/` 😕. Linkekben és időpontokban nem cserél. (v0.42) Az emoji-választó a Dynotch saját, **kis ablaka**, mindig **az emoji ikon alá** nyílik (hoverre vagy kattintásra): legutóbb használtak, majd kategóriák (arcok, kezek, szívek, természet, étel, egyéb); megnyitásakor a notch rögzül. |
| E-13 | Ha egy üzenetet a saját appjában elolvastak vagy megválaszoltak (az értesítés eltűnik a macOS Értesítési központból), **a notch listájából is eltűnik** néhány másodpercen belül. A Dynotch által bezárt bannerek értesítései maradnak. |
| E-14 | A Beeper-kulcs az app saját, csak a felhasználó által olvasható fájljában van (nem a kulcskarikában), így a macOS nem kér jelszót az Értesítések megnyitásakor. A korábban megadott kulcsot egyszer újra be kell illeszteni. |
| E-1b | (v0.43) Az értesítés-adatbázis írását figyeli (a `-wal` fájlt), így az új értesítés azonnal megjelenik; a lekérdezés 5 mp-enként csak tartalék. |
| E-1c | (v0.43) Ha az adatbázis szerkezete megváltozik (macOS-frissítés), érthető hibaüzenet jelenik meg, nem hiányoznak csendben az értesítések. |
| E-19 | (v0.43) **Elhalasztás:** jobb klikk egy értesítésen vagy a lista fejlécén: *1 óra múlva*, *ma este (18:00)*, *holnap reggel (9:00)*. Addig eltűnik, utána újra felugrik. |
| E-20 | (v0.43) **Fókusz mód:** ha egy macOS Fókusz be van kapcsolva, az értesítések nem ugranak fel (a listában ott vannak). Appontként felülbírálható (*Pop up during Focus*), az egész kikapcsolható. A Fókusz állapotát a Teljes lemezeléréssel olvassa. |

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
| SZ-10 | (v0.37) Megnyitáskor (hoverrel, kattintással, gyorsbillentyűvel vagy a menüsorból) a számológép **azonnal fogadja a gépelést**, nem kell belekattintani: a notch erre a modulra rögtön átveszi a billentyűzetet, a kurzor pedig a szöveg végén **egy új sorban** áll (ha az utolsó sor nem üres, új sor kezdődik). |
| SZ-11 | (v0.37) **Szöveg a sorban:** a számítás akkor is kiértékelődik, ha szöveg van körülötte: az utolsó kettőspont utáni rész számít, és az első szám előtti, valamint az utolsó szám utáni szavak elhagyhatók (pl. „Asd: 10*10” → 100, „Rent 1200*12 eur” → 14 400). A számok közötti szó továbbra sem számítás. Az eredmény színe a Dynotch szokásos kékje (korábban zöld). |
| SZ-8 | **Lakat ikon** a notch menüsorában és a menüsor paneljén: alapból szürke, bekattintva **zöld**. Bekattintva a panel **nyitva marad**, akkor is, ha az egér elhagyja (notch), illetve ha máshova kattintasz (menüsor panel). A két lakat független. A notch lakatja a panel bezárásakor (és újraindításkor) kikapcsol. |
| SZ-12 | (v0.43) **Változók:** `ár = 1200`, a lenti sorokban `ár * 1,27`. A sorok együtt számolódnak. |
| SZ-13 | (v0.43) **Százalék:** `20% of 340` → 68. |
| SZ-14 | (v0.43) **Mértékegységek:** `5 km in mi`, `70 kg to lb`, `30 c in f` – hossz, tömeg, hőmérséklet, térfogat, sebesség, adat, idő. Valuta nincs. |
| SZ-15 | (v0.43) **Összeg:** `total` / `sum` / `összesen` sor az előtte álló sorok (az előző üres sorig) összegét adja. |
| SZ-16 | (v0.43) Az eredmények a sor alapvonalán ülnek: Enter az utolsó sorban nem csúsztatja lejjebb az utolsó eredményt. |

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
| R-6b | (v0.35) A feladatlista végén **„New task”** sor: beírva és Entert nyomva a feladat a kiválasztott listába kerül (dátum és „@Lista” felismerése, mint a gyors bevitelnél), a mező utána kész a következőre. A mentés eredménye (a lista azonosítója és írhatósága, a szöveg nélkül) a `reminders.log`-ba kerül. |
| R-7 | A **menüsor-ikon mellett** a kiválasztott lista nyitott feladatainak **száma** látszik (engedély nélkül nincs szám). (v0.40) A szám függőlegesen pontosan az ikon két sora közé igazodik. (v0.42) A számot az ikonnal együtt rajzolja egy képbe, a számjegyek közepe mérten a két sor közé esik. |
| R-8 | Alsó sor: szűrő (kész feladatok), a nyitott feladatok száma vagy hibaüzenet, lakat (menüsor), *Megnyitás az Emlékeztetők appban*. A kézi sorrend (amit az Emlékeztetők appban húzással állítasz) nem érhető el, ezért alapból határidő, azonos határidőnél cím szerinti a sorrend. |
| R-9 | (v0.43) A határidő **színes pill**: lejárt piros, ma narancs, holnap kék, később szürke. |

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
| F-8 | (v0.25) **Az aktív alkalmazáson belül a fókusz nem vált ablakot** (az app maga dönti el, melyik ablaka aktív), csak másik alkalmazásra. Így a párbeszédablakok és felugró ablakok nem villódznak. Ha egy ablak kétszer egymás után nem veszi át a fókuszt, a Dynotch nem próbálkozik tovább, amíg az egér máshová nem megy. |
| F-9 | (v0.26) A lenyitott notch jobb felső sorában, a billentyűzetzár mellett **felfelé nyíl ikonú kapcsoló**: be- és kikapcsolja a funkciót (bekapcsolva kék). |
| F-10 | (v0.35, **v0.36.1-ben visszavonva**) A kattintás körüli szünet (lenyomáskor a függő váltás megszakítása, utána 0,5 mp szünet) után a fókusz alig követte az egeret, ezért a korábbi működés állt vissza. Helyette a `focus.log` rögzíti, miért marad el egy váltás (Dynotch-ablaké a billentyűzet; az ablak kétszer sem tartotta meg a fókuszt; a WindowServer elutasította), okonként legfeljebb percenként egyszer, app- és ablaknevek nélkül. |
| F-11 | (v0.37) A notch panelje bezárás után is „billentyűzetet fogadónak” jelezte magát (nem aktiválja az appot, így semmi nem veszi el tőle ezt az állapotot), ezért gépelés után (beállítások, számológép, jegyzet) a fókusz sokáig nem követte az egeret, főleg kijelzők közötti váltáskor. A notch panelje mostantól csak akkor számít, amikor nyitva van és valóban kéri a billentyűzetet. |
| F-12 | (v0.38) **A szoftveresen rajzolt egérmutató nem akadály:** amikor a macOS szoftveresen rajzolja a mutatót (pl. amíg egy iPad kijelzőként csatlakozik), az egy saját ablak a mutató alatt, a legfelső szinten. Ezt (és a fölötte lévő szinteket) a választás átnézi; korábban emiatt a fókusz egyáltalán nem követte az egeret. |

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
| B-6 | **Bal kattintás** az ikonra megnyitja az alkalmazást (v0.24). **Jobb kattintás** lenyitja a notchot az Értesítések funkcióval, és csak **az adott app még meg nem nyitott értesítéseit** mutatja (a legfrissebbeket, annyit, amennyit a jelvény számol); „All” gombbal vissza a teljes listára, „Open <app>” gombbal megnyitható az alkalmazás. Ha az Értesítések funkció ki van kapcsolva, a kattintás az appot nyitja meg. |
| B-7 | **Sorrend** fogd-és-vidd módszerrel módosítható a notchon (az ikonok húzásával) és a beállítások listájában is. |
| B-8 | (v0.31) **Nem takarja a menüsort:** az app méri, hol ér véget a menüsor a notch bal oldalán (az aktív app menüi Kisegítő hozzáféréssel, a menüikonok a rendszer ablaklistájából), appváltáskor és 3 másodpercenként. Ha a jelvények belelógnának, csak annyi látszik, amennyi kifér (a sorrend elejéről), a többit a bal szélen egy **„‹ +N”** jel mutatja. **Hoverre** az összes kinyílik (ilyenkor ideiglenesen takarhatják a menüt), és visszacsukódik, ha az egér elhagyja a notch bal oldalát. Mérések között egy pillanatra előfordulhat átfedés. |

## 4i. Billentyűzetzár (v0.21)

| # | Követelmény |
|---|-------------|
| KL-1 | A lenyitott notch jobb felső sorában, a beállítások (fogaskerék) mellett **billentyűzet ikonú gomb**: kikapcsolva szürke, bekapcsolva kék. |
| KL-2 | Bekapcsolva **minden billentyűleütést letilt** (betűk, módosítók, médiabillentyűk), hogy a billentyűzet bekapcsolt gép mellett is takarítható legyen. Kisegítő lehetőségek engedély kell hozzá. |
| KL-3 | Kikapcsolni csak egérrel/trackpaddel lehet, ugyanazzal a gombbal. Az app újraindítása után mindig kikapcsolt. |

## 4j. Bejövő hívások (v0.21)

| # | Követelmény |
|---|-------------|
| P-1c | (v0.24) A kártyán **csak a hívó neve** áll; a macOS sorából („Név, P, From Your iPhone”) csak az első rész kell. Üzenetnél a cím sorrendje: telefonszám (SMS, majd iMessage), e-mail-cím (iMessage), végül maga a név, amelyet a Messages a meglévő beszélgetésekből old fel. |
| P-1b | A hívó nevét a banner saját szövegéből veszi (a banner és az Értesítési központ saját elnevezései nélkül); a **képet** és – ha a banner csak számot mutat – a nevet a Névjegyekből (engedély kell). Ha az SMS nem küldhető el, a mező alatt látszik az ok. |
| P-1 | A bejövő (iPhone-ról átirányított vagy FaceTime) hívás **a notchban jelenik meg**: kör alakú monogram, a hívás eredete („from iPhone”) és a hívó neve vagy száma. A hívást az app a macOS saját hívásbanneréből ismeri fel (Accessibility), mert macOS-en nincs hívás-API. Kikapcsolható (Beállítások › General). |
| P-2 | **Felvétel** (zöld) és **elutasítás** (piros) gomb: a macOS-banner megfelelő gombját nyomja meg. A hívás végén (felvétel, elutasítás, a hívó leteszi) a kártya eltűnik. |
| P-3 | Harmadik gomb: **üzenet**. Kattintásra beviteli mező jelenik meg; **Enterre** SMS-t (ha nincs SMS-továbbítás, iMessage-et) küld a hívónak a Messages appon keresztül, majd elutasítja a hívást. A számot a banner szövegéből, név esetén a Névjegyekből veszi (engedély kell). |
| P-4 | Hívás közben a kártya elsőbbséget élvez a notch többi jelzésével szemben; a notch hoverre nem nyílik le. |
| P-5 | (v0.39) **A Telefon app a Dockban marad:** amíg a hívás cseng, és utána, amíg tart (a csengés végétől 5 mp-ig, majd amíg az alapértelmezett mikrofont valami használja), a Telefon / FaceTime app minden magától jövő előugrását elrejti (mint a ⌘H; az ikon a Dockban marad). Ha közben egy másik appban kattintasz (pl. a Dock-ikonjára), és az app előjön, a hívás végéig békén hagyja. *Settings › General › Keep the Phone app in the Dock during calls* (alapból be). |

## 4k. Teendőlista a jegyzetekben (v0.23)

| # | Követelmény |
|---|-------------|
| J-12 | **Teendőlista:** az eszköztár gombja vagy a ⇧⌘L a kijelölt sorokat teendővé alakítja (és vissza). Egy teendő a sor elején álló kör: ○ nyitott, ◉ (narancs) kész; a kész sor szövege halványabb. **Kattintás a körre** kipipálja / visszavonja; a kipipált elem **a lista aljára kerül**, a visszavont a nyitottak végére. Enter új teendőt kezd, üres teendőn Enter kilép a listából. |
| J-12b | Az Apple Notes a saját (natív) listáit és pipáit más appnak nem adja ki és nem engedi írni, ezért a teendők az Apple Notes-ban ○ / ◉ kezdetű sima sorokként látszanak. A natív listát tartalmazó jegyzet csak olvasható marad, de a **„Make editable”** gombbal a listaelemek nyitott teendővé alakíthatók (a natív pipák állapota nem olvasható ki); az Apple Notes az első módosításkor kapja meg az új formát. |
| J-13 | (v0.43) **Scratchpad** (a korábbi „New Note” piszkozat): helyben marad, amíg el nem mentjük a Jegyzetekbe. *Paste as Note* a vágólap szövegét hozzáfűzi; bármely appban kijelölt szöveg a *Services › New Dynotch Note* menüből ide kerül, és a notch a jegyzetekkel nyílik meg. |

## 4l. Gyorsbillentyűk (v0.23)

| # | Követelmény |
|---|-------------|
| SC-1 | **Beállítások › Features:** minden modul mellé rögzíthető egy globális gyorsbillentyű (pl. ⌥1 → Jegyzetek; ⌘, ⌥ vagy ⌃ kötelező; Esc megszakít, Delete töröl). A gyorsbillentyű lenyitja a notchot az adott modullal azon a kijelzőn, ahol az egér van; újra megnyomva bezárja. Billentyűs moduloknál a fókusz rögtön a panelre kerül. Rögzítés nélkül a panel addig marad nyitva, amíg az egér rá nem megy, majd el nem hagyja. |
| SC-3 | Külön gyorsbillentyű a **notch rögzítésére**: nyitott panelnél ki-be kapcsolja a rögzítést, csukottnál rögzítve megnyitja. A lakat ikon rögzítéskor **kék**, mint a billentyűzetzár. |
| SC-2 | **Modulonként** jelölőnégyzet („Pin”) a Features listában: ha be van jelölve, az adott modul gyorsbillentyűs megnyitásakor a notch rögzítése automatikusan bekapcsol (nem záródik be). (v0.26; korábban egy közös kapcsoló volt, annak bekapcsolt állapota minden modulra átöröklődik.) |

## 4m. „Claude befejezte” jelzés (v0.23)

| # | Követelmény |
|---|-------------|
| CN-1 | Amikor a Claude Code befejez egy feladatot, a becsukott notch alatt megjelenik egy sor: fehér Claude-ikon, „Claude finished”, a projekt neve és az időpont. **Csak kétujjas felfelé swipe-ra tűnik el.** Ha egy jelző részletei (hover, meeting-bejelentés) nyitva vannak, azok látszanak helyette. |
| CN-3 | A jelzés **csak akkor jelenik meg, ha a Claude Code mindennel végzett**: ha a leállás pillanatában még fut háttérfeladata (a munkamenet naplója szerint elindult, de nem jelentett vissza és nem lett leállítva), nincs jelzés; az a végső leálláskor jön. A Dynotch saját chatjének futásai nem váltják ki. |
| CN-4 | (v0.26) A jelzés azt a projektet nevezi meg, amelyben a munkamenet **ténylegesen dolgozott** (a napló utolsó szakaszában legtöbbet érintett git-repó), nem azt a mappát, ahonnan a munkamenet indult. |
| CN-2 | Működés: a Beállítások › General kapcsolója egy „Stop” hookot ír a `~/.claude/settings.json` fájlba (biztonsági másolattal), amely a `dynotch://claude-finished?project=…` hivatkozást nyitja meg. Kikapcsolva a hook törlődik. |

## 4n. Claude a notchban (v0.24)

| # | Követelmény |
|---|-------------|
| CC-1 | Új modul **Claude** néven, a menüsorban a Claude jelével. **Bal oldalt** a korábbi chatek listája (legfrissebb felül, törölhetők) és az „New chat” gomb; **jobb oldalt** a beszélgetés és alul a beviteli mező. |
| CC-2 | A válaszokat a gépen lévő **Claude Code** program adja (a szerkesztő-bővítmény legújabb beépített példánya, különben a telepített `claude`), a meglévő bejelentkezéssel; eszközök nélkül, sima beszélgetésként. A beszélgetés folytatható: a chat megjegyzi a munkamenetét. |
| CC-3 | Új chatnél a panel kicsi; **Enterre** elküldi a kérdést, és a panel **lefelé megnő**, a válasz folyamatosan íródik ki. Folyamatosan lehet tovább chatelni; a futó válasz leállítható. |
| CC-4 | Ha a notchot elhagyom, bezárul, de amíg Claude dolgozik, a becsukott notch **bal oldalán a Claude jele, jobb oldalán mozgó pontok** jelzik a munkát. |
| CC-6 | **Előzmények:** a chatlista alján „From Claude Code” címmel megjelennek a Claude Code saját munkamenetei (`~/.claude/projects`, a legfrissebb 40). Kattintásra a beszélgetés szövege betöltődik (eszközhívások és belső jegyzetek nélkül), és folytatható: a következő kérdés a munkamenet **másolatát** viszi tovább, az eredeti érintetlen marad. A claude.ai és a Claude appok beszélgetései az Anthropic szerverein vannak, helyben nem olvashatók, ezért nem húzhatók be. |
| CC-7 | A chatlista (oldalsáv) **becsukható és kinyitható** a „New chat” gomb jobb oldalán lévő gombbal (ikon: lekerekített keret, bal szélén rövid függőleges vonal); becsukva a gomb a beviteli mező elé kerül. Az állapot megmarad. |
| CC-8 | **Menüsor-ikon** (Claude jele) ugyanazzal a chattel, a többi menüsor-panel mintájára; a Features fülön kapcsolható. |
| CC-5 | Amikor megjön a válasz (és a chat nincs a képernyőn), a jelzés eltűnik, és a notch alatt **kis sor lóg le: „Claude answered” + a chat címe**. Ott marad, amíg rá nem viszem az egeret; **hoverre a notch megnő** és a chatet mutatja. |

## 4o. Előnézet hoverre (v0.25)

| # | Követelmény |
|---|-------------|
| PV-1 | Beállítás (General): **hoverre csak előnézet**. Bekapcsolva a notch fölé vitt egérre egy kis panel nyílik: az aktuális modul ikonja, neve és egy sor róla (következő esemény, legutóbbi értesítés, utolsó számítás, jegyzet első sora, nyitott emlékeztetők, AI-keret, Claude utolsó válasza). |
| PV-2 | Beállítás: **hány másodperc hover után nyíljon ki teljesen** (0–5 s, fél másodperces lépésekben; 0 = magától soha). |
| PV-3 | Beállítás: **kattintásra nyíljon ki teljesen**. A gyorsbillentyűk, a jelvények és a „Claude answered” sor mindig a teljes panelt nyitják. |
| C-5 | A Beállítások **App badges** és **Notifications** fülén keresőmező szűri az alkalmazások listáját. |

## 4p. Akkumulátorok (v0.26)

| # | Követelmény |
|---|-------------|
| BT-1 | Új modul **Batteries**: a Mac és minden csatlakoztatott eszköz (billentyűzet, egér, trackpad, fülhallgató és tokja…) egy-egy sor: ikon, név, százalék, akkujel (zöld, 20% alatt piros, töltés közben villám). |
| BT-2 | Adatforrás: a Mac saját akkuja a rendszer áramforrás-adataiból; a Magic-eszközök az I/O Registryből (`ioreg`); az AirPods és más Bluetooth-eszközök a rendszerprofilból (`system_profiler`). Frissítés 2 percenként és a modul megnyitásakor. |
| BT-3 | Ha egy eszköz **20% alá** esik (és nem tölt), a becsukott notch mellett megjelenik: **bal oldalt az eszköz ikonja, jobb oldalt pirossal a töltöttség**. Hoverre a neve és egy **X**; **amíg nem X-elem ki, ott marad**. Kiikszelve csak akkor jön újra, ha az eszközt közben 30% fölé töltötték, majd megint lemerül. |
| BT-1b | (v0.43) Az eszközöket 5 percenként kérdezi le (a `system_profiler` drága). A sorok szövege és ikonja akkora, mint a többi modulban. |
| BT-4 | (v0.43) **Előzmény:** eszközönként egy hét töltöttsége a lemezen; egy sorra kattintva lenyílik a grafikon a becsült hátralévő idővel (az elmúlt nap merülése alapján). |
| BT-5 | (v0.43) **Feltöltve:** értesítés, amikor egy eszköz eléri a 100%-ot. |
| BT-6 | (v0.43) A becsukott notch melletti alacsony-akku jelzés hover-címkéjén kis grafikon (utolsó 24 óra) és a becsült hátralévő idő. |

## 4q. Frissítés és telepítés (v0.27)

| # | Követelmény |
|---|-------------|
| U-1 | Az app indulás után 20 másodperccel, majd **6 óránként** megnézi a legfrissebb GitHub-kiadást. |
| U-2 | Ha újabb verzió van, letölti a verziószámos zipet, és csak akkor telepíti, ha **az SHA256 egyezik** a kiadás `SHA256SUMS.txt`-jével, a csomagban **a várt verzió** van, és **ugyanaz a tanúsítvány írta alá**, mint a futó appot. |
| U-3 | Alapból automatikusan telepít: az app kilép, egy háttérfolyamat kicseréli a `/Applications`-beli példányt (hiba esetén visszateszi a régit), és elindítja az újat. Az újraindulás után egy értesítés jelzi az új verziót. *Settings › About*: automatikus telepítés ki/be, „Check Now” / „Install”, állapot. |
| U-4 | **Homebrew:** `brew install --cask kera77/dynotch/dynotch` (tap: `Kera77/homebrew-dynotch`). A cask mindig a legfrissebb kiadás fix nevű `Dynotch.dmg`-jét tölti le (a Homebrew 7 miatt a tapot előbb `brew trust kera77/dynotch`-csal engedélyezni kell), és leveszi a karantén jelzést, mert az app nincs az Apple-nél hitelesítve. A további frissítéseket az app maga végzi (U-1…U-3). |
| U-5 | (v0.42) Frissítés után a „**Dynotch updated**” a notch megjelenése után 2 mp-cel **feljön**: lelógó sor a notch alatt (kék frissítés ikon, a verzió, az idő), amely **kétujjas felfelé pöccintésre** tűnik el, és az értesítések között is ott van. Korábban a notch elkészülte előtt jött, ezért csak a listában látszott. |

## 4r. iPad mint kijelző (v0.34)

| # | Követelmény |
|---|-------------|
| TB-1 | A kinyitott panel felső sorában, **jobb oldalt**, a „fókusz követi az egeret” kapcsoló mellett (balra tőle) egy tablet ikon (kis lefelé nyíllal) nyit egy menüt, a macOS Kijelzők beállításainak „+” menüjéhez hasonlóan. Az ikon kék, amíg egy iPad kijelzőként csatlakozik. (v0.35: a modulikonok mellől került ide; a jobb oldali gombok 30 pt szélesek, így az öt gomb a legkeskenyebb panelben is a notch mellett marad.) |
| TB-2 | **Mirror or extend to:** a közelben lévő, kijelzőként használható iPadek (Sidecar) pipával; kattintásra csatlakozik (kiterjesztett kijelzőként), pipásra kattintva lecsatlakozik. Nem csatlakozott iPadhez „Mirror to …” sor is van: csatlakozik és rögtön tükröz. Ha nincs iPad: „No iPad nearby”. |
| TB-3 | Csatlakozott iPadnél a menü saját szakaszában: **Extended display / Mirror of the main display** (választó) és **Disconnect**. A tükrözés a fő kijelzőt mutatja az iPaden. |
| TB-4 | A menü alján **Display Settings…** nyitja a macOS Kijelzők beállításait – ott érhető el az AirPlay-kijelző (pl. TV) és a billentyűzet/egér összekapcsolása (Universal Control), mert ezeket egy nem Apple által aláírt app nem tudja vezérelni. Hiba esetén az oka a menüben látszik. Megvalósítás: a privát `SidecarCore` (`SidecarDisplayManager`) és a CoreGraphics tükrözés. |
| TB-5 | (v0.37) A tablet ikon mellől elmaradt a kis lefelé nyíl. Ha a notch bezáródik, a nyitva maradt menü (a tablet menü és a notch többi menüje) is bezáródik, nem marad a képernyőn a következő kattintásig. |

## 4s. Claude kérdez (v0.36)

| # | Követelmény |
|---|-------------|
| CQ-1 | Ha a Claude Code (terminálban, a VS Code-bővítményben vagy a Claude app Code részében) **kérdést tesz fel** (AskUserQuestion), vagy **engedélyre vár** (pl. parancs futtatása), a becsukott notch alatt megjelenik egy sor: Claude-ikon, narancs „Claude asks” / „Claude needs you”, a kérdés (több kérdésnél „(+N)”) vagy az engedélykérés szövege, és az időpont. A „waiting for your input” (tétlen) értesítés nem jelenik meg; arra a „Claude finished” (CN-1) való. A Dynotch saját chatje nem váltja ki. |
| CQ-2 | A sor **magától eltűnik**, amint a kérdésre válasz jött: a következő eszközfutáskor, új promptnál vagy a kör végén. Kétujjas felfelé swipe-pal korábban is eltüntethető. A „Claude finished” sort a válasz nem tünteti el. |
| CQ-3 | Ha az egér a sorra ér, az az app kerül előtérbe, amelyben a Claude Code fut (Terminál, VS Code…), kérdésenként egyszer. |
| CQ-4 | Működés: *Settings › General › Tell me when Claude Code asks a question* hookokat ír a `~/.claude/settings.json`-ba (biztonsági másolattal, a többi app hookjai megmaradnak): `PreToolUse` (csak AskUserQuestion) és `Notification` → `dynotch://claude-asks` (a hook bemenete egy ideiglenes fájlban, az app azonosítója a `__CFBundleIdentifier` változóból); `PostToolUse`, `UserPromptSubmit`, `Stop` → csak ha nyitott kérdés van, `dynotch://claude-answered`. A naplóba csak a sor típusa és az app kerül, a kérdés szövege nem. Kikapcsolva a hookok törlődnek. |

## 4t. Design (v0.39)

| # | Követelmény |
|---|-------------|
| D-1 | *Settings › Appearance › Design* három móddal: **Black** (az eddigi fekete, alapértelmezés), **Liquid glass** (teljes üveg), **Black to glass** (felül, a notch sorában fekete, lefelé fokozatosan üvegbe vált). |
| D-2 | Az üveg **sötétre színezett** Liquid Glass (macOS 26-tól a rendszer `glassEffect`-je), így a fehér szövegek és ikonok világos háttér előtt is olvashatók. macOS 26 előtt sötét elmosott anyag helyettesíti. |
| D-3 | A design a **lenyitott panelen** (minden modul, beállítások, előnézet, értesítéslista) és a **lelógó értesítésen** látszik. A **becsukott notch fekete marad** (a hardveres notch-csal egybeolvad); lenyitáskor a fekete a nyitás rugójával vált át üvegbe, és vissza. (v0.42) Csak a **teljesen lenyitott** notch kapja a designt; a lelógó értesítés, az eszköz-értesítés és az előnézet mindig fekete. |
| D-4 | A **menüsor-buborékok** (számológép, jegyzetek, emlékeztetők, AI usage, Claude chat) ugyanazt a designt kapják; a fekete mód a korábbi sötétszürke. |
| D-5 | Új *Appearance* fül a beállításokban: a design mellett ide kerültek a megjelenést érintő beállítások a General fülről (beállítások megnyitása, lekerekítés, teljes képernyős rejtés, előnézet hoverre). |
| D-6 | (v0.40) **Az üveg mindig üveg:** a rendszer üvege abban az ablakban, amely a billentyűzetet kapja, majdnem feketén rajzolódik (mérve: a gépelős modulok, a beállítások, rögzítés után kikattintva visszaváltott). Ezért az üveg a notch és a menüsor-buborékok alatt **külön, billentyűzetet és egeret soha nem kapó ablakban** van, ugyanazzal a mérettel és animációval; a tartalom fölötte, átlátszó panelen. |
| D-7 | (v0.40) *Settings › Appearance › Displays without a notch*: **Notch** (a felső szélhez simul, alapértelmezés) vagy **Pill**: a notch nélküli kijelzőkön a fekete rész 6 pt-tal a felső szél alatt lebeg, minden sarka kerek (nyugalomban teljes kapszula, lenyitva 24 pt). A hover-zóna ennyivel lejjebb ér. (v0.42) A pill 4 pt-tal a felső szél alatt kezdődik, és **pontosan a menüsor aljánál ér véget** (nyugalomban ennyivel alacsonyabb a notch soránál, a tartalma középen marad). |
| D-8 | (v0.43) Egy helyen a színek és sarkok (`Theme`): a kék, zöld, piros, a kitöltések és a lekerekítések mindenhol ugyanazok. |
| D-9 | (v0.43) Három mozgásfajta (`Motion`): rugó a notch nyitásához, gyors a váltásokhoz, rövid a hoverhez. |
| D-10 | (v0.43) Egyforma **kapszula-választó**: értesítés-fülek, vágólap-fülek, AI-szolgáltató, AI usage, tálca nézete. |
| D-11 | (v0.43) Egyforma **üres állapot**: ikon, egy mondat és ha van, a teendő gombja (pl. *Open Beeper*). |
| D-12 | (v0.43) A **menüsor-buborékok** mindig az eredeti fekete designt kapják, Liquid Glass nélkül, a notch designjától függetlenül. Minden ikongombnak van VoiceOver-címkéje. |

## 4u. Modul-ikonsor és környezetfüggő nyitás (v0.41)

| # | Követelmény |
|---|-------------|
| MS-1 | **Ikonsor a notch alatt:** ha az egér a becsukott notch **alsó sávján** megáll, a notch alá lecsúszik a bekapcsolt modulok ikonsora: áttetsző, elmosott hátterű körök, jól kivehető fehér ikonnal (enyhe árnyék), a notch közepéhez igazítva. Hoverre az ikon kissé nagyobb és világosabb. A sor addig marad, amíg az egér a sávon vagy a soron van. |
| MS-2 | A sáv a notch szélességében, alulról a notch magasságának **1/8–1/3 része** (alapból 1/8), a várakozás **0,1–1,0 mp** (alapból 0,3 mp): *Settings › Appearance › Module strip*. A sáv fölötti rész a szokásos módon azonnal lenyitja a notchot (és eltünteti a sort); ha az egér felfelé áthalad a sávon, nem jön elő a sor. (v0.42) A sáv alapból a notch **alsó fele** (1/4–1/2 állítható); az 1/8 túl vékony volt. |
| MS-3 | Ikonra kattintva a notch **azzal a modullal** nyílik le. |
| MS-4 | Nincs ikonsor értesítés, hívás, teljes képernyős app alatt (N-12), lenyitott notchnál, vagy ha csak egy modul van bekapcsolva. Pill módban (D-7) a sáv és a sor a pillhez igazodik. |
| MS-1b | (v0.43) Az ikonok az egér helyéről **úsznak ki** a helyükre, gyors rugóval (nem felülről jönnek). |
| MS-5 | (v0.43) *Megjelenés › Strip modules*: kiválasztható, mely modulok ikonjai jelenjenek meg a sávban (alapból mind). |
| SO-1 | **Környezetfüggő nyitás:** ha a notch **hoverrel** nyílik (nem gyorsbillentyűvel és nem az ikonsorból), az első teljesülő szabály modulja nyílik meg az utoljára használt helyett. Az új értesítések (E-4) és a „Claude answered” (CC-5) továbbra is a saját nézetüket nyitják. |
| SO-2 | Sorrend: 1. **meeting** visszaszámlálás vagy folyamatban → Naptár; 2. **emlékeztető** 15 percen belül esedékes vagy lejárt (időponttal) → Reminders; 3. **az elmúlt 2 percben kimásolt számítás vagy szám** → Számológép, a kifejezés egy új sorba beírva (eredménnyel); 4. **alacsony akkumulátor** → Akkumulátorok; 5. **AI-fogyasztás 90% fölött** → AI usage. Egyébként az utoljára használt modul. |
| SO-3 | **Egy esemény egyszer:** ugyanaz a meeting, emlékeztető, másolás, eszköz vagy 10%-os fogyasztási lépcső csak egyszer nyitja meg a modulját; ha elváltasz onnan, legközelebb a szokásos modul jön. |
| SO-4 | Szabályonként kikapcsolható: *Settings › Appearance › Smart opening* (alapból mind be). A vágólapnak csak a változásszámlálóját figyeli másodpercenként; a tartalmát csak nyitáskor, az elmúlt 2 percben történt másolásnál olvassa. |

## 4v. Csatlakozó eszközök (v0.42)

| # | Követelmény |
|---|-------------|
| DV-1 | **Csatlakozáskor** a notch alatt lelógó értesítés jelenik meg (mint egy új értesítés, E-3): az eszköz **saját ikonja** (AirPods / AirPods Pro / Max, Magic Keyboard, Magic Mouse, Magic Trackpad, fejhallgató – az akkumulátor-modul ikonjai, BT-2), a neve, az akkumulátor szintje (fülhallgatónál **L / R / Case** külön), jobbra zöld pipa. |
| DV-2 | **Lecsatlakozáskor** ugyanilyen értesítés szürke ikonnal és „Disconnected” felirattal, jobbra áthúzott kör; az utolsó ismert akkumulátorszinttel. |
| DV-3 | Figyelt eszközök: **Bluetooth** (IOBluetooth csatlakozási értesítések), **USB** (IOKit: billentyűzet, egér, pendrive, hub), **külső kijelző** (képernyőváltozás; neve és felbontása), **meghajtó** (csatolás / leválasztás; mérete és szabad helye), **audiokimenet** (CoreAudio: ha a hang egy új eszközre vált). A **meghajtóknál** (pendrive, külső lemez, **telepítő lemezképek / DMG**) az értesítésen mindig ott az **Eject** gomb; a DMG-nél ez a telepítés utáni szokásos kidobást váltja ki. |
| DV-4 | **Gyorsgombok az értesítésen:** pendrive/meghajtó → **Eject** és **Open**; fejhallgató, amely csatlakozott, de nem ő a hangkimenet → **Use for audio**; kijelző → **Displays…** (Kijelzők beállítás). |
| DV-5 | **Zajszűrés:** ébredés után 30 mp-ig és indításkor nincs értesítés (a rendszer ilyenkor mindent újracsatlakoztat); ugyanarról az eszközről 10 mp-en belüli le-fel csatlakozás egy értesítés; az iPhone/iPad (Continuity, Sidecar) és a Mac saját belső eszközei kimaradnak. |
| DV-6 | Megjelenési idő: mint az értesítéseké (E-3, beállítható). Nem kerül az értesítéslistába és a jelvényekbe; a hover nem nyitja az értesítéskártyát, hanem az Akkumulátorok modult (ha be van kapcsolva). |
| DV-7 | *Settings › Devices* (vagy a General fülön): be/ki, kategóriánként (Bluetooth, USB, kijelző, meghajtó, audio) és **lecsatlakozás is** kapcsoló. |
| DV-8 | (v0.42.1) A Bluetooth-figyeléshez az Info.plist-ben ott a használat leírása (`NSBluetoothAlwaysUsageDescription`); nélküle a macOS indításkor leállította az appot. Első indításkor a macOS engedélyt kér a Bluetooth-hoz. |

## 4w. Olvasatlan üzenetek a notchban (v0.42)

| # | Követelmény |
|---|-------------|
| UM-1 | **Cél:** amit a Beeperben vagy a Google Chatben még nem olvastál el (sem az appban, sem a notchban), az **mindig ott van** a notch értesítéseinél, és a notchból válaszolható. A notch nem csak az új értesítésekből dolgozik, hanem az appok olvasatlan állapotából. |
| UM-2 | **Beeper (Desktop API):** 20 mp-enként (és a notch nyitásakor) lekéri a csevegéseket, amelyeknek `unreadCount > 0`; mindegyikből az utolsó *unreadCount* (legfeljebb 10) üzenetet. Ezek egy-egy **olvasatlan csoportot** alkotnak (a feladó/csevegés neve, ikon, üzenetek), amely addig marad, amíg a Beeper szerint a csevegés olvasatlan. |
| UM-3 | **Olvasottnak jelölés a Beeperben is:** ha a csoportot a notchban **megnyitod** (a kártya legalább 2 mp-ig látszik), vagy válaszolsz rá, a Dynotch a Beeper API-n olvasottnak jelöli a csevegést (`POST /v1/chats/{chatID}/read`, az utolsó látott üzenetig). Ha a Beeperben olvasod el, a következő lekérdezéskor a notchból is eltűnik. |
| UM-4 | **Google Chat:** nincs nyilvános API Google-fiók és saját Google Cloud-alkalmazás nélkül, ezért a forrás a macOS Értesítési központ: egy Google Chat-értesítés addig olvasatlan, amíg **benne van az Értesítési központban** (E-13 fordítva: nem tűnik el az idővel, csak ha ott eltűnik – a csevegés megnyitásakor a böngésző/webapp eltávolítja). Válasz a meglévő módon (a csevegés megnyitása és begépelés, E-11b). |
| UM-5 | **Megjelenés:** a becsukott notch mellett az értesítési jelvény (B-1) mutatja az olvasatlanok **összesített számát**; a notch értesítés-nézetében felül egy „**Unread**” szakasz csevegésenként (legújabb elöl), alatta a korábbi értesítések. Hover/kattintás egy csoportra: a kártya (E-4) az olvasatlan üzenetekkel és a válaszmezővel (E-11, E-17 soronkénti válasz). |
| UM-6 | **Duplikáció nélkül:** ha ugyanarról az üzenetről értesítés is jött, csak egyszer látszik (Beeper: az üzenet szövege és ideje alapján összevonva). |
| UM-7 | **Beállítás:** *Settings › Notifications*: „Keep unread chats in the notch” forrásonként (Beeper, Google Chat); a lekérdezési gyakoriság 10–60 mp. Csak a csevegések neve, az üzenetek szövege és ideje kerül a memóriába; lemezre és a naplóba nem. |
| UM-8 | **Nézetválasztó** a notch értesítés-nézetének tetején, három füllel: **All** (minden értesítés, mint eddig, felül az olvasatlan csevegésekkel), **Chats** (csak a Beeper- és Google Chat-beszélgetések: olvasatlanok és a mai csevegések), **Beeper** (a teljes Beeper-nézet, 4x). A választás megmarad; a fülek között swipe-pal is lehet váltani. |
| UM-9 | (v0.43) A **Chats** fülön az olvasatlan Beeper-csevegések újra **értesítéskártyák**, mint a Beeper-fül előtt: kattintásra lenyílnak az olvasatlan üzenetek, soronként saját reply gombbal, alattuk a válaszmező (a Beeperen át küld). A Beeper saját értesítései itt nem duplázódnak. Fülváltáskor a tartalom becsúszik, mint a tálcán. |

## 4x. Beeper a notchban (v0.42)

| # | Követelmény |
|---|-------------|
| BP-1 | **Beeper-fül** (UM-8): **nagyobb panel**, kb. 760 × 420 pt, a Beeper elrendezésével: **balra a csevegések listája** (kb. 240 pt; olvasatlanok elöl, utána a legutóbbi aktivitás szerint), **jobbra a kiválasztott beszélgetés**, alul a válaszmezővel. |
| BP-1b | A **csevegéslista kikapcsolható**: a fül fejlécének oldalsáv-ikonjával és *Settings › Notifications › Beeper › Show the chat list*; lista nélkül a fejlécben legördülő választó mutatja a csevegéseket (olvasatlanok elöl). |
| BP-2 | **Design a Beeperét követi:** sötét felület; a listában kerek profilkép, a sarkában a hálózat kis jelvényével (WhatsApp, Messenger, Telegram, Signal, iMessage, Slack…), név, az utolsó üzenet egy sora, idő, olvasatlanságnál vastag név és kék számos pirula; a beszélgetésben a bejövő üzenetek balra szürke, a sajátok jobbra kék buborékban, csoportban a feladó neve a buborék fölött; a reakciók kis pirulaként a buborék alatt (emoji + szám); a válasz-idézet vékony csíkkal a buborék tetején; napelválasztók („Today”, „Yesterday”). |
| BP-3 | **Profilképek** (7): a csevegés és a feladó képe a Beeperből (`imgURL`, szükség esetén `assets/download`), memóriában gyorsítótárazva; ha nincs kép, monogram színes körben, mint a Beeperben. Az értesítéskártyákon (E-4) is ezek látszanak az app ikonja helyett. |
| BP-4 | **Reakció egy kattintással** (1): üzenetre vitt egérnél a buborék mellett kis sor: 👍 ❤️ 😂 😮 😢 🙏 és egy „+” az emoji-választóhoz (E-18). Kattintásra elküldi (`POST …/messages/{id}/reactions`), saját reakcióra kattintva visszavonja. Csak ahol a csevegés engedi (`capabilities.allowedReactions`). |
| BP-5 | **Megnyitás a Beeperben** (2): gomb a beszélgetés fejlécében és jobb klikkre egy üzeneten: a Beeper azon a csevegésen és üzeneten nyílik meg (`POST /v1/focus` `chatID`, `messageID`), a félig megírt válasz **piszkozatként** átkerül (`draftText`). |
| BP-6 | **Emlékeztető egy csevegésre** (3): a fejlécben harang ikon: „In 1 hour”, „This evening (18:00)”, „Tomorrow 9:00”, „Next week”, „Custom…”, és „Cancel if they reply” kapcsoló (`POST /v1/chats/{id}/reminders`, `dismissOnIncomingMessage`). A beállított emlékeztető a listában kis harangként látszik; törölhető. |
| BP-7 | **Fájlküldés** (5): fájlt a tálcáról (vagy a Finderből) a beszélgetésre húzva, vagy a válaszmező „+” gombjával: feltölti (`assets/upload`), és egy üzenetben elküldi; a válaszmező szövege a fájl mellé kerül. Üzenetenként **egy fájl**; több fájlnál egymás után, mindegyik külön üzenet – egyenként, kézi jóváhagyással (BP-10). |
| BP-8 | **Képek és csatolmányok** (6): képek és GIF-ek kicsinyítve a buborékban (kattintásra Quick Look), videónál előnézeti kép és hossz, hangüzenetnél hossz (és átirat, ha a Beeper ad), fájlnál ikon, név, méret; kattintásra megnyílik. |
| BP-9 | **Szerkesztés és visszavonás** (12): elküldés után 5 mp-ig „Undo” a buborék alatt (törli: `DELETE …/messages/{id}`); saját üzenet jobb klikkre „Edit” (`PUT …/messages/{id}`) és „Delete”, ha a hálózat engedi (`capabilities`). |
| BP-10 | **Csak kézi küldés:** minden üzenet, reakció és fájl csak a felhasználó kifejezett műveletére megy el (Enter, gomb, ejtés); nincs automatikus, ütemezett vagy tömeges küldés. A Beeper figyelmeztet, hogy a túl sok küldés miatt egy hálózat felfüggesztheti a fiókot. |
| BP-11 | **Adatok:** a Beeper Desktop API-n (localhost) keresztül; a token a meglévő (E-11). Az üzenetek és képek csak memóriában vannak; a naplóba csak műveletek és hibakódok kerülnek, tartalom nem. Ha a Beeper nem fut, a fül ezt írja ki, és a többi fül változatlanul működik. |
| BP-12 | **A Beeper jelvényére kattintva** (a notch mellett, B-1) a notch a **Beeper fülön** nyílik le az app megnyitása helyett (ha az Értesítések modul be van kapcsolva; különben marad a régi működés). A jobb klikk (B-6) változatlan. |
| BP-3b | (v0.43) Ha a csevegésnek nincs saját képe, a másik résztvevő képe látszik; ha neki sincs, monogram (emojit és írásjelet kihagyva). A hálózat jelvénye a **telepített hivatalos app ikonja** (WhatsApp, Messenger, Telegram, Signal, Üzenetek, Slack, Discord…), ha nincs telepítve, a színes jel. A sikertelen képletöltést később újrapróbálja. |
| BP-4b | (v0.43) A reply és a reakció gomb **fix szélességű** helyen a buborék mellett (hoverre a sor nem változik); egy üzenetre kattintva arra válaszol. A reakciógomb hoverre a gyors reakciókat, kattintásra a teljes emoji-választót nyitja. Beeper nem fut: *Open Beeper* gomb. |

## 4y. Vágólapkezelő (v0.42)

| # | Követelmény |
|---|-------------|
| CB-1 | Új **Clipboard** modul; a vágólapot a modul bekapcsolása nélkül is figyeli, és a gyorsbillentyű akkor is működik. Szöveget és képet (pl. Shottr) tárol, a legújabb elöl, ismétlés nélkül; újraindítás után is megmarad (Application Support, a képek PNG-ként). |
| CB-2 | Két gyorsbillentyű, módosítható: **⌥V** a vágólap elemeihez, **⌥⇧V** a mentett elemekhez (*Settings › Clipboard*). A magyar kiosztáson az ⌥V a „ karaktert írja; ezt a billentyű elveszi. |
| CB-3 | **Röviden megnyomva** a legutóbbi elemet illeszti be (⌘V a front appnak). **A módosító nyomva tartásával** 0,25 mp után lenyílik a notch: kártyák egymás mellett, alul számozva; a billentyű újra vagy ←→ léptet, ↑↓ vált a vágólap és a mentett elemek között, ⌥1–9 közvetlenül választ; a módosító felengedése beilleszt, Esc megszakít és összecsuk. Választás közben a nyilakat, számokat és az Esc-et csak a Dynotch kapja. |
| CB-4 | A modulban „Clipboard / Saved” fülek, keresés, csillag (mentés), törlés, „Clear”; mentett szöveg felvétele; kattintásra beillesztés a front appba. |
| CB-5 | Képmetszőből (pl. Shottr) másolt kép is elem, kicsinyítve látszik. |
| CB-6 | A jelszókezelők rejtett/ideiglenes jelölésű másolatai (pl. `org.nspasteboard.ConcealedType`) és a kizárt appok másolatai nem kerülnek be. |
| CB-7 | Beállítások: a két gyorsbillentyű, a megtartott elemek száma (5–100, alapból 25), kizárt appok. |

## 4z. Fájltálca (v0.42)

| # | Követelmény |
|---|-------------|
| FT-1 | Fájlt a becsukott notchra húzva lenyílik az ejtési zóna: balra **Keep in Tray**, jobbra **AirDrop**. |
| FT-2 | A tálca a fájlokra **hivatkozást** tárol (követi, ha áthelyezed); ami ideiglenes helyről jön (böngésző, képmetsző), azt a Dynotch tálcamappájába másolja. |
| FT-3 | AirDrop: a rendszer megszokott AirDrop-ablaka nyílik meg. |
| FT-4 | A **Tray** modulban fülek: „Tray” és a „+”-szal csatolt mappák (színes ponttal); swipe-pal is váltható, a végén a következő modulra lép. |
| FT-5 | Fájlok kihúzhatók bármely appba; mappára vagy a rácsra ejtve **másolás**, ⌥-tal **áthelyezés**; dupla kattintás megnyit; jobb klikk: Quick Look, Open, Show in Finder, Remove. |
| FT-6 | Opcionális lejárat: a fájlok N nap után kikerülnek (Never, 1, 3, 7, 14, 30 nap). |
| FT-8 | **Quick Look:** kijelölt fájlon szóköz megnyitja / bezárja. |
| FT-9 | A kiválasztott csatolt mappa változásait (más appból hozzáadott / törölt fájl) azonnal mutatja. |
| FT-10 | (v0.43) A tálca és a csatolt mappák közötti váltás becsúszik, mint az értesítés-fülek. |
| FT-11 | (v0.43) **Mozaik / lista** nézet a mappák sorának jobb szélén; megjegyzi. |
| FT-12 | (v0.43) A kihúzott fájl a behúzáskori nevét tartja meg (a tálca mappánként tárolja). |
| FT-13 | (v0.43) Fájlt a notch fölé húzva két lekerekített szekció: bal **1/3 AirDrop** (az AirDrop ikonjával), jobb **2/3 Keep in Tray**; mindkettő közepén ikon. A húzást az egérgomb lenyomása alatt figyeli, mert a rendszer-húzások nem adnak egéreseményt. |

## 4zz. Google Chat a notchban, API nélkül (v0.42)

| # | Követelmény |
|---|-------------|
| GC-1 | **Google Chat** fül (UM-8) a Beeperével azonos designnal: balra a beszélgetések, jobbra az üzenetek; a forrás az Értesítési központban még meglévő Google Chat-értesítések (UM-4). |
| GC-2 | Ami nem érhető el API nélkül, az nincs a felületen: reakció, emlékeztető, fájlküldés, szerkesztés/visszavonás, profilkép (monogram helyette). |
| GC-3 | Válasz a meglévő módon (a beszélgetés megnyitása és begépelés); a notchból küldött válaszok kék buborékként a beszélgetésben látszanak, amíg a Dynotch fut. |
| GC-4 | „Open Google Chat” gomb a fejlécben. |

## 4ä. AI modul: Claude és ChatGPT (v0.42)

| # | Követelmény |
|---|-------------|
| AI-1 | A Claude modul neve **AI**. Két szolgáltató: **Claude** (a Claude Code-on keresztül, CC-2) és **ChatGPT** (a ChatGPT app **Codex** programján keresztül), mindkettő a Macen bejelentkezett fiókkal – előfizetéssel vagy ingyenes fiókkal; API-kulcs nem kell. A fejléc kapszula-választója (Claude \| ChatGPT) a következő beszélgetés szolgáltatóját adja; egy beszélgetés a sajátjánál marad (másikra váltva új beszélgetés indul). |
| AI-2 | **Modellválasztó** a fejlécben: Claude-nál Opus / Sonnet / Haiku, ChatGPT-nél a fiókban elérhető modellek (a Codex saját listájából, `~/.codex/models_cache.json`); „Default” a szolgáltató alapértelmezése. **Think harder** kapcsoló (agy ikon): Claude-nál több gondolkodás, ChatGPT-nél magas érvelési szint. |
| AI-3 | ChatGPT: `codex exec --json` a Dynotch chatmappájában, **csak olvasható** módban (fájlt nem módosíthat), a folytatás ugyanabban a Codex-munkamenetben (`resume`). Ha a Codex nincs meg vagy nincs bejelentkezés, a hiba szövege a chatben látszik. |
| AI-4 | **Gyorskérdés:** ⌃⌥A (a Modules fülön módosítható) bárhonnan megnyitja az AI modult, a mező rögtön fogadja a gépelést. |
| AI-5 | **Kontextus:** a mező fölötti sávból a vágólap (szöveg a kérdésbe, kép csatolmányként), a front appban kijelölt szöveg (Accessibility), fájl csatolása (gombbal vagy ráhúzva); a csatolmányok kis címkéként látszanak, X-szel eltávolíthatók. Claude a csatolt fájlokat olvasni tudja (csak a Read eszköz), ChatGPT a képeket közvetlenül kapja. |
| AI-6 | **Fogyasztás:** az AI usage modulban Claude \| ChatGPT választó; a ChatGPT keretei a Codex naplóiból (`rate_limits`: használt %, ablak, visszaállás), hálózat és bejelentkezési adat nélkül – akkor frissülnek, amikor a Codexet bárhol használják. A notch melletti jelző **amelyik közelebb van a kerethez**, azt mutatja. |
| AI-7 | **Formázott válasz:** címek félkövéren, félkövér/dőlt/kód/linkek, **kódblokkok** külön dobozban „Copy” gombbal; minden válasz alatt **Copy** és **Insert** (bezárja a notchot és beilleszti a front appba). |
| AI-8 | **Sablonok** (a fejléc menüjéből): fordítás angolra/magyarra, összefoglalás, udvariasabb átírás, egyszerű magyarázat, helyesírás javítása; a beírt kérdés saját sablonként menthető és törölhető. |
| AI-9 | *Settings › General › AI:* alapértelmezett szolgáltató és szolgáltatónként alapértelmezett modell. |
| AI-11 | A beszélgetéslistában **keresés** (cím és szöveg) és **kitűzés** (jobb klikk: Pin / Unpin; a kitűzöttek elöl, 📌 jellel); a válaszkész jelzés a szolgáltató nevét írja („ChatGPT answered”). |
| AI-12 | **Folytatás a Terminálban:** a fejléc gombja a beszélgetést a Claude Code-ban vagy a Codexben folytatja (ugyanaz a munkamenet). |
| AI-6b | (v0.43) Az AI usage fejlécében *Updated*, *Show at notch* és frissítés gomb ChatGPT-nél is. |
| AI-13 | (v0.43) Az AI modul ikonja ✨ (sparkles); Claude-nál és ChatGPT-nél mindenhol a telepített hivatalos app ikonja. A bal oldali előzmények csak az aktuális szolgáltatás csevegései. |
| AI-14 | (v0.43) **Diktálás:** mikrofon gomb a beviteli mező mellett, a macOS diktálását indítja (saját mikrofonengedély nélkül). |
| AI-15 | (v0.43) **Kedvencek:** csillag a válaszok alatt; a csevegőlistában *Favorites* szakasz, kattintásra a csevegés nyílik meg, jobb klikkel másolás vagy eltávolítás. |
| AI-16 | (v0.43) **ChatGPT módja:** *Codex* (a notchban, a Codex CLI-vel) vagy *ChatGPT* (a kérdés a chatgpt.com-on nyílik meg, ingyenes fiókkal is). A beállításokban *Sign in to ChatGPT…*. |

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
| **v0.43** | A 0.42 tesztjén talált hibák javítása; napi idővonal, értesítés-elhalasztás és Fókusz, számológép-változók és mértékegységek, scratchpad, határidő-pillek, akku-előzmény, AI diktálás és kedvencek, ChatGPT-mód; egységes design, Engedélyek fül, gyorsabb notch |
| **v0.42.1** | Javítás: a 0.42 indításkor kilépett (hiányzó Bluetooth-leírás) |
| **v0.42** | AI modul (Claude + ChatGPT), vágólapkezelő, fájltálca, értesítés-fülek, Beeper és Google Chat a notchban, csatlakozó eszközök; a v0.40–0.41 hibáinak javítása |
| **v0.41** | Modul-ikonsor a notch alsó sávjánál; környezetfüggő nyitás (meeting, emlékeztető, másolt számítás, akkumulátor, AI usage) |
| **v0.40** | Üveg külön ablakban (nem vált feketére); pill külső kijelzőn; beállítások az első kattintásig; Join a meeting hover-sorában; válasz egy sorra, emoji; nincs App Nap |
| **v0.39** | Design-választó (fekete / Liquid Glass / átmenet), Appearance fül; a Telefon app hívás közben a Dockban marad |
| **v0.38** | Autoraise szoftveres egérmutató mellett is (iPad-kijelző); a válaszmező alapból ki |
| **v0.37** | Beállítások rögzítve nyílnak; számológép: szöveg a sorban, kék eredmény, azonnali gépelés; autoraise gépelés után is vált; csak a tartalmas oldal kerek (kapcsoló); a tablet menü a notch-csal együtt záródik |
| **v0.36.1** | Az autoraise korábbi működése visszaáll; naplózza, ha nem vált |
| **v0.36** | Jelzés a notch alatt, ha a Claude Code kérdez vagy engedélyre vár (terminál, VS Code); válaszra eltűnik |
| **v0.35** | A notch csak alapállapotban kapszula; tablet menü jobbra, a gombok elférnek; „New task” sor az Emlékeztetőkben; autoraise kattintás közben nem vált |
| **v0.34** | Kapszula alakú notch; rejtés teljes képernyős appoknál (felső szélre nyílik); iPad mint kijelző a felső sor menüjéből |
| **v0.33** | Lekerekített, Dynamic Island-szerű notch (kapcsolható); a Notifications fül keresője az űrlap fölé került; a böngészők korábbi értesítéseinek oldalai is külön forrásként jelennek meg |
| **v0.32** | Weboldalanként külön értesítésforrás (Zen); szabályok forrásonként (név, banner, válaszmező) |
| **v0.31** | A Space-animáció időzítése; a Notifications fül keresője kattintható; a jelvények nem takarják a menüsort („‹ +N”, hoverre kinyílik) |
| **v0.30** | A Space-váltás animációja a swipe-pal együtt indul és ér véget |
| **v0.29** | Space-váltás animáció; értesítésre válaszoláskor rögzül a notch; Modules fül húzható sorokkal; Pin csak gyorsbillentyűvel |
| **v0.28** | A modulikonok elférnek a notch mellett, swipe-pal léptethetők; a jelvény jobb klikkes listája mindig csak az adott app értesítéseit mutatja |
| **v0.27** | Automatikus frissítés; Homebrew-telepítés |
| **v0.26** | Akkumulátor-modul és merülésjelzés; minden rendszerértesítés; a „Claude finished” a valódi projektet írja; élesebb körök; fókusz-kapcsoló a menüsorban |
| **v0.25** | Előnézet hoverre; Claude Code-előzmények, becsukható oldalsáv és menüsor-ikon a Claude-modulban; „Claude finished” csak a háttérmunka végén; kereső a beállítások applistáiban; appon belül nincs fókuszváltás |
| **v0.24** | Claude-chat a notchban; rögzítés-gyorsbillentyű; jelvény bal/jobb klikk; appban elintézett értesítések eltűnnek; hívó csak névvel, iMessage-tartalék; Beeper-kulcs fájlban; fókusz-villódzás javítása |
| **v0.23** | Teendőlista a jegyzetekben; modulonkénti gyorsbillentyűk; „Claude befejezte” jelzés; hívó neve és képe |
| **v0.22** | Értesítések küldőnként csoportosítva, kattintásra kinyíló csoport válaszmezővel; jelvény-kattintás az app értesítéseit mutatja; hívásfelismerés javítása |
| **v0.21** | Bejövő hívások a notchban (felvétel, elutasítás, SMS); billentyűzetzár; Beeper/Google Chat/Gmail jelvényikonok; hoverre megálló pulzálás |
| **v0.20** | App-jelvények (olvasatlan értesítések száma a notch mellett); fehér Claude-ikon, szint szerinti színek |
| **v0.20+** | További funkciók (például Most játszott zene, Fájlpolc, Időzítő), külön specifikálva |
