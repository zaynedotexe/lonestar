
-- =============================================================
-- 11. NOCLIP
--     Amiwa shipped four separate noclip implementations, one per
--     anticheat, each defeating that AC's specific collision
--     monitor. Lonestar keeps all four and auto-picks the right one
--     from the scan, with a manual override dropdown.
-- =============================================================

---@param mode integer
function LS.SetNoclip(mode)
    LS.NoclipMode = mode
end

MachoMenuDropDown(SelfExtra, "Noclip Mode", function(index)
    LS.SetNoclip(index)
end,
    "Auto",
    "Standard",
    "Ghost (ElectronAC)",
    "Bypass (FiveGuard)",
    "Shield (WaveShield)",
    "Silent (ReaperV4)"
)

function LS.ToggleNoclip(state)
    local speed = tonumber(LS.NoclipSpeed or 1.0)
    LS.NoclipEnabled = state and true or false

    if not state then
        LS.StopLoop("Lonestar.Noclip")
        LS.Run([[
            local ped = LONESTAR.SelfPed()
            if ped then
                LONESTAR.SafeRunNative(SetEntityCollision, ped, true, true)
                LONESTAR.SafeRunNative(SetEntityVelocity, ped, 0.0, 0.0, 0.0)
                LONESTAR.SafeRunNative(SetPedGravityEnabled, ped, true)
                LONESTAR.NoclipVector = nil
            end
        ]])
        return
    end

    -- Resolve the best mode for the detected anticheat.
    local resolved
    if LS.NoclipMode and LS.NoclipMode > 1 then
        resolved = LS.NoclipMode
    elseif LS.HasAC("ElectronAC") then resolved = 3
    elseif LS.HasAC("FiveGuard") then resolved = 4
    elseif LS.HasAC("WaveShield") then resolved = 5
    elseif LS.HasAC("ReaperV4") then resolved = 6
    else resolved = 2 end

    local strategy
    if resolved == 3 then
        -- ElectronAC: teleport-based movement hides velocity deltas.
        strategy = [[
            local ped = LONESTAR.SelfPed()
            if not ped then return end
            LONESTAR.SafeRunNative(SetEntityCollision, ped, false, false)
            LONESTAR.SafeRunNative(SetPedGravityEnabled, ped, false)
            LONESTAR.SafeRunNative(DisableControlAction, 0, 1, true)
            LONESTAR.SafeRunNative(DisableControlAction, 0, 2, true)
            local speed = %f
            if IsControlPressed(0, 21) then speed = speed * 2.0 end
            local base = GetEntityCoords(ped)
            local rot = GetGameplayCamRot(2)
            local rad = math.rad(rot.z)
            local dir = vector3(-math.sin(rad), math.cos(rad), 0.0)
            local right = vector3(dir.y, -dir.x, 0.0)
            local move = vector3(0.0, 0.0, 0.0)
            if IsControlPressed(0, 32) then move = move + dir end
            if IsControlPressed(0, 33) then move = move - dir end
            if IsControlPressed(0, 34) then move = move + right end
            if IsControlPressed(0, 35) then move = move - right end
            if IsControlPressed(0, 22) then move = move + vector3(0.0, 0.0, 1.0) end
            if IsControlPressed(0, 36) then move = move - vector3(0.0, 0.0, 1.0) end
            if move ~= vector3(0.0, 0.0, 0.0) then
                LONESTAR.SafeRunNative(SetEntityCoordsNoOffset, ped,
                    base.x + move.x * speed, base.y + move.y * speed, base.z + move.z * speed,
                    false, false, false)
            end
        ]]
    elseif resolved == 4 then
        -- FiveGuard: camera-relative push with collision restored on exit.
        strategy = [[
            local ped = LONESTAR.SelfPed()
            if not ped then return end
            LONESTAR.SafeRunNative(SetEntityCollision, ped, false, false)
            local speed = %f
            if IsControlPressed(0, 21) then speed = speed * 2.0 end
            LONESTAR.SafeRunNative(DisableControlAction, 0, 1, true)
            LONESTAR.SafeRunNative(DisableControlAction, 0, 2, true)
            local coords = GetEntityCoords(ped)
            local rot = GetGameplayCamRot(2)
            local rad = math.rad(rot.z)
            local radX = math.rad(rot.x)
            local cosX = math.cos(radX)
            local forward = vector3(-math.sin(rad) * cosX, math.cos(rad) * cosX, math.sin(radX))
            local right = vector3(math.cos(rad), math.sin(rad), 0.0)
            local move = vector3(0.0, 0.0, 0.0)
            if IsControlPressed(0, 32) then move = move + forward end
            if IsControlPressed(0, 33) then move = move - forward end
            if IsControlPressed(0, 34) then move = move + right end
            if IsControlPressed(0, 35) then move = move - right end
            if IsControlPressed(0, 22) then move = move + vector3(0.0, 0.0, 1.0) end
            if IsControlPressed(0, 36) then move = move - vector3(0.0, 0.0, 1.0) end
            if move ~= vector3(0.0, 0.0, 0.0) then
                move = move * speed
                LONESTAR.SafeRunNative(SetEntityCoordsNoOffset, ped,
                    coords.x + move.x, coords.y + move.y, coords.z + move.z, false, false, false)
            end
        ]]
    elseif resolved == 5 then
        -- WaveShield: interpolation between sampled waypoints.
        strategy = [[
            local ped = LONESTAR.SelfPed()
            if not ped then return end
            LONESTAR.SafeRunNative(SetEntityCollision, ped, false, false)
            local speed = %f
            if IsControlPressed(0, 21) then speed = speed * 3.0 end
            LONESTAR.NoclipFrom = LONESTAR.NoclipFrom or GetEntityCoords(ped)
            LONESTAR.NoclipTo = LONESTAR.NoclipTo or GetEntityCoords(ped)
            local rad = math.rad(GetGameplayCamRot(2).z)
            local dir = vector3(-math.sin(rad), math.cos(rad), 0.0)
            local right = vector3(dir.y, -dir.x, 0.0)
            local step = vector3(0.0, 0.0, 0.0)
            if IsControlPressed(0, 32) then step = step + dir end
            if IsControlPressed(0, 33) then step = step - dir end
            if IsControlPressed(0, 34) then step = step + right end
            if IsControlPressed(0, 35) then step = step - right end
            if IsControlPressed(0, 22) then step = step + vector3(0.0, 0.0, 1.0) end
            if IsControlPressed(0, 36) then step = step - vector3(0.0, 0.0, 1.0) end
            if step ~= vector3(0.0, 0.0, 0.0) then
                LONESTAR.NoclipFrom = GetEntityCoords(ped)
                LONESTAR.NoclipTo = LONESTAR.NoclipFrom + (step * speed)
            end
            LONESTAR.SafeRunNative(SetEntityCoordsNoOffset, ped,
                LONESTAR.NoclipFrom.x, LONESTAR.NoclipFrom.y, LONESTAR.NoclipFrom.z, false, false, false)
            LONESTAR.SafeRunNative(SetEntityCoordsNoOffset, ped,
                LONESTAR.NoclipTo.x, LONESTAR.NoclipTo.y, LONESTAR.NoclipTo.z, false, false, false)
        ]]
    elseif resolved == 6 then
        -- ReaperV4: freeze-frame sampling, apply on the next tick only.
        strategy = [[
            local ped = LONESTAR.SelfPed()
            if not ped then return end
            LONESTAR.SafeRunNative(SetEntityCollision, ped, false, false)
            local speed = %f
            if IsControlPressed(0, 21) then speed = speed * 2.0 end
            local coords = GetEntityCoords(ped)
            local rad = math.rad(GetGameplayCamRot(2).z)
            local dir = vector3(-math.sin(rad), math.cos(rad), 0.0)
            local right = vector3(dir.y, -dir.x, 0.0)
            local move = vector3(0.0, 0.0, 0.0)
            if IsControlPressed(0, 32) then move = move + dir end
            if IsControlPressed(0, 33) then move = move - dir end
            if IsControlPressed(0, 34) then move = move + right end
            if IsControlPressed(0, 35) then move = move - right end
            if IsControlPressed(0, 22) then move = move + vector3(0.0, 0.0, 1.0) end
            if IsControlPressed(0, 36) then move = move - vector3(0.0, 0.0, 1.0) end
            if move ~= vector3(0.0, 0.0, 0.0) then
                LONESTAR.NoclipPending = coords + (move * speed)
            elseif LONESTAR.NoclipPending then
                LONESTAR.SafeRunNative(SetEntityCoordsNoOffset, ped,
                    LONESTAR.NoclipPending.x, LONESTAR.NoclipPending.y, LONESTAR.NoclipPending.z,
                    false, false, false)
                LONESTAR.NoclipPending = nil
            end
        ]]
    else
        -- Standard: velocity based, keeps physics live for servers that check it.
        strategy = [[
            local ped = LONESTAR.SelfPed()
            if not ped then return end
            LONESTAR.SafeRunNative(SetEntityCollision, ped, false, false)
            LONESTAR.SafeRunNative(SetEntityGravityEnabled, ped, false)
            local speed = %f
            if IsControlPressed(0, 21) then speed = speed * 2.0 end
            LONESTAR.SafeRunNative(DisableControlAction, 0, 1, true)
            LONESTAR.SafeRunNative(DisableControlAction, 0, 2, true)
            local rad = math.rad(GetGameplayCamRot(2).z)
            local dir = vector3(-math.sin(rad), math.cos(rad), 0.0)
            local right = vector3(dir.y, -dir.x, 0.0)
            local move = vector3(0.0, 0.0, 0.0)
            if IsControlPressed(0, 32) then move = move + dir end
            if IsControlPressed(0, 33) then move = move - dir end
            if IsControlPressed(0, 34) then move = move + right end
            if IsControlPressed(0, 35) then move = move - right end
            if IsControlPressed(0, 22) then move = move + vector3(0.0, 0.0, 1.0) end
            if IsControlPressed(0, 36) then move = move - vector3(0.0, 0.0, 1.0) end
            if move ~= vector3(0.0, 0.0, 0.0) then
                LONESTAR.SafeRunNative(SetEntityVelocity, ped, move.x * speed, move.y * speed, move.z * speed)
            end
        ]]
    end

    LS.StartLoop("Lonestar.Noclip", strategy:format(speed, speed, speed, speed), [[
        local ped = LONESTAR.SelfPed()
        if ped then
            LONESTAR.SafeRunNative(SetEntityCollision, ped, true, true)
            LONESTAR.SafeRunNative(SetPedGravityEnabled, ped, true)
            LONESTAR.NoclipVector = nil
            LONESTAR.NoclipPending = nil
        end
    ]])
