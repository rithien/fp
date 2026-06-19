local Event = require 'lib.event'
local Public = {}
local refresh_listeners = {}
local function bind_storage()
    storage.server_select = storage.server_select or { servers = {}, current_id = nil }
    storage.server_select.servers = storage.server_select.servers or {}
end
Event.on_init(bind_storage)
Event.on_configuration_changed(bind_storage)
function Public.register_refresh(fn)
    refresh_listeners[#refresh_listeners + 1] = fn
end
local function notify()
    for _, fn in ipairs(refresh_listeners) do
        local ok, err = pcall(fn)
        if not ok then
            log('[server_select] refresh listener failed: ' .. tostring(err))
        end
    end
end
function Public.update_instances(json, full, current_id)
    bind_storage()
    local ok, list = pcall(helpers.json_to_table, json)
    if not ok or type(list) ~= 'table' then
        log('[server_select] update_instances: malformed json: ' .. tostring(list))
        return
    end
    if full then
        storage.server_select.servers = {}
    end
    for _, srv in ipairs(list) do
        if type(srv) == 'table' and srv.id then
            if srv.removed then
                storage.server_select.servers[srv.id] = nil
            else
                storage.server_select.servers[srv.id] = srv
            end
        end
    end
    storage.server_select.current_id = current_id
    notify()
end
function Public.get_servers()
    bind_storage()
    local out = {}
    for _, srv in pairs(storage.server_select.servers) do
        out[#out + 1] = srv
    end
    table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return out
end
function Public.get_current_id()
    bind_storage()
    return storage.server_select.current_id
end
function Public.get_server(id)
    bind_storage()
    return storage.server_select.servers[id]
end
return Public
