local PickerIsOpen        = false
local CurrentInteraction  = nil
local InteractionMarker   = nil
local StartingCoords      = nil
local CanStartInteraction = true
local MaxRadius           = 0.0
local NearbyAvailable     = false
local NearbyActionLabel   = nil
local OpenPrompt          = nil
local LastPromptText      = nil
local OpenKeyHoldStarted  = 0
local OpenKeyHoldDone     = false
local NextRestartAttempt  = 0
local PreviewPed          = nil
local PreviewKey          = nil
local PreviewBusy         = false
local PlayerPreviewHidden = false
local HiddenPlayerPed     = nil
local ObjectInteractionsByHash = {}
local PointInteractions = {}
local CachedAvailable = {}
local CachedAvailableAt = 0


local function SetLocalPlayerPreviewHidden(hidden)
    -- Keep the real player visible during preview. Some RedM visibility/alpha natives
    -- can leak unexpected states to other clients when applied to PlayerPedId().
    if PlayerPreviewHidden then
        local ped = PlayerPedId()
        local targetPed = HiddenPlayerPed
        if targetPed and DoesEntityExist(targetPed) then
            ResetEntityAlpha(targetPed)
            SetEntityVisible(targetPed, true, false)
        elseif DoesEntityExist(ped) then
            ResetEntityAlpha(ped)
            SetEntityVisible(ped, true, false)
        end
    end

    PlayerPreviewHidden = false
    HiddenPlayerPed     = nil
end

local function SafeCall(fn, ...)
    if type(fn) ~= 'function' then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

