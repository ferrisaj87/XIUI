--[[
* XIUI Config Menu - Vana Time Settings
]]--

require('common');
local imgui      = require('imgui');
local components = require('config.components');

local M = {};

local BG_THEMES  = {'-None-', 'Plain', 'Window1', 'Window2', 'Window3',
                    'Window4', 'Window5', 'Window6', 'Window7', 'Window8'};
local SIDE_LABELS  = {'Right', 'Left', 'Above', 'Below'};
local SIDE_VALUES  = {'right', 'left', 'above', 'below'};
local TT_DIR_LABELS = {'Above', 'Below'};
local TT_DIR_VALUES = {'above', 'below'};

function M.DrawSettings()
    components.DrawCheckbox('Enabled', 'showVanaTime', CheckVisibility);
    components.DrawCheckbox('Hide When Menu Open', 'vanaTimeHideOnMenuFocus');
    imgui.ShowHelp('Hide this module when a game menu is open (equipment, map, etc.).');

    imgui.Spacing();
    imgui.Separator();
    imgui.Spacing();

    imgui.TextColored(components.TAB_STYLE.gold, 'Display Options');

    components.DrawCheckbox('Show Local Time (LT)', 'vanaTimeShowLocalTime');
    imgui.ShowHelp('Show your local real-world clock on the right side of the time row.');

    components.DrawCheckbox('Show Moon Phase', 'vanaTimeShowMoonPercent');
    imgui.ShowHelp('Show moon phase percentage and waxing/waning arrow under each day icon.');

    components.DrawCheckbox('Show Past / Future Days', 'vanaTimeShowPastFuture');
    imgui.ShowHelp('Show yesterday and tomorrow columns at reduced opacity on either side of today.');

    if gConfig.vanaTimeShowPastFuture ~= false then
        imgui.Indent(16);
        components.DrawSlider('Past / Future Opacity', 'vanaTimePastFutureOpacity', 0.0, 1.0);
        imgui.ShowHelp('How visible the past and future day columns are (0 = invisible, 1 = fully opaque).');
        imgui.Unindent(16);
    end

    components.DrawCheckbox('Show Weather Popup', 'vanaTimeShowWeather');
    imgui.ShowHelp('Show a floating popup when elemental weather is active in your current zone.');

    if gConfig.vanaTimeShowWeather ~= false then
        imgui.Indent(16);
        components.Combo('Weather Popup Side##vt', gConfig, 'vanaTimeWeatherSide',
            SIDE_LABELS, SIDE_VALUES, 'right');
        imgui.ShowHelp('Which side of the VanaTime window the weather popup floats on.');
        imgui.Unindent(16);
    end

    components.DrawCheckbox('Enable Hover Tooltips', 'vanaTimeShowTooltip');
    imgui.ShowHelp('Show a tooltip above/below the VanaTime window when hovering over a day column.');

    if gConfig.vanaTimeShowTooltip ~= false then
        imgui.Indent(16);
        components.DrawCheckbox('Fenrir Details##vt',  'vanaTimeTooltipFenrir');
        imgui.ShowHelp('Show Lunar Cry, Ecliptic Howl, and Ecliptic Growl values for the hovered moon phase.');
        components.DrawCheckbox("Selene's Bow##vt",    'vanaTimeTooltipSeleneBow');
        imgui.ShowHelp("Show Selene's Bow Ranged Accuracy / Ranged Attack values for the hovered moon phase.");
        components.Combo('Tooltip Direction##vt', gConfig, 'vanaTimeTooltipDirection',
            TT_DIR_LABELS, TT_DIR_VALUES, 'above');
        imgui.ShowHelp('Whether the tooltip appears above or below the VanaTime window.');
        imgui.Unindent(16);
    end

    imgui.Spacing();
    imgui.Separator();
    imgui.Spacing();

    imgui.TextColored(components.TAB_STYLE.gold, 'Scaling & Layout');

    components.DrawSlider('Scale##vt', 'vanaTimeScale', 0.5, 2.0, '%.2f');
    imgui.ShowHelp('Global scale for the entire VanaTime window.');

    components.DrawSlider('Font Size##vt', 'vanaTimeFontSize', 8, 24, '%d');
    imgui.ShowHelp('Font size for clock and moon phase text (scaled by Scale above).');

    components.DrawSlider('Icon Size##vt', 'vanaTimeIconSize', 16, 64, '%d');
    imgui.ShowHelp('Size of the element day icons in pixels (scaled by Scale above).');

    imgui.Spacing();
    imgui.Separator();
    imgui.Spacing();

    if components.CollapsingSection('Background##vt', true) then
        components.Combo('Background Style##vtbg', gConfig, 'vanaTimeBackgroundTheme',
            BG_THEMES, nil, 'Plain');
        imgui.ShowHelp('Fill style for the window background.\nPlain = gradient using the BG tint below.\nWindow1-8 = FFXI nine-slice texture.\nNone = fully transparent.');

        components.DrawSlider('Background Scale##vt', 'vanaTimeBgScale', 0.1, 3.0, '%.2f');
        imgui.ShowHelp('Scale of the background texture (Window themes only).');

        components.DrawSlider('Background Opacity##vt', 'vanaTimeBackgroundOpacity', 0.0, 1.0, '%.2f');
        imgui.ShowHelp('Center opacity of the gradient (Plain) or texture opacity (Window themes).');

        imgui.Spacing();
        imgui.Separator();
        imgui.Spacing();

        components.Combo('Border Style##vtborder', gConfig, 'vanaTimeBorderTheme',
            BG_THEMES, nil, 'Plain');
        imgui.ShowHelp('Border decoration style.\nPlain = simple rounded outline.\nWindow1-8 = FFXI nine-slice border pieces.\nNone = no border.');

        components.DrawSlider('Border Scale##vt', 'vanaTimeBorderScale', 0.1, 3.0, '%.2f');
        imgui.ShowHelp('Scale of window border pieces (Window themes only).');

        components.DrawSlider('Border Opacity##vt', 'vanaTimeBorderOpacity', 0.0, 1.0, '%.2f');
        imgui.ShowHelp('Opacity of window borders.');
    end