end

MachoMenuCheckbox(SelfExtra, "Noclip", function()
    LS.ToggleNoclip(true)
    LS.Ok("Noclip enabled")
end, function()
    LS.ToggleNoclip(false)
    LS.Info("Noclip disabled")
end)

-- =============================================================
-- 12. FREECAM
--     Amiwa's implementation. OverrideLodScaleThisFrame is what
--     makes the camera survive far-plane culling at altitude.
-- =============================================================

LS.FreecamActive = false
LS.FreecamSpeed  = 0.4

MachoMenuSlider(SelfExtra, "Freecam Speed", 4.0, 0.1, 0.4, "", 0.1, function(value)
    LS.FreecamSpeed = value
end)

---@param state boolean
function LS.ToggleFreecam(state)
    if state == LS.FreecamActive then return end
    LS.FreecamActive = state

    if state then
        LS.Run(([[
            local speed = %f
            LONESTAR.FreeCam = true
            LONESTAR.FreeCamHandle = nil

            LONESTAR.FreeCamRotToDirection = function(rot)
                local radZ = math.rad(rot.z)
                local radX = math.rad(rot.x)
                local cosX = math.cos(radX)
                return vector3(-math.sin(radZ) * cosX, math.cos(radZ) * cosX, math.sin(radX))
            end

            LONESTAR.FreeCamRotToRight = function(rot)
                local radZ = math.rad(rot.z)
                return vector3(math.cos(radZ), math.sin(radZ), 0.0)
            end

            LONESTAR.CreateTrackedThread('Lonestar.FreeCam', {
                thread = function()
                    local ped = LONESTAR.SelfPed()
                    if not ped then return end

                    local camPos = GetGameplayCamCoord()
                    local camRot = GetGameplayCamRot(2)
                    LONESTAR.FreeCamHandle = CreateCamWithParams(
                        'DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z,
                        camRot.x, camRot.y, camRot.z, 70.0, 1, 0)

                    SetCamActive(LONESTAR.FreeCamHandle, true)
                    RenderScriptCams(true, true, 0, true, true)

                    while _G.SetClient_TrackedSafeThreads['Lonestar.FreeCam'] do
                        local cam = LONESTAR.FreeCamHandle
                        if not cam or not DoesCamExist(cam) then break end

                        -- Keep LOD scale high so distant geometry stays rendered.
                        OverrideLodScaleThisFrame(2.0)
                        SetCamFarClip(cam, 0.0)

                        local step = speed
                        if IsDisabledControlPressed(0, 21) then step = step * 4.0 end

                        local pos = GetCamCoord(cam)
                        local rot = GetCamRot(cam, 2)
                        local fwd = LONESTAR.FreeCamRotToDirection(rot)
                        local right = LONESTAR.FreeCamRotToRight(rot)

                        DisableControlAction(0, 1, true)
                        DisableControlAction(0, 2, true)
                        DisableControlAction(0, 24, true)

                        if IsDisabledControlPressed(0, 32) then
                            SetCamCoord(cam, pos.x + fwd.x * step, pos.y + fwd.y * step, pos.z + fwd.z * step)
                        end
                        if IsDisabledControlPressed(0, 33) then
                            SetCamCoord(cam, pos.x - fwd.x * step, pos.y - fwd.y * step, pos.z - fwd.z * step)
                        end
                        if IsDisabledControlPressed(0, 34) then
                            SetCamCoord(cam, pos.x + right.x * step, pos.y + right.y * step, pos.z)
                        end
                        if IsDisabledControlPressed(0, 35) then
                            SetCamCoord(cam, pos.x - right.x * step, pos.y - right.y * step, pos.z)
                        end
                        if IsDisabledControlPressed(0, 22) then
                            SetCamCoord(cam, pos.x, pos.y, pos.z + step)
                        end
                        if IsDisabledControlPressed(0, 36) then
                            SetCamCoord(cam, pos.x, pos.y, pos.z - step)
                        end

                        -- Raise / lower the camera far faster than foot speed.
                        if IsDisabledControlPressed(0, 14) then
                            local p = GetCamCoord(cam)
                            SetCamCoord(cam, p.x, p.y, p.z + 3.0)
                        end
                        if IsDisabledControlPressed(0, 15) then
                            local p = GetCamCoord(cam)
                            SetCamCoord(cam, p.x, p.y, p.z - 3.0)
                        end

                        local x = GetDisabledControlNormal(0, 1)
                        local y = GetDisabledControlNormal(0, 2)
                        if x ~= 0.0 or y ~= 0.0 then
                            local r = GetCamRot(cam, 2)
                            SetCamRot(cam, r.x - y * 5.0, 0.0, r.z - x * 5.0, 2)
                        end

                        SetFocusPosAndVel(pos.x, pos.y, pos.z, 0.0, 0.0, 0.0)
                        SetEntityVisible(ped, false, false)

                        Wait(0)
                    end
                end,
                onRemove = function()
                    if LONESTAR.FreeCamHandle and DoesCamExist(LONESTAR.FreeCamHandle) then
                        RenderScriptCams(false, true, 500, true, true)
                        DestroyCam(LONESTAR.FreeCamHandle, false)
                    end
                    LONESTAR.FreeCamHandle = nil
                    ClearFocus()
                    local ped = LONESTAR.SelfPed()
                    if ped then SetEntityVisible(ped, true, false) end
                end
            })
        ]]):format(LS.FreecamSpeed or 0.4))
        LS.Ok("Freecam enabled - WASD / QE / RF / mouse")
    else
        LS.Run([[ LONESTAR.DeleteTrackedThread('Lonestar.FreeCam') ]])
        LS.Info("Freecam disabled")
    end
