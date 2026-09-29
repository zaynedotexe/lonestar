# Lonestar

FiveM admin menu. The UI is served from GitHub Pages and rendered in a browser
page through the MachoMenuV2 DUI API, the same architecture Allstar uses. All
navigation, the input buffer and every widget interaction are handled in Lua;
this page is a pure renderer.

**Live page:** <https://zaynedotexe.github.io/lonestar/>

## Repo layout

```
index.html      the page MachoCreateDui loads
style.css       appearance; --accent is overridden at runtime
app.js          renderer: tree -> DOM, listens for state from Lua

resource/       the FiveM resource
  fxmanifest.lua
  client_script.lua     merged build, this is what you install
  RESOURCE-README.md    full install + config notes

src/            editable parts, concatenated by build.ps1
  p1_core.lua           config, notify, safe-native packer
  p1b_ui.lua            the local MachoMenu* implementation + DUI bridge
  p2_data.lua           shared data
  p3_self.lua           Player List, Self
  p4_toggles.lua        tracked toggle engine
  p5_move.lua           noclip, freecam, slide
  p6_teleport_troll.lua Teleport, Troll
  p7_weapons.lua        Weapons
  p8_vehicle.lua        Vehicle, Upgrades
  p9_server_exploit.lua Server, Exploit
  p10_nuke_settings.lua Nuke, Settings, boot
  build.ps1
```

`p1b_ui.lua` must stay second in the order. It defines the local `MachoMenu*`
functions that every widget part calls, so it has to be in place before
`p2_data.lua` builds the window.

## Install on a server

1. Copy `resource/` to your server as the `lonestar` resource.
2. In `server.cfg`, in this order:

   ```
   ensure macho_menuv2
   ensure lonestar
   ```

3. Restart, or `restart lonestar`. Press `INSERT`.

`macho_menuv2` is a licensed, key-gated commercial library and a hard
dependency — the resource will not start without it. It supplies the DUI and
injection functions (`MachoCreateDui`, `MachoShowDui`, `MachoHideDui`,
`MachoSendDuiMessage`, `MachoOnKeyDown`, `MachoOnKeyUp`, `MachoResourceInjectable`,
`MachoInjectResourceRaw`, `MachoInjectResourceScriptOverride`). The entire
widget API is implemented in `p1b_ui.lua` and needs nothing from it. There is no
legitimate free copy of the library; the "free" releases floating around this
ecosystem are a common malware vector.

See `resource/RESOURCE-README.md` for the controls table, the server-compat
matrix and troubleshooting.

## Controls

| Key | Action |
|---|---|
| `INSERT` | Open / close |
| `UP` / `DOWN` | Groups, then items |
| `PAGE UP` / `PAGE DOWN` | Switch tab |
| `ENTER` | Select, confirm input, confirm dropdown |
| `BACKSPACE` | Back one level |
| `LEFT` / `RIGHT` | Adjust slider |

## Changing the look

Edit `style.css` and push. The accent is a CSS variable, so `--accent` is
replaced at runtime by the accent setting in the menu. The page is public, so
anyone can read its source — don't put anything private in it.

## Rebuilding the client script

```
powershell -ExecutionPolicy Bypass -File src\build.ps1
```

Update the paths at the top of `build.ps1` to match your machine, then commit
the rebuilt `resource/client_script.lua`.
