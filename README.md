# MidnightTooltip

MidnightTooltip is a World of Warcraft addon that provides cursor-following tooltips with extensive customization options for appearance, behavior, and player information display.

## Features

### Cursor Following
- **Anchor tooltips to cursor** - Tooltips follow your mouse cursor with configurable anchor points
- **Customizable offset** - Adjust X and Y offset to position tooltips exactly where you want them
- **Configurable fade delay** - Control how quickly tooltips fade out (0-2 seconds)
- **Tooltip scale** - Adjust tooltip size from 50% to 200%

### Player Information
- **Class-colored names** - Player names displayed in their class colors
- **Guild information** - Shows guild names with customizable colors for your guild vs other guilds (supports realm-suffixed names)
- **Player status** - Displays AFK/DND status
- **Item level display** - Shows player item levels (target a player to inspect them, then hover for cached data)
- **Faction display** - Shows player faction (Horde/Alliance)
- **Mount information** - Shows what mount a player is riding and if you have it collected
- **Role icons** - Displays player role (Tank/Healer/DPS)
- **Mythic+ rating** - Shows player's Mythic+ score
- **Target of target** - Displays who the unit is targeting

### Item Tooltips
- **Quality border colors** - Colors tooltip borders based on item quality (including upgraded items)
- **Shopping tooltip positioning** - Intelligently positions comparison tooltips with secret value protection
- **World map compatibility** - Shopping tooltips work correctly with world quest rewards

### Combat & Instances
- **Hide tooltips in combat** - Option to hide tooltips during combat in dungeons/raids
- **Taint-safe** - Designed to avoid tainting secure frames in restricted content
- **Secret value protection** - Handles protected values in battlegrounds, arenas, and world quests
- **World map support** - Tooltips use default positioning on world map to prevent anchor conflicts

### Inspection System
- **Smart inspect caching** - Caches player inspect data for 5 minutes with automatic cleanup
- **Target-based inspection** - Only sends inspect requests when you target a player
- **Throttled requests** - Prevents API rate limiting with 1.5-second cooldown
- **GUID-based storage** - Stores item level data by player GUID for reliable retrieval
- **Secret value handling** - Safely handles GUID comparisons in protected content (battlegrounds, arenas)

### Profile System
- **Account-wide profiles** - Share settings across characters with profile support
- **Per-character settings** - Character-specific settings override profile settings
- **Automatic loading** - Settings load correctly after saved variables are available

## Installation

1. Download the MidnightTooltip addon files
2. Extract the contents into your World of Warcraft `Interface/AddOns` directory
3. Ensure the folder structure is:
   ```
   Interface/AddOns/MidnightTooltip/
   ├── MidnightTooltip.lua
   ├── MidnightTooltip.toc
   ├── config.lua
   ├── README.md
   ├── CHANGES.txt
   ├── core/
   ├── locales/
   └── modules/
   ```
4. Launch World of Warcraft and enable the addon from the AddOns menu

## Usage

### Slash Commands
- `/midnighttooltip` or `/mtt` - Open the options panel
- `/mttr` - Reload the UI to apply changes
- `/mttcursor` - Toggle cursor-only mode on/off

### Options Panel
Access the options through the in-game Interface Options menu or by typing `/mtt`.

**General Settings:**
- Enable/disable cursor anchor
- Cursor-only mode (disables most customizations)
- Hide tooltips in combat during dungeons/raids
- Enable quality borders

**Player Information:**
- Toggle class colorswith custom color pickers for:
  - Your guild members (default: magenta)
  - Other guilds (default: blue)
- Show/hide player status, mount info, item level, faction, role icons, Mythic+ rating, target of target
- Colors update dynamically (move mouse off and back to see changes)
- Show/hide player status, mount info, item level, faction, role icons, Mythic+ rating, target of target

**Positioning:**
- Tooltip anchor point (9 positions available)
- X/Y offset sliders (-200 to 200)

**Appearance:**
- Fade out delay (0-2 seconds)
- Tooltip scale (50%-200%)

### Item Level Feature
1. **Target a player** to send an inspect request
2. **Wait for data** to load (usually 1-2 seconds)
3. **Hover over the player** anytime in the next 5 minutes to see their cached item level
4. Players you haven't inspected will show "Target player to get ilvl" in gray

## Configuration

Settings are automatically saved in `SavedVariables/MidnightTooltipDB.lua` and persist across sessions.

### Default Settings
```lua
enableCursorAnchor = true
cursorOnlyMode = false
hideTooltipsInCombat = false
enableQualityBorder = true
anchorPoint = "BOTTOM"
cursorOffsetX = 0
cursorOffsetY = 0
fadeOutDelay = 0.2
tooltipScale = 100
showClassColors = true
showGuildColors = true
showPlayerStatus = true
showMountInfo = true
showItemLevel = true
showFaction = true
showRoleIcon = true
showMythicRating = true
showTargetOfTarget = true
```

## Known Limitations
taint
- Guild colors require moving your mouse off and back onto the unit to update after changing colors
- World map tooltips use default positioning to avoid conflicts with Blizzard's positioning

## Localization

Currently supports:
- English (US/UK)
- German (DE)
- Russian (RU)
- French (FR)
- Spanish (ES/MX)
- Chinese (Simplified & Traditional)
- Korean (KR)
- Italian (IT)
- Portuguese (BR)

## License

This project is licensed under the MIT License.