function IsPedChild(ped)
    return Citizen.InvokeNative(0x137772000DAF42C5, ped)
end

function IsPedAdult(ped)
    return IsPedHuman(ped) and not IsPedChild(ped)
end

function IsPedHumanMale(ped)
    return IsPedHuman(ped) and IsPedMale(ped)
end

function IsPedHumanFemale(ped)
    return IsPedHuman(ped) and not IsPedMale(ped)
end

function IsPedAdultMale(ped)
    return not IsPedChild(ped) and IsPedMale(ped)
end

function IsPedAdultFemale(ped)
    return not IsPedChild(ped) and not IsPedMale(ped)
end

function IsPedUsingScenarioHash(ped, scenarioHash)
    return Citizen.InvokeNative(0x34D6AC1157C8226C, ped, scenarioHash)
end

function DrawInteractionMarker(type, x, y, z, color)
    Citizen.InvokeNative(
        0x2A32FAA57B937173,
        type,
        x, y, z,
        0, 0, 0,
        0, 0, 0,
        1.0, 1.0, 1.0,
        color.r, color.g, color.b, color.a,
        false, false, 2, false, 0, 0, false
    )
end

function LoadAnimDict(dict, timeoutMs)
    if not DoesAnimDictExist(dict) then
        return false
    end
    if HasAnimDictLoaded(dict) then
        return true
    end

    RequestAnimDict(dict)

    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Citizen.Wait(10)
    end

    return HasAnimDictLoaded(dict)
end

function HumanizeName(raw)
    if not raw then return '' end
    local s = tostring(raw):gsub('_', ' '):lower()
    return (s:gsub('(%a)([%w_]*)', function(first, rest)
        return first:upper() .. rest
    end))
end

function L()
    return Locales[Config.Locale] or Locales.en
end

function TranslateScenario(name)
    local locale = L()
    return (locale.scenarios and locale.scenarios[name]) or HumanizeName(name)
end

function TranslateAnimation(key)
    local locale = L()
    return (locale.animations and locale.animations[key]) or HumanizeName(key)
end

function TranslateCategory(key)
    local locale = L()
    return (locale.categories and locale.categories[key]) or (key and HumanizeName(key)) or nil
end

function TranslatePosition(key)
    local locale = L()
    return (locale.positions and locale.positions[key]) or (key and HumanizeName(key)) or nil
end
