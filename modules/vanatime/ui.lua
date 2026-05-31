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
local TextureManager = require('libs.texturemanager');
local windowbg  = require('libs.windowbackground');

local M = {};

-- ── Constants ─────────────────────────────────────────────────────────────────

local WEATHER_POPUP_GAP  = 4;   -- px gap between main window and popup
local PAST_FUTURE_ALPHA  = 0.18;
local BADGE_SCALE        = 0.40; -- weakness badge as fraction of main icon size
local ARROW_SCALE        = 0.55; -- down-arrow as fraction of badge icon size
local MOON_ARROW_UP      = '(+)'; -- waxing
local MOON_ARROW_DOWN    = '(-)'; -- waning
local MOON_ARROW_FLAT    = '';    -- new/full moon: no direction shown
local COL_ARROW          = '>';   -- column separator

-- ── Pure-Lua Vana'diel time (no FFI / ashita.memory) ─────────────────────────
-- Vana'diel time runs at 25× real-world speed.
-- 1 VD day  = 3456 real seconds  (57.6 minutes)
-- 1 VD hour = 144  real seconds
-- 1 VD min  = 2.4  real seconds
-- Moon cycle = 84 VD days; day 0 = new moon, day 42 = full moon.
local VANA_EPOCH    = 1009810800; -- Unix ts of Vana'diel year-0 epoch (Jan 1 2002 12:00 UTC)
local VD_DAY_SEC    = 3456;
local VD_HOUR_SEC   = 144;
local VD_MIN_F      = 2.4;
local VD_MOON_DAYS  = 84;

-- os.time() truncates to the last whole second, so on average the display
-- lags ~0.5 real seconds behind true time.  At 25x VT speed that's ~12 VT
-- seconds of lag.  Subtract a small constant so the clock reads "now" rather
-- than "just before now".  0.25 s is empirically comfortable; adjust if needed.
local VT_TIME_BIAS  = 0.25;

local function GetRawTime()
    return (os.time() + VT_TIME_BIAS) - VANA_EPOCH;
end

local function CalcMoonPercent(moonDay)
    if moonDay <= 42 then
        return math.floor(moonDay / 42 * 100);
    else
        return math.floor((VD_MOON_DAYS - moonDay) / 42 * 100);
    end
end

