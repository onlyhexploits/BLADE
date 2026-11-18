local genv = (getgenv and getgenv()) or _G

if genv.__ParentResolver then
    return genv.__ParentResolver
end

local function safeRef(inst)
    if typeof(cloneref) == "function" then
        local ok, ref = pcall(cloneref, inst)
        if ok and ref then return ref end
    end
    return inst
end

local function getService(name: string)
    local ok, svc = pcall(game.GetService, game, name)
    return ok and svc and safeRef(svc) or nil
end

local function randomName(len: number?): string
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local out = table.create(len or 12)
    for i = 1, len or 12 do
        local n = math.random(1, #chars)
        out[i] = chars:sub(n, n)
    end
    return table.concat(out)
end

local function callHidden(fn): Instance?
    if typeof(fn) ~= "function" then return nil end
    local ok, hui = pcall(fn)
    if ok and typeof(hui) == "Instance" then return hui end
    return nil
end

local candidates = {
    { name = "gethui",         get = function() return callHidden(gethui) end },
    { name = "get_hidden_gui", get = function() return callHidden(get_hidden_gui) end },
    { name = "coregui",        get = function() return getService("CoreGui") end },
    { name = "playergui",      get = function()
        local players = getService("Players")
        local lp = players and players.LocalPlayer
        if not lp then return nil end
        return lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 5)
    end },
}

local function probe(parent: Instance): boolean
    local ok = pcall(function()
        local t = Instance.new("ScreenGui")
        t.Name = randomName()
        t.Parent = parent
        local stuck = t.Parent == parent
        t:Destroy()
        assert(stuck)
    end)
    return ok
end

local Module = {}
local handles = {}
local cached: Instance?, cachedName: string?

function Module.resolve(force: boolean?): (Instance?, string?)
    if not force and cached and cached.Parent then
        return cached, cachedName
    end
    for _, c in ipairs(candidates) do
        local ok, parent = pcall(c.get)
        if ok and parent and probe(parent) then
            cached, cachedName = parent, c.name
            return parent, c.name
        end
    end
    return nil, nil
end

function Module.mount(gui: ScreenGui, opts: { name: string?, display: number?, persist: boolean? }?)
    opts = opts or {}
    local parent, source = Module.resolve()
    if not parent then
        warn("m: no valid ui parent found")
        return nil
    end

    gui.Name = opts.name or randomName()
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = opts.display or 999

    if syn and typeof(syn.protect_gui) == "function" then
        pcall(syn.protect_gui, gui)
    elseif typeof(protect_gui) == "function" then
        pcall(protect_gui, gui)
    end

    local ok = pcall(function() gui.Parent = parent end)
    if not ok or gui.Parent ~= parent then
        return nil
    end

    local handle = { Gui = gui, Source = source, Alive = true }
    local conn

    if opts.persist ~= false then
        conn = gui.AncestryChanged:Connect(function()
            if not handle.Alive or gui.Parent ~= nil then return end
            task.defer(function()
                if not handle.Alive then return end
                local p = Module.resolve(true)
                if p then pcall(function() gui.Parent = p end) end
            end)
        end)
    end

    function handle.Destroy()
        if not handle.Alive then return end
        handle.Alive = false
        if conn then conn:Disconnect() end
        pcall(function() gui:Destroy() end)
        local i = table.find(handles, handle)
        if i then table.remove(handles, i) end
    end

    table.insert(handles, handle)
    return handle
end

function Module.unload()
    for i = #handles, 1, -1 do
        handles[i].Destroy()
    end
    genv.__ParentResolver = nil
end

genv.__ParentResolver = Module
return Module
