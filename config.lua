-- config.lua
-- Configuration and options panel for MidnightTooltip

local addonName, addon = ...

-- UI Layout Constants
local SPACING_SMALL = -8
local SPACING_MEDIUM = -16
local SPACING_LARGE = -24
local SPACING_XLARGE = -40
local COLUMN_OFFSET = 200
local SWATCH_SIZE = 24
local SLIDER_WIDTH = 260
local SLIDER_BUTTON_SIZE = 20

-- Default settings
local defaults = {
    enableCursorAnchor = true,
    cursorOnlyMode = false,
    hideTooltipsInCombat = false,
    enableQualityBorder = true,
    anchorPoint = "BOTTOM",
    cursorOffsetX = 0,
    cursorOffsetY = 0,
    fadeOutDelay = 0.2,
    tooltipScale = 100,
    showClassColors = true,
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

-- Create saved variables table (these will be properly loaded by TOC after ADDON_LOADED)
MidnightTooltipDB = MidnightTooltipDB or {}
MidnightTooltipProfiles = MidnightTooltipProfiles or {}

-- Initialize settings with defaults (call this after ADDON_LOADED)
local function InitializeSettings()
    for k, v in pairs(defaults) do
        if MidnightTooltipDB[k] == nil then
            MidnightTooltipDB[k] = v
        end
    end
    
    -- Initialize Default profile if it doesn't exist
    if not MidnightTooltipProfiles["Default"] then
        MidnightTooltipProfiles["Default"] = {}
        for k, v in pairs(defaults) do
            MidnightTooltipProfiles["Default"][k] = v
        end
    end
end

-- Create event frame to initialize after saved variables are loaded
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "MidnightTooltip" then
        InitializeSettings()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Helper function to create color picker swatch
local function CreateColorPickerSwatch(parent, label, anchorTo, rKey, gKey, bKey, defaultR, defaultG, defaultB)
    local colorLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, SPACING_SMALL)
    colorLabel:SetText(label)
    
    local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    swatch:SetPoint("LEFT", colorLabel, "RIGHT", 8, 0)
    swatch:SetSize(SWATCH_SIZE, SWATCH_SIZE)
    
    -- Add backdrop for better visibility
    swatch:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    swatch:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    swatch:SetNormalTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
    local texture = swatch:GetNormalTexture()
    texture:SetVertexColor(
        MidnightTooltipDB[rKey] or defaultR,
        MidnightTooltipDB[gKey] or defaultG,
        MidnightTooltipDB[bKey] or defaultB
    )
    
    -- Add hover effect
    swatch:SetScript("OnEnter", function(self)
        swatch:SetBackdropBorderColor(1, 1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to choose color")
        GameTooltip:Show()
    end)
    
    swatch:SetScript("OnLeave", function(self)
        swatch:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        GameTooltip:Hide()
    end)
    
    swatch:SetScript("OnClick", function(self)
        local function OnColorChanged()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            -- Validate RGB values are in bounds
            r, g, b = math.max(0, math.min(1, r)), math.max(0, math.min(1, g)), math.max(0, math.min(1, b))
            MidnightTooltipDB[rKey] = r
            MidnightTooltipDB[gKey] = g
            MidnightTooltipDB[bKey] = b
            texture:SetVertexColor(r, g, b)
            if addon and addon.RefreshSettingsCache then
                addon.RefreshSettingsCache()
            end
            -- Notify user that tooltips will update on next show
            print("|cFF00FFFFMidnightTooltip|r: Color updated. Move your mouse off and back onto units to see the change.")
        end
        
        local function OnCancel()
            local r, g, b = ColorPickerFrame:GetPreviousValues()
            MidnightTooltipDB[rKey] = r
            MidnightTooltipDB[gKey] = g
            MidnightTooltipDB[bKey] = b
            texture:SetVertexColor(r, g, b)
            if addon and addon.RefreshSettingsCache then
                addon.RefreshSettingsCache()
            end
        end
        
        local options = {
            swatchFunc = OnColorChanged,
            cancelFunc = OnCancel,
            hasOpacity = false,
            r = MidnightTooltipDB[rKey] or defaultR,
            g = MidnightTooltipDB[gKey] or defaultG,
            b = MidnightTooltipDB[bKey] or defaultB,
        }
        
        ColorPickerFrame:SetupColorPickerAndShow(options)
    end)
    
    return colorLabel, swatch, texture
end

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

-- Cursor Only Mode checkbox
local cursorOnlyModeCheckbox = CreateFrame("CheckButton", "MidnightTooltipCursorOnlyMode", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
cursorOnlyModeCheckbox:SetPoint("TOPLEFT", cursorAnchorCheckbox, "BOTTOMLEFT", 0, -8)
cursorOnlyModeCheckbox.Text:SetText("Cursor-only mode (no customizations)")
cursorOnlyModeCheckbox.tooltipText = "When enabled, only cursor positioning is active. All other customizations are disabled."
cursorOnlyModeCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.cursorOnlyMode = self:GetChecked()
    print("|cFF00FFFFMidnightTooltip|r: Cursor-only mode " .. (MidnightTooltipDB.cursorOnlyMode and "enabled" or "disabled") .. ". Reload UI to apply changes.")
end)

-- Hide Tooltips in Combat (in instances) checkbox
local hideCombatCheckbox = CreateFrame("CheckButton", "MidnightTooltipHideCombat", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
hideCombatCheckbox:SetPoint("TOPLEFT", cursorOnlyModeCheckbox, "BOTTOMLEFT", 0, -8)
hideCombatCheckbox.Text:SetText("Hide tooltips in combat (dungeons/raids)")
hideCombatCheckbox.tooltipText = "When enabled, tooltips are hidden during combat in dungeons, raids, and scenarios"
hideCombatCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.hideTooltipsInCombat = self:GetChecked()
    print("|cFF00FFFFMidnightTooltip|r: Hide combat tooltips " .. (MidnightTooltipDB.hideTooltipsInCombat and "enabled" or "disabled") .. ". Reload UI to apply changes.")
end)

-- Enable Quality Border checkbox
local qualityBorderCheckbox = CreateFrame("CheckButton", "MidnightTooltipQualityBorder", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
qualityBorderCheckbox:SetPoint("TOPLEFT", hideCombatCheckbox, "BOTTOMLEFT", 0, -8)
qualityBorderCheckbox.Text:SetText("Color borders by item quality")
qualityBorderCheckbox.tooltipText = "When enabled, item tooltip borders will be colored based on item quality"
qualityBorderCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.enableQualityBorder = self:GetChecked()
    print("|cFF00FFFFMidnightTooltip|r: Quality borders " .. (MidnightTooltipDB.enableQualityBorder and "enabled" or "disabled") .. ". Reload UI to apply changes.")
end)

-- Show Class Colors checkbox
local classColorsCheckbox = CreateFrame("CheckButton", "MidnightTooltipClassColors", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
classColorsCheckbox:SetPoint("TOPLEFT", qualityBorderCheckbox, "BOTTOMLEFT", 0, -8)
classColorsCheckbox.Text:SetText("Color player names by class")
classColorsCheckbox.tooltipText = "When enabled, player names and tooltip text will be colored by their class"
classColorsCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showClassColors = self:GetChecked()
    print("|cFF00FFFFMidnightTooltip|r: Class colors " .. (MidnightTooltipDB.showClassColors and "enabled" or "disabled") .. ". Reload UI to apply changes.")
end)

-- Show Guild Colors checkbox
local guildColorsCheckbox = CreateFrame("CheckButton", "MidnightTooltipGuildColors", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
guildColorsCheckbox:SetPoint("TOPLEFT", classColorsCheckbox, "BOTTOMLEFT", 0, -8)
guildColorsCheckbox.Text:SetText("Show guild name colors")
guildColorsCheckbox.tooltipText = "When enabled, guild names will be colored differently for your guild members"
guildColorsCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showGuildColors = self:GetChecked()
end)

-- My Guild Color Picker
local myGuildColorLabel, myGuildColorSwatch, myGuildColorTexture = CreateColorPickerSwatch(
    optionsPanel, 
    "My Guild Color:", 
    guildColorsCheckbox, 
    "customGuildColorR", "customGuildColorG", "customGuildColorB",
    1.0, 0.2, 1.0
)

-- Other Guild Color Picker
local otherGuildColorLabel, otherGuildColorSwatch, otherGuildColorTexture = CreateColorPickerSwatch(
    optionsPanel,
    "Other Guild Color:",
    myGuildColorLabel,
    "customOtherGuildColorR", "customOtherGuildColorG", "customOtherGuildColorB",
    0.0, 0.502, 0.8
)

-- Right Column - Information Display Options
-- Show Player Status checkbox (Row 1, Right Column)
local playerStatusCheckbox = CreateFrame("CheckButton", "MidnightTooltipPlayerStatus", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
playerStatusCheckbox:SetPoint("TOPLEFT", cursorAnchorCheckbox, "TOPRIGHT", COLUMN_OFFSET, 0)
playerStatusCheckbox.Text:SetText("Show player status (AFK/DND)")
playerStatusCheckbox.tooltipText = "When enabled, shows AFK and DND status on player names"
playerStatusCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showPlayerStatus = self:GetChecked()
end)

-- Show Item Level checkbox (Row 2, Right Column)
local iLevelCheckbox = CreateFrame("CheckButton", "MidnightTooltipItemLevel", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
iLevelCheckbox:SetPoint("TOPLEFT", playerStatusCheckbox, "BOTTOMLEFT", 0, -8)
iLevelCheckbox.Text:SetText("Show player item level")
iLevelCheckbox.tooltipText = "When enabled, shows the player's average item level"
iLevelCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showItemLevel = self:GetChecked()
end)

-- Show Role Icon checkbox (Row 3, Right Column)
local roleIconCheckbox = CreateFrame("CheckButton", "MidnightTooltipRoleIcon", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
roleIconCheckbox:SetPoint("TOPLEFT", iLevelCheckbox, "BOTTOMLEFT", 0, -8)
roleIconCheckbox.Text:SetText("Show role icon (Tank/Healer/DPS)")
roleIconCheckbox.tooltipText = "When enabled, shows the player's role icon"
roleIconCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showRoleIcon = self:GetChecked()
end)

-- Show Mythic+ Rating checkbox (Row 4, Right Column)
local mythicRatingCheckbox = CreateFrame("CheckButton", "MidnightTooltipMythicRating", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
mythicRatingCheckbox:SetPoint("TOPLEFT", roleIconCheckbox, "BOTTOMLEFT", 0, -8)
mythicRatingCheckbox.Text:SetText("Show Mythic+ rating")
mythicRatingCheckbox.tooltipText = "When enabled, shows the player's Mythic+ rating score"
mythicRatingCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showMythicRating = self:GetChecked()
end)

-- Show Faction checkbox (Row 5, Right Column)
local factionCheckbox = CreateFrame("CheckButton", "MidnightTooltipFaction", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
factionCheckbox:SetPoint("TOPLEFT", mythicRatingCheckbox, "BOTTOMLEFT", 0, -8)
factionCheckbox.Text:SetText("Show faction (Horde/Alliance)")
factionCheckbox.tooltipText = "When enabled, the faction line will show red for Horde and blue for Alliance"
factionCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showFaction = self:GetChecked()
end)

-- Show Mount Info checkbox (Row 6, Right Column)
local mountInfoCheckbox = CreateFrame("CheckButton", "MidnightTooltipMountInfo", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
mountInfoCheckbox:SetPoint("TOPLEFT", factionCheckbox, "BOTTOMLEFT", 0, -8)
mountInfoCheckbox.Text:SetText("Show mount information")
mountInfoCheckbox.tooltipText = "When enabled, shows what mount a player is riding and collection status"
mountInfoCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showMountInfo = self:GetChecked()
end)

-- Show Target of Target checkbox (Row 7, Right Column)
local targetOfTargetCheckbox = CreateFrame("CheckButton", "MidnightTooltipTargetOfTarget", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
targetOfTargetCheckbox:SetPoint("TOPLEFT", mountInfoCheckbox, "BOTTOMLEFT", 0, -8)
targetOfTargetCheckbox.Text:SetText("Show target of target")
targetOfTargetCheckbox.tooltipText = "When enabled, shows who the unit is targeting"
targetOfTargetCheckbox:SetScript("OnClick", function(self)
    MidnightTooltipDB.showTargetOfTarget = self:GetChecked()
end)

-- Disable OnValueChanged during initialization
local isInitializing = true

-- Anchor Point Dropdown
local anchorLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
anchorLabel:SetPoint("TOPLEFT", otherGuildColorLabel, "BOTTOMLEFT", 0, -16)
anchorLabel:SetText("Tooltip Anchor Point:")

local anchorDropdown = CreateFrame("Frame", "MidnightTooltipAnchorDropdown", optionsPanel, "UIDropDownMenuTemplate")
anchorDropdown:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", -15, -5)

local anchorPoints = {
    {text = "Top Left", value = "TOPLEFT"},
    {text = "Top", value = "TOP"},
    {text = "Top Right", value = "TOPRIGHT"},
    {text = "Left", value = "LEFT"},
    {text = "Center", value = "CENTER"},
    {text = "Right", value = "RIGHT"},
    {text = "Bottom Left", value = "BOTTOMLEFT"},
    {text = "Bottom", value = "BOTTOM"},
    {text = "Bottom Right", value = "BOTTOMRIGHT"},
}

local function AnchorDropdown_OnClick(self)
    MidnightTooltipDB.anchorPoint = self.value
    UIDropDownMenu_SetText(anchorDropdown, self:GetText())
    CloseDropDownMenus()
end

local function AnchorDropdown_Initialize(self, level)
    local info = UIDropDownMenu_CreateInfo()
    for _, anchor in ipairs(anchorPoints) do
        info.text = anchor.text
        info.value = anchor.value
        info.func = AnchorDropdown_OnClick
        info.checked = (MidnightTooltipDB.anchorPoint == anchor.value)
        UIDropDownMenu_AddButton(info)
    end
end

UIDropDownMenu_Initialize(anchorDropdown, AnchorDropdown_Initialize)
UIDropDownMenu_SetWidth(anchorDropdown, 120)

-- Set initial text
local function GetAnchorText(value)
    for _, anchor in ipairs(anchorPoints) do
        if anchor.value == value then
            return anchor.text
        end
    end
    return "Bottom"
end
UIDropDownMenu_SetText(anchorDropdown, GetAnchorText(MidnightTooltipDB.anchorPoint or "BOTTOM"))

-- X Offset slider
local offsetXLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
offsetXLabel:SetPoint("TOPLEFT", targetOfTargetCheckbox, "BOTTOMLEFT", 0, -16)
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
        if addon and addon.RefreshSettingsCache then
            addon.RefreshSettingsCache()
        end
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
        if addon and addon.RefreshSettingsCache then
            addon.RefreshSettingsCache()
        end
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

-- Fade Out Delay slider
local fadeOutLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
fadeOutLabel:SetPoint("TOPLEFT", offsetYSlider, "BOTTOMLEFT", -20, -16)
fadeOutLabel:SetText("Tooltip Fade Out Delay")

local fadeOutSlider = CreateFrame("Slider", "MidnightTooltipFadeOutSlider", optionsPanel, "OptionsSliderTemplate")
fadeOutSlider:SetPoint("TOPLEFT", fadeOutLabel, "BOTTOMLEFT", 20, -8)
fadeOutSlider:SetMinMaxValues(0, 2)
fadeOutSlider:SetValueStep(0.1)
fadeOutSlider:SetObeyStepOnDrag(true)
fadeOutSlider:SetWidth(260)
fadeOutSlider.Low:SetText("0.0s")
fadeOutSlider.High:SetText("2.0s")
fadeOutSlider.Text:SetText(string.format("%.1fs", MidnightTooltipDB.fadeOutDelay or 0.2))
fadeOutSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value * 10 + 0.5) / 10
    self.Text:SetText(string.format("%.1fs", value))
    if not isInitializing then
        MidnightTooltipDB.fadeOutDelay = value
        if addon and addon.RefreshSettingsCache then
            addon.RefreshSettingsCache()
        end
    end
end)

