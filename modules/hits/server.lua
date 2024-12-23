HitRegistry = {}
HitInfo = {}
HitmanPlayers = {}

function AddHitToRegistry(hit, ignoreSync, insertSQL) 
    if not hit.target then
        dprint("Hit missing target")
        return
    end
    if HitRegistry[hit.target] then
        dprint("Hit already exists for target: " .. hit.target)
        return
    end
    HitRegistry[hit.target] = {
        source = GetSourceFromIdentifier(hit.target),
        npc = hit.npc or nil,
        target = hit.target,
        targetname = hit.targetname,
        image = hit.image or "NO_IMAGE",
        issuer = hit.issuer,
        reward = hit.reward,
        description = hit.description,
        datetime = hit.datetime or os.time(),
    }
    if insertSQL then
        MySQL.Async.execute("INSERT INTO pickle_hitman_hits (target, targetname, image, issuer, reward, description, datetime) VALUES (@target, @targetname, @image, @issuer, @reward, @description, @datetime)", {
            ["@target"] = hit.target,
            ["@targetname"] = hit.targetname,
            ["@image"] = hit.image or "NO_IMAGE",
            ["@issuer"] = hit.issuer,
            ["@reward"] = hit.reward,
            ["@description"] = hit.description,
            ["@datetime"] = hit.datetime and os.date("%Y-%m-%d %H:%M:%S", hit.datetime) or nil,
        }, function(rowsChanged)
            dprint("Inserted hit into SQL: " .. rowsChanged)
        end)
    end
    if ignoreSync then return end
    TriggerClientEvent("pickle_hitman:addHit", -1, hit.target, HitRegistry[hit.target])
end

exports("AddHitToRegistry", function(hit)
    AddHitToRegistry(hit, false, true)
end)

function RemoveHitFromRegistry(target, ignoreSync, deleteSQL, source)
    if not HitRegistry[target] then
        dprint("Hit does not exist for target: " .. target)
        return
    end
    if HitRegistry[target].npc then
        GenerateNPCHit(false)
    end
    HitRegistry[target] = nil
    HitInfo[target] = nil
    for k,v in pairs(HitmanPlayers) do
        if v.target == target then
            HitmanPlayers[k] = nil
        end
    end
    if source then
        TriggerClientEvent("pickle_hitman:setHitState", -1, target, {
            type = "removeHitTarget",
            source = source,
        })
    end
    if deleteSQL then
        MySQL.Async.execute("DELETE FROM pickle_hitman_hits WHERE target = @target", {
            ["@target"] = target,
        }, function(rowsChanged)
            dprint("Deleted hit from SQL: " .. rowsChanged)
        end)
    end
    if ignoreSync then return end
    TriggerClientEvent("pickle_hitman:removeHit", -1, target)
end

exports("RemoveHitFromRegistry", function(target)
    RemoveHitFromRegistry(target, false, true)
end)

function UpdateHit(target, hit)
    if not HitRegistry[target] then
        dprint("Hit does not exist for target: " .. target)
        return
    end
    HitRegistry[target] = hit
    TriggerClientEvent("pickle_hitman:updateHit", -1, target, hit)
end

