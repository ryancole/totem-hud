local ADDON_NAME, ns = ...

-- The HUD: a small movable panel with one bar per totem down, in the
-- default totem bar's element order. Each bar is tinted for its element
-- and drains as the totem runs out, with the totem's icon and name at
-- the left and the time left at the right. Nothing down means nothing
-- shown (unless the empty-slot option keeps a dimmed row per element).
-- Unlocking it (it starts locked) shows a sample bar per element so it
-- can be seen and dragged into place.
--
-- Rows are plain frames, so they may be shown, hidden, and rearranged
-- in combat: the HUD needs no secure frames.

local WIDTH = 180
local MIN_ROW_HEIGHT = 18 -- rows grow past this to fit a large font
local ROW_GAP = 2
local PAD = 6
local TITLE_HEIGHT = 14
local WARN_SECONDS = 10 -- time text turns red below this
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
    row.Icon:SetPoint("LEFT", 0, 0)
    -- Trim the icon's stock border
    row.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.Name = row.Bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Name:SetPoint("LEFT", 4, 0)
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)

    row.Time = row.Bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Time:SetPoint("RIGHT", -4, 0)
    row.Time:SetJustifyH("RIGHT")
    row.Name:SetPoint("RIGHT", row.Time, "LEFT", -4, 0)
    ApplyFont(row)
    -- Height, icon size, and bar inset are set per layout (UpdateHud),
    -- since they follow the font size

    rows[i] = row
    return row
end

-- The bar and time text for one totem; called every tick
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
    if left < WARN_SECONDS then
        row.Time:SetTextColor(1, 0.3, 0.3)
    else
        row.Time:SetTextColor(1, 1, 1)
    end
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
            name = def.element .. " Totem",
            icon = def.sampleIcon,
            startTime = now - SAMPLE_DURATION * 0.4,
            duration = SAMPLE_DURATION,
        }
    end
    return list
end

-- Lays the rows out for the current totems and starts or stops the
-- timer. Called on every totem change and on option changes.
function ns.UpdateHud()
    if not frame then return end
    local unlocked = not opts.locked
    active = unlocked and Samples() or ns.ScanTotems()

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
    local shown = 0
    local height = RowHeight()
    for i, def in ipairs(ns.slots) do
        local row = rows[i] or CreateRow(i, def)
        row:SetHeight(height)
        row.Icon:SetSize(height - 2, height - 2)
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
            row:SetAlpha(1)
            Tick(row, totem)
        elseif opts.showEmptySlots then
            row.Icon:SetTexture(nil)
            row.Name:SetText(def.element)
            row.Time:SetText("")
            row.Bar:SetMinMaxValues(0, 1)
            row.Bar:SetValue(0)
            row:SetAlpha(0.4)
        end
        if totem or opts.showEmptySlots then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", PAD, y)
            row:Show()
            y = y - height - ROW_GAP
            shown = shown + 1
        else
            row:Hide()
        end
    end

    frame:SetHeight(-y - ROW_GAP + PAD)
    frame:EnableMouse(unlocked)
    frame:SetShown(shown > 0)
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
