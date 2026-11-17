-- FNaF_SB_Ap: Archipelago mod for FNaF: Security Breach (UE4SS 3.0.1).

local cfg = require("config")
local U = require("util")
local APC = require("ap_core")
local ok_tables, APT = pcall(require, "ap_tables")

local MOD = "FNaF_SB_Ap"
local VERSION = "1.0.0-beta.3"

-- paths & log
local src = debug.getinfo(1, "S").source:gsub("^@", "")
local mod_dir = U.dirname(U.dirname(src))
if not U.file_exists(mod_dir .. "/Scripts/main.lua") then
    mod_dir = "Mods/" .. MOD
end

if cfg.keep_previous_log ~= false then
    pcall(os.remove, mod_dir .. "/log_previous.txt")
    pcall(os.rename, mod_dir .. "/log.txt", mod_dir .. "/log_previous.txt")
end
local log = U.new_logger({
    path = mod_dir .. "/log.txt",
    max_lines = cfg.max_log_lines,
    prefix = "[FNaF_SB_Ap]",
    console = cfg.log_console,
    verbose = cfg.log_verbose,
    flush_every = cfg.log_flush_every,
    echo = function(s) print(s .. "\n") end,
})

local trace = { file = nil, n = 0, path = mod_dir .. "/trace.txt" }
if cfg.crash_trace ~= false then
    pcall(os.remove, mod_dir .. "/trace_previous.txt")
    pcall(os.rename, trace.path, mod_dir .. "/trace_previous.txt")
    trace.file = io.open(trace.path, "wb")
end
local function trace_step(what)
    local f = trace.file
    if not f then return end
    trace.n = trace.n + 1
    if trace.n > (cfg.crash_trace_lines or 20000) then
        f:close()
        f = io.open(trace.path, "wb")
        trace.file, trace.n = f, 1
        if not f then return end
    end
    f:write(os.date("%H:%M:%S"), string.format(" %.3f ", os.clock()), what, "\n")
    f:flush()
end

local function try(what, fn, ...)
    trace_step(what)
    local ok, err = pcall(fn, ...)
    if not ok then log:write("Error", what .. ": " .. tostring(err)) end
    return ok, err
end

local function on_game_thread(what, fn)
    ExecuteInGameThread(function() try(what, fn) end)
end

-- object access
local function is_valid(obj)
    if obj == nil then return false end
    local ok, v = pcall(function() return obj:IsValid() end)
    return ok and v == true
end

local found_paths = {}
local function obj_path(obj)
    local ok, s = pcall(function() return obj:GetFullName() end)
    return ok and type(s) == "string" and s:match("^%S+%s+(.+)$") or nil
end
local function obj_class(obj)
    local ok, s = pcall(function() return obj:GetClass():GetFName():ToString() end)
    return ok and s or "?"
end
local function cached(key)
    local c = found_paths[key]
    if not c then return nil end
    local ok, o = pcall(StaticFindObject, c.path)
    if ok and is_valid(o) and obj_class(o) == c.class then return o end
    found_paths[key] = nil
    return nil
end
local function remember(key, obj)
    local p = obj_path(obj)
    if p then found_paths[key] = { path = p, class = obj_class(obj) } end
end

local world = { pause_until = 0, in_minigame = false, switches = 0, hook_seen = {} }
local function world_now() return (type(AP_CLOCK) == "function" and AP_CLOCK()) or os.time() end
local function world_now_ms() return (type(AP_CLOCK_MS) == "function" and AP_CLOCK_MS()) or math.floor(os.clock() * 1000) end
local function world_busy()
    local now = world_now()
    if world.in_minigame or now < world.pause_until then return true end
    if cfg.pause_on_loading == false then return false end
    return (world.loading ~= nil and now < world.loading) or (world.load_end ~= nil and now < world.load_end)
end
local function find(short_class)
    local o = cached(short_class)
    if o then return o end
    local ok, found = pcall(FindFirstOf, short_class)
    if ok and is_valid(found) then
        remember(short_class, found)
        return found
    end
    return nil
end

local function live_ams()
    local o = cached("AIManagementSystem")
    if o and not obj_path(o):find("Default__", 1, true) then return o end
    local ams = nil
    for _, x in ipairs(FindAllOf("AIManagementSystem") or {}) do
        if is_valid(x) and not (obj_path(x) or "Default__"):find("Default__", 1, true) then ams = x end
    end
    if ams then remember("AIManagementSystem", ams) end
    return ams
end

local function prop(obj, name)
    if obj == nil then return nil end
    local ok, v = pcall(function() return obj[name] end)
    if ok then return v end
    return nil
end

local function call(obj, fname, ...)
    if obj == nil then return nil end
    local args = { ... }
    local ok, v = pcall(function() return obj[fname](obj, table.unpack(args)) end)
    if ok then return v end
    return nil
end

local function full_name(obj)
    local ok, s = pcall(function() return obj:GetFullName() end)
    return ok and s or "?"
end

local function class_name(obj)
    local ok, s = pcall(function() return obj:GetClass():GetFName():ToString() end)
    return ok and s or "?"
end

local function location_of(actor)
    local loc = call(actor, "K2_GetActorLocation")
    return tonumber(prop(loc, "X")) or 0, tonumber(prop(loc, "Y")) or 0, tonumber(prop(loc, "Z")) or 0
end

-- Archipelago bridge
local apcfg = cfg.ap or {}
local ap = nil
if apcfg.enabled and ok_tables then
    local fs = {
        read = function(path)
            local f = io.open(path, "rb")
            if not f then return nil end
            local t = f:read("a")
            f:close()
            return t
        end,
        write = function(path, text) return U.write_file(path, text) end,
        replace = function(tmp, target)
            os.remove(target)
            return os.rename(tmp, target)
        end,
    }
    ap = APC.new({
        tables = APT, bridge_dir = apcfg.bridge_dir or (mod_dir .. "/bridge"), fs = fs, cfg = apcfg,
        log = function(msg) log:write("AP", msg) end,
    })
elseif apcfg.enabled then
    log:write("AP", "ap_tables.lua missing or broken, bridge disabled: " .. tostring(APT))
end

local function ap_event(detect, name)
    if not ap then return end
    try("ap event", function() ap:on_event(detect, name) end)
    if ap.dirty then try("ap flush", function() ap:flush() end) end
end

local voice_seen, voice_count = {}, 0
local function voice_heard(text, where)
    if text == nil or text == "" or text == "nil" or text == "None" then return end
    if not voice_seen[text] and voice_count < 2000 then
        voice_seen[text] = true
        voice_count = voice_count + 1
        log:write("Voice", where .. ": " .. text)
    end
    local low = text:lower()
    for _, line in ipairs(apcfg.voice_lines or {}) do
        for _, m in ipairs(line.match or {}) do
            if low:find(m:lower(), 1, true) then ap_event("voice", line.event); break end
        end
    end
end

local function voice_poll()
    for _, cls in ipairs(cfg.voice_widgets or {}) do
        for _, w in ipairs(FindAllOf(cls) or {}) do
            if is_valid(w) then
                voice_heard(U.to_str(prop(w, "P_Source")), cls)
                local arr = prop(w, "P_LineStrings")
                if arr then
                    pcall(function() arr:ForEach(function(_, e) voice_heard(U.to_str(U.unwrap(e)), cls) end) end)
                end
            end
        end
    end
end

