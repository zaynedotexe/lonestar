
-- =============================================================
-- 14. TAB: TELEPORT
-- =============================================================

local TeleTab   = MachoMenuAddTab(LS.Window, "Teleport")
local TeleMain  = MachoMenuGroup(TeleTab, "Teleport", 150, 9, 500, 500)
local TeleExtra = MachoMenuGroup(TeleTab, "Coordinates & Waypoint", 500, 9, 800, 500)

MachoMenuButton(TeleMain, "Teleport To Waypoint", function()
    LS.Run([[
        local blip = GetFirstBlipInfoId(8)
        if not DoesBlipExist(blip) then return end
        local coords = GetBlipInfoIdCoord(blip)
        LONESTAR.TeleportTo(coords.x, coords.y, coords.z, true)
    ]])
    LS.Ok("Teleported to waypoint")
end)

MachoMenuCheckbox(TeleMain, "Auto Teleport To Waypoint", function()
    LS.StartLoop("Lonestar.AutoWaypoint", [[
        local blip = GetFirstBlipInfoId(8)
        if DoesBlipExist(blip) then
            local coords = GetBlipInfoIdCoord(blip)
            LONESTAR.TeleportTo(coords.x, coords.y, coords.z, true)
            Wait(4000)
        else
            Wait(500)
        end
    ]])
    LS.Ok("Auto waypoint teleport enabled")
end, function()
    LS.StopLoop("Lonestar.AutoWaypoint")
    LS.Info("Auto waypoint teleport disabled")
end)

local locationIndex = 0
MachoMenuDropDown(TeleMain, "Location", function(index)
    locationIndex = index
end, "None", "Legion Square", "Sandy Shores", "Paleto Bay", "Los Santos Intl", "Stab City",
    "Vinewood", "Maze Bank", "Kortz Center", "Pillbox Hill", "Mount Chiliad", "Humane Labs",
    "Mirror Park", "Docks", "Grove Street", "Zancudo Pier", "Cayo Perico")

MachoMenuButton(TeleMain, "Teleport To Location", function()
    -- Dropdown index 1 is "None", so location N lives at LS.Locations[N - 1].
    local loc = LS.Locations[locationIndex - 1]
    if not loc then LS.Info("Pick a location first") return end
    LS.Run(([[ LONESTAR.TeleportTo(%f, %f, %f, true) ]]):format(loc[2], loc[3], loc[4]))
    LS.Ok(("Teleported to %s"):format(loc[1]))
end)

MachoMenuText(TeleMain, "Player Movement")

MachoMenuButton(TeleMain, "Teleport To Target Player", function()
    LS.WithTarget(function(serverId)
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if not ped then return end
            local coords = GetEntityCoords(ped)
            LONESTAR.TeleportTo(coords.x, coords.y, coords.z, true)
        ]]):format(serverId))
        LS.Ok("Teleported to target")
    end)
end)

MachoMenuButton(TeleMain, "Teleport To Target Vehicle", function()
    LS.WithTarget(function(serverId)
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if not ped then return end
            local veh = GetVehiclePedIsIn(ped, false)
            local coords = veh ~= 0 and GetEntityCoords(veh) or GetEntityCoords(ped)
            LONESTAR.TeleportTo(coords.x, coords.y, coords.z, true)
        ]]):format(serverId))
        LS.Ok("Teleported to target vehicle")
    end)
end)

MachoMenuButton(TeleMain, "Bring Target To Me", function()
    LS.WithTarget(function(serverId)
        LS.Run(([[
            local ped = LONESTAR.SelfPed()
            if not ped then return end
            local coords = GetEntityCoords(ped)
            TriggerEvent('esx:teleport', coords.x, coords.y, coords.z, 4.0, 0.0, false, true, false, false, %d)
            TriggerEvent('QBCore:Command:GoToMarker', %d)
            TriggerEvent('txcl:teleport', %d, vector3(coords.x, coords.y, coords.z))
            TriggerEvent('TeleportTarget', %d, coords.x, coords.y, coords.z)
        ]]):format(serverId, serverId, serverId))
        LS.Ok("Target brought to you")
    end)
end)

MachoMenuText(TeleExtra, "Manual Coordinates")

local coordBox = MachoMenuInputbox(TeleExtra, "Coordinates", "Ex. 143,0,0")

