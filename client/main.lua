


local TMGCore = exports['tmg-core']:GetCoreObject()
local KeysList = {}
local isTakingKeys = false
local isCarjacking = false
local canCarjack = true
local AlertSend = false
local lastPickedVehicle = nil
local IsHotwiring = false
local trunkclose = true
local looped = false


local isLoopRunning = false

local function robKeyLoop()
    if isLoopRunning then return end
    isLoopRunning = true

    CreateThread(function()
        while isLoopRunning do
            local sleep = 1000 
            local ped = PlayerPedId()
            
            if LocalPlayer.state.isLoggedIn then
                local entering = GetVehiclePedIsTryingToEnter(ped)
                local inVehicle = IsPedInAnyVehicle(ped, false)
                
                if entering ~= 0 then
                    sleep = 500
                    if not isBlacklistedVehicle(entering) then
                        HandleNPCEntryLogic(entering)
                        sleep = 2000 
                    end
                end

                if inVehicle then
                    local vehicle = GetVehiclePedIsIn(ped)
                    local plate = TMGCore.Functions.GetPlate(vehicle)
                    
                    if GetPedInVehicleSeat(vehicle, -1) == ped and not HasKeys(plate) and not isBlacklistedVehicle(vehicle) then
                        sleep = 0 
                        local vPos = GetEntityCoords(vehicle)
                        DrawText3D(vPos.x, vPos.y, vPos.z + 0.5, Lang:t('info.skeys'))
                        SetVehicleEngineOn(vehicle, false, false, true)

                        if IsControlJustPressed(0, 74) then 
                            Hotwire(vehicle, plate)
                        end
                    else
                        sleep = 1000 
                    end
                end

                local currentWeapon = GetSelectedPedWeapon(ped)
                if currentWeapon ~= `WEAPON_UNARMED` and Config.CarJackEnable and canCarjack then
                    sleep = 200 
                    local aiming, target = GetEntityPlayerIsFreeAimingAt(PlayerId())
                    if aiming and DoesEntityExist(target) and IsPedInAnyVehicle(target, false) then
                        HandleCarjackDetection(target)
                    end
                end

                if entering == 0 and not inVehicle and currentWeapon == `WEAPON_UNARMED` then
                    isLoopRunning = false
                    break
                end
            end
            Wait(sleep)
        end
    end)
end

