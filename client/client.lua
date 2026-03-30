local Framework = nil
local FrameworkType = "standalone"

-- Detect framework
CreateThread(function()
    if GetResourceState('qb-core') == 'started' then
        Framework = exports['qb-core']:GetCoreObject()
        FrameworkType = "qb"
        print("[DTERP] QB-Core detected")
    elseif GetResourceState('es_extended') == 'started' then
        Framework = exports['es_extended']:getSharedObject()
        FrameworkType = "esx"
        print("[DTERP] ESX detected")
    else
        print("[DTERP] Running in standalone mode")
    end
end)

-- Commands for keybinds
RegisterCommand('+point', function()
    TriggerEvent('dterp:togglePoint')
end, false)

RegisterCommand('-point', function() end, false)

RegisterKeyMapping('+point', 'Point', 'keyboard', 'B')


RegisterCommand('+handsup', function()
    TriggerEvent('dterp:toggleHandsUp')
end, false)

RegisterCommand('-handsup', function() end, false)

RegisterKeyMapping('+handsup', 'Hands Up', 'keyboard', 'X')

local isPointing = false
local handsUp = false

-- Example cuff check (edit based on your framework)
local function isRestrained(ped)

    -- QB-Core / Qbox
    if FrameworkType == "qb" then
        return LocalPlayer.state.isCuffed or LocalPlayer.state.isHandcuffed
    end

    -- ESX
    if FrameworkType == "esx" then
        return IsEntityPlayingAnim(ped, "mp_arresting", "idle", 3)
    end

    -- Standalone fallback
    return IsEntityPlayingAnim(ped, "mp_arresting", "idle", 3)
end

-- Load animation helper
local function loadAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(10)
    end
end

-- =========================
-- POINT EVENT
-- =========================
local function startPointing(ped)
    if isPointing then return end
    loadAnimDict("anim@mp_point")

    SetPedCurrentWeaponVisible(ped, false, true, true, true)
    SetPedConfigFlag(ped, 36, true)

    Citizen.InvokeNative(0x2D537BA194896636, ped, "task_mp_pointing", 0.5, 0, "anim@mp_point", 24)

    isPointing = true

    -- SYNC STATE
    Entity(ped).state:set("isPointing", true, true)

    CreateThread(function()
        local lastPitch, lastHeading = 0.0, 0.0

        while isPointing do
            Wait(0)

            local camPitch = GetGameplayCamRelativePitch()
            local camHeading = GetGameplayCamRelativeHeading()

            camPitch = math.max(-70.0, math.min(42.0, camPitch))
            camHeading = math.max(-180.0, math.min(180.0, camHeading))

            local pitch = (camPitch + 70.0) / 112.0
            local heading = ((camHeading * -1.0) + 180.0) / 360.0

            -- Smooth
            pitch = lastPitch + (pitch - lastPitch) * 0.25
            heading = lastHeading + (heading - lastHeading) * 0.25

            lastPitch = pitch
            lastHeading = heading

            SetTaskMoveNetworkSignalFloat(ped, "Pitch", pitch)
            SetTaskMoveNetworkSignalFloat(ped, "Heading", heading)

            SetTaskMoveNetworkSignalBool(ped, "isBlocked", false)
            SetTaskMoveNetworkSignalBool(ped, "isFirstPerson", GetFollowPedCamViewMode() == 4)
        end
    end)
end

local function stopPointing(ped)
    Citizen.InvokeNative(0xD01015C7316AE176, ped, "Stop")
    ClearPedSecondaryTask(ped)

    SetPedConfigFlag(ped, 36, false)
    SetPedCurrentWeaponVisible(ped, true, true, true, true)

    isPointing = false

    -- SYNC STATE
    Entity(ped).state:set("isPointing", false, true)
end
RegisterNetEvent('dterp:togglePoint', function()
    local ped = PlayerPedId()

    if IsEntityDead(ped)
    or IsPlayerFreeAiming(PlayerId())
    or isRestrained(ped)
    or handsUp then
        return
    end

    if not isPointing then
        startPointing(ped)
    else
        stopPointing(ped)
    end
end)

