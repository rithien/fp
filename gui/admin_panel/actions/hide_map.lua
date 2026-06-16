local AdminPanel = require 'gui.admin_panel'
local ChunkJobs = require 'lib.chunk_jobs'
ChunkJobs.register('hide_map',
    function(surface, force, cx, cy)
        if force and force.valid then
            force.unchart_chunk({ x = cx, y = cy }, surface)
        end
    end,
    function(_surface, _force, player, job)
        if player and player.valid then
            player.print({ 'fp-admin.hide-map-result', job.total })
        end
    end
)
AdminPanel.register_action({
    id = 'hide_map',
    caption = { 'fp-admin.hide-map-caption' },
    tooltip = { 'fp-admin.hide-map-tooltip' },
    on_click = function(player)
        local queued, total = ChunkJobs.enqueue(player, 'hide_map')
        if not queued then
            player.print({ 'fp-admin.hide-map-busy' })
        else
            player.print({ 'fp-admin.hide-map-started', total })
        end
    end
})
