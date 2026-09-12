local ADDON_NAME, ns = ...

-- The HUD: a small movable panel with one bar per totem down, in the
-- default totem bar's element order. Each bar is tinted for its element
-- and drains as the totem runs out, with the totem's icon and name at
-- the left and the time left at the right. It is always four rows, a
-- dimmed one for each element with nothing down, so it never changes
-- size; an option hides the whole panel while no totem is down.
-- Unlocking it (it starts locked) shows a sample bar per element so it
-- can be seen and dragged into place.
--
-- Rows are plain frames, so they may be shown, hidden, and rearranged
-- in combat: the HUD needs no secure frames.

local WIDTH = 180
local MIN_ROW_HEIGHT = 18 -- rows grow past this to fit a large font
local ROW_GAP = 2
local PAD = 6
local INSET = 4 -- time text from the bar's right edge
local TITLE_HEIGHT = 14
local WARN_SECONDS = 10 -- time text turns red and the alert icon shows below this
-- The 2D quest "!" from the gossip window, hung off the panel's left
-- edge (or right, per option) beside a row while its totem is about to
-- expire or, in combat, missing. Other flat icons the client ships that would read
-- as "out of range" in its place: Interface\Minimap\MiniMap-QuestArrow
-- (the minimap-edge arrow to something off the map) and
-- Interface\Buttons\UI-GroupLoot-Pass-Up (the loot roll's red X).
local ALERT_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
-- The raid target "cross", a plain red X with no circle, cut from the
-- sheet of eight raid markers (4 by 2; the cross is the seventh), hung
-- beyond the "!" while the player is out of the totem's range; both
-- show when both apply. (Tried and passed over: the ready check's X in
-- a circle, Interface\RaidFrame\ReadyCheck-NotReady; the loot roll's
-- pass mark, Interface\Buttons\UI-GroupLoot-Pass-Up, also circled; and
-- the minimap's edge arrow, Interface\Minimap\MiniMap-QuestArrow.)
local RANGE_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local RANGE_ICON_COORDS = { 0.5, 0.75, 0.25, 0.5 } -- left, right, top, bottom; nil for a whole file
local ALERT_PULSE = 6 -- radians per second; about one pulse a second
-- Three spoken alerts from a Windows text-to-speech voice: "totem
-- expiring" as a totem runs out, "totem dead" as something kills one
-- early, and "totem distance" as the player leaves a totem's range. On
-- the Master channel so they are heard even with effects turned down;
-- they are the whole point of the alert.
local ALERT_SOUNDS = {}
for _, kind in ipairs({ "expiring", "dead", "distance" }) do
    ALERT_SOUNDS[kind] = ("Interface\\AddOns\\%s\\assets\\%s.ogg"):format(ADDON_NAME, kind)
end
-- Totems vanishing this soon after a Totemic Call were recalled on
-- purpose, so they don't get the sound; nor is their range judged in
-- that moment, since the buff can go before the totem update does
local RECALL_WINDOW = 1
-- A totem gone with more than this many seconds left was killed rather
-- than expired. The totem update lags the expiry by a fraction of a
-- second, and the start time the client reports is itself a little
-- fuzzy, so a natural expiry can read as slightly early.
local KILL_SLACK = 1
local TICK = 0.1 -- seconds between bar updates
local SAMPLE_DURATION = 120
-- Cascadia Mono (SIL OFL), the bar text's face; the game ships no
-- monospace face of its own
local FONT = "Interface\\AddOns\\" .. ADDON_NAME .. "\\assets\\CascadiaMono.ttf"

local frame
local rows = {} -- one per ns.slots entry, in that order
local opts
local active = {} -- ns.ScanTotems() result, or samples while unlocked
local ticking = false
-- The totem each slot held at the last real scan, so a slot that has
-- gone empty can be noticed
local seen = {}
local recalledAt = 0 -- GetTime() of the last Totemic Call

-- Whether a Totemic Call was cast within the last RECALL_WINDOW
local function Recalled()
    return GetTime() - recalledAt < RECALL_WINDOW
end

local function Anchor()
    frame:ClearAllPoints()
    frame:SetPoint(opts.framePoint, UIParent, opts.frameRelPoint, opts.frameX, opts.frameY)
end

local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    opts.framePoint, opts.frameRelPoint, opts.frameX, opts.frameY = point, relPoint, x, y
end

-- Translucent background, with or without the tooltip-style border
local function ApplyBackdrop()
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = opts.showBorder and "Interface\\Tooltips\\UI-Tooltip-Border" or nil,
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.6)
    if opts.showBorder then
        frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
    end
end

-- The bar text's face and size. SetFont reports a font it couldn't load
-- (say, a file added since the client started), in which case the stock
-- small face is used at the chosen size.
local function ApplyFont(row)
    local size = opts.fontSize
    local stockPath, _, stockFlags = GameFontHighlightSmall:GetFont()
    for _, fs in ipairs({ row.Name, row.Time }) do
        if not fs:SetFont(FONT, size, "") then
            fs:SetFont(stockPath, size, stockFlags or "")
        end
    end
end

-- Row height for the current font: the minimum, or enough to clear the
-- text with a little air
local function RowHeight()
    return math.max(MIN_ROW_HEIGHT, opts.fontSize + 8)
end

-- "4:32" past a minute, whole seconds under it; never below zero
function ns.FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    if seconds >= 60 then
        return ("%d:%02d"):format(seconds / 60, seconds % 60)
    end
    return tostring(seconds)
end

local function CreateRow(i, def)
    local row = CreateFrame("Frame", nil, frame)
    row:SetWidth(WIDTH - PAD * 2)

    row.Bar = CreateFrame("StatusBar", nil, row)
    row.Bar:SetPoint("BOTTOMRIGHT")
    row.Bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.Bar:SetMinMaxValues(0, 1)
    row.Bar:SetValue(1)
    local r, g, b = unpack(def.color)
    row.color = def.color
    row.Bar:SetStatusBarColor(r, g, b)

    row.Back = row.Bar:CreateTexture(nil, "BACKGROUND")
    row.Back:SetAllPoints()
    row.Back:SetColorTexture(r * 0.3, g * 0.3, b * 0.3, 0.6)

    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetPoint("LEFT") -- flush with the row, so its gap to the panel edge matches the bar's
    -- Trim the icon's stock border
    row.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.Alert = row:CreateTexture(nil, "OVERLAY")
    row.Alert:SetTexture(ALERT_ICON)
    row.Alert:Hide() -- anchored as shown (Hang), since the side is an option

    row.Range = row:CreateTexture(nil, "OVERLAY")
    row.Range:SetTexture(RANGE_ICON)
    if RANGE_ICON_COORDS then
        row.Range:SetTexCoord(unpack(RANGE_ICON_COORDS))
    end
    row.Range:Hide() -- likewise

    row.Name = row.Bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Name:SetPoint("LEFT", 4, 0)
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)

    row.Time = row.Bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Time:SetPoint("RIGHT", -INSET, 0)
    row.Time:SetJustifyH("RIGHT")
    row.Name:SetPoint("RIGHT", row.Time, "LEFT", -4, 0)
    ApplyFont(row)
    -- Height, icon size, and bar inset are set per layout (UpdateHud),
    -- since they follow the font size

    rows[i] = row
    return row
