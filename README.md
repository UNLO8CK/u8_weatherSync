# u8_weatherSync

Valós idejű játékóra és **budapesti időjárás** szinkron FiveM-re. / Real-time game clock + real Budapest weather for FiveM.

- **Idő:** 1 játékperc = 1 valós perc, a budapesti fali órához igazítva (téli/nyári időszámítással). A szerver számol, a kliens csak megjeleníti.
- **Időjárás:** [Open-Meteo](https://open-meteo.com/) (API-kulcs nélkül), WMO kód → GTA időjárás, eső- és szélerősséggel. Az átmenet sima (alapból 90 mp), nem ugrik.
- **Admin:** `/weather <típus|live>` és `/time <ÓÓ:PP|live>`, ACE jogosultsággal. A beállítás tartós, amíg valaki ki nem adja a `live` parancsot.
- Függőség nélküli (ESX/QB nem kell), NUI nincs, képkockánkénti ciklus nincs.

## Telepítés

1. A mappát másold a `resources` alá, `server.cfg`:
   ```
   ensure u8_weatherSync
   add_ace group.admin u8_weatherSync.admin allow
   ```
2. Az admin csoportba tartozó játékosok használhatják a parancsokat (`add_principal identifier.license:XXXX group.admin`).
3. Állítsd le a többi idő/időjárás scriptet (vSync, cd_easytime, qb-weathersync…), különben harcolnak egymással.

## Beállítás

Minden a `shared/config.lua`-ban van (város koordinátái, időzóna, frissítési gyakoriság, átmenet hossza, hó, esőerősség, WMO → GTA térkép). Nyelv: `Config.Locale = 'hu'` (alap) vagy `'en'`, új nyelv = új fájl a `locales/` mappában.
Más városhoz: `Config.Weather.Latitude/Longitude` + `Config.Time.Timezone` (`Name`, `BaseOffset`, `DST`).

## Tél (Config.Snow)

December 1. 00:00-tól március 1. 00:00-ig (helyi idő, a dátumok configban állíthatók) a talajon hó van ("Snow On Terrain"), **az időjárástól függetlenül**: lehet napsütés vagy eső is, a hó a földön marad. A gyalogosok lábnyomot, a járművek keréknyomot hagynak (ropogó hanggal), az autók tapadása csökken (`Slippery.Strength`). Az égből való havazás opcionális (`Fall.Enabled`, alapból ki).
Hógolyó (`Gather.Mode`): `'inventory'` = az ox_inventoryba kerül, `'hand'` = azonnal a kezébe, az inventoryba nem (egyszerre max 1). A gyúrás: a `Gather.Key` gombbal (alap: **E**, a játékos átállíthatja a Key Mappingben) lehajol és havat gyúr, a hógolyó (`WEAPON_SNOWBALL`) a `Gather.Mode` szerint az inventoryba vagy a kezébe kerül. `Gather.Enabled = false`-nál nem lehet gyúrni. Csak akkor működik, ha van hó. A szerver ellenőrzi az időt, a távolságot, a cooldownt és a hordható mennyiséget.

## Parancsok

| Parancs | Hatás |
|---|---|
| `/weather` | aktuális időjárás és használat |
| `/weather rain` | fix esős idő (a `live`-ig) |
| `/weather live` | vissza a valós budapesti időjárásra |
| `/time 21:30` | fix idő (a `live`-ig, az óra áll) |
| `/time live` | vissza a valós időre |

A szerver konzolból is használhatók.

## Exportok (szerver)

`exports.u8_weatherSync:GetWeather()` → GTA típus, `exports.u8_weatherSync:GetTime()` → `óra, perc`.

## Biztonság

- A kliens nem küldhet időt/időjárást: az egyetlen net event a `u8_weatherSync:ready` (paraméter nélkül, 10 mp rate limit).
- A szerver az API válaszát validálja, a kliens a szervertől kapott értékeket is (típus-whitelist, tartományok).
- A `shared/config.lua` minden játékoshoz eljut, ezért nincs benne titok; a nyelvi fájlok csak szerver oldaliak.

## Adatforrás

Időjárás adat: [Open-Meteo.com](https://open-meteo.com/) (CC BY 4.0). Az ingyenes API **nem kereskedelmi** használatra szól; kereskedelmi szerverhez szerezz kereskedelmi licencet.

## Licenc

MIT – UNLO8CK
