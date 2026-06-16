local AdminPanel = require 'gui.admin_panel'
local RADIUS = 300
AdminPanel.register_action({
    id = 'reveal_300',
    caption = { 'fp-admin.reveal-300-caption' },
    tooltip = { 'fp-admin.reveal-300-tooltip' },
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
