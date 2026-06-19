local Commands = require 'lib.commands'
local Config = require 'lib.config'
local Overhead = require 'lib.translation_overhead'
Commands.new('fpo', { 'fp-commands.fpo-help' })
    :server_only()
    :callback(function(cmd)
        local raw = cmd.parameter
        if not raw or raw == '' then return end
        local ok, payload = pcall(helpers.json_to_table, raw)
        if not ok or type(payload) ~= 'table' then return end
        if Config.is_enabled('translate_chat') and type(payload.chat) == 'string' and payload.chat ~= '' then
            game.print(payload.chat)
        end
        if Config.is_enabled('translate_overhead') and type(payload.speaker) == 'string' then
            Overhead.show(payload)
        end
    end)