-- Fade Out Delay decrease button
local fadeOutDecBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
fadeOutDecBtn:SetPoint("RIGHT", fadeOutSlider, "LEFT", -5, 0)
fadeOutDecBtn:SetSize(20, 20)
fadeOutDecBtn:SetText("<")
fadeOutDecBtn:SetScript("OnClick", function()
    local value = fadeOutSlider:GetValue() - 0.1
    fadeOutSlider:SetValue(value)
end)

-- Fade Out Delay increase button
local fadeOutIncBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
fadeOutIncBtn:SetPoint("LEFT", fadeOutSlider, "RIGHT", 5, 0)
fadeOutIncBtn:SetSize(20, 20)
fadeOutIncBtn:SetText(">")
fadeOutIncBtn:SetScript("OnClick", function()
    local value = fadeOutSlider:GetValue() + 0.1
    fadeOutSlider:SetValue(value)
end)

-- Tooltip Scale slider
local scaleLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
scaleLabel:SetPoint("TOPLEFT", fadeOutSlider, "BOTTOMLEFT", -20, -16)
scaleLabel:SetText("Tooltip Scale")

local scaleSlider = CreateFrame("Slider", "MidnightTooltipScaleSlider", optionsPanel, "OptionsSliderTemplate")
scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 20, -8)
scaleSlider:SetMinMaxValues(50, 200)
scaleSlider:SetValueStep(5)
scaleSlider:SetObeyStepOnDrag(true)
scaleSlider:SetWidth(260)
scaleSlider.Low:SetText("50%")
scaleSlider.High:SetText("200%")
scaleSlider.Text:SetText(string.format("%d%%", MidnightTooltipDB.tooltipScale or 100))
scaleSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value / 5 + 0.5) * 5
    self.Text:SetText(string.format("%d%%", value))
    if not isInitializing then
        MidnightTooltipDB.tooltipScale = value
        if addon and addon.RefreshSettingsCache then
            addon.RefreshSettingsCache()
        end
    end
