
-- =============================================================
-- 8. TAB: PLAYER LIST
--    Menudo's dynamic-slot pattern: 32 fixed checkboxes whose
--    labels are rewritten on a refresh timer. Allstar's richer
--    per-player metadata is used for the label text.
-- =============================================================

local PlayerTab   = MachoMenuAddTab(LS.Window, "Player List")
local PlayerGroup = MachoMenuGroup(PlayerTab, "Players", 150, 9, 800, 500)

local searchBox = MachoMenuInputbox(PlayerGroup, "Search Player", "Enter name...")

MachoMenuButton(PlayerGroup, "Refresh Players", function()
    LS.RefreshPlayers()
    LS.Ok("Player list refreshed")
end)

MachoMenuButton(PlayerGroup, "Clear Selection", function()
    LS.Selected = nil
    LS.RefreshPlayers()
    LS.Info("Selection cleared")
end)

MachoMenuText(PlayerGroup, "Selected:")
local SelectedText = MachoMenuText(PlayerGroup, "None")

MachoMenuText(PlayerGroup, "Player ID:")
LS.ManualIdBox = MachoMenuInputbox(PlayerGroup, "Manual Player ID", "Ex. 12")

MachoMenuText(PlayerGroup, "Roster:")

local slots = {}
local slotPlayers = {}
LS.Selected = nil

for i = 1, CONFIG.maxListRows do
    local handle = MachoMenuCheckbox(PlayerGroup, "Empty", function()   -- enable
        local player = slotPlayers[i]
        if player then
            LS.Selected = player
            local name = GetPlayerName(player)
            LS.Info(("Target: %s (%d)"):format(name or "unknown", GetPlayerServerId(player)))
        end
    end, function()                                                    -- disable
        local player = slotPlayers[i]
        if player and LS.Selected == player then
            LS.Selected = nil
            LS.Info("Target cleared")
        end
    end)
    slots[i] = handle
end

---Best-effort description of a player, matching Allstar's metadata.
---@param serverId integer
---@param clientId integer
---@return string
local function DescribePlayer(serverId, clientId)
    local ped = GetPlayerPed(clientId)
    if not DoesEntityExist(ped) then
        return ("%d - %s"):format(serverId, GetPlayerName(clientId) or "Unknown")
    end

    local info = ("%d - %s"):format(serverId, GetPlayerName(clientId) or "Unknown")
    local health = math.floor(GetEntityHealth(ped))
    local armour = math.floor(GetPedArmour(ped) or 0)
    info = info .. (" [HP %d]"):format(health)
    if armour > 0 then info = info .. (" [AR %d]"):format(armour) end

    local coords = GetEntityCoords(ped)
    info = info .. (" (%.0f, %.0f)"):format(coords.x, coords.y)

    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        local model = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
        info = info .. (" [%s]"):format(model or "Vehicle")
    end

    if IsEntityPlayingAnim(ped) then
        info = info .. " [Anim]"
    end

    return info
end

---Rebuild every roster slot from the live player list.
function LS.RefreshPlayers()
    local filter = (MachoMenuGetInputbox(searchBox) or ""):lower()
    local row = 0

    for _, clientId in ipairs(GetActivePlayers()) do
        if row >= CONFIG.maxListRows then break end
        local serverId = GetPlayerServerId(clientId)
        if serverId ~= GetPlayerServerId(PlayerId()) then
            local name = (GetPlayerName(clientId) or ""):lower()
            if filter == "" or name:find(filter, 1, true) then
                row = row + 1
                slotPlayers[row] = clientId
                MachoMenuSetText(slots[row], DescribePlayer(serverId, clientId))
            end
        end
    end

    for i = row + 1, CONFIG.maxListRows do
        slotPlayers[i] = nil
        MachoMenuSetText(slots[i], "Empty")
    end

    if LS.Selected and DoesEntityExist(GetPlayerPed(LS.Selected)) then
        local name = GetPlayerName(LS.Selected) or "Unknown"
        local serverId = GetPlayerServerId(LS.Selected)
        local dist = #(GetEntityCoords(GetPlayerPed(LS.Selected)) - GetEntityCoords(PlayerPedId()))
        MachoMenuSetText(SelectedText, ("%s | id %d | %.0fm"):format(name, serverId, dist))
    else
        LS.Selected = nil
        MachoMenuSetText(SelectedText, "None")
    end
