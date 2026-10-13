--[[
    u8_weatherSync — Szerver
    ─────────────────────────────────────────────────────────────────────────
    - Idő: a szerver számolja a helyi (budapesti) időt, a kliensek csak a
      pillanatnyi másodpercet kapják meg.
    - Időjárás: Open-Meteo (API-kulcs nélkül), WMO kód → GTA típus.
    - Admin: /weather és /time (ACE), tartós felülírás a `live` parancsig.

    Teljesítmény: nincs képkockánkénti ciklus. Két alvó szál van
    (időszinkron: 60 mp, időjárás-lekérés: 10 perc), és az időjárást csak
    változáskor küldjük ki.
]]

print('^00')
print('^11')
print('^22')
print('^33')
print('^44')
print('^55')
print('^66')
print('^77')
print('^88')
print('^99')
print('^1010')

local Cfg = Config
local TZ  = Cfg.Time.Timezone
local WCfg = Cfg.Weather

-- ══════════════════════════════════════════════════════════════════════════
--  Nyelv + napló
-- ══════════════════════════════════════════════════════════════════════════

local function _L(key, ...)
    local s = (Locales[Cfg.Locale] or Locales.en)[key] or Locales.en[key] or key
    if select('#', ...) > 0 then return s:format(...) end
    return s
end

local TAG = '^5[u8_weatherSync]^7 '
local function log(level, msg)
    local colors = { info = '^2', warn = '^3', error = '^1' }
    print(('%s%s%s^7 %s'):format(TAG, colors[level] or '^7', level:upper(), msg))
end
local function debug(msg) if Cfg.Debug then log('info', msg) end end

-- ══════════════════════════════════════════════════════════════════════════
--  Állapot
-- ══════════════════════════════════════════════════════════════════════════

local validManual = {}
for _, t in ipairs(Cfg.ManualWeatherTypes) do validManual[t] = true end

local State = {
    apiOffset = TZ.BaseOffset, -- az API által jelzett UTC eltolás (DST='api')
    temp      = nil,

    time = { mode = 'live', fixed = 0 },                  -- fixed: nap másodperce
    weather = {
        mode = 'live',
        live   = { type = WCfg.Default, rain = nil, ws = 0.0, wd = 0.0 },
        manual = nil,
    },
}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- ══════════════════════════════════════════════════════════════════════════
--  IDŐ (UTC → helyi, DST)
-- ══════════════════════════════════════════════════════════════════════════

-- Napok száma 1970-01-01 óta (proleptikus gergely naptár, időzóna-független).
local function daysFromCivil(y, m, d)
    if m <= 2 then y = y - 1 end
    local era = (y >= 0 and y or y - 399) // 400
    local yoe = y - era * 400
    local doy = (153 * (m + (m > 2 and -3 or 9)) + 2) // 5 + d - 1
    local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468
end

-- Egy hónap utolsó vasárnapja 01:00 UTC-kor (epoch másodperc).
local function lastSundayUtc(year, month)
    local last = daysFromCivil(year, month, 31) -- március és október is 31 napos
    local weekday = (last + 4) % 7              -- 0 = vasárnap (1970-01-01 csütörtök)
    return (last - weekday) * 86400 + 3600
end

local function utcOffset(utc)
    if TZ.DST == 'api' then return State.apiOffset end
    if TZ.DST == 'off' then return TZ.BaseOffset end

    local year = os.date('!*t', utc).year
    local dst = utc >= lastSundayUtc(year, 3) and utc < lastSundayUtc(year, 10)
    return TZ.BaseOffset + (dst and 3600 or 0)
end

