-- config.lua
-- Configuration and options panel for MidnightTooltip

local addonName, addon = ...

-- Default settings
local defaults = {
    enableCursorAnchor = true,
    enableQualityBorder = true,
    cursorOffsetX = 0,
    cursorOffsetY = 0,
    showGuildColors = true,
    showPlayerStatus = true,
    showMountInfo = true,
    showItemLevel = true,
    showFaction = true,
    showRoleIcon = true,
    showMythicRating = true,
    showTargetOfTarget = true,
    -- Custom colors (RGB 0-1 range)
    customGuildColorR = 1.0,
    customGuildColorG = 0.2,
    customGuildColorB = 1.0,
    customOtherGuildColorR = 0.0,
    customOtherGuildColorG = 0.502,
    customOtherGuildColorB = 0.8,
}

-- Create saved variables table
MidnightTooltipDB = MidnightTooltipDB or {}

-- Initialize settings with defaults
local function InitializeSettings()
    for k, v in pairs(defaults) do
        if MidnightTooltipDB[k] == nil then
            MidnightTooltipDB[k] = v
        end
    end
end

-- Initialize on load first
InitializeSettings()

-- Options panel
local optionsPanel = CreateFrame("Frame", "MidnightTooltipOptionsPanel", UIParent)
optionsPanel.name = "MidnightTooltip"

-- Title
local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("MidnightTooltip Options")

-- Description
local description = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
description:SetText("Configure tooltip behavior and appearance")

-- Left Column (5 checkboxes)
-- Enable Cursor Anchor checkbox
local cursorAnchorCheckbox = CreateFrame("CheckButton", "MidnightTooltipCursorAnchor", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
cursorAnchorCheckbox:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -16)
cursorAnchorCheckbox.Text:SetText("Anchor tooltips to cursor")
cursorAnchorCheckbox.tooltipText = "When enabled, tooltips will follow your mouse cursor"
cursorAnchorCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.enableCursorAnchor = self:GetChecked()
    print("|cFF00FFFFMidnightTooltip|r: Cursor anchoring " .. (MidnightTooltipDB.enableCursorAnchor and "enabled" or "disabled") .. ". Reload UI to apply changes.")
end)

-- Enable Quality Border checkbox
local qualityBorderCheckbox = CreateFrame("CheckButton", "MidnightTooltipQualityBorder", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
qualityBorderCheckbox:SetPoint("TOPLEFT", cursorAnchorCheckbox, "BOTTOMLEFT", 0, -8)
qualityBorderCheckbox.Text:SetText("Color borders by item quality")
qualityBorderCheckbox.tooltipText = "When enabled, item tooltip borders will be colored based on item quality"
qualityBorderCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.enableQualityBorder = self:GetChecked()
    print("|cFF00FFFFMidnightTooltip|r: Quality borders " .. (MidnightTooltipDB.enableQualityBorder and "enabled" or "disabled") .. ". Reload UI to apply changes.")
end)

-- Show Guild Colors checkbox
local guildColorsCheckbox = CreateFrame("CheckButton", "MidnightTooltipGuildColors", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
guildColorsCheckbox:SetPoint("TOPLEFT", qualityBorderCheckbox, "BOTTOMLEFT", 0, -8)
guildColorsCheckbox.Text:SetText("Show guild name colors")
guildColorsCheckbox.tooltipText = "When enabled, guild names will be colored differently for your guild members"
guildColorsCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showGuildColors = self:GetChecked()
end)

-- Show Player Status checkbox
local playerStatusCheckbox = CreateFrame("CheckButton", "MidnightTooltipPlayerStatus", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
playerStatusCheckbox:SetPoint("TOPLEFT", guildColorsCheckbox, "BOTTOMLEFT", 0, -8)
playerStatusCheckbox.Text:SetText("Show player status (AFK/DND)")
playerStatusCheckbox.tooltipText = "When enabled, shows AFK and DND status on player names"
playerStatusCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showPlayerStatus = self:GetChecked()
end)

-- Show Mount Info checkbox
local mountInfoCheckbox = CreateFrame("CheckButton", "MidnightTooltipMountInfo", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
mountInfoCheckbox:SetPoint("TOPLEFT", playerStatusCheckbox, "BOTTOMLEFT", 0, -8)
mountInfoCheckbox.Text:SetText("Show mount information")
mountInfoCheckbox.tooltipText = "When enabled, shows what mount a player is riding and collection status"
mountInfoCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showMountInfo = self:GetChecked()
end)

-- Right Column (5 checkboxes)
-- Show Item Level checkbox
local itemLevelCheckbox = CreateFrame("CheckButton", "MidnightTooltipItemLevel", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
itemLevelCheckbox:SetPoint("TOPLEFT", cursorAnchorCheckbox, "TOPRIGHT", 200, 0)
itemLevelCheckbox.Text:SetText("Show player item level")
itemLevelCheckbox.tooltipText = "When enabled, shows the player's average item level"
itemLevelCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showItemLevel = self:GetChecked()
end)

