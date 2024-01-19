local debug_getinfo = debug.getinfo
local undump = require "undump"
local include = {}

local function nextline(proto, abs, currentline, pc)
    local line = proto.lineinfo[pc]
    if line == -128 then
        return assert(abs[pc-1])
    else
        return currentline + line
    end
end

local function calc_actives_54(proto, actives)
    local currentline = proto.linedefined
    local abs = {}
    for _, line in ipairs(proto.abslineinfo) do
        abs[line.pc] = line.line
    end
    local start = 1
    if proto.is_vararg > 0 then
        assert(proto.code[1] & 0x7F == 81) -- OP_VARARGPREP
        currentline = nextline(proto, abs, currentline, 1)
        start = 2
    end
    for pc = start, #proto.lineinfo do
        currentline = nextline(proto, abs, currentline, pc)
        actives[currentline] = true
    end
    for i = 1, proto.sizep do
        calc_actives_54(proto.p[i], actives)
    end
end

local function calc_actives_53(proto, actives)
    for _, line in ipairs(proto.lineinfo) do
        actives[line] = true
    end
    for i = 1, proto.sizep do
        calc_actives_53(proto.p[i], actives)
    end
end

local function get_actives(source)
    local prefix = source:sub(1, 1)
    if prefix == "=" then
        return {}
    end
    if prefix == "@" then
        local f = assert(io.open(source:sub(2)))
        source = f:read "a"
        f:close()
    end
    local cl, version = undump(string.dump(assert(load(source))))
    local actives = {}
    if version >= 0x54 then
        calc_actives_54(cl.f, actives)
    else
        calc_actives_53(cl.f, actives)
    end
    return actives
end

local function sortpairs(t)
    local sort = {}
    for k in pairs(t) do
        sort[#sort+1] = k
    end
    table.sort(sort)
    local n = 1
    return function ()
        local k = sort[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

local function debug_hook(_, lineno)
    local file = include[debug_getinfo(2, "S").source]
    if file then
        file[lineno] = true
    end
end

local m = {}

function m.include(source, name)
    if include[source] then
        include[source].name = name
    else
        include[source] = { name = name }
    end
end

function m.start(co)
    if co then
        debug.sethook(co, debug_hook, "l")
    else
        debug.sethook(debug_hook, "l")
    end
end

function m.stop()
    debug.sethook()
end

function m.result()
    local str = {}
    for source, file in sortpairs(include) do
        local actives = get_actives(source)
        local max = 0
        for i in pairs(actives) do
            if i > max then max = i end
        end
        local total = 0
        local pass = 0
        local status = {}
        local lines = {}
        for i = 1, max do
            if not actives[i] then
                status[#status+1] = "."
            elseif file[i] then
                total = total + 1
                pass = pass + 1
                status[#status+1] = "."
            else
                total = total + 1
                status[#status+1] = "X"
                lines[#lines+1] = tostring(i)
            end
        end
        str[#str+1] = string.format("coverage: %02.02f%% (%d/%d) %s", pass / total * 100, pass, total, file.name)
        if #lines > 0 then
            str[#str+1] = table.concat(lines, " ")
            str[#str+1] = table.concat(status)
        end
    end
    return table.concat(str, "\n")
end

return m
