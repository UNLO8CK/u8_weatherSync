--[[
    u8_weatherSync — UNLO8CK
    ─────────────────────────────────────────────────────────────────────────
    Valós idejű óra + budapesti időjárás szinkron.

    BIZTONSÁG

    Ami `client_scripts` vagy `shared_scripts` alá kerül, azt minden játékos
    letölti és kiolvashatja. A `shared/config.lua` ezért nem tartalmaz
    titkot; a nyelvi fájlok (locales/) csak SZERVER scriptek. A kliens nem
    tud időt vagy időjárást állítani:
    az egyetlen net event, amit elsüthet, a `u8_weatherSync:ready`
    (állapot kérése, paraméter nélkül, rate limittel).
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'u8_weatherSync'
author      'UNLO8CK'
version     '1.0.0'
description 'Valós idejű játékóra és budapesti időjárás szinkron (Open-Meteo), sima átmenettel.'
license     'MIT'

shared_scripts {
    'shared/config.lua',
}

server_scripts {
    'locales/*.lua', -- hu.lua, en.lua – csak a szerver használja, a kliens nem tölti le
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