end)

-- Tooltip Scale decrease button
local scaleDecBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
scaleDecBtn:SetPoint("RIGHT", scaleSlider, "LEFT", -5, 0)
scaleDecBtn:SetSize(20, 20)
scaleDecBtn:SetText("<")
scaleDecBtn:SetScript("OnClick", function()
    local value = scaleSlider:GetValue() - 5
    scaleSlider:SetValue(value)
end)

-- Tooltip Scale increase button
local scaleIncBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
scaleIncBtn:SetPoint("LEFT", scaleSlider, "RIGHT", 5, 0)
scaleIncBtn:SetSize(20, 20)
scaleIncBtn:SetText(">")
scaleIncBtn:SetScript("OnClick", function()
    local value = scaleSlider:GetValue() + 5
    scaleSlider:SetValue(value)
end)

-- Info text about reloading
local reloadInfo = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
reloadInfo:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -24)
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
    -- Update all checkboxes
    cursorAnchorCheckbox:SetChecked(defaults.enableCursorAnchor)
    cursorOnlyModeCheckbox:SetChecked(defaults.cursorOnlyMode)
    hideCombatCheckbox:SetChecked(defaults.hideTooltipsInCombat)
    qualityBorderCheckbox:SetChecked(defaults.enableQualityBorder)
    classColorsCheckbox:SetChecked(defaults.showClassColors)
    UIDropDownMenu_SetText(anchorDropdown, GetAnchorText(defaults.anchorPoint))
    guildColorsCheckbox:SetChecked(defaults.showGuildColors)
    playerStatusCheckbox:SetChecked(defaults.showPlayerStatus)
    mountInfoCheckbox:SetChecked(defaults.showMountInfo)
    iLevelCheckbox:SetChecked(defaults.showItemLevel)
    factionCheckbox:SetChecked(defaults.showFaction)
    roleIconCheckbox:SetChecked(defaults.showRoleIcon)
    mythicRatingCheckbox:SetChecked(defaults.showMythicRating)
    targetOfTargetCheckbox:SetChecked(defaults.showTargetOfTarget)
    -- Update sliders
    offsetXSlider:SetValue(defaults.cursorOffsetX)
    offsetYSlider:SetValue(defaults.cursorOffsetY)
    fadeOutSlider:SetValue(defaults.fadeOutDelay)
    scaleSlider:SetValue(defaults.tooltipScale)
    -- Reset color swatches
    myGuildColorTexture:SetVertexColor(defaults.customGuildColorR, defaults.customGuildColorG, defaults.customGuildColorB)
    otherGuildColorTexture:SetVertexColor(defaults.customOtherGuildColorR, defaults.customOtherGuildColorG, defaults.customOtherGuildColorB)
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

