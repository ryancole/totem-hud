local ADDON_NAME, ns = ...

-- Canvas-style settings panel (Options -> AddOns -> Totem HUD): the
-- account-wide option checkboxes and a reset-position button.

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
        check:Click()
    end)
    text:SetScript("OnEnter", function()
        check:LockHighlight()
    end)
    text:SetScript("OnLeave", function()
        check:UnlockHighlight()
    end)
    return check
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

    local defs = {
        { "Lock the HUD in place (it shows sample totems while unlocked)", "locked" },
        { "Keep a dimmed row for each element with no totem down", "showEmptySlots" },
        { "Show a border around the HUD", "showBorder" },
    }
    local previous = versionText
    for _, def in ipairs(defs) do
        local label, key = def[1], def[2]
        local check = MakeCheckbox(panel, label,
            function() return opts[key] end,
            function(v)
                opts[key] = v
                ns.RefreshHud()
            end)
        check:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", previous == versionText and -4 or 0,
            previous == versionText and -10 or -2)
        previous = check
    end

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(140, 22)
    resetButton:SetText("Reset Position")
    resetButton:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 4, -12)
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