end

-- The voice clip for the alert; `kind` is "expiring" or "distance"
local function PlayAlert(kind)
    PlaySoundFile(ALERT_SOUNDS[kind], "Master")
end

-- The first alert icon's gap from the row: past the panel edge (the
-- row sits PAD inside it) and then PAD more, so the panel's margin to
-- the icon matches its margin to the bar
local ICON_GAP = PAD * 2
local ICON_SPACING = 2 -- between two icons

-- Shows or hides one alert icon and, shown, hangs it `gap` off the
-- outer side of `anchor` (the row, or the icon before it) on the
-- option's side. Returns the next icon's anchor and gap, so the icons
-- pack outward from the row with no hole where a hidden one would sit.
local function Hang(icon, shown, anchor, gap)
    icon:SetShown(shown)
    if not shown then
        return anchor, gap
    end
    icon:ClearAllPoints()
    if opts.alertSide == "RIGHT" then
        icon:SetPoint("LEFT", anchor, "RIGHT", gap, 0)
    else
        icon:SetPoint("RIGHT", anchor, "LEFT", -gap, 0)
    end
    return icon, ICON_SPACING
end

-- The bar and time text for one totem; called every tick. Two alerts
-- pulse beside the row, the "!" nearest and the red X beyond it: the
-- "!" as the totem is about to run out (time text red too) and the X
-- while the player is out of its range. Going out of range also gets
-- the "totem distance" voice cue, once per exit, when sounds are on:
-- for the player, a totem out of reach is as good as gone. Not judged
-- just after a Totemic Call: the buff leaves before the totem does,
-- and that gap would read as leaving range.
local function Tick(row, totem)
    local left = ns.TimeLeft(totem)
    local duration = totem.duration
    if duration and duration > 0 then
        row.Bar:SetMinMaxValues(0, duration)
        row.Bar:SetValue(math.max(0, left))
    else
        row.Bar:SetMinMaxValues(0, 1)
        row.Bar:SetValue(1)
    end
    row.Time:SetText(ns.FormatTime(left))
    local warn = left < WARN_SECONDS
    row.Time:SetTextColor(1, warn and 0.3 or 1, warn and 0.3 or 1)
    local out, first = false, false
    if not totem.sample and not Recalled() then
        out, first = ns.OutOfRange(totem)
    end
    if first and opts.playSound then
        PlayAlert("distance")
    end
    local pulse = 0.7 + 0.3 * math.sin(GetTime() * ALERT_PULSE)
    row.Alert:SetAlpha(pulse)
    row.Range:SetAlpha(pulse)
    Hang(row.Range, out, Hang(row.Alert, warn, row, ICON_GAP))
