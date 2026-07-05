local FancyTime = require 'lib.fancy_time'
local Server = require 'lib.server'
local Constants = require 'constants'
local Core = require 'lib.antigrief.core'
local DebugLog = require 'lib.debug_log'
local AG = Constants.antigrief
local floor = math.floor
local abs = math.abs
local ActionLog = {}
local this
Core.register_binder(function(s) this = s end)
local is_logging_muted_for = Core.is_logging_muted_for
local bind_storage = Core.bind_storage
local KINDS = {
    build = { verb = 'built', category = 'build' },
    mine = { verb = 'mined', category = 'mining' },
    decon = { verb = 'marked for decon', category = 'deconstruct' },
    upgrade = { verb = 'marked for upgrade', category = 'upgrade' },
}
local function emit_cluster(player, kind, cluster)
    local spec = KINDS[kind]
    local t = abs(floor((cluster.last_tick) / 60))
    local formatted = FancyTime.short_fancy_time(t)
    local lines = 0
    for entity_name, count in pairs(cluster.entities) do
        local str = '[' .. formatted .. '] '
        str = str .. player.name .. ' ' .. spec.verb .. ' '
        if count > 1 then
            str = str .. count .. 'x ' .. entity_name
        else
            str = str .. entity_name
        end
        str = str .. ' at X:'
        str = str .. floor(cluster.position.x)
        str = str .. ' Y:'
        str = str .. floor(cluster.position.y)
        str = str .. ' '
        str = str .. 'surface:' .. cluster.surface_index
        Server.log_antigrief_data(spec.category, str, nil, player.name)
        lines = lines + 1
    end
    DebugLog.log('[antigrief.action_log] flush kind=%s player=%s lines=%d total=%d', kind, player.name, lines, cluster.total_count)
end
function ActionLog.flush()
    bind_storage()
    local pending = this.player_action_pending
    if not pending or not next(pending) then return end
    local current_tick = game.tick
    local time_threshold = AG.robot_mining_cluster_time_threshold_ticks
    local max_count = AG.robot_mining_cluster_max_count
    for player_index, kinds in pairs(pending) do
        local player = game.get_player(player_index)
        if not player or not player.valid then
            pending[player_index] = nil
        else
            for kind, clusters in pairs(kinds) do
                local to_remove = {}
                for cluster_id, cluster in pairs(clusters) do
                    if current_tick - cluster.last_tick >= time_threshold or cluster.total_count >= max_count then
                        emit_cluster(player, kind, cluster)
                        to_remove[#to_remove + 1] = cluster_id
                    end
                end
                for i = 1, #to_remove do
                    clusters[to_remove[i]] = nil
                end
                if not next(clusters) then
                    kinds[kind] = nil
                end
            end
            if not next(kinds) then
                pending[player_index] = nil
            end
        end
    end
end
function ActionLog.queue(player, kind, entity)
    local spec = KINDS[kind]
    if not spec then return end
    if not player or not player.valid then return end
    if not entity or not entity.valid then return end
    if is_logging_muted_for(player) then return end
    if not this or not this.player_action_pending then
        bind_storage() 
    end
    local pending = this.player_action_pending
    local per_player = pending[player.index]
    if not per_player then
        per_player = {}
        pending[player.index] = per_player
    end
    local clusters = per_player[kind]
    if not clusters then
        clusters = {}
        per_player[kind] = clusters
    end
    local current_tick = game.tick
    local pos = entity.position
    local surface_index = entity.surface.index
    local dist = AG.robot_mining_cluster_distance_threshold
    local dist_sq = dist * dist
    local time_threshold = AG.robot_mining_cluster_time_threshold_ticks
    local found
    for _, cluster in pairs(clusters) do
        if cluster.surface_index == surface_index then
            local dx = cluster.position.x - pos.x
            local dy = cluster.position.y - pos.y
            if dx * dx + dy * dy <= dist_sq and current_tick - cluster.last_tick <= time_threshold then
                found = cluster
                break
            end
        end
    end
    if not found then
        found = {
            entities = {},
            total_count = 0,
            position = { x = pos.x, y = pos.y },
            surface_index = surface_index,
            first_tick = current_tick,
            last_tick = current_tick,
        }
        clusters[#clusters + 1] = found
    end
    found.entities[entity.name] = (found.entities[entity.name] or 0) + 1
    found.total_count = found.total_count + 1
    found.last_tick = current_tick
    DebugLog.log('[antigrief.action_log] queue kind=%s player=%s entity=%s cluster_total=%d', kind, player.name, entity.name, found.total_count)
    if found.total_count >= AG.robot_mining_cluster_max_count then
        ActionLog.flush() 
    end
end
return ActionLog
