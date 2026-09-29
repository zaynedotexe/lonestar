
-- =============================================================
-- 21. TAB: NUKE
--    Destructive actions from Allstar's and Menudo's nuke groups.
--    Every entry asks for a typed confirmation.
-- =============================================================

local NukeTab   = MachoMenuAddTab(LS.Window, "Nuke")
local NukeMain  = MachoMenuGroup(NukeTab, "Nuke", 150, 9, 500, 500)
local NukeMore  = MachoMenuGroup(NukeTab, "Chaos", 500, 9, 800, 500)

MachoMenuText(NukeMain, "Confirm Code: LONESTAR")

local nukeConfirmBox = MachoMenuInputbox(NukeMain, "Type LONESTAR", "Confirmation")

---@param label string
---@param action fun()
---@param warning string|nil
local function Confirm(label, action, warning)
    local typed = LS.Trim(MachoMenuGetInputbox(nukeConfirmBox))
    if typed ~= "LONESTAR" then
        LS.Err("Type LONESTAR in the box to confirm")
        return
    end
    if warning then
        print(("^1[Lonestar]^7 %s: %s"):format(label, warning))
    end
    action()
    LS.Ok(label .. " executed")
end

MachoMenuButton(NukeMain, "Explode All Vehicles", function()
    Confirm("Explode All Vehicles", function()
        LS.Run([[
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if DoesEntityExist(veh) then
                    local c = GetEntityCoords(veh)
                    AddExplosion(c.x, c.y, c.z, 12, 0.0, true, false, 0.0, false, false)
                end
            end
        ]])
    end, "This will destroy every vehicle on the map.")
end)

MachoMenuButton(NukeMain, "Delete All Vehicles", function()
    Confirm("Delete All Vehicles", function()
        LS.Run([[
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if DoesEntityExist(veh) then
                    NetworkRequestControlOfEntity(veh)
                    DeleteEntity(veh)
                end
            end
        ]])
    end, "Every networked vehicle will be removed.")
end)

MachoMenuButton(NukeMain, "Explode All Props", function()
    Confirm("Explode All Props", function()
        LS.Run([[
            for _, obj in ipairs(GetGamePool('CObject')) do
                if DoesEntityExist(obj) then
                    local c = GetEntityCoords(obj)
                    AddExplosion(c.x, c.y, c.z, 0, 0.0, true, false, 0.0, false, false)
                end
            end
        ]])
    end, "Detonates every world object.")
end)

MachoMenuButton(NukeMain, "Delete All Peds", function()
    Confirm("Delete All Peds", function()
        LS.Run([[
            for _, ped in ipairs(GetGamePool('CPed')) do
                if ped ~= PlayerPedId() and DoesEntityExist(ped) then
                    DeleteEntity(ped)
                end
            end
        ]])
    end, "Removes every ped including other players.")
end)

MachoMenuButton(NukeMain, "Remove All Blips", function()
    Confirm("Remove All Blips", function()
        LS.Run([[
            local blip = GetFirstBlipInfoId(1)
            while DoesBlipExist(blip) do
                SetBlipAlpha(blip, 0)
                SetBlipAsShortRange(blip, true)
                RemoveBlip(blip)
                blip = GetFirstBlipInfoId(1)
            end
        ]])
    end, "Removes map markers and mission blips.")
end)

MachoMenuText(NukeMain, "Targeted Nuke")

MachoMenuButton(NukeMain, "Nuke Target Player", function()
    Confirm("Nuke Target Player", function()
        LS.WithTarget(function(sid)
            LS.Run(([[
                local ped = LONESTAR.PedFromServerId(%d)
                if not ped then return end
                local c = GetEntityCoords(ped)
                for i = 1, 12 do
                    AddExplosion(c.x + math.random(-6, 6), c.y + math.random(-6, 6),
                        c.z + math.random(-2, 2), 12, 0.0, true, false, 0.0, false, false)
                    Wait(120)
                end
            ]]):format(sid))
        end)
    end, "Twelve explosions around the selected player.")
end)

MachoMenuText(NukeMore, "World Chaos")

MachoMenuButton(NukeMore, "Tornado", function()
    Confirm("Tornado", function()
        LS.StartLoop("Lonestar.Tornado", [[
            local ped = LONESTAR.SelfPed()
            if not ped then return end
            local target = GetEntityCoords(ped)
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if DoesEntityExist(veh) then
                    local c = GetEntityCoords(veh)
                    local delta = c - target
                    local dist = #delta
                    if dist < 300.0 and dist > 3.0 then
                        NetworkRequestControlOfEntity(veh)
                        SetEntityVelocity(veh,
                            (delta / dist).x * 60.0,
                            (delta / dist).y * 60.0,
                            20.0 + (delta / dist).z * 10.0)
                    end
                end
            end
        ]])
    end, "Vehicles within 300m will be thrown into the air.")
end)