end

function M.DrawColorSettings()
    local colorCfg = gConfig.colorCustomization and gConfig.colorCustomization.vanaTime;
    if not colorCfg then
        imgui.TextDisabled('Color config not available.');
        return;
    end

    if components.CollapsingSection('Background Colors##vt', true) then
        components.DrawTextColorPicker('Background Tint##vt', colorCfg, 'bgColor',
            'Tint color for the window background. Use black at low opacity for a dark transparent look.');
        components.DrawTextColorPicker('Border Color##vt', colorCfg, 'borderColor',
            'Color of window borders (Window themes only).');
    end

    if components.CollapsingSection('Text Colors##vt', true) then
        components.DrawTextColorPicker('General Text / LT Clock##vt', colorCfg, 'textColor',
            'Color for local time clock and other non-element text.');
    end

    if components.CollapsingSection('Element Colors##vt', false) then
        imgui.TextDisabled('These color the VT clock text and day column pill backgrounds.');
        imgui.TextDisabled('Light group (Fire/Wind/Lightning/Light): black outline + white pill.');
        imgui.TextDisabled('Dark group (Ice/Water/Earth/Dark): white outline + dark pill.');
        imgui.Spacing();
        components.DrawTextColorPicker('Fire (Firesday)##vt',           colorCfg, 'elementFire');
        components.DrawTextColorPicker('Earth (Earthsday)##vt',         colorCfg, 'elementEarth');
        components.DrawTextColorPicker('Water (Watersday)##vt',         colorCfg, 'elementWater');
        components.DrawTextColorPicker('Wind (Windsday)##vt',           colorCfg, 'elementWind');
        components.DrawTextColorPicker('Ice (Iceday)##vt',              colorCfg, 'elementIce');
        components.DrawTextColorPicker('Lightning (Lightningday)##vt',  colorCfg, 'elementLightning');
        components.DrawTextColorPicker('Light (Lightsday)##vt',         colorCfg, 'elementLight');
        components.DrawTextColorPicker('Dark (Darksday)##vt',           colorCfg, 'elementDark');
    end

    if components.CollapsingSection('Moon Glow##vt', false) then
        imgui.TextDisabled('Tint shown behind the moon% text on Full / New Moon.');
        imgui.Spacing();
        components.DrawTextColorPicker('Full Moon Glow##vt',  colorCfg, 'moonFullColor',
            'Golden glow shown behind moon percent on a Full Moon.');
        components.DrawTextColorPicker('New Moon Glow##vt',   colorCfg, 'moonNewColor',
            'Dark red glow shown behind moon percent on a New Moon.');
    end
end

return M;
