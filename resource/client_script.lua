--------------------------------------------------------------------------
-- >>> p1_core.lua
--------------------------------------------------------------------------

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
    -- Matches the Allstar DUI accent: rgb(242, 109, 220).
    accent      = { 242, 109, 220 },
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


--------------------------------------------------------------------------
-- >>> p1b_ui.lua
--------------------------------------------------------------------------

--[[
    ============================================================
      1b. DUI UI LAYER  (Allstar architecture)
      ------------------------------------------------------------
      Renders the menu in a browser page loaded by MachoCreateDui,
      exactly like Allstar, instead of using the built-in MachoMenu*
      widget renderer.

      The MachoMenu* functions below are LOCAL recorders: they build a
      declarative widget tree and return handle tables. Nothing here
      talks to the real library UI, so parts 2-10 need no changes at
      all - they keep calling MachoMenuButton, MachoMenuCheckbox etc.

      Like Allstar, the DUI is a pure renderer. All navigation, the
      text input buffer and every widget interaction is handled in Lua
      via MachoOnKeyDown, and state is pushed down with
      MachoSendDuiMessage. There are no NUI callbacks, because a Macho
      DUI does not expose them.
    ============================================================
 ]]

local UI = {}
LS.UI = UI

UI.dui       = nil
UI.ready     = false
UI.visible   = false
UI.duiUrl    = CONFIG.ui and CONFIG.ui.url or ""
UI.notifyTime = CONFIG.ui and CONFIG.ui.notifyTime or 4000

UI.items     = {}   -- id -> item
UI.tabs      = {}   -- ordered list of tabs
UI.textQueue = {}   -- batched MachoMenuSetText updates

-- =============================================================
-- WINDOW / TREE CONSTRUCTION
-- =============================================================

local function NewId()
    UI.nextId = (UI.nextId or 0) + 1
    return UI.nextId
end

local function ParentOf(parent)
    if type(parent) == "table" and parent.tabs then
        return parent
    end
    return UI.window
end

