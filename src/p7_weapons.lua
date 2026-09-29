
-- ---------- 15.1 Props & Emotes (right group) ----------

MachoMenuText(TrollProps, "Attach Object To Target")

-- The prop table has ~50 entries, well past the dropdown size the Macho
-- widgets handle reliably, so objects are picked by name substring instead.
local propBox = MachoMenuInputbox(TrollProps, "Object Name", "Ex. dog, ferris, barrel")

local attachSlot = 1
MachoMenuDropDown(TrollProps, "Attach To", function(index)
    attachSlot = index
end, "Head", "Face", "Hand", "Neck", "Back", "Feet")

local attachBones = {
    [1] = { bone = 12844, x = 0.0,  y = 0.0,  z = 0.0 },
    [2] = { bone = 31086, x = 0.0,  y = 0.0,  z = 0.0 },
    [3] = { bone = 28422, x = 0.0,  y = 0.0,  z = 0.0 },
    [4] = { bone = 31086, x = 0.0,  y = 0.0,  z = 0.10 },
    [5] = { bone = 11819, x = 0.0,  y = 0.0,  z = 0.0 },
    [6] = { bone = 14201, x = 0.0,  y = 0.0,  z = 0.0 },
}

---Exact match first, then substring, so "ferris" still finds "Ferris Wheel 2".
---@param query string
---@return string|nil model, string|nil label
local function FindProp(query)
    query = query:lower()
    for _, entry in ipairs(LS.AttachProps) do
        if entry[2]:lower() == query or entry[1]:lower() == query then
            return entry[1], entry[2]
        end
    end
    for _, entry in ipairs(LS.AttachProps) do
        if entry[2]:lower():find(query, 1, true) or entry[1]:lower():find(query, 1, true) then
            return entry[1], entry[2]
        end
    end
    return nil
end

MachoMenuButton(TrollProps, "Attach Object", function()
    local query = LS.Trim(MachoMenuGetInputbox(propBox))
    if not query then LS.Err("Enter an object name") return end

    local model, label = FindProp(query)
    if not model then LS.Err(("No prop matching '%s'"):format(query)) return end

    local slot = attachBones[attachSlot] or attachBones[1]

    LS.WithTarget(function(sid)
        LS.Run(([[
            local model = GetHashKey('%s')
            local ped = LONESTAR.PedFromServerId(%d)
            if not ped then return end
            local coords = GetEntityCoords(ped)
            local obj = CreateObject(model, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, false, false, false)
            AttachEntityToEntity(obj, ped, %d, %f, %f, %f, true, true, false, false, false, true, 1, false)
        ]]):format(model, sid, slot.bone, slot.x, slot.y, slot.z))
        LS.Ok(("%s attached"):format(label))
    end)
end)

MachoMenuText(TrollProps, "Attach Map-Scale Object (risky)")

local mapPropIndex = 1
MachoMenuDropDown(TrollProps, "Map Object", function(index)
    mapPropIndex = index
end, "None", "Ferris Wheel", "Ferris Wheel (Alt)", "Ferris Wheel (Right)", "Pier",
    "Del Perro Wheel", "Sign", "Big Wheel", "Rubbish", "Rubbish 2", "Gas Cylinder")

MachoMenuButton(TrollProps, "Attach Map Object", function()
    if mapPropIndex < 2 then LS.Info("Pick an object first") return end
    local model = LS.MapProps[mapPropIndex - 1][1]
    LS.WithTarget(function(sid)
        LS.Run(([[
            local model = GetHashKey('%s')
            local ped = LONESTAR.PedFromServerId(%d)
            if not ped then return end
            local coords = GetEntityCoords(ped)
            local obj = CreateObject(model, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, false, false, false)
            AttachEntityToEntity(obj, ped, 11816, 0.0, 0.0, 0.0, true, true, false, false, false, true, 1, false)
        ]]):format(model, sid))
        LS.Ok("Map object attached")
    end)
end)

MachoMenuText(TrollProps, "Attach Car To Target")

local carBox = MachoMenuInputbox(TrollProps, "Car Model", "Ex. neon")

