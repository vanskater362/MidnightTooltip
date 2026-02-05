-- MidnightTooltip.lua
-- Anchors game tooltips to follow the mouse cursor

local addonName, addon = ...
local MidnightTooltip = {}

-- Cache settings to avoid repeated lookups
local settingsCache = {}
local function RefreshSettingsCache()
    -- Check both MidnightTooltipDB (standalone) and addon.GetSetting (with config)
    local db = MidnightTooltipDB or {}
    local profileDB = nil
    
    -- Check if there's a current profile set and load it as fallback
    if db.currentProfile and MidnightTooltipProfiles and MidnightTooltipProfiles[db.currentProfile] then
        profileDB = MidnightTooltipProfiles[db.currentProfile]
    end
    
    local function getSetting(key, default)
        -- First try character-specific DB (highest priority)
        if db[key] ~= nil and key ~= "currentProfile" then 
            return db[key]
        end
        -- Then try profile DB (if profile is set)
        if profileDB and profileDB[key] ~= nil then
            return profileDB[key]
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
    settingsCache.tooltipScale = getSetting("tooltipScale", 100)
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
local abs = math.abs

-- Cache whether we're in a restricted environment (dungeon/raid)
local isInRestrictedInstance = false

-- Special frames that should use default tooltip positioning (not cursor anchored)
local SPECIAL_FRAMES = {
    ["Inspect"] = true,
    ["Character"] = true,
    ["Wardrobe"] = true,
    ["PaperDoll"] = true,
    ["PlayerChoice"] = true,
    ["Quest"] = true,
    ["Achievement"] = true,
    ["CompactRaid"] = true,
    ["CompactParty"] = true,
}

-- Helper function to check if a button is an assisted combat action (Single Button Assistant)
local function IsAssistedCombatButton(owner)
    if not owner or type(owner) ~= "table" then return false end
    
    -- Check if it's an action button with an action
    if owner.action and type(owner.action) == "number" then
        -- Use C_ActionBar API to check if this slot has an assisted combat action
        -- Wrap in pcall for safety in case API fails
        local success, isAssisted = pcall(C_ActionBar.IsAssistedCombatAction, owner.action)
        return success and isAssisted or false
    end
    
    return false
end

-- Helper function to check if owner is a special frame
local function IsSpecialFrame(ownerName)
    if not ownerName then return false end
    for prefix in pairs(SPECIAL_FRAMES) do
        if ownerName:find("^" .. prefix) then
            return true
        end
    end
    return false
end

-- Helper function to check if tooltip is for a WorldMap element
local function IsWorldMapTooltip()
    -- Check if WorldMapFrame exists and is shown
    if WorldMapFrame and WorldMapFrame:IsShown() then
        return true
    end
    return false
end

-- Inspect throttling to avoid hitting rate limits
local lastInspectTime = 0
local lastInspectedGUID = nil
local INSPECT_THROTTLE_SECONDS = 1.5 -- Wait at least 1.5 seconds between inspect requests
local INSPECT_CACHE_TTL = 300 -- 5 minute cache TTL
local MAX_CACHE_SIZE = 100 -- Maximum number of cached inspects
local inspectedGUIDs = {} -- Cache of GUIDs we've successfully inspected with timestamp
local inspectedIlvls = {} -- Cache of item levels indexed by GUID

-- Cache cleanup timer
local lastCacheCleanup = 0
local CACHE_CLEANUP_INTERVAL = 60 -- Clean cache every 60 seconds

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

