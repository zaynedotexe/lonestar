
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
