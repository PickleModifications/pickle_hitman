local HitInfo = {}
HitRegistry = {}
DutyInteractions = {}
HIDE_INTERACTIONS = false

function HitsToArray(hits)
    local hitsArray = {}

    for k, v in pairs(hits) do
        table.insert(hitsArray, {
            id = v.target,
            source = v.source,
            hitmanId = v.hitmanId,
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

function StartHitBurialMission()
    if not CurrentHit then return end
    CurrentHit.objective = _L("hit_objective_bury_body")
    ShowNotification(CurrentHit.objective)
    SendNUIMessage({
        type = "setCurrentHit",
        currentHit = CurrentHit
    })
    CreateThread(function()
        local id = CurrentHit.id
        local locations = {}
        for i=1, #Config.Burial.locations do 
            local location = Config.Burial.locations[i]
            local newLocation = {}
            if Config.Burial.blip.enabled then
                newLocation.blip = CreateBlip({
                    coords = location.coords,
                    label = Config.Burial.blip.label,
                    category = Config.Burial.blip.category,
                    sprite = Config.Burial.blip.sprite,
                    color = Config.Burial.blip.color,
                    scale = Config.Burial.blip.scale,
                    radius = Config.Burial.blip.radius,
                })
            end
            locations[#locations + 1] = newLocation
        end
        while CurrentHit and CurrentHit.id == id do
            Wait(1000)
        end
        for i=1, #locations do 
            if locations[i].blip then
                RemoveBlip(locations[i].blip)
            end
        end
    end)
end

function OnHitDeath()
    if not CurrentHit then return end
    CurrentHit.objective = _L("hit_objective_take_photo")
    CurrentHit.requestConfirmation = true
    CurrentHit.confirmedTarget = false
    ShowNotification(CurrentHit.objective)
    SendNUIMessage({
        type = "setCurrentHit",
        currentHit = CurrentHit
    })
    local id = CurrentHit.id
    CreateThread(function()
        local confirmed = false
        while CurrentHit and CurrentHit.id == id do
            if CurrentHit.confirmedTarget then
                confirmed = true
                usingCamera = false
                if CurrentHit.npc then
                    StartHitBurialMission()
                else
                    TriggerServerEvent("pickle_hitman:completeHit", CurrentHit.id)
                end
                break
            end
            Wait(1000)
        end
    end)
end

function PerformScenario(scenario)
    local id = CurrentHit.id
    -- SetTimeout(1000, function()
    --     SetEntityHealth(CurrentHit.targetNPC, 0)
    -- end)
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

function RevivePed(ped)
    local coords = GetEntityCoords(PlayerPedId())
    ResurrectPed(ped)
    SetEntityHealth(ped, 200)
    SetEntityCoords(ped, coords.x, coords.y, coords.z + 0.5)
    ClearPedTasksImmediately(ped)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
end

function VehicleInteract()
    if not CurrentHit then return false end
    local vehicle = GetClosestVehicle()
    local netId = VehToNet(vehicle)
    if not netId then return false end
    if not CurrentHit.confirmedTarget then return ShowNotification(_L("hit_interact_must_confirm")) end
    if CurrentHit.insideVehicle then
        local vehicle = CurrentHit.insideVehicle
        DetachEntity(CurrentHit.targetNPC, true, true)
        local boneIndex = GetEntityBoneIndexByName(vehicle, "boot")
        local boneCoords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
        local offset = GetOffsetFromEntityGivenWorldCoords(vehicle, boneCoords.x, boneCoords.y, boneCoords.z)
        local worldCoords = GetOffsetFromEntityInWorldCoords(vehicle, offset.x, offset.y - 1.0, offset.z - 0.5)
        SetEntityCoords(CurrentHit.targetNPC, worldCoords.x, worldCoords.y, worldCoords.z)
        ClearPedTasksImmediately(CurrentHit.targetNPC)
        SetEntityHealth(CurrentHit.targetNPC, 0)
        CurrentHit.insideVehicle = nil
    else
        if CurrentHit.carrying then
            CurrentHit.carrying = false
            SetTimeout(100, function()
                VehicleInteract()
            end)
        else
            CurrentHit.insideVehicle = vehicle
            RevivePed(CurrentHit.targetNPC)
            local boneIndex = GetEntityBoneIndexByName(vehicle, "boot")
            local boneCoords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
            local offset = GetOffsetFromEntityGivenWorldCoords(vehicle, boneCoords.x, boneCoords.y, boneCoords.z)
            AttachEntityToEntity(CurrentHit.targetNPC, vehicle, 0, offset.x, offset.y, offset.z, 0.0, 0.0, 0.0, false, false, false, false, 20, true)
            CreateThread(function()
                while CurrentHit and CurrentHit.insideVehicle do 
                    if not IsEntityPlayingAnim(CurrentHit.targetNPC, "timetable@floyd@cryingonbed@base", "base", 3) then
                        PlayAnim(CurrentHit.targetNPC, "timetable@floyd@cryingonbed@base", "base", 8.0, -8.0, -1, 1, 0, 0, 0, 0)
                    end
                    Wait(100)
                end
            end)
        end
    end
    return true
end

function HitInteract(identifier, interactType)
    local entity = PlayerPedId()
    local data = nil
    if interactType == "carry" then
        if not CurrentHit or CurrentHit.carrying then return end
        if CurrentHit.insideVehicle then return ShowNotification(_L("hit_interact_must_outcar")) end
        if not CurrentHit.confirmedTarget then return ShowNotification(_L("hit_interact_must_confirm")) end
        if not NetworkDoesNetworkIdExist(HitInfo[identifier].netId) then return end

        local ped = NetToPed(HitInfo[identifier].netId)
        if not DoesEntityExist(ped) or GetEntityHealth(ped) > 0 then return ShowNotification(_L("hit_interact_must_dead")) end
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        RevivePed(ped)
        ClearPedTasksImmediately(playerPed)

        CurrentHit.carrying = true
        HIDE_INTERACTIONS = true
        CreateThread(function()
            AttachEntityToEntity(ped, playerPed, 0, 0.27, 0.15, 0.63, 0.5, 0.5, 180, false, false, false, false, 2, true)
            while CurrentHit and CurrentHit.carrying and CurrentHit.id == identifier do
                local playerPed = PlayerPedId()
                local coords = GetEntityCoords(playerPed)
                if not IsEntityPlayingAnim(playerPed, "missfinale_c2mcs_1", "fin_c2_mcs_1_camman", 3) then
                    PlayAnim(playerPed, "missfinale_c2mcs_1", "fin_c2_mcs_1_camman", 8.0, -8.0, -1, 49, 0, 0, 0, 0)
                    Wait(10)
                end
                if not IsEntityPlayingAnim(ped, "nm", "firemans_carry", 3) then
                    PlayAnim(ped, "nm", "firemans_carry", 8.0, -8.0, -1, 1, 0, 0, 0, 0)
                    Wait(10)
                end
                DisableControlAction(0, 140, true) -- Disable melee attack light
                DisableControlAction(0, 141, true) -- Disable melee attack heavy
                DisableControlAction(0, 142, true) -- Disable melee attack alternate
                DisableControlAction(0, 75, true)  -- Disable exit vehicle
                DisableControlAction(0, 23, true) -- Disable enter vehicle
                local nearestBurial = nil
                for i=1, #Config.Burial.locations do 
                    local burial = Config.Burial.locations[i]
                    local distance = #(coords - burial.coords)
                    if not nearestBurial or distance < nearestBurial.distance then
                        nearestBurial = { coords = burial.coords, distance = distance }
                    end
                end
                if nearestBurial and nearestBurial.distance < 2.5 then
                    ShowInteractText("[E] - " .. _L("hit_interact_bury_body", NumberWithCommas(CurrentHit.reward)))
                    if IsControlJustPressed(1, 51) then
                        TriggerServerEvent("pickle_hitman:completeHit", identifier)
                        break
                    end
                else
                    ShowInteractText("[E] - " .. _L("stop_carrying_body"))
                    if IsControlJustPressed(1, 51) then
                        CurrentHit.carrying = false
                        break
                    end
                end
                Wait(0)
            end
            HIDE_INTERACTIONS = false
            ClearPedTasks(playerPed)
            ClearPedTasks(ped)
            DetachEntity(ped, true, true)
            SetEntityHealth(ped, 0)
        end)
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
    if hitInfo.netId then
        options[#options + 1] = { name = "carry", label = _L("hit_interact_carry"), onSelect = function() HitInteract(identifier, "carry") end }
        enabledOptions.carry = true
        AddTargetNetworkId(hitInfo.netId, options)
    end
    return enabledOptions
end

function RemoveHitTargetOptions(identifier)
    if not Config.UseTarget then return end
    local hitInfo = HitInfo[identifier]
    if not hitInfo then return end
    local options = {
        { name = "carry", label = _L("hit_interact_carry") },
        { name = "vehicle", label = _L("hit_interact_vehicle") },
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
    options[#options + 1] = { name = "carry", title = _L("hit_interact_carry"), onSelect = function() HIDE_INTERACTIONS = false; HitInteract(identifier, "carry") end }
    options[#options + 1] = { name = "vehicle", title = _L("hit_interact_vehicle"), close = false, onSelect = function() 
        if not VehicleInteract() then
            return ShowNotification(_L("hit_no_vehicle"))
        end
        HIDE_INTERACTIONS = false
        lib.hideContext()
    end}
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
        type = "setCurrentHit",
        currentHit = CurrentHit
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
        }
        if CurrentHit and CurrentHit.id == identifier then
            if Config.UseTarget then
                AddTargetGlobalVehicle({{ name = "vehicle", label = _L("hit_interact_vehicle"), onSelect = function() VehicleInteract() end }})
            end
            ShowHitTargetOptions(identifier)
        end
    elseif data.type == "removeHitTarget" then
        if Config.UseTarget then
            RemoveTargetGlobalVehicle({{ name = "vehicle" }})
        end
        RemoveHitTargetOptions(identifier)
        HitInfo[identifier] = nil
        if CurrentHit and CurrentHit.id == identifier then
            CancelCurrentHit()
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
        objective = _L("hit_objective_find_target"),
        requestConfirmation = false,
        confirmedTarget = false,
    }
    ShowNotification(CurrentHit.objective)
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
                if distance < 200.0 then
                    if not CurrentHit.targetNPC then
                        CurrentHit.targetNPC = CreateNPC(GetHashKey(CurrentHit.npc.model), location.coords.x, location.coords.y, location.coords.z, location.heading, true, true)
                        local netId = PedToNet(CurrentHit.targetNPC)
                        if NetworkDoesNetworkIdExist(netId) then
                            SetTimeout(1000, function()
                                TriggerServerEvent("pickle_hitman:setCurrentHitNPC", netId)
                            end)
                        end
                        TaskWanderStandard(CurrentHit.targetNPC, 10.0, 10)
                    elseif distance < 20.0 then
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

RegisterNetEvent("pickle_hitman:refreshHitPosition", function(data)
    local coords = data.coords
    if CurrentHit and CurrentHit.id == data.id then
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
end)

RegisterNetEvent("pickle_hitman:onTargetDeath", function(identifier)
    if CurrentHit and CurrentHit.id == identifier then
        OnHitDeath()
    end
end)

RegisterNUICallback("addPlayerToHit", function(data, cb)
    TriggerServerEvent("pickle_hitman:addPlayerToHit", {
        source = data.player.source,
        identifier = data.player.identifier, 
        image = data.player.image, 
        reward = data.player.reward, 
        description = data.player.description,
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

RegisterNUICallback("cancelContract", function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent("pickle_hitman:cancelCurrentHit")
    cb(true)
end)

RegisterNUICallback("useCamera", function(data, cb)     
    SetNuiFocus(false, false)   
    if not CurrentHit then return end
    if CurrentHit.npc then
        CameraLoop({trackType = "ped", netId = CurrentHit.targetNPC and PedToNet(CurrentHit.targetNPC) or -1})
    else
        CameraLoop({trackType = "player", serverId = HitInfo[CurrentHit.id].source})
    end
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
local lastCoords

function GetActualEntitySpeed(entity)
    local newCoords = GetEntityCoords(entity)
    local speed = #(newCoords - (lastCoords or newCoords)) * 10
    lastCoords = newCoords
    return speed
end

RegisterCommand("+openHitInteraction", function() 
    if not CurrentHit or usingCamera then return end
    hitInteract.holding = true
    hitInteract.ticks = 0
    CreateThread(function()
        while CurrentHit and hitInteract.holding do
            if GetActualEntitySpeed(PlayerPedId()) > 0.01 or IsPlayerClimbing(PlayerId()) or IsPedJumping(PlayerPedId()) or IsPedFalling(PlayerPedId()) then
                hitInteract.ticks = 0
            else
                hitInteract.ticks = hitInteract.ticks + 1
                if hitInteract.ticks > 25 then
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