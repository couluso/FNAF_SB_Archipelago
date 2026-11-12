-- Pure-Lua helpers. No UE4SS globals are used at load time.
local U = {}

function U.dirname(path)
    return tostring(path):match("^(.*)[/\\][^/\\]+$") or "."
end

function U.level_of(full)
    local path = tostring(full):match("^%S+ ([^:]+):") or ""
    return path:match("/([^/%.]+)%.[^/]*$") or "?"
end

function U.short_object_name(full)
    return tostring(full):match("[%.:]([^%.:]+)$") or tostring(full)
end

function U.to_str(v)
    local t = type(v)
    if v == nil then return "nil" end
    if t == "string" then return v end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t == "userdata" or t == "table" then
        for _, attempt in ipairs({
            function() return v:ToString() end,
            function() return v:GetFullName() end,
        }) do
            local ok, s = pcall(attempt)
            if ok and type(s) == "string" and s ~= "" then return s end
        end
    end
    local ok, s = pcall(tostring, v)
    return ok and s or "?"
end

function U.unwrap(v)
    if v == nil then return nil end
    local t = type(v)
    if t == "userdata" or t == "table" then
        local ok, inner = pcall(function() return v:get() end)
        if ok and inner ~= nil then return inner end
    end
    return v
end

function U.list_from_array(arr, map)
    map = map or U.to_str
    local out = {}
    if arr == nil then return out end
    local ok = pcall(function()
        arr:ForEach(function(_, elem) out[#out + 1] = map(U.unwrap(elem)) end)
    end)
    if ok then return out end
    out = {}
    if type(arr) == "table" then
        for _, elem in pairs(arr) do out[#out + 1] = map(U.unwrap(elem)) end
    end
    return out
end

function U.set_of(list)
    local s = {}
    for _, v in ipairs(list) do s[v] = true end
    return s
end

function U.diff_sets(old, new)
    local added, removed = {}, {}
    for k in pairs(new) do if not old[k] then added[#added + 1] = k end end
    for k in pairs(old) do if not new[k] then removed[#removed + 1] = k end end
    table.sort(added); table.sort(removed)
    return added, removed
end

function U.sorted_keys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

function U.clock_hour(text, pm)
    local t = tostring(text or "")
    local h = tonumber(t:match("(%d+)%s*:%s*%d+"))
    if not h or h < 1 or h > 12 then return nil end
    local up = t:upper()
    local is_pm
    if up:find("PM", 1, true) then
        is_pm = true
    elseif up:find("AM", 1, true) then
        is_pm = false
    else
        is_pm = pm == true or U.to_str(pm) == "true"
    end
    return (h % 12) + (is_pm and 12 or 0)
end

U.INVENTORY_CATEGORY = {
    [0] = "None", [1] = "Message", [2] = "Equipment", [3] = "Food", [4] = "Toys",
    [5] = "Trophy", [6] = "LostAndFound", [7] = "Character", [8] = "Clothing",
    [9] = "SecurityBadge", [10] = "PartyBadge", [11] = "RetroCD", [12] = "CollectibleDLC",
    [13] = "RealCollectables", [14] = "ARCollectables",
}

local Logger = {}
Logger.__index = Logger
local QUIET_TAGS = { Hook = true, Swap = true, Change = true, State = true }
local LOUD_TAGS = { Error = true, Start = true }

function U.new_logger(opts)
    local self = setmetatable({
        path = opts.path,
        max_lines = opts.max_lines or 5000,
        echo = opts.echo,
        console = opts.console,
        verbose = opts.verbose,
        prefix = opts.prefix or "",
        clock = opts.clock or function() return os.date("%H:%M:%S") end,
        lines = 0,
        capped = false,
        file = nil,
    }, Logger)
    local f = io.open(self.path, "wb")
    if f then self.file = f end
    return self
end

function Logger:write(tag, msg)
    if not self.verbose and QUIET_TAGS[tag] then return end
    local line = string.format("[%s] [%s] %s", self.clock(), tag, tostring(msg))
    if self.echo and (self.console or LOUD_TAGS[tag]) then pcall(self.echo, self.prefix .. " " .. line) end
    if self.capped or not self.file then return end
    self.lines = self.lines + 1
    if self.lines > self.max_lines then
        self.capped = true
        line = string.format("[%s] [Log] %d lines reached, log stopped for this session", self.clock(), self.max_lines)
    end
    self.file:write(line, "\n")
    if self.verbose or self.capped or tag == "Error" or self.lines % 50 == 0 then self.file:flush() end
end

function U.write_file(path, text)
    local f, err = io.open(path, "wb")
    if not f then return false, err end
    f:write(text)
    f:close()
    return true
end

function U.file_exists(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

return U
