local Public = {}
local LANGUAGES = {
    { key = 'pl',    name = 'Polski' },
    { key = 'en',    name = 'English' },
    { key = 'uk',    name = 'Українська' },
    { key = 'ru',    name = 'Русский' },
    { key = 'de',    name = 'Deutsch' },
    { key = 'cs',    name = 'Čeština' },
    { key = 'sk',    name = 'Slovenčina' },
    { key = 'fr',    name = 'Français' },
    { key = 'es-ES', name = 'Español' },
    { key = 'it',    name = 'Italiano' },
    { key = 'pt-BR', name = 'Português (BR)' },
    { key = 'tr',    name = 'Türkçe' },
    { key = 'hu',    name = 'Magyar' },
    { key = 'nl',    name = 'Nederlands' },
    { key = 'zh-CN', name = '简体中文' },
    { key = 'ja',    name = '日本語' },
    { key = 'ko',    name = '한국어' },
}
local function is_valid_key(key)
    for _, l in ipairs(LANGUAGES) do
        if l.key == key then return true end
    end
    return false
end
function Public.get_choices()
    local out = {}
    for i, l in ipairs(LANGUAGES) do
        out[i] = { key = l.key, name = l.name }
    end
    return out
end
function Public.get_override(index)
    local bag = storage.player_locale
    local k = bag and bag[index]
    if type(k) == 'string' and is_valid_key(k) then return k end
    return nil
end
function Public.set_override(index, key)
    if key ~= nil and (type(key) ~= 'string' or not is_valid_key(key)) then return end
    if not storage.player_locale then
        if key == nil then return end
        storage.player_locale = {}
    end
    storage.player_locale[index] = key
end
function Public.effective(player)
    return Public.get_override(player.index) or player.locale
end
return Public
