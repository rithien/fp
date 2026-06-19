local Commands = require 'lib.commands'
local Welcome = require 'gui.welcome_screen'
Commands.new('news', { 'fp-commands.news-help' })
    :callback(function(cmd)
        if cmd.player_index then
            local player = game.get_player(cmd.player_index)
            if not player or not player.valid then return end
            Welcome.show(player)
            player.print({ 'fp-welcome.news-reset-self' })
        else
            Welcome.reset_all()
            log('[news] welcome status reset for all players (RCON)')
        end
    end)
