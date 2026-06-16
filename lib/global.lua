local Event = require 'lib.event_core'
local Global = {
    names = {},
    index = 0,
    filepath = {}
}
local function ensure()
    if not storage.tokens then
        storage.tokens = {}
    end
    return storage.tokens
end
Event.on_init(ensure)
local concat = table.concat
local function validate_entry(filepath)
    local tokens = ensure()
    if tokens[filepath] then
        if not tokens[filepath].token_index then
            tokens[filepath].token_index = 1
        else
            tokens[filepath].token_index = tokens[filepath].token_index + 1
        end
        local index = tokens[filepath].token_index
        filepath = filepath .. '_' .. index
    end
    return filepath
end
function Global.set_global(tbl)
    local tokens = ensure()
    local filepath = debug.getinfo(3, 'S').source:match('^@__level__/(.+)$'):sub(1, -5):gsub('/', '_')
    filepath = validate_entry(filepath)
    Global.index = Global.index + 1
    Global.filepath[filepath] = Global.index
    Global.names[filepath] = concat { Global.filepath[filepath], ' - ', filepath }
    tokens[filepath] = tbl
    return Global.index, filepath
end
function Global.get_global(token)
    if storage.tokens and storage.tokens[token] then
        return storage.tokens[token]
    end
end
function Global.register(tbl, callback)
    local token, filepath = Global.set_global(tbl)
    Event.on_load(
        function ()
            if storage.tokens and storage.tokens[token] then
                callback(Global.get_global(token))
            else
                callback(Global.get_global(filepath))
            end
        end
    )
    return filepath
end
function Global.register_init(tbl, init_handler, callback)
    local token, filepath = Global.set_global(tbl)
    Event.on_init(
        function ()
            init_handler(tbl)
            callback(tbl)
        end
    )
    Event.on_load(
        function ()
            if storage.tokens and storage.tokens[token] then
                callback(Global.get_global(token))
            else
                callback(Global.get_global(filepath))
            end
        end
    )
    return filepath
end
return Global
