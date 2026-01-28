-- MidnightTooltip.lua
-- Anchors game tooltips to follow the mouse cursor

local addonName, addon = ...
local MidnightTooltip = {}

-- Cache settings to avoid repeated lookups
local settingsCache = {}
local function RefreshSettingsCache()
    -- Check both MidnightTooltipDB (standalone) and addon.GetSetting (with config)
    local db = MidnightTooltipDB or {}
    local function getSetting(key, default)
        -- First try direct DB access
        if db[key] ~= nil then 
            return db[key]
        end
        -- Then try addon function
        if addon and addon.GetSetting then
            local val = addon.GetSetting(key)
            if val ~= nil then return val end
        end
        return default
    end
    
    settingsCache.enableCursorAnchor = getSetting("enableCursorAnchor", true)
    settingsCache.cursorOnlyMode = getSetting("cursorOnlyMode", false)
    settingsCache.hideTooltipsInCombat = getSetting("hideTooltipsInCombat", false)
    settingsCache.enableQualityBorder = getSetting("enableQualityBorder", true)
    settingsCache.anchorPoint = getSetting("anchorPoint", "BOTTOM")
    settingsCache.cursorOffsetX = getSetting("cursorOffsetX", 0)
    settingsCache.cursorOffsetY = getSetting("cursorOffsetY", 0)
    settingsCache.fadeOutDelay = getSetting("fadeOutDelay", 0.2)
    settingsCache.showClassColors = getSetting("showClassColors", true)
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

-- Cache whether we're in a restricted environment (dungeon/raid)
local isInRestrictedInstance = false

-- Update the cached restricted state
local function UpdateRestrictedState()
    local inInstance, instanceType = IsInInstance()
    
    if not inInstance then 
        isInRestrictedInstance = false
    else
        -- Disable in dungeons (party), raids, and scenarios
        isInRestrictedInstance = instanceType == "party" or instanceType == "raid" or instanceType == "scenario"
    end
end

-- Force refresh hooks with current settings
local function RefreshHooks()
    RefreshSettingsCache()
    UpdateRestrictedState()
    -- Clear cached position values
    cachedScale = nil
    cachedAnchorPoint = nil
    cachedOffsetX = nil
    cachedOffsetY = nil
end

