-- MidnightTooltip.lua
-- Anchors game tooltips to follow the mouse cursor

local addonName, addon = ...
local MidnightTooltip = {}
local originalSetDefaultAnchor = GameTooltip_SetDefaultAnchor

-- Cache settings to avoid repeated lookups
local settingsCache = {}
local function RefreshSettingsCache()
    local db = MidnightTooltipDB or {}
    local function getSetting(key, default)
        if addon and addon.GetSetting then
            return addon.GetSetting(key)
        end
        local val = db[key]
        if val ~= nil then return val end
        return default
    end
    
    settingsCache.enableCursorAnchor = getSetting("enableCursorAnchor", true)
    settingsCache.enableQualityBorder = getSetting("enableQualityBorder", true)
    settingsCache.cursorOffsetX = getSetting("cursorOffsetX", 0)
    settingsCache.cursorOffsetY = getSetting("cursorOffsetY", 0)
    settingsCache.showGuildColors = getSetting("showGuildColors", true)
    settingsCache.showPlayerStatus = getSetting("showPlayerStatus", true)
    settingsCache.showMountInfo = getSetting("showMountInfo", true)
    settingsCache.showItemLevel = getSetting("showItemLevel", true)
    settingsCache.showFaction = getSetting("showFaction", true)
    settingsCache.showRoleIcon = getSetting("showRoleIcon", true)
    settingsCache.showMythicRating = getSetting("showMythicRating", true)
    settingsCache.showTargetOfTarget = getSetting("showTargetOfTarget", true)
    -- Custom colors
    settingsCache.customGuildColorR = getSetting("customGuildColorR", 1.0)
    settingsCache.customGuildColorG = getSetting("customGuildColorG", 0.2)
    settingsCache.customGuildColorB = getSetting("customGuildColorB", 1.0)
    settingsCache.customOtherGuildColorR = getSetting("customOtherGuildColorR", 0.0)
    settingsCache.customOtherGuildColorG = getSetting("customOtherGuildColorG", 0.502)
    settingsCache.customOtherGuildColorB = getSetting("customOtherGuildColorB", 0.8)
end

-- Pattern for stripping color codes (compiled once, localized)
local COLOR_CODE_PATTERN = "|c%x%x%x%x%x%x%x%x"
local COLOR_RESET_PATTERN = "|r"
local gsub = string.gsub
local format = string.format
local floor = math.floor

-- Override the SetDefaultAnchor function completely
function GameTooltip_SetDefaultAnchor(tooltip, parent)
    if InCombatLockdown() then
        return
    end
    
    if settingsCache.enableCursorAnchor then
        tooltip:SetOwner(parent, "ANCHOR_CURSOR")
    else
        originalSetDefaultAnchor(tooltip, parent)
    end
end

-- Hook to update tooltip position with offset
local lastUpdateTime = 0
local UPDATE_THROTTLE = 0.01 -- Update every 0.01 seconds (100 FPS)
local function UpdateTooltipPosition(tooltip, elapsed)
    lastUpdateTime = lastUpdateTime + elapsed
    if lastUpdateTime < UPDATE_THROTTLE then return end
    lastUpdateTime = 0
    
    if not settingsCache.enableCursorAnchor then return end
    
    tooltip:ClearAllPoints()
    local x, y = GetCursorPosition()
    local scale = tooltip:GetEffectiveScale()
    tooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (x / scale) + settingsCache.cursorOffsetX, (y / scale) + settingsCache.cursorOffsetY)
end

-- Helper to set border color
local function SetBorderColor(tooltip, r, g, b)
    if tooltip.NineSlice then
        tooltip.NineSlice:SetBorderColor(r, g, b, 1)
    end
    if tooltip.SetBackdropBorderColor then
        tooltip:SetBackdropBorderColor(r, g, b, 1)
    end
end