MachoMenuButton(TrollProps, "Attach Car", function()
    local model = LS.Ident(MachoMenuGetInputbox(carBox))
    if not model then LS.Err("Enter a car model") return end
    LS.WithTarget(function(sid)
        LS.Run(([[
            local model = GetHashKey('%s')
            if model == 0 or not IsModelAVehicle(model) then return end
            LONESTAR.SafeRunNative(RequestModel, model)
            local t = 0
            while not HasModelLoaded(model) and t < 300 do LONESTAR.SafeRunNative(Wait, 10) t = t + 1 end
            local ped = LONESTAR.PedFromServerId(%d)
            if not ped then return end
            local coords = GetEntityCoords(ped)
            local veh = CreateVehicle(model, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, true, false)
            AttachEntityToEntity(veh, ped, 11816, 0.0, 0.0, 0.0, true, true, false, false, false, true, 1, false)
        ]]):format(model, sid))
        LS.Ok("Car attached to target")
    end)
end)

MachoMenuText(TrollProps, "Fake Animations")

MachoMenuCheckbox(TrollProps, "Fake Cuff & Drag", function()
    LS.StartLoop("Lonestar.FakeCuff", [[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        local serverId = GetPlayerServerId(PlayerId())
        -- Attach an invisible arrest prop to ourselves so others read us as cuffed.
        local prop = CreateObject(GetHashKey('prop_cs_heist_bag_02'),
            0.0, 0.0, 0.0, false, false, false)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 4103), 0.0, 0.06, 0.04, true, true, false, false, false, true, 1, false)
        SetNuiFocus(false, false)
    ]], [[
        local ped = LONESTAR.SelfPed()
        if ped then
            for _, obj in ipairs(GetGamePool('CObject')) do
                if GetEntityModel(obj) == GetHashKey('prop_cs_heist_bag_02') then
                    DetachEntity(obj, true, true)
                    DeleteEntity(obj)
                end
            end
        end
    ]])
    LS.Ok("Fake cuff active")
end, function()
    LS.StopLoop("Lonestar.FakeCuff")
    LS.Info("Fake cuff cleared")
end)

MachoMenuText(TrollProps, "Vehicle Trolls")

MachoMenuText(TrollProps, "Target Vehicle")

local vehTrollIndex = 1
MachoMenuDropDown(TrollProps, "Vehicle Action", function(index)
    vehTrollIndex = index
end, "None", "Bug Vehicle", "Spike Stripes", "Remove Wheels", "Destroy Engine",
    "Remove Doors", "Explode Tires", "Flip Vehicle", "Grab Vehicle", "Kick From Seat",
    "Delete Vehicle", "Launch Vehicle")

MachoMenuButton(TrollProps, "Apply Vehicle Action", function()
    if vehTrollIndex < 2 then LS.Info("Pick an action first") return end
    LS.WithTarget(function(sid)
        local action = vehTrollIndex
        LS.Run(([[
            local sid = %d
            local ped = LONESTAR.PedFromServerId(sid)
            if not ped then return end
            local veh = GetVehiclePedIsIn(ped, false)
            if veh == 0 then return end
            local action = %d

            if action == 2 then
                SetVehicleEngineHealth(veh, -4000.0)
            elseif action == 3 then
                for i = 0, 7 do SetVehicleTyreBurst(veh, i, true) end
            elseif action == 4 then
                for i = 0, 7 do SetVehicleWheelYRotation(veh, i, 10000.0) end
            elseif action == 5 then
                for i = 0, 5 do SetVehicleDoorOpen(veh, i, true, false) end
            elseif action == 6 then
                local coords = GetEntityCoords(veh)
                NetworkExplodeVehicle(veh, coords.x, coords.y, coords.z, true, false, false)
            elseif action == 7 then
                SetVehicleOnGroundProperly(veh)
                SetVehicleRotation(veh, 0.0, 180.0, 0.0, 0.0, 0.0, 0.0)
            elseif action == 8 then
                NetworkRequestControlOfEntity(veh)
                local t = 0
                while not NetworkHasControlOfEntity(veh) and t < 100 do Wait(10) t = t + 1 end
                TaskLeaveVehicle(ped, veh, 16)
            elseif action == 9 then
                SetVehicleDoorLockStatus(veh, 2)
            elseif action == 10 then
                NetworkRequestControlOfEntity(veh)
                SetEntityVelocity(veh, 0.0, 0.0, 20.0)
            elseif action == 11 then
                NetworkRequestControlOfEntity(veh)
                SetEntityCoords(veh, GetEntityCoords(veh).x, GetEntityCoords(veh).y, GetEntityCoords(veh).z + 100.0, false, false, false, false)
            end
        ]]):format(sid, action))
        LS.Ok("Vehicle action applied")
    end)
end)

