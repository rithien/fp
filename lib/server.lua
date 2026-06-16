local concat = table.concat
local tostring = tostring
local raw_print = print
local Public = {}
local data_set_handlers = {}
local discord_tag = '[DISCORD]'
local discord_raw_tag = '[DISCORD-RAW]'
local discord_bold_tag = '[DISCORD-BOLD]'
local discord_admin_tag = '[DISCORD-ADMIN]'
local discord_admin_raw_tag = '[DISCORD-ADMIN-RAW]'
local discord_embed_tag = '[DISCORD-EMBED]'
local discord_embed_raw_tag = '[DISCORD-EMBED-RAW]'
local discord_embed_parsed_tag = '[DISCORD-EMBED-PARSED]'
local discord_admin_embed_tag = '[DISCORD-ADMIN-EMBED]'
local discord_admin_embed_raw_tag = '[DISCORD-ADMIN-EMBED-RAW]'
local discord_antigrief_bold_tag = '[DISCORD-ANTIGRIEF-BOLD]'
local discord_antigrief_embed_tag = '[DISCORD-ANTIGRIEF-EMBED]'
local discord_antigrief_embed_parsed_tag = '[DISCORD-ANTIGRIEF-EMBED-PARSED]'
local data_set_tag = '[DATA-SET]'
local data_get_tag = '[DATA-GET]'
local data_get_and_print_tag = '[DATA-GET-AND-PRINT]'
local data_get_all_tag = '[DATA-GET-ALL]'
local antigrief_tag = '[ANTIGRIEF-LOG]'
local jail_tag = '[JAIL]'
local unjail_tag = '[UNJAIL]'
local trust_tag = '[TRUST]'
local untrust_tag = '[UNTRUST]'
Public.raw_print = raw_print
local function output_data(primary, secondary)
    assert(primary, 'output_data - primary must be provided')
    if type(primary) ~= 'string' then
        primary = tostring(primary)
    end
    assert(primary:len() > 0, 'output_data - primary must be a non-empty string')
    if type(secondary) == 'boolean' then
        secondary = tostring(secondary)
    end
    if type(secondary) == 'table' then
        secondary = helpers.table_to_json(secondary)
    end
    raw_print(primary .. (secondary or ''))
end
function Public.to_discord(message, locale)
    if locale then print(message, discord_tag) else output_data(discord_tag .. message) end
end
function Public.to_discord_raw(message, locale)
    if locale then print(message, discord_raw_tag) else output_data(discord_raw_tag .. message) end
end
function Public.to_discord_bold(message, locale)
    if locale then print(message, discord_bold_tag) else output_data(discord_bold_tag .. message) end
end
function Public.to_admin(message, locale)
    if locale then print(message, discord_admin_tag) else output_data(discord_admin_tag .. message) end
end
function Public.to_admin_raw(message, locale)
    if locale then print(message, discord_admin_raw_tag) else output_data(discord_admin_raw_tag .. message) end
end
function Public.to_discord_embed(message, locale)
    if locale then print(message, discord_embed_tag) else output_data(discord_embed_tag .. message) end
end
function Public.to_discord_embed_raw(message, locale)
    if locale then print(message, discord_embed_raw_tag) else output_data(discord_embed_raw_tag .. message) end
end
function Public.to_discord_embed_parsed(message)
    if type(message) ~= 'table' then
        return error('to_discord_embed_parsed - message must be a table', 2)
    end
    if not message.title then
        return error('to_discord_embed_parsed - message must have a title', 2)
    end
    if not message.description then
        return error('to_discord_embed_parsed - message must have a description', 2)
    end
    output_data(discord_embed_parsed_tag .. helpers.table_to_json(message))
end
function Public.to_admin_embed(message, locale)
    if locale then print(message, discord_admin_embed_tag) else output_data(discord_admin_embed_tag .. message) end
end
function Public.to_admin_embed_raw(message, locale)
    if locale then print(message, discord_admin_embed_raw_tag) else output_data(discord_admin_embed_raw_tag .. message) end
end
function Public.to_discord_antigrief_bold(message, locale)
    if locale then print(message, discord_antigrief_bold_tag) else output_data(discord_antigrief_bold_tag .. message) end
end
function Public.to_discord_antigrief_embed(message, locale)
    if locale then print(message, discord_antigrief_embed_tag) else output_data(discord_antigrief_embed_tag .. message) end
end
function Public.to_discord_antigrief_embed_parsed(message)
    if type(message) ~= 'table' then
        return error('to_discord_antigrief_embed_parsed - message must be a table', 2)
    end
    if not message.title then
        return error('to_discord_antigrief_embed_parsed - message must have a title', 2)
    end
    if not message.description then
        return error('to_discord_antigrief_embed_parsed - message must have a description', 2)
    end
    output_data(discord_antigrief_embed_parsed_tag .. helpers.table_to_json(message))
end
local function double_escape(str)
    if not str then return '' end
    return str:gsub('\\', '\\\\\\\\'):gsub('"', '\\\\\\"'):gsub('\n', '\\\\n')
end
local function single_escape(str)
    if not str then return '' end
    return str:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n')
end
local function send_try_get_data(data_set, key, callback_token)
    data_set = single_escape(data_set)
    key = single_escape(key)
    output_data(concat { data_get_tag, callback_token, ' {', 'data_set:"', data_set, '",key:"', key, '"}' })
end
local function send_try_get_data_and_print(data_set, key, to_print, callback_token)
    data_set = single_escape(data_set)
    key = single_escape(key)
    to_print = single_escape(to_print)
    output_data(concat { data_get_and_print_tag, callback_token, ' {', 'data_set:"', data_set, '",key:"', key, '",to_print:"', to_print, '"}' })
