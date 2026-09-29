
-- =============================================================
-- 10. TOGGLE ENGINE
--     Every toggle is a tracked thread living in the injected
--     context, keyed by name, so disable is always reliable and
--     the previous native state can be restored explicitly.
-- =============================================================

---@param name string
---@param threadFn fun()
---@param onRemove fun|nil
function LS.StartLoop(name, threadFn, onRemove)
    LS.Run(([[
        LONESTAR.CreateTrackedThread('%s', {
            thread = function()
                while _G.SetClient_TrackedSafeThreads['%s'] do
                    %s
                    LONESTAR.SafeRunNative(Wait, 0)
                end
            end,
            onRemove = function()
                %s
            end
        })
    ]]):format(name, name, threadFn, onRemove or ""))
end

---@param name string
function LS.StopLoop(name)
    LS.Run(([[ LONESTAR.DeleteTrackedThread('%s') ]]):format(name))
end

-- ---------- 10.1 Core self toggles ----------

MachoMenuCheckbox(SelfExtra, "Godmode", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if ped then LONESTAR.SafeRunNative(SetEntityInvincible, ped, true) end
    ]])
    LS.Ok("Godmode enabled")
end, function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if ped then LONESTAR.SafeRunNative(SetEntityInvincible, ped, false) end
    ]])
    LS.Info("Godmode disabled")
end)

MachoMenuCheckbox(SelfExtra, "Invisibility", function()
    LS.StartLoop("Lonestar.Invisible", [[
        local ped = LONESTAR.SelfPed()
        if ped then
            LONESTAR.SafeRunNative(SetEntityVisible, ped, false, false)
            LONESTAR.SafeRunNative(SetEntityAlpha, ped, 0, false)
        end
    ]])
    LS.Ok("Invisibility enabled")
end, function()
    LS.StopLoop("Lonestar.Invisible")
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if ped then
            LONESTAR.SafeRunNative(SetEntityVisible, ped, true, false)
            LONESTAR.SafeRunNative(SetEntityAlpha, ped, 255, false)
        end
    ]])
    LS.Info("Invisibility disabled")
end)

MachoMenuCheckbox(SelfExtra, "No Ragdoll", function()
    -- Allstar's version snapshots and restores the proof flags.
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        LONESTAR.SavedCanRagdoll = GetPedCanRagdoll(ped)
        LONESTAR.SafeRunNative(SetPedCanRagdoll, ped, false)
        LONESTAR.SafeRunNative(SetPedConfigFlag, ped, 5, false)
        LONESTAR.SafeRunNative(SetPedConfigFlag, ped, 31, true)
    ]])
    LS.StartLoop("Lonestar.NoRagdoll", [[
        local ped = LONESTAR.SelfPed()
        if ped then
            LONESTAR.SafeRunNative(SetPedCanRagdoll, ped, false)
            LONESTAR.SafeRunNative(SetPedConfigFlag, ped, 5, false)
        end
    ]], [[
        local ped = LONESTAR.SelfPed()
        if ped then
            LONESTAR.SafeRunNative(SetPedCanRagdoll, ped, LONESTAR.SavedCanRagdoll ~= false)
            LONESTAR.SafeRunNative(SetPedConfigFlag, ped, 5, true)
            LONESTAR.SafeRunNative(SetPedConfigFlag, ped, 31, false)
        end
    ]])
    LS.Ok("Ragdoll disabled")
end, function()
    LS.StopLoop("Lonestar.NoRagdoll")
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if ped then
            LONESTAR.SafeRunNative(SetPedCanRagdoll, ped, true)
            LONESTAR.SafeRunNative(SetPedConfigFlag, ped, 5, true)
            LONESTAR.SafeRunNative(SetPedConfigFlag, ped, 31, false)
        end
    ]])
    LS.Info("Ragdoll restored")
end)

MachoMenuCheckbox(SelfExtra, "Anti-Headshot", function()
    LS.StartLoop("Lonestar.AntiHeadshot", [[
        local ped = LONESTAR.SelfPed()
        if ped then
            LONESTAR.SafeRunNative(SetPedSuffersCriticalHits, ped, false)
        end
    ]])
    LS.Ok("Anti-Headshot enabled")
end, function()
    LS.StopLoop("Lonestar.AntiHeadshot")
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if ped then LONESTAR.SafeRunNative(SetPedSuffersCriticalHits, ped, true) end
    ]])
    LS.Info("Anti-Headshot disabled")
end)