---@return integer secondOfDay, string clockText
local function localClock()
    local utc = os.time()
    local sod = (utc + utcOffset(utc)) % 86400
    return sod, ('%02d:%02d'):format(sod // 3600, (sod % 3600) // 60)
end

local function timePacket()
    if State.time.mode == 'manual' then
        return { sod = State.time.fixed, frozen = true }
    end
    return { sod = (localClock()), frozen = false }
end

local function broadcastTime()
    TriggerClientEvent('u8_weatherSync:time', -1, timePacket())
end

-- ══════════════════════════════════════════════════════════════════════════
--  IDŐJÁRÁS
-- ══════════════════════════════════════════════════════════════════════════

local RAINY = { RAIN = true, THUNDER = true, CLEARING = true }

local SNOW_TYPES = { SNOW = true, BLIZZARD = true, SNOWLIGHT = true, XMAS = true }

--- Téli időszak (helyi időben, [Start, End) – az évforduló átfordulását is kezeli).
local function seasonActive()
    local S = Cfg.Snow
    if not S or not S.Enabled then return false end

    local utc = os.time()
    local t = os.date('!*t', utc + utcOffset(utc))
    local md = t.month * 100 + t.day
    local s = S.Season.Start.Month * 100 + S.Season.Start.Day
    local e = S.Season.End.Month * 100 + S.Season.End.Day

    if s <= e then return md >= s and md < e end
    return md >= s or md < e
end

--- Csak ha Config.Snow.Fall.Enabled: télen a valós típust havazásra cseréljük.
local function seasonalType(t)
    local F = Cfg.Snow.Fall
    if t == 'THUNDER' then return F.Heavy end
    if t == 'RAIN' then return F.Precip end
    return F.Calm
end

local function activeWeather()
    if State.weather.mode == 'manual' then return State.weather.manual end

    local live = State.weather.live
    if Cfg.Snow.Fall.Enabled and seasonActive() then
        return { type = seasonalType(live.type), rain = nil, ws = live.ws, wd = live.wd }
    end
    return live
end

--- Van-e hó a talajon: télen mindig, egyébként ha a típus havas.
local function snowGround(w)
    return seasonActive() or SNOW_TYPES[w.type] == true
end

local function weatherPacket(instant, manual)
    local w = activeWeather()
    return {
        type       = w.type,
        rain       = w.rain,
        ws         = w.ws or 0.0,
        wd         = w.wd or 0.0,
        snow       = snowGround(w),
        instant    = instant or false,
        transition = manual and WCfg.ManualTransition or WCfg.Transition,
    }
end

local function broadcastWeather(manual)
    TriggerClientEvent('u8_weatherSync:weather', -1, weatherPacket(false, manual))
end

-- ── Felhőzet ──────────────────────────────────────────────────────────────

local cloud = nil  -- nil = reset (alaphelyzet)

local function cloudPacket()
    return { name = cloud, transition = Cfg.Clouds.Transition }
end

local function broadcastCloud()
    TriggerClientEvent('u8_weatherSync:cloud', -1, cloudPacket())
end

--- Új felhő sorsolása: nem ismétli az előzőt.
local function rotateCloud()
    local list = Cfg.Clouds.List
    if #list == 0 then return end

    local pick
    repeat pick = list[math.random(#list)] until pick ~= cloud or #list == 1
    cloud = pick
    debug('cloud -> ' .. pick)
    broadcastCloud()
end

--- WMO kód + mért adatok → GTA állapot. A bemenetet nem tekintjük megbízhatónak.
local function mapWeather(cur)
    local code  = math.tointeger(cur.weather_code)
    local cloud = tonumber(cur.cloud_cover) or 0
    local mm    = clamp(tonumber(cur.precipitation) or 0, 0, 100)
    local day   = cur.is_day == 1

    local gta = code and WCfg.CodeMap[code] or nil
    if not gta then return nil end

    if gta == 'CLEAR' and day and cloud <= WCfg.SunnyMaxCloud then
        gta = 'EXTRASUNNY'
    end
    if not WCfg.Snow and (gta == 'SNOW' or gta == 'BLIZZARD' or gta == 'SNOWLIGHT' or gta == 'XMAS') then
        gta = 'OVERCAST'
    end

    local rain
    if RAINY[gta] then
        local r = WCfg.Rain
        rain = clamp(r.Base + mm * r.PerMm, 0.0, r.Max)
    end

    local ws, wd = 0.0, 0.0
    if WCfg.Wind.Enabled then
        ws = clamp((tonumber(cur.wind_speed_10m) or 0) / 3.6, 0.0, WCfg.Wind.MaxSpeed) -- km/h → m/s
        wd = math.rad((tonumber(cur.wind_direction_10m) or 0) % 360)
    end

    return { type = gta, rain = rain, ws = ws, wd = wd }
end

local function urlEncode(s)
    return (s:gsub('[^%w%-_%.~]', function(c) return ('%%%02X'):format(c:byte()) end))
end

local failStreak = 0

local function fetchWeather()
    local url = ('https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f'
        .. '&current=temperature_2m,is_day,precipitation,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m'
        .. '&wind_speed_unit=kmh&timezone=%s'):format(WCfg.Latitude, WCfg.Longitude, urlEncode(TZ.Name))

    PerformHttpRequest(url, function(status, body)
        local ok, data = pcall(json.decode, body or '')
        if status ~= 200 or not ok or type(data) ~= 'table' or type(data.current) ~= 'table' then
            failStreak = failStreak + 1
            -- Csak az első és minden tizedik hibát írjuk ki, hogy ne spameljen.
            if failStreak == 1 or failStreak % 10 == 0 then
                log('warn', _L('api_fail', tostring(status)))
            end
            return
        end

        local mapped = mapWeather(data.current)
        if not mapped then
            log('warn', _L('api_fail', 'weather_code ' .. tostring(data.current.weather_code)))
            return
        end
        failStreak = 0

        local off = math.tointeger(data.utc_offset_seconds)
        if off and off >= -14 * 3600 and off <= 14 * 3600 then State.apiOffset = off end
        State.temp = tonumber(data.current.temperature_2m)

        local old = activeWeather()
        State.weather.live = mapped
        local new = activeWeather()

        local changed = old.type ~= new.type
            or math.abs((old.rain or -1) - (new.rain or -1)) > 0.05
            or math.abs((old.ws or 0) - new.ws) > 1.0

        debug(_L('api_ok', mapped.type, tostring(State.temp), tostring(mapped.rain)))

        if changed and State.weather.mode == 'live' then
            broadcastWeather(false)
        end
    end, 'GET', '', { ['Accept'] = 'application/json' })
end

-- ══════════════════════════════════════════════════════════════════════════
--  Kliens kérések (az egyetlen net event)
-- ══════════════════════════════════════════════════════════════════════════

local lastReady = {}
local notify, snowNow -- lent, a hógolyó résznél kapnak értéket

RegisterNetEvent('u8_weatherSync:ready', function()
    local src = source
    local now = GetGameTimer()
    if lastReady[src] and now - lastReady[src] < 10000 then return end
    lastReady[src] = now

    TriggerClientEvent('u8_weatherSync:time', src, timePacket())
    TriggerClientEvent('u8_weatherSync:weather', src, weatherPacket(true))
    if Cfg.Clouds.Enabled then
        TriggerClientEvent('u8_weatherSync:cloud', src, { name = cloud, transition = 0 })
    end

    if Cfg.Snow.Gather.Enabled and snowNow() then
        notify(src, 'snow_hint', Cfg.Snow.Gather.Key)
    end

    if IsPlayerAceAllowed(src, Cfg.Ace) then
        local types = table.concat(Cfg.ManualWeatherTypes, '|')
        TriggerClientEvent('chat:addSuggestion', src, '/' .. Cfg.Commands.Weather, 'Időjárás / Weather',
            { { name = 'típus|live', help = types:lower() } })
        TriggerClientEvent('chat:addSuggestion', src, '/' .. Cfg.Commands.Time, 'Idő / Time',
            { { name = 'ÓÓ:PP|live', help = 'pl. 21:30' } })
    end
end)

-- ══════════════════════════════════════════════════════════════════════════
--  Hógolyó gyúrás
-- ══════════════════════════════════════════════════════════════════════════
--
--  Két lépés, mind a kettőt a szerver ellenőrzi: `gather` (kezdés) →
--  animáció a kliensen → `gatherDone` (a szerver méri az eltelt időt és a
--  távolságot). A kliens csak kérhet, a hógolyót a szerver adja.

local SNOWBALL = Cfg.Snow.Gather.Item
local busy     = {}   -- [src] = { at, pos }
local cooldown = {}   -- [src] = GetGameTimer() lejárat

function notify(src, key, ...)
    TriggerClientEvent('u8_weatherSync:notify', src, _L(key, ...))
end

local function hasInventory()
    return GetResourceState('ox_inventory') == 'started'
end

--- Inventory módban kerül-e az inventoryba (ox_inventory nélkül kézbe adjuk).
local function inventoryMode()
    return Cfg.Snow.Gather.Mode == 'inventory' and hasInventory()
end

--- Hány hógolyó van nála. Kéz módban legfeljebb 1: ha éppen a kezében van, már van.
local function carried(src)
    if not inventoryMode() then
        local ped = GetPlayerPed(src)
        return (ped and ped ~= 0 and GetSelectedPedWeapon(ped) == joaat(SNOWBALL)) and 1 or 0
    end
    local ok, count = pcall(function() return exports.ox_inventory:GetItemCount(src, SNOWBALL) end)
    return ok and tonumber(count) or 0
end

function snowNow()
    return snowGround(activeWeather())
end

--- Közös ellenőrzés: kezdéskor és befejezéskor is lefut.
---@return boolean ok, integer? ped
local function canGather(src)
    local G = Cfg.Snow.Gather
    if not G.Enabled or not snowNow() then return false end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false end
    if GetEntityHealth(ped) <= 105 then return false end -- halott/ájult

    return true, ped
end

RegisterNetEvent('u8_weatherSync:gather', function()
    local src = source
    local G = Cfg.Snow.Gather
    local now = GetGameTimer()

    if busy[src] and now - busy[src].at < G.Duration + 5000 then return end
    if cooldown[src] and now < cooldown[src] then return end

    local ok, ped = canGather(src)
    if not ok then return end

    local limit = inventoryMode() and G.MaxCarry or 1
    if carried(src) + (inventoryMode() and G.Amount or 1) > limit then
        cooldown[src] = now + 1500
        return notify(src, 'gather_full')
    end

    busy[src] = { at = now, pos = GetEntityCoords(ped) }
    TriggerClientEvent('u8_weatherSync:gatherBegin', src, G.Duration)
end)

RegisterNetEvent('u8_weatherSync:gatherDone', function()
    local src = source
    local G = Cfg.Snow.Gather
    local job = busy[src]
    busy[src] = nil
    if not job then return end

    local now = GetGameTimer()
    -- Nem érkezhet hamarabb, mint az animáció hossza (kis hálózati ráhagyás).
    if now - job.at < G.Duration - 400 then return end

    local ok, ped = canGather(src)
    if not ok then return end
    -- Gyúrás közben nem sétálhatott el.
    if #(GetEntityCoords(ped) - job.pos) > 3.0 then return end

    cooldown[src] = now + G.Cooldown

    if not inventoryMode() then
        -- Kéz mód: a kliens azonnal a kezébe veszi, az inventoryba nem kerül.
        if carried(src) >= 1 then return notify(src, 'gather_full') end
        TriggerClientEvent('u8_weatherSync:giveHand', src, SNOWBALL)
        return notify(src, 'gather_done', 1)
    end

    local amount = math.min(G.Amount, math.max(0, G.MaxCarry - carried(src)))
    if amount <= 0 then return notify(src, 'gather_full') end

    local can = exports.ox_inventory:CanCarryItem(src, SNOWBALL, amount)
    if not can then return notify(src, 'gather_full') end
    local given = exports.ox_inventory:AddItem(src, SNOWBALL, amount) and true or false

    if given then notify(src, 'gather_done', amount) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastReady[src], busy[src], cooldown[src] = nil, nil, nil
end)

-- ══════════════════════════════════════════════════════════════════════════
--  Admin parancsok
-- ══════════════════════════════════════════════════════════════════════════

local function reply(src, msg)
    if src == 0 then
        log('info', msg)
    else
        TriggerClientEvent('chat:addMessage', src, { color = { 120, 200, 255 }, args = { 'u8_weatherSync', msg } })
    end
end

local function allowed(src)
    return src == 0 or IsPlayerAceAllowed(src, Cfg.Ace)
end

local function who(src)
    return src == 0 and 'console' or ('%s [%d]'):format(GetPlayerName(src) or '?', src)
end

RegisterCommand(Cfg.Commands.Weather, function(src, args)
    if not allowed(src) then return reply(src, _L('no_permission')) end

    local arg = args[1] and args[1]:lower()
    if not arg then
        local w = activeWeather()
        local mode = _L(State.weather.mode == 'manual' and 'mode_manual' or 'mode_live')
        reply(src, _L('status_weather', w.type, mode))
        if State.temp then reply(src, _L('temp', ('%.1f'):format(State.temp))) end
        return reply(src, _L('usage_weather', Cfg.Commands.Weather, table.concat(Cfg.ManualWeatherTypes, ', '):lower()))
    end

    if arg == 'live' then
        State.weather.mode, State.weather.manual = 'live', nil
        broadcastWeather(true)
        log('info', ('%s -> weather live'):format(who(src)))
        return reply(src, _L('weather_live'))
    end

    local wtype = arg:upper()
    if not validManual[wtype] then
        return reply(src, _L('usage_weather', Cfg.Commands.Weather, table.concat(Cfg.ManualWeatherTypes, ', '):lower()))
    end

    State.weather.mode = 'manual'
    State.weather.manual = { type = wtype, rain = nil, ws = 0.0, wd = 0.0 }
    broadcastWeather(true)
    log('info', ('%s -> weather %s'):format(who(src), wtype))
    reply(src, _L('weather_set', wtype, Cfg.Commands.Weather))
end, false)

RegisterCommand(Cfg.Commands.Time, function(src, args)
    if not allowed(src) then return reply(src, _L('no_permission')) end

    local arg = args[1] and args[1]:lower()
    if not arg then
        local mode = _L(State.time.mode == 'manual' and 'mode_manual' or 'mode_live')
        local sod = State.time.mode == 'manual' and State.time.fixed or (localClock())
        reply(src, _L('status_time', ('%02d:%02d'):format(sod // 3600, (sod % 3600) // 60), mode))
        return reply(src, _L('usage_time', Cfg.Commands.Time))
    end

    if arg == 'live' then
        State.time.mode = 'live'
        broadcastTime()
        log('info', ('%s -> time live'):format(who(src)))
        return reply(src, _L('time_live'))
    end

    local h, m = arg:match('^(%d%d?):(%d%d?)$')
    if not h then h = arg:match('^(%d%d?)$'); m = h and '0' end
    h, m = tonumber(h), tonumber(m)
    if not h or h > 23 or m > 59 then
        return reply(src, _L('usage_time', Cfg.Commands.Time))
    end

    State.time.mode, State.time.fixed = 'manual', h * 3600 + m * 60
    broadcastTime()
    local text = ('%02d:%02d'):format(h, m)
    log('info', ('%s -> time %s'):format(who(src), text))
    reply(src, _L('time_set', text, Cfg.Commands.Time))
end, false)

-- ══════════════════════════════════════════════════════════════════════════
--  Exportok (más szerver scriptekhez, csak olvasás)
-- ══════════════════════════════════════════════════════════════════════════

exports('GetWeather', function() return activeWeather().type end)
exports('GetTime', function()
    local sod = State.time.mode == 'manual' and State.time.fixed or (localClock())
    return sod // 3600, (sod % 3600) // 60
end)

-- ══════════════════════════════════════════════════════════════════════════
--  Szálak
-- ══════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════
--  Verziófigyelő
-- ══════════════════════════════════════════════════════════════════════════

local function parseVersion(v)
    local a, b, c = tostring(v or ''):match('^v?(%d+)%.(%d+)%.?(%d*)')
    if not a then return nil end
    return { tonumber(a), tonumber(b), tonumber(c) or 0 }
end

local function isNewer(remote, current)
    for i = 1, 3 do
        if remote[i] ~= current[i] then return remote[i] > current[i] end
    end
    return false
end

local function checkVersion()
    local current = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '0.0.0'
    log('info', _L('ver_running', current))

    local vc = Cfg.VersionCheck
    if not vc or not vc.Enabled then return end

    local repo = tostring(vc.Repository or '')
    if not repo:match('^[%w%-_%.]+/[%w%-_%.]+$') then
        return log('warn', _L('ver_failed', 'Repository'))
    end

    PerformHttpRequest(('https://api.github.com/repos/%s/releases/latest'):format(repo), function(status, body)
        local ok, data = pcall(json.decode, body or '')
        if status ~= 200 or not ok or type(data) ~= 'table' then
            -- 404 = még nincs release; ez nem hiba, csak nincs mit összehasonlítani.
            if status == 404 then return end
            return log('warn', _L('ver_failed', tostring(status)))
        end

        local remote, cur = parseVersion(data.tag_name), parseVersion(current)
        if not remote or not cur then return log('warn', _L('ver_failed', 'tag')) end

        if isNewer(remote, cur) then
            log('warn', _L('ver_outdated', table.concat(remote, '.'), current))
            -- Csak GitHub linket írunk ki, mást nem.
            local url = type(data.html_url) == 'string' and data.html_url:match('^https://github%.com/[%w%-_%./]+$')
            if url then log('warn', _L('ver_download', url)) end
        else
            log('info', _L('ver_latest', current))
        end
    end, 'GET', '', { ['Accept'] = 'application/vnd.github+json', ['User-Agent'] = 'u8_weatherSync' })
end

CreateThread(function()
    log('info', _L('started', TZ.Name, tostring(math.max(300, WCfg.UpdateInterval))))
    checkVersion()
    while true do
        fetchWeather()
        Wait(math.max(300, WCfg.UpdateInterval) * 1000)
    end
end)

if Cfg.Clouds.Enabled then
    math.randomseed(os.time())
    CreateThread(function()
        while true do
            Wait(math.max(1, Cfg.Clouds.Interval) * 60000)
            rotateCloud()
        end
    end)
end

CreateThread(function()
    local wasSeason = seasonActive()
    while true do
        Wait(math.max(10, Cfg.Time.SyncInterval) * 1000)
        broadcastTime()

        -- A tél kezdete/vége: az időszak határán (00:00) mindenkinek kimegy az új állapot.
        local season = seasonActive()
        if season ~= wasSeason then
            wasSeason = season
            if State.weather.mode == 'live' then broadcastWeather(false) end
            notify(-1, season and 'snow_start' or 'snow_end')
            log('info', _L(season and 'snow_start' or 'snow_end'))
        end
    end
end)