MachoMenuButton(TrollProps, "Ram Player", function()
    LS.WithTarget(function(sid)
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if not ped then return end
            local coords = GetEntityCoords(ped)
            local model = GetHashKey('sultan')
            RequestModel(model)
            local t = 0
            while not HasModelLoaded(model) and t < 200 do Wait(10) t = t + 1 end
            local spawn = vector3(coords.x - 60.0, coords.y, coords.z + 3.0)
            local veh = CreateVehicle(model, spawn.x, spawn.y, spawn.z, 0.0, 0.0, 0.0, true, false)
            SetEntityVelocity(veh, 0.0, 200.0, 0.0)
        ]]):format(sid))
        LS.Ok("Ram incoming")
    end)
end)

MachoMenuText(TrollProps, "V2 Exploits")

MachoMenuCheckbox(TrollProps, "Stalker Ram Loop", function()
    LS.StartLoop("Lonestar.Stalker", [[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        NetworkRequestControlOfEntity(veh)
        if NetworkHasControlOfEntity(veh) then
            SetVehicleEngineOn(veh, true, true, false)
            SetVehicleForwardSpeed(veh, 120.0)
        end
    ]])
    LS.Ok("Stalker ram active")
end, function()
    LS.StopLoop("Lonestar.Stalker")
    LS.Info("Stalker ram stopped")
end)

MachoMenuCheckbox(TrollProps, "Black Hole", function()
    LS.StartLoop("Lonestar.BlackHole", [[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        local target = GetEntityCoords(ped)
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(veh) and veh ~= GetVehiclePedIsIn(ped, false) then
                local c = GetEntityCoords(veh)
                local dist = #(target - c)
                if dist < 250.0 and dist > 2.0 then
                    NetworkRequestControlOfEntity(veh)
                    local dir = target - c
                    local force = 30.0
                    SetEntityVelocity(veh, (dir / dist).x * force, (dir / dist).y * force, (dir / dist).z * force + 2.0)
                end
            end
        end
    ]])
    LS.Ok("Black hole active")
end, function()
    LS.StopLoop("Lonestar.BlackHole")
    LS.Info("Black hole stopped")
end)

-- =============================================================
-- 16. TAB: WEAPONS
--    Amiwa shipped 39 individual weapon checkboxes but every one
--    shared a single flag and every off-handler removed the knife.
--    Lonestar uses one tracked thread per weapon, so each weapon
--    has an independent, correct off state.
-- =============================================================

local WeaponTab   = MachoMenuAddTab(LS.Window, "Weapons")
local WeaponMain  = MachoMenuGroup(WeaponTab, "Spawn & Upgrade", 150, 9, 500, 500)
local WeaponMore  = MachoMenuGroup(WeaponTab, "Combat", 500, 9, 800, 500)

MachoMenuText(WeaponMain, "Give Weapon")

local weaponBox = MachoMenuInputbox(WeaponMain, "Weapon Name", "Ex. weapon_carbine_rifle")

MachoMenuButton(WeaponMain, "Give Weapon By Name", function()
    local model = LS.Trim(MachoMenuGetInputbox(weaponBox))
    if not model then LS.Err("Enter a weapon name") return end
    local hash = GetHashKey(model)
    if hash == 0 then LS.Err("Unknown weapon name") return end
    LS.Run(([[
        LONESTAR.SafeRunNative(GiveWeaponToPed, PlayerPedId(), %d, 250, 0, true)
    ]]):format(hash))
    LS.Ok(("Gave %s"):format(model))
end)