-- Request inspect data for a unit if appropriate
local function RequestInspectIfNeeded(unit)
    -- Only inspect targeted players
    if unit ~= "target" then return end
    
    -- Don't interfere with the game's inspect frame
    if InspectFrame and InspectFrame:IsShown() then return end
    
    -- Only inspect players (not yourself)
    local isPlayerSuccess, isPlayer = pcall(UnitIsPlayer, unit)
    if not isPlayerSuccess or not isPlayer or unit == "player" then return end
    
    -- Skip party/raid members (auto-inspected by the game)
    local inPartySuccess, inParty = pcall(UnitInParty, unit)
    local inRaidSuccess, inRaid = pcall(UnitInRaid, unit)
    if (inPartySuccess and inParty) or (inRaidSuccess and inRaid) then return end
    
    -- Get unit GUID for tracking
    local guidSuccess, guid = pcall(UnitGUID, unit)
    if not guidSuccess or not guid then return end
    
    -- Check if already inspected recently (cache with TTL)
    local currentTime = GetTime()
    if inspectedGUIDs[guid] and currentTime - inspectedGUIDs[guid] < INSPECT_CACHE_TTL then return end
    
    -- Check if can inspect
    local canInspectSuccess, canInspect = pcall(CanInspect, unit)
    if not canInspectSuccess or not canInspect then return end
    
    -- Throttle requests (1.5 second global cooldown)
    if currentTime - lastInspectTime < INSPECT_THROTTLE_SECONDS then return end
    
    -- Additional throttle for same player (30 seconds)
    if guid == lastInspectedGUID and currentTime - lastInspectTime < 30 then return end
    
    -- Check range
    local inRangeSuccess, inRange = pcall(CheckInteractDistance, unit, 1)
    if not inRangeSuccess or not inRange then return end
    
    -- Send inspect request
    local notifySuccess = pcall(NotifyInspect, unit)
    if notifySuccess then
        lastInspectTime = currentTime
        lastInspectedGUID = guid
    end
end

-- Force refresh hooks with current settings
local function RefreshHooks()
    RefreshSettingsCache()
    UpdateRestrictedState()
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
    
    local quality = nil
    
    -- First try to get quality from the tooltip's item link (this respects upgrades)
    if tooltip.GetItem then
        local _, item = tooltip:GetItem()
        if item then
            quality = select(3, C_Item.GetItemInfo(item))
        end
    end
    
    -- Fall back to data.id if item link method didn't work
    if not quality and data and data.id then
        quality = C_Item.GetItemQualityByID(data.id)
    end
    
    -- Apply border color based on quality
    if quality and quality >= Enum.ItemQuality.Common then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        SetBorderColor(tooltip, r, g, b)
    else
        SetBorderColor(tooltip, 1, 1, 1)
    end
end

-- Helper to strip color codes from text
local function StripColorCodes(text)
    return gsub(gsub(text, COLOR_CODE_PATTERN, ""), COLOR_RESET_PATTERN, "")
end