end

-- =============================================================
-- 13. SLIDE (Menudo's, with the shared-flag bug fixed)
-- =============================================================

MachoMenuCheckbox(SelfExtra, "Slide", function()
    LS.Run([[
        LONESTAR.Sliding = true
        LONESTAR.CreateTrackedThread('Lonestar.Slide', {
            thread = function()
                local control = 47 -- G
                while _G.SetClient_TrackedSafeThreads['Lonestar.Slide'] do
                    if IsControlJustPressed(0, control) then
                        local ped = LONESTAR.SelfPed()
                        if ped and not IsPedInAnyVehicle(ped, false) then
                            -- Clone the ped into a seated pose and slide it.
                            local model = GetEntityModel(ped)
                            local coords = GetEntityCoords(ped)
                            local heading = GetEntityHeading(ped)
                            local ghost = CreatePed(4, model,
                                coords.x, coords.y, coords.z, heading, 0.0, 0.0, false, false)
                            SetEntityVisible(ghost, true, false)
                            FreezeEntityPosition(ghost, true)
                            SetPedToRagdoll(ghost, 3000, 3000, 0, false, false, false)
                            local slideDir = vector3(-math.sin(math.rad(heading)), math.cos(math.rad(heading)), 0.0)
                            local travelled = 0.0
                            local runtime = 0
                            while runtime < 900 and DoesEntityExist(ghost) do
                                SetEntityCoords(ghost,
                                    coords.x + slideDir.x * travelled,
                                    coords.y + slideDir.y * travelled,
                                    coords.z + 0.05, false, false, false, false)
                                travelled = travelled + 0.35
                                runtime = runtime + 1
                                Wait(0)
                            end
                            if DoesEntityExist(ghost) then DeleteEntity(ghost) end
                        end
                    end
                    Wait(0)
                end
            end,
            onRemove = function()
                LONESTAR.Sliding = false
            end
        })
    ]])
    LS.Ok("Slide armed - press G")
end, function()
    LS.Run([[ LONESTAR.DeleteTrackedThread('Lonestar.Slide') ]])
    LS.Info("Slide disabled")
end)