-- Weekday index -> element name (matches assets/hotbar/elements/*.png)
local ELEMENT_NAMES = {
    [0] = 'Fire',
    [1] = 'Earth',
    [2] = 'Water',
    [3] = 'Wind',
    [4] = 'Ice',
    [5] = 'Lightning',
    [6] = 'Light',
    [7] = 'Dark',
};

-- Day name strings
local DAY_NAMES = {
    [0] = 'Firesday',
    [1] = 'Earthsday',
    [2] = 'Watersday',
    [3] = 'Windsday',
    [4] = 'Iceday',
    [5] = 'Lightningday',
    [6] = 'Lightsday',
    [7] = 'Darksday',
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

-- moonDay: 0=new moon, 42=full moon, 1-41=waxing, 43-83=waning
local function GetMoonArrow(moonDay)
    if moonDay == 0 or moonDay == 42 then return MOON_ARROW_FLAT; end
    if moonDay < 42 then return MOON_ARROW_UP; end
    return MOON_ARROW_DOWN;
end

-- Weather IDs 4-19 are elemental; odd = double
-- Map to weekday element index (0-7)
local WEATHER_TO_ELEMENT = {
    [4]=0,  [5]=0,   -- Fire / Fire x2
    [6]=2,  [7]=2,   -- Water / Water x2
    [8]=1,  [9]=1,   -- Earth / Earth x2
    [10]=3, [11]=3,  -- Wind / Wind x2
    [12]=4, [13]=4,  -- Ice / Ice x2
    [14]=5, [15]=5,  -- Lightning / Lightning x2
    [16]=6, [17]=6,  -- Light / Light x2
    [18]=7, [19]=7,  -- Dark / Dark x2
};

-- ── Texture cache ─────────────────────────────────────────────────────────────

local textures = {};
local arrowDownTex  = nil;
local arrowRightTex = nil;
local moonUpTex     = nil;
local moonDownTex   = nil;
local moonPhaseTextures = {};  -- [0..11] → phase icon

-- Map moonDay (0-83) to phase icon index 0-11
-- Waxing: 0-42, Waning: 43-83
local function GetMoonPhaseIndex(moonDay)
    if moonDay == 0  then return 0 end   -- New Moon
    if moonDay == 42 then return 6 end   -- Full Moon
    if moonDay < 42 then
        -- Waxing: phases 1-5 spread across moonDay 1-41
        return math.min(5, math.floor((moonDay - 1) / 7) + 1);
    else
        -- Waning: phases 7-11 spread across moonDay 43-83
        return math.min(11, math.floor((moonDay - 43) / 7) + 7);
    end
end

local function LoadTextures()
    for i = 0, 7 do
        local name = ELEMENT_NAMES[i];
        if name and not textures[i] then
            textures[i] = TextureManager.getFileTexture('hotbar/elements/' .. name);
        end
    end
    for i = 0, 11 do
        if not moonPhaseTextures[i] then
            moonPhaseTextures[i] = TextureManager.getFileTexture('hotbar/vanatime/moon/phase_' .. i);
        end
    end
    if not arrowDownTex then
        arrowDownTex = TextureManager.getFileTexture('hotbar/vanatime/arrow_down');
    end
    if not arrowRightTex then
        arrowRightTex = TextureManager.getFileTexture('hotbar/vanatime/arrow_right');
    end
    if not moonUpTex then
        moonUpTex = TextureManager.getFileTexture('hotbar/vanatime/moon_up');
    end
    if not moonDownTex then
        moonDownTex = TextureManager.getFileTexture('hotbar/vanatime/moon_down');
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
local function GetPillColor(weekday, alpha)
    if LIGHT_GROUP[weekday] then
        return WithAlpha(0xFFFFFFFF, alpha or 0.22);
    end
    return WithAlpha(0xFF000000, alpha or 0.40);
end

-- Draw text with a custom outline color (bypasses imtext's hardcoded black)
local function DrawTextWithOutline(drawList, text, x, y, textArgb, outlineArgb, fontSize)
    local font     = imtext.GetFont();
    local ow       = 1;
    local textU32  = ToU32(textArgb);
    local outU32   = ToU32(outlineArgb);
    -- apply SIZE_OFFSET to match imtext scaling
    local fs = fontSize and (fontSize + 2) or nil;
    local function addText(dx, dy, col)
        local p = {x + dx, y + dy};
        if fs and font then
            drawList:AddText(font, fs, p, col, text);
        else
            drawList:AddText(p, col, text);
        end
    end
    -- Single shadow offset — clean drop-shadow instead of heavy cardinal outline
    addText( 1,  1, outU32);
    -- main text
    addText(0, 0, textU32);
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
-- Deferred Fenrir tooltip: set during Begin/End hover check, drawn after End() on the foreground list
local pendingFenrirTooltip = nil;  -- {moonDay, moonPercent}

-- ── Draw helpers ──────────────────────────────────────────────────────────────

-- Draw a single day column: icon + moon% + weakness badge
-- colWeekday: 0-7 weekday for this column
-- moonPercent: moon % for this day (may differ past/future)
-- moonDay: day within the 84-day moon cycle (0=new, 42=full)
-- showMoon: whether to draw the moon% text row
local function DrawDayColumn(drawList, cx, cy, colWeekday, moonPercent, moonDay, alpha, iconSize, fontSize, colorConfig, showMoon)
    local badgeSize = math.floor(iconSize * BADGE_SCALE);
    local arrowW    = math.floor(badgeSize * ARROW_SCALE);

    local elemKeys = {
        [0]='elementFire', [1]='elementEarth', [2]='elementWater', [3]='elementWind',
        [4]='elementIce',  [5]='elementLightning', [6]='elementLight', [7]='elementDark',
    };
    local elemArgb = colorConfig[elemKeys[colWeekday]] or 0xFFFFFFFF;

    -- Effective content width: icon, or moon row (phase icon + "100%" + arrow)
    local moonArrowSlot = showMoon and (math.floor(fontSize * 0.7) + 2) or 0;
    local phaseIconSlot = showMoon and (math.floor(fontSize + 2) + 2) or 0;
    local moonMaxW      = showMoon and (phaseIconSlot + imtext.Measure('100%', fontSize) + moonArrowSlot) or 0;
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
    local LIGHT_GROUP = { [0]=true, [3]=true, [5]=true, [6]=true };  -- Fire, Wind, Lightning, Light
    local iconX = cx + math.floor((colContentW - iconSize) / 2);

    -- Flat black background behind the icon only
    drawList:AddRectFilled(
        {iconX, iconY}, {iconX + iconSize, iconY + iconSize},
        ToU32(WithAlpha(0xFF000000, alpha)), 3);

    -- Main element icon — centered within colContentW
    local iconTex = GetTexPtr(textures[colWeekday]);
    if iconTex then
        local tint  = ToU32(WithAlpha(0xFFFFFFFF, alpha));
        drawList:AddImage(iconTex,
            {iconX, iconY}, {iconX + iconSize, iconY + iconSize}, {0,0}, {1,1}, tint);
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
        local phaseTex = GetTexPtr(moonPhaseTextures[GetMoonPhaseIndex(moonDay)]);

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

        -- Moon glow (full/new moon) — spans the whole group horizontally
        local totalMoonRowW = phaseGap + moonW + (moonArrowTex and (moonArrowSize + arrowGap) or 0);
        if moonDay == 42 and alpha >= 0.95 then
            local glowArgb = WithAlpha(colorConfig.moonFullColor or 0xFFFFD700, 0.35);
            DrawPill(drawList, moonTextX - phaseGap - 3, moonBaseY - 1, totalMoonRowW + 6, fontSize + 2, glowArgb, 3);
        elseif moonDay == 0 and alpha >= 0.95 then
            local glowArgb = WithAlpha(colorConfig.moonNewColor or 0xFF8B0000, 0.45);
            DrawPill(drawList, moonTextX - phaseGap - 3, moonBaseY - 1, totalMoonRowW + 6, fontSize + 2, glowArgb, 3);
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

    -- Weakness corner badge: small weakness element icon in bottom-right corner of main icon,
    -- with a red border. Overlaid directly on the element icon — no separate row.
    local weakWeekday = ELEMENT_DEFEATS[colWeekday];
    local badgeTex    = weakWeekday ~= nil and GetTexPtr(textures[weakWeekday]) or nil;
    if badgeTex then
        local cornerX = iconX + iconSize - badgeSize;
        local cornerY = iconY + iconSize - badgeSize;
        -- Solid dark-red background so badge reads clearly over the element icon
        drawList:AddRectFilled(
            {cornerX - 1, cornerY - 1}, {cornerX + badgeSize + 1, cornerY + badgeSize + 1},
            ToU32(WithAlpha(0xFF3B0000, alpha)), 2);
        -- Weakness element icon
        drawList:AddImage(badgeTex,
            {cornerX, cornerY}, {cornerX + badgeSize, cornerY + badgeSize},
            {0,0}, {1,1}, ToU32(WithAlpha(0xFFFFFFFF, alpha)));
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
    if not (gConfig and gConfig.vanaTimeShowTooltip ~= false) then return; end
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

    local phaseIdx  = GetMoonPhaseIndex(moonDay);
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
    local dimGoldCol  = imgui.GetColorU32({0.85, 0.72, 0.38, 0.80});  -- dimmed section title
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
    arrowDownTex  = nil;
    arrowRightTex = nil;
    moonUpTex     = nil;
    moonDownTex   = nil;
end

function M.DrawWindow(weatherId)
    local cfg       = gConfig;
    if not cfg then return; end
    -- Clear deferred tooltip from any previous frame
    pendingFenrirTooltip = nil;
    local colorCfg  = (cfg.colorCustomization or {}).vanaTime or {};
    local scale     = cfg.vanaTimeScale or 1.0;
    local fontSize  = math.floor((cfg.vanaTimeFontSize or 12) * scale);
    local iconSize  = math.floor((cfg.vanaTimeIconSize or 28) * scale);
    local rounding  = 12.0;

    -- ── Get game data (pure Lua — no FFI) ───────────────────────────────────
    local rawTime       = GetRawTime();
    local weekday       = math.floor(rawTime / VD_DAY_SEC) % 8;
    local vtHour        = math.floor(rawTime % VD_DAY_SEC / VD_HOUR_SEC);
    local vtMin         = math.floor(rawTime % VD_HOUR_SEC / VD_MIN_F);
    local moonDay       = math.floor(rawTime / VD_DAY_SEC) % VD_MOON_DAYS;
    local moonPct       = CalcMoonPercent(moonDay);

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
    local elemArgb    = colorCfg[ELEM_KEYS[weekday]] or 0xFFFFFFFF;
    local outlineArgb = GetOutlineColor(weekday);

    -- ── Column layout geometry ───────────────────────────────────────────────
    local winPad    = 8;                          -- window padding (kept for PushStyleVar)
    local CARD_PAD  = 4;                          -- card extends this many px outside colContentW on each side
    local SEP_GAP   = 4;                          -- gap between card edge and separator arrow
    local arrowW    = fontSize + 2;               -- text fallback size
    local sepArrowW = math.floor(iconSize * 0.5); -- separator arrow width

    local showPastFuture = cfg.vanaTimeShowPastFuture ~= false;
    local showMoon       = cfg.vanaTimeShowMoonPercent ~= false;
    local pastFutureAlpha = cfg.vanaTimePastFutureOpacity or PAST_FUTURE_ALPHA;

    -- Base column content width: phase icon + "100%" + direction arrow
    local moonArrowSlot = showMoon and (math.floor(fontSize * 0.7) + 2) or 0;
    local phaseIconSlot = showMoon and (math.floor(fontSize + 2) + 2) or 0;
    local moonMaxW      = showMoon and (phaseIconSlot + imtext.Measure('100%', fontSize) + moonArrowSlot) or 0;
    local colContentW   = math.max(iconSize, moonMaxW + 4);

    -- Card width (as drawn by DrawDayColumn: content + CARD_PAD on each side)
    local cardW = colContentW + CARD_PAD * 2;

    -- Total card area width (layout anchored on card edges, not column padding)
    local cardAreaW;
    if showPastFuture then
        cardAreaW = cardW * 3 + SEP_GAP * 4 + sepArrowW * 2;
    else
        cardAreaW = cardW;
    end

    -- colW only used for DrawDayColumn x-offset computation below
    local colPad = winPad;  -- keep variable alive for PushStyleVar below

    -- Clock row height
    local clockH = fontSize + 4;
    -- Column height: badge is now a corner overlay on the icon, not a separate row
    local colH   = showMoon
        and (iconSize + 2 + fontSize + 4)
        or  (iconSize + 4);

    -- contentW is purely the card area — clock text floats above independently
    local contentW = cardAreaW;

    -- Pre-measure clock strings — only re-measure when text or font size changes
    if fontSize ~= lastFontSize then
        lastFontSize    = fontSize;
        vtCache.measW   = 0;  -- force re-measure
        ltCache.measW   = 0;
    end
    if vtCache.measW == 0 then
        vtCache.measW = imtext.Measure(vtCache.str, fontSize);
    end
    local vtMeasW = vtCache.measW;
    local ltMeasW = 0;
    if ltStr ~= '' then
        if ltCache.measW == 0 then
            ltCache.measW = imtext.Measure(ltCache.str, fontSize);
        end
        ltMeasW = ltCache.measW;
    end

    local totalH = clockH + colH + colPad;

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

        local cx0, cy0 = imgui.GetCursorScreenPos();
        local drawList = GetUIDrawList();

        -- ── Window background ────────────────────────────────────────────────
        local bgPad  = colPad;
        local bgX    = cx0 - bgPad;
        local bgY    = cy0 - bgPad;
        local bgW    = contentW + bgPad * 2;
        local bgH    = totalH  + bgPad * 2;
        local bgOpacity = cfg.vanaTimeBackgroundOpacity or 0.85;
        local bgRgb  = colorCfg.bgColor or 0xFF000000;

        local bgTheme     = cfg.vanaTimeBackgroundTheme or 'Plain';
        local borderTheme = cfg.vanaTimeBorderTheme     or 'Plain';

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

        if ltStr ~= '' then
            -- Two-column layout: VT centered in left half, LT centered in right half
            local halfW = contentW / 2;
            local vtX   = cx0 + math.floor((halfW - vtMeasW) / 2);
            local ltX   = cx0 + halfW + math.floor((halfW - ltMeasW) / 2);
            DrawTextWithOutline(drawList, vtStr, vtX, clockY, elemArgb,  outlineArgb, fontSize);
            DrawTextWithOutline(drawList, ltStr, ltX, clockY, colorCfg.textColor or 0xFFFFFFFF, outlineArgb, fontSize);
        else
            -- VT fully centered
            local vtX = cx0 + math.floor((contentW - vtMeasW) / 2);
            DrawTextWithOutline(drawList, vtStr, vtX, clockY, elemArgb, outlineArgb, fontSize);
        end

        -- ── Day columns ──────────────────────────────────────────────────────
        local colY   = cy0 + clockH + colPad;
        local cardX0 = cx0;  -- cards start at the content origin (no offset needed)

        if showPastFuture then
            -- Column cx values: DrawDayColumn draws card at (cx - CARD_PAD),
            -- so cx = card_left + CARD_PAD.  First card starts at cx0.
            local pastX = cardX0 + CARD_PAD;

            local pcx, pcy, pcw, pch = DrawDayColumn(drawList, pastX, colY, pastWeekday,
                pastMoonPct, pastMoonDay, pastFutureAlpha,
                iconSize, fontSize, colorCfg, showMoon);
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
                iconSize, fontSize, colorCfg, showMoon);
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
                iconSize, fontSize, colorCfg, showMoon);
            DrawFenrirTooltip(drawList, fcx, fcy, fcw, fch, futureMoonDay, futureMoonPct);
        else
            -- Current column only, centered
            local ccx, ccy, ccw, cch = DrawDayColumn(drawList, cardX0, colY, weekday,
                moonPct, moonDay, 1.0,
                iconSize, fontSize, colorCfg, showMoon);
            DrawFenrirTooltip(drawList, ccx, ccy, ccw, cch, moonDay, moonPct);
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

    -- ── Weather popup ────────────────────────────────────────────────────────
    if cfg.vanaTimeShowWeather ~= false and weatherId >= 4 then
        M.DrawWeatherPopup(weatherId, fontSize, iconSize, colorCfg, rounding);
    end
end

function M.DrawWeatherPopup(weatherId, fontSize, iconSize, colorCfg, rounding)
    local cfg       = gConfig;
    local elemIdx   = WEATHER_TO_ELEMENT[weatherId];
    if elemIdx == nil then return; end

    local isDouble  = (weatherId % 2 ~= 0) and weatherId >= 5;
    local weatherTex = GetTexPtr(textures[elemIdx]);
    if weatherTex == nil then return; end

    -- Position relative to main window
    local side     = cfg.vanaTimeWeatherSide or 'right';
    local wx, wy   = mainWinPos.x, mainWinPos.y;
    local ww, wh   = mainWinSize.w, mainWinSize.h;

    local popX, popY;
    if side == 'right' then
        popX = wx + ww + WEATHER_POPUP_GAP;
        popY = wy;
    elseif side == 'left' then
        popX = wx - WEATHER_POPUP_GAP - (iconSize + (isDouble and fontSize + 6 or 0) + 8);
        popY = wy;
    elseif side == 'below' then
        popX = wx;
        popY = wy + wh + WEATHER_POPUP_GAP;
    else -- 'above'
        popX = wx;
        popY = wy - cachedWeatherH - WEATHER_POPUP_GAP;
    end

    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, rounding);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, {6, 6});
    imgui.SetNextWindowPos({popX, popY}, ImGuiCond_Always);

    if imgui.Begin('VanaTimeWeather', true, WIN_FLAGS_WEATHER) then
        local pw, ph = imgui.GetWindowSize();
        cachedWeatherH = ph;

        local cx, cy   = imgui.GetCursorScreenPos();
        local drawList = GetUIDrawList();

        -- Background
        local popContentW = iconSize + (isDouble and fontSize + 4 or 0);
        local popBgPad    = 6;
        local popBgArgb   = WithAlpha(colorCfg.bgColor or 0xFF000000, (cfg.vanaTimeBackgroundOpacity or 0.85) * 0.9);
        drawList:AddRectFilled(
            {cx - popBgPad, cy - popBgPad},
            {cx + popContentW + popBgPad, cy + iconSize + popBgPad},
            ToU32(popBgArgb), rounding);
        local bgTheme = cfg.vanaTimeBackgroundTheme or 'Plain';
        if bgTheme:match('^Window%d+$') then
            windowbg.Draw(drawList, cx, cy, popContentW, iconSize, {
                theme = bgTheme, bgOpacity = 0,
                borderScale = cfg.vanaTimeBorderScale or 1.0,
                borderOpacity = cfg.vanaTimeBorderOpacity or 1.0,
                borderColor = colorCfg.borderColor or 0xFFFFFFFF,
                padding = popBgPad,
            });
        else
            local borderArgb = WithAlpha(colorCfg.borderColor or 0xFFFFFFFF, cfg.vanaTimeBorderOpacity or 1.0);
            drawList:AddRect(
                {cx - popBgPad, cy - popBgPad},
                {cx + popContentW + popBgPad, cy + iconSize + popBgPad},
                ToU32(borderArgb), rounding, nil, 1.0);
        end

        -- Weather element icon
        drawList:AddImage(
            weatherTex,
            {cx, cy}, {cx + iconSize, cy + iconSize});

        -- "x2" label for double weather
        if isDouble then
            local x2Str = 'x2';
            local x2X   = cx + iconSize + 3;
            local x2Y   = cy + (iconSize - fontSize) / 2;
            local elemArgb = colorCfg['element' .. ELEMENT_NAMES[elemIdx]] or 0xFFFFFFFF;
            local outArgb  = GetOutlineColor(elemIdx);
            DrawTextWithOutline(drawList, x2Str, x2X, x2Y, elemArgb, outArgb, fontSize);
        end

        -- ImGui dummy to size the window
        local dummyW = iconSize + (isDouble and fontSize + 6 or 0);
        imgui.Dummy({dummyW, iconSize});
    end
    imgui.End();
    imgui.PopStyleVar(2);
end

-- ── Window flags helper (kept local to ui) ────────────────────────────────────
-- WIN_FLAGS_WEATHER already defined above; this local is referenced at module level.

return M;