MachoMenuCheckbox(SelfExtra, "Anti-Freeze", function()
    -- Allstar's approach: keep requesting the unfreeze every frame.
    LS.StartLoop("Lonestar.AntiFreeze", [[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        if IsEntityPositionFrozen(ped) then
            LONESTAR.SafeRunNative(FreezeEntityPosition, ped, false)
        end
        -- Re-assert our own position so remote freeze attempts are dropped.
        local c = GetEntityCoords(ped)
        LONESTAR.SafeRunNative(SetEntityCoords, ped, c.x, c.y, c.z, false, false, false)
    ]])
    LS.Ok("Anti-Freeze enabled")
end, function()
    LS.StopLoop("Lonestar.AntiFreeze")
    LS.Info("Anti-Freeze disabled")
end)

MachoMenuCheckbox(SelfExtra, "Anti-Attach", function()
    LS.StartLoop("Lonestar.AntiAttach", [[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        if GetEntityVehicle(ped) ~= 0 or IsPedInAnyVehicle(ped, false) then return end
        if GetEntityParent(ped) and GetEntityParent(ped) ~= 0 then
            LONESTAR.SafeRunNative(DetachEntity, ped, true, true)
        end
        if IsPedBeingArrested(ped) then
            LONESTAR.SafeRunNative(ClearPedTasksImmediately, ped)
        end
    ]])
    LS.Ok("Anti-Attach enabled")
end, function()
    LS.StopLoop("Lonestar.AntiAttach")
    LS.Info("Anti-Attach disabled")
end)

MachoMenuCheckbox(SelfExtra, "Anti-Carry & Anti-Launch", function()
    LS.StartLoop("Lonestar.AntiCarry", [[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        if GetEntityParent(ped) and GetEntityParent(ped) ~= 0 then
            LONESTAR.SafeRunNative(DetachEntity, ped, true, true)
        end
        LONESTAR.SafeRunNative(ClearPedTasksImmediately, ped)
    ]])
    LS.Ok("Anti-Carry enabled")
end, function()
    LS.StopLoop("Lonestar.AntiCarry")
    LS.Info("Anti-Carry disabled")
end)

MachoMenuCheckbox(SelfExtra, "Anti-VDM (Vehicle Damage)", function()
    -- Amiwa's silent-VDM: an invisible follower ped that steals damage.
    LS.StartLoop("Lonestar.AntiVDM", [[
        local ped = LONESTAR.SelfPed()
        if not ped then return end

        if not LONESTAR.VDMProxy or not DoesEntityExist(LONESTAR.VDMProxy) then
            local model = GetHashKey('a_f_m_freemode_01')
            LONESTAR.SafeRunNative(RequestModel, model)
            local t = 0
            while not HasModelLoaded(model) and t < 200 do
                LONESTAR.SafeRunNative(Wait, 10) t = t + 1
            end
            local coords = GetEntityCoords(ped)
            LONESTAR.VDMProxy = CreatePed(4, model, coords.x + 130.0, coords.y + 3.6, coords.z, 0.0, 0.0, 0.0, false, false)
            LONESTAR.SafeRunNative(SetEntityVisible, LONESTAR.VDMProxy, false, false)
            LONESTAR.SafeRunNative(SetEntityCollision, LONESTAR.VDMProxy, false, false)
        end

        LONESTAR.SafeRunNative(AttachEntityToEntity,
            LONESTAR.VDMProxy, ped, 11816, 0.0, 180.0, 0.0, 1.0, true, false, false, true, 1, true)
        LONESTAR.SafeRunNative(SetPedToRagdoll, LONESTAR.VDMProxy, 1000.0, 1000.0, 0, false, false, false)
    ]], [[
        if LONESTAR.VDMProxy and DoesEntityExist(LONESTAR.VDMProxy) then
            LONESTAR.SafeRunNative(DeleteEntity, LONESTAR.VDMProxy)
        end
        LONESTAR.VDMProxy = nil
    ]])
    LS.Ok("Anti-VDM enabled")
end, function()
    LS.StopLoop("Lonestar.AntiVDM")
    LS.Info("Anti-VDM disabled")
end)

MachoMenuCheckbox(SelfExtra, "Anti-Collision", function()
    LS.StartLoop("Lonestar.NoCollision", [[
        local ped = LONESTAR.SelfPed()
        if ped then LONESTAR.SafeRunNative(SetEntityCollision, ped, false, false) end
    ]], [[
        local ped = LONESTAR.SelfPed()
        if ped then LONESTAR.SafeRunNative(SetEntityCollision, ped, true, true) end
    ]])
    LS.Ok("Collision disabled")
end, function()
    LS.StopLoop("Lonestar.NoCollision")
    LS.Info("Collision restored")
end)