function GenerateNPCHit(ignoreSync)
    local riskCfg = Config.NPCTargets
    local reasons = riskCfg.reasons
    local target = nil
    local gender = (math.random(1, 2) == 1 and "male" or "female")
    local genderCfg = Config.NPCTargets.characters[gender]
    local firstname = genderCfg.firstnames[math.random(1, #genderCfg.firstnames)]
    local lastname = Config.NPCTargets.characters.lastnames[math.random(1, #Config.NPCTargets.characters.lastnames)]
    local model = genderCfg.peds[math.random(1, #genderCfg.peds)]
    repeat
        target = "npc:" .. math.random(1, 999999)
    until not HitRegistry[target]
    HitRegistry[target] = {
        target = target,
        targetname = firstname .. " " .. lastname,
        npc = {
            model = model,
        },
        image = "https://cfx-nui-pickle_hitman/nui/images/"..model..".png",
        issuer = "system",
        reward = math.random(Config.NPCTargets.rewardRange[1], Config.NPCTargets.rewardRange[2]),
        description = riskCfg.reasons[math.random(1, #riskCfg.reasons)] or "Unknown Reason.",
        datetime = os.time(),
    }
    if ignoreSync then return end
    TriggerClientEvent("pickle_hitman:addHit", -1, target, HitRegistry[target])
end

exports("GenerateNPCHit", function()
    GenerateNPCHit(false)
end)

function GetPlayerCurrentHit(source)
    for k,v in pairs(HitmanPlayers) do
        if k == source then
            return v.target, HitRegistry[v.target]
        end
    end
end

exports("GetPlayerCurrentHit", GetPlayerCurrentHit)

function CancelHit(target, source, remove)
    local hit = HitRegistry[target]
    if remove then
        RemoveHitFromRegistry(target, false, true)
    else
        hit.hitmanId = nil
        UpdateHit(target, hit)
    end
    if source then
        HitmanPlayers[source] = nil
        local stillActive = false
        for k,v in pairs(HitmanPlayers) do
            if v.target == target then
                stillActive = true
            end
        end
        if not stillActive then
            HitInfo[target] = nil
        end
    else
        for k,v in pairs(HitmanPlayers) do
            if v.target == target then
                HitmanPlayers[k] = nil
            end
        end
        HitInfo[target] = nil
    end
    TriggerClientEvent("pickle_hitman:setHitState", -1, target, {
        type = "removeHitTarget"
    })
end

exports("CancelHit", CancelHit)

function CompleteHit(identifier, source)
    local hit = HitRegistry[identifier]
    local hitInfo = HitInfo[identifier]  
    if not hit or not hitInfo then return end
    local reward = hit.reward
    AddMoney(source, math.floor(reward))
    ShowNotification(source, _L("hit_reward_self", NumberWithCommas(reward)))
    HitmanPlayers[source] = nil
    RemoveHitFromRegistry(identifier, false, true, source)
end

function IsPlayerHitman(source)
    return HitmanPlayers[source] ~= nil
end

function GetNPCTargetHitman(identifier)
    for k,v in pairs(HitmanPlayers) do
        if v.target == identifier then
            return k
        end
    end
end

exports("IsPlayerHitman", IsPlayerHitman)

RegisterNetEvent("pickle_hitman:setCurrentHitNPC", function(netId)
    local source = source
    local currentHitId, currentHit = GetPlayerCurrentHit(source)
    if not currentHit then return ShowNotification(source, _L("no_current_hit")) end
    if HitInfo[currentHitId] then return end
    HitInfo[currentHitId] = {
        netId = netId,
    }
    CreateThread(function()
        while HitRegistry[currentHitId] and HitInfo[currentHitId] do 
            Wait(5000)
        end
        local entity = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(entity) then
            SetTimeout(5000, function()
                DeleteEntity(entity)
            end)
        end
    end)
    TriggerClientEvent("pickle_hitman:setHitState", -1, currentHitId, {
        type = "registerHitTarget",
        netId = netId,
    })
end)

RegisterNetEvent("pickle_hitman:removeHit", function(target)
    local permissions = GetPlayerPermissions(source)
    local hit = HitRegistry[target]
    if not hit then return ShowNotification(source, _L("hit_not_exist")) end
    if string.sub(target, 1, 4) == "npc:" then return ShowNotification(source, _L("hit_remove_is_npc")) end
    if not Config.HitPermissions.cancelHits(source, hit, true) then
        return ShowNotification(source, _L("no_permission_hit"))
    end
    ShowNotification(source, _L("hit_canceled", hit.targetname))
    RemoveHitFromRegistry(target, false, true)
end)

RegisterNetEvent("pickle_hitman:acceptHit", function(target)
    local source = source
    local target = target
    if target == nil then -- TODO: REMOVE THIS WHEN DONE
        for k,v in pairs(HitRegistry) do
            target = k
            break
        end
        if target == nil then
            return ShowNotification(source, _L("hit_not_exist"))
        end
    end
    local hit = HitRegistry[target]
    if not hit then return ShowNotification(source, _L("hit_not_exist")) end
    if target == GetIdentifier(source) then return ShowNotification(source, _L("hit_cant_self")) end
    if HitmanPlayers[source] then return ShowNotification(source, _L("hit_already_accepted")) end
    if not Config.HitPermissions.acceptHits(source, hit, true) then
        return ShowNotification(source, _L("no_permission_hit"))
    end
    HitmanPlayers[source] = {
        target = target
    }
    ShowNotification(source, _L("hit_accepted", hit.targetname))
    if hit.npc then
        hit.hitmanId = source
    end
    UpdateHit(target, hit)
    if not hit.npc then
        HitInfo[target] = {
            source = hit.source,
            currentVehicle = nil,
        }
        TriggerClientEvent("pickle_hitman:setHitState", -1, target, {
            type = "registerHitTarget",
            source = hit.source,
        })
    end
    TriggerClientEvent("pickle_hitman:acceptHit", source, target)
end)

RegisterNetEvent("pickle_hitman:cancelCurrentHit", function(fail)
    local source = source
    local currentHitId, currentHit = GetPlayerCurrentHit(source)
    if not currentHit then return ShowNotification(source, _L("no_current_hit")) end
    if not fail then
        ShowNotification(source, _L("hit_canceled", currentHit.targetname))
    end
    CancelHit(currentHitId, source, false)
end)

RegisterNetEvent("pickle_hitman:addPlayerToHit", function(data)
    local source = source
    local permissions = GetPlayerPermissions(source)
    local target = GetIdentifier(data.source)
    if not target or not data.reward or data.reward < 0 or HitRegistry[target] then return end
    local money = GetMoney(source)
    if money < data.reward then return ShowNotification(source, _L("hit_not_enough_money")) end
    local hit = {
        target = target,
        targetname = GetPlayerCharacterName(data.source),
        image = data.image,
        issuer = GetIdentifier(source),
        reward = data.reward or 0,
        description = data.description,
        datetime = os.time(),
        risk = 3,
    }
    if not Config.HitPermissions.placeHits(source, hit, true) then return ShowNotification(source, _L("no_permission_hit")) end
    RemoveMoney(source, data.reward)
    AddHitToRegistry(hit, false, true)
    ShowNotification(source, _L("hit_place_title", NumberWithCommas(data.reward)))
end)

RegisterNetEvent("pickle_hitman:completeHit", function()
    local currentHit = GetPlayerCurrentHit(source)
    if not currentHit then return ShowNotification(source, _L("no_current_hit")) end
    if not HitInfo[currentHit] then return end
    if HitInfo[currentHit].deceased then
        CompleteHit(currentHit, source)
    else
        ShowNotification(source, _L("hit_interact_must_dead"))
    end
end)

CreateThread(function()
    while true do 
        for k,v in pairs(HitInfo) do 
            if v.netId then
                local hitman = GetNPCTargetHitman(k)
                local entity = NetworkGetEntityFromNetworkId(v.netId)
                if not hitman then
                    CancelHit(k)
                elseif not DoesEntityExist(entity) then
                    CancelHit(k)
                    ShowNotification(hitman, _L("hit_target_escaped"))
                elseif not v.deceased then
                    local health = GetEntityHealth(entity)
                    if health <= 0 then
                        v.deceased = true
                        TriggerClientEvent("pickle_hitman:onTargetDeath", hitman, k)
                    end
                end
            end
        end
        Wait(2000)
    end
end)

CreateThread(function()
    if not Config.PlayerHits.blip.enabled then return end
    while true do
        for k,v in pairs(HitInfo) do 
            if v.source then
                local hit = HitRegistry[k]
                for hitmanSource,hitman in pairs(HitmanPlayers) do
                    if hitman.target == k then
                        local ped = GetPlayerPed(v.source)
                        TriggerClientEvent("pickle_hitman:refreshHitPosition", hitmanSource, {
                            id = k,
                            coords = GetEntityCoords(ped),
                        })
                    end
                end
            end
        end
        Wait((Config.PlayerHits.blip.refreshTime or 10) * 1000)
    end
end)

CreateThread(function()
    for i=1, Config.NPCTargets.maxNPCTargets do
        GenerateNPCHit(true, ignoreSync)
    end
end)

AddEventHandler("onPlayerDropped", function()
    local source = source
    local identifier = GetPlayerIdentifier(source)
    local currentHitId, currentHit = GetPlayerCurrentHit(source)
    if currentHit then
        UpdateHit(currentHitId, currentHit)
    end
    local hit = HitRegistry[identifier]
    if hit then
        hit.source = nil
        UpdateHit(identifier, hit)
    end
    HitmanPlayers[source] = nil
end)