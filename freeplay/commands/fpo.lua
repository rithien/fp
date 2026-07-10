local Commands = require 'lib.commands'
local Sink = require 'lib.translation_sink'
Commands.new('fpo', { 'fp-commands.fpo-help' })
    :server_only()
    :callback(function(cmd)
        local raw = cmd.parameter
        if not raw or raw == '' then return end
        local ok, payload = pcall(helpers.json_to_table, raw)
        if not ok or type(payload) ~= 'table' then return end
        Sink.dispatch(payload)
    end)
