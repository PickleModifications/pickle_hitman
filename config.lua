Config = {}

Config.Debug = true

Config.Language = "en" -- Language to use.

Config.RenderDistance = 20.0 -- Scenario display Radius.

Config.InteractDistance = 1.5 -- Interact Radius

Config.UseTarget = true -- When set to true, it'll use targeting instead of key-presses to interact.

Config.NoModelTargeting = true -- When set to true and using Target, it'll spawn a small invisible prop so you can third-eye when no entity is defined.

Config.InventoryLimit = false -- If using ESX 1.1, this must be on if using a limit-based inventory.

Config.PhoneboxModels = {
    "p_phonebox_01b_s",
    "prop_phonebox_01c",
    "sf_prop_sf_phonebox_01b_s",
    "ch_chint02_phonebox001",
    "prop_phonebox_01a",
    "p_phonebox_02_s",
    "prop_phonebox_01b",
    "prop_phonebox_04",
    "prop_phonebox_03",
    "prop_phonebox_02",
}

Config.PhoneboxLocations = {
    -- Not needed, but if you want to set the coords for a phonebox somewhere, you can add it here.
    -- { coords = vector3(0.0, 0.0, 0.0), heading = 0.0 },
}

Config.Burial = {
    blip = {
        enabled = true,
        label = "Hitman: Burial Site",
        category = 1,
        sprite = 119,
        color = 1,
        scale = 0.8,
    },
    locations = {
        { coords = vector3(974.6524, -2167.1689, 29.4616), heading = 356.4430 }, -- Acid
        { coords = vector3(1686.9285, 39.1528, 161.7674), heading = 186.5351 }, -- Dock
        { coords = vector3(-279.2317, 2842.7998, 54.0298), heading = 330.9481 }, -- Grave
        { coords = vector3(-85.6894, 6233.7188, 31.0911), heading = 122.2676 }, -- Chicken
        { coords = vector3(-552.1412, 5328.3335, 73.6392), heading = 339.5307 }, -- Sawmill
    },
}

Config.HitPermissions = {
    placeHits = function(source, hit, processing)
        -- You can code your own permission system here, or use the example provided.
        -- Must return true to pass the check, return false to deny.
        -- The processing variable is used to determine if the function is being called to check or to process.
        local challengeCoins = Inventory.GetItemCount(source, "challengecoin")
        if challengeCoins < 1 then
            if processing then
                ShowNotification(source, "You need a challenge coin to place a hit.")
            end
            return false
        end
        if processing then
            Inventory.RemoveItem(source, "challengecoin", 1) -- This will remove the coin from the player when they place a hit.
        end
        return true
    end,
    acceptHits = function(source, hit, processing)
        -- You can code your own permission system here, or use the example provided.
        -- Must return true to pass the check, return false to deny.
        -- The processing variable is used to determine if the function is being called to check or to process.
        return true
    end,
    cancelHits = function(source, hit, processing)
        -- You can code your own permission system here, or use the example provided.
        -- Must return true to pass the check, return false to deny.
        -- The processing variable is used to determine if the function is being called to check or to process.
        local identifier = GetIdentifier(source)
        if hit and hit.issuer and identifier == hit.issuer then
            if processing then
                Inventory.AddItem(source, "challengecoin", 1) -- This will return the coin to the player when they remove the hit.
                AddMoney(source, hit.reward) -- This will return the reward to the player when they remove the hit.
            end
            return true
        elseif CheckPermission(source, { groups = { "admin", "god" }}) then
            return true
        else
            if processing then
                ShowNotification(source, "You cannot remove this hit.")
            end
            return false
        end
    end,
}

Config.HitCooldown = 10 -- Cooldown in seconds for accepting a hit.

Config.DefaultPosition = {x = 1510, y = 10} -- Default position for the Overlay UI.

Config.PlayerHits = {
    blip = {
        enabled = true,
        refreshTime = 5, -- Every x seconds, refresh the area position of the target.
        labelPrefix = "Hit Target:", -- Prefix for the blip label. Hit Target: NAME_HERE
        sprite = 378,
        color = 1,
        scale = 0.8,
        radius = { color = 1, alpha = 127, size = 400.0 }
    }
}