end

-- Keep the roster and target readout live while the tab is open.
CreateThread(function()
    while true do
        Wait(1000)
        pcall(LS.RefreshPlayers)
    end
end)

-- =============================================================
-- 9. TAB: SELF
-- =============================================================

local SelfTab   = MachoMenuAddTab(LS.Window, "Self")
local SelfMain  = MachoMenuGroup(SelfTab, "Main", 150, 9, 500, 500)
local SelfExtra = MachoMenuGroup(SelfTab, "Protection & Toggles", 500, 9, 800, 500)

-- ---------- 9.1 Vitals ----------

MachoMenuText(SelfMain, "Vitals")

local healthValue = 200
local armorValue  = 100

MachoMenuSlider(SelfMain, "Health", 200, 0, 200, " HP", 1, function(value)
    healthValue = math.floor(value)
end)

MachoMenuButton(SelfMain, "Set Health", function()
    LS.Raw(([[
        local ped = PlayerPedId()
        if DoesEntityExist(ped) and not IsEntityDead(ped) then
            SetEntityHealth(ped, %d)
        end
    ]]):format(healthValue))
    LS.Ok(("Health set to %d"):format(healthValue))
end)

MachoMenuSlider(SelfMain, "Armour", 100, 0, 100, " AR", 1, function(value)
    armorValue = math.floor(value)
end)

MachoMenuButton(SelfMain, "Set Armour", function()
    LS.Raw(([[
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            SetPedArmour(ped, %d)
        end
    ]]):format(armorValue))
    LS.Ok(("Armour set to %d"):format(armorValue))
end)

MachoMenuButton(SelfMain, "Heal & Armour (Full)", function()
    -- Allstar version: guarded against dead / missing peds.
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if ped and not IsEntityDead(ped) then
            LONESTAR.SafeRunNative(SetEntityHealth, ped, GetEntityMaxHealth(ped))
            LONESTAR.SafeRunNative(SetPedArmour, ped, 100)
        end
    ]])
    LS.Ok("Health and armour restored")
end)

MachoMenuButton(SelfMain, "Clean Player", function()
    -- Amiwa's clean-ped pass: blood, dirt, damage and cause-of-death.
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        LONESTAR.SafeRunNative(ClearPedBloodDamage, ped)
        LONESTAR.SafeRunNative(ClearPedWetness, ped)
        LONESTAR.SafeRunNative(ClearPedEnvDirt, ped)
        LONESTAR.SafeRunNative(ClearPedDamageImmediately, ped)
        LONESTAR.SafeRunNative(ResetPedVisibleDamage, ped)
        LONESTAR.SafeRunNative(ClearPedTasksImmediately, ped)
        LONESTAR.SafeRunNative(ResetPedVisibleDamage, ped)
    ]])
    LS.Ok("Player cleaned")
end)

MachoMenuButton(SelfMain, "Suicide", function()
    LS.Raw([[
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            SetEntityHealth(ped, 0)
        end
    ]])
    LS.Info("Goodbye")
end)

MachoMenuText(SelfMain, "Needs & Status")

