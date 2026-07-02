local Token = {}
local tokens = {}
local counter = 200
local alternative_counter = 20000
local custom_prefix = 'comfy_'
function Token.register(var, sarg)
    if _LIFECYCLE == 8 then
        error('Calling Token.register after on_init() or on_load() has run is a desync risk.', 2)
    end
    if sarg then
        alternative_counter = alternative_counter + 1
        tokens[alternative_counter] = var
        return alternative_counter
    end
    counter = counter + 1
    tokens[counter] = var
    return counter
end
local named_tokens = {}
function Token.register_named(name, var)
    if _LIFECYCLE == 8 then
        error('Calling Token.register_named after on_init() or on_load() has run is a desync risk.', 2)
    end
    if type(name) ~= 'string' then
        error('Token.register_named: name must be a string', 2)
    end
    if named_tokens[name] ~= nil then
        error('Token.register_named: duplicate name "' .. name .. '"', 2)
    end
    named_tokens[name] = var
    return name
end
function Token.get(token_id)
    if type(token_id) == 'string' then
        return named_tokens[token_id]
    end
    return tokens[token_id]
end
local uid_counter = 100
function Token.uid(prefix)
    uid_counter = uid_counter + 1
    return prefix and prefix .. '_' .. uid_counter or custom_prefix .. uid_counter
end
return Token