-- Create Profiles Panel
local profilesPanel = CreateFrame("Frame", "MidnightTooltipProfilesPanel", UIParent)
profilesPanel.name = "Profiles"
profilesPanel.parent = "MidnightTooltip"

-- Forward declare RefreshUI so it can be used in profile loading
local RefreshUI

-- Profiles Title
local profilesTitle = profilesPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
profilesTitle:SetPoint("TOPLEFT", 16, -16)
profilesTitle:SetText("Profile Management")

-- Profiles Description
local profilesDescription = profilesPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
profilesDescription:SetPoint("TOPLEFT", profilesTitle, "BOTTOMLEFT", 0, -8)
profilesDescription:SetText("Save and load your settings across characters")

-- Profile name input
local profileNameLabel = profilesPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
profileNameLabel:SetPoint("TOPLEFT", profilesDescription, "BOTTOMLEFT", 0, -24)
profileNameLabel:SetText("Profile Name:")

local profileNameEditBox = CreateFrame("EditBox", "MidnightTooltipProfileName", profilesPanel, "InputBoxTemplate")
profileNameEditBox:SetPoint("TOPLEFT", profileNameLabel, "BOTTOMLEFT", 10, -8)
profileNameEditBox:SetSize(200, 25)
profileNameEditBox:SetAutoFocus(false)
profileNameEditBox:SetMaxLetters(32)

