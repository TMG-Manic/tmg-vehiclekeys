local TMGCore = exports['tmg-core']:GetCoreObject()
local VehicleList = {}

RegisterNetEvent('tmg-vehiclekeys:server:GiveVehicleKeys', function(receiver, plate)
    local giver = source
    if not receiver or not plate then return end

    if HasKeys(giver, plate) then
        TriggerClientEvent('TMGCore:Notify', giver, Lang:t('notify.vgkeys'), 'success')

        if type(receiver) == 'table' then
            for _, targetID in ipairs(receiver) do
                GiveKeys(targetID, plate)
            end
        else
            GiveKeys(receiver, plate)
        end
    else
        TriggerClientEvent('TMGCore:Notify', giver, Lang:t('notify.ydhk'), 'error')
    end
end)

RegisterNetEvent('tmg-vehiclekeys:server:AcquireVehicleKeys', function(plate)
    local src = source
    if not plate then return end

    GiveKeys(src, plate)
end)


RegisterNetEvent('tmg-vehiclekeys:server:breakLockpick', function(itemName)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return end

    if not (itemName == 'lockpick' or itemName == 'advancedlockpick') then 
        return 
    end

    local hasItem = Player.Functions.GetItemByName(itemName)
    if hasItem and hasItem.amount > 0 then
        if Player.Functions.RemoveItem(itemName, 1) then
            TriggerClientEvent('tmg-inventory:client:ItemBox', src, TMGCore.Shared.Items[itemName], 'remove', 1)
            
            TriggerEvent('tmg-log:server:CreateLog', 'vehicles', 'Tool Failure', 'orange', string.format("Citizen %s broke a %s", Player.PlayerData.citizenid, itemName))
        end
    else
        print(string.format("^1[TMG]^7 Alert: Terminal %s attempted to break a %s they do not possess.", src, itemName))
    end
end)


RegisterNetEvent('tmg-vehiclekeys:server:setVehLockState', function(vehNetId, state)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(vehNetId)

    if DoesEntityExist(vehicle) then
        SetVehicleDoorsLocked(vehicle, state)
        
        local isLocked = state > 1
        Entity(vehicle).state:set('isLocked', isLocked, true)

        print(string.format("^5[TMG]^7 Sync: Terminal %s set Entity %s LockState to %s", src, vehNetId, isLocked))
    else
        print(string.format("^5[TMG]^7 Warning: Terminal %s attempted to lock a non-existent Entity ID: %s", src, vehNetId))
    end
end)

TMGCore.Functions.CreateCallback('tmg-vehiclekeys:server:GetVehicleKeys', function(source, cb)
    local Player = TMGCore.Functions.GetPlayer(source)
    
    if not Player then return cb({}) end

    local keysList = Player.PlayerData.metadata["vehicleKeys"] or {}

    cb(keysList)
    
    local count = 0
    for _ in pairs(keysList) do count = count + 1 end
    
    print(string.format("^5[TMG]^7 Registry: Streamed %s keys to Terminal %s", count, source))
end)


TMGCore.Functions.CreateCallback('tmg-keys:server:checkOwnership', function(source, cb, plate)
    if not plate then return cb(false) end
    
    local trimmedPlate = plate:gsub("%s+", ""):upper()

    if VehicleList[trimmedPlate] then
        return cb(true)
    end

    exports['tmgnosql']:FetchOne('player_vehicles', 
        { ["plate"] = trimmedPlate }, 
        function(vehicle)
            if vehicle and vehicle.citizenid then
                VehicleList[trimmedPlate] = VehicleList[trimmedPlate] or {}
                VehicleList[trimmedPlate][vehicle.citizenid] = true
                
                cb(true)
            else
                cb(false)
            end
        end,
        { ["citizenid"] = 1 }
    )
end)
function GiveKeys(id, plate)
    local Player = TMGCore.Functions.GetPlayer(id)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    if not plate then
        local ped = GetPlayerPed(id)
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 then
            plate = TMGCore.Shared.Trim(GetVehicleNumberPlateText(vehicle))
        else
            return
        end
    end

    VehicleList[plate] = VehicleList[plate] or {}
    VehicleList[plate][citizenid] = true

    local currentKeys = Player.PlayerData.metadata["vehicleKeys"] or {}
    currentKeys[plate] = true
    
    Player.Functions.SetMetaData("vehicleKeys", currentKeys)

    TriggerClientEvent('TMGCore:Notify', id, Lang:t('notify.vgetkeys'), 'success')
    TriggerClientEvent('tmg-vehiclekeys:client:AddKeys', id, plate)
    
    print(string.format("^5[TMG]^7 Keys: Authorized Citizen %s for Plate [%s]", citizenid, plate))
end

exports('GiveKeys', GiveKeys)