MachoMenuButton(SelfMain, "Reset Hunger / Thirst", function()
    -- Allstar's chain, trimmed to the resources that actually exist.
    if LS.Running("rryban_secure") then
        executeCode("esx_basicneeds", [[
            LONESTAR.SafeRunNative(TriggerEvent, 'esx_status:set', 'hunger', 1000000)
            LONESTAR.SafeRunNative(TriggerEvent, 'esx_status:set', 'thirst', 1000000)
        ]])
    elseif LS.Running("ars_ambulancejob") then
        executeCode("ars_ambulancejob", [[ LONESTAR.SafeRunNative(TriggerEvent, 'ars_ambulancejob:healStatus') ]])
    elseif LS.Running("esx_status") then
        executeCode("esx_status", [[
            LONESTAR.SafeRunNative(TriggerEvent, 'esx_status:set', 'hunger', 1000000)
            LONESTAR.SafeRunNative(TriggerEvent, 'esx_status:set', 'thirst', 1000000)
            LONESTAR.SafeRunNative(TriggerEvent, 'esx_status:set', 'stress', 0)
            LocalPlayer.state:set('stress', -50)
        ]])
    elseif LS.Running("cfx-hu-core") then
        executeCode("cfx-hu-core", [[ LONESTAR.SafeRunNative(TriggerEvent, "esx_basicneeds:healPlayer") ]])
    elseif LS.Running("es_extended") then
        executeCode("es_extended", [[
            LONESTAR.SafeRunNative(TriggerEvent, 'es_extended:status:Add', 'hunger', 1000000)
            LONESTAR.SafeRunNative(TriggerEvent, 'es_extended:status:Add', 'thirst', 1000000)
            LONESTAR.SafeRunNative(TriggerEvent, 'es_extended:status:Remove', 'stress', 0)
        ]])
    elseif LS.Running("QBCore") or LS.Running("qb-core") then
        LS.Raw([[
            QBCore.Functions.SetPlayerData('hunger', 100)
            QBCore.Functions.SetPlayerData('thirst', 100)
            QBCore.Functions.SetPlayerData('stress', 0)
        ]], "qb-core")
    else
        LS.Raw([[
            TriggerEvent('esx_status:set', 'hunger', 1000000)
            TriggerEvent('esx_status:set', 'thirst', 1000000)
            TriggerEvent('esx_status:set', 'stress', 0)
        ]])
    end
    LS.Ok("Needs reset")
end)

MachoMenuButton(SelfMain, "Remove Stress", function()
    if LS.Running("jg-stress-addon") then
        LS.Raw([[ LocalPlayer.state:set('stress', -100) ]], "jg-stress-addon")
    elseif LS.Running("esx_status") then
        LS.Raw([[ TriggerEvent('esx_status:set', 'stress', 0) ]], "esx_status")
    else
        LS.Raw([[ LocalPlayer.state:set('stress', 0) ]])
    end
    LS.Ok("Stress removed")
end)

MachoMenuText(SelfMain, "Revive")

-- Combined revive: the union of Allstar's and Amiwa's framework
-- chains, evaluated in order of likelihood.
local ReviveTarget = nil
MachoMenuDropDown(SelfMain, "Revive Method", function(index)
    ReviveTarget = index
end,
    "Auto (all frameworks)",
    "Native Resurrect",
    "ESX Ambulance",
    "QB / QBCore",
    "Sxph / Ryban",
    "Wasabi",
    "Ars",
    "Whoapd",
    "Paramedic",
    "CFX-HU",
    "Hospital",
    "TxAdmin"
)

