local guiEnabled = false
function EnableGui(enable)
    SetNuiFocus(enable, enable)
    guiEnabled = enable

    if enable then
        SendNUIMessage({type = "open"})
    end
end

AddEventHandler("onClientResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        EnableGui(false)
    end
end)
RegisterNetEvent("omni_mout_builder:open")
AddEventHandler("omni_mout_builder:open", function()
	EnableGui(true)
end)

local isEditorEnabled = false
local Editor = {
    enabled = false,
    prop = "",
    propName = "",
    hiddenProp = "bmx",
    fakeEntity = nil,
    regenerate = false,
    x = 0.0,
    cx = 0.0,
    y = 0.0,
    cy = 4.0,
    z = 0.0,
    cz = 0.0,
    r = 0.0,
    cr = 80.0,
    snap = false,
    camera = nil,
    cameraEntity = nil,
    movementEntity = nil,
    first_time = true,
    oob = false,
    range = 0.0,
    rx = 0.0,
    ry = 0.0,
    rz = 0.0,
}

local movement_scale_slow = 0.10
local movement_scale_fast = 1.50
local movement_scale = movement_scale_slow
local rotation_scale_slow = 5.0
local rotation_scale_fast = 45.0
local rotation_scale = rotation_scale_slow


RegisterNUICallback('close', function(data, cb)
    EnableGui(false)
    Editor.enabled = false
end)

RegisterNUICallback('selectProp', function(data, cb)
    Editor.prop = data.prop.model
    Editor.propName = data.prop.name
    Editor.regenerate = true
end)

RegisterNUICallback('offsetProp', function(data, cb)
    Editor.x = math.floor((Editor.x + (data.x or 0.0) * movement_scale) / movement_scale_slow + 0.5) * movement_scale_slow
    Editor.y = math.floor((Editor.y + (data.y or 0.0) * movement_scale) / movement_scale_slow + 0.5) * movement_scale_slow
    Editor.z = math.floor((Editor.z + (data.z or 0.0) * movement_scale) / movement_scale_slow + 0.5) * movement_scale_slow
    Editor.r = math.floor((Editor.r + (data.r or 0.0) * rotation_scale) / rotation_scale_slow + 0.5) * rotation_scale_slow
end)
RegisterNUICallback('offsetCamera', function(data, cb)
    Editor.cx = math.floor((Editor.cx + (data.x or 0.0) * movement_scale) / movement_scale_slow + 0.5) * movement_scale_slow
    Editor.cy = math.floor((Editor.cy + (data.y or 0.0) * movement_scale) / movement_scale_slow + 0.5) * movement_scale_slow
    Editor.cz = math.floor((Editor.cz + (data.z or 0.0) * movement_scale) / movement_scale_slow + 0.5) * movement_scale_slow
    Editor.cr = math.floor((Editor.cr + (data.r or 0.0) * rotation_scale) / rotation_scale_slow + 0.5) * rotation_scale_slow
end)
RegisterNUICallback('setCameraHeight', function(data, cb)
    Editor.cz = data.value * 1.0
end)
RegisterNUICallback('setCameraRotation', function(data, cb)
    Editor.cx = data.value * 1.0
end)
RegisterNUICallback('toggleSnap', function(data, cb)
    Editor.snap = data.snap or false
    movement_scale = Editor.snap and movement_scale_fast or movement_scale_slow
    rotation_scale = Editor.snap and rotation_scale_fast or rotation_scale_slow
end)
RegisterNUICallback('confirmProp', function(data, cb)
    if Editor.enabled and Editor.fakeEntity then
        RequestModel(Editor.prop)
        while not HasModelLoaded(Editor.prop) do Wait(0) end
        TriggerServerEvent("omni_mout_builder:confirmedProp", Editor)
        Editor.prop = ""
        Editor.regenerate = true
    end
end)
RegisterNUICallback('resetCamera', function(data, cb)
    if Editor.enabled then
        local pos = GetEntityCoords(PlayerPedId())
        Editor.x = pos.x
        Editor.y = pos.y
        Editor.z = pos.z
    end
end)

local PlacedProps = {}

RegisterNetEvent("omni_mout_builder:placeProp")
AddEventHandler("omni_mout_builder:placeProp", function(data)
    for _, prop in next, PlacedProps do
        if data.prop == prop.prop and data.x == prop.x and data.y == prop.y and data.z == prop.z and data.r == prop.r then
            return false
        end
    end

    RequestModel(data.prop)
    while not HasModelLoaded(data.prop) do Wait(0) end
    local prop = CreateObject(data.prop, data.x, data.y, data.z, false, 0, true)
    SetEntityCoordsNoOffset(prop, data.x, data.y, data.z, 0, 0, 0, false)
    SetEntityRotation(prop, 0.0, 0.0, data.r, 0, 0)
    SetStateOfClosestDoorOfType(data.prop, data.x, data.y, data.z, false, 0.0, 0)
    FreezeEntityPosition(prop, true)

    table.insert(PlacedProps, data)
end)

RegisterNetEvent("omni_mout_builder:enable")
AddEventHandler("omni_mout_builder:enable", function(x, y, z, range)
    if Editor.first_time then
        local pos = GetEntityCoords(PlayerPedId())
        Editor.x = pos.x
        Editor.y = pos.y
        Editor.z = pos.z
        Editor.first_time = false
    end
    Editor.rx = x
    Editor.ry = y
    Editor.rz = z
    Editor.range = range
    Editor.enabled = true
    EnableGui(true)
end)

