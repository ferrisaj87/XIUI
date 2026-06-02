--[[
* VanaTime UI renderer for XIUI.
*
* Layout (when all options enabled):
*
*   ┌─ VanaTime ──────────────────────────────────────────────┐
*   │  VT: 18:32                       LT: 01:53 AM           │
*   │ ┌──────────┐ ▶ ┌────────────────┐ ▶ ┌──────────┐       │
*   │ │ [Fire]   │   │   [Earth]      │   │  [Wind]  │       │
*   │ │  65% ↑   │   │    72% ↑       │   │  73% ↑   │       │
*   │ │[↓][weak] │   │  [↓][weak]     │   │[↓][weak] │       │
*   │ └──────────┘   └────────────────┘   └──────────┘       │
*   └─────────────────────────────────────────────────────────┘
*
*   Weather popup (when elemental weather active):
*   ┌─ VanaTimeWeather ─┐
*   │  [Fire]  x2       │   (auto-width, no x2 for single)
*   └───────────────────┘
]]--

require('common');
local bit       = require('bit');
local imgui     = require('imgui');
local imtext    = require('libs.imtext');
local ffi       = require('ffi');

-- High-precision wall-clock milliseconds via Windows API.
-- os.clock() is CPU time in LuaJIT (doesn't advance while the game sleeps),
-- so we use GetTickCount64 for sub-second interpolation instead.
pcall(function() ffi.cdef[[ unsigned long long __stdcall GetTickCount64(void); ]]; end);
local function _doGetTickCount64()
    return tonumber(ffi.C.GetTickCount64());
end
local function GetTickMs()
    local ok, v = pcall(_doGetTickCount64);
    return (ok and v) or nil;
end

local TextureManager = require('libs.texturemanager');
local windowbg  = require('libs.windowbackground');
local timers    = require('modules.vanatime.timers');

local M = {};

-- ── Constants ─────────────────────────────────────────────────────────────────

local WEATHER_POPUP_GAP  = 4;   -- px gap between main window and popup
local PAST_FUTURE_ALPHA  = 0.18;
local BADGE_SCALE        = 0.40; -- weakness badge as fraction of main icon size
local VT_TEXT_COLOR      = 0xFFC3AE79; -- XIUI Gold Dark — fixed for VT clock text
local ARROW_SCALE        = 0.55; -- down-arrow as fraction of badge icon size
local COL_ARROW          = '>';   -- column separator

-- ── Pure-Lua Vana'diel time (no FFI / ashita.memory) ─────────────────────────
-- Vana'diel time runs at 25× real-world speed.
-- 1 VD day  = 3456 real seconds  (57.6 minutes)
-- 1 VD hour = 144  real seconds
-- 1 VD min  = 2.4  real seconds
-- Moon cycle = 84 VD days; day 0 = new moon, day 42 = full moon.
local VANA_EPOCH    = 1009810797.6; -- Unix ts of Vana'diel epoch, calibrated -2.4s (1 VT min) vs raw JST anchor
local VD_DAY_SEC    = 3456;
local VD_HOUR_SEC   = 144;
local VD_MIN_F      = 2.4;
local VD_MOON_DAYS  = 84;
-- VT day 0 does not coincide with moon-cycle day 0.  Calibrated against live data:
-- at a known timestamp the raw vtDays%84 is off by +4, so subtract 4 (add 80) to align.
local VD_MOON_OFFSET = 80;

-- os.time() has 1-second granularity; at 25x VT speed a 0-1s truncation lag = 0-25 VT seconds.
-- Sub-second VT precision via GetTickCount64 (wall-clock ms).
-- os.clock() is CPU time in LuaJIT on Windows and does NOT advance while the
-- game sleeps between frames, so it cannot be used for wall-clock interpolation.
-- GetTickCount64 is a lightweight Windows kernel call (no syscall overhead) that
-- returns monotonic milliseconds since boot — perfect for this purpose.
local _vtLastSec   = 0;    -- last os.time() second anchor
local _vtTickAtSec = 0;    -- GetTickCount64() value when os.time() last ticked

local function GetRawTime()
    local t      = os.time();
    local tickMs = GetTickMs();
    if tickMs then
        if t ~= _vtLastSec then
            _vtLastSec   = t;
            _vtTickAtSec = tickMs;
        end
        local subSec = math.min(0.999, (tickMs - _vtTickAtSec) / 1000.0);
        return (t + subSec) - VANA_EPOCH;
    else
        -- Fallback if FFI unavailable: integer-second precision.
        return t - VANA_EPOCH;
    end
end

local function CalcMoonPercent(moonDay)
    if moonDay <= 42 then
        return math.floor(moonDay / 42 * 100 + 0.5);
    else
        return math.floor((VD_MOON_DAYS - moonDay) / 42 * 100 + 0.5);
    end
end

-- Weekday index -> element name (matches assets/VanaTime/elements/*.png)
-- Indices 0-7: the eight FFXI elements (used for day columns and elemental weather).
-- Indices 8-11: non-elemental weather icons (used only for the weather popup).
local ELEMENT_NAMES = {
    [0] = 'Fire',
    [1] = 'Earth',
    [2] = 'Water',
    [3] = 'Wind',
    [4] = 'Ice',
    [5] = 'Thunder',
    [6] = 'Light',
    [7] = 'Darkness',
    [8] = 'Clear',
    [9] = 'Sunshine',
    [10] = 'Cloudy',
    [11] = 'Foggy',
};

-- Module-level constant: maps weekday index to colorCustomization key
local ELEM_KEYS = {
    [0]='elementFire', [1]='elementEarth', [2]='elementWater', [3]='elementWind',
    [4]='elementIce',  [5]='elementLightning', [6]='elementLight', [7]='elementDark',
};

-- Frame cache for time strings — only recompute when the values actually change
local vtCache = { hour = -1, min = -1, str = '', measW = 0 };
local ltCache = { osMin = -1, osHour = -1, str = '', measW = 0 };
local lastOsTime = -1;
local lastFontSize = -1;  -- flush measure cache if font size changes

-- Which element each weekday DEFEATS (shown as weakness badge)
-- Chain: Water > Fire > Ice > Wind > Earth > Thunder > Water; Light<->Dark
local ELEMENT_DEFEATS = {
    [0] = 4,  -- Fire   defeats Ice
    [1] = 5,  -- Earth  defeats Lightning
    [2] = 0,  -- Water  defeats Fire
    [3] = 1,  -- Wind   defeats Earth
    [4] = 3,  -- Ice    defeats Wind
    [5] = 2,  -- Lightning defeats Water
    [6] = 7,  -- Light  defeats Dark
    [7] = 6,  -- Dark   defeats Light
};

-- Light group (black outline + white pill). Dark group gets white + dark pill.
local LIGHT_GROUP = { [0]=true, [3]=true, [5]=true, [6]=true };

-- ── Fenrir Blood Pact tooltip data (indexed by phase 0-11) ────────────────────
-- Phase 0=New Moon, 6=Full Moon; 1-5 waxing, 7-11 waning
local PHASE_NAMES = {
    [0]='New Moon',        [1]='Waxing Crescent', [2]='Waxing Crescent',
    [3]='First Quarter',   [4]='Waxing Gibbous',  [5]='Waxing Gibbous',
    [6]='Full Moon',       [7]='Waning Gibbous',  [8]='Waning Gibbous',
    [9]='Last Quarter',    [10]='Waning Crescent', [11]='Waning Crescent',
};
-- Lunar Cry: {acc_penalty, eva_penalty}
local LUNAR_CRY = {
    [0]={-1,-31}, [1]={-6,-26},  [2]={-11,-21}, [3]={-16,-16},
    [4]={-21,-11},[5]={-26,-6},  [6]={-31,-1},  [7]={-26,-6},
    [8]={-21,-11},[9]={-16,-16}, [10]={-11,-21},[11]={-6,-26},
};
-- Ecliptic Howl: {acc_bonus, eva_bonus}
local ECLIPTIC_HOWL = {
    [0]={1,25},  [1]={5,21},  [2]={9,17},  [3]={13,13},
    [4]={17,9},  [5]={21,5},  [6]={25,1},  [7]={21,5},
    [8]={17,9},  [9]={13,13}, [10]={9,17}, [11]={5,21},
};
-- Ecliptic Growl: {STR/DEX/VIT, AGI/INT/MND/CHR}
local ECLIPTIC_GROWL = {
    [0]={1,7},  [1]={2,6},  [2]={3,5},  [3]={4,4},
    [4]={5,3},  [5]={6,2},  [6]={7,1},  [7]={6,2},
    [8]={5,3},  [9]={4,4},  [10]={3,5}, [11]={2,6},
};

-- Selene's Bow: {Ranged Accuracy bonus, Ranged Attack bonus}
-- Full Moon=best RAcc; New Moon=best RAtk; Gibbous/Crescent/Quarter interpolate
local SELENE_BOW = {
    [0]={5,25},  [1]={10,20}, [2]={10,20}, [3]={15,15},
    [4]={20,10}, [5]={20,10}, [6]={25,5},  [7]={20,10},
    [8]={20,10}, [9]={15,15}, [10]={10,20},[11]={10,20},
};

-- Weather IDs 4-19 are elemental; odd = double
-- Map to weekday element index (0-7)
local WEATHER_TO_ELEMENT = {
    [0]=8,  [1]=9,   -- Clear / Sunshine          (non-elemental)
    [2]=10, [3]=11,  -- Cloudy / Fog              (non-elemental)
    [4]=3,  [5]=3,   -- Wind / Gales              (Wind)
    [6]=2,  [7]=2,   -- Rain / Squall             (Water)
    [8]=0,  [9]=0,   -- Hot Spell / Heat Wave     (Fire)
    [10]=1, [11]=1,  -- Dust Storm / Sandstorm    (Earth)
    [12]=4, [13]=4,  -- Snow / Blizzard           (Ice)
    [14]=5, [15]=5,  -- Thunder / Thunderstorm    (Lightning)
    [16]=6, [17]=6,  -- Auroras / Stellar Glare   (Light)
    [18]=7, [19]=7,  -- Gloom / Darkness          (Dark)
};

local WEATHER_NAMES = {
    [0]  = 'Clear',
    [1]  = 'Sunshine',
    [2]  = 'Cloudy',
    [3]  = 'Fog',
    [4]  = 'Wind',
    [5]  = 'Gales',
    [6]  = 'Rain',
    [7]  = 'Squall',
    [8]  = 'Hot Spell',
    [9]  = 'Heat Wave',
    [10] = 'Dust Storm',
    [11] = 'Sandstorm',
    [12] = 'Snow',
    [13] = 'Blizzard',
    [14] = 'Thunder',
    [15] = 'Thunderstorm',
    [16] = 'Auroras',
    [17] = 'Stellar Glare',
    [18] = 'Gloom',
    [19] = 'Darkness',
};



-- ── Texture cache ─────────────────────────────────────────────────────────────

local textures = {};
local arrowRightTex = nil;
local moonUpTex     = nil;
local moonDownTex   = nil;
local moonPhaseTextures = {};  -- [0..11] → phase icon
local todDayTex       = nil;   -- VT 06:00-17:59
local todNightTex     = nil;   -- VT 18:00-19:59 and 04:00-05:59
local todDeadNightTex = nil;   -- VT 20:00-03:59 (priority over night)

-- ── Timers panel state ─────────────────────────────────────────────────────
local clockIconTex    = nil;
local gearIconTex     = nil;   -- settings gear icon
local timersOpen      = false;
local cachedTimersH   = 200;  -- seeded so first-frame 'above' position doesn't flicker
local clockIconRect   = { x=0, y=0, w=0, h=0 };
local firstTimerFrame = false;   -- seeds CollapsingHeader open states on popup open
local timersLastActivity = 0;    -- os.clock() of last hover/click inside timers window
local timersOpenedAt     = 0;    -- os.clock() when timers was opened; suppresses same-frame close
-- Session-only section open state: always starts collapsed on reload, never written to disk.
local timerSectionOpen    = { airships=false, boats=false, rse=false, lunar=false };
-- Session-only boat sub-group open state: all collapsed on addon load.
local timerBoatGroupOpen  = {};
-- Holds the colorCfg table for the duration of DrawTimersPopup so inner draw helpers
-- can resolve element-day colours without needing extra parameters.

-- Maps phase index (0-11) to icon file number.
-- After renaming phase_3/4/5 assets to match logical order, this is 1:1.
local PHASE_ICON_MAP = {
    [0]=0, [1]=1,  [2]=2,
    [3]=3, [4]=4,  [5]=5,
    [6]=6, [7]=7,  [8]=8,
    [9]=9, [10]=10,[11]=11,
};

-- Map moonDay (0-83) to the raw logical phase index (0-11).
-- New Moon wraps: moonDays 80-83 and 0-2 → 0.
-- All other phases are 7-day segments from moonDay 3 onward.
-- Phase → moonDay range → asset file:
--   0  New Moon          80-83, 0-2  phase_0.png
--   1  Waxing Crescent   3-9         phase_1.png
--   2  Waxing Crescent   10-16       phase_2.png
--   3  First Quarter     17-23       phase_3.png
--   4  Waxing Gibbous    24-30       phase_4.png
--   5  Waxing Gibbous    31-37       phase_5.png
--   6  Full Moon         38-44       phase_6.png
--   7  Waning Gibbous    45-51       phase_7.png
--   8  Waning Gibbous    52-58       phase_8.png
--   9  Last Quarter      59-65       phase_9.png
--  10  Waning Crescent   66-72       phase_10.png
--  11  Waning Crescent   73-79       phase_11.png
local function GetMoonPhaseRaw(moonDay)
    if moonDay >= 80 or moonDay <= 2 then
        return 0;
    else
        return math.floor((moonDay - 3) / 7) + 1;
    end
end

local function LoadTextures()
    for i = 0, 11 do
        local name = ELEMENT_NAMES[i];
        if name and not textures[i] then
            textures[i] = TextureManager.getFileTexture('VanaTime/elements/' .. name);
        end
    end
    for i = 0, 11 do
        if not moonPhaseTextures[i] then
            moonPhaseTextures[i] = TextureManager.getFileTexture('VanaTime/moon/phase_' .. i);
        end
    end
    if not arrowRightTex then
        arrowRightTex = TextureManager.getFileTexture('VanaTime/arrow_right');
    end
    if not moonUpTex then
        moonUpTex = TextureManager.getFileTexture('VanaTime/moon_up');
    end
    if not moonDownTex then
        moonDownTex = TextureManager.getFileTexture('VanaTime/moon_down');
    end
    if not clockIconTex then
        clockIconTex = TextureManager.getFileTexture('VanaTime/clock_icon');
    end
    if not gearIconTex then
        gearIconTex = TextureManager.getFileTexture('icons/gear');
    end
    if not todDayTex then
        todDayTex = TextureManager.getFileTexture('VanaTime/tod/tod_day');
    end
    if not todNightTex then
        todNightTex = TextureManager.getFileTexture('VanaTime/tod/tod_night');
    end
    if not todDeadNightTex then
        todDeadNightTex = TextureManager.getFileTexture('VanaTime/tod/tod_deadofnight');
    end
end

local function GetTexPtr(tex)
    if tex == nil then return nil; end
    return TextureManager.getTexturePtr(tex);
end

-- ── Color helpers ─────────────────────────────────────────────────────────────

local function ArgbR(c) return bit.band(bit.rshift(c, 16), 0xFF) / 255.0; end
local function ArgbG(c) return bit.band(bit.rshift(c,  8), 0xFF) / 255.0; end
local function ArgbB(c) return bit.band(c,                0xFF) / 255.0; end
local function ArgbA(c) return bit.band(bit.rshift(c, 24), 0xFF) / 255.0; end

local function ToU32(argb)
    return imgui.GetColorU32(ARGBToImGui(argb));
end

local function WithAlpha(argb, alpha)
    local a = math.floor(alpha * 255);
    return bit.bor(bit.lshift(a, 24), bit.band(argb, 0x00FFFFFF));
end

-- All elements use black outline (dark text reads better against the lit element colors)
local function GetOutlineColor(weekday)
    return 0xFF000000;
end

-- Returns pill background color for element group
-- ── Per-frame allocation sinks (reused across calls to avoid GC pressure) ─────
-- Shared position table for DrawTextWithOutline (replaces per-call {x, y} allocations)
local _textPos = {0, 0};

-- Cached measurement for the constant string "100%" at the current fontSize.
-- Avoids calling imtext.Measure (which does ImGui PushFont/CalcTextSize) 4× per frame.
-- Invalidated whenever fontSize changes (see the lastFontSize block in DrawWindow).
local _moonPctMeasW   = 0;
local _moonPctFontSz  = -1;

-- Draw text with a custom outline color (bypasses imtext's hardcoded black)
local function DrawTextWithOutline(drawList, text, x, y, textArgb, outlineArgb, fontSize)
    local font     = imtext.GetFont();
    local ow       = 1;
    local textU32  = ToU32(textArgb);
    local outU32   = ToU32(outlineArgb);
    -- apply SIZE_OFFSET to match imtext scaling
    local fs = fontSize and (fontSize + 2) or nil;
    -- shadow (reuse module-level _textPos to avoid per-call table allocation)
    _textPos[1] = x + ow; _textPos[2] = y + ow;
    if fs and font then
        drawList:AddText(font, fs, _textPos, outU32, text);
    else
        drawList:AddText(_textPos, outU32, text);
    end
    -- main text
    _textPos[1] = x; _textPos[2] = y;
    if fs and font then
        drawList:AddText(font, fs, _textPos, textU32, text);
    else
        drawList:AddText(_textPos, textU32, text);
    end
end

-- Draw a rounded pill rectangle behind text/icons
local function DrawPill(drawList, x, y, w, h, argb, rounding)
    local col = ToU32(argb);
    local r   = rounding or 4;
    drawList:AddRectFilled({x, y}, {x + w, y + h}, col, r);
end

-- ── Main window state (updated each frame for popup positioning) ──────────────

local mainWinPos   = {x=0, y=0};
local mainWinSize  = {w=0, h=0};
local cachedWeatherH = 0; -- used by 'above' positioning
local cachedWeatherW = 0; -- used by right-align positioning (accounts for double weather width)
local cachedTodH     = 0; -- used when TOD and weather share a left/right side
local cachedTodW     = 0; -- used when TOD and weather share an above/below side
-- Deferred Fenrir tooltip: set during Begin/End hover check, drawn after End() on the foreground list
local pendingFenrirTooltip = nil;  -- {moonDay, moonPercent}

-- Preview flags: set by config/vanatime.lua while the respective weather icon size sliders are
-- actively being dragged, so the weather popup previews correctly regardless of current weather.
if _G.XIUI_weatherElementalPreview == nil then _G.XIUI_weatherElementalPreview = false; end
if _G.XIUI_weatherBasePreview      == nil then _G.XIUI_weatherBasePreview      = false; end
-- Test-placement expiry: os.clock() timestamp; positive = test active (blinks the weather tab)
if _G.XIUI_weatherTestExpiry       == nil then _G.XIUI_weatherTestExpiry       = 0;     end

-- ── Draw helpers ──────────────────────────────────────────────────────────────

-- Draw a single day column: icon + moon% + weakness badge
-- colWeekday: 0-7 weekday for this column
-- moonPercent: moon % for this day (may differ past/future)
-- moonDay: day within the 84-day moon cycle (0=new, 42=full)
-- showMoon: whether to draw the moon% text row
local function DrawDayColumn(drawList, cx, cy, colWeekday, moonPercent, moonDay, alpha, iconSize, fontSize, colorConfig, showMoon, showBadge, disableIcons)
    local badgeSize = math.floor(iconSize * BADGE_SCALE);
    local arrowW    = math.floor(badgeSize * ARROW_SCALE);

    local elemArgb = colorConfig[ELEM_KEYS[colWeekday]] or 0xFFFFFFFF;

    -- Effective content width: icon, or moon row (phase icon + "100%" + arrow)
    local moonArrowSlot = showMoon and (math.floor(fontSize * 0.7) + 2) or 0;
    local phaseIconSlot = showMoon and (math.floor(fontSize + 2) + 2) or 0;
    local moonMaxW      = showMoon and (phaseIconSlot + _moonPctMeasW + moonArrowSlot) or 0;
    local colContentW   = math.max(iconSize, moonMaxW + 4);

    -- Row Y positions (badge is a corner overlay on the icon, not a separate row)
    local iconY  = cy;
    local moonY  = iconY + iconSize + 2;

    -- Full column height (no separate badge row)
    local colH = showMoon
        and (iconSize + 2 + fontSize + 4)
        or  (iconSize + 4);

    -- Column card: dark background + element-colored border.
    local cardPad = 4;
    local cardX   = cx - cardPad;
    local cardY   = cy - cardPad;
    local cardW   = colContentW + cardPad * 2;
    local cardH   = colH + cardPad * 2;
    drawList:AddRectFilled({cardX, cardY}, {cardX + cardW, cardY + cardH},
        ToU32(WithAlpha(0xFF050510, 0.70 * alpha)), 6);
    drawList:AddRect({cardX, cardY}, {cardX + cardW, cardY + cardH},
        ToU32(WithAlpha(elemArgb, alpha)), 6, nil, alpha >= 0.95 and 1.5 or 1.0);

    -- Element group glow removed — border color carries the light/dark affinity instead.
    local iconX = cx + math.floor((colContentW - iconSize) / 2);

    -- Flat black background behind the icon, or element-color fill when icons are disabled
    if disableIcons then
        drawList:AddRectFilled(
            {iconX, iconY}, {iconX + iconSize, iconY + iconSize},
            ToU32(WithAlpha(elemArgb, alpha * 0.85)), 3);
    else
        drawList:AddRectFilled(
            {iconX, iconY}, {iconX + iconSize, iconY + iconSize},
            ToU32(WithAlpha(0xFF000000, alpha)), 3);
    end

    -- Main element icon — skipped when icons are disabled
    if not disableIcons then
        local iconTex = GetTexPtr(textures[colWeekday]);
        if iconTex then
            local tint  = ToU32(WithAlpha(0xFFFFFFFF, alpha));
            drawList:AddImage(iconTex,
                {iconX, iconY}, {iconX + iconSize, iconY + iconSize}, {0,0}, {1,1}, tint);
        end
    end
    -- Border: XIUI gold for Light group, dark purple for Dark group
    local iconBorderArgb = LIGHT_GROUP[colWeekday] and 0xFFF4DA97 or 0xFF6A0DAD;
    drawList:AddRect(
        {iconX - 1, iconY - 1}, {iconX + iconSize + 1, iconY + iconSize + 1},
        ToU32(WithAlpha(iconBorderArgb, alpha * 0.85)), 4, nil, 1.0);

    -- Moon % text + direction arrow image (only when enabled)
    -- Layout: [phase icon][ ][XX%][ ][↑/↓ img]  — centered as a group within colContentW
    if showMoon then
        local moonStr     = string.format('%d%%', moonPercent);
        local outlineArgb = WithAlpha(GetOutlineColor(colWeekday), alpha);
        local textArgb    = WithAlpha(elemArgb, alpha);
        local moonW, _    = imtext.Measure(moonStr, fontSize);

        -- Phase icon (square, same height as font + 2 to match imtext rendered size)
        local phaseIconSize = math.floor(fontSize + 2);
        local phaseTex = GetTexPtr(moonPhaseTextures[GetMoonPhaseRaw(moonDay)]);

        -- Arrow image to the right of the % text
        local moonArrowSize = math.floor(fontSize * 0.7);  -- smaller, keeps aspect ratio
        local moonArrowTex  = nil;
        if moonDay > 0 and moonDay < 42 then
            moonArrowTex = GetTexPtr(moonUpTex);
        elseif moonDay > 42 then
            moonArrowTex = GetTexPtr(moonDownTex);
        end
        local arrowGap  = moonArrowTex and 2 or 0;
        local phaseGap  = phaseTex and (phaseIconSize + 2) or 0;

        -- Center the % TEXT itself under the element icon (same centering as iconX above).
        -- Phase disc floats to its left; direction arrow floats to its right.
        local moonTextX = cx + math.floor((colContentW - moonW) / 2);

        -- colH allocates fontSize+4 for the moon row; center everything in that row.
        -- Use full row height so all items share the same vertical midpoint.
        local moonRowH  = fontSize + 4;
        local moonBaseY = moonY + math.floor((moonRowH - fontSize) / 2);

        -- Moon pill border for New Moon (blood red) and Full Moon (moonlit blue).
        -- Phase check uses the same 7-day ranges as GetMoonPhaseRaw:
        --   New Moon  = moonDay >= 80 or moonDay <= 2
        --   Full Moon = moonDay >= 38 and moonDay <= 44
        -- Always drawn on any column (current/past/future); border alpha is scaled by column alpha.
        local totalMoonRowW = phaseGap + moonW + (moonArrowTex and (moonArrowSize + arrowGap) or 0);
        local isNewMoonPhase  = (moonDay >= 80 or moonDay <= 2);
        local isFullMoonPhase = (moonDay >= 38 and moonDay <= 44);
        if isNewMoonPhase or isFullMoonPhase then
            -- Center the pill around the full group (icon + text + arrow) within colContentW
            local pillPad = 4;
            local groupLeft = cx + math.floor((colContentW - totalMoonRowW) / 2);
            local pillX = groupLeft - pillPad;
            local pillY = moonBaseY - 3;
            local pillW = totalMoonRowW + pillPad * 2;
            local pillH = fontSize + 6;
            if isNewMoonPhase then
                DrawPill(drawList, pillX, pillY, pillW, pillH,
                    ToU32(WithAlpha(0xFF6B0000, 0.30 * alpha)), 4);
                drawList:AddRect({pillX, pillY}, {pillX + pillW, pillY + pillH},
                    ToU32(WithAlpha(0xFFCC2222, 0.85 * alpha)), 4, nil, 1.0);
            else
                DrawPill(drawList, pillX, pillY, pillW, pillH,
                    ToU32(WithAlpha(0xFF001833, 0.35 * alpha)), 4);
                drawList:AddRect({pillX, pillY}, {pillX + pillW, pillY + pillH},
                    ToU32(WithAlpha(0xFF4499FF, 0.85 * alpha)), 4, nil, 1.0);
            end
        end

        -- Phase disc icon: immediately left of the % text, centered in the row
        if phaseTex then
            local phIconX = moonTextX - phaseGap;
            local phIconY = moonY + math.floor((moonRowH - phaseIconSize) / 2);
            drawList:AddImage(phaseTex,
                {phIconX, phIconY}, {phIconX + phaseIconSize, phIconY + phaseIconSize},
                {0,0}, {1,1}, ToU32(WithAlpha(0xFFFFFFFF, alpha)));
        end

        DrawTextWithOutline(drawList, moonStr, moonTextX, moonBaseY, textArgb, outlineArgb, fontSize);

        -- Direction arrow: immediately right of the % text, centered in the row
        if moonArrowTex then
            local arrowX = moonTextX + moonW + arrowGap;
            local arrowY = moonY + math.floor((moonRowH - moonArrowSize) / 2);
            drawList:AddImage(moonArrowTex,
                {arrowX, arrowY}, {arrowX + moonArrowSize, arrowY + moonArrowSize},
                {0,0}, {1,1}, ToU32(WithAlpha(0xFFFFFFFF, alpha)));
        end
    end

    -- Weakness corner badge: small weakness element icon (or color fill) in bottom-right
    -- corner of the main icon, with a red border.
    local weakWeekday = ELEMENT_DEFEATS[colWeekday];
    if showBadge ~= false and weakWeekday ~= nil then
        local cornerX = iconX + iconSize - badgeSize;
        local cornerY = iconY + iconSize - badgeSize;
        -- Solid dark-red background so badge reads clearly
        drawList:AddRectFilled(
            {cornerX - 1, cornerY - 1}, {cornerX + badgeSize + 1, cornerY + badgeSize + 1},
            ToU32(WithAlpha(0xFF3B0000, alpha)), 2);
        if disableIcons then
            -- Color fill using weakness element's color
            local weakArgb = colorConfig[ELEM_KEYS[weakWeekday]] or 0xFFFFFFFF;
            drawList:AddRectFilled(
                {cornerX, cornerY}, {cornerX + badgeSize, cornerY + badgeSize},
                ToU32(WithAlpha(weakArgb, alpha * 0.85)), 2);
        else
            local badgeTex = GetTexPtr(textures[weakWeekday]);
            if badgeTex then
                drawList:AddImage(badgeTex,
                    {cornerX, cornerY}, {cornerX + badgeSize, cornerY + badgeSize},
                    {0,0}, {1,1}, ToU32(WithAlpha(0xFFFFFFFF, alpha)));
            end
        end
        -- Darker red border
        drawList:AddRect(
            {cornerX - 1, cornerY - 1}, {cornerX + badgeSize + 1, cornerY + badgeSize + 1},
            ToU32(WithAlpha(0xFF8B1010, alpha)), 2, nil, 1.0);
    end

    -- Return card rect so the caller can do hover detection / tooltips
    return cardX, cardY, cardW, cardH;
end

-- ── Fenrir tooltip ────────────────────────────────────────────────────────────

-- Called INSIDE Begin/End: checks hover, draws the card glow, stores deferred data.
local function DrawFenrirTooltip(drawList, cardX, cardY, cardW, cardH, moonDay, moonPercent)
    -- Bail if tooltips are globally disabled
    if not (gConfig and gConfig.vanaTimeEnableTooltips ~= false
        and (gConfig.vanaTimeTooltipFenrir or gConfig.vanaTimeTooltipSeleneBow)) then return; end
    if not imgui.IsMouseHoveringRect({cardX, cardY}, {cardX + cardW, cardY + cardH}) then
        return;
    end
    -- Hover glow: bright white border overlay
    drawList:AddRect({cardX, cardY}, {cardX + cardW, cardY + cardH},
        ToU32(0xCCFFFFFF), 6, nil, 2.0);
    -- Defer the actual tooltip draw to after imgui.End() so it lands on the foreground layer
    pendingFenrirTooltip = {moonDay, moonPercent};
end

-- Called AFTER imgui.End(): renders tooltip on the foreground draw list (always on top).
local function FlushFenrirTooltip()
    if not pendingFenrirTooltip then return; end
    local moonDay, moonPercent = pendingFenrirTooltip[1], pendingFenrirTooltip[2];
    pendingFenrirTooltip = nil;

    local showFenrir  = not gConfig or gConfig.vanaTimeTooltipFenrir  ~= false;
    local showSelene  = not gConfig or gConfig.vanaTimeTooltipSeleneBow ~= false;
    if not showFenrir and not showSelene then return; end

    local phaseIdx  = GetMoonPhaseRaw(moonDay);
    local phaseName = PHASE_NAMES[phaseIdx] or '?';

    local dl = imgui.GetForegroundDrawList();
    if not dl then return; end

    local fontSize    = 12;
    local pad         = 8;
    local lineSpacing = fontSize + 5;
    local colGap      = 10;
    local sectionGap  = math.floor(pad * 0.5);  -- extra space between sections

    imtext.SetConfig('Tahoma', false, 1);

    -- ── Build row list ──────────────────────────────────────────────────────
    -- Each row: {kind, label, value}
    --   kind = 'header' | 'sep' | 'row'
    local rows = {};
    local function addRow(lbl, val) rows[#rows+1] = {'row', lbl, val}; end
    local function addSep()         rows[#rows+1] = {'sep', '', ''}; end
    local function addHeader(txt)   rows[#rows+1] = {'header', txt, ''}; end

    if showFenrir then
        local lc = LUNAR_CRY[phaseIdx];
        local eh = ECLIPTIC_HOWL[phaseIdx];
        local eg = ECLIPTIC_GROWL[phaseIdx];
        if lc and eh and eg then
            addHeader('Fenrir Pacts');
            addRow('Lunar Cry',      string.format('Acc %+d   Eva %+d', lc[1], lc[2]));
            addRow('Ecliptic Howl',  string.format('Acc %+d   Eva %+d', eh[1], eh[2]));
            addRow('Ecliptic Growl', string.format('STR/DEX/VIT %+d   AGI/INT/MND/CHR %+d', eg[1], eg[2]));
        end
    end

    if showSelene then
        local sb = SELENE_BOW[phaseIdx];
        if sb then
            if showFenrir then addSep(); end
            addHeader("Selene's Bow");
            addRow('Rng Acc / Atk', string.format('%+d RAcc   %+d RAtk', sb[1], sb[2]));
        end
    end

    if #rows == 0 then return; end

    -- ── Measure ──────────────────────────────────────────────────────────
    local labelColW = 0;
    local valueColW = 0;
    for _, r in ipairs(rows) do
        if r[1] == 'row' then
            local lw = imtext.Measure(r[2], fontSize);
            local vw = imtext.Measure(r[3], fontSize);
            if lw > labelColW then labelColW = lw; end
            if vw > valueColW then valueColW = vw; end
        end
    end
    labelColW = labelColW + colGap;

    local headerStr = phaseName .. '  (' .. moonPercent .. '%)';
    local headerW   = imtext.Measure(headerStr, fontSize);

    -- measure section header widths too
    local maxSecW = 0;
    for _, r in ipairs(rows) do
        if r[1] == 'header' then
            local hw = imtext.Measure(r[2], fontSize);
            if hw > maxSecW then maxSecW = hw; end
        end
    end

    local separatorH = math.floor(pad * 0.75);
    local contentW   = math.max(headerW, maxSecW, labelColW + valueColW);
    local boxW       = contentW + pad * 2;

    -- Count row heights: header row has a small divider above it (except first), sep = thin line
    local boxH = pad + lineSpacing + separatorH;  -- phase header + main sep
    for i, r in ipairs(rows) do
        if r[1] == 'row' then
            boxH = boxH + lineSpacing;
        elseif r[1] == 'header' then
            -- section header line
            boxH = boxH + lineSpacing;
        elseif r[1] == 'sep' then
            boxH = boxH + sectionGap * 2 + 1;  -- thin line + spacing
        end
    end
    boxH = boxH + pad;

    -- ── Position relative to VanaTime window ──────────────────────────────
    local direction = (gConfig and gConfig.vanaTimeTooltipDirection) or 'above';
    local ox = mainWinPos.x + math.floor((mainWinSize.w - boxW) / 2);
    local oy;
    if direction == 'below' then
        oy = mainWinPos.y + mainWinSize.h + 4;
    else
        oy = mainWinPos.y - boxH - 4;
    end

    -- ── Draw background + border ──────────────────────────────────────────
    local bgCol     = imgui.GetColorU32({0.06, 0.06, 0.07, 0.92});
    local borderCol = imgui.GetColorU32({0.45, 0.45, 0.45, 1.0});
    dl:AddRectFilled({ox, oy}, {ox + boxW, oy + boxH}, bgCol, 4);
    dl:AddRect({ox, oy}, {ox + boxW, oy + boxH}, borderCol, 4, nil, 1.0);

    -- ── Draw header ───────────────────────────────────────────────────────
    local curY = oy + pad;
    imtext.Draw(dl, headerStr, ox + pad, curY, 0xFFF4DA97, fontSize);
    curY = curY + lineSpacing;

    -- main separator
    local sepLineY = curY + math.floor(separatorH / 2);
    dl:AddLine({ox + pad, sepLineY}, {ox + boxW - pad, sepLineY},
        imgui.GetColorU32({0.35, 0.35, 0.35, 1.0}), 1.0);
    curY = curY + separatorH;

    -- ── Draw rows ─────────────────────────────────────────────────────────
    local sepLineCol  = imgui.GetColorU32({0.28, 0.28, 0.28, 1.0});

    for _, r in ipairs(rows) do
        local kind, a, b = r[1], r[2], r[3];
        if kind == 'header' then
            imtext.Draw(dl, a, ox + pad, curY, 0xFFCBAA50, fontSize);
            curY = curY + lineSpacing;
        elseif kind == 'row' then
            imtext.Draw(dl, a, ox + pad,             curY, 0xFFAAAAAA, fontSize);
            imtext.Draw(dl, b, ox + pad + labelColW, curY, 0xFFFFFFFF, fontSize);
            curY = curY + lineSpacing;
        elseif kind == 'sep' then
            curY = curY + sectionGap;
            dl:AddLine({ox + pad, curY}, {ox + boxW - pad, curY}, sepLineCol, 1.0);
            curY = curY + sectionGap + 1;
        end
    end
end

-- ── Window flags ──────────────────────────────────────────────────────────────

local WIN_FLAGS_BASE = bit.bor(
    ImGuiWindowFlags_NoDecoration,
    ImGuiWindowFlags_AlwaysAutoResize,
    ImGuiWindowFlags_NoFocusOnAppearing,
    ImGuiWindowFlags_NoNav,
    ImGuiWindowFlags_NoBackground,
    ImGuiWindowFlags_NoBringToFrontOnFocus,
    ImGuiWindowFlags_NoDocking
);

local WIN_FLAGS_WEATHER = bit.bor(
    WIN_FLAGS_BASE,
    ImGuiWindowFlags_NoMove,
    ImGuiWindowFlags_NoSavedSettings
);

-- Timers popup uses ImGui-drawn background (no NoBackground) so PushStyleColor controls it.
-- NoBringToFrontOnFocus is intentionally OMITTED so SetNextWindowFocus() can keep it on top.
local WIN_FLAGS_TIMERS = bit.bor(
    ImGuiWindowFlags_NoDecoration,
    ImGuiWindowFlags_AlwaysAutoResize,
    ImGuiWindowFlags_NoFocusOnAppearing,
    ImGuiWindowFlags_NoNav,
    ImGuiWindowFlags_NoDocking,
    ImGuiWindowFlags_NoMove,
    ImGuiWindowFlags_NoSavedSettings
);

-- ── Public API ────────────────────────────────────────────────────────────────

function M.Initialize()
    LoadTextures();
end

function M.Reset()
    -- Called on UpdateVisuals (settings change) — flush cached time strings
    -- so the next frame re-evaluates with updated settings.
    vtCache    = { hour = -1, min = -1, str = '', measW = 0 };
    ltCache    = { osMin = -1, osHour = -1, str = '', measW = 0 };
    lastOsTime  = -1;
    lastFontSize = -1;
end

function M.Cleanup()
    textures = {};
    moonPhaseTextures = {};
    arrowRightTex = nil;
    moonUpTex     = nil;
    moonDownTex   = nil;
    clockIconTex  = nil;
    gearIconTex   = nil;
    todDayTex       = nil;
    todNightTex     = nil;
    todDeadNightTex = nil;
    timersOpen    = false;
end

function M.DrawWindow(weatherId)
    local cfg       = gConfig;
    if not cfg then return; end
    -- Clear deferred tooltip from any previous frame
    pendingFenrirTooltip = nil;
    local colorCfg  = (cfg.colorCustomization or {}).vanaTime or {};
    local scale     = math.max(0.5, math.min(2.0,  cfg.vanaTimeScale    or 1.0));
    local fontSize  = math.floor(math.max(8,  math.min(24, cfg.vanaTimeFontSize or 12)) * scale);
    local iconSize  = math.floor(math.max(16, math.min(64, cfg.vanaTimeIconSize  or 28)) * scale);
    local rounding  = 12.0;

    -- ── Get game data (pure Lua — no FFI) ───────────────────────────────────
    local rawTime       = GetRawTime();
    local weekday       = math.floor(rawTime / VD_DAY_SEC) % 8;
    local vtDay         = math.floor(rawTime / VD_DAY_SEC);
    local vtHour        = math.floor(rawTime % VD_DAY_SEC / VD_HOUR_SEC);
    local vtMin         = math.floor(rawTime % VD_HOUR_SEC / VD_MIN_F);
    local vtMinuteOfDay = vtHour * 60 + vtMin;
    local moonDay       = (math.floor(rawTime / VD_DAY_SEC) + VD_MOON_OFFSET) % VD_MOON_DAYS;
    local moonPct       = CalcMoonPercent(moonDay);

    -- Feed timers cache when the panel is open (no-op cost when closed)
    local showTimers = cfg.vanaTimeShowTimers ~= false;
    if showTimers and timersOpen then
        timers.Update(os.time(), vtMinuteOfDay, vtDay, moonDay);
    end

    -- Past / future days
    local pastWeekday   = (weekday  - 1 + 8)           % 8;
    local futureWeekday = (weekday  + 1)                % 8;
    local pastMoonDay   = (moonDay  - 1 + VD_MOON_DAYS) % VD_MOON_DAYS;
    local futureMoonDay = (moonDay  + 1)                % VD_MOON_DAYS;
    local pastMoonPct   = CalcMoonPercent(pastMoonDay);
    local futureMoonPct = CalcMoonPercent(futureMoonDay);

    -- VT string — only reformat when minute changes (VT minute = every 2.4 real sec)
    if vtHour ~= vtCache.hour or vtMin ~= vtCache.min then
        vtCache.hour  = vtHour;
        vtCache.min   = vtMin;
        vtCache.str   = string.format('VT: %02d:%02d', vtHour, vtMin);
        vtCache.measW = 0;  -- force re-measure next frame
    end
    local vtStr = vtCache.str;

    -- LT string — only rebuild when the real-time hour or minute changes
    local ltStr = '';
    if cfg.vanaTimeShowLocalTime ~= false then
        local now = os.time();
        if now ~= lastOsTime then
            lastOsTime = now;
            local lt   = os.date('*t', now);
            local h    = lt.hour;
            local m    = lt.min;
            local ampm = h >= 12 and 'PM' or 'AM';
            local h12  = h % 12;
            if h12 == 0 then h12 = 12; end
            if h ~= ltCache.osHour or m ~= ltCache.osMin then
                ltCache.osHour = h;
                ltCache.osMin  = m;
                ltCache.str    = string.format('LT: %02d:%02d %s', h12, m, ampm);
                ltCache.measW  = 0;  -- force re-measure next frame
            end
        end
        ltStr = ltCache.str;
    end

    -- Element color for current day (ELEM_KEYS is a module-level constant — no alloc)
    -- vtTextColor resolved inside pcall to avoid contributing an extra upvalue.

    -- ── Column layout geometry ───────────────────────────────────────────────
    -- colPad stays here because PushStyleVar below needs it.
    local colPad = 8;  -- window padding

    -- Cache measurement updates — run every frame so strings are ready when window opens.
    if fontSize ~= lastFontSize then
        lastFontSize  = fontSize;
        vtCache.measW = 0;
        ltCache.measW = 0;
        -- Also invalidate the "100%" moon-percent measurement cache (used by DrawDayColumn).
        _moonPctFontSz = -1;
    end
    if vtCache.measW == 0 then
        vtCache.measW = imtext.Measure(vtCache.str, fontSize);
    end
    if ltStr ~= '' and ltCache.measW == 0 then
        ltCache.measW = imtext.Measure(ltCache.str, fontSize);
    end
    -- Measure "100%" once per unique fontSize; reused in DrawDayColumn and the outer layout.
    if _moonPctFontSz ~= fontSize then
        _moonPctFontSz = fontSize;
        _moonPctMeasW  = imtext.Measure('100%', fontSize);
    end

    -- ── Window open ──────────────────────────────────────────────────────────
    local windowFlags = GetBaseWindowFlags(cfg.lockPositions);

    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, rounding);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, {colPad, colPad});

    ApplyWindowPosition('VanaTime');

    local ok, err = pcall(function()
    if imgui.Begin('VanaTime', true, windowFlags) then
        SaveWindowPosition('VanaTime');

        local wx, wy   = imgui.GetWindowPos();
        local ww, wh   = imgui.GetWindowSize();
        mainWinPos.x   = wx;
        mainWinPos.y   = wy;
        mainWinSize.w  = ww;
        mainWinSize.h  = wh;

        -- ── Layout geometry (locals here so they don't add outer upvalues) ──────
        local elemArgb    = colorCfg[ELEM_KEYS[weekday]] or 0xFFFFFFFF;
        local outlineArgb = GetOutlineColor(weekday);
        local vtTextColor = cfg.vanaTimeVTElementColor and elemArgb or VT_TEXT_COLOR;

        local CARD_PAD       = 4;
        local SEP_GAP        = 4;
        local arrowW         = fontSize + 2;
        local sepArrowW      = math.floor(iconSize * 0.5);

        local showGear     = cfg.vanaTimeShowSettingsBtn ~= false;
        local showPastFuture  = cfg.vanaTimeShowPastFuture ~= false;
        local showMoon        = cfg.vanaTimeShowMoonPercent ~= false;
        local showBadge       = cfg.vanaTimeShowWeaknessBadge ~= false;
        local plainDayIcons   = cfg.vanaTimePlainDayIcons == true;
        local pastFutureAlpha = cfg.vanaTimePastFutureOpacity or PAST_FUTURE_ALPHA;

        local moonArrowSlot = showMoon and (math.floor(fontSize * 0.7) + 2) or 0;
        local phaseIconSlot = showMoon and (math.floor(fontSize + 2) + 2) or 0;
        local moonMaxW      = showMoon and (phaseIconSlot + _moonPctMeasW + moonArrowSlot) or 0;
        local colContentW   = math.max(iconSize, moonMaxW + 4);
        local cardW         = colContentW + CARD_PAD * 2;
        local cardAreaW     = showPastFuture
            and (cardW * 3 + SEP_GAP * 4 + sepArrowW * 2)
            or  cardW;

        local clockH   = fontSize + 4;
        local colH     = showMoon and (iconSize + 2 + fontSize + 4) or (iconSize + 4);
        local contentW = cardAreaW;
        local vtMeasW  = vtCache.measW;
        local ltMeasW  = ltStr ~= '' and ltCache.measW or 0;

        local totalH = clockH + colH + colPad;
        local ltBelowColumns = (not showPastFuture) and (ltStr ~= '');
        if not showPastFuture then
            local inlineTodW = (not cfg.vanaTimeTodPopup) and (clockH + 3) or 0;
            -- How many icon slots appear in the right zone of the clock row?
            local numIcons   = (showTimers and 1 or 0) + (showGear and 1 or 0);
            local iconZoneW  = numIcons > 0 and (numIcons * clockH + (numIcons - 1) * 2 + 4) or 0;
            local vtRowNeed  = vtMeasW + inlineTodW + 8 + iconZoneW;
            local ltRowNeed  = ltStr ~= '' and (ltMeasW + 8) or 0;
            contentW = math.max(contentW, vtRowNeed, ltRowNeed);
        end
        if ltBelowColumns then
            totalH = totalH + clockH + 2;
        end

        local cx0, cy0 = imgui.GetCursorScreenPos();
        local drawList = imgui.GetWindowDrawList();

        -- ── Window background ────────────────────────────────────────────────
        local bgPad  = colPad;
        local bgX    = cx0 - bgPad;
        local bgY    = cy0 - bgPad;
        local bgW    = contentW + bgPad * 2;
        local bgH    = totalH  + bgPad * 2;
        local bgOpacity = cfg.vanaTimeBackgroundOpacity or 0.85;
        local bgRgb  = colorCfg.bgColor or 0xFF000000;

        local bgTheme     = 'Plain';    -- locked: Background = Plain
        local borderTheme = 'Window1';  -- locked: Border = Window1

        if bgTheme:match('^Window%d+$') then
            -- Nine-slice textured background
            windowbg.Draw(drawList, cx0, cy0, contentW, totalH, {
                theme         = bgTheme,
                bgScale       = cfg.vanaTimeBgScale or 1.0,
                bgOpacity     = bgOpacity,
                borderScale   = 0,
                borderOpacity = 0,
                bgColor       = bgRgb,
                borderColor   = 0x00000000,
                padding       = colPad,
            });
        elseif bgTheme ~= '-None-' then
            -- Plain theme: horizontal gradient, transparent at edges → opaque at center
            local opaqueU32 = ToU32(WithAlpha(bgRgb, bgOpacity));
            local transpU32 = ToU32(WithAlpha(bgRgb, 0.0));
            local midX      = bgX + bgW / 2;
            drawList:AddRectFilledMultiColor(
                {bgX,  bgY}, {midX, bgY + bgH},
                transpU32, opaqueU32, opaqueU32, transpU32);
            drawList:AddRectFilledMultiColor(
                {midX, bgY}, {bgX + bgW, bgY + bgH},
                opaqueU32, transpU32, transpU32, opaqueU32);
        end

        -- ── Border decoration ─────────────────────────────────────────────────
        if borderTheme:match('^Window%d+$') then
            windowbg.Draw(drawList, cx0, cy0, contentW, totalH, {
                theme         = borderTheme,
                bgScale       = 0,
                bgOpacity     = 0,
                borderScale   = cfg.vanaTimeBorderScale or 1.0,
                borderOpacity = cfg.vanaTimeBorderOpacity or 1.0,
                bgColor       = 0x00000000,
                borderColor   = colorCfg.borderColor or 0xFFFFFFFF,
                padding       = colPad,
            });
        elseif borderTheme == 'Plain' then
            local borderArgb = WithAlpha(colorCfg.borderColor or 0xFFFFFFFF, cfg.vanaTimeBorderOpacity or 1.0);
            drawList:AddRect({bgX, bgY}, {bgX + bgW, bgY + bgH}, ToU32(borderArgb), rounding, nil, 1.0);
        end

        -- ── Spacer for imgui layout (prevents window collapsing to zero) ─────
        imgui.Dummy({contentW, totalH});

        -- ── Clock row ────────────────────────────────────────────────────────
        local clockY = cy0;

        -- Elemental glow strip behind the clock row
        do
            local gY   = clockY - 2;
            local gH   = clockH + 4;
            local gX1  = cx0 - 4;
            local gX2  = cx0 + contentW + 4;
            local midX = (gX1 + gX2) / 2;
            local glow   = ToU32(WithAlpha(elemArgb, 0.28));
            local transp = ToU32(WithAlpha(elemArgb, 0.0));
            drawList:AddRectFilledMultiColor({gX1, gY}, {midX, gY + gH}, transp, glow, glow, transp);
            drawList:AddRectFilledMultiColor({midX, gY}, {gX2, gY + gH}, glow, transp, transp, glow);
        end

        -- Three layout modes:
        --  No timers           → VT centred (or VT|LT split halves)
        --  Timers, no LT       → left 2/3 VT  |  right 1/3 clock icon
        --  Timers + LT         → equal thirds: VT | clock icon | LT
        local iconSzClock = clockH;  -- square: icon fits the clock row height

        -- ── Time-of-day icon (placed right after the VT text in every layout) ──
        -- Dead of Night 20:00-03:59  |  Day 06:00-17:59  |  Night otherwise
        local todIconSize = clockH;
        local todTexRaw =
            (vtHour >= 20 or vtHour < 4)                and todDeadNightTex
            or (vtHour >= 6 and vtHour < 18)            and todDayTex
            or todNightTex;
        local todTex = GetTexPtr(todTexRaw);

        local function DrawTodIcon(vtX)
            if not todTex then return end;
            if cfg.vanaTimeTodPopup then return end; -- shown in its own tab instead
            local tx = vtX + vtMeasW + 3;
            local ty = clockY + math.floor((clockH - todIconSize) / 2);
            drawList:AddImage(todTex, {tx, ty}, {tx + todIconSize, ty + todIconSize},
                {0,0}, {1,1}, ToU32(0xEEFFFFFF));
        end

        -- Hover tooltips for VT and LT text regions
        local function DrawClockTooltips(vtX, ltX, ltClockY)
            if cfg.vanaTimeEnableTooltips == false then return end;
            local ltY = ltClockY or clockY;
            if imgui.IsMouseHoveringRect({vtX, clockY}, {vtX + vtMeasW, clockY + clockH}) then
                if cfg.vanaTimeTipVT ~= false then imgui.SetTooltip("Vana'diel Time"); end
            elseif ltX and ltMeasW > 0
                and imgui.IsMouseHoveringRect({ltX, ltY}, {ltX + ltMeasW, ltY + clockH}) then
                if cfg.vanaTimeTipLT ~= false then imgui.SetTooltip('Local Time'); end
            end
        end

        if showTimers then
            local iconTex = GetTexPtr(clockIconTex);
            if ltBelowColumns then
                -- VT left 2/3 + clock icon right 1/3; LT draws below columns
                local twoThird = math.floor(contentW * 2 / 3);
                local vtX  = cx0 + math.floor((twoThird - vtMeasW) / 2);
                local icX  = cx0 + twoThird + math.floor(((contentW - twoThird) - iconSzClock) / 2);
                local icY  = clockY + math.floor((clockH - iconSzClock) / 2);
                DrawTextWithOutline(drawList, vtStr, vtX, clockY, vtTextColor, outlineArgb, fontSize);
                DrawTodIcon(vtX);
                clockIconRect.x = icX; clockIconRect.y = icY;
                clockIconRect.w = iconSzClock; clockIconRect.h = iconSzClock;
                DrawClockTooltips(vtX, nil);
            elseif ltStr ~= '' then
                -- Equal thirds: VT | clock icon | LT
                local third = math.floor(contentW / 3);
                local vtX  = cx0 + math.floor((third - vtMeasW) / 2);
                local icX  = cx0 + third + math.floor((third - iconSzClock) / 2);
                local icY  = clockY + math.floor((clockH - iconSzClock) / 2);
                local ltX  = cx0 + third * 2 + math.floor((third - ltMeasW) / 2);
                DrawTextWithOutline(drawList, vtStr, vtX, clockY, vtTextColor, outlineArgb, fontSize);
                DrawTodIcon(vtX);
                DrawTextWithOutline(drawList, ltStr, ltX, clockY, colorCfg.textColor or 0xFFFFFFFF, outlineArgb, fontSize);
                clockIconRect.x = icX; clockIconRect.y = icY;
                clockIconRect.w = iconSzClock; clockIconRect.h = iconSzClock;
                DrawClockTooltips(vtX, ltX);
            else
                -- VT in left 2/3, icon in right 1/3
                local twoThird = math.floor(contentW * 2 / 3);
                local vtX  = cx0 + math.floor((twoThird - vtMeasW) / 2);
                local icX  = cx0 + twoThird + math.floor(((contentW - twoThird) - iconSzClock) / 2);
                local icY  = clockY + math.floor((clockH - iconSzClock) / 2);
                DrawTextWithOutline(drawList, vtStr, vtX, clockY, vtTextColor, outlineArgb, fontSize);
                DrawTodIcon(vtX);
                clockIconRect.x = icX; clockIconRect.y = icY;
                clockIconRect.w = iconSzClock; clockIconRect.h = iconSzClock;
                DrawClockTooltips(vtX, nil);
            end
            -- Glow disc behind icon — black so the white icon reads clearly
            local icx, icy, isz = clockIconRect.x, clockIconRect.y, clockIconRect.w;

            -- If gear is also showing, re-center the pair within the right zone.
            if showGear then
                -- Re-derive zone start from the branch above for accuracy.
                -- Pair: clock + 2px gap + gear
                local pairW      = isz * 2 + 2;
                -- The right zone for the current branch: from the raw icX formula we can
                -- back-calculate; easier to just shift icx left by half the gear + gap.
                icx = icx - math.floor((isz + 2) / 2);
                clockIconRect.x = icx;
            end

            local cx2, cy2 = icx + isz * 0.5, icy + isz * 0.5;
            local glowAlpha = timersOpen and 0xAA or 0x66;
            drawList:AddCircleFilled({cx2, cy2}, isz * 0.65,
                ToU32(bit.bor(bit.lshift(glowAlpha, 24), 0x000000)), 24);
            -- Icon
            if iconTex then
                drawList:AddImage(iconTex, {icx, icy}, {icx + isz, icy + isz},
                    {0, 0}, {1, 1}, ToU32(0xCCFFFFFF));
            end
            -- Hover highlight + click
            if imgui.IsMouseHoveringRect({icx, icy}, {icx + isz, icy + isz}) then
                drawList:AddCircleFilled({cx2, cy2}, isz * 0.65, ToU32(0x30FFFFFF), 24);
                if imgui.IsMouseClicked(0) then
                    timersOpen    = not timersOpen;
                    firstTimerFrame = timersOpen;
                    if timersOpen then
                        timersLastActivity = os.clock();
                        timersOpenedAt     = os.clock();
                    end
                end
            end

            -- Gear icon sits immediately to the right of the clock icon.
            if showGear then
                local gearTex = GetTexPtr(gearIconTex);
                local gx      = icx + isz + 2;
                local gy      = icy;
                local gc2x, gc2y = gx + isz * 0.5, gy + isz * 0.5;
                drawList:AddCircleFilled({gc2x, gc2y}, isz * 0.65,
                    ToU32(bit.bor(bit.lshift(0x55, 24), 0x000000)), 24);
                if gearTex then
                    drawList:AddImage(gearTex, {gx, gy}, {gx + isz, gy + isz},
                        {0,0}, {1,1}, ToU32(0xCCC3AE79));
                end
                if imgui.IsMouseHoveringRect({gx, gy}, {gx + isz, gy + isz}) then
                    drawList:AddCircleFilled({gc2x, gc2y}, isz * 0.65, ToU32(0x30FFFFFF), 24);
                    if cfg.vanaTimeEnableTooltips ~= false then
                        imgui.SetTooltip('VanaTime Settings');
                    end
                    if imgui.IsMouseClicked(0) and XIUI_ToggleVanaTimeConfig then
                        XIUI_ToggleVanaTimeConfig();
                    end
                end
            end
        elseif ltBelowColumns then
            -- VT in left zone; LT draws below columns (past/future hidden, no timers)
            -- If gear is shown, split left 2/3 / right 1/3; otherwise center VT.
            local twoThird = showGear and math.floor(contentW * 2 / 3) or contentW;
            local vtX = cx0 + math.floor((twoThird - vtMeasW) / 2);
            DrawTextWithOutline(drawList, vtStr, vtX, clockY, vtTextColor, outlineArgb, fontSize);
            DrawTodIcon(vtX);
            DrawClockTooltips(vtX, nil);
            if showGear then
                local gearTex = GetTexPtr(gearIconTex);
                local gx  = cx0 + twoThird + math.floor(((contentW - twoThird) - iconSzClock) / 2);
                local gy  = clockY + math.floor((clockH - iconSzClock) / 2);
                local gc2x, gc2y = gx + iconSzClock * 0.5, gy + iconSzClock * 0.5;
                drawList:AddCircleFilled({gc2x, gc2y}, iconSzClock * 0.65, ToU32(bit.bor(bit.lshift(0x55, 24), 0x000000)), 24);
                if gearTex then
                    drawList:AddImage(gearTex, {gx, gy}, {gx + iconSzClock, gy + iconSzClock}, {0,0}, {1,1}, ToU32(0xCCC3AE79));
                end
                if imgui.IsMouseHoveringRect({gx, gy}, {gx + iconSzClock, gy + iconSzClock}) then
                    drawList:AddCircleFilled({gc2x, gc2y}, iconSzClock * 0.65, ToU32(0x30FFFFFF), 24);
                    if cfg.vanaTimeEnableTooltips ~= false then imgui.SetTooltip('VanaTime Settings'); end
                    if imgui.IsMouseClicked(0) and XIUI_ToggleVanaTimeConfig then XIUI_ToggleVanaTimeConfig(); end
                end
            end
        elseif ltStr ~= '' then
            -- Original two-column layout: VT centred in left half, LT in right half
            local halfW = contentW / 2;
            local vtX   = cx0 + math.floor((halfW - vtMeasW) / 2);
            local ltX   = cx0 + halfW + math.floor((halfW - ltMeasW) / 2);
            DrawTextWithOutline(drawList, vtStr, vtX, clockY, vtTextColor, outlineArgb, fontSize);
            DrawTodIcon(vtX);
            DrawTextWithOutline(drawList, ltStr, ltX, clockY, colorCfg.textColor or 0xFFFFFFFF, outlineArgb, fontSize);
            DrawClockTooltips(vtX, ltX);
            -- Gear icon: drawn after LT, in a small slot at the far right if space allows
            if showGear then
                local gearTex = GetTexPtr(gearIconTex);
                local gx  = cx0 + contentW - iconSzClock;
                local gy  = clockY + math.floor((clockH - iconSzClock) / 2);
                local gc2x, gc2y = gx + iconSzClock * 0.5, gy + iconSzClock * 0.5;
                drawList:AddCircleFilled({gc2x, gc2y}, iconSzClock * 0.65, ToU32(bit.bor(bit.lshift(0x55, 24), 0x000000)), 24);
                if gearTex then
                    drawList:AddImage(gearTex, {gx, gy}, {gx + iconSzClock, gy + iconSzClock}, {0,0}, {1,1}, ToU32(0xCCC3AE79));
                end
                if imgui.IsMouseHoveringRect({gx, gy}, {gx + iconSzClock, gy + iconSzClock}) then
                    drawList:AddCircleFilled({gc2x, gc2y}, iconSzClock * 0.65, ToU32(0x30FFFFFF), 24);
                    if cfg.vanaTimeEnableTooltips ~= false then imgui.SetTooltip('VanaTime Settings'); end
                    if imgui.IsMouseClicked(0) and XIUI_ToggleVanaTimeConfig then XIUI_ToggleVanaTimeConfig(); end
                end
            end
        else
            -- VT in left zone; gear in right zone if enabled, otherwise VT fully centered.
            local twoThird = showGear and math.floor(contentW * 2 / 3) or contentW;
            local vtX = cx0 + math.floor((twoThird - vtMeasW) / 2);
            DrawTextWithOutline(drawList, vtStr, vtX, clockY, vtTextColor, outlineArgb, fontSize);
            DrawTodIcon(vtX);
            DrawClockTooltips(vtX, nil);
            if showGear then
                local gearTex = GetTexPtr(gearIconTex);
                local gx  = cx0 + twoThird + math.floor(((contentW - twoThird) - iconSzClock) / 2);
                local gy  = clockY + math.floor((clockH - iconSzClock) / 2);
                local gc2x, gc2y = gx + iconSzClock * 0.5, gy + iconSzClock * 0.5;
                drawList:AddCircleFilled({gc2x, gc2y}, iconSzClock * 0.65, ToU32(bit.bor(bit.lshift(0x55, 24), 0x000000)), 24);
                if gearTex then
                    drawList:AddImage(gearTex, {gx, gy}, {gx + iconSzClock, gy + iconSzClock}, {0,0}, {1,1}, ToU32(0xCCC3AE79));
                end
                if imgui.IsMouseHoveringRect({gx, gy}, {gx + iconSzClock, gy + iconSzClock}) then
                    drawList:AddCircleFilled({gc2x, gc2y}, iconSzClock * 0.65, ToU32(0x30FFFFFF), 24);
                    if cfg.vanaTimeEnableTooltips ~= false then imgui.SetTooltip('VanaTime Settings'); end
                    if imgui.IsMouseClicked(0) and XIUI_ToggleVanaTimeConfig then XIUI_ToggleVanaTimeConfig(); end
                end
            end
        end  -- closes: if showTimers / elseif ltBelowColumns / elseif ltStr / else

        -- ── Day columns ──────────────────────────────────────────────────────
        local colY   = cy0 + clockH + colPad;
        local cardX0 = cx0;  -- cards start at the content origin (no offset needed)

        if showPastFuture then
            -- Column cx values: DrawDayColumn draws card at (cx - CARD_PAD),
            -- so cx = card_left + CARD_PAD.  First card starts at cx0.
            local pastX = cardX0 + CARD_PAD;

            local pcx, pcy, pcw, pch = DrawDayColumn(drawList, pastX, colY, pastWeekday,
                pastMoonPct, pastMoonDay, pastFutureAlpha,
                iconSize, fontSize, colorCfg, showMoon, showBadge, plainDayIcons);
            DrawFenrirTooltip(drawList, pcx, pcy, pcw, pch, pastMoonDay, pastMoonPct);

            -- Separator arrow: starts right after past card's right edge
            local arr1X  = pastX + colContentW + CARD_PAD + SEP_GAP;
            local arrImgW = sepArrowW;
            local arrImgH = math.floor(colH * 0.75);
            local arr1Y   = colY + math.floor((colH - arrImgH) / 2);
            local arrTex  = GetTexPtr(arrowRightTex);
            local arrTint = ToU32(0xC0FFFFFF);
            if arrTex then
                drawList:AddImage(arrTex, {arr1X, arr1Y}, {arr1X + arrImgW, arr1Y + arrImgH},
                    {0,0}, {1,1}, arrTint);
            else
                DrawTextWithOutline(drawList, COL_ARROW, arr1X, colY + math.floor((colH - fontSize) / 2),
                    0xFFFFFFFF, 0xFF000000, fontSize);
            end

            -- Current column: card left = arr1X + sepArrowW + SEP_GAP
            local curX = arr1X + sepArrowW + SEP_GAP + CARD_PAD;
            local ccx, ccy, ccw, cch = DrawDayColumn(drawList, curX, colY, weekday,
                moonPct, moonDay, 1.0,
                iconSize, fontSize, colorCfg, showMoon, showBadge, plainDayIcons);
            DrawFenrirTooltip(drawList, ccx, ccy, ccw, cch, moonDay, moonPct);

            -- Second separator arrow
            local arr2X = curX + colContentW + CARD_PAD + SEP_GAP;
            if arrTex then
                drawList:AddImage(arrTex, {arr2X, arr1Y}, {arr2X + arrImgW, arr1Y + arrImgH},
                    {0,0}, {1,1}, arrTint);
            else
                DrawTextWithOutline(drawList, COL_ARROW, arr2X, colY + math.floor((colH - fontSize) / 2),
                    0xFFFFFFFF, 0xFF000000, fontSize);
            end

            -- Future column: card left = arr2X + sepArrowW + SEP_GAP
            local futX = arr2X + sepArrowW + SEP_GAP + CARD_PAD;
            local fcx, fcy, fcw, fch = DrawDayColumn(drawList, futX, colY, futureWeekday,
                futureMoonPct, futureMoonDay, pastFutureAlpha,
                iconSize, fontSize, colorCfg, showMoon, showBadge, plainDayIcons);
            DrawFenrirTooltip(drawList, fcx, fcy, fcw, fch, futureMoonDay, futureMoonPct);
        else
            -- Current column only, centered within contentW
            local cardOffX = math.floor((contentW - cardW) / 2);
            local ccx, ccy, ccw, cch = DrawDayColumn(drawList, cardX0 + cardOffX + CARD_PAD, colY, weekday,
                moonPct, moonDay, 1.0,
                iconSize, fontSize, colorCfg, showMoon, showBadge, plainDayIcons);
            DrawFenrirTooltip(drawList, ccx, ccy, ccw, cch, moonDay, moonPct);
        end

        -- LT below day columns when past/future is hidden
        if ltBelowColumns and ltStr ~= '' then
            local ltY = colY + colH + 2;
            local ltX = cx0 + math.floor((contentW - ltMeasW) / 2);
            DrawTextWithOutline(drawList, ltStr, ltX, ltY, colorCfg.textColor or 0xFFFFFFFF, outlineArgb, fontSize);
            if cfg.vanaTimeEnableTooltips ~= false and cfg.vanaTimeTipLT ~= false then
                if imgui.IsMouseHoveringRect({ltX, ltY}, {ltX + ltMeasW, ltY + clockH}) then
                    imgui.SetTooltip('Local Time');
                end
            end
        end
    end  -- pcall body end
    end); -- pcall
    imgui.End();
    imgui.PopStyleVar(2);
    if not ok then
        error(err, 2);  -- re-raise so XIUI can log it, but ImGui stack is already clean
    end

    -- Render deferred Fenrir tooltip on the foreground draw list (always above all windows)
    FlushFenrirTooltip();

    -- ── Time of Day popup ────────────────────────────────────────────────────
    -- ── Weather popup ────────────────────────────────────────────────────────
    -- Drawn BEFORE the timers popup so timers (last drawn) always renders on top.
    local todEnabled     = cfg.vanaTimeTodPopup == true;

    -- Test-placement preview: cancel if non-elemental hiding was turned off or 30s elapsed.
    local weatherTestId    = nil;
    local weatherTestAlpha = 1.0;
    if cfg.vanaTimeShowWeather ~= false and cfg.vanaTimeWeatherHideNonElemental then
        if os.clock() < (_G.XIUI_weatherTestExpiry or 0) then
            weatherTestId    = 4;  -- Wind (first elemental in HorizonXI ordering)
            weatherTestAlpha = 0.35 + 0.65 * math.abs(math.sin(os.clock() * 3));
        end
    else
        _G.XIUI_weatherTestExpiry = 0;  -- cancel if user turned off hideNonElemental
    end

    local weatherEnabled = (cfg.vanaTimeShowWeather ~= false
        and weatherId >= 0
        and not (cfg.vanaTimeWeatherHideNonElemental and weatherId < 4))
        or (weatherTestId ~= nil);
    local todSide        = cfg.vanaTimeTodSide     or 'left';
    local weatherSide    = cfg.vanaTimeWeatherSide or 'right';
    local sameSide       = todEnabled and weatherEnabled and (todSide == weatherSide);

    -- When sharing a side: left/right → stack vertically (TOD first, weather below)
    --   left/right side  → stack vertically (TOD first, weather below)
    --   above/below side → stack only when both share the same H-align (to avoid overlap).
    --                      Different H-aligns → each popup uses its own setting independently.
    local weatherOffX, weatherOffY = 0, 0;
    local todAlignForce, weatherAlignForce = nil, nil;
    if sameSide then
        if todSide == 'left' or todSide == 'right' then
            weatherOffY = cachedTodH + WEATHER_POPUP_GAP;
        else
            local todAlign     = cfg.vanaTimeTodAlign     or 'left';
            local weatherAlign = cfg.vanaTimeWeatherAlign or 'left';
            if todAlign == weatherAlign then
                -- Same alignment: stack to avoid overlap.
                -- TOD keeps its alignment; weather is offset to the opposite side of it.
                todAlignForce = todAlign;
                if todAlign == 'right' then
                    weatherAlignForce = 'right';
                    weatherOffX = -(cachedTodW + WEATHER_POPUP_GAP);
                else
                    weatherAlignForce = 'left';
                    weatherOffX = cachedTodW + WEATHER_POPUP_GAP;
                end
            end
            -- Different alignments: each popup goes to its own edge, no offset needed.
        end
    end

    -- Resolve per-tab icon sizes (custom scale or fall back to main iconSize).
    local todIconSize;
    if cfg.vanaTimeTodCustomScale then
        todIconSize = math.floor(math.max(16, math.min(64, cfg.vanaTimeTodIconSize or 28)) * scale);
    else
        todIconSize = iconSize;
    end

    -- Weather base size (custom or shared with main icon size)
    local weatherBaseSize;
    if cfg.vanaTimeWeatherCustomScale then
        weatherBaseSize = math.floor(math.max(16, math.min(64, cfg.vanaTimeWeatherIconSize or 28)) * scale);
    else
        weatherBaseSize = iconSize;
    end
    -- Elemental weather adjustment: boost size for IDs 4-19 (or always while preview drag is active)
    local weatherIconSize = weatherBaseSize;
    if cfg.vanaTimeWeatherAdjustElemental then
        local isElemental    = weatherEnabled and weatherId >= 4;
        local previewActive  = _G.XIUI_weatherElementalPreview == true;
        local previewBase    = _G.XIUI_weatherBasePreview == true;
        -- previewBase: dragging the non-elemental slider — suppress the elemental boost
        -- so the user sees exactly what non-elemental weather will look like.
        if not previewBase and (isElemental or previewActive) then
            if cfg.vanaTimeWeatherCustomScale then
                weatherIconSize = math.floor(math.max(16, math.min(64, cfg.vanaTimeWeatherElementalIconSize or 42)) * scale);
            else
                -- Auto: 50% larger than base, hard-capped at scaled 64
                weatherIconSize = math.min(math.floor(weatherBaseSize * 1.5), math.floor(64 * scale));
            end
        end
    end

    if todEnabled then
        M.DrawTodPopup(vtHour, vtMinuteOfDay, todIconSize, colorCfg, rounding, todAlignForce);
    end
    if weatherEnabled then
        M.DrawWeatherPopup(weatherTestId or weatherId, fontSize, weatherIconSize, colorCfg, rounding, weatherOffX, weatherOffY, weatherAlignForce, weatherTestAlpha);
    end

    -- ── Timers popup ─────────────────────────────────────────────────────────
    -- Drawn last so it renders above TOD/Weather tabs.
    if showTimers and timersOpen then
        local timersFontSize = math.floor(math.max(8, math.min(24, cfg.vanaTimeTimersFontSize or 12)) * scale);
        M.DrawTimersPopup(timersFontSize, colorCfg, rounding);
    end
end

-- ── Timers popup helpers ──────────────────────────────────────────────────────

-- DrawTimerSection: wraps a CollapsingHeader with XIUI gold label text.
-- State is session-only (timerSectionOpen) — never written to disk.
local function DrawTimerSection(label, key, drawFn)
    local saved = timerSectionOpen[key] == true;
    if firstTimerFrame then
        imgui.SetNextItemOpen(saved, ImGuiCond_Always);
    end
    imgui.PushStyleColor(ImGuiCol_Text, {0.957, 0.855, 0.592, 1.0});
    local isOpen = imgui.CollapsingHeader(label);
    imgui.PopStyleColor(1);
    timerSectionOpen[key] = isOpen;
    if isOpen then drawFn() end
end

-- Helper: thin not-full-width separator between rows inside a timer section.
local function DrawSectionDivider()
    imgui.PushStyleColor(ImGuiCol_Separator, {0.28, 0.28, 0.28, 0.55});
    imgui.Separator();
    imgui.PopStyleColor(1);
end

-- Helper: one transport route row — Label | Countdown | VT departure time (element colour)
local function DrawRouteRow(row)
    if row.city1 then
        imgui.TextColored(row.city1Color, row.city1);
        if row.city2 and row.city2 ~= '' then
            imgui.SameLine(0, 4);
            imgui.TextColored(timers.colorGoldDark, row.arrow or '>');
            imgui.SameLine(0, 4);
            imgui.TextColored(row.city2Color, row.city2);
        end
        if row.city3 then
            imgui.SameLine(0, 4);
            imgui.TextColored(timers.colorGoldDark, '>');
            imgui.SameLine(0, 4);
            imgui.TextColored(row.city3Color, row.city3);
        end
        if row.routeVia then
            imgui.SameLine(0, 6);
            imgui.TextColored(timers.colorDimGrey, row.routeVia);
        end
    else
        imgui.TextColored(timers.colorGoldDark, row.label or '');
    end
    imgui.SameLine(0, 10);
    if row.isOOS then
        imgui.TextColored({0.85, 0.22, 0.22, 1.0}, 'Out of Service');
        imgui.SameLine(0, 10);
    elseif row.isServicedSoon then
        imgui.TextColored(timers.colorServicedSoon, 'Serviced Soon');
        imgui.SameLine(0, 10);
    elseif row.isBoarding then
        imgui.TextColored(timers.colorBoarding, 'BOARDING');
        imgui.SameLine(0, 10);
    elseif row.isTransit then
        imgui.TextColored(timers.colorGoldDark, 'IN-TRANSIT');
        imgui.SameLine(0, 10);
    end
    local cdColor = (row.isEmpty or not row.cdColor) and timers.colorDimGrey or row.cdColor;
    imgui.TextColored(cdColor, row.countdownStr or '--');
end

local function DrawAirshipsContent()
    local a = timers.airships;
    for i, entry in ipairs(a) do
        DrawRouteRow(entry);
        if i < #a then DrawSectionDivider() end
    end
end

local function DrawBoatsContent()
    local b = timers.boats;
    local groupOpen = false;
    for i, entry in ipairs(b) do
        if entry.isHeader then
            -- Seed collapsed state on popup open; remember state within session.
            if firstTimerFrame then
                imgui.SetNextItemOpen(timerBoatGroupOpen[entry.label] == true, ImGuiCond_Always);
            end
            imgui.PushStyleColor(ImGuiCol_Text, timers.colorGoldDark);
            local open = imgui.CollapsingHeader(entry.label .. '##boatGroup');
            imgui.PopStyleColor(1);
            timerBoatGroupOpen[entry.label] = open;
            groupOpen = open;
        elseif groupOpen then
            DrawRouteRow(entry);
            if i < #b and not b[i + 1].isHeader then
                DrawSectionDivider();
            end
        end
    end
end

local RSE_LOCATION_COLOR = {
    ['Shakrami Maze'] = {0.22, 0.80, 0.42, 1.0},  -- Windurst green
    ['Ordelle Caves'] = {0.90, 0.25, 0.30, 1.0},  -- Sandoria red
    ['Gusgen Mines']  = {0.33, 0.53, 0.93, 1.0},  -- Bastok blue
};

local function DrawRSELocation(loc)
    local col = RSE_LOCATION_COLOR[loc] or timers.colorDimGrey;
    imgui.TextColored(timers.colorDimGrey, '@');
    imgui.SameLine(0, 4);
    imgui.TextColored(col, loc or '');
end

local function DrawRSEContent()
    local rse = timers.rse;
    for i, e in ipairs(rse) do
        if e.isCurrent then
            -- Active slot: Name (rich gold) | @ Location (coloured) | countdown left (yellow)
            imgui.TextColored(timers.colorGoldDark,  e.slotName);
            imgui.SameLine(0, 5);
            DrawRSELocation(e.location);
            imgui.SameLine(0, 10);
            imgui.TextColored(timers.colorSoon,    e.countdownStr .. ' left');
        else
            -- Future slot: Name (muted gold) | @ Location (coloured) | date (dim) | countdown (waiting)
            imgui.TextColored(timers.colorGoldMuted, e.slotName);
            imgui.SameLine(0, 5);
            DrawRSELocation(e.location);
            imgui.SameLine(0, 10);
            imgui.TextColored(timers.colorDimGrey, e.dateStr);
            imgui.SameLine(0, 10);
            imgui.TextColored(timers.colorWaiting, e.countdownStr);
        end
        if i < #rse then DrawSectionDivider() end
    end
end

local function DrawLunarContent()
    local lun  = timers.lunar;
    local dl   = imgui.GetWindowDrawList();
    local isz  = math.floor(imgui.GetTextLineHeight());

    local function DrawPhaseIcon(phaseIdx)
        local iconIdx = PHASE_ICON_MAP[phaseIdx] or phaseIdx;
        local tex = GetTexPtr(moonPhaseTextures[iconIdx]);
        local cx, cy = imgui.GetCursorScreenPos();
        if tex then
            dl:AddImage(tex, {cx, cy}, {cx + isz, cy + isz}, {0,0}, {1,1}, 0xFFFFFFFF);
        end
        imgui.Dummy({isz, isz});
    end

    for i, e in ipairs(lun) do
        local isNew  = (e.phaseIdx == 0);
        local isFull = (e.phaseIdx == 6);
        -- Capture row top-left before any items are drawn (for border rect)
        local rowX, rowY = imgui.GetCursorScreenPos();

        if e.isCurrent then
            -- Current phase: icon | Name (rich gold) | ends [date] (dim) | countdown (yellow)
            DrawPhaseIcon(e.phaseIdx);
            imgui.SameLine(0, 4);
            imgui.TextColored(timers.colorGoldDark,  e.phaseName);
            imgui.SameLine(0, 10);
            imgui.TextColored(timers.colorDimGrey, 'ends');
            imgui.SameLine(0, 4);
            imgui.TextColored(timers.colorGrey,    e.dateStr);
            imgui.SameLine(0, 10);
            imgui.TextColored(timers.colorSoon,    e.countdownStr);
        else
            -- Future phase: icon | Name (muted gold) | start date (dim) | countdown (waiting)
            DrawPhaseIcon(e.phaseIdx);
            imgui.SameLine(0, 4);
            imgui.TextColored(timers.colorGoldMuted, e.phaseName);
            imgui.SameLine(0, 10);
            imgui.TextColored(timers.colorDimGrey, e.dateStr);
            imgui.SameLine(0, 10);
            imgui.TextColored(timers.colorWaiting, e.countdownStr);
        end

        -- Blood-red border for New Moon; moonlit-blue border for Full Moon (hardcoded, not config)
        if isNew or isFull then
            local mx, my = imgui.GetItemRectMax();
            local borderArgb = isNew and 0xFFCC2222 or 0xFF4499FF;
            dl:AddRect({rowX - 3, rowY - 1}, {mx + 3, my + 1},
                ToU32(WithAlpha(borderArgb, 0.80)), 3, nil, 1.0);
        end

        if i < #lun then DrawSectionDivider() end
    end
end

function M.DrawTimersPopup(fontSize, colorCfg, rounding)
    local cfg  = gConfig;
    if not cfg then return; end

    local side = cfg.vanaTimeTimerSide or 'above';
    local popX = mainWinPos.x;
    local popY;
    if side == 'above' then
        popY = mainWinPos.y - cachedTimersH - 4;
    else
        popY = mainWinPos.y + mainWinSize.h + 4;
    end

    -- XIUI standard dark color scheme (same palette as config panels / status tooltips)
    imgui.PushStyleColor(ImGuiCol_WindowBg,       {0.06, 0.06, 0.07, 0.93});
    imgui.PushStyleColor(ImGuiCol_Border,          {0.38, 0.38, 0.38, 0.90});
    imgui.PushStyleColor(ImGuiCol_Header,          {0.14, 0.12, 0.08, 1.0});
    imgui.PushStyleColor(ImGuiCol_HeaderHovered,   {0.22, 0.19, 0.11, 1.0});
    imgui.PushStyleColor(ImGuiCol_HeaderActive,    {0.28, 0.24, 0.12, 1.0});
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, rounding);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, {8, 6});
    imgui.SetNextWindowPos({popX, popY}, ImGuiCond_Always);
    imgui.SetNextWindowSizeConstraints({200, 0}, {500, 9999});

    -- Capture the GLOBAL (unscaled) font size before Begin; inside the window
    -- GetFontSize() would return the already-scaled value from the prior frame,
    -- which creates a feedback loop and makes the window oscillate.
    local globalFontSize = imgui.GetFontSize();
    if not globalFontSize or globalFontSize <= 1 then globalFontSize = 13; end

    -- Keep Timers on top even if a TOD/Weather window was just created this frame.
    imgui.SetNextWindowFocus();
    local timersHovered = false;
    if imgui.Begin('VanaTimeTimers', true, WIN_FLAGS_TIMERS) then
        -- Scale all ImGui text to match the VanaTime font-size setting.
        -- Uses the global font size captured before Begin to avoid feedback loop.
        -- Clamp scale so a weird globalFontSize reading can't produce extreme or zero values.
        local fontScale = math.max(0.5, math.min(3.0, fontSize / globalFontSize));
        imgui.SetWindowFontScale(fontScale);

        local _, ph = imgui.GetWindowSize();
        cachedTimersH = ph;

        DrawTimerSection('Airships##vtTimers', 'airships', DrawAirshipsContent);
        DrawTimerSection('Boats##vtTimers',    'boats',    DrawBoatsContent);
        DrawTimerSection('RSE##vtTimers',      'rse',      DrawRSEContent);
        DrawTimerSection('Lunar Phases##vtTimers', 'lunar', DrawLunarContent);

        firstTimerFrame = false;

        -- Capture hover state while window context is valid.
        -- Flag 32 = AllowWhenBlockedByActiveItem: stays true while clicking items inside.
        timersHovered = imgui.IsWindowHovered(32);
        if timersHovered then
            timersLastActivity = os.clock();
        end
        -- Reset font scale before End() so the window state is neutral for the next frame.
        imgui.SetWindowFontScale(1.0);
    end
    imgui.End();

    -- ── Auto-close logic ────────────────────────────────────────────────────
    local cfg = gConfig;

    -- Option 1: close when clicking outside the timers window.
    -- Grace period of 0.15s after open so the opening click doesn't immediately close it.
    if cfg.vanaTimeTimersAutoCloseClick then
        if (imgui.IsMouseClicked(0) or imgui.IsMouseClicked(1))
            and not timersHovered
            and (os.clock() - timersOpenedAt) > 0.15 then
            timersOpen = false;
        end
    end

    -- Option 2: close after idle timeout (inactivity = mouse not hovering the window).
    if cfg.vanaTimeTimersAutoCloseIdle then
        local idleSec = cfg.vanaTimeTimersAutoCloseIdleSec or 5;
        if os.clock() - timersLastActivity > idleSec then
            timersOpen = false;
        end
    end

    imgui.PopStyleVar(2);
    imgui.PopStyleColor(5);
end

function M.DrawTodPopup(vtHour, vtMinuteOfDay, iconSize, colorCfg, rounding, alignOverride)
    local cfg  = gConfig;
    local side = cfg.vanaTimeTodSide or 'left';
    local wx, wy = mainWinPos.x, mainWinPos.y;
    local ww, wh = mainWinSize.w, mainWinSize.h;

    local todTexRaw =
        (vtHour >= 20 or vtHour < 4)     and todDeadNightTex
        or (vtHour >= 6 and vtHour < 18) and todDayTex
        or todNightTex;
    local todTex = GetTexPtr(todTexRaw);
    if not todTex then return; end

    local align = alignOverride or cfg.vanaTimeTodAlign or 'left';

    -- ── Timer countdown to next TOD transition ───────────────────────────────
    local showTimer  = cfg.vanaTimeTodShowTimer == true;
    local timerStr   = nil;
    if showTimer then
        -- Period boundaries in VT minutes:
        --   Dead of Night : [1200,1440) ∪ [0,240)  → transitions to Night at 04:00 (240)
        --   Night (early) : [240, 360)              → transitions to Day   at 06:00 (360)
        --   Day           : [360,1080)              → transitions to Night at 18:00 (1080)
        --   Night (late)  : [1080,1200)             → transitions to Dead  at 20:00 (1200)
        local m = vtMinuteOfDay;
        local target;
        if m >= 1200 or m < 240 then
            target = 240;
        elseif m < 360 then
            target = 360;
        elseif m < 1080 then
            target = 1080;
        else
            target = 1200;
        end
        -- Use fractional VT-minute position so the counter ticks every real
        -- second rather than jumping once per 2.4 s VT-minute boundary.
        local vtMinFrac = (GetRawTime() % VD_DAY_SEC) / VD_MIN_F;
        local diffFrac  = target - vtMinFrac;
        if diffFrac <= 0 then diffFrac = diffFrac + 1440 end;
        local secs = math.max(0, diffFrac * VD_MIN_F);
        timerStr = timers.FmtCountdown(secs);
    end

    -- Seed dimensions on first frame so right/above alignment doesn't overshoot.
    -- 12 = WindowPadding * 2 (6 each side).
    if cachedTodW == 0 then cachedTodW = iconSize + 12; end
    if cachedTodH == 0 then cachedTodH = iconSize + 12; end

    local popX, popY;
    if side == 'right' then
        popX = wx + ww + WEATHER_POPUP_GAP;
        popY = wy;
    elseif side == 'left' then
        popX = wx - WEATHER_POPUP_GAP - iconSize - 8;
        popY = wy;
    elseif side == 'below' then
        popY = wy + wh + WEATHER_POPUP_GAP;
        popX = (align == 'right') and (wx + ww - cachedTodW) or wx;
    else -- 'above'
        popY = wy - cachedTodH - WEATHER_POPUP_GAP;
        popX = (align == 'right') and (wx + ww - cachedTodW) or wx;
    end

    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, rounding);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, {6, 6});
    imgui.SetNextWindowPos({popX, popY}, ImGuiCond_Always);

    if imgui.Begin('VanaTimeTod', true, WIN_FLAGS_WEATHER) then
        local pw, ph = imgui.GetWindowSize();
        cachedTodH = ph;
        cachedTodW = pw;

        local cx, cy   = imgui.GetCursorScreenPos();
        local drawList = imgui.GetWindowDrawList();

        -- Full window coverage for bg/border (1-frame-behind pw/ph is fine).
        local popBgPad  = 6;
        local bgX = cx - popBgPad; local bgY = cy - popBgPad;   -- = windowX, windowY
        local bgW = pw;            local bgH = ph;               -- full window rect
        local contentW  = pw - 12;   -- inside padding (pw = content + 2*6)
        local contentH  = ph - 12;
        local bgOpacity  = cfg.vanaTimeBackgroundOpacity or 0.85;
        local bgRgb      = colorCfg.bgColor or 0xFF000000;
        local bgTheme    = 'Plain';
        local borderTheme = 'Window1';

        if bgTheme:match('^Window%d+$') then
            windowbg.Draw(drawList, cx, cy, contentW, contentH, {
                theme=bgTheme, bgScale=cfg.vanaTimeBgScale or 1.0,
                bgOpacity=bgOpacity, borderScale=0, borderOpacity=0,
                bgColor=bgRgb, borderColor=0x00000000, padding=popBgPad });
        elseif bgTheme ~= '-None-' then
            local opaqueU32 = ToU32(WithAlpha(bgRgb, bgOpacity));
            local transpU32 = ToU32(WithAlpha(bgRgb, 0.0));
            local midX = bgX + bgW / 2;
            drawList:AddRectFilledMultiColor({bgX,bgY},{midX,bgY+bgH}, transpU32,opaqueU32,opaqueU32,transpU32);
            drawList:AddRectFilledMultiColor({midX,bgY},{bgX+bgW,bgY+bgH}, opaqueU32,transpU32,transpU32,opaqueU32);
        end

        if borderTheme:match('^Window%d+$') then
            windowbg.Draw(drawList, cx, cy, contentW, contentH, {
                theme=borderTheme, bgScale=0, bgOpacity=0,
                borderScale=cfg.vanaTimeBorderScale or 1.0,
                borderOpacity=cfg.vanaTimeBorderOpacity or 1.0,
                bgColor=0x00000000, borderColor=colorCfg.borderColor or 0xFFFFFFFF,
                padding=popBgPad });
        elseif borderTheme == 'Plain' then
            local borderArgb = WithAlpha(colorCfg.borderColor or 0xFFFFFFFF, cfg.vanaTimeBorderOpacity or 1.0);
            drawList:AddRect({bgX,bgY},{bgX+bgW,bgY+bgH}, ToU32(borderArgb), rounding, nil, 1.0);
        end

        -- Icon: centered horizontally within whatever width the window has settled on.
        local iconOffX = math.max(0, math.floor((contentW - iconSize) / 2));
        drawList:AddImage(todTex, {cx + iconOffX, cy}, {cx + iconOffX + iconSize, cy + iconSize}, {0,0}, {1,1}, ToU32(0xEEFFFFFF));
        imgui.Dummy({iconSize, iconSize});

        -- Timer text: inside the box, centered, font scaled proportionally to icon.
        if timerStr then
            local fontScale = iconSize / 28.0;
            imgui.SetWindowFontScale(fontScale);
            local tw, _ = imgui.CalcTextSize(timerStr);
            local textOffX = math.max(0, math.floor((contentW - tw) / 2));
            imgui.SetCursorPosX(imgui.GetCursorPosX() + textOffX);
            local timerArgb = colorCfg.todTimerColor or 0xFFFFFFFF;
            local timerF4   = {ArgbR(timerArgb), ArgbG(timerArgb), ArgbB(timerArgb), ArgbA(timerArgb)};
            imgui.TextColored(timerF4, timerStr);
            imgui.SetWindowFontScale(1.0);
        end

        if imgui.IsWindowHovered() then
            if cfg.vanaTimeEnableTooltips ~= false and cfg.vanaTimeTipTod ~= false then
                local todName =
                    (vtHour >= 20 or vtHour < 4)     and 'Dead of Night'
                    or (vtHour >= 6 and vtHour < 18) and 'Day'
                    or 'Night';
                imgui.SetTooltip(todName);
            end
        end
    end
    imgui.End();
    imgui.PopStyleVar(2);
end

function M.DrawWeatherPopup(weatherId, fontSize, iconSize, colorCfg, rounding, offX, offY, alignOverride, iconAlpha)
    local cfg       = gConfig;
    local elemIdx   = WEATHER_TO_ELEMENT[weatherId];
    if elemIdx == nil then return; end

    local isDouble  = (weatherId % 2 ~= 0) and weatherId >= 5;
    local weatherTex = GetTexPtr(textures[elemIdx]);
    if weatherTex == nil then return; end

    local iconGap   = 2;  -- gap between the two icons for double weather
    local doubleW   = isDouble and (iconSize + iconGap) or 0;

    -- Seed cachedWeatherW on first frame (before Begin runs) so right-align
    -- doesn't overshoot on the very first render.  12 = WindowPadding*2 (6+6).
    if cachedWeatherW == 0 then
        cachedWeatherW = iconSize + doubleW + 12;
    end

    -- Position relative to main window
    local side     = cfg.vanaTimeWeatherSide or 'right';
    local align    = alignOverride or cfg.vanaTimeWeatherAlign or 'left';
    local wx, wy   = mainWinPos.x, mainWinPos.y;
    local ww, wh   = mainWinSize.w, mainWinSize.h;

    local popX, popY;
    if side == 'right' then
        popX = wx + ww + WEATHER_POPUP_GAP;
        popY = wy;
    elseif side == 'left' then
        popX = wx - WEATHER_POPUP_GAP - (iconSize + doubleW + 8);
        popY = wy;
    elseif side == 'below' then
        popY = wy + wh + WEATHER_POPUP_GAP;
        popX = (align == 'right') and (wx + ww - cachedWeatherW) or wx;
    else -- 'above'
        popY = wy - cachedWeatherH - WEATHER_POPUP_GAP;
        popX = (align == 'right') and (wx + ww - cachedWeatherW) or wx;
    end
    popX = popX + (offX or 0);
    popY = popY + (offY or 0);

    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, rounding);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, {6, 6});
    imgui.SetNextWindowPos({popX, popY}, ImGuiCond_Always);

    if imgui.Begin('VanaTimeWeather', true, WIN_FLAGS_WEATHER) then
        local pw, ph = imgui.GetWindowSize();
        cachedWeatherH = ph;
        cachedWeatherW = pw;

        local cx, cy   = imgui.GetCursorScreenPos();
        local drawList = imgui.GetWindowDrawList();

        -- Background + border — mirrors main window logic exactly
        local popContentW  = iconSize + doubleW;
        local popBgPad     = 6;
        local bgX = cx - popBgPad;
        local bgY = cy - popBgPad;
        local bgW = popContentW + popBgPad * 2;
        local bgH = iconSize    + popBgPad * 2;
        local bgOpacity   = cfg.vanaTimeBackgroundOpacity or 0.85;
        local bgRgb       = colorCfg.bgColor  or 0xFF000000;
        local bgTheme     = 'Plain';    -- locked: Background = Plain
        local borderTheme = 'Window1';  -- locked: Border = Window1

        if bgTheme:match('^Window%d+$') then
            windowbg.Draw(drawList, cx, cy, popContentW, iconSize, {
                theme         = bgTheme,
                bgScale       = cfg.vanaTimeBgScale or 1.0,
                bgOpacity     = bgOpacity,
                borderScale   = 0,
                borderOpacity = 0,
                bgColor       = bgRgb,
                borderColor   = 0x00000000,
                padding       = popBgPad,
            });
        elseif bgTheme ~= '-None-' then
            -- Plain: horizontal gradient, transparent edges → opaque centre
            local opaqueU32 = ToU32(WithAlpha(bgRgb, bgOpacity));
            local transpU32 = ToU32(WithAlpha(bgRgb, 0.0));
            local midX = bgX + bgW / 2;
            drawList:AddRectFilledMultiColor(
                {bgX,  bgY}, {midX,    bgY + bgH},
                transpU32, opaqueU32, opaqueU32, transpU32);
            drawList:AddRectFilledMultiColor(
                {midX, bgY}, {bgX + bgW, bgY + bgH},
                opaqueU32, transpU32, transpU32, opaqueU32);
        end

        if borderTheme:match('^Window%d+$') then
            windowbg.Draw(drawList, cx, cy, popContentW, iconSize, {
                theme         = borderTheme,
                bgScale       = 0,
                bgOpacity     = 0,
                borderScale   = cfg.vanaTimeBorderScale   or 1.0,
                borderOpacity = cfg.vanaTimeBorderOpacity or 1.0,
                bgColor       = 0x00000000,
                borderColor   = colorCfg.borderColor or 0xFFFFFFFF,
                padding       = popBgPad,
            });
        elseif borderTheme == 'Plain' then
            local borderArgb = WithAlpha(colorCfg.borderColor or 0xFFFFFFFF, cfg.vanaTimeBorderOpacity or 1.0);
            drawList:AddRect({bgX, bgY}, {bgX + bgW, bgY + bgH}, ToU32(borderArgb), rounding, nil, 1.0);
        end

        -- Weather element icon(s) — two side-by-side for double weather
        local iconTint = ToU32(WithAlpha(0xFFFFFFFF, iconAlpha or 1.0));
        drawList:AddImage(
            weatherTex,
            {cx, cy}, {cx + iconSize, cy + iconSize}, {0,0}, {1,1}, iconTint);

        if isDouble then
            local x2 = cx + iconSize + iconGap;
            drawList:AddImage(
                weatherTex,
                {x2, cy}, {x2 + iconSize, cy + iconSize}, {0,0}, {1,1}, iconTint);
        end

        -- ImGui dummy to size the window
        local dummyW = iconSize + doubleW;
        imgui.Dummy({dummyW, iconSize});

        if imgui.IsWindowHovered() then
            if cfg.vanaTimeEnableTooltips ~= false and cfg.vanaTimeTipWeather ~= false then
                imgui.SetTooltip(WEATHER_NAMES[weatherId] or 'Unknown');
            end
        end
    end
    imgui.End();
    imgui.PopStyleVar(2);
end

-- ── Window flags helper (kept local to ui) ────────────────────────────────────
-- WIN_FLAGS_WEATHER already defined above; this local is referenced at module level.

return M;