-- Hook to update tooltip position with offset
local cachedScale, cachedAnchorPoint, cachedOffsetX, cachedOffsetY
local function UpdateTooltipPosition(tooltip, elapsed)
    -- Skip if tooltip has no owner
    local owner = tooltip:GetOwner()
    if not owner then return end
    
    -- Check if tooltip is anchored to a specific UI element (not UIParent or cursor-following)
    -- This prevents us from fighting with game's default positioning for quest tooltips, etc.
    local point, relativeTo, relativePoint = tooltip:GetPoint(1)
    if relativeTo and relativeTo ~= UIParent and relativeTo ~= tooltip:GetParent() then
        -- Tooltip is anchored to a specific frame (like a quest button), don't touch it
        return
    end
    
    -- Skip quest tooltips and other default-anchored tooltips
    -- Check if the owner is a quest frame, world map frame, or other UI element that should use default positioning
    local ownerName = owner:GetName()
    if ownerName then
        -- Don't reposition tooltips owned by quest frames, world map, achievement frames, etc.
        if ownerName:find("Quest") or ownerName:find("WorldMap") or ownerName:find("Achievement") or 
           ownerName:find("Objective") or ownerName:find("Scenario") or ownerName:find("QuestInfo") then
            return
        end
    end
    
    -- Only reposition tooltips that show items or units (not quests, achievements, etc)
    local hasItem = tooltip.GetItem and select(1, pcall(tooltip.GetItem, tooltip))
    local hasUnit = tooltip.GetUnit and select(1, pcall(tooltip.GetUnit, tooltip)) and select(3, pcall(tooltip.GetUnit, tooltip))
    
    -- If tooltip doesn't have an item or unit, it's probably a quest/achievement tooltip - don't reposition
    if not hasItem and not hasUnit then
        return
    end
    
    -- Cache these values to avoid repeated lookups
    if not cachedAnchorPoint then
        cachedAnchorPoint = settingsCache.anchorPoint or "BOTTOM"
        cachedOffsetX = settingsCache.cursorOffsetX
        cachedOffsetY = settingsCache.cursorOffsetY
    end
    
    local x, y = GetCursorPosition()
    
    -- Cache scale calculation
    if not cachedScale then
        cachedScale = tooltip:GetEffectiveScale()
    end
    
    -- Always reposition to cursor
    tooltip:ClearAllPoints()
    tooltip:SetPoint(cachedAnchorPoint, UIParent, "BOTTOMLEFT", (x / cachedScale) + cachedOffsetX, (y / cachedScale) + cachedOffsetY)
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
    -- Wrap in pcall to prevent tainting secure quest tooltips
    -- GetUnit returns (name, unit), so pcall returns (success, name, unit)
    local success, _, unit = pcall(tooltip.GetUnit, tooltip)
    if not success or not unit then
        if not settingsCache.enableQualityBorder then
            SetBorderColor(tooltip, 1, 1, 1)
        end
        return
    end
    
    -- Check if unit actually exists (prevents issues with quest/item tooltips)
    if not UnitExists(unit) then
        return
    end
    
    -- Additional check: only process if this is actually a player or NPC unit
    -- Skip if tooltip name doesn't match GameTooltip (prevents quest/item tooltip processing)
    if tooltip:GetName() ~= "GameTooltip" then
        return
    end
    
    -- Direct UnitIsPlayer check (pcall unnecessary here)
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
            if settingsCache.showClassColors then
                nameText:SetTextColor(color.r, color.g, color.b)
            end
        end
        
        -- Get guild name and check mount status
        local guildName = settingsCache.showGuildColors and GetGuildInfo(unit)
        local isGuildMate = guildName and UnitIsInMyGuild(unit)
        
        local mountName, mountOwned
        if settingsCache.showMountInfo then
            for i = 1, 40 do
                local auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
                if not auraData then break end
                
                if auraData.spellId then
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
        local numLines = tooltip:NumLines()
        for i = 2, numLines do
            local lineText = _G[tooltipName .. "TextLeft" .. i]
            if lineText then
                local text = lineText:GetText()
                if text then
                    -- Skip lines that might contain cooldown info - combined pattern for efficiency
                    if not text:find("Recharging") and not text:find("sec") and not text:find("min") and not text:find("ooldown") then
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
                        elseif settingsCache.showClassColors and not cleanText:match("^Level") then
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
        if settingsCache.enableQualityBorder and settingsCache.showClassColors then
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
    -- Initialize settings cache with defaults first
    RefreshSettingsCache()
    
    -- Initialize restricted instance state
    UpdateRestrictedState()
    
    -- Reload settings after saved variables are loaded
    C_Timer.After(0.5, function()
        RefreshHooks()
    end)
    
    -- Update restricted state when zone changes
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:SetScript("OnEvent", function()
        UpdateRestrictedState()
    end)
    
    -- Track fade out timing
    local fadeStartTime = nil
    
    -- Reset fade timer and immediately position tooltip when it shows
    GameTooltip:HookScript("OnShow", function(self)
        -- Hide immediately if in combat in restricted instance and setting is enabled
        if isInRestrictedInstance and settingsCache.hideTooltipsInCombat and InCombatLockdown() then
            self:Hide()
            return
        end
        
        fadeStartTime = nil
        self:SetAlpha(1)
        
        -- Immediately position at cursor when tooltip appears
        if settingsCache.enableCursorAnchor then
            self:ClearAllPoints()
            local x, y = GetCursorPosition()
            local scale = self:GetEffectiveScale()
            local anchorPoint = settingsCache.anchorPoint or "BOTTOM"
            local offsetX = settingsCache.cursorOffsetX or 0
            local offsetY = settingsCache.cursorOffsetY or 0
            self:SetPoint(anchorPoint, UIParent, "BOTTOMLEFT", (x / scale) + offsetX, (y / scale) + offsetY)
        end
    end)
    
    -- Override tooltip fade out delay
    hooksecurefunc(GameTooltip, "FadeOut", function(self)
        if settingsCache.fadeOutDelay and settingsCache.fadeOutDelay >= 0 then
            if settingsCache.fadeOutDelay == 0 then
                -- Instant hide for 0 delay
                self:Hide()
                fadeStartTime = nil
                self:SetAlpha(1)
            else
                -- Cancel the default fade by showing the tooltip again
                self:Show()
                -- Store when we started the custom fade
                fadeStartTime = GetTime()
            end
        end
    end)
    
    -- Hook OnUpdate to continuously update tooltip position and handle custom fade
    GameTooltip:HookScript("OnUpdate", function(self, elapsed)
        -- Hide tooltip if in combat in restricted instance and setting is enabled
        if isInRestrictedInstance and settingsCache.hideTooltipsInCombat and InCombatLockdown() then
            if self:IsShown() then
                self:Hide()
            end
            return
        end
        
        -- Reposition if enabled and tooltip is shown (cursor positioning works in dungeons)
        if settingsCache.enableCursorAnchor and self:IsShown() then
            UpdateTooltipPosition(self, elapsed)
        end
        
        -- Handle custom fade out
        if fadeStartTime then
            local fadeTime = GetTime() - fadeStartTime
            local fadeDelay = settingsCache.fadeOutDelay or 0.2
            
            if fadeTime >= fadeDelay then
                -- Fade complete, hide the tooltip
                self:Hide()
                fadeStartTime = nil
                self:SetAlpha(1)
            else
                -- Gradually reduce alpha
                local fadeProgress = fadeTime / fadeDelay
                self:SetAlpha(1 - fadeProgress)
            end
        else
            -- Ensure tooltip is fully opaque when not fading
            if self:GetAlpha() < 1 then
                self:SetAlpha(1)
            end
        end
    end)
    
    -- Hook tooltip item display to color border
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        -- Skip in dungeons/raids or cursor-only mode
        if isInRestrictedInstance or settingsCache.cursorOnlyMode then return end
        ColorTooltipBorder(tooltip, data)
    end)
    
    -- Hook tooltip unit display to color border by class/reaction
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
        -- Cancel any pending fade and reposition when new unit content is set (fixes fast hover flicker)
        if tooltip == GameTooltip then
            fadeStartTime = nil
            tooltip:SetAlpha(1)
            -- Immediately reposition to cursor
            if settingsCache.enableCursorAnchor then
                tooltip:ClearAllPoints()
                local x, y = GetCursorPosition()
                local scale = tooltip:GetEffectiveScale()
                local anchorPoint = settingsCache.anchorPoint or "BOTTOM"
                local offsetX = settingsCache.cursorOffsetX or 0
                local offsetY = settingsCache.cursorOffsetY or 0
                tooltip:SetPoint(anchorPoint, UIParent, "BOTTOMLEFT", (x / scale) + offsetX, (y / scale) + offsetY)
            end
        end
        -- Skip in dungeons/raids or cursor-only mode
        if isInRestrictedInstance or settingsCache.cursorOnlyMode then return end
        ColorTooltipBorderByUnit(tooltip)
    end)
    
    -- -- Handle shopping tooltips (comparison tooltips)
    -- TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    --     if tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2 then
    --         ColorTooltipBorder(tooltip, data)
    --     end
    -- end)
    
    -- -- Hook the comparison tooltip function to position them properly
    -- hooksecurefunc("GameTooltip_ShowCompareItem", function(self, anchorFrame)
    --     if ShoppingTooltip1 and ShoppingTooltip1:IsShown() then
    --         ShoppingTooltip1:ClearAllPoints()
    --         ShoppingTooltip1:SetPoint("TOPRIGHT", GameTooltip, "TOPLEFT", -2, 0)
    --     end
    --     if ShoppingTooltip2 and ShoppingTooltip2:IsShown() then
    --         ShoppingTooltip2:ClearAllPoints()
    --         ShoppingTooltip2:SetPoint("TOPRIGHT", ShoppingTooltip1, "TOPLEFT", -2, 0)
    --     end
    -- end)
