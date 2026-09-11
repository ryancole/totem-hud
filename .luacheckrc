-- Check against WoW's Lua dialect: 5.1 syntax and stdlib. luacheck itself
-- may run on any Lua version; this is what it validates *against*.
std = "lua51"

max_line_length = false

ignore = {
    "211/ADDON_NAME", -- every file destructures ...; not all use the name
    "211/_",          -- discarded values
    "212",            -- unused arguments (self in handlers, etc.)
    "213/_",          -- discarded loop variables
}

-- Globals this addon is allowed to create or assign
globals = {
    "TotemHudDB", -- SavedVariables
    "SLASH_TOTEMHUD1",
    "SLASH_TOTEMHUD2",
    "SlashCmdList",
}

-- WoW-provided API, read-only
read_globals = {
    -- Lua extensions in the WoW environment
    "strlower", "strsplit", "strtrim", "wipe",
    -- API functions
    "CreateFrame", "GetTime", "GetTotemInfo", "GetTotemTimeLeft",
    "InCombatLockdown", "PlaySoundFile", "UnitAffectingCombat", "UnitClass",
    -- Namespaces
    "C_AddOns", "Settings",
    -- Frames, fonts, and constants
    "GameFontDisable", "GameFontHighlight", "GameFontHighlightSmall",
    "GameFontNormal", "GameFontNormalHuge",
    "GameFontNormalSmall", "GameTooltip", "NORMAL_FONT_COLOR", "TotemFrame",
    "TotemFrame_Update", "UIParent", "WHITE_FONT_COLOR",
    -- Legacy dropdown menu
    "UIDropDownMenu_AddButton", "UIDropDownMenu_CreateInfo",
    "UIDropDownMenu_Initialize", "UIDropDownMenu_SetSelectedValue",
    "UIDropDownMenu_SetText", "UIDropDownMenu_SetWidth",
}
