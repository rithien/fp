local Commands = require 'lib.commands'
Commands.new('fp', { 'fp-commands.fp-help' })
    :server_only()
    :callback(function(cmd)
        local text = cmd.parameter
        if not text or text == '' then return end
        game.print(text)
    end)