end

function MidnightTooltip:OnEnable()
    -- Register slash commands
    SLASH_MIDNIGHTRELOAD1 = "/mttr"
    SlashCmdList["MIDNIGHTRELOAD"] = function()
        ReloadUI()
    end
    
    SLASH_MIDNIGHT1 = "/midnighttooltip"
    SLASH_MIDNIGHT2 = "/mtt"
    SlashCmdList["MIDNIGHT"] = function(msg)
        if addon and addon.OpenOptions then
            addon.OpenOptions()
        else
            print("|cFF00FFFFMidnightTooltip|r: Config addon not loaded.")
        end
    end
    
    SLASH_MIDNIGHTCURSOR1 = "/mttcursor"
    SlashCmdList["MIDNIGHTCURSOR"] = function(msg)
        MidnightTooltipDB.cursorOnlyMode = not MidnightTooltipDB.cursorOnlyMode
        print("|cFF00FFFFMidnightTooltip|r: Cursor-only mode " .. (MidnightTooltipDB.cursorOnlyMode and "enabled" or "disabled") .. ". Type /reload to apply changes.")
    end
    
    print("|cFF00FFFFMidnightTooltip|r: Loaded. Type /mtt for options or /mttcursor to toggle cursor-only mode.")
end

-- Main entry point
function MidnightTooltip:Start()
    self:OnInitialize()
    self:OnEnable()
end

-- Export RefreshSettingsCache to addon
addon.RefreshSettingsCache = RefreshSettingsCache
addon.RefreshHooks = RefreshHooks

-- Start the addon
MidnightTooltip:Start()

-- Return the addon table
return MidnightTooltip