function RemoveKeys(id, plate)
    local Player = TMGCore.Functions.GetPlayer(id)
    if not Player or not plate then return end
    
    local citizenid = Player.PlayerData.citizenid
    local trimmedPlate = TMGCore.Shared.Trim(plate)

    if VehicleList[trimmedPlate] and VehicleList[trimmedPlate][citizenid] then
        VehicleList[trimmedPlate][citizenid] = nil
        
        if not next(VehicleList[trimmedPlate]) then
            VehicleList[trimmedPlate] = nil
        end
    end

    local currentKeys = Player.PlayerData.metadata["vehicleKeys"] or {}
    if currentKeys[trimmedPlate] then
        currentKeys[trimmedPlate] = nil
        
        Player.Functions.SetMetaData("vehicleKeys", currentKeys)
    end

    TriggerClientEvent('tmg-vehiclekeys:client:RemoveKeys', id, trimmedPlate)
    
    print(string.format("^5[TMG]^7 Keys: Revoked access for Citizen %s on Plate [%s]", citizenid, trimmedPlate))
end

exports('RemoveKeys', RemoveKeys)


function HasKeys(id, plate)
    local Player = TMGCore.Functions.GetPlayer(id)
    if not Player or not plate then return false end
    
    local citizenid = Player.PlayerData.citizenid
    local trimmedPlate = TMGCore.Shared.Trim(plate)

    if VehicleList[trimmedPlate] and VehicleList[trimmedPlate][citizenid] then
        return true
    end

    local persistentKeys = Player.PlayerData.metadata["vehicleKeys"]
    if persistentKeys and persistentKeys[trimmedPlate] then
        VehicleList[trimmedPlate] = VehicleList[trimmedPlate] or {}
        VehicleList[trimmedPlate][citizenid] = true
        return true
    end

    return false
end

exports('HasKeys', HasKeys)


TMGCore.Commands.Add('givekeys', Lang:t('addcom.givekeys'), { 
    { name = Lang:t('addcom.givekeys_id'), help = Lang:t('addcom.givekeys_id_help') } 
}, false, function(source, args)
    local src = source
    local targetId = tonumber(args[1])

    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return end

    local TargetPlayer = TMGCore.Functions.GetPlayer(targetId)
    if not targetId or not TargetPlayer then
        return TriggerClientEvent('TMGCore:Notify', src, 'Mainframe Error: Target Citizen not found in RAM.', 'error')
    end

    if src ~= targetId then
        TriggerClientEvent('tmg-vehiclekeys:client:GiveKeys', src, targetId)
    else
        TriggerClientEvent('TMGCore:Notify', src, 'Protocol Error: You cannot transmit keys to your own terminal.', 'error')
    end
end)

TMGCore.Commands.Add('addkeys', Lang:t('addcom.addkeys'), { 
    { name = Lang:t('addcom.addkeys_id'), help = Lang:t('addcom.addkeys_id_help') }, 
    { name = Lang:t('addcom.addkeys_plate'), help = Lang:t('addcom.addkeys_plate_help') } 
}, true, function(source, args)
    local src = source
    local targetId = tonumber(args[1])
    local rawPlate = args[2]

    if not targetId or not rawPlate then
        return TriggerClientEvent('TMGCore:Notify', src, 'Mainframe Alert: Invalid Terminal ID or Plate signature.', 'error')
    end

    local TargetPlayer = TMGCore.Functions.GetPlayer(targetId)
    if not TargetPlayer then
        return TriggerClientEvent('TMGCore:Notify', src, 'Mainframe Error: Target Citizen not found in RAM.', 'error')
    end

    local cleanPlate = TMGCore.Shared.Trim(rawPlate)

    GiveKeys(targetId, cleanPlate)

    TriggerClientEvent('TMGCore:Notify', src, string.format("Injected keys for [%s] into Terminal %s", cleanPlate, targetId), 'success')
    print(string.format("^1[TMG]^7 Force-Acquisition: Admin %s granted keys for [%s] to Terminal %s", src, cleanPlate, targetId))
end, 'admin')

TMGCore.Commands.Add('removekeys', Lang:t('addcom.rkeys'), { 
    { name = Lang:t('addcom.rkeys_id'), help = Lang:t('addcom.rkeys_id_help') }, 
    { name = Lang:t('addcom.rkeys_plate'), help = Lang:t('addcom.rkeys_plate_help') } 
}, true, function(source, args)
    local src = source
    local targetId = tonumber(args[1])
    local rawPlate = args[2]

    if not targetId or not rawPlate then
        return TriggerClientEvent('TMGCore:Notify', src, 'Mainframe Alert: Invalid Terminal ID or Plate signature.', 'error')
    end

    local TargetPlayer = TMGCore.Functions.GetPlayer(targetId)
    if not TargetPlayer then
        return TriggerClientEvent('TMGCore:Notify', src, 'Mainframe Error: Target Citizen not found in RAM.', 'error')
    end

    local cleanPlate = TMGCore.Shared.Trim(rawPlate)

    RemoveKeys(targetId, cleanPlate)

    TriggerClientEvent('TMGCore:Notify', src, string.format("Purged keys for [%s] from Terminal %s", cleanPlate, targetId), 'success')
    print(string.format("^1[TMG]^7 Force-Revocation: Admin %s purged keys for [%s] from Terminal %s", src, cleanPlate, targetId))
end, 'admin')
