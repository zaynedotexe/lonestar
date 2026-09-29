
-- =============================================================
-- 17. TAB: VEHICLE
-- =============================================================

local VehTab   = MachoMenuAddTab(LS.Window, "Vehicle")
local VehMain  = MachoMenuGroup(VehTab, "Spawn", 150, 9, 500, 500)
local VehMore  = MachoMenuGroup(VehTab, "Toggles & Repair", 500, 9, 800, 500)

MachoMenuText(VehMain, "Spawn Vehicle")

local spawnCarBox = MachoMenuInputbox(VehMain, "Vehicle Model", "Ex. neon")

local spawnPlateBox = MachoMenuInputbox(VehMain, "Custom Plate", "Leave blank for random")

local spawnIndex = 1
MachoMenuDropDown(VehMain, "Common Vehicle", function(index)
    spawnIndex = index
end, "None", "Adder", "Zentorno", "Comet 2", "Sultan", "Sunrise", "Jugular", "Komoda",
    "Neon", "Kuruma", "Pounder", "Patriot", "Sultan RS", "Turismo R", "Vigilante",
    "Ruiner 2", "Buffalo S")

---@param model string
---@param plate string
function LS.SpawnVehicle(model, plate)
    model = LS.Ident(model)
    if not model then LS.Err("Enter a valid vehicle model") return end

    plate = tostring(plate or ""):upper():gsub("[^%w ]", "")

    -- Framework spawners are preferred so the vehicle is networked for everyone.
    local code = ([[
        local model   = '%s'
        local plate   = '%s'
        local hash    = GetHashKey(model)
        if hash == 0 or not IsModelAVehicle(hash) then return end

        LONESTAR.SafeRunNative(RequestModel, hash)
        local t = 0
        while not HasModelLoaded(hash) and t < 400 do
            LONESTAR.SafeRunNative(Wait, 10)
            t = t + 1
        end

        local ped     = LONESTAR.SelfPed()
        local coords  = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)

        if GetResourceState('jg-mechanic') == 'started' then
            TriggerEvent('jg-mechanic:client:spawnVehicle', model, false, false, false)
            return
        end

        if plate == '' then
            plate = 'LS' .. tostring(math.random(1000, 9999))
        end

        local veh = LONESTAR.SafeRunNative(CreateVehicle, hash,
            coords.x + 3.0, coords.y, coords.z, heading, true, false)
        local netId = NetworkGetNetworkIdFromEntity(veh)
        SetNetworkIdExistsOnAllMachines(netId, true)
        NetworkRequestControlOfEntity(veh)
        LONESTAR.SafeRunNative(SetVehicleNumberPlateText, veh, plate)

        if GetResourceState('es_extended') == 'started' then
            TriggerServerEvent('esx:spawnVehicle', model, netId, plate)
        elseif GetResourceState('esx_policejobs') == 'started' then
            TriggerServerEvent('esx_vehicleshop:setVehicleOwned', netId, plate)
        end

        LONESTAR.SafeRunNative(SetModelAsNoLongerNeeded, hash)
    ]]):format(model, plate)

    LS.Raw(code, LS.VehicleTarget())
end

MachoMenuButton(VehMain, "Spawn Vehicle", function()
    local model = LS.Ident(MachoMenuGetInputbox(spawnCarBox)) or
        (spawnIndex > 1 and LS.CommonVehicles[spawnIndex - 1][1]) or nil
    if not model then LS.Err("Enter a valid vehicle model") return end
    LS.SpawnVehicle(model, LS.Trim(MachoMenuGetInputbox(spawnPlateBox)) or "")
    LS.Ok(("Spawning %s"):format(model))
end)

MachoMenuButton(VehMain, "Spawn & Sit Inside", function()
    local model = LS.Ident(MachoMenuGetInputbox(spawnCarBox)) or
        (spawnIndex > 1 and LS.CommonVehicles[spawnIndex - 1][1]) or nil
    if not model then LS.Err("Enter a valid vehicle model") return end

    LS.Run(([[
        local model = '%s'
        local hash = GetHashKey(model)
        if hash == 0 or not IsModelAVehicle(hash) then return end
        LONESTAR.SafeRunNative(RequestModel, hash)
        local t = 0
        while not HasModelLoaded(hash) and t < 400 do LONESTAR.SafeRunNative(Wait, 10) t = t + 1 end
        local ped = LONESTAR.SelfPed()
        local coords = GetEntityCoords(ped)
        local veh = CreateVehicle(hash, coords.x + 3.0, coords.y, coords.z, GetEntityHeading(ped), true, false)
        SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(veh), true)
        LONESTAR.SafeRunNative(SetPedIntoVehicle, ped, veh, -1)
        LONESTAR.SafeRunNative(SetModelAsNoLongerNeeded, hash)
    ]]):format(model))
    LS.Ok("Vehicle spawned - you are inside")
