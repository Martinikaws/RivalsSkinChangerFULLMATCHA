-- Rivals changer - autoexec entry point.
--
-- This loads the GUI only: a window drawn on screen (Right Shift shows and
-- hides it, unless you changed the key in its Settings). It applies your saved
-- config by itself once Rivals has loaded (Auto-apply on join), and stays
-- there, so you can change a skin mid-game and press Save & Apply without
-- rejoining.
--
-- Do not also put the changer (RivalsSkinSwapper.lua) in this folder: it would
-- run a second time and the second run is refused by its own lock.

local CANDIDATES = {"RivalsSkinGui.lua", "workspace/RivalsSkinGui.lua", "scripts/RivalsSkinGui.lua"}
local URL = "https://raw.githubusercontent.com/Martinikaws/RivalsSkinChangerFULLMATCHA/refs/heads/main/gui.lua"

local function localCopy()
    for _, path in ipairs(CANDIDATES) do
        local ok, exists = pcall(isfile, path)
        if ok and exists then
            local okRead, body = pcall(readfile, path)
            if okRead and type(body) == "string" and #body > 0 then return body, path end
        end
    end
end

local function download()
    local ok, body = pcall(function() return game:HttpGet(URL) end)
    if ok and type(body) == "string" and #body > 0 then return body, "github" end
end

-- Autoexec runs before the game exists, and a yield out here would throw, so
-- the waiting happens in its own thread. The window needs the player and the
-- camera.
task.spawn(function()
    local deadline = tick() + 300
    while tick() < deadline do
        local ok, ready = pcall(function()
            return game:IsLoaded() and game:GetService("Players").LocalPlayer ~= nil and workspace.CurrentCamera ~= nil
        end)
        if ok and ready then break end
        task.wait(0.5)
    end

    local source, from = localCopy()
    if not source then source, from = download() end
    if not source then
        warn("[Rivals GUI] RivalsSkinGui.lua not found in the workspace and the download failed.")
        return
    end

    local fn, err = loadstring(source)
    if type(fn) ~= "function" then
        warn("[Rivals GUI] Could not compile the GUI: " .. tostring(err))
        return
    end
    local okRun, runErr = pcall(fn)
    if not okRun then
        warn("[Rivals GUI] " .. tostring(runErr))
    else
        print("[Rivals GUI] Loaded from " .. tostring(from) .. ".")
    end
end)
