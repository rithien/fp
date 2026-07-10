local AdminPanel = require 'gui.admin_panel'
local ChunkJobs = require 'lib.chunk_jobs'
local CHUNK = ChunkJobs.CHUNK_SIZE
local function player_forces()
    local out = {}
    for _, f in pairs(game.forces) do
        if f.name ~= 'enemy' and f.name ~= 'neutral' then
            out[#out + 1] = f
        end
    end
    return out
end
ChunkJobs.register('delete_unrevealed_chunks',
    function(surface, _force, cx, cy)
        surface.delete_chunk({ x = cx, y = cy })
    end,
    function(_surface, _force, player, job)
        if player and player.valid then
            player.print({ 'fp-admin.delete-unrevealed-chunks-result', job.processed_count or 0 })
        end
    end,
    function(surface, _force, cx, cy)
        for _, p in pairs(game.connected_players) do
            if p.physical_surface_index == surface.index then
                local pos = p.physical_position
                if math.floor(pos.x / CHUNK) == cx and math.floor(pos.y / CHUNK) == cy then
                    return false
                end
            end
        end
        local forces = player_forces()
        local chunk_pos = { x = cx, y = cy }
        for _, f in pairs(forces) do
            if f.is_chunk_charted(surface, chunk_pos) then return false end
        end
        local area = { { cx * CHUNK, cy * CHUNK }, { (cx + 1) * CHUNK, (cy + 1) * CHUNK } }
        return surface.count_entities_filtered({ area = area, force = forces, limit = 1 }) == 0
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
        for _, f in pairs(player_forces()) do
            f.cancel_charting(surface)
        end
        local queued, total = ChunkJobs.enqueue(player, 'delete_unrevealed_chunks')
        if not queued then
            player.print({ 'fp-admin.delete-unrevealed-chunks-busy' })
        else
            player.print({ 'fp-admin.delete-unrevealed-chunks-started', total })
        end
    end
})