end)

MachoMenuText(VehMain, "Addon Vehicles")

MachoMenuButton(VehMain, "Scan Vehicle Addons", function()
    local found = {}
    local self = GetCurrentResourceName()
    for i = 0, GetNumResources() - 1 do
        local res = GetResourceByFindIndex(i)
        if res and res ~= self then
            local meta = GetResourceMetadata(res, "vehicles_meta")
            if meta or LoadResourceFile(res, "vehicles.meta") then
                found[#found + 1] = res
            end
        end
    end
    if #found == 0 then
        LS.Info("No vehicle metas found")
    else
        print("^3[Lonestar]^7 Vehicle resources: " .. table.concat(found, ", "))
        LS.Ok(("%d resources with vehicle data"):format(#found))
    end
end)

MachoMenuText(VehMore, "Repair & Clean")

MachoMenuButton(VehMore, "Repair Vehicle", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        LONESTAR.SafeRunNative(SetVehicleFixed, veh)
        LONESTAR.SafeRunNative(SetVehicleBodyHealth, veh, 1000.0)
        LONESTAR.SafeRunNative(SetVehicleEngineHealth, veh, 1000.0)
        LONESTAR.SafeRunNative(SetVehiclePetrolTankHealth, veh, 1000.0)
    ]])
    LS.Ok("Vehicle repaired")
end)

MachoMenuButton(VehMore, "Clean Vehicle", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        LONESTAR.SafeRunNative(SetVehicleDirtLevel, veh, 0.0)
        LONESTAR.SafeRunNative(SetVehicleBodyHealth, veh, 1000.0)
        LONESTAR.SafeRunNative(CleanVehicle, veh)
    ]])
    LS.Ok("Vehicle cleaned")
end)

MachoMenuButton(VehMore, "Set Vehicle Engine Health", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        LONESTAR.SafeRunNative(SetVehicleEngineHealth, GetVehiclePedIsIn(ped, false), 1000.0)
    ]])
    LS.Ok("Engine restored")
end)

MachoMenuButton(VehMore, "Force Engine On", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        LONESTAR.SafeRunNative(SetVehicleEngineOn, GetVehiclePedIsIn(ped, false), true, true, false)
        LONESTAR.SafeRunNative(SetVehicleUndriveable, GetVehiclePedIsIn(ped, false), false)
    ]])
    LS.Ok("Engine forced on")
end)

MachoMenuText(VehMore, "Vehicle Toggles")

MachoMenuCheckbox(VehMore, "Vehicle Godmode", function()
    LS.StartLoop("Lonestar.VehGod", [[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        SetVehicleCanBeVisiblyDamaged(veh, false)
    ]])
    LS.Ok("Vehicle godmode enabled")
end, function()
    LS.StopLoop("Lonestar.VehGod")
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if ped and IsPedInAnyVehicle(ped, false) then
            SetVehicleCanBeVisiblyDamaged(GetVehiclePedIsIn(ped, false), true)
        end
    ]])
    LS.Info("Vehicle godmode disabled")
end)

MachoMenuCheckbox(VehMore, "Auto Repair", function()
    LS.StartLoop("Lonestar.VehRepair", [[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehicleEngineHealth(veh, 1000.0)
    ]])
    LS.Ok("Auto repair enabled")
end, function()
    LS.StopLoop("Lonestar.VehRepair")
    LS.Info("Auto repair disabled")
end)

MachoMenuCheckbox(VehMore, "Auto Clean", function()
    LS.StartLoop("Lonestar.VehClean", [[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        SetVehicleDirtLevel(GetVehiclePedIsIn(ped, false), 0.0)
    ]])
    LS.Ok("Auto clean enabled")
end, function()
    LS.StopLoop("Lonestar.VehClean")
    LS.Info("Auto clean disabled")
end)