MachoMenuButton(TeleExtra, "Set Waypoint", function()
    local raw = LS.Trim(MachoMenuGetInputbox(coordBox))
    if not raw then LS.Err("Enter coordinates as x,y,z") return end
    local x, y, z = raw:match("^%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)%s*$")
    if not x then LS.Err("Bad format - use x,y,z") return end
    LS.Raw(([[ SetNewWaypoint(%s, %s) ]]):format(x, y))
    LS.Ok("Waypoint set")
end)

MachoMenuButton(TeleExtra, "Teleport To Coordinates", function()
    local raw = LS.Trim(MachoMenuGetInputbox(coordBox))
    if not raw then LS.Err("Enter coordinates as x,y,z") return end
    local x, y, z = raw:match("^%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)%s*$")
    if not x then LS.Err("Bad format - use x,y,z") return end
    LS.Run(([[ LONESTAR.TeleportTo(%s, %s, %s, true) ]]):format(x, y, z))
    LS.Ok("Teleported")
end)

MachoMenuButton(TeleExtra, "Print My Coordinates", function()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    print(("^3[Lonestar]^7 x = %.2f, y = %.2f, z = %.2f, h = %.2f"):format(c.x, c.y, c.z, h))
    LS.Ok(("%.2f, %.2f, %.2f"):format(c.x, c.y, c.z))
end)

MachoMenuText(TeleExtra, "Server Locations (select then act)")

local serverLocIndex = 0
local ServerLocations = {
    { "LSPD HQ",         452.15,  -1017.62, 29.10 },
    { "Pillbox Medical", 307.13,  -594.16,  43.28 },
    { "MCPD",            1142.50, -2073.24, 31.55 },
    { "Sandy Shores PD", 1839.20, 3672.90,  32.00 },
    { "Paleto Sheriff",  -448.70, 6021.50,  31.20 },
    { "FIB Office",     -561.20,  -271.40,  43.40 },
    { "Prison",          1651.90, -4920.10, 29.30 },
    { "LS Car Meet",    1035.00,  -2691.20, 39.50 },
}

MachoMenuDropDown(TeleExtra, "Server Location", function(index)
    serverLocIndex = index
end, "None", "LSPD HQ", "Pillbox Medical", "MCPD", "Sandy Shores PD", "Paleto Sheriff",
    "FIB Office", "Prison", "LS Car Meet")

MachoMenuButton(TeleExtra, "Teleport To Server Location", function()
    -- Index 1 is the "None" placeholder, so entry N lives at [N - 1].
    local loc = ServerLocations[serverLocIndex - 1]
    if not loc then LS.Info("Pick a location first") return end
    LS.Run(([[ LONESTAR.TeleportTo(%f, %f, %f, true) ]]):format(loc[2], loc[3], loc[4]))
    LS.Ok(("Teleported to %s"):format(loc[1]))
end)

-- =============================================================
-- 15. TAB: TROLL PLAYERS
-- =============================================================

local TrollTab   = MachoMenuAddTab(LS.Window, "Troll")
local TrollMain  = MachoMenuGroup(TrollTab, "Player Trolls", 150, 9, 500, 500)
local TrollProps = MachoMenuGroup(TrollTab, "Props & Emotes", 500, 9, 800, 500)

MachoMenuText(TrollMain, "Offensive")

MachoMenuButton(TrollMain, "Explode Player", function()
    LS.WithTarget(function(sid)
        -- Allstar's 3-method chain: hook, then explosion, then direct.
        LS.Run(([[
            local sid = %d
            local ped = LONESTAR.PedFromServerId(sid)
            if ped then
                local coords = GetEntityCoords(ped)
                AddExplosion(coords.x, coords.y, coords.z + 1.0, 12, 0.0, false, false, 0.0, false, false)
            end
        ]]):format(sid))
        LS.Ok("Target exploded")
    end)
end)

MachoMenuButton(TrollMain, "Kill Player", function()
    LS.WithTarget(function(sid)
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if ped then
                local coords = GetEntityCoords(ped)
                if not IsEntityDead(ped) then
                    local weapon = GetHashKey('WEAPON_PISTOL')
                    LONESTAR.SafeRunNative(ShootSingleBulletBetweenCoords,
                        coords.x, coords.y, coords.z + 0.5,
                        coords.x, coords.y - 0.5, coords.z + 1.0, true, true,
                        weapon, ped, 1)
                end
            end
        ]]):format(sid))
        LS.Ok("Target killed")
    end)
end)