MachoMenuButton(SelfMain, "Revive Self", function()
    local method = ReviveTarget or 1
    LS.Run(([[
        local ped = LONESTAR.SelfPed()
        if not ped then return end

        local function nativeRevive()
            local coords = GetEntityCoords(ped)
            LONESTAR.SafeRunNative(TriggerScreenblurFadeOut, 0)
            LONESTAR.SafeRunNative(SetEntityCoordsNoOffset, ped, coords.x, coords.y, coords.z, false, false, false)
            LONESTAR.SafeRunNative(SetPlayerInvincible, ped, false)
            LONESTAR.SafeRunNative(ClearPedBloodDamage, ped)
            LONESTAR.SafeRunNative(NetworkResurrectLocalPlayer, coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
        end

        local function esxAmbulance()
            LONESTAR.SafeRunNative(TriggerEvent, 'esx_ambulancejob:revive')
            LONESTAR.SafeRunNative(TriggerEvent, 'esx_ambulance:revive')
            LONESTAR.SafeRunNative(TriggerEvent, 'esx:onPlayerSpawn')
            LONESTAR.SafeRunNative(TriggerEvent, 'esx_ambulancejob:setDeathStatus', false)
        end

        local function qbCore()
            LONESTAR.SafeRunNative(TriggerEvent, 'QBCore:Server:Revive', GetPlayerServerId(PlayerId()))
            LONESTAR.SafeRunNative(TriggerEvent, 'hospital:client:Revive', 100)
        end

        local function sxphRyban()
            LONESTAR.SafeRunNative(TriggerEvent, 'sxph:setDeathStatus', false, false)
            LONESTAR.SafeRunNative(TriggerEvent, 'sxph:revive')
            LONESTAR.SafeRunNative(TriggerEvent, 'cfx-sxph-injury:client:RemoveBleed')
            LONESTAR.SafeRunNative(TriggerEvent, 'cfx-sxph-injury:client:ResetLimbs')
        end

        local function wasabi()
            LONESTAR.SafeRunNative(TriggerEvent, 'wasabi_ambulance:revive')
            LONESTAR.SafeRunNative(TriggerEvent, 'wasabi_ambulance:heal')
        end

        local function ars()
            LONESTAR.SafeRunNative(TriggerEvent, 'ars_ambulancejob:revive')
            LONESTAR.SafeRunNative(TriggerEvent, 'ars_ambulancejob:healStatus')
        end

        local function whoapd()  LONESTAR.SafeRunNative(TriggerEvent, 'whoapd:revive') end
        local function paramedic() LONESTAR.SafeRunNative(TriggerEvent, 'paramedic:revive') end
        local function deathscr() LONESTAR.SafeRunNative(TriggerEvent, 'deathscreen:revive') end
        local function cfxHu()   LONESTAR.SafeRunNative(TriggerEvent, 'esx_ambulance:revive') end
        local function hospital() LONESTAR.SafeRunNative(TriggerEvent, 'hospital:client:Revive', 100) end
        local function txAdmin() LONESTAR.SafeRunNative(TriggerEvent, 'txcl:revivePlayer') end

        if method == 1 then
            -- Fan out to every framework so the widest coverage wins.
            nativeRevive()
            esxAmbulance(); qbCore(); sxphRyban(); wasabi(); ars()
            whoapd(); paramedic(); deathscr()
        elseif method == 2 then nativeRevive()
        elseif method == 3 then esxAmbulance()
        elseif method == 4 then qbCore()
        elseif method == 5 then sxphRyban()
        elseif method == 6 then wasabi()
        elseif method == 7 then ars()
        elseif method == 8 then whoapd()
        elseif method == 9 then paramedic()
        elseif method == 10 then cfxHu()
        elseif method == 11 then hospital()
        elseif method == 12 then txAdmin()
        end
    ]]):format(method))
    LS.Ok("Revive dispatched")
end)

MachoMenuText(SelfMain, "Model & Appearance")

local ModelBox = MachoMenuInputbox(SelfMain, "Model Name", "Ex. a_m_m_business_01")

MachoMenuButton(SelfMain, "Set Model By Name", function()
    local model = LS.Ident(MachoMenuGetInputbox(ModelBox))
    if not model then LS.Err("Enter a valid model name first") return end

    LS.Run(([[
        local model = '%s'
        local hash = GetHashKey(model)
        if hash == 0 or not IsModelValid(hash) then return end
        LONESTAR.SafeRunNative(RequestModel, hash)
        local timeout = 0
        while not HasModelLoaded(hash) and timeout < 300 do
            LONESTAR.SafeRunNative(Wait, 10)
            timeout = timeout + 1
        end
        LONESTAR.SafeRunNative(SetPlayerModel, PlayerId(), hash)
        LONESTAR.SafeRunNative(SetModelAsNoLongerNeeded, hash)
    ]]):format(model))
    LS.Ok(("Model set to %s"):format(model))
end)

local ModelPreset = nil

MachoMenuDropDown(SelfMain, "Preset Model", function(index)
    ModelPreset = index
end, "None", "Freemode Male", "Freemode Female", "Michael", "Franklin", "Trevor", "Story Male", "Story Female")

MachoMenuButton(SelfMain, "Apply Preset Model", function()
    local presets = {
        [2] = "a_m_m_freemode_01", [3] = "a_f_m_freemode_01",
        [4] = "a_m_m_filmore_01", [5] = "a_m_m_freemode_01", [6] = "a_m_m_tringen_01",
        [7] = "a_m_y_genome_01",  [8] = "a_f_y_genome_01",
    }
    local model = presets[ModelPreset or 0]
    if not model then LS.Err("Pick a preset first") return end
    LS.Run(([[
        local hash = GetHashKey('%s')
        LONESTAR.SafeRunNative(RequestModel, hash)
        local t = 0
        while not HasModelLoaded(hash) and t < 300 do LONESTAR.SafeRunNative(Wait, 10) t = t + 1 end
        LONESTAR.SafeRunNative(SetPlayerModel, PlayerId(), hash)
    ]]):format(model))
    LS.Ok("Model applied")
end)

MachoMenuButton(SelfMain, "Random Outfit", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        -- Snapshot the current outfit once so it can be restored.
        if not LONESTAR.OriginalOutfit then
            LONESTAR.OriginalOutfit = {
                components = {}, props = {},
                drawable = {}, texture = {}
            }
            for i = 0, 11 do
                LONESTAR.OriginalOutfit.drawable[i], LONESTAR.OriginalOutfit.texture[i] =
                    GetPedDrawableVariation(ped, i), GetPedTextureVariation(ped, i)
            end
            for i = 0, 8 do
                LONESTAR.OriginalOutfit.props[i] = GetPedPropIndex(ped, i)
            end
        end
        for i = 0, 11 do
            SetPedComponentVariation(ped, i, math.random(0, 20), math.random(0, 5), 0)
        end
        for i = 0, 8 do
            if math.random(0, 1) == 1 then
                SetPedPropIndex(ped, i, math.random(0, 30), math.random(0, 3), true)
            end
        end
    ]])
    LS.Ok("Outfit randomised - use Restore Outfit to revert")
