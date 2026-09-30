-- Rivals changer GUI, drawn on screen
-- Edits rivals_config.lua and runs the skin changer, in a window of its own
-- drawn with the Drawing library (it replaced the Matcha menu tab, now kept as
-- RivalsSkinGuiMatcha.lua): weapons by loadout slot, skin grid with pictures,
-- Switch and Swap, wraps, finishers, charms, sky, lighting and sounds. A key
-- (Right Shift unless changed in Settings) shows and hides it; the accent
-- color is picked there too. Auto-apply on join applies the saved config once
-- per server.
--
-- Matcha can't create instances, so everything is Drawing objects redrawn every
-- frame from a pool. Pictures come from the config site (the same files its
-- pages use) and are cached in the workspace as .dat files.

local FILE = "rivals_config.lua"
local SETTINGS = "rivals_gui_settings.txt"
local BACKUP = "rivals_config.backup.lua"
local CACHE = "rivals_gui_cache"
local SCRIPT_FILES = {"RivalsSkinSwapper.lua", "workspace/RivalsSkinSwapper.lua", "scripts/RivalsSkinSwapper.lua"}
local SCRIPT_URL = "https://raw.githubusercontent.com/Martinikaws/RivalsSkinChangerFULLMATCHA/refs/heads/main/main.lua"
local SITE = "https://martinikaws.github.io/rivals-skins/"
local RIVALS_GAME_ID = 6035872082
-- Keys the show/hide key can be set to (Windows key codes), by name.
local KEY_NAMES = {
    [0x08] = "Backspace", [0x09] = "Tab", [0x0D] = "Enter", [0x14] = "Caps Lock", [0x20] = "Space",
    [0x21] = "Page Up", [0x22] = "Page Down", [0x23] = "End", [0x24] = "Home", [0x25] = "Left", [0x26] = "Up",
    [0x27] = "Right", [0x28] = "Down", [0x2D] = "Insert", [0x2E] = "Delete", [0xA0] = "Left Shift",
    [0xA1] = "Right Shift", [0xA2] = "Left Ctrl", [0xA3] = "Right Ctrl", [0xA4] = "Left Alt", [0xA5] = "Right Alt",
    [0xBA] = ";", [0xBB] = "=", [0xBC] = ",", [0xBD] = "-", [0xBE] = ".", [0xBF] = "/", [0xC0] = "`",
    [0xDB] = "[", [0xDC] = "\\", [0xDD] = "]", [0xDE] = "'",
}
for i = 0, 25 do KEY_NAMES[0x41 + i] = string.char(65 + i) end
for i = 0, 9 do KEY_NAMES[0x30 + i] = tostring(i); KEY_NAMES[0x60 + i] = "Num " .. i end
for i = 1, 12 do KEY_NAMES[0x6F + i] = "F" .. i end
local function keyName(vk) return KEY_NAMES[vk] or ("Key " .. tostring(vk)) end
local DEFAULT_TOGGLE, DEFAULT_ACCENT = 0xA1, "568cff"

assert(Drawing and type(Drawing.new) == "function", "Matcha's Drawing library is required.")
assert(type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function",
    "Matcha file functions are required.")

-- A second run replaces the first; the menu-tab GUI steps aside too.
-- Only in RIVALS. (The id is 0 until the game has loaded; started that early,
-- the window closes itself once the game turns out to be another one.)
local function otherGame()
    local ok, id = pcall(function() return tonumber(game.GameId) end)
    return ok and id ~= nil and id ~= 0 and id ~= RIVALS_GAME_ID
end
if otherGame() then
    print("[Rivals GUI] Not RIVALS - the GUI stays off in this game.")
    return
end

if _G.__RivalsDrawnGui then pcall(_G.__RivalsDrawnGui.stop) end
pcall(function() UI.RemoveTab("Rivals Changer") end)

_G.RivalsGuiState = _G.RivalsGuiState or {busy = false}
local shared = _G.RivalsGuiState
shared.busy = false
local guiToken = {}
_G.__RivalsGuiSession = guiToken

-- Lists that don't come from the game

