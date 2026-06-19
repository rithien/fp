local AdminPanel = require 'gui.admin_panel'
local ChunkJobs = require 'lib.chunk_jobs'
local SIZE = ChunkJobs.CHUNK_SIZE
ChunkJobs.register('destroy_decoratives',
    function(surface, _force, cx, cy)
        surface.destroy_decoratives({
            area = { { cx * SIZE, cy * SIZE }, { cx * SIZE + SIZE, cy * SIZE + SIZE } },
        })
    end,
    function(surface, _force, player, job)
        if player and player.valid then
            player.print({ 'fp-admin.destroy-decoratives-result', surface.name, job.total })
        end
    end
)
AdminPanel.register_action({
    id = 'destroy_decoratives',
    caption = { 'fp-admin.destroy-decoratives-caption' },
    tooltip = { 'fp-admin.destroy-decoratives-tooltip' },
    on_click = function(player)
        local queued, total = ChunkJobs.enqueue(player, 'destroy_decoratives')
        if not queued then
            player.print({ 'fp-admin.destroy-decoratives-busy' })
        else
            player.print({ 'fp-admin.destroy-decoratives-started', total })
        end
    end
})
