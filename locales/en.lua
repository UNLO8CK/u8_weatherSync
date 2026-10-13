--[[
    u8_weatherSync — English nyelvi fájl (szerver)
    ─────────────────────────────────────────────────────────────────────────
    A `%s` / `%d` helyére kerülnek a változó adatok — a sorrendjüket ne
    cseréld fel. Hiányzó kulcsnál az angol szöveg, majd maga a kulcs látszik.
]]

Locales = Locales or {}

Locales['en'] = {
    ['no_permission'] = 'You do not have permission to use this command.',
    ['usage_weather'] = 'Usage: /%s <type|live>. Types: %s',
    ['usage_time'] = 'Usage: /%s <HH:MM|live>',
    ['weather_set'] = 'Weather set to %s (fixed until /%s live).',
    ['weather_live'] = 'Weather follows the real weather again.',
    ['time_set'] = 'Time set to %s (fixed until /%s live).',
    ['time_live'] = 'Time follows the real time again.',
    ['status_weather'] = 'Weather: %s (%s)',
    ['status_time'] = 'Time: %s (%s)',
    ['mode_live'] = 'live',
    ['mode_manual'] = 'manual',
    ['temp'] = 'Temperature: %s°C',
    ['api_ok'] = 'Weather updated: %s, %s°C, rain: %s',
    ['api_fail'] = 'Weather request failed (%s). Keeping the last value.',
    ['started'] = 'Started. Timezone: %s, refresh: %s s.',
    ['ver_running'] = 'Running version: v%s',
    ['ver_latest'] = 'You are running the latest version (v%s).',
    ['ver_outdated'] = 'A new version is available: v%s (current: v%s)',
    ['ver_download'] = 'Download: %s',
    ['ver_failed'] = 'Version check failed (%s).',
    ['snow_start'] = 'Winter is here, it started snowing!',
    ['snow_end'] = 'Winter is over, the snow has melted.',
    ['snow_hint'] = 'Press %s to make a snowball.',
    ['gather_done'] = '+%d snowball',
    ['gather_full'] = 'You cannot carry more snowballs.',
}
