--[[
    u8_weatherSync — Kliens
    ─────────────────────────────────────────────────────────────────────────
    Csak a szervertől kapott állapotot jeleníti meg. Nem tartalmaz titkot
    konfigurációt, és semmit nem küld vissza a szervernek, azon kívül, hogy
    induláskor állapotot kér. Egy csaló legfeljebb a saját képernyőjét
    állíthatja át, másokét nem.

    Teljesítmény: nincs képkockánkénti ciklus. Az óra-ellenőrzés 10
    másodpercenként fut, az átmenet-szál csak váltás közben él (0,5 mp-es
    lépésekkel).
]]

-- Csak ezeket a típusokat fogadjuk el (a szerver is ellenőrzi).
local VALID = {
    EXTRASUNNY = true, CLEAR = true, CLOUDS = true, SMOG = true, FOGGY = true,
    OVERCAST = true, RAIN = true, THUNDER = true, CLEARING = true,
    NEUTRAL = true, SNOW = true, BLIZZARD = true, SNOWLIGHT = true,
    XMAS = true, HALLOWEEN = true,
}

local MS_PER_MIN  = 60000       -- 1 játékperc = 1 valós perc
local MS_FROZEN   = 2000000000  -- gyakorlatilag álló óra (fix idő)
local DRIFT_LIMIT = 2           -- mp

-- ══════════════════════════════════════════════════════════════════════════
--  IDŐ
-- ══════════════════════════════════════════════════════════════════════════

local clock = { sod = nil, at = 0, frozen = false }

local function expectedSecond()
    if clock.frozen then return clock.sod end
    return (clock.sod + (GetGameTimer() - clock.at) // 1000) % 86400
end

local function setClock(sod)
    NetworkOverrideClockTime(sod // 3600, (sod % 3600) // 60, sod % 60)
end

RegisterNetEvent('u8_weatherSync:time', function(p)
    if type(p) ~= 'table' or math.type(p.sod) ~= 'integer' or p.sod < 0 or p.sod >= 86400 then return end

    clock.sod, clock.at, clock.frozen = p.sod, GetGameTimer(), p.frozen == true
    NetworkOverrideClockMillisecondsPerGameMinute(clock.frozen and MS_FROZEN or MS_PER_MIN)
    setClock(p.sod)
end)

-- Drift-őr: ha más script elállítaná az órát, visszaigazítjuk.
CreateThread(function()
    while true do
        Wait(10000)
        if clock.sod then
            local now = GetClockHours() * 3600 + GetClockMinutes() * 60 + GetClockSeconds()
            local diff = math.abs(now - expectedSecond())
            if math.min(diff, 86400 - diff) > DRIFT_LIMIT then
                setClock(expectedSecond())
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════════════
--  HÓ: talaj, nyomok, csúszás
-- ══════════════════════════════════════════════════════════════════════════

local SCfg   = Config.Snow
local snowOn = false

local VEHICLE_GRIP_FIELDS = { 'fTractionCurveMax', 'fTractionCurveMin' }
local gripOriginal = {}   -- [vehicle] = { [field] = eredeti érték }

local function restoreGrip(veh)
    local orig = gripOriginal[veh]
    gripOriginal[veh] = nil
    if not orig or not DoesEntityExist(veh) then return end
    for field, value in pairs(orig) do
        SetVehicleHandlingFloat(veh, 'CHandlingData', field, value)
    end
end

local function reduceGrip(veh)
    if gripOriginal[veh] then return end
    local orig = {}
    for _, field in ipairs(VEHICLE_GRIP_FIELDS) do
        local value = GetVehicleHandlingFloat(veh, 'CHandlingData', field)
        orig[field] = value
        SetVehicleHandlingFloat(veh, 'CHandlingData', field, value * SCfg.Slippery.Strength)
    end
    gripOriginal[veh] = orig
end

--- Csúszós út: csak a saját vezetett járművet érinti, és csak hóban fut.
local function slipperyLoop()
    local last = 0
    while snowOn do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= last then
            if last ~= 0 then restoreGrip(last) end
            last = 0
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                local model = GetEntityModel(veh)
                if IsThisModelACar(model) or IsThisModelABike(model) or IsThisModelAQuadbike(model) then
                    reduceGrip(veh)
                    last = veh
                end
            end
        end
        Wait(1000)
    end

    for veh in pairs(gripOriginal) do restoreGrip(veh) end
end

-- Újabb/átnevezett natívok: ha az adott build nem ismeri, kihagyjuk, nem hibázunk.
local function optionalNative(name, ...)
    local fn = _G[name]
    if fn then fn(...) end
end

local function setSnow(on)
    if on == snowOn then return end
    snowOn = on

    ForceSnowPass(on)
    SetForcePedFootstepsTracks(on and SCfg.Footprints or false)
    SetForceVehicleTrails(on and SCfg.VehicleTracks or false)

    -- Hó-részecskék a lábnál/keréknél (ahogy a Menyoo EnableTracks is teszi).
    optionalNative('UseSnowFootVfxWhenUnsheltered', on and SCfg.Footprints or false)
    optionalNative('UseSnowWheelVfxWhenUnsheltered', on and SCfg.VehicleTracks or false)

    if on then
        RequestNamedPtfxAsset('core_snow')
        optionalNative('UseParticleFxAsset', 'core_snow')
        -- Ropogó hang.
        RequestScriptAudioBank('ICE_FOOTSTEPS', false)
        RequestScriptAudioBank('SNOW_FOOTSTEPS', false)
        if SCfg.Slippery.Enabled then CreateThread(slipperyLoop) end
    else
        RemoveNamedPtfxAsset('core_snow')
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for veh in pairs(gripOriginal) do restoreGrip(veh) end
    UnloadAllCloudHats()
    ForceSnowPass(false)
    optionalNative('UseSnowFootVfxWhenUnsheltered', false)
    optionalNative('UseSnowWheelVfxWhenUnsheltered', false)
    SetForcePedFootstepsTracks(false)
    SetForceVehicleTrails(false)
end)

-- ══════════════════════════════════════════════════════════════════════════
--  Hógolyó gyúrás (gombnyomásra, ciklus nélkül)
-- ══════════════════════════════════════════════════════════════════════════

local gathering = false

local function notify(text)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, false)
end

RegisterNetEvent('u8_weatherSync:notify', function(text)
    if type(text) == 'string' and #text <= 200 then notify(text) end
end)

RegisterCommand('u8_weatherSync_gather', function()
    if gathering or not snowOn or not SCfg.Gather.Enabled then return end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, true) or IsPedRagdoll(ped) or IsPedSwimming(ped)
        or IsEntityDead(ped) or IsPedFalling(ped) or IsPedInCover(ped, false)
        or IsPlayerFreeAiming(PlayerId()) then
        return
    end

    TriggerServerEvent('u8_weatherSync:gather')
end, false)

