-- Registers custom prop models from config_custom_models.lua without editing the vanilla lists.

local function IsEnabled()
    return Config and Config.CustomPropModels and Config.CustomPropModels.enabled ~= false
end

local function CopyTable(src)
    local t = {}
    if type(src) ~= 'table' then return t end
    for k, v in pairs(src) do t[k] = v end
    return t
end

local function MergeTables(base, override)
    local t = CopyTable(base)
    if type(override) == 'table' then
        for k, v in pairs(override) do
            if k ~= 'seats' then t[k] = v end
        end
    end
    return t
end

local function NormalizeCustomEntry(entry, defaults)
    local t = CopyTable(defaults)

    if type(entry) == 'string' then
        t.model = entry
    elseif type(entry) == 'table' then
        for k, v in pairs(entry) do
            if k ~= 'seats' then t[k] = v end
        end
    end

    if not t.model or t.model == '' then
        return nil
    end

    t.radius  = tonumber(t.radius)  or tonumber(defaults and defaults.radius)  or 1.5
    t.x       = tonumber(t.x)       or tonumber(defaults and defaults.x)       or 0.0
    t.y       = tonumber(t.y)       or tonumber(defaults and defaults.y)       or 0.0
    t.z       = tonumber(t.z)       or tonumber(defaults and defaults.z)       or 0.5
    t.heading = tonumber(t.heading) or tonumber(defaults and defaults.heading) or 180.0

    return t
end

local function AddCustomInteraction(category, entry, defaults, payload)
    local cfg = NormalizeCustomEntry(entry, defaults)
    if not cfg then return end

    local interaction = {
        category     = category,
        isCompatible = cfg.isCompatible or payload.isCompatible,
        objects      = { cfg.model },
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

    Interactions[#Interactions + 1] = interaction
end

local function AddCustomList(category, list, defaults, payload)
    if type(list) ~= 'table' then return end

    for i = 1, #list do
        local entry = list[i]

        if type(entry) == 'table' and type(entry.seats) == 'table' then
            for seatIndex = 1, #entry.seats do
                local seatEntry = MergeTables(entry, entry.seats[seatIndex])
                AddCustomInteraction(category, seatEntry, defaults, payload)
            end
        else
            AddCustomInteraction(category, entry, defaults, payload)
        end
    end
end

local function RegisterCustomPropModels()
    if not IsEnabled() then return end
    if type(Interactions) ~= 'table' then return end

    local custom = Config.CustomPropModels or {}

    AddCustomList('chair', custom.chairs, {
        radius = 1.5,
        x = 0.0, y = 0.0, z = 0.5, heading = 180.0,
    }, {
        isCompatible = IsPedAdult,
        scenarios    = GenericChairAndBenchScenarios,
    })

    AddCustomList('bench', custom.benches, {
        radius = 2.0,
        x = 0.5, y = 0.0, z = 0.5, heading = 180.0,
    }, {
        isCompatible = IsPedHuman,
        scenarios    = GenericChairAndBenchScenarios,
    })

    AddCustomList('bed', custom.beds, {
        radius = 2.0,
        x = 0.0, y = 0.0, z = 0.5, heading = 180.0,
    }, {
        isCompatible = IsPedHuman,
        scenarios    = BedScenarios,
    })

    AddCustomList('bath', custom.baths, {
        radius = 2.0,
        x = -0.5, y = 0.0, z = 0.65, heading = 270.0,
    }, {
        isCompatible = IsPedHuman,
        animations   = BathingAnimations,
        effect       = 'clean',
    })

    AddCustomList('piano', custom.pianos, {
        radius = 2.0,
        x = 0.0, y = -0.75, z = 0.5, heading = 0.0,
    }, {
        isCompatible = IsPedHuman,
        scenarios = {
            { name = 'PROP_HUMAN_PIANO',         isCompatible = IsPedHumanMale },
            { name = 'PROP_HUMAN_ABIGAIL_PIANO', isCompatible = IsPedHumanFemale },
        },
    })

    AddCustomList('misc', custom.misc, {
        radius = 1.5,
        x = 0.0, y = 0.0, z = 0.5, heading = 180.0,
    }, {
        isCompatible = IsPedHuman,
    })
end

RegisterCustomPropModels()
