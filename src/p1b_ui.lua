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