MachoMenuButton(WeaponMain, "Clear Weapons", function()
    LS.Run([[ LONESTAR.SafeRunNative(RemoveAllPedWeapons, PlayerPedId(), true) ]])
    LS.Ok("Weapons cleared")
end)

MachoMenuButton(WeaponMain, "Fully Upgrade Weapon", function()
    -- Amiwa's full-component pass plus a gold finish.
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        local comps = {
            0, 1, 2, 4, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25
        }
        for _, c in ipairs(comps) do
            for _, weapon in ipairs({ GetHashKey('WEAPON_PISTOL'), GetHashKey('WEAPON_SMG'),
                GetHashKey('WEAPON_CARBINERIFLE'), GetHashKey('WEAPON_SPECIALCARBINE') }) do
                GiveWeaponToPed(ped, weapon, 30, false, true)
                SetPedWeaponComponentEnabled(ped, weapon, c, true)
            end
        end
        SetPedWeaponTintIndex(ped, 0, 6)
    ]])
    LS.Ok("Weapon fully upgraded")
end)

MachoMenuText(WeaponMain, "Quick Give")

local quickWeaponIndex = 1
MachoMenuDropDown(WeaponMain, "Weapon Class", function(index)
    quickWeaponIndex = index
end, "None", "Melee", "Handguns", "SMG", "Rifles", "Shotguns", "Snipers", "Heavy", "Throwables")

local quickWeaponNames = { "Melee", "Handguns", "SMG", "Rifles", "Shotguns", "Snipers", "Heavy", "Throwables" }

MachoMenuButton(WeaponMain, "Give First Of Class", function()
    if quickWeaponIndex < 2 then LS.Info("Pick a class first") return end
    local group = LS.Weapons[quickWeaponNames[quickWeaponIndex - 1]]
    if not group or #group == 0 then LS.Err("Empty class") return end
    local model = group[1][1]
    LS.Run(([[ LONESTAR.SafeRunNative(GiveWeaponToPed, PlayerPedId(), GetHashKey('%s'), 250, 0, true) ]]):format(model))
    LS.Ok(("Gave %s"):format(group[1][2]))
end)

MachoMenuText(WeaponMain, "Ammo")

local ammoValue = 300
MachoMenuSlider(WeaponMain, "Ammo Refill", 300, 1, 300, " rnds", 5, function(value)
    ammoValue = math.floor(value)
end)

MachoMenuButton(WeaponMain, "Refill Ammo", function()
    LS.Run(([[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        local weapon = GetSelectedPedWeapon(ped)
        local ammo = %d
        SetPedAmmo(ped, weapon, ammo)
        if GetPedWeaponShootType(ped) == 4 then
            for _, t in ipairs({ 0, 1, 2 }) do SetPedAmmoByType(ped, weapon, t, ammo) end
        else
            SetPedAmmoByType(ped, weapon, 0, ammo)
        end
    ]]):format(ammoValue))
    LS.Ok("Ammo refilled")
end)

MachoMenuText(WeaponMain, "Attachments")

local attachIndex = 1
MachoMenuDropDown(WeaponMain, "Component", function(index)
    attachIndex = index
end, "None", "Flashlight", "Suppressor", "Barrel", "Scoop", "Skin", "Scopes (Big)",
    "Scope Small", "Muzzle", "Drum", "Rail", "Luxe Finisher", "Luxe Skin")

MachoMenuButton(WeaponMain, "Add Component", function()
    if attachIndex < 2 then LS.Info("Pick a component first") return end
    local component = LS.Attachments[attachIndex - 1][1]
    LS.Run(([[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        local weapon = GetSelectedPedWeapon(ped)
        for i = 0, 40 do
            if i ~= 13 then SetPedWeaponComponentEnabled(ped, weapon, i, false) end
        end
        SetPedWeaponComponentEnabled(ped, weapon, %d, true)
    ]]):format(component))
    LS.Ok("Component added")
end)

