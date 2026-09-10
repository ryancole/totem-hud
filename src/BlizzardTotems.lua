local ADDON_NAME, ns = ...

-- Hides the default totem timers (TotemFrame, the row of icons under the
-- player frame) when the option asks for it, since the HUD replaces them.
-- TotemFrame is an ordinary frame, not a secure one, so we may hide it
-- at any time; still, the hide is deferred out of combat as a courtesy
-- to any client build that protects it.
--
-- Hiding: drop its events so it stops updating itself, hide it, and
-- re-hide it from OnShow in case the player frame shows it again.
-- Restoring: put the original OnShow back, re-register the events its
-- OnLoad registers, and ask it to redraw.

local BLIZZARD_EVENTS = {
    "PLAYER_TOTEM_UPDATE",
    "PLAYER_ENTERING_WORLD",
    "UPDATE_SHAPESHIFT_FORM",
}

local originalOnShow
local hidden = false
local pending -- desired state, waiting for combat to end

local function Apply(hide)
    local f = TotemFrame
    if not f or hide == hidden then return end
    hidden = hide
    if hide then
        originalOnShow = f:GetScript("OnShow")
        f:UnregisterAllEvents()
        f:SetScript("OnShow", f.Hide)
        f:Hide()
    else
        f:SetScript("OnShow", originalOnShow)
        for _, event in ipairs(BLIZZARD_EVENTS) do
            f:RegisterEvent(event)
        end
        -- Newer FrameXML puts the update on the frame; older keeps a
        -- global function
        if f.Update then
            f:Update()
        elseif TotemFrame_Update then
            TotemFrame_Update()
        end
    end
end

local waiter = CreateFrame("Frame")
waiter:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if pending ~= nil then
        Apply(pending)
        pending = nil
    end
end)

-- Called on login and whenever the option changes
function ns.ApplyBlizzardTotems()
    local hide = TotemHudDB.options.hideBlizzardTotems and true or false
    if InCombatLockdown() then
        pending = hide
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        Apply(hide)
    end
end
