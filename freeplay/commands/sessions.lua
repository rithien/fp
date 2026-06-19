local Commands = require 'lib.commands'
local Session = require 'lib.sessions'
local function format_threshold(ticks)
    local minutes = ticks / 3600
    if minutes >= 60 then
        return { 'fp-commands.threshold-minutes-hours', math.floor(minutes), string.format('%.2f', minutes / 60) }
    end
    return { 'fp-commands.threshold-minutes', math.floor(minutes) }
end
Commands.new('sessionsthreshold', { 'fp-commands.sessionsthreshold-help' })
    :require_admin()
    :add_parameter('minutes', true, 'number')
    :callback(function(cmd, minutes)
        local previous_ticks = Session.get_trusted_threshold()
        local new_ticks
        if not minutes or minutes <= 0 then
            new_ticks = Session.set_trusted_threshold(nil) 
        else
            new_ticks = Session.set_trusted_threshold(math.floor(minutes * 3600))
        end
        local msg = { 'fp-commands.sessionsthreshold-result',
            format_threshold(previous_ticks), format_threshold(new_ticks) }
        game.print(msg, { color = { r = 1, g = 1, b = 0 } })
        log(msg)
    end)
Commands.new('sessionsstatus', { 'fp-commands.sessionsstatus-help' })
    :require_admin()
    :add_parameter('player', true, 'player')
    :callback(function(cmd, target)
        local function reply(msg)
            if cmd.player_index then
                local p = game.get_player(cmd.player_index)
                if p and p.valid then p.print(msg) end
            else
                log(msg)
            end
        end
        if target then
            local name = target.name
            local online_time = target.online_time
            local sessions_ticks = (storage.sessions and storage.sessions[name]) or 0
            local online_track = (storage.online_track and storage.online_track[name]) or 0
            local trusted = (storage.trusted and storage.trusted[name]) or false
            local manually_untrusted = (storage.manually_untrusted and storage.manually_untrusted[name]) or false
            reply({ 'fp-commands.sessionsstatus-player',
                name, online_time, string.format('%.1f', online_time / 3600),
                sessions_ticks, string.format('%.1f', sessions_ticks / 3600),
                online_track, tostring(trusted), tostring(manually_untrusted)
            })
            return
        end
        local threshold = Session.get_trusted_threshold()
        local sessions_table = storage.sessions or {}
        local trusted_table = storage.trusted or {}
        local online_track_table = storage.online_track or {}
        local sessions_count, trusted_count, online_track_count = 0, 0, 0
        for _ in pairs(sessions_table) do sessions_count = sessions_count + 1 end
        for _, v in pairs(trusted_table) do if v then trusted_count = trusted_count + 1 end end
        for _ in pairs(online_track_table) do online_track_count = online_track_count + 1 end
        reply({ 'fp-commands.sessionsstatus-global',
            format_threshold(threshold), sessions_count, trusted_count, online_track_count
        })
    end)
