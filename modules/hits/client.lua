local HitInfo = {}
HitRegistry = {}
DutyInteractions = {}
LOCAL_ON_DUTY = false
HIDE_INTERACTIONS = false

function HitsToArray(hits)
    local hitsArray = {}

    for k, v in pairs(hits) do
        table.insert(hitsArray, {
            id = v.target,
            source = v.source,
            image = v.image,
            description = v.description,
            name = v.targetname,
            reward = v.reward,
            time = v.time,
            active = v.active,
            date = v.datetime
        })
    end

    return hitsArray
end

function UpdateHits(hits)
    HitRegistry = hits
    SendNUIMessage({
        type = "updateHits",
        hits = HitsToArray(hits)
    })
end

function GetScenarioFromChances(chances)
    local rng = math.random(1, 100)
    local cumulativeChance = 0
    for scenario, chance in pairs(chances) do
        cumulativeChance = cumulativeChance + chance
        if rng <= cumulativeChance * 100 then
            return scenario
        end
    end
    return "fleeFoot" -- default scenario if none matched
end

function GetNPCScenarioFromRisk(risk)
    local chances = {
        firearmAttack = Config.NPCTargets.firearmAttack,
        meleeAttack = Config.NPCTargets.meleeAttack,
        fleeVehicle = Config.NPCTargets.fleeVehicle,
        fleeFoot = Config.NPCTargets.fleeFoot,
    }
    return GetScenarioFromChances(chances)
end