AddStateBagChangeHandler("isPointing", "", function(bagName, key, value, _, replicated)
    if not replicated then return end

    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then return end

    local ped = entity

    -- Ignore local player (already handled)
    if ped == PlayerPedId() then return end

    if value then
        -- Start pointing for other player
        loadAnimDict("anim@mp_point")

        SetPedCurrentWeaponVisible(ped, false, true, true, true)
        SetPedConfigFlag(ped, 36, true)

        Citizen.InvokeNative(0x2D537BA194896636, ped, "task_mp_pointing", 0.5, 0, "anim@mp_point", 24)
    else
        -- Stop pointing for other player
        Citizen.InvokeNative(0xD01015C7316AE176, ped, "Stop")
        ClearPedSecondaryTask(ped)

        SetPedConfigFlag(ped, 36, false)
        SetPedCurrentWeaponVisible(ped, true, true, true, true)
    end
end)

-- =========================
-- HANDS UP EVENT
-- =========================
local function startHandsUp(ped)
    loadAnimDict("missminuteman_1ig_2")

    TaskPlayAnim(
        ped,
        "missminuteman_1ig_2",
        "handsup_enter",
        8.0,
        8.0,
        -1,
        50,
        0,
        false,
        false,
        false
    )

    handsUp = true

    -- SYNC STATE
    Entity(ped).state:set("handsUp", true, true)
end

local function stopHandsUp(ped)
    ClearPedTasks(ped)

    handsUp = false

    -- SYNC STATE
    Entity(ped).state:set("handsUp", false, true)
end
RegisterNetEvent('dterp:toggleHandsUp', function()
    local ped = PlayerPedId()

    if IsEntityDead(ped)
    or IsPedInAnyVehicle(ped, false)
    or IsPlayerFreeAiming(PlayerId())
    or isRestrained(ped) then
        return
    end

    if not handsUp then
        startHandsUp(ped)
    else
        stopHandsUp(ped)
    end
end)
AddStateBagChangeHandler("handsUp", "", function(bagName, key, value, _, replicated)
    if not replicated then return end

    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then return end

    local ped = entity

    -- Ignore local player
    if ped == PlayerPedId() then return end

    if value then
        loadAnimDict("missminuteman_1ig_2")

        TaskPlayAnim(
            ped,
            "missminuteman_1ig_2",
            "handsup_enter",
            8.0,
            8.0,
            -1,
            50,
            0,
            false,
            false,
            false
        )
    else
        ClearPedTasks(ped)
    end
end)

-- =========================
-- AUTO CANCEL LOOP
-- =========================
CreateThread(function()
    while true do
        Wait(0) -- Run every frame to ensure instant cancel on invalid states
        local sleep = 1000
        local ped = PlayerPedId()

        if not IsEntityDead(ped) then
            sleep = 200

            local aiming = IsPlayerFreeAiming(PlayerId())
            local inVeh = IsPedInAnyVehicle(ped, false)

            -- Cancel hands up if invalid
            if handsUp and (aiming or inVeh or isRestrained(ped)) then
                ClearPedTasks(ped)
                Entity(ped).state:set("handsUp", false, true)
                handsUp = false
            end

            -- Cancel pointing if aiming or restrained
            if isPointing and (aiming or isRestrained(ped)) then
                Citizen.InvokeNative(0xD01015C7316AE176, ped, "Stop")
                ClearPedSecondaryTask(ped)
                SetPedConfigFlag(ped, 36, false)
                SetPedCurrentWeaponVisible(ped, true, true, true, true)
                Entity(ped).state:set("isPointing", false, true)
                isPointing = false
            end

        else
            -- Reset everything on death
            if handsUp or isPointing then
                ClearPedTasksImmediately(ped)

                Citizen.InvokeNative(0xD01015C7316AE176, ped, "Stop")
                SetPedConfigFlag(ped, 36, false)
                SetPedCurrentWeaponVisible(ped, true, true, true, true)

                handsUp = false
                isPointing = false
            end
        end

        Wait(sleep)
    end
end)