RegisterKeyMapping('u8_weatherSync_gather', 'Hógolyó gyúrása / Make a snowball', 'keyboard', SCfg.Gather.Key)

-- Kéz mód: a hógolyó azonnal a kezében van, az inventoryba nem kerül.
RegisterNetEvent('u8_weatherSync:giveHand', function(item)
    if item ~= Config.Snow.Gather.Item then return end

    local ped = PlayerPedId()
    local hash = joaat(item)
    if GetAmmoInPedWeapon(ped, hash) >= 1 then return end

    GiveWeaponToPed(ped, hash, 1, false, true)
    SetCurrentPedWeapon(ped, hash, true)
end)

RegisterNetEvent('u8_weatherSync:gatherBegin', function(duration)
    if gathering or math.type(duration) ~= 'integer' or duration < 500 or duration > 15000 then return end
    gathering = true

    local ped = PlayerPedId()
    local dict, clip = 'anim@mp_snowball', 'pickup_snowball'
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end

    local start = GetEntityCoords(ped)
    TaskPlayAnim(ped, dict, clip, 4.0, -4.0, duration, 0, 0.0, false, false, false)

    local untilMs = GetGameTimer() + duration
    local ok = true
    while GetGameTimer() < untilMs do
        Wait(100)
        ped = PlayerPedId()
        -- Megszakad, ha elesik, elindul, járműbe ül, vagy elhagyja a helyet.
        if IsPedRagdoll(ped) or IsEntityDead(ped) or IsPedInAnyVehicle(ped, true)
            or #(GetEntityCoords(ped) - start) > 1.5 or not snowOn then
            ok = false
            break
        end
    end

    ClearPedTasks(ped)
    RemoveAnimDict(dict)
    gathering = false
    if ok then TriggerServerEvent('u8_weatherSync:gatherDone') end
end)

