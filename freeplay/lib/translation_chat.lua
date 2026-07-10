local Public = {}
local MODE_CHOICES = {
    { key = 'off',        caption = { 'fp-admin.chat-mode-off' } },
    { key = 'universal',  caption = { 'fp-admin.chat-mode-universal' } },
    { key = 'per_player', caption = { 'fp-admin.chat-mode-per-player' } },
}
local DEFAULT_MODE = 'universal'  
local function is_valid_mode(key)
    for _, c in ipairs(MODE_CHOICES) do
        if c.key == key then return true end
    end
    return false
end
local function ensure_storage()
    if not storage.translation_chat then
        storage.translation_chat = {}
        local bag = storage.toggle_defaults
        local old = bag and bag.translate_chat
        if old ~= nil then
            storage.translation_chat.mode = old and 'universal' or 'off'
            bag.translate_chat = nil  
        else
            storage.translation_chat.mode = DEFAULT_MODE
        end
    end
end
function Public.get_mode_choices()
    local out = {}
    for i, c in ipairs(MODE_CHOICES) do
        out[i] = { key = c.key, caption = c.caption }
    end
    return out
end
function Public.get_mode()
    ensure_storage()
    local m = storage.translation_chat.mode
    if type(m) == 'string' and is_valid_mode(m) then return m end
    return DEFAULT_MODE
end
function Public.set_mode(key)
    if type(key) ~= 'string' or not is_valid_mode(key) then return end
    ensure_storage()
    storage.translation_chat.mode = key
end
function Public.show_per_player(payload)
    local speaker = payload.speaker
    if type(speaker) ~= 'string' or speaker == '' then return end
    local t = type(payload.t) == 'table' and payload.t or nil
    if not t then return end
    for _, p in pairs(game.connected_players) do
        if p.valid and p.name ~= speaker then
            local variant = t[p.locale]
            if type(variant) == 'string' and variant ~= '' then
                p.print(speaker .. ': ' .. variant)
            end
        end
    end
end
return Public
