local CAMERA_VALUES = {}
CAMERA_VALUES.fov = { 10.0, 90.0 }
CAMERA_VALUES.calculatedFov = CAMERA_VALUES.fov[2]
CAMERA_VALUES.speed = { zoom = 10.0, x = 8.0, y = 8.0 }

usingCamera = false

local function HideHUD()
    local hiddenComponents = {1, 2, 3, 4, 6, 7, 8, 9, 11, 12, 13, 15, 18, 19}
    for i=1, #hiddenComponents do
        HideHudComponentThisFrame(hiddenComponents[i])
    end
    HideHelpTextThisFrame()
    HideHudAndRadarThisFrame()
end

function CameraControls(cam, zoom)
    local playerPed = PlayerPedId()
    local rightAxis = {x = GetDisabledControlNormal(0, 220), y = GetDisabledControlNormal(0, 221)}
    local rotation = GetCamRot(cam, 2)
    if IsControlJustPressed(0, IsPedSittingInAnyVehicle(playerPed) and 17 or 241) then
        CAMERA_VALUES.calculatedFov = math.max(CAMERA_VALUES.calculatedFov - CAMERA_VALUES.speed.zoom, CAMERA_VALUES.fov[1])
    end
    if IsControlJustPressed(0, IsPedSittingInAnyVehicle(playerPed) and 16 or 242) then
        CAMERA_VALUES.calculatedFov = math.min(CAMERA_VALUES.calculatedFov + CAMERA_VALUES.speed.zoom, CAMERA_VALUES.fov[2])
    end
    local current_fov = GetCamFov(cam)
    if math.abs(CAMERA_VALUES.calculatedFov-current_fov) < 0.1 then
        CAMERA_VALUES.calculatedFov = current_fov
    end
    SetCamFov(cam, current_fov + (CAMERA_VALUES.calculatedFov - current_fov)*0.05)
    SetEntityHeading(playerPed, rotation.z)
    if rightAxis.x ~= 0.0 or rightAxis.y ~= 0.0 then
        local new_z = rotation.z + rightAxis.x*-1.0*(CAMERA_VALUES.speed.y)*(zoom+0.1)
        local new_x = math.max(math.min(20.0, rotation.x + rightAxis.y*-1.0*(CAMERA_VALUES.speed.x)*(zoom+0.1)), -89.5)
        SetCamRot(cam, new_x, 0.0, new_z, 2)
    end
end

function CameraLoop(trackData)
    if usingCamera then return end
    usingCamera = true
    local playerPed = PlayerPedId()
    CreateThread(function()
        local cam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
        AttachCamToEntity(cam, playerPed, 0.0, 1.0, 0.75, true)
        SetCamFov(cam, CAMERA_VALUES.calculatedFov)
        SetCamRot(cam, 0.0, 0.0, GetEntityHeading(playerPed), 2)
        RenderScriptCams(true, false, 0, true, false)
        local obj = CreateProp(`prop_pap_camera_01`, GetEntityCoords(playerPed), true, true)
        local boneIndex = GetPedBoneIndex(playerPed, 28422)
        AttachEntityToEntity(obj, playerPed, boneIndex, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        local targetPed = nil
        local cameraState = "idle"
        local scanTime = 0
        SendNUIMessage({
            type = "setCameraState",
            cameraState = cameraState
        })
        CreateThread(function()
            while usingCamera and CurrentHit do
                SetCurrentPedWeapon(playerPed, `WEAPON_UNARMED`, true)
                if not IsEntityPlayingAnim(playerPed, "amb@world_human_paparazzi@male@base", "base", 3) then
                    ClearPedTasksImmediately(playerPed)
                    PlayAnim(playerPed, "amb@world_human_paparazzi@male@base", "base", -8.0, 8.0, -1, 49, 0, false, false, false)
                end
                if trackData.trackType == "player" then
                    local targetPlayer
                    for i=1, #GetActivePlayers() do
                        local player = GetActivePlayers()[i]
                        if GetPlayerServerId(player) == trackData.serverId then
                            targetPlayer = player
                            break
                        end
                    end
                    if targetPlayer then
                        targetPed = GetPlayerPed(targetPlayer)
                    else
                        targetPed = nil
                    end
                else
                    if (not targetPed or not DoesEntityExist(targetPed)) and NetworkDoesEntityExistWithNetworkId(trackData.netId) then
                        targetPed = NetToPed(trackData.netId)
                    end
                end
                Wait(1000)
            end
        end)
        while usingCamera and CurrentHit and not IsPedInAnyVehicle(playerPed) and not IsEntityDead(playerPed) do
            HideHUD()
            CameraControls(cam, (1.0 / (CAMERA_VALUES.fov[2] - CAMERA_VALUES.fov[1])) * (CAMERA_VALUES.calculatedFov - CAMERA_VALUES.fov[1]))
            targetVisible = (targetPed and DoesEntityExist(targetPed) and not IsEntityOccluded(targetPed))
            DisableControlAction(0, 30, true)  -- Disable move left/right
            DisableControlAction(0, 31, true)  -- Disable move up/down
            DisableControlAction(0, 21, true)  -- Disable sprint
            DisableControlAction(0, 22, true)  -- Disable jump
            DisableControlAction(0, 24, true)  -- Disable attack
            DisableControlAction(0, 25, true)  -- Disable aim
            DisableControlAction(0, 37, true)  -- Disable weapon select
            DisableControlAction(0, 44, true)  -- Disable cover
            DisableControlAction(0, 140, true) -- Disable melee attack light
            DisableControlAction(0, 141, true) -- Disable melee attack heavy
            DisableControlAction(0, 142, true) -- Disable melee attack alternate
            DisableControlAction(0, 143, true) -- Disable melee block
            if IsControlJustPressed(0, 202) then
                break
            end
            if cameraState == "idle" then
                if IsDisabledControlJustPressed(0, 22) then
                    cameraState = "scanning"
                    SendNUIMessage({
                        type = "setCameraState",
                        cameraState = cameraState
                    })
                end
            elseif cameraState == "scanning" then
                if IsDisabledControlJustReleased(0, 22) then
                    cameraState = "idle"
                    scanTime = 0
                    SendNUIMessage({
                        type = "setCameraState",
                        cameraState = cameraState
                    })
                else
                    scanTime = scanTime + 1
                    if scanTime >= 100 then
                        cameraState = (targetVisible and "match" or "no_match")
                        scanTime = 0
                        SendNUIMessage({
                            type = "setCameraState",
                            cameraState = cameraState
                        })
                        if cameraState == "match" and CurrentHit and CurrentHit.requestConfirmation then
                            CurrentHit.confirmedTarget = true
                        end
                        SetTimeout(1000, function()
                            if cameraState ~= nil then
                                cameraState = "idle"
                                SendNUIMessage({
                                    type = "setCameraState",
                                    cameraState = cameraState
                                })
                            end
                        end)
                    end
                end
            end
            Wait(0)
        end
        DeleteEntity(obj)
        ClearPedTasksImmediately(PlayerPedId())
        usingCamera = false
        cameraState = nil
        SendNUIMessage({
            type = "setCameraState",
            cameraState = cameraState,
        })
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(cam, false)
        CAMERA_VALUES.calculatedFov = CAMERA_VALUES.fov[2]
    end)
end

RegisterCommand("camera", function()
    CameraLoop()
end, false)