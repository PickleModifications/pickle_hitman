function GetAllPlayers(source, ignoreSelf)
    local players = {}
    for _, player in ipairs(GetPlayers()) do
        if not source or not ignoreSelf or tonumber(player) ~= tonumber(source) then
            table.insert(players, {
                source = tonumber(player),
                identifier = GetIdentifier(player),
                name = GetPlayerCharacterName(player),
            })
        end
    end
    return players
end

function GetPlayerPermissions(source)
    return {
        placeHits = Config.HitPermissions.placeHits(source, nil, false),
        acceptHits = Config.HitPermissions.acceptHits(source, nil, false),
        cancelHits = Config.HitPermissions.cancelHits(source, nil, false),
    }
end

function ResyncPermissions(source)
    local permissions = GetPlayerPermissions(source)
    TriggerClientEvent("pickle_hitman:resyncPermissions", source, permissions)
end

function GetExtraQueries(source, extraQueries)
    local queries = {}
    if extraQueries["nearbyPlayers"] then
        queries["nearbyPlayers"] = GetNearbyPlayers(source)
    end
    return queries
end

function GetNearbyPlayers(source)
    local players = GetAllPlayers(source, true)
    local nearbyPlayers = {}
    local sourceCoords = GetEntityCoords(GetPlayerPed(source))
    for i=1, #players do 
        local target = players[i].source
        local targetCoords = GetEntityCoords(GetPlayerPed(target))
        local distance = #(sourceCoords - targetCoords)
        if distance < 5.0 and tonumber(target) ~= tonumber(source) then
            table.insert(nearbyPlayers, players[i])
        end
    end
    return nearbyPlayers
end

RegisterCallback("pickle_hitman:getPlayers", function(source, cb, ignoreSelf)
    cb(GetAllPlayers(source, ignoreSelf))
end)

RegisterCallback("pickle_hitman:getNearbyPlayers", function(source, cb)
    cb(GetNearbyPlayers(source))
end)

RegisterCallback("pickle_hitman:getPermissions", function(source, cb, extraQueries)
    local permissions = GetPlayerPermissions(source)
    cb(permissions, GetExtraQueries(source, extraQueries))
end)

RegisterNetEvent("pickle_hitman:initializePlayer", function()
    local identifier = GetIdentifier(source)
    local hit = HitRegistry[identifier]
    if hit then
        hit.source = source
        UpdateHit(identifier, hit)
    end
    TriggerClientEvent("pickle_hitman:initializePlayer", source, {
        identifier = GetIdentifier(source),
        hits = HitRegistry,
        permissions = GetPlayerPermissions(source),
    })
end)

AddEventHandler("onResourceStart", function(name)
    if name == GetCurrentResourceName() then 
        SetTimeout(2000, function()
            TriggerClientEvent("pickle_hitman:onRestart", -1)
        end)
    end
end)

MySQL.ready(function()
    MySQL.Sync.execute([[CREATE TABLE IF NOT EXISTS pickle_hitman_hits (
        target VARCHAR(255) PRIMARY KEY NOT NULL,
        targetname VARCHAR(255) NOT NULL,
        image VARCHAR(255) NOT NULL,
        issuer VARCHAR(255) NOT NULL,
        reward INT NOT NULL,
        description TEXT NOT NULL,
        datetime DATETIME DEFAULT CURRENT_TIMESTAMP
    )]], {})
    MySQL.Async.fetchAll("SELECT * FROM pickle_hitman_hits", {}, function(hits)
        for _, hit in ipairs(hits) do
            AddHitToRegistry({
                target = hit.target,
                targetname = hit.targetname,
                image = hit.image,
                issuer = hit.issuer,
                reward = hit.reward,
                description = hit.description,
                datetime = hit.datetime and math.floor(hit.datetime / 1000) or nil,
            }, true)
        end
    end)
end)