-- Rivals changer GUI (Matcha UI tab)
-- Edits rivals_config.lua and runs the skin changer. Based on the community
-- GUI; adds wraps, finishers, charms (with season ranks), skybox and lighting,
-- and reads the item lists from the running game instead of a bundled copy.

local FILE = "rivals_config.lua"
local SETTINGS = "rivals_gui_settings.txt"
local BACKUP = "rivals_config.backup.lua"
local SCRIPT_FILES = {"RivalsSkinSwapper.lua", "workspace/RivalsSkinSwapper.lua", "scripts/RivalsSkinSwapper.lua"}
local SCRIPT_URL = "https://raw.githubusercontent.com/Martinikaws/RivalsSkinChangerFULLMATCHA/refs/heads/main/main.lua"
local SITE = "https://martinikaws.github.io/rivals-skins/"
local TAB = "Rivals Changer"
local RIVALS_GAME_ID = 6035872082

assert(UI and type(UI.AddTab) == "function", "Matcha UI binding is required.")
assert(type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function",
    "Matcha file functions are required.")

_G.RivalsGuiState = _G.RivalsGuiState or {busy = false}
local shared = _G.RivalsGuiState
assert(not shared.busy, "Wait for the current operation to finish, then rerun this GUI.")

-- Matcha's dropdowns can't scroll, so the skies are split into short groups:
-- pick a group, then the sky in it.
local function numbered(prefix, from, to)
    local out = {}
    for n = from, to do out[#out + 1] = string.format("%s %02d", prefix, n) end
    return out
end
local SKY_GROUPS = {
    {name = "Off", skies = {}},
    {name = "Game skies", skies = {"blue", "space", "graveyard", "sudden death", "station", "westown", "black", "gray", "classic"}},
    {name = "Cloudy 1-12", skies = {"cloudy 01", "cloudy 02", "cloudy 03", "cloudy 04", "cloudy 05", "cloudy 06", "cloudy 07", "cloudy 08", "cloudy 09", "cloudy 10", "cloudy 11", "cloudy 12"}},
    {name = "Cloudy 13-25", skies = {"cloudy 13", "cloudy 14", "cloudy 15", "cloudy 16", "cloudy 17", "cloudy 18", "cloudy 19", "cloudy 20", "cloudy 21", "cloudy 22", "cloudy 23", "cloudy 24", "cloudy 25"}},
    {name = "Space", skies = {"galaxy", "blue nebula", "gold nebula"}},
    {name = "More A-D", skies = {"aurora", "beautiful", "black hole", "blue sky", "broken sky", "castle grounds", "chill gray", "chill pink", "chroma key", "clear skies", "cyan", "dead star forest", "disaster"}},
    {name = "More E-M", skies = {"elegant morning", "emo", "fade blue", "forest", "goodnight", "grimnight", "hades", "hazy", "jungle", "light blue", "light pink", "minecraft", "minecraft end"}},
    {name = "More M-P", skies = {"moonlight", "neon sky", "neon sky 2", "nibiru", "night", "night sky moon", "northern lights", "oblivion", "orange", "overcast", "pandora", "peaceful morning", "pink sunrise"}},
    {name = "More P-S", skies = {"pumpkin hill", "purple nebula", "red", "setting sun", "sfoth", "shiverfrost", "sky 05", "sky 13", "sky 2006", "sky 22", "sky 31", "sky 38", "sky 47"}},
    {name = "More S-Z", skies = {"sky purple", "sky sunset", "space blue", "spooky", "sunny sky", "universe", "utter east", "whomp fortress", "winterness", "xen", "zen end"}},
}
-- Sound library. Rivals and Roblox sounds always play; community uploads
-- are public but their owners can remove them.
local SOUND_LIBRARY = {
    {name = "Rivals", sounds = {
        {"Hitmarker tick", "13110130082"},
        {"Headshot crack", "16537449730"},
        {"Elimination 1", "16530229616"},
        {"Elimination 2", "16530229541"},
        {"Elimination 3", "16530229695"},
        {"Target shatter", "14441658101"},
        {"RPG explosion", "13455969017"},
        {"Equip click", "13158735106"},
        {"Landing", "16736552001"},
        {"Jump", "16736552098"},
        {"Duel timer tick", "17826390328"},
        {"Click", "177266782"},
    }},
    {name = "Roblox", sounds = {
        {"Classic hit", "12222046"},
        {"Button", "12221967"},
        {"Electronic ping", "12221990"},
        {"Glass break", "12222005"},
        {"Kerplunk", "12222054"},
        {"Fast click", "12221976"},
        {"Bright click", "15675059323"},
        {"Cute pop", "15675055424"},
        {"Notification", "17208361335"},
        {"Coin", "127645268874265"},
        {"Pinball bell", "16480570986"},
        {"8-bit blip", "16480580213"},
        {"Metal click", "16480551554"},
        {"Sparkle ding", "9126073001"},
        {"Cannon blast", "3149249837"},
    }},
    {name = "Hit sounds", sounds = {
        {"Undertale critical hit", "140181868959125"},
        {"Hit sound", "139520673393967"},
        {"Undertale attack hit", "140721035016341"},
        {"Fist hit", "140604838213617"},
        {"TF2 critical hit", "137392628136734"},
        {"AvA punch", "138208560796742"},
        {"Rock hit", "82708037443413"},
        {"Spear hit", "135278368445325"},
        {"Persona 5 hit", "140706017778464"},
        {"Energy sword hit", "139503070303020"},
        {"Stone hit", "3581383408"},
        {"8-bit impact", "109598434966968"},
        {"Minecraft hit", "73369656122118"},
        {"Car hit", "1897654568"},
        {"Beam hit", "103134129110384"},
    }},
    {name = "Your pack", sounds = {
        {"agpa 1", "102651850556408"},
        {"agpa 2", "132463144859699"},
        {"Huhh", "115574480250251"},
        {"Minecraft hurt", "127059326655954"},
        {"msfrs.hit", "138523457528846"},
        {"neverlose.cc", "139452805868562"},
        {"Rust headshot 2", "138750331387064"},
        {"skeet (louder)", "140247876667835"},
        {"Taco Bell bong", "128327858093323"},
        {"Bubble pop", "121434237134952"},
        {"Windows XP error", "95509039020568"},
        {"My name is Jeff", "2867856238"},
        {"HL2 crowbar", "73268721537561"},
        {"DSR-1", "93739917036633"},
        {"Fatality", "97439296876895"},
        {"Bepis", "1921494658"},
        {"Burp", "130147881880627"},
        {"Duck quack", "140601322851309"},
        {"Computer beep", "2626561747"},
        {"MGS alert", "139345986070502"},
        {"Doom shotgun", "15120932483"},
        {"Cash register", "120891770644830"},
        {"Cowbell", "9125935023"},
        {"Winner FX", "1841267764"},
        {"Cartoon bubble", "5852470908"},
    }},
    {name = "Community", sounds = {
        {"CoD hitmarker", "138832207290954"},
        {"Quake hitmarker", "1455817260"},
        {"GameSense hitmarker", "4817809188"},
        {"Minecraft hitmarker", "127091812835195"},
        {"Minecraft bow ding", "135478009117226"},
        {"MLG hitmarker", "121351852050830"},
        {"Head hitmarker", "17724154662"},
        {"TF2 hitsound", "138901307926331"},
        {"osu! hitsound", "123941247147792"},
        {"Bubble pop", "119697580657161"},
        {"CS:GO headshot", "133002449941130"},
        {"Arsenal headshot", "18513634637"},
        {"Fortnite headshot", "2513174484"},
        {"Rust headshot", "128633263668964"},
        {"Battlefield headshot", "70528023820006"},
        {"PHIGHTING headshot", "138549196892842"},
        {"TF2 kill", "124543461907751"},
        {"Among Us kill", "130456049552264"},
        {"MM2 knife kill", "97347330766907"},
        {"Double kill", "116907610084760"},
    }},
    {name = "Kenney (CC0)", sounds = {
        {"Punch heavy", "107508753428253"},
        {"Punch", "76122581259100"},
        {"Metal tap", "138075431083492"},
        {"Metal clang", "133464625805308"},
        {"Glass tap", "138936753289661"},
        {"Glass smash", "75898126734535"},
        {"Bell hit", "126126591991039"},
        {"Plate tap", "117110797440641"},
        {"Tin hit", "135391446483517"},
        {"Soft thud", "95039951320381"},
        {"Click", "127906824435990"},
        {"Tick", "130702709867354"},
        {"Confirm", "112196335049721"},
        {"Glass ding", "127490438798725"},
        {"Pluck", "72021613097471"},
        {"Bong", "117732813936667"},
        {"Drop", "128207733490113"},
        {"Glitch", "131159017045649"},
        {"Zap", "136683295906047"},
        {"Zap two-tone", "132620272525127"},
        {"Pep", "70583920911483"},
        {"High up", "117530563976701"},
        {"Phaser up", "104765335548518"},
        {"Power up", "105788477038167"},
        {"Three-tone", "70578968807464"},
        {"Small laser", "91301983822305"},
        {"Retro laser", "118116613865507"},
        {"Explosion crunch", "82931503751689"},
    }},
}
local SKY_GROUP_NAMES = {}
for _, g in ipairs(SKY_GROUPS) do SKY_GROUP_NAMES[#SKY_GROUP_NAMES + 1] = g.name end
local RANKS = {"Archnemesis", "Nemesis", "Onyx 3", "Onyx 2", "Onyx 1", "Diamond 3", "Diamond 2", "Diamond 1",
    "Platinum 3", "Platinum 2", "Platinum 1", "Gold 3", "Gold 2", "Gold 1", "Silver 3", "Silver 2", "Silver 1",
    "Bronze 3", "Bronze 2", "Bronze 1", "Unranked"}

local state = {
    status = "Ready", lines = {}, values = {}, revision = 0, owned = {}, rank = {},
    search = {}, searchText = {}, readable = false, catalogStatus = "",
}
local session = tostring(tick())
local guiToken = {}
_G.__RivalsGuiSession = guiToken
local catalog = {weapons = {}, wraps = {}, finishers = {}, charms = {}}

-- Config file

local function trim(s) return s:match("^%s*(.-)%s*$") end
local function header(line)
    local s = line:match("^%s*%[%s*(.-)%s*%]%s*$")
    return s and s:lower() or nil
end
local function pair(line)
    if line:match("^%s*%-%-") then return nil end
    local k, v = line:match("^%s*([^=]-)%s*=%s*(.-)%s*$")
    if k and trim(k) ~= "" then return trim(k), v end
end
local function swapLine(line)
    local w, owned, target = line:match("^%s*([^|]-)%s*|%s*([^>]-)%s*>%s*(.-)%s*$")
    if w and owned and target and w ~= "" and owned ~= "" and target ~= "" then return w, owned, target end
end
local function indexConfig()
    state.values = {skins = {}, wraps = {}, finishers = {}, charms = {}, skybox = {}, lighting = {}}
    state.swaps = {}
    local section = "skins"
    for _, line in ipairs(state.lines) do
        local h = header(line)
        if h then
            section = h
        elseif section == "skins" and not line:match("^%s*%-%-") and swapLine(line) then
            local w, owned, target = swapLine(line)
            state.swaps[w] = state.swaps[w] or {}
            state.swaps[w][owned] = target
        else
            local k, v = pair(line)
            if k then
                state.values[section] = state.values[section] or {}
                state.values[section][k] = v
            end
        end
    end
end
local function loadConfig()
    local raw = isfile(FILE) and readfile(FILE) or nil
    local content = (raw or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    if content:sub(1, 3) == string.char(239, 187, 191) then content = content:sub(4) end
    local lines = {}
    for line in (content .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    while lines[#lines] == "" do table.remove(lines) end
    local cleaned, dropped = {}, 0
    for _, line in ipairs(lines) do
        local k, v = pair(line)
        if k and v and k == v then dropped = dropped + 1 else cleaned[#cleaned + 1] = line end
    end
    state.lines, state.baseline = cleaned, raw
    state.droppedSelf = dropped
    indexConfig()
    state.readable = true
    state.revision = state.revision + 1
    state.status = raw and "Loaded your configuration." or "Nothing saved yet - pick something."
    if (state.droppedSelf or 0) > 0 then
        state.status = string.format("Loaded (%d line%s set to itself removed - press Save & Apply).",
            state.droppedSelf, state.droppedSelf == 1 and "" or "s")
    end
end
-- One key per section. A nil value removes the line; unknown sections get a
-- new [Header] at the end. Lines this GUI doesn't understand (skin swaps,
-- comments) are copied through untouched.
local function setMapping(section, key, value)
    if shared.busy or not state.readable then return end
    local output, current, found = {}, "skins", false
    for _, line in ipairs(state.lines) do
        local h = header(line)
        if h then current = h end
        local k = not h and pair(line) or nil
        if current == section and k == key then
            if not found and value then output[#output + 1] = key .. "=" .. value end
            found = true
        else
            output[#output + 1] = line
        end
    end
    if not found and value then
        local position = section == "skins" and 1 or nil
        current = "skins"
        for i, line in ipairs(output) do
            local h = header(line)
            if h then current = h end
            if current == section then position = i + 1 end
        end
        if not position then
            output[#output + 1] = ""
            output[#output + 1] = "[" .. section:sub(1, 1):upper() .. section:sub(2) .. "]"
            position = #output + 1
        end
        table.insert(output, position, key .. "=" .. value)
    end
    state.lines = output
    indexConfig()
    state.status = "Ready to apply."
end
-- "Weapon | Owned > Target" lives in the skins section, after the Weapon=Skin
-- lines. A nil target removes it.
local function setSwap(weapon, owned, target)
    if shared.busy or not state.readable then return end
    local output, section, lastSkinLine = {}, "skins", 0
    for _, line in ipairs(state.lines) do
        local h = header(line)
        if h then section = h end
        local keep = true
        if section == "skins" and not h then
            local w, o = swapLine(line)
            if w == weapon and o == owned then keep = false end
        end
        if keep then
            output[#output + 1] = line
            if section == "skins" and not h then lastSkinLine = #output end
        end
    end
    if target then
        table.insert(output, lastSkinLine + 1, weapon .. " | " .. owned .. " > " .. target)
    end
    state.lines = output
    indexConfig()
    state.status = "Ready to apply."
end

local function configText()
    if #state.lines == 0 then return "-- Rivals config\n" end
    return table.concat(state.lines, "\n") .. "\n"
end
local function saveConfig()
    assert(state.readable, "Reload the configuration before saving.")
    local current = isfile(FILE) and readfile(FILE) or nil
    assert(current == state.baseline,
        "The config changed outside this GUI. Rerun the GUI to load it; your file was not overwritten.")
    local content = configText()
    if current == content then return end
    if current then
        writefile(BACKUP, current)
        assert(readfile(BACKUP) == current, "Could not verify the backup; save cancelled.")
    end
    writefile(FILE, content)
    assert(readfile(FILE) == content, "Could not verify the save. Your previous config is in " .. BACKUP)
    state.baseline = content
end


-- Auto-apply on join
--
-- From autoexec this script only builds the menu, so the changer would sit
-- there until Apply is pressed. With auto-apply on, it applies the saved
-- config by itself once the game is ready, once per server. The setting lives
-- in the workspace next to the config; the autoexec folder is only used to
-- guess the default, and Matcha may refuse to read outside its workspace.
local AUTOEXEC_DIRS = {"../autoexec", "C:/matcha/autoexec", "autoexec"}
local GUI_MARKERS = {"RivalsSkinGui", "RivalsSkinChangerFULLMATCHA", "gui.lua"}

local function autoexecLoadsGui()
    for _, dir in ipairs(AUTOEXEC_DIRS) do
        local okList, files = pcall(listfiles, dir)
        if okList and type(files) == "table" then
            for _, path in ipairs(files) do
                local okRead, body = pcall(readfile, path)
                if okRead and type(body) == "string" then
                    for _, marker in ipairs(GUI_MARKERS) do
                        if body:find(marker, 1, true) then return true, path end
                    end
                end
            end
        end
    end
    return false
end

local function loadSettings()
    local auto
    local okRead, body = pcall(readfile, SETTINGS)
    if okRead and type(body) == "string" then
        state.settingsRead = true
        local value = body:match("autoapply%s*=%s*(%w+)")
        if value then auto = (value == "1" or value == "true" or value == "on") end
    end
    if auto == nil then
        -- First run: default to on when autoexec starts this GUI.
        local okScan, found, where = pcall(autoexecLoadsGui)
        auto = okScan and found or false
        state.autoexecPath = okScan and where or nil
        state.autoexecScan = okScan and (found and "found in autoexec" or "not in autoexec")
            or "autoexec folder not readable"
    end
    state.autoApply = auto
end

local function saveSettings()
    pcall(writefile, SETTINGS, "autoapply=" .. (state.autoApply and "1" or "0") .. "\n")
end

-- Item lists, read from the running game
--
-- Every cosmetic is an entry in CosmeticLibrary.Cosmetics with a Type ("Skin",
-- "Wrap", ...) and, for skins, the weapon it belongs to in ItemName. The
-- library is a Lua table, reached through the registry: a ModuleScript keeps
-- the VM's main thread at +0x168 and its registry slot at +0x188; the thread's
-- global state (+0x48) holds the registry at +0x618. Finishers and charms are
-- plain folders of instances.
local mrd = memory_read
local function rd(a) local ok, v = pcall(mrd, "uintptr_t", a) return ok and v or nil end
local function i32(a) local ok, v = pcall(mrd, "int", a) return ok and v or nil end
local function tag(a) local ok, v = pcall(mrd, "byte", a) return ok and v or nil end
local function str(p)
    if not p or p < 0x10000 then return nil end
    local ok, v = pcall(mrd, "string", p + 24)
    if ok and type(v) == "string" and #v > 0 and #v < 80 then return v end
end
local function nodeKey(node) return str(rd(node + 16)) end
local function moduleTable(ms)
    if not ms or not ms.Address then return nil end
    local thread = rd(ms.Address + 0x168)
    if not thread or thread < 0x10000 or tag(thread) ~= 10 then return nil end
    local global = rd(thread + 0x48)
    local registry = global and global > 0x10000 and rd(global + 0x618)
    if not registry or registry < 0x10000 or tag(registry) ~= 7 then return nil end
    local slot, size, array = i32(ms.Address + 0x188), i32(registry + 8), rd(registry + 0x28)
    if not slot or not size or not array or slot < 1 or slot > size then return nil end
    local t = rd(array + (slot - 1) * 16)
    if not t or t < 0x10000 or tag(t) ~= 7 then return nil end
    return t
end
local function fieldOf(t, name, maxNodes)
    local base = t and rd(t + 0x20)
    if not base or base < 0x10000 then return nil end
    for i = 0, (maxNodes or 64) - 1 do
        local node = base + i * 32
        if nodeKey(node) == name and i32(node + 12) ~= 0 then return rd(node) end
    end
end

local function gameCatalog()
    local out = {weapons = {}, wraps = {}, finishers = {}, charms = {}}
    local rs = game:GetService("ReplicatedStorage")
    local modules = rs:FindFirstChild("Modules")
    local LP = game:GetService("Players").LocalPlayer
    local ps = LP and LP:FindFirstChild("PlayerScripts")
    local assets = ps and ps:FindFirstChild("Assets")
    local finishers = modules and modules:FindFirstChild("Finishers")
    for _, m in ipairs(finishers and finishers:GetChildren() or {}) do
        if not m.Name:find("MISSING_", 1, true) then out.finishers[#out.finishers + 1] = m.Name end
    end
    local charms = assets and assets:FindFirstChild("Charms")
    for _, m in ipairs(charms and charms:GetChildren() or {}) do
        if not m.Name:find("MISSING_", 1, true) then out.charms[#out.charms + 1] = m.Name end
    end

    local library = modules and moduleTable(modules:FindFirstChild("CosmeticLibrary"))
    local cosmetics = library and fieldOf(library, "Cosmetics", 256)
    local base = cosmetics and rd(cosmetics + 0x20)
    local byWeapon = {}
    if base then
        for i = 0, 16383 do
            local node = base + i * 32
            local name = nodeKey(node)
            if name and i32(node + 12) == 7 and not name:find("MISSING_", 1, true) then
                local entry = rd(node)
                local kind = str(fieldOf(entry, "Type", 32))
                if kind == "Skin" then
                    local weapon = str(fieldOf(entry, "ItemName", 32))
                    if weapon then
                        byWeapon[weapon] = byWeapon[weapon] or {}
                        table.insert(byWeapon[weapon], name)
                    end
                elseif kind == "Wrap" then
                    out.wraps[#out.wraps + 1] = name
                end
            end
        end
    end
    -- Weapons the game lists models for, so a weapon with no skins still shows.
    local vm = assets and assets:FindFirstChild("ViewModels")
    local weapons = vm and vm:FindFirstChild("Weapons")
    for _, w in ipairs(weapons and weapons:GetChildren() or {}) do
        byWeapon[w.Name] = byWeapon[w.Name] or {}
    end
    for weapon, skins in pairs(byWeapon) do
        table.sort(skins)
        out.weapons[#out.weapons + 1] = {name = weapon, skins = skins}
    end
    table.sort(out.weapons, function(a, b) return a.name < b.name end)
    table.sort(out.wraps)
    table.sort(out.finishers)
    table.sort(out.charms)
    return out
end

local function fetch(url)
    local body = (type(httpget) == "function") and httpget(url) or game:HttpGet(url)
    assert(type(body) == "string" and #body > 0, "Download failed: " .. url)
    return body
end
local function jsonAssignment(source, pattern)
    local encoded = source:match(pattern)
    assert(encoded, "Website format changed; keeping the current lists.")
    return game:GetService("HttpService"):JSONDecode(encoded)
end
-- The website knows which skins belong to which weapon, and every wrap name.
local function siteCatalog(into)
    local weapons = jsonAssignment(fetch(SITE), "const%s+OFFICIAL_WEAPON_DATA%s*=%s*(%b[])%s*;")
    local wraps = jsonAssignment(fetch(SITE .. "assets/wraps.js"), "window%.WRAPS%s*=%s*(%b[])%s*;")
    into.weapons = {}
    for _, w in ipairs(weapons) do
        if type(w.name) == "string" and type(w.skins) == "table" then
            into.weapons[#into.weapons + 1] = {name = w.name, skins = w.skins, category = w.category}
        end
    end
    into.wraps = {}
    for _, row in ipairs(wraps) do
        if type(row[1]) == "string" and not row[1]:find("MISSING_", 1, true) then
            into.wraps[#into.wraps + 1] = row[1]
        end
    end
    table.sort(into.weapons, function(a, b) return a.name < b.name end)
    table.sort(into.wraps)
    return into
end

local function loadCatalog()
    local ok, fromGame = pcall(gameCatalog)
    local enough = ok and type(fromGame) == "table" and #fromGame.weapons > 0 and #fromGame.wraps > 0
    if enough then
        catalog = fromGame
        state.catalogStatus = string.format("From the game: %d weapons, %d wraps, %d finishers, %d charms",
            #catalog.weapons, #catalog.wraps, #catalog.finishers, #catalog.charms)
    else
        if ok and type(fromGame) == "table" then catalog = fromGame end
        local okSite, err = pcall(siteCatalog, catalog)
        state.catalogStatus = okSite and "From the website (game lists unavailable)"
            or ("Lists unavailable: " .. tostring(err):sub(1, 40))
    end
    state.revision = state.revision + 1
end

-- Running the changer

local function currentContext()
    local ok, result = pcall(function()
        if tonumber(game.GameId) ~= RIVALS_GAME_ID or not game:IsLoaded() then return nil end
        local jobId = game.JobId
        if type(jobId) ~= "string" or jobId == "" then return nil end
        local player = game:GetService("Players").LocalPlayer
        local scripts = player and player:FindFirstChild("PlayerScripts")
        local assets = scripts and scripts:FindFirstChild("Assets")
        local models = assets and assets:FindFirstChild("ViewModels")
        local weapons = models and models:FindFirstChild("Weapons")
        if not weapons or not weapons.Address or #weapons:GetChildren() == 0 then return nil end
        return {key = jobId .. ":" .. tostring(weapons.Address), wf = weapons.Address}
    end)
    return ok and result or nil
end
local function upstreamBusy()
    local stamp = _G.__RIVALS_SKIN_CHANGER_BUSY
    return type(stamp) == "number" and tick() - stamp < 180
end
-- The local copy first: that is the one autoexec runs.
local function changerSource()
    for _, p in ipairs(SCRIPT_FILES) do
        local ok, exists = pcall(isfile, p)
        if ok and exists then
            local okRead, body = pcall(readfile, p)
            if okRead and type(body) == "string" and #body > 0 then return body, p end
        end
    end
    return fetch(SCRIPT_URL), "github"
end
local function apply()
    local context = currentContext()
    assert(context, "Wait for Rivals and its weapon assets to finish loading.")
    assert(not upstreamBusy(), "The changer is already running.")
    saveConfig()
    state.status = "Applying..."
    local source, from = changerSource()
    local fn, err = loadstring(source)
    assert(type(fn) == "function", err or "Could not compile the changer.")
    local before = _G.__RIVALS_SKIN_CHANGER_STATE
    fn()
    -- Matcha returns from the call as soon as the script yields, so the work is
    -- still going: wait for its completion record and the run lock clearing.
    local deadline = tick() + 150
    while tick() < deadline do
        local now = currentContext()
        if not now or now.key ~= context.key then
            state.status = "Server changed while applying - run it again."
            return
        end
        local finished = _G.__RIVALS_SKIN_CHANGER_STATE
        if type(finished) == "table" and finished ~= before and finished.wfAddr == context.wf and not upstreamBusy() then
            state.status = "Applied (" .. from .. "). See the console for details."
            return
        end
        state.status = "Applying... (a few seconds)"
        task.wait(0.5)
    end
    error("The changer did not finish within 150s. Check the Matcha console.")
end

-- Widgets

local function job(label, fn)
    if shared.busy then return end
    shared.busy, state.status = true, label
    task.spawn(function()
        local ok, err = pcall(fn)
        shared.busy = false
        if not ok then
            state.status = "Error - see the Matcha console."
            print("[Rivals GUI] " .. tostring(err))
            if type(notify) == "function" then pcall(notify, tostring(err), TAB, 8) end
        end
    end)
end
local drawTab
-- Sound preview. The menu can't play audio, but the game plays
-- SoundLibrary.EquipSounds every time you switch weapons, so for a few
-- seconds those become the sound being previewed. They are Luau strings
-- reached through the module's table (same registry route as the changer),
-- rewritten in place and put back afterwards.
local DEFAULT_SOUNDS = {Hit = "13110130082", Critical = "16537449730", Kill = "16530229616"}
local PREVIEW_SECONDS = 10
local previewing = false

local function rdq(a) local ok, v = pcall(memory_read, "uintptr_t", a) return ok and v or nil end
local function rdi(a) local ok, v = pcall(memory_read, "int", a) return ok and v or nil end
local function readLuaString(ts) local ok, v = pcall(memory_read, "string", ts + 24) return ok and v or nil end
local function writeLuaString(ts, text)
    for i = 1, #text do memory_write("byte", ts + 24 + i - 1, string.byte(text, i)) end
    memory_write("byte", ts + 24 + #text, 0)
    memory_write("int", ts + 20, #text)
end

local function equipSoundStrings()
    local modules = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
    local ms = modules and modules:FindFirstChild("SoundLibrary")
    local thread = ms and rdq(ms.Address + 0x170)
    local g = thread and rdq(thread + 0x18)
    local reg = g and rdq(g + 0x620)
    local slot, arr = ms and rdi(ms.Address + 0x178), reg and rdq(reg + 0x20)
    local t = arr and slot and slot > 0 and rdq(arr + (slot - 1) * 16)
    if not t then return {} end
    local base = rdq(t + 0x18)
    local okL, l = pcall(memory_read, "byte", t + 6)
    if not base or not okL or l > 12 then return {} end
    for i = 0, 2 ^ l - 1 do
        local node = base + i * 32
        local key = rdq(node + 16)
        if key and readLuaString(key) == "EquipSounds" then
            local list = rdq(node)
            local size, items = list and rdi(list + 8), list and rdq(list + 0x20)
            local out = {}
            for j = 0, (size or 0) - 1 do
                local ts = rdq(items + j * 16)
                local text = ts and readLuaString(ts)
                if text and text:find("^rbxassetid://%d+$") then out[#out + 1] = ts end
            end
            return out
        end
    end
    return {}
end

local function previewSound(id)
    if previewing then return "Already on - switch weapons to hear it." end
    local digits = id and tostring(id):match("(%d+)$")
    if not digits then return "That one is muted - nothing to play." end
    local text = "rbxassetid://" .. digits
    if #text > 31 then return "That id is too long to preview." end
    local strings = equipSoundStrings()
    if #strings == 0 then return "Preview not available right now." end
    local saved = {}
    for _, ts in ipairs(strings) do
        saved[#saved + 1] = {ts, readLuaString(ts)}
        writeLuaString(ts, text)
    end
    previewing = true
    -- task.delay does not run in Matcha; a spawned wait does.
    task.spawn(function()
        task.wait(PREVIEW_SECONDS)
        for _, s in ipairs(saved) do
            if readLuaString(s[1]) == text then writeLuaString(s[1], s[2]) end
        end
        previewing = false
    end)
    return "Switch weapons (1-4) in the next " .. PREVIEW_SECONDS .. " s to hear it."
end

local function refreshTab()
    if state.refreshQueued then return end
    state.refreshQueued = true
    task.spawn(function()
        task.wait()
        if _G.__RivalsGuiSession ~= guiToken then return end
        pcall(function()
            UI.RemoveTab(TAB)
            UI.AddTab(TAB, drawTab)
        end)
        state.refreshQueued = false
    end)
end
local function selectedIndex(list, value)
    for i, text in ipairs(list) do if text == value then return i - 1 end end
    return 0
end
local function options(names, selected, firstLabel)
    local result, seen = {firstLabel}, {[firstLabel] = true}
    for _, name in ipairs(names) do
        if name ~= "Standard" and name ~= "Default" and not seen[name] then
            result[#result + 1], seen[name] = name, true
        end
    end
    if selected and not seen[selected] then result[#result + 1] = selected end
    return result
end
local function picker(sec, section, key, names, firstLabel, label, onPick)
    local selected = (state.values[section] or {})[key]
    -- Never offer the item you own as its own replacement.
    local choices = {}
    for _, name in ipairs(names) do
        if name ~= key then choices[#choices + 1] = name end
    end
    local list = options(choices, selected, firstLabel)
    local id = "rv_" .. session .. "_" .. state.revision .. "_" .. section .. "_" .. key
    UI.SetValue(id, selectedIndex(list, selected))
    sec:Combo(id, label or key, list, selectedIndex(list, selected), function(idx)
        local value = list[(tonumber(idx) or 0) + 1]
        if not value then return end
        if onPick then onPick(idx ~= 0 and value or nil) else setMapping(section, key, idx ~= 0 and value or nil) end
    end)
end
local function searchBox(sec, section, label)
    sec:InputText("rv_find_" .. session .. "_" .. section, label or "Search", state.searchText[section] or "", function(value)
        if type(value) ~= "string" then return end
        local normalized = trim(value):lower()
        local changed = (state.search[section] or "") ~= normalized
        state.searchText[section], state.search[section] = value, normalized
        if changed then refreshTab() end
    end)
end
local function matching(section, names)
    local query, out = state.search[section] or "", {}
    for _, name in ipairs(names) do
        if query == "" or name:lower():find(query, 1, true) then out[#out + 1] = name end
    end
    return out
end
-- The "Looks like" half has its own search; the current pick always stays listed.
local function matchingTargets(section, names, selected)
    local out = matching(section .. "_target", names)
    if selected and #out < #names then
        local listed = false
        for _, name in ipairs(out) do if name == selected then listed = true break end end
        if not listed then out[#out + 1] = selected end
    end
    return out
end
-- "Item you own" then "looks like", written as Owned=Target.
local function mappingSection(sec, section, list)
    searchBox(sec, section, "Search you own")
    searchBox(sec, section .. "_target", "Search looks like")
    local names = matching(section, list)
    if #names == 0 then sec:Text("No matches - clear the search."); return end
    local index = selectedIndex(names, state.owned[section])
    state.owned[section] = names[index + 1]
    local id = "rv_own_" .. session .. "_" .. state.revision .. "_" .. section .. "_" .. (state.search[section] or "")
    UI.SetValue(id, index)
    sec:Combo(id, "You own", names, index, function(idx)
        if not shared.busy then
            state.owned[section] = names[(tonumber(idx) or 0) + 1]
            refreshTab()
        end
    end)
    local owned = state.owned[section]
    if not owned then return end
    -- Season charms carry every rank; one has to be picked or the game shows all.
    local targets = matchingTargets(section, list, (state.values[section] or {})[owned])
    if section == "charms" then
        local current = (state.values.charms or {})[owned]
        targets = matchingTargets(section, list, current and (current:match("^(Season %d+)%s") or current))
        picker(sec, section, owned, targets, "Unchanged", "Looks like", function(value)
            if value and value:match("^Season %d+$") then
                local rank = state.rank[owned] or RANKS[1]
                setMapping(section, owned, value .. " " .. rank)
            else
                setMapping(section, owned, value)
            end
            refreshTab()
        end)
        local target = (state.values.charms or {})[owned] or ""
        local season = target:match("^(Season %d+)%s")
        if season then
            local current = target:match("^Season %d+%s+(.+)$") or RANKS[1]
            local rid = "rv_rank_" .. session .. "_" .. state.revision .. "_" .. owned
            UI.SetValue(rid, selectedIndex(RANKS, current))
            sec:Combo(rid, "Rank", RANKS, selectedIndex(RANKS, current), function(idx)
                local rank = RANKS[(tonumber(idx) or 0) + 1]
                if rank then
                    state.rank[owned] = rank
                    setMapping(section, owned, season .. " " .. rank)
                end
            end)
        end
    else
        picker(sec, section, owned, targets, "Unchanged", "Looks like")
    end
    sec:Spacing()
    local keys = {}
    for key in pairs(state.values[section] or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    if #keys > 0 then sec:Text("Set:") end
    for _, key in ipairs(keys) do sec:Text("  " .. key .. " -> " .. state.values[section][key]) end
end


-- Watches for Rivals to finish loading (the changer needs its assets), then
-- applies once per server. Autoexec can start the menu long before the join
-- and the menu outlives teleports, so it keeps watching instead of timing
-- out. A second GUI run takes over.
local function autoApplyOnJoin()
    task.spawn(function()
        while _G.__RivalsGuiSession == guiToken do
            -- Autoexec can start the menu before the workspace is readable;
            -- read the saved switch again once it is.
            local okFile, hasFile = pcall(isfile, SETTINGS)
            if not state.settingsRead and okFile and hasFile then
                local before = state.autoApply
                pcall(loadSettings)
                if state.autoApply ~= before then refreshTab() end
            end
            local context = state.autoApply and currentContext()
            local key = context and context.key
            local applied = _G.__RIVALS_SKIN_CHANGER_STATE
            if key and _G.__RivalsGuiAutoApplied ~= key and applied and applied.wfAddr == context.wf then
                -- Already applied here, by hand or by an earlier menu.
                _G.__RivalsGuiAutoApplied = key
            elseif key and _G.__RivalsGuiAutoApplied ~= key and not shared.busy and not upstreamBusy() then
                _G.__RivalsGuiAutoApplied = key
                if not (isfile(FILE) and readfile(FILE):find("%S")) then
                    state.status = "Auto-apply: nothing configured yet."
                else
                    -- Started from autoexec the lists were read before Rivals
                    -- loaded, so they are empty; read them again now.
                    if #catalog.weapons == 0 then
                        pcall(loadCatalog)
                        refreshTab()
                    end
                    job("Auto-applying...", apply)
                end
            end
            task.wait(2)
        end
    end)
end

pcall(loadConfig)
pcall(loadSettings)
pcall(loadCatalog)
pcall(function() UI.RemoveTab(TAB) end)

drawTab = function(tab)
    local controls = tab:Section("Changer", "Left")
    controls:Button("Save & Apply", function() job("Applying...", apply) end)
    controls:Button("Reload lists", function() job("Reading lists...", function() loadCatalog() refreshTab() end) end)
    controls:Text(shared.busy and "Working..." or state.status)
    controls:Text(state.catalogStatus)
    local autoOptions = {"Off", "On"}
    local aid = "rv_auto_" .. session .. "_" .. state.revision
    UI.SetValue(aid, state.autoApply and 1 or 0)
    controls:Combo(aid, "Auto-apply on join", autoOptions, state.autoApply and 1 or 0, function(idx)
        state.autoApply = (tonumber(idx) or 0) == 1
        saveSettings()
        state.status = state.autoApply and "Auto-apply on: it will apply itself next join."
            or "Auto-apply off."
    end)
    if state.autoexecScan then controls:Text("Autoexec: " .. state.autoexecScan) end

    local sky = tab:Section("Skybox and lighting", "Left")
    local skyNow = ((state.values.skybox or {}).Preset or ""):lower()
    local function setSky(value)
        -- Per-face ids from the site would win over the preset; drop them.
        for _, k in ipairs({"All", "BK", "DN", "FT", "LF", "RT", "UP"}) do setMapping("skybox", k, nil) end
        setMapping("skybox", "Preset", value)
    end
    -- The group shown is the one holding the current sky, unless another was just picked.
    local groupIndex = 0
    for gi, g in ipairs(SKY_GROUPS) do
        for _, name in ipairs(g.skies) do if name == skyNow then groupIndex = gi - 1 end end
    end
    if state.skyGroup then groupIndex = state.skyGroup end
    local group = SKY_GROUPS[groupIndex + 1]
    local gid = "rv_skyg_" .. session .. "_" .. state.revision
    UI.SetValue(gid, groupIndex)
    sky:Combo(gid, "Skybox", SKY_GROUP_NAMES, groupIndex, function(idx)
        if shared.busy then return end
        state.skyGroup = tonumber(idx) or 0
        if state.skyGroup == 0 then setSky(nil) end
        refreshTab()
    end)
    if #group.skies > 0 then
        local sid = "rv_sky_" .. session .. "_" .. state.revision .. "_" .. groupIndex
        local current = selectedIndex(group.skies, skyNow)
        local listed = false
        for _, name in ipairs(group.skies) do if name == skyNow then listed = true end end
        local options = {}
        if not listed then options[1] = "Pick one" end
        for _, name in ipairs(group.skies) do options[#options + 1] = name end
        current = listed and current or 0
        UI.SetValue(sid, current)
        sky:Combo(sid, "Sky", options, current, function(idx)
            local value = options[(tonumber(idx) or 0) + 1]
            if value and value ~= "Pick one" then setSky(value) end
        end)
    end
    -- "Match sky" uses the lighting made for the chosen sky (the uploaded ones).
    local lightOptions, lightValues = {"Normal", "Dark", "Match sky"}, {nil, "dark", "match"}
    local lightNow = ((state.values.lighting or {}).Preset or ""):lower()
    local lightIndex = lightNow == "dark" and 1 or (lightNow == "match" and 2 or 0)
    local lid = "rv_light_" .. session .. "_" .. state.revision
    UI.SetValue(lid, lightIndex)
    sky:Combo(lid, "Lighting", lightOptions, lightIndex, function(idx)
        setMapping("lighting", "Preset", lightValues[(tonumber(idx) or 0) + 1])
    end)

    -- Hit, headshot and kill sounds: a Roblox audio id each, "none" mutes,
    -- empty keeps the game's own.
    -- A fixed-height section scrolls (dropdowns can't), so each sound is a
    -- page with the whole list as buttons; the current pick is marked.
    local soundSlots = {{"Hit", "Body hit"}, {"Critical", "Headshot"}, {"Kill", "Kill"}}
    local soundPages = {}
    for _, slot in ipairs(soundSlots) do soundPages[#soundPages + 1] = slot[2] end
    local sounds = tab:Section("Sounds", "Left", soundPages, 260)
    local slot = soundSlots[(sounds.page or 0) + 1] or soundSlots[1]
    local key = slot[1]
    local current = (state.values.sounds or {})[key]
    local currentLow = current and tostring(current):lower()
    sounds:Button("Preview this sound", function()
        state.previewNote = previewSound(current or DEFAULT_SOUNDS[key])
        refreshTab()
    end)
    sounds:Text(state.previewNote or "Plays on your next weapon switch (hold a weapon).")
    local function choice(label, id)
        local picked = (id == nil and current == nil) or (id ~= nil and id == currentLow)
        sounds:Button((picked and "> " or "   ") .. label, function()
            setMapping("sounds", key, id)
            refreshTab()
        end)
    end
    choice("Game default", nil)
    choice("Mute", "none")
    for _, group in ipairs(SOUND_LIBRARY) do
        sounds:Text(group.name)
        for _, g in ipairs(group.sounds) do choice(g[1], g[2]) end
    end
    sounds:Spacing()
    sounds:InputText("rv_snd_" .. session .. "_" .. key, "Custom id", current and currentLow ~= "none" and current or "", function(value)
        if type(value) ~= "string" then return end
        local v = trim(value)
        setMapping("sounds", key, v ~= "" and v or nil)
    end)
    sounds:Text("Any Roblox audio id the game can play.")

    local credits = tab:Section("Credits", "Left")
    credits:Text("Skin changer by Martini")
    credits:Text("Contributor: dantekarati")
    credits:Text("Main Testers/Supporters: choperr0333 aka @Giounis")

    local pages = {"Skins", "Swaps", "Wraps", "Finishers", "Charms"}
    local items = tab:Section("Items", "Right", pages, 440)
    local page = pages[(items.page or 0) + 1] or "Skins"
    if page == "Skins" then
        searchBox(items, "skins")
        local query, shown = state.search.skins or "", 0
        -- Matches the weapon name or any of its skins; a skin match lists only those skins.
        for _, weapon in ipairs(catalog.weapons) do
            local skins = weapon.skins or {}
            if query ~= "" and not weapon.name:lower():find(query, 1, true) then
                local hits, selected = matching("skins", skins), (state.values.skins or {})[weapon.name]
                if #hits == 0 then
                    skins = nil
                else
                    local listed = not selected
                    for _, s in ipairs(hits) do if s == selected then listed = true break end end
                    if not listed then hits[#hits + 1] = selected end
                    skins = hits
                end
            end
            if skins then
                picker(items, "skins", weapon.name, skins, "Default")
                shown = shown + 1
            end
        end
        if shown == 0 then items:Text("No weapons match that search.") end
    elseif page == "Swaps" then
        items:Text("Equip a skin you own and it looks like another skin of the same weapon.")
        local weaponNames = {}
        for _, w in ipairs(catalog.weapons) do weaponNames[#weaponNames + 1] = w.name end
        if #weaponNames == 0 then
            items:Text("Weapon list unavailable - press Reload lists.")
        else
            local wIndex = selectedIndex(weaponNames, state.owned.swapWeapon)
            state.owned.swapWeapon = weaponNames[wIndex + 1]
            local wid = "rv_swapw_" .. session .. "_" .. state.revision
            UI.SetValue(wid, wIndex)
            items:Combo(wid, "Weapon", weaponNames, wIndex, function(idx)
                if not shared.busy then
                    state.owned.swapWeapon = weaponNames[(tonumber(idx) or 0) + 1]
                    refreshTab()
                end
            end)
            local weapon = state.owned.swapWeapon
            local skins = {}
            for _, w in ipairs(catalog.weapons) do
                if w.name == weapon then
                    for _, skin in ipairs(w.skins or {}) do
                        if skin ~= "Default" and skin ~= "Standard" then skins[#skins + 1] = skin end
                    end
                end
            end
            if #skins == 0 then
                items:Text("No skins listed for this weapon.")
            else
                local oIndex = selectedIndex(skins, state.owned.swapSkin)
                state.owned.swapSkin = skins[oIndex + 1]
                local oid = "rv_swapo_" .. session .. "_" .. state.revision .. "_" .. weapon
                UI.SetValue(oid, oIndex)
                items:Combo(oid, "You own", skins, oIndex, function(idx)
                    if not shared.busy then
                        state.owned.swapSkin = skins[(tonumber(idx) or 0) + 1]
                        refreshTab()
                    end
                end)
                local owned = state.owned.swapSkin
                local current = ((state.swaps or {})[weapon] or {})[owned]
                searchBox(items, "swaps_target", "Search looks like")
                local targets = {"Unchanged"}
                for _, skin in ipairs(matchingTargets("swaps", skins, current)) do
                    if skin ~= owned then targets[#targets + 1] = skin end
                end
                local tid = "rv_swapt_" .. session .. "_" .. state.revision .. "_" .. weapon .. "_" .. tostring(owned)
                UI.SetValue(tid, selectedIndex(targets, current))
                items:Combo(tid, "Looks like", targets, selectedIndex(targets, current), function(idx)
                    local value = targets[(tonumber(idx) or 0) + 1]
                    if value and owned then setSwap(weapon, owned, idx ~= 0 and value or nil) end
                end)
            end
            items:Spacing()
            local any = false
            for w, list in pairs(state.swaps or {}) do
                for owned, target in pairs(list) do
                    if not any then items:Text("Set:") any = true end
                    items:Text("  " .. w .. ": " .. owned .. " -> " .. target)
                end
            end
        end
    elseif page == "Wraps" then
        mappingSection(items, "wraps", catalog.wraps)
    elseif page == "Finishers" then
        mappingSection(items, "finishers", catalog.finishers)
    else
        mappingSection(items, "charms", catalog.charms)
    end
end

UI.AddTab(TAB, drawTab)
print("[Rivals GUI] Ready - open the '" .. TAB .. "' tab."
    .. (state.autoApply and " Auto-apply is on." or ""))
autoApplyOnJoin()