Config.NPCTargets = {
    enabled = true,
    generateCooldown = 30, -- Cooldown in seconds for generating a new NPC hit (this is skipped during server start).
    maxNPCTargets = 10, -- Maximum amount of NPC hit targets that can be available at once.
    rewardRange = {1000, 5000}, -- Minimum and maximum reward for NPC hit targets.
    maxDistance = 200.0, -- Maximum distance from the player a spawned NPC hit can be before it fails the mission.
    maxDrivingTime = 180, -- Maximum time in seconds the NPC hit can be driving before it stops the car to get out and run / shoot.
    maxStopTime = 10, -- Time in seconds the NPC hit can be stopped for before it gets out and runs / shoots.
    blip = {
        labelPrefix = "Hit Contract:", -- Prefix for the blip label. Hit: NAME_HERE
        sprite = 378,
        color = 1,
        scale = 0.8,
        rngOffset = {0, 100}, -- Range for how far the blip can be offset from the center of the radius. Good for making people search for the target.
        radius = { color = 1, alpha = 127, size = 100.0}
    },
    locations = {
        { coords = vector3(-216.7631, -1970.6584, 27.7558), heading = 294.3834 },
        { coords = vector3(198.7951, -1010.8240, 29.3041), heading = 257.8059 },
        { coords = vector3(1108.8599, -630.8035, 56.8160), heading = 6.7750 },
        { coords = vector3(295.7472, 182.7069, 104.2432), heading = 216.3967 },
        { coords = vector3(-613.1423, -112.2452, 40.0083), heading = 194.8465 },
    },
    vehicles = { `adder`, `blista`, `asea`, `emperor`, `fugitive` }, -- Vehicles that can be spawned for NPC hit targets. Use `model_name` for models.
    weapons = { `WEAPON_PISTOL`, `WEAPON_KNIFE` }, -- Weapons that can be used by NPC hit targets. Use `WEAPON_NAME` for weapons.
    chaseScenarioChances = { -- Chances for each scenario to happen after a chase. Do not delete any of these entries.
        ["fleeFoot"] = 0.6, -- Chance of the NPC fleeing on foot. 0.4 means 40% chance.
        ["meleeAttack"] = 0.3, -- Chance of the NPC fleeing in a vehicle. 0.6 means 60% chance.
        ["firearmAttack"] = 0.1, -- Chance of the NPC fleeing in a vehicle. 0.6 means 60% chance.
    },
    -- For peds, please ONLY USE "", as we need to use the ped model name to find the appropriate image name.
    characters = {
        male = {
            peds = {"g_m_y_pologoon_02", "g_m_m_armgoon_01", "g_m_y_lost_03" },
            firstnames = {"John", "Michael", "David", "James", "Robert", "William", "Joseph", "Charles", "Thomas", "Christopher", "Daniel", "Matthew", "Anthony", "Mark", "Donald", "Steven", "Paul", "Andrew", "Joshua", "Kenneth"},
        },
        female = {
            peds = {"g_f_y_vagos_01", "g_f_y_families_01", "g_f_y_ballas_01" },
            firstnames = {"Mary", "Patricia", "Jennifer", "Linda", "Elizabeth", "Barbara", "Susan", "Jessica", "Sarah", "Karen", "Nancy", "Margaret", "Lisa", "Betty", "Dorothy", "Sandra", "Ashley", "Kimberly", "Donna", "Emily"},
        },
        lastnames = {"Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin"},
    },
    reasons = {
        "My partner cheated on me, lets see if they can cheat death.", 
        "They took my fentanyl, overdose them with bullets.", 
        "They stole my PostOP package, now take their life.", 
        "They cut me in line to see a movie, cut them out of the script.", 
        "They stole my lunch money, get it done.", 
        "They owe me money, make them pay the final price.", 
        "They looked at me funny, we don't do that around here.", 
        "They're a snitch, and snitches get stitches.", 
        "They're a rival gang member, gotta take out the opposition."
    },
    -- Combat scenario chances:
    firearmAttack = 0.1, -- Chance of the NPC using a firearm attack. 0.1 means 10% chance.
    meleeAttack = 0.1, -- Chance of the NPC using a melee attack. 0.1 means 10% chance.
    fleeVehicle = 0.4, -- Chance of the NPC fleeing in a vehicle. 0.4 means 40% chance.
    fleeFoot = 0.4, -- Chance of the NPC fleeing on foot. 0.4 means 40% chance.
}
