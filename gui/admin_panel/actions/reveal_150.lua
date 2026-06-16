local AdminPanel = require 'gui.admin_panel'
local RADIUS = 150
AdminPanel.register_action({
    id = 'reveal_150',
    caption = { 'fp-admin.reveal-150-caption' },
    tooltip = { 'fp-admin.reveal-150-tooltip' },
    on_click = function(player)
        local pos = player.position
        local surface = player.surface
        local area = {
            { pos.x - RADIUS, pos.y - RADIUS },
            { pos.x + RADIUS, pos.y + RADIUS }
        }
        player.force.chart(surface, area)
        player.print({ 'fp-admin.reveal-result', RADIUS })
    end
})
