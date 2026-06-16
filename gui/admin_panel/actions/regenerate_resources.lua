local AdminPanel = require 'gui.admin_panel'
local ChunkJobs = require 'lib.chunk_jobs'
local SIZE = ChunkJobs.CHUNK_SIZE
local function yields_fluid(prototype)
    local mp = prototype and prototype.mineable_properties
    if not (mp and mp.products) then
        return false
    end
    for _, p in ipairs(mp.products) do
        if p.type == 'fluid' then
            return true
        end
    end
    return false
end
ChunkJobs.register('regenerate_resources',
    function(surface, _force, cx, cy)
        local area = { { cx * SIZE, cy * SIZE }, { cx * SIZE + SIZE, cy * SIZE + SIZE } }
        for _, e in pairs(surface.find_entities_filtered({ type = 'resource', area = area })) do
            if e.valid then
                local proto = e.prototype
                if proto.infinite_resource then
                    e.amount = e.initial_amount                 
                elseif yields_fluid(proto) then
                else
                    e.destroy()                                 
                end
            end
        end
    end,
    function(surface, _force, player, _job)
        local solid_finite = {}
        for resource, prototype in pairs(prototypes.get_entity_filtered({ { filter = 'type', type = 'resource' } })) do
            if not prototype.infinite_resource and not yields_fluid(prototype) then
                solid_finite[#solid_finite + 1] = resource
            end
        end
        surface.regenerate_entity(solid_finite)
        local queued = player and player.valid and ChunkJobs.enqueue(player, 'regenerate_resources_drills')
        if not queued then
            for _, e in pairs(surface.find_entities_filtered({ type = 'mining-drill' })) do
                if e.valid then e.update_connections() end
            end
            if player and player.valid then
                player.print({ 'fp-admin.regenerate-resources-result', surface.name })
            end
        end
    end
)
ChunkJobs.register('regenerate_resources_drills',
    function(surface, _force, cx, cy)
        local area = { { cx * SIZE, cy * SIZE }, { cx * SIZE + SIZE, cy * SIZE + SIZE } }
        for _, e in pairs(surface.find_entities_filtered({ type = 'mining-drill', area = area })) do
            if e.valid then e.update_connections() end
        end
    end,
    function(surface, _force, player, _job)
        if player and player.valid then
            player.print({ 'fp-admin.regenerate-resources-result', surface.name })
        end
    end
)
AdminPanel.register_action({
    id = 'regenerate_resources',
    caption = { 'fp-admin.regenerate-resources-caption' },
    tooltip = { 'fp-admin.regenerate-resources-tooltip' },
    on_click = function(player)
        local queued, total = ChunkJobs.enqueue(player, 'regenerate_resources')
        if not queued then
            player.print({ 'fp-admin.regenerate-resources-busy' })
        else
            player.print({ 'fp-admin.regenerate-resources-started', total })
        end
    end
})