MachoMenuCheckbox(VehMore, "Unlimited Fuel", function()
    LS.StartLoop("Lonestar.Fuel", [[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        if GetResourceState('ox_fuel') == 'started' then
            TriggerEvent('ox_fuel:setFuel', veh, 100.0)
        elseif GetResourceState('LegacyFuel') == 'started' then
            TriggerEvent('LegacyFuel:Client:Refuel', veh, 100.0)
        elseif GetResourceState('cdn-fuel') == 'started' then
            TriggerEvent('cdn-fuel:client:refuel', veh, 100.0)
        else
            SetVehicleFuelLevel(veh, 100.0)
        end
    ]])
    LS.Ok("Unlimited fuel enabled")
end, function()
    LS.StopLoop("Lonestar.Fuel")
    LS.Info("Unlimited fuel disabled")
end)

MachoMenuCheckbox(VehMore, "Rainbow Vehicle", function()
    -- Allstar's version snapshots the colours and restores them on disable.
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        local p1, p2, p3 = 0, 0, 0
        LONESTAR.SavedVehicleColours = {
            p1 = GetVehicleCustomPrimaryColour(veh),
            p2 = GetVehicleCustomSecondaryColour(veh),
            p3 = GetVehicleCustomPearlescentColour(veh),
        }
    ]])
    LS.StartLoop("Lonestar.Rainbow", [[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        local h = (GetGameTimer() / 12) % 360.0
        local r, g, b = HSVToRGB(h, 1.0, 1.0)
        SetVehicleCustomPrimaryColour(veh, math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
        SetVehicleCustomSecondaryColour(veh, math.floor(r * 128), math.floor(g * 128), math.floor(b * 128))
        if math.random(0, 20) == 0 then
            SetVehicleNeonLightsEnabled(veh, true)
            SetVehicleNeonLightsColour(veh, r, g, b)
        end
    ]], [[
        local ped = LONESTAR.SelfPed()
        if ped and IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            local c = LONESTAR.SavedVehicleColours
            if c then
                SetVehicleCustomPrimaryColour(veh, c.p1 or 0, 0, 0)
                SetVehicleCustomSecondaryColour(veh, c.p2 or 0, 0, 0)
            end
            SetVehicleNeonLightsEnabled(veh, false)
        end
        LONESTAR.SavedVehicleColours = nil
    ]])
    LS.Ok("Rainbow enabled")
end, function()
    LS.StopLoop("Lonestar.Rainbow")
    LS.Info("Rainbow disabled")
end)

MachoMenuCheckbox(VehMore, "No Fall Off", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if ped and IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            SetVehicleReduceGrip(veh, 100.0)
            SetVehicleFlags(veh, 0, true)
        end
    ]])
    LS.Ok("No fall off enabled")
end)

MachoMenuCheckbox(VehMore, "Hard Braking", function()
    LS.StartLoop("Lonestar.HardBrake", [[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        SetVehicleBrake(veh, true, 8)
    ]], [[
        local ped = LONESTAR.SelfPed()
        if ped and IsPedInAnyVehicle(ped, false) then
            SetVehicleBrake(GetVehiclePedIsIn(ped, false), false, 0)
        end
    ]])
    LS.Ok("Hard braking enabled")
end, function()
    LS.StopLoop("Lonestar.HardBrake")
    LS.Info("Hard braking disabled")
end)

MachoMenuCheckbox(VehMore, "Shift Boost", function()
    LS.StartLoop("Lonestar.Boost", [[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        if not IsControlPressed(0, 21) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        NetworkRequestControlOfEntity(veh)
        if NetworkHasControlOfEntity(veh) then
            SetVehicleForwardSpeed(veh, GetEntitySpeed(veh) + 22.0)
            SetVehicleEngineOn(veh, true, true, false)
        end
    ]])
    LS.Ok("Shift boost enabled")
end, function()
    LS.StopLoop("Lonestar.Boost")
    LS.Info("Shift boost disabled")
end)

MachoMenuCheckbox(VehMore, "Disable Vehicle Locks", function()
    LS.StartLoop("Lonestar.NoLocks", [[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        SetVehicleDoorLockStatus(GetVehiclePedIsIn(ped, false), 1)
        SetVehicleDoorsLocked(1)
    ]])
    LS.Ok("Locks disabled")
end, function()
    LS.StopLoop("Lonestar.NoLocks")
    LS.Info("Locks restored")
end)