-- Helper to get item level color based on value
local function GetItemLevelColor(ilvl)
    if ilvl >= 285 then
        return "|cFFFF8000" -- Legendary orange (Mythic raid/high M+ vault)
    elseif ilvl >= 270 then
        return "|cFFA335EE" -- Epic purple (Heroic raid/high M+)
    elseif ilvl >= 260 then
        return "|cFF0070DD" -- Rare blue (Normal raid/mid M+)
    else
        return "|cFF1EFF00" -- Uncommon green (Leveling/early endgame)
    end
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
    
    -- Additional check: only process if this is actually a player or NPC unit
    -- Skip if tooltip name doesn't match GameTooltip (prevents quest/item tooltip processing)
    if tooltip:GetName() ~= "GameTooltip" then
        return
    end
    
    -- Check if unit actually exists (prevents issues with quest/item tooltips)
    -- Wrap in pcall to avoid taint errors with secret values in scenarios/restricted content
    local unitCheckSuccess, unitExists = pcall(UnitExists, unit)
    if not unitCheckSuccess or not unitExists then
        return
    end
    
    -- Request inspect for non-grouped players if needed (for item level display)
    if settingsCache.showItemLevel then
        RequestInspectIfNeeded(unit)
    end
    
    -- Direct UnitIsPlayer check wrapped in pcall for safety
    local playerCheckSuccess, isPlayer = pcall(UnitIsPlayer, unit)
    if not playerCheckSuccess then
        return
    end
    
    if isPlayer then
        local classSuccess, _, class = pcall(UnitClass, unit)
        if not classSuccess or not class then return end
        
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
                    local afkSuccess, isAFK = pcall(UnitIsAFK, unit)
                    local dndSuccess, isDND = pcall(UnitIsDND, unit)
                    if afkSuccess and isAFK then
                        prefix = "|cFF808080[AFK]|r "
                    elseif dndSuccess and isDND then
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
        local guildName = nil
        local isGuildMate = false
        
        if settingsCache.showGuildColors then
            local success, name = pcall(GetGuildInfo, unit)
            if success and name then
                guildName = name
                local mateSuccess, inGuild = pcall(UnitIsInMyGuild, unit)
                if mateSuccess and inGuild then
                    isGuildMate = true
                end
            end
        end
        
        local mountName, mountOwned
        if settingsCache.showMountInfo then
            for i = 1, 40 do
                local auraSuccess, auraData = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
                if not auraSuccess or not auraData then break end
                
                -- Wrap mount journal calls in pcall to avoid taint errors during combat/events
                if auraData.spellId then
                    local mountSuccess, mountID = pcall(C_MountJournal.GetMountFromSpell, auraData.spellId)
                    if mountSuccess and mountID then
                        mountName = auraData.name
                        local infoSuccess, _, _, _, _, _, _, _, _, _, _, isCollected = pcall(C_MountJournal.GetMountInfoByID, mountID)
                        if infoSuccess then
                            mountOwned = isCollected
                        end
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
                        
                        -- Check for guild name
                        local isGuildLine = false
                        if settingsCache.showGuildColors and guildName and i == 2 then
                            -- Guild name is typically on line 2
                            -- It may appear as "GuildName" or "GuildName-RealmName"
                            if cleanText == guildName or cleanText:match("^" .. guildName:gsub("%-", "%%-") .. "%-") or cleanText:match("^" .. guildName:gsub("%-", "%%-") .. "$") then
                                isGuildLine = true
                                lineText:SetText(cleanText)
                                if isGuildMate then
                                    lineText:SetTextColor(settingsCache.customGuildColorR, settingsCache.customGuildColorG, settingsCache.customGuildColorB)
                                else
                                    lineText:SetTextColor(settingsCache.customOtherGuildColorR, settingsCache.customOtherGuildColorG, settingsCache.customOtherGuildColorB)
                                end
                            end
                        end
                        
                        if not isGuildLine then
                            if cleanText:match("Horde") or cleanText:match("Alliance") then
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
        end
        
        -- Get player's item level
        if settingsCache.showItemLevel then
            local avgItemLevel
            if unit == "player" then
                -- For player, use GetAverageItemLevel
                _, avgItemLevel = GetAverageItemLevel()
            else
                -- First check our GUID cache for previously inspected data
                local guidSuccess, guid = pcall(UnitGUID, unit)
                if guidSuccess and guid and inspectedIlvls[guid] then
                    avgItemLevel = inspectedIlvls[guid]
                end
                
                -- If not in cache, try inspect API (works for party/raid and current inspect target)
                if not avgItemLevel then
                    local inspectSuccess, inspectIlvl = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
                    if inspectSuccess and inspectIlvl and inspectIlvl > 0 then
                        avgItemLevel = inspectIlvl
                    end
                end
                
                -- If inspect didn't work, parse from default tooltip (works for any nearby player)
                if not avgItemLevel or avgItemLevel == 0 then
                    local numLines = tooltip:NumLines()
                    for i = 2, numLines do
                        local lineText = _G[tooltipName .. "TextLeft" .. i]
                        if lineText then
                            local text = lineText:GetText()
                            if text then
                                -- Look for "Item Level: XXX" or localized variants
                                local ilvl = text:match("Item Level:?%s*(%d+)") or text:match("(%d+)%s*Item Level")
                                if ilvl then
                                    avgItemLevel = tonumber(ilvl)
                                    -- Hide the original line since we'll add our own
                                    lineText:SetText("")
                                    break
                                end
                            end
                        end
                    end
                end
            end
            
            -- Always show item level line if enabled (for other players)
            if unit ~= "player" then
                if avgItemLevel and avgItemLevel > 0 then
                    local ilvlColor = GetItemLevelColor(avgItemLevel)
                    tooltip:AddLine(format("|cFFFFFFFFItem Level: |r%s%d|r", ilvlColor, floor(avgItemLevel)))
                else
                    -- No data available, show prompt to target
                    tooltip:AddLine("|cFFFFFFFFItem Level: |r|cFF808080Target player to get ilvl|r")
                end
            elseif avgItemLevel and avgItemLevel > 0 then
                -- For self, show ilvl if available
                local ilvlColor = GetItemLevelColor(avgItemLevel)
                tooltip:AddLine(format("|cFFFFFFFFItem Level: |r%s%d|r", ilvlColor, floor(avgItemLevel)))
            end
        end
        
        -- Show role icon
        if settingsCache.showRoleIcon then
            local roleSuccess, role = pcall(UnitGroupRolesAssigned, unit)
            if roleSuccess and role and role ~= "NONE" then
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
            local targetExistsSuccess, targetExists = pcall(UnitExists, targetUnit)
            if targetExistsSuccess and targetExists then
                local targetNameSuccess, targetName = pcall(UnitName, targetUnit)
                if targetNameSuccess and targetName then
                    local targetColor = "|cFFFFFFFF"
                    local playerSuccess, isTargetPlayer = pcall(UnitIsPlayer, targetUnit)
                    if playerSuccess and isTargetPlayer then
                        local classSuccess, _, targetClass = pcall(UnitClass, targetUnit)
                        if classSuccess and targetClass then
                            local classColor = C_ClassColor.GetClassColor(targetClass)
                            if classColor then
                                targetColor = format("|cFF%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
                            end
                        end
                    else
                        local controlSuccess, isControlled = pcall(UnitPlayerControlled, targetUnit)
                        if not (controlSuccess and isControlled) then
                            local reactionSuccess, reaction = pcall(UnitReaction, targetUnit, "player")
                            if reactionSuccess and reaction then
                                if reaction >= 5 then
                                    targetColor = "|cFF00FF00" -- Friendly
                                elseif reaction == 4 then
                                    targetColor = "|cFFFFFF00" -- Neutral
                                else
                                    targetColor = "|cFFFF0000" -- Hostile
                                end
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
        local reactionSuccess, reaction = pcall(UnitReaction, unit, "player")
        if reactionSuccess and reaction and settingsCache.enableQualityBorder then
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
    -- Initialize restricted instance state
    UpdateRestrictedState()
    
    -- Create a frame to listen for ADDON_LOADED to refresh settings after SavedVariables load
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("ADDON_LOADED")
    initFrame:SetScript("OnEvent", function(self, event, loadedAddon)
        if loadedAddon == "MidnightTooltip" then
            -- Saved variables are now loaded, refresh settings cache
            RefreshSettingsCache()
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
    
    -- Create event frame for INSPECT_READY
    local inspectFrame = CreateFrame("Frame")
    inspectFrame:RegisterEvent("INSPECT_READY")
    inspectFrame:SetScript("OnEvent", function(self, event, guid)
        if event == "INSPECT_READY" and guid then
            -- Cache the GUID now that we have valid inspect data
            inspectedGUIDs[guid] = GetTime()
            
            -- Store the ilvl data for this GUID
            -- Find the unit with this GUID and get their ilvl
            for _, unit in ipairs({"target", "mouseover", "player"}) do
                local guidSuccess, unitGuid = pcall(UnitGUID, unit)
                if guidSuccess and unitGuid then
                    -- Use pcall to safely compare GUIDs (can be secret values in combat/battlegrounds)
                    local compareSuccess, matches = pcall(function() return unitGuid == guid end)
                    if compareSuccess and matches then
                        local success, ilvl = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
                        if success and ilvl and ilvl > 0 then
                            inspectedIlvls[guid] = ilvl
                        end
                        break
                    end
                end
            end
        end
    end)
    
    -- Reload settings after saved variables are loaded
    C_Timer.After(0.5, function()
        RefreshHooks()
    end)
    
    -- Update restricted state when zone changes
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:SetScript("OnEvent", function(self, event, guid)
        UpdateRestrictedState()
    end)
    
    -- Variables for tracking tooltip state
    local fadeStartTime = nil
    local lastUnitGUID = nil
    local lastUnitToken = nil
    
    -- Function to clean up old inspect cache entries
    local function CleanupInspectCache()
        local now = GetTime()
        local count = 0
        
        -- Count current entries
        for _ in pairs(inspectedGUIDs) do
            count = count + 1
        end
        
        -- Remove expired entries
        for guid, time in pairs(inspectedGUIDs) do
            if now - time > INSPECT_CACHE_TTL then
                inspectedGUIDs[guid] = nil
                inspectedIlvls[guid] = nil
                count = count - 1
            end
        end
        
        -- If still over limit, remove oldest entries
        if count > MAX_CACHE_SIZE then
            local entries = {}
            for guid, time in pairs(inspectedGUIDs) do
                table.insert(entries, {guid = guid, time = time})
            end
            table.sort(entries, function(a, b) return a.time < b.time end)
            
            for i = 1, count - MAX_CACHE_SIZE do
                local guid = entries[i].guid
                inspectedGUIDs[guid] = nil
                inspectedIlvls[guid] = nil
            end
        end
    end
    
    -- Hook OnShow to initialize tooltip state and positioning
    GameTooltip:HookScript("OnShow", function(self)
        -- Check for special frames FIRST - skip ALL modifications for WorldMap, Character sheet, etc.
        if IsWorldMapTooltip() then
            -- Completely skip all modifications when WorldMap is open
            return
        end
        
        local owner = self:GetOwner()
        if owner then
            local ownerName = owner:GetName()
            if ownerName and IsSpecialFrame(ownerName) then
                -- Completely skip all modifications for special frames
                return
            end
            -- Check for assisted combat buttons (Single Button Assistant)
            if IsAssistedCombatButton(owner) then
                return
            end
        end
        
        -- Hide if configured to hide tooltips in combat during instances
        if isInRestrictedInstance and settingsCache.hideTooltipsInCombat and InCombatLockdown() then
            self:Hide()
            return
        end
        
        -- Apply tooltip scale (convert percentage to decimal)
        if settingsCache.tooltipScale and settingsCache.tooltipScale > 0 then
            self:SetScale(settingsCache.tooltipScale / 100)
        end
        
        -- Reset fade state
        fadeStartTime = nil
        self:SetAlpha(1)
        
        -- Track current unit (skip in restricted instances to avoid potential taint)
        if not isInRestrictedInstance then
            local success, _, unit = pcall(self.GetUnit, self)
            if success and unit then
                local guidSuccess, currentGUID = pcall(UnitGUID, unit)
                if guidSuccess then
                    lastUnitGUID = currentGUID
                    lastUnitToken = unit
                end
            else
                lastUnitGUID = nil
                lastUnitToken = nil
            end
        end
        
        -- Position at cursor
        if settingsCache.enableCursorAnchor then
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            local tooltipScale = (settingsCache.tooltipScale and settingsCache.tooltipScale > 0) and (settingsCache.tooltipScale / 100) or 1
            local anchorPoint = settingsCache.anchorPoint or "BOTTOM"
            local offsetX = settingsCache.cursorOffsetX or 0
            local offsetY = settingsCache.cursorOffsetY or 0
            self:ClearAllPoints()
            -- Divide by tooltip scale to compensate for the scaled coordinate system
            self:SetPoint(anchorPoint, UIParent, "BOTTOMLEFT", ((x / scale) + offsetX) / tooltipScale, ((y / scale) + offsetY) / tooltipScale)
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
    
    -- Override tooltip Hide to prevent action bars from instantly hiding tooltips
    local isHideHookActive = false
    hooksecurefunc(GameTooltip, "Hide", function(self)
        -- Prevent re-entrancy to avoid infinite loops
        if isHideHookActive then return end
        
        -- If we have a fade timer active, prevent instant hide and continue fading
        if fadeStartTime and settingsCache.fadeOutDelay and settingsCache.fadeOutDelay > 0 then
            local elapsed = GetTime() - fadeStartTime
            if elapsed < settingsCache.fadeOutDelay then
                -- Still within fade period, show it again and let OnUpdate handle the fade
                isHideHookActive = true
                self:Show()
                isHideHookActive = false
            end
        end
    end)
    
    -- NOTE: Removed GameTooltip_SetDefaultAnchor override as it causes taint in restricted instances
    -- The OnShow hook handles positioning adequately without needing to override this global function
    
    -- Hook OnUpdate to handle cursor positioning, unit changes, fading, and cache cleanup
    GameTooltip:HookScript("OnUpdate", function(self, elapsed)
        -- Periodic cache cleanup
        lastCacheCleanup = lastCacheCleanup + elapsed
        if lastCacheCleanup >= CACHE_CLEANUP_INTERVAL then
            CleanupInspectCache()
            lastCacheCleanup = 0
        end
        
        -- Check for special frames early - skip all positioning for WorldMap, Character sheet, etc.
        local isSpecialFrame = false
        if self:IsShown() then
            -- Check if WorldMap is open
            if IsWorldMapTooltip() then
                isSpecialFrame = true
            else
                local owner = self:GetOwner()
                if owner then
                    local ownerName = owner:GetName()
                    if ownerName and IsSpecialFrame(ownerName) then
                        isSpecialFrame = true
                    elseif IsAssistedCombatButton(owner) then
                        isSpecialFrame = true
                    end
                end
            end
        end
        
        -- Hide tooltip in combat during instances if configured
        if isInRestrictedInstance and settingsCache.hideTooltipsInCombat and InCombatLockdown() then
            if self:IsShown() then
                self:Hide()
            end
            return
        end
        
        -- Reposition tooltip to cursor for smooth tracking (skip for special frames)
        if not isSpecialFrame and settingsCache.enableCursorAnchor and self:IsShown() then
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            local tooltipScale = (settingsCache.tooltipScale and settingsCache.tooltipScale > 0) and (settingsCache.tooltipScale / 100) or 1
            local anchorPoint = settingsCache.anchorPoint or "BOTTOM"
            local offsetX = settingsCache.cursorOffsetX or 0
            local offsetY = settingsCache.cursorOffsetY or 0
            self:ClearAllPoints()
            -- Divide by tooltip scale to compensate for the scaled coordinate system
            self:SetPoint(anchorPoint, UIParent, "BOTTOMLEFT", ((x / scale) + offsetX) / tooltipScale, ((y / scale) + offsetY) / tooltipScale)
        end
        
        -- Detect unit changes and reset fade state
        -- CRITICAL: Skip unit tracking in restricted instances to prevent taint
        if not isInRestrictedInstance then
            local success, _, unit = pcall(self.GetUnit, self)
            if success and unit then
                local guidSuccess, currentGUID = pcall(UnitGUID, unit)
                if guidSuccess and currentGUID then
                    -- Check if this is a new unit (different GUID or different unit token)
                    local guidChanged = (currentGUID ~= lastUnitGUID)
                    local tokenChanged = (unit ~= lastUnitToken)
                    
                    if guidChanged or tokenChanged then
                        lastUnitGUID = currentGUID
                        lastUnitToken = unit
                        fadeStartTime = nil
                        self:SetAlpha(1)
                    end
                end
            else
                lastUnitGUID = nil
                lastUnitToken = nil
            end
        end
        
        -- Check if tooltip should start fading (only for mouseover tooltips)
        -- For target/focus/etc, let the game's default behavior handle fading
        -- Skip in restricted instances to prevent taint
        if not fadeStartTime and self:IsShown() and not isInRestrictedInstance then
            local success, _, unit = pcall(self.GetUnit, self)
            if success and unit then
                -- Safely check if this is a mouseover tooltip
                local compareSuccess, isMouseover = pcall(function() return unit == "mouseover" end)
                if compareSuccess and isMouseover then
                    -- For mouseover tooltips, check if mouse is still over the unit
                    if not UnitExists("mouseover") then
                        fadeStartTime = GetTime()
                    end
                end
            end
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
    
    -- Hook tooltip item display to color border (handles all item tooltips including shopping tooltips)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        -- Skip in restricted instances to prevent any potential taint
        if isInRestrictedInstance then
            return
        end
        
        -- Skip in cursor-only mode (except for shopping tooltips)
        if settingsCache.cursorOnlyMode and tooltip ~= ShoppingTooltip1 and tooltip ~= ShoppingTooltip2 then
            return
        end
        ColorTooltipBorder(tooltip, data)
    end)
    
    -- Hook tooltip unit display to color border by class/reaction (only for non-item tooltips)
    -- REMOVED DUPLICATE: The first Unit callback that called ColorTooltipBorder was for items, not units
    
    -- Hook tooltip unit display to color border by class/reaction (only for non-item tooltips)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
        -- Skip in dungeons/raids to prevent taint
        -- The issue: calling tooltip:GetUnit() during TooltipDataProcessor for world cursor
        -- tooltips taints the tooltip, causing Blizzard's code to fail
        if isInRestrictedInstance then return end
        
        -- Skip in cursor-only mode
        if settingsCache.cursorOnlyMode then return end
        
        -- Don't override item border colors - only apply to pure unit tooltips
        if tooltip.GetItem then
            local _, item = tooltip:GetItem()
            if item then
                return -- This is an item tooltip, don't override
            end
        end
        ColorTooltipBorderByUnit(tooltip)
    end)
    
    -- Hook the comparison tooltip function to position them properly
    hooksecurefunc("GameTooltip_ShowCompareItem", function(self, anchorFrame)
        -- Apply scale to shopping tooltips
        if settingsCache.tooltipScale and settingsCache.tooltipScale > 0 then
            local scale = settingsCache.tooltipScale / 100
            if ShoppingTooltip1 then
                ShoppingTooltip1:SetScale(scale)
            end
            if ShoppingTooltip2 then
                ShoppingTooltip2:SetScale(scale)
            end
        end
        
        if ShoppingTooltip1 and ShoppingTooltip1:IsShown() then
            ShoppingTooltip1:ClearAllPoints()
            
            -- Check if there's enough space on the left side of GameTooltip
            -- Use pcall to safely handle secret values that cannot be compared
            local success, tooltipLeft = pcall(GameTooltip.GetLeft, GameTooltip)
            tooltipLeft = (success and tooltipLeft) or 0
            local screenWidth = GetScreenWidth()
            local successRight, tooltipRight = pcall(GameTooltip.GetRight, GameTooltip)
            tooltipRight = (successRight and tooltipRight) or screenWidth
            
            -- If tooltip is too far left (less than 25% of screen width), anchor to the right
            if tooltipLeft < (screenWidth * 0.25) then
                ShoppingTooltip1:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", 2, 0)
                
                if ShoppingTooltip2 and ShoppingTooltip2:IsShown() then
                    ShoppingTooltip2:ClearAllPoints()
                    ShoppingTooltip2:SetPoint("TOPLEFT", ShoppingTooltip1, "TOPRIGHT", 2, 0)
                end
            else
                -- Default: anchor to the left
                ShoppingTooltip1:SetPoint("TOPRIGHT", GameTooltip, "TOPLEFT", -2, 0)
                
                if ShoppingTooltip2 and ShoppingTooltip2:IsShown() then
                    ShoppingTooltip2:ClearAllPoints()
                    ShoppingTooltip2:SetPoint("TOPRIGHT", ShoppingTooltip1, "TOPLEFT", -2, 0)
                end
            end
        elseif ShoppingTooltip2 and ShoppingTooltip2:IsShown() then
            -- Handle case where only ShoppingTooltip2 is shown
            ShoppingTooltip2:ClearAllPoints()
            
            -- Use pcall to safely handle secret values that cannot be compared
            local success, tooltipLeft = pcall(GameTooltip.GetLeft, GameTooltip)
            tooltipLeft = (success and tooltipLeft) or 0
            local screenWidth = GetScreenWidth()
            
            if tooltipLeft < (screenWidth * 0.25) then
                ShoppingTooltip2:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", 2, 0)
            else
                ShoppingTooltip2:SetPoint("TOPRIGHT", GameTooltip, "TOPLEFT", -2, 0)
            end
        end
    end)
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
