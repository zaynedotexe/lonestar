# Lonestar

Combined FiveM menu. **Allstar DUI UI**, Allstar native handling, Amiwa features.

## Install

1. Publish the UI to GitHub Pages (see below) and set the URL in `client_script.lua`.
2. Copy the whole `lonestar` folder into your server's `resources/` directory.
3. Add this to your `server.cfg` **before** other scripts that may inject into it:

   ```
   ensure macho_menuv2
   ensure lonestar
   ```

4. Restart the server (or `restart lonestar` from the txAdmin console).
5. Press `INSERT` in game.

## Step 1: publish the UI to GitHub Pages

The menu renders in a browser page, the same way Allstar does. The three files
in `_nui/` are that page.

1. Create a repository named `lonestar` (it must be **public** for Pages).
2. Upload `index.html`, `style.css` and `app.js` to the repository root.
3. In the repo: **Settings → Pages → Source: Deploy from a branch**,
   branch `main`, folder `/ (root)`, then Save.
4. Wait for the green check, then set this in `client_script.lua` near the top
   of the `CONFIG` table:

   ```lua
   ui = {
       url = "https://YOUR-USERNAME.github.io/lonestar/",
   }
   ```

   Your address must end in `/`.

If the URL is wrong the resource logs `CONFIG.ui.url is not set` or
`MachoCreateDui failed` and the menu will not open. Everything else works
offline; only the page itself is fetched over HTTPS.

Editing the look? Change `_nui/style.css` — the accent colour is a CSS variable
(`--accent`) and is overridden at runtime by the accent setting in the menu.

## Required dependency: `macho_menuv2`

This resource will NOT start without the MachoMenuV2 base library.
It is a hard `dependency` in `fxmanifest.lua`, so if it is missing FiveM
refuses to start the resource and logs:

```
Unable to start resource lonestar as it depends on resource
`macho_menuv2` which is not present or not started
```

That error is the intended, self-documenting failure mode.

Still required from the library:

| Function | Used for |
|---|---|
| `MachoCreateDui` / `MachoShowDui` / `MachoHideDui` / `MachoSendDuiMessage` | Showing the page and pushing state into it |
| `MachoOnKeyDown` / `MachoOnKeyUp` | Keyboard navigation and the text input buffer |
| `MachoResourceInjectable` | Deciding whether a resource can be injected into |
| `MachoInjectResourceRaw` / `MachoInjectResourceScriptOverride` | The safe-native packer |

No longer required from the library — this resource implements the whole
widget API itself and draws it in the page: `MachoMenuTabbedWindow`,
`MachoMenuAddTab`, `MachoMenuGroup`, `MachoMenuButton`, `MachoMenuCheckbox`,
`MachoMenuDropDown`, `MachoMenuSlider`, `MachoMenuInputbox`, `MachoMenuText`,
`MachoMenuSmallText`, `MachoMenuKeybind`, `MachoMenuSetKeybind`,
`MachoMenuSetText`, `MachoMenuGetInputbox`, `MachoMenuGetSelectedPlayer`,
`MachoMenuSetAccent`, `MachoMenuNotification`, `MachoMenuDestroy`.

The base library is still licensed, key-gated software. Buy it from the seller
who provided your menu scripts; there is no legitimate free copy, and "free"
releases of this ecosystem are a common malware vector.

## Controls

| Key | Action |
|---|---|
| `INSERT` | Open / close the menu |
| `UP` / `DOWN` | Move between groups, then between items |
| `PAGE UP` / `PAGE DOWN` | Switch tab |
| `ENTER` | Select; also confirms input and dropdowns |
| `BACKSPACE` | Back out one level |
| `LEFT` / `RIGHT` | Adjust a slider |

## Verified against this server

Checked against the resource set in this folder:

| Found on server | Effect on Lonestar |
|---|---|
| `rryban_secure` | Injection uses the simple passthrough branch instead of the safe-native packer |
| `ElectronAC` | ElectronAC noclip strategy is auto-selected |
| `es_extended` (ESX) | Framework detection resolves to ESX; QBCore paths stay dormant |
| `jg-mechanic` | Vehicle spawn and Upgrades tuning events use this path |
| `ox_fuel` | Unlimited fuel uses the `ox_fuel` event |
| `mm_radio` | Radio frequency controls are live |
| `monitor` (txAdmin 8.1.1) | Nothing required |
| `scully_emotemenu` | Force-emote event names line up |

## Layout

```
lonestar/
  fxmanifest.lua
  client_script.lua     merged build
  _nui/                 the GitHub Pages source
    index.html
    style.css
    app.js
```

`client_script.lua` is the merged build. If you want to edit it, the readable
parts live in `Lowbat\lua\_build\` and are concatenated in this order by
`_build\build.ps1`:

```
p1_core.lua  ->  p1b_ui.lua  ->  p2_data.lua  ->  p3_self.lua
p4_toggles.lua  ->  p5_move.lua  ->  p6_teleport_troll.lua
p7_weapons.lua  ->  p8_vehicle.lua  ->  p9_server_exploit.lua
p10_nuke_settings.lua
```

`p1b_ui.lua` must stay second: it defines the local `MachoMenu*` functions that
the widget parts call. Run `build.ps1` after any edit — it rebuilds
`Lonestar.lua` and copies both the script and `_nui` to the server folder.
