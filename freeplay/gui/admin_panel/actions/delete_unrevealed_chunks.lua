local AdminPanel = require 'gui.admin_panel'
local ChunkJobs = require 'lib.chunk_jobs'
ChunkJobs.register('delete_unrevealed_chunks',
    function(surface, _force, cx, cy)
        surface.delete_chunk({ x = cx, y = cy })
    end,
    function(_surface, _force, player, job)
        if player and player.valid then
            player.print({ 'fp-admin.delete-unrevealed-chunks-result', job.total })
        end
    end
)
AdminPanel.register_action({
    id = 'delete_unrevealed_chunks',
    caption = { 'fp-admin.delete-unrevealed-chunks-caption' },
    tooltip = { 'fp-admin.delete-unrevealed-chunks-tooltip' },
    on_click = function(player)
        local surface = player.surface
        local force = player.force
        force.cancel_charting(surface)
        local queued, total = ChunkJobs.enqueue(player, 'delete_unrevealed_chunks', {
            filter = function(cx, cy)
                return not force.is_chunk_charted(surface, { x = cx, y = cy })
            end,
        })
        if not queued then
            player.print({ 'fp-admin.delete-unrevealed-chunks-busy' })
        else
            player.print({ 'fp-admin.delete-unrevealed-chunks-started', total })
        end
    end
})
