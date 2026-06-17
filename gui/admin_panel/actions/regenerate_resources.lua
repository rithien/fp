local AdminPanel = require 'gui.admin_panel'
local ChunkJobs = require 'lib.chunk_jobs'
local DebugLog = require 'lib.debug_log'
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
local function should_regenerate(prototype)
    return not prototype.infinite_resource
        and prototype.autoplace_specification ~= nil
        and not yields_fluid(prototype)
end
ChunkJobs.register('regenerate_resources',
    function(surface, _force, cx, cy, stats)
        local area = { { cx * SIZE, cy * SIZE }, { cx * SIZE + SIZE, cy * SIZE + SIZE } }
        for _, e in pairs(surface.find_entities_filtered({ type = 'resource', area = area })) do
            if e.valid then
                local proto = e.prototype
                if proto.infinite_resource then
                    e.amount = e.initial_amount                 
                    if stats then stats.reset = stats.reset + 1 end
                elseif should_regenerate(proto) then
                    e.destroy()                                 
                    if stats then stats.destroyed = stats.destroyed + 1 end
                elseif yields_fluid(proto) then
                    if stats then stats.skipped_fluid = stats.skipped_fluid + 1 end          
                else
                    if stats then stats.skipped_no_autoplace = stats.skipped_no_autoplace + 1 end 
                end
            end
        end
    end,
    function(surface, _force, player, job)
        local solid_finite = {}
        for resource, prototype in pairs(prototypes.get_entity_filtered({ { filter = 'type', type = 'resource' } })) do
            if should_regenerate(prototype) then
                solid_finite[#solid_finite + 1] = resource
            end
        end
        local ok, err = pcall(function() surface.regenerate_entity(solid_finite) end)
        local stats = job and job.extra
        DebugLog.log('[regenerate_resources] %s: reset_infinite=%d destroyed_solid=%d skipped_fluid=%d skipped_no_autoplace=%d → regenerate(%s) %d prototypów: %s',
            surface.name,
            stats and stats.reset or -1,
            stats and stats.destroyed or -1,
            stats and stats.skipped_fluid or -1,
            stats and stats.skipped_no_autoplace or -1,
            ok and 'OK' or ('BŁĄD: ' .. tostring(err)),
            #solid_finite,
            #solid_finite > 0 and table.concat(solid_finite, ', ') or '(brak)')
        if DebugLog.is_enabled() then 
            DebugLog.log('[regenerate_resources] %s: resource entities PO regenerate = %d',
                surface.name, surface.count_entities_filtered({ type = 'resource' }))
        end
        local queued = player and player.valid
            and ChunkJobs.enqueue(player, 'regenerate_resources_drills', { extra = { drills = 0 } })
        if not queued then
            local n = 0
            for _, e in pairs(surface.find_entities_filtered({ type = 'mining-drill' })) do
                if e.valid then
                    e.update_connections()
                    n = n + 1
                end
            end
            DebugLog.log('[regenerate_resources] %s: fallback update_connections na %d drillach', surface.name, n)
            if player and player.valid then
                player.print({ 'fp-admin.regenerate-resources-result', surface.name })
            end
        end
    end
)
ChunkJobs.register('regenerate_resources_drills',
    function(surface, _force, cx, cy, stats)
        local area = { { cx * SIZE, cy * SIZE }, { cx * SIZE + SIZE, cy * SIZE + SIZE } }
        for _, e in pairs(surface.find_entities_filtered({ type = 'mining-drill', area = area })) do
            if e.valid then
                e.update_connections()
                if stats then stats.drills = stats.drills + 1 end
            end
        end
    end,
    function(surface, _force, player, job)
        local stats = job and job.extra
        DebugLog.log('[regenerate_resources] %s: update_connections na %d drillach',
            surface.name, stats and stats.drills or -1)
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
        local queued, total = ChunkJobs.enqueue(player, 'regenerate_resources', {
            extra = { reset = 0, destroyed = 0, skipped_fluid = 0, skipped_no_autoplace = 0 },
        })
        if not queued then
            player.print({ 'fp-admin.regenerate-resources-busy' })
        else
            DebugLog.log('[regenerate_resources] %s: zakolejkowano %d chunków', player.surface.name, total)
            player.print({ 'fp-admin.regenerate-resources-started', total })
        end
    end
})