end

local elapsed = 0
local function OnUpdate(self, dt)
    elapsed = elapsed + dt
    if elapsed < TICK then return end
    elapsed = 0
    for _, totem in ipairs(active) do
        if totem.row then
            Tick(totem.row, totem)
        end
    end
end

local function SetTicking(on)
    if on == ticking then return end
    ticking = on
    elapsed = TICK -- first tick right away
    frame:SetScript("OnUpdate", on and OnUpdate or nil)
end

-- One pretend totem per element, for positioning while unlocked
local function Samples()
    local now = GetTime()
    local list = {}
    for _, def in ipairs(ns.slots) do
        list[#list + 1] = {
            def = def,
            sample = true,
            name = def.element .. " Totem",
            icon = def.sampleIcon,
            startTime = now - SAMPLE_DURATION * 0.4,
            duration = SAMPLE_DURATION,
        }
    end
    return list
end

-- Plays the sound for any slot that has gone empty since the last scan:
-- "totem expiring" if its totem had run its course, "totem dead" if it
-- still had time left, so something killed it. A slot holding a
-- different totem than last time was re-dropped by the player, and
-- totems gone within a moment of a Totemic Call were recalled; neither
-- gets a sound.
local function NoteGone(totems)
    local now = {}
    for _, totem in ipairs(totems) do
        now[totem.def.slot] = totem
    end
    local recalled = Recalled()
    for _, def in ipairs(ns.slots) do
        local was = seen[def.slot]
        if was and not now[def.slot] and not recalled and opts.playSound then
            PlayAlert(ns.TimeLeft(was) > KILL_SLACK and "dead" or "expiring")
        end
        seen[def.slot] = now[def.slot]
    end
end

-- Totems don't survive a loading screen; forget them so the empty slots
-- afterwards don't sound
function ns.ForgetTotems()
    wipe(seen)
end