MachoMenuButton(WeaponMain, "Remove All Components", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        local weapon = GetSelectedPedWeapon(ped)
        for i = 0, 40 do SetPedWeaponComponentEnabled(ped, weapon, i, false) end
    ]])
    LS.Ok("Components removed")
end)

MachoMenuText(WeaponMore, "Ammo & Damage Modifiers")

MachoMenuCheckbox(WeaponMore, "Infinite Ammo", function()
    LS.StartLoop("Lonestar.InfAmmo", [[
        local ped = LONESTAR.SelfPed()
        if ped then SetPedInfiniteAmmoClip(ped, true) end
    ]])
    LS.Ok("Infinite ammo enabled")
end, function()
    LS.StopLoop("Lonestar.InfAmmo")
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if ped then SetPedInfiniteAmmoClip(ped, false) end
    ]])
    LS.Info("Infinite ammo disabled")
end)

MachoMenuCheckbox(WeaponMore, "Explosive Ammo", function()
    LS.StartLoop("Lonestar.ExplAmmo", [[
        local ped = LONESTAR.SelfPed()
        if not ped or not HasEntityBeenDamaged(ped) then return end
        local impact = GetPedLastWeaponImpactCoord(ped)
        AddExplosion(impact.x, impact.y, impact.z, 12, 0.0, false, false, 0.0, false, false)
    ]])
    LS.Ok("Explosive ammo enabled")
end, function()
    LS.StopLoop("Lonestar.ExplAmmo")
    LS.Info("Explosive ammo disabled")
end)

MachoMenuCheckbox(WeaponMore, "Rapid Fire (10 Round Burst)", function()
    LS.StartLoop("Lonestar.RapidFire", [[
        if not IsControlPressed(0, 24) then return end
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        local weapon = GetSelectedPedWeapon(ped)
        local coords = GetEntityCoords(ped)
        local camRot = GetGameplayCamRot(2)
        local fwd = LONESTAR.FreeCamRotToDirection and LONESTAR.FreeCamRotToDirection(camRot)
            or vector3(-math.sin(math.rad(camRot.z)), math.cos(math.rad(camRot.z)), 0.0)
        for i = 1, 10 do
            local spread = vector3(
                coords.x + fwd.x * 100.0 + (i - 5) * 0.4,
                coords.y + fwd.y * 100.0,
                coords.z + fwd.z * 100.0)
            ShootSingleBulletBetweenCoords(
                coords.x, coords.y, coords.z + 0.6,
                spread.x, spread.y, spread.z, true, true, weapon, ped, 1)
        end
    ]])
    LS.Ok("Rapid fire enabled - hold LMB")
end, function()
    LS.StopLoop("Lonestar.RapidFire")
    LS.Info("Rapid fire disabled")
end)

MachoMenuText(WeaponMore, "Aimbot / Reach")

MachoMenuCheckbox(WeaponMore, "Anti-Headshot (Weapon)", function()
    LS.StartLoop("Lonestar.WeaponHeadshot", [[
        LONESTAR.SafeRunNative(SetPedSuffersCriticalHits, PlayerPedId(), false)
        LONESTAR.SafeRunNative(SetPedCanRagdoll, PlayerPedId(), false)
    ]])
    LS.Ok("Anti-headshot enabled")
end, function()
    LS.StopLoop("Lonestar.WeaponHeadshot")
    LS.Info("Anti-headshot disabled")
end)

MachoMenuCheckbox(WeaponMore, "Ignore Max Range", function()
    LS.Run([[
        LONESTAR.SafeRunNative(SetPlayerCanDoDriveBy, PlayerId(), true)
        LONESTAR.SafeRunNative(SetPedSuffersCriticalHits, PlayerPedId(), false)
    ]])
    LS.Ok("Max range ignored")
end)

