local AdminPanel = require 'gui.admin_panel'
local ChunkJobs = require 'lib.chunk_jobs'
local CHUNK_RADIUS = 32  
ChunkJobs.register('delete_chunks',
    function(surface, _force, cx, cy)
        surface.delete_chunk({ x = cx, y = cy })
    end,
    function(_surface, _force, player, job)
        if player and player.valid then
            player.print({ 'fp-admin.delete-chunks-result', job.total, CHUNK_RADIUS })
        end
    end
)
AdminPanel.register_action({
    id = 'delete_chunks',
    caption = { 'fp-admin.delete-chunks-caption' },
    tooltip = { 'fp-admin.delete-chunks-tooltip' },
    on_click = function(player)
        local surface = player.surface
        player.force.cancel_charting(surface)
        local queued, total = ChunkJobs.enqueue(player, 'delete_chunks', {
            filter = function(cx, cy)
                return cx < -CHUNK_RADIUS or cx > CHUNK_RADIUS
                    or cy < -CHUNK_RADIUS or cy > CHUNK_RADIUS
            end,
        })
        if not queued then
            player.print({ 'fp-admin.delete-chunks-busy' })
        else
            player.print({ 'fp-admin.delete-chunks-started', total })
        end
    end
})