MachoMenuButton(TrollMain, "Silent Kill Player", function()
    LS.WithTarget(function(sid)
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if ped then
                LONESTAR.SafeRunNative(SetEntityHealth, ped, 0)
            end
        ]]):format(sid))
        LS.Ok("Target silently killed")
    end)
end)

MachoMenuButton(TrollMain, "Ragdoll Player", function()
    LS.WithTarget(function(sid)
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if ped then
                LONESTAR.SafeRunNative(SetPedToRagdoll, ped, 10000.0, 10000.0, 0, false, false, false)
            end
        ]]):format(sid))
        LS.Ok("Target ragdolled")
    end)
end)

MachoMenuButton(TrollMain, "Crash Player", function()
    LS.WithTarget(function(sid)
        -- Amiwa's approach: overwhelm the target with peds.
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if not ped then return end
            local coords = GetEntityCoords(ped)
            for i = 1, 24 do
                local model = GetHashKey('player_zero')
                local angle = (i / 24) * 6.283
                local ox = coords.x + math.cos(angle) * 2.0
                local oy = coords.y + math.sin(angle) * 2.0
                CreatePed(4, model, ox, oy, coords.z, 0.0, 0.0, 0.0, false, false)
            end
        ]]):format(sid))
        LS.Ok("Target crashed")
    end)
end)

MachoMenuText(TrollMain, "Movement")

MachoMenuButton(TrollMain, "Send Player To Sky", function()
    LS.WithTarget(function(sid)
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if not ped then return end
            local coords = GetEntityCoords(ped)
            LONESTAR.SafeRunNative(SetEntityCoords, ped, coords.x, coords.y, coords.z + 400.0, false, false, false, false)
            LONESTAR.SafeRunNative(ApplyForceToEntity, ped, 500.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, false)
        ]]):format(sid))
        LS.Ok("Target launched")
    end)
end)

MachoMenuButton(TrollMain, "Launch Player (Semi Safe)", function()
    LS.WithTarget(function(sid)
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if not ped then return end
            LONESTAR.SafeRunNative(SetPedToRagdoll, ped, 10000.0, 10000.0, 0, false, false, false)
            LONESTAR.SafeRunNative(AddForceToEntity, ped, 0.0, 0.0, 1500.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, true, true, true, true)
        ]]):format(sid))
        LS.Ok("Target launched")
    end)
end)

MachoMenuButton(TrollMain, "Glitch Player", function()
    LS.WithTarget(function(sid)
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if not ped then return end
            for i = 1, 40 do
                local coords = GetEntityCoords(ped)
                SetEntityCoords(ped, coords.x + math.random(-3, 3), coords.y + math.random(-3, 3),
                    coords.z + math.random(-3, 3), false, false, false, false)
                ClearPedTasksImmediately(ped)
                Wait(10)
            end
        ]]):format(sid))
        LS.Ok("Target glitched")
    end)
end)

MachoMenuButton(TrollMain, "Sky And Stay", function()
    LS.WithTarget(function(sid)
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if not ped then return end
            local coords = GetEntityCoords(ped)
            SetEntityCoords(ped, coords.x, coords.y, coords.z + 300.0, false, false, false, false)
            SetPedGravityEnabled(ped, false)
            SetEntityVelocity(ped, 0.0, 0.0, 0.0)
        ]]):format(sid))
        LS.Ok("Target parked in the sky")
    end)
end)

MachoMenuText(TrollMain, "Containment")

MachoMenuButton(TrollMain, "Cage Player", function()
    LS.WithTarget(function(sid)
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if not ped then return end
            local coords = GetEntityCoords(ped)
            for _, model in ipairs({ 'prop_container_ld_pu', 'prop_cargo_crate_02a' }) do
                local hash = GetHashKey(model)
                CreateObject(hash, coords.x, coords.y + 1.5, coords.z - 0.5, 0.0, 0.0, 0.0, false, false, false)
                CreateObject(hash, coords.x, coords.y - 1.5, coords.z - 0.5, 0.0, 0.0, 0.0, false, false, false)
            end
            SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
        ]]):format(sid))
        LS.Ok("Target caged")
    end)
end)

MachoMenuButton(TrollMain, "Invisible Cage Player", function()
    LS.WithTarget(function(sid)
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if not ped then return end
            local coords = GetEntityCoords(ped)
            for i = 1, 4 do
                local obj = CreateObject(GetHashKey('prop_container_ld_pu'),
                    coords.x + (i - 2.5), coords.y, coords.z, 0.0, 0.0, 0.0, false, false, false)
                SetEntityVisible(obj, false, false)
            end
        ]]):format(sid))
        LS.Ok("Target caged (invisible)")
    end)
