local Commands = require 'lib.commands'
local Session = require 'lib.sessions'
local Event = require 'lib.event'
Commands.new('trust', { 'fp-commands.trust-help' })
    :require_admin()
    :add_parameter('player', false, 'player')
    :callback(function(cmd, target)
        Event.raise(Session.events.on_player_trusted, { player_index = target.index })
        local actor_name = 'server'
        if cmd.player_index then
            local actor = game.get_player(cmd.player_index)
            if actor and actor.valid then
                actor_name = actor.name
                actor.print({ 'fp-commands.trust-now', target.name })
            end
        end
        log('[trust] ' .. target.name .. ' trusted by ' .. actor_name)
    end)
Commands.new('untrust', { 'fp-commands.untrust-help' })
    :require_admin()
    :add_parameter('player', false, 'player')
    :callback(function(cmd, target)
        Event.raise(Session.events.on_player_untrusted, { player_index = target.index })
        local actor_name = 'server'
        if cmd.player_index then
            local actor = game.get_player(cmd.player_index)
            if actor and actor.valid then
                actor_name = actor.name
                actor.print({ 'fp-commands.untrust-now', target.name })
            end
        end
        log('[untrust] ' .. target.name .. ' untrusted by ' .. actor_name)
    end)