-- Function to color tooltip border based on item quality
local function ColorTooltipBorder(tooltip, data)
    if InCombatLockdown() then
        return
    end
    
    if not settingsCache.enableQualityBorder then
        SetBorderColor(tooltip, 1, 1, 1)
        return
    end
    
    if data and data.id then
        local quality = C_Item.GetItemQualityByID(data.id)
        if quality and quality >= Enum.ItemQuality.Common then
            local r, g, b = C_Item.GetItemQualityColor(quality)
            SetBorderColor(tooltip, r, g, b)
        end
    else
        SetBorderColor(tooltip, 1, 1, 1)
    end
end

-- Helper to strip color codes from text
local function StripColorCodes(text)
    return gsub(gsub(text, COLOR_CODE_PATTERN, ""), COLOR_RESET_PATTERN, "")
end

-- Function to color tooltip text and border based on unit class/faction
local function ColorTooltipBorderByUnit(tooltip)
    if InCombatLockdown() then
        return
    end
    
    local _, unit = tooltip:GetUnit()
    if not unit then
        if not settingsCache.enableQualityBorder then
            SetBorderColor(tooltip, 1, 1, 1)
        end
        return
    end
    
    local isPlayer = UnitIsPlayer(unit)
    if isPlayer then
        local _, class = UnitClass(unit)
        if not class then return end
        
        local color = C_ClassColor.GetClassColor(class)
        if not color then return end
        
        local tooltipName = tooltip:GetName()
        
        -- Color the name (line 1) and add status prefix
        local nameText = _G[tooltipName .. "TextLeft1"]
        if nameText then
            local success, name = pcall(nameText.GetText, nameText)
            if success and name then
                local prefix = ""
                if settingsCache.showPlayerStatus then
                    if UnitIsAFK(unit) then
                        prefix = "|cFF808080[AFK]|r "
                    elseif UnitIsDND(unit) then
                        prefix = "|cFFFF0000[DND]|r "
                    end
                end
                nameText:SetText(prefix .. StripColorCodes(name))
            end
            nameText:SetTextColor(color.r, color.g, color.b)
        end
        
        -- Get guild name and check mount status
        local guildName, isGuildMate
        if settingsCache.showGuildColors then
            guildName = GetGuildInfo(unit)
            isGuildMate = UnitIsInMyGuild(unit)
        end
        
        local mountName, mountOwned
        if settingsCache.showMountInfo then
            for i = 1, 40 do
                local auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
                if not auraData or not auraData.spellId then
                    if not auraData then break end
                else
                    local mountID = C_MountJournal.GetMountFromSpell(auraData.spellId)
                    if mountID then
                        mountName = auraData.name
                        local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
                        mountOwned = isCollected
                        break
                    end
                end
            end
        end
        
        -- Color all lines (class, spec, guild, etc)
        for i = 2, tooltip:NumLines() do
            local lineText = _G[tooltipName .. "TextLeft" .. i]
            if lineText then
                local success, text = pcall(lineText.GetText, lineText)
                if success and text and type(text) == "string" then
                    -- Skip lines that might contain cooldown info (these are often secret values)
                    local isCooldownLine = text:match("Recharging") or text:match("sec") or text:match("min") or text:match("Cooldown") or text:match("cooldown")
                    
                    if not isCooldownLine then
                        local cleanText = StripColorCodes(text)
                        
                        if guildName and cleanText == guildName then
                            lineText:SetText(cleanText)
                            if isGuildMate then
                                lineText:SetTextColor(settingsCache.customGuildColorR, settingsCache.customGuildColorG, settingsCache.customGuildColorB)
                            else
                                lineText:SetTextColor(settingsCache.customOtherGuildColorR, settingsCache.customOtherGuildColorG, settingsCache.customOtherGuildColorB)
                            end
                        elseif cleanText:match("Horde") or cleanText:match("Alliance") then
                            if settingsCache.showFaction then
                                if cleanText:match("Horde") then
                                    lineText:SetTextColor(1.0, 0.0, 0.0)
                                else
                                    lineText:SetTextColor(0.0, 0.44, 0.87)
                                end
                            else
                                lineText:SetText("")  -- Hide the line
                            end
                        elseif not cleanText:match("^Level") then
                            lineText:SetTextColor(color.r, color.g, color.b)
                        end
                    end
                end
            end
        end
        
        -- Get player's item level
        if settingsCache.showItemLevel then
            local _, avgItemLevel = GetAverageItemLevel(unit)
            if avgItemLevel and avgItemLevel > 0 then
                -- Color based on Midnight Season 1 item level ranges (max 289)
                local ilvlColor
                if avgItemLevel >= 285 then
                    ilvlColor = "|cFFFF8000" -- Legendary orange (Mythic raid/high M+ vault)
                elseif avgItemLevel >= 270 then
                    ilvlColor = "|cFFA335EE" -- Epic purple (Heroic raid/high M+)
                elseif avgItemLevel >= 260 then
                    ilvlColor = "|cFF0070DD" -- Rare blue (Normal raid/mid M+)
                else
                    ilvlColor = "|cFF1EFF00" -- Uncommon green (Leveling/early endgame)
                end
                tooltip:AddLine(format("|cFFFFFFFFItem Level: |r%s%d|r", ilvlColor, floor(avgItemLevel)))
            end
        end
        
        -- Show role icon
        if settingsCache.showRoleIcon then
            local role = UnitGroupRolesAssigned(unit)
            if role and role ~= "NONE" then
                local roleText = ""
                if role == "TANK" then
                    roleText = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:0:19:22:41|t Tank"
                elseif role == "HEALER" then
                    roleText = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:1:20|t Healer"
                elseif role == "DAMAGER" then
                    roleText = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:22:41|t DPS"
                end
                if roleText ~= "" then
                    tooltip:AddLine(roleText, 1, 1, 1)
                end
            end
        end
        
        -- Show Mythic+ rating
        if settingsCache.showMythicRating then
            local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
            if summary and summary.currentSeasonScore and summary.currentSeasonScore > 0 then
                local rating = summary.currentSeasonScore
                local ratingColor
                if rating >= 2500 then
                    ratingColor = "|cFFFF8000" -- Orange
                elseif rating >= 2000 then
                    ratingColor = "|cFFA335EE" -- Purple
                elseif rating >= 1500 then
                    ratingColor = "|cFF0070DD" -- Blue
                else
                    ratingColor = "|cFF1EFF00" -- Green
                end
                tooltip:AddLine("|cFFFFFFFFM+ Rating: |r" .. ratingColor .. rating .. "|r", 1, 1, 1)
            end
        end
        
        -- Show target of target
        if settingsCache.showTargetOfTarget then
            local targetUnit = unit .. "target"
            if UnitExists(targetUnit) then
                local targetName = UnitName(targetUnit)
                if targetName then
                    local targetColor = "|cFFFFFFFF"
                    if UnitIsPlayer(targetUnit) then
                        local _, targetClass = UnitClass(targetUnit)
                        if targetClass then
                            local classColor = C_ClassColor.GetClassColor(targetClass)
                            if classColor then
                                targetColor = format("|cFF%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
                            end
                        end
                    elseif not UnitPlayerControlled(targetUnit) then
                        local reaction = UnitReaction(targetUnit, "player")
                        if reaction then
                            if reaction >= 5 then
                                targetColor = "|cFF00FF00" -- Friendly
                            elseif reaction == 4 then
                                targetColor = "|cFFFFFF00" -- Neutral
                            else
                                targetColor = "|cFFFF0000" -- Hostile
                            end
                        end
                    end
                    tooltip:AddLine("|cFFFFFFFFTarget: |r" .. targetColor .. targetName .. "|r", 1, 1, 1)
                end
            end
        end
        
        -- Add mount info if mounted
        if mountName then
            if mountOwned then
                tooltip:AddLine(mountName .. " |cFF00FF00[Collected]|r", 0.6, 0.8, 1.0)
            else
                tooltip:AddLine(mountName .. " |cFFFF4D4D[Not Collected]|r", 0.6, 0.8, 1.0)
            end
        end
        
        -- Color border
        if settingsCache.enableQualityBorder then
            SetBorderColor(tooltip, color.r, color.g, color.b)
        end
    else
        -- For NPCs, use reaction color
        local reaction = UnitReaction(unit, "player")
        if reaction and settingsCache.enableQualityBorder then
            local r, g, b
            if reaction >= 5 then
                r, g, b = 0.0, 1.0, 0.0 -- Friendly
            elseif reaction == 4 then
                r, g, b = 1.0, 1.0, 0.0 -- Neutral
            else
                r, g, b = 1.0, 0.0, 0.0 -- Hostile
            end
            SetBorderColor(tooltip, r, g, b)
        end
    end
end

function MidnightTooltip:OnInitialize()
    -- Wait for config to load, then initialize settings cache
    C_Timer.After(0, function()
        RefreshSettingsCache()
    end)
    
    -- Hook OnUpdate to continuously update tooltip position
    GameTooltip:HookScript("OnUpdate", function(self, elapsed)
        if settingsCache.enableCursorAnchor and self:IsShown() then
            UpdateTooltipPosition(self, elapsed)
        end
    end)
    
    -- Hook tooltip item display to color border
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ColorTooltipBorder)
    
    -- Hook tooltip unit display to color border by class/reaction
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
        ColorTooltipBorderByUnit(tooltip)
    end)
    
    -- Handle ItemRefTooltip (shift-click links)
    if ItemRefTooltip then
        ItemRefTooltip:HookScript("OnShow", function(self)
            self:SetOwner(UIParent, "ANCHOR_CURSOR")
        end)
    end
    
    -- Handle shopping tooltips (comparison tooltips)
    if ShoppingTooltip1 then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if tooltip == ShoppingTooltip1 then
                ColorTooltipBorder(tooltip, data)
            end
        end)
    end
    
    if ShoppingTooltip2 then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if tooltip == ShoppingTooltip2 then
                ColorTooltipBorder(tooltip, data)
            end
        end)
    end
    
    -- Hook the comparison tooltip function to position them properly
    hooksecurefunc("GameTooltip_ShowCompareItem", function(self, anchorFrame)
        if ShoppingTooltip1 and ShoppingTooltip1:IsShown() then
            ShoppingTooltip1:ClearAllPoints()
            ShoppingTooltip1:SetPoint("TOPRIGHT", GameTooltip, "TOPLEFT", -2, 0)
        end
        if ShoppingTooltip2 and ShoppingTooltip2:IsShown() then
            ShoppingTooltip2:ClearAllPoints()
            ShoppingTooltip2:SetPoint("TOPRIGHT", ShoppingTooltip1, "TOPLEFT", -2, 0)
        end
    end)
end

function MidnightTooltip:OnEnable()
    print("|cFF00FFFFMidnightTooltip|r: Loaded. Type /mtt to open options.")
end

-- Slash command to reload UI
SLASH_MIDNIGHTRELOAD1 = "/mttr"
SlashCmdList["MIDNIGHTRELOAD"] = function()
    ReloadUI()
end

-- Slash command
SLASH_MIDNIGHT1 = "/midnighttooltip"
SLASH_MIDNIGHT2 = "/mtt"
SlashCmdList["MIDNIGHT"] = function(msg)
    -- Refresh cache when opening options
    RefreshSettingsCache()
    if addon and addon.OpenOptions then
        addon.OpenOptions()
    else
        print("|cFF00FFFFMidnightTooltip|r: Opening settings...")
        C_Timer.After(0.1, function()
            if addon and addon.OpenOptions then
                addon.OpenOptions()
            end
        end)
    end
end

-- Main entry point
function MidnightTooltip:Start()
    self:OnInitialize()
    self:OnEnable()
end

-- Start the addon
MidnightTooltip:Start()

-- Return the addon table
return MidnightTooltip