-- ══════════════════════════════════════════════════════════════════════════
--  IDŐJÁRÁS
-- ══════════════════════════════════════════════════════════════════════════

local current = nil      -- { type, rain, ws, wd } – amit éppen mutatunk
local token   = 0        -- új váltás érvényteleníti a futó átmenetet

local function lerp(a, b, t) return a + (b - a) * t end

local function lerpAngle(a, b, t)
    local d = (b - a + math.pi) % (2 * math.pi) - math.pi
    return a + d * t
end

local function applyRain(v)
    SetRainLevel(v and v + 0.0 or -1.0)
end

local function applyWind(speed, dir)
    SetWindSpeed(speed + 0.0)
    SetWindDirection(dir + 0.0)
end

local function snapType(t)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypePersist(t)
    SetWeatherTypeNow(t)
    SetWeatherTypeNowPersist(t)
end

local function applyWeather(p)
    setSnow(p.snow)
    token = token + 1
    local my = token
    local from = current

    -- Azonnali beállítás: első betöltés vagy 0 mp-es átmenet.
    if not from or p.instant or p.transition <= 0 then
        snapType(p.type)
        applyRain(p.rain)
        applyWind(p.ws, p.wd)
        current = { type = p.type, rain = p.rain, ws = p.ws, wd = p.wd }
        return
    end

    local secs = p.transition
    if from.type ~= p.type then
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        SetWeatherTypeOvertimePersist(p.type, secs + 0.0)
    end

    -- Eső és szél finom átmenete (csak amíg a váltás tart).
    CreateThread(function()
        local startMs = GetGameTimer()
        local total = secs * 1000
        while true do
            if token ~= my then return end
            local t = math.min(1.0, (GetGameTimer() - startMs) / total)
            local rain = from.rain and p.rain and lerp(from.rain, p.rain, t) or nil
            -- Ha valamelyik oldalon nincs saját esőszint, a motor értékét
            -- használjuk, azt a végén váltjuk át.
            if rain then applyRain(rain) end
            applyWind(lerp(from.ws, p.ws, t), lerpAngle(from.wd, p.wd, t))
            if t >= 1.0 then break end
            Wait(500)
        end

        if token ~= my then return end
        snapType(p.type)
        applyRain(p.rain)
        applyWind(p.ws, p.wd)
        current = { type = p.type, rain = p.rain, ws = p.ws, wd = p.wd }
    end)
end

RegisterNetEvent('u8_weatherSync:weather', function(p)
    if type(p) ~= 'table' or not VALID[p.type] then return end
    if type(p.ws) ~= 'number' or type(p.wd) ~= 'number' or type(p.transition) ~= 'number' then return end
    if p.rain ~= nil and type(p.rain) ~= 'number' then return end

    p.ws = math.max(0.0, math.min(12.0, p.ws))
    p.rain = p.rain and math.max(0.0, math.min(0.5, p.rain)) or nil
    p.transition = math.max(0, math.min(600, p.transition))
    p.instant = p.instant == true
    p.snow = p.snow == true

    applyWeather(p)
end)

-- ══════════════════════════════════════════════════════════════════════════
--  FELHŐZET
-- ══════════════════════════════════════════════════════════════════════════

local allowedClouds = {}
for _, name in ipairs(Config.Clouds.List) do allowedClouds[name] = true end

local cloudNow = nil

RegisterNetEvent('u8_weatherSync:cloud', function(p)
    if type(p) ~= 'table' or type(p.transition) ~= 'number' then return end
    if p.name ~= nil and not allowedClouds[p.name] then return end
    local t = math.max(0.0, math.min(300.0, p.transition)) + 0.0

    local old = cloudNow
    cloudNow = p.name
    if old == cloudNow then return end

    if cloudNow then
        -- Az új felhő lassan megjelenik, a régi ugyanennyi idő alatt eltűnik.
        LoadCloudHat(cloudNow, t)
        if old then UnloadCloudHat(old, t) end
    else
        UnloadAllCloudHats()
    end
end)

-- ══════════════════════════════════════════════════════════════════════════
--  Indulás: állapot kérése
-- ══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    TriggerServerEvent('u8_weatherSync:ready')
end)