-- Called by Core.lua when the player casts Totemic Call
function ns.NoteRecall()
    recalledAt = GetTime()
end

-- Lays the rows out for the current totems and starts or stops the
-- timer. Called on every totem change and on option changes.
function ns.UpdateHud()
    if not frame then return end
    local unlocked = not opts.locked
    -- Always scan the real totems, even while showing samples, so a
    -- totem going away is never missed or misread once locked again
    local totems = ns.ScanTotems()
    NoteGone(totems)
    active = unlocked and Samples() or totems

    -- Which row each totem sits in: slot order, so a totem never moves
    -- when another is dropped or dies
    local bySlot = {}
    for _, totem in ipairs(active) do
        bySlot[totem.def.slot] = totem
    end

    local y = -PAD
    frame.Title:SetShown(unlocked)
    if unlocked then
        y = y - TITLE_HEIGHT
    end
    -- Always all four rows, a dimmed one for each element with nothing
    -- down, so the panel never changes size. In combat an empty row also
    -- gets the "!" (steady, where an expiring totem's pulses): a missing
    -- totem matters in a fight, and out of one it would only nag.
    local inCombat = UnitAffectingCombat("player")
    local height = RowHeight()
    for i, def in ipairs(ns.slots) do
        local row = rows[i] or CreateRow(i, def)
        row:SetHeight(height)
        row.Icon:SetSize(height - 2, height - 2)
        row.Alert:SetSize(height, height)
        row.Range:SetSize(height, height)
        row.Bar:SetPoint("TOPLEFT", height, 0)
        -- No fill at all, or the fill alone, or fill plus a dim tint
        -- across the drained part
        local r, g, b = unpack(row.color)
        row.Bar:SetStatusBarColor(r, g, b, opts.showBarFill and 1 or 0)
        row.Back:SetShown(opts.showBarFill and opts.showBarBackground)
        local totem = bySlot[def.slot]
        if totem then
            totem.row = row
            row.Icon:SetTexture(totem.icon)
            row.Name:SetText(totem.name)
            row.Bar:SetAlpha(1)
            Tick(row, totem)
        else
            row.Icon:SetTexture(nil)
            row.Name:SetText(def.element)
            row.Time:SetText("")
            row.Bar:SetMinMaxValues(0, 1)
            row.Bar:SetValue(0)
            -- Dim the bar (and its text) but not the "!", which sits on
            -- the row itself
            row.Bar:SetAlpha(0.4)
            row.Alert:SetAlpha(1)
            Hang(row.Alert, inCombat, row, ICON_GAP)
            row.Range:Hide()
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", PAD, y)
        row:Show()
        y = y - height - ROW_GAP
    end

    frame:SetHeight(-y - ROW_GAP + PAD)
    frame:EnableMouse(unlocked)
    -- Samples count as down, so the panel shows while unlocked
    frame:SetShown(#active > 0 or not opts.hideWhenEmpty)
    SetTicking(#active > 0)
end

-- Re-anchors and redraws after an option change or position reset
function ns.RefreshHud()
    if not frame then return end
    Anchor()
    ApplyBackdrop()
    for _, row in ipairs(rows) do
        ApplyFont(row)
    end
    ns.UpdateHud()
end

-- Called by Core.lua on PLAYER_LOGIN, for shamans only
function ns.SetupHud()
    opts = TotemHudDB.options

    frame = CreateFrame("Frame", "TotemHudFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(WIDTH)
    frame:SetHeight(MIN_ROW_HEIGHT + PAD * 2)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    ApplyBackdrop()
    frame:SetScript("OnDragStart", function(self)
        if not opts.locked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)

    frame.Title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.Title:SetPoint("TOPLEFT", PAD, -PAD + 2)
    frame.Title:SetPoint("RIGHT", -PAD, 0)
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetWordWrap(false)
    frame.Title:SetText("Drag to move; lock in options")

    Anchor()
    frame:Hide()
    ns.UpdateHud()
end