-- Current profile indicator
local currentProfileLabel = profilesPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
currentProfileLabel:SetPoint("TOPLEFT", profileNameEditBox, "BOTTOMLEFT", -10, -16)
currentProfileLabel:SetText("")

-- Function to update the current profile indicator
local function UpdateCurrentProfileIndicator()
    local currentProfile = MidnightTooltipDB.currentProfile
    if currentProfile then
        currentProfileLabel:SetText("|cFF00FF00Active Profile: " .. currentProfile .. "|r")
    else
        currentProfileLabel:SetText("|cFFFF6600No profile loaded|r")
    end
end

-- Save Profile button
local saveProfileButton = CreateFrame("Button", "MidnightTooltipSaveProfile", profilesPanel, "UIPanelButtonTemplate")
saveProfileButton:SetPoint("LEFT", profileNameEditBox, "RIGHT", 10, 0)
saveProfileButton:SetSize(100, 25)
saveProfileButton:SetText("Save Profile")
saveProfileButton:SetScript("OnClick", function()
    local profileName = profileNameEditBox:GetText()
    if profileName and profileName ~= "" then
        -- Save current settings to profile
        MidnightTooltipProfiles[profileName] = {}
        for k, v in pairs(MidnightTooltipDB) do
            MidnightTooltipProfiles[profileName][k] = v
        end
        MidnightTooltipDB.currentProfile = profileName
        print("|cFF00FFFFMidnightTooltip|r: Profile '" .. profileName .. "' saved.")
        profileNameEditBox:SetText("")
        UpdateCurrentProfileIndicator()
        -- Refresh profile list
        if profilesPanel.RefreshProfileList then
            profilesPanel:RefreshProfileList()
        end
    else
        print("|cFF00FFFFMidnightTooltip|r: Please enter a profile name.")
    end
end)

