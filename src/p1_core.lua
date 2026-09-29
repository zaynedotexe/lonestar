--[[
    ============================================================
      LONESTAR  -  combined Macho menu
      Merged from: Menudo V2.2 / Allstar / Amiwa V2
      UI style  : MachoMenuTabbedWindow (Menudo style)
      Core      : Allstar safe-native packer + Amiwa AC awareness
    ============================================================
]]

---@diagnostic disable: undefined-global

local LS = {}
LS.Version = "1.0"
LS.Brand = "Lonestar"

local CONFIG = {
    debug       = false,
    accent      = { 255, 0, 0 },
    window      = { title = "Lonestar", x = 1100, y = 550, w = 800, h = 500, tab = 150 },
    maxListRows = 32,
    defaultKey  = 0x2E, -- INSERT

    -- DUI settings. The UI is published to GitHub Pages from
    -- https://github.com/zaynedotexe/lonestar and served over https.
    -- Every other menu file stays unchanged because the widget API is
    -- implemented locally against this page.
    ui = {
        url          = "https://zaynedotexe.github.io/lonestar/",
        pollInterval = 0,
        notifyTime   = 4000,
    },
}

-- =============================================================
-- 1. NOTIFY / LOG
-- =============================================================

local function Log(fmt, ...)
    if CONFIG.debug then
        print(("[%s] " .. fmt):format(LS.Brand, ...))
    end
end

---@param title string
---@param msg string
function LS.Notify(title, msg)
    pcall(MachoMenuNotification, title or LS.Brand, msg)
end

function LS.Ok(msg)   LS.Notify(LS.Brand, "Success! | " .. tostring(msg)) end
function LS.Info(msg) LS.Notify(LS.Brand, "Info! | " .. tostring(msg)) end
function LS.Err(msg)  LS.Notify(LS.Brand, "Error! | " .. tostring(msg)) end

---@param value any
---@return string|nil
function LS.Trim(value)
    if value == nil then return nil end
    local s = tostring(value)
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then return nil end
    return s
end

---Reduce free text to characters that are safe to embed inside a quoted
---Lua string in an injected payload. Returns nil if nothing survives.
---@param value any
---@return string|nil
function LS.Ident(value)
    local s = LS.Trim(value)
    if not s then return nil end
    s = s:lower():gsub("[^%w_]", "")
    if s == "" then return nil end
    return s:sub(1, 64)
end

-- =============================================================
-- 2. RESOURCE / FRAMEWORK DETECTION
-- =============================================================

---@param name string
---@return boolean
function LS.Running(name)
    return GetResourceState(name) == "started"
end

---@var string[] ordered framework probes, first hit wins
LS.Frameworks = {
    { name = "es_extended",  label = "ESX" },
    { name = "esx_legacy",   label = "ESX Legacy" },
    { name = "qb-core",      label = "QBCore" },
    { name = "cfx-hu-core",  label = "CFX-HU" },
    { name = "humpback",     label = "Humpback" },
    { name = "core",         label = "Core" },
    { name = "monolith",     label = "Monolith" },
}

---@return string label, string|nil resource
function LS.Framework()
    for _, fw in ipairs(LS.Frameworks) do
        if LS.Running(fw.name) then
            return fw.label, fw.name
        end
    end
    return "Unknown", nil
end

-- Injection targets. The first *running* candidate is used so the
-- payload executes inside a resource that is guaranteed to be alive.
LS.InjectTargets = {
    "lunar_fishing", "jg-advancedgarages", "jg-dealerships", "cd_garage",
    "cfx-bg-garages", "es_extended", "qb-core", "ox_lib", "monitor", "any",
}

---Best resource to inject vehicle/spawn payloads into.
---@return string
function LS.VehicleTarget()
    for _, name in ipairs({ "lunar_fishing", "jg-advancedgarages", "jg-dealerships",
        "cd_garage", "cfx-bg-garages", "es_extended", "qb-core" }) do
        if LS.Running(name) then return name end
    end
    return "any"
end

---Best resource to inject generic payloads into.
---@return string
function LS.SafeTarget()
    for _, name in ipairs({ "es_extended", "qb-core", "ox_lib", "cfx-hu-core", "monitor" }) do
        if LS.Running(name) then return name end
    end
    return "any"
end

-- =============================================================
-- 3. ANTI-CHEAT SCANNER
--    Probes by injectable name, file signatures and manifest text.
-- =============================================================

LS.Anticheats = {}

---@param name string
---@return boolean
local function ResourceInjectable(name)
    local ok, result = pcall(MachoResourceInjectable, name)
    return ok and result == true
