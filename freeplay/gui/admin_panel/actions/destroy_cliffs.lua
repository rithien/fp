local AdminPanel = require 'gui.admin_panel'
local SIZE = 100  
AdminPanel.register_action({
    id = 'destroy_cliffs',
    caption = { 'fp-admin.destroy-cliffs-caption' },
    tooltip = { 'fp-admin.destroy-cliffs-tooltip' },
    on_click = function(player)
        local surface = player.surface
        local pos = player.position
        local area = {
            { pos.x - SIZE, pos.y - SIZE },
            { pos.x + SIZE, pos.y + SIZE }
        }
        local cliffs = surface.find_entities_filtered({ area = area, type = 'cliff' })
        local count = 0
        for _, e in pairs(cliffs) do
            if e.valid then
                e.destroy()
                count = count + 1
            end
        end
        player.print({ 'fp-admin.destroy-cliffs-result', count })
    end
})
