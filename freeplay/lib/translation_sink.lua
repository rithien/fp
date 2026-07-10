local Config = require 'lib.config'
local Overhead = require 'lib.translation_overhead'
local ChatMode = require 'lib.translation_chat'
local Public = {}
function Public.dispatch(payload)
    local mode = ChatMode.get_mode()
    if mode == 'universal' then
        if type(payload.chat) == 'string' and payload.chat ~= '' then
            game.print(payload.chat)
        end
    elseif mode == 'per_player' then
        ChatMode.show_per_player(payload)
    end
    if Config.is_enabled('translate_overhead') and type(payload.speaker) == 'string' then
        Overhead.show(payload)
    end
end
return Public
