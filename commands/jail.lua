local Commands = require 'lib.commands'
local Jail = require 'lib.jail'
local Constants = require 'constants'
local AUDIT = Constants.audit
Commands.new('jail', { 'fp-commands.jail-help' })
    :require_admin()
    :add_parameter('name', false, 'string')
    :callback(function(cmd, name)
        local reason = cmd.parameter and cmd.parameter:gsub('^%s*%S+%s*', '') or ''
        local by = cmd.player_index and game.get_player(cmd.player_index)
        local source = (by and by.valid and by.name) or 'global list'
        if reason == '' then
            reason = string.format(AUDIT.jailed_by, source)
        end
        Jail.jail_player(name, reason, source)
    end)
Commands.new('unjail', { 'fp-commands.unjail-help' })
    :require_admin()
    :add_parameter('name', false, 'string')
    :callback(function(_, name)
        Jail.unjail_player(name)
    end)