local function DistanceSquared(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return dx * dx + dy * dy + dz * dz
end

local function NormalizeRadius(interaction)
    local radius = tonumber(interaction.radius) or 1.5
    interaction.radius = radius
    interaction.radiusSq = radius * radius
    return radius
end

local function BuildRuntimeInteractionCache()
    ObjectInteractionsByHash = {}
    PointInteractions = {}
    MaxRadius = 0.0

    for i = 1, #Interactions do
        local interaction = Interactions[i]
        local radius = NormalizeRadius(interaction)

        if interaction.objects then
            if radius > MaxRadius then MaxRadius = radius end

            for j = 1, #interaction.objects do
                local modelName = interaction.objects[j]
                local modelHash = type(modelName) == 'number' and modelName or GetHashKey(modelName)

                if modelHash and modelHash ~= 0 then
                    local bucket = ObjectInteractionsByHash[modelHash]
                    if not bucket then
                        bucket = {}
                        ObjectInteractionsByHash[modelHash] = bucket
                    end

                    bucket[#bucket + 1] = {
                        interaction = interaction,
                        modelName = modelName,
                    }
                end
            end
        else
            if interaction.x and interaction.y and interaction.z then
                interaction.runtimeCoords = vector3(interaction.x, interaction.y, interaction.z)
                PointInteractions[#PointInteractions + 1] = interaction
            end
        end
    end

    if MaxRadius < 0.1 then MaxRadius = 0.1 end
end

local function IsInBannedArea(coords)
    local areas = Config.BannedAreas
    if type(areas) ~= 'table' then return false end

    for i = 1, #areas do
        local area = areas[i]
        if area and area.coords and area.radius then
            local radius = tonumber(area.radius) or 0.0
            if radius > 0.0 and DistanceSquared(coords, area.coords) <= (radius * radius) then
                return true
            end
        end
    end

    return false
end

local function RunInteractionEffect(interaction, phase)
    if not interaction or not interaction.effect then return end
    if type(Config.Effects) ~= 'table' then return end

    local effect = Config.Effects[interaction.effect]
    if type(effect) ~= 'function' then return end

    -- Effects run on start by default. Entries may use effectPhase = 'stop' or 'both'.
    local wantedPhase = interaction.effectPhase or 'start'
    if wantedPhase == phase or wantedPhase == 'both' then
        effect(interaction, phase)
    end
end

local function IsEntityNetworkedSafe(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    local result = SafeCall(NetworkGetEntityIsNetworked, entity)
    return result == true
end

local function ForcePreviewPedLocalOnly(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    -- Use protected calls for optional network-visibility natives when available.
    SafeCall(NetworkSetEntityInvisibleToNetwork, entity, true)

    if IsEntityNetworkedSafe(entity) then
        local netId = SafeCall(NetworkGetNetworkIdFromEntity, entity)
        if netId then
            SafeCall(SetNetworkIdCanMigrate, netId, false)
            SafeCall(SetNetworkIdExistsOnAllMachines, netId, false)
        end
    end
end

local function LoadModelSafe(model, timeoutMs)
    if not model or model == 0 then return false end
    if HasModelLoaded(model) then return true end

    RequestModel(model)
    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while not HasModelLoaded(model) and GetGameTimer() < deadline do
        Citizen.Wait(10)
    end

    return HasModelLoaded(model)
end

local function CreatePreviewPedLocalOnly(playerPed, x, y, z, h)
    -- Do not pass heading to ClonePed on RedM; set it after cloning to keep the
    -- preview ped local/script-only across tested builds.
    local ghost = ClonePed(playerPed, false, false, false)

    if ghost and ghost ~= 0 and DoesEntityExist(ghost) and ghost ~= playerPed then
        SetEntityCoordsNoOffset(ghost, x, y, z)
        SetEntityHeading(ghost, h)
        ForcePreviewPedLocalOnly(ghost)
        return ghost
    end

    return nil
end

local function EnablePickerMouseLook()
    local previewConfig = Config.Preview or {}
    if previewConfig.allowMouseLook == false then return end

    -- Re-enable only camera controls while the picker is open.
    EnableControlAction(0, `INPUT_LOOK_LR`, true)
    EnableControlAction(0, `INPUT_LOOK_UD`, true)
    EnableControlAction(0, `INPUT_LOOK_UP_ONLY`, true)
    EnableControlAction(0, `INPUT_LOOK_DOWN_ONLY`, true)
    EnableControlAction(0, `INPUT_LOOK_LEFT_ONLY`, true)
    EnableControlAction(0, `INPUT_LOOK_RIGHT_ONLY`, true)
    EnableControlAction(0, `INPUT_LOOK_BEHIND`, true)

    if previewConfig.allowZoom ~= false then
        EnableControlAction(0, `INPUT_VEH_RADIO_WHEEL`, true)
        EnableControlAction(0, `INPUT_NEXT_CAMERA`, true)
    end
end

local function GetNearbyObjects(coords)
    local itemset = CreateItemset(true)
    local size    = Citizen.InvokeNative(0x59B57C4B06531E1E, coords, MaxRadius, itemset, 3, Citizen.ResultAsInteger())
    local objects = {}

    if size > 0 then
        for i = 0, size - 1 do
            objects[#objects + 1] = GetIndexedItemInItemset(i, itemset)
        end
    end

    if IsItemsetValid(itemset) then
        DestroyItemset(itemset)
    end

    return objects
end

local function CanStartAtObject(interaction, playerCoords, objectCoords)
    local radiusSq = interaction.radiusSq or ((interaction.radius or 1.5) * (interaction.radius or 1.5))
    return DistanceSquared(playerCoords, objectCoords) <= radiusSq
end

local function IsCompatible(t, ped)
    return not t.isCompatible or t.isCompatible(ped)
end

local function PlayAnimation(ped, anim)
    if not LoadAnimDict(anim.dict) then
        return
    end
    TaskPlayAnim(ped, anim.dict, anim.name, 0.0, 0.0, -1, 1, 1.0, false, false, false, '', false)
    RemoveAnimDict(anim.dict)
end



local function StopInteractionPreview()
    PreviewKey  = nil
    PreviewBusy = false

    if PreviewPed and DoesEntityExist(PreviewPed) then
        ClearPedTasksImmediately(PreviewPed)
        DeleteEntity(PreviewPed)
    end

    PreviewPed = nil
end

local function ResolveInteractionCoords(interaction)
    local x, y, z, h = interaction.x, interaction.y, interaction.z, interaction.heading

    if interaction.object and interaction.object ~= 0 and DoesEntityExist(interaction.object) then
        local objectHeading = GetEntityHeading(interaction.object)
        local objectCoords  = GetEntityCoords(interaction.object)

        local r    = math.rad(objectHeading)
        local cosr = math.cos(r)
        local sinr = math.sin(r)

        local localX = x or 0.0
        local localY = y or 0.0

        x = localX * cosr - localY * sinr + objectCoords.x
        y = localX * sinr + localY * cosr + objectCoords.y
        z = (z or 0.0) + objectCoords.z
        h = (h or 0.0) + objectHeading
    end

    return x, y, z, h
end

local function BuildPreviewKey(interaction)
    return table.concat({
        tostring(interaction.object or 0),
        tostring(interaction.x or 0.0),
        tostring(interaction.y or 0.0),
        tostring(interaction.z or 0.0),
        tostring(interaction.heading or 0.0),
        tostring(interaction.scenario or ''),
        tostring(interaction.animation and interaction.animation.dict or ''),
        tostring(interaction.animation and interaction.animation.name or '')
    }, '|')
end

local function ApplyPreviewPedStyle(ped)
    local previewConfig = Config.Preview or {}
    local alpha         = previewConfig.alpha or 120

    SetEntityAlpha(ped, alpha, false)
    SetEntityCollision(ped, false, false)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityAsMissionEntity(ped, true, true)

    if previewConfig.hideWeapons ~= false then
        RemoveAllPedWeapons(ped, true, true)
    end
end

local function StartInteractionPreview(interaction)
    local previewConfig = Config.Preview or {}
    if previewConfig.enabled == false or PreviewBusy then return end

    local key = BuildPreviewKey(interaction)
    if PreviewKey == key and PreviewPed and DoesEntityExist(PreviewPed) then return end

    PreviewBusy = true
    StopInteractionPreview()
    PreviewKey = key

    local playerPed = PlayerPedId()
    if not DoesEntityExist(playerPed) or IsPedDeadOrDying(playerPed) then
        PreviewBusy = false
        return
    end

    local x, y, z, h = ResolveInteractionCoords(interaction)
    if not x or not y or not z or not h then
        PreviewBusy = false
        return
    end

    local ghost = CreatePreviewPedLocalOnly(playerPed, x, y, z, h)
    if not ghost or ghost == 0 or not DoesEntityExist(ghost) or ghost == playerPed then
        PreviewBusy = false
        return
    end

    PreviewPed = ghost

    SetEntityCoordsNoOffset(ghost, x, y, z)
    SetEntityHeading(ghost, h)
    ApplyPreviewPedStyle(ghost)

    if interaction.scenario then
        TaskStartScenarioAtPosition(ghost, GetHashKey(interaction.scenario), x, y, z, h, -1, false, true)
    elseif interaction.animation then
        PlayAnimation(ghost, interaction.animation)
    end

    PreviewBusy = false
end

local function StartInteractionAtCoords(interaction)
    local x, y, z, h = interaction.x, interaction.y, interaction.z, interaction.heading
    local ped = PlayerPedId()

    if not StartingCoords then
        StartingCoords = GetEntityCoords(ped)
    end

    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, true)

    if interaction.scenario then
        TaskStartScenarioAtPosition(ped, GetHashKey(interaction.scenario), x, y, z, h, -1, false, true)
    elseif interaction.animation then
        SetEntityCoordsNoOffset(ped, x, y, z)
        SetEntityHeading(ped, h)
        PlayAnimation(ped, interaction.animation)
    end

    RunInteractionEffect(interaction, 'start')

    CurrentInteraction = interaction
end

local function StartInteractionAtObject(interaction)
    interaction.x, interaction.y, interaction.z, interaction.heading = ResolveInteractionCoords(interaction)
    StartInteractionAtCoords(interaction)
end

local function StopInteraction()
    local interaction = CurrentInteraction
    CurrentInteraction = nil
    local ped = PlayerPedId()

    RunInteractionEffect(interaction, 'stop')

    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)
    Citizen.Wait(100)

    if StartingCoords then
        if Config.TeleportBackOnStop ~= false then
            SetEntityCoordsNoOffset(ped, StartingCoords.x, StartingCoords.y, StartingCoords.z)
        end
        StartingCoords = nil
    end
end

local function IsPedUsingInteraction(ped, interaction)
    if interaction.scenario then
        return IsPedUsingScenarioHash(ped, GetHashKey(interaction.scenario))
    elseif interaction.animation then
        return IsEntityPlayingAnim(ped, interaction.animation.dict, interaction.animation.name, 1)
    end
    return false
end

local function SetMarker(target)
    InteractionMarker = target
end

local function DrawMarker()
    if not InteractionMarker then return end
    if Config.Marker and Config.Marker.enabled == false then return end

    local x, y, z
    if type(InteractionMarker) == 'number' then
        x, y, z = table.unpack(GetEntityCoords(InteractionMarker))
    else
        x, y, z = table.unpack(InteractionMarker)
    end
    DrawInteractionMarker(Config.Marker.type, x, y, z, Config.Marker.color)
end

local function BuildDisplayLabel(entry)
    local locale = L()
    local parts  = {}

    if entry.category then
        local cat = TranslateCategory(entry.category)
        if cat then parts[#parts + 1] = cat end
    end

    local action
    if entry.scenario then
        action = TranslateScenario(entry.scenario)
    elseif entry.animation then
        action = TranslateAnimation(entry.animation.labelKey)
    end

    if action then
        if #parts > 0 then
            parts[#parts] = parts[#parts] .. ': ' .. action
        else
            parts[#parts + 1] = action
        end
    end

    if entry.label then
        local pos = TranslatePosition(entry.label)
        if pos then parts[#parts] = parts[#parts] .. ' (' .. pos .. ')' end
    end

    return table.concat(parts, ' ')
end


local function ResetOpenKeyHold()
    OpenKeyHoldStarted = 0
    OpenKeyHoldDone    = false
end

local function HasOpenKeyCompleted()
    -- Standard press mode uses the configured key without a Lua hold timer.
    if OpenPrompt and PromptHasStandardModeCompleted then
        return PromptHasStandardModeCompleted(OpenPrompt)
    end

    return IsControlJustPressed(0, Config.OpenKey)
end

local function ResolvePromptLabel(available)
    local locale       = L()
    local promptLocale = locale.prompt or {}
    local actions      = promptLocale.actions or {}

    if #available == 0 then return nil end

    local firstCategory = available[1].category
    local allSame       = firstCategory ~= nil
    if allSame then
        for i = 2, #available do
            if available[i].category ~= firstCategory then
                allSame = false
                break
            end
        end
    end

    if allSame and actions[firstCategory] then
        return actions[firstCategory]
    end

    return promptLocale.action or 'Interact'
end

local function CreateOpenPrompt()
    if OpenPrompt then return end
    local locale = L()
    local label  = (locale.prompt and locale.prompt.action) or 'Interact'

    OpenPrompt = PromptRegisterBegin()
    PromptSetControlAction(OpenPrompt, Config.OpenKey)
    PromptSetText(OpenPrompt, CreateVarString(10, 'LITERAL_STRING', label))
    PromptSetEnabled(OpenPrompt, false)
    PromptSetVisible(OpenPrompt, false)
    if Config.OpenHoldMode then
        -- RedM expects a duration in milliseconds for native hold prompts.
        PromptSetHoldMode(OpenPrompt, tonumber(Config.OpenHoldTimeMs) or 2000)
    else
        PromptSetStandardMode(OpenPrompt, true)
    end
    PromptRegisterEnd(OpenPrompt)
    LastPromptText = label
end

local function DestroyOpenPrompt()
    if not OpenPrompt then return end
    PromptDelete(OpenPrompt)
    OpenPrompt     = nil
    LastPromptText = nil
    ResetOpenKeyHold()
end

local function UpdateOpenPrompt()
    if not OpenPrompt then return end

    -- Show the prompt only when a nearby interaction is available.
    local shouldShow = NearbyAvailable
        and CanStartInteraction
        and not PickerIsOpen
        and not CurrentInteraction

    if shouldShow then
        local label = NearbyActionLabel

        if label and label ~= LastPromptText then
            PromptSetText(OpenPrompt, CreateVarString(10, 'LITERAL_STRING', label))
            LastPromptText = label
        end

        PromptSetEnabled(OpenPrompt, true)
        PromptSetVisible(OpenPrompt, true)
    else
        PromptSetEnabled(OpenPrompt, false)
        PromptSetVisible(OpenPrompt, false)
        ResetOpenKeyHold()
    end
end

local function CollectInteractions(list, interaction, ped, playerCoords, targetCoords, modelName, object)
    local distance = #(playerCoords - targetCoords)

    if interaction.scenarios then
        for i = 1, #interaction.scenarios do
            local scenario = interaction.scenarios[i]
            if IsCompatible(scenario, ped) then
                list[#list + 1] = {
                    x = interaction.x, y = interaction.y, z = interaction.z, heading = interaction.heading,
                    scenario   = scenario.name,
                    object     = object,
                    modelName  = modelName,
                    distance   = distance,
                    label      = interaction.label,
                    category   = interaction.category,
                    effect     = interaction.effect,
                    effectPhase = interaction.effectPhase,
                    displayLabel = nil,
                }
            end
        end
    end

    if interaction.animations then
        for i = 1, #interaction.animations do
            local animation = interaction.animations[i]
            if IsCompatible(animation, ped) then
                list[#list + 1] = {
                    x = interaction.x, y = interaction.y, z = interaction.z, heading = interaction.heading,
                    animation  = animation,
                    object     = object,
                    modelName  = modelName,
                    distance   = distance,
                    label      = interaction.label,
                    category   = interaction.category,
                    effect     = interaction.effect,
                    effectPhase = interaction.effectPhase,
                    displayLabel = nil,
                }
            end
        end
    end
end

local function GetAvailableInteractions()
    local ped          = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local available    = {}

    if IsInBannedArea(playerCoords) then
        return available
    end

    local nearbyObjects = GetNearbyObjects(playerCoords)
    for j = 1, #nearbyObjects do
        local object = nearbyObjects[j]
        if object and object ~= 0 and DoesEntityExist(object) then
            local bucket = ObjectInteractionsByHash[GetEntityModel(object)]
            if bucket then
                local objectCoords = GetEntityCoords(object)

                for k = 1, #bucket do
                    local cached      = bucket[k]
                    local interaction = cached.interaction

                    if IsCompatible(interaction, ped) and CanStartAtObject(interaction, playerCoords, objectCoords) then
                        CollectInteractions(available, interaction, ped, playerCoords, objectCoords, cached.modelName, object)
                    end
                end
            end
        end
    end

    for i = 1, #PointInteractions do
        local interaction = PointInteractions[i]
        local target = interaction.runtimeCoords

        if target and IsCompatible(interaction, ped) and DistanceSquared(playerCoords, target) <= (interaction.radiusSq or 4.0) then
            CollectInteractions(available, interaction, ped, playerCoords, target)
        end
    end

    table.sort(available, function(a, b)
        if a.distance ~= b.distance then return a.distance < b.distance end
        if a.object   ~= b.object   then return (a.object or 0) < (b.object or 0) end
        local aLabel = a.scenario or (a.animation and a.animation.labelKey) or ''
        local bLabel = b.scenario or (b.animation and b.animation.labelKey) or ''
        return aLabel < bLabel
    end)

    for i = 1, #available do
        available[i].displayLabel = BuildDisplayLabel(available[i])
    end

    return available
end

local function SetCachedAvailable(available)
    CachedAvailable = available or {}
    CachedAvailableAt = GetGameTimer()
end

local function GetFreshAvailableInteractions()
    local now = GetGameTimer()
    local cacheTtl = (tonumber(Config.NearbyCheckInterval) or 750) + 250

    if CachedAvailable and CachedAvailableAt > 0 and (now - CachedAvailableAt) <= cacheTtl then
        return CachedAvailable
    end

    local available = GetAvailableInteractions()
    SetCachedAvailable(available)
    return available
end

local function OpenPicker()
    ResetOpenKeyHold()
    if PickerIsOpen or not CanStartInteraction then return end
    StopInteractionPreview()

    local available = GetFreshAvailableInteractions()

    if #available == 0 then
        if CurrentInteraction then
            StopInteraction()
        end
        return
    end

    local locale = L()

    SendNUIMessage({
        type         = 'showInteractionPicker',
        interactions = json.encode(available),
        title        = locale.menu.title,
        cancelLabel  = locale.menu.end_,
        theme        = Config.Theme,
    })

    PickerIsOpen = true
    SetLocalPlayerPreviewHidden(true)
    UpdateOpenPrompt()
end

local function ClosePicker(startSelected)
    ResetOpenKeyHold()
    StopInteractionPreview()
    if not startSelected then
        SetLocalPlayerPreviewHidden(false)
    end
    SendNUIMessage({
        type    = startSelected and 'startInteraction' or 'hideInteractionPicker',
    })
    SetMarker(nil)
    PickerIsOpen = false
end

RegisterNUICallback('startInteraction', function(data, cb)
    StopInteractionPreview()
    SetLocalPlayerPreviewHidden(false)
    if data.object and data.object ~= 0 then
        StartInteractionAtObject(data)
    else
        StartInteractionAtCoords(data)
    end
    cb({})
end)

RegisterNUICallback('stopInteraction', function(data, cb)
    StopInteractionPreview()
    SetLocalPlayerPreviewHidden(false)
    StopInteraction()
    cb({})
end)

RegisterNUICallback('setInteractionMarker', function(data, cb)
    if data.entity and data.entity ~= 0 then
        SetMarker(data.entity)
    elseif data.x and data.y and data.z then
        SetMarker(vector3(data.x, data.y, data.z))
    else
        SetMarker(nil)
    end
    cb({})
end)

RegisterNUICallback('setInteractionPreview', function(data, cb)
    if data and data.cancel == 1 then
        StopInteractionPreview()
    elseif data and (data.scenario or data.animation) then
        StartInteractionPreview(data)
    else
        StopInteractionPreview()
    end
    cb({})
end)

RegisterCommand('interact', function()
    ResetOpenKeyHold()
    if PickerIsOpen then
        ClosePicker(false)
    elseif CurrentInteraction then
        StopInteraction()
    else
        OpenPicker()
    end
end, false)

Citizen.CreateThread(function()
    BuildRuntimeInteractionCache()
    CreateOpenPrompt()

    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        CanStartInteraction = not IsPedDeadOrDying(ped) and not IsPedInCombat(ped) and not IsInBannedArea(coords)

        if CanStartInteraction and not PickerIsOpen and not CurrentInteraction then
            local available = GetAvailableInteractions()
            SetCachedAvailable(available)
            if #available > 0 then
                NearbyAvailable   = true
                NearbyActionLabel = ResolvePromptLabel(available)
            else
                NearbyAvailable   = false
                NearbyActionLabel = nil
            end
        else
            NearbyAvailable   = false
            NearbyActionLabel = nil
        end

        UpdateOpenPrompt()

        Citizen.Wait(Config.NearbyCheckInterval)
    end
end)

Citizen.CreateThread(function()
    while true do
        local wait = 500

        if PickerIsOpen then
            wait = 0
            DisableAllControlActions(0)
            SetLocalPlayerPreviewHidden(true)
            EnablePickerMouseLook()

            if IsDisabledControlJustPressed(0, Config.Controls.menuUp) then
                SendNUIMessage({ type = 'moveSelectionUp' })
            end
            if IsDisabledControlJustPressed(0, Config.Controls.menuDown) then
                SendNUIMessage({ type = 'moveSelectionDown' })
            end
            if IsDisabledControlJustPressed(0, Config.Controls.menuAccept) then
                ClosePicker(true)
            end
            if IsDisabledControlJustPressed(0, Config.Controls.menuCancel) or not CanStartInteraction then
                ClosePicker(false)
            end

            if InteractionMarker then
                DrawMarker()
            end
        elseif CurrentInteraction then
            wait = 0
            local ped = PlayerPedId()
            if not CanStartInteraction then
                StopInteraction()
            elseif Config.StopKey and IsControlJustPressed(0, Config.StopKey) then
                StopInteraction()
            elseif IsControlJustPressed(0, Config.OpenKey) then
                -- Allow reopening the picker while an interaction is already active.
                OpenPicker()
            elseif not IsPedUsingInteraction(ped, CurrentInteraction) then
                local now = GetGameTimer()
                if now >= NextRestartAttempt then
                    NextRestartAttempt = now + 1000
                    StartInteractionAtCoords(CurrentInteraction)
                end
            end
        elseif NearbyAvailable and CanStartInteraction then
            wait = 0
            if HasOpenKeyCompleted() then
                OpenPicker()
            end
        end

        Citizen.Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if CurrentInteraction then
        StopInteraction()
    end
    StopInteractionPreview()
    SetLocalPlayerPreviewHidden(false)
    DestroyOpenPrompt()
    SendNUIMessage({ type = 'hideInteractionPicker' })
end)