local function numbered(prefix, from, to)
    local out = {}
    for n = from, to do out[#out + 1] = string.format("%s %02d", prefix, n) end
    return out
end
local SKY_GROUPS = {
    {name = "Game skies", skies = {"blue", "space", "graveyard", "sudden death", "station", "westown", "black", "gray", "classic"}},
    {name = "Cloudy", skies = numbered("cloudy", 1, 25)},
    {name = "Space", skies = {"galaxy", "blue nebula", "gold nebula"}},
    {name = "More A-D", skies = {"aurora", "beautiful", "black hole", "blue sky", "broken sky", "castle grounds", "chill gray", "chill pink", "chroma key", "clear skies", "cyan", "dead star forest", "disaster"}},
    {name = "More E-M", skies = {"elegant morning", "emo", "fade blue", "forest", "goodnight", "grimnight", "hades", "hazy", "jungle", "light blue", "light pink", "minecraft", "minecraft end"}},
    {name = "More M-P", skies = {"moonlight", "neon sky", "neon sky 2", "nibiru", "night", "night sky moon", "northern lights", "oblivion", "orange", "overcast", "pandora", "peaceful morning", "pink sunrise"}},
    {name = "More P-S", skies = {"pumpkin hill", "purple nebula", "red", "setting sun", "sfoth", "shiverfrost", "sky 05", "sky 13", "sky 2006", "sky 22", "sky 31", "sky 38", "sky 47"}},
    {name = "More S-Z", skies = {"sky purple", "sky sunset", "space blue", "spooky", "sunny sky", "universe", "utter east", "whomp fortress", "winterness", "xen", "zen end"}},
}
-- Front faces of the game's own skies; the uploaded ones come from skyboxes.json.
local SKY_FACES = {
    blue = "14147882761", space = "10196550367", graveyard = "135908632589654",
    ["sudden death"] = "84214501374682", station = "2108482231", westown = "12261809766",
}
local SOUND_LIBRARY = {
    {name = "Rivals", sounds = {
        {"Hitmarker tick", "13110130082"}, {"Headshot crack", "16537449730"}, {"Elimination 1", "16530229616"},
        {"Elimination 2", "16530229541"}, {"Elimination 3", "16530229695"}, {"Target shatter", "14441658101"},
        {"RPG explosion", "13455969017"}, {"Equip click", "13158735106"}, {"Landing", "16736552001"},
        {"Jump", "16736552098"}, {"Duel timer tick", "17826390328"}, {"Click", "177266782"},
    }},
    {name = "Roblox", sounds = {
        {"Classic hit", "12222046"}, {"Button", "12221967"}, {"Electronic ping", "12221990"},
        {"Glass break", "12222005"}, {"Kerplunk", "12222054"}, {"Fast click", "12221976"},
        {"Bright click", "15675059323"}, {"Cute pop", "15675055424"}, {"Notification", "17208361335"},
        {"Coin", "127645268874265"}, {"Pinball bell", "16480570986"}, {"8-bit blip", "16480580213"},
        {"Metal click", "16480551554"}, {"Sparkle ding", "9126073001"}, {"Cannon blast", "3149249837"},
    }},
    {name = "Hit sounds", sounds = {
        {"Undertale critical hit", "140181868959125"}, {"Hit sound", "139520673393967"},
        {"Undertale attack hit", "140721035016341"}, {"Fist hit", "140604838213617"},
        {"TF2 critical hit", "137392628136734"}, {"AvA punch", "138208560796742"}, {"Rock hit", "82708037443413"},
        {"Spear hit", "135278368445325"}, {"Persona 5 hit", "140706017778464"},
        {"Energy sword hit", "139503070303020"}, {"Stone hit", "3581383408"}, {"8-bit impact", "109598434966968"},
        {"Minecraft hit", "73369656122118"}, {"Car hit", "1897654568"}, {"Beam hit", "103134129110384"},
    }},
    {name = "Your pack", sounds = {
        {"agpa 1", "102651850556408"}, {"agpa 2", "132463144859699"}, {"Huhh", "115574480250251"},
        {"Minecraft hurt", "127059326655954"}, {"msfrs.hit", "138523457528846"}, {"neverlose.cc", "139452805868562"},
        {"Rust headshot 2", "138750331387064"}, {"skeet (louder)", "140247876667835"},
        {"Taco Bell bong", "128327858093323"}, {"Bubble pop", "121434237134952"},
        {"Windows XP error", "95509039020568"}, {"My name is Jeff", "2867856238"}, {"HL2 crowbar", "73268721537561"},
        {"DSR-1", "93739917036633"}, {"Fatality", "97439296876895"}, {"Bepis", "1921494658"},
        {"Burp", "130147881880627"}, {"Duck quack", "140601322851309"}, {"Computer beep", "2626561747"},
        {"MGS alert", "139345986070502"}, {"Doom shotgun", "15120932483"}, {"Cash register", "120891770644830"},
        {"Cowbell", "9125935023"}, {"Winner FX", "1841267764"}, {"Cartoon bubble", "5852470908"},
    }},
    {name = "Community", sounds = {
        {"CoD hitmarker", "138832207290954"}, {"Quake hitmarker", "1455817260"},
        {"GameSense hitmarker", "4817809188"}, {"Minecraft hitmarker", "127091812835195"},
        {"Minecraft bow ding", "135478009117226"}, {"MLG hitmarker", "121351852050830"},
        {"Head hitmarker", "17724154662"}, {"TF2 hitsound", "138901307926331"}, {"osu! hitsound", "123941247147792"},
        {"Bubble pop", "119697580657161"}, {"CS:GO headshot", "133002449941130"}, {"Arsenal headshot", "18513634637"},
        {"Fortnite headshot", "2513174484"}, {"Rust headshot", "128633263668964"},
        {"Battlefield headshot", "70528023820006"}, {"PHIGHTING headshot", "138549196892842"},
        {"TF2 kill", "124543461907751"}, {"Among Us kill", "130456049552264"}, {"MM2 knife kill", "97347330766907"},
        {"Double kill", "116907610084760"},
    }},
    {name = "Kenney (CC0)", sounds = {
        {"Punch heavy", "107508753428253"}, {"Punch", "76122581259100"}, {"Metal tap", "138075431083492"},
        {"Metal clang", "133464625805308"}, {"Glass tap", "138936753289661"}, {"Glass smash", "75898126734535"},
        {"Bell hit", "126126591991039"}, {"Plate tap", "117110797440641"}, {"Tin hit", "135391446483517"},
        {"Soft thud", "95039951320381"}, {"Click", "127906824435990"}, {"Tick", "130702709867354"},
        {"Confirm", "112196335049721"}, {"Glass ding", "127490438798725"}, {"Pluck", "72021613097471"},
        {"Bong", "117732813936667"}, {"Drop", "128207733490113"}, {"Glitch", "131159017045649"},
        {"Zap", "136683295906047"}, {"Zap two-tone", "132620272525127"}, {"Pep", "70583920911483"},
        {"High up", "117530563976701"}, {"Phaser up", "104765335548518"}, {"Power up", "105788477038167"},
        {"Three-tone", "70578968807464"}, {"Small laser", "91301983822305"}, {"Retro laser", "118116613865507"},
        {"Explosion crunch", "82931503751689"},
    }},
}
local SOUND_SLOTS = {{"Hit", "Body hit"}, {"Critical", "Headshot"}, {"Kill", "Kill"}}
local RANKS = {"Archnemesis", "Nemesis", "Onyx 3", "Onyx 2", "Onyx 1", "Diamond 3", "Diamond 2", "Diamond 1",
    "Platinum 3", "Platinum 2", "Platinum 1", "Gold 3", "Gold 2", "Gold 1", "Silver 3", "Silver 2", "Silver 1",
    "Bronze 3", "Bronze 2", "Bronze 1", "Unranked"}
local RARITY_COLORS = {
    Common = Color3.fromRGB(123, 255, 0), Rare = Color3.fromRGB(0, 221, 255), Legendary = Color3.fromRGB(255, 60, 60),
    Mythical = Color3.fromRGB(129, 133, 242), Unique = Color3.fromRGB(255, 140, 0), Genuine = Color3.fromRGB(127, 163, 90),
}
-- Loadout slot of each weapon; the site's list replaces this when it loads.
local WEAPON_SLOTS = {}
for slot, names in pairs({
    Primary = {"Assault Rifle", "Bow", "Burst Rifle", "Crossbow", "Distortion", "Energy Rifle", "Flamethrower",
        "Grenade Launcher", "Gunblade", "Minigun", "Paintball Gun", "Permafrost", "RPG", "Shotgun", "Sniper", "Wildcat"},
    Secondary = {"Daggers", "Energy Pistols", "Exogun", "Flare Gun", "Handgun", "Revolver", "Shorty", "Slingshot",
        "Spray", "Uzi", "Warper"},
    Melee = {"Battle Axe", "Chainsaw", "Fists", "Katana", "Knife", "Maul", "Riot Shield", "Scythe", "Spear", "Trowel"},
    Utility = {"Flashbang", "Freeze Ray", "Grappler", "Grenade", "Jump Pad", "Medkit", "Molotov", "Satchel",
        "Smoke Grenade", "Subspace Tripmine", "War Horn", "Warpstone"},
}) do
    for _, name in ipairs(names) do WEAPON_SLOTS[name] = slot end
end
local WRAP_RARITY_NAMES = {"Common", "Rare", "Legendary", "Mythical", "Unique", "Genuine", "Unobtainable"}

local state = {
    status = "Loading...", lines = {}, values = {}, swaps = {}, readable = false,
    tab = "Skins", skinsView = "main", slotTab = "All", mode = "Switch", swapStep = 1, swapOwned = {},
    weapon = nil, cosKind = "wraps", owned = {}, rank = {},
    skyGroup = 1, soundSlot = 1, soundGroup = 1,
    inputs = {}, scroll = {}, mouseOffset = 0, open = true,
    toggleKey = DEFAULT_TOGGLE, accent = DEFAULT_ACCENT,
    -- "You own" lists show only what you own; the window stays hidden when
    -- autoexec starts it.
    ownedOnly = true, showOnAutoexec = false,
}
local catalog = {weapons = {}, wraps = {}, finishers = {}, charms = {}, skyFaces = {}, loaded = false}

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
    state.values = {skins = {}, wraps = {}, finishers = {}, charms = {}, skybox = {}, lighting = {}, sounds = {}}
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
local function configText()
    if #state.lines == 0 then return "-- Rivals config\n" end
    return table.concat(state.lines, "\n") .. "\n"
end
-- Changed compared with what was last loaded or saved.
local function markChanged()
    state.dirty = configText() ~= state.cleanText
    state.status = state.dirty and "Changed - press Save & Apply." or "No changes."
end
-- The changer trades two models for each line, so a skin, finisher or charm
-- can only be in one line: it skips a second line that uses one again.
-- Returns those lines, in the order the changer would skip them.
local function configClashes()
    local out, section, touched, used, swaps = {}, "skins", {}, {}, {}
    for _, line in ipairs(state.lines) do
        local h = header(line)
        if h then
            section = h
        elseif section == "skins" then
            local w, o, t = swapLine(line)
            if w then
                swaps[#swaps + 1] = {o, t}
            else
                local k, v = pair(line)
                local low = v and v:lower()
                if k and v and low ~= "default" and low ~= "standard" then
                    if touched[v] or touched[k] then
                        out[#out + 1] = k .. " -> " .. v
                    else
                        touched[v], touched[k] = true, true
                    end
                end
            end
        elseif section == "finishers" or section == "charms" then
            local k, v = pair(line)
            if k and v then
                -- Every rank of a season charm is the same model.
                local model = section == "charms" and (v:match("^(Season %d+)%s") or v) or v
                used[section] = used[section] or {}
                local u = used[section]
                if u[k] or u[model] then out[#out + 1] = k .. " -> " .. v else u[k], u[model] = true, true end
            end
        end
    end
    -- The changer runs the swaps after the Weapon=Skin lines.
    for _, sw in ipairs(swaps) do
        if touched[sw[2]] or touched[sw[1]] then
            out[#out + 1] = sw[1] .. " -> " .. sw[2]
        else
            touched[sw[2]], touched[sw[1]] = true, true
        end
    end
    return out
end
local function clashWarning()
    local bad = configClashes()
    if #bad == 0 then return nil end
    return "Two lines use the same item - the changer skips: " .. table.concat(bad, ", ")
end
local function loadConfig()
    local raw = isfile(FILE) and readfile(FILE) or nil
    local content = (raw or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    if content:sub(1, 3) == string.char(239, 187, 191) then content = content:sub(4) end
    local lines = {}
    for line in (content .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    while lines[#lines] == "" do table.remove(lines) end
    local cleaned = {}
    for _, line in ipairs(lines) do
        local k, v = pair(line)
        if not (k and v and k == v) then cleaned[#cleaned + 1] = line end
    end
    state.lines, state.baseline = cleaned, raw
    indexConfig()
    state.readable = true
    state.cleanText, state.dirty = configText(), false
    state.status = clashWarning() or (raw and "Loaded your configuration." or "Nothing saved yet - pick something.")
end
-- One key per section. A nil value removes the line; unknown sections get a
-- new [Header] at the end. Lines this GUI doesn't understand are kept.
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
    markChanged()
end
-- "Weapon | Owned > Target" lives in the skins section after the Weapon=Skin
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
    markChanged()
end
-- No hands: [NoHands] has Weapon=true lines, and All=true for every weapon
-- (a Weapon=false line then keeps that one's arms).
local function handsHidden(weapon)
    local v = state.values.nohands or {}
    local own = v[weapon] and tostring(v[weapon]):lower()
    if own == "true" then return true elseif own == "false" then return false end
    return tostring(v.All or ""):lower() == "true"
end
local function toggleHands(weapon)
    local all = tostring((state.values.nohands or {}).All or ""):lower() == "true"
    if handsHidden(weapon) then
        setMapping("nohands", weapon, all and "false" or nil)
    else
        setMapping("nohands", weapon, (not all) and "true" or nil)
    end
end
-- Makes a pick, then takes it back if it would put one item in two lines.
local function guarded(change, target)
    local before, was = state.lines, #configClashes()
    change()
    if #configClashes() > was then
        state.lines = before
        indexConfig()
        markChanged()
        state.status = target .. " is already used by another line. Two can't look like the same one - change that line first."
        if type(notify) == "function" then pcall(notify, "Rivals Skin Changer", state.status, 6) end
    end
end
local function saveConfig()
    assert(state.readable, "Reload the configuration before saving.")
    local current = isfile(FILE) and readfile(FILE) or nil
    assert(current == state.baseline,
        "The config changed outside this GUI. Press Reload config; your file was not overwritten.")
    local content = configText()
    if current == content then return end
    if current then
        writefile(BACKUP, current)
        assert(readfile(BACKUP) == current, "Could not verify the backup; save cancelled.")
    end
    writefile(FILE, content)
    assert(readfile(FILE) == content, "Could not verify the save. Your previous config is in " .. BACKUP)
    state.baseline = content
    state.cleanText, state.dirty = configText(), false
end

-- Settings: auto-apply is shared with the menu-tab GUI; the rest is this one's.
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
                        if body:find(marker, 1, true) then return true end
                    end
                end
            end
        end
    end
    return false
end
local function loadSettings()
    local okRead, body = pcall(readfile, SETTINGS)
    local auto
    if okRead and type(body) == "string" then
        state.settingsRead = true
        local value = body:match("autoapply%s*=%s*(%w+)")
        if value then auto = (value == "1" or value == "true" or value == "on") end
        state.mouseOffset = tonumber(body:match("mouseoffset%s*=%s*(%-?%d+)")) or 0
        local key = tonumber(body:match("togglekey%s*=%s*(%d+)"))
        state.toggleKey = key and KEY_NAMES[key] and key or DEFAULT_TOGGLE
        state.accent = body:match("accent%s*=%s*(%x%x%x%x%x%x)") or DEFAULT_ACCENT
        state.ownedOnly = body:match("ownedonly%s*=%s*(%d)") ~= "0"
        state.showOnAutoexec = body:match("showonautoexec%s*=%s*(%d)") == "1"
        state.noticeSeen = body:match("noticeseen%s*=%s*(%d)") == "1"
    end
    if auto == nil then
        local okScan, found = pcall(autoexecLoadsGui)
        auto = okScan and found or false
    end
    state.autoApply = auto
end
local function saveSettings()
    pcall(writefile, SETTINGS, "autoapply=" .. (state.autoApply and "1" or "0") .. "\n"
        .. "mouseoffset=" .. tostring(state.mouseOffset) .. "\n"
        .. "togglekey=" .. tostring(state.toggleKey) .. "\n"
        .. "accent=" .. tostring(state.accent) .. "\n"
        .. "ownedonly=" .. (state.ownedOnly and "1" or "0") .. "\n"
        .. "showonautoexec=" .. (state.showOnAutoexec and "1" or "0") .. "\n"
        .. "noticeseen=" .. (state.noticeSeen and "1" or "0") .. "\n")
end

-- What you own
--
-- Your player data has a CosmeticInventory table: a cosmetic's name maps to
-- true, or to a table of the weapons you own it for ({IsUniversal = true} for
-- all of them). It sits at PlayerDataController.CurrentData.Data, all Lua
-- tables, read from memory through the registry like the changer reads the
-- item libraries. nil when it can't be read; the lists then show everything.
local inventory = nil
local readInventory
do
    local mrd = memory_read
    local function rd(a) local ok, v = pcall(mrd, "uintptr_t", a) return ok and v or nil end
    local function rint(a) local ok, v = pcall(mrd, "int", a) return ok and v or nil end
    local function rbyte(a) local ok, v = pcall(mrd, "byte", a) return ok and v or nil end
    -- Roblox build 02c37bc (Sep 30 2026): an object's type is byte 1 of its
    -- header, a table's lsizenode byte 4, and a thread's global state +0x68.
    local TAG_TABLE, TAG_THREAD = 7, 10
    local function isTable(t) return t and t > 0x10000 and rbyte(t + 1) == TAG_TABLE end
    local function moduleTable(ms)
        local thread = ms and ms.Address and rd(ms.Address + 0x170)
        if not thread or thread < 0x10000 or rbyte(thread + 1) ~= TAG_THREAD then return nil end
        local g = rd(thread + 0x68)
        local reg = g and g > 0x10000 and rd(g + 0x620)
        if not isTable(reg) then return nil end
        local slot, size, arr = rint(ms.Address + 0x178), rint(reg + 8), rd(reg + 0x20)
        if not slot or not size or not arr or slot < 1 or slot > size then return nil end
        local t = rd(arr + (slot - 1) * 16)
        return isTable(t) and t or nil
    end
    -- Every string key of a table: key -> {value, type tag}
    local function fields(t)
        local out = {}
        if not isTable(t) then return out end
        local base, l = rd(t + 0x18), rbyte(t + 4)
        if not base or base < 0x10000 or not l or l > 16 then return out end
        for i = 0, 2 ^ l - 1 do
            local node = base + i * 32
            local tt, kp = rint(node + 12), rd(node + 16)
            if tt and tt ~= 0 and kp and kp > 0x10000 then
                local ok, key = pcall(mrd, "string", kp + 24)
                if ok and type(key) == "string" and #key > 0 and #key < 80 then out[key] = {rd(node), tt} end
            end
        end
        return out
    end
    readInventory = function()
        local ok, result = pcall(function()
            local ps = game:GetService("Players").LocalPlayer.PlayerScripts
            local ctl = moduleTable(ps.Controllers.PlayerDataController)
            local cur = ctl and fields(ctl).CurrentData
            local data = cur and fields(cur[1]).Data
            local inv = data and fields(data[1]).CosmeticInventory
            if not inv or not isTable(inv[1]) then return nil end
            local out, n = {}, 0
            for name, v in pairs(fields(inv[1])) do
                n = n + 1
                if v[2] == TAG_TABLE then
                    local on = {}
                    for weapon in pairs(fields(v[1])) do on[weapon] = true end
                    out[name] = on
                else
                    out[name] = true
                end
            end
            return n > 0 and out or nil
        end)
        inventory = ok and result or nil
        return inventory ~= nil
    end
end
-- Owned at all, or (for a skin) owned for that weapon.
local function owns(name, weapon)
    local e = inventory and inventory[name]
    if e == true then return true end
    if type(e) ~= "table" then return false end
    return weapon == nil or e.IsUniversal == true or e[weapon] == true
end
-- Whether the "you own" lists are cut down to what you own.
local function ownedOnly() return state.ownedOnly and inventory ~= nil end

-- Item lists

local function fetch(url)
    local body = (type(httpget) == "function") and httpget(url) or game:HttpGet(url)
    assert(type(body) == "string" and #body > 0, "Download failed: " .. url)
    return body
end
local function decode(text) return game:GetService("HttpService"):JSONDecode(text) end
local function jsAssignment(source, name)
    local encoded = source:match("window%." .. name .. "%s*=%s*(%b[])")
    return encoded and decode(encoded) or nil
end

local function loadCatalog()
    readInventory()
    local out = {weapons = {}, wraps = {}, finishers = {}, charms = {}, skyFaces = {}, loaded = true}
    -- Weapons, their skins, pictures and rarities, as the site shows them.
    local okMap, map = pcall(function() return decode(fetch(SITE .. "skin_icon_map.json")) end)
    local byName = {}
    if okMap and type(map) == "table" then
        -- The map, like the game's weapon models, has an "Unobtainable" entry
        -- that isn't a weapon.
        map.Unobtainable = nil
        for weapon, skins in pairs(map) do
            local entry = {name = weapon, skins = {}, info = {}}
            for skin, data in pairs(skins) do
                entry.info[skin] = {src = data.src, rarity = data.rarity}
                if skin ~= "Standard" and skin ~= "Default" then entry.skins[#entry.skins + 1] = skin end
            end
            table.sort(entry.skins)
            entry.icon = entry.info.Standard and entry.info.Standard.src
            byName[weapon] = entry
        end
    end
    -- Weapons the game has models for, so a new one still shows.
    pcall(function()
        local weapons = game:GetService("Players").LocalPlayer.PlayerScripts.Assets.ViewModels.Weapons
        for _, w in ipairs(weapons:GetChildren()) do
            if w.Name ~= "Unobtainable" then
                byName[w.Name] = byName[w.Name] or {name = w.Name, skins = {}, info = {}}
            end
        end
    end)
    -- Slots from the site's weapon list, over the built-in ones.
    local slots = {}
    for name, slot in pairs(WEAPON_SLOTS) do slots[name] = slot end
    pcall(function()
        local encoded = fetch(SITE):match("const%s+OFFICIAL_WEAPON_DATA%s*=%s*(%b[])%s*;")
        for _, w in ipairs(encoded and decode(encoded) or {}) do
            if type(w.name) == "string" and type(w.category) == "string" then slots[w.name] = w.category end
        end
    end)
    for name, w in pairs(byName) do w.slot = slots[name] or "Other" end
    for _, w in pairs(byName) do out.weapons[#out.weapons + 1] = w end
    table.sort(out.weapons, function(a, b) return a.name < b.name end)

    local okWraps, wrapsJs = pcall(fetch, SITE .. "assets/wraps.js")
    for _, row in ipairs(okWraps and jsAssignment(wrapsJs, "WRAPS") or {}) do
        if type(row[1]) == "string" and not row[1]:find("MISSING_", 1, true) then
            -- Each part: material, color, transparency, texture id. The game has
            -- no wrap pictures (it paints a 3D sheet); the site's previews are
            -- used, with these parts as color bands until one has loaded.
            local colors, textures = {}, {}
            for _, part in ipairs(type(row[4]) == "table" and row[4] or {}) do
                local ok, c = pcall(Color3.fromHex, tostring(part[2]))
                if ok and c and #colors < 3 then
                    colors[#colors + 1] = c
                    local tex = tonumber(part[4]) or 0
                    textures[#colors] = tex > 0 and string.format("assets/images/wraps/%.0f.png", tex) or false
                end
            end
            -- The site's wrap previews, one PNG per wrap named after it.
            local slug = row[1]:lower():gsub("[^a-z0-9]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
            out.wraps[#out.wraps + 1] = {name = row[1], rarity = WRAP_RARITY_NAMES[(tonumber(row[2]) or 0) + 1],
                colors = colors, textures = textures, src = "assets/images/wrapicons/" .. slug .. ".png"}
        end
    end
    local okCos, cosJs = pcall(fetch, SITE .. "assets/cosmetics.js")
    for _, kind in ipairs({{"finishers", "FINISHERS", "assets/images/finishers/"}, {"charms", "CHARMS", "assets/images/charms/"}}) do
        local seen = {}
        for _, row in ipairs(okCos and jsAssignment(cosJs, kind[2]) or {}) do
            if type(row[1]) == "string" and not row[1]:find("MISSING_", 1, true) then
                seen[row[1]] = true
                out[kind[1]][#out[kind[1]] + 1] = {name = row[1], rarity = row[2],
                    src = (type(row[3]) == "string" and row[3] ~= "") and (kind[3] .. row[3]) or nil}
            end
        end
        -- Anything the game has that the site doesn't list yet.
        pcall(function()
            local folder = kind[1] == "finishers"
                and game:GetService("ReplicatedStorage").Modules.Finishers
                or game:GetService("Players").LocalPlayer.PlayerScripts.Assets.Charms
            for _, m in ipairs(folder:GetChildren()) do
                if not seen[m.Name] and not m.Name:find("MISSING_", 1, true) then
                    out[kind[1]][#out[kind[1]] + 1] = {name = m.Name}
                end
            end
        end)
        table.sort(out[kind[1]], function(a, b) return a.name < b.name end)
    end
    table.sort(out.wraps, function(a, b) return a.name < b.name end)

    local okSky, skies = pcall(function() return decode(fetch(SITE .. "assets/skyboxes.json")) end)
    for name, face in pairs(SKY_FACES) do out.skyFaces[name] = face end
    for _, sky in ipairs(okSky and type(skies) == "table" and skies.skyboxes or {}) do
        if type(sky.name) == "string" and type(sky.faces) == "table" and sky.faces.ft then
            out.skyFaces[sky.name:lower()] = tostring(sky.faces.ft)
        end
    end
    catalog = out
    if not state.weapon and #catalog.weapons > 0 then state.weapon = catalog.weapons[1].name end
    state.status = okMap and string.format("%d weapons, %d wraps, %d finishers, %d charms",
        #catalog.weapons, #catalog.wraps, #catalog.finishers, #catalog.charms)
        or "The site is unreachable - pictures and skin lists are missing."
end

-- Running the changer

local function currentContext()
    local ok, result = pcall(function()
        if tonumber(game.GameId) ~= RIVALS_GAME_ID or not game:IsLoaded() then return nil end
        local jobId = game.JobId
        if type(jobId) ~= "string" or jobId == "" then return nil end
        local weapons = game:GetService("Players").LocalPlayer.PlayerScripts.Assets.ViewModels.Weapons
        if not weapons or not weapons.Address or #weapons:GetChildren() == 0 then return nil end
        return {key = jobId .. ":" .. tostring(weapons.Address), wf = weapons.Address}
    end)
    return ok and result or nil
end
local function upstreamBusy()
    local stamp = _G.__RIVALS_SKIN_CHANGER_BUSY
    return type(stamp) == "number" and tick() - stamp < 180
end
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
    local deadline = tick() + 150
    while tick() < deadline do
        local now = currentContext()
        if not now or now.key ~= context.key then
            state.status = "Server changed while applying - run it again."
            return
        end
        local finished = _G.__RIVALS_SKIN_CHANGER_STATE
        if type(finished) == "table" and finished ~= before and finished.wfAddr == context.wf and not upstreamBusy() then
            state.status = "Applied (" .. from .. "). Respawn to see new effects."
            return
        end
        state.status = "Applying... (a few seconds)"
        task.wait(0.5)
    end
    error("The changer did not finish within 150s. Check the Matcha console.")
end
local function job(label, fn)
    if shared.busy then return end
    shared.busy, state.status = true, label
    task.spawn(function()
        local ok, err = pcall(fn)
        shared.busy = false
        if not ok then
            state.status = "Error: " .. tostring(err):gsub("^.-:%d+: ", ""):sub(1, 90)
            print("[Rivals GUI] " .. tostring(err))
        end
    end)
end

-- Sound preview: the equip sounds briefly become the picked sound (see
-- RivalsSkinGui.lua for how the strings are found).
local PREVIEW_SECONDS = 10
local DEFAULT_SOUNDS = {Hit = "13110130082", Critical = "16537449730", Kill = "16530229616"}
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
    local g = thread and rdq(thread + 0x68)
    local reg = g and rdq(g + 0x620)
    local slot, arr = ms and rdi(ms.Address + 0x178), reg and rdq(reg + 0x20)
    local t = arr and slot and slot > 0 and rdq(arr + (slot - 1) * 16)
    if not t then return {} end
    local base = rdq(t + 0x18)
    local okL, l = pcall(memory_read, "byte", t + 4)
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
    task.spawn(function()
        task.wait(PREVIEW_SECONDS)
        for _, s in ipairs(saved) do
            if readLuaString(s[1]) == text then writeLuaString(s[1], s[2]) end
        end
        previewing = false
    end)
    return "Switch weapons (1-4) in the next " .. PREVIEW_SECONDS .. " s to hear it."
end

-- Pictures: downloaded one at a time, newest request first so what's on
-- screen loads before what was scrolled past. The bytes are kept per file;
-- each place a picture is drawn gets its own Image object, so one texture can
-- show on several tiles at once.

local images, imageQueue, imageWorker = {}, {}, false
local imageObjects = {}
local function cachePath(path) return CACHE .. "/" .. path:gsub("[^%w%-_%.]", "_") .. ".dat" end
local function loadImage(path)
    local file = cachePath(path)
    local okHas, has = pcall(isfile, file)
    if okHas and has then
        local okRead, body = pcall(readfile, file)
        if okRead and type(body) == "string" and #body > 8 then return body end
    end
    local ok, body = pcall(fetch, SITE .. path)
    if not ok or body:sub(2, 4) ~= "PNG" then return nil end
    pcall(writefile, file, body)
    return body
end
local function requestImage(path)
    local e = images[path]
    if e then return e end
    e = {state = "queued"}
    images[path] = e
    imageQueue[#imageQueue + 1] = path
    if not imageWorker then
        imageWorker = true
        pcall(makefolder, CACHE)
        task.spawn(function()
            while #imageQueue > 0 and _G.__RivalsGuiSession == guiToken do
                local p = table.remove(imageQueue)
                local ok, data = pcall(loadImage, p)
                images[p].data = ok and data or nil
                images[p].state = images[p].data and "ok" or "failed"
                task.wait()
            end
            imageWorker = false
        end)
    end
    return e
end

-- Drawing: a pool per kind, reused frame to frame; each object only gets a
-- property written when it changed.

local V2, RGB = Vector2.new, Color3.fromRGB
local FONT = (Drawing.Fonts and (Drawing.Fonts.System or Drawing.Fonts.UI)) or 1
local FONT_BOLD = (Drawing.Fonts and Drawing.Fonts.SystemBold) or FONT
local C = {
    bg = RGB(15, 16, 21), bar = RGB(19, 20, 27), panel = RGB(22, 24, 31), card = RGB(29, 31, 40),
    cardHover = RGB(37, 40, 52), line = RGB(44, 47, 60), text = RGB(226, 229, 236), dim = RGB(138, 144, 160),
    faint = RGB(90, 96, 112), good = RGB(80, 210, 120), bad = RGB(240, 90, 90),
}
-- The accent and the shades made from it; picked in Settings.
local ACCENTS = {"568cff", "8b5cf6", "ec4899", "ef4444", "f97316", "eab308", "22c55e", "14b8a6", "06b6d4", "e5e7eb"}
local function applyAccent(hex)
    local ok, c = pcall(Color3.fromHex, "#" .. tostring(hex))
    if not ok or not c then c = Color3.fromHex("#" .. DEFAULT_ACCENT) end
    C.accent = c
    C.accentDim = Color3.new(c.R * 0.42, c.G * 0.42, c.B * 0.42)
    C.accentHot = Color3.new(math.min(1, c.R + 0.08), math.min(1, c.G + 0.08), math.min(1, c.B + 0.08))
    -- Dark text on light accents so labels stay readable.
    local light = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B > 0.62
    C.onAccent = light and RGB(20, 22, 28) or RGB(255, 255, 255)
end
applyAccent(state.accent)
-- Opacity of everything drawn this frame; the open/close animation lowers it.
local Fade = 1
local Pool, Cache, Used = {sq = {}, tx = {}, ln = {}, ci = {}}, {sq = {}, tx = {}, ln = {}, ci = {}}, {sq = 0, tx = 0, ln = 0, ci = 0}
local CLASS = {sq = "Square", tx = "Text", ln = "Line", ci = "Circle"}
local shownImages, drawnImages = {}, {}

local function take(kind)
    local i = Used[kind] + 1
    Used[kind] = i
    local obj = Pool[kind][i]
    if not obj then
        obj = Drawing.new(CLASS[kind])
        Pool[kind][i], Cache[kind][i] = obj, {}
        if kind == "tx" then pcall(function() obj.Outline = false end) end
    end
    return obj, Cache[kind][i]
end
local function put(o, c, k, v) if c[k] ~= v then c[k] = v; o[k] = v end end
local function place(o, c, k, x, y)
    if c[k .. "x"] ~= x or c[k .. "y"] ~= y then c[k .. "x"], c[k .. "y"] = x, y; o[k] = V2(x, y) end
end
local function rect(x, y, w, h, color, z, corner, alpha)
    if w <= 0 or h <= 0 then return end
    local o, c = take("sq")
    place(o, c, "Position", x, y) place(o, c, "Size", w, h)
    put(o, c, "Color", color) put(o, c, "Filled", true) put(o, c, "Corner", corner or 0)
    put(o, c, "ZIndex", z or 1) put(o, c, "Transparency", (alpha or 1) * Fade) put(o, c, "Visible", true)
end
local function border(x, y, w, h, color, z, corner, thick)
    local o, c = take("sq")
    place(o, c, "Position", x, y) place(o, c, "Size", w, h)
    put(o, c, "Color", color) put(o, c, "Filled", false) put(o, c, "Thickness", thick or 1)
    put(o, c, "Corner", corner or 0) put(o, c, "ZIndex", z or 1) put(o, c, "Transparency", Fade) put(o, c, "Visible", true)
end
-- Width of a string as Matcha lays it out (its TextBounds), remembered per
-- string; an estimate if that isn't available.
local measurer, widths, widthCount = nil, {}, 0
local function textWidth(s, size, bold)
    s = tostring(s)
    local key = s .. "\1" .. size .. (bold and "b" or "")
    local known = widths[key]
    if known then return known end
    local ok, w = pcall(function()
        measurer = measurer or Drawing.new("Text")
        measurer.Visible = false
        measurer.Size, measurer.Font, measurer.Text = size, bold and FONT_BOLD or FONT, s
        return measurer.TextBounds.X
    end)
    w = (ok and type(w) == "number" and w > 0) and w or #s * size * 0.58
    if widthCount > 4000 then widths, widthCount = {}, 0 end
    widths[key], widthCount = w, widthCount + 1
    return w
end
local function fitText(s, room, size, bold)
    s = tostring(s)
    if textWidth(s, size, bold) <= room then return s end
    local lo, hi = 0, #s
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if textWidth(s:sub(1, mid) .. "..", size, bold) <= room then lo = mid else hi = mid - 1 end
    end
    return s:sub(1, math.max(1, lo)) .. ".."
end
local function text(s, x, y, color, size, z, bold, center)
    s = tostring(s)
    if s == "" then return end
    local o, c = take("tx")
    size = size or 13
    put(o, c, "Text", s) put(o, c, "Size", size) put(o, c, "Font", bold and FONT_BOLD or FONT)
    -- Matcha draws text higher than its position by about a third of the size;
    -- this puts the letters where the layout expects them.
    put(o, c, "Center", center and true or false) place(o, c, "Position", math.floor(x + 0.5), math.floor(y + size * 0.3 + 0.5))
    put(o, c, "Color", color) put(o, c, "ZIndex", z or 5) put(o, c, "Transparency", Fade) put(o, c, "Visible", true)
end
local function line(x1, y1, x2, y2, color, z, thick)
    local o, c = take("ln")
    place(o, c, "From", x1, y1) place(o, c, "To", x2, y2)
    put(o, c, "Color", color) put(o, c, "Thickness", thick or 1) put(o, c, "ZIndex", z or 5)
    put(o, c, "Transparency", Fade) put(o, c, "Visible", true)
end
local function circle(x, y, r, color, z, filled, thick)
    local o, c = take("ci")
    place(o, c, "Position", x, y) put(o, c, "Radius", r) put(o, c, "Color", color)
    put(o, c, "Filled", filled and true or false) put(o, c, "Thickness", thick or 1)
    pcall(put, o, c, "NumSides", 32) put(o, c, "ZIndex", z or 5) put(o, c, "Transparency", Fade) put(o, c, "Visible", true)
end
-- A picture from the site; false while it downloads. `key` names the spot it
-- is drawn in when the same file shows more than once.
local function picture(path, x, y, w, h, z, key, alpha)
    if not path then return false end
    local e = requestImage(path)
    if e.state ~= "ok" then return false end
    key = key or path
    local slot = imageObjects[key]
    if not slot or slot.path ~= path then
        if slot then pcall(function() slot.obj:Remove() end) end
        local obj = Drawing.new("Image")
        obj.Visible = false
        obj.Data = e.data
        slot = {obj = obj, cache = {}, path = path}
        imageObjects[key] = slot
    end
    local o, c = slot.obj, slot.cache
    place(o, c, "Position", x, y) place(o, c, "Size", w, h)
    put(o, c, "ZIndex", z or 4) put(o, c, "Transparency", (alpha or 1) * Fade)
    if not c.Visible then c.Visible = true; o.Visible = true end
    drawnImages[key] = slot
    return true
end
local function beginFrame()
    for k in pairs(Used) do Used[k] = 0 end
    drawnImages = {}
end
local function endFrame()
    for kind, list in pairs(Pool) do
        for i = Used[kind] + 1, #list do
            local c = Cache[kind][i]
            if c and c.Visible ~= false then c.Visible = false; list[i].Visible = false end
        end
    end
    for key, slot in pairs(shownImages) do
        if not drawnImages[key] then slot.cache.Visible = false; slot.obj.Visible = false end
    end
    shownImages = drawnImages
end
local function wipe()
    for kind, list in pairs(Pool) do
        for _, o in ipairs(list) do pcall(function() o.Visible = false; o:Remove() end) end
        Pool[kind], Cache[kind], Used[kind] = {}, {}, 0
    end
    for _, slot in pairs(imageObjects) do
        pcall(function() slot.obj.Visible = false; slot.obj:Remove() end)
    end
    imageObjects, images = {}, {}
    if measurer then pcall(function() measurer:Remove() end) measurer = nil end
end

-- Input: the mouse and the keyboard are polled every frame. A click counts on
-- release, so pressing and dragging a list scrolls it instead.

local mouse, mouseAt = nil, 0
local M = {x = 0, y = 0, down = false, press = false, release = false, px = 0, py = 0, dragged = false, took = false}
local keyState = {}
local function keyHit(vk)
    local ok, down = pcall(iskeypressed, vk)
    down = ok and down == true
    local was = keyState[vk]
    keyState[vk] = down
    return down and not was, down
end
local function readInput()
    -- The player (and its mouse) is a new object after a server change.
    if not mouse or tick() - mouseAt > 2 then
        mouseAt = tick()
        pcall(function() mouse = game:GetService("Players").LocalPlayer:GetMouse() end)
    end
    local ok = pcall(function() M.x, M.y = mouse.X, mouse.Y + (state.mouseOffset or 0) end)
    if not ok then M.x, M.y = -1, -1 end
    local active = not isrbxactive or isrbxactive() ~= false
    local down = active and ismouse1pressed() == true
    M.press = down and not M.down
    M.release = M.down and not down
    M.down = down
    if M.press then M.px, M.py, M.dragged = M.x, M.y, false end
    if M.down and (math.abs(M.x - M.px) > 5 or math.abs(M.y - M.py) > 5) then M.dragged = true end
    M.took = false
end
local function over(x, y, w, h) return M.x >= x and M.x < x + w and M.y >= y and M.y < y + h end
local function clicked(x, y, w, h)
    if M.took or not M.release or M.dragged then return false end
    if over(x, y, w, h) and M.px >= x and M.px < x + w and M.py >= y and M.py < y + h then
        M.took = true
        return true
    end
    return false
end

-- Text boxes: while one is focused, typing goes to it and not to the game.
local TYPED = {}
for i = 0, 25 do TYPED[0x41 + i] = {string.char(97 + i), string.char(65 + i)} end
for i = 0, 9 do TYPED[0x30 + i] = {tostring(i), (")!@#$%^&*("):sub(i + 1, i + 1)} end
TYPED[0x20] = {" ", " "} TYPED[0xBD] = {"-", "_"} TYPED[0xBE] = {".", ">"} TYPED[0xDE] = {"'", "\""}
TYPED[0xBF] = {"/", "?"} TYPED[0xBA] = {";", ":"}
local focus, backspaceAt = nil, 0
local function typeInto(id)
    local value = state.inputs[id] or ""
    local shift = select(2, keyHit(0x10))
    for vk, chars in pairs(TYPED) do
        if keyHit(vk) then value = value .. chars[shift and 2 or 1] end
    end
    local bsHit, bsDown = keyHit(0x08)
    if bsHit then value = value:sub(1, -2); backspaceAt = tick() + 0.45
    elseif bsDown and tick() > backspaceAt then value = value:sub(1, -2); backspaceAt = tick() + 0.04 end
    if keyHit(0x0D) or keyHit(0x1B) then focus = nil end
    state.inputs[id] = value
end
local function textbox(id, x, y, w, h, placeholder)
    local focused = focus == id
    rect(x, y, w, h, focused and C.cardHover or C.card, 3, 5)
    border(x, y, w, h, focused and C.accent or C.line, 3, 5)
    local value = state.inputs[id] or ""
    local blink = focused and (tick() % 1 < 0.5) and "|" or ""
    if value == "" and not focused then
        text(placeholder, x + w / 2, y + (h - 13) / 2, C.faint, 13, 5, false, true)
    else
        text(fitText(value, w - 20, 13) .. blink, x + 9, y + (h - 13) / 2, C.text, 13, 5)
    end
    if clicked(x, y, w, h) then focus = id end
    return value
end
local function button(x, y, w, h, label, primary, disabled)
    local hot = not disabled and over(x, y, w, h)
    rect(x, y, w, h, primary and (hot and C.accentHot or C.accent) or (hot and C.cardHover or C.card), 3, 5)
    if not primary then border(x, y, w, h, C.line, 3, 5) end
    text(label, x + w / 2, y + (h - 13) / 2, disabled and C.faint or (primary and C.onAccent or C.text), 13, 5, primary, true)
    return not disabled and clicked(x, y, w, h)
end
-- A row of choices; returns the index clicked.
local function segmented(x, y, w, h, labels, selected)
    rect(x, y, w, h, C.panel, 3, 6)
    local each, picked = w / #labels, nil
    for i, label in ipairs(labels) do
        local bx = x + (i - 1) * each
        if i == selected then
            rect(bx + 2, y + 2, each - 4, h - 4, C.card, 3, 5)
            line(bx + each * 0.3, y + h - 3, bx + each * 0.7, y + h - 3, C.accent, 5, 2)
        end
        text(label, bx + each / 2, y + (h - 13) / 2, i == selected and C.text or C.dim, 13, 5, i == selected, true)
        if clicked(bx, y, each, h) then picked = i end
    end
    return picked
end

-- Scrolling in whole rows: drag the list, drag its bar, or PageUp/PageDown and
-- the arrow keys while pointing at it.
local function scroller(id, x, y, w, h, total, visible)
    local maxFirst = math.max(0, total - visible)
    local s = state.scroll[id] or {first = 0}
    state.scroll[id] = s
    if over(x, y, w, h) then
        if keyHit(0x22) or keyHit(0x28) then s.first = s.first + (keyState[0x22] and visible or 1) end
        if keyHit(0x21) or keyHit(0x26) then s.first = s.first - (keyState[0x21] and visible or 1) end
    end
    if M.press and over(x, y, w, h) then s.grab, s.grabFirst = M.y, s.first end
    if not M.down then s.grab = nil end
    if s.grab and M.dragged then
        local rowH = h / math.max(1, visible)
        s.first = s.grabFirst - math.floor((M.y - s.grab) / rowH + 0.5)
    end
    s.first = math.max(0, math.min(maxFirst, s.first))
    -- The bar: drag the thumb, or click above or below it to move a page.
    -- (Matcha can't read the mouse wheel.)
    if maxFirst > 0 then
        local bx, bw = x + w + 4, 8
        local barH = math.max(28, h * visible / total)
        local barY = y + (h - barH) * s.first / maxFirst
        local onBar = over(bx - 2, y, bw + 4, h)
        rect(bx, y, bw, h, C.card, 3, 4)
        if M.press and onBar then
            if M.y >= barY and M.y <= barY + barH then
                s.bar = M.y - barY
            else
                s.first = s.first + (M.y < barY and -visible or visible)
                s.grab = nil
            end
            M.dragged = true
        end
        if not M.down then s.bar = nil end
        if s.bar then
            s.first = math.floor((M.y - s.bar - y) / math.max(1, h - barH) * maxFirst + 0.5)
            s.grab = nil
            M.dragged = true
        end
        s.first = math.max(0, math.min(maxFirst, s.first))
        barY = y + (h - barH) * s.first / maxFirst
        rect(bx, barY, bw, barH, s.bar and C.accent or (onBar and C.dim or C.faint), 4, 4)
    end
    return s.first
end
local function resetScroll(id) state.scroll[id] = {first = 0} end

-- Pieces of the window

local function matches(q, name) return q == "" or name:lower():find(q, 1, true) ~= nil end
local function query(id) return trim(state.inputs[id] or ""):lower() end

-- A list on the left: rows of names, one picked, a dot where something is set.
local function sideList(id, x, y, w, h, items, selected, marked)
    local rowH = 30
    local visible = math.floor(h / rowH)
    local first = scroller(id, x, y, w, h, #items, visible)
    local picked
    for i = first + 1, math.min(#items, first + visible) do
        local name = items[i]
        local ry = y + (i - first - 1) * rowH
        local hot = over(x, ry, w, rowH - 4)
        if name == selected then
            rect(x, ry, w, rowH - 4, C.card, 3, 5)
            rect(x, ry + 6, 2, rowH - 16, C.accent, 4, 1)
        elseif hot then
            rect(x, ry, w, rowH - 4, C.panel, 3, 5)
        end
        text(fitText(name, w - 30, 13), x + 12, ry + 6, name == selected and C.text or C.dim, 13, 5)
        if marked and marked(name) then circle(x + w - 12, ry + (rowH - 4) / 2, 3, C.good, 5, true) end
        if clicked(x, ry, w, rowH - 4) then picked = name end
    end
    if #items == 0 then text("Nothing matches.", x + 8, y + 6, C.faint, 13, 5) end
    return picked
end

-- A grid of tiles with pictures. Each item: {name, src, rarity, colors, none}.
local TILE_W, TILE_H = 104, 118
local function tileGrid(id, x, y, w, h, items, isSelected, badge)
    local cols = math.max(1, math.floor((w + 8) / (TILE_W + 8)))
    local rowsVisible = math.max(1, math.floor((h + 8) / (TILE_H + 8)))
    local rows = math.ceil(#items / cols)
    local first = scroller(id, x, y, w, h, rows, rowsVisible)
    local gap = cols > 1 and (w - cols * TILE_W) / (cols - 1) or 0
    local picked
    for r = first, math.min(rows - 1, first + rowsVisible - 1) do
        for col = 0, cols - 1 do
            local item = items[r * cols + col + 1]
            if item then
                local tx = x + col * (TILE_W + gap)
                local ty = y + (r - first) * (TILE_H + 8)
                local sel = isSelected(item)
                local hot = over(tx, ty, TILE_W, TILE_H)
                rect(tx, ty, TILE_W, TILE_H, hot and C.cardHover or C.card, 3, 6)
                if sel then border(tx, ty, TILE_W, TILE_H, C.accent, 6, 6, 2) end
                local ix, iy, is = tx + 14, ty + 8, TILE_W - 28
                if item.none then
                    circle(tx + TILE_W / 2, iy + is / 2, 18, C.dim, 5, false, 2)
                    line(tx + TILE_W / 2 - 12, iy + is / 2 + 12, tx + TILE_W / 2 + 12, iy + is / 2 - 12, C.dim, 5, 2)
                elseif item.src and picture(item.src, ix, iy, is, is, 4) then
                    -- The picture; the lines below draw stand-ins while it loads.
                elseif item.colors and #item.colors > 0 then
                    -- Like the game's wrap icon: the first part is the sheet,
                    -- the second the band along the bottom, the third a corner.
                    local cols, texs = item.colors, item.textures or {}
                    local sheetH = math.floor(is * 0.68)
                    local areas = {
                        {ix, iy, is, sheetH},
                        {ix, iy + sheetH, is, is - sheetH},
                        {ix + is - 22, iy + sheetH - 22, 22, 22},
                    }
                    for k = 1, math.max(2, #cols) do
                        local a = areas[k]
                        local col3 = cols[k] or cols[1]
                        if a and col3 then
                            rect(a[1], a[2], a[3], a[4], col3, 4, 0)
                            local tex = texs[k] or (cols[k] == nil and texs[1]) or nil
                            if tex and not item.src then picture(tex, a[1], a[2], a[3], a[4], 5, "wrap:" .. item.name .. ":" .. k, 0.6) end
                        end
                    end
                    border(ix, iy, is, is, C.line, 5, 0)
                else
                    text(item.src and "..." or "?", tx + TILE_W / 2, iy + is / 2 - 7, C.faint, 14, 5, false, true)
                end
                text(fitText(item.name, TILE_W - 10, 12), tx + TILE_W / 2, ty + TILE_H - 26, sel and C.text or C.dim, 12, 5, sel, true)
                local rc = item.rarity and RARITY_COLORS[item.rarity]
                if rc then rect(tx + 30, ty + TILE_H - 6, TILE_W - 60, 2, rc, 5, 1) end
                local mark = badge and badge(item)
                if mark then
                    rect(tx + TILE_W - 24, ty + 6, 18, 18, C.accent, 5, 9)
                    text(mark, tx + TILE_W - 15, ty + 8, C.onAccent, 12, 6, true, true)
                end
                if clicked(tx, ty, TILE_W, TILE_H) then picked = item end
            end
        end
    end
    if #items == 0 then text("Nothing matches.", x + 4, y + 6, C.faint, 13, 5) end
    return picked
end

local function weaponEntry(name)
    for _, w in ipairs(catalog.weapons) do if w.name == name then return w end end
end
-- ownedFor: a weapon name, to list only the skins you own for it.
local function skinItems(w, exclude, searchId, withNone, ownedFor)
    local out = {}
    if withNone then out[1] = {name = "None", none = true} end
    local q = query(searchId)
    local mine = ownedFor and ownedOnly()
    for _, skin in ipairs(w and w.skins or {}) do
        if skin ~= exclude and matches(q, skin)
            and (not mine or owns(skin, ownedFor) or (state.swaps[ownedFor] or {})[skin] ~= nil) then
            local info = w.info[skin] or {}
            out[#out + 1] = {name = skin, src = info.src, rarity = info.rarity}
        end
    end
    return out
end
local function swapCount(weapon)
    local n = 0
    for _ in pairs(state.swaps[weapon] or {}) do n = n + 1 end
    return n
end

-- Tabs

-- The main page: every weapon, grouped by slot like the game's loadout
-- (Primary, Secondary, Melee, Utility; A-Z inside a slot). Each tile shows
-- what the weapon looks like now.
local SLOT_ORDER = {"Primary", "Secondary", "Melee", "Utility", "Other"}
local function drawWeaponMain(x, y, w, h)
    rect(x, y, w, h, C.panel, 2, 8)
    text("Weapons", x + 16, y + 14, C.text, 15, 5, true)
    local setCount = 0
    for _, wpn in ipairs(catalog.weapons) do
        if (state.values.skins or {})[wpn.name] or swapCount(wpn.name) > 0 then setCount = setCount + 1 end
    end
    text(setCount .. " changed  -  pick one to choose its skin", x + 16, y + 36, C.dim, 12, 5)
    textbox("weaponSearch", x + w - 252, y + 14, 240, 28, "Search weapons or skins...")
    if not catalog.loaded then text("Loading lists...", x + 16, y + 70, C.dim, 14, 5) return end

    -- Slot tabs: All, then each slot that has a weapon.
    local tabs = {"All"}
    for _, slot in ipairs(SLOT_ORDER) do
        for _, wpn in ipairs(catalog.weapons) do
            if (wpn.slot or "Other") == slot then tabs[#tabs + 1] = slot break end
        end
    end
    local tabIndex = 1
    for i, t in ipairs(tabs) do if t == state.slotTab then tabIndex = i end end
    local pickedTab = segmented(x + 12, y + 54, w - 24, 32, tabs, tabIndex)
    if pickedTab and tabs[pickedTab] ~= tabs[tabIndex] then
        state.slotTab = tabs[pickedTab]
        resetScroll("weaponMain")
    end
    local only = tabs[pickedTab or tabIndex] ~= "All" and tabs[pickedTab or tabIndex] or nil

    -- Rows: a header per slot, then its tiles.
    local q = query("weaponSearch")
    local gx, gw, gy, gh = x + 12, w - 30, y + 96, h - 104
    local cols = math.max(1, math.floor((gw + 8) / (TILE_W + 8)))
    local gap = cols > 1 and (gw - cols * TILE_W) / (cols - 1) or 0
    local rows = {}
    for _, slot in ipairs(only and {only} or SLOT_ORDER) do
        local list = {}
        for _, wpn in ipairs(catalog.weapons) do
            if (wpn.slot or "Other") == slot then
                local hit = matches(q, wpn.name)
                if not hit then
                    for _, skin in ipairs(wpn.skins) do if matches(q, skin) then hit = true break end end
                end
                if hit then list[#list + 1] = wpn end
            end
        end
        if #list > 0 then
            rows[#rows + 1] = {header = slot, count = #list}
            for i = 1, #list, cols do
                local row = {}
                for k = i, math.min(#list, i + cols - 1) do row[#row + 1] = list[k] end
                rows[#rows + 1] = {tiles = row}
            end
        end
    end
    local HEADER_H, ROW_H = 30, TILE_H + 8
    local function height(row) return row.header and HEADER_H or ROW_H end
    -- How many rows fit at the end decides how far the list scrolls.
    local fitEnd, used = 0, 0
    for i = #rows, 1, -1 do
        used = used + height(rows[i])
        if used > gh then break end
        fitEnd = fitEnd + 1
    end
    local first = scroller("weaponMain", gx, gy, gw, gh, #rows, math.max(1, fitEnd))
    local cy = gy
    for i = first + 1, #rows do
        local row = rows[i]
        if cy + height(row) > gy + gh + 1 then break end
        if row.header then
            text(row.header:upper(), gx + 2, cy + 10, C.faint, 11, 5, true)
            text(tostring(row.count), gx + 2 + textWidth(row.header:upper(), 11, true) + 14, cy + 10, C.faint, 11, 5)
            line(gx + 110, cy + 16, gx + gw, cy + 16, C.line, 3, 1)
        else
            for col, wpn in ipairs(row.tiles) do
                local tx = gx + (col - 1) * (TILE_W + gap)
                local current = (state.values.skins or {})[wpn.name]
                local swaps = swapCount(wpn.name)
                local hot = over(tx, cy, TILE_W, TILE_H)
                rect(tx, cy, TILE_W, TILE_H, hot and C.cardHover or C.card, 3, 6)
                if current or swaps > 0 then border(tx, cy, TILE_W, TILE_H, C.accentDim, 6, 6, 2) end
                local info = current and wpn.info[current]
                local src = (info and info.src) or wpn.icon
                local is = TILE_W - 28
                if not picture(src, tx + 14, cy + 8, is, is, 4) then
                    text(src and "..." or "?", tx + TILE_W / 2, cy + 8 + is / 2 - 7, C.faint, 14, 5, false, true)
                end
                text(fitText(wpn.name, TILE_W - 10, 12), tx + TILE_W / 2, cy + TILE_H - 32, C.text, 12, 5, true, true)
                local sub = current or (swaps > 0 and (swaps .. " swap" .. (swaps == 1 and "" or "s")) or "Default")
                text(fitText(sub, TILE_W - 10, 11), tx + TILE_W / 2, cy + TILE_H - 17,
                    (current or swaps > 0) and C.accent or C.faint, 11, 5, false, true)
                if clicked(tx, cy, TILE_W, TILE_H) then
                    state.weapon, state.skinsView = wpn.name, "weapon"
                    state.swapStep = state.swapOwned[wpn.name] and 2 or 1
                    state.inputs.skinSearch = ""
                    resetScroll("skinGrid")
                end
            end
        end
        cy = cy + height(row)
    end
    if #rows == 0 then text("No weapon or skin matches.", gx + 4, gy + 6, C.faint, 13, 5) end
end

local function drawSkins(x, y, w, h)
    local wpn = state.skinsView == "weapon" and weaponEntry(state.weapon)
    if not wpn then
        state.skinsView = "main"
        return drawWeaponMain(x, y, w, h)
    end

    -- One weapon's page
    local rx, rw = x, w
    rect(rx, y, rw, h, C.panel, 2, 8)
    local weapon = wpn.name
    if button(rx + 12, y + 18, 72, 32, "< Back") or keyHit(0x1B) then
        state.skinsView = "main"
        focus = nil
        return
    end
    rect(rx + 94, y + 12, 44, 44, C.card, 3, 6)
    picture(wpn.icon, rx + 96, y + 14, 40, 40, 4)
    text(weapon, rx + 148, y + 14, C.text, 15, 5, true)
    local current = (state.values.skins or {})[weapon]
    local sub = state.mode == "Switch" and ("Switch  -  " .. (current or "Default"))
        or ("Swap  -  " .. swapCount(weapon) .. " set")
    text(sub, rx + 148, y + 36, C.dim, 12, 5)
    -- Your arms in first person, for this weapon.
    if button(rx + rw - 366, y + 16, 142, 32, handsHidden(weapon) and "Hands: hidden" or "Hands: shown") then
        toggleHands(weapon)
    end
    local modeAt = segmented(rx + rw - 212, y + 16, 200, 32, {"Switch", "Swap"}, state.mode == "Switch" and 1 or 2)
    if modeAt then state.mode = modeAt == 1 and "Switch" or "Swap"; resetScroll("skinGrid") end

    local gy = y + 68
    if state.mode == "Switch" then
        text("Pick what the default " .. weapon .. " looks like. Works without owning any skin.", rx + 14, gy, C.faint, 12, 5)
        gy = gy + 22
    else
        -- 1: the skin you own, 2: what it looks like. Set pairs below.
        local owned = state.swapOwned[weapon]
        local target = owned and (state.swaps[weapon] or {})[owned]
        local step = segmented(rx + 12, gy, rw - 24, 32,
            {"1  You own: " .. fitText(owned or "pick", 150, 13), "2  Looks like: " .. fitText(target or (owned and "pick" or "-"), 150, 13)},
            state.swapStep)
        if step == 1 or (step == 2 and owned) then state.swapStep = step; resetScroll("skinGrid") end
        gy = gy + 40
        local cx = rx + 12
        for o, t in pairs(state.swaps[weapon] or {}) do
            local label = fitText(o .. "  >  " .. t, 220, 12)
            local cw = textWidth(label, 12) + 34
            if cx + cw > rx + rw - 12 then break end
            rect(cx, gy, cw, 22, C.accentDim, 3, 11)
            text(label, cx + 10, gy + 4, C.text, 12, 5)
            text("x", cx + cw - 14, gy + 3, C.dim, 13, 5, true)
            if clicked(cx + cw - 22, gy, 22, 22) then
                setSwap(weapon, o, nil)
            elseif clicked(cx, gy, cw - 22, 22) then
                state.swapOwned[weapon], state.swapStep = o, 2
            end
            cx = cx + cw + 6
        end
        gy = gy + 28
    end
    textbox("skinSearch", rx + 12, gy, rw - 24, 28, "Search skins...")
    gy = gy + 38
    local gridH = y + h - gy - 30
    local items
    if state.mode == "Switch" then
        items = skinItems(wpn, nil, "skinSearch", true)
        local hit = tileGrid("skinGrid", rx + 12, gy, rw - 30, gridH, items, function(it)
            if it.none then return current == nil end
            return it.name == current
        end)
        if hit and hit.none then
            setMapping("skins", weapon, nil)
        elseif hit then
            guarded(function() setMapping("skins", weapon, hit.name) end, hit.name)
        end
    elseif state.swapStep == 1 or not state.swapOwned[weapon] then
        items = skinItems(wpn, nil, "skinSearch", false, weapon)
        if #items == 0 and ownedOnly() and query("skinSearch") == "" then
            text("You own no skins for this weapon. Settings > Lists shows every skin.", rx + 16, gy + 30, C.dim, 12, 5)
        end
        local hit = tileGrid("skinGrid", rx + 12, gy, rw - 30, gridH, items, function(it)
            return it.name == state.swapOwned[weapon]
        end, function(it) return (state.swaps[weapon] or {})[it.name] and ">" or nil end)
        if hit then state.swapOwned[weapon], state.swapStep = hit.name, 2; resetScroll("skinGrid") end
    else
        local owned = state.swapOwned[weapon]
        local target = (state.swaps[weapon] or {})[owned]
        items = skinItems(wpn, owned, "skinSearch", true)
        local hit = tileGrid("skinGrid", rx + 12, gy, rw - 30, gridH, items, function(it)
            if it.none then return target == nil end
            return it.name == target
        end)
        if hit and hit.none then
            setSwap(weapon, owned, nil)
        elseif hit then
            guarded(function() setSwap(weapon, owned, hit.name) end, hit.name)
        end
    end
    local count = #items - ((items[1] and items[1].none) and 1 or 0)
    text(count .. " skin(s) for " .. weapon, rx + 14, y + h - 22, C.faint, 12, 5)
end

local COS_KINDS = {
    {key = "wraps", label = "Wraps", section = "wraps"},
    {key = "finishers", label = "Finishers", section = "finishers"},
    {key = "charms", label = "Charms", section = "charms"},
}
local function drawCosmetics(x, y, w, h)
    local kindIndex = 1
    for i, k in ipairs(COS_KINDS) do if k.key == state.cosKind then kindIndex = i end end
    local kind = COS_KINDS[kindIndex]
    local list = catalog[kind.key] or {}
    local values = state.values[kind.section] or {}

    local lw = 210
    rect(x, y, lw, h, C.panel, 2, 8)
    local pickedKind = segmented(x + 8, y + 8, lw - 16, 30, {"Wraps", "Finishers", "Charms"}, kindIndex)
    if pickedKind and pickedKind ~= kindIndex then
        state.cosKind = COS_KINDS[pickedKind].key
        resetScroll("cosOwned") resetScroll("cosGrid")
        return
    end
    text("YOU OWN", x + 12, y + 48, C.faint, 11, 5, true)
    local sid = "cosOwnSearch" .. kind.key
    textbox(sid, x + 10, y + 66, lw - 20, 28, "Search...")
    local names, q = {}, query(sid)
    for _, item in ipairs(list) do if matches(q, item.name) and (values[item.name] ~= nil or not ownedOnly() or owns(item.name)) then names[#names + 1] = item.name end end
    local owned = state.owned[kind.key]
    local picked = sideList("cosOwned", x + 8, y + 102, lw - 22, h - 110, names, owned, function(n) return values[n] ~= nil end)
    if picked then state.owned[kind.key] = picked; resetScroll("cosGrid") end
    owned = state.owned[kind.key]

    local rx, rw = x + lw + 12, w - lw - 12
    rect(rx, y, rw, h, C.panel, 2, 8)
    if not owned then
        text("Pick one you own on the left, then what it should look like.", rx + 16, y + 18, C.dim, 13, 5)
        text("Saved as Owned=Target: the game shows the target wherever the owned one would be.", rx + 16, y + 40, C.faint, 12, 5)
        return
    end
    local target = values[owned]
    local season = target and target:match("^(Season %d+)%s")
    text(owned, rx + 16, y + 14, C.text, 15, 5, true)
    text("looks like  " .. (target or "itself"), rx + 16, y + 36, C.dim, 12, 5)
    local gy = y + 62
    if kind.key == "charms" and season then
        -- Season charms hold every rank; one has to be picked.
        local current = target:match("^Season %d+%s+(.+)$") or RANKS[1]
        local ri = 1
        for i, r in ipairs(RANKS) do if r == current then ri = i end end
        text("Rank", rx + 16, gy + 7, C.dim, 13, 5)
        if button(rx + 60, gy, 30, 28, "<") then
            ri = math.max(1, ri - 1); state.rank[owned] = RANKS[ri]; setMapping("charms", owned, season .. " " .. RANKS[ri])
        end
        text(RANKS[ri], rx + 150, gy + 7, C.text, 13, 5, true, true)
        if button(rx + 210, gy, 30, 28, ">") then
            ri = math.min(#RANKS, ri + 1); state.rank[owned] = RANKS[ri]; setMapping("charms", owned, season .. " " .. RANKS[ri])
        end
        gy = gy + 38
    end
    local tsid = "cosTargetSearch" .. kind.key
    textbox(tsid, rx + 12, gy, rw - 24, 28, "Search looks like...")
    gy = gy + 38
    local items, tq = {{name = "None", none = true}}, query(tsid)
    for _, item in ipairs(list) do
        if item.name ~= owned and matches(tq, item.name) then items[#items + 1] = item end
    end
    local hit = tileGrid("cosGrid", rx + 12, gy, rw - 30, y + h - gy - 30, items, function(it)
        if it.none then return target == nil end
        return it.name == target or (season ~= nil and it.name == season)
    end)
    if hit then
        if hit.none then
            setMapping(kind.section, owned, nil)
        elseif kind.key == "charms" and hit.name:match("^Season %d+$") then
            guarded(function() setMapping("charms", owned, hit.name .. " " .. (state.rank[owned] or RANKS[1])) end, hit.name)
        else
            guarded(function() setMapping(kind.section, owned, hit.name) end, hit.name)
        end
    end
    local set = 0
    for _ in pairs(values) do set = set + 1 end
    text(set .. " " .. kind.label:lower() .. " set  -  " .. #list .. " in the list", rx + 14, y + h - 22, C.faint, 12, 5)
end

-- Every sky in one grid (the groups only existed because Matcha's own menu
-- couldn't scroll a dropdown): the game's skies first, then the uploaded ones.
local function drawVisuals(x, y, w, h)
    local skyNow = ((state.values.skybox or {}).Preset or ""):lower()
    local rx, rw = x, w
    rect(rx, y, rw, h, C.panel, 2, 8)
    text("Skybox", rx + 16, y + 14, C.text, 15, 5, true)
    text(skyNow ~= "" and ("Now: " .. skyNow .. " (next map load)") or "Now: the game's own sky",
        rx + 16, y + 36, C.dim, 12, 5)
    local lightNow = ((state.values.lighting or {}).Preset or ""):lower()
    local li = lightNow == "dark" and 2 or (lightNow == "match" and 3 or 1)
    text("Lighting", rx + rw - 290, y + 22, C.dim, 12, 5)
    local l = segmented(rx + rw - 232, y + 14, 220, 30, {"Normal", "Dark", "Match sky"}, li)
    if l then setMapping("lighting", "Preset", ({false, "dark", "match"})[l] or nil) end

    textbox("skySearch", rx + 12, y + 56, rw - 24, 28, "Search skies...")
    local q = query("skySearch")
    local items = {}
    if q == "" then items[1] = {name = "Off", none = true} end
    for _, g in ipairs(SKY_GROUPS) do
        for _, s in ipairs(g.skies) do
            if matches(q, s) then
                local face = catalog.skyFaces[s]
                items[#items + 1] = {name = s, src = face and ("assets/images/skies/" .. face .. ".png") or nil,
                    colors = (s == "gray" and {RGB(128, 128, 128)}) or (s == "black" and {RGB(8, 8, 10)})
                        or (s == "classic" and {RGB(116, 160, 214), RGB(186, 208, 236)}) or nil}
            end
        end
    end
    local hit = tileGrid("skyGrid", rx + 12, y + 94, rw - 30, h - 104, items, function(it)
        if it.none then return skyNow == "" end
        return it.name == skyNow
    end)
    if hit then
        -- Per-face ids from the site would win over the preset; drop them.
        for _, key in ipairs({"All", "BK", "DN", "FT", "LF", "RT", "UP"}) do setMapping("skybox", key, nil) end
        setMapping("skybox", "Preset", (not hit.none) and hit.name or nil)
    end
end

-- Tracers: the colour of your shots, for every gun or one gun at a time,
-- saved as the [Tracers] section. The game draws them, so they don't lag.
local TRACER_COLORS = {
    {"Red", "ff2d2d"}, {"Orange", "ff7a00"}, {"Gold", "ffc400"}, {"Yellow", "ffee00"}, {"Lime", "a6ff00"},
    {"Green", "2dff5a"}, {"Mint", "00ffa6"}, {"Cyan", "00e5ff"}, {"Blue", "2d6bff"}, {"Purple", "8a2dff"},
    {"Pink", "ff4fd8"}, {"White", "ffffff"},
}
local function hexColor(hex)
    return RGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end

local function drawTracers(x, y, w, h)
    local values = state.values.tracers or {}
    local lw = 210
    rect(x, y, lw, h, C.panel, 2, 8)
    text("GUNS", x + 12, y + 10, C.faint, 11, 5, true)
    textbox("tracerSearch", x + 10, y + 28, lw - 20, 28, "Search...")
    local names, q = {}, query("tracerSearch")
    if q == "" then names[1] = "All guns" end
    for _, wpn in ipairs(catalog.weapons) do if matches(q, wpn.name) then names[#names + 1] = wpn.name end end
    local picked = sideList("tracerGuns", x + 8, y + 64, lw - 22, h - 72, names, state.tracerGun or "All guns",
        function(n) return values[n == "All guns" and "Color" or n] ~= nil end)
    if picked then state.tracerGun = picked; resetScroll("tracerGrid") end

    local gun = state.tracerGun or "All guns"
    local key = gun == "All guns" and "Color" or gun
    local current = values[key] and tostring(values[key]):lower()
    local rx, rw = x + lw + 12, w - lw - 12
    rect(rx, y, rw, h, C.panel, 2, 8)
    text(gun == "All guns" and "Tracers - every gun" or ("Tracers - " .. gun), rx + 16, y + 14, C.text, 15, 5, true)
    text("Now: " .. (current or (key == "Color" and "the game's own" or "same as All guns")), rx + 16, y + 36, C.dim, 12, 5)

    local items = {{name = key == "Color" and "Game's own" or "Same as all", none = true},
        {name = "Rainbow", value = "rainbow", colors = {RGB(255, 60, 60), RGB(60, 120, 255), RGB(255, 230, 0)}}}
    for _, c in ipairs(TRACER_COLORS) do items[#items + 1] = {name = c[1], value = c[2], colors = {hexColor(c[2])}} end
    local gy = y + 62
    local hit = tileGrid("tracerGrid", rx + 12, gy, rw - 30, h - (gy - y) - 132, items, function(it)
        if it.none then return current == nil end
        return it.value == current
    end)
    if hit then setMapping("tracers", key, hit.value) end

    -- The game draws no tracers for the Energy Pistols; this turns them on.
    local ey = y + h - 122
    local epOn = tostring(values.EnergyPistolsTracers or ""):lower() == "true"
    text("Energy Pistols tracers", rx + 16, ey, C.dim, 13, 5)
    text("Not recommended with 50% speed or under", rx + 16, ey + 16, C.faint, 11, 5)
    local ep = segmented(rx + rw - 152, ey, 140, 28, {"Off", "On"}, epOn and 2 or 1)
    if ep then setMapping("tracers", "EnergyPistolsTracers", ep == 2 and "true" or nil) end

    -- Speed, for every gun: 100% is the game's own, low is slow like the
    -- Keyper. Saved when you let go, so dragging doesn't re-apply every frame.
    local sy = y + h - 84
    local sp = state.tracerSpeed or tonumber(values.Speed) or 100
    text("Speed", rx + 16, sy + 6, C.dim, 13, 5)
    local bx, bw = rx + 72, rw - 250
    local t = (sp - 5) / 195
    rect(bx, sy + 12, bw, 4, C.card, 3, 2)
    rect(bx, sy + 12, math.max(1, bw * t), 4, C.accent, 4, 2)
    circle(bx + bw * t, sy + 14, 7, C.text, 5, true)
    if M.press and over(bx - 8, sy, bw + 16, 28) then state.tracerDrag = true end
    if state.tracerDrag then
        if M.down then
            sp = math.floor((5 + 195 * math.max(0, math.min(1, (M.x - bx) / bw))) / 5 + 0.5) * 5
            state.tracerSpeed = sp
            M.dragged = true
        else
            state.tracerDrag, state.tracerSpeed = nil, nil
            setMapping("tracers", "Speed", sp ~= 100 and tostring(sp) or nil)
        end
    end
    text(sp .. "%" .. (sp <= 25 and "  - slow, like the Keyper" or (sp == 100 and "  - the game's own" or "")),
        bx + bw + 16, sy + 6, C.text, 13, 5)

    local cy = y + h - 42
    textbox("tracerHex", rx + 12, cy, rw - 140, 30, "Any colour, like ff66cc")
    if button(rx + rw - 120, cy, 108, 30, "Use colour") then
        local v = trim(state.inputs.tracerHex or ""):gsub("^#", ""):lower()
        if v:match("^%x%x%x%x%x%x$") then setMapping("tracers", key, v) else state.status = "Colours are 6 hex digits, like ff66cc" end
    end
end

-- Hands: your first-person arms, hidden on every weapon or one at a time,
-- saved as the [NoHands] section. Only you see it.
local function drawHands(x, y, w, h)
    local allOn = tostring((state.values.nohands or {}).All or ""):lower() == "true"
    local lw = 210
    rect(x, y, lw, h, C.panel, 2, 8)
    text("WEAPONS", x + 12, y + 10, C.faint, 11, 5, true)
    textbox("handsSearch", x + 10, y + 28, lw - 20, 28, "Search...")
    local names, q = {}, query("handsSearch")
    if q == "" then names[1] = "Every weapon" end
    for _, wpn in ipairs(catalog.weapons) do if matches(q, wpn.name) then names[#names + 1] = wpn.name end end
    local picked = sideList("handsList", x + 8, y + 64, lw - 22, h - 72, names, state.handsFor or "Every weapon",
        function(n)
            if n == "Every weapon" then return allOn end
            return handsHidden(n)
        end)
    if picked then state.handsFor = picked end

    local who = state.handsFor or "Every weapon"
    local every = who == "Every weapon"
    local hiddenNow = every and allOn or (not every and handsHidden(who))
    local rx, rw = x + lw + 12, w - lw - 12
    rect(rx, y, rw, h, C.panel, 2, 8)
    text("Hands - " .. (every and "every weapon" or who), rx + 16, y + 14, C.text, 15, 5, true)
    text("Now: " .. (hiddenNow and "hidden" or "shown") .. ((not every and allOn) and "  (every weapon is set to hidden)" or ""),
        rx + 16, y + 36, C.dim, 12, 5)
    local p = segmented(rx + 16, y + 64, 260, 32, {"Shown", "Hidden"}, hiddenNow and 2 or 1)
    if p and (p == 2) ~= hiddenNow then
        if every then setMapping("nohands", "All", p == 2 and "true" or nil) else toggleHands(who) end
    end
    text("Your arms in first person are hidden while that weapon is out.", rx + 16, y + 112, C.dim, 12, 5)
    text("The weapon still moves as if held. Only you see it.", rx + 16, y + 132, C.dim, 12, 5)
    text("A green dot in the list marks a weapon whose hands are hidden.", rx + 16, y + 152, C.faint, 12, 5)
    text("Shows from the next Save & Apply.", rx + 16, y + h - 26, C.faint, 12, 5)
end

local function drawSounds(x, y, w, h)
    local lw = 184
    rect(x, y, lw, h, C.panel, 2, 8)
    text("LIBRARY", x + 12, y + 10, C.faint, 11, 5, true)
    local groupNames = {"Basics"}
    for _, g in ipairs(SOUND_LIBRARY) do groupNames[#groupNames + 1] = g.name end
    local picked = sideList("soundGroups", x + 8, y + 30, lw - 22, h - 38, groupNames, groupNames[state.soundGroup])
    if picked then
        for i, n in ipairs(groupNames) do if n == picked then state.soundGroup = i end end
        resetScroll("soundList")
    end

    local rx, rw = x + lw + 12, w - lw - 12
    rect(rx, y, rw, h, C.panel, 2, 8)
    local slotLabels = {}
    for _, s in ipairs(SOUND_SLOTS) do slotLabels[#slotLabels + 1] = s[2] end
    local si = segmented(rx + 12, y + 12, 300, 30, slotLabels, state.soundSlot)
    if si then state.soundSlot = si end
    local key = SOUND_SLOTS[state.soundSlot][1]
    local current = (state.values.sounds or {})[key]
    local currentLow = current and tostring(current):lower()
    if button(rx + rw - 132, y + 12, 120, 30, "Preview") then
        state.status = previewSound(current or DEFAULT_SOUNDS[key])
    end
    text("Now: " .. (current or "game default"), rx + 16, y + 52, C.dim, 12, 5)

    local rows = {}
    if state.soundGroup == 1 then
        rows = {{"Game default", nil}, {"Mute", "none"}}
    else
        for _, s in ipairs(SOUND_LIBRARY[state.soundGroup - 1].sounds) do rows[#rows + 1] = {s[1], s[2]} end
    end
    local ly, lh, rowH = y + 76, h - 76 - 50, 30
    local visible = math.floor(lh / rowH)
    local first = scroller("soundList", rx + 12, ly, rw - 30, lh, #rows, visible)
    for i = first + 1, math.min(#rows, first + visible) do
        local row = rows[i]
        local ry = ly + (i - first - 1) * rowH
        local sel = (row[2] == nil and current == nil) or (row[2] ~= nil and row[2] == currentLow)
        rect(rx + 12, ry, rw - 30, rowH - 4, sel and C.card or (over(rx + 12, ry, rw - 30, rowH - 4) and C.cardHover or C.panel), 3, 5)
        if sel then rect(rx + 12, ry + 6, 2, rowH - 16, C.accent, 4, 1) end
        text(row[1], rx + 24, ry + 6, sel and C.text or C.dim, 13, 5, sel)
        if row[2] then text(row[2], rx + rw - 40 - textWidth(row[2], 12), ry + 7, C.faint, 12, 5) end
        if clicked(rx + 12, ry, rw - 30, rowH - 4) then setMapping("sounds", key, row[2]) end
    end
    local cy = y + h - 42
    textbox("customSound", rx + 12, cy, rw - 140, 30, "Custom audio id")
    if button(rx + rw - 120, cy, 108, 30, "Use id") then
        local v = trim(state.inputs.customSound or "")
        if v ~= "" then setMapping("sounds", key, v) end
    end
end

-- Spoof: your name, level, streak and badges as you see them, saved as the
-- [Spoof] section; the changer shows them from the next Save & Apply. Only you
-- see them, except the device, which the server is told.
local SPOOF_FIELDS = {
    {key = "Name", label = "Display name", hint = "Your display name"},
    {key = "Username", label = "@Username", hint = "Not longer than your real one"},
    {key = "Level", label = "Level", number = true},
    {key = "Streak", label = "Win streak", number = true},
    {key = "ELO", label = "ELO", number = true},
}
local SPOOF_BADGES = {{"Influencer", "Influencer badge"}, {"Employee", "Roblox employee badge"}, {"Trustworthy", "Trustworthy"}}
local DEVICE_CHOICES = {{"Real", nil}, {"PC", "MouseKeyboard"}, {"Mobile", "Touch"}, {"Controller", "Gamepad"}, {"VR", "VR"}}

-- A text box tied to one [Spoof] key: it starts at the saved value and saves
-- when you press Enter or click away.
local function spoofBox(field, x, y, w)
    local id = "spoof_" .. field.key
    local saved = (state.values.spoof or {})[field.key] or ""
    if state.inputs[id] == nil then state.inputs[id] = saved end
    text(field.label, x, y, C.dim, 12, 5)
    textbox(id, x, y + 18, w, 30, field.hint or "Real")
    if focus ~= id then
        local v = trim(state.inputs[id] or "")
        if field.number and v ~= "" and not v:match("^%d+$") then
            state.inputs[id] = saved -- digits only; keep what was there
        elseif v ~= saved then
            setMapping("spoof", field.key, v ~= "" and v or nil)
        end
    end
end

local function drawSpoof(x, y, w, h)
    rect(x, y, w, h, C.panel, 2, 8)
    local cx = x + 20
    text("Spoof", cx, y + 14, C.text, 15, 5, true)
    text("How your name and stats look to you. The server keeps the real ones. Empty = real.", cx, y + 36, C.dim, 12, 5)

    local cy, colW = y + 60, math.floor((w - 60) / 2)
    spoofBox(SPOOF_FIELDS[1], cx, cy, colW)
    spoofBox(SPOOF_FIELDS[2], cx + colW + 20, cy, colW)
    cy = cy + 62
    local third = math.floor((w - 80) / 3)
    for i = 3, 5 do spoofBox(SPOOF_FIELDS[i], cx + (i - 3) * (third + 20), cy, third) end
    cy = cy + 62

    local values = state.values.spoof or {}
    -- The effect on your name: the game's gold (Prime) or purple (Contraband).
    text("Name effect", cx, cy + 8, C.text, 13, 5)
    local effectNow = (values.Effect or ""):lower()
    local ei = (effectNow == "none" and 2) or (effectNow == "prime" and 3) or (effectNow == "contraband" and 4) or 1
    local ep = segmented(x + w - 380, cy, 360, 30, {"Real", "None", "Prime", "Contraband"}, ei)
    if ep and ep ~= ei then setMapping("spoof", "Effect", ({false, "none", "prime", "contraband"})[ep] or nil) end
    cy = cy + 36
    for _, badge in ipairs(SPOOF_BADGES) do
        text(badge[2], cx, cy + 8, C.text, 13, 5)
        local now = (values[badge[1]] or ""):lower()
        local idx = (now == "true" and 2) or (now == "false" and 3) or 1
        local pick = segmented(x + w - 260, cy, 240, 30, {"Real", "On", "Off"}, idx)
        if pick and pick ~= idx then setMapping("spoof", badge[1], ({false, "true", "false"})[pick] or nil) end
        cy = cy + 36
    end

    cy = cy + 8
    line(cx, cy, x + w - 20, cy, C.line, 3, 1)
    cy = cy + 14
    text("Device Icon (Pro Matcha Only)", cx, cy + 8, C.text, 13, 5, true)
    text("Everyone sees this one - it is sent to the server. Needs Matcha's Hybrid Mode.", cx, cy + 28, C.bad, 12, 5)
    local deviceNow = values.Device
    local di = 1
    local labels = {}
    for i, d in ipairs(DEVICE_CHOICES) do
        labels[i] = d[1]
        if d[2] and deviceNow and d[2]:lower() == deviceNow:lower() then di = i end
    end
    local dp = segmented(cx, cy + 48, 400, 30, labels, di)
    if dp and dp ~= di then setMapping("spoof", "Device", DEVICE_CHOICES[dp][2]) end

    local by = y + h - 44
    text("Shows from the next Save & Apply.", cx, by + 8, C.faint, 12, 5)
    if button(x + w - 200, by, 180, 30, "Turn it all off") then
        for _, f in ipairs(SPOOF_FIELDS) do setMapping("spoof", f.key, nil); state.inputs["spoof_" .. f.key] = "" end
        for _, b in ipairs(SPOOF_BADGES) do setMapping("spoof", b[1], nil) end
        setMapping("spoof", "Effect", nil)
        setMapping("spoof", "Device", nil)
    end
end

-- Misc: smaller features, each a tab of its own under this one.
local function drawMisc(x, y, w, h)
    local at = state.miscTab or 1
    local pick = segmented(x, y, 360, 30, {"Tracers", "Hands", "Spoof"}, at)
    if pick and pick ~= at then state.miscTab, at, focus = pick, pick, nil end
    if at == 1 then drawTracers(x, y + 38, w, h - 38)
    elseif at == 2 then drawHands(x, y + 38, w, h - 38)
    else drawSpoof(x, y + 38, w, h - 38) end
end

-- Support ID: a short number for this PC, made here from Matcha's hardware ID
-- and scrambled so it can't be turned back into it. Nothing is sent anywhere;
-- it is printed so a log or screenshot says which copy it came from, and the
-- changer refuses to run for IDs listed in the repo's blacklist.txt.
local function supportId()
    local ok, hw = pcall(function() return gethwid() end)
    if not ok or type(hw) ~= "string" or hw == "" then return nil end
    local s = "rsc:" .. hw
    local h1, h2 = 7, 11
    for _ = 1, 3 do
        for i = 1, #s do
            local c = s:byte(i)
            h1 = (h1 * 131 + c + h2 % 251) % 999983
            h2 = (h2 * 65599 + c * 7 + i + h1 % 509) % 1000003
        end
    end
    return string.format("%04d-%04d", h1 % 10000, h2 % 10000)
end
local function drawSettings(x, y, w, h)
    rect(x, y, w, h, C.panel, 2, 8)
    local cx, cy = x + 20, y + 18
    text("Auto-apply on join", cx, cy + 6, C.text, 14, 5, true)
    text("Applies your saved config by itself once per server.", cx, cy + 26, C.faint, 12, 5)
    local a = segmented(x + w - 200, cy, 180, 30, {"Off", "On"}, state.autoApply and 2 or 1)
    if a then state.autoApply = a == 2; saveSettings() end
    cy = cy + 50
    text("Mouse offset", cx, cy + 6, C.text, 14, 5, true)
    text("If the dot isn't on your cursor, move it until it is: " .. state.mouseOffset .. " px",
        cx, cy + 26, C.faint, 12, 5)
    if button(x + w - 200, cy, 84, 30, "Up") then state.mouseOffset = state.mouseOffset - 2; saveSettings() end
    if button(x + w - 104, cy, 84, 30, "Down") then state.mouseOffset = state.mouseOffset + 2; saveSettings() end
    cy = cy + 50
    text("Reload", cx, cy + 6, C.text, 14, 5, true)
    text("After editing the config elsewhere, or when the site gets new skins.", cx, cy + 26, C.faint, 12, 5)
    if button(x + w - 200, cy, 84, 30, "Lists") then job("Reading lists...", loadCatalog) end
    if button(x + w - 104, cy, 84, 30, "Config") then job("Reading config...", loadConfig) end
    cy = cy + 50
    text("Accent color", cx, cy + 6, C.text, 14, 5, true)
    text("Buttons, highlights and the picked tile.", cx, cy + 26, C.faint, 12, 5)
    for i, hex in ipairs(ACCENTS) do
        local sx = x + w - 20 - (#ACCENTS - i) * 30 - 12
        local sy = cy + 15
        local ok, col3 = pcall(Color3.fromHex, "#" .. hex)
        if ok then circle(sx, sy, 10, col3, 5, true) end
        if hex == state.accent then circle(sx, sy, 14, C.text, 5, false, 2) end
        if clicked(sx - 14, sy - 14, 28, 28) then state.accent = hex; applyAccent(hex); saveSettings() end
    end
    cy = cy + 50
    text("Show / hide key", cx, cy + 6, C.text, 14, 5, true)
    text(state.binding and "Press the key to use. Esc cancels." or "Click, then press the key that shows and hides this window.",
        cx, cy + 26, C.faint, 12, 5)
    local label = state.binding and "Press a key..." or keyName(state.toggleKey)
    if button(x + w - 200, cy, 180, 30, label, state.binding) and not state.binding then
        -- Keys already held when binding starts don't count.
        state.binding, state.bindHeld = true, {}
        for vk in pairs(KEY_NAMES) do
            local okDown, down = pcall(iskeypressed, vk)
            if okDown and down then state.bindHeld[vk] = true end
        end
    end
    cy = cy + 50
    text("Lists", cx, cy + 6, C.text, 14, 5, true)
    text(inventory and "The \"you own\" lists show only what you own, or everything."
        or "Your inventory couldn't be read - the lists show everything. Try Reload > Lists in a match.", cx, cy + 26, C.faint, 12, 5)
    local o = segmented(x + w - 200, cy, 180, 30, {"Everything", "Owned"}, state.ownedOnly and 2 or 1)
    if o then state.ownedOnly = o == 2; saveSettings() end
    cy = cy + 50
    text("Window on autoexec", cx, cy + 6, C.text, 14, 5, true)
    text("Hidden: it loads quietly and " .. keyName(state.toggleKey) .. " opens it.", cx, cy + 26, C.faint, 12, 5)
    local v = segmented(x + w - 200, cy, 180, 30, {"Hidden", "Shown"}, state.showOnAutoexec and 2 or 1)
    if v then state.showOnAutoexec = v == 2; saveSettings() end
    cy = cy + 50
    text("Unload", cx, cy + 6, C.text, 14, 5, true)
    text("Removes this window until the script runs again.", cx, cy + 26, C.faint, 12, 5)
    if button(x + w - 200, cy, 180, 30, "Unload") then state.unload = true end
    cy = cy + 58
    line(cx, cy, x + w - 20, cy, C.line, 3, 1)
    text("Skin changer by Martini", cx, cy + 14, C.dim, 13, 5, true)
    text("mr.vage - Main Contributor for the GUI", cx, cy + 36, C.dim, 12, 5)
    text("Sorta copied from Gain's external", cx, cy + 56, C.faint, 12, 5)
    text("dantekarati - Contributor for the idea", cx, cy + 76, C.faint, 12, 5)
    local rx2 = x + math.floor(w / 2)
    text("Main testers/supporters: choperr0333 aka @Giounis", rx2, cy + 16, C.faint, 12, 5)
    text("Site: " .. SITE, rx2, cy + 36, C.faint, 12, 5)
    state.supportId = state.supportId or supportId() or "unavailable"
    text("Support ID: " .. state.supportId, rx2, cy + 76, C.dim, 12, 5)
    text("Gain's Discord: https://discord.gg/RHbxDSe8Z", rx2, cy + 56, C.faint, 12, 5)
end

-- The window

local TABS = {"Skins", "Cosmetics", "Visuals", "Misc", "Sounds", "Settings"}
local DRAW = {Skins = drawSkins, Cosmetics = drawCosmetics, Visuals = drawVisuals, Misc = drawMisc, Sounds = drawSounds,
    Settings = drawSettings}
local function viewport()
    local ok, vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
    return ok and vp or V2(1920, 1080)
end
local win = {w = 840, h = 660}
do
    local vp = viewport()
    win.x = math.floor(math.max(10, (vp.X - win.w) / 2))
    win.y = math.floor(math.max(40, (vp.Y - win.h) / 2))
end
local grabbed, lastInputGrab = nil, nil

-- The first-run notice: it has to be read before anything else shows, and its
-- button unlocks after a few seconds. Seen once, it is remembered in the
-- settings file (shared by both GUIs).
local NOTICE_SECONDS = 10
local NOTICE = {
    "All of the functions of the script are undetected. The only detectable way is to enable Device Spoof, "
        .. "but the chances of a ban by using it are extremely unlikely.",
    "You can swap between your own skins. Example: you own Event Horizon and set Event Horizon > Keyper. "
        .. "If you equip Event Horizon, it will show Keyper.",
    "Demanding questions about the mentioned stuff in this notice will get you blacklisted.",
    "The script gives this PC a support ID, made on your PC from Matcha's hardware ID and scrambled. "
        .. "It is not sent anywhere: it shows in the console, and a blacklisted ID can't run the script.",
}
local noticeLines, noticeWidth
local function drawNotice(x, y, w, h)
    state.noticeStart = state.noticeStart or tick()
    local left = math.ceil(NOTICE_SECONDS - (tick() - state.noticeStart))
    local px, pw = x + 70, w - 140
    -- Wrapped once per width: measuring text every frame is slow.
    if noticeWidth ~= pw then
        noticeLines, noticeWidth = {}, pw
        for _, para in ipairs(NOTICE) do
            local line = ""
            for word in para:gmatch("%S+") do
                local try = line == "" and word or (line .. " " .. word)
                if line ~= "" and textWidth(try, 14) > pw then
                    noticeLines[#noticeLines + 1] = line
                    line = word
                else
                    line = try
                end
            end
            if line ~= "" then noticeLines[#noticeLines + 1] = line end
            noticeLines[#noticeLines + 1] = ""
        end
    end
    local cy = y + 36
    -- A red title with a soft glow behind it (the same text, larger and faint).
    local red = RGB(255, 45, 60)
    rect(x + w / 2 - 90, cy - 6, 180, 38, red, 3, 19, 0.12)
    rect(x + w / 2 - 74, cy - 2, 148, 30, red, 3, 15, 0.16)
    text("NOTICE!", x + w / 2, cy, red, 22, 5, true, true)
    cy = cy + 52
    for _, l in ipairs(noticeLines) do
        if l ~= "" then text(l, px, cy, RGB(255, 194, 51), 14, 5) end
        cy = cy + (l == "" and 12 or 22)
    end
    local bw, ready = 280, left <= 0
    local by = math.max(cy + 16, y + h - 84)
    if button(x + (w - bw) / 2, by, bw, 38, ready and "I've read and accept" or ("I've read and accept  (" .. left .. ")"), ready, not ready) then
        state.noticeSeen = true
        saveSettings()
    end
end

local function drawWindow(slide)
    local vp = viewport()
    win.w = math.min(840, math.max(560, vp.X - 20))
    win.h = math.min(660, math.max(420, vp.Y - 40))
    local x, y, w, h = win.x, win.y + math.floor(slide or 0), win.w, win.h

    -- Drag by the title bar.
    if M.press and not slide and over(x, y, w - 60, 40) then grabbed = {M.x - x, M.y - y} end
    if not M.down then grabbed = nil end
    if grabbed then
        win.x = math.floor(math.max(0, math.min(vp.X - 60, M.x - grabbed[1])))
        win.y = math.floor(math.max(0, math.min(vp.Y - 40, M.y - grabbed[2])))
        x, y = win.x, win.y
        M.dragged = true
    end

    rect(x - 1, y - 1, w + 2, h + 2, C.line, 0, 11)
    rect(x, y, w, h, C.bg, 1, 10)
    text("Rivals", x + 16, y + 12, C.text, 16, 5, true)
    text("Skin Changer", x + 16 + textWidth("Rivals ", 16, true), y + 12, C.accent, 16, 5, true)
    if button(x + w - 36, y + 8, 26, 24, "x") then state.open = false end
    line(x, y + 40, x + w, y + 40, C.line, 2, 1)

    if not state.noticeSeen then
        drawNotice(x, y + 40, w, h - 40)
        circle(M.x, M.y, 2, C.accent, 9, true)
        return over(x, y, w, h)
    end

    -- Tabs
    local tw = (w - 24) / #TABS
    for i, name in ipairs(TABS) do
        local tx = x + 12 + (i - 1) * tw
        local sel = state.tab == name
        if sel then
            rect(tx + 2, y + 48, tw - 4, 30, C.card, 2, 6)
            line(tx + tw * 0.3, y + 76, tx + tw * 0.7, y + 76, C.accent, 5, 2)
        end
        text(name, tx + tw / 2, y + 55, sel and C.text or C.dim, 13, 5, sel, true)
        if clicked(tx, y + 48, tw, 30) then state.tab = name; focus = nil end
    end

    local body = y + 88
    DRAW[state.tab](x + 12, body, w - 24, h - (body - y) - 48)

    -- Footer
    local fy = y + h - 40
    line(x, fy - 2, x + w, fy - 2, C.line, 2, 1)
    local busy = shared.busy or upstreamBusy()
    text(fitText((busy and "Working...  " or "") .. tostring(state.status), w - 330, 12), x + 16, fy + 12,
        state.dirty and C.text or C.dim, 12, 5)
    -- Right-aligned against the button, so any key name sits the same way.
    local hint = keyName(state.toggleKey) .. " hides"
    text(hint, x + w - 172 - 16 - textWidth(hint, 12), fy + 12, C.faint, 12, 5)
    if button(x + w - 172, fy + 5, 160, 28, "Save & Apply", true, busy) then job("Applying...", apply) end

    -- Where the game says the mouse is, to check the offset against.
    circle(M.x, M.y, 2, C.accent, 9, true)
    return over(x, y, w, h)
end

local appliedAccent
local function captureKey()
    for vk in pairs(KEY_NAMES) do
        local ok, down = pcall(iskeypressed, vk)
        down = ok and down == true
        if down and not state.bindHeld[vk] then
            state.binding = false
            if vk ~= 0x1B then
                state.toggleKey = vk
                saveSettings()
            end
            keyState[vk] = true -- so the new key doesn't toggle on this same press
            return
        end
        if not down then state.bindHeld[vk] = nil end
    end
    local ok, esc = pcall(iskeypressed, 0x1B)
    if ok and esc then state.binding = false end
end

-- Opening pulls the window up into place while it fades in; closing drops it
-- back down and fades it out. `shown` runs 0 (hidden) to 1 (open).
local OPEN_SECONDS, CLOSE_SECONDS, SLIDE = 0.3, 0.22, 48
local shown, lastFrame = 0, nil

local function frame()
    readInput()
    if state.accent ~= appliedAccent then appliedAccent = state.accent; applyAccent(state.accent) end
    if state.binding then
        captureKey()
    elseif keyHit(state.toggleKey) then
        state.open = not state.open; focus = nil
    end
    local now = tick()
    local dt = math.min(0.05, now - (lastFrame or now))
    lastFrame = now
    if state.open then shown = math.min(1, shown + dt / OPEN_SECONDS)
    else shown = math.max(0, shown - dt / CLOSE_SECONDS) end

    beginFrame()
    local overWindow = false
    if shown > 0 then
        local eased = 1 - (1 - shown) ^ 3
        if state.open and focus then typeInto(focus) end
        -- A click anywhere ends typing; a click in a box focuses it again.
        if M.press and focus then focus = nil end
        -- Clicks only count once the window is fully out.
        if shown < 1 then M.press, M.release = false, false end
        Fade = eased
        overWindow = drawWindow(shown < 1 and (1 - eased) * SLIDE or nil)
        Fade = 1
    end
    endFrame()
    -- Keep clicks and typing on the window from reaching the game.
    local grab = state.open and (overWindow or focus ~= nil or state.binding == true)
    if grab ~= lastInputGrab and type(setrobloxinput) == "function" then
        lastInputGrab = grab
        pcall(setrobloxinput, not grab)
    end
end

local alive = true
local function stop()
    alive = false
    if _G.__RivalsGuiSession == guiToken then _G.__RivalsGuiSession = nil end
    pcall(wipe)
    if type(setrobloxinput) == "function" then pcall(setrobloxinput, true) end
end
-- What is on screen right now, as text: for checking the layout from a script.
local function dump()
    local out = {}
    for i, o in ipairs(Pool.tx) do
        local c = Cache.tx[i]
        if c.Visible then out[#out + 1] = string.format("%d,%d %s", c.Positionx, c.Positiony, c.Text) end
    end
    local shown = 0
    for _ in pairs(shownImages) do shown = shown + 1 end
    out[#out + 1] = "images shown: " .. shown
    return table.concat(out, "\n")
end
_G.__RivalsDrawnGui = {stop = stop, state = state, dump = dump, win = win}

-- Auto-apply, once per server, like the menu-tab GUI.
local function autoApplyOnJoin()
    task.spawn(function()
        while alive and _G.__RivalsGuiSession == guiToken do
            local okFile, hasFile = pcall(isfile, SETTINGS)
            if not state.settingsRead and okFile and hasFile then pcall(loadSettings) end
            local context = state.autoApply and currentContext()
            local key = context and context.key
            local applied = _G.__RIVALS_SKIN_CHANGER_STATE
            if key and _G.__RivalsGuiAutoApplied ~= key and applied and applied.wfAddr == context.wf then
                _G.__RivalsGuiAutoApplied = key
            elseif key and _G.__RivalsGuiAutoApplied ~= key and not shared.busy and not upstreamBusy() then
                _G.__RivalsGuiAutoApplied = key
                if isfile(FILE) and readfile(FILE):find("%S") then
                    if #catalog.weapons == 0 then pcall(loadCatalog) end
                    job("Auto-applying...", apply)
                end
            end
            task.wait(2)
        end
    end)
end

pcall(loadConfig)
pcall(loadSettings)
-- Started by autoexec, the window stays hidden until its key is pressed
-- (Settings > Window on autoexec).
local startedHidden = false
if _G.__RivalsGuiFromAutoexec then
    _G.__RivalsGuiFromAutoexec = nil
    if not state.showOnAutoexec then state.open, startedHidden = false, true end
end
-- The notice is shown straight away the first time, however it was started.
if not state.noticeSeen then state.open, startedHidden = true, false end
task.spawn(function()
    local ok, err = pcall(loadCatalog)
    if not ok then state.status = "Lists failed: " .. tostring(err):sub(1, 80) end
end)

task.spawn(function()
    local lastError
    while alive and _G.__RivalsGuiSession == guiToken do
        if otherGame() then
            print("[Rivals GUI] Not RIVALS - the GUI stays off in this game.")
            break
        end
        local ok, err = pcall(frame)
        if not ok and tostring(err) ~= lastError then
            lastError = tostring(err)
            print("[Rivals GUI] " .. lastError)
        end
        if state.unload then break end
        task.wait()
    end
    stop()
end)
autoApplyOnJoin()
if startedHidden and type(notify) == "function" then
    pcall(notify, "Rivals Skin Changer", "Loaded - " .. keyName(state.toggleKey) .. " opens the window.", 5)
end
print("[Rivals GUI] Drawn window ready - " .. keyName(state.toggleKey) .. " shows and hides it."
    .. (state.autoApply and " Auto-apply is on." or ""))
