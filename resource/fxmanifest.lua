fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'lonestar'
author 'lonestar'
description 'Lonestar - combined Macho menu (Allstar DUI UI / Allstar natives / Amiwa features)'
version '1.1.0'

-- REQUIRED: the MachoMenuV2 base library.
--
-- The menu renders in a browser page (GitHub Pages) through the library's DUI
-- API, exactly like Allstar. It no longer uses the built-in widget renderer,
-- so these functions are supplied by this resource itself:
--   MachoMenuTabbedWindow, MachoMenuAddTab, MachoMenuGroup, MachoMenuButton,
--   MachoMenuCheckbox, MachoMenuDropDown, MachoMenuSlider, MachoMenuInputbox,
--   MachoMenuText, MachoMenuSmallText, MachoMenuKeybind, MachoMenuSetKeybind,
--   MachoMenuSetText, MachoMenuGetInputbox, MachoMenuGetSelectedPlayer,
--   MachoMenuSetAccent, MachoMenuNotification, MachoMenuDestroy
--
-- These still come from the base library:
--   MachoCreateDui, MachoShowDui, MachoHideDui, MachoSendDuiMessage,
--   MachoOnKeyDown, MachoOnKeyUp, MachoResourceInjectable,
--   MachoInjectResourceRaw, MachoInjectResourceScriptOverride
--
-- Without that resource this one will error on load.
dependency 'macho_menuv2'

client_scripts {
    'client_script.lua',
}