MachoMenuCheckbox(WeaponMore, "No Recoil", function()
    LS.StartLoop("Lonestar.NoRecoil", [[
        local ped = LONESTAR.SelfPed()
        if ped then
            LONESTAR.SafeRunNative(SetPedConfigFlag, ped, 6, false)
        end
    ]])
    LS.Ok("No recoil enabled")
end, function()
    LS.StopLoop("Lonestar.NoRecoil")
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if ped then LONESTAR.SafeRunNative(SetPedConfigFlag, ped, 6, true) end
    ]])
    LS.Info("No recoil disabled")
end)

MachoMenuText(WeaponMore, "Force Weapon (independent toggles)")

local forceWeapons = {
    "weapon_knife", "weapon_switchblade", "weapon_bat", "weapon_crowbar",
    "weapon_pistol", "weapon_combatpistol", "weapon_pistol_mk2", "weapon_appistol",
    "weapon_heavypistol", "weapon_pistol50",
    "weapon_microsmg", "weapon_smg", "weapon_assaultsmg", "weapon_minismg", "weapon_combatpdw",
    "weapon_pumpshotgun", "weapon_sawnoffshotgun", "weapon_pumpshotgun_mk2",
    "weapon_assaultrifle", "weapon_carbinerifle", "weapon_specialcarbine", "weapon_advancedrifle",
    "weapon_bullpuprifle", "weapon_marksmanrifle", "weapon_marksmanrifle_mk2",
    "weapon_sniperrifle", "weapon_heavysniper",
    "weapon_mg", "weapon_gusenberg", "weapon_compactrifle",
    "weapon_rpg", "weapon_grenadelauncher", "weapon_minigun", "weapon_hominglauncher",
}

local forceSlot = 1
MachoMenuDropDown(WeaponMore, "Force Weapon", function(index)
    forceSlot = index
end, "None", "Knife", "Switchblade", "Bat", "Crowbar", "Pistol", "Combat Pistol",
    "Pistol Mk II", "AP Pistol", "Heavy Pistol", "Pistol .50", "Micro SMG", "SMG",
    "Assault SMG", "Mini SMG", "Combat PDW", "Pump Shotgun", "Sawed-Off", "Pump Mk II",
    "Assault Rifle", "Carbine Rifle", "Special Carbine", "Advanced Rifle", "Bullpup",
    "Marksman", "Marksman Mk II", "Sniper", "Heavy Sniper", "MG", "Gusenberg",
    "Compact Rifle", "RPG", "Grenade Launcher", "Minigun", "Homing Launcher")

MachoMenuCheckbox(WeaponMore, "Force Selected Weapon", function()
    if forceSlot < 2 then LS.Err("Pick a weapon first") return end
    local model = forceWeapons[forceSlot - 1]
    -- One tracked thread per weapon, so toggles never collide.
    LS.StartLoop(("Lonestar.Weapon.%s"):format(model), ([==[
        LONESTAR.SafeRunNative(RemoveAllPedWeapons, PlayerPedId(), true)
        LONESTAR.SafeRunNative(GiveWeaponToPed, PlayerPedId(), GetHashKey('%s'), 999, 0, true)
    ]==]):format(model))
    LS.Ok("Weapon forced")
end, function()
    if forceSlot < 2 then return end
    local model = forceWeapons[forceSlot - 1]
    LS.StopLoop(("Lonestar.Weapon.%s"):format(model))
    LS.Run(([[ LONESTAR.SafeRunNative(RemoveAllPedWeapons, PlayerPedId(), true) ]]))
    LS.Info("Weapon removed")
end)

MachoMenuText(WeaponMore, "HUD")

MachoMenuCheckbox(WeaponMore, "Crosshair", function()
    LS.StartLoop("Lonestar.Crosshair", [[
        Wait(0)
        if not IsHudComponentVisible(14) then RequestHudComponent(14) end
        SetHudComponentSize(14, 0.24, 0.24)
        SetHudComponentPosition(14, 0.5, 0.5)
    ]])
    LS.Ok("Crosshair enabled")
end, function()
    LS.StopLoop("Lonestar.Crosshair")
    LS.Run([[ HideHudComponentThisFrame(14) ]])
    LS.Info("Crosshair disabled")
end)
