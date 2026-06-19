local Defaults = require 'toggle_defaults'
local Config = {}
local function seed(force)
    if not storage.toggle_defaults then storage.toggle_defaults = {} end
    for id, val in pairs(Defaults) do
        if force or storage.toggle_defaults[id] == nil then
            storage.toggle_defaults[id] = val and true or false
        end
    end
end
local function ensure_storage()
    if not storage.toggle_defaults then seed(true) end
end
function Config.get_default(id)
    local v = Defaults[id]
    if v == nil then return false end
    return v and true or false
end
function Config.is_enabled(id)
    ensure_storage()
    local v = storage.toggle_defaults[id]
    if v == nil then return Config.get_default(id) end
    return v and true or false
end
function Config.set(id, new_state)
    ensure_storage()
    storage.toggle_defaults[id] = new_state and true or false
end
function Config.ensure_defaults()
    seed(false)
end
function Config.reset_to_defaults()
    storage.toggle_defaults = {}
    seed(true)
end
function Config.iter_defaults()
    return pairs(Defaults)
end
return Config