MachoMenuCheckbox(VehMore, "Vehicle Fly", function()
    -- Allstar's version restores alpha, collision and gravity on exit.
    LS.StartLoop("Lonestar.VehFly", [[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        NetworkRequestControlOfEntity(veh)
        if not NetworkHasControlOfEntity(veh) then return end

        SetEntityVisible(veh, false, true)
        SetEntityCollision(veh, false, false)
        SetVehicleGravity(veh, false)

        if IsControlPressed(0, 22) then SetEntityVelocity(veh, 0.0, 0.0, 25.0) end
        if IsControlPressed(0, 36) then SetEntityVelocity(veh, 0.0, 0.0, -25.0) end
        if IsControlPressed(0, 32) then SetEntityVelocity(veh, 25.0, 0.0, 0.0) end
        if IsControlPressed(0, 33) then SetEntityVelocity(veh, -25.0, 0.0, 0.0) end
        if IsControlPressed(0, 35) then SetEntityVelocity(veh, 0.0, 25.0, 0.0) end
        if IsControlPressed(0, 34) then SetEntityVelocity(veh, 0.0, -25.0, 0.0) end
    ]], [[
        local ped = LONESTAR.SelfPed()
        if ped and IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            SetEntityVisible(veh, true, true)
            SetEntityCollision(veh, true, true)
            SetVehicleGravity(veh, true)
            SetEntityVelocity(veh, 0.0, 0.0, 0.0)
        end
    ]])
    LS.Ok("Vehicle fly enabled")
end, function()
    LS.StopLoop("Lonestar.VehFly")
    LS.Info("Vehicle fly disabled")
end)

MachoMenuText(VehMore, "Vehicle Utility")

MachoMenuButton(VehMore, "Delete Vehicle", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        NetworkRequestControlOfEntity(veh)
        LONESTAR.SafeRunNative(DeleteEntity, veh)
    ]])
    LS.Ok("Vehicle deleted")
end)

MachoMenuButton(VehMore, "Remove All Doors", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        for i = 0, 5 do SetVehicleDoorOpen(veh, i, true, false) end
        SetVehicleDoorOpen(veh, 5, true, false)
    ]])
    LS.Ok("Doors removed")
end)

MachoMenuButton(VehMore, "Teleport Into Closest Vehicle", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        local handle, veh = FindFirstVehicle()
        local done = false
        repeat
            local dist = #(GetEntityCoords(veh) - GetEntityCoords(ped))
            if not done and dist < 80.0 then
                NetworkRequestControlOfEntity(veh)
                SetVehicleDoorsLockedForAllPlayers(veh, true)
                SetVehicleDoorsLocked(veh, 1)
                if IsVehicleSeatFree(veh, -1) then
                    TaskWarpPedIntoVehicle(ped, veh, -1)
                    done = true
                end
            end
        until not FindNextVehicle(handle)
        EndFindVehicle(handle)
    ]])
    LS.Ok("Entered closest vehicle")
end)

MachoMenuText(VehMore, "Vehicle Stunts")

local stuntIndex = 1
MachoMenuDropDown(VehMore, "Stunt", function(index)
    stuntIndex = index
end, "None", "Jump", "Back Flip", "Kick Flip", "Flip", "Rocket Boost", "Tornado")

MachoMenuButton(VehMore, "Perform Stunt", function()
    if stuntIndex < 2 then LS.Info("Pick a stunt first") return end
    local stunt = stuntIndex
    LS.Run(([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        NetworkRequestControlOfEntity(veh)
        local stunt = %d
        if stunt == 2 then
            SetEntityVelocity(veh, 0.0, 0.0, 45.0)
        elseif stunt == 3 then
            SetEntityRotation(veh, 0.0, 0.0, 180.0, 2, true)
            SetEntityVelocity(veh, 0.0, 0.0, 25.0)
        elseif stunt == 4 then
            SetEntityRotation(veh, 0.0, 0.0, 360.0, 2, true)
            SetEntityVelocity(veh, 0.0, 0.0, 30.0)
        elseif stunt == 5 then
            SetEntityRotation(veh, 0.0, 0.0, 720.0, 2, true)
        elseif stunt == 6 then
            SetEntityVelocity(veh, 0.0, 0.0, 60.0)
        elseif stunt == 7 then
            SetEntityAngularVelocity(veh, 0.0, 0.0, 15.0)
        end
    ]]):format(stunt))
    LS.Ok("Stunt performed")
end)

