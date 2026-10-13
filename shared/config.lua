--[[
    u8_weatherSync — Konfiguráció (shared)
    SHARED fájl: minden játékos letölti és kiolvashatja, ezért NE írj ide
    titkot (kulcs, webhook, jelszó). Jelenleg nincs is ilyen benne.
]]

Config = {}

-- Nyelv: 'hu' (alapértelmezett) vagy 'en'. Váltás: írd át 'en'-re.
-- Új nyelv: másold le a locales/hu.lua-t (pl. de.lua), fordítsd le, és írd ide a nevét.
Config.Locale = 'hu'

-- Részletes konzol napló (HTTP válaszok, állapotváltások)
Config.Debug = false

-- ══════════════════════════════════════════════════════════════════════════
--  VERZIÓFIGYELŐ
-- ══════════════════════════════════════════════════════════════════════════
--
--  Indításkor mindig kiírja a futó verziót. Ha Enabled = true, a GitHub
--  legfrissebb release-ét is lekéri, és jelzi, ha újabb verzió van.
--  Ha false, nem megy ki semmilyen kérés, csak a verzió íródik ki.
Config.VersionCheck = {
    Enabled    = true,
    -- GitHub 'tulajdonos/repó' (a release tag-je legyen pl. v1.0.1 vagy 1.0.1)
    Repository = 'UNLO8CK/u8_weatherSync',
}

-- ══════════════════════════════════════════════════════════════════════════
--  ADMIN JOGOSULTSÁG (ACE)
-- ══════════════════════════════════════════════════════════════════════════
--
--  Az /weather és /time parancsot az használhatja, akinek ez az ACE
--  jogosultsága megvan (a szerver konzol mindig használhatja).
--  server.cfg:
--      add_ace group.admin u8_weatherSync.admin allow
--      add_principal identifier.license:XXXX group.admin
Config.Ace = 'u8_weatherSync.admin'

Config.Commands = {
    Weather = 'weather',
    Time    = 'time',
}

-- ══════════════════════════════════════════════════════════════════════════
--  IDŐ
-- ══════════════════════════════════════════════════════════════════════════
--
--  1 játékperc = 1 valós perc. A szerver kiszámolja a helyi időt, a kliensek
--  csak a pillanatnyi másodpercet kapják meg.
Config.Time = {
    Timezone = {
        -- Az Open-Meteo-nak küldött IANA név (ugyanez a város ideje is).
        Name       = 'Europe/Budapest',
        -- Téli (standard) UTC eltolás másodpercben. Budapest: UTC+1 = 3600.
        BaseOffset = 3600,
        -- Nyári időszámítás:
        --   'eu'  = európai szabály (március utolsó vasárnapja – október
        --           utolsó vasárnapja, 01:00 UTC), a szerver maga számolja
        --   'api' = az Open-Meteo által küldött eltolás (nem EU-s városhoz;
        --           a váltás legfeljebb egy lekérdezési ciklust késik)
        --   'off' = nincs nyári időszámítás
        DST        = 'eu',
    },

    -- Milyen gyakran küldjön a szerver friss időt mindenkinek (mp).
    -- A kliens magától is járatja az órát, ez csak a driftet javítja.
    SyncInterval = 60,
}

-- ══════════════════════════════════════════════════════════════════════════
--  IDŐJÁRÁS
-- ══════════════════════════════════════════════════════════════════════════
Config.Weather = {
    -- A város, aminek az időjárását követjük (Budapest).
    Latitude  = 47.4979,
    Longitude = 19.0402,

    -- Lekérdezés gyakorisága (mp). Az Open-Meteo ingyenes API-ja nem
    -- kereskedelmi használatra szól; 10 perc bőven elég, és az adat is
    -- 15 percenként frissül. Minimum 300.
    UpdateInterval = 600,

    -- Ennyi másodperc alatt megy át az egyik időjárásból a másikba
    -- a valós időjárás-követésnél, illetve admin parancsnál.
    Transition       = 90,
    ManualTransition = 15,

    -- Induláskor, amíg nincs első API válasz (vagy ha az API nem elérhető).
    Default = 'CLEAR',

    -- Napos időnél (kevés felhő, nappal) EXTRASUNNY, különben CLEAR.
    SunnyMaxCloud = 20,

    -- Évszakon KÍVÜLI valós havazás követése (WMO 71-77, 85-86). Kikapcsolva
    -- ilyenkor az 'OVERCAST' típust kapja. A téli időszakot a Config.Snow
    -- kezeli, ettől függetlenül.
    Snow = false,

    -- Eső mértéke (0.0 – 0.5; 0.5 fölött a GTA nem erősít). A csapadék
    -- mm-éből számolva: Base + mm * PerMm, a határokon belül.
    Rain = { Base = 0.15, PerMm = 0.08, Max = 0.5 },

    -- Szél (a GTA ~0–12 m/s tartományt használja).
    Wind = { Enabled = true, MaxSpeed = 12.0 },

    -- WMO időjárás kód → GTA időjárás típus.
    -- Érvényes típusok: EXTRASUNNY CLEAR CLOUDS SMOG FOGGY OVERCAST RAIN
    -- THUNDER CLEARING NEUTRAL SNOW BLIZZARD SNOWLIGHT XMAS HALLOWEEN
    CodeMap = {
        [0]  = 'CLEAR',    [1]  = 'CLEAR',
        [2]  = 'CLOUDS',   [3]  = 'OVERCAST',
        [45] = 'FOGGY',    [48] = 'FOGGY',
        [51] = 'CLEARING', [53] = 'CLEARING', [55] = 'RAIN',
        [56] = 'CLEARING', [57] = 'RAIN',
        [61] = 'CLEARING', [63] = 'RAIN',     [65] = 'RAIN',
        [66] = 'RAIN',     [67] = 'RAIN',
        [71] = 'SNOWLIGHT', [73] = 'SNOW',    [75] = 'BLIZZARD', [77] = 'SNOWLIGHT',
        [80] = 'CLEARING', [81] = 'RAIN',     [82] = 'RAIN',
        [85] = 'SNOWLIGHT', [86] = 'BLIZZARD',
        [95] = 'THUNDER',  [96] = 'THUNDER',  [97] = 'THUNDER',  [99] = 'THUNDER',
    },
}