RegisterCommand("build_menu", function()
    local pos = GetEntityCoords(PlayerPedId())
    TriggerEvent("omni_mout_builder:enable", pos.x, pos.y, pos.z, 10000.0)
end, false)

Citizen.CreateThread(function()
    while true do
        Wait(0)
        if Editor.enabled and Editor.prop ~= "" then
            if (not Editor.fakeEntity) or (not DoesEntityExist(Editor.fakeEntity)) or Editor.regenerate then
                if DoesEntityExist(Editor.fakeEntity) then
                    DeleteEntity(Editor.fakeEntity)
                end
                Editor.regenerate = false
                RequestModel(Editor.prop)
                while not HasModelLoaded(Editor.prop) do Wait(0) end
                Editor.fakeEntity = CreateObject(Editor.prop, Editor.x, Editor.y, Editor.z, false, 0, true)
                SetEntityCollision(Editor.fakeEntity, false, false)
            else
                -- Generate camera if not already generated
                if not Editor.camera then
                    Editor.camera = CreateCam("DEFAULT_SCRIPTED_CAMERA", 0)
                end
                if not Editor.cameraEntity then
                    RequestModel(Editor.hiddenProp)
                    while not HasModelLoaded(Editor.hiddenProp) do Wait(0) end
                    Editor.cameraEntity = CreateObject(Editor.hiddenProp, Editor.x, Editor.y, Editor.z, false, 0, false)
                    SetEntityVisible(Editor.cameraEntity, false, 0)
                end
                if not Editor.movementEntity then
                    RequestModel(Editor.hiddenProp)
                    while not HasModelLoaded(Editor.hiddenProp) do Wait(0) end
                    Editor.movementEntity = CreateObject(Editor.hiddenProp, Editor.x, Editor.y, Editor.z, false, 0, false)
                    SetEntityVisible(Editor.movementEntity, false, 0)
                end


                SetEntityRotation(Editor.movementEntity, 0.0, 0.0, Editor.r, 0, 0)
                SetEntityRotation(Editor.cameraEntity, 0.0, 0.0, Editor.cx, 0, 0)

                -- Move and deal with camera render
                local cfx = GetEntityForwardX(Editor.cameraEntity)
                local cfy = GetEntityForwardY(Editor.cameraEntity)

                SetCamActive(Editor.camera, true)
                SetCamCoord(Editor.camera, Editor.x + cfx * Editor.cy, Editor.y + cfy * Editor.cy, Editor.z + Editor.cz)
                SetCamFov(Editor.camera, Editor.cr)
                PointCamAtEntity(Editor.camera, Editor.fakeEntity, 0.0, 0.0, 0.0, 1)
                RenderScriptCams(true, false, 3000, 1, 1)

                -- Move and rotate entity
                SetEntityCoordsNoOffset(Editor.fakeEntity, Editor.x, Editor.y, Editor.z, 0, 0, 0, false)
                SetEntityRotation(Editor.fakeEntity, 0.0, 0.0, Editor.r, 0, 0)

                local dist = #(vector3(Editor.x, Editor.y, 0.0) - vector3(Editor.rx, Editor.ry, 0.0))
                Editor.oob = dist > Editor.range

                SetEntityAlpha(entity, Editor.oob and 200 or 255, false)

                -- Draw entity rotation
                local fvx = GetEntityForwardX(Editor.fakeEntity)
                local fvy = GetEntityForwardY(Editor.fakeEntity)
                local pos1 = vector3(Editor.x + fvx * 5.0, Editor.y + fvy * 5.0, Editor.z)
                local pos2 = vector3(Editor.x - fvx * 5.0, Editor.y - fvy * 5.0, Editor.z)
                DrawLine(pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z, 0, 255, 255, 255)

                -- Draw coordinate guides
                DrawLine(Editor.x, Editor.y, Editor.z, Editor.x + 5.0, Editor.y, Editor.z, 255, 0, 0, 255)
                DrawLine(Editor.x, Editor.y, Editor.z, Editor.x, Editor.y + 5.0, Editor.z, 0, 255, 0, 255)
                DrawLine(Editor.x, Editor.y, Editor.z, Editor.x, Editor.y, Editor.z + 5.0, 0, 0, 255, 255)
            end
        else
            -- Remove camera
            if Editor.camera then
                RenderScriptCams(false, false, 3000, 1, 1)
                DetachCam(Editor.camera)
                SetCamActive(Editor.camera, false)
                DestroyCam(Editor.camera, false)
                Editor.camera = nil
            end
            -- Remove entity
            if Editor.fakeEntity then
                if DoesEntityExist(Editor.fakeEntity) then
                    DeleteEntity(Editor.fakeEntity)
                end
                Editor.fakeEntity = nil
            end
            if Editor.fakeEntity then
                if DoesEntityExist(Editor.fakeEntity) then
                    DeleteEntity(Editor.fakeEntity)
                end
                Editor.fakeEntity = nil
            end
            if Editor.movementEntity then
                if DoesEntityExist(Editor.movementEntity) then
                    DeleteEntity(Editor.movementEntity)
                end
                Editor.movementEntity = nil
            end
        end
    end
end)
