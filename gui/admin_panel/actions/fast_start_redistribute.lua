local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local FastStart = require 'gui.admin_panel.toggles.fast_start'
local FastStartMech = require 'gui.admin_panel.toggles.fast_start_mech'
AdminPanel.register_action({
    id = 'fast_start_redistribute',
    caption = { 'fp-admin.fast-start-redistribute-caption' },
    tooltip = { 'fp-admin.fast-start-redistribute-tooltip' },
    on_click = function(player)
        local active_caption, force_give
        if Config.is_enabled('fast_start') then
            active_caption = { 'fp-admin.fast-start-caption' }
            force_give = FastStart.force_give_to_online_unarmored
        elseif Config.is_enabled('fast_start_mech') then
            active_caption = { 'fp-admin.fast-start-mech-caption' }
            force_give = FastStartMech.force_give_to_online_unarmored
        else
            player.print({ 'fp-admin.fast-start-redistribute-none' })
            return
        end
        local count = force_give()
        if count > 0 then
            game.print(
                { 'fp-admin.fast-start-redistribute-broadcast', active_caption, player.name, count },
                { color = { r = 1, g = 1, b = 0 } }
            )
        else
            player.print({ 'fp-admin.fast-start-redistribute-empty', active_caption })
        end
    end
})
