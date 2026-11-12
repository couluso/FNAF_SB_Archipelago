-- Archipelago bridge logic. Pure Lua with no UE4SS globals, so it can be tested outside the game.
local A = {}
A.__index = A

local function sorted_ids(set)
    local out = {}
    for id in pairs(set) do out[#out + 1] = id end
    table.sort(out)
    return out
end

function A.new(opts)
    local self = setmetatable({}, A)
    self.T = opts.tables
    self.dir = opts.bridge_dir
    self.fs = opts.fs
    self.log = opts.log or function() end
    self.cfg = opts.cfg or {}
    self.header = nil
    self.options = {}
    self.received = {}
    self.deaths_received = 0
    self.checks = {}
    self.used = {}
    self.deaths = 0
    self.dirty = false
    self.self_awarded = {}
    self.award_attempts = {}
    self.logged_once = {}
    self.recorded_now = {}
    self.opened = {}
    self.taken = {}
    self.endings = {}
    self.goal = false
    self.last_text = nil
    self.ap_names = {}
    for _, it in pairs(self.T.items or {}) do
        for _, n in ipairs(it.names or {}) do self.ap_names[n] = true end
    end
    for n in pairs(self.cfg.block_story_pickups or {}) do self.ap_names[n] = true end
    return self
end

function A:once(key, msg)
    if self.logged_once[key] then return end
    self.logged_once[key] = true
    self.log(msg)
end

function A:path(name) return self.dir .. "/" .. name end

function A:state_path()
    local tag = (self.header or "S none none"):sub(3):gsub("[^%w%-_]", "_")
    return self:path("ap_state_" .. tag .. ".txt")
end

-- scouts.txt (0.5.48)
function A:read_scouts()
    if not self.header then return end
    local text = self.fs.read(self:path("scouts.txt"))
    if not text or text == self.scouts_text then return end
    local header = (text:match("^([^\r\n]*)") or ""):gsub("%s+$", "")
    if header ~= self.header then
        self:once("scouts:" .. header, "bridge: scouts.txt is for " .. header .. ", not " .. self.header .. ": waiting")
        return
    end
    self.scouts_text = text
    local s, n = {}, 0
    for line in text:gmatch("[^\r\n]+") do
        local loc, item, flags, own, iname, pname = line:match("^L\t(%d+)\t(%-?%d+)\t(%d+)\t([01])\t([^\t]*)\t?([^\t]*)")
        if loc then
            s[tonumber(loc)] = { item = tonumber(item), flags = tonumber(flags) or 0, own = own == "1",
                                 name = iname, player = pname }
            n = n + 1
        end
    end
    self.scouts = s
    self.log(string.format("bridge: %d scouted location(s) (pickup popups)", n))
end

-- to_game.txt
function A:read_to_game()
    local text = self.fs.read(self:path("to_game.txt"))
    if not text then return false end
    if text == self.last_text then return true end
    self.last_text = text
    local header, received, options, deaths, server_checks = nil, {}, {}, 0, {}
    for line in text:gmatch("[^\r\n]+") do
        local tag, a, b = line:match("^(%a)%s+(%S+)%s*(%S*)")
        if tag == "S" then
            header = line:gsub("%s+$", "")
        elseif tag == "O" then
            options[a] = tonumber(b) or b
        elseif tag == "I" then
            local idx, id = tonumber(a), tonumber(b)
            if idx and id then received[idx + 1] = id end
        elseif tag == "D" then
            deaths = tonumber(a) or 0
        elseif tag == "K" then
            local id = tonumber(a)
            if id then server_checks[#server_checks + 1] = id end
        end
    end
    local same_room = header == self.header
    if header ~= self.header then
        local pending = self.header == nil and self.checks or {}
        local pending_endings = self.header == nil and self.endings or {}
        self.header = header
        self:load_state()
        for id in pairs(pending) do self.checks[id] = true end
        for key in pairs(pending_endings) do self.endings[key] = true end
        if (self.deaths_pending or 0) > 0 then
            self.deaths = self.deaths + self.deaths_pending
            self.deaths_pending = nil
        end
        self.dirty = true
        self.log("bridge: multiworld " .. tostring(header))
        if header and header:match("^S unknown ") then
            self.log("WARNING: the client sends no seed name (old fnaf_sb.apworld). Every seed shares the record "
                .. self:state_path() .. ": install fnaf_sb.apworld 0.2.1, or empty the bridge folder before a new seed")
        end
    end
    local merged = 0
    for _, id in ipairs(server_checks) do
        if not self.checks[id] then
            self.checks[id] = true
            merged = merged + 1
        end
    end
    if merged > 0 then
        self.dirty = true
        self.log(string.format("bridge: %d check(s) already done on the server added to the record", merged))
    end
    local before = #self.received
    self.received, self.options = received, options
    self:check_goal()
    if not same_room or self.dl_seen == nil or deaths < self.dl_seen then
        self.dl_seen = deaths
    elseif deaths > self.dl_seen then
        self.dl_queue = (self.dl_queue or 0) + (deaths - self.dl_seen)
        self.log(string.format("bridge: Death Link received (%d new, %d in total)", deaths - self.dl_seen, deaths))
        self.dl_seen = deaths
    end
    self.deaths_received = deaths
    if #received ~= before then
        self.log(string.format("bridge: %d item(s) received in total", #received))
    end
    if same_room and #received < before then
        self.log(string.format("WARNING: the received item list went from %d to %d in the same room: "
            .. "is a second client writing to this bridge folder? Keep one client open", before, #received))
    end
    return true
end

-- ledger
function A:load_state()
    self.checks, self.used, self.taken = {}, {}, {}
    self.deaths = 0
    self.endings, self.goal = {}, false
    local text = self.fs.read(self:state_path())
    if not text then return end
    for line in text:gmatch("[^\r\n]+") do
        local tag, v = line:match("^(%a)%s+(%-?%d+)")
        if tag == "C" then self.checks[tonumber(v)] = true end
        if tag == "U" then self.used[tonumber(v)] = true end
        if tag == "D" then self.deaths = tonumber(v) or 0 end
        local taken = line:match("^P%s+(%S+)")
        if taken then self.taken[taken] = true end
        local ending = line:match("^E%s+(%S+)")
        if ending then self.endings[ending] = true end
        if line:match("^G%s*$") then self.goal = true end
    end
end

function A:save_state()
    if not self.header then return end
    local lines = { self.header }
    for _, id in ipairs(sorted_ids(self.checks)) do lines[#lines + 1] = "C " .. id end
    for _, i in ipairs(sorted_ids(self.used)) do lines[#lines + 1] = "U " .. i end
    local taken = {}
    for name in pairs(self.taken or {}) do taken[#taken + 1] = name end
    table.sort(taken)
    for _, name in ipairs(taken) do lines[#lines + 1] = "P " .. name end
    lines[#lines + 1] = "D " .. (self.deaths or 0)
    local ends = {}
    for key in pairs(self.endings or {}) do ends[#ends + 1] = key end
    table.sort(ends)
    for _, key in ipairs(ends) do lines[#lines + 1] = "E " .. key end
    if self.goal then lines[#lines + 1] = "G" end
    self.fs.write(self:state_path(), table.concat(lines, "\n") .. "\n")
end

-- vanilla rewards
function A:prefix() return self.cfg.swap_prefix or "APX_" end

function A:original_name(name)
    local p = self:prefix()
    if type(name) == "string" and #name > #p and name:sub(1, #p) == p then return name:sub(#p + 1), true end
    return name, false
end

function A:is_vanilla(name)
    local v = self.cfg.vanilla_items
    if v == nil then v = { Fazwatch = true, PhotoPass = true } end
    return v[name] == true
end

function A:pickup_checked(name)
    local id = self.T.locations.collect[(self:original_name(name))]
    return id ~= nil and self.checks[id] == true
end

function A:opened_name() return self.cfg.opened_name or "None" end

function A:story_task(name)
    if self:is_vanilla(name) then return nil end
    return (self.T.story_items or {})[name]
end

function A:swap_name(name, forced)
    if not self.cfg.block_vanilla or type(name) ~= "string" then return nil end
    if select(2, self:original_name(name)) then return nil end
    if not forced and not self.T.locations.collect[name] then return nil end
    if (self.cfg.listed_only or {})[name] and (not forced or self:pickup_checked(name)) then
        return nil
    end
    if self:is_vanilla(name) or (self.cfg.keep_vanilla or {})[name] then return nil end
    if not self.ap_names[name] then
        self:once("novanilla:" .. name, "pickup " .. name .. " kept vanilla: no AP item gives this game item yet")
        return nil
    end
    return self:prefix() .. name
end

function A:inventory_added(name)
    local original, swapped = self:original_name(name)
    if name == self:opened_name() and name ~= "None" then
        self.log("vanilla reward blocked: an opened pickup gave " .. name)
        return self.cfg.remove_swap_items ~= false and "remove" or nil
    end
    if swapped then
        self.log(string.format("vanilla reward blocked: the %s pickup gave %s", original, name))
        return self.cfg.remove_swap_items ~= false and "remove" or nil
    end
    if self.ap_names[name] and not self:is_ap_name(name) then
        if self:is_vanilla(name) then
            self.log("vanilla reward kept on purpose (vanilla item): " .. name)
            return nil
        end
        if self.cfg.block_vanilla and self.cfg.remove_vanilla_items ~= false then
            local task = self:story_task(name)
            self.log(string.format("vanilla reward blocked: %s entered the inventory without coming from AP%s: taken back",
                name, task and (" (task " .. task.key .. ")") or ""))
            return "remove"
        end
        self.log(string.format("vanilla reward NOT blocked: %s entered the inventory without coming from AP", name))
    end
    return nil
end

-- checks
function A:record_check(id, why)
    if self.checks[id] then
        if self.recorded_now[id] then return false end
        local info = self.T.location_info[id] or {}
        self:once("again:" .. id, string.format("check %d %s already recorded (%s), not sent again (%s)",
            id, tostring(info.key), why, self:state_path()))
        return false
    end
    self.checks[id] = true
    self.recorded_now[id] = true
    self.dirty = true
    local info = self.T.location_info[id] or {}
    self.log(string.format("check %d %s [%s] (%s)%s", id, tostring(info.key), tostring(info.status), why,
        self.header and "" or " -- no client yet, kept until to_game.txt appears"))
    return true
end

function A:on_event(detect, name)
    if name == nil or name == "" or name == "None" or name == "nil" then return false end
    if detect == "mission" and ((self.cfg.goal or {}).missions or {})[name] then
        self:ending_seen(self.cfg.goal.missions[name], "mission " .. name)
    end
    local swapped
    name, swapped = self:original_name(name)
    if swapped and detect ~= "collect" then return false end
    if swapped then self.opened[name] = true end
    if detect == "collect" and not swapped and (self.cfg.listed_only or {})[name] then
        return false
    end
    if swapped and (self.cfg.hold_until_pickup or {})[name] and not self.taken[name] then
        self.taken[name] = true
        self.dirty = true
        self.log(string.format("pickup %s taken: the AP item held back can be given now", name))
    end
    local id = (self.T.locations[detect] or {})[name]
    if not id then
        local alias = (self.cfg.event_aliases or {})[detect .. " " .. name]
        if alias and not (detect == "inventory" and self:is_ap_name(name)) then
            local d2, n2 = alias:match("^(%S+)%s+(.+)$")
            local id2 = d2 and (self.T.locations[d2] or {})[n2]
            if id2 then return self:record_check(id2, detect .. " " .. name .. " (as " .. alias .. ")") end
        end
        local quiet = detect == "inventory" or detect == "task" or detect == "flag" or (detect == "collect" and self.T.locations.message[name])
        if not quiet then
            self:once(detect .. ":" .. name, string.format("no AP location for %s %s", detect, name))
        end
        return false
    end
    if detect == "inventory" and self:is_ap_name(name) then
        return false
    end
    if detect == "clock" and not self.cfg.clock_checks then
        self:once("clock:" .. name, "clock hour " .. name .. " reached (clock checks are off in config.lua)")
        return false
    end
    return self:record_check(id, detect .. " " .. name)
end

local GOAL_KEYS = { [0] = "leave", "loading_dock", "rooftop", "afton", "unmasked", "canon" }
function A:ending_seen(key, how)
    if not key then return false end
    if not self.endings[key] then
        self.endings[key] = true
        self.dirty = true
        self.log(string.format("ending reached: %s (%s)", key, how or "?"))
    end
    return self:check_goal()
end
function A:goal_key()
    local g = self.options.goal
    if g == nil then return nil end
    return GOAL_KEYS[tonumber(g)] or tostring(g)
end
function A:check_goal()
    if self.goal or next(self.endings) == nil then return self.goal end
    local g = self:goal_key()
    if not g then
        self:once("goal?", "an ending was reached but the client sent no goal (fnaf_sb.apworld older than 0.3.11): kept until it does")
        return false
    end
    if self.endings[g] then
        self.goal = true
        self.dirty = true
        self.log("GOAL: the " .. g .. " ending is this slot's goal: sent to the client (G)")
        return true
    end
    local seen = {}
    for key in pairs(self.endings) do seen[#seen + 1] = key end
    table.sort(seen)
    self:once("goal-no:" .. table.concat(seen, ","), string.format("ending(s) %s reached, but this slot's goal is %s: not sent",
        table.concat(seen, ", "), g))
    return false
end


function A:game_deaths(n, now, muted)
    n = tonumber(n)
    if n == nil then return 0 end
    local last = self.game_deaths_last
    self.game_deaths_last = n
    if last == nil or n <= last then return 0 end
    local new = 0
    for _ = 1, n - last do
        if muted then
            self.log("bridge: Gregory died, Death Link is Disabled in the pause menu: not sent")
        elseif self.own_death_until and (now == nil or now <= self.own_death_until) then
            self.own_death_until = nil
            self.log("bridge: this death came from Death Link: not sent back")
        else
            new = new + 1
        end
    end
    if new > 0 then
        if self.header then
            self.deaths = self.deaths + new
            self.dirty = true
        else
            self.deaths_pending = (self.deaths_pending or 0) + new
        end
        self.log(string.format("bridge: Gregory died (game count %d), slot total %d", n,
            self.deaths + (self.deaths_pending or 0)))
    end
    return new
end
function A:set_deaths(n) return self:game_deaths(n) end

function A:expect_own_death(until_s) self.own_death_until = until_s end

function A:take_death_link()
    local n = self.dl_queue or 0
    self.dl_queue = 0
    return n
end

function A:from_game_text()
    local lines = { self.header }
    for _, id in ipairs(sorted_ids(self.checks)) do lines[#lines + 1] = "C " .. id end
    lines[#lines + 1] = "D " .. self.deaths
    if self.goal then lines[#lines + 1] = "G" end
    return table.concat(lines, "\n") .. "\n"
end

function A:flush()
    if not self.header then return false end
    local target = self:path("from_game.txt")
    if not self.dirty then
        if self.fs.read(target) ~= nil then return false end
        self.log("from_game.txt is missing: written again")
    end
    local tmp = target .. ".tmp"
    if not self.fs.write(tmp, self:from_game_text()) then
        self:once("write", "cannot write " .. tmp .. " (does the bridge folder exist?)")
        return false
    end
    self.fs.replace(tmp, target)
    self:save_state()
    self.dirty = false
    return true
end

-- items
function A:has_received(name)
    for _, id in ipairs(self.received) do
        local it = self.T.items[id]
        if it and it.name == name then return true end
    end
    return false
end

function A:desired()
    local counts, awards, seen, consumables, level = {}, {}, {}, {}, 0
    for i, id in ipairs(self.received) do
        local it = self.T.items[id]
        if not it then
            self:once("item:" .. id, "unknown AP item id " .. id)
        else
            counts[id] = (counts[id] or 0) + 1
            local n = counts[id]
            if it.kind == "badge" then
                level = level + 1
            elseif it.kind == "arcade" then
            elseif it.kind == "battery" or it.kind == "trap" or it.kind == "tokens" or it.kind == "effect" then
                consumables[#consumables + 1] = { index = i - 1, item = it }
            elseif #it.names > 0 then
                local name = it.names[math.min(n, #it.names)]
                if not seen[name] then
                    seen[name] = true
                    awards[#awards + 1] = name
                end
            else
                self:once("noname:" .. id, string.format("received %s: no sure game name (%s), not given", it.name, it.status))
            end
        end
    end
    return { awards = awards, award_set = seen, level = level, consumables = consumables }
end

function A:now()
    local f = rawget(_G, "AP_CLOCK")
    return f and f() or os.time()
end

function A:suspend(name, seconds, why)
    self.suspended = self.suspended or {}
    local cur = self.suspended[name]
    if cur and self:now() < cur.untilt then return false end
    self.suspended[name] = { untilt = self:now() + seconds, why = why }
    self.log(string.format("%s will be given back in %d s at the earliest (%s)", name, seconds, why))
    return true
end

function A:is_ap_name(name)
    return self.self_awarded[name] or self:desired().award_set[name] or false
end

function A:plan(game)
    local d = self:desired()
    local actions = {}
    local max_awards = self.cfg.max_awards_per_tick or 5
    local exact = self.cfg.enforce_security_level ~= false
    if self.cfg.set_security_level ~= false and game.security_level ~= nil
        and ((exact and game.security_level ~= d.level) or (not exact and d.level > 0 and game.security_level < d.level)) then
        actions[#actions + 1] = { op = "security", level = d.level }
    end
    local awards = 0
    for _, name in ipairs(d.awards) do
        if awards >= max_awards then break end
        local attempts = self.award_attempts[name] or 0
        local has = game.has(name)
        local hold = self:is_vanilla(name) and (self.T.story_items or {})[name]
        local until_pickup = (self.cfg.hold_until_pickup or {})[name] and not self.taken[name]
            and (self.T.story_items or {})[name]
        self.had = self.had or {}
        local wait = (self.suspended or {})[name]
        if wait and self:now() >= wait.untilt then
            self.suspended[name], self.had[name], wait = nil, nil, nil
        end
        local delay = (self.cfg.regive_delay or {})[name]
        if has == false and not wait and delay and self.had[name] then
            self:suspend(name, delay, "taken by the game, a recharge station?")
            wait = self.suspended[name]
        end
        if has then self.had[name] = true end
        if has == false and wait then
        elseif has == false and until_pickup and not (game.missions or {})[until_pickup.mission] then
            self:once("holdp:" .. name, string.format("holding %s until its vanilla pickup is taken (mission %s): "
                .. "the pickup hides itself while the item is owned", name, until_pickup.mission))
        elseif has == false and hold and not (game.missions or {})[hold.mission]
            and not (game.tasks or {})[hold.mission .. "#" .. hold.task] then
            self:once("hold:" .. name, string.format("holding %s until task %s (mission %s) is done: its pickup must stay closed",
                name, hold.key, hold.mission))
        elseif has == false and attempts < (self.cfg.max_award_attempts or 3) then
            actions[#actions + 1] = { op = "award", name = name }
            awards = awards + 1
        elseif has == false then
            self:once("giveup:" .. name, "AwardItem " .. name .. " did not stick after several tries, giving up this session")
        elseif has then
            self.award_attempts[name] = 0
        end
    end
    for _, c in ipairs(d.consumables) do
        if not self.used[c.index] then
            local name = c.item.name
            if name == "Battery Refill" then
                actions[#actions + 1] = { op = "battery", mode = "refill", index = c.index, item = name }
            elseif name == "Battery Trap" then
                actions[#actions + 1] = { op = "battery", mode = "drain", index = c.index, item = name }
            elseif c.item.kind == "effect" then
                if game.gregory then
                    actions[#actions + 1] = { op = "effect", index = c.index, item = name }
                end
            elseif name == "Security Alert" then
                if game.gregory then
                    actions[#actions + 1] = { op = "alert", index = c.index, item = name }
                end
            else
                actions[#actions + 1] = { op = "skip", index = c.index, item = name }
            end
        end
    end
    return actions
end

function A:task_actions(game)
    local actions = {}
    self.task_wait = self.task_wait or {}
    if not self.cfg.block_vanilla or self.cfg.complete_story_tasks == false then return actions end
    for name, t in pairs(self.T.story_items or {}) do
        local id = self.T.locations.collect[name]
        local key = t.mission .. "#" .. t.task
        local due = ((id and self.checks[id]) or self.opened[name]) and self:story_task(name) and self.ap_names[name]
            and (game.active or {})[t.mission] and not (game.missions or {})[t.mission]
            and not (game.tasks or {})[key]
        if due then
            self.task_wait[key] = (self.task_wait[key] or 0) + 1
            if self.task_wait[key] == 2 then
                actions[#actions + 1] = { op = "task", mission = t.mission, task = t.task, key = t.key, item = name }
            end
        else
            self.task_wait[key] = nil
        end
    end
    table.sort(actions, function(a, b) return a.key < b.key end)
    return actions
end

function A:done(action, ok)
    if action.op == "task" then
        self.log(string.format("completed task %s by hand (pickup %s checked, task not done by the game)%s",
            action.key, action.item, ok and "" or " -- FAILED"))
        return
    end
    if action.op == "award" then
        self.self_awarded[action.name] = true
        self.award_attempts[action.name] = (self.award_attempts[action.name] or 0) + 1
    elseif action.index ~= nil then
        self.used[action.index] = true
        self.dirty = true
        if action.op == "skip" then
            self.log("received " .. action.item .. ": no game mechanism yet, not applied")
        end
    end
end

function A:status()
    local d = self:desired()
    local n = 0
    for _ in pairs(self.checks) do n = n + 1 end
    return string.format("header=%s received=%d to_give=%d badge_level=%d checks=%d deaths=%d",
        tostring(self.header), #self.received, #d.awards, d.level, n, self.deaths)
end

return A