-- Show Faction checkbox
local factionCheckbox = CreateFrame("CheckButton", "MidnightTooltipFaction", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
factionCheckbox:SetPoint("TOPLEFT", itemLevelCheckbox, "BOTTOMLEFT", 0, -8)
factionCheckbox.Text:SetText("Show faction (Horde/Alliance)")
factionCheckbox.tooltipText = "When enabled, the faction line will show red for Horde and blue for Alliance"
factionCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showFaction = self:GetChecked()
end)

-- Show Role Icon checkbox
local roleIconCheckbox = CreateFrame("CheckButton", "MidnightTooltipRoleIcon", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
roleIconCheckbox:SetPoint("TOPLEFT", factionCheckbox, "BOTTOMLEFT", 0, -8)
roleIconCheckbox.Text:SetText("Show role icon (Tank/Healer/DPS)")
roleIconCheckbox.tooltipText = "When enabled, shows the player's role icon"
roleIconCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showRoleIcon = self:GetChecked()
end)

-- Show Mythic+ Rating checkbox
local mythicRatingCheckbox = CreateFrame("CheckButton", "MidnightTooltipMythicRating", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
mythicRatingCheckbox:SetPoint("TOPLEFT", roleIconCheckbox, "BOTTOMLEFT", 0, -8)
mythicRatingCheckbox.Text:SetText("Show Mythic+ rating")
mythicRatingCheckbox.tooltipText = "When enabled, shows the player's Mythic+ rating score"
mythicRatingCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showMythicRating = self:GetChecked()
end)

-- Show Target of Target checkbox
local targetOfTargetCheckbox = CreateFrame("CheckButton", "MidnightTooltipTargetOfTarget", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
targetOfTargetCheckbox:SetPoint("TOPLEFT", mythicRatingCheckbox, "BOTTOMLEFT", 0, -8)
targetOfTargetCheckbox.Text:SetText("Show target of target")
targetOfTargetCheckbox.tooltipText = "When enabled, shows who the unit is targeting"
targetOfTargetCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showTargetOfTarget = self:GetChecked()
end)

-- Disable OnValueChanged during initialization
local isInitializing = true

-- X Offset slider
local offsetXLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
offsetXLabel:SetPoint("TOPLEFT", mountInfoCheckbox, "BOTTOMLEFT", 0, -24)
offsetXLabel:SetText("Tooltip X Offset")

local offsetXSlider = CreateFrame("Slider", "MidnightTooltipOffsetXSlider", optionsPanel, "OptionsSliderTemplate")
offsetXSlider:SetPoint("TOPLEFT", offsetXLabel, "BOTTOMLEFT", 20, -8)
offsetXSlider:SetMinMaxValues(-200, 200)
offsetXSlider:SetValueStep(1)
offsetXSlider:SetObeyStepOnDrag(true)
offsetXSlider:SetWidth(260)
offsetXSlider.Low:SetText("-200")
offsetXSlider.High:SetText("200")
offsetXSlider.Text:SetText("X: " .. (MidnightTooltipDB.cursorOffsetX or 0))
offsetXSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    self.Text:SetText("X: " .. value)
    if not isInitializing then
        MidnightTooltipDB.cursorOffsetX = value
    end
end)

-- X Offset decrease button
local offsetXDecBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
offsetXDecBtn:SetPoint("RIGHT", offsetXSlider, "LEFT", -5, 0)
offsetXDecBtn:SetSize(20, 20)
offsetXDecBtn:SetText("<")
offsetXDecBtn:SetScript("OnClick", function()
    local value = offsetXSlider:GetValue() - 1
    offsetXSlider:SetValue(value)
end)

-- X Offset increase button
local offsetXIncBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
offsetXIncBtn:SetPoint("LEFT", offsetXSlider, "RIGHT", 5, 0)
offsetXIncBtn:SetSize(20, 20)
offsetXIncBtn:SetText(">")
offsetXIncBtn:SetScript("OnClick", function()
    local value = offsetXSlider:GetValue() + 1
    offsetXSlider:SetValue(value)
end)

-- Y Offset slider
local offsetYLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
offsetYLabel:SetPoint("TOPLEFT", offsetXSlider, "BOTTOMLEFT", -20, -16)
offsetYLabel:SetText("Tooltip Y Offset")

local offsetYSlider = CreateFrame("Slider", "MidnightTooltipOffsetYSlider", optionsPanel, "OptionsSliderTemplate")
offsetYSlider:SetPoint("TOPLEFT", offsetYLabel, "BOTTOMLEFT", 20, -8)
offsetYSlider:SetMinMaxValues(-200, 200)
offsetYSlider:SetValueStep(1)
offsetYSlider:SetObeyStepOnDrag(true)
offsetYSlider:SetWidth(260)
offsetYSlider.Low:SetText("-200")
offsetYSlider.High:SetText("200")
offsetYSlider.Text:SetText("Y: " .. (MidnightTooltipDB.cursorOffsetY or 0))
offsetYSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    self.Text:SetText("Y: " .. value)
    if not isInitializing then
        MidnightTooltipDB.cursorOffsetY = value
    end