end)

MachoMenuButton(SelfMain, "Restore Original Outfit", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped or not LONESTAR.OriginalOutfit then return end
        local o = LONESTAR.OriginalOutfit
        for i = 0, 11 do
            SetPedComponentVariation(ped, i, o.drawable[i] or 0, o.texture[i] or 0, 0)
        end
        for i = 0, 8 do
            SetPedPropIndex(ped, i, o.props[i] or -1, 0, true)
        end
    ]])
    LS.Ok("Original outfit restored")
end)

MachoMenuText(SelfMain, "Voice")

local RadioBox = MachoMenuInputbox(SelfMain, "Radio Frequency", "Ex. 3")

MachoMenuButton(SelfMain, "Connect To Radio", function()
    local freq = tonumber(LS.Trim(MachoMenuGetInputbox(RadioBox)))
    if not freq then LS.Err("Enter a numeric frequency") return end
    if LS.Running("pma-voice") then
        LS.Raw(([[ exports['pma-voice']:setRadioChannel(%d) ]]):format(freq), "pma-voice")
        LS.Ok(("Joined radio channel %d"):format(freq))
    else
        LS.Info("pma-voice not found")
    end
end)

MachoMenuButton(SelfMain, "Leave Radio", function()
    if LS.Running("pma-voice") then
        LS.Raw([[ exports['pma-voice']:setRadioChannel(0) ]], "pma-voice")
        LS.Ok("Left radio channel")
    end
end)

MachoMenuText(SelfMain, "Movement")

MachoMenuSlider(SelfMain, "Noclip Speed", 12.0, 1.0, 1.0, "x", 0.5, function(value)
    LS.NoclipSpeed = value
end)
LS.NoclipSpeed = 1.0

MachoMenuCheckbox(SelfMain, "Freecam", function()
    LS.ToggleFreecam(true)
end, function()
    LS.ToggleFreecam(false)
end)
