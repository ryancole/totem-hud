local ADDON_NAME, ns = ...

-- Shaman only: on any other class the addon loads its saved variables and
-- then does nothing, so it can sit in the addon list on every character
-- without cost.

local opts -- TotemHudDB.options (account-wide)
local isShaman = false
local TOTEMIC_CALL = 36936 -- spell ID; recalls every totem at once

-------------------------------------------------------------------------------
-- SavedVariables
-------------------------------------------------------------------------------
-- Everything is account-wide: a HUD position and a couple of display
-- flags don't vary between shamans.
--
-- TotemHudDB = {
--   version = 1,
--   options = { ... },
-- }

ns.optionDefaults = {
    locked = true,          -- HUD can't be dragged; unlocked, it shows
                            -- sample rows so it can be positioned
    hideWhenEmpty = true,   -- hide the whole HUD while no totem is down;
                            -- off, it stays up with four dimmed rows
    showBorder = true,      -- draw the tooltip-style border around the HUD
    showBarFill = true,     -- color each bar by its element; off leaves
                            -- just icon, name, and time on the panel
    showBarBackground = true, -- (with showBarFill) also tint the drained
                              -- part dimly, so the whole bar is colored
    hideBlizzardTotems = false, -- hide the default totem timers under
                                -- the player frame
    expireSound = true,     -- play the "tote" clip once as a totem
                            -- crosses under the warning time
    deathSound = true,      -- play it too when a totem is killed before
                            -- reaching the warning time
    fontSize = 7,           -- bar text size, in points
    framePoint = "CENTER",  -- HUD anchor, saved after each drag
    frameRelPoint = "CENTER",
    frameX = 0,
    frameY = -220,
}

local function InitDB()
    TotemHudDB = TotemHudDB or { version = 1 }
    TotemHudDB.options = TotemHudDB.options or {}
    opts = TotemHudDB.options
    for k, v in next, ns.optionDefaults do
        if opts[k] == nil then
            opts[k] = v
        end
    end
    -- Options since dropped: rows for empty slots are now always shown,
    -- and the group-only display (v0.3.0) went with hideWhenEmpty
    opts.showEmptySlots = nil
    opts.groupOnly = nil
end

-------------------------------------------------------------------------------
-- Totems
-------------------------------------------------------------------------------

-- The client's totem slots, in the order the default totem bar shows them
-- (earth first, then fire, water, air). Colors are per element and tint
-- each totem's bar; the sample icon stands in while the HUD is unlocked.
ns.slots = {
    { slot = 2, element = "Earth", color = { 0.35, 0.65, 0.20 },
        sampleIcon = "Interface\\Icons\\Spell_Nature_StrengthOfEarthTotem02" },
    { slot = 1, element = "Fire",  color = { 0.90, 0.35, 0.15 },
        sampleIcon = "Interface\\Icons\\Spell_Fire_SearingTotem" },
    { slot = 3, element = "Water", color = { 0.20, 0.50, 0.90 },
        sampleIcon = "Interface\\Icons\\Spell_Nature_ManaRegenTotem" },
    { slot = 4, element = "Air",   color = { 0.60, 0.45, 0.90 },
        sampleIcon = "Interface\\Icons\\Spell_Nature_Windfury" },
}

-- Totem names carry their rank ("Mana Spring Totem IV"); the list is
-- short on room and the rank says nothing about the timer
local function StripRank(name)
    return (name:gsub("%s+[IVXL]+$", ""))
end

-- What is down right now, one entry per ns.slots row that has a totem:
-- { def, name, icon, startTime, duration }. Order follows ns.slots.
function ns.ScanTotems()
    local totems = {}
    for _, def in ipairs(ns.slots) do
        local have, name, startTime, duration, icon = GetTotemInfo(def.slot)
        if have and name and name ~= "" then
            totems[#totems + 1] = {
                def = def,
                name = StripRank(name),
                icon = icon,
                startTime = startTime,
                duration = duration,
            }
        end
    end
    return totems
end

-- Seconds a totem has left. Computed from its start time and duration so
-- the bars run smoothly; GetTotemTimeLeft is whole seconds and serves as a
-- backstop when the start time is missing.
function ns.TimeLeft(totem)
    if totem.startTime and totem.duration and totem.duration > 0 then
        return totem.startTime + totem.duration - GetTime()
    end
    return GetTotemTimeLeft(totem.def.slot)
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_TOTEM_UPDATE" then
        ns.UpdateHud()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Totems don't survive a loading screen, but the slot data does
        -- get refreshed here, so re-read it
        ns.ForgetTotems()
        ns.UpdateHud()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        if spellID == TOTEMIC_CALL then
            ns.NoteRecall()
        end
    elseif event == "ADDON_LOADED" then
        if ... == ADDON_NAME then
            InitDB()
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        isShaman = class == "SHAMAN"
        ns.isShaman = isShaman
        if isShaman then
            ns.SetupHud()
            ns.SetupOptions()
            ns.ApplyBlizzardTotems()
            self:RegisterEvent("PLAYER_TOTEM_UPDATE")
            self:RegisterEvent("PLAYER_ENTERING_WORLD")
            -- To tell a Totemic Call from totems being killed
            self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        end
    end
end)

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------

local function Print(msg)
    print("|cff33ff99TotemHud|r: " .. msg)
end

SLASH_TOTEMHUD1 = "/totemhud"
SLASH_TOTEMHUD2 = "/th"
SlashCmdList.TOTEMHUD = function(msg)
    if not isShaman then
        return Print("only shamans have totems; nothing to show on this character.")
    end
    local cmd = strlower(strtrim(msg or ""))
    if cmd == "lock" or cmd == "unlock" then
        opts.locked = cmd == "lock"
        ns.RefreshHud()
        Print(opts.locked and "HUD locked."
            or "HUD unlocked; drag it to move it. It shows sample totems until you lock it again.")
    elseif cmd == "reset" then
        for _, k in ipairs({ "framePoint", "frameRelPoint", "frameX", "frameY" }) do
            opts[k] = ns.optionDefaults[k]
        end
        ns.RefreshHud()
        Print("HUD position reset.")
    elseif cmd == "list" then
        local totems = ns.ScanTotems()
        if #totems == 0 then
            return Print("no totems down.")
        end
        Print("totems down:")
        for _, totem in ipairs(totems) do
            print(("  %s: %s (%s left)"):format(totem.def.element, totem.name,
                ns.FormatTime(ns.TimeLeft(totem))))
        end
    elseif cmd == "options" or cmd == "config" or cmd == "" then
        ns.OpenOptions()
    else
        print("|cff33ff99TotemHud|r commands:")
        print("  /th lock — lock the HUD in place")
        print("  /th unlock — unlock the HUD so it can be dragged")
        print("  /th reset — move the HUD back to its default spot")
        print("  /th list — print your totems and their remaining time")
        print("  /th options — open the settings panel")
    end
end