MachoMenuButton(VehMore, "Teleport To Nearest Vehicle", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        local handle, veh = FindFirstVehicle()
        local best, bestDist = 0, 999999.0
        repeat
            local dist = #(GetEntityCoords(veh) - GetEntityCoords(ped))
            if dist < bestDist then best, bestDist = veh, dist end
        until not FindNextVehicle(handle)
        EndFindVehicle(handle)
        if best ~= 0 then
            local c = GetEntityCoords(best)
            LONESTAR.TeleportTo(c.x + 2.0, c.y, c.z + 1.0, true)
        end
    ]])
    LS.Ok("Teleported to nearest vehicle")
end)

-- =============================================================
-- 18. TAB: UPGRADES
-- =============================================================

local UpTab   = MachoMenuAddTab(LS.Window, "Upgrades")
local UpMain  = MachoMenuGroup(UpTab, "Performance", 150, 9, 500, 500)
local UpMore  = MachoMenuGroup(UpTab, "Cosmetics", 500, 9, 800, 500)

MachoMenuButton(UpMain, "Max All Tuning", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)

        for i = 11, 85 do
            if i ~= 45 and i ~= 65 then
                SetVehicleModKit(veh, i)
                local count = GetNumVehicleMods(veh, i)
                if count > 0 then SetVehicleMod(veh, i, count - 1, false) end
            end
        end

        SetVehicleModKit(veh, 0)
        SetVehicleMod(veh, 17, 0, false)   -- front bump
        SetVehicleMod(veh, 18, 0, false)   -- rear bump
        SetVehicleMod(veh, 15, 0, false)   -- suspension
        SetVehicleMod(veh, 13, 1, false)   -- transmission
        SetVehicleMod(veh, 11, 1, false)   -- engine
        SetVehicleMod(veh, 16, 2, false)   -- brakes

        SetVehicleWheelType(veh, 7)
        SetVehicleWindowTint(veh, 0)
        SetVehicleExtraLights(veh, true)
        SetVehicleNeonLightsEnabled(veh, true)
        SetVehicleNeonLightsColour(veh, 255, 0, 255)
    ]])
    LS.Ok("Vehicle fully tuned")
end)

MachoMenuText(UpMain, "Performance Mods")

local perfIndex = 1
MachoMenuDropDown(UpMain, "Performance Part", function(index)
    perfIndex = index
end, "None", "Engine", "Transmission", "Brakes", "Tyres", "Armor", "Turbo")

local perfVersion = 3
MachoMenuSlider(UpMain, "Mod Level", 10, 0, 3, "", 1, function(value)
    perfVersion = math.floor(value)
end)

MachoMenuButton(UpMain, "Apply Performance Mod", function()
    if perfIndex < 2 then LS.Info("Pick a part first") return end
    local modIndex, modName = LS.PerformanceMods[perfIndex - 1][1], LS.PerformanceMods[perfIndex - 1][2]
    LS.Run(([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        SetVehicleModKit(veh, %d)
        local max = GetNumVehicleMods(veh, %d) - 1
        local level = math.min(%d, math.max(0, max))
        SetVehicleMod(veh, %d, level, false)
    ]]):format(modIndex, modIndex, perfVersion, modIndex))
    LS.Ok(("%s set to level %d"):format(modName, perfVersion))
end)

MachoMenuButton(UpMain, "Install Bulletproof Tyres", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        for i = 0, 7 do SetVehicleTyreProofLevel(veh, i, 1000.0) end
    ]])
    LS.Ok("Tyres upgraded")
end)

MachoMenuCheckbox(UpMain, "Turbo", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        SetVehicleTurbo(veh, true)
        SetVehicleEngineOn(veh, true, true, true)
    ]])
    LS.Ok("Turbo installed")
end, function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if ped and IsPedInAnyVehicle(ped, false) then
            SetVehicleTurbo(GetVehiclePedIsIn(ped, false), false)
        end
    ]])
    LS.Info("Turbo removed")
end)

MachoMenuText(UpMain, "jg-mechanic Tuning")

MachoMenuButton(UpMain, "Ceramic Brakes", function()
    if not LS.Running("jg-mechanic") then LS.Info("jg-mechanic not found") return end
    LS.Raw([[ TriggerEvent('jg-mechanic:client:toggleTuning', 'brakes', 1) ]], "jg-mechanic")
    LS.Ok("Ceramic brakes applied")
end)

MachoMenuButton(UpMain, "Drivetrain (AWD)", function()
    if not LS.Running("jg-mechanic") then LS.Info("jg-mechanic not found") return end
    LS.Raw([[ TriggerEvent('jg-mechanic:client:toggleTuning', 'drivetrain', 1) ]], "jg-mechanic")
    LS.Ok("Drivetrain set")
end)

