local Event = require 'lib.event'
local Server = require 'lib.server'
local PlayerLocale = require 'lib.player_locale'
local de = defines.events
local TAG = '[FP-TRANSLATE]'
local Public = {}
function Public.emit(speaker_name, text, locales)
    Server.output_data(TAG .. helpers.table_to_json({
        speaker = speaker_name,
        text = text,
        locales = locales,
    }))
end
local function on_console_chat(event)
    if not event.player_index then return end  
    local speaker = game.get_player(event.player_index)
    if not speaker or not speaker.valid then return end
    local message = event.message
    if type(message) ~= 'string' or message == '' then return end
    local seen, locales, count = {}, {}, 0
    for _, p in pairs(game.connected_players) do
        if p.valid then
            local loc = PlayerLocale.effective(p)
            if type(loc) == 'string' and loc ~= '' and not seen[loc] then
                seen[loc] = true
                count = count + 1
                locales[count] = loc
            end
        end
    end
    if count == 0 then return end  
    Public.emit(speaker.name, message, locales)
end
Public.on_console_chat = on_console_chat
Event.add(de.on_console_chat, on_console_chat)
return Public
