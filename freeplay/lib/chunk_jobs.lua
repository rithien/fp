local Event = require 'lib.event'
local ChunkJobs = {}
local CHUNK_SIZE = 32
local BATCH_CHUNKS = 48
ChunkJobs.BATCH = BATCH_CHUNKS
local processors = {}
local finalizers = {}
local filters = {}
function ChunkJobs.register(kind, process_fn, finalize_fn, filter_fn)
    processors[kind] = process_fn
    finalizers[kind] = finalize_fn
    filters[kind] = filter_fn
end
local function ensure_init()
    if not storage.chunk_jobs then storage.chunk_jobs = {} end
end
local function already_queued(kind, surface_index)
    for _, job in ipairs(storage.chunk_jobs) do
        if job.kind == kind and job.surface_index == surface_index then
            return true
        end
    end
    return false
end
function ChunkJobs.enqueue(player, kind, opts)
    ensure_init()
    if not processors[kind] then
        error('ChunkJobs: nieznany kind "' .. tostring(kind) .. '"', 2)
    end
    opts = opts or {}
    local has_player = player and player.valid
    local surface = opts.surface
    if not (surface and surface.valid) then
        if not has_player then return false, 0 end
        surface = player.surface
    end
    local force = opts.force
    if not (force and force.valid) then
        if not has_player then return false, 0 end
        force = player.force
    end
    if already_queued(kind, surface.index) then
        return false, 0
    end
    local positions = {}
    for chunk in surface.get_chunks() do
        positions[#positions + 1] = { chunk.x, chunk.y }
    end
    storage.chunk_jobs[#storage.chunk_jobs + 1] = {
        kind = kind,
        surface_index = surface.index,
        force_index = force.index,
        player_index = has_player and player.index or nil, 
        positions = positions,
        cursor = 1,
        total = #positions,
        processed_count = 0, 
        extra = opts.extra,
    }
    return true, #positions
end
local function log_error(err)
    log('[chunk_jobs] ' .. debug.traceback(tostring(err)))
end
local function finish_job(job)
    local surface = game.surfaces[job.surface_index]
    local finalize = finalizers[job.kind]
    if surface and surface.valid and finalize then
        local force = game.forces[job.force_index]
        local player = job.player_index and game.get_player(job.player_index) or nil
        xpcall(finalize, log_error, surface, force, player, job)
    end
end
local function on_tick()
    local jobs = storage.chunk_jobs
    if not jobs or #jobs == 0 then return end
    local job = jobs[1]
    local surface = game.surfaces[job.surface_index]
    if not surface or not surface.valid then
        table.remove(jobs, 1)
        return
    end
    local force = game.forces[job.force_index]
    local process = processors[job.kind]
    if not process then 
        table.remove(jobs, 1)
        return
    end
    local positions = job.positions
    local filter = filters[job.kind]
    local scanned = 0
    while job.cursor <= job.total and scanned < BATCH_CHUNKS do
        local pos = positions[job.cursor]
        if pos then
            local include = true
            if filter then
                local ok, res = xpcall(filter, log_error, surface, force, pos[1], pos[2], job.extra)
                include = (ok and res) and true or false
            end
            if include then
                xpcall(process, log_error, surface, force, pos[1], pos[2], job.extra)
                job.processed_count = (job.processed_count or 0) + 1 
            end
        end
        job.cursor = job.cursor + 1
        scanned = scanned + 1
    end
    if job.cursor > job.total then
        finish_job(job)
        table.remove(jobs, 1)
    end
end
ChunkJobs.CHUNK_SIZE = CHUNK_SIZE
Event.on_init(ensure_init)
Event.on_configuration_changed(ensure_init)
Event.add(defines.events.on_tick, on_tick)
return ChunkJobs