end)

MachoMenuButton(TrollMain, "Freeze Player", function()
    LS.WithTarget(function(sid)
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if ped then LONESTAR.SafeRunNative(FreezeEntityPosition, ped, true) end
        ]]):format(sid))
        LS.Ok("Target frozen")
    end)
end)

MachoMenuButton(TrollMain, "Admin Freeze Player", function()
    LS.WithTarget(function(sid)
        LS.Run(([[
            TriggerEvent('esx:freezePlayer', %d, true)
            TriggerEvent('QBCore:Command:Freeze', %d, true)
            TriggerEvent('police:client:freezePlayer', %d, true)
        ]]):format(sid))
        LS.Ok("Admin freeze sent")
    end)
end)

MachoMenuText(TrollMain, "Target Utility")

MachoMenuButton(TrollMain, "Get Player Information", function()
    LS.WithTarget(function(sid)
        local clientId = GetPlayerFromServerId(sid)
        if clientId == -1 then LS.Err("Player is not connected") return end
        local name = GetPlayerName(clientId) or "Unknown"
        local ped = GetPlayerPed(clientId)
        local info = ("Name: %s | ID: %d"):format(name, sid)
        if DoesEntityExist(ped) then
            local c = GetEntityCoords(ped)
            info = info .. ("\nHP: %d | Armour: %d"):format(
                math.floor(GetEntityHealth(ped)), math.floor(GetPedArmour(ped) or 0))
            info = info .. ("\nPos: %.2f, %.2f, %.2f"):format(c.x, c.y, c.z)
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                info = info .. ("\nVehicle: %s"):format(
                    GetDisplayNameFromVehicleModel(GetEntityModel(veh)) or "?")
            end
        end
        print(info)
        LS.Ok("Information printed to F8")
    end)
end)

MachoMenuButton(TrollMain, "Spectate Player", function()
    LS.WithTarget(function(sid)
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if not ped then return end
            NetworkSetInSpectatorMode(true, false)
            NetworkSetInSpectatorPlayerNetworkId(GetPlayerFromServerId(%d))
        ]]):format(sid, sid))
        LS.Ok("Spectating target")
    end)
end)

MachoMenuButton(TrollMain, "Stop Spectating", function()
    LS.Raw([[ NetworkSetInSpectatorMode(false, false) ]])
    LS.Info("Spectating stopped")
end)

MachoMenuButton(TrollMain, "Steal Outfit", function()
    LS.WithTarget(function(sid)
        LS.Run(([[
            local src = LONESTAR.PedFromServerId(%d)
            local me = LONESTAR.SelfPed()
            if not src or not me then return end
            SetPlayerModel(PlayerId(), GetEntityModel(src))
            for i = 0, 11 do
                SetPedComponentVariation(me, i,
                    GetPedDrawableVariation(src, i), GetPedTextureVariation(src, i), 0)
            end
            for i = 0, 8 do
                SetPedPropIndex(me, i, GetPedPropIndex(src, i), 0, true)
            end
        ]]):format(sid))
        LS.Ok("Outfit copied")
    end)
end)

MachoMenuButton(TrollMain, "Make Player Invisible", function()
    LS.WithTarget(function(sid)
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if ped then LONESTAR.SafeRunNative(SetEntityVisible, ped, false, false) end
        ]]):format(sid))
        LS.Ok("Target hidden")
    end)
end)

MachoMenuText(TrollMain, "Emote Troll")

local EmoteTarget = nil
MachoMenuDropDown(TrollMain, "Force Emote", function(index)
    EmoteTarget = index
end, "None", "Hands Up", "Punch", "Headbutt", "Slap", "Hug", "Lap Dance",
    "Horse Dance", "Silly Dance", "Glow Stick", "Baseball Throw", "Twerk", "Pimp Sex")

MachoMenuButton(TrollMain, "Apply Emote To Target", function()
    if not EmoteTarget or EmoteTarget < 2 then LS.Info("Pick an emote first") return end
    LS.WithTarget(function(sid)
        local emote = LS.Emotes[EmoteTarget][1]
        LS.Run(([[
            TriggerEvent('ServerValidEmote', %d, '%s', '%s')
            TriggerEvent('ClientEmoteRequestReceive', GetPlayerFromServerId(%d), '%s')
        ]]):format(sid, emote, emote, sid, emote))
        LS.Ok("Emote forced on target")
    end)
end)