end

---Every resource except the one we are running inside.
---@return string[]
local function BuildResourceList()
    local list = {}
    local self = GetCurrentResourceName()
    for i = 0, GetNumResources() - 1 do
        local res = GetResourceByFindIndex(i)
        if res and res ~= self then list[#list + 1] = res end
    end
    return list
end

---Return the first resource whose small files contain any signature.
---@param signatures string[]
---@return string|nil
local function ScanSignatures(signatures)
    for _, res in ipairs(BuildResourceList()) do
        local files = GetResourceFileList(res) or {}
        for _, file in ipairs(files) do
            local content = LoadResourceFile(res, file)
            if content and #content > 0 and #content < 400000 then
                local lower = content:lower()
                for _, sig in ipairs(signatures) do
                    if lower:find(sig:lower(), 1, true) then
                        return res
                    end
                end
            end
        end
    end
    return nil
end

function LS.ScanAnticheats()
    local found = {}

    -- Phase 1: name probes
    for _, ac in ipairs({
        { "WaveShield", "WaveShield" }, { "ReaperV4", "ReaperV4" },
        { "ElectronAC", "ElectronAC" },   { "Eminence", "Eminence" },
        { "FiniAC", "FiniAC" },           { "Eagle", "EagleAC" },
        { "AegisX", "AegisX" },           { "VynxAC", "VynxAC" },
        { "rryban_secure", "Ryban" },    { "baguvix", "Baguvix" },
        { "EC_AC", "EC_AC" },             { "CyberAC", "CyberAC" },
        { "WardenAC", "WardenAC" },       { "FYAC", "FYAC" },
        { "PhoenixAC", "PhoenixAC" },     { "GuidAC", "GuidAC" },
        { "LikizaoAC", "LikizaoAC" },     { "OTAC", "OTAC" },
        { "FeloxAC", "FeloxAC" },         { "SniffAC", "SniffAC" },
        { "cfx-praryo-kernel", "NXGN" },
    }) do
        if LS.Running(ac[1]) or ResourceInjectable(ac[1]) then
            found[ac[2]] = ac[1]
        end
    end

    -- Phase 2: file-signature probes
    local sigs = {
        { "electron-services.com", "ElectronAC" },
        { "reaperac", "ReaperV4" },
        { "fini.ac", "FiniAC" },
        { "waveshield", "WaveShield" },
    }
    for _, sig in ipairs(sigs) do
        if not found[sig[2]] then
            local res = ScanSignatures({ sig[1] })
            if res then found[sig[2]] = res end
        end
    end

    -- Phase 3: any resource with an obfuscated client script == FiveGuard AC
    for _, res in ipairs(BuildResourceList()) do
        local meta = GetResourceMetadata(res, "client_script") or ""
        if meta:lower():find("obfusc", 1, true) and not found["FiveGuard"] then
            found["FiveGuard"] = res
        end
    end

    LS.Anticheats = found
    return found
end

---@param name string
---@return boolean
function LS.HasAC(name)
    return LS.Anticheats[name] ~= nil
end

---@return string
function LS.ACSummary()
    local names = {}
    for name in pairs(LS.Anticheats) do names[#names + 1] = name end
    if #names == 0 then return "None detected" end
    table.sort(names)
    return table.concat(names, ", ")
end

-- =============================================================
-- 4. SAFE NATIVE INJECTION  (value-packer scheduler bridge)
--    This is the Allstar engine, kept intact: the payload's natives
--    and functions are marshalled through a state bag so that
--    scheduler-level anticheats never observe a foreign call.
-- =============================================================

local function executeCode(resource, code)
    -- rryban_secure does its own native hiding, so when it is present the
    -- packer is bypassed. The override is applied AFTER the helper block is
    -- built, otherwise the helpers (SelfPed, TeleportTo, CreateTrackedThread,
    -- ...) would be missing from every payload on an rryban server.
    local passthrough = LS.Running("rryban_secure") and 1 or 0

    -- Inserted after the helper block, so the helpers survive on rryban servers.
    local mid = ""
    if passthrough == 1 then
        mid = [[
		-- rryban_secure does its own native hiding, so call natives directly.
		LONESTAR.SafeRunNative = function(setFunc, ...)
			return setFunc(...)
		end
		]]
    end

    code = [[
		-- Shared across every injection into this resource, so state saved by
		-- one button (ped scale, saved outfit, VDM proxy) survives the next.
		local LONESTAR = _G.__lonestar_shared or {}
		_G.__lonestar_shared = LONESTAR

		LONESTAR.RunId = 'RUN_ID'

		LONESTAR.StringFind = string.find
		LONESTAR.StringChar = string.char
		LONESTAR.StringLower = string.lower
		LONESTAR.TableUnpack = table.unpack

		LONESTAR.EXT_FUNCREF = 10

		LONESTAR.PackValueExt = function(tag, data)
			local len = #data

			if len == 1 then
				return LONESTAR.StringChar(0xD4, tag)..data
			elseif len == 2 then
				return LONESTAR.StringChar(0xD5, tag)..data
			elseif len == 4 then
				return LONESTAR.StringChar(0xD6, tag)..data
			elseif len == 8 then
				return LONESTAR.StringChar(0xD7, tag)..data
			elseif len == 16 then
				return LONESTAR.StringChar(0xD8, tag)..data
			elseif len <= 255 then
				return LONESTAR.StringChar(0xC7, len, tag)..data
			elseif len <= 65535 then
				return LONESTAR.StringChar(0xC8, math.floor(len / 256), len % 256, tag)..data
			end
		end

		LONESTAR.PackValue = function(val)
			local t = val ~= nil and type(val)

			if val == nil then
				return LONESTAR.StringChar(0xC0)
			elseif t == 'boolean' then
				return LONESTAR.StringChar(val and 0xC3 or 0xC2)
			elseif t == 'number' then
				if val % 1 == 0 then
					if val >= 0 and val <= 127 then
						return LONESTAR.StringChar(val)
					elseif val < 0 and val >= -32 then
						return LONESTAR.StringChar(0x100 + val)
					elseif val >= 0 and val <= 0xFF then
						return LONESTAR.StringChar(0xCC, val)
					elseif val >= 0 and val <= 0xFFFF then
						return LONESTAR.StringChar(0xCD, math.floor(val / 256), val % 256)
					elseif val >= -128 and val < 0 then
						return LONESTAR.StringChar(0xD0, 0x100 + val)
					elseif val >= -32768 and val < 0 then
						local v = 0x10000 + val
						return LONESTAR.StringChar(0xD1, math.floor(v / 256), v % 256)
					end
				end

				local buf = string.pack('>d', val)

				return LONESTAR.StringChar(0xCB) .. buf
			elseif t == 'string' then
				local len = #val

				if len <= 31 then
					return LONESTAR.StringChar(0xA0 + len) .. val
				elseif len <= 255 then
					return LONESTAR.StringChar(0xD9, len) .. val
				elseif len <= 65535 then
					return LONESTAR.StringChar(0xDA, math.floor(len / 256), len % 256) .. val
				end
			elseif t == 'function' then
				local ref = Citizen.GetFunctionReference(val)

				if ref then
					return LONESTAR.PackValueExt(LONESTAR.EXT_FUNCREF, ref)
				else
					error('Cannot pack non-referenced function')
				end
			elseif t == 'table' then
				local cfxRef = rawget(val, '__cfx_functionReference')
				if cfxRef then
					local ref = Citizen.GetFunctionReference(val)
					if ref then
						return LONESTAR.PackValueExt(LONESTAR.EXT_FUNCREF, ref)
					end
				end

				local n = #val
				local header

				if n <= 15 then
					header = LONESTAR.StringChar(0x90 + n)
				elseif n <= 65535 then
					header = LONESTAR.StringChar(0xDC, math.floor(n / 256), n % 256)
				end

				local parts = {
					header
				}

				for i = 1, n do
					parts[#parts + 1] = LONESTAR.PackValue(val[i])
				end

				return table.concat(parts)
			end
		end

		LONESTAR.RawSafeRunNative = function(native, ...)
			local funcRef = msgpack.unpack(LONESTAR.PackValue(native))

			return funcRef(...)
		end

		LONESTAR.SetSafeStateBag = function(bag, key, value, synced)
			if value == nil then
				return
			end

			local payload = LONESTAR.PackValue(value)
			if payload == nil then
				return
			end

			LONESTAR.RawSafeRunNative(SetStateBagValue, bag, key, payload, #payload, synced)
		end

		LONESTAR.SetSafeLocalState = function(key, value, synced)
			return LONESTAR.SetSafeStateBag('player:'..GetPlayerServerId(PlayerId()), key, value, synced or false)
		end

		LONESTAR.CachedSafeFuncs = {}

		LONESTAR.GetSafeFunc = function(func)
			local safeFunc = LONESTAR.CachedSafeFuncs[func]

			if safeFunc then
				return safeFunc
			end

			local serverId = GetPlayerServerId(PlayerId())
			local bag = 'player:'..serverId
			local key = '__cfx_stateBag::'..LONESTAR.RunId..'::'..math.random(999999)..'::'..GetGameTimer()

			LONESTAR.SetSafeStateBag(bag, key, func, false)

			safeFunc = Player(serverId).state[key]
			LONESTAR.CachedSafeFuncs[func] = safeFunc

			return safeFunc
		end

		LONESTAR.SafeRunNative = function(setNative, ...)
			local safeFunc = LONESTAR.GetSafeFunc(setNative)

			return safeFunc(...)
		end

		LONESTAR.SafeCall = function(cb, ...)
			local callArgs = {...}
			local createThread = LONESTAR.GetSafeFunc(Citizen.CreateThreadNow)
			local safeCb = LONESTAR.GetSafeFunc(cb)

			createThread(function()
				safeCb(LONESTAR.TableUnpack(callArgs))
			end)
		end

		LONESTAR.DeleteTrackedThread = function(threadName)
			if _G.SetClient_TrackedSafeThreads then
				local setThreadCb = _G.SetClient_TrackedSafeThreads[threadName]

				if setThreadCb then
					setThreadCb()
				end
			end
		end

		LONESTAR.DeleteAllTrackedThreads = function()
			if _G.SetClient_TrackedSafeThreads then
				local setTrackedThreads = {}

				for threadName, setThreadCb in pairs(_G.SetClient_TrackedSafeThreads) do
					if setThreadCb then
						setTrackedThreads[#setTrackedThreads + 1] = setThreadCb
					end
				end

				_G.SetClient_TrackedSafeThreads = nil

				for i = 1, #setTrackedThreads do
					LONESTAR.SafeCall(setTrackedThreads[i])
				end
			end
		end

		LONESTAR.CreateTrackedThread = function(threadName, setHandlers)
			LONESTAR.DeleteTrackedThread(threadName)

			LONESTAR.SafeCall(function()
				setHandlers.isActive = true

				_G.SetClient_TrackedSafeThreads = _G.SetClient_TrackedSafeThreads or {}

				_G.SetClient_TrackedSafeThreads[threadName] = function()
					setHandlers.isActive = false

					if _G.SetClient_TrackedSafeThreads then
						_G.SetClient_TrackedSafeThreads[threadName] = nil
					end

					if setHandlers.onRemove then
						setHandlers:onRemove()
					end
				end

				setHandlers:thread()
			end)
		end

		LONESTAR.GetEntityParent = function(entity)
			local selfPed = entity or PlayerPedId()
			local selfVehicle = GetVehiclePedIsIn(selfPed, false)
			local selfEntity = selfPed

			if selfVehicle and selfVehicle > 0 and selfPed == GetPedInVehicleSeat(selfVehicle, -1) then
				selfEntity = selfVehicle
			end

			return selfEntity
		end

		LONESTAR.SafeWrapValue = function(setVal)
			return function(...)
				local Promise = promise.new()
				local setArgs = {...}

				LONESTAR.SafeCall(function()
					Promise:resolve(setVal(LONESTAR.TableUnpack(setArgs)))
				end)

				return Citizen.Await(Promise)
			end
		end

		local AreStringsEqual = LONESTAR.SafeWrapValue(AreStringsEqual)

		LONESTAR.GetSafeArgs = function(setArgs)
			for setKey, setValue in pairs(setArgs) do
				local setType = type(setValue)

				if setType == 'function' then
					setValue = tostring(setValue)
				elseif setType == 'table' then
					setValue = LONESTAR.GetSafeArgs(setValue)
				end

				setArgs[setKey] = setValue
			end

			return setArgs
		end

		LONESTAR.SendToHook = function(hookType, ...)
			LONESTAR.SafeRunNative(AreStringsEqual, 'LONESTAR.Hook', json.encode({
				HookData = {
					HookType = hookType,
					SetArgs = LONESTAR.GetSafeArgs({...})
				}
			}))
		end

		-- ------------------------------------------------------------
		-- Shared helpers available to every payload
		-- ------------------------------------------------------------
		LONESTAR.SelfPed = function()
			local ped = PlayerPedId()
			if not DoesEntityExist(ped) then return nil end
			return ped
		end

		LONESTAR.SafeGroundZ = function(x, y, fallbackZ)
			for height = 0.0, 1000.0, 25.0 do
				local found, groundZ = GetGroundZFor_3dCoord(x, y, height, false)
				if found then
					return groundZ + 1.0
				end
			end

			return (fallbackZ or 0.0) + 1.0
		end

		LONESTAR.ClientIdFromServerId = function(serverId)
			local players = GetActivePlayers()
			for _, pid in ipairs(players) do
				if GetPlayerServerId(pid) == serverId then
					return pid
				end
			end
			return nil
		end

		LONESTAR.PedFromServerId = function(serverId)
			local clientId = LONESTAR.ClientIdFromServerId(serverId)
			if not clientId then return nil end
			local ped = GetPlayerPed(clientId)
			if not DoesEntityExist(ped) then return nil end
			return ped
		end

		LONESTAR.TeleportTo = function(x, y, z, keepVehicle)
			local ped = LONESTAR.SelfPed()
			if not ped then return false end

			local safeZ = LONESTAR.SafeGroundZ(x, y, z)
			local mover = ped

			if IsPedInAnyVehicle(ped, false) then
				if not keepVehicle then return false end
				mover = GetVehiclePedIsIn(ped, false)
			end

			LONESTAR.SafeRunNative(RequestCollisionAtCoord, x, y, safeZ)
			LONESTAR.SafeRunNative(FreezeEntityPosition, mover, true)

			if IsPedInAnyVehicle(ped, false) and keepVehicle then
				LONESTAR.SafeRunNative(SetEntityCoords, mover, x, y, safeZ, false, false, false, false)
			else
				LONESTAR.SafeRunNative(SetEntityCoordsNoOffset, ped, x, y, safeZ, false, false, false)
			end

			local started = GetGameTimer()
			while (GetGameTimer() - started) < 3000 do
				LONESTAR.SafeRunNative(RequestCollisionAtCoord, x, y, safeZ)
				if HasCollisionLoadedAroundEntity(mover) then break end
				LONESTAR.SafeRunNative(Wait, 50)
			end

			LONESTAR.SafeRunNative(FreezeEntityPosition, mover, false)
			return true
		end

		]]..mid..[[
		]]..code..[[
	]]

    code = code:gsub('RUN_ID', math.random(999999)..'-'..GetGameTimer())

    MachoInjectResourceScriptOverride(1, resource, code, '@citizen:/scripting/lua/scheduler.lua', 1, 9999)
end

---Inject into a target with an automatic fallback.
---@param code string
---@param target string|nil
function LS.Run(code, target)
    local res = target
    if not res or GetResourceState(res) == "missing" then
        res = LS.SafeTarget()
    end
    executeCode(res, code)
    Log("ran into %s", tostring(res))
end

---Raw injection (no safe-native packer) - for payloads that only need
---plain natives/events and want the smallest footprint.
---@param code string
---@param target string|nil
function LS.Raw(code, target)
    local res = target
    if not res or GetResourceState(res) == "missing" then
        res = LS.SafeTarget()
    end
    -- A minimal LONESTAR shim is still provided so payload helpers resolve.
    MachoInjectResourceRaw(res, ([[
        local LONESTAR = _G.__lonestar_shared or {}
        _G.__lonestar_shared = LONESTAR
        LONESTAR.SafeRunNative = function(setFunc, ...)
            return setFunc(...)
        end
    ]]):format() .. code)
end

-- =============================================================
-- 5. TARGET PLAYER RESOLUTION
--    Menu selection first, manual server-id fallback second.
-- =============================================================

LS.ManualId = nil

---@return integer|nil
function LS.TargetServerId()
    -- 1. A player ticked in the Lonestar roster (most explicit choice).
    if LS.Selected and GetPlayerName(LS.Selected) then
        local serverId = GetPlayerServerId(LS.Selected)
        if serverId and serverId > 0 then return serverId end
    end

    -- 2. Whatever the Macho player picker currently has highlighted.
    local ok, clientId = pcall(MachoMenuGetSelectedPlayer)
    if ok and clientId and clientId >= 0 then
        local serverId = GetPlayerServerId(clientId)
        if serverId and serverId > 0 then return serverId end
    end

    -- 3. The manual Player ID box, refreshed on demand.
    if LS.ManualIdBox then
        local boxOk, raw = pcall(MachoMenuGetInputbox, LS.ManualIdBox)
        if boxOk then LS.ManualId = raw end
    end

    local manual = tonumber(LS.ManualId or "")
    if manual and manual > 0 then return math.floor(manual) end

    return nil
end

---@param action fun(serverId: integer)
---@return boolean ok
function LS.WithTarget(action)
    local serverId = LS.TargetServerId()
    if not serverId then
        LS.Err("Select a player in Player List or enter a Player ID.")
        return false
    end
    action(serverId)
    return true
end
