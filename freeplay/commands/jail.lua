local Commands = require 'lib.commands'
local Jail = require 'lib.jail'
local Constants = require 'constants'
local AUDIT = Constants.audit
local function reply(cmd, msg)
    local p = cmd.player_index and game.get_player(cmd.player_index)
    if p and p.valid then
        p.print(msg)
    else
        log(msg)
    end
end
Commands.new('jail', { 'fp-commands.jail-help' })
    :require_admin()
    :add_parameter('name', false, 'string')
    :callback(function(cmd, name)
        if not game.get_player(name) then
            reply(cmd, { 'fp-commands.jail-unknown-player', name })
            return
        end
        local reason = cmd.parameter and cmd.parameter:gsub('^%s*%S+%s*', '') or ''
        local by = cmd.player_index and game.get_player(cmd.player_index)
        local source = (by and by.valid and by.name) or 'global list'
        if reason == '' then
            reason = string.format(AUDIT.jailed_by, source)
        end
        if not Jail.jail_player(name, reason, source) then
            reply(cmd, { 'fp-commands.jail-already-jailed', name }) 
        end
    end)
Commands.new('unjail', { 'fp-commands.unjail-help' })
    :require_admin()
    :add_parameter('name', false, 'string')
    :callback(function(cmd, name)
        if not Jail.unjail_player(name) then
            reply(cmd, { 'fp-commands.unjail-not-jailed', name })
        end
    end)