function PerformScenario(scenario)
    local id = CurrentHit.id
    SetTimeout(0, function()
        SetEntityHealth(CurrentHit.targetNPC, 0)
        CameraLoop({trackType = "ped", netId = PedToNet(CurrentHit.targetNPC)})
    end)
    if scenario == "fleeFoot" or (scenario == "fleeVehicle" and CurrentHit.vehicle == nil) then
        while CurrentHit and CurrentHit.id == id and CurrentHit.targetNPC do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local targetCoords = GetEntityCoords(CurrentHit.targetNPC)
            local distance = #(playerCoords - targetCoords)
            if distance < 50.0 then
                RemoveBlip(CurrentHit.targetBlip)
                CurrentHit.targetBlip = nil
                RemoveBlip(CurrentHit.targetRadius)
                CurrentHit.targetRadius = nil
                TaskSmartFleePed(CurrentHit.targetNPC, playerPed, 100.0, -1, false, false)
                ShowNotification(_L("hit_fleeing", CurrentHit.name))
                break
            end
            Wait(1000)
        end
    elseif scenario == "meleeAttack" then
        RemoveAllPedWeapons(CurrentHit.targetNPC)
        while CurrentHit and CurrentHit.id == id and CurrentHit.targetNPC do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local targetCoords = GetEntityCoords(CurrentHit.targetNPC)
            local distance = #(playerCoords - targetCoords)
            if distance < 50.0 then
                RemoveBlip(CurrentHit.targetBlip)
                CurrentHit.targetBlip = nil
                RemoveBlip(CurrentHit.targetRadius)
                CurrentHit.targetRadius = nil
                TaskCombatPed(CurrentHit.targetNPC, playerPed, 0, 16)
                break
            end
            Wait(1000)
        end
    elseif scenario == "firearmAttack" then
        RemoveAllPedWeapons(CurrentHit.targetNPC)
        local weaponHash = Config.NPCTargets.weapons[#Config.NPCTargets.weapons > 1 and math.random(1, #Config.NPCTargets.weapons) or 1]
        GiveWeaponToPed(CurrentHit.targetNPC, weaponHash, 999, false, true)
        while CurrentHit and CurrentHit.id == id and CurrentHit.targetNPC do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local targetCoords = GetEntityCoords(CurrentHit.targetNPC)
            local distance = #(playerCoords - targetCoords)
            if distance < 50.0 then
                RemoveBlip(CurrentHit.targetBlip)
                CurrentHit.targetBlip = nil
                RemoveBlip(CurrentHit.targetRadius)
                CurrentHit.targetRadius = nil
                TaskCombatPed(CurrentHit.targetNPC, playerPed, 0, 16)
                break
            end
            Wait(1000)
        end
    elseif scenario == "fleeVehicle" then
        local vehicle = CurrentHit.vehicle
        if vehicle and DoesEntityExist(vehicle) then
            ClearPedTasksImmediately(CurrentHit.targetNPC)
            TaskEnterVehicle(CurrentHit.targetNPC, vehicle, -1, -1, 2.0, 8, 0)
            local timeStopped = 0
            local drivingTime = 0
            local driving = false
            local stopped = false
            local leaveVehicle = false
            while CurrentHit and CurrentHit.id == id and CurrentHit.targetNPC do
                if not driving and IsPedInAnyVehicle(CurrentHit.targetNPC, false) then
                    ShowNotification(_L("hit_fleeing_vehicle", CurrentHit.name))
                    driving = true
                end
                if driving then
                    TaskVehicleDriveWander(CurrentHit.targetNPC, vehicle, 10000.0, 786468)
                    if GetEntitySpeed(vehicle) < 1 then
                        stopped = true
                        timeStopped = timeStopped + 1
                        if timeStopped > Config.NPCTargets.maxStopTime then
                            leaveVehicle = true
                            break
                        end
                    elseif stopped then
                        stopped = false
                        drivingTime = 0
                        timeStopped = 0
                    end
                    drivingTime = drivingTime + 1
                    if drivingTime > Config.NPCTargets.maxDrivingTime then
                        leaveVehicle = true
                        break
                    end
                end
                Wait(1000)
            end
            if leaveVehicle then
                TaskLeaveVehicle(CurrentHit.targetNPC, vehicle, 0)
                Wait(2000)
                local newScenario = GetScenarioFromChances(Config.NPCTargets.chaseScenarioChances)
                return PerformScenario(newScenario)
            end
        end
    end
end

function GetClosestVehicle()
    local pool = GetGamePool("CVehicle")
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestVehicle = nil
    local closestDistance = 9999.0
    for i=1, #pool do
        local vehicle = pool[i]
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(playerCoords - vehicleCoords)
        if distance < closestDistance then
            closestDistance = distance
            closestVehicle = vehicle
        end
    end
    return closestVehicle, closestDistance
end

function VehicleInteract()
    local vehicle = GetClosestVehicle()
    local netId = VehToNet(vehicle)
    if not netId then return false end
    if not IsVehicleSeatFree(vehicle, 2) and not GetPedInVehicleSeat(vehicle, 2) then ShowNotification("no_back_seat") return false end
    TriggerServerEvent("pickle_hitman:vehicleInteract", netId)
    return true
end

function HitInteract(identifier, interactType)
    local entity = PlayerPedId()
    local data = nil
    if interactType == "detain" then
        local ped = NetToPed(HitInfo[identifier].netId)
        data = {
            coords = GetOffsetFromEntityInWorldCoords(entity, 0.0, 0.8, -1.5),
            heading = GetEntityHeading(entity),
        }
    end
    if interactType == "custody" then
        TriggerServerEvent("pickle_hitman:takeCustody", identifier)
        return
    end
    TriggerServerEvent("pickle_hitman:hitInteract", identifier, interactType, data)
end

function ShowHitTargetOptions(identifier)
    if not Config.UseTarget then return end
    local hitInfo = HitInfo[identifier]
    if not hitInfo then return end
    local options = {}
    local enabledOptions = {}

    if not hitInfo.isDetained then
        options[#options + 1] = { name = "detain", label = _L("hit_interact_detain"), onSelect = function() HitInteract(identifier, "detain") end }
        enabledOptions.detain = true
    else
        options[#options + 1] = { name = "drag", label = _L("hit_interact_drag"), onSelect = function() HitInteract(identifier, "drag") end }
        enabledOptions.drag = true
    end
    if hitInfo.netId then
        AddTargetNetworkId(hitInfo.netId, options)
    end
    return enabledOptions
end

function RemoveHitTargetOptions(identifier)
    if not Config.UseTarget then return end
    local hitInfo = HitInfo[identifier]
    if not hitInfo then return end
    local options = {
        { name = "detain", label = _L("hit_interact_detain") },
        { name = "drag", label = _L("hit_interact_drag") },
        { name = "vehicle", label = _L("hit_interact_vehicle") },
        { name = "custody", label = _L("hit_interact_custody") },
    }
    if hitInfo.netId then
        RemoveTargetNetworkId(hitInfo.netId, options)
    end
end

function ShowHitTargetMenu(identifier)
    local hit = HitRegistry[identifier]
    local hitInfo = HitInfo[identifier]
    if not hit or not hitInfo then return end
    local options = {}
    HIDE_INTERACTIONS = true
    if not hitInfo.isDetained then
        options[#options + 1] = { name = "detain", title = _L("hit_interact_detain"), onSelect = function() HIDE_INTERACTIONS = false; HitInteract(identifier, "detain") end }
    else
        options[#options + 1] = { name = "drag", title = _L("hit_interact_drag"), onSelect = function() HIDE_INTERACTIONS = false; HitInteract(identifier, "drag") end }
        options[#options + 1] = { name = "vehicle", title = _L("hit_interact_vehicle"), close = false, onSelect = function() 
            if not VehicleInteract() then
                return ShowNotification(_L("hit_no_vehicle"))
            end
            HIDE_INTERACTIONS = false
            lib.hideContext()
        end}
    end
    local menuId = "hit_target_menu"
    lib.registerContext({
        id = menuId,
        title = _L("hit_target_menu", hit.targetname),
        options = options,
        onExit = function()
            HIDE_INTERACTIONS = false
        end
    })
    lib.showContext(menuId)
end

function CancelCurrentHit()
    if not CurrentHit then return end
    if CurrentHit.targetBlip then
        RemoveBlip(CurrentHit.targetBlip)
    end
    if CurrentHit.targetRadius then
        RemoveBlip(CurrentHit.targetRadius)
    end
    if CurrentHit.targetNPC then 
        -- Handled sv-side
    end
    if CurrentHit.vehicle then
        local targetVeh = CurrentHit.vehicle
        SetTimeout(5000, function()
            DeleteEntity(targetVeh)
        end)
    end
    CurrentHit = nil
    SendNUIMessage({
        type = "updateHit",
        hit = CurrentHit
    })
end

RegisterNetEvent('pickle_hitman:addHit', function(identifier, data)
    HitRegistry[identifier] = data
    UpdateHits(HitRegistry)
end)

RegisterNetEvent("pickle_hitman:removeHit", function(identifier)
    HitRegistry[identifier] = nil
    UpdateHits(HitRegistry)
end)

RegisterNetEvent("pickle_hitman:updateHit", function(identifier, data)
    HitRegistry[identifier] = data
    UpdateHits(HitRegistry)
end)

RegisterNetEvent("pickle_hitman:setHitState", function(identifier, data)
    if data.type == "registerHitTarget" then
        HitInfo[identifier] = {
            source = data.source,
            netId = data.netId,
            currentVehicle = nil,
            isDetained = false,
            dragger = data.dragger or nil,
        }
        if LOCAL_ON_DUTY then
            ShowHitTargetOptions(identifier)
        end
    elseif data.type == "removeHitTarget" then
        if HitInfo[identifier] then
            if HitInfo[identifier].netId then
                local ped = NetToPed(HitInfo[identifier].netId)
                DetachEntity(ped, true, true)
                ClearPedTasks(ped)
                PlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0, 0, 0, 0)
            end
            if HitInfo[identifier].dragger and HitInfo[identifier].dragger == GetPlayerServerId(PlayerId()) then
                ClearPedTasks(PlayerPedId())
            end
            if HitInfo[identifier].dragger and HitInfo[identifier].source == GetPlayerServerId(PlayerId()) then
                DetachEntity(PlayerPedId(), true, true)
                ClearPedTasks(PlayerPedId())
            end
        end
        RemoveHitTargetOptions(identifier)
        HitInfo[identifier] = nil
        if CurrentHit and CurrentHit.id == identifier then
            CancelCurrentHit()
        end
    elseif data.type == "detainHitTarget" then
        HitInfo[identifier].isDetained = true
        if data.source == GetPlayerServerId(PlayerId()) then
            if HitInfo[identifier].netId then
                local ped = NetToPed(HitInfo[identifier].netId)
                if not NetworkHasControlOfEntity(ped) then
                    NetworkRequestControlOfEntity(ped)
                    local timeout = 500
                    while timeout > 0 and not NetworkHasControlOfEntity(ped) do
                        Wait(100)
                        timeout = timeout - 100
                    end
                end
            end
            SetEntityHeading(PlayerPedId(), data.heading)
            FreezeEntityPosition(PlayerPedId(), true)
            PlayAnim(PlayerPedId(), "mp_arrest_paired", "cop_p2_back_left", 8.0, -8.0, 5500, 33, 0, false, false, false)
            SetTimeout(5000, function()
                FreezeEntityPosition(PlayerPedId(), false)
                ShowNotification(_L("hit_detained"))
            end)
        end
        if HitInfo[identifier].netId then
            local ped = NetToPed(HitInfo[identifier].netId)
            if not NetworkHasControlOfEntity(ped) then
                NetworkRequestControlOfEntity(ped)
                local timeout = 500
                while timeout > 0 and not NetworkHasControlOfEntity(ped) do
                    Wait(100)
                    timeout = timeout - 100
                end
            end
            if ped then
                ClearPedTasksImmediately(ped)
                PlayAnim(ped, "mp_arrest_paired", "crook_p2_back_left", 8.0, -8.0, 5500, 33, 0, false, false, false)
                SetEntityCoords(ped, data.coords.x, data.coords.y, data.coords.z + 0.5)
                SetEntityHeading(ped, data.heading)

                SetEnableHandcuffs(ped, true)
                SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true) -- unarm player
                SetPedCanPlayGestureAnims(ped, false)
                FreezeEntityPosition(ped, true)
            end
            SetTimeout(5000, function()
                FreezeEntityPosition(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                CreateThread(function()
                    while ped and DoesEntityExist(ped) and HitInfo[identifier] and HitInfo[identifier].isDetained do
                        if not IsEntityPlayingAnim(ped, "mp_arresting", "idle", 3) then
                            ClearPedTasks(ped)
                            PlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0, 0, 0, 0)
                            Wait(100)
                        end
                        Wait(1000)
                    end
                end)
            end)
        elseif HitInfo[identifier].source == GetPlayerServerId(PlayerId()) then
            local ped = PlayerPedId()
            SetEntityCoords(ped, data.coords.x, data.coords.y, data.coords.z + 0.5)
            SetEntityHeading(ped, data.heading)
            SetEnableHandcuffs(ped, true)
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true) -- unarm player
            PlayAnim(ped, "mp_arrest_paired", "crook_p2_back_left", 8.0, -8.0, 5500, 33, 1.0, false, false, false)
            SetTimeout(5000, function()
                CreateThread(function()
                    while HitInfo[identifier] and HitInfo[identifier].isDetained do
                        local ped = PlayerPedId()
                        if not IsEntityPlayingAnim(ped, "mp_arresting", "idle", 3) then
                            ClearPedTasks(ped)
                            PlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0, 0, 0, 0)
                        end
                        DisableControlAction(0, 22, true) 
                        DisableControlAction(0, 23, true) 
                        DisableControlAction(0, 24, true)
                        DisableControlAction(0, 25, true) 
                        DisableControlAction(0, 30, true) 
                        DisableControlAction(0, 31, true) 
                        DisableControlAction(0, 32, true) 
                        DisableControlAction(0, 34, true) 
                        DisableControlAction(0, 36, true) 
                        DisableControlAction(0, 44, true) 
                        DisableControlAction(0, 45, true) 
                        DisableControlAction(0, 47, true) 
                        DisableControlAction(0, 75, true)  
                        DisableControlAction(0, 140, true) 
                        DisableControlAction(0, 141, true) 
                        DisableControlAction(0, 142, true) 
                        DisableControlAction(0, 143, true) 
                        DisableControlAction(0, 257, true) 
                        DisableControlAction(0, 263, true) 
                        DisableControlAction(0, 264, true) 
                        DisableControlAction(0, 289, true) 
                        Wait(0)
                    end
                    ClearPedTasksImmediately(PlayerPedId())
                    SetEnableHandcuffs(PlayerPedId(), false)
                end)
            end)
        end
        if LOCAL_ON_DUTY then
            ShowHitTargetOptions(identifier)
        end
    elseif data.type == "dragHitTarget" then
        HitInfo[identifier].dragger = data.source
        local playerPed = PlayerPedId()
        local serverId = GetPlayerServerId(PlayerId())
        if data.source == serverId then
            if HitInfo[identifier].netId then
                local ped = NetToPed(HitInfo[identifier].netId)
                if not NetworkHasControlOfEntity(ped) then
                    NetworkRequestControlOfEntity(ped)
                    local timeout = 500
                    while timeout > 0 and not NetworkHasControlOfEntity(ped) do
                        Wait(100)
                        timeout = timeout - 100
                    end
                end
                if ped and NetworkHasControlOfEntity(ped) then
                    CreateThread(function()
                        local sourcePed = PlayerPedId()
                        local boneIndex = GetPedBoneIndex(sourcePed, 0x60F2)
                        local coords, rot = vector3(-0.25, 0.24, -0.5), vector3(0.0, 90.0, 0.0)
                        AttachEntityToEntity(ped, sourcePed, boneIndex, coords.x, coords.y, coords.z, rot.x, rot.y, rot.z, 0, 0, 0, 1, 2, 1)
                        local moving = false
                        while ped and DoesEntityExist(ped) and HitInfo[identifier] and HitInfo[identifier].dragger and HitInfo[identifier].dragger == serverId do
                            sourcePed = PlayerPedId()
                            if IsPedWalking(sourcePed) then
                                if not IsEntityPlayingAnim(ped, 'move_action@generic@core', 'walk', 3) then 
                                    moving = true
                                    PlayAnim(ped, 'move_action@generic@core', 'walk', 8.0, -8.0, -1, 1, 0, false, false, false)
                                end
                            elseif IsPedSprinting(sourcePed) or IsPedRunning(sourcePed) then
                                if not IsEntityPlayingAnim(ped, 'move_action@generic@core', 'run', 3) then 
                                    moving = true
                                    PlayAnim(ped, 'move_action@generic@core', 'run', 8.0, -8.0, -1, 1, 0, false, false, false)
                                end
                            elseif moving then
                                moving = false
                                ClearPedTasks(ped)
                                PlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0, 0, 0, 0)
                            end
                            Wait(0)
                        end
                    end)
                end
            end
            CreateThread(function()
                local animLoop = true
                local hit = HitRegistry[identifier]
                HIDE_INTERACTIONS = true
                while HitRegistry[identifier] and HitInfo[identifier] and HitInfo[identifier].dragger and HitInfo[identifier].dragger == serverId  do
                    local playerPed = PlayerPedId()
                    local playerCoords = GetEntityCoords(playerPed)
                    if animLoop and not IsEntityPlayingAnim(playerPed, 'missfbi4prepp1', 'idle', 3) then 
                        PlayAnim(playerPed, 'missfbi4prepp1', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
                        animLoop = false
                        SetTimeout(1000, function()
                            animLoop = true
                        end)
                    end
                    ShowInteractText("[E] - " .. _L("stop_dragging"))
                    if IsControlJustPressed(0, 51) then
                        HitInteract(identifier, "stopDragging")
                        break
                    end
                    Wait(0)
                end
                HIDE_INTERACTIONS = false
            end)
        end
        if HitInfo[identifier].source == serverId then
            CreateThread(function()
                local ped = PlayerPedId()
                local sourcePed = GetPlayerPed(GetPlayerFromServerId(data.source))
                local boneIndex = GetPedBoneIndex(sourcePed, 0x60F2)
                local coords, rot = vector3(-0.25, 0.24, -0.5), vector3(0.0, 90.0, 0.0)
                AttachEntityToEntity(ped, sourcePed, boneIndex, coords.x, coords.y, coords.z, rot.x, rot.y, rot.z, 0, 0, 0, 1, 2, 1)
                local moving = false
                while HitInfo[identifier] and HitInfo[identifier].dragger and HitInfo[identifier].dragger == data.source do
                    sourcePed = GetPlayerPed(GetPlayerFromServerId(data.source))
                    ped = PlayerPedId()
                    if IsPedWalking(sourcePed) then
                        if not IsEntityPlayingAnim(ped, 'move_action@generic@core', 'walk', 3) then 
                            moving = true
                            PlayAnim(ped, 'move_action@generic@core', 'walk', 8.0, -8.0, -1, 1, 0, false, false, false)
                        end
                    elseif IsPedSprinting(sourcePed) or IsPedRunning(sourcePed) then
                        if not IsEntityPlayingAnim(ped, 'move_action@generic@core', 'run', 3) then 
                            moving = true
                            PlayAnim(ped, 'move_action@generic@core', 'run', 8.0, -8.0, -1, 1, 0, false, false, false)
                        end
                    elseif moving then
                        moving = false
                        ClearPedTasks(ped)
                        PlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0, 0, 0, 0)
                    end
                    Wait(0)
                end
                ClearPedTasksImmediately(PlayerPedId())
            end)
        end
    elseif data.type == "releaseHitTarget" then
        HitInfo[identifier].dragger = nil
        local playerPed = PlayerPedId()
        local serverId = GetPlayerServerId(PlayerId())
        if data.source == serverId then
            if HitInfo[identifier].netId then
                local ped = NetToPed(HitInfo[identifier].netId)
                if not NetworkHasControlOfEntity(ped) then
                    NetworkRequestControlOfEntity(ped)
                    local timeout = 500
                    while timeout > 0 and not NetworkHasControlOfEntity(ped) do
                        Wait(100)
                        timeout = timeout - 100
                    end
                end
                if ped and NetworkHasControlOfEntity(ped) then
                    DetachEntity(ped, true, true)
                    ClearPedTasks(ped)
                    FreezeEntityPosition(ped, true)
                end
            end
            ClearPedTasks(playerPed)
        end
        if HitInfo[identifier].source == serverId then
            local ped = PlayerPedId()
            ClearPedTasks(ped)
            DetachEntity(ped, true, true)
        end
    elseif data.type == "putHitInVehicle" then
        local playerPed = PlayerPedId()
        local serverId = GetPlayerServerId(PlayerId())
        if data.source == serverId then
            if HitInfo[identifier].netId then
                local ped = NetToPed(HitInfo[identifier].netId)
                if not NetworkHasControlOfEntity(ped) then
                    NetworkRequestControlOfEntity(ped)
                    local timeout = 500
                    while timeout > 0 and not NetworkHasControlOfEntity(ped) do
                        Wait(100)
                        timeout = timeout - 100
                    end
                end
                if ped and NetworkHasControlOfEntity(ped) then
                    local vehicle = NetToVeh(data.currentVehicle)
                    if vehicle then
                        FreezeEntityPosition(ped, false)
                        TaskWarpPedIntoVehicle(ped, vehicle, 2)
                    end
                end
            end
        end
        if HitInfo[identifier].source == serverId then
            local ped = PlayerPedId()
            local vehicle = NetToVeh(data.currentVehicle)
            if vehicle then
                FreezeEntityPosition(ped, false)
                TaskWarpPedIntoVehicle(ped, vehicle, 2)
            end
        end
    elseif data.type == "removeHitFromVehicle" then
        local playerPed = PlayerPedId()
        local serverId = GetPlayerServerId(PlayerId())
        if data.source == serverId then
            if HitInfo[identifier].netId then
                local ped = NetToPed(HitInfo[identifier].netId)
                if not NetworkHasControlOfEntity(ped) then
                    NetworkRequestControlOfEntity(ped)
                    local timeout = 500
                    while timeout > 0 and not NetworkHasControlOfEntity(ped) do
                        Wait(100)
                        timeout = timeout - 100
                    end
                end
                if ped then
                    ClearPedTasks(ped)
                    TaskLeaveVehicle(ped, NetToVeh(data.currentVehicle), 16)
                end
            end
        end
        if HitInfo[identifier].source == serverId then
            local ped = PlayerPedId()
            ClearPedTasksImmediately(ped)
            TaskLeaveVehicle(ped, NetToVeh(data.currentVehicle), 16)
        end
    end
end)