---@param parent table window or tab handle
---@param item table
local function Push(parent, item)
    item.id = NewId()
    UI.items[item.id] = item
    local p = ParentOf(parent)
    if item.type == "group" then
        p.groups = p.groups or {}
        p.groups[#p.groups + 1] = item
    else
        p.items = p.items or {}
        p.items[#p.items + 1] = item
    end
    return item
end

-- Serialise the tree for the browser page. Callbacks stay in Lua.
local function EncodeItem(item)
    if item.type == "group" then
        return { id = item.id, type = "group", label = item.label }
    end
    local out = { id = item.id, type = item.type, label = item.label }
    if item.type == "checkbox" then out.checked = item.checked and true or false end
    if item.type == "dropdown" then
        out.options = item.options
        out.value = item.value
    end
    if item.type == "slider" then
        out.value = item.value
        out.min = item.min
        out.max = item.max
        out.step = item.step
        out.suffix = item.suffix
    end
    if item.type == "input" then out.value = item.value end
    if item.type == "keybind" then out.value = UI:KeyLabel(item.value) end
    return out
end

---@return table
function UI:Tree()
    local tabs = {}
    for i, tab in ipairs(UI.tabs) do
        local groups = {}
        for j, group in ipairs(tab.groups or {}) do
            local items = {}
            for k, item in ipairs(group.items or {}) do
                items[k] = EncodeItem(item)
            end
            groups[j] = { id = group.id, type = "group", label = group.label, items = items }
        end
        tabs[i] = { id = tab.id, label = tab.label, groups = groups }
    end
    return tabs
end

-- =============================================================
-- DUI TRANSPORT
-- =============================================================

local function Send(payload)
    if not UI.dui then return end
    local ok, err = pcall(MachoSendDuiMessage, UI.dui, json.encode(payload))
    if not ok and CONFIG.debug then
        print(("[%s] DUI send failed: %s"):format(LS.Brand, tostring(err)))
    end
end
UI.Send = Send

function UI:AccentHex()
    local a = UI.accent or { 255, 0, 0 }
    return ("#%02x%02x%02x"):format(a[1] or 255, a[2] or 0, a[3] or 0)
end

---@param vk any
---@return string
function UI:KeyLabel(vk)
    if type(vk) == "number" then
        return UI.keyNames[vk] or ("0x%X"):format(vk)
    end
    return tostring(vk or "")
end

function UI:PushTree()
    local binds = {}
    for i, item in ipairs(UI.keybindItems) do
        binds[i] = { label = item.label, value = UI:KeyLabel(item.value) }
    end

    local framework, ac = "none", 0
    if LS.Framework then pcall(function() framework = LS.Framework() or "none" end) end
    if LS.Anticheats then pcall(function() ac = #(LS.Anticheats or {}) end) end

    Send({
        action  = "init",
        brand   = LS.Brand,
        version = LS.Version,
        status  = ("%s | AC: %d | target: %s"):format(
            tostring(framework), ac, tostring(LS.SafeTarget and LS.SafeTarget() or "?")),
        title   = UI.window and UI.window.title or "Lonestar",
        accent  = self:AccentHex(),
        tabs    = self:Tree(),
        keybinds = binds,
        visible = UI.visible,
    })
    self:FlushText(true)
    self:SyncView()
end

-- A Macho DUI exposes no load callback and no NUI callbacks, so anything sent
-- straight after MachoCreateDui is dropped when the remote page has not
-- finished loading. Re-push for a while, and again on every open.
function UI:Start()
    if not self:Create() then return false end
    self:PushTree()

    CreateThread(function()
        for _, delay in ipairs({ 400, 700, 1000, 1500, 2000, 3000 }) do
            Wait(delay)
            self:PushTree()
        end
    end)
    return true
end

function UI:FlushText(force)
    if #UI.textQueue == 0 then return end
    local batch = UI.textQueue
    UI.textQueue = {}
    for i = 1, #batch do
        local entry = batch[i]
        Send({ action = "text", id = entry.id, label = entry.label })
    end
    if force then return end
end

-- =============================================================
-- VIEW / CURSOR STATE
-- =============================================================

UI.tabIndex   = 1
UI.inGroup    = false
UI.groupIndex = 1
UI.itemIndex  = 1

function UI:ActiveTab()
    return UI.tabs[UI.tabIndex]
end

function UI:GroupList()
    local tab = self:ActiveTab()
    return (tab and tab.groups) or {}
end

function UI:ItemList()
    local groups = self:GroupList()
    local group = groups[UI.groupIndex]
    return (group and group.items) or {}
end

function UI:CurrentItem()
    return self:ItemList()[UI.itemIndex]
end

local function Clamp(value, low, high)
    if high < low then return low end
    if value < low then return low end
    if value > high then return high end
    return value
end

function UI:SyncView()
    local tab = self:ActiveTab()
    if not tab then
        Send({ action = "view", tab = 0, group = 0, index = 0, groups = {} })
        return
    end

    if not self.inGroup then
        local groups = self:GroupList()
        Send({
            action = "view",
            tab    = tab.id,
            group  = 0,
            index  = Clamp(UI.groupIndex, 1, math.max(#groups, 1)) - 1,
            groups = groups,
        })
        return
    end

    local group  = self:GroupList()[UI.groupIndex]
    local items  = self:ItemList()
    Send({
        action = "view",
        tab    = tab.id,
        group  = group and group.id or 0,
        index  = Clamp(UI.itemIndex, 1, math.max(#items, 1)) - 1,
        items  = items,
    })
end

-- =============================================================
-- TEXT INPUT BUFFER  (Allstar style, handled entirely in Lua)
-- =============================================================

UI.keyboard = nil
UI.shift    = false

local CHAR_MAP = {
    [0x30] = "0", [0x31] = "1", [0x32] = "2", [0x33] = "3", [0x34] = "4",
    [0x35] = "5", [0x36] = "6", [0x37] = "7", [0x38] = "8", [0x39] = "9",
    [0x41] = "A", [0x42] = "B", [0x43] = "C", [0x44] = "D", [0x45] = "E",
    [0x46] = "F", [0x47] = "G", [0x48] = "H", [0x49] = "I", [0x4A] = "J",
    [0x4B] = "K", [0x4C] = "L", [0x4D] = "M", [0x4E] = "N", [0x4F] = "O",
    [0x50] = "P", [0x51] = "Q", [0x52] = "R", [0x53] = "S", [0x54] = "T",
    [0x55] = "U", [0x56] = "V", [0x57] = "W", [0x58] = "X", [0x59] = "Y",
    [0x5A] = "Z", [0xBD] = "-", [0xBB] = "=", [0xBC] = ",", [0xBE] = ".",
    [0xBA] = ";", [0xDE] = "'", [0xBF] = "/", [0xC0] = "`", [0x20] = " ",
}

UI.keyNames = {
    [0x08] = "BACKSPACE", [0x09] = "TAB",    [0x0D] = "ENTER",
    [0x1B] = "ESC",      [0x20] = "SPACE",  [0x2E] = "INSERT",
    [0x2D] = "DELETE",   [0x25] = "LEFT",    [0x26] = "UP",
    [0x27] = "RIGHT",    [0x28] = "DOWN",    [0x10] = "LSHIFT",
    [0xA0] = "LSHIFT",   [0xA1] = "RSHIFT",  [0xA2] = "LCONTROL",
    [0xA4] = "LALT",     [0xA5] = "RALT",    [0xA3] = "RCONTROL",
    [0x12] = "LCONTROL", [0x11] = "LCONTROL",[0x13] = "PAUSE",
    [0x14] = "CAPSLOCK", [0x90] = "NUMLOCK", [0xC5] = "SCROLLLOCK",
    [0x31] = "F1",  [0x32] = "F2",  [0x33] = "F3",  [0x34] = "F4",
    [0x35] = "F5",  [0x36] = "F6",  [0x37] = "F7",  [0x38] = "F8",
    [0x39] = "F9",  [0x3A] = "F10", [0x3B] = "F11", [0x3C] = "F12",
    [0x52] = "F3",  [0x51] = "F4",  [0x50] = "F5",  [0x4F] = "F6",
    [0x4E] = "F7",  [0x4D] = "F8",  [0x4C] = "F9",  [0x4B] = "F10",
    [0x4A] = "F11", [0x49] = "F12",
    [0x6A] = "*", [0x6B] = "+", [0x6D] = "-", [0x6E] = ".",
    [0x60] = "0", [0x61] = "1", [0x62] = "2", [0x63] = "3", [0x64] = "4",
    [0x65] = "5", [0x66] = "6", [0x67] = "7", [0x68] = "8", [0x69] = "9",
}

function UI:OpenKeyboard(title, value, onConfirm, kind, maxLength, closeable)
    if UI.keyboard then return end
    UI.keyboard = {
        title     = title or "Input",
        buffer    = kind == "keybind" and "" or tostring(value or ""),
        onConfirm = onConfirm,
        kind      = kind or "typeable",
        maxLength = maxLength or 32,
        closeable = closeable ~= false,
        vk        = nil,
    }
    self:PushKeyboard()
end

function UI:CloseKeyboard()
    UI.keyboard = nil
    Send({ action = "keyboard", visible = false })
end

function UI:PushKeyboard()
    local kb = UI.keyboard
    if not kb then return end
    if kb.kind == "keybind" then
        local name = kb.vk and (UI.keyNames[kb.vk] or ("0x%X"):format(kb.vk)) or "Press any key"
        Send({ action = "keyboard", visible = true, title = kb.title, value = name, hint = true })
        return
    end
    Send({ action = "keyboard", visible = true, title = kb.title, value = kb.buffer })
end

function UI:ConfirmKeyboard()
    local kb = UI.keyboard
    if not kb then return end
    local result = (kb.kind == "keybind") and kb.vk or kb.buffer
    self:CloseKeyboard()
    if kb.onConfirm and result ~= nil then pcall(kb.onConfirm, result, true) end
end

function UI:HandleKeyInKeyboard(vk)
    local kb = UI.keyboard
    if not kb then return true end

    if vk == 0x0D then -- Enter
        self:ConfirmKeyboard()
        return true
    end

    if vk == 0x1B then -- Escape
        if not kb.closeable then return true end
        self:CloseKeyboard()
        return true
    end

    if kb.kind == "keybind" then
        if vk == 0x1B then
            if not kb.closeable then return true end
            self:CloseKeyboard()
            return true
        end
        if vk == 0x08 then return true end
        if vk == 0x0D then return true end
        if vk == 0x10 or vk == 0xA0 or vk == 0xA1 then return true end
        kb.vk = vk
        self:PushKeyboard()
        return true
    end

    if vk == 0x08 then -- Backspace
        kb.buffer = kb.buffer:sub(1, -2)
        self:PushKeyboard()
        return true
    end

    local char = CHAR_MAP[vk]
    if char and #kb.buffer < kb.maxLength then
        if char:match("%a") then
            char = UI.shift and char:upper() or char:lower()
        elseif UI.shift and char == "-" then
            char = "_"
        end
        kb.buffer = kb.buffer .. char
        self:PushKeyboard()
    end
    return true
end

-- =============================================================
-- WIDGET INTERACTION
-- =============================================================

function UI:MoveItem(delta)
    local items = self:ItemList()
    if #items == 0 then return end
    UI.itemIndex = ((UI.itemIndex - 1 + delta) % #items) + 1
    self:SyncView()
end

function UI:MoveGroup(delta)
    local groups = self:GroupList()
    if #groups == 0 then return end
    UI.groupIndex = ((UI.groupIndex - 1 + delta) % #groups) + 1
    UI.itemIndex = 1
    self:SyncView()
end

function UI:MoveTab(delta)
    local count = #UI.tabs
    if count == 0 then return end
    UI.tabIndex   = ((UI.tabIndex - 1 + delta) % count) + 1
    UI.inGroup    = false
    UI.groupIndex = 1
    UI.itemIndex  = 1
    self:SyncView()
end

function UI:AdjustSlider(item, delta)
    local step = item.step or 1
    local min  = item.min or 0
    local max  = item.max or 100
    local next = Clamp((item.value or min) + (delta * step), min, max)
    if next == item.value then return end
    item.value = next
    Send({
        action = "widget", id = item.id, type = "slider",
        value = item.value, label = item.label,
    })
    if item.onChange then pcall(item.onChange, item.value) end
end

function UI:AdjustDropdown(item, delta)
    local count = #(item.options or {})
    if count == 0 then return end
    local next = ((item.value - 1 + delta) % count) + 1
    if next == item.value then return end
    item.value = next
    Send({
        action = "widget", id = item.id, type = "dropdown",
        value = item.value, label = item.label, options = item.options,
    })
    if item.onChange then pcall(item.onChange, item.options[next], next - 1) end
end

function UI:ActivateItem()
    local item = self:CurrentItem()
    if not item then return end

    if item.type == "button" then
        if item.onSelect then pcall(item.onSelect) end

    elseif item.type == "checkbox" then
        item.checked = not item.checked
        Send({ action = "widget", id = item.id, type = "checkbox", checked = item.checked })
        if item.checked then
            if item.onEnable then pcall(item.onEnable) end
        else
            if item.onDisable then pcall(item.onDisable) end
        end

    elseif item.type == "dropdown" then
        Send({
            action = "dropdown", id = item.id, visible = true,
            options = item.options, value = item.value, label = item.label,
        })
        UI.dropdown = item

    elseif item.type == "slider" then
        local step = item.step or 1
        if step > 0 then self:AdjustSlider(item, 1) end

    elseif item.type == "input" then
        self:OpenKeyboard(item.label, item.value, function(text)
            item.value = text
            Send({ action = "widget", id = item.id, type = "input", value = item.value })
            if item.onChange then pcall(item.onChange, item.value) end
        end, "typeable", 32, true)

    elseif item.type == "keybind" then
        self:OpenKeyboard(item.label, item.value, function(vk)
            item.value = vk
            Send({ action = "widget", id = item.id, type = "keybind", value = self:KeyLabel(vk) })
            if item.onChange then pcall(item.onChange, vk) end
        end, "keybind", 16, true)
    end
end

function UI:Enter()
    if UI.dropdown then
        local item = UI.dropdown
        UI.dropdown = nil
        Send({ action = "dropdown", id = item.id, visible = false })
        return
    end

    if not self.inGroup then
        local groups = self:GroupList()
        local group  = groups[UI.groupIndex]
        if group then
            self.inGroup = true
            UI.itemIndex = 1
            self:SyncView()
        end
        return
    end

    self:ActivateItem()
end

function UI:Backspace()
    if UI.dropdown then
        local item = UI.dropdown
        UI.dropdown = nil
        Send({ action = "dropdown", id = item.id, visible = false })
        return
    end
    if self.inGroup then
        self.inGroup = false
        UI.itemIndex = 1
        self:SyncView()
    end
end

-- =============================================================
-- KEY ROUTING
-- =============================================================

local function MenuKey(key)
    local target = UI.menuKey
    if type(target) ~= "number" or target == 0 then
        target = CONFIG.defaultKey
    end
    if key == target then return true end
    if target ~= 0x2E and (key == 0x60 or key == 0x6F) then return true end -- Numpad 0
    return false
end

function UI:OnKey(vk)
    if vk == 0x10 or vk == 0xA0 or vk == 0xA1 then
        UI.shift = true
    end

    if self:HandleKeyInKeyboard(vk) then return end

    if MenuKey(vk) then
        self:Toggle()
        return
    end

    if not UI.visible then return end

    if UI.dropdown then
        if vk == 0x26 or vk == 0x57 then        -- Up / W
            self:AdjustDropdown(UI.dropdown, -1)
        elseif vk == 0x28 or vk == 0x53 then    -- Down / S
            self:AdjustDropdown(UI.dropdown, 1)
        elseif vk == 0x0D or vk == 0x0E then     -- Enter / Numpad Enter
            self:Enter()
        elseif vk == 0x1B then                 -- Escape
            self:Backspace()
        end
        return
    end

    if vk == 0x25 or vk == 0x57 then            -- Left / W
        if self.inGroup then
            local item = self:CurrentItem()
            if item and item.type == "slider" then
                self:AdjustSlider(item, -1)
                return
            end
        end
        self:MoveItem(-1)

    elseif vk == 0x27 or vk == 0x44 then         -- Right / D
        if self.inGroup then
            local item = self:CurrentItem()
            if item and item.type == "slider" then
                self:AdjustSlider(item, 1)
                return
            end
        end
        self:MoveItem(1)

    elseif vk == 0x26 then                      -- Up
        if self.inGroup then self:MoveItem(-1) else self:MoveGroup(-1) end

    elseif vk == 0x28 then                      -- Down
        if self.inGroup then self:MoveItem(1) else self:MoveGroup(1) end

    elseif vk == 0x0D or vk == 0x0E then         -- Enter / Numpad Enter
        self:Enter()

    elseif vk == 0x1B or vk == 0x08 then         -- Escape / Backspace
        self:Backspace()

    elseif vk == 0x21 or vk == 0x6B then         -- PageUp / Numpad +
        self:MoveTab(-1)

    elseif vk == 0x22 or vk == 0x6D then         -- PageDown / Numpad -
        self:MoveTab(1)

    elseif vk == 0x74 then                       -- F8
        if self.inGroup then self:MoveItem(-1) else self:MoveGroup(-1) end
    end
end

-- =============================================================
-- SHOW / HIDE
-- =============================================================

function UI:Show()
    if UI.visible then return end
    UI.visible = true
    UI.inGroup = false
    UI.itemIndex = 1
    self:PushTree()          -- never open with a stale or missing tree
    Send({ action = "show" })
    pcall(MachoShowDui, UI.dui)
    self:SyncView()
end

function UI:Hide()
    if not UI.visible then return end
    UI.visible = false
    UI.dropdown = nil
    self:CloseKeyboard()
    Send({ action = "hide" })
    pcall(MachoHideDui, UI.dui)
end

function UI:Toggle()
    if UI.visible then self:Hide() else self:Show() end
end

function UI:Notify(title, message, kind)
    Send({
        action  = "notify",
        title   = tostring(title or LS.Brand),
        message = tostring(message or ""),
        kind    = kind or "info",
        time    = UI.notifyTime,
    })
end

-- =============================================================
-- BOOT
-- =============================================================

function UI:Create()
    if UI.dui then return UI.dui end

    if not UI.duiUrl or UI.duiUrl == "" then
        print(("[%s] CONFIG.ui.url is not set - menu cannot load"):format(LS.Brand))
        return nil
    end

    local ok, dui = pcall(MachoCreateDui, UI.duiUrl)
    if not ok or not dui then
        print(("[%s] MachoCreateDui failed: %s"):format(LS.Brand, tostring(dui)))
        return nil
    end

    UI.dui = dui
    pcall(MachoHideDui, dui)
    return dui
end

-- Batch text updates so the live player roster does not spam the DUI.
CreateThread(function()
    while true do
        Wait(100)
        UI:FlushText()
    end
end)

-- Route our navigation through the same key hook the menu keybinds use.
pcall(MachoOnKeyDown, function(vk)
    pcall(function() UI:OnKey(vk) end)
end)

pcall(MachoOnKeyUp, function(vk)
    if vk == 0x10 or vk == 0xA0 or vk == 0xA1 then
        UI.shift = false
    end
end)

-- =============================================================
-- LOCAL MACHOMENU* IMPLEMENTATION
-- ------------------------------------------------------------
-- These shadow the library UI so parts 2-10 run unchanged. The library
-- functions used for the DUI and for the safe-native packer are NOT
-- shadowed: MachoCreateDui, MachoShowDui, MachoHideDui,
-- MachoSendDuiMessage, MachoOnKeyDown, MachoOnKeyUp,
-- MachoResourceInjectable, MachoInjectResourceRaw and
-- MachoInjectResourceScriptOverride all still reach the real resource.
-- =============================================================

function MachoMenuTabbedWindow(title, x, y, w, h, tab)
    UI.window = {
        kind   = "window",
        title  = title or "Lonestar",
        x = x, y = y, w = w, h = h,
        tabWidth = tab,
        groups = {},
    }
    UI.tabs = {}
    return UI.window
end

function MachoMenuAddTab(window, label)
    local tab = { kind = "tab", id = NewId(), label = label, groups = {} }
    UI.tabs[#UI.tabs + 1] = tab
    return tab
end

function MachoMenuGroup(parent, label, _, _, _, _)
    return Push(parent, { type = "group", label = label, items = {} })
end

function MachoMenuButton(parent, label, onSelect)
    return Push(parent, { type = "button", label = label, onSelect = onSelect })
end

function MachoMenuCheckbox(parent, label, onEnable, onDisable, checked)
    return Push(parent, {
        type = "checkbox", label = label,
        onEnable = onEnable, onDisable = onDisable,
        checked = checked and true or false,
    })
end

function MachoMenuDropDown(parent, label, options, onChange, defaultIndex)
    return Push(parent, {
        type = "dropdown", label = label,
        options = options or {},
        value   = math.max((defaultIndex or 0) + 1, 1),
        onChange = onChange,
    })
end

function MachoMenuSlider(parent, label, max, min, default, suffix, step, onChange)
    local low  = min or 0
    local high = max or 100
    return Push(parent, {
        type = "slider", label = label,
        min = low, max = high,
        value = Clamp(default or low, low, high),
        suffix = suffix, step = (step and step > 0) and step or 1,
        onChange = onChange,
    })
end

function MachoMenuInputbox(parent, label, placeholder, onChange)
    return Push(parent, {
        type = "input", label = label,
        value = "", placeholder = placeholder,
        onChange = onChange,
    })
end

function MachoMenuText(parent, text, centered)
    return Push(parent, { type = "text", label = tostring(text or ""), centered = centered and true or false })
end

function MachoMenuSmallText(parent, text, centered)
    return Push(parent, { type = "smalltext", label = tostring(text or ""), centered = centered and true or false })
end

-- The real library treats this as a "press a key to bind" prompt and calls
-- back with the virtual key code. Parts 10 poll those codes themselves, so
-- the callback must receive a number, not a name.
function MachoMenuKeybind(parent, group, label, defaultKey, onChange)
    local item = Push(parent, {
        type = "keybind", label = label, group = group,
        value = defaultKey, onChange = onChange,
    })
    UI.keybindItems = UI.keybindItems or {}
    table.insert(UI.keybindItems, item)
    return item
end

-- May be called with the window handle to change the menu key, or with a
-- keybind item to change that binding.
function MachoMenuSetKeybind(target, key)
    local code = type(key) == "number" and key or nil
    if code == nil and type(key) == "string" then
        for vk, name in pairs(UI.keyNames) do
            if name == key:upper() then code = vk break end
        end
    end
    if type(target) ~= "table" or not target.id then
        UI.menuKey = code or UI.menuKey
        Send({ action = "menuKey", value = UI:KeyLabel(UI.menuKey) })
        return
    end
    target.value = code or key
    for i = 1, #(UI.keybindItems or {}) do
        if UI.keybindItems[i] == target then
            Send({ action = "widget", id = target.id, type = "keybind", value = UI:KeyLabel(target.value) })
            break
        end
    end
end

function MachoMenuSetText(item, text)
    if type(item) ~= "table" then return end
    local label = tostring(text or "")
    item.label = label
    UI.textQueue[#UI.textQueue + 1] = { id = item.id, label = label }
end

function MachoMenuGetInputbox(item)
    if type(item) ~= "table" then return "" end
    return item.value or ""
end

function MachoMenuGetSelectedPlayer()
    return LS.Selected
end

function MachoMenuSetAccent(_, r, g, b)
    UI.accent = {
        r or CONFIG.accent[1],
        g or CONFIG.accent[2],
        b or CONFIG.accent[3]
    }
    Send({ action = "accent", accent = UI:AccentHex() })
end

function MachoMenuNotification(title, message)
    UI:Notify(title, message, "info")
end

function MachoMenuDestroy()
    UI:Hide()
end


--------------------------------------------------------------------------
-- >>> p2_data.lua
--------------------------------------------------------------------------


-- =============================================================
-- 6. SHARED DATA TABLES
-- =============================================================

---Weapon model -> display label. Modelled on Allstar's list, which
---was the most complete of the three sources.
LS.Weapons = {
    Melee = {
        { "weapon_unarmed",       "Unarmed" },
        { "weapon_knife",         "Knife" },
        { "weapon_dagger",        "Dagger" },
        { "weapon_bat",           "Baseball Bat" },
        { "weapon_bottle",        "Broken Bottle" },
        { "weapon_crowbar",       "Crowbar" },
        { "weapon_golfclub",      "Golf Club" },
        { "weapon_hammer",        "Hammer" },
        { "weapon_hatchet",       "Hatchet" },
        { "weapon_machete",       "Machete" },
        { "weapon_switchblade",   "Switchblade" },
        { "weapon_nightstick",    "Nightstick" },
        { "weapon_wrench",        "Wrench" },
    },
    Handguns = {
        { "weapon_pistol",        "Pistol" },
        { "weapon_pistol_mk2",    "Pistol Mk II" },
        { "weapon_combatpistol",  "Combat Pistol" },
        { "weapon_appistol",      "AP Pistol" },
        { "weapon_stungun",       "Taser" },
        { "weapon_pistol50",      "Pistol .50" },
        { "weapon_snspistol",     "SNS Pistol" },
        { "weapon_snspistol_mk2", "SNS Pistol Mk II" },
        { "weapon_heavypistol",   "Heavy Pistol" },
        { "weapon_vintagepistol", "Vintage Pistol" },
        { "weapon_flaregun",      "Flare Gun" },
    },
    SMG = {
        { "weapon_microsmg",      "Micro SMG" },
        { "weapon_smg",           "SMG" },
        { "weapon_smg_mk2",       "SMG Mk II" },
        { "weapon_assaultsmg",    "Assault SMG" },
        { "weapon_machinepistol", "Machine Pistol" },
        { "weapon_minismg",       "Mini SMG" },
        { "weapon_combatpdw",     "Combat PDW" },
        { "weapon_gusenberg",     "Gusenberg Saw" },
    },
    Rifles = {
        { "weapon_assaultrifle",      "Assault Rifle" },
        { "weapon_assaultrifle_mk2",  "Assault Rifle Mk II" },
        { "weapon_carbinerifle",      "Carbine Rifle" },
        { "weapon_carbinerifle_mk2",  "Carbine Rifle Mk II" },
        { "weapon_advancedrifle",     "Advanced Rifle" },
        { "weapon_specialcarbine",    "Special Carbine" },
        { "weapon_specialcarbine_mk2","Special Carbine Mk II" },
        { "weapon_bullpuprifle",      "Bullpup Rifle" },
        { "weapon_bullpuprifle_mk2",  "Bullpup Rifle Mk II" },
        { "weapon_compactrifle",      "Compact Rifle" },
        { "weapon_marksmanrifle",     "Marksman Rifle" },
        { "weapon_marksmanrifle_mk2", "Marksman Rifle Mk II" },
    },
    Shotguns = {
        { "weapon_pumpshotgun",       "Pump Shotgun" },
        { "weapon_pumpshotgun_mk2",   "Pump Shotgun Mk II" },
        { "weapon_sawnoffshotgun",     "Sawed-Off Shotgun" },
        { "weapon_assaultshotgun",    "Assault Shotgun" },
        { "weapon_bullpupshotgun",    "Bullpup Shotgun" },
        { "weapon_heavyshotgun",      "Heavy Shotgun" },
        { "weapon_autoshotgun",       "Auto Shotgun" },
    },
    Snipers = {
        { "weapon_sniperrifle",       "Sniper Rifle" },
        { "weapon_heavysniper",       "Heavy Sniper" },
        { "weapon_heavysniper_mk2",   "Heavy Sniper Mk II" },
        { "weapon_marksmanrifle_mk2", "Marksman Rifle Mk II" },
    },
    Heavy = {
        { "weapon_rpg",            "RPG" },
        { "weapon_grenadelauncher", "Grenade Launcher" },
        { "weapon_minigun",        "Minigun" },
        { "weapon_hominglauncher", "Homing Launcher" },
        { "weapon_railgun",        "Railgun" },
        { "weapon_firework",       "Firework Launcher" },
        { "weapon_compactlauncher","Compact Grenade Launcher" },
    },
    Throwables = {
        { "weapon_grenade",      "Grenade" },
        { "weapon_stickybomb",   "Sticky Bomb" },
        { "weapon_molotov",      "Molotov Cocktail" },
        { "weapon_pipebomb",     "Pipe Bomb" },
        { "weapon_proxmine",     "Proximity Mine" },
        { "weapon_bzgas",        "BZ Gas" },
        { "weapon_smokegrenade", "Smoke Grenade" },
        { "weapon_ball",         "Baseball" },
        { "weapon_flare",        "Flare" },
        { "weapon_petrolcan",    "Jerry Can" },
    },
}

---Flat model -> label lookup, used to resolve dropdown selections.
LS.WeaponByLabel = {}
for _, group in pairs(LS.Weapons) do
    for _, entry in ipairs(group) do
        LS.WeaponByLabel[entry[2]] = entry[1]
    end
end

---Common vehicles for the quick-spawn dropdown. Full/custom models go
---through the free-text inputbox instead, which also covers addons.
LS.CommonVehicles = {
    { "adder",     "Adder" },
    { "zentorno",  "Zentorno" },
    { "comet2",    "Comet" },
    { "sultan",    "Sultan" },
    { "sunrise1",  "Sunrise" },
    { "jugular",   "Jugular" },
    { "komoda",    "Komoda" },
    { "neon",      "Neon" },
    { "kuruma",    "Kuruma" },
    { "pounder",   "Pounder" },
    { "patriot",   "Patriot" },
    { "sultanrs",  "Sultan RS" },
    { "t20",       "Turismo R" },
    { "vigilante", "Vigilante" },
    { "ruiner2",   "Ruiner 2" },
    { "buffalo2",  "Buffalo S" },
}

---Teleport destinations, merged from all three sources.
LS.Locations = {
    { "Legion Square",     195.19, -933.77, 29.70 },
    { "Sandy Shores",      168.09, -73.03, 69.83 },
    { "Paleto Bay",       -103.50, 646.53, 31.63 },
    { "Los Santos Intl",  -1036.26, -2736.87, 20.19 },
    { "Stab City",        -105.05, -2731.10, 35.32 },
    { "Vinewood",         613.29, -3.86, 43.79 },
    { "Maze Bank",         265.74, -801.09, 29.52 },
    { "Kortz Center",     -819.55, -175.40, 41.57 },
    { "Pillbox Hill",     -130.49, -635.72, 31.40 },
    { "Mount Chiliad",     -267.55, -330.18, 118.60 },
    { "Humane Labs",       1400.37, 3800.50, 44.90 },
    { "Mirror Park",      -1341.33, -679.10, 9.39 },
    { "Docks",            -295.26, -1395.50, 12.30 },
    { "Grove Street",     -1580.00, -618.00, 25.20 },
    { "Zancudo Pier",    -2060.00, 3400.00, 10.00 },
    { "Cayo Perico",      4957.00, 4813.00,  0.00 },
}

---Props for the attach-object troll. Merged Menudo + Allstar sets.
LS.AttachProps = {
    { "prop_barrel_02a",        "Barrel" },
    { "prop_beer_bottle_01",    "Beer Bottle" },
    { "prop_cs_hotdog_01",      "Hot Dog" },
    { "prop_dog_01a",           "Dog" },
    { "prop_dog_02a",           "Dog 2" },
    { "prop_dog_03a",           "Dog 3" },
    { "prop_dog_04a",           "Dog 4" },
    { "prop_dog_05a",           "Dog 5" },
    { "prop_dog_06a",           "Dog 6" },
    { "prop_dog_07a",           "Dog 7" },
    { "prop_dog_08a",           "Dog 8" },
    { "prop_guitar_01",         "Guitar" },
    { "prop_guitar_02",         "Guitar 2" },
    { "prop_guitar_03",         "Guitar 3" },
    { "prop_dummy_02",          "Dummy" },
    { "prop_m_c_dock_01",       "Dock" },
    { "prop_m_c_dock_02",       "Dock 2" },
    { "prop_p_gas_tank_02a",    "Gas Tank" },
    { "prop_gas_tank_02a",      "Gas Tank" },
    { "prop_scr_door_01",       "Door" },
    { "prop_streetlight_01",    "Street Light" },
    { "prop_traffic_01a",       "Traffic Light" },
    { "prop_washer_01",         "Washer" },
    { "prop_washer_02",         "Washer 2" },
    { "prop_toilet_01a",        "Toilet" },
    { "prop_ld_ferris_wheel",   "Ferris Wheel" },
    { "prop_p_ferris_wheel_01", "Ferris Wheel 2" },
    { "prop_crib_01",           "Crib" },
    { "prop_dresser_01",        "Dresser" },
    { "prop_sink_01",           "Sink" },
    { "prop_sink_02",           "Sink 2" },
    { "prop_bathtub_01",        "Bathtub" },
    { "prop_tv_01",             "TV" },
    { "prop_tv_02",             "TV 2" },
    { "prop_tv_03",             "TV 3" },
    { "prop_monitor_01",        "Monitor" },
    { "prop_table_01",          "Table" },
    { "prop_table_02",          "Table 2" },
    { "prop_table_03",          "Table 3" },
    { "prop_vending_machine_01","Vending Machine" },
    { "prop_u_florist_01",      "Flower Pot" },
    { "prop_binbag_01a",        "Bin Bag" },
    { "prop_bench_01a",         "Bench" },
    { "prop_bench_05b",         "Bench 2" },
    { "prop_woodpile_01a",      "Wood Pile" },
    { "prop_gas_pump_1a",       "Gas Pump" },
    { "prop_gas_pump_1b",       "Gas Pump 2" },
    { "prop_veh_bike_01",       "Bike" },
    { "prop_veh_bicycle_01",    "Bicycle" },
    { "prop_shamal_01",         "Shamal" },
    { "prop_lift_01",           "Forklift" },
    { "prop_industrial_shelf_01","Industrial Shelf" },
}

---Large map-scale props (attach risks) merged from Menudo + Allstar.
LS.MapProps = {
    { "prop_ferris_wheel_01",     "Ferris Wheel" },
    { "p_ferris_wheel_amo_l",     "Ferris Wheel (Alt)" },
    { "p_ferris_wheel_amo_r",     "Ferris Wheel (Right)" },
    { "prop_ld_pier_01",          "Pier" },
    { "prop_ld_ferris_wheel",     "Del Perro Wheel" },
    { "prop_leisure_sign_01a",    "Sign" },
    { "prop_air_bigwheel_01",     "Big Wheel" },
    { "prop_rubbish_03b",         "Rubbish" },
    { "prop_rubbish_03c",         "Rubbish 2" },
    { "prop_gas_tank_02a",        "Gas Cylinder" },
}

---Force-emote sets. Menudo's list, kept intact.
LS.Emotes = {
    { "none",             "None" },
    { "handsup",          "Hands Up" },
    { "punch",            "Punch" },
    { "headbutt",         "Headbutt" },
    { "slap",             "Slap" },
    { "hug",              "Hug" },
    { "lapdance",         "Lap Dance" },
    { "horseDance",       "Horse Dance" },
    { "sillydance",       "Silly Dance" },
    { "glowstick",        "Glow Stick Dance" },
    { "baseballthrow",    "Baseball Throw" },
    { "twerk",            "Twerk" },
    { "pimpsysex",        "Pimp Sex" },
}

---Attachment components for the weapon upgrader (Amiwa's full set).
LS.Attachments = {
    { 0, "COMPONENT_AT_PI_FLSH" },
    { 1, "COMPONENT_AT_PI_SUPP" },
    { 2, "COMPONENT_AT_PI_BFL" },
    { 4, "COMPONENT_AT_AR_SCOOP" },
    { 6, "COMPONENT_AT_PI_SS" },
    { 7, "COMPONENT_AT_SCOPE_MACRO" },
    { 8, "COMPONENT_AT_AR_CANSKIN" },
    { 9, "COMPONENT_AT_AR_SKGILL" },
    { 11,"COMPONENT_AT_SCOPE_BIG" },
    { 12,"COMPONENT_AT_SCOPE_SMALL" },
    { 13,"COMPONENT_AT_AR_MUZZLE" },
    { 14,"COMPONENT_AT_SCOPE_MED" },
    { 15,"COMPONENT_AT_DRUM" },
    { 16,"COMPONENT_AT_PI_RAIL" },
    { 17,"COMPONENT_AT_SCOPE_BIG_MUSCLE" },
    { 18,"COMPONENT_AT_PIPEVIEW" },
    { 20,"COMPONENT_AT_AT_PI_FLSH" },
    { 21,"COMPONENT_AT_AT_PI_SUPP" },
    { 22,"COMPONENT_AT_AT_AR_MUZZLE" },
    { 23,"COMPONENT_AT_AT_SCOPE_BIG" },
    { 24,"COMPONENT_AT_AT_SCOPE_SMALL" },
    { 25,"COMPONENT_AT_AT_AR_FIN_GOLD" },
}

LS.VehicleMods = {
    { 11, "Spoiler" },
    { 12, "Hood" },
    { 13, "Side Skirt" },
    { 15, "Suspension" },
    { 16, "Exhaust" },
}

LS.PerformanceMods = {
    { 11, "Engine" },
    { 16, "Transmission" },
    { 15, "Brakes" },
    { 21, "Tyres" },
    { 13, "Armor" },
    { 18, "Turbo" },
}

---Menu accent presets for the Settings tab.
LS.Themes = {
    { "Red",      255, 0,   0 },
    { "Green",    0,   255, 0 },
    { "Blue",     0,   120, 255 },
    { "Yellow",   255, 220, 0 },
    { "Cyan",     0,   255, 255 },
    { "Orange",   255, 140, 0 },
    { "Purple",   160, 0,   255 },
    { "Pink",     255, 0,   150 },
    { "Brown",    140, 90,  50 },
    { "Gray",     160, 160, 160 },
    { "Black",    20,  20,  20 },
    { "White",    240, 240, 240 },
}

-- =============================================================
-- 7. MENU WINDOW
-- =============================================================

local W = CONFIG.window

LS.Window = MachoMenuTabbedWindow(
    W.title, W.x, W.y, W.w, W.h, W.tab
)

MachoMenuSetAccent(LS.Window, CONFIG.accent[1], CONFIG.accent[2], CONFIG.accent[3])

LS.BrandText = MachoMenuText(LS.Window, "   Lonestar " .. LS.Version)


--------------------------------------------------------------------------
-- >>> p3_self.lua
--------------------------------------------------------------------------


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


--------------------------------------------------------------------------
-- >>> p4_toggles.lua
--------------------------------------------------------------------------


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


--------------------------------------------------------------------------
-- >>> p5_move.lua
--------------------------------------------------------------------------


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


--------------------------------------------------------------------------
-- >>> p6_teleport_troll.lua
--------------------------------------------------------------------------


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


--------------------------------------------------------------------------
-- >>> p7_weapons.lua
--------------------------------------------------------------------------


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


--------------------------------------------------------------------------
-- >>> p8_vehicle.lua
--------------------------------------------------------------------------


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


--------------------------------------------------------------------------
-- >>> p9_server_exploit.lua
--------------------------------------------------------------------------


-- =============================================================
-- 19. TAB: SERVER
-- =============================================================

local SrvTab   = MachoMenuAddTab(LS.Window, "Server")
local SrvMain  = MachoMenuGroup(SrvTab, "Self & Vehicle", 150, 9, 500, 500)
local SrvExtra = MachoMenuGroup(SrvTab, "Jobs, Money & World", 500, 9, 800, 500)

MachoMenuText(SrvMain, "Server-Side Self")

local healthBox = MachoMenuInputbox(SrvMain, "Health Value", "Ex. 200")
local armourBox = MachoMenuInputbox(SrvMain, "Armour Value", "Ex. 100")

MachoMenuButton(SrvMain, "Revive Self (Server Side)", function()
    LS.Run([[
        local serverId = GetPlayerServerId(PlayerId())
        TriggerEvent('esx:onPlayerDied')
        TriggerEvent('esx_ambulancejob:revive', serverId)
        TriggerEvent('esx_ambulancejob:revivePlayer', serverId, false)
        TriggerEvent('QBCore:Player:Revive')
        TriggerEvent('QBCore:Command:ReviveMe')
        TriggerEvent('humane:revive')
        TriggerEvent('txcl:revive')
        TriggerEvent('core:revive')
    ]])
    LS.Ok("Revive events sent")
end)

MachoMenuButton(SrvMain, "Heal Self (Server Side)", function()
    LS.Run([[
        local serverId = GetPlayerServerId(PlayerId())
        TriggerEvent('esx:onPlayerHurt')
        TriggerEvent('esx_ambulancejob:revive', serverId)
        TriggerEvent('QBCore:Command:Heal')
        TriggerEvent('QBCore:Player:SetPlayerHealth', serverId, 200)
        TriggerEvent('humane:heal')
        TriggerEvent('hospital:heal')
    ]])
    LS.Ok("Heal events sent")
end)

MachoMenuButton(SrvMain, "Set Health (100-200)", function()
    local value = tonumber(LS.Trim(MachoMenuGetInputbox(healthBox)) or "") or 200
    LS.Run(([[
        local value = math.min(200, math.max(0, %d))
        SetEntityHealth(PlayerPedId(), value)
        if GetEntityMaxHealth(PlayerPedId()) < value then
            SetEntityMaxHealth(PlayerPedId(), value, value)
        end
        TriggerEvent('esx_ambulancejob:revive')
    ]]):format(value))
    LS.Ok(("Health set to %d"):format(value))
end)

MachoMenuButton(SrvMain, "Set Armour (0-100)", function()
    local value = tonumber(LS.Trim(MachoMenuGetInputbox(armourBox)) or "") or 100
    LS.Run(([[ SetPedArmour(PlayerPedId(), math.min(100, math.max(0, %d))) ]]):format(value))
    LS.Ok(("Armour set to %d"):format(value))
end)

MachoMenuCheckbox(SrvMain, "Noclip Money (No Cooldown)", function()
    LS.StartLoop("Lonestar.Money", [[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        TriggerEvent('esx:triggerClientAction', 'bankDeposit', 1000, function() end)
        TriggerEvent('QBCore:Command:AddMoney', 'cash', 1000)
    ]])
    LS.Ok("Money loop running - get in a vehicle")
end, function()
    LS.StopLoop("Lonestar.Money")
    LS.Info("Money loop stopped")
end)

MachoMenuText(SrvMain, "Vehicle Ownership")

MachoMenuButton(SrvMain, "Spawn Personal Vehicle", function()
    if not LS.Framework() then
        LS.Err("No framework detected - use the Vehicle tab instead")
        return
    end
    LS.WithTarget(function()
        LS.Run([[
            local hash = GetHashKey('dilettante')
            RequestModel(hash)
            local t = 0
            while not HasModelLoaded(hash) and t < 300 do Wait(10) t = t + 1 end
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local veh = CreateVehicle(hash, coords.x + 3.0, coords.y, coords.z, GetEntityHeading(ped), true, false)
            SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(veh), true)
            TriggerEvent('esx:spawnVehicle', GetDisplayNameFromVehicleModel(hash), NetworkGetNetworkIdFromEntity(veh))
            TriggerEvent('QBCore:Client:SpawnVehicle', hash, coords.x + 3.0, coords.y, coords.z, GetEntityHeading(ped))
            SetPedIntoVehicle(ped, veh, -1)
        ]])
        LS.Ok("Personal vehicle spawned")
    end)
end)

MachoMenuText(SrvExtra, "Job & Duty")

local jobBox = MachoMenuInputbox(SrvExtra, "Job Name", "Ex. police, ambulance")

MachoMenuButton(SrvExtra, "Set Job", function()
    local job = LS.Trim(MachoMenuGetInputbox(jobBox))
    if not job then LS.Err("Enter a job name") return end
    job = job:lower():gsub("[^%a_]", "")
    LS.Run(([[
        local job = '%s'
        if GetResourceState('es_extended') == 'started' then
            TriggerEvent('esx:setJob', job, 0)
        elseif GetResourceState('QBCore') == 'started' then
            TriggerEvent('QBCore:Client:OnJobUpdate', job, 0)
        elseif GetResourceState('txAdmin') == 'started' or GetResourceState('txcl') == 'started' then
            TriggerEvent('txcl:setJob', job, 0)
        end
    ]]):format(job))
    LS.Ok(("Job set to %s"):format(job))
end)

local gradeBox = MachoMenuInputbox(SrvExtra, "Grade", "Ex. 4")

MachoMenuButton(SrvExtra, "Set Job Grade", function()
    local job = LS.Trim(MachoMenuGetInputbox(jobBox))
    local grade = tonumber(LS.Trim(MachoMenuGetInputbox(gradeBox)) or "") or 0
    if not job then LS.Err("Enter a job name first") return end
    LS.Run(([[
        local job, grade = '%s', %d
        if GetResourceState('es_extended') == 'started' then
            TriggerEvent('esx:setJob', job, grade)
        elseif GetResourceState('QBCore') == 'started' then
            TriggerEvent('QBCore:Client:OnJobUpdate', job, grade)
        end
    ]]):format(job:lower():gsub("[^%a_]", ""), math.max(0, grade)))
    LS.Ok("Grade set")
end)

MachoMenuText(SrvExtra, "Money")

local moneyTypeIndex = 1
MachoMenuDropDown(SrvExtra, "Account", function(index)
    moneyTypeIndex = index
end, "None", "Cash", "Bank")

local moneyAmount = 1000
MachoMenuSlider(SrvExtra, "Amount", 1000000, 1, 1000, "", 100, function(value)
    moneyAmount = math.floor(value)
end)

MachoMenuButton(SrvExtra, "Add Money", function()
    if moneyTypeIndex < 2 then LS.Info("Pick an account first") return end
    local account = moneyTypeIndex == 2 and "cash" or "bank"
    LS.Run(([[
        local account, amount = '%s', %d
        TriggerEvent('esx:onPlayerMoneyChange', account, amount, 'Add')
        TriggerEvent('esx:giveMoney', account, amount)
        TriggerEvent('QBCore:Command:AddMoney', account, amount)
        TriggerEvent('QBCore:Player:AddMoney', account, amount, 'Lonestar')
    ]]):format(account, moneyAmount))
    LS.Ok(("Added %d"):format(moneyAmount))
end)

MachoMenuButton(SrvExtra, "Remove Money", function()
    if moneyTypeIndex < 2 then LS.Info("Pick an account first") return end
    local account = moneyTypeIndex == 2 and "cash" or "bank"
    LS.Run(([[
        local account, amount = '%s', %d
        TriggerEvent('esx:onPlayerMoneyChange', account, -amount, 'Remove')
        TriggerEvent('QBCore:Command:RemoveMoney', account, amount)
    ]]):format(account, moneyAmount))
    LS.Ok(("Removed %d"):format(moneyAmount))
end)

MachoMenuText(SrvExtra, "World")

MachoMenuButton(SrvExtra, "Change Weather", function()
    LS.Run([[
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        SetWeatherTypePersist(true)
        SetWeatherTypeNowAndPersist(math.random(0, 7))
    ]])
    LS.Ok("Weather randomised")
end)

MachoMenuButton(SrvExtra, "Clear Weather Override", function()
    LS.Run([[ ClearOverrideWeather() ClearWeatherTypePersist() ]])
    LS.Ok("Weather cleared")
end)

local timeIndex = 1
MachoMenuDropDown(SrvExtra, "Set Time", function(index)
    timeIndex = index
end, "None", "Midnight", "Morning", "Noon", "Afternoon", "Evening")

MachoMenuButton(SrvExtra, "Apply Time", function()
    if timeIndex < 2 then LS.Info("Pick a time first") return end
    local hours = ({ [2] = 0, [3] = 8, [4] = 12, [5] = 15, [6] = 20 })[timeIndex]
    LS.Run(([[ NetworkOverrideClockTime(%d, 0, 0) ]]):format(hours))
    LS.Ok(("Time set to %d:00"):format(hours))
end)

MachoMenuCheckbox(SrvExtra, "Freeze Time", function()
    LS.StartLoop("Lonestar.Time", [[
        local hour = 12
        NetworkOverrideClockTime(hour, 0, 0)
        Wait(0)
    ]])
    LS.Ok("Time frozen at 12:00")
end, function()
    LS.StopLoop("Lonestar.Time")
    LS.Run([[ ClearOverrideClock() ]])
    LS.Info("Time unfrozen")
end)

MachoMenuCheckbox(SrvExtra, "Blackout (Screen Modifier)", function()
    LS.StartLoop("Lonestar.Blackout", [[
        LONESTAR.SafeRunNative(SetTimecycleModifier, 'spectator5')
        LONESTAR.SafeRunNative(SetTimecycleModifierStrength, 1.0)
    ]])
    LS.Ok("Blackout enabled")
end, function()
    LS.StopLoop("Lonestar.Blackout")
    LS.Run([[ ClearTimecycleModifier() ]])
    LS.Info("Blackout disabled")
end)

-- =============================================================
-- 20. TAB: EXPLOIT
-- =============================================================

local ExpTab   = MachoMenuAddTab(LS.Window, "Exploit")
local ExpMain  = MachoMenuGroup(ExpTab, "Player Exploits", 150, 9, 500, 500)
local ExpMore  = MachoMenuGroup(ExpTab, "Vehicle & Weapon", 500, 9, 800, 500)

MachoMenuText(ExpMain, "Clip & Position")

MachoMenuButton(ExpMain, "Teleport Through Walls", function()
    -- Noclip to the facing waypoint, then hand control back to the game.
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        local rot = GetGameplayCamRot(2)
        local rad = math.rad(rot.z)
        local dir = vector3(-math.sin(rad), math.cos(rad), 0.0)
        local target = GetEntityCoords(ped) + dir * 6.0
        LONESTAR.TeleportTo(target.x, target.y, target.z, true)
    ]])
    LS.Ok("Stepped forward 6m through any geometry")
end)

MachoMenuButton(ExpMain, "Unfreeze & Un-Attach (Force)", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        LONESTAR.SafeRunNative(FreezeEntityPosition, ped, false)
        LONESTAR.SafeRunNative(DetachEntity, ped, true, true)
        LONESTAR.SafeRunNative(SetEntityCollision, ped, true, true)
        local c = GetEntityCoords(ped)
        LONESTAR.SafeRunNative(SetEntityCoords, ped, c.x, c.y, c.z + 0.5, false, false, false)
    ]])
    LS.Ok("Forced unfreeze")
end)

MachoMenuCheckbox(ExpMain, "Disable Interior Renders", function()
    LS.StartLoop("Lonestar.NoInteriors", [[
        for _, interior in ipairs({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }) do
            LONESTAR.SafeRunNative(SetInteriorPortalEnabled, interior, false)
        end
    ]])
    LS.Ok("Interiors disabled")
end, function()
    LS.StopLoop("Lonestar.NoInteriors")
    LS.Info("Interiors restored")
end)

MachoMenuCheckbox(ExpMain, "Block All Weapons", function()
    LS.StartLoop("Lonestar.NoWeapons", [[
        LONESTAR.SafeRunNative(DisableControlAction, 0, 24, true)
        LONESTAR.SafeRunNative(DisableControlAction, 0, 25, true)
        LONESTAR.SafeRunNative(DisableControlAction, 0, 26, true)
    ]])
    LS.Ok("Weapon controls disabled")
end, function()
    LS.StopLoop("Lonestar.NoWeapons")
    LS.Info("Weapon controls restored")
end)

MachoMenuText(ExpMore, "Vehicle Exploits")

MachoMenuCheckbox(ExpMore, "Bring Vehicle To You", function()
    LS.StartLoop("Lonestar.BringVeh", [[
        local ped = LONESTAR.SelfPed()
        if not ped or not IsPedInAnyVehicle(ped, false) then return end
        local veh = GetVehiclePedIsIn(ped, false)
        local target = GetEntityCoords(ped)
        local handle, other = FindFirstVehicle()
        repeat
            if other ~= veh and DoesEntityExist(other) then
                local c = GetEntityCoords(other)
                if #(c - target) < 120.0 then
                    NetworkRequestControlOfEntity(other)
                    SetEntityCoords(other, target.x + 5.0, target.y + 5.0, target.z, false, false, false, false)
                end
            end
        until not FindNextVehicle(handle)
        EndFindVehicle(handle)
    ]])
    LS.Ok("Nearby vehicles are being pulled to you")
end, function()
    LS.StopLoop("Lonestar.BringVeh")
    LS.Info("Stopped pulling vehicles")
end)

MachoMenuCheckbox(ExpMore, "Push All Vehicles Away", function()
    LS.StartLoop("Lonestar.PushVeh", [[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        local target = GetEntityCoords(ped)
        local mine = GetVehiclePedIsIn(ped, false)
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if veh ~= mine and DoesEntityExist(veh) then
                local c = GetEntityCoords(veh)
                local delta = c - target
                local dist = #delta
                if dist < 150.0 and dist > 1.0 then
                    NetworkRequestControlOfEntity(veh)
                    SetEntityVelocity(veh, (delta / dist).x * 25.0, (delta / dist).y * 25.0, 8.0)
                end
            end
        end
    ]])
    LS.Ok("Vehicles being pushed away")
end, function()
    LS.StopLoop("Lonestar.PushVeh")
    LS.Info("Stopped pushing vehicles")
end)

MachoMenuText(ExpMore, "Weapon Exploits")

local ammoBox = MachoMenuInputbox(ExpMore, "Ammo To Add", "Ex. 99999")

MachoMenuButton(ExpMore, "Add Ammo To Current Weapon", function()
    local ammo = tonumber(LS.Trim(MachoMenuGetInputbox(ammoBox)) or "") or 99999
    ammo = math.min(math.max(ammo, 0), 1000000)
    LS.Run(([[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        local weapon = GetSelectedPedWeapon(ped)
        SetPedAmmo(ped, weapon, %d)
    ]]):format(ammo))
    LS.Ok(("Ammo set to %d"):format(ammo))
end)

MachoMenuCheckbox(ExpMore, "Free Ammo Refill", function()
    LS.StartLoop("Lonestar.FreeAmmo", [[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        local weapon = GetSelectedPedWeapon(ped)
        SetPedAmmo(ped, weapon, 999)
    ]])
    LS.Ok("Free ammo refill enabled")
end, function()
    LS.StopLoop("Lonestar.FreeAmmo")
    LS.Info("Free ammo refill disabled")
end)

MachoMenuButton(ExpMore, "Give Weapons To Target", function()
    LS.WithTarget(function(sid)
        LS.Run(([[
            local ped = LONESTAR.PedFromServerId(%d)
            if not ped then return end
            for _, weapon in ipairs({
                'WEAPON_PISTOL', 'WEAPON_SMG', 'WEAPON_CARBINERIFLE',
                'WEAPON_SHOTGUN', 'WEAPON_SNIPERRIFLE', 'WEAPON_RPG' }) do
                GiveWeaponToPed(ped, GetHashKey(weapon), 999, 0, true)
            end
        ]]):format(sid))
        LS.Ok("Weapons given to target")
    end)
end)

MachoMenuText(ExpMore, "Entity Utilities")

MachoMenuButton(ExpMore, "Delete All Vehicles In Range", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        local target = GetEntityCoords(ped)
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(veh) and #(GetEntityCoords(veh) - target) < 200.0 then
                NetworkRequestControlOfEntity(veh)
                DeleteEntity(veh)
            end
        end
    ]])
    LS.Ok("Nearby vehicles deleted")
end)

MachoMenuButton(ExpMore, "Delete All Props In Range", function()
    LS.Run([[
        local ped = LONESTAR.SelfPed()
        if not ped then return end
        local target = GetEntityCoords(ped)
        for _, obj in ipairs(GetGamePool('CObject')) do
            if DoesEntityExist(obj) and #(GetEntityCoords(obj) - target) < 100.0 then
                DeleteEntity(obj)
            end
        end
    ]])
    LS.Ok("Nearby props deleted")
end)


--------------------------------------------------------------------------
-- >>> p10_nuke_settings.lua
--------------------------------------------------------------------------


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