-- ══════════════════════════════════════════════════════════════════════════
--  FELHŐZET (cloud hat)
-- ══════════════════════════════════════════════════════════════════════════
--
--  A felhőzet az időjárástól független réteg. Induláskor alaphelyzet (reset,
--  nincs külön felhőréteg), majd Interval percenként a szerver kisorsol egyet
--  a listából (az előzőt nem ismétli). A Menyoo LOAD_CLOUD_HAT-ja ugyanezt
--  hívja 0,5 mp-es átmenettel; itt lassabb, a Transition másodpercben állítható.
Config.Clouds = {
    Enabled    = true,
    Interval   = 30,   -- perc
    Transition = 20,   -- mp (a Menyooban 0.5)
    List = {
        'Clear 01', 'Cloudy 01', 'Contrails', 'Nimbus', 'Puffs',
        'Stratoscumulus', 'Wispy',
    },
}

-- ══════════════════════════════════════════════════════════════════════════
--  TÉL
-- ══════════════════════════════════════════════════════════════════════════
--
--  A téli időszakban a talajon hó van ("Snow On Terrain"), a lábnyomok és a
--  keréknyomok látszanak, és az autók csúsznak. Ez FÜGGETLEN az időjárástól:
--  lehet EXTRASUNNY, eső vagy bármi más, a hó a földön marad.
--  Az időszak a helyi (Config.Time.Timezone) időben számít, a Start napjának
--  00:00-jától az End napjának 00:00-jáig (az End már NEM téli nap).
Config.Snow = {
    Enabled = true,

    Season = {
        Start = { Month = 12, Day = 1 },
        End   = { Month = 3,  Day = 1 },
    },

    -- Opcionális: télen az égből is havazzon-e. Alapból NEM: az időjárás a
    -- valós budapesti időjárás marad, csak a talajon van hó. Ha Enabled = true,
    -- a valós időjárás típusát havazásra cseréli:
    --   Calm = derült/felhős/ködös, Precip = esős, Heavy = zivatar.
    Fall = { Enabled = false, Calm = 'XMAS', Precip = 'SNOW', Heavy = 'BLIZZARD' },

    -- Lábnyomok (gyalogos) és keréknyomok (jármű) a hóban + ropogó hang.
    Footprints    = true,
    VehicleTracks = true,

    -- Csúszós út: a járművek tapadása a megadott szorzóra csökken
    -- (1.0 = nincs változás, 0.65 = észrevehetően csúszós, 0.4 = jég).
    Slippery = { Enabled = true, Strength = 0.65 },

    -- Hógolyó gyúrása: a megadott gombbal lehajol és havat gyúr.
    -- Csak akkor működik, ha van hó (téli időszak vagy havas időjárás).
    -- A gomb a játékos saját beállításai között átállítható (Key Mapping).
    Gather = {
        Enabled  = true,
        Key      = 'E',
        -- Hová kerüljön a hógolyó:
        --   'inventory' = az ox_inventoryba (ha az nem fut, kézbe kerül)
        --   'hand'      = azonnal a kezébe, az inventoryba NEM kerül; ilyenkor
        --                 egyszerre legfeljebb 1 lehet nála, eldobás után gyúrhat újat
        Mode     = 'inventory',
        Item     = 'WEAPON_SNOWBALL', -- ox_inventory eldobható hógolyó / GTA fegyver
        Amount   = 1,                 -- inventory módban ennyit kap egy gyúrásra
        MaxCarry = 10,                -- inventory módban ennyinél többet nem cipelhet
        Duration = 3000,              -- ms, a gyúrás hossza
        Cooldown = 1500,              -- ms, két gyúrás között
    },
}

-- Ezeket a típusokat fogadja el az /weather parancs.
Config.ManualWeatherTypes = {
    'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'SMOG', 'FOGGY', 'OVERCAST', 'RAIN',
    'THUNDER', 'CLEARING', 'NEUTRAL', 'SNOW', 'BLIZZARD', 'SNOWLIGHT',
    'XMAS', 'HALLOWEEN',
}
