local Event = require 'lib.event'
local Server = require 'lib.server'
local de = defines.events
local TAG = '[FP-TRANSLATE]'
local Public = {}
local function on_console_chat(event)
    if not event.player_index then return end  
    local speaker = game.get_player(event.player_index)
    if not speaker or not speaker.valid then return end
    local message = event.message
    if type(message) ~= 'string' or message == '' then return end
    local seen, locales, count = {}, {}, 0
    for _, p in pairs(game.connected_players) do
        if p.valid then
            local loc = p.locale
            if type(loc) == 'string' and loc ~= '' and not seen[loc] then
                seen[loc] = true
                count = count + 1
                locales[count] = loc
            end
        end
    end
    if count < 2 then return end  
    Server.output_data(TAG .. helpers.table_to_json({
        speaker = speaker.name,
        text = message,
        locales = locales,
    }))
end
Public.on_console_chat = on_console_chat
Event.add(de.on_console_chat, on_console_chat)
return Public