RegisterNetEvent("pickle_hitman:acceptHit", function(target)
    local hit = HitRegistry[target]

    CurrentHit = {
        id = target,
        npc = hit.npc,
        name = hit.targetname,
        image = hit.image,
        reward = hit.reward,
        description = hit.description,
        date = hit.datetime or 0,
    }
    SendNUIMessage({
        type = "setCurrentHit",
        currentHit = CurrentHit
    })
    if CurrentHit.npc then
        local locations = Config.NPCTargets.locations
        local location = locations[#locations > 1 and math.random(1, #locations) or 1]
        local blipCfg = Config.NPCTargets.blip
        local rngOffset = {1, 100}
        local rngScale = (math.random(rngOffset[1], rngOffset[2]) / rngOffset[2]) * (blipCfg.radius.size / 2)
        local rngCoords = location.coords + vector3(
            (math.random(1, 2) == 1 and 1 or -1) * rngScale,
            (math.random(1, 2) == 1 and 1 or -1) * rngScale,
            0
        )
        local targetBlip, targetRadius = CreateBlip({
            coords = rngCoords,
            label = blipCfg.labelPrefix .." ".. CurrentHit.name,
            category = 1,
            sprite = blipCfg.sprite,
            color = blipCfg.color,
            scale = blipCfg.scale,
            radius = blipCfg.radius,
        })
        CurrentHit.targetBlip = targetBlip
        CurrentHit.targetRadius = targetRadius
        local id = CurrentHit.id
        local scenario = GetNPCScenarioFromRisk(risk)
        CurrentHit.targetNPC = nil
        CreateThread(function()
            while CurrentHit and CurrentHit.id == id and not CurrentHit.targetNPC do 
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                local distance = #(playerCoords - location.coords)
                if distance < 100.0 then
                    CurrentHit.targetNPC = CreateNPC(GetHashKey(CurrentHit.npc.model), location.coords.x, location.coords.y, location.coords.z, location.heading, true, true)
                    local netId = PedToNet(CurrentHit.targetNPC)
                    if NetworkDoesNetworkIdExist(netId) then
                        SetTimeout(1000, function()
                            TriggerServerEvent("pickle_hitman:setCurrentHitNPC", netId)
                        end)
                    end
                    if scenario == "fleeVehicle" then
                        local vehicleModel = Config.NPCTargets.vehicles[#Config.NPCTargets.vehicles > 1 and math.random(1, #Config.NPCTargets.vehicles) or 1]
                        local roadFound, roadCoords, roadHeading = GetClosestVehicleNodeWithHeading(location.coords.x, location.coords.y, location.coords.z, 0, 100.0, 100.0)
                        if roadFound and #(roadCoords - location.coords) < 100.0 then
                            CurrentHit.vehicle = CreateVeh(vehicleModel, roadCoords.x, roadCoords.y, roadCoords.z, roadHeading, true, true)
                            SetVehicleEngineHealth(CurrentHit.vehicle, 500.0)
                        end
                    end
                    break
                end
                Wait(1000)
            end
            if not CurrentHit or CurrentHit.id ~= id or not CurrentHit.targetNPC then
                CancelCurrentHit()
                return
            end
            PerformScenario(scenario)                
        end)
    end
end)

RegisterNetEvent("pickle_hitman:dutyState", function(state)
    if LOCAL_ON_DUTY == state then return end
    LOCAL_ON_DUTY = state
    RenderDutyLocations()
    UpdatePermissions(LOCAL_PERMISSIONS)
    if not LOCAL_ON_DUTY then 
        ToggleOutfit(false)
        for k,v in pairs(HitInfo) do 
            RemoveHitTargetOptions(k)
        end
        if Config.UseTarget then
            RemoveTargetGlobalVehicle({{ name = "vehicle" }})
        end
        return
    else
        ToggleOutfit(true)
        for k,v in pairs(HitInfo) do 
            ShowHitTargetOptions(k)
        end
        if Config.UseTarget then
            AddTargetGlobalVehicle({{ name = "vehicle", label = _L("hit_interact_vehicle"), onSelect = function() VehicleInteract() end }})
        end
    end
    CreateThread(function()
        local inVehicle = false
        local brakeTime = -1
        local showInteract = false
        while LOCAL_ON_DUTY do
            local wait = 1000
            if displayingText or (not inVehicle and IsPedInAnyVehicle(PlayerPedId(), false)) then
                inVehicle = true
            elseif inVehicle then
                local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                if not DoesEntityExist(vehicle) then
                    inVehicle = false
                    displayingText = false
                    brakeTime = -1
                else
                    wait = 0
                    if GetEntitySpeed(vehicle) < 1.0 and IsControlPressed(0, 22) then
                        brakeTime = brakeTime + 1
                    elseif brakeTime > 0 or brakeTime == -1 then
                        if brakeTime < 20 and brakeTime > 0 then
                            ExecuteCommand("hits")
                        elseif brakeTime == -1 then
                            showInteract = true
                            SetTimeout(3000, function()
                                showInteract = false
                            end)
                        end
                        brakeTime = 0
                    end
                end
                if showInteract then
                    wait = 0
                    ShowInteractText(_L("hit_vehicle_info"))
                end
            end
            Wait(wait)
        end
    end)
end)

RegisterNetEvent("pickle_hitman:refreshHitPosition", function(data)
    local coords = data.coords
    if CurrentHit and CurrentHit.id == data.id then
        if HitInfo[data.id] and HitInfo[data.id].isDetained then
            if CurrentHit.targetBlip or CurrentHit.targetRadius then
                RemoveBlip(CurrentHit.targetBlip)
                RemoveBlip(CurrentHit.targetRadius)
                CurrentHit.targetBlip = nil
                CurrentHit.targetRadius = nil
            end
        else
            local blipCfg = Config.PlayerHits.blip
            local rngOffset = {1, 100}
            local rngScale = (math.random(rngOffset[1], rngOffset[2]) / rngOffset[2]) * (blipCfg.radius.size / 2)
            local rngCoords = coords + vector3(
                (math.random(1, 2) == 1 and 1 or -1) * rngScale,
                (math.random(1, 2) == 1 and 1 or -1) * rngScale,
                0
            )
            if CurrentHit.targetBlip and CurrentHit.targetRadius then
                SetBlipCoords(CurrentHit.targetBlip, rngCoords)
                SetBlipCoords(CurrentHit.targetRadius, rngCoords)
            else
                RemoveBlip(CurrentHit.targetBlip)
                RemoveBlip(CurrentHit.targetRadius)
                local targetBlip, targetRadius = CreateBlip({
                    coords = rngCoords,
                    label = blipCfg.labelPrefix .." ".. CurrentHit.name,
                    category = 1,
                    sprite = blipCfg.sprite,
                    color = blipCfg.color,
                    scale = blipCfg.scale,
                    radius = blipCfg.radius,
                })
                CurrentHit.targetBlip = targetBlip
                CurrentHit.targetRadius = targetRadius
            end
        end
    end
end)

RegisterNUICallback("addPlayerToHit", function(data, cb)
    TriggerServerEvent("pickle_hitman:addPlayerToHit", {
        source = data.player.source,
        identifier = data.player.identifier, 
        image = data.player.image, 
        reward = data.player.reward, 
    })
    cb(true)
end)

RegisterNUICallback("acceptHit", function(data, cb)
    TriggerServerEvent("pickle_hitman:acceptHit", data.hit.id)
    cb(true)
end)

RegisterNUICallback("declineHit", function(data, cb)
    TriggerServerEvent("pickle_hitman:removeHit", data.hit.id)
    cb(true)
end)

RegisterNUICallback("cancelCurrentHit", function(data, cb)
    SendNUIMessage({
        type = "updateHit",
        hit = CurrentHit
    })
    TriggerServerEvent("pickle_hitman:cancelCurrentHit")
    cb(true)
end)

CreateThread(function()
    if Config.UseTarget then return end
    while true do 
        local wait = 1000
        local closestHit = {}
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        for k,v in pairs(HitInfo) do 
            local ped
            if v.netId and NetworkDoesNetworkIdExist(v.netId) then
                ped = NetToPed(v.netId)
                if not DoesEntityExist(ped) then
                    ped = nil
                end
            elseif string.sub(k, 1, 4) ~= "npc:" then
                local hit = HitRegistry[k]
                if hit and hit.source and IsPlayerInRange(hit.source, false) then
                    ped = GetPlayerPed(GetPlayerFromServerId(hit.source))
                end
            end
            if ped then
                local coords = GetEntityCoords(ped)
                local distance = #(playerCoords - coords)
                if distance < 2 and (not closestHit.distance or distance < closestHit.distance) then
                    closestHit = {
                        id = k,
                        distance = distance,
                        coords = coords,
                    }
                end
            end
        end
        if closestHit.id and not IsPedInAnyVehicle(playerPed, false) and not HIDE_INTERACTIONS then
            ShowInteractText("[E] - " .. _L("hit_interact_target"))
            if IsControlJustPressed(0, 51) then
                ShowHitTargetMenu(closestHit.id)
            end
            wait = 0
        end
        Wait(wait)
    end    
end)

CreateThread(function()
    if Config.UseTarget then
        local onSelect = function(interactType, source)
            for k,v in pairs(HitInfo) do
                if v.source == source then
                    local enabledOptions = ShowHitTargetOptions(k)
                    if enabledOptions[interactType] then
                        HitInteract(k, interactType)
                    end
                end
            end
        end
        local canInteract = function(interactType, source)
            for k,v in pairs(HitInfo) do
                if v.source == source then
                    local enabledOptions = ShowHitTargetOptions(k)
                    return (enabledOptions[interactType] or false)
                end
            end
        end
        AddTargetGlobalPlayer({
            { name = "detain", label = _L("hit_interact_detain"), interactCheck = function(...) return canInteract("detain", ...) end, onSelected = function(...) onSelect("detain", ...) end },
            { name = "drag", label = _L("hit_interact_drag"), interactCheck = function(...) return canInteract("drag", ...) end, onSelected = function(...) onSelect("drag", ...) end },
            { name = "custody", label = _L("hit_interact_custody"), interactCheck = function(...) return canInteract("custody", ...) end, onSelected = function(...) onSelect("custody", ...) end }        
        })
    end
    local modifiers = {
        ["weapon_stungun"] = {},
        ["weapon_stungun_mp"] = {}
    }
    for k,v in pairs(modifiers) do
        v.default = GetWeaponDamageModifier(k)
        SetWeaponDamageModifier(k, 0.0)
    end
end)

local hitInteract = {holding = false, ticks = 0}

RegisterCommand("+openHitInteraction", function() 
    if not CurrentHit then return end
    hitInteract.holding = true
    CreateThread(function()
        while hitInteract.holding do
            if GetEntitySpeed(PlayerPedId()) > 0.5 then
                hitInteract.ticks = 0
            else
                hitInteract.ticks = hitInteract.ticks + 1
                if hitInteract.ticks > 50 then
                    SendNUIMessage({
                        type = "setInteracting",
                        data = true
                    })
                    SetNuiFocus(true, true)
                    hitInteract.ticks = 0
                end
            end
            Wait(0)
        end
    end)
end)

RegisterCommand("-openHitInteraction", function() 
    hitInteract.holding = false
    hitInteract.ticks = 0
end)

RegisterKeyMapping("+openHitInteraction", "Open Hit Interaction", "keyboard", "LSHIFT")

RegisterNUICallback("returnToGame", function(data, cb)
    SetNuiFocus(false, false)
    cb(true)
end)