end)

-- Y Offset decrease button
local offsetYDecBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
offsetYDecBtn:SetPoint("RIGHT", offsetYSlider, "LEFT", -5, 0)
offsetYDecBtn:SetSize(20, 20)
offsetYDecBtn:SetText("<")
offsetYDecBtn:SetScript("OnClick", function()
    local value = offsetYSlider:GetValue() - 1
    offsetYSlider:SetValue(value)
end)

-- Y Offset increase button
local offsetYIncBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
offsetYIncBtn:SetPoint("LEFT", offsetYSlider, "RIGHT", 5, 0)
offsetYIncBtn:SetSize(20, 20)
offsetYIncBtn:SetText(">")
offsetYIncBtn:SetScript("OnClick", function()
    local value = offsetYSlider:GetValue() + 1
    offsetYSlider:SetValue(value)
end)

-- Info text about reloading
local reloadInfo = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
reloadInfo:SetPoint("TOPLEFT", offsetYSlider, "BOTTOMLEFT", 0, -24)
reloadInfo:SetText("|cFFFFFF00Settings are saved automatically.|r\nReload UI (|cFF00FFFF/mttr|r) to apply changes.")
reloadInfo:SetJustifyH("LEFT")

-- Save & Reload button
local saveReloadButton = CreateFrame("Button", "MidnightTooltipSaveReload", optionsPanel, "UIPanelButtonTemplate")
saveReloadButton:SetPoint("TOPLEFT", reloadInfo, "BOTTOMLEFT", 0, -8)
saveReloadButton:SetSize(140, 25)
saveReloadButton:SetText("Save & Reload UI")
saveReloadButton:SetScript("OnClick", function()
    print("|cFF00FFFFMidnightTooltip|r: Settings saved. Reloading UI...")
    ReloadUI()
end)

-- Reset button
local resetButton = CreateFrame("Button", "MidnightTooltipReset", optionsPanel, "UIPanelButtonTemplate")
resetButton:SetPoint("LEFT", saveReloadButton, "RIGHT", 10, 0)
resetButton:SetSize(120, 25)
resetButton:SetText("Reset to Defaults")
resetButton:SetScript("OnClick", function()
    for k, v in pairs(defaults) do
        MidnightTooltipDB[k] = v
    end
    cursorAnchorCheckbox:SetChecked(defaults.enableCursorAnchor)
    qualityBorderCheckbox:SetChecked(defaults.enableQualityBorder)
    offsetXSlider:SetValue(defaults.cursorOffsetX)
    offsetYSlider:SetValue(defaults.cursorOffsetY)
    print("|cFF00FFFFMidnightTooltip|r: Settings reset to defaults.")
end)

-- Version info
local version = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
version:SetPoint("BOTTOMLEFT", 16, 16)
version:SetText("Version: " .. (C_AddOns.GetAddOnMetadata("MidnightTooltip", "Version") or "1.00.02"))
version:SetTextColor(0.5, 0.5, 0.5)

-- Register the panel
local category
if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(optionsPanel, optionsPanel.name)
    Settings.RegisterAddOnCategory(category)
end

-- Function to refresh UI with current values
local function RefreshUI()
    cursorAnchorCheckbox:SetChecked(MidnightTooltipDB.enableCursorAnchor)
    qualityBorderCheckbox:SetChecked(MidnightTooltipDB.enableQualityBorder)
    guildColorsCheckbox:SetChecked(MidnightTooltipDB.showGuildColors)
    playerStatusCheckbox:SetChecked(MidnightTooltipDB.showPlayerStatus)
    mountInfoCheckbox:SetChecked(MidnightTooltipDB.showMountInfo)
    itemLevelCheckbox:SetChecked(MidnightTooltipDB.showItemLevel)
    factionCheckbox:SetChecked(MidnightTooltipDB.showFaction)
    roleIconCheckbox:SetChecked(MidnightTooltipDB.showRoleIcon)
    mythicRatingCheckbox:SetChecked(MidnightTooltipDB.showMythicRating)
    targetOfTargetCheckbox:SetChecked(MidnightTooltipDB.showTargetOfTarget)
    offsetXSlider:SetValue(MidnightTooltipDB.cursorOffsetX)
    offsetYSlider:SetValue(MidnightTooltipDB.cursorOffsetY)
end

-- Set initial values after initialization
RefreshUI()

-- Re-enable OnValueChanged after initialization
isInitializing = false

-- Refresh values when panel is shown
optionsPanel:SetScript("OnShow", function()
    RefreshUI()
end)

-- Export functions
addon.GetSetting = function(key)
    return MidnightTooltipDB[key]
end

addon.SetSetting = function(key, value)
    MidnightTooltipDB[key] = value
end

addon.OpenOptions = function()
    if category then
        Settings.OpenToCategory(category:GetID())
    end
end
