local LOCAL_PERMISSIONS = { placeHits = false, cancelHits = false }
local LOCAL_IDENTIFIER = "NULL"
local display = false

function SetAppDisplay(bool)
    display = bool
    if display then
        TriggerScreenblurFadeIn(200)
        SetNuiFocus(true, true)
    else
        TriggerScreenblurFadeOut(200)
        SetNuiFocus(false, false)
    end
    SendNUIMessage({
        type = "setAppDisplay",
        data = display
    })
end

function UpdatePermissions(permissions)
    LOCAL_PERMISSIONS = permissions
    SendNUIMessage({
        type = "updatePermissions",
        permissions = {
            placeHits = permissions.placeHits or false,
            cancelHits = permissions.cancelHits or false,
            acceptHits = permissions.acceptHits or false,
        }
    })
end

RegisterNetEvent("pickle_hitman:onRestart", function()
    TriggerServerEvent("pickle_hitman:initializePlayer")
end)

RegisterNetEvent("pickle_hitman:initializePlayer", function(data)
    if initializedPlayer then return end
    initializedPlayer = true
    LOCAL_IDENTIFIER = data.identifier
    LOCAL_PERMISSIONS = data.permissions
    UpdatePermissions(data.permissions)
    UpdateHits(data.hits)
end)

RegisterNetEvent("pickle_hitman:resyncPermissions", function(permissions)
    LOCAL_PERMISSIONS = permissions
    UpdatePermissions(permissions)
end)

RegisterNUICallback("requestConfig", function(data, cb)
    cb({
        type = "setConfig",
        locale = Language[Config.Language],
        currency = {
            name = "USD",
            locale = "en-US"
        },
        identifier = LOCAL_IDENTIFIER,
        permissions = LOCAL_PERMISSIONS,
        defaultPlayerImage = "https://www.shutterstock.com/image-vector/silhouette-people-unknown-male-person-260nw-1372192277.jpg",
    })
    SendNUIMessage({
        type = "setSections",
        sections = {
            {name = "hits", label = _L("header_hit")},
        }
    })
    TriggerServerEvent("pickle_hitman:acceptHit")
    if Config.UseTarget then
        AddTargetModel(Config.PhoneboxModels, 2.5, {
            {
                name = "hitman_use_phone",
                label = "Hitman Agency",
                onSelect = function(data)
                    SetAppDisplay(true)
                end
            }
        })
    end
end)

RegisterNUICallback("getPlayers", function(data, cb)
    ServerCallback("pickle_hitman:getPlayers", function(players)
        cb({players = players})
    end, true)
end)

RegisterNUICallback("closeApp", function(data, cb)
    SetAppDisplay(false)
end)