MachoMenuButton(UpMain, "Nitro", function()
    if not LS.Running("jg-mechanic") then LS.Info("jg-mechanic not found") return end
    LS.Raw([[ TriggerEvent('jg-mechanic:client:toggleTuning', 'nitro', 1) ]], "jg-mechanic")
    LS.Ok("Nitro applied")
end)

MachoMenuText(UpMore, "Colours")

local primaryBox  = MachoMenuInputbox(UpMore, "Primary RGB", "Ex. 255,0,0")
local secondaryBox = MachoMenuInputbox(UpMore, "Secondary RGB", "Ex. 0,0,255")
local pearlBox     = MachoMenuInputbox(UpMore, "Pearlescent (0-159)", "Ex. 12")
local plateBox     = MachoMenuInputbox(UpMore, "Plate", "Ex. LONESTAR")

---@param box userdata
---@return integer|nil, integer|nil, integer|nil
local function ReadRGB(box)
    local raw = LS.Trim(MachoMenuGetInputbox(box))
    if not raw then return nil end
    local r, g, b = raw:match("^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
    if not r then return nil end
    return math.min(tonumber(r), 255), math.min(tonumber(g), 255), math.min(tonumber(b), 255)
end

MachoMenuButton(UpMore, "Set Primary Colour", function()
    local r, g, b = ReadRGB(primaryBox)
    if not r then LS.Err("Use format r,g,b") return end
    LS.Run(([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        SetVehicleCustomPrimaryColour(GetVehiclePedIsIn(ped, false), %d, %d, %d)
    ]]):format(r, g, b))
    LS.Ok("Primary colour set")
end)

MachoMenuButton(UpMore, "Set Secondary Colour", function()
    local r, g, b = ReadRGB(secondaryBox)
    if not r then LS.Err("Use format r,g,b") return end
    LS.Run(([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        SetVehicleCustomSecondaryColour(GetVehiclePedIsIn(ped, false), %d, %d, %d)
    ]]):format(r, g, b))
    LS.Ok("Secondary colour set")
end)

MachoMenuButton(UpMore, "Set Pearlescent Colour", function()
    local v = tonumber(LS.Trim(MachoMenuGetInputbox(pearlBox)) or "")
    if not v then LS.Err("Enter a number 0-159") return end
    LS.Run(([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        SetVehiclePearlescentColour(GetVehiclePedIsIn(ped, false), %d)
    ]]):format(math.min(math.max(v, 0), 159)))
    LS.Ok("Pearlescent set")
end)

MachoMenuButton(UpMore, "Set Plate", function()
    local plate = LS.Trim(MachoMenuGetInputbox(plateBox))
    if not plate then LS.Err("Enter a plate") return end
    LS.Run(([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        SetVehicleNumberPlateText(veh, '%s')
        SetVehicleNumberPlateTextIndex(veh, 1)
    ]]):format(plate:upper():gsub("[^%w ]", "")))
    LS.Ok("Plate changed")
end)

MachoMenuText(UpMore, "Body Mods")

local bodyIndex = 1
MachoMenuDropDown(UpMore, "Body Part", function(index)
    bodyIndex = index
end, "None", "Spoiler", "Hood", "Side Skirt", "Suspension", "Exhaust")

local bodyVersion = 0
MachoMenuSlider(UpMore, "Body Mod Level", 10, 0, 0, "", 1, function(value)
    bodyVersion = math.floor(value)
end)

MachoMenuButton(UpMore, "Apply Body Mod", function()
    if bodyIndex < 2 then LS.Info("Pick a part first") return end
    local modIndex = LS.VehicleMods[bodyIndex - 1][1]
    LS.Run(([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        SetVehicleModKit(veh, %d)
        local max = GetNumVehicleMods(veh, %d) - 1
        SetVehicleMod(veh, %d, math.min(%d, math.max(0, max)), false)
    ]]):format(modIndex, modIndex, modIndex, bodyVersion))
    LS.Ok("Body mod applied")
end)

MachoMenuCheckbox(UpMore, "Neon Lights", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        SetVehicleNeonLightsEnabled(veh, true)
        SetVehicleNeonLightsColour(veh, 255, 0, 255)
    ]])
    LS.Ok("Neon enabled")
end, function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if ped and IsPedInAnyVehicle(ped, false) then
            SetVehicleNeonLightsEnabled(GetVehiclePedIsIn(ped, false), false)
        end
    ]])
    LS.Info("Neon disabled")
end)