end
local function log_antigrief_data(category, action, severity, player_name)
    category = single_escape(category)
    action = single_escape(action)
    severity = single_escape(severity or 'info')
    if player_name then
        player_name = single_escape(player_name)
        output_data(concat { antigrief_tag, '{', 'category:"', category, '",severity:"', severity, '",player:"', player_name, '",action:"', action, '"}' })
    else
        output_data(concat { antigrief_tag, '{', 'category:"', category, '",severity:"', severity, '",action:"', action, '"}' })
    end
end
local function notify_jail_change(name, jailed, reason)
    name = single_escape(name)
    if jailed then
        reason = single_escape(reason or '')
        output_data(concat { jail_tag, '{', 'name:"', name, '",reason:"', reason, '"}' })
    else
        output_data(concat { unjail_tag, '{', 'name:"', name, '"}' })
    end
end
local function notify_trust_change(name, trusted, source)
    name = single_escape(name)
    if trusted then
        source = single_escape(source or 'auto')
        output_data(concat { trust_tag, '{', 'name:"', name, '",source:"', source, '"}' })
    else
        output_data(concat { untrust_tag, '{', 'name:"', name, '"}' })
    end
end
local function validate_arguments(data_set, key, callback_token)
    if type(data_set) ~= 'string' then error('data_set must be a string', 3) end
    if type(key) ~= 'string' then error('key must be a string', 3) end
    if type(callback_token) ~= 'number' then error('callback_token must be a number', 3) end
end
function Public.set_data(data_set, key, value)
    if type(data_set) ~= 'string' then error('data_set must be a string', 2) end
    if type(key) ~= 'string' then error('key must be a string', 2) end
    data_set = single_escape(data_set)
    key = single_escape(key)
    local message
    local vt = type(value)
    if vt == 'nil' then
        message = concat({ data_set_tag, '{data_set:"', data_set, '",key:"', key, '"}' })
    elseif vt == 'string' then
        value = double_escape(value)
        message = concat({ data_set_tag, '{data_set:"', data_set, '",key:"', key, '",value:"\\"', value, '\\""}' })
    elseif vt == 'number' then
        message = concat({ data_set_tag, '{data_set:"', data_set, '",key:"', key, '",value:"', value, '"}' })
    elseif vt == 'boolean' then
        message = concat({ data_set_tag, '{data_set:"', data_set, '",key:"', key, '",value:"', tostring(value), '"}' })
    elseif vt == 'function' then
        error('value cannot be a function', 2)
    else 
        value = helpers.table_to_json(value)
        value = value:gsub('\\', '\\\\'):gsub("'", "\\'")
        message = concat({ data_set_tag, '{data_set:"', data_set, '",key:"', key, "\",value:'", value, "'}" })
    end
    output_data(message)
end
function Public.try_get_data(data_set, key, callback_token)
    validate_arguments(data_set, key, callback_token)
    send_try_get_data(data_set, key, callback_token)
end
function Public.try_get_data_and_print(data_set, key, to_print, callback_token)
    validate_arguments(data_set, key, callback_token)
    send_try_get_data_and_print(data_set, key, to_print, callback_token)
end
function Public.try_get_all_data(data_set, callback_token)
    if type(data_set) ~= 'string' then error('data_set must be a string', 2) end
    if type(callback_token) ~= 'number' then error('callback_token must be a number', 2) end
    data_set = single_escape(data_set)
    output_data(concat { data_get_all_tag, callback_token, ' {', 'data_set:"', data_set, '"}' })
end
local function data_set_changed(data)
    local handlers = data_set_handlers[data.data_set]
    if handlers == nil then return end
    if _DEBUG then
        for _, handler in ipairs(handlers) do
            local success, err = pcall(handler, data)
            if not success then
                log(err); error(err, 2)
            end
        end
    else
        for _, handler in ipairs(handlers) do
            local success, err = pcall(handler, data)
            if not success then log(err) end
        end
    end
end
function Public.on_data_set_changed(data_set, handler)
    if _LIFECYCLE == 8 then
        error('cannot call during runtime', 2)
    end
    if type(data_set) ~= 'string' then
        error('data_set must be a string', 2)
    end
    local handlers = data_set_handlers[data_set]
    if handlers == nil then
        data_set_handlers[data_set] = { handler }
    else
        handlers[#handlers + 1] = handler
    end
end
Public.raise_data_set = data_set_changed
Public.log_antigrief_data = log_antigrief_data
Public.notify_jail_change = notify_jail_change
Public.notify_trust_change = notify_trust_change
Public.output_data = output_data
local function command_handler(command_name, callback, ...)
    local chunk
    local success, err
    if type(callback) == 'function' then
        success, err = pcall(callback, ...)
    else
        chunk, err = load(callback)
        if not chunk then
            return false, string.format('[%s] load failed: %s\nCallback: %s', command_name, err, callback)
        end
        success, err = pcall(chunk, ...)
    end
    if not success then
        err = string.format('[%s] Runtime error: %s\nCallback: %s', command_name, tostring(err), callback)
    end
    return success, err
end
commands.add_command(
    'fpc',
    '<callback> - Evaluate command (used by comfy_adapter plugin via RCON)',
    function(cmd)
        local player = game.player
        if player then return end 
        local callback = cmd.parameter
        if not callback then return end
        if not string.find(callback, '%s') and not string.find(callback, 'return') then
            callback = 'return ' .. callback
        end
        local success, err = command_handler('fpc', callback)
        if not success and type(err) == 'string' then
            local _end = string.find(err, 'stack traceback')
            if _end then err = string.sub(err, 1, _end - 2) end
        end
        if err and storage.debug_cc then
            output_data(err)
        end
    end
)
return Public
