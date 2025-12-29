--[[
* XIUI hotbar - Data Module
]]--

require('common');
local jobs = require('libs.jobs');

local M = {};

-- ============================================
-- Constants
-- ============================================

-- M.MAX_POOL_SLOTS = 10;              -- Maximum hotbar slots (0-9)
-- M.POOL_TIMEOUT_SECONDS = 300;       -- 5 minutes pool timeout
-- M.MAX_HISTORY_ITEMS = 20;           -- Maximum items to keep in won history

-- ============================================
-- State
-- ============================================

-- -- Current pool state from memory (slot -> item data)
-- M.poolItems = {};

-- Keybinds cache (job -> keybind entries)
M.keybindsCache = {};
M.jobId = nil;

-- ============================================
-- Helper Functions
-- ============================================

-- Parse a keybind entry from array format to object format
function M.ParseKeybindEntry(entry)
    if type(entry) ~= 'table' or #entry < 2 then
        return nil;
    end
    
    -- Parse the first element: 'battle 1 1' -> context, hotbar, slot
    local battleStr = entry[1];
    local context, hotbar, slot = battleStr:match('(%w+)%s+(%d+)%s+(%d+)');
    
    local parsed = {
        context = context or 'battle',
        hotbar = tonumber(hotbar) or 1,
        slot = tonumber(slot) or 1,
        actionType = entry[2],           -- 'ma', 'ja', 'ws', 'macro', etc.
        action = entry[3],                -- Spell/ability/ws name
        target = entry[4],                -- 'stpc', 'stnpc', 'me', 't', etc.
        displayName = entry[5] or entry[3],  -- Display name (defaults to action if not provided)
        extraType = entry[6],             -- Optional: 'item', texture name, etc.
        raw = entry                       -- Keep original array for reference
    };
    
    return parsed;
end

-- Get current keybinds 
function M.GetKeybinds()
    local rawKeybinds = M.GetBaseKeybindsForJob(M.jobId);
    if not rawKeybinds then
        print(string.format("[XIUI hotbar] GetKeybinds returned nil for job %d", M.jobId or 0));
        return nil;
    end
    
    -- Parse raw array entries into object format
    local parsedKeybinds = {};
    for i, entry in ipairs(rawKeybinds) do
        local parsed = M.ParseKeybindEntry(entry);
        if parsed then
            table.insert(parsedKeybinds, parsed);
        else
            print(string.format("[XIUI hotbar] Failed to parse entry %d (has %d elements)", i, #entry));
        end
    end
    
    return parsedKeybinds;
end


-- Get keybinds for a specific job
function M.GetBaseKeybindsForJob(jobId)
    if not jobId then
        return nil;
    end
    
    local jobKeybinds = M.keybindsCache[jobId];
    if not jobKeybinds then
        print(string.format("[XIUI hotbar] Warning: No keybinds found for job %d", jobId));
        return nil;
    end
    
    if not jobKeybinds['Base'] then
        print(string.format("[XIUI hotbar] Warning: Job %d keybinds missing 'Base' key", jobId));
        return nil;
    end

    return jobKeybinds['Base'];
end

-- Get all cached keybinds
function M.GetAllKeybinds()
    return M.keybindsCache;
end

-- Check if keybinds are loaded
function M.HasKeybinds()
    return M.keybindsCache and next(M.keybindsCache) ~= nil;
end


-- ============================================
-- Font Storage (created by init.lua, used by display.lua)
-- ============================================

M.allFonts = nil;
M.hotbarNumberFonts = {};  -- GDI fonts for hotbar numbers (1-6)


-- Set preview mode
function M.SetPreview(enabled)
end

-- Clear all preview state (call when config closes)
function M.ClearPreview()
   
end


-- Clear error message
function M.ClearError()

end


-- ============================================
-- Lifecycle
-- ============================================

-- Initialize data module
function M.Initialize()
    -- Clear any existing cache
    M.keybindsCache = {};
    
    -- Get the addon path
    local addonPath = AshitaCore:GetInstallPath();
    
    -- Loop over all jobs and load their keybinds
    for jobId, jobName in ipairs(jobs) do
        local jobNameLower = jobName:lower();
        local keybindsPath = string.format('%saddons\\XIUI\\modules\\hotbar\\keybinds\\%s.lua', addonPath, jobNameLower);
        
        -- Load the keybinds file for this job
        local success, result = pcall(function()
            local chunk, err = loadfile(keybindsPath);
            if chunk then
                local keybinds = chunk();
                if keybinds and next(keybinds) ~= nil then
                    M.keybindsCache[jobId] = keybinds;
                    print(string.format("[XIUI hotbar] Loaded keybinds for %s (job %d)", jobName, jobId));
                else
                    print(string.format("[XIUI hotbar] Warning: %s keybinds file returned empty table", jobName));
                end
            else
                if err then
                    print(string.format("[XIUI hotbar] Could not load %s: %s", jobName, err));
                end
            end
        end);
        
        if not success and result then
            print(string.format("[XIUI hotbar] Error loading %s keybinds: %s", jobName, result));
        end
    end

    M.SetPlayerJob();    
end

function M.SetPlayerJob()
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    local currentJobId = player:GetMainJob();
    if(currentJobId == 0) then
       return;
    end
    M.jobId = currentJobId;
    print(string.format("[XIUI hotbar] Current job changed to %s (%d)", jobs[M.jobId] or "Unknown", M.jobId));
end

-- Clear all state (call on zone change)
function M.Clear()
    -- Note: We keep keybindsCache intact on zone change
    -- as keybinds don't need to be reloaded
end

-- Cleanup (call on addon unload)
function M.Cleanup()
    M.Clear();
end

return M;
