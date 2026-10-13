--[[
    u8_weatherSync — Magyar nyelvi fájl (szerver)
    ─────────────────────────────────────────────────────────────────────────
    A `%s` / `%d` helyére kerülnek a változó adatok — a sorrendjüket ne
    cseréld fel. Hiányzó kulcsnál az angol szöveg, majd maga a kulcs látszik.
]]

Locales = Locales or {}

Locales['hu'] = {
    ['no_permission'] = 'Nincs jogosultságod ehhez a parancshoz.',
    ['usage_weather'] = 'Használat: /%s <típus|live>. Típusok: %s',
    ['usage_time'] = 'Használat: /%s <ÓÓ:PP|live>',
    ['weather_set'] = 'Az időjárás beállítva: %s (fix, amíg /%s live nem fut).',
    ['weather_live'] = 'Az időjárás újra a valós budapesti időjárást követi.',
    ['time_set'] = 'Az idő beállítva: %s (fix, amíg /%s live nem fut).',
    ['time_live'] = 'Az idő újra a valós idő.',
    ['status_weather'] = 'Időjárás: %s (%s)',
    ['status_time'] = 'Idő: %s (%s)',
    ['mode_live'] = 'valós',
    ['mode_manual'] = 'kézi',
    ['temp'] = 'Budapest: %s°C',
    ['api_ok'] = 'Időjárás frissítve: %s, %s°C, eső: %s',
    ['api_fail'] = 'Az időjárás lekérése sikertelen (%s). A legutóbbi érték marad.',
    ['started'] = 'Elindult. Időzóna: %s, frissítés: %s mp.',
    ['ver_running'] = 'Futó verzió: v%s',
    ['ver_latest'] = 'A legújabb verziót használod (v%s).',
    ['ver_outdated'] = 'Új verzió érhető el: v%s (jelenlegi: v%s)',
    ['ver_download'] = 'Letöltés: %s',
    ['ver_failed'] = 'A verzióellenőrzés nem sikerült (%s).',
    ['snow_start'] = 'Beköszöntött a tél, havazni kezdett!',
    ['snow_end'] = 'Vége a télnek, elolvadt a hó.',
    ['snow_hint'] = 'Hógolyót a(z) %s gombbal gyúrhatsz.',
    ['gather_done'] = '+%d hógolyó',
    ['gather_full'] = 'Nem bírsz több hógolyót cipelni.',
}
