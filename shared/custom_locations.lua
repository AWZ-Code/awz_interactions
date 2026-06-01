-- Registers fixed-position interactions from config_custom_locations.lua.

local function IsEnabled()
    return Config and Config.CustomLocations and Config.CustomLocations.enabled ~= false
end

local function ReadCoords(entry)
    if type(entry) ~= 'table' then return nil end

    if entry.coords then
        return entry.coords.x, entry.coords.y, entry.coords.z
    end

    if entry.x and entry.y and entry.z then
        return entry.x, entry.y, entry.z
    end

    return nil
end

local function NormalizeLocationEntry(entry, defaults)
    if type(entry) ~= 'table' then return nil end

    local x, y, z = ReadCoords(entry)
    if not x or not y or not z then return nil end

    local t = {}
    for k, v in pairs(defaults or {}) do t[k] = v end
    for k, v in pairs(entry) do t[k] = v end

    t.x       = tonumber(x)
    t.y       = tonumber(y)
    t.z       = tonumber(z)
    t.radius  = tonumber(t.radius) or tonumber(defaults and defaults.radius) or 2.0
    t.heading = tonumber(t.heading) or tonumber(defaults and defaults.heading) or 180.0

    return t
end

local function AddLocationInteraction(category, entry, defaults, payload)
    local cfg = NormalizeLocationEntry(entry, defaults)
    if not cfg then return end

    Interactions[#Interactions + 1] = {
        category     = category,
        isCompatible = cfg.isCompatible or payload.isCompatible,
        radius       = cfg.radius,
        label        = cfg.label,
        scenarios    = cfg.scenarios or payload.scenarios,
        animations   = cfg.animations or payload.animations,
        effect       = cfg.effect or payload.effect,
        effectPhase   = cfg.effectPhase or payload.effectPhase,
        x            = cfg.x,
        y            = cfg.y,
        z            = cfg.z,
        heading      = cfg.heading,
    }
end

local function AddLocationList(category, list, defaults, payload)
    if type(list) ~= 'table' then return end

    for i = 1, #list do
        AddLocationInteraction(category, list[i], defaults, payload)
    end
end

local function RegisterCustomLocations()
    if not IsEnabled() then return end
    if type(Interactions) ~= 'table' then return end

    local custom = Config.CustomLocations or {}

    AddLocationList('chair', custom.chairs, {
        radius = 1.5,
        heading = 180.0,
    }, {
        isCompatible = IsPedAdult,
        scenarios    = GenericChairAndBenchScenarios,
    })

    AddLocationList('bench', custom.benches, {
        radius = 2.0,
        heading = 180.0,
    }, {
        isCompatible = IsPedHuman,
        scenarios    = GenericChairAndBenchScenarios,
    })

    AddLocationList('bed', custom.beds, {
        radius = 2.0,
        heading = 180.0,
    }, {
        isCompatible = IsPedHuman,
        scenarios    = BedScenarios,
    })

    AddLocationList('bath', custom.baths, {
        radius = 2.0,
        heading = 270.0,
    }, {
        isCompatible = IsPedHuman,
        animations   = BathingAnimations,
        effect       = 'clean',
    })

    AddLocationList('piano', custom.pianos, {
        radius = 2.0,
        heading = 0.0,
    }, {
        isCompatible = IsPedHuman,
        scenarios = {
            { name = 'PROP_HUMAN_PIANO',         isCompatible = IsPedHumanMale },
            { name = 'PROP_HUMAN_ABIGAIL_PIANO', isCompatible = IsPedHumanFemale },
        },
    })
end

RegisterCustomLocations()