MachoMenuButton(NukeMore, "Stop All Chaos Loops", function()
    LS.Run([[
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(veh) then
                NetworkRequestControlOfEntity(veh)
                SetEntityVelocity(veh, 0.0, 0.0, 0.0)
                SetEntityAngularVelocity(veh, 0.0, 0.0, 0.0)
            end
        end
    ]])
    LS.StopLoop("Lonestar.Tornado")
    LS.StopLoop("Lonestar.BlackHole")
    LS.StopLoop("Lonestar.Stalker")
    LS.Ok("Chaos loops stopped")
end)

MachoMenuButton(NukeMore, "Detonate All Blips (Explosive Blips)", function()
    Confirm("Explosive Blips", function()
        LS.Run([[
            local blip = GetFirstBlipInfoId(1)
            local count = 0
            while DoesBlipExist(blip) do
                local c = GetBlipInfoIdCoord(blip)
                AddExplosion(c.x, c.y, c.z, 12, 0.0, true, false, 0.0, false, false)
                count = count + 1
                blip = GetFirstBlipInfoId(1)
            end
            print(('[Lonestar] Detonated %d blips'):format(count))
        ]])
    end, "Creates an explosion at every blip on the map.")
end)

MachoMenuButton(NukeMore, "Suicide (Detonate Self)", function()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end
    local c = GetEntityCoords(ped)
    LS.Raw(([[ AddExplosion(%f, %f, %f, 12, 0.0, true, false, 0.0, false, false) ]]):format(c.x, c.y, c.z))
    LS.Ok("Boom")
end)

-- =============================================================
-- 22. TAB: SETTINGS
-- =============================================================

local SetTab   = MachoMenuAddTab(LS.Window, "Settings")
local SetMain  = MachoMenuGroup(SetTab, "Appearance", 150, 9, 500, 500)
local SetMore  = MachoMenuGroup(SetTab, "Keybinds & Info", 500, 9, 800, 500)

MachoMenuText(SetMain, "Accent Colour")

---@return integer, integer, integer
local function Accent()
    return CONFIG.accent[1], CONFIG.accent[2], CONFIG.accent[3]
end

---@param r integer
---@param g integer
---@param b integer
local function SetAccent(r, g, b)
    CONFIG.accent = { r, g, b }
    pcall(MachoMenuSetAccent, LS.Window, r, g, b)
end

MachoMenuButton(SetMain, "Red", function()
    SetAccent(255, 0, 0)
    LS.Ok("Accent: red")
end)

MachoMenuButton(SetMain, "Blue", function()
    SetAccent(0, 90, 255)
    LS.Ok("Accent: blue")
end)

MachoMenuButton(SetMain, "Green", function()
    SetAccent(0, 255, 120)
    LS.Ok("Accent: green")
end)

MachoMenuButton(SetMain, "Purple", function()
    SetAccent(160, 80, 255)
    LS.Ok("Accent: purple")
end)

MachoMenuButton(SetMain, "Gold", function()
    SetAccent(255, 190, 60)
    LS.Ok("Accent: gold")
end)

MachoMenuCheckbox(SetMain, "Rainbow Accent", function()
    CreateThread(function()
        while true do
            local hue = (GetGameTimer() / 8) % 360.0
            local r = math.floor((math.sin(math.rad(hue)) * 127) + 128)
            local g = math.floor((math.sin(math.rad(hue + 120)) * 127) + 128)
            local b = math.floor((math.sin(math.rad(hue + 240)) * 127) + 128)
            pcall(MachoMenuSetAccent, LS.Window, r, g, b)
            Wait(50)
        end
    end)
    LS.Ok("Rainbow accent enabled")
end)

MachoMenuText(SetMain, "Custom Accent")

local accentBox = MachoMenuInputbox(SetMain, "Accent RGB", "Ex. 255,0,0")

