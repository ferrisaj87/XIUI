--[[
* VanaTime module for XIUI.
*
* Displays Vana'diel time, day element, moon phase, and zone weather.
* Data sources:
*   - Time / day / moon : require 'ffxi.time'  (FFXiMain.dll FFI calls)
*   - Weather           : packet 0x057 (environment update); reset on 0x000A zone-in.
*                         NO raw memory reads -- avoids EXCEPTION_ACCESS_VIOLATION on
*                         HorizonXI's build of FFXiMain.dll.
]]--

require('common');
local ui = require('modules.vanatime.ui');

local M = {};

-- ── Module state ──────────────────────────────────────────────────────────────
local hidden    = false;
local weatherId = 0;  -- updated via packets only; never via ashita.memory

-- ── Module lifecycle ──────────────────────────────────────────────────────────

function M.Initialize(settings)
    ui.Initialize();
end

function M.DrawWindow(settings)
    if hidden then return; end
    ui.DrawWindow(weatherId);
end

function M.UpdateVisuals(settings)
    ui.Reset();
end

function M.SetHidden(h)
    hidden = h;
end

function M.Cleanup()
    weatherId = 0;
    ui.Cleanup();
end

-- ── Packet hooks ──────────────────────────────────────────────────────────────
-- Wired from XIUI.lua packet_in handler.

function M.HandlePacketIn(e)
    -- Zone change: clear weather display until server sends a new update.
    if e.id == 0x000A then
        weatherId = 0;
        return;
    end

    -- Environment / weather update packet.
    -- The weather type byte is at offset 0x0C in the packet payload.
    -- Wrapped in pcall for safety (pure string ops but belt-and-suspenders).
    if e.id == 0x057 then
        local ok, val = pcall(struct.unpack, 'B', e.data, 0x0C + 1);
        if ok and type(val) == 'number' then
            weatherId = val;
        end
    end
end

return M;