-- Saved Profiles section
local savedProfilesLabel = profilesPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
savedProfilesLabel:SetPoint("TOPLEFT", currentProfileLabel, "BOTTOMLEFT", 10, -16)
savedProfilesLabel:SetText("Saved Profiles:")

-- Scroll frame for profiles
local profileScrollFrame = CreateFrame("ScrollFrame", "MidnightTooltipProfileScroll", profilesPanel, "UIPanelScrollFrameTemplate")
profileScrollFrame:SetPoint("TOPLEFT", savedProfilesLabel, "BOTTOMLEFT", 0, -8)
profileScrollFrame:SetSize(500, 300)

local profileScrollChild = CreateFrame("Frame", nil, profileScrollFrame)
profileScrollChild:SetSize(480, 1)
profileScrollFrame:SetScrollChild(profileScrollChild)

-- Function to refresh profile list
function profilesPanel:RefreshProfileList()
    -- Clear existing buttons
    for _, child in ipairs({profileScrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Count profiles
    local profileCount = 0
    for _ in pairs(MidnightTooltipProfiles) do
        profileCount = profileCount + 1
    end
    
    if profileCount == 0 then
        -- Show "no profiles" message
        local noProfilesText = profileScrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        noProfilesText:SetPoint("TOPLEFT", 10, -10)
        noProfilesText:SetText("No profiles saved yet. Create one using the form above.")
        return
    end
    
    local yOffset = 0
    local currentProfile = MidnightTooltipDB.currentProfile
    
    for profileName, profileData in pairs(MidnightTooltipProfiles) do
        local isCurrentProfile = (currentProfile == profileName)
        
        -- Profile container
        local profileFrame = CreateFrame("Frame", nil, profileScrollChild, "BackdropTemplate")
        profileFrame:SetPoint("TOPLEFT", 0, yOffset)
        profileFrame:SetSize(480, 30)
        profileFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        -- Highlight current profile
        if isCurrentProfile then
            profileFrame:SetBackdropColor(0.2, 0.3, 0.2, 0.7)
            profileFrame:SetBackdropBorderColor(0.2, 0.8, 0.2, 1)
        else
            profileFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
            profileFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        end
        
        -- Profile name text
        local profileText = profileFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        profileText:SetPoint("LEFT", 10, 0)
        if isCurrentProfile then
            profileText:SetText(profileName .. " |cFF00FF00(Active)|r")
        else
            profileText:SetText(profileName)
        end
        
        -- Save button (only enabled for active profile)
        local saveButton = CreateFrame("Button", nil, profileFrame, "UIPanelButtonTemplate")
        saveButton:SetPoint("RIGHT", -205, 0)
        saveButton:SetSize(75, 22)
        saveButton:SetText("Save")
        if isCurrentProfile then
            saveButton:Enable()
            saveButton:SetScript("OnClick", function()
                -- Update the current profile with current settings
                MidnightTooltipProfiles[profileName] = {}
                for k, v in pairs(MidnightTooltipDB) do
                    if k ~= "currentProfile" then
                        MidnightTooltipProfiles[profileName][k] = v
                    end
                end
                print("|cFF00FFFFMidnightTooltip|r: Profile '" .. profileName .. "' saved.")
                profilesPanel:RefreshProfileList()
            end)
        else
            saveButton:Disable()
        end
        
        -- Load button
        local loadButton = CreateFrame("Button", nil, profileFrame, "UIPanelButtonTemplate")
        loadButton:SetPoint("RIGHT", -120, 0)
        loadButton:SetSize(75, 22)
        loadButton:SetText("Load")
        loadButton:SetScript("OnClick", function()
            -- Load profile settings
            for k, v in pairs(profileData) do
                MidnightTooltipDB[k] = v
            end
            MidnightTooltipDB.currentProfile = profileName
            print("|cFF00FFFFMidnightTooltip|r: Profile '" .. profileName .. "' loaded. Reload UI to apply changes.")
            RefreshUI()
            UpdateCurrentProfileIndicator()
            profilesPanel:RefreshProfileList()
        end)
        
        -- Delete button (don't allow deleting Default profile)
        if profileName ~= "Default" then
            local deleteButton = CreateFrame("Button", nil, profileFrame, "UIPanelButtonTemplate")
            deleteButton:SetPoint("RIGHT", -10, 0)
            deleteButton:SetSize(100, 22)
            deleteButton:SetText("Delete")
            deleteButton:SetScript("OnClick", function()
                StaticPopup_Show("MIDNIGHTTOOLTIP_DELETE_PROFILE", profileName, nil, profileName)
            end)
        end
        
        yOffset = yOffset - 35
    end
    
    profileScrollChild:SetHeight(math.max(math.abs(yOffset) + 10, 1))
end

-- Delete confirmation dialog
StaticPopupDialogs["MIDNIGHTTOOLTIP_DELETE_PROFILE"] = {
    text = "Delete profile '%s'?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, data)
        local profileName = data
        if not profileName then return end
        
        -- Ensure tables exist
        MidnightTooltipProfiles = MidnightTooltipProfiles or {}
        MidnightTooltipDB = MidnightTooltipDB or {}
        
        MidnightTooltipProfiles[profileName] = nil
        -- Clear current profile if we're deleting the active one
        if MidnightTooltipDB.currentProfile == profileName then
            MidnightTooltipDB.currentProfile = nil
        end
        print("|cFF00FFFFMidnightTooltip|r: Profile '" .. profileName .. "' deleted.")
        if profilesPanel and profilesPanel.RefreshProfileList then
            profilesPanel:RefreshProfileList()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Refresh profile list when panel is shown
profilesPanel:SetScript("OnShow", function(self)
    UpdateCurrentProfileIndicator()
    self:RefreshProfileList()
end)

-- Initial population of profile list (in case panel is already visible)
C_Timer.After(0, function()
    if profilesPanel:IsVisible() then
        UpdateCurrentProfileIndicator()
        profilesPanel:RefreshProfileList()
    end
end)

-- Register profiles panel
if Settings and Settings.RegisterCanvasLayoutSubcategory then
    local profileCategory = Settings.RegisterCanvasLayoutSubcategory(category, profilesPanel, profilesPanel.name)
end

-- Function to refresh UI with current values
RefreshUI = function()
    cursorAnchorCheckbox:SetChecked(MidnightTooltipDB.enableCursorAnchor)
    cursorOnlyModeCheckbox:SetChecked(MidnightTooltipDB.cursorOnlyMode)
    hideCombatCheckbox:SetChecked(MidnightTooltipDB.hideTooltipsInCombat)
    qualityBorderCheckbox:SetChecked(MidnightTooltipDB.enableQualityBorder)
    classColorsCheckbox:SetChecked(MidnightTooltipDB.showClassColors)
    UIDropDownMenu_SetText(anchorDropdown, GetAnchorText(MidnightTooltipDB.anchorPoint or "BOTTOM"))
    guildColorsCheckbox:SetChecked(MidnightTooltipDB.showGuildColors)
    playerStatusCheckbox:SetChecked(MidnightTooltipDB.showPlayerStatus)
    mountInfoCheckbox:SetChecked(MidnightTooltipDB.showMountInfo)
    iLevelCheckbox:SetChecked(MidnightTooltipDB.showItemLevel)
    factionCheckbox:SetChecked(MidnightTooltipDB.showFaction)
    roleIconCheckbox:SetChecked(MidnightTooltipDB.showRoleIcon)
    mythicRatingCheckbox:SetChecked(MidnightTooltipDB.showMythicRating)
    targetOfTargetCheckbox:SetChecked(MidnightTooltipDB.showTargetOfTarget)
    offsetXSlider:SetValue(MidnightTooltipDB.cursorOffsetX)
    offsetYSlider:SetValue(MidnightTooltipDB.cursorOffsetY)
    fadeOutSlider:SetValue(MidnightTooltipDB.fadeOutDelay or 0.2)
    scaleSlider:SetValue(MidnightTooltipDB.tooltipScale or 100)
    -- Refresh color swatches
    myGuildColorTexture:SetVertexColor(
        MidnightTooltipDB.customGuildColorR or 1.0,
        MidnightTooltipDB.customGuildColorG or 0.2,
        MidnightTooltipDB.customGuildColorB or 1.0
    )
    otherGuildColorTexture:SetVertexColor(
        MidnightTooltipDB.customOtherGuildColorR or 0.0,
        MidnightTooltipDB.customOtherGuildColorG or 0.502,
        MidnightTooltipDB.customOtherGuildColorB or 0.8
    )
end

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
    if category and category.GetID then
        local success, err = pcall(function()
            Settings.OpenToCategory(category:GetID())
        end)
        if not success then
            print("|cFF00FFFFMidnightTooltip|r: Could not open settings panel.")
        end
    else
        print("|cFF00FFFFMidnightTooltip|r: Settings panel not registered.")
    end
end