MachoMenuButton(SetMain, "Apply Custom Accent", function()
    local raw = LS.Trim(MachoMenuGetInputbox(accentBox))
    if not raw then LS.Err("Enter r,g,b") return end
    local r, g, b = raw:match("^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
    if not r then LS.Err("Bad format - use r,g,b") return end
    SetAccent(math.min(tonumber(r), 255), math.min(tonumber(g), 255), math.min(tonumber(b), 255))
    LS.Ok("Accent updated")
end)

MachoMenuText(SetMain, "Startup Notification")

MachoMenuCheckbox(SetMain, "Notify On Start", function()
    CONFIG.notifyOnStart = true
    LS.Info("Will notify on next start")
end, function()
    CONFIG.notifyOnStart = false
    LS.Info("Startup notification disabled")
end)

MachoMenuText(SetMore, "Keybinds")

local boundKey   = CONFIG.defaultKey
local noclipBound = 0
local freecamBound = 0

MachoMenuKeybind(SetMore, "Menu Key", 0, function(key, toggle)
    boundKey = key
    pcall(MachoMenuSetKeybind, LS.Window, key)
    LS.Ok("Menu keybind updated")
end)

MachoMenuKeybind(SetMore, "Noclip Key", 0, function(key, toggle)
    noclipBound = key
    LS.Ok("Noclip key assigned")
end)

MachoMenuKeybind(SetMore, "Freecam Key", 0, function(key, toggle)
    freecamBound = key
    LS.Ok("Freecam key assigned")
end)

MachoMenuText(SetMore, "Manual Keybind")

local manualKeyBox = MachoMenuInputbox(SetMore, "Key Name", "Ex. F7")

---@param key string
local function ApplyKeybind(key)
    local map = {
        INSERT = 0x2E, DELETE = 0x2D, HOME = 0x24, END = 0x23, PAGEUP = 0x21, PAGEDOWN = 0x22,
        ["`"] = 0x29, ["-"] = 0x0D, ["="] = 0x0C, F5 = 0x74, F6 = 0x75, F7 = 0x76, F8 = 0x77,
    }
    local code = map[key:upper()]
    if not code then
        LS.Err(("Unknown key '%s' - try INSERT, F5-F8, HOME, END, PAGEUP"):format(key))
        return
    end
    boundKey = code
    pcall(MachoMenuSetKeybind, LS.Window, code)
    LS.Ok(("Menu key set to %s"):format(key))
end

MachoMenuButton(SetMore, "Set Keybind (Manual)", function()
    ApplyKeybind(LS.Trim(MachoMenuGetInputbox(manualKeyBox)) or "INSERT")
end)

MachoMenuButton(SetMore, "Reset Key To Insert", function()
    ApplyKeybind("INSERT")
end)

MachoMenuText(SetMore, "Diagnostics")

MachoMenuButton(SetMore, "Show Framework", function()
    LS.Info("Framework: " .. tostring(LS.Framework() or "none detected"))
end)

MachoMenuButton(SetMore, "Show Anticheats", function()
    local text = LS.ACSummary()
    print("^3[Lonestar]^7 " .. text)
    LS.Ok("Anticheat list printed to console")
end)

MachoMenuButton(SetMore, "Show Injection Target", function()
    LS.Info("Target: " .. tostring(LS.SafeTarget()))
end)

MachoMenuButton(SetMore, "Recalculate Anticheats", function()
    LS.ScanAnticheats()
    LS.Ok("Anticheat scan refreshed")
end)

MachoMenuText(SetMore, "About")

MachoMenuText(SetMore, "Lonestar " .. LS.Version)
MachoMenuText(SetMore, "Menu style: MachoMenuTabbedWindow")
MachoMenuText(SetMore, "Merged: Menudo V2.2 / Allstar / Amiwa V2")

MachoMenuButton(SetMore, "Destroy Menu", function()
    pcall(MachoMenuDestroy, LS.Window)
    LS.Notify(LS.Brand, "Menu closed - restart your resource to reopen")
end)

-- =============================================================
-- 23. BOOT
-- =============================================================

pcall(MachoMenuSetAccent, LS.Window, Accent())

LS.ScanAnticheats()

-- Manual keybinds: the menu key is handled by MachoMenuSetKeybind above,
-- everything else is polled here, exactly as Menudo does.
MachoOnKeyDown(function(key)
    if key == 0 then return end

    if key == noclipBound and noclipBound ~= 0 then
        local state = LS.NoclipEnabled ~= true
        LS.ToggleNoclip(state)
        if state then LS.Ok("Noclip enabled") else LS.Info("Noclip disabled") end
        return
    end

    if key == freecamBound and freecamBound ~= 0 then
        local state = LS.FreecamActive ~= true
        LS.ToggleFreecam(state)
        if state then LS.Ok("Freecam enabled") else LS.Info("Freecam disabled") end
    end
end)

CreateThread(function()
    if CONFIG.notifyOnStart ~= false then
        Wait(1200)
        LS.Notify(LS.Brand, ("v%s loaded | framework: %s | AC: %d")
            :format(LS.Version, tostring(LS.Framework() or "none"), #LS.Anticheats))
        LS.Info("Press INSERT to open the menu")
    end
end)

  print(("^1[Lonestar]^7 v%s online - %s source active, target %s")
      :format(LS.Version, tostring(LS.Framework() or "no framework"), tostring(LS.SafeTarget())))

-- =============================================================
-- DUI BOOT
-- ------------------------------------------------------------
-- Deferred one frame so every tab has registered its widgets before
-- the tree is serialised and shipped to the browser page.
-- =============================================================
CreateThread(function()
    Wait(0)
    local ui = LS.UI
    if not ui or not ui.Start then return end
    if ui:Start() then
        print(("^1[Lonestar]^7 DUI ready - %s"):format(tostring(ui.duiUrl)))
    end
end)