function HandleNPCEntryLogic(veh)
    local driver = GetPedInVehicleSeat(veh, -1)
    local plate = TMGCore.Functions.GetPlate(veh)
    
    if driver ~= 0 and not IsPedAPlayer(driver) and not HasKeys(plate) then
        if IsEntityDead(driver) then
            TriggerServerEvent('tmg-vehiclekeys:server:AcquireVehicleKeys', plate)
        else
            local lockState = Config.LockNPCDrivingCars and 2 or 1
            TriggerServerEvent('tmg-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(veh), lockState)
        end
    end
end

local hashedBlacklist = {}

local function initializeBlacklist()
    hashedBlacklist = {}
    for _, modelName in ipairs(Config.NoLockVehicles) do
        hashedBlacklist[joaat(modelName)] = true
    end
end

CreateThread(function()
    initializeBlacklist()
end)

function isBlacklistedVehicle(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then 
        return true 
    end

    local model = GetEntityModel(vehicle)
    if hashedBlacklist[model] then 
        return true 
    end

    if GetVehicleClass(vehicle) == 13 then 
        return true 
    end

    local state = Entity(vehicle).state
    if state and state.ignoreLocks then 
        return true 
    end

    return false
end

function addNoLockVehicles(model)
    if not model then return end
    
    local modelHash = type(model) == "string" and joaat(model) or model
    
    hashedBlacklist[modelHash] = true
    
    Config.NoLockVehicles[#Config.NoLockVehicles + 1] = model
    
    print("^3[TMG VehicleKeys]^7 Added " .. model .. " to blacklist.")
end

exports('addNoLockVehicles', addNoLockVehicles)

function removeNoLockVehicles(model)
    if not model then return end
    
    local modelHash = type(model) == "string" and joaat(model) or model
    
    hashedBlacklist[modelHash] = nil
    
    for k, v in ipairs(Config.NoLockVehicles) do
        if (type(v) == "string" and joaat(v) or v) == modelHash then
            table.remove(Config.NoLockVehicles, k)
            break 
        end
    end
end

exports('removeNoLockVehicles', removeNoLockVehicles)





local lastLockTick = 0

RegisterKeyMapping('togglelocks', Lang:t('info.tlock'), 'keyboard', 'L')

RegisterCommand('togglelocks', function()
    local ped = PlayerPedId()
    local currentTime = GetGameTimer()

    if currentTime - lastLockTick < 500 then return end
    lastLockTick = currentTime

    local vehicle = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or GetVehicle()
    
    if not vehicle or vehicle == 0 then return end

    if IsPedInAnyVehicle(ped, false) then
        ToggleVehicleLocksWithoutNui(vehicle)
    elseif Config.UseKeyfob then
        local dist = #(GetEntityCoords(ped) - GetEntityCoords(vehicle))
        if dist <= Config.LockToggleDist then
            OpenMenu()
        else
            TMGCore.Functions.Notify(Lang:t('notify.vtoofar'), "error")
        end
    else
        ToggleVehicleLocksWithoutNui(vehicle)
    end
end, false) 

local lastEngineTick = 0

RegisterKeyMapping('engine', Lang:t('info.engine'), 'keyboard', 'G')
RegisterCommand('engine', function()
    local ped = PlayerPedId()
    local currentTime = GetGameTimer()

    if currentTime - lastEngineTick < 600 then return end
    lastEngineTick = currentTime

    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle == 0 then 
        vehicle = GetVehicle() 
    end

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then 
        return
    end

    ToggleEngine(vehicle)
end, false)

local function InitialKeySync()
    local timeout = 0
    while not TMGCore or not TMGCore.Functions.GetPlayerData().citizenid do
        Wait(100)
        timeout = timeout + 1
        if timeout > 100 then break end 
    end

    GetKeys()
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    local PlayerData = TMGCore.Functions.GetPlayerData()
    if PlayerData and PlayerData.citizenid then
        InitialKeySync()
    end
end)

RegisterNetEvent('TMGCore:Client:OnPlayerLoaded', function()
    SetTimeout(math.random(0, 500), function()
        InitialKeySync()
    end)
end)

RegisterNetEvent('TMGCore:Client:OnPlayerUnload', function()
    KeysList = {}
    LocalPlayer.state:set("hasKeys", false, true)
end)

RegisterNetEvent('tmg-vehiclekeys:client:AddKeys', function(plate)
    if not plate then return end
    
    KeysList[plate] = true
    
    LocalPlayer.state:set("hasKeys", true, true)

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle ~= 0 then
        local vehiclePlate = TMGCore.Functions.GetPlate(vehicle)
        
        if plate:gsub("%s+", "") == vehiclePlate:gsub("%s+", "") then
            Entity(vehicle).state:set("keysAcquired", true, true)
            
            if GetIsVehicleAlarmFiring(vehicle) then
                SetVehicleAlarm(vehicle, false)
            end
            
            TMGCore.Functions.Notify(Lang:t('notify.vkeysreceived'), "success")
        end
    end
end)

RegisterNetEvent('tmg-vehiclekeys:client:RemoveKeys', function(plate)
    if not plate then return end
    
    KeysList[plate] = nil
    
    LocalPlayer.state:set("hasKeys", false, true)
    
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and TMGCore.Functions.GetPlate(vehicle) == plate then
         Entity(vehicle).state:set("keysAcquired", false, true)
    end
end)

RegisterNetEvent('tmg-vehiclekeys:client:ToggleEngine', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local plate = TMGCore.Functions.GetPlate(vehicle)
    local isRunning = GetIsVehicleEngineRunning(vehicle)

    if HasKeys(plate) or AreKeysJobShared(vehicle) then
        if not NetworkHasControlOfEntity(vehicle) then
            NetworkRequestControlOfEntity(vehicle)
            local timeout = 0
            while not NetworkHasControlOfEntity(vehicle) and timeout < 20 do
                Wait(10)
                timeout = timeout + 1
            end
        end

        SetVehicleEngineOn(vehicle, not isRunning, false, true)
        
        if not isRunning then
            TMGCore.Functions.Notify(Lang:t('notify.vengine_on'), 'success')
        else
            TMGCore.Functions.Notify(Lang:t('notify.vengine_off'), 'primary')
        end
    else
        TMGCore.Functions.Notify(Lang:t('notify.ydhk'), 'error')
    end
end)

RegisterNetEvent('tmg-vehiclekeys:client:GiveKeys', function(id)
    local ped = PlayerPedId()
    
    local targetVehicle = GetVehiclePedIsIn(ped, false)
    if targetVehicle == 0 then targetVehicle = GetVehicle() end
    
    if not targetVehicle or not DoesEntityExist(targetVehicle) then return end

    local targetPlate = TMGCore.Functions.GetPlate(targetVehicle)
    if not HasKeys(targetPlate) then
        return TMGCore.Functions.Notify(Lang:t('notify.ydhk'), 'error')
    end

    if id and type(id) == 'number' and id > 0 then 
        GiveKeys(id, targetPlate)

    elseif IsPedSittingInVehicle(ped, targetVehicle) then 
        local otherOccupants = GetOtherPlayersInVehicle(targetVehicle)
        if #otherOccupants > 0 then
            TMGCore.Functions.Notify("Distributing keys to occupants...", "primary")
            for p = 1, #otherOccupants do
                local targetSid = GetPlayerServerId(NetworkGetPlayerIndexFromPed(otherOccupants[p]))
                TriggerServerEvent('tmg-vehiclekeys:server:GiveVehicleKeys', targetSid, targetPlate)
                Wait(50) 
            end
        end

    else 
        local closestPlayer, closestDistance = TMGCore.Functions.GetClosestPlayer()
        
        if closestPlayer ~= -1 and closestDistance < 3.0 then
            local targetSid = GetPlayerServerId(closestPlayer)
            GiveKeys(targetSid, targetPlate)
        else
            TMGCore.Functions.Notify(Lang:t('notify.nonear'), 'error')
        end
    end
end)

RegisterNetEvent('TMGCore:Client:VehicleInfo', function(data)
    if data and data.event == 'Entering' then
        robKeyLoop()
    end
end)

RegisterNetEvent('tmg-weapons:client:DrawWeapon', function()
    CreateThread(function()
        local timeout = 0
        local ped = PlayerPedId()
        
        while GetSelectedPedWeapon(ped) == `WEAPON_UNARMED` and timeout < 30 do
            Wait(100)
            timeout = timeout + 1
        end

        robKeyLoop()
    end)
end)

RegisterNetEvent('lockpicks:UseLockpick', function(isAdvanced)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    
    local vehicle = GetVehicle() 
    
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if #(pos - GetEntityCoords(vehicle)) > 2.5 then return end
    if HasKeys(TMGCore.Functions.GetPlate(vehicle)) then return end
    if GetVehicleDoorLockStatus(vehicle) <= 1 then return end 

    if not NetworkHasControlOfEntity(vehicle) then
        NetworkRequestControlOfEntity(vehicle)
        local timeout = 0
        while not NetworkHasControlOfEntity(vehicle) and timeout < 25 do
            Wait(10)
            timeout = timeout + 1
        end
    end

    local animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
    local animName = "machinic_loop_mechandplayer"
    loadAnimDict(animDict)
    TaskPlayAnim(ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)

    local difficulty = isAdvanced and 'easy' or 'medium'
    local success = exports['tmg-minigames']:Skillbar(difficulty)
    
    ClearPedTasks(ped) 

    if success then
        lastPickedVehicle = vehicle
        local plate = TMGCore.Functions.GetPlate(vehicle)
        
        TriggerServerEvent('hud:server:GainStress', math.random(1, 4))
        
        if GetPedInVehicleSeat(vehicle, -1) == ped then
            TriggerServerEvent('tmg-vehiclekeys:server:AcquireVehicleKeys', plate)
        else
            TMGCore.Functions.Notify(Lang:t('notify.vlockpick'), 'success')
            TriggerServerEvent('tmg-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(vehicle), 1)
        end
    else
        AttemptPoliceAlert('steal')
        TriggerServerEvent('hud:server:GainStress', math.random(2, 5))
    end

    local chance = math.random()
    local threshold = isAdvanced and Config.RemoveLockpickAdvanced or Config.RemoveLockpickNormal
    local pickType = isAdvanced and 'advancedlockpick' or 'lockpick'

    if chance <= threshold then
        TriggerServerEvent('tmg-vehiclekeys:server:breakLockpick', pickType)
    end
end)

RegisterNetEvent('vehiclekeys:client:SetOwner', function(plate)
    TriggerServerEvent('tmg-vehiclekeys:server:AcquireVehicleKeys', plate)
end)






function OpenMenu()
    PlaySoundFrontend(-1, "BUTTON_SQUASH", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        SetVehicleEngineOn(GetVehiclePedIsIn(PlayerPedId(), false), false, false, true)
    end

    SendNUIMessage({ casemenue = 'open' })
    SetNuiFocus(true, true)
end

function ToggleEngine(veh)
    if not veh or not DoesEntityExist(veh) then return end
    if isBlacklistedVehicle(veh) then return end

    local plate = TMGCore.Functions.GetPlate(veh)
    if not HasKeys(plate) and not AreKeysJobShared(veh) then 
        return TMGCore.Functions.Notify(Lang:t('notify.ydhk'), 'error') 
    end

    if not NetworkHasControlOfEntity(veh) then
        NetworkRequestControlOfEntity(veh)
        local timeout = 0
        while not NetworkHasControlOfEntity(veh) and timeout < 30 do
            Wait(10)
            timeout = timeout + 1
        end
    end

    local EngineOn = GetIsVehicleEngineRunning(veh)
    
    if EngineOn then
        SetVehicleEngineOn(veh, false, false, true)
        TMGCore.Functions.Notify(Lang:t('notify.vengine_off'), 'primary')
    else
        SetVehicleEngineOn(veh, true, true, true)
        TMGCore.Functions.Notify(Lang:t('notify.vengine_on'), 'success')
    end
    
    Entity(veh).state:set("engineRunning", not EngineOn, true)
end


local isToggling = false 

function ToggleVehicleLocksWithoutNui(veh)
    if not veh or not DoesEntityExist(veh) or isToggling then return end
    
    if isBlacklistedVehicle(veh) then
        TriggerServerEvent('tmg-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(veh), 1)
        return
    end

    local plate = TMGCore.Functions.GetPlate(veh)
    if not HasKeys(plate) and not AreKeysJobShared(veh) then
        return TMGCore.Functions.Notify(Lang:t('notify.ydhk'), 'error')
    end

    isToggling = true
    local ped = PlayerPedId()
    local vehLockStatus = GetVehicleDoorLockStatus(veh)
    local curVeh = GetVehiclePedIsIn(ped, false)
    
    if not NetworkHasControlOfEntity(veh) then
        NetworkRequestControlOfEntity(veh)
        local timeout = 0
        while not NetworkHasControlOfEntity(veh) and timeout < 30 do
            Wait(10)
            timeout = timeout + 1
        end
    end

    if curVeh == 0 then
        local propModel = Config.LockToggleAnimation.Prop
        local activeProp = 0

        if propModel then
            local modelHash = joaat(propModel)
            RequestModel(modelHash)
            local mTimeout = 0
            while not HasModelLoaded(modelHash) and mTimeout < 50 do Wait(1) mTimeout = mTimeout + 1 end
            
            activeProp = CreateObject(modelHash, 0, 0, 0, true, true, true)
            AttachEntityToEntity(activeProp, ped, GetPedBoneIndex(ped, Config.LockToggleAnimation.PropBone), 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        end

        loadAnimDict(Config.LockToggleAnimation.AnimDict)
        TaskPlayAnim(ped, Config.LockToggleAnimation.AnimDict, Config.LockToggleAnimation.Anim, 8.0, -8.0, -1, 48, 0, false, false, false)
        TriggerServerEvent('InteractSound_SV:PlayWithinDistance', 5.0, Config.LockAnimSound, 0.5)

        SetTimeout(Config.LockToggleAnimation.WaitTime, function()
            if DoesEntityExist(activeProp) then DeleteObject(activeProp) end
            StopAnimTask(ped, Config.LockToggleAnimation.AnimDict, Config.LockToggleAnimation.Anim, 1.0)
            isToggling = false
        end)
    else
        isToggling = false 
    end

    local newLockState = (vehLockStatus == 1) and 2 or 1
    TriggerServerEvent('tmg-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(veh), newLockState)
    
    TMGCore.Functions.Notify((newLockState == 2 and Lang:t('notify.vlock') or Lang:t('notify.vunlock')), (newLockState == 2 and 'primary' or 'success'))
    TriggerServerEvent('InteractSound_SV:PlayWithinDistance', 5, Config.LockToggleSound, 0.3)

    SetVehicleLights(veh, 2)
    Wait(200)
    SetVehicleLights(veh, 0)
    Wait(200)
    SetVehicleLights(veh, 2)
    Wait(200)
    SetVehicleLights(veh, 0)
end

function GiveKeys(id, plate)
    if not id or id <= 0 then return end
    
    local targetId = tonumber(id)
    local targetPlayer = GetPlayerFromServerId(targetId)
    
    if targetPlayer == -1 then
        TMGCore.Functions.Notify("Target player is out of sync or offline", 'error')
        return
    end

    local targetPed = GetPlayerPed(targetPlayer)
    if not targetPed or targetPed == 0 or not DoesEntityExist(targetPed) then
        TMGCore.Functions.Notify(Lang:t('notify.nonear'), 'error')
        return
    end

    local myCoords = GetEntityCoords(PlayerPedId())
    local targetCoords = GetEntityCoords(targetPed)
    local distance = #(myCoords - targetCoords)

    if distance > 3.0 then
        TMGCore.Functions.Notify(Lang:t('notify.nonear'), 'error')
        return
    end

    TriggerServerEvent('tmg-vehiclekeys:server:GiveVehicleKeys', targetId, plate)
    TMGCore.Functions.Notify("Handing over the keys...", "primary")
end


local isKeysLoaded = false

function GetKeys()
    isKeysLoaded = false
    TMGCore.Functions.TriggerCallback('tmg-vehiclekeys:server:GetVehicleKeys', function(keysList)
        local tempKeys = {}
        if keysList then
            for plate, status in pairs(keysList) do
                tempKeys[plate] = status
            end
        end
        KeysList = tempKeys
        isKeysLoaded = true
    end)
end

function HasKeys(plate)
    if not isKeysLoaded then 
        return false 
    end
    
    if not plate then return false end
    local cleanPlate = plate:gsub("%s+", "")
    
    for k, v in pairs(KeysList) do
        if k:gsub("%s+", "") == cleanPlate then
            return v
        end
    end
    
    return false
end

exports('HasKeys', HasKeys)

function loadAnimDict(dict)
    if not dict then return end
    if HasAnimDictLoaded(dict) then return end

    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 100 do
        Wait(10) 
        timeout = timeout + 1
    end
    
    if timeout >= 100 then
        print("^1[TMG VehicleKeys] Error: Failed to load anim dict: " .. dict .. "^7")
    end
end




function GetVehicle()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then 
        return vehicle 
    end

    local forwardVector = GetEntityForwardVector(ped)
    local rayEnd = pos + (forwardVector * Config.LockToggleDist)
    
    local rayHandle = StartShapeTestCapsule(pos.x, pos.y, pos.z, rayEnd.x, rayEnd.y, rayEnd.z, 0.5, 10, ped, 7)
    local _, hit, _, _, vehicleHandle = GetShapeTestResult(rayHandle)

    if hit and DoesEntityExist(vehicleHandle) and IsEntityAVehicle(vehicleHandle) then
        return vehicleHandle
    end

    vehicle = TMGCore.Functions.GetClosestVehicle()
    
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        local targetPos = GetEntityCoords(vehicle)
        if #(pos - targetPos) <= Config.LockToggleDist then
            return vehicle
        end
    end

    return nil
end

function AreKeysJobShared(veh)
    if not veh or not DoesEntityExist(veh) then return false end

    local playerData = TMGCore.Functions.GetPlayerData()
    if not playerData or not playerData.job then return false end

    local jobName = playerData.job.name
    local onDuty = playerData.job.onduty
    
    local sharedJobConfig = Config.SharedKeys[jobName]
    if not sharedJobConfig then return false end
    if sharedJobConfig.requireOnduty and not onDuty then return false end

    local vehModel = GetEntityModel(veh) 
    local vehPlate = TMGCore.Functions.GetPlate(veh)

    for _, vehicleModelName in pairs(sharedJobConfig.vehicles) do
        if joaat(vehicleModelName) == vehModel then
            if not HasKeys(vehPlate) then
                TriggerServerEvent('tmg-vehiclekeys:server:AcquireVehicleKeys', vehPlate)
            end
            return true
        end
    end

    return false
end


function ToggleVehicleLocks(veh)
    if not veh or not DoesEntityExist(veh) then return end

    if isBlacklistedVehicle(veh) then
        TriggerServerEvent('tmg-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(veh), 1)
        return
    end

    local plate = TMGCore.Functions.GetPlate(veh)
    if not HasKeys(plate) and not AreKeysJobShared(veh) then
        return TMGCore.Functions.Notify(Lang:t('notify.ydhk'), 'error')
    end

    local ped = PlayerPedId()
    local vehLockStatus = GetVehicleDoorLockStatus(veh)
    
    if not NetworkHasControlOfEntity(veh) then
        NetworkRequestControlOfEntity(veh)
        local timeout = 0
        while not NetworkHasControlOfEntity(veh) and timeout < 30 do
            Wait(10)
            timeout = timeout + 1
        end
    end

    local animDict = 'anim@mp_player_intmenu@key_fob@'
    loadAnimDict(animDict)
    TaskPlayAnim(ped, animDict, 'fob_click', 8.0, 8.0, -1, 48, 0, false, false, false)
    
    PlaySoundFrontend(-1, "BUTTON_SQUASH", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)

    local newLockState = (vehLockStatus == 1) and 2 or 1
    TriggerServerEvent('tmg-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(veh), newLockState)
    
    if newLockState == 2 then
        TMGCore.Functions.Notify(Lang:t('notify.vlock'), 'primary')
        TriggerServerEvent('InteractSound_SV:PlayWithinDistance', 5, 'lock', 0.3)
    else
        TMGCore.Functions.Notify(Lang:t('notify.vunlock'), 'success')
        TriggerServerEvent('InteractSound_SV:PlayWithinDistance', 5, 'unlock', 0.3)
    end

    SetVehicleLights(veh, 2)
    Wait(200)
    SetVehicleLights(veh, 0)
    Wait(200)
    SetVehicleLights(veh, 2)
    Wait(200)
    SetVehicleLights(veh, 0)
    
    ClearPedTasks(ped)
end

function ToggleVehicleunLocks(veh)
    if not veh or not DoesEntityExist(veh) then return end
    ToggleVehicleLocks(veh)
end

function ToggleVehicleTrunk(veh)
    if not veh or not DoesEntityExist(veh) or isToggling then return end

    if isBlacklistedVehicle(veh) then return end
    
    local plate = TMGCore.Functions.GetPlate(veh)
    if not HasKeys(plate) and not AreKeysJobShared(veh) then
        return TMGCore.Functions.Notify(Lang:t('notify.ydhk'), 'error')
    end

    if not NetworkHasControlOfEntity(veh) then
        NetworkRequestControlOfEntity(veh)
        local timeout = 0
        while not NetworkHasControlOfEntity(veh) and timeout < 30 do Wait(10) timeout = timeout + 1 end
    end

    local trunkDoor = 5 
    local isOpened = GetVehicleDoorAngleRatio(veh, trunkDoor) > 0.0
    
    isToggling = true
    local ped = PlayerPedId()
    
    local animDict = 'anim@mp_player_intmenu@key_fob@'
    loadAnimDict(animDict)
    TaskPlayAnim(ped, animDict, 'fob_click', 8.0, 8.0, -1, 48, 0, false, false, false)
    PlaySoundFrontend(-1, "BUTTON_SQUASH", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)

    if isOpened then
        SetVehicleDoorShut(veh, trunkDoor, false)
        TMGCore.Functions.Notify("Trunk Closed", 'primary')
    else
        SetVehicleDoorOpen(veh, trunkDoor, false, false)
        TMGCore.Functions.Notify("Trunk Opened", 'success')
    end

    SetVehicleLights(veh, 2)
    Wait(150)
    SetVehicleLights(veh, 0)

    SetTimeout(500, function()
        isToggling = false
        ClearPedTasks(ped)
    end)
end

function GetOtherPlayersInVehicle(vehicle)
    if not vehicle or vehicle == 0 then return {} end

    local otherPeds = {}
    local myPed = PlayerPedId()
    local model = GetEntityModel(vehicle)
    local maxSeats = GetVehicleModelNumberOfSeats(model)

    for seat = -1, maxSeats - 2 do
        local pedInSeat = GetPedInVehicleSeat(vehicle, seat)
        
        if pedInSeat ~= 0 and IsPedAPlayer(pedInSeat) and pedInSeat ~= myPed then
            otherPeds[#otherPeds + 1] = pedInSeat
        end
    end

    return otherPeds
end

function GetPedsInVehicle(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return {} end

    local npcTable = {}
    local model = GetEntityModel(vehicle)
    local maxSeats = GetVehicleModelNumberOfSeats(model)

    for seat = -1, maxSeats - 2 do
        local pedInSeat = GetPedInVehicleSeat(vehicle, seat)
        
        if pedInSeat ~= 0 and DoesEntityExist(pedInSeat) and not IsPedAPlayer(pedInSeat) then
            npcTable[#npcTable + 1] = pedInSeat
        end
    end

    return npcTable
end

local hashedWeaponBlacklist = {}

CreateThread(function()
    for _, weaponName in pairs(Config.NoCarjackWeapons) do
        hashedWeaponBlacklist[joaat(weaponName)] = true
    end
end)

function IsBlacklistedWeapon()
    local ped = PlayerPedId()
    local weaponHash = GetSelectedPedWeapon(ped)
    
    if weaponHash == `WEAPON_UNARMED` then return false end

    if hashedWeaponBlacklist[weaponHash] then
        return true
    end

    return false
end

function Hotwire(vehicle, plate)
    if not vehicle or IsHotwiring then return end 

    local hotwireTime = math.random(Config.minHotwireTime, Config.maxHotwireTime)
    local ped = PlayerPedId()
    IsHotwiring = true 

    SetVehicleAlarm(vehicle, true)
    SetVehicleAlarmTimeLeft(vehicle, hotwireTime + 2000) 
    
    local alertTimer = true
    SetTimeout(7000, function()
        if IsHotwiring and alertTimer then
            AttemptPoliceAlert('steal')
        end
    end)

    TMGCore.Functions.Progressbar('hotwire_vehicle', Lang:t('progress.hskeys'), hotwireTime, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
    }, {
        animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        anim = 'machinic_loop_mechandplayer',
        flags = 49 
    }, {}, {}, function() 
        IsHotwiring = false
        alertTimer = false
        StopAnimTask(ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 1.0)
        
        TriggerServerEvent('hud:server:GainStress', math.random(1, 4))
        
        if (math.random() <= Config.HotwireChance) then
            TriggerServerEvent('tmg-vehiclekeys:server:AcquireVehicleKeys', plate)
        else
            TMGCore.Functions.Notify(Lang:t('notify.fvlockpick'), 'error')
        end
        
        Wait(Config.TimeBetweenHotwires)
    end, function() 
        IsHotwiring = false
        alertTimer = false 
        StopAnimTask(ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 1.0)
    end)

end

function CarjackVehicle(target)
    if not Config.CarJackEnable or isCarjacking or not target then return end
    
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsUsing(target)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    if not NetworkHasControlOfEntity(vehicle) then
        NetworkRequestControlOfEntity(vehicle)
    end

    isCarjacking = true
    canCarjack = false
    loadAnimDict('mp_am_hold_up')
    
    local occupants = GetPedsInVehicle(vehicle)
    local plate = TMGCore.Functions.GetPlate(vehicle)

    FreezeEntityPosition(vehicle, true)
    SetVehicleUndriveable(vehicle, true)

    for i=1, #occupants do
        local vic = occupants[i]
        if DoesEntityExist(vic) then
            TaskPlayAnim(vic, 'mp_am_hold_up', 'holdup_victim_20s', 8.0, -8.0, -1, 49, 0, false, false, false)
            PlayPain(vic, 6, 0)
        end
    end

    CreateThread(function()
        while isCarjacking do
            local myCoords = GetEntityCoords(ped)
            local targetCoords = GetEntityCoords(target)
            
            
            if not DoesEntityExist(target) or IsPedDeadOrDying(target) or #(myCoords - targetCoords) > 10.0 then
                TriggerEvent('progressbar:client:cancel')
                break 
            end
            Wait(250) 
        end
    end)

    TMGCore.Functions.Progressbar('rob_keys', Lang:t('progress.acjack'), Config.CarjackingTime, false, true, {
        disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true
    }, {}, {}, {}, function() 
        local hasWeapon, weaponHash = GetCurrentPedWeapon(ped, true)
        
        if hasWeapon and isCarjacking then
            local weaponGroup = tostring(GetWeapontypeGroup(weaponHash))
            local carjackChance = Config.CarjackChance[weaponGroup] or 0.5
                
            if math.random() <= carjackChance then
                for i=1, #occupants do
                    local vic = occupants[i]
                    if DoesEntityExist(vic) then
                        TaskLeaveVehicle(vic, vehicle, 256) 
                        SetBlockingOfNonTemporaryEvents(vic, true)
                        TaskSmartFleePed(vic, ped, 100.0, -1)
                    end
                end
                TriggerServerEvent('hud:server:GainStress', math.random(1, 4))
                TriggerServerEvent('tmg-vehiclekeys:server:AcquireVehicleKeys', plate)
            else
                TMGCore.Functions.Notify(Lang:t('notify.cjackfail'), 'error')
                TaskSmartFleePed(target, ped, 100.0, -1)
            end
        end

        FreezeEntityPosition(vehicle, false)
        SetVehicleUndriveable(vehicle, false)
        isCarjacking = false
        AttemptPoliceAlert('carjack')
        SetTimeout(Config.DelayBetweenCarjackings, function() canCarjack = true end)

    end, function() 
        FreezeEntityPosition(vehicle, false)
        SetVehicleUndriveable(vehicle, false)
        if DoesEntityExist(target) then TaskSmartFleePed(target, ped, 100.0, -1) end
        isCarjacking = false
        SetTimeout(Config.DelayBetweenCarjackings, function() canCarjack = true end)
    end)
end

local lastAlertTime = 0

function AttemptPoliceAlert(alertType)
    local currentTime = GetGameTimer()
    
    if (currentTime - lastAlertTime) < Config.AlertCooldown then return end

    local chance = Config.PoliceAlertChance
    local hour = GetClockHours()
    
    if hour >= 1 and hour <= 6 then
        chance = Config.PoliceNightAlertChance
    end

    if math.random() <= chance then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local s1, s2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local streetLabel = GetStreetNameFromHashKey(s1)
        if s2 ~= 0 then streetLabel = streetLabel .. " | " .. GetStreetNameFromHashKey(s2) end

        local alertData = {
            message = Lang:t('info.palert') .. " " .. alertType,
            location = streetLabel,
            coords = coords,
            type = alertType
        }

        TriggerServerEvent('police:server:policeAlert', alertData.message .. " at " .. alertData.location)
        
        

        lastAlertTime = currentTime 
    end
end

function MakePedFlee(ped)
    if not ped or not DoesEntityExist(ped) then return end
    
    SetPedFleeAttributes(ped, 0, false)
    SetBlockingOfNonTemporaryEvents(ped, true) 
    
    TaskSmartFleePed(ped, PlayerPedId(), 100.0, -1, false, true)
    
    SetTimeout(20000, function()
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
            DeleteEntity(ped)
        end
    end)
end

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    SetTextScale(0.35, 0.35)
    SetTextFont(GetConvar('qb_locale', 'en') == 'en' and 4 or 1)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end




RegisterNUICallback('closui', function()
    SetNuiFocus(false, false)
end)

RegisterNUICallback('unlock', function()
    ToggleVehicleunLocks(GetVehicle())
    SetNuiFocus(false, false)
end)

RegisterNUICallback('lock', function()
    ToggleVehicleLocks(GetVehicle())
    SetNuiFocus(false, false)
end)

RegisterNUICallback('trunk', function()
    ToggleVehicleTrunk(GetVehicle())
    SetNuiFocus(false, false)
end)

RegisterNUICallback('engine', function()
    ToggleEngine(GetVehicle())
    SetNuiFocus(false, false)
end)
