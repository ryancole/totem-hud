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
    playSound = true,       -- play the "totem" clip once as a totem goes
                            -- away, whether it ran out or was killed,
                            -- and once as the player leaves one's range
    fontSize = 7,           -- bar text size, in points
    alertSide = "LEFT",     -- which side of the HUD the "!" hangs off;
                            -- "LEFT" or "RIGHT"
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
    -- the group-only display (v0.3.0) went with hideWhenEmpty, the
    -- separate expiry and death sounds became playSound, and the
    -- out-of-range alert is now always on
    opts.showEmptySlots = nil
    opts.groupOnly = nil
    opts.expireSound = nil
    opts.deathSound = nil
    opts.rangeAlert = nil
    -- A range record table lived here briefly during development
    TotemHudDB.range = nil
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

-- Range, by way of buffs. A totem can't be asked where it is, and the
-- game hides positions in instances, but a buff totem keeps its buff on
-- everyone in range, the shaman included; the buff leaving the player
-- means they have walked out of range. The buff carries the totem's
-- own icon, so that is how the two are matched.
--
-- The totems that give a buff, by name as ScanTotems reports it (rank
-- stripped). Searing, Magma, Fire Nova, Earthbind, Tremor, Stoneclaw,
-- Grounding, Sentry, the cleansing totems, and the elementals give
-- none, so they are never judged.
ns.buffTotems = {
    ["Strength of Earth Totem"] = true,
    ["Stoneskin Totem"] = true,
    ["Flametongue Totem"] = true,
    ["Frost Resistance Totem"] = true,
    ["Totem of Wrath"] = true,
    ["Healing Stream Totem"] = true,
    ["Mana Spring Totem"] = true,
    ["Mana Tide Totem"] = true,
    ["Fire Resistance Totem"] = true,
    ["Windfury Totem"] = true,
    ["Grace of Air Totem"] = true,
    ["Wrath of Air Totem"] = true,
    ["Tranquil Air Totem"] = true,
    ["Windwall Totem"] = true,
    ["Nature Resistance Totem"] = true,
}

-- buffs is one record per slot: { startTime, had, missingSince, out }.
-- had is set once the buff has been seen on the player; missingSince
-- is when it was last found gone, so a short gap (an aura refresh, or
-- the buff and totem going in separate updates as it expires) doesn't
-- alert. A buff found gone before it was ever seen (the totem was down
-- before the addon looked: a /reload)
-- counts as out at once, but quietly: the cue marks the moment of
-- leaving range, which was not witnessed.
local buffs = {}
local BUFF_GRACE = 0.5 -- seconds the buff must be gone before it counts
-- A totem this young isn't judged: its buff is still landing
local SETTLING = 2
-- The buff goes with the totem as it runs out, and the two updates may
-- not arrive together; that last moment is the expiry alert's, not this
local ENDING = 1.5

-- The player's buffs, by icon; refreshed on UNIT_AURA
local buffIcons = {}
function ns.ScanBuffs()
    wipe(buffIcons)
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end
        buffIcons[aura.icon] = true
    end
end

-- What is down right now, one entry per ns.slots row that has a totem:
-- { def, name, icon, startTime, duration, buff }. Order follows ns.slots.
function ns.ScanTotems()
    local totems = {}
    for _, def in ipairs(ns.slots) do
        local have, name, startTime, duration, icon = GetTotemInfo(def.slot)
        if have and name and name ~= "" then
            local buff = buffs[def.slot]
            if not buff or buff.startTime ~= startTime then
                buff = { startTime = startTime }
                buffs[def.slot] = buff
            end
            totems[#totems + 1] = {
                def = def,
                name = StripRank(name),
                icon = icon,
                startTime = startTime,
                duration = duration,
                buff = buff,
            }
        else
            buffs[def.slot] = nil
        end
    end
    return totems
end

-- Whether the player is out of a totem's range, judged by its buff (see
-- `buffs`): true when the buff is not on the player (and, if it was
-- before, has been gone for BUFF_GRACE), false when it is on them or
-- has only just gone, nil when there is nothing to judge (the totem
-- gives no buff, is too young or about to run out, or the player is
-- dead and has no buffs at all). The second value is true on the one
-- call that sees the player leave range, for a one-time cue.
function ns.OutOfRange(totem)
    local buff = totem.buff
    if not buff or not ns.buffTotems[totem.name] then
        return nil
    end
    if buffIcons[totem.icon] then
        buff.had = true
        buff.missingSince = nil
        buff.out = nil
        return false
    end
    local now = GetTime()
    if now - (totem.startTime or now) < SETTLING
        or UnitIsDeadOrGhost("player") or ns.TimeLeft(totem) < ENDING then
        return nil
    end
    if not buff.had then
        buff.out = true
        return true
    end
    buff.missingSince = buff.missingSince or now
    if now - buff.missingSince < BUFF_GRACE then
        return false
    end
    local first = not buff.out
    buff.out = true
    return true, first
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
    if event == "PLAYER_TOTEM_UPDATE"
        or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        ns.UpdateHud()
    elseif event == "UNIT_AURA" then
        -- The HUD's tick picks the change up; nothing to redraw here
        ns.ScanBuffs()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Totems don't survive a loading screen, but the slot data does
        -- get refreshed here, so re-read it
        ns.ForgetTotems()
        ns.ScanBuffs()
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
            ns.ScanBuffs()
            ns.SetupHud()
            ns.SetupOptions()
            ns.ApplyBlizzardTotems()
            self:RegisterEvent("PLAYER_TOTEM_UPDATE")
            -- For the buff-based range check
            self:RegisterUnitEvent("UNIT_AURA", "player")
            self:RegisterEvent("PLAYER_ENTERING_WORLD")
            -- Combat start and end, for the "!" on empty rows
            self:RegisterEvent("PLAYER_REGEN_DISABLED")
            self:RegisterEvent("PLAYER_REGEN_ENABLED")
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
            local range = ns.OutOfRange(totem) and ", out of range" or ""
            print(("  %s: %s (%s left%s)"):format(totem.def.element, totem.name,
                ns.FormatTime(ns.TimeLeft(totem)), range))
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