local function mission_task_events(mission)
    if not ap then return end
    for key in pairs(APT.locations.task or {}) do
        if key:sub(1, #mission + 1) == mission .. "#" then ap_event("task", key) end
    end
end

-- state snapshot
local clock_seen_negative = false

local watch = { world = nil, at = {}, due = nil }
function watch.appeared(cls)
    if (cfg.watch_actor_props or {})[cls] then watch.due = world_now_ms() + (cfg.watch_appear_ms or 1000) end
end
function watch.find_all()
    local again = false
    for cls in pairs(cfg.watch_actor_props or {}) do
        for _, a in ipairs(FindAllOf(cls) or {}) do
            local p = is_valid(a) and obj_path(a)
            if p and not p:find("Default__", 1, true) then
                local x, y, z = location_of(a)
                if x == 0 and y == 0 and z == 0 then again = true
                else watch.at[cls] = { path = p, x = x, y = y, z = z } end
            end
        end
    end
    if again then watch.due = world_now_ms() + 2000 end
end
function watch.actor(cls, greg)
    local now = world_now_ms()
    if watch.world ~= world.switches then
        watch.world, watch.at, watch.due = world.switches, {}, now + (cfg.watch_settle_ms or 10000)
    end
    if watch.due and now >= watch.due then watch.due = nil; watch.find_all() end
    local at = watch.at[cls]
    if not at then return nil end
    local gx, gy, gz = 0, 0, 0
    if greg then gx, gy, gz = location_of(greg) end
    local r = cfg.watch_radius or 2500
    if not (gx == 0 and gy == 0 and gz == 0) and (gx - at.x) ^ 2 + (gy - at.y) ^ 2 + (gz - at.z) ^ 2 > r * r then
        return nil
    end
    local ok, o = pcall(StaticFindObject, at.path)
    if ok and is_valid(o) then return o end
    return nil
end

local function read_state()
    local s = { scalars = {}, quiet = {}, inventory = {}, missions = {}, tasks = {}, active = {} }
    local inv = find("FNAFInventorySystem")
    local ws = find("WorldStateSystem")
    local ms = find("FNAFMissionSystem")
    local greg = find("Gregory_C")
    s.scalars["subsystems"] = string.format("inv=%s ws=%s missions=%s gregory=%s",
        tostring(inv ~= nil), tostring(ws ~= nil), tostring(ms ~= nil), tostring(greg ~= nil))
    if inv then
        if cfg.log_state_details then
            for _, k in ipairs(cfg.inventory_scalars) do s.scalars["Inventory." .. k] = U.to_str(prop(inv, k)) end
            for _, k in ipairs(cfg.inventory_quiet) do s.quiet["Inventory." .. k] = U.to_str(prop(inv, k)) end
        end
        s.inventory = U.set_of(U.list_from_array(call(inv, "GetAllCurrentInventoryItems")))
    end
    if ws then
        local fs = prop(ws, "FreddyState")
        if fs ~= nil then
            s.freddy = {}
            for _, k in ipairs(cfg.freddy_state_fields) do
                local v = U.to_str(prop(fs, k))
                s.scalars["FreddyState." .. k] = v
                if v == "true" then s.freddy[k] = true end
            end
        end
        s.scalars["WorldState.WorldState"] = U.to_str(prop(ws, "WorldState"))
        s.scalars["WorldState.DeathCount"] = U.to_str(call(ws, "GetCurrentDeathCount"))
        if cfg.read_world_flags then
            local flags = call(ws, "GetAllCurrentActivables")
            if flags ~= nil then s.flags = U.set_of(U.list_from_array(flags)) end
        end
        local arcade = prop(ws, "ArcadeState")
        if arcade ~= nil then
            s.arcade = {}
            for _, game in ipairs(cfg.arcade_games or {}) do
                local st = prop(arcade, game)
                for _, f in ipairs(cfg.arcade_fields or {}) do
                    local v = U.to_str(prop(st, f))
                    s.scalars["Arcade." .. game .. "." .. f] = v
                    if v == "true" then s.arcade[game .. "." .. f] = true end
                end
            end
        end
    end
    for cls, props in pairs(cfg.watch_actor_props or {}) do
        local obj = watch.actor(cls, greg)
        if obj then
            s.actors = s.actors or {}
            for _, p in ipairs(props) do
                local v = U.to_str(prop(obj, p))
                s.scalars["Actor." .. cls .. "." .. p] = v
                if v == "true" then s.actors[cls .. "." .. p] = true end
            end
        end
    end
    local gi = find("FNAFGameInstance_C")
    if gi and s.arcade then
        for _, k in ipairs(cfg.game_instance_flags or {}) do
            local v = U.to_str(prop(gi, k))
            s.scalars["GameInstance." .. k] = v
            if v == "true" then s.arcade[k] = true end
        end
    end
    if ms then
        s.missions = U.set_of(U.list_from_array(call(ms, "GetCompletedMissions"), function(st)
            return U.to_str(prop(st, "Name"))
        end))
        for _, st in ipairs(U.list_from_array(call(ms, "GetActiveMissions"), function(st) return st end)) do
            local m = U.to_str(prop(st, "Name"))
            s.active[m] = true
            local done = U.list_from_array(prop(st, "CompletedTasks"), function(v) return tonumber(U.to_str(v)) end)
            for _, i in ipairs(done) do
                s.tasks[m .. "#" .. tostring(i)] = true
            end
            if cfg.log_state_details then
                s.scalars["Mission." .. m] = string.format("status=%s info=%s tasks=%d",
                    U.to_str(prop(st, "Status")), U.to_str(prop(st, "InfoState")), #done)
            end
        end
    end
    if greg and cfg.log_state_details then
        for _, k in ipairs(cfg.gregory_props) do s.scalars["Gregory." .. k] = U.to_str(prop(greg, k)) end
    end
    s.ready = inv ~= nil and greg ~= nil
    if not s.ready then clock_seen_negative = false end
    if s.ready then
        s.clock_seconds = tonumber(call(find("GameClockSystem"), "GetCurrentTimeInSeconds"))
        if s.clock_seconds then
            s.clock_hour = math.floor(s.clock_seconds / 3600) % 24
            if s.clock_seconds < 0 then
                clock_seen_negative = true
            elseif s.clock_seconds == 0 and not clock_seen_negative then
                s.clock_hour = nil
            end
        else
            local widget = find("WI_Gregory_Clock_C")
            if widget then
                s.clock_text = U.to_str(call(prop(widget, "ClockText"), "GetText"))
                s.clock_hour = U.clock_hour(s.clock_text, prop(widget, "PM"))
            end
        end
    end
    return s
end

local last_state = nil

local function fname_add(name) return FName(name, EFindName.FNAME_Add) end

local function inventory_seen(n)
    if not ap then return end
    local ok, act = pcall(function() return ap:inventory_added(n) end)
    if ok and act == "remove" then
        local inv = find("FNAFInventorySystem")
        if inv then
            log:write("AP", "RemoveItem " .. n)
            try("RemoveItem " .. n, function() inv:RemoveItem(fname_add(n)) end)
        end
    end
    return ok and act or nil
end

-- AP: block vanilla rewards
local COLLECTIBLE_CLASS = "/Game/Blueprints/Objects/Collectibles/Collectible.Collectible_C"
local collectible_class = nil
local pickup_class_cache, pickup_miss_logged = {}, {}

local function isa_collectible(actor)
    if collectible_class == nil or not is_valid(collectible_class) then
        local ok, c = pcall(StaticFindObject, COLLECTIBLE_CLASS)
        collectible_class = (ok and is_valid(c)) and c or nil
        if not collectible_class then return false end
    end
    local ok, v = pcall(function() return actor:IsA(collectible_class) end)
    return ok and v == true
end

local function walk_class(cls)
    local chain, c = {}, cls
    for _ = 1, 16 do
        if not is_valid(c) then return false, false, chain end
        local name = U.to_str(call(c, "GetFName"))
        chain[#chain + 1] = name
        if name == "Collectible_C" then return true, true, chain end
        if name == "nil" then return false, false, chain end
        local ok, super = pcall(function() return c:GetSuperStruct() end)
        if not ok then return false, false, chain end
        if super == nil or not is_valid(super) then return false, true, chain end
        c = super
    end
    return false, false, chain
end

local function is_collectible(actor)
    local ok, cls = pcall(function() return actor:GetClass() end)
    if not ok or cls == nil then return isa_collectible(actor) end
    local key = U.to_str(call(cls, "GetFName"))
    local cached = nil
    if key ~= "nil" then cached = pickup_class_cache[key] end
    if cached ~= nil then return cached end
    local found, complete, chain = walk_class(cls)
    if not found then found = isa_collectible(actor) end
    if found or (complete and key ~= "nil") then pickup_class_cache[key] = found end
    if not found and not pickup_miss_logged[key] and (key:find("Collect") or key:find("Present") or key:find("Pass")) then
        pickup_miss_logged[key] = true
        log:write("Swap", string.format("class %s not recognised as a pickup (chain %s, complete=%s)",
            key, table.concat(chain, " > "), tostring(complete)))
    end
    return found
end

local swap_count, swap_failed = 0, {}
local function swap_actor(actor, why)
    if not ap or not apcfg.block_vanilla or not is_valid(actor) then return end
    local name = U.to_str(prop(actor, "ItemName"))
    local full = full_name(actor)
    local forced = false
    for _, suffix in ipairs(apcfg.extra_pickups or {}) do
        if full:sub(-#suffix) == suffix then forced = true end
    end
    local new = ap:swap_name(name, forced)
    if not new then return end
    actor.ItemName = fname_add(new)
    local now = U.to_str(prop(actor, "ItemName"))
    if now ~= new then
        if not swap_failed[full] then
            swap_failed[full] = true
            log:write("Swap", string.format("FAILED on %s: ItemName is still %s (%s)", U.short_object_name(full), now, why))
        end
        return
    end
    swap_count = swap_count + 1
    local begun = why == "scan" and call(actor, "HasActorBegunPlay") == true
    if begun and apcfg.log_swaps ~= false then
        log:write("Swap", string.format("%s missed before loading (class %s, recognised now: %s)", U.short_object_name(full),
            class_name(actor), tostring(is_collectible(actor))))
    end
    if begun and apcfg.reset_opened_presents ~= false and not ap:pickup_checked(name) then
        local inv = find("FNAFInventorySystem")
        local owned = inv and call(inv, "HasItem", fname_add(name)) == true
        if owned then
            call(actor, "Reset Animation")
            log:write("Swap", string.format("%s loaded as opened (%s owned): Reset Animation called", U.short_object_name(full), name))
        end
    end
    if apcfg.log_swaps ~= false then
        log:write("Swap", string.format("%s: %s -> %s (%s) CanCollect=%s CollectComplete=%s", U.short_object_name(full),
            name, new, why, U.to_str(prop(actor, "CanCollect")), U.to_str(prop(actor, "CollectComplete"))))
    end
end

local popup = { pending = {} }
local function popup_now() return (type(AP_CLOCK) == "function" and AP_CLOCK()) or os.time() end

local function empty_opened(actor)
    if not ap or not apcfg.block_vanilla then return end
    local name = U.to_str(prop(actor, "ItemName"))
    local original, swapped = ap:original_name(name)
    if not swapped then return end
    local loc, now = ap.T.locations.collect[original], popup_now()
    popup.pending[#popup.pending + 1] = { loc = loc, t = now, what = original }
    popup.armed = false
    popup.veil()
    if loc then popup.recent[loc], popup.last_loc, popup.last_t = now, loc, now end
    actor.ItemName = fname_add(ap:opened_name())
    log:write("Swap", string.format("%s opened: ItemName %s -> %s", U.short_object_name(full_name(actor)), name,
        U.to_str(prop(actor, "ItemName"))))
end

popup.recent = {}
function popup.expect(loc, what, fresh, again)
    if not loc or (apcfg.popup or {}).all_checks == false then return end
    for _, e in ipairs(popup.pending) do
        if e.loc == loc then return end
    end
    local now = popup_now()
    if not again and popup.recent[loc] and now - popup.recent[loc] < 3 then return end
    popup.recent[loc], popup.last_loc, popup.last_t = now, loc, now
    popup.pending[#popup.pending + 1] = { loc = loc, t = now, what = what, fresh = fresh }
    popup.armed = false
    popup.veil()
    log:write("AP", "popup expected for " .. tostring(what) .. " (location " .. tostring(loc) .. ")")
end
function popup.badge_location(actor)
    local award = ap.T.locations.inventory[U.to_str(prop(actor, "BadgeAward")) or ""]
    if award then return award end
    local cls = (class_name(actor) or ""):lower()
    local best, len
    for item, id in pairs(ap.T.locations.inventory or {}) do
        local suffix = item:match("^SecurityBadge(.+)$")
        if suffix and cls:find(suffix:lower(), 1, true) and (not len or #suffix > len) then best, len = id, #suffix end
    end
    if not best then ap:once("badge class:" .. cls, "popup: no badge holder location for class " .. cls) end
    return best
end
function popup.collect_opened(name)
    local original, swapped = ap:original_name(name)
    if swapped or (ap.cfg.listed_only or {})[original] then return end
    popup.expect(ap.T.locations.collect[original] or ap:boss_location(original), original)
end
function popup.inventory_added(n, act, new_check)
    local fresh = (apcfg.popup or {}).late_fresh_s or 1.5
    if new_check then return popup.expect(new_check, n, fresh) end
    if act == "remove" and popup.last_loc and popup_now() - popup.last_t < 5 then
        popup.expect(popup.last_loc, n, fresh, true)
    end
end
function popup.begun_done(why)
    local b = popup.begun
    if not b or not ap then return false end
    popup.begun = nil
    if popup_now() - b.t > ((apcfg.popup or {}).begun_s or 15) then return false end
    local ok, actor = pcall(StaticFindObject, b.path)
    if not (ok and is_valid(actor)) then actor = nil end
    if actor and prop(actor, "CanCollect") == true then return false end
    trace_step("pickup collected without OnCollect")
    log:write("AP", string.format("pickup %s (%s, class %s) collected without its OnCollect (%s): counted as collected",
        U.short_object_name(b.path), tostring(b.name), tostring(b.cls), why))
    ap_event("collect", b.name)
    if actor then empty_opened(actor) end
    popup.collect_opened(b.name)
    return true
end

function popup.vanilla_added(name)
    if not (ap and ap:is_vanilla(name) and popup.notify_item) then return end
    popup.notified = popup.notified or {}
    if popup.notified[name] then return end
    popup.notified[name] = true
    popup.notify_item(name)
end

local condition_seen = {}
local conditions_done = {}
local function swap_conditions(actor, why)
    if not ap or not apcfg.block_vanilla or not is_valid(actor) then return end
    local spec = (apcfg.condition_swaps or {})[class_name(actor)]
    if not spec then return end
    local full = full_name(actor)
    if why == "BeginPlay" then conditions_done[full] = nil
    elseif conditions_done[full] then return end
    conditions_done[full] = true
    for comp_name, item in pairs(spec) do
        local comp = prop(actor, comp_name)
        local cur = U.to_str(prop(comp, "RequiredInventoryItem"))
        local new = ap:prefix() .. item
        local key = full .. "." .. comp_name
        if cur == item then
            comp.RequiredInventoryItem = fname_add(new)
            local now = U.to_str(prop(comp, "RequiredInventoryItem"))
            log:write("Swap", string.format("%s.%s: RequiredInventoryItem %s -> %s (%s)%s", U.short_object_name(full),
                comp_name, cur, now, why, now == new and "" or " FAILED"))
        elseif cur ~= new and not condition_seen[key] then
            condition_seen[key] = true
            log:write("Swap", string.format("%s.%s: RequiredInventoryItem is %s, expected %s: left alone (%s)",
                U.short_object_name(full), comp_name, cur, item, why))
        end
    end
end

local DF = { tries = 0, opened = false, after_load = false, was_unchecked = false, seen = {}, active = true }
local function df_now() return (type(AP_CLOCK) == "function" and AP_CLOCK()) or os.time() end
local pickup_quiet_until, scan_due = nil, true
local function pickup_quiet() return pickup_quiet_until ~= nil and df_now() < pickup_quiet_until end

local function df_forget() found_paths["daycare station"] = nil end
local function df_wake()
    df_forget()
    DF.active = true
    DF.until_t = df_now() + ((apcfg.daycare_flashlight or {}).active_s or 30)
end

local function df_station(c)
    local ok, list = pcall(FindAllOf, "FlashlightRechargeStation_C")
    for _, st in ipairs(ok and type(list) == "table" and list or {}) do
        if is_valid(st) and full_name(st):sub(-#c.station) == c.station then
            return st
        end
    end
    return nil
end

local function df_state(station, child)
    return string.format("State=%s CanUseRecharge=%s ClosedCompletely=%s Opening?=%s | child bHidden=%s CanCollect=%s FlashlightAvailable=%s",
        U.to_str(prop(station, "State")), U.to_str(prop(station, "CanUseRecharge")),
        U.to_str(prop(station, "ClosedCompletely")), U.to_str(prop(station, "Opening?")),
        U.to_str(prop(child, "bHidden")), U.to_str(prop(child, "CanCollect")), U.to_str(prop(child, "FlashlightAvailable")))
end

local function df_owned(item)
    local inv = find("FNAFInventorySystem")
    return inv ~= nil and call(inv, "HasItem", fname_add(item)) == true
end

local function df_condition(c, station, value, why)
    local comp = prop(station, c.condition)
    local cur = U.to_str(prop(comp, "RequiredInventoryItem"))
    if cur == value then return end
    local other = value == c.item and ap:prefix() .. c.item or c.item
    if cur ~= other then
        if not DF.seen["cond" .. cur] then
            DF.seen["cond" .. cur] = true
            log:write("Swap", string.format("Daycare flashlight station: RequiredInventoryItem is %s, expected %s: left alone (%s)", cur, other, why))
        end
        return
    end
    comp.RequiredInventoryItem = fname_add(value)
    log:write("Swap", string.format("Daycare flashlight station: RequiredInventoryItem %s -> %s (%s)", cur,
        U.to_str(prop(comp, "RequiredInventoryItem")), why))
end

local function df_after_take(c, why)
    local station = df_station(c)
    if not station then return end
    local child = prop(prop(station, c.child), "ChildActor")
    local before = df_state(station, child)
    if U.to_str(prop(child, "bHidden")) == "false" and not df_owned(c.item) then
        call(station, "SetCollectibleState", false, true)
        log:write("Swap", string.format("Daycare flashlight taken: station emptied, SetCollectibleState(false, true) (%s)\n    before: %s\n    after:  %s",
            why, before, df_state(station, child)))
    else
        log:write("Swap", string.format("Daycare flashlight taken: station left as it is (%s) %s", why, before))
    end
    if not ap:is_ap_name(c.item) then
        local greg = find("Gregory_C")
        for _, pname in ipairs(c.unequip or {}) do
            if U.to_str(prop(greg, pname)) == "true" then
                greg[pname] = false
                log:write("Swap", string.format("Gregory.%s true -> %s (%s not received from AP yet)", pname,
                    U.to_str(prop(greg, pname)), c.item))
            end
        end
    end
end

local function daycare_flashlight_tick(why)
    local c = apcfg.daycare_flashlight
    if not ap or not apcfg.block_vanilla or not c or not DF.active then return end
    if DF.until_t and df_now() > DF.until_t then DF.active = false; df_forget(); return end
    if pickup_quiet() then return end
    local station = df_station(c)
    if not station then DF.active = false; return end
    local child = prop(prop(station, c.child), "ChildActor")
    if not ap:pickup_checked(c.item) then
        DF.was_unchecked = true
        df_condition(c, station, ap:prefix() .. c.item, why)
        local ready = U.to_str(prop(child, "bHidden")) == "false" and U.to_str(prop(child, "FlashlightAvailable")) == "true"
            and U.to_str(prop(child, "CanCollect")) == "true"
        if not ready and DF.tries < (c.tries or 3) then
            DF.tries = DF.tries + 1
            local before = df_state(station, child)
            call(station, "SetCollectibleState", true, false)
            if is_valid(child) then child.CanCollect = true end
            if not DF.opened then
                DF.opened = true
                call(station, "FlaslightStationOpenClose", true)
            end
            log:write("Swap", string.format("Daycare flashlight shown for pickup: SetCollectibleState(true, false), CanCollect = true (%s, try %d)\n    before: %s\n    after:  %s",
                why, DF.tries, before, df_state(station, child)))
        end
    else
        df_condition(c, station, c.item, why)
        if DF.was_unchecked or DF.after_load then
            local reason = DF.was_unchecked and "just taken" or "level loaded"
            DF.was_unchecked, DF.after_load = false, false
            DF.active = false
            ExecuteWithDelay(c.after_take_ms or 2000, function()
                on_game_thread("daycare flashlight taken", function() df_after_take(c, reason) end)
            end)
        end
        DF.active = false
    end
end

local function df_beginplay(actor)
    local c = apcfg.daycare_flashlight
    if not ap or not apcfg.block_vanilla or not c then return end
    local cls = class_name(actor)
    if not (c.stash_classes or {})[cls] then return end
    if cls == "FlashlightRechargeStation_C" and full_name(actor):sub(-#c.station) ~= c.station then return end
    DF.tries, DF.opened, DF.after_load = 0, false, true
    df_wake()
    if ap:pickup_checked(c.item) or not df_owned(c.item) then return end
    local inv = find("FNAFInventorySystem")
    call(inv, "RemoveItem", fname_add(c.item))
    ap:suspend(c.item, math.ceil((c.stash_ms or 5000) / 1000), "hidden while the Daycare " .. cls .. " loads")
    log:write("Swap", string.format("Daycare flashlight not taken yet: %s hidden from the inventory during %s BeginPlay (now owned: %s)",
        c.item, cls, tostring(df_owned(c.item))))
end

local function scan_pickups()
    local ok, list = pcall(FindAllOf, "Collectible_C")
    if ok and type(list) == "table" then
        for _, actor in ipairs(list) do swap_actor(actor, "scan") end
    end
    for cls in pairs(apcfg.condition_swaps or {}) do
        local ok2, l2 = pcall(FindAllOf, cls)
        if ok2 and type(l2) == "table" then
            for _, actor in ipairs(l2) do swap_conditions(actor, "scan") end
        end
    end
end

local function snapshot(reason)
    local s = read_state()
    if world.fresh_load and last_state ~= nil then
        if not s.ready then return end
        if s.clock_seconds == nil and world.fresh_tries < (cfg.fresh_load_tries or 5) then
            world.fresh_tries = world.fresh_tries + 1
            return
        end
        world.fresh_load = false
        if s.clock_seconds and s.clock_seconds < 0 then
            log:write("AP", string.format("new game (clock %.0f s): this state is the new baseline, the last save's items it may still hold are not checks (%d item(s))",
                s.clock_seconds, #U.sorted_keys(s.inventory)))
            last_state = s
            return
        end
    end
    if last_state == nil then
        log:write("State", "baseline (" .. reason .. ")")
        for _, k in ipairs(U.sorted_keys(s.scalars)) do log:write("State", "  " .. k .. " = " .. s.scalars[k]) end
        log:write("State", "  inventory: " .. table.concat(U.sorted_keys(s.inventory), ", "))
        log:write("State", "  completed missions: " .. table.concat(U.sorted_keys(s.missions), ", "))
        log:write("State", "  tasks done in active missions: " .. table.concat(U.sorted_keys(s.tasks), ", "))
        log:write("State", "  world flags: " .. table.concat(U.sorted_keys(s.flags or {}), ", "))
        for _, n in ipairs(U.sorted_keys(s.inventory)) do
            if ap and select(2, ap:original_name(n)) then inventory_seen(n) end
        end
        if apcfg.send_missions_at_load then
            for _, n in ipairs(U.sorted_keys(s.missions)) do ap_event("mission", n); mission_task_events(n) end
            for _, n in ipairs(U.sorted_keys(s.tasks)) do ap_event("task", n) end
            for _, n in ipairs(U.sorted_keys(s.flags or {})) do ap_event("flag", n) end
            for _, n in ipairs(U.sorted_keys(s.arcade or {})) do ap_event("arcade", n) end
            for _, n in ipairs(U.sorted_keys(s.actors or {})) do ap_event("actor", n) end
            for _, n in ipairs(U.sorted_keys(s.freddy or {})) do ap_event("freddy", n) end
        end
        if s.clock_hour and s.clock_hour <= 6 then
            for h = 0, s.clock_hour do ap_event("clock", tostring(h)) end
        end
        last_state = s
        return
    end
    for _, k in ipairs(U.sorted_keys(s.scalars)) do
        if last_state.scalars[k] ~= s.scalars[k] then
            log:write("Change", string.format("%s: %s -> %s (%s)", k, U.to_str(last_state.scalars[k]), s.scalars[k], reason))
        end
    end
    if s.flags == nil then s.flags = last_state.flags end
    if s.arcade == nil then s.arcade = last_state.arcade end
    if s.actors == nil then s.actors = last_state.actors end
    if s.freddy == nil then s.freddy = last_state.freddy end
    for _, n in ipairs(U.diff_sets(last_state.freddy or {}, s.freddy or {})) do
        log:write("Change", "freddy + " .. n .. " (" .. reason .. ")")
        ap_event("freddy", n)
    end
    local added, removed = U.diff_sets(last_state.flags or {}, s.flags or {})
    for _, n in ipairs(added) do
        log:write("Change", "flag + " .. n .. " (" .. reason .. ")")
        ap_event("flag", n)
    end
    for _, n in ipairs(removed) do log:write("Change", "flag - " .. n .. " (" .. reason .. ")") end
    added = U.diff_sets(last_state.arcade or {}, s.arcade or {})
    for _, n in ipairs(added) do
        log:write("Change", "arcade + " .. n .. " (" .. reason .. ")")
        ap_event("arcade", n)
    end
    added = U.diff_sets(last_state.actors or {}, s.actors or {})
    for _, n in ipairs(added) do
        log:write("Change", "actor + " .. n .. " (" .. reason .. ")")
        ap_event("actor", n)
    end
    added, removed = U.diff_sets(last_state.inventory, s.inventory)
    for _, n in ipairs(added) do
        log:write("Change", "inventory + " .. n .. " (" .. reason .. ")")
        local loc = ap and ap.T.locations.inventory[n]
        local new_check = loc and not ap.checks[loc] and (not ap:is_ap_name(n) or ap.boss_live[n]) and loc or nil
        ap_event("inventory", n)
        popup.inventory_added(n, inventory_seen(n), new_check)
        popup.vanilla_added(n)
    end
    for _, n in ipairs(removed) do log:write("Change", "inventory - " .. n .. " (" .. reason .. ")") end
    added, removed = U.diff_sets(last_state.missions, s.missions)
    for _, n in ipairs(added) do
        log:write("Change", "mission completed + " .. n .. " (" .. reason .. ")")
        ap_event("mission", n)
        mission_task_events(n)
    end
    if s.clock_hour == nil and last_state.clock_hour ~= nil then s.clock_hour = last_state.clock_hour end
    if s.clock_hour ~= last_state.clock_hour then
        log:write("Clock", string.format("hour %s (GetCurrentTimeInSeconds = %s, Faz-Watch text %s)",
            tostring(s.clock_hour), tostring(s.clock_seconds), tostring(s.clock_text)))
        if s.clock_hour and s.clock_hour <= 6 then
            for h = 0, s.clock_hour do ap_event("clock", tostring(h)) end
        end
    end
    for _, n in ipairs(removed) do log:write("Change", "mission completed - " .. n .. " (" .. reason .. ")") end
    added = U.diff_sets(last_state.tasks or {}, s.tasks)
    for _, n in ipairs(added) do
        log:write("Change", "task done + " .. n .. " (" .. reason .. ")")
        ap_event("task", n)
    end
    last_state = s
end

local snapshot_pending = false
local function snapshot_soon(reason)
    if snapshot_pending then return end
    snapshot_pending = true
    ExecuteWithDelay(300, function()
        on_game_thread("snapshot", function()
            snapshot_pending = false
            if world_busy() then return end
            snapshot(reason)
        end)
    end)
end

-- hooks (observe only)
local function short(path) return (path:match("[%.]([^%.]+)$") or path) end

local function make_callback(spec, is_actor)
    return function(self, ...)
        if world.in_minigame then return end
        local params, nparams = { ... }, select("#", ...)
        try("hook " .. spec.path, function()
            if is_actor then
                local actor = U.unwrap(self)
                if spec.swap then swap_actor(actor, "hook " .. short(spec.path)) end
                if spec.swap and spec.path:find(":OnBeginCollect", 1, true) then
                    popup.begun = { path = obj_path(actor), name = U.to_str(prop(actor, "ItemName")),
                                    cls = class_name(actor), t = popup_now() }
                elseif spec.check == "collect" then
                    popup.begun = nil
                end
                local picked = spec.check and U.to_str(prop(actor, "ItemName"))
                if spec.check then ap_event(spec.check, picked) end
                if spec.check == "collect" then empty_opened(actor) end
                if ap and picked then
                    if spec.check == "message" then popup.expect(ap.T.locations.message[picked], picked) end
                    if spec.check == "collect" then popup.collect_opened(picked) end
                end
                if ap and spec.path:find(":Collect_SecurityBadge", 1, true) then
                    popup.expect(popup.badge_location(actor), class_name(actor))
                end
                local dfi = (apcfg.daycare_flashlight or {}).item
                if spec.check == "collect" and dfi and (picked == dfi or picked == (ap and ap:prefix() or "APX_") .. dfi) then
                    df_wake()
                end
                if spec.check then pickup_quiet_until = df_now() + (cfg.after_pickup_quiet_s or 5) end
            elseif spec.voice then
                if not spec.on then return end
                for i = 1, math.min(nparams, spec.max_params or nparams) do
                    voice_heard(U.to_str(U.unwrap(params[i])), short(spec.path))
                end
            end
            if spec.snapshot then snapshot_soon("after " .. short(spec.path)) end
        end)
    end
end

local pending = {}

local function try_register(spec)
    local ok, err, post_id = pcall(RegisterHook, spec.path, make_callback(spec, spec.is_actor))
    if ok then
        spec.pre_id, spec.post_id = err, post_id
        log:write("Hook", "registered " .. spec.path)
        return true
    end
    spec.last_error = tostring(err)
    return false
end

local function register_all(list, is_actor)
    for _, spec in ipairs(list) do
        spec.is_actor = is_actor
        if not try_register(spec) then
            spec.attempts = 0
            pending[#pending + 1] = spec
        end
    end
end

local voice_specs = {}
local function voice_needed()
    for _, id in pairs((ap and ap.T.locations.voice) or {}) do
        if not ap.checks[id] then return true end
    end
    return false
end
local function voice_hooks_tick(has_client, missions)
    for _, line in ipairs(apcfg.voice_lines or {}) do
        if line.done_with_mission and missions and missions[line.done_with_mission] then
            local id = ap.T.locations.voice[line.event]
            if id and not ap.checks[id] then
                log:write("AP", string.format("voice line %s not heard but mission %s is done: sent", line.event, line.done_with_mission))
                ap_event("voice", line.event)
            end
        end
    end
    local want = has_client and voice_needed()
    for _, spec in ipairs(voice_specs) do
        if want and not spec.on then
            if try_register(spec) then spec.on = true end
        elseif not want and spec.on then
            spec.on = false
            if spec.pre_id then pcall(UnregisterHook, spec.path, spec.pre_id, spec.post_id) end
            log:write("Hook", "voice hook off (every voice check is sent): " .. spec.path)
        end
    end
end

function world.hook_class(spec)
    if not world.beginplay_hook or cfg.hook_wait_class == false then return nil end
    return spec.path:match("%.([%w_]+):[^/]*$")
end
local function retry_pending()
    local still = {}
    local now = world_now_ms()
    for _, spec in ipairs(pending) do
        local cls = world.hook_class(spec)
        local seen = cls and world.hook_seen[cls]
        if cls and (not seen or now - seen < (cfg.hook_class_settle_ms or 10000)) then
            if seen == nil then world.hook_seen[cls] = false end
            still[#still + 1] = spec
        elseif cls then
            local okf, fn = pcall(StaticFindObject, spec.path)
            if not (okf and fn ~= nil and is_valid(fn) and try_register(spec)) then
                world.hook_seen[cls] = false
                still[#still + 1] = spec
            end
        else
            local okf, fn = pcall(StaticFindObject, spec.path)
            local loaded = okf and fn ~= nil and is_valid(fn)
            if not loaded then spec.loaded_seen, spec.last_error = nil, "function not loaded" end
            if loaded and not spec.loaded_seen and cfg.hook_settle ~= false then
                spec.loaded_seen = true
                still[#still + 1] = spec
            elseif not (loaded and try_register(spec)) then
                spec.attempts = (spec.attempts or 0) + 1
                if spec.attempts >= cfg.hook_retry_max then
                    log:write("Hook", "giving up on " .. spec.path .. " (" .. tostring(spec.last_error) .. ")")
                else
                    still[#still + 1] = spec
                end
            end
        end
    end
    pending = still
end

-- AP: apply received items
local function fname(name) return FName(name, EFindName.FNAME_Find) end

local game = {
    has = function(name)
        local inv = find("FNAFInventorySystem")
        if not inv then return nil end
        local ok, v = pcall(function() return inv:HasItem(fname(name)) end)
        if not ok then return nil end
        return v == true
    end,
}

local function ak_event(snd)
    for _, p in ipairs(snd.paths or {}) do
        local ok, o = pcall(StaticFindObject, p)
        if ok and is_valid(o) then return o, p end
    end
    local ok, list = pcall(FindAllOf, "AkAudioEvent")
    for _, o in ipairs(ok and type(list) == "table" and list or {}) do
        local full = full_name(o)
        if is_valid(o) and full:match("[%.:/]" .. snd.name .. "$") then return o, full end
    end
    if type(LoadAsset) == "function" then
        for _, p in ipairs(snd.paths or {}) do
            local okl, o = pcall(LoadAsset, p)
            if okl and is_valid(o) then return o, p .. " (LoadAsset)" end
        end
    end
    return nil, nil
end

local function play_sound(snd, label, quiet)
    local L = (label or "Security Alert") .. ": "
    local function note(t) if not quiet then log:write("AP", L .. t) end end
    local greg = find("Gregory_C")
    if not greg then return false end
    local akc_class = StaticFindObject("/Script/AkAudio.AkComponent")
    if is_valid(akc_class) then
        local comp = call(greg, "GetComponentByClass", akc_class)
        if is_valid(comp) then
            local id = tonumber(U.to_str(call(comp, "PostAkEventByName", snd.name)))
            if id and id ~= 0 then
                note(string.format("%s played on Gregory's AkComponent (id %d)", snd.name, id))
                return true
            end
        end
    end
    local gs = StaticFindObject("/Script/AkAudio.Default__AkGameplayStatics")
    if not is_valid(gs) then log:write("AP", L .. "no AkGameplayStatics, " .. snd.name .. " not played"); return false end
    if snd.attach ~= false and pcall(function() gs:PostEventByName(snd.name, greg, false) end) then
        note(snd.name .. " posted on Gregory (PostEventByName)")
        return true
    end
    local x, y, z = location_of(greg)
    local loc, rot = { X = x, Y = y, Z = z }, { Pitch = 0, Yaw = 0, Roll = 0 }
    local ev, where = ak_event(snd)
    if ev then
        local id = gs:PostEventAtLocation(ev, loc, rot, "", greg)
        note(string.format("%s played (%s, id %s)", snd.name, where, U.to_str(id)))
    else
        gs:PostEventAtLocationByName(snd.name, loc, rot, greg)
        note(snd.name .. " posted by name (event asset not found)")
    end
    return true
end

local security_seeded = false
effects_setting = false
local trail = {}
local spawned_ai = {}
local function spawned_force(why)
    local n = 0
    for _, e in pairs(spawned_ai) do if not e.force then e.force = why; n = n + 1 end end
    if n > 0 then log:write("AP", string.format("Security Alert: %d spawned animatronic(s) to remove (%s)", n, why)) end
end
local function completed_mission()
    local ms = find("FNAFMissionSystem")
    if not ms then return nil end
    local names = U.list_from_array(call(ms, "GetCompletedMissions"), function(st) return U.to_str(prop(st, "Name")) end)
    local set = U.set_of(names)
    if set["LostAndFound"] then return "LostAndFound" end
    local keys = U.sorted_keys(set)
    return keys[1]
end
local function spawn_vanny(pick, where, here)
    local sa = apcfg.security_alert or {}
    local before = {}
    for _, v in ipairs(FindAllOf("Vanny_C") or {}) do if is_valid(v) then before[full_name(v)] = true end end
    local gm = nil
    for _, g in ipairs(FindAllOf("MainGameGM_C") or {}) do
        if is_valid(g) and not full_name(g):find("Default__", 1, true) then gm = g end
    end
    if not gm then log:write("AP", "Security Alert: Vanny: no MainGameGM_C, no spawn"); return end
    local ok, err = pcall(function() gm:ForceSpawnVanny() end)
    log:write("AP", string.format("Security Alert: spawn Vanny at %.0f units (%s): ForceSpawnVanny %s",
        pick.d, where, ok and "called" or ("FAILED " .. tostring(err))))
    if not ok then return end
    local tries = 0
    local function look()
        tries = tries + 1
        if world_busy() then return end
        local new = nil
        for _, v in ipairs(FindAllOf("Vanny_C") or {}) do
            if is_valid(v) and not before[full_name(v)] then new = v end
        end
        if not new then
            if tries < (sa.vanny_wait_tries or 10) then
                ExecuteWithDelay(sa.vanny_wait_ms or 300, function() on_game_thread("vanny wait", look) end)
            else
                log:write("AP", string.format("Security Alert: Vanny: no new Vanny_C after %d look(s)", tries))
            end
            return
        end
        local loc = { X = pick.x, Y = pick.y, Z = pick.z }
        local how = "TeleportAI"
        if not pcall(function() new:TeleportAI(loc) end) then
            how = pcall(function() new:K2_SetActorLocation(loc, false, {}, true) end) and "K2_SetActorLocation" or "not moved"
        end
        spawned_ai[full_name(new)] = { t = world_now() }
        local oka = pcall(function() new:SendPositionalAlert(here) end)
        local px, py, pz = location_of(new)
        log:write("AP", string.format("Security Alert: Vanny %s found (look %d), %s, now at (%.0f,%.0f,%.0f), alert %s",
            full_name(new):match("([^%.:]+)$") or "?", tries, how, px, py, pz, oka and "sent" or "FAILED"))
    end
    look()
end
local function capture_off(p)
    local box = prop(p, "PlayerCaptureTrigger")
    if not is_valid(box) then return false, "no PlayerCaptureTrigger" end
    local ok1 = pcall(function() box:SetGenerateOverlapEvents(false) end)
    local ok2 = pcall(function() box:SetCollisionEnabled(0) end)
    return ok1 or ok2, (ok1 and "overlaps off" or "overlaps FAILED") .. ", " .. (ok2 and "collision off" or "collision FAILED")
end
local function trail_tick()
    local sa = apcfg.security_alert or {}
    local greg = find("Gregory_C")
    if not greg then return end
    local x, y, z = location_of(greg)
    if x == 0 and y == 0 and z == 0 then return end
    local last = trail[#trail]
    if last and (last.x - x) ^ 2 + (last.y - y) ^ 2 + (last.z - z) ^ 2 > (sa.jump_dist or 3000) ^ 2 then
        for k in pairs(trail) do trail[k] = nil end
        last = nil
        spawned_force("Gregory moved away at once")
    end
    local step = sa.trail_step or 200
    if last and (last.x - x) ^ 2 + (last.y - y) ^ 2 + (last.z - z) ^ 2 < step * step then return end
    trail[#trail + 1] = { x = x, y = y, z = z }
    if #trail > (sa.trail_max or 120) then table.remove(trail, 1) end
end
local function security_alarm(opts)
    local sa = apcfg.security_alert or {}
    local greg = find("Gregory_C")
    if not greg then log:write("AP", "Security Alert: no Gregory_C when the alarm was due, skipped"); return end
    local x, y, z = location_of(greg)
    if sa.alarm_sound then try("security alert sound", play_sound, sa.alarm_sound) end
    if sa.alarm_music ~= false then
        local n = 0
        for _, t in ipairs(FindAllOf("TensionControl_C") or {}) do
            if is_valid(t) and not full_name(t):find("Default__", 1, true) then
                call(t, "PlayStaffBotAlarmMusic"); n = n + 1
            end
        end
        log:write("AP", string.format("Security Alert: staff bot alarm music on %d TensionControl_C", n))
    end
    if sa.add_spotted ~= false then
        local ws = find("WorldStateSystem")
        if ws then call(ws, "AddSpotted") end
    end
    local ams = live_ams()
    if not ams then log:write("AP", "Security Alert: no AIManagementSystem, no alert"); return end
    local here = { X = x, Y = y, Z = z }
    local function short(o) local f = full_name(o); return f:match("([^%.:]+)$") or f end
    local function alert_one(p, done, notes)
        local key = full_name(p)
        if done and done[key] then return false end
        local can = call(p, "CanReceiveAlert")
        if can == false then notes[#notes + 1] = short(p) .. " CanReceiveAlert=false"; return false end
        local ok, err = pcall(function() p:SendPositionalAlert(here) end)
        if not ok then notes[#notes + 1] = short(p) .. " SendPositionalAlert failed: " .. tostring(err); return false end
        if done then done[key] = true end
        notes[#notes + 1] = short(p) .. " sent"
        return true
    end
    local function alert_all(done, what)
        local alerted, seen, notes = 0, 0, {}
        for _, p in ipairs(U.list_from_array(call(ams, "GetAllAI"), function(e) return e end)) do
            if is_valid(p) then
                seen = seen + 1
                if alert_one(p, done, notes) then alerted = alerted + 1 end
            end
        end
        log:write("AP", string.format("Security Alert at (%.0f,%.0f,%.0f)%s: %d of %d AI sent to Gregory [%s]",
            x, y, z, what, alerted, seen, table.concat(notes, "; ")))
    end
    local done = {}
    if sa.spawn ~= false and not (opts and opts.spawn == false) then
        local existing = {}
        for _, t in ipairs(U.list_from_array(call(ams, "GetExistingPawnTypes"),
                function(e) return tonumber(e) or tonumber(U.to_str(e)) end)) do
            existing[t] = true
        end
        local allowed = {}
        local ws_state = nil
        do
            local ws = find("WorldStateSystem")
            if ws then
                ws_state = tonumber(U.to_str(call(ws, "GetWorldState")))
                if ws_state == nil then ws_state = tonumber(U.to_str(prop(ws, "WorldState"))) end
            end
        end
        local left_out = {}
        for _, t in ipairs(sa.spawn_types or { 0, 1, 2 }) do
            local need = (sa.type_states or {})[t]
            local ok_state = need == nil
            if need then for _, st in ipairs(need) do if st == ws_state then ok_state = true end end end
            for _, v in pairs((sa.spawn_props or {})[t] or {}) do
                if v == "@completed_mission" and not completed_mission() then ok_state = false end
            end
            if ok_state then allowed[#allowed + 1] = t else left_out[#left_out + 1] = (sa.type_names or {})[t] or tostring(t) end
        end
        if #left_out > 0 then
            log:write("AP", string.format("Security Alert: world state %s, left out: %s", tostring(ws_state), table.concat(left_out, ", ")))
        end
        local types = {}
        for _, t in ipairs(allowed) do if not existing[t] then types[#types + 1] = t end end
        if #types == 0 then types = allowed end
        if #types == 0 then
            log:write("AP", "Security Alert: no spawn type configured, no spawn")
        else
            local typ = types[math.random(#types)]
            local near, best, best_d = {}, nil, nil
            for _, sp in ipairs(U.list_from_array(call(ams, "GetAllSpawnPoints"), function(e) return e end)) do
                if is_valid(sp) then
                    local use = prop(sp, "bUseType") == true
                    local sp_t = tonumber(U.to_str(prop(sp, "AIType")))
                    if not use or sp_t == typ then
                        local sx, sy, sz = location_of(sp)
                        local d = math.sqrt((sx - x) ^ 2 + (sy - y) ^ 2)
                        if math.abs(sz - z) <= (sa.spawn_max_dz or 350) and d >= (sa.spawn_min or 600) then
                            if d <= (sa.spawn_max or 2500) then near[#near + 1] = { x = sx, y = sy, z = sz, d = d } end
                            if not best_d or d < best_d then best, best_d = { x = sx, y = sy, z = sz, d = d }, d end
                        end
                    end
                end
            end
            local pick, where = nil, nil
            local close, mid = {}, {}
            for _, c in ipairs(trail) do
                local d = math.sqrt((c.x - x) ^ 2 + (c.y - y) ^ 2)
                if math.abs(c.z - z) <= (sa.spawn_max_dz or 250) and d >= (sa.spawn_min or 600) then
                    if d <= (sa.spawn_near or 1500) then close[#close + 1] = { x = c.x, y = c.y, z = c.z, d = d }
                    elseif d <= (sa.spawn_max or 2500) then mid[#mid + 1] = { x = c.x, y = c.y, z = c.z, d = d } end
                end
            end
            if #close > 0 then pick, where = close[math.random(#close)], "Gregory's trail"
            elseif #mid > 0 then pick, where = mid[math.random(#mid)], "Gregory's trail (farther)" end
            if not pick and #near > 0 then pick, where = near[math.random(#near)], "spawn point" end
            if not pick then
                log:write("AP", string.format("Security Alert: no trail spot nor spawn point within %d units (trail %d spots, closest spawn point %s): no spawn",
                    sa.spawn_max or 2500, #trail, best_d and string.format("%.0f", best_d) or "none"))
            elseif typ == (sa.vanny_type or 100) then
                spawn_vanny(pick, where, here)
            else
                local ok, pawn = pcall(function()
                    return ams:SpawnAITypeAtLocation(typ, { X = pick.x, Y = pick.y, Z = pick.z }, false)
                end)
                log:write("AP", string.format("Security Alert: spawn type %d (%s) at %.0f units (%s; %d spawn point(s) in range): %s",
                    typ, (sa.type_names or {})[typ] or "?", pick.d, where, #near,
                    (ok and is_valid(pawn)) and short(pawn) or ("FAILED " .. tostring(pawn))))
                if ok and is_valid(pawn) then
                    spawned_ai[full_name(pawn)] = { t = world_now() }
                    local notes = {}
                    local sets = {}
                    for k, v in pairs((sa.spawn_props or {})[typ] or {}) do
                        local val, shown = v, tostring(v)
                        if v == "@completed_mission" then
                            local m = completed_mission() or "None"
                            val, shown = FName(m), m
                        elseif type(v) == "string" and v:sub(1, 6) == "FName:" then val = FName(v:sub(7)) end
                        local okp, errp = pcall(function() pawn[k] = val end)
                        if okp and k == "CaughtMissionName" then
                            shown = shown .. " (now " .. U.to_str(prop(pawn, k)) .. ")"
                        end
                        sets[#sets + 1] = k .. (okp and ("=" .. shown) or (" FAILED " .. tostring(errp)))
                    end
                    if #sets > 0 then
                        table.sort(sets)
                        notes[#notes + 1] = "set " .. table.concat(sets, ", ")
                    end
                    for _, ct in ipairs(sa.capture_off or {}) do
                        if ct == typ then
                            local okc, what = capture_off(pawn)
                            spawned_ai[full_name(pawn)].catch = okc
                            notes[#notes + 1] = "capture box: " .. what
                        end
                    end
                    if not alert_one(pawn, done, notes) then
                        local ok2, err2 = pcall(function() pawn:StartMoveTo(here) end)
                        notes[#notes + 1] = ok2 and "StartMoveTo Gregory" or ("StartMoveTo failed: " .. tostring(err2))
                        if ok2 then done[full_name(pawn)] = true end
                    end
                    local px, py, pz = location_of(pawn)
                    log:write("AP", string.format("Security Alert: spawned one at (%.0f,%.0f,%.0f): %s", px, py, pz,
                        table.concat(notes, "; ")))
                end
            end
        end
    end
    alert_all(done, "")
    ExecuteWithDelay(sa.second_alert_ms or 1500, function()
        on_game_thread("security alert again", function()
            if world_busy() then return end
            alert_all(nil, " (second pass)")
        end)
    end)
end

local function catch_tick()
    local active = false
    for _, e in pairs(spawned_ai) do if e.catch then active = true end end
    if not active then return end
    local sa = apcfg.security_alert or {}
    local ams = live_ams()
    local greg = find("Gregory_C")
    if not ams or not greg then return end
    local gx, gy, gz = location_of(greg)
    for _, p in ipairs(U.list_from_array(call(ams, "GetAllAI"), function(e) return e end)) do
        if is_valid(p) then
            local key = full_name(p)
            local e = spawned_ai[key]
            if e and e.catch then
                capture_off(p)
                local px, py, pz = location_of(p)
                local d = math.sqrt((px - gx) ^ 2 + (py - gy) ^ 2 + (pz - gz) ^ 2)
                local methods = sa.scare_methods or { "Jumpscare", "On Jumpscare", "ForceJumpscarePlayer" }
                e.tries = e.tries or 0
                if e.tries < #methods and d <= (sa.scare_dist or 300)
                        and (not e.next_try or world_now_ms() >= e.next_try) then
                    e.tries = e.tries + 1
                    e.next_try = world_now_ms() + (sa.scare_retry_ms or 1500)
                    local m = methods[e.tries]
                    if e.tries == 1 then pcall(function() p.CurrentJumpscareTarget = greg end) end
                    local ok, err = pcall(function()
                        if m == "ForceJumpscarePlayer" then p:ForceJumpscarePlayer() else p[m](p, greg) end
                    end)
                    log:write("AP", string.format("Security Alert: spawned %s at %.0f units from Gregory, try %d: %s %s",
                        key:match("([^%.:]+)$") or key, d, e.tries, m, ok and "called" or ("FAILED " .. tostring(err))))
                end
            end
        end
    end
end

local function despawn_tick()
    if next(spawned_ai) == nil then return end
    local sa = apcfg.security_alert or {}
    local ams = live_ams()
    local greg = find("Gregory_C")
    if not ams or not greg then return end
    local gx, gy, gz = location_of(greg)
    local now, alive = world_now(), {}
    for key, e in pairs(spawned_ai) do
        local okp, p = pcall(StaticFindObject, key:match("^%S+%s+(.+)$") or key)
        if okp and is_valid(p) and full_name(p) == key then
            alive[key] = true
            local age = now - e.t
            if e.force or age >= (sa.spawn_lifetime_s or 90) then
                local px, py, pz = location_of(p)
                local d = math.sqrt((px - gx) ^ 2 + (py - gy) ^ 2 + (pz - gz) ^ 2)
                if d >= (e.force and (sa.force_keep_dist or 500) or (sa.keep_dist or 1500)) then
                    pcall(function() ams:UnRegisterAI(p) end)
                    local ok, err = pcall(function() p:K2_DestroyActor() end)
                    spawned_ai[key] = nil
                    log:write("AP", string.format("Security Alert: spawned %s removed (%s, %.0f s, %.0f units from Gregory)%s",
                        key:match("([^%.:]+)$") or key, e.force or "lifetime", age, d, ok and "" or (": " .. tostring(err))))
                end
            end
        end
    end
    for key, e in pairs(spawned_ai) do
        if not alive[key] and now - e.t > (sa.spawn_lifetime_s or 90) then spawned_ai[key] = nil end
    end
end

local function security_alert(a)
    local sa = apcfg.security_alert or {}
    if not security_seeded then math.randomseed(os.time()); security_seeded = true end
    if not find("Gregory_C") then error("no Gregory_C") end
    if sa.voice then try("security alert voice", play_sound, sa.voice) end
    local wait = sa.voice and (sa.alarm_after_ms or 0) or 0
    if wait > 0 then
        ExecuteWithDelay(wait, function()
            on_game_thread("security alarm", function()
                if world_busy() then log:write("AP", "Security Alert: world switch before the alarm, skipped"); return end
                security_alarm()
            end)
        end)
    else
        security_alarm()
    end
end

local dl = { pending = 0, active = nil, said = {}, tries = 0, OFF = -1 }
local function dl_cfg() return apcfg.death_link or {} end
function dl.cdo_set(k)
    if not (k.cdo and k.props) then return nil end
    local okc, cdo = pcall(StaticFindObject, k.cdo)
    if not (okc and is_valid(cdo)) then return { note = "class default not found" } end
    local old, set = { obj = cdo }, {}
    for pk, v in pairs(k.props) do
        local m = v == "@completed_mission" and completed_mission() or nil
        if m then
            local was = U.to_str(prop(cdo, pk))
            if pcall(function() cdo[pk] = FName(m) end) then
                old[pk] = was or "None"
                set[#set + 1] = pk .. "=" .. m
            end
        end
    end
    old.note = #set > 0 and ("class default " .. table.concat(set, ", ") .. " for the spawn") or "class default unchanged"
    return old
end
function dl.cdo_restore(old)
    if not (old and old.obj) then return end
    for pk, v in pairs(old) do
        if pk ~= "obj" and pk ~= "note" then pcall(function() old.obj[pk] = FName(v) end) end
    end
end
function dl.saves_off(k)
    if not k.no_save then return nil end
    if dl.no_save then return "saving already off" end
    local ss = find("FNAFSaveGameSystem")
    if not ss then return "saving: no FNAFSaveGameSystem" end
    if call(ss, "IsSavingAllowed") == false then return "saving was already off (game)" end
    local ok = pcall(function() ss:SetIsSavingAllowed(false) end)
    if not ok then return "saving off FAILED" end
    dl.no_save = { switches = world.switches, until_s = os.time() + (dl_cfg().no_save_s or 120) }
    return "saving off until the reload"
end
function dl.saves_back()
    local n = dl.no_save
    if not n or world_busy() or (world.switches == n.switches and os.time() < n.until_s) then return end
    local ss = find("FNAFSaveGameSystem")
    if not ss then return end
    dl.no_save = nil
    local ok = pcall(function() ss:SetIsSavingAllowed(true) end)
    log:write("AP", "Death Link: saving allowed again" .. (ok and "" or " FAILED"))
end
local function dl_behavior()
    if dl.override ~= nil then return dl.override end
    return ap and ap.options.death_link_behavior
end
local function dl_step(text)
    if dl.last_step == text then return end
    dl.last_step = text
    trace_step("death link step: " .. text)
    if (apcfg.death_link or {}).trace ~= false then log:write("AP", "Death Link step: " .. text) end
end
local function dl_say(slot, text)
    if dl.said[slot] ~= text then dl.said[slot] = text; log:write("AP", "Death Link: " .. text) end
end
local function world_state_now()
    local ws = find("WorldStateSystem")
    if not ws then return nil end
    local s = tonumber(U.to_str(call(ws, "GetWorldState")))
    if s == nil then s = tonumber(U.to_str(prop(ws, "WorldState"))) end
    return s
end
local function dl_unusable(key, for_random)
    local c = dl_cfg()
    local k = (c.kinds or {})[key]
    if not k then return "unknown kind" end
    if k.none then return k.none end
    if (dl.bad or {})[key] then return "could not be spawned anywhere, twice this session" end
    if (dl.skip or {})[key] then return "could not be spawned anywhere for this death" end
    if k.staff then return nil end
    if k.untested then
        if for_random and not c.random_untested then return "never tried in game" end
        if not for_random and c.try_untested == false then return "never tried in game (try_untested off)" end
    end
    if k.states and k.anywhere and for_random and not k.random_anywhere then
        local s, ok = world_state_now(), false
        for _, st in ipairs(k.states) do if st == s then ok = true end end
        if not ok then return "outside his hours (his jumpscare actor, not in Random)" end
    end
    if k.states and not k.anywhere then
        local s, ok = world_state_now(), false
        for _, st in ipairs(k.states) do if st == s then ok = true end end
        if not ok then return "only during his own phases (world state " .. tostring(s) .. ")" end
    end
    if k.needs_mission and not completed_mission() then
        return "no mission completed yet (she would take Gregory to Lost and Found)"
    end
    return nil
end
local function dl_choose(b)
    local c = dl_cfg()
    local order = c.order or {}
    local key = order[tonumber(b) or 13] or "random_without_staffbot"
    if key == "random" or key == "random_without_staffbot" then
        local pool = {}
        for n = 0, 31 do
            local k = order[n]
            if k and k ~= "random" and k ~= "random_without_staffbot"
                    and not (key == "random_without_staffbot" and k == "staff_bot")
                    and not dl_unusable(k, true) then
                pool[#pool + 1] = k
            end
        end
        if #pool == 0 then return nil, key .. ": nothing usable now" end
        local pick = pool[math.random(#pool)]
        return pick, key .. " -> " .. pick
    end
    local why = dl_unusable(key, false)
    if not why then return key, key end
    local subs = {}
    for _, k in ipairs(c.substitutes or { "chica", "roxy", "monty", "endos" }) do
        if not dl_unusable(k, true) then subs[#subs + 1] = k end
    end
    if #subs == 0 then return nil, key .. ": " .. why .. "; no substitute usable" end
    local pick = subs[math.random(#subs)]
    return pick, key .. ": " .. why .. "; " .. pick .. " instead"
end
if type(TEST_HOOKS) == "table" then TEST_HOOKS.dl_choose, TEST_HOOKS.world = dl_choose, world end
local function dl_spots(greg, k)
    local c = dl_cfg()
    local x, y, z = location_of(greg)
    local d = c.front_dist or 80
    local out = {}
    local ok, fv = pcall(function() return greg:GetActorForwardVector() end)
    local fx = ok and tonumber(U.to_str(prop(fv, "X"))) or nil
    local fy = ok and tonumber(U.to_str(prop(fv, "Y"))) or nil
    local facing = fx and fy and (fx ~= 0 or fy ~= 0)
    if facing and k and k.behind_first then
        out[#out + 1] = { { X = x - fx * d, Y = y - fy * d, Z = z }, string.format("%d units behind Gregory", d) }
    end
    if facing then
        out[#out + 1] = { { X = x + fx * d, Y = y + fy * d, Z = z }, string.format("%d units in front of Gregory", d) }
    end
    local near = {}
    for _, t in ipairs(trail) do
        local dd = math.sqrt((t.x - x) ^ 2 + (t.y - y) ^ 2)
        if math.abs(t.z - z) <= 150 and dd >= 100 and dd <= (c.trail_max_dist or 1500) then
            near[#near + 1] = { t = t, d = dd }
        end
    end
    table.sort(near, function(a, b) return a.d < b.d end)
    for i = 1, math.min(#near, c.trail_tries or 3) do
        local t = near[i].t
        out[#out + 1] = { { X = t.x, Y = t.y, Z = t.z }, string.format("Gregory's trail, %.0f units", near[i].d) }
    end
    if facing and not (k and k.behind_first) then
        out[#out + 1] = { { X = x - fx * d, Y = y - fy * d, Z = z }, string.format("%d units behind Gregory", d) }
    end
    out[#out + 1] = { { X = x, Y = y, Z = z }, "on Gregory" }
    return out
end
local function game_death_count()
    return tonumber(last_state and last_state.scalars["WorldState.DeathCount"])
end
local function find_func(obj, fname)
    local ok, c = pcall(function() return obj:GetClass() end)
    for _ = 1, 12 do
        if not ok or not is_valid(c) then return nil end
        local path = full_name(c):match("^%S+ (.+)$")
        if path then
            local okf, f = pcall(StaticFindObject, path .. ":" .. fname)
            if okf and is_valid(f) then return f end
        end
        ok, c = pcall(function() return c:GetSuperStruct() end)
    end
    return nil
end
local function has_func(obj, fname) return find_func(obj, fname) ~= nil end
local function func_params(f)
    local names = {}
    local ok = pcall(function()
        f:ForEachProperty(function(p) names[#names + 1] = U.to_str(call(p, "GetFName")) end)
    end)
    return ok and names or nil
end
local function call_no_params(obj, fname, force)
    local f = find_func(obj, fname)
    if not f then return fname .. ": not on this class" end
    local params = func_params(f)
    if params == nil and force then
        local okf = pcall(function() obj[fname](obj) end)
        return fname .. (okf and " called (parameters unreadable)" or " FAILED (parameters unreadable)")
    end
    if params == nil then return fname .. ": parameters unreadable, not called" end
    if #params > 0 then return fname .. ": takes " .. table.concat(params, ", ") .. ", not called" end
    local ok = pcall(function() obj[fname](obj) end)
    return fname .. (ok and " called" or " FAILED")
end
local function live_freddy()
    local o = cached("Freddy_C live")
    if o then return o end
    local fred = nil
    for _, f in ipairs(FindAllOf("Freddy_C") or {}) do
        if is_valid(f) and not (obj_path(f) or "Default__"):find("Default__", 1, true) then fred = f end
    end
    if fred then remember("Freddy_C live", fred) end
    return fred
end
local function dl_kill_freddy(key, how)
    local c = dl_cfg()
    local k = (c.kinds or {})[key] or {}
    local greg = find("Gregory_C")
    dl_step("Freddy: the one in the world")
    local fred = live_freddy()
    if not fred then
        log:write("AP", "Death Link (" .. how .. "): no Freddy in the world: another animatronic")
        return "other"
    end
    local gx, gy, gz = location_of(greg)
    local d = k.dist or 150
    local okf, fv = pcall(function() return greg:GetActorForwardVector() end)
    local fx = okf and tonumber(U.to_str(prop(fv, "X"))) or 1
    local fy = okf and tonumber(U.to_str(prop(fv, "Y"))) or 0
    local loc = { X = gx + fx * d, Y = gy + fy * d, Z = gz }
    dl_step("Freddy: moved in front of Gregory")
    local okm = pcall(function() fred:K2_SetActorLocation(loc, false, {}, true) end)
    local yaw = math.deg(math.atan(gy - loc.Y, gx - loc.X))
    local okr = pcall(function() fred:K2_SetActorRotation({ Pitch = 0, Yaw = yaw, Roll = 0 }, true) end)
    ap:expect_own_death(world_now() + (c.own_death_s or 60))
    local key_name = full_name(fred)
    local short = key_name:match("([^%.:]+)$") or key_name
    dl.active = { key = key_name, short = short, kind = key, since = world_now_ms(), deaths = game_death_count(),
                  step = 0, next_ms = world_now_ms() + (c.instant_delay_ms or 0),
                  methods = k.methods or { "Jumpscare", "LethalJumpscareBPI" }, lookup = live_freddy }
    local px, py, pz = location_of(fred)
    log:write("AP", string.format("Death Link (%s): %s %s %d units in front of Gregory%s, now at (%.0f,%.0f,%.0f)",
        how, short, okm and "moved" or "NOT moved", d, okr and ", facing him" or "", px, py, pz))
    return true
end
function dl.staff_bot_show(k)
    if k.show_bot == false then return end
    local bot = nil
    for _, cn in ipairs(dl.staff_classes or k.bot_classes or {}) do
        for _, b in ipairs(FindAllOf(cn) or {}) do
            if not bot and is_valid(b) and not (full_name(b) or "Default__"):find("Default__", 1, true) then bot = b end
        end
    end
    if not bot and not dl.staff_scanned and k.bot_scan ~= false then
        dl.staff_scanned = true
        local seen, found = {}, {}
        pcall(ForEachUObject, function(o)
            local okn, fn = pcall(function() return o:GetFullName() end)
            if not okn or type(fn) ~= "string" then return end
            local cn = fn:match("^(%S+) ")
            if cn and not seen[cn] and fn:find("PersistentLevel", 1, true) and not fn:find("Default__", 1, true)
                    and (cn:find("StaffBot", 1, true) or cn:find("Staffbot", 1, true) or cn:find("SecurityBot", 1, true)) then
                seen[cn] = true
                local skip = false
                for _, no in ipairs(k.bot_skip or { "Collectible", "PlayerControlled", "Caution", "Head", "Manager", "Spawner",
                                            "InteractionPoint", "_ABP", "LINK", "Controller" }) do
                    if cn:find(no, 1, true) then skip = true end
                end
                if not skip then found[#found + 1] = cn end
            end
        end)
        local all = {}
        for cn in pairs(seen) do all[#all + 1] = cn end
        table.sort(all)
        log:write("AP", "Death Link: staff bot classes in the world: " .. (#all > 0 and table.concat(all, ", ") or "none")
            .. (#found > 0 and (" (used: " .. table.concat(found, ", ") .. ")") or ""))
        dl.staff_classes = found
        for _, cn in ipairs(found) do
            for _, b in ipairs(FindAllOf(cn) or {}) do
                if not bot and is_valid(b) and not (full_name(b) or "Default__"):find("Default__", 1, true) then bot = b end
            end
        end
    end
    if not bot then log:write("AP", "Death Link: no staff bot in the world to show"); return end
    local greg = find("Gregory_C")
    local gx, gy, gz = location_of(greg)
    local bx, by, bz = location_of(bot)
    local okr0, rot0 = pcall(function() return bot:K2_GetActorRotation() end)
    local yaw0 = okr0 and tonumber(U.to_str(prop(rot0, "Yaw"))) or 0
    local d = k.bot_dist or 250
    local okf, fv = pcall(function() return greg:GetActorForwardVector() end)
    local fx = okf and tonumber(U.to_str(prop(fv, "X"))) or 1
    local fy = okf and tonumber(U.to_str(prop(fv, "Y"))) or 0
    local loc = { X = gx + fx * d, Y = gy + fy * d, Z = gz }
    local okm = pcall(function() bot:K2_SetActorLocation(loc, false, {}, true) end)
    local yaw = math.deg(math.atan(gy - loc.Y, gx - loc.X))
    pcall(function() bot:K2_SetActorRotation({ Pitch = 0, Yaw = yaw, Roll = 0 }, true) end)
    local path, short = obj_path(bot), (full_name(bot):match("([^%.:]+)$") or "?")
    log:write("AP", string.format("Death Link: staff bot %s %s %d units in front of Gregory, back in %.1f s", short,
        okm and "put" or "NOT put", d, (k.bot_show_ms or 3000) / 1000))
    if not okm then return end
    ExecuteWithDelay(k.bot_show_ms or 3000, function()
        on_game_thread("death link staff bot back", function()
            local okb, b = pcall(StaticFindObject, path)
            if not (okb and is_valid(b)) then return end
            pcall(function() b:K2_SetActorLocation({ X = bx, Y = by, Z = bz }, false, {}, true) end)
            pcall(function() b:K2_SetActorRotation({ Pitch = 0, Yaw = yaw0, Roll = 0 }, true) end)
            log:write("AP", "Death Link: staff bot " .. short .. " put back")
        end)
    end)
end
function dl.kill_moon(key, how)
    local c = dl_cfg()
    local k = (c.kinds or {})[key] or {}
    local cn = k.seq_class or "HourlyMoonManSequence_C"
    local function seq_now()
        for _, s in ipairs(FindAllOf(cn) or {}) do
            if is_valid(s) and not (full_name(s) or "Default__"):find("Default__", 1, true) then return s end
        end
        return nil
    end
    dl_step("Moon: the hourly Moon sequence")
    local seq = seq_now()
    local s = world_state_now()
    local his = true
    if k.states then
        his = false
        for _, st in ipairs(k.states) do if st == s then his = true end end
    end
    if seq and not his and k.anywhere and k.actor ~= true then
        log:write("AP", "Death Link (" .. how .. "): not his hours: his sequence's KillPlayer anyway")
        his = true
    end
    if not (seq and his) then
        if k.anywhere and k.actor == true then
            log:write("AP", "Death Link (" .. how .. "): " .. (seq and "not his hours" or ("no " .. cn)) .. ": his jumpscare actor")
            return dl.moon_actor(key, how)
        end
        log:write("AP", "Death Link (" .. how .. "): no " .. cn .. " in the world (not his hours?): another animatronic")
        return "other"
    end
    ap:expect_own_death(world_now() + (c.own_death_s or 60))
    dl_step("Moon: " .. (k.kill_func or "KillPlayer"))
    local note = call_no_params(seq, k.kill_func or "KillPlayer", true)
    local key_name = full_name(seq)
    dl.active = { key = key_name, short = "Moon (" .. cn .. ")", kind = key, since = world_now_ms(), deaths = game_death_count(),
                  step = 0, next_ms = world_now_ms() + (k.retry_ms or 5000), methods = k.methods or {}, lookup = seq_now }
    log:write("AP", "Death Link (" .. how .. "): Moon's own kill: " .. note)
    return true
end
function dl.staff_bot_catch(k)
    local greg = find("Gregory_C")
    if not greg then return false end
    local gx, gy, gz = location_of(greg)
    local d = k.catch_dist or 150
    local okf, fv = pcall(function() return greg:GetActorForwardVector() end)
    local fx = okf and tonumber(U.to_str(prop(fv, "X"))) or 1
    local fy = okf and tonumber(U.to_str(prop(fv, "Y"))) or 0
    local loc = { X = gx + fx * d, Y = gy + fy * d, Z = gz }
    local bot, spawned, from = nil, false, nil
    if k.bot_type then
        local ams = live_ams()
        dl_step("staff bot: SpawnAITypeAtLocation type " .. tostring(k.bot_type))
        local ok, p = false, nil
        if ams then ok, p = pcall(function() return ams:SpawnAITypeAtLocation(k.bot_type, loc, false) end) end
        if ok and is_valid(p) and has_func(p, "NonLethalJumpScare") then
            bot, spawned, from = p, true, "spawned (type " .. k.bot_type .. ")"
        elseif ok and is_valid(p) then
            log:write("AP", "Death Link: AI type " .. k.bot_type .. " gave " .. class_name(p) .. ", not a staff bot: removed")
            pcall(function() p:K2_DestroyActor() end)
        else
            log:write("AP", "Death Link: no staff bot from AI type " .. tostring(k.bot_type))
        end
    end
    local bx, by, bz, yaw0
    if not bot then
        local classes = (k.bot_classes and #k.bot_classes > 0) and k.bot_classes
            or { "StaffBotSecurityPatrol_C", "StaffBotTalent_C", "FollowSplineStaffbot_C" }
        for _, cn in ipairs(classes) do
            for _, b in ipairs(FindAllOf(cn) or {}) do
                if not bot and is_valid(b) and not (full_name(b) or "Default__"):find("Default__", 1, true)
                        and has_func(b, "NonLethalJumpScare") then
                    bot, from = b, "of the world (" .. cn .. ")"
                end
            end
        end
        if not bot then return false end
        bx, by, bz = location_of(bot)
        local okr0, rot0 = pcall(function() return bot:K2_GetActorRotation() end)
        yaw0 = okr0 and tonumber(U.to_str(prop(rot0, "Yaw"))) or 0
        pcall(function() bot:K2_SetActorLocation(loc, false, {}, true) end)
    end
    local yaw = math.deg(math.atan(gy - loc.Y, gx - loc.X))
    pcall(function() bot:K2_SetActorRotation({ Pitch = 0, Yaw = yaw, Roll = 0 }, true) end)
    dl_step("staff bot: NonLethalJumpScare")
    local okj = pcall(function() bot:NonLethalJumpScare(greg, false) end)
    local path, short = obj_path(bot), (full_name(bot):match("([^%.:]+)$") or "?")
    log:write("AP", string.format("Death Link: staff bot %s %s, %d units in front of Gregory: NonLethalJumpScare %s",
        short, from, d, okj and "called" or "FAILED"))
    ExecuteWithDelay(k.alert_after_ms or 1500, function()
        on_game_thread("death link staff bot alert", function()
            local okb, b = pcall(StaticFindObject, path)
            if not (okb and is_valid(b)) then return end
            dl_step("staff bot: Send Alert")
            local oka = has_func(b, "Send Alert") and pcall(function() b["Send Alert"](b, true) end)
            if not oka then security_alarm({ spawn = false }) end
            log:write("AP", "Death Link: staff bot " .. short .. (oka and ": Send Alert called" or ": Send Alert FAILED, the alarm instead"))
            ExecuteWithDelay(k.gone_after_ms or 500, function()
                on_game_thread("death link staff bot gone", function()
                    local okg, g = pcall(StaticFindObject, path)
                    if not (okg and is_valid(g)) then return end
                    if spawned then
                        pcall(function() g:K2_DestroyActor() end)
                    else
                        pcall(function() g:K2_SetActorLocation({ X = bx, Y = by, Z = bz }, false, {}, true) end)
                        pcall(function() g:K2_SetActorRotation({ Pitch = 0, Yaw = yaw0, Roll = 0 }, true) end)
                    end
                    log:write("AP", "Death Link: staff bot " .. short .. (spawned and " removed" or " put back"))
                end)
            end)
        end)
    end)
    return true
end
function dl.obj(path)
    if not path then return nil end
    local ok, o = pcall(StaticFindObject, path)
    if ok and is_valid(o) then return o end
    return nil
end
function dl.front_of(greg, d)
    local gx, gy, gz = location_of(greg)
    local okf, fv = pcall(function() return greg:GetActorForwardVector() end)
    local fx = okf and tonumber(U.to_str(prop(fv, "X"))) or 1
    local fy = okf and tonumber(U.to_str(prop(fv, "Y"))) or 0
    local loc = { X = gx + fx * d, Y = gy + fy * d, Z = gz }
    return loc, math.deg(math.atan(gy - loc.Y, gx - loc.X)), { X = gx, Y = gy, Z = gz }
end
function dl.staff_alert_task(b)
    local ctrl = call(b, "GetController")
    if not is_valid(ctrl) then return false, "no controller for the SendAlert task" end
    local cp = obj_path(ctrl) or "?"
    local own, tree = nil, nil
    for _, t in ipairs(FindAllOf("SendAlert_C") or {}) do
        local fn = is_valid(t) and full_name(t) or "Default__"
        if not fn:find("Default__", 1, true) then
            if fn:find(cp, 1, true) then own = own or t else tree = tree or t end
        end
    end
    local task = own or tree
    if not task then return false, "no SendAlert_C task loaded" end
    local alert = U.to_str(prop(task, "Alert"))
    dl_step("staff bot: the SendAlert task")
    local ok, err = pcall(function() task:ReceiveExecuteAI(ctrl, b) end)
    return ok, string.format("the game's SendAlert task (%s, Alert %s) %s", own and "its own" or "the behavior tree's",
        tostring(alert), ok and "run" or ("FAILED: " .. tostring(err)))
end
function dl.staff_vanilla(k, trap)
    local tag = trap and "Security Alert" or "Death Link"
    local greg = find("Gregory_C")
    if not greg then return false end
    local _, _, gloc = dl.front_of(greg, 0)
    local classes = (k.bot_classes and #k.bot_classes > 0) and k.bot_classes
        or { "StaffBotSecurityPatrol_C", "StaffBotTalent_C" }
    local bot, best, diag = nil, nil, {}
    local spawned, new_how = false, "the game's spawner"
    local base_path = k.base_class or "/Game/Blueprints/AI/StaffBot/StaffBotBase.StaffBotBase_C"
    local loc, yaw = dl.front_of(greg, k.catch_dist or 150)
    if k.spawn ~= false then
        local sps, mgr, md = {}, nil, nil
        for _, s in ipairs(FindAllOf("StaffBotSpawnerComponent_C") or {}) do
            if is_valid(s) and not (full_name(s) or "Default__"):find("Default__", 1, true) then
                local nt = #(U.list_from_array(prop(s, "TypesToAlert"), function(e) return e end) or {})
                sps[#sps + 1] = { s = s, nt = nt, ty = U.to_str(prop(s, "StaffBotType")) }
            end
        end
        table.sort(sps, function(a, b) return a.nt > b.nt end)
        for _, m in ipairs(FindAllOf("SplinePathwayManager_C") or {}) do
            if is_valid(m) and not (full_name(m) or "Default__"):find("Default__", 1, true) then
                local mx, my, mz = location_of(m)
                local dd = mx and ((mx - gloc.X) ^ 2 + (my - gloc.Y) ^ 2 + (mz - gloc.Z) ^ 2) or 1e18
                if not mgr or dd < md then mgr, md = m, dd end
            end
        end
        local tried = {}
        for _, e in ipairs(sps) do
            if bot or #tried >= (k.spawner_tries or 3) then break end
            dl_step("staff bot: spawner SpawnBot (type " .. tostring(e.ty) .. ")")
            local before = #(U.list_from_array(prop(e.s, "SpawnedStaffBots"), function(x) return x end) or {})
            local ok, r = pcall(function() return e.s:SpawnBot(loc, mgr) end)
            if ok and is_valid(r) then bot = r end
            if not bot then
                local list = U.list_from_array(prop(e.s, "SpawnedStaffBots"), function(x) return x end) or {}
                if #list > before and is_valid(list[#list]) then bot = list[#list] end
            end
            tried[#tried + 1] = string.format("type %s / %d alert type(s): %s", tostring(e.ty), e.nt, bot and "spawned" or (ok and "nothing" or "FAILED"))
        end
        diag[#diag + 1] = string.format("%d spawner(s), spline manager %s [%s]", #sps, mgr and "found" or "none", table.concat(tried, "; "))
        spawned = bot ~= nil
    end
    if not bot and k.spawn_actor ~= false then
        local cp = k.spawn_class or "/Game/Blueprints/AI/StaffBot/Security/Patrol/StaffBotSecurityPatrol.StaffBotSecurityPatrol_C"
        local cls = dl.obj(cp)
        if not cls and type(LoadAsset) == "function" and not dl.staff_load_ms then
            dl.staff_load_ms = world_now_ms()
            dl_step("staff bot: LoadAsset " .. cp)
            local okl = pcall(LoadAsset, cp)
            log:write("AP", string.format(tag .. ": staff bot: no spawner, its class not loaded: LoadAsset %s, the spawn in %.1f s",
                okl and "called" or "FAILED", (k.load_wait_ms or 2000) / 1000))
            return "wait"
        end
        local okw, world = false, nil
        if cls then okw, world = pcall(function() return greg:GetWorld() end) end
        if cls and okw and is_valid(world) then
            dl_step("staff bot: World:SpawnActor")
            local oks, a = pcall(function() return world:SpawnActor(cls, loc, { Pitch = 0, Yaw = yaw, Roll = 0 }) end)
            if oks and is_valid(a) then bot, spawned, new_how = a, true, "World:SpawnActor" end
            diag[#diag + 1] = "World:SpawnActor " .. (bot and "spawned" or "FAILED")
        else
            diag[#diag + 1] = "its class " .. (cls and "loaded, no World" or "not loaded")
        end
    end
    local base_cls = dl.obj(base_path)
    for _, cn in ipairs(bot and {} or classes) do
        local n = 0
        for _, b in ipairs(FindAllOf(cn) or {}) do
            if is_valid(b) and not (full_name(b) or "Default__"):find("Default__", 1, true)
                    and base_cls and select(2, pcall(function() return b:IsA(base_cls) end)) == true then
                n = n + 1
                local bx, by, bz = location_of(b)
                local dd = (bx and gloc.X) and ((bx - gloc.X) ^ 2 + (by - gloc.Y) ^ 2 + (bz - gloc.Z) ^ 2) or 1e18
                if not bot or dd < best then bot, best = b, dd end
            end
        end
        diag[#diag + 1] = cn .. " " .. n
        if bot then break end
    end
    log:write("AP", tag .. ": staff bot: " .. table.concat(diag, ", "))
    if bot and spawned then
        local again = dl.obj(obj_path(bot))
        if not again then log:write("AP", tag .. ": staff bot: the new one is already gone"); bot, spawned = nil, false end
        bot = again
    end
    if not bot then return false end
    local short = full_name(bot):match("([^%.:]+)$") or "?"
    local path = obj_path(bot)
    local bx, by, bz = location_of(bot)
    local okr0, rot0 = pcall(function() return bot:K2_GetActorRotation() end)
    local yaw0 = okr0 and tonumber(U.to_str(prop(rot0, "Yaw"))) or 0
    local function half(a)
        local cap = prop(a, "CapsuleComponent")
        return is_valid(cap) and tonumber(U.to_str(call(cap, "GetScaledCapsuleHalfHeight"))) or nil
    end
    local ghh, bhh = half(greg), half(bot)
    if ghh and bhh then loc.Z = loc.Z - ghh + bhh + (k.z_offset or 0) end
    dl_step("staff bot: put in front of Gregory")
    local rot = { Pitch = 0, Yaw = yaw, Roll = 0 }
    dl_step("staff bot: DisablePatrol")
    pcall(function() bot:DisablePatrol() end)
    dl_step("staff bot: SetMoveToLocationAndRotation")
    pcall(function() bot:SetMoveToLocationAndRotation(loc, rot) end)
    if k.world_set == true then
        dl_step("staff bot: SetWorldLocation")
        pcall(function() bot:SetWorldLocation(loc, false, true) end)
        pcall(function() bot:SetWorldRotation(rot, true) end)
    end
    dl_step("staff bot: K2_SetActorLocation")
    local okm = pcall(function() bot:K2_SetActorLocation(loc, false, {}, true) end)
    pcall(function() bot:K2_SetActorRotation(rot, true) end)
    local notes = { spawned and ("NEW (" .. new_how .. ")") or "of the world" }
    local base = dl.obj(base_path)
    local fobj = dl.obj(base_path .. ":NonLethalJumpScare")
    local isa = base and select(2, pcall(function() return bot:IsA(base) end)) == true
    local jumped = false
    if trap then
        notes[#notes + 1] = "no jumpscare (Security Alert)"
    elseif isa then
        dl_step("staff bot: its NonLethalJumpScare")
        jumped = pcall(function() bot:NonLethalJumpScare(greg, false) end)
        notes[#notes + 1] = "its NonLethalJumpScare " .. (jumped and "called" or "FAILED")
    else
        notes[#notes + 1] = string.format("not a StaffBotBase (%s, function %s)", tostring(isa), tostring(fobj ~= nil))
    end
    if ghh and bhh then notes[#notes + 1] = string.format("height %+.0f (capsules %.0f / %.0f)", bhh - ghh, bhh, ghh) end
    local types = U.list_from_array(prop(bot, "TypesToAlert"), function(e) return e end) or {}
    local nalert = tonumber(U.to_str(prop(bot, "NumberOfBotsToAlert")))
    notes[#notes + 1] = string.format("its alert: %d type(s), %s to alert", #types, tostring(nalert))
    dl.staff_types_empty = (#types == 0)
    dl_step("staff bot: its blackboard")
    local bb = nil
    local ctrl = call(bot, "GetController")
    if is_valid(ctrl) then bb = prop(ctrl, "Blackboard") end
    if not is_valid(bb) then
        local lib = dl.obj("/Script/AIModule.Default__AIBlueprintHelperLibrary")
        if lib then local okb, b2 = pcall(function() return lib:GetBlackboard(bot) end); if okb and is_valid(b2) then bb = b2 end end
    end
    notes[#notes + 1] = "controller " .. (is_valid(ctrl) and (class_name(ctrl) or "?") or "none")
    local fired = false
    if trap or (jumped and k.auto_alert ~= true) then
        bb = nil
    elseif is_valid(bb) then
        local key = U.to_str(prop(bot, "TriggerAutoAlertKey"))
        local pkey = U.to_str(prop(bot, "PlayerLocationKey"))
        if pkey and pkey ~= "" and pkey ~= "None" then
            local okp = pcall(function() bb:SetValueAsVector(FName(pkey), gloc) end)
            notes[#notes + 1] = pkey .. (okp and " set" or " FAILED")
        end
        if key and key ~= "" and key ~= "None" then
            fired = pcall(function() bb:SetValueAsBool(FName(key), true) end)
            notes[#notes + 1] = key .. (fired and " = true" or " FAILED")
        else
            notes[#notes + 1] = "no TriggerAutoAlertKey"
        end
    elseif not jumped then
        notes[#notes + 1] = "no blackboard"
    end
    if not trap then ap:expect_own_death(world_now() + (dl_cfg().own_death_s or 60)) end
    log:write("AP", string.format(tag .. ": staff bot %s %s %d units in front of Gregory; %s", short,
        okm and "put" or "NOT put", k.catch_dist or 150, table.concat(notes, ", ")))
    local function now_bot() local okg, g = pcall(StaticFindObject, path); return (okg and is_valid(g)) and g or nil end
    local function scared(b)
        local gr = find("Gregory_C")
        return (gr and prop(gr, "IsGettingJumpScare") == true) or prop(b, "IsJumpscaring") == true or prop(b, "HasJumpscared") == true
    end
    local alert_ms = trap and (k.trap_alert_ms or 500) or (jumped and (k.alert_after_ms or 1500) or (k.check_ms or 1500))
    ExecuteWithDelay(alert_ms, function()
        on_game_thread("death link staff bot check", function()
            local b = now_bot()
            local gr = find("Gregory_C")
            if not (b and gr) then return end
            if jumped or trap then
                local oka, task_note = false, nil
                if k.alert_task ~= false then oka, task_note = dl.staff_alert_task(b) end
                if not oka then oka = isa and pcall(function() b["Send Alert"](b, true) end) end
                local gen = task_note and (", " .. task_note) or ""
                if dl.staff_types_empty and k.general_alert ~= false then
                    local ams = live_ams()
                    local list = {}
                    for _, t in ipairs(k.alert_types or { 0, 1, 2 }) do list[#list + 1] = { AIType = t, AISubType = 0 } end
                    local _, _, gl = dl.front_of(gr, 0)
                    local okg = ams and pcall(function() ams:SendGeneralAlert(gl, list, k.alert_count or 1) end)
                    gen = gen .. ", the game's SendGeneralAlert " .. (okg and "called" or "FAILED")
                end
                log:write("AP", tag .. ": staff bot " .. short .. ": its alert " .. (oka and "sent" or "FAILED") .. gen)
            elseif fired and scared(b) then
                log:write("AP", tag .. ": staff bot " .. short .. " jumpscared Gregory by itself (its auto alert)")
            else
                dl_step("staff bot: NonLethalJumpScare")
                local how = nil
                local at = prop(b, "JumpscareTransform")
                if is_valid(at) and k.greg_fallback ~= false and pcall(function() gr:NonLethalJumpscareBPI(1.0, at, b) end) then
                    how = "Gregory's NonLethalJumpscareBPI on its JumpscareTransform"
                end
                local oka = isa and pcall(function() b["Send Alert"](b, true) end)
                log:write("AP", string.format(tag .. ": staff bot %s did not jumpscare by itself: %s, its Send Alert %s", short,
                    how or "no jumpscare call worked", oka and "called" or "FAILED"))
            end
            ExecuteWithDelay(trap and (k.trap_gone_ms or 4000) or (k.bot_gone_ms or 6000), function()
                on_game_thread("death link staff bot gone", function()
                    local g = now_bot()
                    if not g then return end
                    if spawned then
                        pcall(function() g:K2_DestroyActor() end)
                        log:write("AP", tag .. ": staff bot " .. short .. " removed")
                        return
                    end
                    local back, r0 = { X = bx, Y = by, Z = bz }, { Pitch = 0, Yaw = yaw0, Roll = 0 }
                    pcall(function() g:SetMoveToLocationAndRotation(back, r0) end)
                    pcall(function() g:K2_SetActorLocation(back, false, {}, true) end)
                    pcall(function() g:K2_SetActorRotation(r0, true) end)
                    pcall(function() g:EnablePatrol() end)
                    log:write("AP", tag .. ": staff bot " .. short .. " put back")
                end)
            end)
        end)
    end)
    return true
end
function dl.alert_system_now()
    local sa = apcfg.security_alert or {}
    local greg = find("Gregory_C")
    if not greg then return false, "no Gregory_C" end
    local function live(o) return is_valid(o) and not (full_name(o) or "Default__"):find("Default__", 1, true) end
    local as = nil
    for _, gm in ipairs(FindAllOf(sa.gm_class or "MainGameGM_C") or {}) do
        if live(gm) and live(prop(gm, "AlertSystem")) then as = prop(gm, "AlertSystem") end
    end
    if not as then
        for _, x in ipairs(FindAllOf("AlertSystem_C") or {}) do if live(x) then as = x end end
    end
    if not as then return false, "no AlertSystem_C (MainGameGM_C.AlertSystem)" end
    local types, count, from = {}, nil, "config"
    if sa.types_from_bot ~= false then
        for _, cn in ipairs(sa.bot_classes or { "StaffBotSecurityPatrol_C", "StaffBotTalent_C" }) do
            for _, b in ipairs(FindAllOf(cn) or {}) do
                if #types == 0 and live(b) then
                    for _, e in ipairs(U.list_from_array(prop(b, "TypesToAlert"), function(x) return x end) or {}) do
                        local t = tonumber(U.to_str(prop(e, "AIType"))) or tonumber(U.to_str(e))
                        if t then types[#types + 1] = t end
                    end
                    if #types > 0 then
                        count = tonumber(U.to_str(prop(b, "NumberOfBotsToAlert")))
                        from = full_name(b):match("([^%.:]+)$") or cn
                    end
                end
            end
        end
    end
    if #types == 0 then types = { table.unpack(sa.alert_types or { 0, 1, 2 }) } end
    count = count or sa.alert_count or 1
    local _, _, gl = dl.front_of(greg, 0)
    local name = sa.alert_name or "StaffbotAlert"
    local ok, err = pcall(function() as["Send Alert"](as, FName(name), gl, types, count) end)
    return ok, string.format("the game's AlertSystem Send Alert(%s, Gregory's spot, types {%s} from %s, %d) %s", name,
        table.concat(types, ","), from, count, ok and "called" or ("FAILED: " .. tostring(err)))
end
function dl.security_trap(a)
    local sa = apcfg.security_alert or {}
    if not find("Gregory_C") then error("no Gregory_C") end
    if not security_seeded then math.randomseed(os.time()); security_seeded = true end
    if sa.voice then try("security alert voice", play_sound, sa.voice) end
    local wait = sa.voice and (sa.alarm_after_ms or 0) or 0
    local tries = 0
    local function go()
        on_game_thread("security alert bot", function()
            if world_busy() then log:write("AP", "Security Alert: world switch before the alert, skipped"); return end
            if (sa.mode or "system") == "system" then
                local ok, note = dl.alert_system_now()
                log:write("AP", "Security Alert: " .. note)
                if not ok and sa.fallback_own then security_alarm() end
                return
            end
            local ws = find("WorldStateSystem")
            local more = tries < (sa.retries or 120)
            if sa.wait_freddy ~= false and ws and call(ws, "IsPlayerInFreddy") == true and more then
                tries = tries + 1
                if tries == 1 then log:write("AP", "Security Alert: Gregory is inside Freddy: the alert once he is out") end
                ExecuteWithDelay(sa.retry_ms or 1000, go)
                return
            end
            local k = (dl_cfg().kinds or {}).staff_bot or {}
            local r = dl.staff_vanilla(k, true)
            if r == "wait" and more then
                tries = tries + 1
                ExecuteWithDelay(k.load_wait_ms or 2000, go)
                return
            end
            dl.staff_load_ms = nil
            if r ~= true then
                log:write("AP", "Security Alert: no staff bot could be brought to Gregory"
                    .. (sa.fallback_own and ": the mod's own alarm instead" or ": no alert"))
                if sa.fallback_own then security_alarm() end
            end
        end)
    end
    if wait > 0 then ExecuteWithDelay(wait, go) else go() end
end
function dl.foxy_paths()
    return (apcfg.effects or {}).foxy or {}
end
function dl.foxy_frames_start(e)
    local fc = dl.foxy_paths()
    e.frames = {}
    local greg = find("Gregory_C")
    local krl = dl.obj("/Script/Engine.Default__KismetRenderingLibrary")
    if not (greg and krl) then return "no Gregory / KismetRenderingLibrary: nothing shown" end
    local bad = 0
    for i = 1, fc.frame_count or 17 do
        local full = mod_dir .. "/" .. string.format(fc.frames or "Media/foxy/foxy_%02d.png", i)
        local ok, t = pcall(function() return krl:ImportFileAsTexture2D(greg, full) end)
        if ok and is_valid(t) then e.frames[#e.frames + 1] = obj_path(t) else bad = bad + 1 end
    end
    if #e.frames == 0 then return string.format("no frame loaded (%d missing, %s): nothing shown", bad, fc.frames or "Media/foxy/foxy_%02d.png") end
    local notes = { string.format("%d frame(s) loaded%s", #e.frames, bad > 0 and (", " .. bad .. " missing") or "") }
    local hud, shown = nil, false
    for _, h in ipairs(FindAllOf(fc.hud_class or "PlayerHUD_C") or {}) do
        if is_valid(h) and not (full_name(h) or "Default__"):find("Default__", 1, true) then
            local inv = call(h, "IsInViewport") == true
            if not hud or (inv and not shown) then hud, shown = h, inv end
        end
    end
    local wt = hud and prop(hud, "WidgetTree")
    local root = is_valid(wt) and prop(wt, "RootWidget") or nil
    local icls = dl.obj("/Script/UMG.Image")
    if not (is_valid(root) and icls and type(StaticConstructObject) == "function") then
        return table.concat(notes, ", ") .. string.format(", no picture (HUD %s, root %s)", tostring(hud ~= nil), tostring(is_valid(root)))
    end
    local oki, img = pcall(StaticConstructObject, icls, wt)
    if not (oki and is_valid(img)) then return table.concat(notes, ", ") .. ", Image not made (" .. tostring(img) .. ")" end
    local first = dl.obj(e.frames[1])
    local okb = pcall(function() img:SetBrushFromTexture(first, true) end)
    local okc, slot = pcall(function() return root:AddChildToCanvas(img) end)
    if not (okc and is_valid(slot)) then
        return table.concat(notes, ", ") .. ", picture NOT on the HUD (not a canvas: " .. tostring(slot) .. ")"
    end
    e.img, e.slot = obj_path(img), obj_path(slot)
    pcall(function() slot:SetZOrder(fc.z_order or 1000) end)
    local fit = fc.screen_fit or fc.fit or "stretch"
    local oka = pcall(function() slot:SetAutoSize(fit == "native") end)
    local fw, fh = fc.frame_w or 1024, fc.frame_h or 768
    local wll = dl.obj("/Script/UMG.Default__WidgetLayoutLibrary")
    local okv, vs = false, nil
    if wll then okv, vs = pcall(function() return wll:GetViewportSize(greg) end) end
    local oks, sc = false, nil
    if wll then oks, sc = pcall(function() return wll:GetViewportScale(greg) end) end
    local vw, vh = okv and tonumber(U.to_str(prop(vs, "X"))) or nil, okv and tonumber(U.to_str(prop(vs, "Y"))) or nil
    sc = oks and tonumber(U.to_str(sc)) or 1
    if sc == nil or sc <= 0 then sc = 1 end
    local placed = "top-left"
    if vw and vh and vw > 0 and vh > 0 then
        local sw, sh = vw / sc, vh / sc
        local w, h = fw, fh
        if fit == "stretch" then w, h = sw, sh
        elseif fit == "height" then w, h = fw * sh / fh, sh
        elseif fit == "cover" then local k = math.max(sw / fw, sh / fh); w, h = fw * k, fh * k end
        local okz = fit == "native" or pcall(function() slot:SetSize({ X = w, Y = h }) end)
        local okp = pcall(function() slot:SetPosition({ X = (sw - w) / 2, Y = (sh - h) / 2 }) end)
        placed = string.format("screen %dx%d (scale %.2f), %s %dx%d %s, centred %s", math.floor(vw), math.floor(vh), sc,
            fit, math.floor(w), math.floor(h), okz and "ok" or "FAILED", okp and "ok" or "FAILED")
    end
    notes[#notes + 1] = string.format("picture on the HUD (frame %s, auto size off %s, %s, HUD in viewport %s)",
        okb and "set" or "FAILED", oka and "ok" or "FAILED", placed, tostring(shown))
    local game_note = fc.sound ~= false and dl.foxy_game_sound(e, greg) or nil
    if game_note then notes[#notes + 1] = game_note end
    e.start_ms = world_now_ms()
    e.until_ms = e.start_ms + (fc.seconds or 1.8) * 1000
    e.shown_frame = 1
    dl.foxy_anim = e
    return table.concat(notes, ", ")
end
function dl.foxy_game_sound(e, greg)
    local fc = dl.foxy_paths()
    if fc.game_sound == false then return nil end
    local pak = fc.game_pak or (mod_dir .. "/../../../../Content/Paks/zzz_APFoxy_P.pak")
    local f = io.open(pak, "rb")
    if not f then return "no " .. (fc.game_pak or "zzz_APFoxy_P.pak") .. ": no sound" end
    f:close()
    local name = fc.game_event or "Play_mus_foreverAndEver_old"
    local path = fc.game_event_path or ("/Game/Audio/Music/" .. name .. "." .. name)
    local loaded = dl.obj(path) and "loaded" or nil
    if not loaded and type(LoadAsset) == "function" then
        local okl, o = pcall(LoadAsset, path)
        loaded = okl and is_valid(o) and "loaded now" or "not loaded"
    end
    local id, how = nil, nil
    local akc = dl.obj("/Script/AkAudio.AkComponent")
    local comp = akc and call(greg, "GetComponentByClass", akc)
    if is_valid(comp) then
        id = tonumber(U.to_str(call(comp, "PostAkEventByName", name)))
        how = "Gregory's AkComponent"
    end
    local gs = dl.obj("/Script/AkAudio.Default__AkGameplayStatics")
    if (not id or id == 0) and gs then
        local okp, r = pcall(function() return gs:PostEventByName(name, greg, false) end)
        id, how = okp and tonumber(U.to_str(r)) or nil, "PostEventByName on Gregory"
    end
    if not id or id == 0 then
        return string.format("%s not played (event %s, %s): no sound", name, loaded or "?", tostring(how))
    end
    e.ak_id = id
    e.ak_end_ms = world_now_ms() + (fc.game_sound_s or 1.85) * 1000
    return string.format("sound played by the game (%s, event %s, %s, id %d)", name, loaded or "?", how, id)
end
function dl.foxy_frame_tick()
    local e = dl.foxy_anim
    if not e or not e.img then return end
    local fc = dl.foxy_paths()
    local n = #e.frames
    local i = math.floor((world_now_ms() - e.start_ms) / (fc.frame_ms or 50))
    local once = fc.play_once
    if once == nil then once = fc.loop == false end
    i = once and math.min(i + 1, n) or (i % n + 1)
    local now = world_now_ms()
    local gone = once and (e.start_ms + n * (fc.frame_ms or 50)) or e.until_ms
    if now >= (gone or math.huge) then
        local img = dl.obj(e.img)
        if img then pcall(function() img:RemoveFromParent() end) end
        dl.foxy_anim = nil
        return
    end
    if i == e.shown_frame then return end
    local img, t = dl.obj(e.img), dl.obj(e.frames[i])
    if img and t then
        pcall(function() img:SetBrushFromTexture(t, false) end)
        e.shown_frame = i
    end
end
function dl.foxy_start(e)
    e.frames_mode = true
    return dl.foxy_frames_start(e)
end
function dl.foxy_tick(e) end
function dl.foxy_stop(e)
    local done = {}
    if dl.foxy_anim == e then dl.foxy_anim = nil end
    local img = e.img and dl.obj(e.img)
    if img then pcall(function() img:RemoveFromParent() end); done[#done + 1] = "picture removed" end
    if e.ak_id then
        local id = e.ak_id
        local wait = math.max((e.ak_end_ms or 0) - world_now_ms(), 0)
        ExecuteWithDelay(math.floor(wait) + 1, function() on_game_thread("foxy sound end", function()
            local gs = dl.obj("/Script/AkAudio.Default__AkGameplayStatics")
            if gs then pcall(function() gs:ExecuteActionOnPlayingID(0, id, 0, 4) end) end
        end) end)
        done[#done + 1] = string.format("sound stopped in %d ms", math.floor(wait))
    end
    return #done > 0 and table.concat(done, ", ") or "nothing to remove"
end
function dl.moon_actor(key, how)
    local c = dl_cfg()
    local k = (c.kinds or {})[key] or {}
    local greg = find("Gregory_C")
    local cpath = k.actor_class or "/Game/Blueprints/AI/MoonMan/MoonMan_Jumpscare.MoonMan_Jumpscare_C"
    local cls = dl.obj(cpath)
    if not cls and k.load_actor ~= false and type(LoadAsset) == "function" then
        dl_step("Moon: loading " .. cpath)
        pcall(LoadAsset, (cpath:gsub("%.[^%.]+$", "")))
        cls = dl.obj(cpath)
    end
    local gs = dl.obj("/Script/Engine.Default__GameplayStatics")
    if not (greg and cls and gs) then
        log:write("AP", "Death Link (" .. how .. "): Moon jumpscare actor class not loaded: another animatronic")
        return "other"
    end
    local loc, yaw = dl.front_of(greg, k.actor_dist or 120)
    local r = math.rad(yaw + (k.actor_yaw or 0)) / 2
    local tf = { Rotation = { X = 0, Y = 0, Z = math.sin(r), W = math.cos(r) }, Translation = loc, Scale3D = { X = 1, Y = 1, Z = 1 } }
    dl_step("Moon: spawning MoonMan_Jumpscare_C")
    local ok, a = pcall(function() return gs:BeginDeferredActorSpawnFromClass(greg, cls, tf, 1, greg) end)
    if not (ok and is_valid(a)) then
        log:write("AP", "Death Link (" .. how .. "): Moon jumpscare actor not spawned (" .. tostring(a) .. "): another animatronic")
        return "other"
    end
    pcall(function() gs:FinishSpawningActor(a, tf) end)
    local path = obj_path(a)
    dl_step("Moon: Gregory's LethalJumpscareBPI")
    local at = prop(a, "JumpscarePoint")
    if not is_valid(at) then at = prop(a, "RootComponent") end
    ap:expect_own_death(world_now() + (c.own_death_s or 60))
    local okj = pcall(function() greg:LethalJumpscareBPI(at, nil, false, k.shake or 1.0, a) end)
    ExecuteWithDelay(k.actor_life_ms or 15000, function()
        on_game_thread("death link moon actor gone", function()
            local oka, o = pcall(StaticFindObject, path)
            if oka and is_valid(o) then pcall(function() o:K2_DestroyActor() end) end
        end)
    end)
    dl.active = { key = full_name(a), short = "Moon (jumpscare actor)", kind = key, since = world_now_ms(), deaths = game_death_count(),
                  step = 0, methods = {}, lookup = function() return dl.obj(path) end }
    log:write("AP", "Death Link (" .. how .. "): MoonMan_Jumpscare_C spawned in front of Gregory, LethalJumpscareBPI "
        .. (okj and "called" or "FAILED"))
    return true
end
function dl.kill_actor(key, how)
    local c = dl_cfg()
    local k = (c.kinds or {})[key] or {}
    local greg = find("Gregory_C")
    if not greg then return false end
    local name = k.name or key
    local cls = dl.obj(k.spawn_class)
    if not cls then
        dl.loads = dl.loads or {}
        local last = dl.loads[key]
        if k.load ~= false and type(LoadAsset) == "function" and not (last and world_now_ms() - last < (k.reload_ms or 30000)) then
            dl.loads[key] = world_now_ms()
            dl_step(name .. ": LoadAsset " .. k.spawn_class)
            local okl, r = pcall(LoadAsset, k.spawn_class)
            if not (okl and is_valid(r)) and not dl.obj(k.spawn_class) then
                local pkg = k.spawn_class:gsub("%.[^%.]+$", "")
                okl, r = pcall(LoadAsset, pkg .. "." .. (pkg:match("([^/]+)$") or ""))
            end
            log:write("AP", string.format("Death Link (%s): %s's class not loaded: LoadAsset %s, the spawn in %.1f s", how, name,
                okl and "called" or ("FAILED (" .. tostring(r) .. ")"), (k.load_wait_ms or 2000) / 1000))
            dl.round_ms = world_now_ms() + (k.load_wait_ms or 2000)
            return "wait"
        end
        log:write("AP", "Death Link (" .. how .. "): " .. name .. "'s class not loaded: another animatronic")
        return "other"
    end
    local okw, world = pcall(function() return greg:GetWorld() end)
    if not (okw and is_valid(world)) then
        log:write("AP", "Death Link (" .. how .. "): no World to spawn " .. name .. " in: another animatronic")
        return "other"
    end
    local loc, yaw = dl.front_of(greg, k.dist or c.front_dist or 80)
    local rot = { Pitch = 0, Yaw = yaw, Roll = 0 }
    dl_step(name .. ": World:SpawnActor")
    local ok, a = pcall(function() return world:SpawnActor(cls, loc, rot) end)
    if not (ok and is_valid(a)) then
        log:write("AP", "Death Link (" .. how .. "): " .. name .. " not spawned (" .. tostring(a) .. "): another animatronic")
        return "other"
    end
    local function half(o)
        local cap = prop(o, "CapsuleComponent")
        return is_valid(cap) and tonumber(U.to_str(call(cap, "GetScaledCapsuleHalfHeight"))) or nil
    end
    local ghh, ahh = half(greg), half(a)
    if ghh and ahh then
        loc.Z = loc.Z - ghh + ahh + (k.z_offset or 0)
        pcall(function() a:K2_SetActorLocation(loc, false, {}, true) end)
    end
    local path = obj_path(a)
    local short = full_name(a):match("([^%.:]+)$") or name
    ap:expect_own_death(world_now() + (c.own_death_s or 60))
    ExecuteWithDelay(k.life_ms or 20000, function()
        on_game_thread("death link " .. key .. " gone", function()
            local o = dl.obj(path)
            if o then pcall(function() o:K2_DestroyActor() end); log:write("AP", "Death Link: " .. short .. " removed") end
        end)
    end)
    dl.active = { key = full_name(a), short = short, kind = key, since = world_now_ms(), deaths = game_death_count(),
                  step = 0, next_ms = world_now_ms() + (k.catch_delay_ms or c.instant_delay_ms or 0),
                  methods = k.methods or { "Jumpscare", "ForceJumpscarePlayer", "LethalJumpscareBPI" },
                  lookup = function() return dl.obj(path) end }
    local px, py, pz = location_of(a)
    log:write("AP", string.format("Death Link (%s): %s spawned by World:SpawnActor %d units in front of Gregory, at (%.0f,%.0f,%.0f)%s",
        how, short, k.dist or c.front_dist or 80, px or 0, py or 0, pz or 0,
        (ghh and ahh) and string.format(", capsules %.0f / %.0f", ahh, ghh) or ""))
    return true
end
local function dl_kill(key, how)
    local c = dl_cfg()
    local k = (c.kinds or {})[key]
    local greg = find("Gregory_C")
    if k.staff then
        if not dl.staff_alarmed then
            dl.staff_alarmed = true
            local okc, real = false, false
            if k.real_catch ~= false then okc, real = pcall(dl.staff_vanilla, k) end
            if not okc and k.real_catch ~= false then log:write("AP", "Death Link: staff bot catch error: " .. tostring(real)) end
            if okc and real == "wait" then
                dl.staff_alarmed = nil
                dl.round_ms = world_now_ms() + (k.load_wait_ms or 2000)
                return "wait"
            end
            if okc and real == true and k.answer ~= true then
                log:write("AP", "Death Link (" .. how .. "): the staff bot's own catch and alert (no animatronic spawned by the mod)")
                return true
            end
            if not (okc and real == true) then
                log:write("AP", "Death Link (" .. how .. "): staff bot alarm")
                security_alarm({ spawn = false })
                try("death link staff bot", dl.staff_bot_show, k)
            end
            if k.killer == false then return true end
            dl.round_ms = world_now_ms() + (k.kill_after_ms or 2500)
            return "wait"
        end
        if k.killer == false then return true end
        if not dl.staff_sub then
            local subs = {}
            for _, s in ipairs(k.killers or dl_cfg().substitutes or { "chica", "roxy", "monty", "endos" }) do
                if not dl_unusable(s, true) then subs[#subs + 1] = s end
            end
            if #subs == 0 then log:write("AP", "Death Link (" .. how .. "): nobody to answer the alarm"); return true end
            dl.staff_sub = subs[math.random(#subs)]
        end
        return dl_kill(dl.staff_sub, how .. ", " .. dl.staff_sub .. " answers the alarm")
    end
    if k.freddy then return dl_kill_freddy(key, how) end
    if k.moon_seq then return dl.kill_moon(key, how) end
    if k.spawn_class then return dl.kill_actor(key, how) end
    dl_step("AI manager")
    local ams = live_ams()
    if not ams then log:write("AP", "Death Link (" .. how .. "): no AIManagementSystem"); return false end
    dl_step("Gregory's position and the spots")
    local x, y, z = location_of(greg)
    local spots = dl_spots(greg, k)
    local i = dl.spot_i or 1
    if i > #spots then i = 1 end
    dl.spot_n = #spots
    local spot, where = spots[i][1], spots[i][2]
    dl_step(string.format("SpawnAITypeAtLocation type %d (%s) %s", k.type, key, where))
    local save_note = dl.saves_off(k)
    local cdo_old = dl.cdo_set(k)
    local ok, pawn = pcall(function() return ams:SpawnAITypeAtLocation(k.type, spot, false) end)
    dl.cdo_restore(cdo_old)
    dl_step("spawn returned, checking it")
    if not (ok and is_valid(pawn)) then
        log:write("AP", string.format("Death Link (%s): spawn of type %d FAILED %s (spot %d of %d) (%s)",
            how, k.type, where, i, #spots, tostring(pawn)))
        dl.spot_i = i + 1
        return "next"
    end
    dl_step("killer's name and settings")
    local key_name = full_name(pawn)
    local short = key_name:match("([^%.:]+)$") or key_name
    spawned_ai[key_name] = { t = world_now(), death_link = true }
    local notes = {}
    if cdo_old then notes[#notes + 1] = cdo_old.note end
    if save_note then notes[#notes + 1] = save_note end
    for pk, v in pairs(k.props or {}) do
        local val, shown = v, tostring(v)
        if v == "@completed_mission" then
            local m = completed_mission() or "None"
            val, shown = FName(m), m
        end
        local okp = pcall(function() pawn[pk] = val end)
        notes[#notes + 1] = pk .. (okp and ("=" .. shown) or " FAILED")
    end
    if k.wake then dl_step("wake") end
    for _, w in ipairs(k.wake or {}) do notes[#notes + 1] = call_no_params(pawn, w, k.wake_force) end
    dl_step("alert")
    local here = { X = x, Y = y, Z = z }
    local can = call(pawn, "CanReceiveAlert")
    local oka = can ~= false and pcall(function() pawn:SendPositionalAlert(here) end)
    if oka then
        notes[#notes + 1] = "alerted to Gregory"
    else
        local okm = pcall(function() pawn:StartMoveTo(here) end)
        notes[#notes + 1] = okm and "StartMoveTo Gregory" or "not sent (no alert, no StartMoveTo)"
    end
    ap:expect_own_death(world_now() + (c.own_death_s or 60))
    dl.active = { key = key_name, short = short, kind = key, since = world_now_ms(), deaths = game_death_count(),
                  step = 0, next_ms = world_now_ms() + (c.instant_delay_ms or 0) }
    local px, py, pz = location_of(pawn)
    log:write("AP", string.format("Death Link (%s): %s spawned at %s, now at (%.0f,%.0f,%.0f); %s", how, short, where,
        px, py, pz, table.concat(notes, ", ")))
    return true
end
function dl.is_seeker(o)
    local base = dl.obj((dl_cfg().seeker_class) or "/Game/Blueprints/AI/Seeker/AISeeker.AISeeker_C")
    return base ~= nil and select(2, pcall(function() return o:IsA(base) end)) == true
end
function dl.ending_of_url(url)
    local g = apcfg.goal or {}
    local low = tostring(url or ""):lower()
    for video, key in pairs(g.endings or {}) do
        if low:find(video:lower(), 1, true) then return key, video end
    end
    return nil
end
function dl.ending_look(how, ui_path)
    local g = apcfg.goal or {}
    ExecuteWithDelay(g.read_delay_ms or 100, function()
        on_game_thread("ending look", function()
            local ui = ui_path and dl.obj(ui_path) or nil
            if not ui then
                for _, u in ipairs(FindAllOf(g.ui_short or "EndGameCinematicPlayerUI_C") or {}) do
                    if is_valid(u) and not (full_name(u) or "Default__"):find("Default__", 1, true) then ui = u end
                end
            end
            local mp = ui and prop(ui, "Media Player")
            local url = nil
            if is_valid(mp) then
                local oku, s = pcall(function() local r = mp:GetUrl(); return type(r) == "string" and r or nil end)
                if oku and type(s) == "string" and s ~= "" then url = s end
                if not url then
                    local pl = call(mp, "GetPlaylist")
                    if not is_valid(pl) then pl = prop(mp, "Playlist") end
                    local names = {}
                    if is_valid(pl) then
                        local n = tonumber(U.to_str(call(pl, "Num"))) or 0
                        for i = 0, math.min(n, 8) - 1 do
                            local src = call(pl, "Get", i)
                            if is_valid(src) then names[#names + 1] = full_name(src) end
                        end
                    end
                    if #names > 0 then url = table.concat(names, " ") end
                end
            end
            local key, video = dl.ending_of_url(url)
            if not key then key = (g.subtitles or {})[how] end
            if key then
                ap:ending_seen(key, how .. (video and (", video " .. video) or ""))
                if ap.dirty then ap:flush() end
            else
                log:write("AP", string.format("end-game screen (%s): ending not recognised (video %s)", how, tostring(url)))
            end
        end)
    end)
end
function dl.ending_hooks()
    if dl.ending_hooked then return end
    local g = apcfg.goal or {}
    if g.enabled == false then return end
    local done, bad = 0, {}
    for _, fname in ipairs(g.triggers or {}) do
        local path = (g.ui_class or "/Game/Cinematics/EndGameCinematicPlayerUI.EndGameCinematicPlayerUI_C") .. ":" .. fname
        local ok = pcall(RegisterHook, path, function(ctx)
            local p = nil
            pcall(function() p = obj_path(ctx:get()) end)
            try("ending hook", function() dl.ending_look(fname, p) end)
        end)
        if ok then done = done + 1 else bad[#bad + 1] = fname end
    end
    for _, path in ipairs(g.end_game or {}) do
        local ok = pcall(RegisterHook, path, function() try("ending hook", function() dl.ending_look("EndGame", nil) end) end)
        if ok then done = done + 1 else bad[#bad + 1] = path:match(":(.+)$") or path end
    end
    if done > 0 then
        dl.ending_hooked = true
        log:write("AP", string.format("goal: %d end-game hook(s) set%s", done, #bad > 0 and (", not set: " .. table.concat(bad, ", ")) or ""))
    end
end
local function dl_catch_now(a, pawn, greg)
    local c = dl_cfg()
    local methods = a.methods or c.instant_methods or { "OnCaptureOverlap", "ForceJumpscarePlayer", "LethalJumpscareBPI" }
    while a.step < #methods do
        a.step = a.step + 1
        local m = methods[a.step]
        dl_step("catch: " .. m)
        local ok, what = nil, nil
        if m == "Jumpscare" and a.kind == "freddy" then
            ok = pcall(function() pawn:Jumpscare() end)
            what = "his own Jumpscare()"
        elseif m == "Jumpscare" and (has_func(pawn, m) or dl.is_seeker(pawn)) then
            ok = pcall(function() pawn:Jumpscare(greg) end)
            what = "its own Jumpscare(Gregory)"
        elseif m == "OnCaptureOverlap" and has_func(pawn, m) then
            local box = prop(pawn, "PlayerCaptureTrigger")
            ok = pcall(function() pawn:OnCaptureOverlap(greg, box) end)
            what = "its own catch (OnCaptureOverlap)"
        elseif m == "ForceJumpscarePlayer" and has_func(pawn, m) then
            ok = pcall(function() pawn:ForceJumpscarePlayer() end)
            what = "ForceJumpscarePlayer"
        elseif m == "LethalJumpscareBPI" then
            local attach = prop(pawn, "JumpscareLocation")
            if not is_valid(attach) then attach = prop(pawn, "RootComponent") end
            local audio = prop(pawn, "JumpscareAudio")
            if not is_valid(audio) then audio = nil end
            local shake = tonumber(U.to_str(prop(pawn, "JumpscareCamShake"))) or 1.0
            ok = pcall(function() greg:LethalJumpscareBPI(attach, audio, false, shake, pawn) end)
            what = string.format("Gregory:LethalJumpscareBPI (attach %s, audio %s)",
                is_valid(attach) and (full_name(attach):match("([^%.:]+)$") or "?") or "none", audio and "yes" or "none")
        end
        if what then
            log:write("AP", string.format("Death Link: %s, try %d: %s %s", a.short, a.step, what, ok and "called" or "FAILED"))
            return true
        end
    end
    return false
end
local function dl_follow()
    local a = dl.active
    if not a then return end
    local c = dl_cfg()
    local greg = find("Gregory_C")
    local deaths = game_death_count()
    if (deaths and a.deaths and deaths > a.deaths) or (greg and prop(greg, "IsGettingJumpScare") == true) then
        log:write("AP", string.format("Death Link: %s caught Gregory after %.1f s", a.short, (world_now_ms() - a.since) / 1000))
        dl.active = nil
        return
    end
    local age = world_now_ms() - a.since
    if greg and a.next_ms and world_now_ms() >= a.next_ms then
        local ams, pawn = nil, nil
        if a.lookup then
            pawn = a.lookup()
        else
            ams = live_ams()
        end
        if ams then
            for _, p in ipairs(U.list_from_array(call(ams, "GetAllAI"), function(e) return e end)) do
                if is_valid(p) and full_name(p) == a.key then pawn = p end
            end
        end
        if not pawn then
            log:write("AP", string.format("Death Link: %s is gone after %.1f s, Gregory not caught", a.short, age / 1000))
            a.next_ms = nil
        elseif dl_catch_now(a, pawn, greg) then
            a.next_ms = world_now_ms() + (c.instant_retry_ms or 1000)
        else
            log:write("AP", string.format("Death Link: %s: no way left to make it catch Gregory now", a.short))
            a.next_ms = nil
        end
    end
    if age >= (c.give_up_ms or 30000) then
        log:write("AP", string.format("Death Link: %s did not catch Gregory within %.0f s: given up", a.short, age / 1000))
        dl.active = nil
    end
end
local function death_link_tick()
    if not ap then return end
    dl.saves_back()
    local c = dl_cfg()
    local n = ap:take_death_link()
    if n > 0 then
        if tonumber(ap.options.death_link) ~= 1 or c.enabled == false then
            log:write("AP", "Death Link received but it is off for this slot (or in config.lua): ignored")
        elseif tonumber(dl_behavior()) == dl.OFF then
            log:write("AP", "Death Link received but it is Disabled in the pause menu: ignored")
        elseif dl.active or dl.pending > 0 then
            log:write("AP", "Death Link received while one is under way: the same death")
        else
            dl.pending = 1
            dl.staff_alarmed, dl.staff_sub = nil, nil
            log:write("AP", string.format("Death Link received (%d): behavior %s%s", n, tostring(dl_behavior()),
                dl.override ~= nil and " (pause menu)" or ""))
        end
    end
    dl_follow()
    if dl.pending == 0 then return end
    if not (last_state and last_state.ready) then dl_say("wait", "waiting for Gregory"); return end
    local greg = find("Gregory_C")
    if not greg then dl_say("wait", "waiting for Gregory"); return end
    if prop(greg, "IsGettingJumpScare") == true then
        log:write("AP", "Death Link: Gregory is already being caught: received death dropped")
        dl.pending = 0
        return
    end
    dl_step("paused or in a cinematic?")
    local pc = dl.controller()
    local skip = (c.skip_paused ~= false and dl.paused(greg) and "the game is paused")
        or (c.skip_cinematic ~= false and dl.sequence(pc))
    if skip then
        log:write("AP", "Death Link: " .. skip .. ": received death skipped")
        dl.pending, dl.tries, dl.ejected, dl.out_ms, dl.unhide_ms = 0, 0, nil, nil, nil
        dl.choice_key, dl.choice_how = nil, nil
        return
    end
    dl_step("inside Freddy?")
    local ws = find("WorldStateSystem")
    if c.wait_in_freddy ~= false and ws and call(ws, "IsPlayerInFreddy") == true then
        if c.eject_freddy ~= false and not dl.ejected then
            dl.ejected = true
            local fred = nil
            for _, f in ipairs(FindAllOf("Freddy_C") or {}) do
                if is_valid(f) and not full_name(f):find("Default__", 1, true) then fred = f end
            end
            if not fred then
                log:write("AP", "Death Link: Gregory is inside Freddy, no Freddy_C to eject him: waiting")
            else
                local bypass = c.eject_bypass_anim ~= false
                local ok = pcall(function() fred["Eject Gregory"](fred, bypass) end)
                dl.out_ms = world_now_ms()
                log:write("AP", string.format("Death Link: Gregory is inside Freddy: Eject Gregory(%s) %s (Can Eject %s)",
                    tostring(bypass), ok and "called" or "FAILED", U.to_str(prop(fred, "Can Eject"))))
            end
        end
        dl_say("wait", "waiting: Gregory is inside Freddy")
        return
    end
    dl_step("hiding?")
    if c.eject_hiding ~= false and dl.hiding(greg) then
        if dl.ejected then
            dl.out_ms = nil
            dl_say("wait", "waiting: Gregory is getting out of Freddy")
            return
        end
        local now = world_now_ms()
        if not dl.unhide_ms or now - dl.unhide_ms >= (c.hide_retry_ms or 2000) then
            local first = dl.unhide_ms == nil
            dl.unhide_ms = now
            local ok = pcall(function() greg:LeaveHidingSpace() end)
            if first or not ok then
                log:write("AP", "Death Link: Gregory is hiding: LeaveHidingSpace " .. (ok and "called" or "FAILED"))
            end
        end
        dl.out_ms = nil
        dl_say("wait", "waiting: Gregory is hiding")
        return
    end
    if (dl.ejected or dl.unhide_ms) and (c.after_eject_ms or 150) > 0 then
        dl.out_ms = dl.out_ms or world_now_ms()
        if world_now_ms() - dl.out_ms < (c.after_eject_ms or 150) then
            dl_say("wait", string.format("waiting: Gregory just got out of %s (%d ms)",
                (dl.unhide_ms and not dl.ejected) and "his hiding spot" or "Freddy", c.after_eject_ms or 150))
            return
        end
    end
    local cam = c.skip_cinematic ~= false and dl.camera_view(pc)
    if cam then
        log:write("AP", "Death Link: " .. cam .. ": received death skipped")
        dl.pending, dl.tries, dl.ejected, dl.out_ms, dl.unhide_ms = 0, 0, nil, nil, nil
        dl.choice_key, dl.choice_how = nil, nil
        return
    end
    dl.said.wait = nil
    if not security_seeded then math.randomseed(os.time()); security_seeded = true end
    if dl.round_ms and world_now_ms() < dl.round_ms then return end
    local key, how = dl.choice_key, dl.choice_how
    if not key then dl_step("choosing the animatronic"); key, how = dl_choose(dl_behavior()) end
    if not key then
        log:write("AP", "Death Link: " .. how .. ": received death dropped")
        dl.pending = 0
        return
    end
    dl.choice_key, dl.choice_how = key, how
    local function done()
        dl.pending, dl.tries, dl.ejected, dl.out_ms, dl.unhide_ms = 0, 0, nil, nil, nil
        dl.choice_key, dl.choice_how, dl.spot_i, dl.round_ms = nil, nil, nil, nil
        dl.skip, dl.last_step = {}, nil
        dl.staff_alarmed, dl.staff_sub, dl.staff_load_ms = nil, nil, nil
    end
    local res = dl_kill(key, how)
    if res == "wait" then return end
    if res == "other" then
        dl.skip = dl.skip or {}
        dl.skip[key] = true
        dl.choice_key, dl.choice_how = nil, nil
        dl.round_ms = world_now_ms() + (c.other_wait_ms or 1500)
        return
    end
    if res == "next" then
        if dl.spot_i > (dl.spot_n or 1) then
            dl.spot_i = 1
            dl.round_ms = world_now_ms() + (c.round_wait_ms or 1000)
            dl.fails = dl.fails or {}
            dl.fails[key] = (dl.fails[key] or 0) + 1
            dl.skip = dl.skip or {}
            dl.skip[key] = true
            local twice = dl.fails[key] >= (c.bad_after_rounds or 2)
            if twice then dl.bad = dl.bad or {}; dl.bad[key] = true end
            dl.choice_key, dl.choice_how = nil, nil
            log:write("AP", string.format("Death Link: %s spawned at none of the %d spots: another animatronic in %.1f s%s",
                key, dl.spot_n or 1, (c.round_wait_ms or 1000) / 1000,
                twice and (" (" .. key .. " not used again until the game restarts)") or ""))
        end
    elseif res then
        done()
        dl_follow()
    else
        dl.tries = dl.tries + 1
        if dl.tries >= (c.retries or 3) then
            log:write("AP", string.format("Death Link: %d failed tries: received death dropped", dl.tries))
            done()
        end
    end
end

local DL_MENU = { { 0, "Chica" }, { 1, "Roxy" }, { 2, "Monty" }, { 4, "Vanessa" }, { 3, "Vanny" }, { 5, "Moon" },
                  { 9, "Endos" }, { 10, "Freddy" }, { 11, "Staff Bot" }, { 12, "Random" },
                  { 13, "Random without Staff Bot" }, { -1, "Disabled" } }
local dlm = { widget = nil, pause = nil, value = nil, next_look = 0, tries = {}, said = {} }
local function obj_at(path)
    if not path then return nil end
    local ok, o = pcall(StaticFindObject, path)
    if ok and is_valid(o) then return o end
    return nil
end
local function dlm_say(text)
    if not dlm.said[text] then dlm.said[text] = true; log:write("AP", "Death Link menu: " .. text) end
end
local function dlm_index(behavior)
    for i, e in ipairs(DL_MENU) do if e[1] == tonumber(behavior) then return i - 1 end end
    return #DL_MENU - 1
end
dlm.CLICK = "/Game/Blueprints/UI/TitleButton.TitleButton_C:BndEvt__ButtonText_K2Node_ComponentBoundEvent_0_OnButtonClickedEvent__DelegateSignature"
function dlm.label(i)
    return ((dl_cfg().pause_menu or {}).title or "DEATH LINK") .. ": " .. DL_MENU[i + 1][2]
end
function dlm.show(w, i)
    if pcall(function() w["Set Display"](w, FText(dlm.label(i))) end) then return true end
    return pcall(function() w.ButtonText:SetText(FText(dlm.label(i))) end)
end
function dlm.clicked(ctx)
    local w = U.unwrap(ctx)
    if dlm.page_clicked(obj_path(w)) then return end
    if dlm.list_clicked(obj_path(w)) then return end
    if not dlm.widget or obj_path(w) ~= dlm.widget then return end
    dlm.value = ((dlm.value or 0) + 1) % #DL_MENU
    local e = DL_MENU[dlm.value + 1]
    dl.override = e[1]
    dl.choice_key, dl.choice_how = nil, nil
    local shown = dlm.show(w, dlm.value)
    log:write("AP", "Death Link menu: now " .. e[2] .. " (until the game is closed)" .. (shown and "" or " [label FAILED]"))
end
function dlm.attach_dropdown(pause, box)
    local mc = dl_cfg().pause_menu or {}
    local cls = obj_at(mc.dropdown_class or "/Game/Blueprints/System/Debug/DropDownUI.DropDownUI_C")
    local lib = obj_at("/Script/UMG.Default__WidgetBlueprintLibrary")
    if not (cls and lib) then dlm_say("no dropdown class loaded: the button instead"); return false end
    local pc = call(pause, "GetOwningPlayer")
    local okw, w = pcall(function() return lib:Create(pause, cls, pc) end)
    if not (okw and is_valid(w)) then dlm_say("dropdown Create failed: the button instead"); return false end
    local where = dlm.place(w, box)
    if not where then dlm_say("dropdown AddChild failed: the button instead"); return false end
    local notes, made = {}, 0
    for _, e in ipairs(DL_MENU) do
        if pcall(function() w:CreateButtonOption(FText(e[2])) end) then made = made + 1 end
    end
    if made == 0 then
        pcall(function() w:RemoveFromParent() end)
        dlm_say("dropdown CreateButtonOption failed: the button instead")
        return false
    end
    local cur = dlm_index(dl_behavior())
    if not pcall(function() w.VariableName:SetText(FText((mc.title or "DEATH LINK") .. ":")) end) then notes[#notes + 1] = "title FAILED" end
    if not pcall(function() w:NewOptionChosen(FText(DL_MENU[cur + 1][2])) end) then
        if not pcall(function() w:UpdateTextFromMain(FText(DL_MENU[cur + 1][2])) end) then notes[#notes + 1] = "current FAILED" end
    end
    dlm.widget, dlm.pause, dlm.value, dlm.kind, dlm.last_text = obj_path(w), obj_path(pause), cur, "dropdown", nil
    log:write("AP", string.format("Death Link menu: dropdown added to the pause menu (%s, %d options), showing %s%s", where,
        made, DL_MENU[cur + 1][2], #notes > 0 and (" [" .. table.concat(notes, ", ") .. "]") or ""))
    return true
end
function dlm.place(w, box)
    local mc = dl_cfg().pause_menu or {}
    if (mc.place or "top_right") == "top_right" then
        local ov = call(box, "GetParent")
        if is_valid(ov) and has_func(ov, "AddChildToOverlay") then
            local oks, slot = pcall(function() return ov:AddChildToOverlay(w) end)
            if oks and is_valid(slot) then
                local p = mc.padding or {}
                local okh = pcall(function() slot:SetHorizontalAlignment(mc.h_align or 3) end)
                local okv = pcall(function() slot:SetVerticalAlignment(mc.v_align or 1) end)
                local okp = pcall(function() slot:SetPadding({ Left = p.left or 0, Top = p.top or 190,
                    Right = p.right or 120, Bottom = p.bottom or 0 }) end)
                return "top right of the pause page" .. ((okh and okv and okp) and "" or " [slot settings FAILED]")
            end
        end
    end
    if pcall(function() box:AddChild(w) end) then return "under the pause buttons" end
    return nil
end
function dlm.shown_pause()
    local shown, any = nil, nil
    for _, p in ipairs(FindAllOf("PauseUI_C") or {}) do
        if is_valid(p) and not (obj_path(p) or "Default__"):find("Default__", 1, true) then
            any = p
            if call(p, "IsInViewport") == true then shown = p end
        end
    end
    return shown or any
end
dlm.hosts = {}
function dlm.hook_click()
    if dlm.hooked then return true end
    local okh, errh = pcall(RegisterHook, dlm.CLICK, function(ctx) try("death link menu click", dlm.clicked, ctx) end)
    dlm.hooked = okh
    if not okh then dlm_say("click hook FAILED: " .. tostring(errh)) end
    return okh
end
function dlm.head_text(i)
    local mc = dl_cfg().pause_menu or {}
    return (mc.title or "DEATH LINK") .. " : " .. DL_MENU[i + 1][2]
end
function dlm.opt_text(i, cur)
    local mc = dl_cfg().pause_menu or {}
    return (i == cur and (mc.mark or "> ") or (mc.indent or "   ")) .. DL_MENU[i + 1][2]
end
function dlm.set_label(path, text)
    local w = obj_at(path)
    return w ~= nil and pcall(function() w["Set Display"](w, FText(text)) end)
end
function dlm.toggle(h, open)
    h.open = open
    for _, o in ipairs(h.opts) do
        local b = obj_at(o.path)
        if b then pcall(function() b:SetVisibility(open and 0 or 1) end) end
    end
end
function dlm.choose(i)
    dlm.value = i
    local e = DL_MENU[i + 1]
    dl.override = e[1]
    dl.choice_key, dl.choice_how = nil, nil
    for _, h in pairs(dlm.hosts) do
        dlm.set_label(h.head, dlm.head_text(i))
        for _, o in ipairs(h.opts) do dlm.set_label(o.path, dlm.opt_text(o.i, i)) end
    end
    if dlm.page then dlm.page_show() end
    log:write("AP", "Death Link menu: now " .. e[2] .. " (until the game is closed)")
end
function dlm.list_clicked(path)
    if not path then return false end
    for _, h in pairs(dlm.hosts) do
        if h.head == path then dlm.toggle(h, not h.open); return true end
        for _, o in ipairs(h.opts) do
            if o.path == path then dlm.choose(o.i); dlm.toggle(h, false); return true end
        end
    end
    return false
end
function dlm.build(kind, host, put)
    local mc = dl_cfg().pause_menu or {}
    local bcls = obj_at(mc.class or "/Game/Blueprints/UI/TitleButton.TitleButton_C")
    local vcls = obj_at("/Script/UMG.VerticalBox")
    local lib = obj_at("/Script/UMG.Default__WidgetBlueprintLibrary")
    if not (bcls and vcls and lib) then return nil, "classes missing" end
    if type(StaticConstructObject) ~= "function" then return nil, "no StaticConstructObject" end
    if not dlm.hook_click() then return nil, "no click hook" end
    local outer = prop(host, "WidgetTree")
    if not is_valid(outer) then outer = host end
    local okv, vb = pcall(StaticConstructObject, vcls, outer)
    if not (okv and is_valid(vb)) then return nil, "VerticalBox not made (" .. tostring(vb) .. ")" end
    local pc = call(host, "GetOwningPlayer")
    local cur = dlm_index(dl_behavior())
    local function make(text)
        local ok, b = pcall(function() return lib:Create(host, bcls, pc) end)
        if not (ok and is_valid(b)) then return nil end
        if not pcall(function() vb:AddChild(b) end) then return nil end
        pcall(function() b["Set Display"](b, FText(text)) end)
        return b
    end
    local head = make(dlm.head_text(cur))
    if not head then return nil, "header button not made" end
    local h = { host = obj_path(host), box = obj_path(vb), head = obj_path(head), opts = {}, open = false }
    for i = 0, #DL_MENU - 1 do
        local b = make(dlm.opt_text(i, cur))
        if b then
            pcall(function() b:SetVisibility(1) end)
            h.opts[#h.opts + 1] = { path = obj_path(b), i = i }
        end
    end
    local where = put(vb)
    if not where then return nil, "not placed" end
    dlm.hosts[kind] = h
    dlm.value = cur
    log:write("AP", string.format("Death Link menu: list added to the %s menu (%s, %d choices), showing %s",
        kind, where, #h.opts, DL_MENU[cur + 1][2]))
    return where
end
function dlm.put_pause(pause)
    return function(vb)
        local mc = dl_cfg().pause_menu or {}
        local anchor = prop(pause, mc.after or "MessagesButton")
        local box = is_valid(anchor) and call(anchor, "GetParent") or nil
        if not is_valid(box) then return nil end
        return dlm.place(vb, box)
    end
end
function dlm.put_options(ou)
    return function(vb)
        local mc = dl_cfg().pause_menu or {}
        local box = prop(ou, mc.options_box or "OptionsVerticalBox")
        local name = mc.options_box or "OptionsVerticalBox"
        if not is_valid(box) then
            local anchor = prop(ou, mc.options_after or "GeneralOptionButton")
            box = is_valid(anchor) and call(anchor, "GetParent") or nil
            name = "the box of " .. (mc.options_after or "GeneralOptionButton")
        end
        if not is_valid(box) then return nil end
        if pcall(function() box:AddChild(vb) end) then return "at the end of " .. name end
        return nil
    end
end
function dlm.list_host(kind, host, put)
    local mc = dl_cfg().pause_menu or {}
    local key = obj_path(host) or "?"
    local h = dlm.hosts[kind]
    if h and h.host == key and obj_at(h.head) then return true end
    dlm.hosts[kind] = nil
    local tk = kind .. " " .. key
    dlm.tries[tk] = (dlm.tries[tk] or 0) + 1
    if dlm.tries[tk] > (mc.max_tries or 3) then return false end
    local where, why = dlm.build(kind, host, put)
    if where then dlm.tries[tk] = 0; return true end
    dlm_say("list not added to the " .. kind .. " menu (" .. tostring(why) .. ")")
    if dlm.tries[tk] >= (mc.max_tries or 3) and kind == "pause" then
        dlm.list_failed = true
        dlm_say("list given up: the dropdown instead")
    end
    return false
end
function dlm.list_tick(pause)
    dlm.list_host("pause", pause, dlm.put_pause(pause))
    if (dl_cfg().pause_menu or {}).in_options ~= false then
        local ou = prop(pause, "OptionsUI")
        if is_valid(ou) then dlm.list_host("options", ou, dlm.put_options(ou)) end
    end
end
dlm.UI = {
    button = "/Game/Blueprints/UI/TitleButton.TitleButton_C",
    combo = "/Game/Blueprints/UI/Title_ComboBox.Title_ComboBox_C",
    check = "/Game/Blueprints/System/Debug/Title_CheckBox.Title_CheckBox_C",
    desc = "/Game/Blueprints/UI/MenuDescriptionUI.MenuDescriptionUI_C",
    lib = "/Script/UMG.Default__WidgetBlueprintLibrary",
    font = "/Game/Blueprints/UI/TitleAssets/good_times_rg_Font.good_times_rg_Font",
    backing = "/Game/UI_DLC/Art/Settings/T_TitleBackingSmall.T_TitleBackingSmall",
    button_font = "/Game/Blueprints/UI/TitleAssets/Mostardesign_-_UniviaProRegular_Font.Mostardesign_-_UniviaProRegular_Font",
    button_hover = "/Game/Blueprints/UI/TitleAssets/MainMenu_button_pink.MainMenu_button_pink",
}
dlm.DESC = {
    Chica = "Chica comes for you and jumpscares you.",
    Roxy = "Roxy comes for you and jumpscares you.",
    Monty = "Monty comes for you and jumpscares you.",
    Vanessa = "Vanessa catches you. Only once a mission is completed (before that, another animatronic comes). Saving is off while she is out.",
    Moon = "Moon catches you, only during his own phases (otherwise another animatronic comes).",
    Endos = "An Endo appears behind you and catches you.",
    Freddy = "Glamrock Freddy himself comes in front of you and jumpscares you.",
    ["Staff Bot"] = "The staff bot alarm goes off, a staff bot spots you, then an animatronic answers the alarm.",
    Random = "One of them, picked at random each time (Staff Bot included).",
    ["Random without Staff Bot"] = "One of them, picked at random each time, never the Staff Bot alarm.",
    Disabled = "Death Link is off: other players' deaths do nothing to you, and yours are not sent to them.",
}
function dlm.pg() return (dl_cfg().pause_menu or {}).page or {} end
local function n_of(v) return tonumber(U.to_str(v)) end
function dlm.slot_read(w)
    local s = prop(w, "Slot")
    if not is_valid(s) then return nil end
    local t = {}
    local sz = prop(s, "Size")
    if sz ~= nil then t.sv, t.sr = n_of(prop(sz, "Value")), n_of(prop(sz, "SizeRule")) end
    local p = prop(s, "Padding")
    if p ~= nil then t.l, t.t, t.r, t.b = n_of(prop(p, "Left")), n_of(prop(p, "Top")), n_of(prop(p, "Right")), n_of(prop(p, "Bottom")) end
    t.h, t.v = n_of(prop(s, "HorizontalAlignment")), n_of(prop(s, "VerticalAlignment"))
    return t
end
function dlm.slot_write(slot, t)
    if not (t and slot ~= nil) then return end
    if t.sr then pcall(function() slot:SetSize({ Value = t.sv or 1, SizeRule = t.sr }) end) end
    if t.l or t.t or t.r or t.b then
        pcall(function() slot:SetPadding({ Left = t.l or 0, Top = t.t or 0, Right = t.r or 0, Bottom = t.b or 0 }) end)
    end
    if t.h then pcall(function() slot:SetHorizontalAlignment(t.h) end) end
    if t.v then pcall(function() slot:SetVerticalAlignment(t.v) end) end
end
function dlm.insert_after(box, anchor, w)
    local n = n_of(call(box, "GetChildrenCount")) or 0
    local at = n_of(call(box, "GetChildIndex", anchor))
    if not at or at < 0 then return false end
    local later = {}
    for i = at + 1, n - 1 do
        local c = call(box, "GetChildAt", i)
        if is_valid(c) then later[#later + 1] = { w = c, s = dlm.slot_read(c) } end
    end
    for _, e in ipairs(later) do pcall(function() box:RemoveChild(e.w) end) end
    local ok, slot = pcall(function() return box:AddChild(w) end)
    if ok then dlm.slot_write(slot, dlm.slot_read(anchor)) end
    for _, e in ipairs(later) do
        local okc, s = pcall(function() return box:AddChild(e.w) end)
        if okc then dlm.slot_write(s, e.s) end
    end
    return ok, #later
end
function dlm.copy_button_style(dst, src)
    local n = 0
    if is_valid(src) then
        local v = prop(src, "ButtonTextAlignment")
        if v ~= nil and pcall(function() dst.ButtonTextAlignment = v end) then n = n + 1 end
    end
    pcall(function() dst:SetTextAlignment() end)
    return n, dlm.copy_brushes(dst, src) .. ", " .. dlm.copy_font(dst, src)
end
function dlm.copy_brushes(dst, src)
    local ws = prop(dst, "WidgetStyle_Optional")
    if ws == nil then return "button style not found" end
    local tex
    local sws = is_valid(src) and prop(src, "WidgetStyle_Optional") or nil
    local sh = sws ~= nil and prop(sws, "Hovered") or nil
    local o = sh ~= nil and prop(sh, "ResourceObject") or nil
    if is_valid(o) then tex = o else tex = obj_at(dlm.pg().button_hover or dlm.UI.button_hover) end
    local bad = {}
    for _, k in ipairs({ "Normal", "Pressed" }) do
        if not pcall(function()
            local c = ws[k].TintColor
            local s = c.SpecifiedColor
            s.R, s.G, s.B, s.A = 1, 1, 1, 0
            c.ColorUseRule = 0
        end) then bad[#bad + 1] = k end
    end
    if not pcall(function()
        local h = ws.Hovered
        if is_valid(tex) then h.ResourceObject = tex end
        local sz = h.ImageSize
        sz.X, sz.Y = 413, 86
        local c = h.TintColor
        local s = c.SpecifiedColor
        s.R, s.G, s.B, s.A = 1, 1, 1, 1
        c.ColorUseRule = 0
    end) then bad[#bad + 1] = "Hovered" end
    pcall(function() dst.UseWidgetStyle = true end)
    local okb = pcall(function() dst:SetButtonStyle() end)
    return "button style " .. (#bad == 0 and "written" or ("not written: " .. table.concat(bad, "/")))
        .. (is_valid(tex) and "" or " (no hover texture)") .. (okb and "" or " (SetButtonStyle failed)")
end
function dlm.font_of(tb, fallback, size)
    local f = is_valid(tb) and prop(tb, "Font") or nil
    local fo = f ~= nil and prop(f, "FontObject") or nil
    local from = "own"
    if not is_valid(fo) then fo, from = obj_at(fallback or ""), "default" end
    if not is_valid(fo) then return nil end
    local tf = f ~= nil and U.to_str(prop(f, "TypefaceFontName")) or nil
    if not tf or tf == "" or tf == "None" then tf = "Default" end
    local cur = f ~= nil and n_of(prop(f, "Size")) or nil
    return { FontObject = fo, TypefaceFontName = FName(tf), Size = size or cur or 30 }, from, cur
end
function dlm.copy_font(dst, src)
    local pg = dlm.pg()
    local fo, size = nil, nil
    local col = { R = 0.496933, G = 0.152926, B = 0.871367, A = 1 }
    local ss = is_valid(src) and prop(src, "TextBlockStyle_Optional") or nil
    local sf = ss ~= nil and prop(ss, "Font") or nil
    if sf ~= nil then
        local o = prop(sf, "FontObject")
        if is_valid(o) then fo = o end
        size = n_of(prop(sf, "Size"))
    end
    local from = fo and "pause button" or "config"
    if not fo then fo = obj_at(pg.button_font or dlm.UI.button_font) end
    if not is_valid(fo) then return "font not found" end
    size = (size and size > 0) and size or (pg.button_font_size or 30)
    local sc = ss ~= nil and prop(ss, "ColorAndOpacity") or nil
    sc = sc ~= nil and prop(sc, "SpecifiedColor") or nil
    if sc ~= nil then
        local r, g, b, al = n_of(prop(sc, "R")), n_of(prop(sc, "G")), n_of(prop(sc, "B")), n_of(prop(sc, "A"))
        if r and g and b then col = { R = r, G = g, B = b, A = al or 1 } end
    end
    local notes = {}
    local ds = prop(dst, "TextBlockStyle_Optional")
    local okf, ef = false, "no style field"
    if ds ~= nil then
        okf, ef = pcall(function()
            local f = ds.Font
            f.FontObject = fo
            f.Size = size
            f.TypefaceFontName = FName("Default")
        end)
        local okc = pcall(function()
            local c = ds.ColorAndOpacity
            local spc = c.SpecifiedColor
            spc.R, spc.G, spc.B, spc.A = col.R, col.G, col.B, col.A
            c.ColorUseRule = 0
        end)
        if not okc then notes[#notes + 1] = "colour not written" end
        local function rgba(field, dr, dg, db, da, inner)
            local v = ss ~= nil and prop(ss, field) or nil
            if v ~= nil and inner then v = prop(v, inner) end
            local r = v ~= nil and n_of(prop(v, "R")) or nil
            if r then return r, n_of(prop(v, "G")) or dg, n_of(prop(v, "B")) or db, n_of(prop(v, "A")) or da end
            return dr, dg, db, da
        end
        local okh = pcall(function()
            local h = ds.HighlightColor
            h.R, h.G, h.B, h.A = rgba("HighlightColor", 1, 0.904661, 0.973446, 1)
        end)
        local oks = pcall(function()
            local sh = ds.ShadowColorAndOpacity
            sh.R, sh.G, sh.B, sh.A = rgba("ShadowColorAndOpacity", 0, 0, 0, 0)
        end)
        pcall(function()
            local sb = ds.SelectedBackgroundColor
            local spc = sb.SpecifiedColor
            spc.R, spc.G, spc.B, spc.A = rgba("SelectedBackgroundColor", 1, 0, 1, 0, "SpecifiedColor")
            sb.ColorUseRule = 0
        end)
        if not okh then notes[#notes + 1] = "highlight colour not written" end
        if not oks then notes[#notes + 1] = "shadow not written" end
    end
    if okf then
        pcall(function() dst.UseTextBlockStyle = true end)
        if not pcall(function() dst:SetTextBlockStyle() end) then notes[#notes + 1] = "SetTextBlockStyle failed" end
    else
        notes[#notes + 1] = "style font not written (" .. tostring(ef) .. ")"
        local dt = prop(dst, "ButtonText")
        if is_valid(dt) then
            local oks, es = pcall(function() dt:SetFont({ FontObject = fo, TypefaceFontName = FName("Default"), Size = size }) end)
            notes[#notes + 1] = oks and "SetFont done" or ("SetFont failed: " .. tostring(es))
            pcall(function() dt:SetColorAndOpacity({ SpecifiedColor = col, ColorUseRule = 0 }) end)
        end
    end
    local dt = prop(dst, "ButtonText")
    local nf = is_valid(dt) and prop(dt, "Font") or nil
    local now = nf ~= nil and prop(nf, "FontObject") or nil
    local nsz = nf ~= nil and n_of(prop(nf, "Size")) or nil
    notes[#notes + 1] = "text font now " .. (is_valid(now) and ((full_name(now) or "?"):match("([^%.]+)$") or "?") or "unknown")
        .. (nsz and (" " .. nsz) or "")
    return string.format("font %s %s from the %s: %s", (full_name(fo) or "?"):match("([^%.]+)$") or "?", tostring(size), from,
        table.concat(notes, ", "))
end
function dlm.wrap_in(parent, w, sb)
    local n = n_of(call(parent, "GetChildrenCount")) or 0
    local at = n_of(call(parent, "GetChildIndex", w))
    if not at or at < 0 then return false end
    local mine = dlm.slot_read(w)
    local later = {}
    for i = at + 1, n - 1 do
        local c = call(parent, "GetChildAt", i)
        if is_valid(c) then later[#later + 1] = { w = c, s = dlm.slot_read(c) } end
    end
    for _, e in ipairs(later) do pcall(function() parent:RemoveChild(e.w) end) end
    pcall(function() parent:RemoveChild(w) end)
    local ok, slot = pcall(function() return parent:AddChild(sb) end)
    if ok then dlm.slot_write(slot, mine) end
    local okc, inner = pcall(function() return sb:AddChild(w) end)
    if okc then
        pcall(function() inner:SetHorizontalAlignment(0) end)
        pcall(function() inner:SetVerticalAlignment(0) end)
    end
    for _, e in ipairs(later) do
        local oka, s = pcall(function() return parent:AddChild(e.w) end)
        if oka then dlm.slot_write(s, e.s) end
    end
    if not (ok and okc) then
        pcall(function() parent:RemoveChild(sb) end)
        local okb, s = pcall(function() return parent:AddChild(w) end)
        if okb then dlm.slot_write(s, mine) end
        return false
    end
    return true
end
function dlm.text_layout(d)
    local pg = dlm.pg()
    local m, width = pg.text_margin or {}, tonumber(pg.text_width) or 0
    local sbc = obj_at("/Script/UMG.SizeBox")
    local tree = prop(d, "WidgetTree")
    local done = {}
    for _, k in ipairs({ "LongDescription", "ShortDescription" }) do
        local tu = prop(d, k)
        if is_valid(tu) then
            local holder, how = tu, ""
            if width > 0 then
                local parent = call(tu, "GetParent")
                local pn = is_valid(parent) and (full_name(parent) or "") or ""
                local okb, sb = false, nil
                if sbc and type(StaticConstructObject) == "function" then
                    okb, sb = pcall(StaticConstructObject, sbc, is_valid(tree) and tree or d)
                end
                if not is_valid(parent) then how = " width: no parent"
                elseif pn:find("^CanvasPanel ") then how = " width: not done (in a CanvasPanel)"
                elseif not (okb and is_valid(sb) and pcall(function() sb:SetWidthOverride(width) end)) then how = " width: no SizeBox"
                elseif dlm.wrap_in(parent, tu, sb) then holder, how = sb, " " .. width .. " wide"
                else how = " width: not put in its box" end
            end
            local mt = m.left or m.top or m.right or m.bottom
            if mt then
                local t = dlm.slot_read(holder) or {}
                local s = prop(holder, "Slot")
                local okp = s ~= nil and pcall(function()
                    s:SetPadding({ Left = (t.l or 0) + (m.left or 0), Top = (t.t or 0) + (m.top or 0),
                                   Right = (t.r or 0) + (m.right or 0), Bottom = (t.b or 0) + (m.bottom or 0) })
                end)
                how = how .. (okp and " margin set" or " margin not set")
            end
            done[#done + 1] = k .. (how ~= "" and how or " unchanged")
        end
    end
    return table.concat(done, ", ")
end
function dlm.fit_desc(d)
    local pg = dlm.pg()
    local done = {}
    for _, e in ipairs({ { "LongDescription", pg.desc_long_size or 16 }, { "ShortDescription", pg.desc_short_size or 20 } }) do
        local tu = prop(d, e[1])
        if is_valid(tu) then
            local tb = prop(tu, "TextBlock_0")
            local wrap = is_valid(tb) and pcall(function() tb:SetAutoWrapText(true) end)
            local fi = prop(tu, "In Font Info")
            local cur = fi ~= nil and n_of(prop(fi, "Size")) or nil
            local sized = " size " .. tostring(cur)
            if cur and e[2] and cur > e[2] then
                local okw = pcall(function() tu["In Font Info"].Size = e[2] end)
                local oku = okw and pcall(function() tu:UpdateTextStyle() end)
                sized = string.format(" size %s->%s%s", tostring(cur), tostring(e[2]),
                    okw and (oku and "" or " (UpdateTextStyle failed)") or " (not written)")
            end
            done[#done + 1] = e[1] .. (wrap and " wraps" or " wrap FAILED") .. sized
        end
    end
    local so = prop(d, "SelectedOption_Text")
    if is_valid(so) then pcall(function() so:SetAutoWrapText(true) end) end
    return table.concat(done, ", ")
end
function dlm.locked() return not (ap and tonumber(ap.options.death_link) == 1 and dl_cfg().enabled ~= false) end
function dlm.page_label()
    if dlm.locked() then return dlm.pg().off_label or "Off for this slot" end
    return DL_MENU[(dlm.value or 0) + 1][2]
end
function dlm.cards_label()
    local pg = dlm.pg()
    return dl.cards_blocked() and (pg.cards_on or "On") or (pg.cards_off or "Off")
end
function dlm.cards_set(on)
    dl.cards_choice = on
    dl.cards_rescan = on == true or nil
    log:write("AP", "Death Link menu: tooltips (instruction cards) now " .. (on and "blocked" or "shown like in the vanilla game")
        .. " (until the game is closed)")
end
function dlm.cards_desc(d)
    local pg = dlm.pg()
    local long = dl.cards_blocked()
        and (pg.cards_on_desc or "Checked: no instruction card (tooltip) ever shows, so none can get stuck on screen.")
        or (pg.cards_off_desc or "Unchecked: instruction cards (tooltips) show like in the vanilla game.")
    local tail = pg.cards_end or "Checked by default, checked again every time the game starts."
    if tail ~= "" then long = long .. "\n\n" .. tail end
    pcall(function() d:UpdateTitle(FText(pg.cards_row or "Disable Tooltips")) end)
    pcall(function() d:UpdateShortDescription(FText(pg.cards_short or "Hides the game's instruction cards.")) end)
    pcall(function() d:UpdateLongDescription(FText(long)) end)
end
function dlm.fire_count()
    local inv = (last_state or {}).inventory or {}
    local n = 0
    for _, it in pairs(type(APT) == "table" and APT.items or {}) do
        if it.kind == "collectible" then
            for _, name in ipairs(it.names or {}) do
                if inv[name] then n = n + 1; break end
            end
        end
    end
    return n
end
function dlm.fire_text()
    local pg = dlm.pg()
    return string.format(pg.fire_row or "Fire ending completion : %d/%d", dlm.fire_count(), pg.fire_needed or 39)
end
function dlm.page_show(with_desc)
    local p = dlm.page
    if not p then return end
    local fire = p.fire and obj_at(p.fire)
    if fire then pcall(function() fire:SetText(FText(dlm.fire_text())) end) end
    local combo = obj_at(p.combo)
    if combo then
        pcall(function() combo.ComboBoxText:SetText(FText(dlm.page_label())) end)
        pcall(function() combo.SettingsName_text:SetText(FText(dlm.pg().row or "Deathlink Behavior")) end)
    end
    local cards = obj_at(p.cards)
    if cards and p.cards_kind == "check" then
        pcall(function() cards.Title_Text:SetText(FText(dlm.pg().cards_row or "Disable Tooltips")) end)
        if prop(cards, "Checked") ~= dl.cards_blocked() then pcall(function() cards:StartingValue(dl.cards_blocked()) end) end
    elseif cards then
        pcall(function() cards.ComboBoxText:SetText(FText(dlm.cards_label())) end)
        pcall(function() cards.SettingsName_text:SetText(FText(dlm.pg().cards_row or "Disable Tooltips")) end)
    end
    if (with_desc or p.desc_shown) and p.desc_for == "cards" then
        local d = obj_at(p.desc)
        if d then dlm.cards_desc(d); p.desc_shown = true end
    elseif with_desc or p.desc_shown then
        local d = obj_at(p.desc)
        if d then
            local pg = dlm.pg()
            local name = dlm.page_label()
            local long = (pg.descriptions or {})[name] or dlm.DESC[name] or name
            local tail = pg.long_end or "When another player of the multiworld dies (Death Link), this animatronic comes for you. Back to your YAML setting every time the game starts."
            if name == "Disabled" then tail = pg.disabled_end or "Until the game is closed or you pick an animatronic again." end
            if dlm.locked() then
                long = pg.off_desc or "Death Link is off for this slot (death_link in your YAML). Turn it on in your YAML to pick who comes for you here."
                tail = ""
            end
            if tail ~= "" then long = long .. "\n\n" .. tail end
            pcall(function() d:UpdateTitle(FText(pg.desc_title or pg.row or "Deathlink Behavior")) end)
            pcall(function() d:UpdateShortDescription(FText(pg.short or "Who comes for you when another player dies.")) end)
            pcall(function() d:UpdateLongDescription(FText(long)) end)
            if not p.text_done then
                p.text_done = true
                local tl = dlm.text_layout(d)
                log:write("AP", "Death Link menu: description text " .. (tl ~= "" and tl or "blocks not found"))
            end
            local fit = dlm.fit_desc(d)
            if fit ~= p.fit_logged then log:write("AP", "Death Link menu: description " .. (fit ~= "" and fit or "text blocks not found")); p.fit_logged = fit end
            p.desc_shown = true
        end
    end
end
function dlm.overlay_open(p, open)
    local host, page = obj_at(p.host), obj_at(p.page)
    if not (host and page) then return end
    if open then
        local hid = {}
        local n = n_of(call(host, "GetChildrenCount")) or 0
        for i = 0, n - 1 do
            local c = call(host, "GetChildAt", i)
            if is_valid(c) and obj_path(c) ~= p.page then
                local v = n_of(call(c, "GetVisibility"))
                if v ~= 1 and pcall(function() c:SetVisibility(1) end) then hid[#hid + 1] = { path = obj_path(c), v = v or 0 } end
            end
        end
        p.hidden = hid
        pcall(function() page:SetVisibility(4) end)
        p.where = string.format(" (over the pause page, %d hidden)", #hid)
        p.open = true
        dlm.page_show(true)
        local combo = obj_at(p.combo)
        if combo then pcall(function() combo:SetKeyboardFocus() end) end
    else
        p.desc_for = nil
        pcall(function() page:SetVisibility(1) end)
        for _, h in ipairs(p.hidden or {}) do
            local c = obj_at(h.path)
            if c then pcall(function() c:SetVisibility(h.v) end) end
        end
        p.hidden = nil
        p.open = false
        local b = obj_at(p.button)
        if b then pcall(function() b:SetKeyboardFocus() end) end
    end
end
function dlm.page_open(open)
    local p = dlm.page
    if not p then return end
    local sw = obj_at(p.switcher)
    if p.mode == "overlay" then dlm.overlay_open(p, open)
    elseif not sw then return
    elseif open then
        local pg = obj_at(p.page)
        if pg then pcall(function() sw:SetActiveWidget(pg) end) end
        p.where = string.format(" (page %s of %s, shown %s)", tostring(pg and n_of(call(sw, "GetChildIndex", pg))),
            tostring(n_of(call(sw, "GetChildrenCount"))), tostring(n_of(call(sw, "GetActiveWidgetIndex"))))
        p.open = true
        dlm.page_show(true)
        local combo = obj_at(p.combo)
        if combo then pcall(function() combo:SetKeyboardFocus() end) end
    else
        pcall(function() sw:SetActiveWidgetIndex(0) end)
        p.open = false
        local b = obj_at(p.button)
        if b then pcall(function() b:SetKeyboardFocus() end) end
    end
    log:write("AP", "Death Link menu: Archipelago Options " .. (open and ("opened" .. (p.where or "")) or "closed"))
end
function dlm.page_clicked(path)
    local p = dlm.page
    if not (p and path) then return false end
    if path == p.button then
        if not p.open then dlm.page_open(true) end
        return true
    end
    if path == p.back then dlm.page_open(false); return true end
    return false
end
function dlm.page_cycle(ctx, delta, from_cycle)
    local p = dlm.page
    local path = obj_path(U.unwrap(ctx))
    if not (p and path and (path == p.combo or path == p.cards)) then return end
    p.desc_for = path == p.cards and "cards" or "dl"
    if from_cycle then dlm.cycle_seen = true
    elseif dlm.cycle_seen then dlm.page_show(true); return end
    if path == p.cards then dlm.cards_set(not dl.cards_blocked()); dlm.page_show(true); return end
    if dlm.locked() then dlm.page_show(true); return end
    if not delta or delta == 0 then delta = 1 end
    delta = delta > 0 and 1 or -1
    dlm.choose(((dlm.value or 0) + delta) % #DL_MENU)
    dlm.page_show(true)
end
function dlm.cards_clicked(ctx)
    local p = dlm.page
    local w = U.unwrap(ctx)
    if not (p and p.cards_kind == "check" and obj_path(w) == p.cards) then return end
    local was, now_c = dl.cards_blocked(), prop(w, "Checked")
    local new = not was
    dlm.cards_set(new)
    if now_c ~= new then pcall(function() w:StartingValue(new) end) end
    p.desc_for = "cards"
    dlm.page_show(true)
end
function dlm.check_hooks()
    if dlm.check_hooked ~= nil then return dlm.check_hooked end
    local K = dlm.UI.check .. ":"
    local hooks = {
        { K .. "BndEvt__Title_CheckBox_Button_0_K2Node_ComponentBoundEvent_0_OnButtonClickedEvent__DelegateSignature", dlm.cards_clicked },
        { K .. "BndEvt__Title_CheckBox_Button_0_K2Node_ComponentBoundEvent_1_OnButtonHoverEvent__DelegateSignature", dlm.page_hover },
        { K .. "BndEvt__Title_CheckBox_Button_0_K2Node_ComponentBoundEvent_3_OnButtonHoverEvent__DelegateSignature", dlm.page_hover },
        { K .. "OnAddedToFocusPath", dlm.page_hover },
    }
    dlm.check_hooked = true
    for i, h in ipairs(hooks) do
        local fn = h[2]
        local okh = pcall(RegisterHook, h[1], function(...) local a = { ... }; try("archipelago options", function() fn(table.unpack(a)) end) end)
        if not okh and i == 1 then dlm.check_hooked = false; dlm_say("checkbox click hook not set: the tooltips row is a < On / Off > row"); break end
    end
    return dlm.check_hooked
end
function dlm.page_hover(ctx)
    local p = dlm.page
    local path = p and obj_path(U.unwrap(ctx))
    if not path or (path ~= p.combo and path ~= p.cards) then return end
    p.desc_for = path == p.cards and "cards" or "dl"
    dlm.page_show(true)
end
function dlm.page_back(ctx)
    local p = dlm.page
    if not (p and p.open and obj_path(U.unwrap(ctx)) == p.pause) then return end
    dlm.page_open(false)
end
function dlm.pause_built(ctx)
    local pause = U.unwrap(ctx)
    local path = obj_path(pause)
    if not path or path:find("Default__", 1, true) or not is_valid(pause) then return end
    local mc = dl_cfg().pause_menu or {}
    if mc.enabled == false or world_busy() or dlm.page_failed or (mc.style or "page") ~= "page" then return end
    if not ap then return end
    local delay = dlm.pg().construct_delay_ms or 0
    if delay <= 0 then dlm.page_tick(pause); return end
    ExecuteWithDelay(delay, function()
        on_game_thread("archipelago options (pause menu made)", function()
            if world_busy() or dlm.page_failed then return end
            local pz = obj_at(path)
            if pz then try("archipelago options build", dlm.page_tick, pz) end
        end)
    end)
end
function dlm.construct_hook()
    if dlm.construct_hooked or not obj_at("/Game/Blueprints/UI/PauseUI.PauseUI_C") then return end
    dlm.construct_hooked = true
    local okh = dl.on_construct("/Game/Blueprints/UI/PauseUI.PauseUI_C", function(ctx)
        try("archipelago options (pause menu made)", dlm.pause_built, ctx)
    end)
    if not okh then dlm_say("pause menu Construct hook not set") end
end
function dlm.page_hooks()
    if dlm.page_hooked then return end
    dlm.page_hooked = true
    local C = dlm.UI.combo .. ":"
    local hooks = {
        { C .. "CycleThroughComboBox", function(ctx, nx) dlm.page_cycle(ctx, n_of(U.unwrap(nx)), true) end },
        { C .. "BndEvt__RightArrow_K2Node_ComponentBoundEvent_1_OnButtonPressedEvent__DelegateSignature", function(ctx) dlm.page_cycle(ctx, 1) end },
        { C .. "BndEvt__LeftArrow_K2Node_ComponentBoundEvent_4_OnButtonPressedEvent__DelegateSignature", function(ctx) dlm.page_cycle(ctx, -1) end },
        { C .. "Nav_RightArrow", function(ctx) dlm.page_cycle(ctx, 1) end },
        { C .. "Nav_LeftArrow", function(ctx) dlm.page_cycle(ctx, -1) end },
        { C .. "BndEvt__Title_ComboBox_Button_0_K2Node_ComponentBoundEvent_0_OnButtonHoverEvent__DelegateSignature", dlm.page_hover },
        { C .. "BndEvt__Title_ComboBox_Button_0_K2Node_ComponentBoundEvent_5_OnButtonHoverEvent__DelegateSignature", dlm.page_hover },
        { C .. "OnAddedToFocusPath", dlm.page_hover },
        { "/Game/Blueprints/UI/PauseUI.PauseUI_C:InputBack", dlm.page_back },
        { "/Game/Blueprints/UI/PauseUI.PauseUI_C:OpenInventoryMenu", dlm.inventory_opened },
    }
    local bad = {}
    for _, h in ipairs(hooks) do
        local fn = h[2]
        local okh = pcall(RegisterHook, h[1], function(...) local a = { ... }; try("archipelago options", function() fn(table.unpack(a)) end) end)
        if not okh then bad[#bad + 1] = h[1]:match(":(.+)$") end
    end
    if #bad > 0 then dlm_say("page hooks not set: " .. table.concat(bad, ", ")) end
end
function dlm.inventory_opened(ctx)
    local p = dlm.page
    if not p or (dlm.inv_said or 0) >= 5 then return end
    dlm.inv_said = (dlm.inv_said or 0) + 1
    local sw = obj_at(p.switcher)
    log:write("AP", string.format("Death Link menu: the game's Inventory opened (pause page %s of %s shown, Archipelago Options %s)",
        tostring(sw and n_of(call(sw, "GetActiveWidgetIndex"))), tostring(sw and n_of(call(sw, "GetChildrenCount"))),
        p.open and "open" or "closed"))
end
function dlm.page_intact(pause, p)
    local btn, page = obj_at(p.button), obj_at(p.page)
    if not (btn and page) then return false end
    local inv = prop(pause, dlm.pg().after or "InventoryButton")
    local box = is_valid(inv) and call(inv, "GetParent") or nil
    if obj_path(call(btn, "GetParent")) ~= obj_path(box) or obj_path(call(page, "GetParent")) ~= p.host then
        dlm_say("Archipelago Options taken out of the pause menu by the game: added again")
        return false
    end
    return true
end
function dlm.add_desc(hb, desc, sb, add)
    local t = { sv = 0.5, sr = 1, h = 3, t = 63, r = -25, l = 0, b = 0 }
    local w = dlm.pg().desc_width or 420
    if sb and w and w > 0 and pcall(function() sb:SetWidthOverride(w) end) then
        local ok, s = pcall(function() return sb:AddChild(desc) end)
        if ok then
            pcall(function() s:SetHorizontalAlignment(0) end)
            pcall(function() s:SetVerticalAlignment(0) end)
            dlm.desc_how = "description " .. w .. " wide"
            return add(hb, "AddChildToHorizontalBox", sb, t)
        end
    end
    dlm.desc_how = "description full width"
    return add(hb, "AddChildToHorizontalBox", desc, t)
end
function dlm.remove_ours(panel)
    if not (dlm.ours and is_valid(panel)) then return 0 end
    local n = n_of(call(panel, "GetChildrenCount")) or 0
    local old = {}
    for i = 0, n - 1 do
        local c = call(panel, "GetChildAt", i)
        if is_valid(c) and dlm.ours[obj_path(c) or ""] then old[#old + 1] = c end
    end
    for _, c in ipairs(old) do pcall(function() panel:RemoveChild(c) end) end
    return #old
end
function dlm.build_page(pause)
    local mc = dl_cfg().pause_menu or {}
    local pg = dlm.pg()
    local lib, bcls, ccls, dcls = obj_at(dlm.UI.lib), obj_at(dlm.UI.button), obj_at(dlm.UI.combo), obj_at(dlm.UI.desc)
    local U_ = {}
    for _, n in ipairs({ "Overlay", "HorizontalBox", "VerticalBox", "TextBlock", "Image", "SizeBox" }) do U_[n] = obj_at("/Script/UMG." .. n) end
    if not (lib and bcls and ccls and dcls and U_.Overlay and U_.HorizontalBox and U_.VerticalBox and U_.TextBlock and U_.Image) then
        return nil, string.format("classes missing (button %s, combo %s, description %s)", tostring(bcls ~= nil),
            tostring(ccls ~= nil), tostring(dcls ~= nil))
    end
    if type(StaticConstructObject) ~= "function" then return nil, "no StaticConstructObject" end
    local inv = prop(pause, pg.after or "InventoryButton")
    local box = is_valid(inv) and call(inv, "GetParent") or nil
    local pov = is_valid(box) and call(box, "GetParent") or nil
    local sw = is_valid(pov) and call(pov, "GetParent") or nil
    if not (is_valid(sw) and (full_name(sw) or ""):find("^WidgetSwitcher ")) then return nil, "no pause page switcher" end
    if not dlm.hook_click() then return nil, "no click hook" end
    dlm.page_hooks()
    dlm.construct_hook()
    local old_out = dlm.remove_ours(box) + dlm.remove_ours(pov) + dlm.remove_ours(sw)
    local tree = prop(pause, "WidgetTree")
    if not is_valid(tree) then tree = pause end
    local pc = call(pause, "GetOwningPlayer")
    local function bp(cls)
        local ok, w = pcall(function() return lib:Create(pause, cls, pc) end)
        return (ok and is_valid(w)) and w or nil
    end
    local function new(cls)
        local ok, w = pcall(StaticConstructObject, cls, tree)
        return (ok and is_valid(w)) and w or nil
    end
    local page, hb, left, rows, tov = new(U_.Overlay), new(U_.HorizontalBox), new(U_.Overlay), new(U_.VerticalBox), new(U_.Overlay)
    local title, backing = new(U_.TextBlock), new(U_.Image)
    local combo, desc, back = bp(ccls), bp(dcls), bp(bcls)
    local fire = pg.fire_row ~= false and new(U_.TextBlock) or nil
    local cards, cards_kind = nil, nil
    if pg.cards_row ~= false then
        local ck = (pg.cards_style or "check") == "check" and obj_at(dlm.UI.check) or nil
        if ck and dlm.check_hooks() then cards, cards_kind = bp(ck), "check" end
        if cards then pcall(function() cards:StartingValue(dl.cards_blocked()) end)
        else cards, cards_kind = bp(ccls), "combo" end
    end
    if not (page and hb and left and rows and tov and title and backing and combo and desc and back) then
        return nil, "widgets not made"
    end
    local m = pg.margin or {}
    local function add(parent, fn, w, t)
        local ok, s = pcall(function() return parent[fn](parent, w) end)
        if ok then dlm.slot_write(s, t) end
        return ok
    end
    local ok = add(page, "AddChildToOverlay", hb, { l = m.left or 100, t = m.top or 73, r = m.right or 0, b = m.bottom or 150 })
        and add(hb, "AddChildToHorizontalBox", left, { sv = 1.25, sr = 1 })
        and dlm.add_desc(hb, desc, U_.SizeBox and new(U_.SizeBox), add)
        and add(left, "AddChildToOverlay", rows, { t = pg.rows_top or 145, l = 0, r = 0, b = 0 })
        and add(left, "AddChildToOverlay", tov, { h = 2, v = 1, l = 243, t = 1, r = 0, b = 0 })
        and add(tov, "AddChildToOverlay", backing, { h = 2, v = 2 })
        and add(tov, "AddChildToOverlay", title, { h = 2, v = 2 })
        and add(rows, "AddChildToVerticalBox", combo, { r = pg.row_right or 80, l = 0, t = 0, b = 0 })
        and (not cards or add(rows, "AddChildToVerticalBox", cards, { r = pg.row_right or 80, l = 0, t = pg.row_gap or 0, b = 0 }))
        and (not fire or add(rows, "AddChildToVerticalBox", fire, { r = pg.row_right or 80, l = 0, t = pg.fire_top or 30, b = 0 }))
        and add(rows, "AddChildToVerticalBox", back, { t = pg.back_top or 40, l = 0, r = 0, b = 0, h = 1 })
    if not ok then return nil, "page not assembled" end
    local tex, font = obj_at(dlm.UI.backing), obj_at(dlm.UI.font)
    if tex then pcall(function() backing:SetBrushFromTexture(tex, true) end); pcall(function() backing:SetRenderScale({ X = 1.07, Y = 1.0 }) end)
    else pcall(function() backing:SetVisibility(1) end) end
    if font then pcall(function() title:SetFont({ FontObject = font, TypefaceFontName = FName("Default"), Size = 30 }) end) end
    pcall(function() title:SetJustification(1) end)
    pcall(function() title:SetText(FText(pg.title or "ARCHIPELAGO")) end)
    if fire then
        local bf = obj_at(dlm.UI.button_font)
        if bf then pcall(function() fire:SetFont({ FontObject = bf, TypefaceFontName = FName("Default"), Size = pg.fire_font_size or 30 }) end) end
        pcall(function() fire:SetText(FText(dlm.fire_text())) end)
    end
    local _, back_font = dlm.copy_button_style(back, inv)
    pcall(function() back["Set Display"](back, FText(pg.back or "Back")) end)
    local in_sw = (pg.host or "overlay") == "switcher"
    local host = in_sw and sw or pov
    if in_sw then
        if not pcall(function() sw:AddChild(page) end) then return nil, "page not added to the switcher" end
    else
        if not add(pov, "AddChildToOverlay", page, { h = 0, v = 0 }) then return nil, "page not added over the pause page" end
        pcall(function() page:SetVisibility(1) end)
    end
    local btn = bp(bcls)
    if not btn then pcall(function() host:RemoveChild(page) end); return nil, "button not made" end
    local styled, font_how = dlm.copy_button_style(btn, inv)
    pcall(function() btn["Set Display"](btn, FText(pg.button or "Archipelago Options")) end)
    local okb, moved = dlm.insert_after(box, inv, btn)
    if not okb then pcall(function() host:RemoveChild(page) end); return nil, "button not added after " .. (pg.after or "InventoryButton") end
    dlm.value = dlm_index(dl_behavior())
    dlm.ours = dlm.ours or {}
    dlm.ours[obj_path(btn) or "?"], dlm.ours[obj_path(page) or "?"] = true, true
    if old_out > 0 then log:write("AP", "Death Link menu: " .. old_out .. " old Archipelago Options widget(s) taken out first") end
    dlm.page = { pause = obj_path(pause), button = obj_path(btn), page = obj_path(page), switcher = obj_path(sw),
                 host = obj_path(host), mode = in_sw and "switcher" or "overlay",
                 combo = obj_path(combo), cards = cards and obj_path(cards) or nil, cards_kind = cards_kind,
                 fire = fire and obj_path(fire) or nil,
                 desc = obj_path(desc), back = obj_path(back), open = false }
    dlm.page_show()
    log:write("AP", string.format("Death Link menu: Archipelago Options button added after %s (%d below moved down, %d style fields copied, %s; Back: %s), page added %s (%s), showing %s%s",
        pg.after or "InventoryButton", moved or 0, styled, tostring(font_how), tostring(back_font),
        in_sw and "to the pause page switcher" or "over the pause page", tostring(dlm.desc_how), dlm.page_label(),
        fire and (", " .. dlm.fire_text()) or ""))
    return true
end
function dlm.page_tick(pause)
    local mc = dl_cfg().pause_menu or {}
    local key = obj_path(pause) or "?"
    local p = dlm.page
    if p and p.pause == key and dlm.page_intact(pause, p) then return end
    if p and p.open then dlm.page_open(false) end
    dlm.page = nil
    local tk = "page " .. key
    dlm.tries[tk] = (dlm.tries[tk] or 0) + 1
    if dlm.tries[tk] > (mc.max_tries or 3) then return end
    local ok, why = dlm.build_page(pause)
    if ok then dlm.tries[tk] = 0; return end
    dlm_say("Archipelago Options not added (" .. tostring(why) .. ")")
    if dlm.tries[tk] >= (mc.max_tries or 3) then
        dlm.page_failed = true
        dlm_say("Archipelago Options given up: the list instead")
    end
end
function dlm.read_dropdown(w)
    local text = U.to_str(prop(w, "SelectedOption"))
    if not text or text == "" or text == dlm.last_text then return end
    dlm.last_text = text
    for i, e in ipairs(DL_MENU) do
        if e[2] == text and dlm.value ~= i - 1 then
            dlm.value = i - 1
            dl.override = e[1]
            dl.choice_key, dl.choice_how = nil, nil
            log:write("AP", "Death Link menu: now " .. e[2] .. " (until the game is closed)")
        end
    end
end
local function dlm_attach(pause)
    local mc = dl_cfg().pause_menu or {}
    local cls = obj_at(mc.class or "/Game/Blueprints/UI/TitleButton.TitleButton_C")
    local lib = obj_at("/Script/UMG.Default__WidgetBlueprintLibrary")
    local anchor = prop(pause, mc.after or "MessagesButton")
    if not (cls and lib and is_valid(anchor)) then
        dlm_say(string.format("not added yet (button class %s, widget library %s, %s %s)", tostring(cls ~= nil),
            tostring(lib ~= nil), mc.after or "MessagesButton", tostring(is_valid(anchor))))
        return
    end
    local box = call(anchor, "GetParent")
    if not is_valid(box) then dlm_say("not added (no box above the buttons)"); return end
    if (mc.style or "list") ~= "button" and dlm.attach_dropdown(pause, box) then return end
    if not dlm.hooked then
        local okh, errh = pcall(RegisterHook, dlm.CLICK, function(ctx) try("death link menu click", dlm.clicked, ctx) end)
        dlm.hooked = okh
        if not okh then dlm_say("click hook FAILED: " .. tostring(errh)); return end
    end
    local pc = call(pause, "GetOwningPlayer")
    local okw, w = pcall(function() return lib:Create(pause, cls, pc) end)
    if not (okw and is_valid(w)) then dlm_say("not added (Create failed: " .. tostring(w) .. ")"); return end
    local cur = dlm_index(dl_behavior())
    local okc = pcall(function() box:AddChild(w) end)
    if not okc then dlm_say("not added (AddChild failed)"); return end
    local shown = dlm.show(w, cur)
    dlm.widget, dlm.pause, dlm.value, dlm.kind = obj_path(w), obj_path(pause), cur, "button"
    log:write("AP", string.format("Death Link menu: button added to the pause menu, showing %s%s", DL_MENU[cur + 1][2],
        shown and "" or " [label FAILED]"))
end
local function dl_menu_tick()
    local mc = dl_cfg().pause_menu or {}
    if mc.enabled == false or world_busy() then return end
    if (mc.style or "page") == "page" then dlm.construct_hook() end
    local here = obj_at(dlm.widget)
    if here and dlm.kind == "dropdown" then dlm.read_dropdown(here) end
    if world_now_ms() < dlm.next_look then return end
    dlm.next_look = world_now_ms() + (mc.look_ms or 1000)
    local gs, greg = obj_at("/Script/Engine.Default__GameplayStatics"), find("Gregory_C")
    if not (gs and greg and call(gs, "IsGamePaused", greg) == true) then
        for _, h in pairs(dlm.hosts) do if h.open then dlm.toggle(h, false) end end
        if dlm.page and dlm.page.open then dlm.page_open(false) end
        return
    end
    local pause = dlm.shown_pause()
    if not pause then return end
    local style = mc.style or "page"
    if style == "page" and not dlm.page_failed then dlm.page_tick(pause); return end
    if (style == "page" or style == "list") and not dlm.list_failed then dlm.list_tick(pause); return end
    local key = obj_path(pause) or "?"
    if here and key == dlm.pause then return end
    dlm.widget = nil
    dlm.tries[key] = (dlm.tries[key] or 0) + 1
    if dlm.tries[key] > (mc.max_tries or 3) then return end
    dlm_attach(pause)
    if dlm.widget then dlm.tries[key] = 0 end
end

local effects = {}
local function num(v) return tonumber(U.to_str(v)) end
local function setp(o, k, v) return pcall(function() o[k] = v end) end
local function stamina_comp()
    local greg = find("Gregory_C")
    local sc = greg and prop(greg, "SprintStamina")
    return is_valid(sc) and sc or nil
end
local function input_settings() return StaticFindObject("/Script/Engine.Default__InputSettings") end
local function remap_axes(e)
    local ist = input_settings()
    if not is_valid(ist) then return "no InputSettings" end
    local ax = (apcfg.effects or {}).reverse_axes or { "MoveForward", "MoveRight" }
    local fwd, right = ax[1], ax[2]
    local swap, sf, sr
    repeat
        swap = math.random(2) == 2
        sf = math.random(2) == 2 and -1 or 1
        sr = math.random(2) == 2 and -1 or 1
    until swap or sf ~= 1 or sr ~= 1
    local n, seen, back = 0, {}, {}
    e.orig = {}
    for idx, m in ipairs(U.list_from_array(prop(ist, "AxisMappings"), function(x) return x end)) do
        local name = U.to_str(prop(m, "AxisName"))
        seen[name] = true
        local sc = num(prop(m, "Scale"))
        if sc and (name == fwd or name == right) then
            local na = name
            if swap then na = (name == fwd) and right or fwd end
            local ns = sc * ((name == fwd) and sf or sr)
            local ok = setp(m, "Scale", ns)
            if ok and na ~= name then ok = setp(m, "AxisName", fname_add(na)) end
            if ok then
                e.orig[idx] = { name = name, scale = sc }
                n = n + 1
                back[#back + 1] = string.format("%s %g->%s %s", name, sc, U.to_str(prop(m, "AxisName")), U.to_str(prop(m, "Scale")))
            end
        end
    end
    local okr = pcall(function() ist:ForceRebuildKeymaps() end)
    if n == 0 then return "no " .. fwd .. "/" .. right .. " mapping (axes: " .. table.concat(U.sorted_keys(seen), ", ") .. ")" end
    local function dir(axis_right, sign)
        if axis_right then return sign > 0 and "right" or "left" end
        return sign > 0 and "forward" or "back"
    end
    return string.format("forward->%s, right->%s; %d mapping(s) changed, rebuild %s [%s]",
        dir(swap, sf), dir(not swap, sr), n, okr and "ok" or "FAILED", table.concat(back, "; "))
end
local function restore_axes(e)
    local ist = input_settings()
    if not is_valid(ist) then return "no InputSettings" end
    local n = 0
    for idx, m in ipairs(U.list_from_array(prop(ist, "AxisMappings"), function(x) return x end)) do
        local o = e.orig[idx]
        if o and setp(m, "Scale", o.scale) and setp(m, "AxisName", fname_add(o.name)) then n = n + 1 end
    end
    local okr = pcall(function() ist:ForceRebuildKeymaps() end)
    return string.format("%d mapping(s) back, rebuild %s", n, okr and "ok" or "FAILED")
end
local function controller()
    local greg = find("Gregory_C")
    local pc = greg and call(greg, "GetController")
    if not is_valid(pc) then pc = find("MainGamePC_C") end
    return is_valid(pc) and pc or nil
end
local SPEED_FIELDS = { "DefaultWalkSpeed", "RunSpeed", "SuperRunSpeed", "DefaultCrouchSpeed" }
local function apply_speed(greg)
    pcall(function() greg["Setup Movement Speed"](greg) end)
end
local EFFECTS = {
    asthma = {
        greg = true,
        tick = function(e)
            local sc = stamina_comp(); if not sc then return end
            local r = num(prop(sc, "StaminaRefillRate"))
            if r and r ~= 0 then e.saved = r; setp(sc, "StaminaRefillRate", 0) end
        end,
        stop = function(e)
            local sc = stamina_comp()
            if sc and e.saved and num(prop(sc, "StaminaRefillRate")) == 0 then setp(sc, "StaminaRefillRate", e.saved) end
            return "refill rate back to " .. tostring(e.saved)
        end,
    },
    energy_drink = {
        greg = true,
        start = function(e)
            local sc = stamina_comp(); if not sc then return "no SprintStamina" end
            local mx = num(prop(sc, "MaxStamina"))
            if mx then setp(sc, "CurrentStamina", mx) end
            return ""
        end,
        tick = function(e)
            local sc = stamina_comp(); if not sc then return end
            local d = num(prop(sc, "StaminaDepleteRate"))
            if d and d ~= 0 then e.saved = d; setp(sc, "StaminaDepleteRate", 0) end
        end,
        stop = function(e)
            local sc = stamina_comp()
            if sc and e.saved and num(prop(sc, "StaminaDepleteRate")) == 0 then setp(sc, "StaminaDepleteRate", e.saved) end
            return "deplete rate back to " .. tostring(e.saved)
        end,
    },
    caffeine = {
        greg = true,
        tick = function(e)
            local greg = find("Gregory_C"); if not greg then return end
            local mult = ((apcfg.effects or {}).caffeine or {}).speed_mult or 1.15
            if e.who ~= full_name(greg) then e.who, e.base, e.boosted = full_name(greg), {}, {} end
            local changed = false
            for _, f in ipairs(SPEED_FIELDS) do
                local v = num(prop(greg, f))
                if v and v > 0 and (not e.boosted[f] or math.abs(v - e.boosted[f]) > 0.01) then
                    e.base[f], e.boosted[f] = v, v * mult
                    setp(greg, f, v * mult)
                    changed = true
                end
            end
            local cm = prop(greg, "CharacterMovement")
            local w = is_valid(cm) and num(prop(cm, "MaxWalkSpeed"))
            if w then
                for f, b in pairs(e.base) do
                    if math.abs(w - b) < 0.5 then setp(cm, "MaxWalkSpeed", e.boosted[f]); break end
                end
            end
            if changed then apply_speed(greg) end
        end,
        stop = function(e)
            local greg = find("Gregory_C")
            if not greg or e.who ~= full_name(greg) then return "Gregory changed, nothing to restore" end
            for f, b in pairs(e.base or {}) do
                local v = num(prop(greg, f))
                if v and math.abs(v - e.boosted[f]) < 0.01 then setp(greg, f, b) end
            end
            local cm = prop(greg, "CharacterMovement")
            local w = is_valid(cm) and num(prop(cm, "MaxWalkSpeed"))
            if w then
                for f, b in pairs(e.base or {}) do
                    if math.abs(w - e.boosted[f]) < 0.5 then setp(cm, "MaxWalkSpeed", b); break end
                end
            end
            apply_speed(greg)
            return "speeds back"
        end,
    },
    recharge = {
        start = function(e)
            local ws = find("WorldStateSystem"); if not ws then return "no WorldStateSystem" end
            e.want = call(ws, "CanCallFreddy") ~= false
            effects_setting = true
            pcall(function() ws:SetCanCallFreddy(false) end)
            effects_setting = false
            return "CanCallFreddy was " .. tostring(e.want)
        end,
        tick = function(e)
            local ws = find("WorldStateSystem"); if not ws then return end
            if call(ws, "CanCallFreddy") == true then
                e.want = true
                effects_setting = true
                pcall(function() ws:SetCanCallFreddy(false) end)
                effects_setting = false
            end
        end,
        stop = function(e)
            local ws = find("WorldStateSystem"); if not ws then return "no WorldStateSystem" end
            if e.want then
                effects_setting = true
                pcall(function() ws:SetCanCallFreddy(true) end)
                effects_setting = false
            end
            return "CanCallFreddy back to " .. tostring(e.want)
        end,
    },
    stun = {
        start = function(e)
            local pc = controller(); if not pc then return "no PlayerController" end
            local ok = pcall(function() pc:SetIgnoreMoveInput(true) end)
            if ok then e.pc = full_name(pc) end
            return "SetIgnoreMoveInput(true) " .. (ok and "ok" or "FAILED")
        end,
        tick = function(e)
            local ec = (apcfg.effects or {}).stun or {}
            if not ec.sound then return end
            local greg = find("Gregory_C"); if not greg then return end
            local pc = controller()
            local seen = {}
            for _, ax in ipairs((apcfg.effects or {}).reverse_axes or { "MoveForward", "MoveRight" }) do
                local v = num(call(greg, "GetInputAxisValue", fname_add(ax)))
                if v and math.abs(v) > 0.2 then seen[#seen + 1] = "Gregory " .. ax end
                local w = pc and num(call(pc, "GetInputAxisValue", fname_add(ax)))
                if w and math.abs(w) > 0.2 then seen[#seen + 1] = "controller " .. ax end
            end
            if pc and ec.key_poll then
                for _, k in ipairs(ec.keys or { "W", "A", "S", "D" }) do
                    local okk, down = pcall(function() return pc:IsInputKeyDown({ KeyName = fname_add(k) }) end)
                    if okk and down == true then seen[#seen + 1] = "key " .. k end
                end
            end
            local trying = #seen > 0
            e.sources = e.sources or {}
            for _, src in ipairs(seen) do
                if not e.sources[src] then
                    e.sources[src] = true
                    log:write("AP", "effect stun: move attempt seen by " .. src)
                end
            end
            local now = world_now_ms()
            if trying and (not e.was_trying or now >= (e.next_beep or 0)) then
                if play_sound(ec.sound, "effect stun", e.beeps ~= nil) then e.beeps = (e.beeps or 0) + 1 end
                e.next_beep = now + (ec.beep_ms or 900)
            end
            e.was_trying = trying
        end,
        stop = function(e)
            local pc = controller()
            if not pc or full_name(pc) ~= e.pc then return "controller changed, nothing to restore" end
            local ok = pcall(function() pc:SetIgnoreMoveInput(false) end)
            return "SetIgnoreMoveInput(false) " .. (ok and "ok" or "FAILED") .. string.format(", %d beep(s)", e.beeps or 0)
        end,
    },
    reverse = {
        start = function(e) e.orig = {}; return remap_axes(e) end,
        stop = function(e) if next(e.orig or {}) == nil then return "nothing changed" end return restore_axes(e) end,
    },
    foxy = {
        greg = true,
        start = function(e) return dl.foxy_start(e) end,
        tick = function(e) dl.foxy_tick(e) end,
        stop = function(e) return dl.foxy_stop(e) end,
    },
    shut_up = {
        greg = true,
        start = function(e)
            local ec = (apcfg.effects or {}).shut_up or {}
            local folder = ec.path or "/Game/Audio/Character/VO/Freddy/"
            local list, loaded, found = {}, 0, 0
            for _, l in ipairs(ec.lines or {}) do
                local path = folder .. l[1] .. "." .. l[1]
                local ok, o = pcall(StaticFindObject, path)
                if ok and is_valid(o) then found = found + 1
                elseif type(LoadAsset) == "function" then
                    local okl, ol = pcall(LoadAsset, path)
                    if okl and is_valid(ol) then loaded = loaded + 1 end
                end
                list[#list + 1] = { name = l[1], path = path, s = l[2] }
            end
            e.lines, e.played = list, 0
            return string.format("%d voice line(s) (%d already loaded, %d loaded now)", #list, found, loaded)
        end,
        tick = function(e)
            local ec = (apcfg.effects or {}).shut_up or {}
            local now = world_now_ms()
            local greg = find("Gregory_C"); if not greg then return end
            local comp = e.comp_path and StaticFindObject(e.comp_path)
            if comp and not is_valid(comp) then comp = nil end
            if e.comp_path and comp and not e.attached then
                local x, y, z = location_of(greg)
                pcall(function() comp:K2_SetWorldLocation({ X = x, Y = y, Z = z }, false, {}, true) end)
            end
            if #e.lines == 0 or now < (e.next_ms or 0) then return end
            if not comp and not e.comp_failed then
                local gs = StaticFindObject("/Script/AkAudio.Default__AkGameplayStatics")
                local x, y, z = location_of(greg)
                local ok, c = pcall(function()
                    return gs:SpawnAkComponentAtLocation(greg, nil, { X = x, Y = y, Z = z }, { Pitch = 0, Yaw = 0, Roll = 0 }, false, "", false)
                end)
                if ok and is_valid(c) then
                    comp = c
                    e.comp_path = full_name(c):match("^%S+ (.+)$") or full_name(c)
                    local root = prop(greg, "RootComponent")
                    e.attached = is_valid(root) and pcall(function()
                        c:K2_AttachToComponent(root, fname_add("None"), 2, 2, 2, false) end) or false
                    local okv = pcall(function() c:SetOutputBusVolume(ec.volume or 2.0) end)
                    log:write("AP", string.format("effect shut_up: own sound component, attached to Gregory %s, volume x%s %s",
                        e.attached and "ok" or "FAILED (moved every tick)", tostring(ec.volume or 2.0), okv and "ok" or "FAILED"))
                else
                    e.comp_failed = true
                    log:write("AP", "effect shut_up: no sound component (" .. tostring(c) .. "), played on Gregory")
                end
            end
            local k = math.random(#e.lines)
            if #e.lines > 1 and k == e.last then k = k % #e.lines + 1 end
            e.last = k
            local line = e.lines[k]
            local how = "own component"
            local id = comp and tonumber(U.to_str(call(comp, "PostAkEventByName", line.name)))
            if not id or id == 0 then
                how = "on Gregory"
                play_sound({ name = line.name, paths = { line.path } }, "effect shut_up", true)
            end
            e.played = e.played + 1
            local dur = line.s or ec.fallback_s or 4
            e.next_ms = now + math.max(dur - (ec.overlap_s or 0.5), 0.3) * 1000
            e.line_end = now + dur * 1000
            log:write("AP", string.format("effect shut_up: %s (%.1f s, %s)", line.name, dur, how))
        end,
        stop = function(e)
            if e.comp_path then
                local path = e.comp_path
                local wait = math.max((e.line_end or 0) - world_now_ms(), 0) + 500
                ExecuteWithDelay(math.floor(wait), function() on_game_thread("shut_up end", function()
                    local c = StaticFindObject(path)
                    if c and is_valid(c) then pcall(function() c:K2_DestroyComponent(c) end) end
                end) end)
            end
            return string.format("%d line(s) played", e.played or 0)
        end,
    },
    shutdown = {
        instant = true,
        start = function(e)
            local ec = (apcfg.effects or {}).shutdown or {}
            local greg = find("Gregory_C"); if not greg then return "no Gregory" end
            local gx, gy, gz = location_of(greg)
            local ams = live_ams()
            if not ams then return "no AIManagementSystem" end
            local notes, n = {}, 0
            for _, p in ipairs(U.list_from_array(call(ams, "GetAllAI"), function(x) return x end)) do
                if is_valid(p) then
                    local px, py, pz = location_of(p)
                    local d = math.sqrt((px - gx) ^ 2 + (py - gy) ^ 2 + (pz - gz) ^ 2)
                    local short = full_name(p):match("([^%.:]+)$") or "?"
                    if d <= (ec.radius or 2500) then
                        local ok, err = pcall(function() p:StunForDuration(ec.stun_s or 60) end)
                        if ok then n = n + 1 end
                        notes[#notes + 1] = string.format("%s %.0f %s", short, d, ok and "stunned" or ("FAILED " .. tostring(err)))
                    end
                end
            end
            return string.format("%d stunned for %d s [%s]", n, ec.stun_s or 60, table.concat(notes, "; "))
        end,
    },
}
local function effect_key(item) return ((apcfg.effects or {}).items or {})[item] end
local function start_effect(a)
    local key = effect_key(a.item)
    local def = key and EFFECTS[key]
    if not def then log:write("AP", "effect: " .. a.item .. " has no effect in config.lua (effects.items)"); return end
    local ec = (apcfg.effects or {})[key] or {}
    local ms = (ec.seconds or 10) * 1000
    local e = effects[key]
    if e then
        e.until_ms = math.max(e.until_ms, world_now_ms() + ms)
        log:write("AP", string.format("effect %s (%s): already running, now %d s left", key, a.item, math.floor((e.until_ms - world_now_ms()) / 1000)))
        return
    end
    if not security_seeded then math.randomseed(os.time()); security_seeded = true end
    e = { until_ms = world_now_ms() + ms }
    local note = def.start and def.start(e) or ""
    if def.tick then def.tick(e) end
    if def.instant then
        log:write("AP", string.format("effect %s (%s): %s", key, a.item, note))
        return
    end
    effects[key] = e
    log:write("AP", string.format("effect %s (%s) for %s s%s", key, a.item, tostring(ec.seconds or 10), note ~= "" and (": " .. note) or ""))
end
local function effects_tick()
    local now = world_now_ms()
    for key, e in pairs(effects) do
        local def = EFFECTS[key]
        if now >= e.until_ms then
            effects[key] = nil
            local note = def.stop and def.stop(e) or ""
            log:write("AP", string.format("effect %s over%s", key, note ~= "" and (": " .. note) or ""))
        elseif def.tick and not (def.greg and world_busy()) then
            def.tick(e)
        end
    end
end
if cfg.native_hooks_enabled then pcall(RegisterHook, "/Script/fnaf9.WorldStateSystem:SetCanCallFreddy", function()
    local e = effects.recharge
    if not e or effects_setting then return end
    local ws = find("WorldStateSystem")
    if ws then e.want = call(ws, "CanCallFreddy") == true end
end) end

local function run_action(inv, a)
    if a.op == "task" then
        local ms = find("FNAFMissionSystem")
        if not ms then error("no FNAFMissionSystem") end
        log:write("AP", string.format("CompleteMissionTask %s %d (%s)", a.mission, a.task, a.key))
        ms:CompleteMissionTask(fname(a.mission), a.task)
    elseif a.op == "remove" then
        log:write("AP", "RemoveItem " .. a.name)
        inv:RemoveItem(fname(a.name))
    elseif a.op == "award" then
        log:write("AP", "AwardItem " .. a.name)
        inv:AwardItem(fname(a.name), apcfg.notify and true or false)
    elseif a.op == "security" then
        log:write("AP", "SetSecurityLevel " .. a.level)
        inv:SetSecurityLevel(a.level)
    elseif a.op == "alert" then
        if (apcfg.security_alert or {}).mode == "own" then security_alert(a) else dl.security_trap(a) end
    elseif a.op == "effect" then
        start_effect(a)
    elseif a.op == "battery" then
        local ws = find("WorldStateSystem")
        local in_freddy = ws ~= nil and call(ws, "IsPlayerInFreddy") == true
        local which = in_freddy and "Freddy" or "Fazwatch"
        local cur = tonumber(U.to_str(prop(inv, which .. "PowerLevel"))) or 0
        local max = tonumber(U.to_str(prop(inv, which .. "MaxPowerLevel"))) or 0
        local delta
        if a.mode == "refill" then
            delta = max - cur
        else
            delta = -math.floor(max * (apcfg.battery_drain_fraction or 0.5))
        end
        log:write("AP", string.format("%s: %s battery %d/%d, AdjustPower_%s(%d)",
            a.item, in_freddy and "Freddy's" or "flashlight", cur, max, which, delta))
        if delta ~= 0 then inv["AdjustPower_" .. which](inv, delta) end
    end
end

local ready_polls = 0

local function find_live(cls)
    local key = "live " .. cls
    local c = cached(key)
    if c then return c end
    for _, o in ipairs(FindAllOf(cls) or {}) do
        if is_valid(o) and not full_name(o):find("Default__", 1, true) then
            remember(key, o)
            return o
        end
    end
    return nil
end

local function now() return (type(AP_CLOCK) == "function" and AP_CLOCK()) or os.time() end

dl.awards = { why = "not loaded yet", free_since = nil }
function dl.hold_on()
    return (apcfg.instruction_cards or {}).hold ~= false and not dl.cards_blocked()
end
function dl.player_busy()
    local cc = apcfg.instruction_cards or {}
    if world.loading and world_now() < world.loading then return "loading screen" end
    if world.loaded_at and world_now() - world.loaded_at < (cc.after_load_s or 15) then return "just loaded" end
    local pc = controller()
    if not pc then return "no player controller" end
    local pawn = call(pc, "K2_GetPawn")
    local pn = is_valid(pawn) and ((full_name(pawn) or ""):match("^(%S+)") or "?") or "nil"
    if pn ~= (cc.player_pawn or "Gregory_C") then return "playing as " .. pn end
    return dl.sequence(pc) or dl.camera_view(pc)
end
function dl.sequence(pc)
    if pc and prop(pc, "IsPlaySequenceRunning?") == true then return "cinematic" end
    return nil
end
function dl.camera_view(pc)
    local vt = pc and call(pc, "GetViewTarget")
    local vc = is_valid(vt) and ((full_name(vt) or ""):match("^(%S+)") or "") or ""
    if vc:find("Camera", 1, true) then return "cinematic (view through " .. vc .. ")" end
    return nil
end
function dl.paused(greg)
    local gs = obj_at("/Script/Engine.Default__GameplayStatics")
    return gs ~= nil and greg ~= nil and call(gs, "IsGamePaused", greg) == true
end
function dl.hiding(greg)
    return prop(greg, "IsHiding") == true or prop(greg, "Hide/Unhide Transition Active") == true
end
function dl.controller() return controller() end
function dl.ui_hooks()
    if dl.ui_hooked then return end
    local gi = "/Game/Blueprints/System/FNAFGameInstance.FNAFGameInstance_C:"
    local ok1 = pcall(RegisterHook, gi .. "OnLoadingScreenStart", function()
        world.loading = world_now() + ((apcfg.instruction_cards or {}).loading_max_s or 60)
    end)
    local ok2 = pcall(RegisterHook, gi .. "OnLoadingScreenEnd", function()
        world.loading, world.loaded_at = nil, world_now()
        world.load_end = world_now() + (cfg.after_loading_s or 5)
    end)
    local ok3 = (apcfg.instruction_cards or {}).hold == false or pcall(RegisterHook,
        "/Game/Blueprints/UI/PlayerHUD.PlayerHUD_C:ShowInstructions", function(_, typ)
            local t = nil
            pcall(function() t = tonumber(typ:get()) end)
            on_game_thread("instruction card", function() dl.card_shown(t) end)
        end)
    if ok1 and ok2 and ok3 then
        dl.ui_hooked = true
        log:write("AP", "loading screen and instruction card hooks set")
    end
end
function dl.card_shown(t)
    if not dl.cards_blocked() then
        if t then popup.cards.by_mod[t] = nil end
        return
    end
    local gi = find("FNAFGameInstance_C")
    log:write("AP", string.format("instruction card %s opened anyway (%s, %d card(s) marked as seen)", tostring(t),
        dl.player_busy() or "player free", gi and #dl.cards_seen(gi) or -1))
end
popup.cards = { marked_for = nil, triggers = {}, scan_next = 0, by_mod = {} }
function dl.cards_blocked()
    if dl.cards_choice ~= nil then return dl.cards_choice end
    return (apcfg.instruction_cards or {}).none ~= false
end
function dl.cards_seen(gi)
    return U.list_from_array(prop(gi, "InstructionCardsSeen"), function(v) return U.to_str(v) end)
end
function dl.cards_mark()
    local cc = apcfg.instruction_cards or {}
    local gi = find("FNAFGameInstance_C")
    if not gi then return end
    local n = cc.types or 48
    local before = dl.cards_seen(gi)
    if #before >= n then return end
    trace_step("instruction cards: marking " .. (n - #before) .. " as seen")
    local called = 0
    local by_mod = popup.cards.by_mod
    for t = 0, n - 1 do
        local k = #dl.cards_seen(gi)
        if pcall(function() gi:InstructionCardViewed(t, {}) end) then called = called + 1 end
        if #dl.cards_seen(gi) > k then by_mod[t] = true end
    end
    local after = dl.cards_seen(gi)
    local written = 0
    local prefix = nil
    for _, e in ipairs(after) do prefix = prefix or e:match("^(.-)%d+$") end
    if prefix and #after < n then
        local have = {}
        for _, e in ipairs(after) do have[e] = true end
        local arr = prop(gi, "InstructionCardsSeen")
        for t = 0, n - 1 do
            local name = prefix .. t
            if not have[name] and pcall(function() arr[#dl.cards_seen(gi) + 1] = name end) then
                written = written + 1
                by_mod[t] = true
            end
        end
        after = dl.cards_seen(gi)
    end
    log:write("AP", string.format("instruction cards marked as seen: %d in the list (was %d; InstructionCardViewed called %d times, %d written by name%s)%s",
        #after, #before, called, written, prefix and (" '" .. prefix .. "N'") or ", no name seen yet",
        #after > 0 and (": " .. table.concat(after, ", ", 1, math.min(#after, 6)) .. (#after > 6 and ", ..." or "")) or ""))
end
function dl.cards_unmark()
    local c = popup.cards
    local gi = find("FNAFGameInstance_C")
    local emptied, kept = false, 0
    if gi and c.marked_for ~= nil then
        local arr = prop(gi, "InstructionCardsSeen")
        emptied = arr ~= nil and pcall(function() arr:Empty() end) and #dl.cards_seen(gi) == 0
        if emptied then
            for t = 0, ((apcfg.instruction_cards or {}).types or 48) - 1 do
                if not c.by_mod[t] and pcall(function() gi:InstructionCardViewed(t, {}) end) then kept = kept + 1 end
            end
        end
    end
    local back = 0
    if next(c.triggers) then
        for _, t in ipairs(FindAllOf((apcfg.instruction_cards or {}).trigger_class or "InstructionCardTrigger_C") or {}) do
            local key = is_valid(t) and full_name(t)
            if key and c.triggers[key] then call(t, "SetActorEnableCollision", true); back = back + 1 end
        end
    end
    log:write("AP", string.format("instruction cards shown like vanilla: %s, %d trigger(s) on again",
        c.marked_for == nil and "none marked" or (emptied and string.format("seen list emptied (%d seen by the player marked again)", kept)
            or "seen list NOT emptied (cards stay hidden until the game restarts)"), back))
    c.marked_for, c.triggers, c.by_mod, c.scan_next = nil, {}, {}, 0
end
function dl.card_trigger_appeared(actor, cls)
    local cc = apcfg.instruction_cards or {}
    if cls ~= (cc.trigger_class or "InstructionCardTrigger_C") then return end
    if cc.triggers_on_beginplay == false or not dl.cards_blocked() then return end
    local key = full_name(actor)
    if not key or key:find("Default__", 1, true) then return end
    call(actor, "SetActorEnableCollision", false)
    if not popup.cards.triggers[key] then
        popup.cards.triggers[key] = true
        log:write("AP", "instruction card trigger off: " .. (key:match("([^%.:]+)$") or key))
    end
end
function dl.cards_tick()
    local cc = apcfg.instruction_cards or {}
    local c = popup.cards
    if not dl.cards_blocked() then
        if c.marked_for ~= nil or next(c.triggers) then try("instruction cards back", dl.cards_unmark) end
        return
    end
    if c.marked_for ~= world.switches and last_state and last_state.ready then
        c.marked_for = world.switches
        try("instruction cards", dl.cards_mark)
    end
    local now_ms = world_now_ms()
    if world.beginplay_hook and cc.triggers_on_beginplay ~= false then
        if not dl.cards_rescan then return end
        dl.cards_rescan = nil
    elseif now_ms >= c.scan_next and not pickup_quiet() then
        c.scan_next = now_ms + (cc.trigger_scan_ms or 10000)
    else
        return
    end
    do
        for _, t in ipairs(FindAllOf(cc.trigger_class or "InstructionCardTrigger_C") or {}) do
            local key = is_valid(t) and full_name(t)
            if key and not key:find("Default__", 1, true) and call(t, "GetActorEnableCollision") ~= false then
                call(t, "SetActorEnableCollision", false)
                if not c.triggers[key] then
                    c.triggers[key] = true
                    log:write("AP", "instruction card trigger off: " .. (key:match("([^%.:]+)$") or key))
                end
            end
        end
    end
end
function dl.awards_tick()
    local a = dl.awards
    local why = dl.player_busy()
    local now_ms = world_now_ms()
    if why then
        a.free_since = nil
        if a.why ~= why then
            if a.why == nil then log:write("AP", "items that can open an instruction card held: " .. why) end
            a.why = why
        end
        return
    end
    if a.why == nil then return end
    a.free_since = a.free_since or now_ms
    local settle = (apcfg.instruction_cards or {}).settle_ms or 3000
    if now_ms - a.free_since >= settle then
        log:write("AP", string.format("items given again: Gregory has had control for %d s (held: %s)", settle // 1000, a.why))
        a.why, a.free_since = nil, nil
    end
end

local ESLATE_VISIBLE, ESLATE_COLLAPSED, ESLATE_HIDDEN = 0, 1, 2
local PROMPT_PARTS = { "KeyBindingIcon", "HoldProgress", "InformationItemImage", "InformationBackground" }
local prompt = { near = nil, shown = false, saved = nil }

local function prompt_hud()
    local hud = dl.nt_hud()
    if not hud then return nil end
    local name = full_name(hud)
    if prompt.hud_name ~= name then
        local n = 0
        for _, h in ipairs(FindAllOf("PlayerHUD_C") or {}) do
            if is_valid(h) and not (full_name(h) or "Default__"):find("Default__", 1, true) then n = n + 1 end
        end
        log:write("AP", string.format("prompt HUD: %s (in viewport %s, %d HUD(s))", name:match("([^%.:]+)$") or name,
            tostring(call(hud, "IsInViewport")), n))
        prompt.hud_name, prompt.saved = name, nil
    end
    return hud
end

local function prompt_set(text)
    local hud = prompt_hud()
    if not hud then return false end
    return pcall(function()
        if not prompt.saved then
            prompt.saved = { InformationPanel = hud.InformationPanel:GetVisibility() }
            local oko, op = pcall(function() return hud.Informational:GetRenderOpacity() end)
            if oko then prompt.saved.opacity = tonumber(U.to_str(op)) end
            local okv, tv = pcall(function() return hud.Informational:GetVisibility() end)
            if okv then prompt.saved.text_vis = tonumber(U.to_str(tv)) end
            local tr = prop(prop(hud.Informational, "RenderTransform"), "Translation")
            local tx, ty = tonumber(U.to_str(prop(tr, "X"))), tonumber(U.to_str(prop(tr, "Y")))
            if tx and ty then
                prompt.saved.translation = { X = tx, Y = ty }
                if (tx ~= 0 or ty ~= 0) and prompt.moved_logged ~= tx .. "," .. ty then
                    prompt.moved_logged = tx .. "," .. ty
                    log:write("AP", string.format("prompt: the HUD had moved the text by (%.0f,%.0f), put back while shown", tx, ty))
                end
            end
            for _, n in ipairs(PROMPT_PARTS) do
                local w = hud[n]
                if w and w:IsValid() then prompt.saved[n] = w:GetVisibility() end
            end
        end
        hud.Informational:SetText(FText(text))
        pcall(function() hud.Informational:SetRenderOpacity(1.0) end)
        pcall(function() hud.Informational:SetVisibility(4) end)
        pcall(function() hud.Informational:SetRenderTranslation({ X = 0.0, Y = 0.0 }) end)
        for _, n in ipairs(PROMPT_PARTS) do
            local w = hud[n]
            if w and w:IsValid() then w:SetVisibility(ESLATE_HIDDEN) end
        end
        hud.InformationPanel:SetRenderOpacity(1.0)
        hud.InformationPanel:SetVisibility(ESLATE_VISIBLE)
    end)
end

local function prompt_clear()
    local saved = prompt.saved or {}
    prompt.saved = nil
    local hud = prompt_hud()
    if not hud then return end
    pcall(function() hud.InformationPanel:SetVisibility(saved.InformationPanel or ESLATE_COLLAPSED) end)
    if saved.opacity ~= nil then pcall(function() hud.Informational:SetRenderOpacity(saved.opacity) end) end
    if saved.text_vis ~= nil then pcall(function() hud.Informational:SetVisibility(saved.text_vis) end) end
    if saved.translation then pcall(function() hud.Informational:SetRenderTranslation(saved.translation) end) end
    for _, n in ipairs(PROMPT_PARTS) do
        if saved[n] ~= nil then pcall(function() hud[n]:SetVisibility(saved[n]) end) end
    end
end

local function item_class(flags)
    flags = tonumber(flags) or 0
    if flags & 1 ~= 0 then return "progression" end
    if flags & 2 ~= 0 then return "useful" end
    if flags & 4 ~= 0 then return "trap" end
    return "filler"
end
local function popup_label(entry)
    local pc = apcfg.popup or {}
    local s = entry and entry.loc and ap and ap.scouts and ap.scouts[entry.loc]
    if not s then return pc.unknown_text or "Archipelago item", nil, "not scouted", nil end
    local class = item_class(s.flags)
    if s.own then
        local it = APT.items[s.item]
        return (it and it.name) or s.name, it and it.icon, "own " .. class .. " item", class
    end
    return string.format(pc.other_format or "%s (%s)", s.name, s.player), nil, class .. " item for " .. s.player, class
end
function popup.veil()
    if (apcfg.popup or {}).veil == false or popup.veiled or popup.veil_entry == popup.pending[1] then return end
    local hud = find_live("PlayerHUD_C")
    local w = hud and prop(hud, "Informational")
    local img = hud and prop(hud, "InformationItemImage")
    if not (is_valid(w) and is_valid(img)) then return end
    local v = { t = popup_now() }
    pcall(function() v.text = w:GetVisibility() end)
    pcall(function() v.img = img:GetVisibility() end)
    pcall(function() w:SetVisibility(ESLATE_HIDDEN) end)
    pcall(function() img:SetVisibility(ESLATE_HIDDEN) end)
    popup.veiled, popup.veil_entry = v, popup.pending[1]
end
function popup.unveil(ours)
    local v = popup.veiled
    if not v then return end
    popup.veiled = nil
    local hud = find_live("PlayerHUD_C")
    local w = hud and prop(hud, "Informational")
    local img = hud and prop(hud, "InformationItemImage")
    if is_valid(w) then
        local tv = tonumber(v.text)
        if tv == nil or tv == ESLATE_HIDDEN or tv == ESLATE_COLLAPSED then tv = 4 end
        pcall(function() w:SetVisibility(tv) end)
    end
    if is_valid(img) and not ours then
        local iv = tonumber(v.img)
        if iv ~= nil and iv ~= ESLATE_HIDDEN then pcall(function() img:SetVisibility(iv) end) end
    end
end
popup.custom, popup.failed = {}, {}
local function custom_icon(ctx, file)
    if popup.failed[file] then return nil end
    local krl = StaticFindObject("/Script/Engine.Default__KismetRenderingLibrary")
    local full = mod_dir .. "/" .. file
    local ok, t = pcall(function() return krl:ImportFileAsTexture2D(ctx, full) end)
    if ok and is_valid(t) then
        popup.custom[file] = full_name(t):match("^%S+ (.+)$") or full_name(t)
        log:write("AP", "popup: custom icon " .. full .. " loaded (" .. popup.custom[file] .. ")")
        return t
    end
    popup.failed[file] = true
    log:write("AP", "popup: custom icon " .. full .. " NOT loaded (" .. tostring(t) .. ")")
    return nil
end
local function popup_texture(ctx, path, class)
    local pc = apcfg.popup or {}
    if path then
        local ok, o = pcall(StaticFindObject, path)
        if not (ok and is_valid(o)) and pc.load_icons and type(LoadAsset) == "function" then ok, o = pcall(LoadAsset, path) end
        if ok and is_valid(o) then return o, "game icon" end
    end
    local cf = class and (pc.icon_files or {})[class]
    if cf then
        local t = custom_icon(ctx, cf)
        if t then return t, class .. " icon" end
    end
    local t = custom_icon(ctx, pc.icon_file or "ap_item.png")
    if t then return t, "custom icon" end
    local fb = pc.fallback_icon or "/Game/Textures/Icons/FazWatch/ItemIcons_2D/TEX_KeyItem_Placeholder.TEX_KeyItem_Placeholder"
    local ok, o = pcall(StaticFindObject, fb)
    if not (ok and is_valid(o)) and pc.load_icons and type(LoadAsset) == "function" then ok, o = pcall(LoadAsset, fb) end
    if ok and is_valid(o) then return o, "placeholder icon" end
    return nil, "no icon"
end
local function pstep(msg) if (apcfg.popup or {}).trace ~= false then log:write("AP", "popup step: " .. msg) end end
local function popup_tick(why)
    local pc = apcfg.popup or {}
    if pc.enabled == false then return end
    while popup.pending[1] and popup_now() - popup.pending[1].t > (pc.window_s or 8) do
        local old = table.remove(popup.pending, 1)
        log:write("AP", "popup: no popup seen for " .. tostring(old.what) .. " within " .. (pc.window_s or 8) .. " s")
    end
    if #popup.pending == 0 then popup.unveil(); return end
    if popup.veiled and popup_now() - popup.veiled.t > (pc.veil_s or 2) then popup.unveil() end
    local trace = pc.trace ~= false
    local hud = find_live("PlayerHUD_C")
    local anim = hud and prop(hud, "InformationAnim")
    local w = hud and prop(hud, "Informational")
    local img = hud and prop(hud, "InformationItemImage")
    if not (is_valid(anim) and is_valid(w) and is_valid(img)) then
        if trace and not popup.missing_logged then
            popup.missing_logged = true
            pstep("HUD or its popup widgets missing")
        end
        return
    end
    local playing = call(hud, "IsAnimationPlaying", anim) == true
    local at = playing and num(call(hud, "GetAnimationCurrentTime", anim)) or nil
    local started
    if not popup.armed then
        popup.armed = true
        started = playing and at ~= nil and at <= ((popup.pending[1] or {}).fresh or pc.fresh_s or 0.4)
        if trace then pstep(string.format("%s: armed, animation %s%s", why,
            playing and ("playing at " .. tostring(at)) or "stopped", started and " (just started: ours)" or "")) end
    else
        started = playing and (not popup.was_playing or (at ~= nil and popup.last_at ~= nil and at + 0.05 < popup.last_at))
    end
    if trace and playing ~= popup.was_playing then
        pstep(string.format("%s: animation %s", why, playing and ("started at " .. tostring(at)) or "stopped"))
    end
    popup.was_playing, popup.last_at = playing, at
    if not playing and not started then popup.veil() end
    if not started then return end
    local entry = table.remove(popup.pending, 1)
    popup.armed = #popup.pending == 0 or popup.armed
    local text, icon, kind, class = popup_label(entry)
    pstep("label " .. text .. " (" .. kind .. "), setting the text")
    local okt = pcall(function() w:SetText(FText(text)) end)
    pstep("text " .. (okt and "set" or "NOT set") .. ", finding the icon " .. tostring(icon or class))
    local tex, where = popup_texture(hud, icon, class)
    pstep("icon: " .. where .. ", setting the image")
    local oki = false
    if tex then
        oki = pcall(function()
            img:SetBrushFromTexture(tex, false)
            img:SetVisibility(ESLATE_VISIBLE)
        end)
        if oki and pc.icon_fade ~= false then
            pcall(function() img:SetRenderOpacity(1) end)
            popup.fade = { t0 = world_now_ms() }
        end
    end
    popup.done_once = true
    popup.unveil(oki)
    log:write("AP", string.format("popup (%s): %s -> %s [%s, %s%s]%s", why, entry and entry.what or "?", text, kind, where,
        oki and "" or " NOT set", okt and "" or " TEXT NOT SET"))
end
function dl.popup_fade_tick()
    local f = popup.fade
    if not f then return end
    local hud = find_live("PlayerHUD_C")
    local anim = hud and prop(hud, "InformationAnim")
    local w = hud and prop(hud, "Informational")
    local img = hud and prop(hud, "InformationItemImage")
    if not (is_valid(w) and is_valid(img)) then popup.fade = nil; return end
    local playing = is_valid(anim) and call(hud, "IsAnimationPlaying", anim) == true
    if playing then
        local op = num(call(w, "GetRenderOpacity")) or num(prop(w, "RenderOpacity")) or 1
        pcall(function() img:SetRenderOpacity(op) end)
        f.seen = true
        return
    end
    if not f.seen and world_now_ms() - f.t0 < 1000 then return end
    pcall(function() img:SetVisibility(ESLATE_HIDDEN) end)
    pcall(function() img:SetRenderOpacity(1) end)
    popup.fade, popup.icon_hidden = nil, true
end
function dl.popup_inventory_now()
    if ap and (apcfg.popup or {}).all_checks ~= false and not world_busy() then snapshot("popup") end
    if #popup.pending > 0 then popup_tick("hook") return end
    if popup.icon_hidden then dl.popup_icon_back() end
end
function dl.popup_icon_back()
    if not popup.icon_hidden then return end
    popup.icon_hidden = false
    local hud = find_live("PlayerHUD_C")
    local img = hud and prop(hud, "InformationItemImage")
    if is_valid(img) then
        pcall(function() img:SetRenderOpacity(1) end)
        pcall(function() img:SetVisibility(ESLATE_VISIBLE) end)
    end
end

dl.nt = { queue = {}, seen = nil, header = nil, retry_at = 0 }
function dl.nt_cfg() return apcfg.received_notify or {} end
popup.notify_item = function(game_name)
    local nc = dl.nt_cfg()
    if nc.enabled == false then return end
    for id, it in pairs(APT.items or {}) do
        for _, n in ipairs(it.names or {}) do
            if n == game_name then
                if #dl.nt.queue < (nc.max_queue or 8) then dl.nt.queue[#dl.nt.queue + 1] = id end
                log:write("AP", "notify: " .. tostring(it.name) .. " added to the inventory, shown like an item received")
                return
            end
        end
    end
end
function dl.notify_poll()
    local nc, nt = dl.nt_cfg(), dl.nt
    if nc.enabled == false or not ap then return end
    local got = ap.received or {}
    local n = #got
    if ap.header ~= nt.header or nt.seen == nil or n < nt.seen then
        nt.header, nt.seen = ap.header, n
        return
    end
    if n == nt.seen then return end
    local dropped = 0
    for i = nt.seen + 1, n do
        if #nt.queue < (nc.max_queue or 8) then nt.queue[#nt.queue + 1] = got[i] else dropped = dropped + 1 end
    end
    log:write("AP", string.format("notify: %d item(s) received, %d waiting%s", n - nt.seen, #nt.queue,
        dropped > 0 and (", " .. dropped .. " not shown (queue full)") or ""))
    nt.seen = n
end
function dl.nt_hud()
    local hud, shown = nil, false
    for _, h in ipairs(FindAllOf("PlayerHUD_C") or {}) do
        if is_valid(h) and not (full_name(h) or "Default__"):find("Default__", 1, true) then
            local inv = call(h, "IsInViewport") == true
            if not hud or (inv and not shown) then hud, shown = h, inv end
        end
    end
    return hud
end
function dl.screen_size(ctx)
    local wll = dl.obj("/Script/UMG.Default__WidgetLayoutLibrary")
    local okv, vs, oks, sc = false, nil, false, nil
    if wll then
        okv, vs = pcall(function() return wll:GetViewportSize(ctx) end)
        oks, sc = pcall(function() return wll:GetViewportScale(ctx) end)
    end
    local vw, vh = okv and num(prop(vs, "X")) or nil, okv and num(prop(vs, "Y")) or nil
    sc = oks and num(sc) or 1
    if not sc or sc <= 0 then sc = 1 end
    if not (vw and vh and vw > 0 and vh > 0) then return 1920, 1080, false end
    return vw / sc, vh / sc, true
end
function dl.asset(path, load)
    local o = dl.obj(path)
    if o or load == false or type(LoadAsset) ~= "function" then return o, o and "loaded" or "not loaded" end
    local ok, l = pcall(LoadAsset, path)
    if ok and is_valid(l) then return l, "loaded now" end
    return nil, "not loaded"
end
function dl.nt_texture(ctx, path)
    local nc = dl.nt_cfg()
    if path then
        local o = dl.asset(path, nc.load_icons == true)
        if o then return o, "game icon" end
    end
    local t = custom_icon(ctx, nc.icon_file or "icons/proguseful.png")
    if t then return t, "custom icon" end
    return nil, "no icon"
end
function dl.nt_style(tb, nc)
    local fpath = nc.font or "/Game/Fonts/Oxanium_Font.Oxanium_Font"
    local fo, how = dl.asset(fpath, nc.load_font)
    local okf = pcall(function()
        local f = tb.Font
        if fo then f.FontObject = fo end
        f.Size = nc.font_size or 26
        f.TypefaceFontName = FName(nc.typeface or "Default")
    end)
    local okc = pcall(function()
        local c = tb.ColorAndOpacity
        local s = c.SpecifiedColor
        s.R, s.G, s.B, s.A = 1, 1, 1, 1
        c.ColorUseRule = 0
    end)
    local oks = pcall(function()
        local o = tb.ShadowOffset
        o.X, o.Y = 2, 2
        local s = tb.ShadowColorAndOpacity
        s.R, s.G, s.B, s.A = 0, 0, 0, nc.shadow or 0.75
    end)
    return string.format("font %s%s, white %s, shadow %s", fo and "Oxanium" or ("default (" .. fpath .. " " .. how .. ")"),
        okf and "" or " NOT set", okc and "ok" or "FAILED", oks and "ok" or "FAILED")
end
function dl.nt_sound()
    local nc = dl.nt_cfg()
    if nc.sound == false then return "no sound (config)" end
    local name = nc.sound_event or "Play_Fazwatch_NewMessage"
    local _, how = dl.asset(nc.sound_event_path or ("/Game/Audio/Assets/Character/Greg/Fazwatch/UI/" .. name .. "." .. name), nc.load_sound)
    local greg = find("Gregory_C")
    if not greg then return "no sound (no Gregory)" end
    local id
    local akc = dl.obj("/Script/AkAudio.AkComponent")
    local comp = akc and call(greg, "GetComponentByClass", akc)
    if is_valid(comp) then id = num(call(comp, "PostAkEventByName", name)) end
    if not id or id == 0 then
        local gs = dl.obj("/Script/AkAudio.Default__AkGameplayStatics")
        local okp, r = false, nil
        if gs then okp, r = pcall(function() return gs:PostEventByName(name, greg, false) end) end
        id = okp and num(r) or nil
    end
    if not id or id == 0 then return string.format("sound %s NOT played (event %s)", name, how) end
    return string.format("sound %s (event %s, id %d)", name, how, id)
end
function dl.nt_show(hud, id, waiting)
    local nc = dl.nt_cfg()
    local it = APT.items[id] or {}
    local name = it.name or ("Item " .. tostring(id))
    local wt = prop(hud, "WidgetTree")
    local root = is_valid(wt) and prop(wt, "RootWidget") or nil
    local hcls, icls, tcls = dl.obj("/Script/UMG.HorizontalBox"), dl.obj("/Script/UMG.Image"), dl.obj("/Script/UMG.TextBlock")
    if not (is_valid(root) and hcls and icls and tcls and type(StaticConstructObject) == "function") then
        log:write("AP", "notify: " .. name .. " not shown (no HUD canvas or widget classes)")
        return nil
    end
    local okb, box = pcall(StaticConstructObject, hcls, wt)
    local oki, img = pcall(StaticConstructObject, icls, wt)
    local okt, tb = pcall(StaticConstructObject, tcls, wt)
    if not (okb and is_valid(box) and oki and is_valid(img) and okt and is_valid(tb)) then
        log:write("AP", "notify: " .. name .. " not shown (widgets not made)")
        return nil
    end
    local size = nc.icon_size or 64
    local tex, where = dl.nt_texture(hud, it.icon)
    if tex then pcall(function() img:SetBrushFromTexture(tex, false) end) end
    local okz = pcall(function() local s = img.Brush.ImageSize; s.X, s.Y = size, size end)
    local style = dl.nt_style(tb, nc)
    local okx = pcall(function() tb:SetText(FText(name)) end)
    local s1 = call(box, "AddChildToHorizontalBox", img)
    local scls = dl.obj("/Script/UMG.Spacer")
    local oksp, sp = false, nil
    if scls then oksp, sp = pcall(StaticConstructObject, scls, wt) end
    if oksp and is_valid(sp) then
        pcall(function() sp:SetSize({ X = nc.gap or 14, Y = 1 }) end)
        call(box, "AddChildToHorizontalBox", sp)
    end
    local s2 = call(box, "AddChildToHorizontalBox", tb)
    for _, s in ipairs({ s1, s2 }) do
        if is_valid(s) then pcall(function() s:SetVerticalAlignment(2) end) end
    end
    local okc, slot = pcall(function() return root:AddChildToCanvas(box) end)
    if not (okc and is_valid(slot)) then
        log:write("AP", "notify: " .. name .. " not shown (not a canvas: " .. tostring(slot) .. ")")
        return nil
    end
    pcall(function() slot:SetAutoSize(true) end)
    pcall(function() slot:SetZOrder(nc.z_order or 900) end)
    local sw, sh, known = dl.screen_size(hud)
    local x, y = nc.margin_x or 40, sh - (nc.margin_y or 40) - size
    pcall(function() box:SetRenderOpacity(0) end)
    pcall(function() slot:SetPosition({ X = x, Y = y + (nc.slide_px or 40) }) end)
    local snd = dl.nt_sound()
    log:write("AP", string.format("notify: %s [%s%s, %s, text %s, screen %dx%d%s, %s]", name, where,
        okz and "" or " (size not set)", style, okx and "set" or "NOT set", math.floor(sw), math.floor(sh),
        known and "" or " (assumed)", snd))
    return { box = obj_path(box), slot = obj_path(slot), x = x, y = y, start = world_now_ms(), name = name,
             hold = (waiting >= (nc.busy_queue or 2) and (nc.hold_busy_s or 1.5) or (nc.hold_s or 3)) * 1000 }
end
function dl.nt_tick()
    local nt, nc = dl.nt, dl.nt_cfg()
    local now = world_now_ms()
    local c = nt.cur
    if not c then
        if #nt.queue == 0 or now < nt.retry_at then return end
        local hud = dl.nt_hud()
        if not hud then nt.retry_at = now + 1000; return end
        c = dl.nt_show(hud, table.remove(nt.queue, 1), #nt.queue)
        if not c then nt.retry_at = now + 1000; return end
        nt.cur = c
    end
    local fin, fout, slide = nc.fade_in_ms or 350, nc.fade_out_ms or 600, nc.slide_px or 40
    local t = now - c.start
    local a, dy
    if t < fin then
        local k = t / fin
        a, dy = k, slide * (1 - k) * (1 - k)
    elseif t < fin + c.hold then
        a, dy = 1, 0
    elseif t < fin + c.hold + fout then
        a, dy = 1 - (t - fin - c.hold) / fout, 0
    end
    local box, slot = dl.obj(c.box), dl.obj(c.slot)
    if not a or not (box and slot) then
        if box then pcall(function() box:RemoveFromParent() end) end
        nt.cur = nil
        return
    end
    pcall(function() box:SetRenderOpacity(a) end)
    pcall(function() slot:SetPosition({ X = c.x, Y = c.y + dy }) end)
end

dl.cr = { hooked = {} }
dl.construct_fns = {}
function dl.on_construct(cpath, fn)
    local list = dl.construct_fns[cpath]
    if list then list[#list + 1] = fn; return true end
    list = { fn }
    local okh = pcall(RegisterHook, cpath .. ":Construct", function(ctx)
        for _, f in ipairs(list) do f(ctx) end
    end)
    if okh then dl.construct_fns[cpath] = list end
    return okh
end
function dl.credits_there(host, text)
    local okn, n = pcall(function() return host:GetChildrenCount() end)
    n = okn and num(n) or 0
    for i = 0, n - 1 do
        local okc, c = pcall(function() return host:GetChildAt(i) end)
        if okc and is_valid(c) and obj_class(c) == "TextBlock" then
            local okt, t = pcall(function() return c:GetText():ToString() end)
            if okt and t == text then return true end
        end
    end
    return false
end
function dl.credits_add(w, menu, cc)
    local wt = prop(w, "WidgetTree")
    local host = menu.inside and prop(w, menu.inside) or (is_valid(wt) and prop(wt, "RootWidget") or nil)
    local tcls = dl.obj("/Script/UMG.TextBlock")
    if not (is_valid(host) and tcls and type(StaticConstructObject) == "function") then
        return nil, "no " .. (menu.inside or "root canvas") .. " or TextBlock class"
    end
    if dl.credits_there(host, cc.text or "Mod credits : Coulu") then return false end
    local okt, tb = pcall(StaticConstructObject, tcls, wt)
    if not (okt and is_valid(tb)) then return nil, "TextBlock not made" end
    local style = dl.nt_style(tb, { font = cc.font, typeface = cc.typeface, font_size = cc.font_size or 22, shadow = cc.shadow })
    local okx = pcall(function() tb:SetText(FText(cc.text or "Mod credits : Coulu")) end)
    pcall(function() tb:SetVisibility(3) end)
    local mx, my = cc.margin_x or 40, cc.margin_y or 40
    local where
    if menu.inside then
        local okc, slot = pcall(function() return host:AddChildToOverlay(tb) end)
        if not (okc and is_valid(slot)) then return nil, menu.inside .. " is not an overlay: " .. tostring(slot) end
        pcall(function() slot:SetHorizontalAlignment(3) end)
        pcall(function() slot:SetVerticalAlignment(3) end)
        local okp = pcall(function() slot:SetPadding({ Left = 0, Top = 0, Right = mx, Bottom = my }) end)
        where = string.format("bottom right of %s, %d,%d from the corner%s", menu.inside, mx, my, okp and "" or " (padding NOT set)")
    else
        local okc, slot = pcall(function() return host:AddChildToCanvas(tb) end)
        if not (okc and is_valid(slot)) then return nil, "not a canvas: " .. tostring(slot) end
        local sw, sh, known = dl.screen_size(w)
        local x, y = sw - mx, sh - my
        pcall(function() slot:SetAlignment({ X = 1, Y = 1 }) end)
        pcall(function() slot:SetAutoSize(true) end)
        pcall(function() slot:SetZOrder(cc.z_order or 950) end)
        local okp = pcall(function() slot:SetPosition({ X = x, Y = y }) end)
        where = string.format("at %d,%d%s of %dx%d%s", math.floor(x), math.floor(y), okp and "" or " (NOT placed)",
            math.floor(sw), math.floor(sh), known and "" or " (assumed)")
    end
    return string.format("%s, text %s, %s", style, okx and "set" or "NOT set", where)
end
function dl.credits_built(cls, menu, ctx)
    local cc = apcfg.credits or {}
    if cc.enabled == false then return end
    local w = U.unwrap(ctx)
    local path = is_valid(w) and obj_path(w) or nil
    if not path or path:find("Default__", 1, true) then return end
    local done, why = dl.credits_add(w, menu, cc)
    if done == false then return end
    log:write("AP", done and ("credits: added to " .. cls .. " (" .. done .. ")")
        or string.format("credits: not added to %s (%s)", cls, tostring(why)))
end
function dl.credits_hooks()
    local cc = apcfg.credits or {}
    local all = true
    for cls, menu in pairs(cc.menus or {}) do
        if not dl.cr.hooked[cls] and dl.obj(menu.class) then
            local okh = dl.on_construct(menu.class, function(ctx) try("credits", dl.credits_built, cls, menu, ctx) end)
            dl.cr.hooked[cls] = okh and "set" or "failed"
            log:write("AP", "credits: " .. cls .. " Construct hook " .. (okh and "set" or "NOT set"))
        end
        if not dl.cr.hooked[cls] then all = false end
    end
    dl.cr.done = all
    return all
end

local function looking_at(x, y, z, range)
    local cam = find_live("PlayerCameraManager")
    if not cam then return false end
    local loc, rot = call(cam, "GetCameraLocation"), call(cam, "GetCameraRotation")
    local cx, cy, cz = tonumber(prop(loc, "X")), tonumber(prop(loc, "Y")), tonumber(prop(loc, "Z"))
    local pitch, yaw = tonumber(prop(rot, "Pitch")), tonumber(prop(rot, "Yaw"))
    if not (cx and cy and cz and pitch and yaw) then return false end
    local dx, dy, dz = x - cx, y - cy, z - cz
    local d = math.sqrt(dx * dx + dy * dy + dz * dz)
    if d > range then return false end
    if d < 1 then return true end
    local p, w = math.rad(pitch), math.rad(yaw)
    local dot = math.cos(p) * math.cos(w) * dx + math.cos(p) * math.sin(w) * dy + math.sin(p) * dz
    return dot / d >= (apcfg.look_cos or 0.93)
end

local function gregory_within(x, y, z, range)
    local greg = find("Gregory_C")
    if not greg then return false end
    local gx, gy, gz = location_of(greg)
    return (gx - x) ^ 2 + (gy - y) ^ 2 + (gz - z) ^ 2 <= range * range
end

function dl.prompt_check(when)
    if (prompt.check_lines or 0) >= ((apcfg.prompt_debug_lines) or 20) then return end
    local hud = prompt_hud()
    if not hud then return end
    local function st(w)
        if not (w and is_valid(w)) then return "-" end
        local v = U.to_str(call(w, "GetVisibility"))
        local o = tonumber(U.to_str(call(w, "GetRenderOpacity")))
        local tr = prop(prop(w, "RenderTransform"), "Translation")
        local sc = prop(prop(w, "RenderTransform"), "Scale")
        return string.format("vis %s op %s tr %s,%s sc %s,%s", v, o and string.format("%.2f", o) or "?",
            U.to_str(prop(tr, "X")), U.to_str(prop(tr, "Y")), U.to_str(prop(sc, "X")), U.to_str(prop(sc, "Y")))
    end
    local sig = string.format("hud[%s] panel[%s] text[%s] root[%s]", st(hud), st(prop(hud, "InformationPanel")),
        st(prop(hud, "Informational")), st(prop(hud, "CanvasPanel_0")))
    if sig ~= prompt.check_sig then
        prompt.check_sig = sig
        prompt.check_lines = (prompt.check_lines or 0) + 1
        log:write("AP", "prompt widgets (" .. when .. "): " .. sig)
    end
end
function dl.prompt_hide_hook()
    dl.hide_calls = (dl.hide_calls or 0) + 1
    if dl.hide_calls <= 3 or dl.hide_calls % 100 == 0 then
        log:write("AP", string.format("HUD Hide Informational Message called (%d times)%s", dl.hide_calls,
            prompt.shown and ", message shown again" or ""))
    end
    if prompt.shown and prompt.last_text then
        local text = prompt.last_text
        on_game_thread("prompt again", function() if prompt.shown then prompt_set(text) end end)
    end
end

local function prompt_tick()
    local n = nil
    for _, c in ipairs(prompt.near and (prompt.near.list or { prompt.near }) or {}) do
        if (c.sphere and gregory_within(c.x, c.y, c.z, c.range)) or
            (not c.sphere and looking_at(c.x, c.y, c.z, c.range)) then n = c; break end
    end
    local want = n ~= nil
    if want then
        if prompt.shown then try("prompt check", dl.prompt_check, "before") end
        prompt.last_text = n.text
        local ok = prompt_set(n.text)
        if ok then try("prompt check", dl.prompt_check, "set") end
        if ok and not prompt.shown then log:write("AP", "prompt shown: " .. n.text) end
        if not ok and not prompt.failed then
            prompt.failed = true
            log:write("AP", "prompt FAILED (no PlayerHUD_C on screen or its widgets changed): " .. n.text)
        end
        prompt.shown = ok
    elseif prompt.shown then
        prompt_clear()
        prompt.shown = false
    end
end

local locked_pickups = {}
local function lock_near_at(x, y, z, h)
    if not h.message or apcfg.show_messages == false then return nil end
    local greg = find("Gregory_C")
    if not greg then return nil end
    local gx, gy, gz = location_of(greg)
    local r = h.radius or 600
    if (gx - x) ^ 2 + (gy - y) ^ 2 + (gz - z) ^ 2 > r * r then return nil end
    return { x = x, y = y, z = z + (h.z_offset or 0), range = h.look or 350, text = h.message }
end
local function lock_near(a, h)
    if not h.message or apcfg.show_messages == false then return nil end
    local x, y, z = location_of(a)
    return lock_near_at(x, y, z, h)
end

dl.scans = { cache = {}, budget = 0, switches = nil }
function dl.find_all(cls)
    local every = apcfg.scan_refresh_ms or 10000
    if every <= 0 then return FindAllOf(cls) or {} end
    local s, now = dl.scans, world_now_ms()
    if s.switches ~= world.switches then s.switches, s.cache = world.switches, {} end
    local c = s.cache[cls]
    if not c or (now >= c.next and s.budget > 0) then
        if c then s.budget = s.budget - 1 end
        local list, paths = {}, {}
        for _, a in ipairs(FindAllOf(cls) or {}) do
            local p = is_valid(a) and obj_path(a)
            if p then list[#list + 1] = a; paths[#paths + 1] = p end
        end
        s.cache[cls] = { paths = paths, next = now + every }
        return list
    end
    local list = {}
    for _, p in ipairs(c.paths) do
        local a = obj_at(p)
        if a then list[#list + 1] = a end
    end
    return list
end
function dl.lock_scan(cls, allow, locked)
    if allow then
        local pre = cls .. " "
        for key in pairs(locked) do
            if key:sub(1, #pre) == pre then return dl.find_all(cls) end
        end
        return {}
    end
    return dl.find_all(cls)
end
dl.poll_steps = {}
function dl.timed(name, fn, ...)
    local t0 = os.clock()
    local ok, err = try(name, fn, ...)
    dl.poll_steps[#dl.poll_steps + 1] = { name, (os.clock() - t0) * 1000 }
    return ok, err
end
function dl.poll_report()
    local limit = cfg.slow_poll_ms or 40
    local steps, total = dl.poll_steps, 0
    dl.poll_steps = {}
    if limit <= 0 then return end
    for _, s in ipairs(steps) do total = total + s[2] end
    if total < limit or os.clock() < (dl.slow_next or 0) then return end
    dl.slow_next = os.clock() + 30
    table.sort(steps, function(a, b) return a[2] > b[2] end)
    local parts = {}
    for i = 1, math.min(#steps, 6) do parts[#parts + 1] = string.format("%s %.0f", steps[i][1], steps[i][2]) end
    log:write("Perf", string.format("slow poll: %.0f ms (%s ms)", total, table.concat(parts, ", ")))
end

dl.lp = { due = nil, world = nil, sig = nil, spots = {} }
function dl.lock_pickup_appeared(cls)
    if (apcfg.lock_pickups or {})[cls] then dl.lp.due = world_now_ms() + (apcfg.lock_settle_ms or 1500) end
end
function dl.lock_pickups_scan(missions)
    local spots, again = {}, false
    for cls, h in pairs(apcfg.lock_pickups or {}) do
        local allow = missions[h.until_mission] == true
        for _, a in ipairs(dl.lock_scan(cls, allow, locked_pickups)) do
            if is_valid(a) then
                local key = full_name(a)
                local short_key = key:match("([^%.:]+)$") or key
                if not allow then
                    if prop(a, "CanCollect") == true then
                        pcall(function() a.CanCollect = false end)
                        if not locked_pickups[key] then
                            log:write("AP", string.format("%s closed until mission %s is done (%s)",
                                short_key, h.until_mission, h.why or ""))
                        end
                        locked_pickups[key] = true
                    end
                    if locked_pickups[key] then
                        local x, y, z = location_of(a)
                        if x == 0 and y == 0 and z == 0 then again = true
                        else spots[key] = { x = x, y = y, z = z, h = h } end
                    end
                elseif locked_pickups[key] then
                    pcall(function() a.CanCollect = true end)
                    locked_pickups[key] = nil
                    log:write("AP", string.format("%s open again: mission %s done", short_key, h.until_mission))
                end
            end
        end
    end
    return spots, again
end
local function lock_pickups_tick(missions)
    if missions == nil then prompt.near = nil; return end
    local P, now = dl.lp, world_now_ms()
    if P.world ~= world.switches then P.world, P.spots, P.due = world.switches, {}, now end
    local sig = table.concat(U.sorted_keys(missions), "|")
    if sig ~= P.sig then P.sig, P.due = sig, now end
    if P.due and now >= P.due then
        local again
        P.spots, again = dl.lock_pickups_scan(missions)
        P.due = again and (now + 2000) or nil
    end
    local near = nil
    for _, s in pairs(P.spots) do near = lock_near_at(s.x, s.y, s.z, s.h) or near end
    prompt.near = near
end

local held_triggers = {}
dl.om = { seen_undone = false, remove_at = nil, removed = 0, said = {}, near = {}, next_near = 0,
          swapped = false, award_hooked = nil, world = nil, why = nil, due = {}, unrestricted = {}, pos = {} }
local function om_say(key, text)
    if not dl.om.said[key] then dl.om.said[key] = true; log:write("AP", text) end
end
local function om_watched(c, path)
    for _, list in ipairs({ c.doors or {}, c.freddy_doors or {} }) do
        for _, p in ipairs(list) do if p == path then return true end end
    end
    return false
end
local function om_set_due(key, at)
    local d = dl.om.due
    if not d[key] or at > d[key] then d[key] = at end
end
function dl.om_keep_pos(actor, path)
    local x, y, z = location_of(actor)
    if not (x == 0 and y == 0 and z == 0) then dl.om.pos[path] = { x = x, y = y, z = z } end
end
function dl.office_appeared(actor, cls)
    local c = apcfg.office_monty or {}
    if c.enabled == false then return end
    local w, now = c.watch or {}, world_now_ms()
    for key, classes in pairs(w) do
        for _, k in ipairs(classes) do
            if k == cls then
                local path = obj_path(actor)
                if key == "doors" then
                    if path and om_watched(c, path) then
                        dl.om_keep_pos(actor, path)
                        dl.om.unrestricted[path] = nil
                        om_set_due("door " .. path, now + (c.settle_ms or 10000))
                    end
                else
                    if path and (path == c.handler or path == c.office) then dl.om_keep_pos(actor, path) end
                    om_set_due(key, now + (c.appear_ms or 1000))
                end
            end
        end
    end
end
function dl.office_award(name)
    if not ap then return end
    local original, swapped = ap:original_name(name)
    if not swapped then return end
    local id = ap.T.locations.collect[original]
    if not id then return end
    if not ap.checks[id] then log:write("AP", "lobby office camera button: minigame done, AP location for " .. original) end
    ap_event("collect", name)
    popup.expect(id, original)
end
local function om_award_hook(c)
    if dl.om.award_hooked ~= nil or not c.award_hook then return end
    local okh, err = pcall(RegisterHook, c.award_hook, function(ctx)
        try("office award", function()
            local award = U.to_str(prop(U.unwrap(ctx), "ItemAward"))
            if award and award:sub(1, #ap:prefix()) == ap:prefix() then dl.office_award(award) end
        end)
    end)
    dl.om.award_hooked = okh
    log:write("AP", okh and ("lobby office: hooked " .. c.award_hook) or ("lobby office: award hook not set: " .. tostring(err)))
end
local function om_swap(c)
    dl.om.swapped = false
    if not (ap and apcfg.block_vanilla and c.swap_award ~= false and c.office) then return end
    local ogm = obj_at(c.office)
    if not ogm then return end
    local cur = U.to_str(prop(ogm, "ItemAward"))
    local orig, already = ap:original_name(cur or "")
    if not already and orig ~= "" and orig ~= "None" and ap.T.locations.collect[orig] then
        pcall(function() ogm.ItemAward = fname_add(ap:prefix() .. orig) end)
        cur = U.to_str(prop(ogm, "ItemAward"))
        log:write("Swap", string.format("lobby office minigame: ItemAward %s -> %s", orig, tostring(cur)))
    end
    dl.om.swapped = cur ~= nil and cur:sub(1, #ap:prefix()) == ap:prefix()
    if dl.om.swapped then om_award_hook(c) end
end
local function om_monty(c, h, why)
    if dl.om.remove_at and world_now_ms() < dl.om.remove_at then return end
    local monty = prop(h, "SpawnedMonty")
    if not is_valid(monty) then return end
    dl.om.removed = dl.om.removed + 1
    if dl.om.removed <= 5 then log:write("AP", "office Monty taken away from the lobby office door (" .. why .. ")") end
    local ok, err = pcall(function() h:Remove() end)
    if not ok then om_say("monty remove", "office Monty: Remove failed, left to the game (" .. tostring(err) .. ")") end
end
local function om_door(path, why)
    local door = obj_at(path)
    local comp = door and prop(door, "Door")
    local locked = is_valid(comp) and prop(comp, "bIsLockedForPlayer")
    om_say("doorstate " .. path, string.format("office scene door %s: %s, door component %s, locked for the player %s", path,
        door and "found" or "NOT found", is_valid(comp) and "ok" or "missing", tostring(locked)))
    local req = is_valid(comp) and prop(comp, "NormalDoorEntryRequirements")
    local level = req and tonumber(prop(req, "RequiredSecurityLevel"))
    if level and level > 0 and (apcfg.office_monty or {}).open_badge_doors ~= false then
        pcall(function() comp:SetSecurityLevel(0) end)
        if tonumber(prop(req, "RequiredSecurityLevel")) ~= 0 then pcall(function() req.RequiredSecurityLevel = 0 end) end
        local after = tonumber(prop(req, "RequiredSecurityLevel"))
        log:write("AP", string.format("office scene door %s: Security Badge level %d -> %s, it opens with any badge (%s)%s",
            U.short_object_name(path), level, tostring(after), why, after == 0 and "" or " FAILED"))
    end
    if locked ~= true then return end
    om_say("door " .. path, string.format("office scene door %s unlocked: the scene is done (%s), the player can go back",
        U.short_object_name(path), why))
    pcall(function() door:SetDoorLockPlayer(false) end)
    if prop(comp, "bIsLockedForPlayer") == true then pcall(function() comp:SetLockedForPlayer(false) end) end
end
local function door_pawns(comp)
    local req = prop(comp, "NormalDoorEntryRequirements")
    local arr = req and prop(req, "RestrictedPawns")
    return arr, U.list_from_array(arr)
end
local PAWN_NONE = 0
local function om_unrestrict(path, why)
    if dl.om.unrestricted[path] then return end
    local door = obj_at(path)
    local comp = door and prop(door, "Door")
    if not is_valid(comp) then return end
    dl.om.unrestricted[path] = true
    local arr, list = door_pawns(comp)
    if not arr or #list == 0 then return end
    local open = true
    for _, v in ipairs(list) do if tonumber(v) ~= PAWN_NONE then open = false end end
    if open then
        om_say("pawns open " .. path, string.format("door %s: pawn list { %s }, nothing to change", U.short_object_name(path),
            table.concat(list, ", ")))
        return
    end
    local ok = pcall(function() arr:ForEach(function(_, e) e:set(PAWN_NONE) end) end)
    local _, after = door_pawns(comp)
    local good = ok and #after > 0
    for _, v in ipairs(after) do if tonumber(v) ~= PAWN_NONE then good = false end end
    log:write("AP", string.format("door %s: pawn list { %s } -> { %s } (%s), Gregory can open it on foot (%s)%s",
        U.short_object_name(path), table.concat(list, ", "), table.concat(after, ", "), "the office scene is done", why,
        good and "" or " FAILED"))
end
function dl.locked_doors_tick()
    if world_now_ms() < dl.om.next_near then return end
    dl.om.next_near = world_now_ms() + 2000
    local greg = find("Gregory_C")
    if not greg then return end
    local gx, gy, gz = location_of(greg)
    local range = (apcfg.office_monty or {}).locked_doors_range or 800
    for _, d in ipairs(dl.find_all("BP_DoorMaster_C")) do
        local path = is_valid(d) and obj_path(d)
        local comp = path and not dl.om.near[path] and prop(d, "Door")
        if is_valid(comp) then
            local x, y, z = location_of(d)
            local dist = math.sqrt((x - gx) ^ 2 + (y - gy) ^ 2 + (z - gz) ^ 2)
            if dist <= range then
                dl.om.near[path] = true
                local _, pawns = door_pawns(comp)
                log:write("AP", string.format("door near the player: %s at %d units (%d,%d,%d), locked for the player %s, for AI %s, pawn list { %s }",
                    path, math.floor(dist), math.floor(x), math.floor(y), math.floor(z),
                    tostring(prop(comp, "bIsLockedForPlayer")), tostring(prop(comp, "bIsLockedForAI")), table.concat(pawns, ", ")))
            end
        end
    end
end
function dl.office_monty_tick(missions, tasks)
    local c = apcfg.office_monty or {}
    if c.enabled == false or not c.handler then return end
    local om, now = dl.om, world_now_ms()
    if om.world ~= world.switches then
        om.world, om.why, om.unrestricted, om.remove_at, om.seen_undone, om.swapped =
            world.switches, nil, {}, nil, false, false
        local t = now + (c.settle_ms or 10000)
        om.due = { monty = t, swap = t }
        for _, list in ipairs({ c.doors or {}, c.freddy_doors or {} }) do
            for _, p in ipairs(list) do om.due["door " .. p] = t end
        end
    end
    local gx, gy, gz = nil, nil, nil
    local function near(path)
        local p = om.pos[path]
        if not p then return false end
        if gx == nil then
            local greg = find("Gregory_C")
            gx, gy, gz = 0, 0, 0
            if greg then gx, gy, gz = location_of(greg) end
        end
        if gx == 0 and gy == 0 and gz == 0 then return false end
        local r = c.near_radius or 2500
        return (gx - p.x) ^ 2 + (gy - p.y) ^ 2 + (gz - p.z) ^ 2 <= r * r
    end
    local function due(key, path)
        local t = om.due[key]
        if t and now >= t and near(path) then om.due[key] = nil; return true end
        return false
    end
    local function doors_due(at)
        for _, list in ipairs({ c.doors or {}, c.freddy_doors or {} }) do
            for _, p in ipairs(list) do om_set_due("door " .. p, at) end
        end
    end
    local function flag(n)
        local ws = find("WorldStateSystem")
        return ws ~= nil and call(ws, "IsActivated", fname_add(n)) == true
    end
    local why = om.why
    if not why then
        for _, m in ipairs(c.done_missions or {}) do if (missions or {})[m] then why = why or ("mission " .. m) end end
        for _, t in ipairs(c.done_tasks or {}) do if (tasks or {})[t] then why = why or ("task " .. t) end end
        for _, f in ipairs(c.done_flags or {}) do if not why and flag(f) then why = f end end
    end
    if why then
        if not om.why then
            om.why = why
            if om.seen_undone then
                doors_due(now)
                om.remove_at = now + (c.grace_ms or 15000)
                om_set_due("monty", om.remove_at)
            end
        end
        for _, path in ipairs(c.doors or {}) do
            if due("door " .. path, path) and c.unlock_doors ~= false then om_door(path, why) end
        end
        for _, path in ipairs(c.freddy_doors or {}) do
            if due("door " .. path, path) and c.unrestrict_doors ~= false then om_unrestrict(path, why) end
        end
        if due("monty", c.handler) then
            local h = obj_at(c.handler)
            if h then om_monty(c, h, why) end
        end
        return
    end
    om.seen_undone, om.remove_at = true, nil
    if due("swap", c.office) then om_swap(c) end
    if not due("monty", c.handler) or om.swapped then return end
    if c.entered_flag and flag(c.entered_flag) then return end
    local early = nil
    for _, it in ipairs(c.early_items or {}) do if not early and game.has(it) then early = it end end
    local h = early and obj_at(c.handler)
    if h then om_monty(c, h, early .. " owned before entering the office") end
end

local function hold_triggers_tick(missions)
    if missions == nil then return end
    for cls, h in pairs(apcfg.hold_triggers or {}) do
        local allow = missions[h.until_mission] == true
        for _, a in ipairs(FindAllOf(cls) or {}) do
            if is_valid(a) then
                local key = full_name(a)
                local on = call(a, "GetActorEnableCollision")
                if not allow and on ~= false then
                    call(a, "SetActorEnableCollision", false)
                    held_triggers[key] = true
                    log:write("AP", string.format("%s held: collision off until mission %s is done (%s)",
                        key:match("([^%.:]+)$") or key, h.until_mission, h.why or ""))
                elseif allow and held_triggers[key] then
                    call(a, "SetActorEnableCollision", true)
                    held_triggers[key] = nil
                    log:write("AP", string.format("%s released: mission %s done", key:match("([^%.:]+)$") or key, h.until_mission))
                end
            end
        end
    end
end

dl.locked_actors, dl.seen_actors = {}, {}
dl.lock = { due = {}, world = nil, spots = {}, done = {}, allowed = {} }
local function obj_addr(o)
    local ok, v = pcall(function() return o:GetAddress() end)
    return ok and v or nil
end
function dl.lock_actor_appeared(cls)
    if (apcfg.lock_actors or {})[cls] then dl.lock.due[cls] = world_now_ms() + (apcfg.lock_settle_ms or 1500) end
end
local function lock_actors_scan(cls, h, allow)
    local L, again = dl.lock, false
    for _, a in ipairs(FindAllOf(cls) or {}) do
        local addr = obj_addr(a)
        if not (addr and L.done[addr]) and is_valid(a) then
            local key = full_name(a)
            local short_key = key:match("([^%.:]+)$") or key
            if not allow then
                local x, y, z = location_of(a)
                if not (x == 0 and y == 0 and z == 0) then
                    if not dl.seen_actors[key] then
                        dl.seen_actors[key] = true
                        log:write("AP", string.format("lock_actors: %s (%s) at (%.0f,%.0f,%.0f)", short_key, cls,
                            tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0))
                    end
                    L.spots[cls] = L.spots[cls] or {}
                    L.spots[cls][key] = { x = x, y = y, z = z }
                end
                if call(a, "GetActorEnableCollision") ~= false then
                    call(a, "SetActorEnableCollision", false)
                    if not dl.locked_actors[key] then
                        log:write("AP", string.format("%s closed (collision off) until mission %s is done",
                            short_key, h.until_mission))
                    end
                end
                dl.locked_actors[key] = true
                if x == 0 and y == 0 and z == 0 then again = true
                elseif addr then L.done[addr] = true end
            elseif dl.locked_actors[key] then
                call(a, "SetActorEnableCollision", true)
                dl.locked_actors[key] = nil
                log:write("AP", string.format("%s open again: mission %s done", short_key, h.until_mission))
            end
        end
    end
    return again
end
function dl.lock_actors_tick(missions)
    if missions == nil then return nil end
    local L, now = dl.lock, world_now_ms()
    if L.world ~= world.switches then
        L.world, L.spots, L.done, L.allowed = world.switches, {}, {}, {}
        dl.locked_actors = {}
        for cls in pairs(apcfg.lock_actors or {}) do L.due[cls] = now end
    end
    local near = nil
    for cls, h in pairs(apcfg.lock_actors or {}) do
        local allow = missions[h.until_mission] == true
        if allow and not L.allowed[cls] then
            L.allowed[cls], L.due[cls], L.done = true, now, {}
            L.spots[cls] = nil
        end
        local every = apcfg.lock_rescan_ms or 0
        if L.due[cls] and now >= L.due[cls] then
            L.due[cls] = every > 0 and (now + every) or nil
            local closed = false
            if allow then
                local pre = cls .. " "
                for key in pairs(dl.locked_actors) do if key:sub(1, #pre) == pre then closed = true end end
            end
            if (not allow or closed) and lock_actors_scan(cls, h, allow) then
                L.due[cls] = now + 2000
            end
        end
        if not allow then
            for _, sp in pairs(L.spots[cls] or {}) do
                local c = lock_near_at(sp.x, sp.y, sp.z, h)
                if c then near = near or { list = {} }; near.list[#near.list + 1] = c end
            end
        end
    end
    return near
end

local arcade_seen, arcade_locked, arcade_sphere = {}, {}, {}
local function machine_sphere(a, key)
    local c = arcade_sphere[key]
    if c ~= nil then return c or nil end
    local sp = prop(a, "Sphere")
    local r = tonumber(U.to_str(call(sp, "GetScaledSphereRadius")))
    local loc = call(sp, "K2_GetComponentLocation")
    local x, y, z = tonumber(prop(loc, "X")), tonumber(prop(loc, "Y")), tonumber(prop(loc, "Z"))
    local ax, ay, az = location_of(a)
    if (x == 0 and y == 0 and z == 0) or (ax == 0 and ay == 0 and az == 0) then
        return nil
    end
    if x and y and z and r and r > 0 and (x - ax) ^ 2 + (y - ay) ^ 2 + (z - az) ^ 2 <= 500 * 500 then
        c = { x = x, y = y, z = z, r = r }
        log:write("AP", string.format("%s interaction sphere: radius %.0f at (%.0f,%.0f,%.0f)",
            key:match("([^%.:]+)$") or key, r, x, y, z))
    else
        c = false
        log:write("AP", (key:match("([^%.:]+)$") or key) .. ": no interaction sphere read, message shown by camera angle")
    end
    arcade_sphere[key] = c
    return c or nil
end
dl.arcade = { due = nil, world = nil, sig = nil, spots = {} }
function dl.arcade_appeared(cls)
    local locks = apcfg.arcade_locks
    if locks and cls == (locks.class or "BP_MiniGame_Activator_C") then
        dl.arcade.due = world_now_ms() + (apcfg.lock_settle_ms or 1500)
    end
end
local function arcade_sig(locks, has_client)
    local parts, types = { tostring(has_client) }, {}
    for typ in pairs(locks.types or {}) do types[#types + 1] = typ end
    table.sort(types)
    for _, typ in ipairs(types) do
        parts[#parts + 1] = tostring(has_client and ap:has_received(locks.types[typ].item) or false)
    end
    for _, n in ipairs(U.sorted_keys((last_state and last_state.arcade) or {})) do parts[#parts + 1] = n end
    return table.concat(parts, "|")
end
local function arcade_scan(locks, has_client)
    local spots, again = {}, false
    for _, a in ipairs(dl.find_all(locks.class or "BP_MiniGame_Activator_C")) do
        if is_valid(a) then
            local key = full_name(a)
            local short_key = key:match("([^%.:]+)$") or key
            local typ = tonumber(U.to_str(prop(a, "Type")))
            if arcade_seen[key] ~= typ then
                arcade_seen[key] = typ
                log:write("AP", string.format("minigame machine %s Type=%s CanUse=%s class=%s", short_key,
                    tostring(typ), U.to_str(prop(a, "CanUse")), U.to_str(call(call(a, "GetClass"), "GetFullName"))))
            end
            local h = typ and (locks.types or {})[typ]
            if h then
                local reason = nil
                if has_client and not ap:has_received(h.item) then
                    reason = "item"
                elseif has_client and h.before_message and prop(a, "CanUse") == false then
                    reason = "before"
                end
                if reason then
                    if arcade_locked[key] ~= reason then
                        log:write("AP", string.format("%s closed (collision off): %s", short_key,
                            reason == "item" and (h.item .. " not received") or "previous act not beaten (CanUse=false)"))
                        arcade_locked[key] = reason
                    end
                    if call(a, "GetActorEnableCollision") ~= false then call(a, "SetActorEnableCollision", false) end
                    local sp = machine_sphere(a, key)
                    local x, y, z = location_of(a)
                    if arcade_sphere[key] == nil or (x == 0 and y == 0 and z == 0) then again = true end
                    spots[key] = { sphere = sp, x = x, y = y, z = z,
                        text = reason == "item" and (h.message or (h.item .. " required")) or h.before_message }
                elseif arcade_locked[key] then
                    call(a, "SetActorEnableCollision", true)
                    arcade_locked[key] = nil
                    log:write("AP", string.format("%s open again (%s received, CanUse=%s)", short_key, h.item,
                        U.to_str(prop(a, "CanUse"))))
                end
            end
        end
    end
    return spots, again
end
local function arcade_locks_tick(has_client)
    local locks = apcfg.arcade_locks
    if not locks then return nil end
    local A, now = dl.arcade, world_now_ms()
    if A.world ~= world.switches then A.world, A.spots, A.due = world.switches, {}, now end
    local sig = arcade_sig(locks, has_client)
    if sig ~= A.sig then A.sig, A.due = sig, now end
    if A.due and now >= A.due then
        local again
        A.spots, again = arcade_scan(locks, has_client)
        A.due = again and (now + (locks.retry_ms or 2000)) or nil
    end
    local near = nil
    for _, s in pairs(A.spots) do
        local sp = s.sphere
        if sp then
            local greg = find("Gregory_C")
            if greg then
                local gx, gy, gz = location_of(greg)
                local r = sp.r + (locks.sphere_margin or 0)
                if (gx - sp.x) ^ 2 + (gy - sp.y) ^ 2 + (gz - sp.z) ^ 2 <= (r + 400) ^ 2 then
                    near = { x = sp.x, y = sp.y, z = sp.z, range = r, text = s.text, sphere = true }
                end
            end
        else
            near = lock_near_at(s.x, s.y, s.z, { message = s.text, radius = locks.radius, look = locks.look,
                z_offset = locks.z_offset }) or near
        end
    end
    return near
end

dl.boss = { refs = {}, next = 0 }
function dl.boss_appeared(actor, cls)
    if not ap then return end
    for name, classes in pairs(apcfg.boss_areas or {}) do
        local match = false
        for _, c in ipairs(classes) do if c == cls then match = true end end
        if not match and cls:find("Collectible", 1, true) and U.to_str(prop(actor, "ItemName")) == name then
            match = true
        end
        if match then
            local refs = dl.boss.refs[name] or {}
            dl.boss.refs[name] = refs
            refs[#refs + 1] = actor
            ap:boss_enter(name, U.short_object_name(full_name(actor)))
            if ap:boss_hold(name) then
                local inv = find("FNAFInventorySystem")
                if inv and call(inv, "HasItem", fname_add(name)) == true then
                    log:write("AP", string.format("RemoveItem %s before %s starts (its boss area)", name,
                        U.short_object_name(full_name(actor))))
                    call(inv, "RemoveItem", fname_add(name))
                end
            end
        end
    end
end
function dl.boss_tick()
    if not ap then return end
    local now = world_now_ms()
    if now < dl.boss.next then return end
    dl.boss.next = now + (apcfg.boss_area_check_ms or 2000)
    for name, refs in pairs(dl.boss.refs) do
        local live = {}
        for _, a in ipairs(refs) do if is_valid(a) then live[#live + 1] = a end end
        dl.boss.refs[name] = live
        if #live == 0 then
            dl.boss.refs[name] = nil
            ap:boss_leave(name)
        end
    end
end

local scan_tick = 0
local function ap_tick()
    if not ap then return end
    scan_tick = scan_tick + 1
    dl.scans.budget = 1
    local quiet = pickup_quiet()
    if apcfg.block_vanilla and scan_due and not quiet and world_now_ms() >= (world.scan_after or 0) then
        scan_due = false
        dl.timed("pickup scan", scan_pickups)
    end
    dl.timed("daycare flashlight", daycare_flashlight_tick, "scan")
    dl.timed("boss areas", dl.boss_tick)
    local has_client = ap:read_to_game()
    try("notify", dl.notify_poll)
    try("scouts", function() ap:read_scouts() end)
    try("ui hooks", dl.ui_hooks)
    if not popup.hooked and (apcfg.popup or {}).enabled ~= false then
        local hp = (apcfg.popup or {}).hook or "/Game/Blueprints/UI/PlayerHUD.PlayerHUD_C:ShowCollectedItemDisplay"
        local ok = pcall(RegisterHook, hp, function()
            if #popup.pending == 0 and popup.begun then
                on_game_thread("popup begun", function()
                    if not popup.begun_done("item collected display") then return dl.popup_inventory_now() end
                    ExecuteWithDelay((apcfg.popup or {}).hook_delay_ms or 50, function()
                        on_game_thread("popup", function() popup_tick("hook") end)
                    end)
                end)
                return
            end
            if #popup.pending == 0 then
                on_game_thread("popup inventory", dl.popup_inventory_now)
                return
            end
            if not popup.done_once then pstep("hook fired") end
            ExecuteWithDelay((apcfg.popup or {}).hook_delay_ms or 50, function()
                on_game_thread("popup", function() popup_tick("hook") end)
            end)
        end)
        if ok then popup.hooked = true; log:write("AP", "popup: hooked " .. hp) end
    end
    if not dl.hide_hooked and apcfg.prompt_hide_hook ~= false then
        dl.hide_hooked = true
        local hp = "/Game/Blueprints/UI/PlayerHUD.PlayerHUD_C:Hide Informational Message"
        local ok, err = pcall(RegisterHook, hp, function() trace_step("hook prompt hide"); dl.prompt_hide_hook() end)
        if ok then log:write("AP", "prompt: hooked " .. hp)
        else
            if not dl.hide_hook_failed then log:write("AP", "prompt: hook not ready yet " .. hp .. ": " .. tostring(err)) end
            dl.hide_hook_failed, dl.hide_hooked = true, false
        end
    end
    ap:game_deaths(last_state and last_state.scalars["WorldState.DeathCount"], world_now(),
        dl.override ~= nil and tonumber(dl.override) == dl.OFF)
    try("death link", death_link_tick)
    local inv = find("FNAFInventorySystem")
    if last_state and last_state.ready then ready_polls = ready_polls + 1 else ready_polls = 0 end
    game.missions = last_state and last_state.missions
    game.tasks = last_state and last_state.tasks
    game.active = last_state and last_state.active
    dl.timed("voice hooks", voice_hooks_tick, has_client, game.missions)
    if last_state and last_state.ready then dl.timed("hold triggers", hold_triggers_tick, game.missions) end
    if last_state and last_state.ready then dl.timed("office monty", dl.office_monty_tick, game.missions, game.tasks) end
    if last_state and last_state.ready and (apcfg.office_monty or {}).log_locked_doors then dl.timed("locked doors", dl.locked_doors_tick) end
    if last_state and last_state.ready and not quiet then
        dl.timed("lock pickups", lock_pickups_tick, game.missions)
        dl.timed("arcade locks", function()
            local n = arcade_locks_tick(has_client)
            if n and not prompt.near then prompt.near = n end
        end)
        dl.timed("lock actors", function()
            local n = dl.lock_actors_tick(game.missions)
            if n and prompt.near then
                local list = { table.unpack(prompt.near.list or { prompt.near }) }
                for _, c in ipairs(n.list) do list[#list + 1] = c end
                prompt.near = { list = list }
            elseif n then prompt.near = n end
        end)
    elseif quiet then
    else prompt.near = nil end
    if ready_polls >= (apcfg.ready_polls or 3) then
        for _, a in ipairs(ap:task_actions(game)) do
            local ok = try("ap task", run_action, inv, a)
            ap:done(a, ok)
        end
        try("ap mission fallbacks", ap.mission_fallbacks, ap, game)
    end
    if has_client and apcfg.inject and inv and ready_polls >= (apcfg.ready_polls or 3) then
        game.security_level = tonumber(U.to_str(prop(inv, "SecurityLevel")))
        game.gregory = find("Gregory_C") ~= nil
        for _, a in ipairs(ap:plan(game)) do
            if a.op == "award" and dl.awards.why and dl.hold_on() then
                ap:once("held:" .. a.name .. ":" .. dl.awards.why, string.format("AwardItem %s waits: %s", a.name, dl.awards.why))
            else
                local ok = try("ap " .. a.op, run_action, inv, a)
                ap:done(a, ok)
            end
        end
    end
    if not dl.ending_hooked then try("goal hooks", dl.ending_hooks) end
    ap:flush()
end

-- startup
log:write("Start", string.format("%s %s loaded (%s)", MOD, VERSION, _VERSION))
if ap then
    log:write("AP", "bridge folder: " .. ap.dir .. " (inject=" .. tostring(apcfg.inject) .. ")")
end

if ap and apcfg.block_vanilla then
    local first = true
    local skip_class = {}
    local function wanted(cls)
        return (apcfg.condition_swaps or {})[cls]
            or ((apcfg.daycare_flashlight or {}).stash_classes or {})[cls]
    end
    local ok, err = pcall(RegisterBeginPlayPreHook, function(ctx)
        if world.in_minigame then return end
        local actor = U.unwrap(ctx)
        local cls = class_name(actor)
        if world.hook_seen[cls] == false then world.hook_seen[cls] = world_now_ms() end
        dl.lock_actor_appeared(cls)
        try("boss area", dl.boss_appeared, actor, cls)
        dl.arcade_appeared(cls)
        dl.lock_pickup_appeared(cls)
        dl.office_appeared(actor, cls)
        watch.appeared(cls)
        dl.card_trigger_appeared(actor, cls)
        if skip_class[cls] then return end
        if wanted(cls) then
            try("condition swap at BeginPlay", swap_conditions, actor, "BeginPlay")
            try("daycare flashlight at BeginPlay", df_beginplay, actor)
        end
        if not is_collectible(actor) then
            if cls ~= "?" and pickup_class_cache[cls] == false and not wanted(cls) then skip_class[cls] = true end
            return
        end
        if world.hook_seen.Collectible_C == false then world.hook_seen.Collectible_C = world_now_ms() end
        if first then
            first = false
            log:write("Swap", "BeginPlay pre-hook reached a pickup: " .. U.short_object_name(full_name(actor)))
        end
        if apcfg.log_beginplay then
            log:write("Swap", string.format("BeginPlay %s ItemName=%s", U.short_object_name(full_name(actor)),
                U.to_str(prop(actor, "ItemName"))))
        end
        try("swap at BeginPlay", swap_actor, actor, "BeginPlay")
        scan_due = true
        world.scan_after = world_now_ms() + (apcfg.scan_settle_ms or 3000)
    end)
    world.beginplay_hook = ok
    log:write("Swap", ok and "BeginPlay pre-hook registered" or ("BeginPlay pre-hook NOT available: " .. tostring(err)
        .. " -- pickups are swapped by the poll scan only, after their BeginPlay"))
end

if cfg.native_hooks_enabled then register_all(cfg.native_hooks, false)
else log:write("AP", "hooks on the game's C++ functions off (native_hooks_enabled = false)") end
register_all(cfg.bp_hooks, true)
for _, spec in ipairs(cfg.voice_hooks or {}) do
    spec.is_actor = false
    voice_specs[#voice_specs + 1] = spec
end
log:write("Hook", #pending .. " hook(s) pending (function not loaded yet), retrying every " .. cfg.hook_retry_ms .. " ms")

local function on_new_controller(pc)
    local ok, full = pcall(function() return pc:GetFullName() end)
    full = ok and type(full) == "string" and full or "?"
    local real = full:find(cfg.real_world_map or "MAP_TheWorld", 1, true) ~= nil
    world.switches = world.switches + 1
    world.pause_until = world_now() + (cfg.world_switch_pause_s or 5)
    world.loaded_at = world_now()
    dlm.widget, dlm.pause, dlm.kind = nil, nil, nil
    dlm.hosts = {}
    dlm.page = nil
    dlm.page_failed, dlm.list_failed, dlm.tries = nil, nil, {}
    for k in pairs(found_paths) do found_paths[k] = nil end
    for k in pairs(trail) do trail[k] = nil end
    spawned_force("world switch")
    for _, e in pairs(effects) do e.until_ms = 0 end
    prompt.near, prompt.shown = nil, false
    local was = world.in_minigame
    world.in_minigame = not real
    if not real and full:find(cfg.title_map or "MAP_Title", 1, true) then world.from_title = true end
    if real and world.from_title then world.from_title, world.fresh_load, world.fresh_tries = false, true, 0 end
    if real then
        scan_due = true
        local gone = 0
        for k in pairs(spawned_ai) do spawned_ai[k] = nil; gone = gone + 1 end
        if gone > 0 then log:write("AP", string.format("Security Alert: %d spawned animatronic(s) forgotten (new world)", gone)) end
        if ap then ap:new_world() end
    end
    log:write("World", string.format("new PlayerController %s: %s, mod paused %ds%s", full,
        real and "real world" or "minigame (mod idle until the real world is back)",
        cfg.world_switch_pause_s or 5, (was and real) and ", back from the minigame" or ""))
end
if type(NotifyOnNewObject) == "function" then
    local okn, errn = pcall(NotifyOnNewObject, "/Script/Engine.PlayerController", function(pc)
        try("new PlayerController", on_new_controller, pc)
    end)
    if not okn then log:write("World", "NotifyOnNewObject failed: " .. tostring(errn)) end
end

LoopAsync(cfg.hook_retry_ms, function()
    if #pending == 0 then return true end
    if world_busy() then return false end
    on_game_thread("retry hooks", retry_pending)
    return false
end)

LoopAsync(cfg.poll_ms, function()
    on_game_thread("poll", function()
        if world_busy() then return end
        dl.timed("state read", snapshot, "poll")
        dl.timed("trail", trail_tick)
        dl.timed("despawn", despawn_tick)
        dl.timed("voice poll", voice_poll)
        ap_tick()
        dl.poll_report()
    end)
    return false
end)

LoopAsync(cfg.prompt_ms or 150, function()
    if world_busy() then return false end
    if prompt.near or prompt.shown then on_game_thread("prompt", prompt_tick) end
    return false
end)

LoopAsync(cfg.prompt_ms or 150, function()
    if world_busy() then return false end
    if next(spawned_ai) ~= nil then on_game_thread("catch", catch_tick) end
    if ap and not dl.ending_hooked and os.clock() >= (dl.ending_next or 0) then
        dl.ending_next = os.clock() + 5
        on_game_thread("goal hooks", function() try("goal hooks", dl.ending_hooks) end)
    end
    if ap and tonumber(ap.options.death_link) == 1 and dl_cfg().enabled ~= false
            then
        local read = world_now_ms() >= (dl.read_next or 0)
        if read then dl.read_next = world_now_ms() + (dl_cfg().read_ms or 500) end
        on_game_thread("death link", function()
            if read then try("death link read", function() ap:read_to_game() end) end
            try("death link", death_link_tick)
            try("death link menu", dl_menu_tick)
        end)
    elseif dl.active then
        on_game_thread("death link", function() try("death link follow", dl_follow) end)
    elseif ap and (dl_cfg().pause_menu or {}).enabled ~= false then
        on_game_thread("death link menu", function() try("death link menu", dl_menu_tick) end)
    end
    return false
end)

LoopAsync(cfg.prompt_ms or 150, function()
    if next(effects) ~= nil then on_game_thread("effects", effects_tick) end
    if not world.in_minigame and dl.hold_on() then
        on_game_thread("held awards", dl.awards_tick)
    end
    if not world.in_minigame and not world_busy() then on_game_thread("instruction cards", dl.cards_tick) end
    return false
end)
LoopAsync((apcfg.popup or {}).tick_ms or 33, function()
    if #popup.pending > 0 then
        on_game_thread("popup", function() popup_tick("tick") end)
    end
    if popup.fade then on_game_thread("popup fade", dl.popup_fade_tick) end
    return false
end)
LoopAsync(((apcfg.effects or {}).foxy or {}).tick_ms or 25, function()
    if dl.foxy_anim then on_game_thread("foxy frames", function() try("foxy frames", dl.foxy_frame_tick) end) end
    return false
end)
LoopAsync((apcfg.received_notify or {}).tick_ms or 25, function()
    if dl.nt.cur or #dl.nt.queue > 0 then on_game_thread("notify", dl.nt_tick) end
    return false
end)
LoopAsync((apcfg.credits or {}).tick_ms or 1000, function()
    if (apcfg.credits or {}).enabled == false or dl.cr.done then return true end
    if world_now() >= world.pause_until then on_game_thread("credits hooks", dl.credits_hooks) end
    return dl.cr.done == true
end)
