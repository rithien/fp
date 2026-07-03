local AdminPanel = require 'gui.admin_panel'
local ChunkJobs = require 'lib.chunk_jobs'
ChunkJobs.register('delete_unrevealed_chunks',
    function(surface, _force, cx, cy)
        surface.delete_chunk({ x = cx, y = cy })
    end,
    function(_surface, _force, player, job)
        if player and player.valid then
            player.print({ 'fp-admin.delete-unrevealed-chunks-result', job.processed_count or 0 })
        end
    end,
    function(surface, force, cx, cy)
        return not force.is_chunk_charted(surface, { x = cx, y = cy })
    end
)
AdminPanel.register_action({
    id = 'delete_unrevealed_chunks',
    caption = { 'fp-admin.delete-unrevealed-chunks-caption' },
    tooltip = { 'fp-admin.delete-unrevealed-chunks-tooltip' },
    sprite = 'file/img/gui/admin/delete_unrevealed_chunks.png',
    sprite_fallback = 'item/deconstruction-planner',
    caption_short = { 'fp-admin.delete-unrevealed-chunks-short' },
    on_click = function(player)
        local surface = player.surface
        local force = player.force
        force.cancel_charting(surface)
        local queued, total = ChunkJobs.enqueue(player, 'delete_unrevealed_chunks')
        if not queued then
            player.print({ 'fp-admin.delete-unrevealed-chunks-busy' })
        else
            player.print({ 'fp-admin.delete-unrevealed-chunks-started', total })
        end
    end
})
