# MidnightTooltip - Fix for Fast Hover Flickering

## Problem
When quickly switching between characters/NPCs with the mouse:
1. Tooltip fades out (even though new content is present)
2. Tooltip briefly appears at wrong position before jumping to cursor

## Cause
- When quickly switching, `OnShow` is not called (tooltip stays visible)
- The custom fade logic (`fadeStartTime`) continues running and fades out the new tooltip
- Position is only corrected in the next frame → brief flash at wrong position

## Fix
In the `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, ...)` hook, cancel the fade and immediately set position:

```lua
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
```

## How to Apply
In `MidnightTooltip.lua`, replace the existing `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, ...)` hook with the code above (around line 510-530).
