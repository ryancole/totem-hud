local ADDON_NAME, ns = ...

-- Canvas-style settings panel (Options -> AddOns -> Totem HUD): the
-- account-wide option checkboxes, the font size slider, and a
-- reset-position button.

local FONT_SIZE_MIN, FONT_SIZE_MAX = 6, 16

local function MakeCheckbox(parent, label, getter, setter)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
    end)
    check:SetScript("OnShow", function(self)
        self:SetChecked(getter())
    end)
    local text = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    check.Text = text
    text:SetText(label)
    text:SetPoint("LEFT", check, "RIGHT", 5, 1)
    text:SetScript("OnMouseUp", function()
        if check:IsEnabled() then
            check:Click()
        end
    end)
    text:SetScript("OnEnter", function()
        if check:IsEnabled() then
            check:LockHighlight()
        end
    end)
    text:SetScript("OnLeave", function()
        check:UnlockHighlight()
    end)
    return check
end

-- Greys out a checkbox and its label, for a child whose parent is off
local function SetCheckEnabled(check, enabled)
    check:SetEnabled(enabled)
    check.Text:SetFontObject(enabled and GameFontHighlight or GameFontDisable)
end

-- Called by Core.lua on PLAYER_LOGIN, for shamans only
function ns.SetupOptions()
    local opts = TotemHudDB.options

    local panel = CreateFrame("Frame")
    panel:Hide()

    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    header:SetPoint("TOPLEFT", 15, -10)
    header:SetText(NORMAL_FONT_COLOR:WrapTextInColorCode("Totem HUD"))

    -- Substituted by the packager at release; raw keyword means a dev copy
    local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
    if not version or version:find("@") then
        version = "dev"
    end
    local versionText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    versionText:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -5)
    versionText:SetText(WHITE_FONT_COLOR:WrapTextInColorCode(("Version: %s"):format(version)))

    -- { label, option key, onChange?, parent = key of the option that
    -- must be on for this one to matter }. Children sit indented under
    -- their parent and grey out while it is off.
    local defs = {
        { "Lock the HUD in place (it shows sample totems while unlocked)", "locked" },
        { "Keep a dimmed row for each element with no totem down", "showEmptySlots" },
        { "Show a border around the HUD", "showBorder" },
        { "Color each bar by its element", "showBarFill" },
        { "Color the whole bar, dim where drained (off: only the time left)", "showBarBackground",
            parent = "showBarFill" },
        { "Hide the default totem timers under the player frame", "hideBlizzardTotems",
            function() ns.ApplyBlizzardTotems() end },
    }
    local checks = {}
    local function SyncChildren()
        for _, def in ipairs(defs) do
            if def.parent then
                SetCheckEnabled(checks[def[2]], opts[def.parent] and true or false)
            end
        end
    end
    local previous = versionText
    for _, def in ipairs(defs) do
        local label, key, onChange = def[1], def[2], def[3]
        local check = MakeCheckbox(panel, label,
            function() return opts[key] end,
            function(v)
                opts[key] = v
                if onChange then onChange(v) end
                SyncChildren()
                ns.RefreshHud()
            end)
        checks[key] = check
        local x = 0
        if previous == versionText then
            x = -4
        elseif def.parent and not previous.def.parent then
            x = 20 -- step in under the parent
        elseif previous.def.parent and not def.parent then
            x = -20 -- step back out
        end
        check:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", x, previous == versionText and -10 or -2)
        check.def = def
        previous = check
    end
    panel:HookScript("OnShow", SyncChildren)

    -- Font size slider; the label above it shows the current value
    local slider = CreateFrame("Slider", nil, panel, "UISliderTemplateWithLabels")
    slider:SetSize(180, 17)
    slider:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 8, -28)
    slider:SetMinMaxValues(FONT_SIZE_MIN, FONT_SIZE_MAX)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText(FONT_SIZE_MIN)
    slider.High:SetText(FONT_SIZE_MAX)
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        self.Text:SetText(("Font size: %d"):format(value))
        if value ~= opts.fontSize then
            opts.fontSize = value
            ns.RefreshHud()
        end
    end)
    slider:SetScript("OnShow", function(self)
        self:SetValue(opts.fontSize)
    end)
    previous = slider

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(140, 22)
    resetButton:SetText("Reset Position")
    resetButton:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", -4, -20)
    resetButton:SetScript("OnClick", function()
        for _, k in ipairs({ "framePoint", "frameRelPoint", "frameX", "frameY" }) do
            opts[k] = ns.optionDefaults[k]
        end
        ns.RefreshHud()
    end)

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -16)
    hint:SetText("Slash commands: /th lock, /th unlock, /th reset, /th list")

    -- Required no-op handlers for canvas settings panels
    panel.OnCommit = function() end
    panel.OnDefault = function() end
    panel.OnRefresh = function() end

    local category = Settings.RegisterCanvasLayoutCategory(panel, "Totem HUD")
    ns.settingsCategory = category
    Settings.RegisterAddOnCategory(category)
end

function ns.OpenOptions()
    if ns.settingsCategory then
        Settings.OpenToCategory(ns.settingsCategory:GetID())
    end
end