MachoMenuCheckbox(SelfExtra, "Anti-Crash", function()
    LS.StartLoop("Lonestar.AntiCrash", [[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        LONESTAR.SafeRunNative(ClearPedTasksImmediately, ped)
        LONESTAR.SafeRunNative(ResetPedStrafeClipset, ped)
        LONESTAR.SafeRunNative(SetPedToRagdoll, ped, 0.0, 0.0, 0, false, false, false)
    ]])
    LS.Ok("Anti-Crash enabled")
end, function()
    LS.StopLoop("Lonestar.AntiCrash")
    LS.Info("Anti-Crash disabled")
end)

MachoMenuCheckbox(SelfExtra, "Infinite Stamina", function()
    LS.StartLoop("Lonestar.Stamina", [[
        LONESTAR.SafeRunNative(RestorePlayerStamina, PlayerId(), 1.0)
    ]])
    LS.Ok("Infinite stamina enabled")
end, function()
    LS.StopLoop("Lonestar.Stamina")
    LS.Info("Infinite stamina disabled")
end)

MachoMenuCheckbox(SelfExtra, "Super Jump", function()
    LS.StartLoop("Lonestar.SuperJump", [[
        LONESTAR.SafeRunNative(SetPedJumpRate, PlayerPedId(), 1.0)
    ]], [[
        LONESTAR.SafeRunNative(SetPedJumpRate, PlayerPedId(), 0.44)
    ]])
    LS.Ok("Super jump enabled")
end, function()
    LS.StopLoop("Lonestar.SuperJump")
    LS.Info("Super jump disabled")
end)

MachoMenuCheckbox(SelfExtra, "Fast Run", function()
    LS.StartLoop("Lonestar.FastRun", [[
        LONESTAR.SafeRunNative(SetPedMoveRateOverride, PlayerPedId(), 2.0)
        LONESTAR.SafeRunNative(SetPedSuffersCriticalHits, PlayerPedId(), false)
    ]], [[
        LONESTAR.SafeRunNative(SetPedMoveRateOverride, PlayerPedId(), 1.0)
    ]])
    LS.Ok("Fast run enabled")
end, function()
    LS.StopLoop("Lonestar.FastRun")
    LS.Info("Fast run disabled")
end)

MachoMenuCheckbox(SelfExtra, "Tiny Ped", function()
    LS.Run([[
        LONESTAR.SavedPedScale = GetEntityScale(PlayerPedId())
        SetPedScale(PlayerPedId(), 0.1)
    ]])
    LS.Ok("Tiny ped enabled")
end, function()
    LS.Run([[
        SetPedScale(PlayerPedId(), LONESTAR.SavedPedScale or 1.0)
    ]])
    LS.Info("Tiny ped disabled")
end)

MachoMenuCheckbox(SelfExtra, "Solo Session", function()
    LS.Raw([[
        NetworkStartSoloTutorialSession()
    ]])
    LS.Ok("Solo session started")
end, function()
    LS.Raw([[ NetworkEndTutorialSession() ]])
    LS.Info("Solo session ended")
end)

MachoMenuCheckbox(SelfExtra, "Friendly Fire", function()
    -- Amiwa's version: relationship groups + damage multipliers.
    LS.StartLoop("Lonestar.FriendlyFire", [[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        for _, group in ipairs({ GetPedRelationshipGroupHash(ped), 0 }) do
            LONESTAR.SafeRunNative(SetPedDamageMultiplier, ped, 100.0, 100.0)
            LONESTAR.SafeRunNative(SetEntityCanBeDamagedByRelationshipGroup, ped, group, true)
        end
        LONESTAR.SafeRunNative(SetPedFriendlyTask, ped, 0, 0)
    ]], [[
        local ped = LONESTAR.SelfPed()
        if ped then LONESTAR.SafeRunNative(SetPedFriendlyTask, ped, 0, 0) end
    ]])
    LS.Ok("Friendly fire enabled")
end, function()
    LS.StopLoop("Lonestar.FriendlyFire")
    LS.Info("Friendly fire disabled")
end)

