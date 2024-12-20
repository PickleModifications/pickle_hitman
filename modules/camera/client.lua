local CAMERA_VALUES = {}
CAMERA_VALUES.fov = { 10.0, 90.0 }
CAMERA_VALUES.calculatedFov = CAMERA_VALUES.fov[2]
CAMERA_VALUES.speed = { zoom = 10.0, x = 8.0, y = 8.0 }

local usingCamera = false

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
    local rightAxisX = GetDisabledControlNormal(0, 220)
    local rightAxisY = GetDisabledControlNormal(0, 221)
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
    if rightAxisX ~= 0.0 or rightAxisY ~= 0.0 then
        local new_z = rotation.z + rightAxisX*-1.0*(CAMERA_VALUES.speed.y)*(zoom+0.1)
        local new_x = math.max(math.min(20.0, rotation.x + rightAxisY*-1.0*(CAMERA_VALUES.speed.x)*(zoom+0.1)), -89.5)
        SetCamRot(cam, new_x, 0.0, new_z, 2)
    end
end

function CameraLoop(trackData)
    if usingCamera then return end
    usingCamera = true
    local playerPed = PlayerPedId()
    CreateThread(function()
        local cam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
        AttachCamToEntity(cam, playerPed, 0.0, 1.0, 1.0, true)
        SetCamFov(cam, CAMERA_VALUES.calculatedFov)
        SetCamRot(cam, 0.0, 0.0, GetEntityHeading(playerPed), 2)
        RenderScriptCams(true, false, 0, true, false)
        local targetPed = nil
        CreateThread(function()
            while usingCamera and CurrentHit do
                if (not targetPed or not DoesEntityExist(targetPed)) and NetworkDoesEntityExistWithNetworkId(trackData.netId) then
                    targetPed = NetToPed(trackData.netId)
                end
                Wait(1000)
            end
        end)
        while usingCamera and CurrentHit and not IsPedInAnyVehicle(playerPed) and not IsEntityDead(playerPed) do
            HideHUD()
            CameraControls(cam, (1.0 / (CAMERA_VALUES.fov[2] - CAMERA_VALUES.fov[1])) * (CAMERA_VALUES.calculatedFov - CAMERA_VALUES.fov[1]))
            targetVisible = (targetPed and DoesEntityExist(targetPed) and not IsEntityOccluded(targetPed))
            print(targetVisible)
            Wait(0)
        end
        usingCamera = false
        CAMERA_VALUES.calculatedFov = (CAMERA_VALUES.fov[2] + CAMERA_VALUES.fov[1]) * 0.5
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(cam, false)
    end)
end

RegisterCommand("camera", function()
    CameraLoop()
end, false)