MachoMenuCheckbox(SelfExtra, "Passive Mode", function()
    LS.StartLoop("Lonestar.Passive", [[
        local ped = LONESTAR.SelfPed()
        if ped then
            LONESTAR.SafeRunNative(SetEntityCanBeDamagedByEntity, ped, false, false)
        end
    ]], [[
        local ped = LONESTAR.SelfPed()
        if ped then
            LONESTAR.SafeRunNative(SetEntityCanBeDamagedByEntity, ped, true, true)
        end
    ]])
    LS.Ok("Passive mode enabled")
end, function()
    LS.StopLoop("Lonestar.Passive")
    LS.Info("Passive mode disabled")
end)

MachoMenuCheckbox(SelfExtra, "Bypass Safe Zones", function()
    LS.StartLoop("Lonestar.Safezone", [[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        -- Disarm ox_inventory's safezone policing.
        if _G.ox and _G.ox.state and _G.ox.state.zones and _G.ox.state.zones.safe then
            _G.ox.state.zones.safe.pos = vector3(0.0, 0.0, 0.0)
            _G.ox.state.zones.safe.radiusSq = 0.0
        end
        if _G.insideSafeZone ~= nil then _G.insideSafeZone = false end
    ]])
    LS.Ok("Safezone bypass enabled")
end, function()
    LS.StopLoop("Lonestar.Safezone")
    LS.Info("Safezone bypass disabled")
end)

MachoMenuCheckbox(SelfExtra, "Super Punch", function()
    LS.StartLoop("Lonestar.SuperPunch", [[
        local ped = LONESTAR.SelfPed()
        if ped then
            LONESTAR.SafeRunNative(SetPedDamageMultiplier, ped, 100.0, 100.0)
            LONESTAR.SafeRunNative(SetPedMeleeWeaponDamageMultiplier, ped, 10.0)
        end
    ]], [[
        local ped = LONESTAR.SelfPed()
        if ped then LONESTAR.SafeRunNative(SetPedMeleeWeaponDamageMultiplier, ped, 1.0) end
    ]])
    LS.Ok("Super punch enabled")
end, function()
    LS.StopLoop("Lonestar.SuperPunch")
    LS.Info("Super punch disabled")
end)

MachoMenuCheckbox(SelfExtra, "Kill Bubble Mode", function()
    -- Amiwa's self-harm loop: explosions in a shrinking radius.
    LS.StartLoop("Lonestar.KillBubble", [[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        local coords = GetEntityCoords(ped)
        local radius = math.random(30, 150) / 10.0
        local pos = vector3(
            coords.x + math.random(-100, 100) / 100.0 * radius,
            coords.y + math.random(-100, 100) / 100.0 * radius,
            coords.z + 2.0)
        LONESTAR.SafeRunNative(AddExplosion, pos.x, pos.y, pos.z, 6, 0.0, false, false, 0.0, false, false, false, false, 0, false)
    ]])
    LS.Ok("Kill bubble enabled")
end, function()
    LS.StopLoop("Lonestar.KillBubble")
    LS.Info("Kill bubble disabled")
end)

MachoMenuText(SelfExtra, "txAdmin Modes")

local TxModes = { "None", "Godmode", "Noclip", "Super Jump", "Show IDs", "Teleport To Waypoint", "Fix Vehicle" }

local TxMode = 1

MachoMenuDropDown(SelfExtra, "TxAdmin Action", function(index)
    TxMode = index
end, "None", "Godmode", "Noclip", "Super Jump", "Show IDs", "Teleport To Waypoint", "Fix Vehicle")

MachoMenuButton(SelfExtra, "Apply TxAdmin Action", function()
    local actions = {
        [2] = 'TriggerEvent("txcl:setPlayerMode", "godmode", true)',
        [3] = 'TriggerEvent("txcl:setPlayerMode", "noclip", true)',
        [4] = 'TriggerEvent("txcl:setPlayerMode", "superjump", true)',
        [5] = 'TriggerEvent("txcl:toggleShowPlayerIDs")',
        [6] = 'TriggerEvent("txcl:tpToWaypoint")',
        [7] = 'TriggerEvent("txcl:fixVehicle")',
    }
    local code = actions[TxMode]
    if not code then LS.Info("No txAdmin action selected") return end
    LS.Raw(code)
    LS.Ok("txAdmin action applied")
end)

MachoMenuButton(SelfExtra, "Disable TxAdmin Modes", function()
    LS.Raw([[
        TriggerEvent('txcl:setPlayerMode', 'godmode', false)
        TriggerEvent('txcl:setPlayerMode', 'noclip', false)
        TriggerEvent('txcl:setPlayerMode', 'superjump', false)
        TriggerEvent('txcl:toggleShowPlayerIDs')
    ]])
    LS.Ok("txAdmin modes cleared")
end)
